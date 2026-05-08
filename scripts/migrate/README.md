# Picoclaw-FUI 迁移脚本使用说明

## 功能
该脚本用于将 picoclaw-fui 项目的代码迁移到 homeocto-app 项目，并自动替换关键词。

## 特点
- ✅ 使用 Go 语言处理文件，避免 PowerShell 替换导致的中文乱码问题
- ✅ 保持 UTF-8 编码，正确处理中文字符
- ✅ 智能跳过二进制文件和不需要处理的目录
- ✅ 按优先级替换关键词（长字符串优先）
- ✅ 先删除后拷贝，确保目标目录干净

## 替换规则
| 原字符串 | 新字符串 | 说明 |
|---------|---------|------|
| PicoClaw UI | HomeOcto UI | 应用名称（首字母大写） |
| Picoclaw UI | HomeOcto UI | 应用名称（首字母大写） |
| picoclaw UI | homeocto UI | 应用名称（小写） |
| picoclaw_flutter_ui | homeocto_app | Flutter 包名 |
| com.sipeed.picoclaw | com.homeai.homeocto | Android 包名/iOS Bundle ID |

### 不替换的内容（外部依赖包）
- `node_modules` - 外部依赖包，不会被替换
- `.git` - Git 目录，不会被替换

## 迁移内容

### 通用目录（完全替换）
1. `lib` → `lib` - Dart/Flutter 核心代码
2. `test` → `test` - 测试代码
3. `tools` → `tools` - 工具脚本

### Android 平台
**需要拷贝的目录：**
- `app/src/main/kotlin` - Kotlin 源代码（自动处理包名重命名：com.sipeed.picoclaw → com.homeai.homeocto）
- `app/src/main/res` - 资源文件（图标、布局等）

**需要拷贝的文件：**
- `app/src/main/AndroidManifest.xml` - Android 清单文件
- `app/build.gradle.kts` - 应用构建配置
- `app/proguard-rules.pro` - 代码混淆规则
- `build.gradle.kts` - 项目构建配置
- `settings.gradle.kts` - Gradle 设置
- `gradle.properties` - Gradle 属性
- `.gitignore` - Git 忽略规则

**自动生成的文件（不拷贝）：**
- `local.properties` - 本地 SDK 路径（由 Android Studio 生成）
- `gradle/wrapper/` - Gradle 包装器（由 Gradle 生成）
- `build/` - 构建产物
- `.gradle/` - Gradle 缓存

### iOS 平台
**需要拷贝的目录：**
- `Runner/` - iOS 应用代码和资源
- `Runner.xcodeproj/` - Xcode 项目配置
- `RunnerTests/` - 测试代码

**需要拷贝的文件：**
- `Podfile` - CocoaPods 依赖配置
- `.gitignore` - Git 忽略规则

**自动生成的文件（不拷贝）：**
- `Flutter/Generated.xcconfig` - Flutter 生成的配置
- `Flutter/ephemeral/` - Flutter 临时文件
- `Flutter/flutter_export_environment.sh` - 导出脚本
- `Pods/` - CocoaPods 依赖（由 pod install 生成）

### macOS 平台
**需要拷贝的目录：**
- `Runner/` - macOS 应用代码和资源
- `Runner.xcodeproj/` - Xcode 项目配置
- `Runner.xcworkspace/` - Xcode 工作区
- `RunnerTests/` - 测试代码

**需要拷贝的文件：**
- `Podfile` - CocoaPods 依赖配置
- `.gitignore` - Git 忽略规则

**自动生成的文件（不拷贝）：**
- `Flutter/GeneratedPluginRegistrant.swift` - 插件注册
- `Flutter/ephemeral/` - Flutter 临时文件
- `Flutter/Flutter-*.xcconfig` - Flutter 生成的配置

### Linux 平台
**需要拷贝的目录：**
- `runner/` - Linux 应用代码

**需要拷贝的文件：**
- `CMakeLists.txt` - CMake 构建配置
- `.gitignore` - Git 忽略规则

**自动生成的文件（不拷贝）：**
- `flutter/` - Flutter 引擎和插件配置
- `flutter/ephemeral/` - Flutter 临时文件
- `flutter/ephemeral/.plugin_symlinks/` - 插件符号链接
- `build/` - 构建产物

### Web 平台（全部拷贝）
**需要拷贝的目录：**
- `icons/` - Web 图标文件

**需要拷贝的文件：**
- `favicon.png` - 网站图标
- `index.html` - HTML 入口文件
- `manifest.json` - Web 清单文件

