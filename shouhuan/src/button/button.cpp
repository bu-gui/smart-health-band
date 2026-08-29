#include "button.h"

// 防抖延迟时间：200毫秒
const unsigned long ButtonModule::DEBOUNCE_DELAY = 200;
// 长按判定时间：1500毫秒
const unsigned long ButtonModule::LONG_PRESS_MS = 1500;

/**
 * @brief 初始化按钮模块
 * 设置按钮引脚为上拉输入模式，初始化状态变量
 * @return true 初始化成功
 */
bool ButtonModule::begin() {
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    currentPage = 0;
    lastButtonState = HIGH;
    lastDebounceTime = 0;
    pageChanged = false;

    _pressStartTime = 0;
    _longPressFlag = false;
    _longPressHandled = false;

    return true;
}

/**
 * @brief 更新按钮状态
 * 执行防抖逻辑，检测短按（切换页面）和长按（步数清零）事件
 */
void ButtonModule::update() {
    int buttonState = digitalRead(BUTTON_PIN);
    unsigned long now = millis();

    // 检测下降沿：按钮从松开→按下
    if (buttonState == LOW && lastButtonState == HIGH) {
        _pressStartTime = now;
        _longPressFlag = false;
        _longPressHandled = false;
    }

    // 检测上升沿：按钮从按下→松开（短按判定）
    if (buttonState == HIGH && lastButtonState == LOW) {
        unsigned long pressDuration = now - _pressStartTime;

        // 只有持续时间 < 长按阈值且未触发过长按时才切换页面
        if (pressDuration < LONG_PRESS_MS && !_longPressFlag) {
            currentPage = (currentPage + 1) % MAX_PAGES;
            pageChanged = true;
        }

        _pressStartTime = 0;
    }

    // 按钮持续按下中：检测是否达到长按阈值
    if (buttonState == LOW && _pressStartTime > 0 && !_longPressHandled) {
        if (now - _pressStartTime >= LONG_PRESS_MS) {
            _longPressFlag = true;
            _longPressHandled = true;
        }
    }

    // 标准防抖时间戳更新
    if (buttonState != lastButtonState) {
        lastDebounceTime = now;
    }

    lastButtonState = buttonState;
}

/**
 * @brief 检测长按事件（单次触发）
 * @return true 检测到长按（>1.5秒），且未被消费过
 */
bool ButtonModule::isLongPress() {
    if (_longPressFlag) {
        _longPressFlag = false;
        return true;
    }
    return false;
}

/**
 * @brief 检查按钮是否被按下（单次触发）
 * @return true 按钮被按下且状态已变化
 */
bool ButtonModule::isPressed() {
    bool changed = pageChanged;
    pageChanged = false;
    return changed;
}

/**
 * @brief 获取当前页面索引
 * @return 当前页面索引值 (0~MAX_PAGES-1)
 */
int ButtonModule::getPage() {
    return currentPage;
}

/**
 * @brief 从外部设置页面索引（供BLE指令调用）
 * @param page 页面索引值 (0~MAX_PAGES-1)
 */
void ButtonModule::setPage(int page) {
    if (page >= 0 && page < MAX_PAGES) {
        currentPage = page;
        pageChanged = true;
    }
}