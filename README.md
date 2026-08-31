# SmartHealthBand — 智能健康手环

![ESP32-S3](https://img.shields.io/badge/ESP32--S3-N16R8-9C27B0)
![PlatformIO](https://img.shields.io/badge/PlatformIO-IDE-orange)
![Flutter](https://img.shields.io/badge/Flutter-App-02569B)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2)
![C++](https://img.shields.io/badge/C%2B%2B-Firmware-00599C)
![BLE](https://img.shields.io/badge/BLE-Local-8A2BE2)
![SQLite](https://img.shields.io/badge/SQLite-Local-003B57)
![License](https://img.shields.io/badge/License-MIT-green)

> 自制智能健康手环（ESP32-S3）+ 配套手机 App（Flutter）。纯 BLE 本地通信，无云端，数据存手机 SQLite。
> ⚠️ 本系统为**非医疗用途**的学习/科研原型，数据仅供演示与算法验证，不用于医疗诊断。

---

## 功能特性

- **实时心率 / 血氧监测**：MAX30102 采集 PPG 信号，经滤波与算法处理
- **计步 / 运动 / 跌倒检测**：MPU6050 + 三阶段状态机
- **OLED 实时显示 + 按键交互**：SH1106（128x64 SPI）
- **数据不丢失**：电量管理，断电 / 重启后步数、时间基准持久化（NVS）
- **隐私不出手机**：纯 BLE 本地通信，无云端；手机端 SQLite 持久化 + 趋势分析
- **本地告警通知**：跌倒 / 心率越限 / 血氧过低时手机端弹通知（带防轰炸去重）

## 系统架构

**数据流（端到端）**：

```
传感器(MAX30102 / MPU6050)
   → ESP32-S3 主控（滤波 · 算法 · 状态机）
   → BLE 本地通信（JSON 协议）
   → App BLE Service（协议解析）
   → Riverpod 状态管理
   → 监测 / 分析 / 设置界面  +  SQLite 本地持久化
```

- **手环端**：传感器采集 → 主控处理（滤波、算法、状态机）→ 通过 BLE 按 JSON 协议上报；
- **App 端**：BLE 解析 → 状态管理刷新界面 → 数据写入手机本地 SQLite，全程无云端。

完整架构、数据流、数据库表结构见 **[docs/architecture.md](docs/architecture.md)**。

## 硬件构成

| 模块 | 型号 | 作用 |
|---|---|---|
| 主控 | ESP32-S3（N16R8） | 数据采集、算法、BLE 通信 |
| 心率 / 血氧 | MAX30102 | PPG 信号采集与算法 |
| 运动 | MPU6050 | 计步、运动识别、跌倒检测 |
| 显示 | SH1106 OLED 128x64（SPI） | 状态与数据展示 |
| 交互 | 按键 | 翻页 / 操作 |
| 供电 | 锂电池 | 便携供电 |

完整引脚表、传感器配置、算法说明见 **[docs/architecture.md](docs/architecture.md)**。

## 项目结构

```
./
├── docs/                    # 本项目文档集中地
│   ├── architecture.md      # 架构 / 引脚 / 数据流 / 数据库
│   ├── protocol.md          # BLE 协议契约（UUID / JSON / 指令）
│   └── building.md          # 编译 / 烧录 / 运行指南
├── shouhuan/                # 固件工程（ESP32-S3 / PlatformIO）
└── smart_health_app/        # 手机 App 工程（Flutter）
```

## 快速开始

### 固件（shouhuan）

```powershell
cd shouhuan
pio run -e esp32-s3-devkitc-1 -t upload      # 编译并烧录到开发板
pio device monitor -b 115200                 # 串口监视（115200）
```

### App（smart_health_app）

```powershell
cd smart_health_app
flutter pub get
flutter analyze
flutter build apk --debug                    # 产物：build/app/outputs/flutter-apk/app-debug.apk
flutter run                                  # 在默认设备运行
```

> ⚠️ 本机 `flutter` 不在 PATH，需完整路径或先配置 PATH。

## 版本历史

| Tag | 内容 |
|---|---|
| `v0.1` | 初始版本：固件 + App 代码基线（BLE 本地通信 + SQLite 存储） |
| `v0.2` | 文档体系落位：架构 / 协议 / 构建 / 路线图 / 清单 |
| `v0.3` | 根 README 入口说明 |
| 后续 | 固件算法优化（心率 / 计步 / 跌倒 / SQI 平滑）、App 数据治理修复、自动化单元测试 |
