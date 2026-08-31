# SmartHealthBand 系统架构说明

> 全文依据真实源码整理（基线 tag `v0.1`）。本文档是 **硬件 / 引脚 / 架构 / 数据库结构的单一权威来源**。

---

## 0. 免责声明

> ⚠️ **本系统为非医疗用途的学习 / 科研原型**。心率、血氧、跌倒等数据仅供演示与算法验证，**不得用于医疗诊断或急救决策**。

---

## 1. 项目概览

**SmartHealthBand** 是一个自制智能健康手环 + 配套手机 App，由两个独立工程组成：

| 子工程 | 路径 | 技术栈 | 角色 |
|---|---|---|---|
| 固件 | `shouhuan/` | C++ / PlatformIO / Arduino / ESP32-S3 | 传感器采集、算法计算、OLED 显示、BLE 广播与数据推送 |
| App | `smart_health_app/` | Dart / Flutter（Riverpod + sqflite + flutter_blue_plus） | BLE 连接、实时监测、SQLite 存储、历史分析与报表 |

**通信方式**：纯 BLE 本地通信，无云端后端。数据最终存于手机本地 SQLite。

**项目目标**：求职作品 + 学原理。核心价值 = 能演示 + 能讲清原理 + 有真实测量证据。

---

## 2. 系统架构（端到端）

```mermaid
flowchart LR
    subgraph 手环(固件 shouhuan)
        S1[MAX30102<br/>心率/血氧]
        S2[MPU6050<br/>计步/跌倒/运动]
        A1[算法层<br/>PPG滤波/心率血氧/计步/跌倒/运动识别]
        D1[OLED SH1106<br/>显示]
        P1[电源管理<br/>电池ADC/熄屏]
        B1[BLE服务<br/>Notify/Write/Read]
        S1 --> A1
        S2 --> A1
        A1 --> D1
        A1 --> P1
        A1 --> B1
        P1 --> B1
    end
    subgraph 手机(App smart_health_app)
        B2[BLE服务<br/>flutter_blue_plus]
        H1[HealthProvider<br/>实时数据状态]
        DB[(SQLite<br/>smart_health.db)]
        UI[4 Tab: 设备/监测/分析/设置]
        B2 --> H1
        H1 --> DB
        H1 --> UI
        DB --> UI
    end
    B1 <-->|BLE GATT 2s推送/指令| B2
```

**数据流（端到端）**：
1. 传感器（MAX30102、MPU6050）以固定频率采样；
2. 固件算法层算出 `心率 / 血氧 / 步数 / 运动状态 / 跌倒 / 信号质量`；
3. 固件 BLE 每 2 秒把上述数据以 JSON 推送给手机（跌倒则立即推送告警）；
4. App 接收 → 写入 SQLite → 更新 Riverpod 状态 → 刷新监测页 UI；
5. App 分析页从 SQLite 读取历史数据，按小时/天聚合后绘制趋势图、生成每日报告、列出异常事件。

---

## 3. 硬件清单与引脚表（权威）

> 引脚定义来自 `shouhuan/src/config.h`。如实物接线与此不一致，以实物为准并同步修改本表与 `config.h`。

### 3.1 器件清单

| 器件 | 型号 | 接口 | I2C 地址 | 备注 |
|---|---|---|---|---|
| 主控 | ESP32-S3（N16R8） | - | - | 16MB Flash + 8MB PSRAM（qio_opi） |
| 心率血氧 | MAX30102 | I2C | `0x57` | PART_ID `0x15`，红光660nm + 红外940nm |
| 六轴 | MPU6050 | I2C | `0x68` | WHO_AM_I `0x68`，加速度计 + 陀螺仪 |
| 显示屏 | SH1106 OLED | SPI | - | 128x64，Adafruit SH110X 库 |
| 按键 | 轻触开关 | GPIO | - | INPUT_PULLUP |
| 电池 | 锂电池 | ADC | - | 经 100K/100K 分压后采样 |

