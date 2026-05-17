# GitHub Actions 构建配置修复总结

## 修复日期
2026-05-17

## 问题描述
从 picoclaw-fui 项目复制的构建配置需要适配 homeocto-app 项目，包括包名、密钥配置、核心依赖来源等。

## 修复内容

### 1. release_full.yml (完整多平台构建)
**文件路径**: `.github/workflows/release_full.yml`

**主要修改**:
- ✅ release_prefix 默认值: `picoclaw_fui` → `homeocto_app`
- ✅ Android 签名 Secrets 名称:
  - `KEYSTORE_BASE64` → `ANDROID_KEYSTORE_BASE64`
  - `KEYSTORE_PASSWORD` → `ANDROID_KEYSTORE_PASSWORD`
  - `KEY_ALIAS` → `ANDROID_KEY_ALIAS`
  - `KEY_PASSWORD` → `ANDROID_KEY_PASSWORD`
- ✅ 核心二进制下载:
  - 仓库: `sipeed/picoclaw` → `home-ai-union/homeocto`
  - 命令: `flutter pub run` → `dart run`
- ✅ 所有产物名称: `picoclaw_fui*` → `homeocto_app*`
- ✅ macOS DMG 卷标: `PicoClawFUI` → `HomeOcto`
- ✅ Windows 启动程序: `picoclaw_flutter_ui.exe` → `homeocto_app.exe`
- ✅ Windows NSIS 脚本: `.github/picoclaw_installer_fixed.nsi` → `.github/homeocto_installer.nsi`
- ✅ Linux 包名: `picoclaw-fui` → `homeocto-app`
- ✅ Linux 桌面项名称: `PicoClaw FUI` → `HomeOcto`

### 2. android-release.yml (Android 单独构建)
**文件路径**: `.github/workflows/android-release.yml`

**主要修改**:
- ✅ Android 签名 Secrets 名称 (同上)
- ✅ 核心二进制下载配置 (同上)
- ✅ 产物名称: `picoclaw_fui*` → `homeocto_app*`

### 3. windows-release.yml (Windows 单独构建)
**文件路径**: `.github/workflows/windows-release.yml`

**主要修改**:
- ✅ 产物名称: `picoclaw_fui*` → `homeocto_app*`

### 4. NSIS 安装脚本
**新建文件**: `.github/homeocto_installer.nsi`

**主要配置**:
- ✅ 应用名称: `HomeOcto`
- ✅ 安装目录: `homeocto_app`
- ✅ 启动程序: `homeocto_app.exe`
- ✅ 注册表项: `homeocto_app`
- ✅ 开始菜单文件夹: `HomeOcto`

### 5. 文档更新

#### GITHUB_ACTIONS_SETUP.md
**文件路径**: `docs/GITHUB_ACTIONS_SETUP.md`

**主要修改**:
- ✅ 概述更新为多平台构建说明
- ✅ 构建产物列表更新
- ✅ 移除 Firebase 配置说明（已在代码中处理）
- ✅ 构建时间: 5-10 分钟 → 10-15 分钟
- ✅ 添加核心二进制依赖说明
- ✅ 故障排查添加核心二进制未找到的处理

#### RELEASE_QUICKSTART.md
**文件路径**: `docs/RELEASE_QUICKSTART.md`

**主要修改**:
- ✅ 构建产物列表更新为多平台
- ✅ Workflow 名称更新
- ✅ 本地测试构建命令更新
- ✅ 相关文件列表更新
- ✅ 构建时间更新

## 需要配置的 GitHub Secrets

### 必需 Secrets
```
ANDROID_KEYSTORE_BASE64        # Android 签名密钥的 Base64 编码
ANDROID_KEYSTORE_PASSWORD      # 密钥库密码
ANDROID_KEY_ALIAS              # 密钥别名
ANDROID_KEY_PASSWORD           # 密钥密码
GITHUB_TOKEN                   # GitHub API Token (自动提供)
```

### 可选 Secrets (用于分析统计)
```
PICOCLAW_FIREBASE_APP_ID              # Firebase App ID (国际版)
PICOCLAW_FIREBASE_API_KEY             # Firebase API Key
PICOCLAW_FIREBASE_PROJECT_ID          # Firebase Project ID
PICOCLAW_FIREBASE_MESSAGING_SENDER_ID # Firebase Messaging Sender ID
PICOCLAW_UMENG_APP_KEY                # 友盟 App Key (国内版)
PICOCLAW_UMENG_CHANNEL                # 友盟渠道
```

## 核心依赖说明

构建时会自动从 `home-ai-union/homeocto` 仓库下载核心二进制文件：
- **Android**: `libhomeocto.so` (arm64)
- **Windows**: `homeocto.exe`, `homeocto-web.exe`
- **macOS**: `homeocto`, `homeocto-launcher` (universal binary)
- **Linux**: `homeocto`, `homeocto-web`

**重要**: 确保 `home-ai-union/homeocto` 仓库有对应平台的 Release 资源，否则构建会失败。

## 构建触发方式

### 1. Git Tag 触发 (推荐)
```bash
git tag v0.2.7
git push origin v0.2.7
```

### 2. 手动触发
GitHub Actions → Release (build all + publish) → Run workflow

## 构建产物命名规则

### Tag 构建 (如 v0.2.7)
- `homeocto_app-android-arm_arm64.aab`
- `homeocto_app-android-universal.apk`
- `homeocto_app-windows-x64.zip`
- `homeocto_app-windows-x64-installer.exe`
- `homeocto_app-macos-universal.dmg`
- `homeocto_app-linux-x86_64.deb`

### 非 Tag 构建
- `homeocto_app-YYMMDD-SHA-android-arm_arm64.aab`
- `homeocto_app-YYMMDD-SHA-windows-x64.zip`
- 等等...

## 测试建议

在正式推送 tag 前，建议：
1. 先推送代码到 develop 分支
2. 手动触发一次 workflow 测试
3. 确认所有平台构建成功
4. 再创建并推送 tag

## 注意事项

1. **分支保护**: main 分支受保护，请修改和推送到 develop 分支
2. **核心依赖**: 确保 `home-ai-union/homeocto` 仓库有对应的 Release
3. **签名密钥**: 使用 PKCS12 格式时密码必须一致
4. **构建时间**: 多平台并行构建约需 10-15 分钟

## 后续优化建议

1. 添加构建缓存以提高构建速度
2. 考虑添加自动化测试步骤
3. 可以添加构建通知（如 Slack、钉钉等）
4. 考虑添加自动化发布到应用商店的步骤
