# Flutter Flavor 构建指南

本项目已配置两个 Android 应用变体（Flavor），可以分别构建不同名称的应用。

## 应用变体

| Flavor | 应用名称 | 包名 | 说明 |
|--------|---------|------|------|
| `homeocto` | HomeOcto | com.homeai.homeocto | 国际版 |
| `bazhuayu` | 八爪鱼 | com.homeai.bazhuayu | 中文版 |

## 构建命令

### 开发调试

```bash
# HomeOcto 版本
flutter run --flavor homeocto

# 八爪鱼 版本
flutter run --flavor bazhuayu
```

### 构建 APK

```bash
# HomeOcto Release APK
flutter build apk --flavor homeocto --release

# 八爪鱼 Release APK
flutter build apk --flavor bazhuayu --release
```

### 构建 App Bundle（用于 Google Play）

```bash
# HomeOcto App Bundle
flutter build appbundle --flavor homeocto --release

# 八爪鱼 App Bundle
flutter build appbundle --flavor bazhuayu --release
```

## 输出位置

构建完成后，APK 文件位于：
```
build/app/outputs/flutter-apk/
├── app-homeocto-release.apk
└── app-bazhuayu-release.apk
```

## 同时安装两个版本

两个 Flavor 使用不同的包名，可以在同一台设备上同时安装：
- HomeOcto (com.homeai.homeocto)
- 八爪鱼 (com.homeai.bazhuayu)

## 注意事项

1. 两个版本共享相同的代码和资源，仅应用名称和包名不同
2. 如果需要为不同版本定制不同的图标或资源，可以在以下目录添加：
   - `android/app/src/homeocto/res/`
   - `android/app/src/bazhuayu/res/`
3. Firebase 和友盟配置通过 dart-defines 传入，两个版本可以使用不同的配置

## 示例：带自定义配置的构建

```bash
# 八爪鱼版本 + 友盟配置
flutter build apk --flavor bazhuayu --release \
  --dart-define=PICOCLAW_UMENG_APP_KEY=your_umeng_key \
  --dart-define=PICOCLAW_UMENG_CHANNEL=bazhuayu

# HomeOcto版本 + Firebase 配置
flutter build apk --flavor homeocto --release \
  --dart-define=PICOCLAW_FIREBASE_APP_ID=your_firebase_app_id \
  --dart-define=PICOCLAW_FIREBASE_API_KEY=your_api_key
```
