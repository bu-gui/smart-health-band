#include "mpu6050.h"
#include "motion.h"

const float MPU6050Module::ACCEL_SENSITIVITY = 8192.0f;
const float MPU6050Module::GYRO_SENSITIVITY = 131.0f;

void MPU6050Module::writeReg(uint8_t regAddr, uint8_t value) {
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(regAddr);
    Wire.write(value);
    Wire.endTransmission(true);
}

void MPU6050Module::readReg(uint8_t regAddr, uint8_t* buffer, uint8_t len) {
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(regAddr);
    Wire.endTransmission(true);
    Wire.requestFrom(MPU6050_ADDR, len, true);
    for (uint8_t i = 0; i < len; i++) {
        buffer[i] = Wire.read();
    }
}

/**
 * 初始化MPU6050传感器
 *
 * 配置流程：
 * 1. 验证WHO_AM_I寄存器确认通信正常
 * 2. 软件复位传感器（DEVICE_RESET=1），恢复上电默认值
 * 3. 唤醒传感器，选择PLL时钟源
 * 4. 配置采样率为100Hz（SMPLRT_DIV=9）
 * 5. 配置DLPF带宽约41Hz（DLPF_CFG=0x03）
 * 6. 设置陀螺仪量程±250°/s
 * 7. 设置加速度计量程±4g
 *
 * @return true表示初始化成功
 */
bool MPU6050Module::begin() {
    Wire.setTimeOut(50); // 设置 50ms 硬件超时保护

    // ====== 验证WHO_AM_I ======
    uint8_t whoAmI;
    readReg(REG_WHO_AM_I, &whoAmI, 1);
    if (whoAmI != 0x68) {
        return false;
    }

    // ====== 软件复位 (DEVICE_RESET = 0x80) ======
    writeReg(REG_PWR_MGMT_1, 0x80);
    delay(100);

    // ====== 唤醒传感器 (SLEEP = 0x00) ======
    writeReg(REG_PWR_MGMT_1, 0x00);
    delay(50);

    // ====== 配置采样率 ======
    writeReg(REG_SMPLRT_DIV, 9);

    // ====== 配置DLPF ======
    writeReg(REG_CONFIG, 0x03);

    // ====== 配置陀螺仪量程 ======
    writeReg(REG_GYRO_CONFIG, 0x00);

    // ====== 配置加速度计量程 ======
    writeReg(REG_ACCEL_CONFIG, 0x01);

    // ====== 初始化数据 ======
    data.ax = data.ay = data.az = 0;
    data.gx = data.gy = data.gz = 0;
    data.steps = 0;
    data.motionState = MOTION_IDLE;
    data.fallDetected = false;

    rawAx = rawAy = rawAz = 0;
    rawGx = rawGy = rawGz = 0;

    // ====== 初始化运动算法与滤波器 ======
    _pedometer.reset();
    _fallDetector.reset();
    _motionState = MotionStateRecognizer();
    _gravX = _gravY = _gravZ = 0;
    _pitch = _roll = 0;
    _lastTime = micros();

    return true;
}

/**
 * 更新传感器数据
 *
 * 处理流程：
 * 1. 从ACCEL_XOUT_H(0x3B)读取14字节（加速度6 + 温度2 + 陀螺仪6）
 * 2. 转换为物理单位（g和°/s）
 * 3. 更新内部运动算法（计步器、跌倒检测、运动状态）
 */
void MPU6050Module::update() {
    // ====== 读取原始数据 ======
    uint8_t raw[14];
    readReg(REG_ACCEL_XOUT_H, raw, 14);

    rawAx = (int16_t)((raw[0] << 8) | raw[1]);
    rawAy = (int16_t)((raw[2] << 8) | raw[3]);
    rawAz = (int16_t)((raw[4] << 8) | raw[5]);
    rawGx = (int16_t)((raw[8] << 8) | raw[9]);
    rawGy = (int16_t)((raw[10] << 8) | raw[11]);
    rawGz = (int16_t)((raw[12] << 8) | raw[13]);

    // ====== 转换为物理单位 ======
    data.ax = rawAx / ACCEL_SENSITIVITY;
    data.ay = rawAy / ACCEL_SENSITIVITY;
    data.az = rawAz / ACCEL_SENSITIVITY;
    data.gx = rawGx / GYRO_SENSITIVITY;
    data.gy = rawGy / GYRO_SENSITIVITY;
    data.gz = rawGz / GYRO_SENSITIVITY;

    // ====== 重力分量估计（一阶低通 α=0.92 匹配 20Hz 主循环） ======
    _gravX = 0.92f * _gravX + 0.08f * data.ax;
    _gravY = 0.92f * _gravY + 0.08f * data.ay;
    _gravZ = 0.92f * _gravZ + 0.08f * data.az;

    // 去除重力后的纯运动加速度
    float maX = data.ax - _gravX;
    float maY = data.ay - _gravY;
    float maZ = data.az - _gravZ;

    // 合加速度（含重力，用于跌倒检测——真实自由落体时传感器读数趋近0）
    float rawMag = sqrtf(data.ax * data.ax + data.ay * data.ay + data.az * data.az);

    // 合加速度（去重力，用于计步器——只关心运动波动幅度）
    float accMag = sqrtf(maX * maX + maY * maY + maZ * maZ);

    // ====== 运动算法处理 ======
    if (_pedometer.update(accMag)) {
        data.steps = _pedometer.getSteps();
    }

    // 计算姿态角（一阶互补滤波，使用原始含重力加速度）
    unsigned long now = micros();
    float dt = (now - _lastTime) / 1000000.0f;
    _lastTime = now;
    if (dt > 0 && dt < 0.1f) {
        float accPitch = atan2f(data.ay, sqrtf(data.ax * data.ax + data.az * data.az)) * 180.0f / PI;
        float accRoll = atan2f(-data.ax, data.az) * 180.0f / PI;
        _pitch = 0.98f * (_pitch + data.gx * dt) + 0.02f * accPitch;
        _roll = 0.98f * (_roll + data.gy * dt) + 0.02f * accRoll;
    }

    // 更新跌倒检测（使用原始含重力合加速度 + 姿态角）
    data.fallDetected = _fallDetector.update(rawMag, _pitch, _roll);

    // 更新运动状态（使用去重力后的纯运动加速度）
    data.motionState = _motionState.update(maX, maY, maZ);
}

MPU6050Module::MotionData MPU6050Module::getData() {
    return data;
}

void MPU6050Module::getAccel(float& ax, float& ay, float& az) {
    ax = data.ax;
    ay = data.ay;
    az = data.az;
}
