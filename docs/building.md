# SmartHealthBand 构建与运行指南

> **构建/烧录/运行命令的单一权威来源**。命令基于本机实测环境。

---

## 1. 环境要求

| 工具 | 版本（本机实测） | 说明 |
|---|---|---|
| Git | 2.45.1 | ✅ |
| PlatformIO Core | 6.1.19 | ✅ 固件用 |
| Flutter SDK | 3.47.2 | ⚠️ 当前不在 PATH，需完整路径 |
| Android SDK | 36.1.0 | ✅ |

---

## 2. 固件（shouhuan）编译与烧录

```powershell
cd shouhuan
pio run                                    # 编译（产物 .pio/build/esp32-s3-devkitc-1/firmware.bin）
pio run -e esp32-s3-devkitc-1 -t upload    # 烧录到开发板
pio device monitor -b 115200               # 串口监视（115200）
```

> 固件默认串口/调试 115200 波特率，启动会打印初始化信息，每秒一条状态总览（`[+xxxxs]`），并打印 `[MAX30102]`、`[BLE]`、`[存储]` 等日志。

---

## 3. App（smart_health_app）

```powershell
cd smart_health_app
flutter pub get
flutter analyze
flutter build apk --debug      # 产物 build/app/outputs/flutter-apk/app-debug.apk
flutter run                    # 在默认设备运行
```

---

## 4. 常见坑

### 4.1 `flutter` 不在 PATH
用完整路径：`D:\huan_jing\flutter\bin\flutter.bat`，或把 `D:\huan_jing\flutter\bin` 加入用户 PATH。

### 4.2 中文用户名导致 Android 构建失败（重要）

- **现象**：`flutter build apk` 报 `source file or directory not found: C:\Users\u5F52\AppData\...`（`\u5F52` 即中文「归」）。
- **根因**：Windows 用户目录含中文，Gradle/Kotlin 编译原生依赖错误转义路径。
- **解决**：设用户变量 `PUB_CACHE=D:\huan_jing\pub_cache`、`GRADLE_USER_HOME=D:\huan_jing\gradle_home`，重新 `flutter clean + pub get + build`。

### 4.3 `android/local.properties` 的 ndk.dir
曾指向旧路径 `D:\007\...`，需改为有效 NDK（如 `C:\Users\...\Sdk\ndk\<版本>`）或删除让 AGP 自动用 SDK 的 NDK。

### 4.4 固件烧录失败
- 检查串口驱动（CH340/CP210x/原生 USB）、选对串口号与波特率（upload_speed=921600，可临时调低）；
- 烧录时按住开发板 BOOT 键。

---

## 5. 一键验证流程

```powershell
# 固件
cd shouhuan
pio run
# App
cd smart_health_app
flutter pub get
flutter analyze
flutter build apk --debug
```

两者通过后，再提交 git（提交信息用中文）。