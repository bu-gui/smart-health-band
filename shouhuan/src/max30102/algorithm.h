#ifndef MAX30102_ALGORITHM_H
#define MAX30102_ALGORITHM_H

#include <Arduino.h>
#include "filter.h"

/**
 * 有效红外信号的最小阈值
 * 低于此值认为手指未放置或无有效PPG信号
 * 被SpO2Algorithm、FingerDetector、SignalQuality共享使用
 *
 * 注意：此阈值的设定与LED驱动电流强相关。
 * 当LED电流为0xFF(最大)时，有手指的原始IR值可达50000-200000，
 * 无手指时通常低于2000，因此3000是安全阈值。
 */
static const int MIN_IR_VALUE = 3000;

/**
 * 心率检测算法类
 *
 * 信号处理链路：
 * rawIR → DCRemovalFilter(去DC) → LowPassFilter(去高频噪声) → 动态阈值峰值检测
 *
 * 通过检测PPG信号中的心跳搏动特征来计算心率
 * 使用动态阈值法自适应识别心跳波形
 */
class HeartRateAlgorithm {
public:
    HeartRateAlgorithm();

    /**
     * 检测是否发生一次心跳搏动
     * 内部会对原始信号进行DC去除和低通滤波后再做峰值检测
     * @param irValue 原始红外PPG信号值（未经滤波）
     * @return 1表示检测到心跳，0表示未检测到
     */
    int checkForBeat(long irValue);

    /**
     * 根据两次心跳间隔计算心率值(BPM)
     * @param delta 两次心跳的时间间隔(毫秒)
     * @return 心率值(40-200 BPM)，无效返回0
     */
    int calculateHeartRate(long delta);

    /** 重置算法状态（包括滤波器状态） */
    void reset(long initialDC = 0);

    long getLastBeatTime() const;
    void setLastBeatTime(long time);

private:
    // ====== 信号处理滤波器 ======
    DCRemovalFilter _dcFilter;   // DC去除滤波器：alpha=0.995，去除基线漂移
    LowPassFilter _lpFilter;     // 低通滤波器：alpha=0.8，滤除高频噪声

    long _lastIR;           // 上一次的红外信号值（State 1下降沿参考峰值）
    int _beatState;         // 心跳检测状态机状态(0=等待波峰, 1=等待波谷)
    int _samplesSinceBeat;  // 自上次心跳后经过的样本数（防卡死超时）
    int _samplesSinceReset; // 自上次reset后经过的样本数（跳过DC收敛期假心跳）
    long _peakValue;        // 当前周期内的信号峰值
    long _troughValue;      // 当前周期内的信号谷值
    int _rates[10];         // 最近10次心率值环形缓冲区，用于滑动平均
    int _rateIndex;         // 心率值环形缓冲区写入索引
    long _lastBeatTime;     // 上一次心跳发生的时间戳(毫秒)，用于计算两次心拍间隔 delta
    unsigned long _lastBeatRefractory; // 不应期时间戳(毫秒)，独立用于 checkForBeat 不期锁解耦
};

/**
 * 血氧饱和度(SpO2)算法类
 * 基于红光和红外光的吸收率比值计算血氧饱和度
 */
class SpO2Algorithm {
public:
    SpO2Algorithm();

    /**
     * 计算血氧饱和度（简单版本，已废弃）
     * @deprecated 请使用 calculateFromBuffer() 代替
     */
    int calculate(int red, int ir, bool fingerOn);

    /**
     * 基于缓冲区的血氧饱和度计算（AC/DC归一化方法）
     *
     * 正确实现Beer-Lambert定律：
     *   R = (Red_AC / Red_DC) / (IR_AC / IR_DC)
     *   SpO2 = 110 - 25 * R
     *   其中 AC 通过RMS计算，DC 通过均值计算
     *
     * @param redBuffer 红光信号环形缓冲区
     * @param irBuffer 红外信号环形缓冲区
     * @param bufferSize 缓冲区大小
     * @param fingerOn 手指是否已放置
     * @return SpO2值(70-100%)，无效返回0
     */
    int calculateFromBuffer(long* redBuffer, long* irBuffer, int bufferSize, bool fingerOn);
};

/**
 * 皮肤贴合检测类（fingerOn 命名沿用于最早的手指夹持实验；手腕佩戴时检测皮肤贴合，逻辑一致）
 * 通过检测信号强度和AC分量来判断手指是否正确放置在传感器上
 */
class FingerDetector {
public:
    FingerDetector();

    /**
     * 检测手指是否已放置
     *
     * 双重检测策略：
     * 1. DC跳变检测：当手指放上时，IR值会瞬间大幅跳升(超过基线+阈值)
     *    这是最快速的检测方式，几乎零延迟
     * 2. AC脉动检测：确认存在脉搏信号(PPG的AC/DC比值 > 0.2%)
     *    防止静止物体遮挡造成的误检
     *
     * 只要二者之一满足，且连续3次以上确认，就判定手指已放置
     *
     * @param irValue 当前红外信号值
     * @param redValue 当前红光信号值
     * @param irACMax 红外信号的近期最大值
     * @param irACMin 红外信号的近期最小值
     * @return true表示检测到手指
     */
    bool detect(long irValue, long redValue, long irACMax, long irACMin);

    /** 重置检测状态 */
    void reset();

private:
    int _fingerOnCounter;   // 手指连续检测到的计数(0-15)，用于消抖+滞回
    long _irBaseline;       // IR信号慢速基线追踪，用于DC跳变检测
    bool _fingerLatched;    // 手指检测锁存标志，防止已检测到手指后短暂信号丢失导致闪烁
};

/**
 * 信号质量评估类
 * 通过分析PPG信号的AC/DC比值和信号周期性来评估信号质量
 */
class SignalQuality {
public:
    SignalQuality();

    /**
     * 评估信号质量
     * 综合评估：幅度评分 × 周期性评分（附带 EMA 平滑去闪烁）
     * @param irBuffer 红外信号缓冲区
     * @param bufferSize 缓冲区大小
     * @return 信号质量分数(0-100)，0=无信号，100=信号最佳
     */
    int evaluate(long* irBuffer, int bufferSize);

    /** 重置平滑状态 */
    void reset();

private:
    float _smoothedScore; // 平滑后的信号质量，消除 40ms 局部窗口导致的高频锯齿跳变
};

#endif
