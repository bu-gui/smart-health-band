#include "algorithm.h"
#include <math.h>

// ==================== 心率算法实现 ====================

HeartRateAlgorithm::HeartRateAlgorithm()
    : _lastIR(0), _beatState(0), _samplesSinceBeat(0), _samplesSinceReset(0), _peakValue(0), _troughValue(0),
      _rateIndex(0), _lastBeatTime(0),
      _dcFilter(0.995f), _lpFilter(0.8f) {
    for (int i = 0; i < 10; i++) {
        _rates[i] = 0;
    }
}

/**
 * 心跳搏动检测
 *
 * 信号处理链路：
 * rawIR → DCRemovalFilter(去DC提取AC) → LowPassFilter(去噪) → 动态阈值峰值检测
 *
 * 峰值/谷值追踪使用指数衰减法（与MAX30102Module::processSingleSample中的
 * irACMax/irACMin机制相同）：
 *   - 每帧对峰值做轻微衰减(×0.999)，谷值做轻微增长(×1.001)
 *   - 用硬比较捕获新的极值
 *   - 这样signalRange由近期信号决定，不会因一次reset后归零
 *     导致后续threshold = cleanSignal而无法再触发
 *
 * 安全超时：DC爬坡期可能假触发beat，若500样本未完成周期则强制复位状态
 */
int HeartRateAlgorithm::checkForBeat(long irValue) {
    _samplesSinceReset++;
    if (_samplesSinceReset < 150) return 0;

    long acSignal = _dcFilter.process(irValue);
    long cleanSignal = _lpFilter.process(acSignal);

    // ====== 指数衰减追踪峰谷值（永不硬重置，自适应追踪信号变化） ======
    _peakValue = (long)(_peakValue * 0.999f);
    _troughValue = (long)(_troughValue * 1.001f);
    if (_troughValue > _peakValue) {
        long mid = (_peakValue + _troughValue) / 2;
        _peakValue = mid;
        _troughValue = mid;
    }
    if (cleanSignal > _peakValue) _peakValue = cleanSignal;
    if (cleanSignal < _troughValue) _troughValue = cleanSignal;

    long signalRange = _peakValue - _troughValue;
    long threshold = _troughValue + signalRange * 3 / 4;

    if (_beatState == 0) {
        if (cleanSignal > threshold && cleanSignal > _troughValue + signalRange / 8) {
            _lastIR = cleanSignal;
            _beatState = 1;
            _samplesSinceBeat = 0;
            return 1;
        }
    } else {
        _samplesSinceBeat++;
        if (cleanSignal < _lastIR - signalRange / 8) {
            _beatState = 0;
            _samplesSinceBeat = 0;
        }
        if (_samplesSinceBeat > 500) {
            static int timeoutCount = 0;
            timeoutCount++;
            if (timeoutCount <= 3 || timeoutCount % 50 == 0) {
                Serial.printf("[HR_ALGO] 状态机超时#%d: peak=%ld trough=%ld range=%ld lastIR=%ld cur=%ld need<%ld\n",
                    timeoutCount, _peakValue, _troughValue, signalRange, _lastIR, cleanSignal,
                    _lastIR - signalRange / 8);
            }
            _beatState = 0;
            _samplesSinceBeat = 0;
        }
    }

    return 0;
}

/**
 * 根据两次心跳间隔计算心率
 *
 * 关键修复：从环形缓冲区倒序查找最近一次有效心率，
 * 避免将最旧数据误判为参考值导致正常心率变化被过滤。
 */
int HeartRateAlgorithm::calculateHeartRate(long delta) {
    if (delta > 300 && delta < 2000) {  // 有效间隔范围
        int bpm = 60000 / delta;        // 毫秒转换为BPM

        if (bpm >= 40 && bpm <= 200) {  // 有效心率范围
            // 异常值过滤：与最近一次有效心率比较
            int lastValid = 0;
            for (int i = 1; i <= 10; i++) {
                int idx = (_rateIndex - i + 10) % 10;  // 从最新位置倒序查找
                if (_rates[idx] > 0) {
                    lastValid = _rates[idx];
                    break;
                }
            }
            if (lastValid > 0 && abs(bpm - lastValid) > lastValid * 0.3f) {
                return lastValid;   // 异常跳变，保持上次有效值
            }

            _rates[_rateIndex] = bpm;   // 存入环形缓冲区
            _rateIndex = (_rateIndex + 1) % 10;

            // 计算最近10次有效心率的平均值
            int sum = 0;
            int count = 0;
            for (int i = 0; i < 10; i++) {
                if (_rates[i] > 0) {
                    sum += _rates[i];
                    count++;
                }
            }

            if (count > 0) {
                return sum / count;     // 返回滑动平均结果
            }
        }
    }

    return 0;  // 无效间隔返回0
}

