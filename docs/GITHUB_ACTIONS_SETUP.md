# GitHub Actions 配置指南

## 概述

本项目已配置 GitHub Actions workflow 来自动构建两个版本的 APK 并生成 GitHub Release。

## Workflow 触发方式

### 1. 通过 Git Tag 触发（推荐）

```bash
# 创建并推送 tag
git tag v0.2.7
git push origin v0.2.7
```

### 2. 手动触发

在 GitHub Actions 页面手动触发 workflow，需要输入版本号（如 `v0.2.7`）。

## 构建产物

每次构建会生成两个 APK：
- **HomeOcto-v0.2.7.apk** - 国际版
- **八爪鱼-v0.2.7.apk** - 中文版

## 配置步骤

### 第一步：准备 Android 签名密钥

1. 如果你还没有 keystore，创建一个新的：

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
```

2. 将 keystore 文件转换为 Base64：

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks")) | Out-File -Encoding ASCII keystore_base64.txt
```

**Linux/Mac:**
```bash
base64 release.jks > keystore_base64.txt
```

### 第二步：配置 GitHub Secrets

前往 GitHub 仓库 → Settings → Secrets and variables → Actions → New repository secret

添加以下 Secrets：

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `ANDROID_KEYSTORE_BASE64` | Keystore 文件的 Base64 编码 | 从 keystore_base64.txt 复制 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore 密码 | 你的 keystore 密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 | release |
| `ANDROID_KEY_PASSWORD` | 密钥密码 | 你的密钥密码 |

**可选的 Firebase 配置：**

| Secret 名称 | 说明 |
|------------|------|
| `FIREBASE_APP_ID` | Firebase App ID |
| `FIREBASE_API_KEY` | Firebase API Key |
| `FIREBASE_PROJECT_ID` | Firebase Project ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase Messaging Sender ID |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage Bucket |

### 第三步：构建 APK

#### 方式 1：使用 Git Tag（推荐）

```bash
# 确保代码已提交
git add .
git commit -m "Prepare for release v0.2.7"

# 创建 tag
git tag v0.2.7

# 推送 tag（触发自动构建）
git push origin v0.2.7
```

#### 方式 2：手动触发

1. 前往 GitHub Actions → Build and Release APKs
2. 点击 "Run workflow"
3. 输入版本号（如 `v0.2.7`）
4. 点击 "Run workflow"

## Release 说明

构建完成后，会自动创建 GitHub Release，包含：

✅ 两个版本的 APK 文件  
✅ SHA256 校验和  
✅ 自动生成的变更日志（从 Git commits）  
✅ 详细的版本信息

## 注意事项

1. **安全性**：
   - Keystore 密码等敏感信息已配置为 Secrets，不会泄露
   - 构建后 Keystore 文件会自动清理

2. **并行构建**：
   - 两个版本的 APK 会并行构建，提高效率
   - 总构建时间约 5-10 分钟

3. **APK 分包**：
   - 使用 `--split-per-abi` 参数，生成针对 CPU 架构优化的 APK
   - 会生成：arm64-v8a、armeabi-v7a、x86_64

4. **标签规范**：
   - Tag 必须以 `v` 开头（如 `v0.2.7`）
   - 建议遵循语义化版本规范

## 故障排查

### 构建失败：Keystore 未找到

检查是否已正确配置以下 Secrets：
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### 构建失败：Flutter 版本不匹配

检查 `build-release.yml` 中的 `FLUTTER_VERSION` 是否与项目匹配。

### Release 未生成

确保：
1. 使用了 tag 触发（`v*`）或手动输入了版本号
2. 构建步骤全部成功完成
3. 检查 Actions 日志中的错误信息

## 示例：完整发布流程

```bash
# 1. 更新版本号
# 编辑 pubspec.yaml，设置 version: 0.2.7

# 2. 提交更改
git add pubspec.yaml
git commit -m "Bump version to 0.2.7"

# 3. 创建并推送 tag
git tag v0.2.7
git push origin main
git push origin v0.2.7

# 4. 等待 GitHub Actions 完成构建（约 5-10 分钟）

# 5. 在 GitHub Releases 页面下载 APK
# 访问: https://github.com/<your-org>/homeocto-app/releases
```

## 自定义配置

如需修改构建参数，编辑 `.github/workflows/build-release.yml`：

- 修改 Flutter 版本：`FLUTTER_VERSION`
- 添加 dart-define 参数：在 Build APK 步骤中添加
- 调整 Release 内容：修改 Prepare release files 步骤
