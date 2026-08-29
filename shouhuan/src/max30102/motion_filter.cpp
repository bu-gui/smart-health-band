#include "motion_filter.h"

const float MotionArtifactFilter::MU = 0.005f;
const float MotionArtifactFilter::DELTA = 1e-4f;

MotionArtifactFilter::MotionArtifactFilter()
    : _bufIndex(0), _gravityX(0), _gravityY(0), _gravityZ(0), _ppgDc(0) {
    for (int i = 0; i < TAPS; i++) {
        _weights[i] = 0;
    }
    for (int i = 0; i < M; i++) {
        _accBufX[i] = 0;
        _accBufY[i] = 0;
        _accBufZ[i] = 0;
    }
}

/**
 * 从加速度中去除重力分量
 * 使用一阶低通滤波器(α=0.995)估计重力方向
 */
float MotionArtifactFilter::removeGravity(float rawAcc, float& gravityEst) {
    gravityEst = 0.995f * gravityEst + 0.005f * rawAcc;
    return rawAcc - gravityEst;
}

/**
 * NLMS自适应滤波处理（含DC去除预处理）
 *
 * 关键改进：在处理前对PPG做DC去除，避免PPG的DC分量
 * (50000-200000)与加速度信号(±2g)数量级差异导致
 * 误差信号被淹没，权重无法收敛。
 */
long MotionArtifactFilter::process(long ppgRaw, float ax, float ay, float az) {
    // ====== 0. 预处理：去除PPG的DC分量（指数移动平均估计DC） ======
    _ppgDc = 0.995f * _ppgDc + 0.005f * (float)ppgRaw;
    float ppgAc = (float)ppgRaw - _ppgDc;  // 提取AC分量（脉搏波动）

    // ====== 1. 去除重力分量 ======
    float maX = removeGravity(ax, _gravityX);
    float maY = removeGravity(ay, _gravityY);
    float maZ = removeGravity(az, _gravityZ);

    // ====== 2. 更新环形缓冲区 ======
    _accBufX[_bufIndex] = maX;
    _accBufY[_bufIndex] = maY;
    _accBufZ[_bufIndex] = maZ;
    _bufIndex = (_bufIndex + 1) % M;

    // ====== 3. 构建参考向量 x = [X轴M个历史, Y轴M个历史, Z轴M个历史] ======
    float x[TAPS];
    for (int i = 0; i < M; i++) {
        x[i] = _accBufX[(_bufIndex + i) % M];
        x[i + M] = _accBufY[(_bufIndex + i) % M];
        x[i + 2 * M] = _accBufZ[(_bufIndex + i) % M];
    }

    // ====== 4. 计算运动噪声估计 y = wᵀ·x ======
    float noise = 0;
    for (int i = 0; i < TAPS; i++) {
        noise += _weights[i] * x[i];
    }

    // ====== 5. 去噪输出：原始信号减去估计的噪声 ======
    long ppgClean = ppgRaw - (long)noise;

    // ====== 6. NLMS权重更新（使用AC分量误差，而非原始PPG） ======
    float error = ppgAc - noise;  // AC分量误差
    float xNorm = 0;
    for (int i = 0; i < TAPS; i++) {
        xNorm += x[i] * x[i];
    }
    float stepNorm = MU / (xNorm + DELTA);
    for (int i = 0; i < TAPS; i++) {
        _weights[i] += stepNorm * error * x[i];
    }

    return ppgClean;
}

void MotionArtifactFilter::reset() {
    _bufIndex = 0;
    _gravityX = _gravityY = _gravityZ = 0;
    _ppgDc = 0;  // 重置PPG DC估计
    for (int i = 0; i < TAPS; i++) {
        _weights[i] = 0;
    }
    for (int i = 0; i < M; i++) {
        _accBufX[i] = 0;
        _accBufY[i] = 0;
        _accBufZ[i] = 0;
    }
}
