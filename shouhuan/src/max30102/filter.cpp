#include "filter.h"

// ==================== 直流去除滤波器实现 ====================

DCRemovalFilter::DCRemovalFilter(float alpha) : _alpha(alpha), _dc(0) {}

/**
 * 高通滤波处理
 *
 * 使用指数移动平均估计DC分量，然后从输入信号中减去DC分量
 * 从而提取出AC(交流)分量，即PPG信号中的脉搏波动部分
 *
 * @param value 原始输入信号
 * @return AC分量(去除直流偏置后的信号)
 */
long DCRemovalFilter::process(long value) {
    _dc = _alpha * _dc + (1.0f - _alpha) * value;  // 更新DC估计值
    return value - (long)_dc;                        // 输出去除DC后的AC分量
}

void DCRemovalFilter::reset(long initialValue) {
    _dc = initialValue;
}

// ==================== 低通滤波器实现 ====================

LowPassFilter::LowPassFilter(float alpha) : _alpha(alpha), _filtered(0) {}

/**
 * 低通滤波处理
 *
 * 使用一阶IIR低通滤波器对信号进行平滑处理
 * 有效滤除高频噪声和工频干扰
 *
 * @param value 输入的原始信号值
 * @return 平滑后的信号值
 */
long LowPassFilter::process(long value) {
    _filtered = _alpha * _filtered + (1.0f - _alpha) * value;  // 一阶低通滤波
    return (long)_filtered;                                      // 返回滤波结果
}

void LowPassFilter::reset(long initialValue) {
    _filtered = initialValue;
}