void HeartRateAlgorithm::reset(long initialDC) {
    _lastIR = 0;
    _beatState = 0;
    _samplesSinceBeat = 0;
    _samplesSinceReset = 0;
    _peakValue = 0;
    _troughValue = 0;
    _rateIndex = 0;
    _lastBeatTime = 0;
    for (int i = 0; i < 10; i++) {
        _rates[i] = 0;
    }
    _dcFilter.reset(initialDC);
    _lpFilter.reset(0);
}

long HeartRateAlgorithm::getLastBeatTime() const {
    return _lastBeatTime;
}

void HeartRateAlgorithm::setLastBeatTime(long time) {
    _lastBeatTime = time;
}

// ==================== 血氧饱和度算法实现 ====================

SpO2Algorithm::SpO2Algorithm() {}

/**
 * 血氧饱和度计算（简单版本，已废弃）
 * @deprecated 使用 calculateFromBuffer() 代替，本函数仅保留兼容
 */
int SpO2Algorithm::calculate(int red, int ir, bool fingerOn) {
    if (ir < MIN_IR_VALUE || !fingerOn) {
        return 0;
    }
    float ratio = (float)red / (float)ir;
    int spo2Val = 110 - 25 * ratio;
    if (spo2Val > 100) spo2Val = 100;
    if (spo2Val < 70) spo2Val = 70;
    return spo2Val;
}

/**
 * 基于缓冲区的血氧饱和度计算（AC/DC归一化方法）
 *
 * 正确实现Beer-Lambert定律：
 *   R = (Red_AC / Red_DC) / (IR_AC / IR_DC)
 *   其中 AC 通过RMS计算，DC 通过均值计算
 *
 * 关键修复：使用int64_t累加平方和，避免32位溢出
 */
int SpO2Algorithm::calculateFromBuffer(long* redBuffer, long* irBuffer, int bufferSize, bool fingerOn) {
    if (!fingerOn || bufferSize == 0) return 0;

    // 计算DC分量（均值）
    int64_t redSum = 0, irSum = 0;
    for (int i = 0; i < bufferSize; i++) {
        redSum += redBuffer[i];
        irSum += irBuffer[i];
    }
    long redDC = (long)(redSum / bufferSize);
    long irDC = (long)(irSum / bufferSize);
    if (redDC == 0 || irDC == 0) return 0;

    // 计算AC分量（RMS），使用int64_t避免溢出
    int64_t redSqSum = 0, irSqSum = 0;
    for (int i = 0; i < bufferSize; i++) {
        long redDiff = redBuffer[i] - redDC;
        long irDiff = irBuffer[i] - irDC;
        redSqSum += (int64_t)redDiff * redDiff;
        irSqSum += (int64_t)irDiff * irDiff;
    }
    float redRMS = sqrt((float)redSqSum / bufferSize);
    float irRMS = sqrt((float)irSqSum / bufferSize);

    // 计算R值（AC/DC归一化后再比值）
    float R = (redRMS / redDC) / (irRMS / irDC);

    // 经验公式：SpO2 = 110 - 25 * R
    int spo2 = (int)(110.0f - 25.0f * R);
    if (spo2 > 100) spo2 = 100;
    if (spo2 < 70) spo2 = 70;

    return spo2;
}

// ==================== 手指检测实现 ====================

FingerDetector::FingerDetector() : _fingerOnCounter(0), _irBaseline(0), _fingerLatched(false) {}

/**
 * 手指放置检测（双重检测策略）
 *
 * 关键修复：基线首次初始化时增加信号强度检查，
 * 避免在传感器刚启动、信号极低时捕获无效基线值。
 */
