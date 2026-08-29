#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include "../config.h"

/**
 * @brief OLED显示模块类
 * 
 * 负责控制SH1106 OLED显示屏，提供多个显示页面的绘制功能
 */
class DisplayModule {
public:
    /**
     * @brief 初始化显示模块
     * 初始化OLED显示屏，设置文本大小和颜色
     * @return true 初始化成功，false 初始化失败
     */
    bool begin();
    
    /**
     * @brief 显示启动画面
     * 显示设备名称和版本信息，以及初始化提示
     */
    void showSplash();
    
    /**
     * @brief 显示健康数据页面（简化版）
     * @param heartRate 心率值（bpm）
     * @param spo2 血氧饱和度（%）
     * @param steps 步数
     */
    void showHealthPage(int heartRate, int spo2, int steps);
    
    /**
     * @brief 显示健康数据页面（完整版）
     * @param heartRate 心率值（bpm）
     * @param spo2 血氧饱和度（%）
     * @param steps 步数
     * @param fingerOn 手指是否在传感器上
     * @param signalQuality 信号质量（0-100）
     */
    void showHealthPage(int heartRate, int spo2, int steps, bool fingerOn, int signalQuality);
    
    /**
     * @brief 显示运动数据页面
     * @param ax X轴加速度（m/s²）
     * @param ay Y轴加速度（m/s²）
     * @param az Z轴加速度（m/s²）
     * @param gx X轴角速度（°/s）
     * @param gy Y轴角速度（°/s）
     * @param gz Z轴角速度（°/s）
     * @param motionState 运动状态(0=静止,1=轻度,2=中度,3=剧烈)
     */
    void showMotionPage(float ax, float ay, float az, float gx, float gy, float gz, int motionState);
    
    /**
     * @brief 显示系统状态页面
     * @param wifiConnected WiFi连接状态
     * @param bleEnabled BLE启用状态
     * @param bleConnected BLE连接状态
     * @param steps 步数
     */
    void showStatusPage(bool wifiConnected, bool bleEnabled, bool bleConnected, int steps);
    
    /**
     * @brief 显示跌倒告警页面
     * 全屏闪烁显示跌倒警报
     */
    void showFallAlert();
    
    /**
     * @brief 清除显示内容
     */
    void clear();
    
private:
    Adafruit_SH1106G display{128, 64, OLED_MOSI, OLED_SCK, OLED_DC, OLED_RESET, OLED_CS};
};

#endif