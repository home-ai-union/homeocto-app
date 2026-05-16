# Firebase & 友盟配置指南

## 概述

项目支持两种设备反馈（Device Feedback）和遥测（Telemetry）服务：
- **Firebase** - 国际版推荐（Google 生态）
- **友盟 (UMeng)** - 国内版推荐（适合中国市场）

你可以根据目标市场选择不同的配置，或者同时配置两者。

---

## 🔥 Firebase 配置

### 需要的参数

| 参数名 | 说明 | 必需 | 获取位置 |
|--------|------|------|---------|
| `PICOCLAW_FIREBASE_PROJECT_ID` | Firebase 项目 ID | ✅ | Firebase Console |
| `PICOCLAW_FIREBASE_APP_ID` | Firebase Android App ID | ✅ | Firebase Console → 项目设置 |
| `PICOCLAW_FIREBASE_API_KEY` | Firebase API Key | ✅ | Firebase Console → 项目设置 |
| `PICOCLAW_FIREBASE_MESSAGING_SENDER_ID` | Firebase 消息发送者 ID | ✅ | Firebase Console → Cloud Messaging |
| `PICOCLAW_FIREBASE_STORAGE_BUCKET` | Firebase 存储桶 |  | 自动生成（可选） |

### 如何获取 Firebase 配置

1. **访问 Firebase Console**
   - 打开 https://console.firebase.google.com
   - 创建新项目或选择现有项目

2. **添加 Android 应用**
   - 点击"添加应用" → 选择 Android
   - 包名：`com.homeai.homeocto` (HomeOcto 版本)
   - 或 `com.homeai.bazhuayu` (八爪鱼版本)
   - 下载 `google-services.json`

3. **获取配置信息**
   - 进入项目设置（齿轮图标）
   - 在"您的应用"部分找到刚添加的 Android 应用
   - 复制以下信息：
     - 项目 ID
     - 应用 ID
     - API 密钥
     - 消息发送者 ID
     - 存储桶

### Firebase 示例配置

```yaml
# GitHub Secrets
FIREBASE_PROJECT_ID: "homeocto-app-12345"
FIREBASE_APP_ID: "1:123456789:android:abcdef123456"
FIREBASE_API_KEY: "AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg"
FIREBASE_MESSAGING_SENDER_ID: "123456789"
FIREBASE_STORAGE_BUCKET: "homeocto-app-12345.appspot.com"
```

---

## 📊 友盟 (UMeng) 配置

### 需要的参数

| 参数名 | 说明 | 必需 | 获取位置 |
|--------|------|------|---------|
| `PICOCLAW_UMENG_APP_KEY` | 友盟应用 AppKey | ✅ | 友盟+后台 |
| `PICOCLAW_UMENG_CHANNEL` | 友盟渠道标识 |  | 自定义（如：official, bazhuayu） |

### 如何获取友盟配置

1. **注册友盟+账号**
   - 访问 https://www.umeng.com
   - 注册并登录

2. **创建应用**
   - 进入"产品" → "U-App 移动统计"
   - 点击"添加新应用"
   - 应用名称：HomeOcto 或 八爪鱼
   - 平台：Android
   - 包名：`com.homeai.homeocto` 或 `com.homeai.bazhuayu`

3. **获取 AppKey**
   - 应用创建后，在应用列表中找到
   - 复制"AppKey"（通常是 24 位字符串）

### 友盟示例配置

```yaml
# GitHub Secrets
UMENG_APP_KEY: "65abcdef1234567890abcdef"
UMENG_CHANNEL: "official"  # HomeOcto 版本
# 或
UMENG_CHANNEL: "bazhuayu"  # 八爪鱼版本
```

---

## 🔧 在 GitHub Actions 中使用

### 已自动配置

`.github/workflows/build-release.yml` 已更新，支持以下 Secrets：

#### 必需的 Secrets（签名）

| Secret 名称 | 说明 |
|------------|------|
| `ANDROID_KEYSTORE_BASE64` | Keystore 的 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore 密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

#### Firebase Secrets（可选）

