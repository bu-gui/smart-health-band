#include "motion.h"

// ==================== 计步器实现 ====================

Pedometer::Pedometer()
    : _steps(0), _state(0), _threshold(0.22f), _currentPeakMax(0.0f),
      _peakIndex(0), _peakCount(0), _lastStepTime(0), _state1StartTime(0),
      _lastAccMag(0), _candidateSteps(0), _isEstablished(false) {
    for (int i = 0; i < 5; i++) {
        _peakValues[i] = 0.22f;
    }
}

/**
 * 计步器更新（黄金平衡防晃步架构 + 状态机卡死防护）
 *
 * 输入：去重力后的纯运动合加速度（静止≈0g，行走≈0.2-0.8g）
 *
 * 算法逻辑：
 * 1. 物理迈步黄金门槛：波峰必须 >= 0.22g，保留自然行走合加速度波峰真实高度
 * 2. 动态阈值下限设为 0.22g，有效隔离打字/手部微小晃动 (<0.22g)
 * 3. 连续 3 步确认机制：偶发摇 1-2 下手自动清零过滤，迈出第 3 步后实时稳定计步
 * 4. 状态 1 增加 1.5 秒超时强行复位，彻底排除硬件噪声导致状态机死锁风险
 */
bool Pedometer::update(float accMag) {
    unsigned long now = millis();

    // 1. 动作停顿超时（>3000ms）：判定连续步态已中断，重置候选步数计数（适应散步走走停停）
    if (_lastStepTime > 0 && (now - _lastStepTime > 3000)) {
        _candidateSteps = 0;
        _isEstablished = false;
    }

    // ====== 状态0: 等待加速度上升超过动态阈值 (下限 0.22g) ======
    if (_state == 0) {
        if (accMag > _threshold && accMag > _lastAccMag) {
            _state = 1;  // 进入上升状态
            _state1StartTime = now;
            _currentPeakMax = accMag;
        }
    }
    // ====== 状态1: 在波峰区域追踪极大值，等待加速度下降到阈值以下 ======
    else if (_state == 1) {
        if (accMag > _currentPeakMax) {
            _currentPeakMax = accMag;
        }

        // 状态1超时保护：如果超过1.5秒仍未下降回落，强行复位状态机，防止死锁
        if (now - _state1StartTime > 1500) {
            _state = 0;
        }
        else if (accMag < _threshold) {
            // 确认 1: 步间隔必须 > 250ms
            // 确认 2: 极大值必须超过物理迈步黄金门槛 0.22g
            if ((now - _lastStepTime > 250) && (_currentPeakMax >= 0.22f)) {
                _lastStepTime = now;
                bool stepCounted = false;

                // 连续 3 步确认逻辑：偶发甩手 1-2 下全数自动过滤，防止误计步
                if (!_isEstablished) {
                    _candidateSteps++;
                    if (_candidateSteps >= 3) {
                        _isEstablished = true;
                        _steps += _candidateSteps; // 连续迈步达标，一次性补齐前 3 步
                        _candidateSteps = 0;
                        stepCounted = true;
                    }
                } else {
                    _steps++; // 步态已建立，实时递增
                    stepCounted = true;
                }

                // 将真实捕获的波峰极大值更新至环形缓冲区（避免极小值污染）
                _peakValues[_peakIndex] = _currentPeakMax;
                _peakIndex = (_peakIndex + 1) % 5;
                if (_peakCount < 5) _peakCount++;

                // 重新计算动态阈值（下限拉高至 0.22g）
                float sum = 0;
                for (int i = 0; i < _peakCount; i++) {
                    sum += _peakValues[i];
                }
                _threshold = (sum / _peakCount) * 0.6f;
                if (_threshold < 0.22f) _threshold = 0.22f;

                _state = 0;
                _lastAccMag = accMag;
                return stepCounted;
            }
            _state = 0;
        }
    }

    _lastAccMag = accMag;

    // 如果长时间没有步伐，默认阈值保持在黄金位 0.22g
    if (now - _lastStepTime > 3000 && _threshold < 0.22f) {
        _threshold = 0.22f;
    }

    return false;
}

void Pedometer::reset() {
    _steps = 0;
    _state = 0;
    _threshold = 0.22f;
    _currentPeakMax = 0.0f;
    _peakIndex = 0;
    _peakCount = 0;
    _lastStepTime = 0;
    _state1StartTime = 0;
    _lastAccMag = 0;
    _candidateSteps = 0;
    _isEstablished = false;
    for (int i = 0; i < 5; i++) {
        _peakValues[i] = 0.22f;
    }
}

