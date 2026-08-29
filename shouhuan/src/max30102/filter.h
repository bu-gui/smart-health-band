#ifndef MAX30102_FILTER_H
#define MAX30102_FILTER_H

#include <Arduino.h>

/**
 * 直流(DC)分量去除滤波器
 *
 * 作用：从PPG信号中去除直流偏置，提取交流(AC)分量
 * 原理：一阶高通滤波器，使用指数移动平均(EMA)估计DC分量
 * 公式：DC(n) = alpha * DC(n-1) + (1-alpha) * value(n)
 *       输出 = value(n) - DC(n)
 * alpha越接近1，截止频率越低，对DC的估计越平滑
 */
class DCRemovalFilter {
public:
    /**
     * @param alpha 平滑因子(0-1)，默认0.995。
     *              越大表示DC估计越缓慢，适合去除缓慢变化的基线漂移
     */
    DCRemovalFilter(float alpha = 0.995f);

    /**
     * 处理单个信号值，去除DC分量
     * @param value 输入的原始信号值
     * @return 去除DC后的AC分量值
     */
    long process(long value);

    /** 重置滤波器状态 */
    void reset(long initialValue = 0);

private:
    float _alpha;  // 平滑因子控制滤波器响应速度
    float _dc;     // 估计的直流分量值
};

/**
 * 低通滤波器
 *
 * 作用：滤除PPG信号中的高频噪声
 * 原理：一阶低通IIR滤波器
 * 公式：输出(n) = alpha * 输出(n-1) + (1-alpha) * 输入(n)
 * alpha越接近1，截止频率越低，平滑效果越强
 */
class LowPassFilter {
public:
    /**
     * @param alpha 平滑因子(0-1)，默认0.8。
     *              越大表示滤波效果越强，但信号响应变慢
     */
    LowPassFilter(float alpha = 0.8f);

    /**
     * 处理单个信号值
     * @param value 输入的原始信号值
     * @return 低通滤波后的平滑值
     */
    long process(long value);

    /** 重置滤波器状态 */
    void reset(long initialValue = 0);

private:
    float _alpha;     // 平滑因子控制滤波强度
    float _filtered;  // 上一次滤波输出值
};

#endif