| Secret 名称 | 说明 | 是否必需 |
|------------|------|----------|
| `FIREBASE_PROJECT_ID` | Firebase 项目 ID | ✅ 如果使用 Firebase |
| `FIREBASE_APP_ID` | Firebase Android App ID | ✅ 如果使用 Firebase |
| `FIREBASE_API_KEY` | Firebase API Key | ✅ 如果使用 Firebase |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase 消息发送者 ID | ✅ 如果使用 Firebase |
| `FIREBASE_STORAGE_BUCKET` | Firebase 存储桶 |  可选 |

#### 友盟 Secrets（可选）

| Secret 名称 | 说明 | 是否必需 |
|------------|------|----------|
| `UMENG_APP_KEY` | 友盟应用 AppKey | ✅ 如果使用友盟 |
| `UMENG_CHANNEL` | 友盟渠道标识 |  自动使用 flavor 名称 |

#### 分析提供商选择

| Secret 名称 | 可选值 | 说明 |
|------------|--------|------|
| `ANALYTICS_PROVIDER` | `firebase`, `umeng`, `none` | 选择使用哪个分析服务，默认 `none` |

### Workflow 配置示例

构建命令已自动包含所有 dart-define 参数：

```yaml
- name: Build APK - ${{ matrix.flavor }}
  env:
    # ... Keystore 配置 ...
    # Firebase Configuration
    FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
    FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}
    FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}
    FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}
    FIREBASE_STORAGE_BUCKET: ${{ secrets.FIREBASE_STORAGE_BUCKET }}
    # UMeng Configuration
    UMENG_APP_KEY: ${{ secrets.UMENG_APP_KEY }}
    UMENG_CHANNEL: ${{ matrix.flavor }}
    ANALYTICS_PROVIDER: ${{ secrets.ANALYTICS_PROVIDER || 'none' }}
  run: |
    flutter build apk \
      --flavor ${{ matrix.flavor }} \
      --release \
      --dart-define=PICOCLAW_ANALYTICS_PROVIDER=$ANALYTICS_PROVIDER \
      --dart-define=PICOCLAW_FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID \
      --dart-define=PICOCLAW_FIREBASE_APP_ID=$FIREBASE_APP_ID \
      --dart-define=PICOCLAW_FIREBASE_API_KEY=$FIREBASE_API_KEY \
      --dart-define=PICOCLAW_FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID \
      --dart-define=PICOCLAW_FIREBASE_STORAGE_BUCKET=$FIREBASE_STORAGE_BUCKET \
      --dart-define=PICOCLAW_UMENG_APP_KEY=$UMENG_APP_KEY \
      --dart-define=PICOCLAW_UMENG_CHANNEL=$UMENG_CHANNEL \
      --split-per-abi
```

### 添加 GitHub Secrets

前往 GitHub → Settings → Secrets and variables → Actions，添加以下 Secrets：

#### Firebase Secrets（如果使用 Firebase）

| Secret 名称 | 值示例 |
|------------|--------|
| `FIREBASE_PROJECT_ID` | `homeocto-app-12345` |
| `FIREBASE_APP_ID` | `1:123456789:android:abcdef123456` |
| `FIREBASE_API_KEY` | `AIzaSyABC...` |
| `FIREBASE_MESSAGING_SENDER_ID` | `123456789` |
| `FIREBASE_STORAGE_BUCKET` | `homeocto-app-12345.appspot.com` |

#### 友盟 Secrets（如果使用友盟）

| Secret 名称 | 值示例 |
|------------|--------|
| `UMENG_APP_KEY` | `65abcdef1234567890abcdef` |
| `UMENG_CHANNEL` | `official` 或 `bazhuayu` |

---

##  不同场景的配置建议

### 场景 1：仅使用 Firebase（国际版）

```yaml
# 适用于面向全球用户的应用
PICOCLAW_ANALYTICS_PROVIDER: firebase
PICOCLAW_FIREBASE_PROJECT_ID: your_project_id
PICOCLAW_FIREBASE_APP_ID: your_app_id
PICOCLAW_FIREBASE_API_KEY: your_api_key
PICOCLAW_FIREBASE_MESSAGING_SENDER_ID: your_sender_id
# 友盟参数留空或不设置
```

### 场景 2：仅使用友盟（国内版）

