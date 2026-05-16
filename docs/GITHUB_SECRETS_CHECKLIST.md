# GitHub Secrets 完整配置清单

## 📋 所有必需的 Secrets

### 1️⃣ Android 签名（必需）

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `ANDROID_KEYSTORE_BASE64` | 见 [KEYSTORE_CONFIG.md](../KEYSTORE_CONFIG.md) | Keystore 文件的 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | `XxkfZymrMKC8T7Y3` | Keystore 密码 |
| `ANDROID_KEY_ALIAS` | `homeocto_release` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | `bHB4qX6FmMKs01jn` | 密钥密码 |

---

### 2️⃣ Firebase 配置（可选 - 国际版推荐）

> **何时需要**：如果你的应用面向全球用户，推荐使用 Firebase

| Secret 名称 | 说明 | 如何获取 |
|------------|------|---------|
| `FIREBASE_PROJECT_ID` | Firebase 项目 ID | Firebase Console → 项目设置 |
| `FIREBASE_APP_ID` | Firebase Android App ID | Firebase Console → 项目设置 → 你的应用 |
| `FIREBASE_API_KEY` | Firebase API Key | Firebase Console → 项目设置 → 常规 |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase 消息发送者 ID | Firebase Console → Cloud Messaging |
| `FIREBASE_STORAGE_BUCKET` | Firebase 存储桶 | 自动生成，如：`your-project.appspot.com` |

**获取步骤**：
1. 访问 https://console.firebase.google.com
2. 创建项目或选择现有项目
3. 添加 Android 应用（包名：`com.homeai.homeocto` 和 `com.homeai.bazhuayu`）
4. 在项目设置中复制上述信息

---

### 3️⃣ 友盟配置（可选 - 国内版推荐）

> **何时需要**：如果你的应用面向中国用户，推荐使用友盟

| Secret 名称 | 说明 | 如何获取 |
|------------|------|---------|
| `UMENG_APP_KEY` | 友盟应用 AppKey | 友盟+后台 → 应用列表 |
| `UMENG_CHANNEL` | 友盟渠道标识 | 自动使用 flavor 名称（homeocto/bazhuayu） |

**获取步骤**：
1. 访问 https://www.umeng.com
2. 注册并登录友盟+后台
3. 创建应用（包名：`com.homeai.homeocto` 和 `com.homeai.bazhuayu`）
4. 复制应用的 AppKey

---

### 4️⃣ 分析提供商选择（可选）

| Secret 名称 | 可选值 | 说明 |
|------------|--------|------|
| `ANALYTICS_PROVIDER` | `firebase`, `umeng`, `none` | 选择使用哪个分析服务，默认 `none` |

**建议配置**：
- HomeOcto 版本：`firebase`
- 八爪鱼版本：`umeng`
- 如果不确定：留空（使用默认值 `none`）

---

## 🔧 配置步骤

### 第 1 步：访问 GitHub Secrets 设置

1. 打开你的 GitHub 仓库
2. 点击 **Settings**（设置）
3. 左侧菜单选择 **Secrets and variables** → **Actions**
4. 点击 **New repository secret**

### 第 2 步：添加 Secrets

按照上面的表格，依次添加所有需要的 Secrets。

**最少配置（无分析服务）**：
- ✅ 添加 4 个 Android 签名 Secrets
- ❌ 不需要 Firebase 和友盟

**推荐配置（国际版）**：
- ✅ 添加 4 个 Android 签名 Secrets
- ✅ 添加 5 个 Firebase Secrets
- 设置 `ANALYTICS_PROVIDER` = `firebase`

**推荐配置（国内版）**：
- ✅ 添加 4 个 Android 签名 Secrets
- ✅ 添加 1 个友盟 Secret (`UMENG_APP_KEY`)
- 设置 `ANALYTICS_PROVIDER` = `umeng`

### 第 3 步：验证配置

配置完成后，手动触发一次构建来验证：

1. 前往 **Actions** → **Build and Release APKs**
2. 点击 **Run workflow**
3. 输入版本号（如 `v0.2.7`）
4. 点击 **Run workflow**
5. 等待构建完成（约 5-10 分钟）
6. 检查构建日志是否有错误

---

## 📊 配置方案对比

### 方案 A：无分析服务（最简单）

**适用场景**：初期测试、不需要数据统计

**需要配置的 Secrets**：4 个
```
✅ ANDROID_KEYSTORE_BASE64
✅ ANDROID_KEYSTORE_PASSWORD
✅ ANDROID_KEY_ALIAS
✅ ANDROID_KEY_PASSWORD
```

**优点**：
- 配置简单
- 不需要第三方服务
- 完全免费

**缺点**：
- 无法收集用户数据
- 无法追踪崩溃和错误
- 无法分析用户行为

---

### 方案 B：Firebase 分析（国际版）

**适用场景**：面向全球用户的应用

