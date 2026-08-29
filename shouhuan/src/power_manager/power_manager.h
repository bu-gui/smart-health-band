#ifndef POWER_MANAGER_H
#define POWER_MANAGER_H

#include <Arduino.h>
#include "../config.h"

/**
 * @brief 滑动平均滤波采样次数
 */
#define BATTERY_SAMPLE_COUNT 10

/**
 * @brief 电源管理模块
 *
 * 负责电池电压采集、电量计算、屏幕超时管理。
 * 通过 ADC 读取分压后的电池电压，换算为电量百分比，
 * 并根据用户活动自动控制屏幕开关以节省功耗。
 */
class PowerManager {
public:
    /**
     * @brief 电源状态结构体
     */
    struct PowerStatus {
        float voltage;       //!< 电池电压 (V)
        int percentage;      //!< 电量百分比 (0-100)
        bool lowBattery;     //!< 是否低电量 (<3.3V)
        bool screenOn;       //!< 屏幕是否亮着
    };

    /**
     * @brief 初始化电源管理模块
     * @param adcPin ADC 输入引脚（接分压电路中点）
     * @return true 初始化成功
     */
    bool begin(int adcPin);

    /**
     * @brief 更新电源状态（每帧调用）
     * 采集电池电压、更新电量、检查屏幕超时
     */
    void update();

    /**
     * @brief 获取当前电源状态
     * @return PowerStatus 结构体
     */
    PowerStatus getStatus();

    /**
     * @brief 快捷获取电量百分比
     * @return 电量百分比 (0-100)
     */
    int getPercentage();

    /**
     * @brief 判断是否低电量
     * @return true 电池电压低于 3.3V
     */
    bool isLowBattery();

    /**
     * @brief 判断屏幕是否处于点亮状态
     * @return true 屏幕亮着
     */
    bool isScreenOn();

    /**
     * @brief 标记用户活动（按键按下时调用）
     * 重置屏幕超时计时器，唤醒屏幕
     */
    void markActivity();

    /**
     * @brief 设置屏幕自动熄屏时间
     * @param ms 超时时间（毫秒），默认 10000
     */
    void setScreenTimeout(unsigned long ms);

private:
    int _adcPin;
    unsigned long _lastActivityTime;
    unsigned long _screenTimeout;
    bool _screenOn;
    float _voltage;
    int _percentage;
    bool _lowBattery;

    float _samples[BATTERY_SAMPLE_COUNT];
    int _sampleIndex;
    int _sampleCount;

    /**
     * @brief 读取 ADC 并换算为电池电压
     * @return 电池电压 (V)
     */
    float readBatteryVoltage();

    /**
     * @brief 将电压映射为电量百分比
     * @param voltage 电池电压 (V)
     * @return 电量百分比 (0-100)
     */
    int voltageToPercentage(float voltage);

    /**
     * @brief 滑动平均滤波
     * @param rawVoltage 原始采样值
     * @return 滤波后的电压值 (V)
     */
    float smoothFilter(float rawVoltage);
};

#endif
