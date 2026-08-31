#ifndef SYSTEM_H
#define SYSTEM_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include "../config.h"

#define CMD_QUEUE_SIZE 4

/**
 * @brief BLE系统管理模块
 *
 * 负责管理蓝牙通信，包含三个BLE特征：
 * - Notify: 手环向手机推送健康数据（JSON格式）
 * - Write: 接收手机下发的控制指令
 * - Read: 手机读取设备基本信息
 */
class SystemModule {
public:
    /**
     * @brief 系统状态结构体
     */
    struct SystemStatus {
        bool bleEnabled;      // BLE模块是否已初始化
        bool bleConnected;    // 是否有手机客户端连接
    };

    bool begin();
    void update();
    SystemStatus getStatus();

    /**
     * @brief 推送健康数据到手机
     * @param heartRate 心率 (bpm)
     * @param spo2 血氧饱和度 (%)
     * @param steps 步数
     * @param motionState 运动状态 (0=静止,1=轻度,2=中度,3=剧烈)
     * @param fallDetected 是否检测到跌倒
     * @param signalQuality 信号质量 (0-100)
     */
    void notifyHealthData(int heartRate, int spo2, int steps, int motionState, bool fallDetected, int signalQuality);

    /**
     * @brief 推送跌倒告警到手机
     */
    void notifyFallAlert();

    /**
     * @brief 从指令队列取出下一条待处理的BLE指令
     * @param cmd 指令名称（输出参数）
     * @param arg 指令参数（输出参数）
     * @return true 有指令待处理，false 队列为空
     */
    bool getNextCommand(String& cmd, String& arg);

    /**
     * @brief 注册页面切换回调
     * @param cb 回调函数指针
     */
    void setPageCallback(void (*cb)(int));

    /**
     * @brief 从电源管理模块同步电池电量（百分比）
     * @param level 电量百分比（0-100）
     */
    void setBatteryLevel(int level);

    /**
     * @brief 设置时间偏移（供电持久化恢复用）
     * @param offset 时间偏移（秒）
     */
    void setTimeOffset(long offset) { timeOffset = offset; }

    /**
     * @brief 获取当前时间偏移（秒）
     */
    long getTimeOffset() const { return timeOffset; }

private:
    SystemStatus status;

    BLEServer* pServer;
    BLECharacteristic* pNotifyChar;
    BLECharacteristic* pWriteChar;
    BLECharacteristic* pReadChar;

    String cmdQueue[CMD_QUEUE_SIZE];
    String argQueue[CMD_QUEUE_SIZE];
    int cmdHead;
    int cmdTail;

    void pushCommand(const String& cmd, const String& arg);

    unsigned long bootTime;
    volatile long timeOffset;
    bool measuring;

    int batteryLevel;

    void (*pageCallback)(int);

    /**
     * @brief BLE连接回调类
     */
    class ServerCallbacks : public BLEServerCallbacks {
    public:
        void onConnect(BLEServer* server);
        void onDisconnect(BLEServer* server);
    };

    /**
     * @brief BLE写入回调类
     * 手机通过Write特征发送指令时触发
     */
    class WriteCallbacks : public BLECharacteristicCallbacks {
    public:
        void onWrite(BLECharacteristic* pCharacteristic);
    };

    void initBLE();
    void handleCommand(const String& cmd, const String& arg);
    long getUnixTime();
};

#endif