### Windows 平台
**需要拷贝的目录：**
- `runner/` - Windows 应用代码

**需要拷贝的文件：**
- `CMakeLists.txt` - CMake 构建配置
- `.gitignore` - Git 忽略规则

**自动生成的文件（不拷贝）：**
- `flutter/` - Flutter 引擎和插件配置
- `flutter/ephemeral/` - Flutter 临时文件
- `build/` - 构建产物

### 配置文件（完全替换）
1. `analysis_options.yaml` → `analysis_options.yaml`
2. `devtools_options.yaml` → `devtools_options.yaml`
3. `l10n.yaml` → `l10n.yaml`
4. `pubspec.yaml` → `pubspec.yaml`

## 使用方法

### 方式一：直接运行 Go 脚本
```powershell
cd g:\code\homeocto-app\scripts\migrate
go run migrate-picoclaw-fui.go G:\code\picoclaw-fui G:\code\homeocto-app
```

### 方式二：使用 PowerShell 启动脚本（推荐）
```powershell
cd g:\code\homeocto-app\scripts\migrate
.\migrate-picoclaw-fui.ps1
```

## 注意事项
- ⚠️ 迁移前请确保已备份目标目录的重要文件
- ⚠️ 脚本会**先删除**目标目录中的同名目录和文件，然后重新拷贝
- ✅ 自动跳过 `node_modules`、`.git`、`.dart_tool`、`build` 等目录
- ✅ 二进制文件（图片、字体等）不会执行替换，直接拷贝
- ✅ 文本文件会执行关键词替换

## 跳过的目录
- `node_modules` - Node.js 依赖
- `.git` - Git 版本控制
- `vendor` - Go 依赖
- `dist` - 构建产物
- `build` - 构建产物
- `.cache` - 缓存
- `.next` - Next.js 构建产物
- `.turbo` - Turborepo 缓存
- `.tanstack` - TanStack 缓存
- `workspace` - 工作区
- `.dart_tool` - Dart 工具缓存
- `.gradle` - Gradle 缓存
- `Pods` - CocoaPods 依赖
- `ephemeral` - Flutter 自动生成的构建产物
- `.plugin_symlinks` - Flutter 插件符号链接
- `generated` - Flutter 自动生成的代码（如国际化文件 l10n）
- `project.xcworkspace` - Xcode 自动生成的工作区配置

## 跳过的文件
- `.DS_Store` - macOS 系统文件
- `Thumbs.db` - Windows 缩略图
- `.env.local` - 本地环境变量
- `pubspec.lock` - Flutter 依赖锁文件
- `*.iml` - IDE 模块文件

## 文本文件类型
以下类型的文件会被识别为文本文件并执行替换：
- Dart: `.dart`
- Flutter 国际化: `.arb`
- Kotlin: `.kt`, `.kts`
- Java: `.java`
- Swift/Objective-C: `.swift`, `.m`, `.h`, `.mm`
- C/C++: `.cc`, `.cpp`, `.c`, `.h`
- JavaScript/TypeScript: `.js`, `.jsx`, `.ts`, `.tsx`
- 配置文件: `.json`, `.yaml`, `.yml`, `.xml`, `.plist`
- 样式文件: `.css`, `.scss`
- 标记语言: `.html`, `.md`, `.txt`
- 构建配置: `.gradle`, `.properties`, `.cmake`
- iOS/Xcode: `.xcodeproj`, `.xcconfig`, `.entitlements`, `.storyboard`, `.xib`

## 验证迁移
迁移完成后，建议执行以下检查：
1. 运行 `flutter pub get` 安装依赖
2. 检查是否还有遗漏的 picoclaw 关键词：`Select-String -Path '**/*.dart' -Pattern 'picoclaw' -CaseSensitive`
3. 检查中文注释是否正常显示
4. 运行 `flutter analyze` 检查代码质量
5. 尝试编译运行：`flutter run`

## 故障排除

### 问题：Go 脚本报错 "Usage: go run migrate-picoclaw-fui.go"
**解决**：确保提供了两个参数：源目录和目标目录

### 问题：中文显示乱码
**解决**：脚本已使用 UTF-8 编码处理，如果仍有问题，检查源文件编码是否为 UTF-8

### 问题：某些文件没有被替换
**解决**：检查文件扩展名是否在文本文件列表中，二进制文件不会执行替换

### 问题：权限错误
**解决**：确保有目标目录的读写权限，关闭可能占用文件的 IDE 或进程
