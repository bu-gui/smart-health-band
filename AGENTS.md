# AGENTS.md — SmartHealthBand 开发守则

> 本文档给参与本项目的开发者 / AI 助手作为进入项目的第一份上下文。请先读本守则，再动手。
> 本项目为双端异构：shouhuan/（ESP32-S3 固件，C++） + smart_health_app/（Flutter App，Dart）。

---

## 1. 项目概览

- 自制智能健康手环 + 配套 App，纯 BLE 本地通信，无云端，数据存手机 SQLite。
- 硬件：ESP32-S3（N16R8）+ MAX30102 + MPU6050 + SH1106 OLED(128x64 SPI) + 按键 + 锂电池。
- 目标：求职作品 + 学原理。判断「要不要做某事」的标准 = 是否让项目更「能跑通 + 能讲清 + 有证据」。功能不是越多越好。

详细架构、引脚、数据库见 docs/architecture.md；BLE 协议见 docs/protocol.md；现状与下一步见 docs/roadmap.md。

---

## 2. 文档是单一事实源 —— 先查文档，别重复劳动

每个事实只在一处写死，其余引用：

| 事实类别 | 权威文档 |
|---|---|
| 硬件 / 引脚 / 架构 / 数据库表结构 | docs/architecture.md |
| BLE 设备名 / UUID / JSON / 指令 | docs/protocol.md |
| 编译 / 烧录 / 运行命令 | docs/building.md |
| 当前状态 / 缺口 / 下一步 | docs/roadmap.md |
| 功能验收项 | docs/checklist.md |

改动一处事实时，必须同步检查上述相关文档，避免再出现「两端颜色不一致」「电量硬编码」这类漂移。

---

## 3. 关键红线（不得违反）

1. BLE 协议两端必须一致：任何 UUID / JSON 键名 / 指令字符串改动，要同步 shouhuan/src/config.h（或 system.cpp）与 smart_health_app/lib/services/ble_service.dart。
2. 手环电量必须取自 powerManager：system.cpp 的 batteryLevel 不得再硬编码，应使用 powerManager.getStatus().percentage（已知待办，见 roadmap S 级）。
3. 传感器无效值语义：hr==0、spo2==0、sq==0 表示无效/无信号，不是真实 0。App 端显示为 --，不做真实值计算。
4. 注释规范：中文注释 + Doxygen 风格（@brief / @param / @return）。沿用现有风格。
5. 常量集中管理：阈值、颜色、UUID、魔数不要散落硬编码在业务代码里。
6. 避免越界改动：只改与当前任务相关的模块，不要顺手重构无关代码、不要新增与任务无关的功能、不要改数据库表结构（除非任务明确要求）。
7. 大改前先给方案：说明改哪些文件、怎么改、如何验证，等确认后再动手。

---

## 4. 常用命令（详情见 docs/building.md）

```powershell
# 固件编译 / 烧录 / 串口监视
cd shouhuan
pio run -e esp32-s3-devkitc-1 -t build
pio run -e esp32-s3-devkitc-1 -t upload
pio device monitor -b 115200

# App 依赖 / 分析 / 构建
cd smart_health_app
flutter pub get
flutter analyze
flutter build apk --debug
```

> 本机 flutter 不在 PATH，需完整路径或先配 PATH（见 docs/building.md 4.1）。

---

## 5. 工作方式与沟通约定

- 用简体中文交流；回答先给结论，再讲细节。
- 遇到无法自行决定的问题（涉及改协议、硬编码、添加依赖、改动数据表等）先停下来问用户，不要自作主张。
- 文档优先：先查 docs/，能引用就不要重复写。
- 修改代码前若涉及「会影响协议/数据/架构」的变更，先说明再改。

---

## 6. 当前项目的下一步提示

详见 docs/roadmap.md。核心主线：先跑通（端到端联调）→ 再讲透（原理）→ 再留证据（实测数据+文档+录屏）。
现阶段最优先的开放问题是：从未端到端联调过，这是最大未知数。