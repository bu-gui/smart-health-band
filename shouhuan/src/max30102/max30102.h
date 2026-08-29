#ifndef MAX30102_H
#define MAX30102_H

#include <Arduino.h>
#include <Wire.h>
#include "../config.h"
#include "algorithm.h"
#include "filter.h"
#include "motion_filter.h"

/**
 * MAX30102 心率血氧传感器驱动模块
 *
 * 功能：
 * - 通过I2C总线驱动MAX30102传感器
 * - 采集红光(660nm)和红外光(940nm)的PPG信号
 * - 集成了算法和滤波模块，直接输出心率、血氧等健康数据
 *
 * 架构分层：
 * - 本文件：传感器驱动层，负责I2C通信和数据采集
 * - algorithm.h/cpp：算法层，包含心率、血氧、手指检测、信号质量评估
 * - filter.h/cpp：信号处理层，提供DC去除和低通滤波
 */
class MAX30102Module {
public:
    /**
     * 健康数据结构体
     * 包含从PPG信号中提取的所有生理参数
     */
    struct HealthData {
        int heartRate;      // 心率(BPM)，范围40-200，0表示无效
        int spo2;           // 血氧饱和度(%)，范围70-100，0表示无效
        bool fingerOn;      // 手指是否已放置在传感器上
        int signalQuality;  // 信号质量评分(0-100)，0=无信号，100=最佳
    };

    /**
     * 初始化MAX30102传感器
     * 配置I2C通信并设置传感器寄存器
     * @return true表示初始化成功，false表示I2C通信失败
     */
    bool begin();

    /**
     * 更新传感器数据
     * 批量读取FIFO中所有可用样本，逐样本处理后执行算法计算
     * 需要在主循环中频繁调用
     */
    void update();

    /**
     * 获取最新的健康数据
     * @return HealthData结构体包含心率、血氧、手指状态和信号质量
     */
    HealthData getData();

    /**
     * 设置当前加速度数据（来自MPU6050）
     * 用于运动伪影滤波
     * @param ax X轴加速度(g)
     * @param ay Y轴加速度(g)
     * @param az Z轴加速度(g)
     */
    void setAccelData(float ax, float ay, float az);

private:
    /** PPG信号采样缓冲区大小(100个样本，800Hz下覆盖125ms) */
    static const int SAMPLE_COUNT = 100;

    /** 手指移开后保持数据的超时时间(5000ms) */
    static const unsigned long NO_FINGER_TIMEOUT = 5000;

    HealthData data;

    long irBuffer[SAMPLE_COUNT];   // 红外PPG信号环形缓冲区
    long redBuffer[SAMPLE_COUNT];  // 红光PPG信号环形缓冲区
    int bufferIndex;                // 环形缓冲区当前写入位置

    long irACMax;                    // 红外信号近期最大值(衰减式追踪)
    long irACMin;                    // 红外信号近期最小值(衰减式追踪)
    unsigned long lastValidBeatTime; // 最后一次有效心跳的时间戳

    // 运动滤波器预热
    int _filterWarmupCount;          // 预热计数器
    bool _isFilterWarmedUp;          // 预热是否完成

    bool _wasFingerOn;               // 上一次手指状态，用于检测OFF→ON跳变
    unsigned long lastFingerOffTime;  // 上一次手指离开时间戳，用于防闪烁（仅>2s才完全重置）

    // 算法模块实例
    HeartRateAlgorithm hrAlgo;       // 心率检测算法
    SpO2Algorithm spo2Algo;          // 血氧饱和度算法
    FingerDetector fingerDetect;     // 手指放置检测
    SignalQuality sigQuality;        // 信号质量评估

    // 运动伪影滤波
    MotionArtifactFilter motionFilter;  // NLMS自适应运动伪影消除
    float _latestAx;                    // 最新加速度X(g)
    float _latestAy;                    // 最新加速度Y(g)
    float _latestAz;                    // 最新加速度Z(g)

    /**
     * 处理单个PPG样本
     * 包含异常值过滤、运动滤波、手指检测、心率血氧计算等完整处理链路
     */
    void processSingleSample(long red, long ir, unsigned long currentTime);
};

#endif
