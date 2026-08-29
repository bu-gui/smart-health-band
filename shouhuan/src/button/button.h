#ifndef BUTTON_H
#define BUTTON_H

#include <Arduino.h>
#include "../config.h"

/**
 * @brief 按钮模块类
 * 
 * 负责处理按钮输入，实现防抖功能，并管理页面切换逻辑
 */
class ButtonModule {
public:
    /**
     * @brief 初始化按钮模块
     * 设置按钮引脚为上拉输入模式，初始化状态变量
     * @return true 初始化成功
     */
    bool begin();
    
    /**
     * @brief 检查按钮是否被按下（单次触发）
     * @return true 按钮被按下且状态已变化
     */
    bool isPressed();
    
    /**
     * @brief 获取当前页面索引
     * @return 当前页面索引值 (0~MAX_PAGES-1)
     */
    int getPage();

    /**
     * @brief 从外部设置页面索引（供BLE指令调用）
     * @param page 页面索引值 (0~MAX_PAGES-1)
     */
    void setPage(int page);
    
    /**
     * @brief 更新按钮状态（需在主循环中调用）
     * 执行防抖逻辑，检测按钮短按和长按事件
     * 短按：切换页面
     * 长按：触发步数清零（由isLongPress()读取）
     */
    void update();

    /**
     * @brief 检测长按事件（单次触发）
     * @return true 检测到长按（>1.5秒），且未被消费过
     */
    bool isLongPress();

private:
    static const unsigned long DEBOUNCE_DELAY;  // 防抖延迟（毫秒）
    static const unsigned long LONG_PRESS_MS;   // 长按判定时间（毫秒）

    int currentPage;           // 当前页面索引
    int lastButtonState;       // 上一次读取的按钮状态
    unsigned long lastDebounceTime;  // 上一次状态变化的时间戳
    bool pageChanged;          // 页面是否发生变化的标志位

    unsigned long _pressStartTime;   // 按钮按下时刻（用于长按判断）
    bool _longPressFlag;             // 长按事件是否发生的标志
    bool _longPressHandled;          // 长按事件是否已被消费
};

#endif