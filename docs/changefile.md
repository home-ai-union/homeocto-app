# HomeOcto 变更文件清单

> 本文档记录从 picoclaw-fui 转换为 homeocto 时修改的所有文件，以便后续从 picoclaw-fui 合并代码时参考。
>
> 标记 `*` 的文件仅修改了 import 路径（`package:picoclaw_fui/` → `package:homeocto_app/`），其他代码保持不变。
> 标记 `**` 的文件修改了 import 路径 + 其他业务逻辑（二进制名、环境变量、工作目录等）。
> 标记 `-` 的文件无需修改（使用相对导入或外部导入，代码与上游一致）。

---

## Dart 文件（lib/ 目录）

### 已修改的文件

| 文件路径 | 修改类型 | 修改内容 |
|----------|----------|----------|
| `lib/main.dart` | ** | import 路径、Windows 实例 key、App title、新增智能家居导航按钮 |
| `lib/src/ui/dashboard_page.dart` | * | 仅 import 路径 |
| `lib/src/ui/config_page.dart` | * | 仅 import 路径 |
| `lib/src/ui/log_page.dart` | * | 仅 import 路径 |
| `lib/src/ui/webview_page.dart` | * | 仅 import 路径 |
| `lib/src/ui/chat_page.dart` | * | 仅 import 路径 |
| `lib/src/ui/widgets/adaptive_action_bar.dart` | * | 仅 import 路径 |
| `lib/src/ui/widgets/tv_focusable.dart` | * | 仅 import 路径 |
| `lib/src/ui/webview/webview_nav_bar.dart` | * | 仅 import 路径 |
| `lib/src/ui/webview/webview_linux.dart` | * | 仅 import 路径 |

### 未修改的文件（使用相对导入，与上游一致）

以下文件仅使用相对导入或外部包导入，未涉及 `package:picoclaw_fui/` import 路径变更，代码与 picoclaw-fui 上游一致，合并时可直接覆盖：

| 文件路径 | 说明 |
|----------|------|
| `lib/src/core/app_theme.dart` | 仅外部导入，未修改 |
| `lib/src/core/background_service.dart` | 仅外部导入，未修改 |
| `lib/src/core/picoclaw_channel.dart` | 仅外部导入，未修改（MethodChannel 名称保持 `com.sipeed.picoclaw/picoclaw`） |
| `lib/src/core/firebase_device_reporter.dart` | 相对导入，未修改 |
| `lib/src/core/umeng_device_reporter.dart` | 相对导入，未修改 |
| `lib/src/core/device_feedback_models.dart` | 无导入语句，未修改 |
| `lib/src/core/service_manager.dart` | 相对导入，未修改 |
| `lib/src/native/core_service_adapter.dart` | 仅 dart:async，未修改 |
| `lib/src/native/core_service_adapter_factory.dart` | 相对导入，未修改 |
| `lib/src/native/android_core_service_adapter.dart` | 相对导入，未修改（MethodChannel 名称保持 `com.sipeed.picoclaw/picoclaw`） |
| `lib/src/native/desktop_core_service_adapter.dart` | 相对导入，未修改 |

## 新增 Dart 文件

| 文件路径 | 说明 |
|----------|------|
| `lib/src/ui/smart_home_page.dart` | 新增：智能家居管理页面 |
| `lib/src/core/homeocto_client.dart` | 新增：WebSocket/HTTP 客户端 |
| `lib/src/core/smart_home_provider.dart` | 新增：智能家居状态管理 |

## 配置文件

| 文件路径 | 修改类型 | 修改内容 |
|----------|----------|----------|
| `pubspec.yaml` | ** | name、description、version |
| `l10n.yaml` | - | 无需修改 |
| `analysis_options.yaml` | - | 无需修改 |

## 本地化文件 (lib/l10n/)

| 文件路径 | 修改类型 | 修改内容 |
|----------|----------|----------|
| `lib/l10n/app_en.arb` | ** | appTitle 等品牌文本、新增智能家居键值 |
| `lib/l10n/app_zh.arb` | ** | appTitle 等品牌文本、新增智能家居键值 |
| `lib/l10n/app_ar.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_de.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_es.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_fr.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_hi.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_id.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_ja.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_ko.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_pt.arb` | * | 仅 appTitle 品牌文本 |
| `lib/l10n/app_ru.arb` | * | 仅 appTitle 品牌文本 |

