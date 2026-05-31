# 应用崩溃问题诊断指南

## 问题描述
应用加载模型后，输入"你好"，界面就自动退出。

## 已实施的修复

### 1. 增强的错误日志 (LlamaEngine.kt)
- 在 `sendUserPrompt` 中添加了详细的日志输出
- 记录每个token的生成过程
- 捕获并记录所有异常

### 2. Native层异常处理 (llama_jni.cpp)
- 为 `processUserPrompt` 添加了 try-catch 块
- 为 `generateNextToken` 添加了 try-catch 块
- 添加了空指针检查
- 所有异常都会返回错误码而不是崩溃

## 如何诊断问题

### 步骤1: 查看Logcat日志

运行以下命令查看日志：
```bash
adb logcat | grep -E "minicpm-v|LlamaEngine"
```

关键日志标记：
- `Sending user prompt:` - 确认收到用户输入
- `processUserPrompt returned:` - 查看处理结果码
- `Error during token generation` - token生成错误
- `Exception caught:` - native层异常

### 步骤2: 识别错误码

**processUserPrompt 返回码：**
- `0` = 成功
- `1` = 通用错误
- `2` = tokenization/eval失败
- `3` = 无法获取用户输入字符串
- `4` = vision context为空
- `5` = 无法初始化input chunks
- `6` = context为空
- `10` = C++标准异常
- `11` = 未知异常

### 步骤3: 常见问题及解决方案

#### 问题A: 内存不足 (OOM)
**症状：**
- 日志显示模型加载成功
- 输入后应用直接退出，无明显错误日志
- 可能看到 "Killed" 或 "Out of memory"

**解决方案：**
1. 检查设备可用内存：`adb shell dumpsys meminfo <package_name>`
2. 尝试使用更小的模型（如 minicpm5-1b 而非 minicpm-v-4.6）
3. 减少 context size（修改 llama_jni.cpp 中的 DEFAULT_CONTEXT_SIZE）

#### 问题B: Native库崩溃
**症状：**
- 日志显示 "Exception caught" 或突然中断
- 可能出现 "SIGSEGV" 或 "signal 11"

**解决方案：**
1. 确认模型文件完整且未损坏
2. 检查MD5校验是否通过
3. 重新下载模型文件

#### 问题C: UTF-8编码问题
**症状：**
- 日志显示 "append to cache" 多次
- 中文字符处理异常

**解决方案：**
- 已在代码中改进UTF-8验证
- 确保输入是有效的UTF-8编码

#### 问题D: 模型未正确加载
**症状：**
- processUserPrompt 返回 4 或 6
- 日志显示 "Vision context is null" 或 "Context is null"

**解决方案：**
1. 确认模型加载流程完成（看到 "Model loaded!" 日志）
2. 检查是否调用了 prepare()
3. 验证状态是否为 ModelReady

## 调试建议

### 1. 启用详细日志
```bash
adb shell setprop log.tag.minicpm-v VERBOSE
```

### 2. 监控内存使用
```bash
adb shell dumpsys meminfo com.example.minicpm_v_demo
```

### 3. 检查native崩溃
```bash
adb logcat | grep -E "libc|DEBUG|backtrace"
```

### 4. 测试简单输入
尝试输入英文 "hello" 而非中文，判断是否是编码问题。

## 下一步

如果问题仍然存在，请提供：
1. 完整的logcat日志（从启动应用到崩溃）
2. 使用的模型名称和大小
3. 设备型号和Android版本
4. 可用内存信息

## 代码修改摘要

### 修改的文件：
1. `android/minicpm_v_demo/src/main/java/com/example/minicpm_v_demo/LlamaEngine.kt`
   - 增强了 sendUserPrompt 的错误处理和日志

2. `android/minicpm_v_demo/src/main/cpp/llama_jni.cpp`
   - 为 processUserPrompt 添加异常处理
   - 为 generateNextToken 添加异常处理
   - 添加了空指针检查

### 编译和测试
修改后需要重新编译：
```bash
cd android
./gradlew assembleDebug
```

然后安装并测试：
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```
