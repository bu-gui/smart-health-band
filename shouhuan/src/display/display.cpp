#include "display.h"

/**
 * @brief 初始化显示模块
 * 初始化OLED显示屏，设置文本大小和颜色
 * @return true 初始化成功，false 初始化失败
 */
bool DisplayModule::begin() {
    // 初始化SH1106 OLED显示屏，使用内部电荷泵
    if (!display.begin(0x3C)) {
        return false;
    }
    
    // 清除显示屏内容
    display.clearDisplay();
    // 设置文本大小为1
    display.setTextSize(1);
    // 设置文本颜色为白色
    display.setTextColor(SH110X_WHITE);
    
    return true;
}

/**
 * @brief 显示启动画面
 * 显示设备名称和版本信息，以及初始化提示
 */
void DisplayModule::showSplash() {
    display.clearDisplay();
    
    // 设置光标位置并显示设备名称
    display.setCursor(0, 20);
    display.setTextSize(1);
    display.println("Smart Health");
    display.println("  Band v1.0");
    
    // 显示初始化提示
    display.setCursor(0, 44);
    display.println("Initializing...");
    
    // 更新显示内容
    display.display();
}

/**
 * @brief 显示健康数据页面（简化版）
 * @param heartRate 心率值（bpm）
 * @param spo2 血氧饱和度（%）
 * @param steps 步数
 */
void DisplayModule::showHealthPage(int heartRate, int spo2, int steps) {
    showHealthPage(heartRate, spo2, steps, true, 100);
}

/**
 * @brief 显示健康数据页面（完整版）
 * @param heartRate 心率值（bpm）
 * @param spo2 血氧饱和度（%）
 * @param steps 步数
 * @param fingerOn 手指是否在传感器上
 * @param signalQuality 信号质量（0-100）
 */
void DisplayModule::showHealthPage(int heartRate, int spo2, int steps, bool fingerOn, int signalQuality) {
    display.clearDisplay();
    
    // 页面标题
    display.setCursor(0, 0);
    display.println("=== Health ===");
    
    // 手指状态提示
    if (!fingerOn) {
        display.setTextColor(SH110X_WHITE);
        display.setCursor(0, 20);
        display.println("Place on skin...");
        display.setCursor(0, 36);
        display.println("  [--]");
    } else {
        // 心率显示
        display.setCursor(0, 16);
        display.print("HR: ");
        if (heartRate > 0) {
            display.print(heartRate);
            display.println(" bpm");
        } else {
            display.println("---");
        }
        
        // 血氧饱和度显示
        display.setCursor(0, 28);
        display.print("SpO2: ");
        if (spo2 > 0) {
            display.print(spo2);
            display.println(" %");
        } else {
            display.println("---");
        }
        
        // 步数显示
        display.setCursor(0, 40);
        display.print("Steps: ");
        display.println(steps);
        
        // 信号质量显示（8格条形指示，避免与P1/3重叠）
        display.setCursor(0, 52);
        display.print("Sig:");
        int bars = (signalQuality * 8 + 99) / 100;
        if (bars > 8) bars = 8;
        for (int i = 0; i < bars; i++) display.print("#");
        for (int i = bars; i < 8; i++) display.print(".");
    }
    
    // 页码显示在右下角 (X:102, Y:52)
    display.setCursor(102, 52);
    display.print("P1/3");
    
    // 更新显示内容
    display.display();
}

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
void DisplayModule::showMotionPage(float ax, float ay, float az, float gx, float gy, float gz, int motionState) {
    display.clearDisplay();

    display.setCursor(0, 0);
    display.println("=== Motion ===");

    const char* motionLabels[] = {"Idle", "Walk ", "Fast ", "Run  "};
    if (motionState < 0 || motionState > 3) motionState = 0;
    display.setCursor(0, 10);
    display.print("State: ");
    display.println(motionLabels[motionState]);

    display.setCursor(0, 21);
    display.print("Ax:");
    display.print(ax, 2);
    display.setCursor(64, 21);
    display.print("Ay:");
    display.println(ay, 2);

    display.setCursor(0, 31);
    display.print("Az:");
    display.println(az, 2);

    display.setCursor(0, 41);
    display.print("Gx:");
    display.print(gx, 1);
    display.setCursor(64, 41);
    display.print("Gy:");
    display.println(gy, 1);

    display.setCursor(0, 52);
    display.print("Gz:");
    display.print(gz, 1);

    display.setCursor(102, 52);
    display.print("P2/3");

    display.display();
}

/**
 * @brief 显示系统状态页面
 * @param wifiConnected WiFi连接状态
 * @param bleEnabled BLE启用状态
 * @param bleConnected BLE连接状态
 * @param steps 步数
 */
void DisplayModule::showStatusPage(bool wifiConnected, bool bleEnabled, bool bleConnected, int steps) {
    display.clearDisplay();
    
    // 页面标题
    display.setCursor(0, 0);
    display.println("=== Status ===");
    
    // WiFi状态显示
    display.setCursor(0, 16);
    display.print("WiFi: ");
    display.println(wifiConnected ? "Connected" : "No");
    
    // BLE状态显示
    display.setCursor(0, 28);
    display.print("BLE: ");
    display.println(bleEnabled ? (bleConnected ? "Linked" : "Advertising") : "Off");
    
    // 步数显示
    display.setCursor(0, 40);
    display.print("Steps: ");
    display.println(steps);
    
    // 页码显示
    display.setCursor(102, 52);
    display.print("P3/3");
    
    // 更新显示内容
    display.display();
}

/**
 * @brief 显示跌倒告警页面
 * 全屏闪烁显示跌倒警报
 */
void DisplayModule::showFallAlert() {
    display.clearDisplay();

    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("!!! ALERT !!!");

    display.setTextSize(2);
    display.setCursor(0, 20);
    display.println(" FALL");
    display.println("DETECTED!");

    display.setTextSize(1);
    display.setCursor(0, 56);
    display.println("Sending help...");

    display.display();
}

/**
 * @brief 清除显示内容
 */
void DisplayModule::clear() {
    display.clearDisplay();
    display.display();
}
