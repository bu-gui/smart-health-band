#include "power_manager.h"

/**
 * @brief 初始化电源管理模块
 * 设置 ADC 分辨率、初始化状态变量和采样缓冲区
 * @param adcPin ADC 输入引脚
 * @return true 初始化成功
 */
bool PowerManager::begin(int adcPin) {
    _adcPin = adcPin;
    _lastActivityTime = millis();
    _screenTimeout = 10000;
    _screenOn = true;
    _voltage = 0;
    _percentage = 100;
    _lowBattery = false;

    _sampleIndex = 0;
    _sampleCount = 0;

    analogReadResolution(12);

    return true;
}

/**
 * @brief 更新电源状态（每帧调用）
 *
 * 每次调用执行三个任务：
 *   1. 采集并滤波电池电压
 *   2. 换算电量百分比，判断低电量
 *   3. 检查屏幕是否超时
 */
void PowerManager::update() {
    float rawVoltage = readBatteryVoltage();
    _voltage = smoothFilter(rawVoltage);

    _percentage = voltageToPercentage(_voltage);
    _lowBattery = (_voltage < 3.3f);

    unsigned long now = millis();
    if (_screenOn && (now - _lastActivityTime >= _screenTimeout)) {
        _screenOn = false;
    }
}

/**
 * @brief 获取当前电源状态
 * @return PowerStatus 包含电压、电量、低电量标志、屏幕状态
 */
PowerManager::PowerStatus PowerManager::getStatus() {
    PowerStatus s;
    s.voltage = _voltage;
    s.percentage = _percentage;
    s.lowBattery = _lowBattery;
    s.screenOn = _screenOn;
    return s;
}

/**
 * @brief 快捷获取电量百分比
 * @return 0~100
 */
int PowerManager::getPercentage() {
    return _percentage;
}

/**
 * @brief 判断是否低电量
 * @return true 电压低于 3.3V
 */
bool PowerManager::isLowBattery() {
    return _lowBattery;
}

/**
 * @brief 判断屏幕是否点亮
 * @return true 屏幕亮着
 */
bool PowerManager::isScreenOn() {
    return _screenOn;
}

/**
 * @brief 标记用户活动
 * 重置超时计时器，立即唤醒屏幕
 */
void PowerManager::markActivity() {
    _lastActivityTime = millis();
    _screenOn = true;
}

/**
 * @brief 设置屏幕自动熄屏时间
 * @param ms 超时毫秒数
 */
void PowerManager::setScreenTimeout(unsigned long ms) {
    _screenTimeout = ms;
}

/**
 * @brief 读取电池电压（原始值）
 *
 * 通过 ADC 采集分压后的电压值（ADC 读到的是 VBAT/2），
 * 使用 analogReadMilliVolts 获得毫伏值后反算实际电池电压。
 *
 * 电压分压电路：
 *   VBAT ── 100KΩ ──┬── 100KΩ ── GND
 *                     │
 *                     └── GPIO (ADC)
 *
 * VBAT = ADC_mV × 2 / 1000
 *
 * @return 电池电压 (V)
 */
float PowerManager::readBatteryVoltage() {
    int adcMilliVolts = analogReadMilliVolts(_adcPin);
    return (adcMilliVolts * 2.0f) / 1000.0f;
}

/**
 * @brief 滑动平均滤波
 *
 * 保持最近 BATTERY_SAMPLE_COUNT 次采样值，
 * 取算术平均作为当前电压输出，滤除瞬时波动。
 *
 * @param rawVoltage 原始 ADC 采样值
 * @return 滤波后的电压值 (V)
 */
float PowerManager::smoothFilter(float rawVoltage) {
    _samples[_sampleIndex] = rawVoltage;
    _sampleIndex = (_sampleIndex + 1) % BATTERY_SAMPLE_COUNT;
    if (_sampleCount < BATTERY_SAMPLE_COUNT) {
        _sampleCount++;
    }

    float sum = 0;
    for (int i = 0; i < _sampleCount; i++) {
        sum += _samples[i];
    }
    return sum / (float)_sampleCount;
}

/**
 * @brief 电压→电量百分比映射
 *
 * 使用分段线性映射，参考典型锂电池放电曲线：
 *
 *   电压区间         电量区间
 *   4.15V 以上        100%
 *   3.82V ~ 4.15V    50% ~ 100%
 *   3.50V ~ 3.82V    10% ~ 50%
 *   3.30V ~ 3.50V     5% ~ 10%
 *   3.00V ~ 3.30V     0% ~ 5%
 *   3.00V 以下          0%
 *
 * @param voltage 电池电压 (V)
 * @return 电量百分比 0~100
 */
int PowerManager::voltageToPercentage(float voltage) {
    if (voltage >= 4.15f) return 100;
    if (voltage >= 3.82f) {
        return 50 + (int)((voltage - 3.82f) / (4.15f - 3.82f) * 50.0f);
    }
    if (voltage >= 3.50f) {
        return 10 + (int)((voltage - 3.50f) / (3.82f - 3.50f) * 40.0f);
    }
    if (voltage >= 3.30f) {
        return 5 + (int)((voltage - 3.30f) / (3.50f - 3.30f) * 5.0f);
    }
    if (voltage >= 3.00f) {
        return (int)((voltage - 3.00f) / (3.30f - 3.00f) * 5.0f);
    }
    return 0;
}