```yaml
# 适用于面向中国用户的应用
PICOCLAW_ANALYTICS_PROVIDER: umeng
PICOCLAW_UMENG_APP_KEY: your_umeng_app_key
PICOCLAW_UMENG_CHANNEL: official
# Firebase 参数留空或不设置
```

### 场景 3：混合使用（推荐）

```yaml
# HomeOcto 版本使用 Firebase
--flavor homeocto
--dart-define=PICOCLAW_ANALYTICS_PROVIDER=firebase
--dart-define=PICOCLAW_FIREBASE_*=your_firebase_config
--dart-define=PICOCLAW_UMENG_APP_KEY=your_umeng_key

# 八爪鱼 版本使用友盟
--flavor bazhuayu
--dart-define=PICOCLAW_ANALYTICS_PROVIDER=umeng
--dart-define=PICOCLAW_UMENG_APP_KEY=your_umeng_key
--dart-define=PICOCLAW_UMENG_CHANNEL=bazhuayu
```

---

## 📝 验证配置

### 本地测试

```bash
# 测试 Firebase 配置
flutter build apk --flavor homeocto --release \
  --dart-define=PICOCLAW_ANALYTICS_PROVIDER=firebase \
  --dart-define=PICOCLAW_FIREBASE_PROJECT_ID=your_project_id \
  --dart-define=PICOCLAW_FIREBASE_APP_ID=your_app_id \
  --dart-define=PICOCLAW_FIREBASE_API_KEY=your_api_key \
  --dart-define=PICOCLAW_FIREBASE_MESSAGING_SENDER_ID=your_sender_id

# 测试友盟配置
flutter build apk --flavor bazhuayu --release \
  --dart-define=PICOCLAW_ANALYTICS_PROVIDER=umeng \
  --dart-define=PICOCLAW_UMENG_APP_KEY=your_umeng_key \
  --dart-define=PICOCLAW_UMENG_CHANNEL=bazhuayu
```

### 检查配置是否生效

在应用中查看日志，应该看到：
- Firebase：`Firebase initialized successfully`
- 友盟：`Umeng initialized with app key: xxx`

---

## ⚠️ 注意事项

### Firebase

1. **安全性**
   - API Key 应该限制 Android 应用使用
   - 在 Google Cloud Console 设置应用包名限制
   - 不要将 API Key 提交到代码仓库

2. **多包名支持**
   - Firebase 支持在同一项目中添加多个 Android 应用
   - 为 `com.homeai.homeocto` 和 `com.homeai.bazhuayu` 分别添加

3. **费用**
   - Firebase 免费额度通常足够使用
   - 超出后按量计费

### 友盟

1. **审核时间**
   - 新应用需要审核（通常 1-2 个工作日）
   - 审核通过后才可正常使用

2. **隐私合规**
   - 需要在应用中添加隐私政策
   - 需要在用户同意后初始化 SDK

3. **数据延迟**
   - 统计数据通常有 2-4 小时延迟
   - 实时数据需要开通高级功能

---

## 🔗 相关链接

- [Firebase Console](https://console.firebase.google.com)
- [友盟+官网](https://www.umeng.com)
- [Firebase Android 设置指南](https://firebase.google.com/docs/android/setup)
- [友盟+接入文档](https://developer.umeng.com/docs/119267/detail/118584)

---

## 📋 配置检查清单

在发布前确认：

### Firebase
- [ ] 已创建 Firebase 项目
- [ ] 已添加 Android 应用（两个包名）
- [ ] 已下载并配置 google-services.json
- [ ] 已在 GitHub Secrets 中配置所有参数
- [ ] API Key 已设置包名限制

### 友盟
- [ ] 已注册友盟+账号
- [ ] 已创建应用（两个包名）
- [ ] 应用已通过审核
- [ ] 已在 GitHub Secrets 中配置 AppKey
- [ ] 已设置正确的渠道标识

### 通用
- [ ] 已选择分析提供商（firebase/umeng）
- [ ] 已测试本地构建
- [ ] 已验证配置是否生效
- [ ] 已准备好隐私政策（如需要）

---

**更新时间：** 2026-05-16  
**版本：** HomeOcto v0.2.7
