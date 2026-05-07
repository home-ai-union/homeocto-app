# copy2pico - Homeocto-App to Picoclaw-FUI 同步工具

## 功能

将 `homeocto-app` 项目的代码同步到 `picoclaw-fui` 项目，并自动进行包名和命名空间的替换，以便进行新版本代码合并。

**核心特性：**
- 根据 `docs/changefile.md` 记录的文件列表进行精确同步
- 自动替换包名、命名空间、应用名称等
- 图片类文件单独提取到 `docs/imgs/` 目录，方便后续手动替换
- 智能跳过构建产物和缓存文件

## 替换规则

同步过程中会自动进行以下替换：

| 原始文本 | 替换为 | 说明 |
|---------|--------|------|
| `homeocto_app` | `picoclaw_flutter_ui` | Flutter 包名 |
| `com.homeai.homeocto` | `com.sipeed.picoclaw` | Android namespace/applicationId |
| `HomeOcto` | `Picoclaw` | 应用名称（大小写敏感） |
| `homeocto` | `picoclaw` | 通用名称 |

## 同步内容

### 一、需要内容替换的文件（同步到 picoclaw-fui）

根据 `docs/changefile.md` 记录，以下文件会进行内容替换后同步到 `picoclaw-fui`：

#### Dart 文件
- **标记 ** 的文件**（import + 业务逻辑）：
  - `lib/main.dart` - 应用入口
  
- **标记 * 的文件**（仅 import 路径）：
  - `lib/src/ui/dashboard_page.dart`
  - `lib/src/ui/config_page.dart`
  - `lib/src/ui/log_page.dart`
  - `lib/src/ui/webview_page.dart`
  - `lib/src/ui/chat_page.dart`
  - `lib/src/ui/widgets/adaptive_action_bar.dart`
  - `lib/src/ui/widgets/tv_focusable.dart`
  - `lib/src/ui/webview/webview_nav_bar.dart`
  - `lib/src/ui/webview/webview_linux.dart`

#### 配置文件
- `pubspec.yaml` - Flutter 项目配置
- `android/app/build.gradle.kts` - Android 构建配置
- `android/app/src/main/AndroidManifest.xml` - Android 清单文件

#### 本地化文件 (lib/l10n/)
- **标记 **：** `app_en.arb`、`app_zh.arb`
- **标记 *：** `app_ar.arb`、`app_de.arb`、`app_es.arb`、`app_fr.arb`、`app_hi.arb`、`app_id.arb`、`app_ja.arb`、`app_ko.arb`、`app_pt.arb`、`app_ru.arb`

#### Android Kotlin 文件
- **标记 **：**
  - `android/app/src/main/kotlin/com/homeai/homeocto/HomeOctoApp.kt`
  - `android/app/src/main/kotlin/com/homeai/homeocto/HomeOctoMethodChannel.kt`
  - `android/app/src/main/kotlin/com/homeai/homeocto/service/HomeOctoService.kt`
  
- **标记 *：**
  - `android/app/src/main/kotlin/com/homeai/homeocto/MainActivity.kt`
  - `android/app/src/main/kotlin/com/homeai/homeocto/AnalyticsReporter.kt`
  - `android/app/src/main/kotlin/com/homeai/homeocto/receiver/BootReceiver.kt`
  - `android/app/src/main/kotlin/com/homeai/homeocto/util/HealthChecker.kt`

#### 目录（包含新增文件）
- `lib/src/core/` - 核心模块（包含新增的 homeocto_client.dart 等）
- `lib/src/ui/` - UI 模块（包含新增的 smart_home_page.dart 等）

### 二、图片文件（单独提取到 docs/imgs/）

以下图片文件会直接拷贝到 `docs/imgs/` 目录，**不做任何内容替换**，以便后续手动替换：

- `assets/app_icon.png` - 应用图标
- `assets/icon.ico` - Windows 图标
- `android/app/src/main/res/mipmap-*/ic_launcher.png` - Android 启动图标（5 种分辨率）

## 使用方法

### 方式一：使用 PowerShell 脚本（推荐）

```powershell
# 在 homeocto-app 目录下执行
.\scripts\copy2pico\copy2pico.ps1
```

### 方式二：直接使用 Go 脚本

```powershell
# 在 homeocto-app 目录下执行
go run scripts/copy2pico/copy2pico.go G:\code\homeocto-app G:\code\picoclaw_fui
```

## 同步后步骤

### 1. 验证代码同步

进入 picoclaw-fui 目录：
```powershell
cd G:\code\picoclaw_fui
```

验证拷贝的文件和替换内容是否正确。

### 2. 更新依赖

```powershell
flutter pub get
```

### 3. 处理图片文件

图片文件已提取到 `docs/imgs/` 目录，需要手动处理：

```powershell
# 查看提取的图片文件
cd G:\code\homeocto-app\docs\imgs

# 手动替换目标项目中的图片
cd G:\code\picoclaw_fui
# 从 docs/imgs/ 目录拷贝对应的图片文件覆盖到项目中
```

### 4. 构建并测试应用

```powershell
flutter run
```

## 注意事项

### 同步行为
- 同步会**覆盖**目标目录中的同名文件和目录
- 图片文件不会同步到 picoclaw-fui，而是提取到 `docs/imgs/` 目录
- 需要同步后**手动处理**图片文件的替换

### ⚠️ 重要：新增文件的 import 引用

对于新增的文件（如 `smart_home_page.dart`、`homeocto_client.dart`、`smart_home_provider.dart`），它们的 import 语句会被内容替换规则影响：

- `homeocto_client.dart` → 类名会被替换为 `PicoClawClient`（正确）
- `smart_home_provider.dart` 中的 `import 'homeocto_client.dart'` → 会被替换为 `import 'picoclaw_client.dart'`（**错误**）

**解决方法：**
同步后需要手动修正新增文件中的 import 引用，确保它们指向实际存在的文件名（`homeocto_client.dart`）。

### 自动跳过的目录
- `node_modules`
- `.git`
- `vendor`
- `dist`
- `build`
- `.cache`
- `.dart_tool`
- `ephemeral`

### 自动跳过的文件类型
- `.lock` 文件（如 `pubspec.lock`）

## 自定义配置

如需修改同步的文件列表、目录或替换规则，编辑 `copy2pico.go` 中的 `getDefaultConfig()` 函数。

主要配置项：
- `Files` - 需要同步并进行内容替换的文件列表
- `Dirs` - 需要同步并进行内容替换的目录列表
- `ImageFiles` - 需要提取到 imgs 目录的图片文件列表
- `ContentReplacements` - 文件内容替换规则
