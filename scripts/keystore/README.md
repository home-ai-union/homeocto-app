# Keystore Base64 转换工具

将 Android Keystore 文件转换为 Base64 编码，用于配置 GitHub Actions Secrets。

## 快速开始

### 使用方法

在项目根目录执行：

```powershell
# 基本用法（输出到 keystore_base64.txt）
.\scripts\keystore\keystore_to_base64.ps1 -KeystorePath android\app\release.jks

# 指定输出文件
.\scripts\keystore\keystore_to_base64.ps1 -KeystorePath android\app\release.jks -OutputFile my_base64.txt
```

## 前提条件

- 已安装 Go 语言环境（https://golang.org/dl/）
- 拥有 Android Keystore 文件（.jks 或 .keystore）

## 输出说明

脚本会生成一个包含 Base64 编码的文本文件，正常情况下：
- Base64 长度：3000-10000 字符
- 单行输出（无换行符）
- 可能包含 `+`、`/`、`=` 等字符

## 配置 GitHub Secrets

生成 Base64 后，需要在 GitHub 仓库配置以下 4 个 Secrets：

1. **ANDROID_KEYSTORE_BASE64** - 生成的 Base64 内容
2. **ANDROID_KEYSTORE_PASSWORD** - Keystore 密码
3. **ANDROID_KEY_ALIAS** - 密钥别名（如：homeocto_release）
4. **ANDROID_KEY_PASSWORD** - 密钥密码

### 配置步骤

1. 打开 GitHub 仓库
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 依次添加上述 4 个 Secrets

## 验证 Keystore

```bash
keytool -list \
  -keystore android/app/release.jks \
  -storepass <your_store_password> \
  -keypass <your_key_password> \
  -alias <your_alias>
```

## 安全提醒

⚠️ **重要**：
- 永远不要将 Keystore 文件提交到版本控制
- 永远不要将 Base64 内容提交到版本控制
- 妥善保管密码信息

本项目已在 `.gitignore` 中配置规则保护敏感文件。

## 故障排查

### Base64 长度异常
- **太短（< 1000 字符）**：文件可能损坏
- **太长（> 50000 字符）**：可能编码了错误的文件

### Go 未安装
从 https://golang.org/dl/ 下载并安装 Go

### 文件路径错误
确保提供的 Keystore 文件路径正确，可使用相对路径或绝对路径

## 相关文档

- [KEYSTORE_TROUBLESHOOTING.md](../../KEYSTORE_TROUBLESHOOTING.md) - 故障排查指南
- [GITHUB_SECRETS_CHECKLIST.md](../../docs/GITHUB_SECRETS_CHECKLIST.md) - Secrets 配置清单