## Android 配置文件

| 文件路径 | 修改类型 | 修改内容 |
|----------|----------|----------|
| `android/app/build.gradle.kts` | ** | namespace、applicationId、jniLibs so 名称 |
| `android/app/src/main/AndroidManifest.xml` | ** | app label、app class name |

## Android Kotlin 文件

> 所有文件从 `android/app/src/main/kotlin/com/sipeed/picoclaw/` 移至 `android/app/src/main/kotlin/com/homeai/homeocto/`

| 文件路径（新） | 修改类型 | 修改内容 |
|----------------|----------|----------|
| `android/.../com/homeai/homeocto/HomeOctoApp.kt` | ** | package、类名、通知渠道名、描述文本 |
| `android/.../com/homeai/homeocto/HomeOctoMethodChannel.kt` | ** | package、类名、配置路径、prefs 名称 |
| `android/.../com/homeai/homeocto/MainActivity.kt` | * | 仅 package、引用类名 |
| `android/.../com/homeai/homeocto/AnalyticsReporter.kt` | * | 仅 package |
| `android/.../com/homeai/homeocto/service/HomeOctoService.kt` | ** | package、类名、二进制名、环境变量、工作目录、Action 常量、通知文本 |
| `android/.../com/homeai/homeocto/receiver/BootReceiver.kt` | * | 仅 package、引用服务类名 |
| `android/.../com/homeai/homeocto/util/HealthChecker.kt` | * | 仅 package |

## 资源文件

| 文件路径 | 修改类型 | 修改内容 |
|----------|----------|----------|
| `assets/app_icon.png` | ** | 替换为 homeocto 图标 |
| `assets/icon.ico` | ** | 替换为 homeocto 图标 |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | ** | 由 flutter_launcher_icons 重新生成 |

## SO 文件（新增）

> 注意：SO 文件由用户自行编译并放入对应目录

| 文件路径 | 说明 |
|----------|------|
| `android/app/src/main/jniLibs/arm64-v8a/libhomeocto.so` | 从 homeocto/build/android/arm64/ 复制 |
| `android/app/src/main/jniLibs/arm64-v8a/libhomeocto-web.so` | 从 homeocto/build/android/arm64/ 复制 |
| `android/app/src/main/jniLibs/armeabi-v7a/libhomeocto.so` | 从 homeocto/build/android/arm/ 复制 |
| `android/app/src/main/jniLibs/armeabi-v7a/libhomeocto-web.so` | 从 homeocto/build/android/arm/ 复制 |
| `android/app/src/main/jniLibs/x86_64/libhomeocto.so` | 从 homeocto/build/android/amd64/ 复制 |
| `android/app/src/main/jniLibs/x86_64/libhomeocto-web.so` | 从 homeocto/build/android/amd64/ 复制 |

---

## 后续代码合并注意事项

### 可自动合并（`-` 标记文件）
- 所有标记为 `-` 的 Dart 文件可直接从 picoclaw-fui 覆盖，无需手动处理
- 现有页面的 UI 改进
- 新 widget 组件
- 主题更新

### 需要手动审查（`*` 标记文件）
- 合并后需重新将 `package:picoclaw_fui/` 替换为 `package:homeocto_app/`
- Kotlin 文件需更新 package 声明和 import 路径

### 需要仔细合并（`**` 标记文件）
- `main.dart`：智能家居导航入口
- `build.gradle.kts` 变更
- `AndroidManifest.xml` 变更
- Kotlin 业务逻辑文件（HomeOctoApp、HomeOctoMethodChannel、HomeOctoService）
- ARB 本地化品牌文本
- 资源文件

### 合并策略
1. 保持跟踪 picoclaw-fui 上游的分支
2. 上游更新时合并到 homeocto 分支
3. `-` 标记文件直接覆盖；`*` 标记文件覆盖后替换 import 路径；`**` 标记文件需手动合并
4. 合并后重新生成本地化代码
