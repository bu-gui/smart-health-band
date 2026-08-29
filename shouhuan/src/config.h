#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

/**
 * @defgroup i2c I2C 总线配置
 * @{
 */
#define I2C_SDA 7     //!< I2C 数据引脚
#define I2C_SCL 8     //!< I2C 时钟引脚
/** @} */

/**
 * @defgroup oled OLED SPI 配置
 * @{
 */
#define OLED_RESET 16   //!< 复位引脚
#define OLED_DC 17      //!< 数据/命令选择引脚
#define OLED_CS 5       //!< 片选引脚
#define OLED_SCK 18     //!< SPI时钟引脚
#define OLED_MOSI 11    //!< SPI数据引脚
/** @} */

/**
 * @defgroup button 按钮配置
 * @{
 */
#define BUTTON_PIN 9    //!< 按钮输入引脚
/** @} */

/**
 * @defgroup power 电源管理配置
 * @{
 */
#define BATTERY_ADC_PIN 4          //!< 电池电压检测 ADC 引脚
#define SCREEN_TIMEOUT_MS 10000    //!< 屏幕自动熄屏时间（毫秒）
#define FALL_ALERT_DURATION_MS 10000  //!< 跌倒告警持续显示时间（毫秒）

/**
 * @defgroup nvs NVS 持久化配置
 * @{
 */
#define NVS_NAMESPACE "shb"           //!< NVS 命名空间
#define NVS_KEY_STEPS "steps"         //!< 步数存储键
#define NVS_KEY_TS_OFFSET "tsoff"     //!< 时间偏移存储键
#define STEPS_SAVE_THRESHOLD 10       //!< 步数每次写入的增量阈值
#define STEPS_SAVE_INTERVAL 30000     //!< 步数写入最大间隔（毫秒）
/** @} */
/** @} */

/**
 * @defgroup sensor 传感器 I2C 地址
 * @{
 */
#define MAX30102_ADDR ((uint8_t)0x57)   //!< MAX30102 心率血氧传感器地址
#define MPU6050_ADDR  ((uint8_t)0x68)   //!< MPU6050 六轴传感器地址
/** @} */

/**
 * @defgroup ble BLE 蓝牙配置
 * @{
 */
#define BLE_DEVICE_NAME "SmartHealthBand"                        //!< 蓝牙广播名称
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"     //!< BLE 服务 UUID
#define NOTIFY_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8" //!< Notify 特征（手环→手机）
#define WRITE_CHAR_UUID "a1b2c3d4-e5f6-7890-abcd-ef1234567890"  //!< Write 特征（手机→手环）
#define READ_CHAR_UUID "b2c3d4e5-f6a7-8901-bcde-f12345678901"   //!< Read 特征（读取设备信息）
/** @} */

/**
 * @defgroup device 设备信息
 * @{
 */
#define FW_VERSION "1.0.0"   //!< 固件版本号
#define HW_VERSION "2.0"     //!< 硬件版本号
#define SERIAL_NUM "SHB2024" //!< 设备序列号
#define MODEL_NAME "SHB-Pro" //!< 设备型号
/** @} */

/**
 * @defgroup timing 数据更新间隔
 * @{
 */
#define BLE_NOTIFY_INTERVAL 2000   //!< BLE 推送间隔（毫秒）
/** @} */

/**
 * @defgroup page 显示页面定义
 * @{
 */
#define PAGE_HEALTH 0   //!< 第0页：健康数据
#define PAGE_MOTION 1   //!< 第1页：运动数据
#define PAGE_STATUS 2   //!< 第2页：系统状态
#define MAX_PAGES 3     //!< 总页面数
/** @} */

/**
 * @defgroup debug 串口调试输出配置
 * @{
 */
#define SERIAL_DEBUG_INTERVAL 2000  //!< 定期状态输出间隔（毫秒），设为0可关闭
/** @} */

/**
 * @defgroup led MAX30102 LED 驱动电流配置
 *
 * 电流值单位为 0.2mA/步：
 * - 0x24 = 7.2mA
 * - 0x32 = 10mA
 * - 0x3F = 12.6mA
 * - 0x7F = 25.4mA
 *
 * 注意事项：
 * - 电流过高 → 信号饱和 → 心率无法检测
 * - 电流过低 → 信号太弱 → 信噪比不足
 * - 推荐范围：0x1F ~ 0x3F (6.2~12.6mA)
 * @{
 */
#define MAX30102_LED1_CURRENT 0x3F  //!< 红光 LED 电流
#define MAX30102_LED2_CURRENT 0x3F  //!< 红外 LED 电流
/** @} */

#endif
