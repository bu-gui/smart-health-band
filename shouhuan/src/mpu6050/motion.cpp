#include "motion.h"

// ==================== 计步器实现 ====================

Pedometer::Pedometer()
    : _steps(0), _state(0), _threshold(0.25f),
      _peakIndex(0), _peakCount(0), _lastStepTime(0), _lastAccMag(0) {
    for (int i = 0; i < 5; i++) {
        _peakValues[i] = 0.25f;
    }
}

/**
 * 计步器更新
 *
 * 输入应为去重力后的纯运动合加速度（静止≈0g，行走≈0.2-0.8g）
 *
 * 算法逻辑：
 * 1. 行走时纯运动加速度周期性波动，峰值超过阈值则检测为一步
 * 2. 动态阈值 = 最近5个峰值的均值 × 0.6，自动适应步态强度
 * 3. 状态机避免在阈值附近晃动时重复计数
 * 4. 最小步间隔 250ms 防止高频抖动
 */
bool Pedometer::update(float accMag) {
    unsigned long now = millis();

    // ====== 状态0: 等待加速度上升超过阈值 ======
    if (_state == 0) {
        if (accMag > _threshold && accMag > _lastAccMag) {
            _state = 1;  // 进入上升状态
        }
    }
    // ====== 状态1: 等待加速度下降到阈值以下 ======
    else if (_state == 1) {
        if (accMag < _threshold && accMag < _lastAccMag) {
            // 确认步间隔 > 250ms
            if (now - _lastStepTime > 250) {
                _steps++;
                _lastStepTime = now;

                // 更新峰值环形缓冲区
                _peakValues[_peakIndex] = accMag;
                _peakIndex = (_peakIndex + 1) % 5;
                if (_peakCount < 5) _peakCount++;

                // 重新计算动态阈值
                float sum = 0;
                for (int i = 0; i < _peakCount; i++) {
                    sum += _peakValues[i];
                }
                _threshold = (sum / _peakCount) * 0.6f;
                if (_threshold < 0.15f) _threshold = 0.15f;

                _state = 0;
                _lastAccMag = accMag;
                return true;
            }
            _state = 0;
        }
    }

    _lastAccMag = accMag;

    // 如果长时间没有步伐，降低阈值防止丢失
    if (now - _lastStepTime > 3000 && _threshold > 0.25f) {
        _threshold = 0.25f;
    }

    return false;
}

void Pedometer::reset() {
    _steps = 0;
    _state = 0;
    _threshold = 0.25f;
    _peakIndex = 0;
    _peakCount = 0;
    _lastStepTime = 0;
    _lastAccMag = 0;
    for (int i = 0; i < 5; i++) {
        _peakValues[i] = 0;
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
 * 相比三级增加了"卧姿持续确认"阶段：
 *   触发跌倒后不会立即告警，而是等待 500ms 确认用户没有起身
 *   如果中途恢复站立(姿态<30°)则自动取消
 *   有效减少弯腰、快速坐下等场景的误报
 */
bool FallDetector::update(float accMag, float pitch, float roll) {
    unsigned long now = millis();
    _alertFlag = false;

    switch (_state) {
        case STATE_NORMAL:
            if (accMag < 0.4f) {
                _freeFallCount++;
                if (_freeFallCount > 10) {
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
            }
            if (now - _freeFallStart > 500) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            }
            break;

        case STATE_IMPACT_CHECK:
            if (fabsf(pitch) > 45.0f || fabsf(roll) > 45.0f) {
                _postFallStart = now;
                _state = STATE_POST_FALL_WAIT;
            }
            if (now - _impactTime > 3000) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            }
            break;

        case STATE_POST_FALL_WAIT:
            if (now - _postFallStart > 500) {
                _state = STATE_POST_FALL_ALERT;
            }
            if (fabsf(pitch) < 30.0f && fabsf(roll) < 30.0f) {
                _state = STATE_NORMAL;
                _freeFallCount = 0;
            }
            if (now - _impactTime > 5000) {
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
 * 计算滑动窗口内的加速度RMS值，按阈值分类
 */
MotionType MotionStateRecognizer::update(float ax, float ay, float az) {
    // 计算当前样本的合加速度
    float accMag = sqrtf(ax * ax + ay * ay + az * az);

    // 存入环形缓冲区
    _buffer[_bufferIndex] = accMag;
    _bufferIndex = (_bufferIndex + 1) % WINDOW_SIZE;
    if (_bufferCount < WINDOW_SIZE) _bufferCount++;

    // 计算窗口内RMS
    float sum = 0;
    for (int i = 0; i < _bufferCount; i++) {
        sum += _buffer[i] * _buffer[i];
    }
    float rms = sqrtf(sum / _bufferCount);

    // 按阈值分类
    if (rms < 0.15f) {
        _currentState = MOTION_IDLE;
    } else if (rms < 0.30f) {
        _currentState = MOTION_LIGHT;
    } else if (rms < 0.80f) {
        _currentState = MOTION_MODERATE;
    } else {
        _currentState = MOTION_VIGOROUS;
    }

    return _currentState;
}