### 3.2 引脚分配

| 功能 | 引脚 | 方向 | 说明 |
|---|---|---|---|
| I2C SDA | GPIO7 | 双向 | 连接 MAX30102 + MPU6050 |
| I2C SCL | GPIO8 | 输出 | 连接 MAX30102 + MPU6050 |
| OLED CS | GPIO5 | 输出 | SPI 片选 |
| OLED DC | GPIO17 | 输出 | 数据/命令选择 |
| OLED RESET | GPIO16 | 输出 | 复位 |
| OLED SCK | GPIO18 | 输出 | SPI 时钟 |
| OLED MOSI | GPIO11 | 输出 | SPI 数据 |
| 按键 | GPIO9 | 输入 | 上拉；短按切页 / 长按1.5s清零步数 |
| 电池 ADC | GPIO4 | 输入 | 12位分辨率，`analogReadMilliVolts` |

**电池电压分压电路**：
```
VBAT — 100KΩ —┬— 100KΩ — GND
                 │
                 └— GPIO4 (ADC)
```
ADC 读到的为 `VBAT/2`，实际电压 = `ADC_mV × 2 / 1000`（V）。

---

## 4. 固件架构（shouhuan）

### 4.1 模块划分

| 模块 | 路径 | 职责 |
|---|---|---|
| 主程序 | `src/main.cpp` | 初始化 + 20Hz 主循环，组装各模块数据流 |
| 配置 | `src/config.h` | 引脚、地址、UUID、版本、间隔、LED 电流等全部常量 |
| 运动 | `src/mpu6050/*` | MPU6050 驱动 + 计步器 / 跌倒检测 / 运动状态识别 |
| 心率血氧 | `src/max30102/*` | MAX30102 驱动 + PPG 算法（心率/血氧/皮肤贴合/信号质量）+ 运动伪影滤波 |
| 显示 | `src/display/*` | SH1106 OLED 绘制（3 个页面 + 启动画面 + 跌倒告警） |
| 按键 | `src/button/*` | 防抖 + 短按切页 + 长按清零 |
| 电源 | `src/power_manager/*` | 电池电压采集/滤波/电量映射 + 屏幕超时 |
| 系统 | `src/system/*` | BLE GATT 服务、指令队列、设备信息、JSON 推送 |

### 4.2 主循环（约 20 Hz，`delay(50)`）

```
按键更新
  ├─ 长按 → 清零步数 + 唤醒屏幕
  └─ 短按 → 记录页面切换
MPU6050 采集 → 计步/跌倒/运动识别
  └─ 加速度传入 MAX30102（供运动伪影滤波）
MAX30102 批量读取 FIFO → 逐个样本处理（见 4.4）
电源管理更新（电压/电量/熄屏检测）
系统更新（BLE 状态）
刷新 OLED（仅屏幕点亮时，按当前页面）
消费 BLE 指令队列（reset_steps / set_page ...）
若跌倒 → 立即推送告警 + 显示告警页
否则若皮肤贴合且信号质量≥30 → 每 2s 推送健康数据
串口调试输出（可配置开关）
```

### 4.3 传感器配置（权威值）

**MPU6050**（`mpu6050.cpp`）：
| 配置 | 值 |
|---|---|
| 采样率 | 100 Hz（SMPLRT_DIV=9） |
| DLPF | 约 41 Hz（DLPF_CFG=0x03） |
| 陀螺仪量程 | ±250 °/s |
| 加速度计量程 | ±4 g |
| 灵敏度 | 加速度 8192 / 陀螺仪 131 |

**MAX30102**（`max30102.cpp`）：
| 配置 | 值 |
|---|---|
| 采样率 | 800 Hz（SPO2_SR=100） |
| ADC 分辨率 | 18 位（LED_PW=11，脉宽 411us） |
| 量程 | 16384 nA（ADC_RGE=11） |
| FIFO | 回绕开启（ROLLOVER_EN=1），MODE=0x03（SpO2 模式：红光+红外） |
| LED 电流 | 红光/红外均 `0x3F`（12.6 mA，见 `config.h`） |

