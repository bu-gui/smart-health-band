#include "system.h"

static SystemModule* systemInstance = nullptr;

/**
 * @brief BLE连接回调：手机客户端已连接
 */
void SystemModule::ServerCallbacks::onConnect(BLEServer* server) {
    if (systemInstance) {
        systemInstance->status.bleConnected = true;
        Serial.println("[BLE] 客户端已连接");
    }
}

/**
 * @brief BLE断开回调：手机客户端已断开，自动恢复广播
 */
void SystemModule::ServerCallbacks::onDisconnect(BLEServer* server) {
    if (systemInstance) {
        systemInstance->status.bleConnected = false;
        Serial.println("[BLE] 客户端已断开");
        server->startAdvertising();
    }
}

/**
 * @brief BLE写入回调：手机通过Write特征下发指令时触发
 *
 * 指令格式：
 * - 无参数: "reset_steps"
 * - 带参数: "set_page:0" "sync_time:1716000000"
 *
 * 解析出指令名和参数后交给 handleCommand 处理
 */
void SystemModule::WriteCallbacks::onWrite(BLECharacteristic* pChar) {
    if (!systemInstance) return;

    std::string raw = pChar->getValue();
    if (raw.empty()) return;

    String value(raw.c_str());
    Serial.printf("[BLE] 收到指令: %s\n", value.c_str());

    int colonIdx = value.indexOf(':');
    if (colonIdx > 0) {
        String cmd = value.substring(0, colonIdx);
        String arg = value.substring(colonIdx + 1);
        systemInstance->handleCommand(cmd, arg);
    } else {
        systemInstance->handleCommand(value, "");
    }
}

/**
 * @brief 解析并执行BLE指令
 *
 * 支持的指令：
 * - reset_steps    重置步数
 * - set_page:N     切换显示页面
 * - sync_time:ts   同步Unix时间戳
 * - start_measure  恢复数据推送
 * - stop_measure   暂停数据推送
 *
 * 需要主循环处理的指令（reset_steps, set_page, sync_time）
 * 会压入指令队列，由 getNextCommand 在主循环中消费
 */
void SystemModule::handleCommand(const String& cmd, const String& arg) {
    if (cmd == "reset_steps") {
        pushCommand("reset_steps", "");
        Serial.println("[BLE] 执行: 重置步数");
    } else if (cmd == "set_page") {
        pushCommand("set_page", arg);
        Serial.printf("[BLE] 执行: 切换页面 %s\n", arg.c_str());
    } else if (cmd == "sync_time") {
        timeOffset = arg.toInt() - (millis() / 1000);
        Serial.printf("[BLE] 时间已同步, offset=%ld\n", timeOffset);
        pushCommand("sync_time", arg);
    } else if (cmd == "start_measure") {
        measuring = true;
        Serial.println("[BLE] 开始测量");
    } else if (cmd == "stop_measure") {
        measuring = false;
        Serial.println("[BLE] 停止测量");
    } else {
        Serial.printf("[BLE] 未知指令: %s\n", cmd.c_str());
    }
}

/**
 * @brief 将指令压入环形队列
 * 队列满时静默丢弃，避免阻塞BLE回调
 */
void SystemModule::pushCommand(const String& cmd, const String& arg) {
    int next = (cmdTail + 1) % CMD_QUEUE_SIZE;
    if (next == cmdHead) return;
    cmdQueue[cmdTail] = cmd;
    argQueue[cmdTail] = arg;
    cmdTail = next;
}

/**
 * @brief 从环形队列取出下一条待处理指令
 * @param cmd 输出参数，接收指令名
 * @param arg 输出参数，接收指令参数
 * @return true 成功取出一条指令
 */
bool SystemModule::getNextCommand(String& cmd, String& arg) {
    if (cmdHead == cmdTail) return false;
    cmd = cmdQueue[cmdHead];
    arg = argQueue[cmdHead];
    cmdHead = (cmdHead + 1) % CMD_QUEUE_SIZE;
    return true;
}

/**
 * @brief 初始化BLE服务
 *
 * 在同一个Service下创建三个特征：
 * 1. Notify特征 — 手环向手机推送JSON健康数据
 * 2. Write特征 — 接收手机下发的控制指令
 * 3. Read特征  — 手机读取设备基本信息（固件版本等）
 */
