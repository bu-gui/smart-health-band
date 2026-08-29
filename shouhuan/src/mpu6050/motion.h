#ifndef MPU6050_MOTION_H
#define MPU6050_MOTION_H

#include <Arduino.h>

/**
 * 运动状态枚举
 */
enum MotionType {
    MOTION_IDLE = 0,       // 静止
    MOTION_LIGHT = 1,      // 轻度活动（慢走）
    MOTION_MODERATE = 2,   // 中度活动（快走）
    MOTION_VIGOROUS = 3    // 剧烈活动（跑步）
};

/**
 * 计步器类
 *
 * 基于加速度信号的波峰检测实现计步
 * 使用动态阈值和状态机进行步态识别
 *
 * 算法来源：ADI AN-2554 步数统计算法
 * - 合加速度计算：accMag = sqrt(ax²+ay²+az²)
 * - 动态阈值 = 最近N个峰值的滑动平均 × 0.6
 * - 状态机：等待→上升→下降→计步
 * - 最小步间隔：250ms（防止高频抖动）
 */
class Pedometer {
public:
    Pedometer();

    /**
     * 更新计步器状态
     * @param accMag 合加速度值(g)，需要去除重力分量
     * @return true表示检测到一步
     */
    bool update(float accMag);

    /** 获取累计步数 */
    int getSteps() const { return _steps; }

    /** 重置计步器 */
    void reset();

    /** 设置累计步数（用于上电恢复） */
    void setSteps(int s);

private:
    int _steps;                // 累计步数
    int _state;                // 状态机(0=等待, 1=上升过阈值, 2=下降过阈值)
    float _threshold;          // 当前动态阈值
    float _peakValues[5];      // 最近5个峰值环形缓冲
    int _peakIndex;            // 峰值缓冲区索引
    int _peakCount;            // 峰值有效计数
    unsigned long _lastStepTime; // 上一步时间戳
    float _lastAccMag;         // 上一次合加速度值
};

/**
 * 跌倒检测类
 *
 * 基于加速度和姿态角的三级联判跌倒检测
 * 人体跌倒过程分三个阶段：
 *   1. 失重（自由落体）：合加速度 < 0.4g，持续 > 200ms
 *   2. 撞击（触地）：合加速度 > 3.0g，在失重后500ms内
 *   3. 卧姿（倒地）：Pitch或Roll > 45°，撞击后3秒内
 *
 * 姿态角使用一阶互补滤波计算：
 *   angle = α × (angle + gyr×dt) + (1-α) × accAngle, α=0.98
 */
class FallDetector {
public:
    FallDetector();

    /**
     * 更新跌倒检测状态
     * @param accMag 合加速度值(g)
     * @param pitch 俯仰角(°)
     * @param roll 横滚角(°)
     * @return true表示检测到跌倒事件
     */
    bool update(float accMag, float pitch, float roll);

    /** 重置跌倒检测状态机 */
    void reset();

private:
    enum State {
        STATE_NORMAL = 0,         // 正常状态
        STATE_FREE_FALL,          // 检测到失重
        STATE_IMPACT_CHECK,       // 等待撞击
        STATE_POST_FALL_WAIT,     // 等待卧姿持续确认(500ms)
        STATE_POST_FALL_ALERT     // 确认跌倒，触发告警
    };

    int _state;                  // 当前状态
    int _freeFallCount;          // 失重持续时间计数器
    unsigned long _freeFallStart; // 失重开始时间
    unsigned long _impactTime;   // 撞击发生时间
    unsigned long _postFallStart; // 卧姿开始时间戳
    bool _alertFlag;             // 跌倒告警标志
};

/**
 * 运动状态识别类
 *
 * 基于加速度RMS值分类用户当前运动状态
 * 使用1秒滑动窗口计算RMS
 *
 * 分类阈值：
 * - 静止: accRMS < 0.15g
 * - 轻度: 0.15g ≤ accRMS < 0.30g
 * - 中度: 0.30g ≤ accRMS < 0.80g
 * - 剧烈: accRMS ≥ 0.80g
 */
class MotionStateRecognizer {
public:
    MotionStateRecognizer();

    /**
     * 更新运动状态
     * @param ax X轴加速度(g)
     * @param ay Y轴加速度(g)
     * @param az Z轴加速度(g)
     * @return 当前运动状态枚举值
     */
    MotionType update(float ax, float ay, float az);

    /** 获取当前状态 */
    MotionType getState() const { return _currentState; }

private:
    static const int WINDOW_SIZE = 50;   // 1秒窗口 @ 50Hz

    float _buffer[WINDOW_SIZE];  // 加速度RMS环形缓冲区
    int _bufferIndex;            // 缓冲区写入位置
    int _bufferCount;            // 缓冲区有效数据计数
    MotionType _currentState;    // 当前运动状态
};

#endif