**需要配置的 Secrets**：9-10 个
```
✅ ANDROID_KEYSTORE_BASE64
✅ ANDROID_KEYSTORE_PASSWORD
✅ ANDROID_KEY_ALIAS
✅ ANDROID_KEY_PASSWORD
✅ FIREBASE_PROJECT_ID
✅ FIREBASE_APP_ID
✅ FIREBASE_API_KEY
✅ FIREBASE_MESSAGING_SENDER_ID
✅ FIREBASE_STORAGE_BUCKET (可选)
✅ ANALYTICS_PROVIDER = firebase
```

**优点**：
- 功能强大（分析、崩溃报告、推送通知）
- 免费额度充足
- Google 生态集成
- 全球可用

**缺点**：
- 在中国大陆不可用
- 需要 Google 账号
- 配置稍复杂

---

### 方案 C：友盟分析（国内版）

**适用场景**：面向中国用户的应用

**需要配置的 Secrets**：5-6 个
```
✅ ANDROID_KEYSTORE_BASE64
✅ ANDROID_KEYSTORE_PASSWORD
✅ ANDROID_KEY_ALIAS
✅ ANDROID_KEY_PASSWORD
✅ UMENG_APP_KEY
✅ ANALYTICS_PROVIDER = umeng
```

**优点**：
- 中国大陆可用
- 符合国内法规
- 配置简单
- 免费使用

**缺点**：
- 功能相对简单
- 需要应用审核（1-2 天）
- 国际用户可能受限

---

### 方案 D：混合配置（推荐）

**适用场景**：同时面向国内外用户

**配置方式**：
- HomeOcto 版本使用 Firebase
- 八爪鱼版本使用友盟

**需要配置的 Secrets**：10-11 个
```
✅ ANDROID_KEYSTORE_BASE64
✅ ANDROID_KEYSTORE_PASSWORD
✅ ANDROID_KEY_ALIAS
✅ ANDROID_KEY_PASSWORD
✅ FIREBASE_PROJECT_ID
✅ FIREBASE_APP_ID
✅ FIREBASE_API_KEY
✅ FIREBASE_MESSAGING_SENDER_ID
✅ UMENG_APP_KEY
✅ ANALYTICS_PROVIDER = firebase (或 umeng)
```

**构建时动态选择**：
```yaml
# 在 workflow 中根据 flavor 设置不同的 provider
--dart-define=PICOCLAW_ANALYTICS_PROVIDER=${{ matrix.flavor == 'homeocto' && 'firebase' || 'umeng' }}
```

---

##  Pre-release 和 Draft 支持

Workflow 现在支持三种发布模式：

### 1. 正式版本（通过 Tag）
```bash
git tag v0.2.7
git push origin v0.2.7
```
自动创建正式版本 Release。

### 2. Pre-release（手动触发）
1. GitHub Actions → Build and Release APKs → Run workflow
2. 输入版本号：`v0.2.7-beta.1`
3. ✅ 勾选 "Mark as pre-release"
4. 运行 workflow

### 3. Draft（手动触发）
1. GitHub Actions → Build and Release APKs → Run workflow
2. 输入版本号：`v0.2.7`
3. ✅ 勾选 "Create as draft"
4. 运行 workflow
5. 在 GitHub Releases 页面编辑并发布

详细使用指南请参考：[PRERELEASE_GUIDE.md](PRERELEASE_GUIDE.md)

---

## ⚠️ 常见问题

### Q1: 如果不配置 Firebase/友盟 会怎样？

A: 应用可以正常构建和运行，只是不会收集用户数据和分析信息。

### Q2: 可以同时配置 Firebase 和友盟吗？

A: 可以，但需要设置 `ANALYTICS_PROVIDER` 为其中一个。目前代码逻辑是选择其中一个使用。

### Q3: 如何切换分析提供商？

A: 修改 `ANALYTICS_PROVIDER` Secret 的值即可，无需重新构建 Keystore。

### Q4: Firebase API Key 安全吗？

A: 建议在 Google Cloud Console 中限制 API Key 的使用范围：
- 限制为 Android 应用
- 设置包名白名单
- 启用 API 限制

### Q5: 友盟审核需要多久？

A: 通常 1-2 个工作日。审核通过前无法使用友盟功能。

---

## 🔗 相关文档

- [KEYSTORE_CONFIG.md](../KEYSTORE_CONFIG.md) - Keystore 配置详情
- [FIREBASE_UMENG_CONFIG.md](FIREBASE_UMENG_CONFIG.md) - Firebase 和友盟详细配置指南
- [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) - GitHub Actions 完整设置指南
- [RELEASE_QUICKSTART.md](../RELEASE_QUICKSTART.md) - 快速发布指南
- [PRERELEASE_GUIDE.md](PRERELEASE_GUIDE.md) - Pre-release 和 Draft 使用指南

---

**更新时间**：2026-05-16  
**版本**：HomeOcto v0.2.7