void SystemModule::initBLE() {
    BLEDevice::init(BLE_DEVICE_NAME);

    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService* pService = pServer->createService(SERVICE_UUID);

    pNotifyChar = pService->createCharacteristic(
        NOTIFY_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );

    pWriteChar = pService->createCharacteristic(
        WRITE_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    pWriteChar->setCallbacks(new WriteCallbacks());

    pReadChar = pService->createCharacteristic(
        READ_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ
    );

    String devInfo = "{\"fw\":\"" FW_VERSION "\",\"hw\":\"" HW_VERSION "\",\"serial\":\"" SERIAL_NUM "\",\"model\":\"" MODEL_NAME "\"}";
    pReadChar->setValue(devInfo.c_str());

    pService->start();
    pServer->getAdvertising()->start();

    status.bleEnabled = true;
    status.bleConnected = false;

    Serial.printf("[BLE] 设备名称: %s\n", BLE_DEVICE_NAME);
    Serial.printf("[BLE] 服务UUID: %s\n", SERVICE_UUID);
    Serial.printf("[BLE] Notify:   %s\n", NOTIFY_CHAR_UUID);
    Serial.printf("[BLE] Write:    %s\n", WRITE_CHAR_UUID);
    Serial.printf("[BLE] Read:     %s\n", READ_CHAR_UUID);
    Serial.printf("[BLE] 设备信息: %s\n", devInfo.c_str());
}

/**
 * @brief 初始化系统模块
 *
 * 初始状态：BLE未连接，测量已启用，电量100%
 * 初始化完成后设备进入广播状态，等待手机连接
 */
bool SystemModule::begin() {
    systemInstance = this;

    status.bleEnabled = false;
    status.bleConnected = false;

    cmdHead = 0;
    cmdTail = 0;

    bootTime = millis();
    timeOffset = 0;
    measuring = true;

    batteryLevel = 0;

    pageCallback = nullptr;

    initBLE();
    return true;
}

/**
 * @brief 系统状态更新（每帧调用）
 * 当前无周期性任务，保留接口供后续扩展
 */
void SystemModule::update() {
}

/**
 * @brief 获取当前系统状态
 * @return SystemStatus 包含BLE启用和连接状态
 */
/**
 * @brief 从电源管理模块同步电池电量（百分比）
 * @param level 电量百分比（0-100）
 */
void SystemModule::setBatteryLevel(int level) {
    batteryLevel = level;
}

SystemModule::SystemStatus SystemModule::getStatus() {
    return status;
}

/**
 * @brief 通过Notify特征推送健康数据到手机
 *
 * JSON格式：
 * {
 *   "ts": 1716000000,    // Unix时间戳（秒）
 *   "hr": 72,            // 心率 (bpm)
 *   "spo2": 97,          // 血氧饱和度 (%)
 *   "steps": 3500,       // 步数
 *   "motion": 1,         // 运动状态
 *   "fall": false,       // 是否跌倒
 *   "sq": 85,            // 信号质量
 *   "bat": 100           // 电量 (%)
 * }
 *
 * @param heartRate 心率
 * @param spo2 血氧
 * @param steps 步数
 * @param motionState 运动状态 0~3
 * @param fallDetected 跌倒标志
 * @param signalQuality 信号质量 0~100
 */
void SystemModule::notifyHealthData(int heartRate, int spo2, int steps, int motionState, bool fallDetected, int signalQuality) {
    if (pNotifyChar == nullptr || !status.bleConnected || !measuring) return;

    char buf[256];
    long ts = getUnixTime();

    snprintf(buf, sizeof(buf),
        "{\"ts\":%ld,\"hr\":%d,\"spo2\":%d,\"steps\":%d,\"motion\":%d,\"fall\":%s,\"sq\":%d,\"bat\":%d}",
        ts, heartRate, spo2, steps, motionState,
        fallDetected ? "true" : "false",
        signalQuality, batteryLevel);

    pNotifyChar->setValue(buf);
    pNotifyChar->notify();

    Serial.printf("[BLE] 推送: %s\n", buf);
}

/**
 * @brief 通过Notify特征推送跌倒告警到手机
 *
 * 跌倒告警与正常健康数据共用同一个Notify特征，
 * 通过 "fall": true 字段区分
 */
void SystemModule::notifyFallAlert() {
    if (pNotifyChar == nullptr || !status.bleConnected) return;

    char buf[256];
    long ts = getUnixTime();

    snprintf(buf, sizeof(buf),
        "{\"ts\":%ld,\"hr\":0,\"spo2\":0,\"steps\":0,\"motion\":0,\"fall\":true,\"sq\":0,\"bat\":%d}",
        ts, batteryLevel);

    pNotifyChar->setValue(buf);
    pNotifyChar->notify();

    Serial.printf("[BLE] 跌倒告警: %s\n", buf);
}

/**
 * @brief 获取当前的Unix时间戳
 *
 * 时间由手机通过 sync_time 指令同步，
 * 手环内部通过 timeOffset + millis()/1000 维护
 *
 * @return Unix时间戳（秒），未同步时返回0
 */
long SystemModule::getUnixTime() {
    if (timeOffset == 0) return 0;
    return timeOffset + (millis() / 1000);
}

/**
 * @brief 注册页面切换回调
 * @param cb 回调函数指针
 */
void SystemModule::setPageCallback(void (*cb)(int)) {
    pageCallback = cb;
}
