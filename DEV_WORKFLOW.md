# SmartHealthBand 开发与 GitHub 工作流

> 双仓库模式：**私有仓库日常开发/备份，公开仓库求职展示**。本文档是本地开发操作手册（仅存在于私有仓库，不同步公开）。

## 1. 双仓库架构

| 仓库 | 地址 | 可见性 | 用途 |
|---|---|---|---|
| `smart-health-band-dev` | https://github.com/bu-gui/smart-health-band-dev | 🔒 私有 | 日常开发 / 备份（`origin`） |
| `smart-health-band` | https://github.com/bu-gui/smart-health-band | 🌍 公开 | 求职展示（`public`） |

本地 git 双 remote：

```powershell
git remote -v
# origin → git@github.com:bu-gui/smart-health-band-dev.git   （开发）
# public → git@github.com:bu-gui/smart-health-band.git        （展示）
```

## 2. 日常开发（只推私有，随时可推）

```powershell
git add -A
git commit -m "feat(scope): 中文描述"
git push origin main
```

## 3. 里程碑同步展示（想清楚了再推）

```powershell
git push public main        # 把当前状态同步到公开仓库
git push public v1.0        # 同步 tag / 新版本
```

## 4. 红线与注意

- **不要**把半成品、踩坑记录、内部文档 push 到 `public`——公开仓库永远只放"满意状态"。
- 公开仓库历史已于 2026-08-29 重构为**单提交 v0.1**；内部文档（protocol / roadmap / building / checklist / AGENTS 等）已移出公开仓库，本地备份在 `D:\AI\backup_github\docs_removed\`。
- 需要发版：先打 tag → 推私有 → 再同步公开：
  ```powershell
  git tag v1.0
  git push origin v1.0
  git push public v1.0
  ```
- `.gitignore` 已覆盖构建产物与签名证书（`.pio/`、`build/`、`.dart_tool/`、`*.jks/*.keystore/*.p12` 等），提交前仍建议 `git status` 扫一眼。

## 5. 常用命令速查

```powershell
# 固件：编译 / 烧录 / 串口监视
cd shouhuan
pio run -e esp32-s3-devkitc-1 -t build
pio run -e esp32-s3-devkitc-1 -t upload
pio device monitor -b 115200

# App：依赖 / 分析 / 构建
cd smart_health_app
flutter pub get
flutter analyze
flutter build apk --debug
```

> ⚠️ 本机 `flutter` 不在 PATH：用完整路径，或配置 `PUB_CACHE` / `GRADLE_USER_HOME` 到英文路径（中文用户名会导致 Android 构建失败）。