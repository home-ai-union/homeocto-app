# MiniCPM-V-demo-Android 迁移总结

## 概述

将 MiniCPM-V-demo-Android 的全部页面（模型下载、模型加载、对话聊天）以 **Android Library 模块** 形式集成到 homeocto-app (Flutter) 项目中，原始 Kotlin/XML/C++ 代码 **零修改**，后续升级可直接覆盖。

## 架构

```
homeocto-app/
├── llama.cpp/                              # llama.cpp 推理引擎（已存在）
├── android/
│   ├── app/                                # Flutter 宿主模块（修改 5 个文件）
│   └── minicpm_v_demo/                     # 新建 Android 库模块（新建 30+ 个文件）
└── lib/src/native/
    └── minicpm_native_bridge.dart          # Flutter 端桥接
```

## 已完成的工作

### 新建文件（~30 个）
| 文件 | 说明 |
|------|------|
| `android/minicpm_v_demo/build.gradle.kts` | 库模块构建配置 |
| `android/minicpm_v_demo/proguard-rules.pro` | 消费者 ProGuard 规则 |
| `android/minicpm_v_demo/src/main/AndroidManifest.xml` | Activity/Service 声明 |
| `android/minicpm_v_demo/src/main/java/com/example/minicpm_v_demo/*.kt` | 13 个 Kotlin 源文件（零修改） |
| `android/minicpm_v_demo/src/main/cpp/CMakeLists.txt` | CMake 构建配置（零修改） |
| `android/minicpm_v_demo/src/main/cpp/llama_jni.cpp` | JNI 桥接代码（零修改） |
| `android/minicpm_v_demo/src/main/cpp/logging.h` | 日志头文件（零修改） |
| `android/minicpm_v_demo/src/main/res/layout/*.xml` | 7 个布局文件（零修改） |
| `android/minicpm_v_demo/src/main/res/drawable/*.xml` | 10 个向量图标（零修改） |
| `android/minicpm_v_demo/src/main/res/values/*.xml` | colors/strings/themes（零修改） |
| `android/minicpm_v_demo/src/main/res/values-en/` | 英文字符串覆盖（零修改） |
| `android/minicpm_v_demo/src/main/res/values-night/` | 深色主题（零修改） |
| `android/minicpm_v_demo/src/main/res/mipmap-*/` | 17 个启动图标（零修改） |
| `android/minicpm_v_demo/src/main/res/xml/` | network_security_config（零修改） |
| `lib/src/native/minicpm_native_bridge.dart` | Flutter MethodChannel 桥接 |

### 修改文件（6 个）
| 文件 | 修改内容 |
|------|---------|
| `android/settings.gradle.kts` | 添加 `include(":minicpm_v_demo")` |
| `android/app/build.gradle.kts` | 添加 `implementation(project(":minicpm_v_demo"))` + Markwon |
| `android/app/proguard-rules.pro` | 添加 MiniCPM-V JNI keep 规则 |
| `android/app/.../PicoClawApp.kt` | 添加 LocaleManager 初始化 + 下载通知渠道 |
| `android/app/.../PicoClawMethodChannel.kt` | 添加 `openModelManager` + `openMiniCPMChat` 方法 |
| `lib/src/ui/dashboard_page.dart` | 添加 AI Chat (MiniCPM-V) 快速入口按钮 |
| `lib/src/ui/config_page.dart` | 添加 Model Management 配置入口（仅 Android） |

## 验证结果

- **Kotlin 编译**: `:minicpm_v_demo:compileDebugKotlin` 成功
- **资源处理**: `:minicpm_v_demo:processDebugResources` 成功  
- **Flutter 分析**: `flutter analyze` 无问题

## 后续步骤

1. **Git Submodule 注册**: 将 `llama.cpp/` 正式注册为 git submodule
   ```bash
   git submodule add <repo-url> llama.cpp
   ```

2. **首次完整构建**: 需要 NDK/CMake 编译 llama.cpp 原生代码（预计 10-30 分钟）
   ```bash
   cd android
   ./gradlew :minicpm_v_demo:assembleDebug
   ```

3. **运行时验证**:
   - 点击 Dashboard 页面的 "AI Chat (MiniCPM-V)" 按钮启动聊天
   - 点击 Config 页面的 "Model Management" 入口管理模型
   - 验证模型下载、加载、对话功能

## 升级路径

当 MiniCPM-V-demo-Android 发布新版本时：
1. 备份当前 `android/minicpm_v_demo/` 目录
2. 从新版本复制所有文件覆盖到 `android/minicpm_v_demo/`
3. 重新构建即可

原始代码无需修改，升级过程简单直接。