void Pedometer::setSteps(int s) {
    _steps = s;
}

// ==================== 跌倒检测实现 ====================

FallDetector::FallDetector()
    : _state(STATE_NORMAL), _freeFallCount(0),
      _freeFallStart(0), _impactTime(0), _postFallStart(0), _alertFlag(false) {}

/**
 * 跌倒检测更新
 *
 * 四级联判状态机：
 *   NORMAL → FREE_FALL → IMPACT_CHECK → POST_FALL_WAIT → POST_FALL_ALERT
 *
 * 优化修正：
 *   - 20Hz 主循环下，连续失重帧调为 2 帧（约 100ms），适应实测跌落失重时长
 *   - 状态转移增加 else if 避免同一帧内被后续超时逻辑冲刷覆盖
 */
bool FallDetector::update(float accMag, float pitch, float roll) {
    unsigned long now = millis();
    _alertFlag = false;

    switch (_state) {
        case STATE_NORMAL:
            if (accMag < 0.4f) {
                _freeFallCount++;
                if (_freeFallCount >= 2) {
                    _state = STATE_FREE_FALL;
                    _freeFallStart = now;
                }
            } else {
                _freeFallCount = 0;
            }
            break;

        case STATE_FREE_FALL:
            if (accMag > 3.0f) {
                _impactTime = now;
                _state = STATE_IMPACT_CHECK;
            } else if (now - _freeFallStart > 500) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            }
            break;

        case STATE_IMPACT_CHECK:
            if (fabsf(pitch) > 45.0f || fabsf(roll) > 45.0f) {
                _postFallStart = now;
                _state = STATE_POST_FALL_WAIT;
            } else if (now - _impactTime > 3000) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            }
            break;

        case STATE_POST_FALL_WAIT:
            if (now - _postFallStart > 500) {
                _state = STATE_POST_FALL_ALERT;
            } else if (fabsf(pitch) < 30.0f && fabsf(roll) < 30.0f) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            } else if (now - _impactTime > 5000) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            }
            break;

        case STATE_POST_FALL_ALERT:
            _alertFlag = true;
            _state = STATE_NORMAL;
            _freeFallCount = 0;
            return true;
    }

    return false;
}

void FallDetector::reset() {
    _state = STATE_NORMAL;
    _freeFallCount = 0;
    _freeFallStart = 0;
    _impactTime = 0;
    _postFallStart = 0;
    _alertFlag = false;
}

// ==================== 运动状态识别实现 ====================

MotionStateRecognizer::MotionStateRecognizer()
    : _bufferIndex(0), _bufferCount(0), _currentState(MOTION_IDLE) {
    for (int i = 0; i < WINDOW_SIZE; i++) {
        _buffer[i] = 0;
    }
}

/**
 * 运动状态识别更新
 *
 * 计算滑动窗口内的加速度标准差（StdDev），消除静态重力直流残余后按阈值分类
 */
MotionType MotionStateRecognizer::update(float ax, float ay, float az) {
    // 计算当前样本的合加速度
    float accMag = sqrtf(ax * ax + ay * ay + az * az);

    // 存入环形缓冲区
    _buffer[_bufferIndex] = accMag;
    _bufferIndex = (_bufferIndex + 1) % WINDOW_SIZE;
    if (_bufferCount < WINDOW_SIZE) _bufferCount++;

    // 计算窗口内均值
    float sum = 0;
    for (int i = 0; i < _bufferCount; i++) {
        sum += _buffer[i];
    }
    float mean = sum / (float)_bufferCount;

    // 计算窗口内标准差
    float sqDiffSum = 0;
    for (int i = 0; i < _bufferCount; i++) {
        float diff = _buffer[i] - mean;
        sqDiffSum += diff * diff;
    }
    float stdDev = sqrtf(sqDiffSum / (float)_bufferCount);

    // 按体感优化的标准差阈值分类：静止<0.08g, 轻度<0.25g, 中度<0.65g, 剧烈>=0.65g
    if (stdDev < 0.08f) {
        _currentState = MOTION_IDLE;
    } else if (stdDev < 0.25f) {
        _currentState = MOTION_LIGHT;
    } else if (stdDev < 0.65f) {
        _currentState = MOTION_MODERATE;
    } else {
        _currentState = MOTION_VIGOROUS;
    }

    return _currentState;
}
