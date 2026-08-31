#include <Arduino.h>
#include <Wire.h>
#include <Preferences.h>
#include "config.h"
#include "mpu6050/mpu6050.h"
#include "max30102/max30102.h"
#include "display/display.h"
#include "button/button.h"
#include "system/system.h"
#include "power_manager/power_manager.h"

MPU6050Module mpu6050;
MAX30102Module max30102;
DisplayModule display;
ButtonModule button;
SystemModule sysManager;
PowerManager powerManager;
Preferences prefs;

static unsigned long lastNotifyTime = 0;

/**
 * @brief BLE指令的最终执行者
 *
 * 由主循环消费指令队列后调用，执行具体的业务逻辑：
 * - reset_steps  → 清零计步器
 * - set_page:N   → 切换OLED显示页面
 *
 * @param cmd 指令名
 * @param arg 指令参数
 */
void onBleCommand(const String& cmd, const String& arg) {
    if (cmd == "reset_steps") {
        mpu6050.resetPedometer();
    } else if (cmd == "set_page") {
        int page = arg.toInt();
        button.setPage(page);
    }
}

/**
 * @brief 系统上电初始化
 *
 * 按顺序执行以下步骤：
 *   1. 串口 115200bps
 *   2. I2C 总线
 *   3. OLED 显示屏 + 启动画面
 *   4. MPU6050 传感器
 *   5. MAX30102 传感器
 *   6. 物理按键
 *   7. BLE 蓝牙广播
 *   8. 电源管理模块
 */
void setup() {
    Serial.begin(115200);
    Wire.begin(I2C_SDA, I2C_SCL);

    Serial.printf("\n========================================\n");
    Serial.printf("  智能健康手环  v1.0\n");
    Serial.printf("  主控芯片: ESP32-S3\n");
    Serial.printf("========================================\n");

    display.begin();
    display.showSplash();
    Serial.printf("  屏幕       %20s[正常]\n", "");

    bool mpuOK = mpu6050.begin();
    Serial.printf("  运动传感器  %19s[%s]\n", "", mpuOK ? "正常" : "失败");

    // 步数持久化恢复（断电后不丢累计步数）
    prefs.begin(NVS_NAMESPACE, false);
    int savedSteps = prefs.getInt(NVS_KEY_STEPS, 0);
    prefs.end();
    if (savedSteps > 0) {
        mpu6050.setSteps(savedSteps);
        Serial.printf("[存储] 恢复步数: %d\n", savedSteps);
    }

    // 时间偏移持久化恢复（断电/重连后时间基准不丢）
    prefs.begin(NVS_NAMESPACE, false);
    long savedOffset = prefs.getLong(NVS_KEY_TS_OFFSET, 0);
    prefs.end();
    if (savedOffset != 0) {
        sysManager.setTimeOffset(savedOffset);
        Serial.printf("[存储] 恢复时间偏移: %ld\n", savedOffset);
    }

    bool maxOK = max30102.begin();
    Serial.printf("  心率血氧    %19s[%s]\n", "", maxOK ? "正常" : "失败");

    button.begin();
    Serial.printf("  按键       %20s[正常]\n", "");

    sysManager.begin();
    auto sysStatus = sysManager.getStatus();
    Serial.printf("  蓝牙       %20s[%s] %s\n", "", sysStatus.bleEnabled ? "正常" : "失败", BLE_DEVICE_NAME);

    powerManager.begin(BATTERY_ADC_PIN);
    powerManager.setScreenTimeout(SCREEN_TIMEOUT_MS);
    auto pwrStatus = powerManager.getStatus();
    Serial.printf("  电源       %20s %.2fV %d%%\n", "", pwrStatus.voltage, pwrStatus.percentage);

    Serial.printf("----------------------------------------\n");
    Serial.printf("  空闲堆内存: %u 字节\n", ESP.getFreeHeap());
    Serial.printf("  空闲 PSRAM: %u 字节\n", ESP.getFreePsram());
    Serial.printf("  芯片版本:   %d\n", ESP.getChipRevision());
    Serial.printf("========================================\n\n");

    delay(1000);

    if (!mpuOK) {
        display.clear();
        display.showHealthPage(0, 0, 0);
    }

    if (!maxOK) {
        display.clear();
        display.showHealthPage(0, 0, 0);
    }
}