### 4.4 PPG 处理链路（`max30102.cpp` 的 `processSingleSample`）

```
原始样本 → 异常值过滤 → NLMS运动滤波 → 预热检查(200样本)
  → AC极值追踪(指数衰减0.998) → 环形缓冲区(100样本)
→ 皮肤贴合检测 → 信号质量评估 → 心率计算 → 血氧计算(降频)
```

关键参数：
- **环形缓冲区**：`SAMPLE_COUNT = 100`（800Hz 下覆盖 125ms）。
- **运动滤波预热**：`_filterWarmupCount >= 200` 后才开始计算心率血氧。
- **无皮肤贴合超时**（`NO_FINGER_TIMEOUT`，命名沿用）= 5000ms，超时后重置心率/血氧/滤波状态。
- **血氧计算**：每 100ms 且缓冲区满一圈（`bufferIndex==0`）时执行一次。
- **心率**：`checkForBeat` 使用**原始 IR**（不做运动滤波），内部自带 DC 去除 + 低通 + 动态阈值峰值检测；`calculateHeartRate` 由心跳间隔换算（40–200 bpm），最近 10 次滑动平均。

### 4.5 算法说明（`algorithm.h` / `motion.cpp`）

**计步器**（`motion.cpp` 的 `Pedometer`）：
- 输入为**去重力后的纯运动合加速度**；
- 峰值法 + **动态阈值**（最近 5 个峰值均值 × 0.6，下限 0.15）；
- 状态机避免阈值附近重复计数；最小步间隔 250ms；3s 无步则阈值回落 0.25。

**跌倒检测**（`FallDetector`）四级状态机：
```
NORMAL → FREE_FALL(合加速度<0.4g 持续>10样本)
      → IMPACT_CHECK(>3.0g 撞击)
      → POST_FALL_WAIT(俯仰/横滚任>45°，等待500ms卧姿确认)
      → POST_FALL_ALERT(告警)
```
- 若是弯腰/快速坐下（姿态<30°或中途恢复站立）自动取消，降低误报。

**运动状态识别**（`MotionStateRecognizer`）：
- 滑动窗口（`WINDOW_SIZE`）内合加速度 **RMS**，按阈值分类：
  `<0.15=静止，<0.30=轻度，<0.80=中度，≥0.80=剧烈`。

**心率算法**（`HeartRateAlgorithm`）：rawIR → DC去除(α=0.995) → 低通(α=0.8) → 动态阈值峰值检测。

**血氧算法**（`SpO2Algorithm::calculateFromBuffer`）：
```
R = (Red_AC/Red_DC) / (IR_AC/IR_DC)   # AC用RMS，DC用均值
SpO2 = 110 - 25 × R
```
> 范围 70–100%，无效返回 0。

**皮肤贴合检测**（`FingerDetector`，命名沿用）：DC 跳变 + AC 脉动，二者任一满足且连续 3 次以上确认。

**信号质量**（`SignalQuality`）：幅度评分 × 周期性评分，0–100。

**NLMS 运动伪影消除**（`MotionArtifactFilter`）：
- 阶数 M=4/轴，总权重 12（TAPS），步长 μ、归一化 δ=1e-4；
- 以 MPU6050 去重力加速度为参考，从 PPG 中估噪并减去；PPG 先做 DC 去除以避免数量级问题。

---

## 5. App 架构（smart_health_app）

### 5.1 分层结构与职责

