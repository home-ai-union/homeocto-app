# 🚀 GitHub Actions 快速开始指南

## 一键发布流程

### 前提条件

1. **已有 Android Keystore**
   - 如果还没有，运行：`keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release`

2. **配置 GitHub Secrets**
   - 前往：GitHub → Settings → Secrets and variables → Actions

### 配置 Secrets（一次性）

需要添加以下 4 个 Secrets：

| Secret | 值 |
|--------|-----|
| `ANDROID_KEYSTORE_BASE64` | 运行 `powershell scripts\keystore_to_base64.ps1 release.jks` 生成 |
| `ANDROID_KEYSTORE_PASSWORD` | 你的 keystore 密码 |
| `ANDROID_KEY_ALIAS` | release（或你的别名） |
| `ANDROID_KEY_PASSWORD` | 你的密钥密码 |

### 发布新版本

```bash
# 1. 提交代码
git add .
git commit -m "feat: prepare release v0.2.7"

# 2. 推送代码
git push origin develop

# 3. 创建并推送 tag（触发自动构建）
git tag v0.2.7
git push origin v0.2.7
```

### 等待构建完成

- ⏱️ 构建时间：约 10-15 分钟
- 📍 查看进度：GitHub → Actions → Release (build all + publish)
- ✅ 完成后自动生成 GitHub Release

### 下载产物

访问：https://github.com/你的用户名/homeocto-app/releases

每次完整构建会生成：
- `homeocto_app-*-android-*.apk` - Android APK
- `homeocto_app-*-android-*.aab` - Android App Bundle
- `homeocto_app-*-windows-x64.zip` - Windows 压缩包
- `homeocto_app-*-windows-x64-installer.exe` - Windows 安装程序
- `homeocto_app-*-macos-universal.dmg` - macOS 安装包
- `homeocto_app-*-linux-x86_64.deb` - Linux 安装包

---

## 📝 详细说明

### 构建产物

每次 Release 会生成：

✅ Android: AAB + APK（国际版和国内版）  
✅ Windows: ZIP + NSIS 安装程序  
✅ macOS: DMG 安装包  
✅ Linux: DEB 安装包  
✅ 自动生成的变更日志  
✅ 版本信息说明

### 手动触发（可选）

如果不方便使用 tag，可以手动触发：

1. GitHub → Actions → Release (build all + publish)
2. 点击 "Run workflow"
3. 可选择输入 release_prefix（默认：homeocto_app）
4. 点击 "Run workflow"

### 本地测试构建

在推送前，可以先在本地测试：

```bash
# 获取依赖
flutter pub get

# 下载核心二进制文件
dart run tools/fetch_core_local.dart --platform android --arch arm64

# 测试 Android 构建
flutter build apk --release

# 测试 Windows 构建
flutter build windows --release

# 生成的产物位置
# Android: build/app/outputs/flutter-apk/
# Windows: build/windows/x64/runner/Release/
```

---

##  常见问题

### Q: 如何生成 Keystore？

```bash
keytool -genkey -v -keystore release.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias release
```

### Q: 如何转换为 Base64？

```powershell
powershell scripts\keystore_to_base64.ps1 release.jks
```

### Q: 构建失败了怎么办？

1. 检查 Secrets 是否正确配置
2. 查看 GitHub Actions 日志
3. 确保 `home-ai-union/homeocto` 仓库有对应的核心二进制 Release 资源
4. 检查网络连接

### Q: 如何修改 Flutter 版本？

编辑 `.github/workflows/release_full.yml`，修改 Flutter action 的配置：
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: 'stable'  # 或指定版本: flutter-version: '3.x.x'
```

---

## 📚 相关文件

- `.github/workflows/release_full.yml` - 完整多平台构建配置
- `.github/workflows/android-release.yml` - Android 单独构建
- `.github/workflows/windows-release.yml` - Windows 单独构建
- `.github/homeocto_installer.nsi` - Windows NSIS 安装脚本
- `docs/GITHUB_ACTIONS_SETUP.md` - 详细配置指南
- `tools/fetch_core_local.dart` - 核心二进制下载工具

---

## 🎉 示例：完整发布 v0.2.8

```bash
# 1. 更新 pubspec.yaml 版本号
# version: 0.2.8

# 2. 提交更改
git add pubspec.yaml
git commit -m "chore: bump version to 0.2.8"
git push origin develop

# 3. 创建 tag
git tag v0.2.8
git push origin v0.2.8

# 4. 等待 10-15 分钟

# 5. 下载产物
# https://github.com/你的用户名/homeocto-app/releases/tag/homeocto_app-v0.2.8
```

**就是这么简单！** 🎊
