#ifndef MPU6050_H
#define MPU6050_H

#include <Arduino.h>
#include <Wire.h>
#include "../config.h"
#include "motion.h"

/**
 * MPU6050 六轴运动传感器驱动模块
 *
 * 功能：
 * - 通过I2C总线驱动MPU6050传感器（与MAX30102共享SDA/SCL）
 * - 采集三轴加速度和三轴角速度数据
 * - 集成了运动算法模块，输出步数、跌倒检测结果、运动状态
 *
 * 架构分层：
 * - 本文件：传感器驱动层，负责I2C通信和数据采集
 * - motion.h/cpp：运动算法层，包含计步器、跌倒检测、运动状态识别
 */
class MPU6050Module {
public:
    /**
     * 运动数据结构体
     * 包含加速度、角速度及衍生运动参数
     */
    struct MotionData {
        float ax;   // X轴加速度(g)
        float ay;   // Y轴加速度(g)
        float az;   // Z轴加速度(g)
        float gx;   // X轴角速度(°/s)
        float gy;   // Y轴角速度(°/s)
        float gz;   // Z轴角速度(°/s)
        int steps;  // 步数累计值
        int motionState;  // 运动状态(0=静止, 1=轻度, 2=中度, 3=剧烈)
        bool fallDetected; // 是否检测到跌倒
    };

    /**
     * 初始化MPU6050传感器
     * 唤醒传感器，配置量程和采样率
     * @return true表示初始化成功，false表示I2C通信失败
     */
    bool begin();

    /**
     * 更新传感器数据和运动算法
     * 读取加速度/角速度，执行计步、跌倒检测、运动状态识别
     */
    void update();

    /**
     * 获取最新的运动数据
     * @return MotionData结构体包含加速度、角速度、步数、运动状态、跌倒标志
     */
    MotionData getData();

    /**
     * 获取最新加速度值（供MAX30102运动伪影滤波使用）
     * @param ax X轴加速度输出(g)
     * @param ay Y轴加速度输出(g)
     * @param az Z轴加速度输出(g)
     */
    void getAccel(float& ax, float& ay, float& az);

    /**
     * 清零步数
     * 由主循环在按钮长按时调用
     */
    void resetPedometer() {
        _pedometer.reset();
        data.steps = 0;
    }

    /**
     * 设置累计步数
     * @param s 要设置的步数（用于上电恢复）
     */
    void setSteps(int s) {
        data.steps = s;
        _pedometer.setSteps(s);
    }

    /**
     * 重置所有运动算法状态
     * 包括重力估计、姿态角、计步器、跌倒检测
     */
    void resetAllMotion() {
        _gravX = _gravY = _gravZ = 0;
        _pitch = _roll = 0;
        _lastTime = 0;
        _pedometer.reset();
        _fallDetector.reset();
        _motionState = MotionStateRecognizer();
        data.steps = 0;
        data.fallDetected = false;
        data.motionState = MOTION_IDLE;
    }

private:
    /** MPU6050 寄存器地址常量 */
    static const uint8_t REG_PWR_MGMT_1 = 0x6B;
    static const uint8_t REG_SMPLRT_DIV = 0x19;
    static const uint8_t REG_CONFIG = 0x1A;
    static const uint8_t REG_GYRO_CONFIG = 0x1B;
    static const uint8_t REG_ACCEL_CONFIG = 0x1C;
    static const uint8_t REG_ACCEL_XOUT_H = 0x3B;
    static const uint8_t REG_GYRO_XOUT_H = 0x43;
    static const uint8_t REG_WHO_AM_I = 0x75;

    /** 传感器量程对应的LSB灵敏度 */
    static const float ACCEL_SENSITIVITY;    // ±4g → 8192 LSB/g
    static const float GYRO_SENSITIVITY;     // ±250°/s → 131 LSB/(°/s)

    MotionData data;

    // 运动算法实例（成员变量，支持外部重置）
    Pedometer _pedometer;
    FallDetector _fallDetector;
    MotionStateRecognizer _motionState;

    // 三轴重力估计值（一阶低通滤波输出，begin()时清零）
    float _gravX, _gravY, _gravZ;

    // 互补滤波姿态角与时间戳
    float _pitch, _roll;
    unsigned long _lastTime;

    /** 加速度原始值（用于后续算法处理） */
    int16_t rawAx, rawAy, rawAz;
    int16_t rawGx, rawGy, rawGz;

    /**
     * 从MPU6050指定寄存器读取N字节
     * @param regAddr 起始寄存器地址
     * @param buffer 数据缓冲区
     * @param len 读取字节数
     */
    void readReg(uint8_t regAddr, uint8_t* buffer, uint8_t len);

    /**
     * 向MPU6050指定寄存器写入1字节
     * @param regAddr 目标寄存器地址
     * @param value 写入的值
     */
    void writeReg(uint8_t regAddr, uint8_t value);
};

#endif