| 层 | 路径 | 职责 |
|---|---|---|
| 入口 | `lib/main.dart`, `lib/app.dart` | 初始化通知服务、主题、底部导航（4 Tab） |
| 模型 | `lib/models/` | `HealthRecord` / `DailySummary` / `DeviceInfo` / `UserSettings` |
| 服务 | `lib/services/` | `BleService`（扫描/连接/指令/推送解析）、`DatabaseService`（SQLite）、`NotificationService`（本地通知；当前仅初始化，未接入业务逻辑） |
| 状态 | `lib/providers/` | `BleNotifier`、`HealthNotifier`、`SettingsNotifier`（Riverpod） |
| 页面 | `lib/pages/` | `DevicePage` / `MonitorPage` / `AnalysisPage` / `SettingsPage` |
| 组件 | `lib/widgets/` | 心率/血氧/步数/运动状态卡片、连接状态栏、跌倒告警弹窗、趋势图 |
| 工具 | `lib/utils/` | `DataParser`（JSON解析）、`DateHelper`、`PermissionsHelper`、`AppColors` |

### 5.2 4 个 Tab

| Tab | 页面 | 功能 |
|---|---|---|
| 设备 | `DevicePage` | BLE 扫描、连接/断开、设备信息展示 |
| 监测 | `MonitorPage` | 实时心率/血氧/步数/运动状态/信号/电量，跌倒告警弹窗 |
| 分析 | `AnalysisPage` | 心率/血氧趋势、步数统计、今日报告、异常事件列表（24h/7d/30d 切换） |
| 设置 | `SettingsPage` | 个人信息、步数目标、告警阈值、数据管理（清除/导出CSV）、关于 |

### 5.3 主题配色（权威，来自 `lib/utils/app_colors.dart`）

| 语义 | 颜色 |
|---|---|
| 主色 primary | `#007AFF` |
| 辅助浅蓝 primaryLight | `#E8F4FD` |
| 心率 heartRate | `#FF3B30` |
| 血氧 spo2 | `#5AC8FA` |
| 步数 steps | `#FF9500` |
| 安全 safe | `#34C759` |
| 告警/异常 alert | `#FF3B30` |
| 警告 warning | `#FFCC00` |
| 文字主色 primaryText | `#1C1C1E` |
| 文字次色 secondaryText | `#8E8E93` |
| 背景 background | `#F2F2F7` |
| 卡片底色 cardBg | `#FFFFFF` |
| 分割线 divider | `#E5E5EA` |

---

## 6. 数据库设计（权威，`DatabaseService`）

数据库：`smart_health.db`，版本 1，位于手机 `getDatabasesPath()` 下。

### 6.1 健康记录表 `health_records`

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| id | INTEGER | 自增 | 主键 |
| timestamp | INTEGER | - | Unix 时间戳（秒） |
| heart_rate | INTEGER | 0 | 心率（bpm），0=无效 |
| spo2 | INTEGER | 0 | 血氧（%），0=无效 |
| steps | INTEGER | 0 | 步数 |
| motion_state | INTEGER | 0 | 0静止/1轻度/2中度/3剧烈 |
| is_fall_alert | INTEGER | 0 | 是否跌倒告警 |
| signal_quality | INTEGER | 0 | 信号质量 |
| battery | INTEGER | 0 | 电量 |

### 6.2 每日汇总表 `daily_summaries`

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| date | TEXT | - | 主键，`YYYY-MM-DD` |
| avg_heart_rate | REAL | 0 | 平均心率 |
| min_heart_rate | INTEGER | 0 | 最低心率 |
| max_heart_rate | INTEGER | 0 | 最高心率 |
| avg_spo2 | REAL | 0 | 平均血氧 |
| min_spo2 | INTEGER | 0 | 最低血氧 |
| total_steps | INTEGER | 0 | 总步数 |
| exercise_minutes | INTEGER | 0 | 运动时长（motion≥1 累计） |
| fall_count | INTEGER | 0 | 跌倒次数 |
| low_spo2_count | INTEGER | 0 | 血氧低于 95% 次数 |

### 6.3 用户设置表 `user_settings`

`key TEXT PRIMARY KEY` / `value TEXT NOT NULL`（key-value 存储）。

