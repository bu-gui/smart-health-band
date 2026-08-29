#ifndef MAX30102_MOTION_FILTER_H
#define MAX30102_MOTION_FILTER_H

#include <Arduino.h>

/**
 * NLMS自适应运动伪影滤波类
 *
 * 用途：使用MPU6050加速度数据作为参考信号，
 *       从MAX30102的PPG信号中去除运动噪声
 *
 * 原理：
 *   观测信号 d(n) = 原始PPG信号 (ir或者red)
 *   参考信号 x(n) = [ax近年值, ay近年值, az近年值] （三轴加速度历史窗口）
 *   估计噪声 y(n) = w(n)ᵀ · x(n)
 *   去噪输出 e(n) = d(n) - y(n)
 *
 * NLMS权重更新公式：
 *   w(n+1) = w(n) + μ · e(n) · x(n) / (||x(n)||² + δ)
 *
 * 关键优化：在处理前先对PPG信号做DC去除预处理，
 *   避免PPG的DC分量(50000-200000)与加速度信号(±2g)数量级差异
 *   导致误差信号被淹没，权重无法收敛。
 *
 * 参数（经验证）：
 *   - 滤波器阶数 M = 4（每轴4个历史延迟，共12个权重系数）
 *   - 步长 μ = 0.005（降低步长防止过度滤波，尤其是剧烈运动场景）
 *   - 归一化常量 δ = 1e-4
 */
class MotionArtifactFilter {
public:
    MotionArtifactFilter();

    /**
     * 处理单个PPG样本，去除运动伪影
     *
     * @param ppgRaw 原始PPG信号值（来自MAX30102红外通道）
     * @param ax X轴加速度(g)，应已去除重力分量
     * @param ay Y轴加速度(g)，应已去除重力分量
     * @param az Z轴加速度(g)，应已去除重力分量
     * @return 去噪后的PPG信号值
     */
    long process(long ppgRaw, float ax, float ay, float az);

    /** 重置滤波器状态（所有权重归零，DC估计清零） */
    void reset();

private:
    static const int M = 4;          // 每轴滤波器阶数
    static const int TAPS = 3 * M;   // 总权重数 = 12
    static const float MU;           // 步长因子 0.02
    static const float DELTA;        // 归一化常量 1e-4

    float _weights[TAPS];            // 自适应滤波器权重系数
    float _accBufX[M];               // X轴加速度历史缓冲区
    float _accBufY[M];               // Y轴加速度历史缓冲区
    float _accBufZ[M];               // Z轴加速度历史缓冲区
    int _bufIndex;                   // 环形缓冲区写入位置

    /** 估计加速度中的重力分量，返回去除重力后的纯运动加速度 */
    float removeGravity(float rawAcc, float& gravityEst);

    float _gravityX;                 // X轴重力估计值
    float _gravityY;                 // Y轴重力估计值
    float _gravityZ;                 // Z轴重力估计值

    float _ppgDc;                    // PPG信号的DC分量估计（指数移动平均）
};

#endif