/**
 * @brief 主循环（约 20 Hz）
 *
 * 每次循环执行：
 *   1. 按键扫描 + 长按清零步数
 *   2. 用户活动标记（唤醒屏幕）
 *   3. MPU6050 数据采集 + 计步/跌倒/运动识别
 *   4. 加速度传给 MAX30102 做运动伪影消除
 *   5. MAX30102 PPG 采样 + 心率血氧计算
 *   6. 电源状态更新 + 屏幕超时管理
 *   7. 刷新 OLED 显示（仅屏幕点亮时）
 *   8. 消费 BLE 指令队列（来自手机的控制指令）
 *   9. 跌倒时推送告警；皮肤贴合时每2秒推送健康数据
 *   10. 串口调试输出
 */
void loop() {
    unsigned long now = millis();

    static bool fallAlertActive = false;
    static unsigned long fallAlertStartMs = 0;

    button.update();

    if (button.isLongPress()) {
        mpu6050.resetPedometer();
        powerManager.markActivity();
        Serial.printf("[事件] 长按触发，步数已清零\n");
    }

    if (button.isPressed()) {
        powerManager.markActivity();
    }

    mpu6050.update();

    float ax, ay, az;
    mpu6050.getAccel(ax, ay, az);
    max30102.setAccelData(ax, ay, az);

    max30102.update();
    powerManager.update();
    sysManager.update();

    auto healthData = max30102.getData();
    auto motionData = mpu6050.getData();
    auto systemStatus = sysManager.getStatus();
    auto pwrStatus = powerManager.getStatus();
    sysManager.setBatteryLevel(pwrStatus.percentage);
    int currentPage = button.getPage();

    // 步数增量持久化（防 NVS 频繁写入磨损，增量>=50步或间隔>=5分钟才擦写 Flash）
    static int lastSavedSteps = -1;
    static unsigned long lastSaveTime = 0;
    if (lastSavedSteps == -1) {
        lastSavedSteps = motionData.steps; // 开机首帧同步已恢复的步数，杜绝无故擦写 Flash
        lastSaveTime = now;
    } else if (motionData.steps != lastSavedSteps &&
        (motionData.steps - lastSavedSteps >= STEPS_SAVE_THRESHOLD ||
         (lastSaveTime != 0 && now - lastSaveTime >= STEPS_SAVE_INTERVAL))) {
        prefs.begin(NVS_NAMESPACE, false);
        prefs.putInt(NVS_KEY_STEPS, motionData.steps);
        prefs.end();
        lastSavedSteps = motionData.steps;
        lastSaveTime = now;
    }

    // 时间偏移持久化（sync_time 一变化即保存）
    static long lastSavedOffset = -1;
    long curOffset = sysManager.getTimeOffset();
    if (curOffset != 0 && curOffset != lastSavedOffset) {
        prefs.begin(NVS_NAMESPACE, false);
        prefs.putLong(NVS_KEY_TS_OFFSET, curOffset);
        prefs.end();
        lastSavedOffset = curOffset;
    }

    if (pwrStatus.screenOn) {
        if (fallAlertActive) {
            display.showFallAlert();
        } else {
            switch (currentPage) {
                case PAGE_HEALTH:
                    display.showHealthPage(
                        healthData.heartRate,
                        healthData.spo2,
                        motionData.steps,
                        healthData.fingerOn,
                        healthData.signalQuality
                    );
                    break;
                case PAGE_MOTION:
                    display.showMotionPage(motionData.ax, motionData.ay, motionData.az, motionData.gx, motionData.gy, motionData.gz, motionData.motionState);
                    break;
                case PAGE_STATUS:
                    display.showStatusPage(false, systemStatus.bleEnabled, systemStatus.bleConnected, motionData.steps);
                    break;
            }
        }
    }

    String cmd, arg;
    while (sysManager.getNextCommand(cmd, arg)) {
        onBleCommand(cmd, arg);
    }

    if (motionData.fallDetected && !fallAlertActive) {
        powerManager.markActivity();
        sysManager.notifyFallAlert();
        fallAlertActive = true;
        fallAlertStartMs = now;
    }

    if (fallAlertActive && (now - fallAlertStartMs >= FALL_ALERT_DURATION_MS)) {
        fallAlertActive = false;
        display.clear();
    }

    if (!fallAlertActive && healthData.fingerOn && healthData.signalQuality >= 30) {
        if (now - lastNotifyTime >= BLE_NOTIFY_INTERVAL) {
            lastNotifyTime = now;
            sysManager.notifyHealthData(
                healthData.heartRate,
                healthData.spo2,
                motionData.steps,
                motionData.motionState,
                motionData.fallDetected,
                healthData.signalQuality
            );
        }
    }

    static bool prevFingerOn = false;
    static bool prevFallDetected = false;
    static unsigned long lastSerialTime = 0;
    static bool prevScreenOn = true;

    if (motionData.fallDetected && !prevFallDetected) {
        Serial.printf("[告警] 检测到跌倒!  ax=%.2f ay=%.2f az=%.2f\n",
            motionData.ax, motionData.ay, motionData.az);
    }
    prevFallDetected = motionData.fallDetected;

    if (healthData.fingerOn != prevFingerOn) {
        if (healthData.fingerOn) {
        Serial.printf("[信息] 皮肤已贴合  | 信号质量=%d\n", healthData.signalQuality);
        } else {
        Serial.printf("[信息] 皮肤已移开  | 上次有效值: 心率=%d 血氧=%d\n",
                healthData.heartRate, healthData.spo2);
        }
        prevFingerOn = healthData.fingerOn;
    }

    if (pwrStatus.screenOn != prevScreenOn) {
        if (!pwrStatus.screenOn) {
            display.clear();
            Serial.printf("[电源] 屏幕已熄屏\n");
        } else {
            Serial.printf("[电源] 屏幕已唤醒\n");
        }
        prevScreenOn = pwrStatus.screenOn;
    }

#if SERIAL_DEBUG_INTERVAL > 0
    if (now - lastSerialTime >= SERIAL_DEBUG_INTERVAL) {
        lastSerialTime = now;

        const char* motionNames[] = {"静止", "轻度", "中度", "剧烈"};
        int mState = motionData.motionState;
        if (mState < 0 || mState > 3) mState = 0;

        unsigned long lastBeatTime = max30102.getLastBeatTime();
        float beatAgeSec = (healthData.fingerOn && healthData.heartRate > 0 && lastBeatTime > 0 && now >= lastBeatTime)
            ? (now - lastBeatTime) / 1000.0f
            : 0.0f;
        const char* noiseNotice = (mState >= MOTION_MODERATE) ? "[运动干扰]" : "";

        char stepStatusBuf[16];
        int candidate = mpu6050.getPedometerCandidate();
        bool established = mpu6050.isPedometerEstablished();
        if (established) {
            snprintf(stepStatusBuf, sizeof(stepStatusBuf), "%05d[稳]", motionData.steps);
        } else if (candidate > 0) {
            snprintf(stepStatusBuf, sizeof(stepStatusBuf), "%05d(候%d)", motionData.steps, candidate);
        } else {
            snprintf(stepStatusBuf, sizeof(stepStatusBuf), "%05d", motionData.steps);
        }

        Serial.printf("[+%04ds] 心率:%03d 血氧:%03d 步数:%-10s 贴合:%s 信号:%02d 运动:%-6s 拍距:%.1fs%s 跌倒:%s 蓝牙:%s 页面:%d 电源:%.2fV %d%%%s\n",
            now / 1000,
            healthData.heartRate,
            healthData.spo2,
            stepStatusBuf,
            healthData.fingerOn ? "接触" : "离开",
            healthData.signalQuality,
            motionNames[mState],
            beatAgeSec,
            noiseNotice,
            motionData.fallDetected ? "是" : "否",
            systemStatus.bleConnected ? "连" : "断",
            currentPage,
            pwrStatus.voltage,
            pwrStatus.percentage,
            pwrStatus.screenOn ? "" : " 屏熄"
        );
    }
#endif

    delay(50);
}