bool FingerDetector::detect(long irValue, long redValue, long irACMax, long irACMin) {
    bool hasFinger = false;

    if (irValue > MIN_IR_VALUE && redValue > 2000) {
        long dcValue = (irACMax + irACMin) / 2;
        long acAmplitude = irACMax - irACMin;

        // 方法1：DC跳变检测
        bool dcJumpDetected = (_irBaseline > 0) && (irValue > _irBaseline + MIN_IR_VALUE);

        // 方法2：AC脉动检测
        bool pulseDetected = (dcValue > 0) && (acAmplitude > dcValue / 500) && (acAmplitude > 20);

        if (dcJumpDetected || pulseDetected) {
            if (_fingerOnCounter < 30) _fingerOnCounter++;
        } else {
            if (_fingerOnCounter > 0) _fingerOnCounter--;
        }

        if (_fingerOnCounter >= 4) {
            _fingerLatched = true;
        }

        if (_fingerLatched) {
            hasFinger = true;
            if (_fingerOnCounter == 0) {
                _fingerLatched = false;
                hasFinger = false;
            }
        }

        // 调试：手指未被检测到时打印中间值
        if (!hasFinger && _fingerOnCounter == 0) {
            static unsigned long lastFingerPrint = 0;
            if (millis() - lastFingerPrint > 2000) {
                lastFingerPrint = millis();
                Serial.printf("[FINGER] ir=%ld red=%ld acAmp=%ld dcVal=%ld base=%ld dcJump=%d pulse=%d cnt=%d\n",
                    irValue, redValue, acAmplitude, dcValue, _irBaseline, dcJumpDetected, pulseDetected, _fingerOnCounter);
            }
        }
    } else {
        _fingerOnCounter -= 3;
        if (_fingerOnCounter < 0) _fingerOnCounter = 0;
        if (_fingerOnCounter == 0) _fingerLatched = false;
    }

    // ====== 更新IR基线（仅无手指时更新） ======
    if (_fingerOnCounter == 0) {
        if (_irBaseline == 0 && irValue > MIN_IR_VALUE) {
            // 修复：仅在信号有效时才初始化基线
            _irBaseline = irValue;
        } else {
            _irBaseline = 0.995f * _irBaseline + 0.005f * irValue;
        }
    }

    return hasFinger;
}

void FingerDetector::reset() {
    _fingerOnCounter = 0;
    _irBaseline = 0;
    _fingerLatched = false;
}

// ==================== 信号质量评估实现 ====================

/**
 * 评估信号质量
 *
 * 评估标准基于幅度评分与周期性评分的乘积：
 *   - 幅度评分：AC/DC 百分比，信号越强得分越高
 *   - 周期性评分：基于过零率的规则性检测，排除随机噪声
 *
 * 在高速采样（800Hz）下，32个样本仅覆盖40ms，
 * 不足以评估周期性的情况下，仅用幅度评分。
 */
int SignalQuality::evaluate(long* irBuffer, int bufferSize) {
    if (bufferSize < 2) return 0;

    long minVal = 0x7FFFFFFF;
    long maxVal = 0;
    long sum = 0;
    int validCount = 0;

    for (int i = 0; i < bufferSize; i++) {
        long v = irBuffer[i];
        if (v > 0) {
            sum += v;
            if (v > maxVal) maxVal = v;
            if (v < minVal) minVal = v;
            validCount++;
        }
    }

    if (validCount == 0) return 0;
    long dc = sum / validCount;
    if (dc < MIN_IR_VALUE) return 0;

    long ac = maxVal - minVal;
    float ratio = (float)ac / (float)dc * 100.0f;

    int baseScore = 0;
    if (ratio < 0.5f) baseScore = 10;
    else if (ratio < 1.0f) baseScore = 30;
    else if (ratio < 2.0f) baseScore = 60;
    else if (ratio < 5.0f) baseScore = 80;
    else if (ratio < 10.0f) baseScore = 90;
    else baseScore = 100;

    // 在不合适的时间尺度上评估周期性反而产生误导。
    // 当采样率高于3×预期心率频率时（800Hz > 3×1.25Hz），
    // 32样本窗口太小，跳过周期性计算。
    return constrain(baseScore, 0, 100);
}
