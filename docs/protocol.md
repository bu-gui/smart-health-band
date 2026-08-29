# SmartHealthBand BLE 协议契约

> **单一权威来源**。固件端（shouhuan/src/config.h + src/system/*）与 App 端（smart_health_app/lib/services/ble_service.dart）必须严格一致。
> **任何改动必须同步两端**，否则连接后数据无法解析或指令失效。

---

## 1. 广播信息

| 项 | 值 |
|---|---|
| 广播设备名 | `SmartHealthBand` |

---

## 2. GATT 服务与特征（UUID）

| 角色 | 名称 | UUID | 属性 | 方向 |
|---|---|---|---|---|
| 服务 | SmartHealthBand Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` | — | — |
| 数据推送 | Notify | `beb5483e-36e1-4688-b7f5-ea07361b26a8` | NOTIFY(+READ) | 手环→手机 |
| 指令 | Write | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` | WRITE | 手机→手环 |
| 设备信息 | Read | `b2c3d4e5-f6a7-8901-bcde-f12345678901` | READ | 手机→手环 |

---

## 3. 数据推送格式（Notify）

手环→手机，每 2 秒一次（JSON，UTF-8 文本）。

```json
{ "ts": 1740000000, "hr": 72, "spo2": 98, "steps": 3521, "motion": 1, "fall": false, "sq": 85, "bat": 85 }
```

| 字段 | 类型 | 含义 | 取值 |
|---|---|---|---|
| ts | long | Unix 时间戳（秒，由 sync_time 同步） | ≥0 |
| hr | int | 心率 bpm | **0=无效**，否则 40-200 |
| spo2 | int | 血氧 % | **0=无效**，否则 70-100 |
| steps | int | 当日累计步数 | ≥0 |
| motion | int | 运动状态 | 0静止 1轻度 2中度 3剧烈 |
| fall | bool | 是否跌倒 | true/false |
| sq | int | PPG 信号质量 | 0-100，0=无信号 |
| bat | int | 电池电量 | 0-100 |

> **无效值语义**：`hr==0`、`spo2==0`、`sq==0` 表示无有效信号（皮肤未贴合），不是真实 0。App 端显示 `--`，不做真实值计算。

---

## 4. 跌倒告警推送（Notify）

检测到跌倒立即推送（与正常 2s 推送共用 Notify 特征，靠 `fall=true` 区分）：

```json
{ "ts": 1740000123, "hr": 95, "spo2": 0, "steps": 0, "motion": 0, "fall": true, "sq": 0, "bat": 85 }
```

---

## 5. 指令格式（Write）

手机→手环，`cmd` 或 `cmd:arg`（冒号分隔）。

| 指令 | 格式 | 功能 | 处理 |
|---|---|---|---|
| 清零步数 | `reset_steps` | 重置计步 | 主循环消费后 `mpu6050.resetPedometer()` |
| 切换页面 | `set_page:0/1/2` | 切 OLED 页 | 主循环消费后 `button.setPage(n)` |
| 同步时间 | `sync_time:<unix>` | 同步时间 | `handleCommand` 直接更新 `timeOffset` |
| 开始测量 | `start_measure` | 恢复推送 | 置 `measuring=true` |
| 停止测量 | `stop_measure` | 暂停推送省电 | 置 `measuring=false` |

- 指令队列为环形缓冲，容量 `CMD_QUEUE_SIZE=4`，满则丢弃（不阻塞 BLE 回调）。
- 未知指令：串口打印并忽略。

---

## 6. 设备信息（Read）

```json
{ "fw": "1.0.0", "hw": "2.0", "serial": "SHB2024", "model": "SHB-Pro" }
```

---

## 7. 行为 / 时序约定

| 项 | 约定 | 出处 |
|---|---|---|
| 正常推送频率 | 每 2000ms | config.h `BLE_NOTIFY_INTERVAL` |
| 推送触发 | 皮肤贴合 且 信号质量≥30 | main.cpp |
| 更新间隔 | 主循环约 20Hz（delay(50)） | main.cpp |
| 跌倒告警 | 立即推送 + 显示告警页（非阻塞，10s 后清屏） | main.cpp |
| 时间同步 | 时间偏移存内存 + NVS 持久化；未同步时 ts 返回 0 | system.cpp / main.cpp |
| App 自动重连 | 断开后 5s→10s→20s 递增，最多 3 次 | ble_service.dart |
| App 跌倒弹窗去重 | 3 秒内一次 | health_provider.dart |

---

## 8. 两端代码对应

| 协议元素 | 固件端 | App 端 |
|---|---|---|
| 设备名 / UUID | config.h | ble_service.dart |
| 推送 JSON | system.cpp `notifyHealthData()` | health_provider.dart 解析 |
| 指令收发 | system.cpp `handleCommand()` | ble_service.dart `sendCommand()` |
| 设备信息 | system.cpp `initBLE()` | ble_service.dart `readDeviceInfo()` |

---

## 9. 一致性检查清单（改动协议时逐条核对）

- [ ] 设备名两端一致
- [ ] Service + 3 特征 UUID 两端一致
- [ ] JSON 键名（ts/hr/spo2/steps/motion/fall/sq/bat）一致
- [ ] `0=无效` 语义一致（App 不把 0 当真实值）
- [ ] 指令字符串（含冒号规则）一致
- [ ] 新增/修改字段时同步 architecture.md 数据库表、config.h、ble_service.dart