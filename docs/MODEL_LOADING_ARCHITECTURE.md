# Model Loading Architecture & Flow

## Problem Statement

当前实现存在以下问题：
1. 下载按钮文字在深色主题下不可见（黑色文字）
2. 模型管理页面和Chat页面的模型状态不同步
3. 缺少与 Android 原生 `JniInferenceService` 的集成

## Current Architecture

### Components Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Layer                        │
├─────────────────────────────────────────────────────────┤
│  ModelDownloadPage  ───┐                                │
│  (Model Management)     │  TODO: MethodChannel           │
│                         ▼                                │
│  LocalChatPage  ◄── JniInferenceService                │
│  (HTTP Client)        │    (Android Service)             │
│                       │                                 │
└───────────────────────┼─────────────────────────────────┘
                        │ HTTP (18792)
                        ▼
                 ┌───────────────┐
                 │ llama-server  │
                 │  (HTTP API)   │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ JniLlamaEngine│
                 │  (JNI/Kotlin) │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │  libhomeocto  │
                 │  _llama.so    │
                 │  (llama.cpp)  │
                 └───────────────┘
```

## Model Loading Flow (Desired)

### Step-by-Step Process

```
1. User clicks "Download" in ModelDownloadPage
   ↓
2. [TODO] Flutter → MethodChannel → Android ModelDownloadService
   ↓
3. Download GGUF + MMProj files to /data/.../models/
   ↓
4. User clicks "Load Model" in ModelDownloadPage
   ↓
5. [TODO] Flutter → MethodChannel → JniInferenceService.loadModel()
   ↓
6. JniInferenceService calls:
   - JniLlamaEngine.initialize(context)
   - JniLlamaEngine.loadModel(modelPath, mmprojPath, version)
   ↓
7. JniInferenceService starts llama-server HTTP server on port 18792
   ↓
8. llama-server loads model into memory (may take 10-30 seconds)
   ↓
9. llama-server ready → /health endpoint returns {"status": "ok"}
   ↓
10. LocalChatPage health check detects status = "ok"
    ↓
11. Chat UI enables input, shows green dot "模型已就绪"
    ↓
12. User can now send messages via HTTP /completion endpoint
```

## Current Implementation Status

### ✅ Working
- [x] ModelDownloadPage UI (model selection, download button, load button)
- [x] LocalChatPage UI (chat bubbles, input bar, status indicator)
- [x] Health check polling (every 5 seconds)
- [x] HTTP streaming completion (simulated)
- [x] Download button text color fix (foregroundColor)

### ❌ TODO - Critical
- [ ] **MethodChannel integration** for model download
- [ ] **MethodChannel integration** for model loading
- [ ] **JniInferenceService** start/stop control
- [ ] Real model file existence check
- [ ] Model loading state synchronization between pages

### ⚠️ Current Workaround
当前使用**模拟下载**和**本地状态**：
- `_simulateDownload()`: 模拟下载进度（20秒）
- `_loadModel()`: 仅设置 `_isModelLoaded = true`（不实际加载）
- Chat页面的健康检查会失败（llama-server未启动）

## Integration Points Needed

### 1. MethodChannel Definition

```dart
// lib/src/core/llama_channel.dart (TODO)
class LlamaChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.homeai.homeocto/llama'
  );
  
  // Download model
  static Future<bool> downloadModel(String modelId) async {
    return await _channel.invokeMethod('downloadModel', {
      'modelId': modelId,
    });
  }
  
  // Load model into JniInferenceService
  static Future<bool> loadModel({
    required String modelPath,
    String? mmprojPath,
    int version = 0,
  }) async {
    return await _channel.invokeMethod('loadModel', {
      'modelPath': modelPath,
      'mmprojPath': mmprojPath,
      'version': version,
    });
  }
  
  // Check if model files exist
  static Future<bool> modelFilesExist(String modelId) async {
    return await _channel.invokeMethod('modelFilesExist', {
      'modelId': modelId,
    });
  }
  
  // Start JniInferenceService
  static Future<bool> startInferenceService() async {
    return await _channel.invokeMethod('startInferenceService');
  }
  
  // Stop JniInferenceService
  static Future<bool> stopInferenceService() async {
    return await _channel.invokeMethod('stopInferenceService');
  }
}
```

### 2. Android MethodChannel Handler

```kotlin
// android/app/src/main/kotlin/.../LlamaMethodChannel.kt (TODO)
class LlamaMethodChannel(private val context: Context) {
    private val inferenceService = JniInferenceService()
    