**常用 key**：`age` `gender` `height` `weight` `daily_step_goal` `hr_upper_limit` `hr_lower_limit` `spo2_lower_limit` `fall_alert_enabled` `fall_alert_mode` `last_device_id`。

### 6.4 数据清理策略

- `cleanOldRecords(daysToKeep=90)`：删除 90 天前的健康记录；
- `clearRecordsBeforeDays(30)`：由设置页触发，清除 30 天前的数据；
- `daily_summaries` 永久保留、`user_settings` 永久保留。

---

## 7. 目录结构总览

```
./
├── .gitignore                  # 根级忽略（排除 ndk/.pio/.dart_tool/build 等）
├── docs/                       # 本项目文档集中地
│   └── architecture.md         # 本文档
├── shouhuan/                   # 固件工程
│   ├── platformio.ini
│   └── src/
│       ├── main.cpp
│       ├── config.h
│       └── {button,display,max30102,mpu6050,power_manager,system}/
└── smart_health_app/           # Flutter 工程
    ├── pubspec.yaml
    └── lib/  (models/services/providers/pages/widgets/utils)
```

---

## 8. 关键常量与阈值（引用其他权威文档）

| 项 | 值 | 权威源 |
|---|---|---|
| 固件/硬件版本/序列号/型号 | FW 1.0.0 / HW 2.0 / SHB2024 / SHB-Pro | `config.h` |
| BLE 设备名 + UUID + JSON 字段 | 见固件 `config.h` 与 App `ble_service.dart` | 两端源码 |
| 心率正常范围 | 60–100 bpm | App 侧 `HealthState.isHeartRateNormal` |
| 血氧告警 / 严重 | <95% / <90% | App 侧 |
| 步数默认目标 | 8000（范围 1000–30000） | App 侧 `UserSettings` |
| 推送条件 | 皮肤贴合 且 信号质量≥30 | 固件 `main.cpp` |
| 推送间隔 | 2000 ms | `config.h` |
| 屏幕熄屏时间 | 10000 ms | `config.h` |
| 电池低电量阈值 | <3.3V | 固件 `power_manager.cpp` |
| I2C 硬件超时与自愈 | 50 ms 超时，10 次 NACK 自动总线复位 | 固件 `max30102.cpp` / `mpu6050.cpp` |
| NVS Flash 擦写保护 | 增量 ≥50 步 或 间隔 ≥5 分钟 (300000ms) | `config.h` / `main.cpp` |
| SQI 信号质量平滑 | 一阶 EMA 低通平滑 ($\alpha=0.85$) + 首帧直达 | 固件 `algorithm.cpp` |
| App 数据库数据治理 | 运动时长 /60 换算分钟、MIN/AVG 过滤 0 值、未同步时间戳 (ts<2020年) 防误删 | App `database_service.dart` |

---

## 9. 已知问题 / 待办（摘要）

> 以下为已知问题摘要，仅列影响架构理解的关键点。

1. ~~固件 `bat` 电量硬编码 100~~（**已修复** 2026-08-29：接入 `power_manager` 真实电量）。
2. ~~固件无持久化~~（**已修复与优化** 2026-08-31：步数 + 时间偏移用 NVS 持久化；已加入 50 步/5 分钟擦写门槛防 Flash 磨损）。
3. 固件**无低功耗/深睡**，续航未优化。
4. ~~App 的 `NotificationService` 未接入告警~~（**已修复** 2026-08-31：成功接入跌倒、心率过高/过低、血氧过低本地通知并包含去重逻辑）。
5. App **「记住设备 + 自动重连」未生效**（`device_page` 未调用 `last_device_id`）。
6. ~~App `BleService.get rssi` 为死代码~~（**已修复** 2026-08-31：接入 `readRssi()` 真实物理信号读取并清理静态死代码）。
7. **从未端到端联调**（两端各自能编译，无实测连接证据）。