    fun handleMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "downloadModel" -> {
                val modelId = call.argument<String>("modelId")!!
                // Call ModelDownloadService
                result.success(true)
            }
            "loadModel" -> {
                val modelPath = call.argument<String>("modelPath")!!
                val mmprojPath = call.argument<String?>("mmprojPath")
                val version = call.argument<Int>("version") ?: 0
                
                // Use JniLlamaEngine to load
                val success = inferenceService.loadModel(
                    modelPath, mmprojPath, version
                )
                result.success(success)
            }
            "modelFilesExist" -> {
                val modelId = call.argument<String>("modelId")!!
                val exists = JniInferenceService.modelsExist(context)
                result.success(exists)
            }
            "startInferenceService" -> {
                val intent = Intent(context, JniInferenceService::class.java)
                context.startForegroundService(intent)
                result.success(true)
            }
            "stopInferenceService" -> {
                val intent = Intent(context, JniInferenceService::class.java)
                context.stopService(intent)
                result.success(true)
            }
        }
    }
}
```

### 3. Updated ModelDownloadPage

```dart
// Replace _loadModel() with:
Future<void> _loadModel() async {
  if (!_modelFileExists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('模型文件不存在，请先下载')),
    );
    return;
  }
  
  setState(() => _isLoading = true);
  
  try {
    // Start JniInferenceService
    await LlamaChannel.startInferenceService();
    
    // Load model via MethodChannel
    final model = _selectedModel;
    final modelPath = '/path/to/models/${model.ggufFileName}';
    final mmprojPath = '/path/to/models/${model.mmprojFileName}';
    
    final success = await LlamaChannel.loadModel(
      modelPath: modelPath,
      mmprojPath: mmprojPath,
      version: model.version,
    );
    
    if (success) {
      setState(() => _isModelLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模型加载成功！')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('加载失败: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 4. Updated LocalChatPage

Chat页面**不需要**修改，因为它已经通过 HTTP 健康检查自动检测模型状态：

```dart
// Current implementation (correct):
Future<void> _checkServerHealth() async {
  try {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:18792/health')
    ).timeout(const Duration(seconds: 2));
    
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    
    setState(() {
      _isModelReady = status == 'ok';  // ← llama-server reports ready
      _serverStatus = _isModelReady ? '模型已就绪' : '模型未就绪';
    });
  } catch (e) {
    setState(() {
      _isModelReady = false;
      _serverStatus = '服务未启动';
    });
  }
}
```

## JniLlamaEngine.kt Usage

### How It Works

根据提供的 `JniLlamaEngine.kt` 代码：

1. **Native Library Loading** (延迟加载):
```kotlin
fun tryLoadNativeLibrary() {
    System.loadLibrary("homeocto_llama")  // libhomeocto_llama.so
    isNativeLibraryLoaded = true
}
```

2. **Model Loading**:
```kotlin
fun loadModel(
    modelPath: String,
    mmprojPath: String? = null,
    imageMaxSliceNums: Int = 9,
    modelVersion: Int = 0
): Boolean {
    load(modelPath)              // JNI call
    loadMmproj(mmprojPath, ...)  // JNI call (if vision)
    prepare()                    // JNI call
    isModelLoaded = true
    return true
}
```

3. **Streaming Generation**:
```kotlin
fun generateStream(prompt: String, maxTokens: Int = 512): Flow<String> {
    processUserPrompt(prompt, maxTokens)
    while (true) {
        val token = generateNextToken() ?: break
        emit(token)
    }
}
```

### Integration with JniInferenceService

`JniInferenceService` 是一个 Android Service，它：
1. 使用 `JniLlamaEngine` 加载模型
2. 启动 Ktor HTTP 服务器（端口 18792）
3. 将 `/completion` 请求转发到 `JniLlamaEngine.generateStream()`
4. 将 `/health` 请求映射到模型加载状态

## Model Loading Success Detection

### How Chat Page Knows Model is Ready

**Current (Correct)**: HTTP Health Check
```
LocalChatPage ──GET /health──→ llama-server (port 18792)
                                    ↓
                              Check JniLlamaEngine.isModelLoaded
                                    ↓
                          {"status": "ok"} or {"status": "error"}
                                    ↓
LocalChatPage ←── Response ───┘
                                    ↓
                      _isModelReady = (status == "ok")
```

**Advantages**:
- ✅ Decoupled from Android implementation
- ✅ Works across platforms (Android, desktop)
- ✅ Real-time status monitoring
- ✅ No MethodChannel needed for status

### Alternative (NOT Recommended): MethodChannel Status

```dart
// This approach is BAD because:
// - Tight coupling to Android
// - No real-time updates
// - Duplicates llama-server's own health check
```

## Next Steps Priority

### High Priority (Must Do)
1. ✅ Fix download button text color ← **DONE**
2. 🔲 Create `LlamaChannel` MethodChannel wrapper
3. 🔲 Implement Android `LlamaMethodChannel` handler
4. 🔲 Update `ModelDownloadPage._loadModel()` to use MethodChannel
5. 🔲 Implement real `modelFilesExist()` check

### Medium Priority (Should Do)
6. 🔲 Integrate real `ModelDownloadService` (replace simulation)
7. 🔲 Add loading spinners during model load
8. 🔲 Handle model load errors gracefully
9. 🔲 Add retry mechanism for failed downloads

### Low Priority (Nice to Have)
10. 🔲 Show model load progress (llama.cpp context building)
11. 🔲 Support model unloading
12. 🔲 Add model switch without restart
13. 🔲 Cache model metadata

## Testing Flow (After Integration)

1. **Download Flow**:
   ```
   Open Model Management → Select Model → Click Download
   → Watch progress → See "Download Complete" toast
   ```

2. **Load Flow**:
   ```
   Click "Load Model" → See loading spinner
   → Wait 10-30s → See "Model Loaded" toast
   → Switch to Chat tab → See green dot "模型已就绪"
   ```

3. **Chat Flow**:
   ```
   Type message → Click send
   → Watch streaming response token by token
   → Click stop to cancel generation
   ```

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `lib/src/ui/model_download_page.dart` | Model management UI | ✅ Complete (needs MethodChannel) |
| `lib/src/ui/local_chat_page.dart` | Chat UI + health check | ✅ Complete |
| `lib/src/ui/chat_message.dart` | Message data models | ✅ Complete |
| `android/.../JniLlamaEngine.kt` | JNI wrapper for llama.cpp | ✅ Provided |
| `android/.../JniInferenceService.kt` | Android service + HTTP server | 🔲 Need to check |
| `android/.../ModelDownloadService.kt` | Download service | ✅ Exists |
| `lib/src/core/llama_channel.dart` | MethodChannel wrapper | ❌ TODO |
| `android/.../LlamaMethodChannel.kt` | MethodChannel handler | ❌ TODO |
