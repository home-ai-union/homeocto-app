# WebSocket 连接时机说明

## 两个 WebSocket 端点对比

| 特性 | Chat (AI 助手) | Device Control (智能设备) |
|------|----------------|---------------------------|
| **端口** | 18790 | 18791 |
| **路径** | `/pico/ws` | `/home/ws` |
| **参数** | `?session_id=xxx` | 无参数 |
| **Token** | `picoclaw-android-local` | `picoclaw-android-local` |
| **连接时机** | 打开 ChatPage 时 | 打开 SmartHomePage 时 |
| **断开时机** | 离开 ChatPage 时 | 离开 SmartHomePage 时 |
| **生命周期** | 页面级 | 页面级 |
| **文件** | `chat_page.dart` | `smart_home_page.dart` |

---

## Chat WebSocket (18790)

### 连接时机
**用户导航到聊天页面时**

```dart
// lib/src/ui/chat_page.dart
class _ChatPageState extends State<ChatPage> {
  @override
  void initState() {
    super.initState();
    _initChat();  // ← 页面初始化时立即连接
  }

  Future<void> _initChat() async {
    _sessionId = await _getOrCreateSessionId();
    _picoToken = await PicoClawChannel.getPicoToken();
    _connectToGateway();  // ← 建立 WebSocket 连接
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();  // ← 页面销毁时断开
    super.dispose();
  }
}
```

### 生命周期流程
```
用户点击聊天按钮
    ↓
Navigator.push(ChatPage)
    ↓
ChatPage.initState()
    ↓
_connectToGateway()
    ↓
ws://127.0.0.1:18790/pico/ws?session_id=xxx
    ↓
用户进行聊天交互
    ↓
用户离开页面
    ↓
ChatPage.dispose()
    ↓
WebSocket 断开
```

---

## Device Control WebSocket (18791)

### 连接时机
**用户导航到智能家居页面时**

```dart
// lib/src/ui/smart_home_page.dart
class _SmartHomePageState extends State<SmartHomePage> {
  late SmartHomeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SmartHomeProvider();  // ← 页面初始化时创建 Provider
  }

  @override
  void dispose() {
    _provider.dispose();  // ← 页面销毁时断开（通过 Provider 内部实现）
    super.dispose();
  }
}

// lib/src/core/smart_home_provider.dart
class SmartHomeProvider extends ChangeNotifier {
  final HomeOctoClient _client;

  SmartHomeProvider({HomeOctoClient? client})
    : _client = client ?? HomeOctoClient() {
    _init();
  }

  void _init() {
    // 监听连接状态
    _client.connectionStream.listen((state) {
      _connectionState = state;
      notifyListeners();
      
      if (state == ConnectionState.connected) {
        _loadDevices();  // ← 连接成功后加载设备列表
      }
    });
  }

  Future<void> connect() async {
    await _client.connect();  // ← 实际建立 WebSocket 连接
  }
}

// lib/src/core/homeocto_client.dart
class HomeOctoClient {
  static const String _wsUrl = 'ws://127.0.0.1:18791/home/ws';

  Future<void> connect() async {
    // 获取 Token
    String token = 'picoclaw-android-local';
    try {
      token = await PicoClawChannel.getPicoToken();
    } catch (e) {
      debugPrint('[HomeOctoClient] Failed to get token, using default: $e');
    }

    // 建立 WebSocket 连接（带 Token 认证）
    _channel = IOWebSocketChannel.connect(
      Uri.parse(_wsUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    // 监听消息...
  }
}
```

### 生命周期流程
```
用户点击 Smart Home 按钮
    ↓
MainShell._onNavTap(4)
    ↓
IndexedStack 显示 SmartHomePage
    ↓
SmartHomePage.initState()
    ↓
SmartHomeProvider 创建
    ↓
SmartHomeProvider.connect()
    ↓
HomeOctoClient.connect()
    ↓
ws://127.0.0.1:18791/home/ws
    ↓
连接成功，加载设备列表
    ↓
用户进行设备控制
    ↓
用户离开页面（切换到其他 Tab）
    ↓
SmartHomePage.dispose()
    ↓
SmartHomeProvider.dispose()
    ↓
HomeOctoClient.disconnect()
    ↓
WebSocket 断开
```

---

## 关键设计原则

### ✅ 相同点
1. **按需连接**: 都在用户打开对应页面时连接
2. **页面级生命周期**: 都跟随页面的 initState/dispose
3. **Token 认证**: 都使用相同的 token (`picoclaw-android-local`)
4. **自动获取 Token**: 都通过 `PicoClawChannel.getPicoToken()` 获取
5. **错误处理**: 都有完整的 try-catch 和日志输出

### ❌ 不同点
1. **端口和路径**: 
   - Chat: `18790/pico/ws?session_id=xxx`
   - Device: `18791/home/ws`
2. **会话管理**: 
   - Chat 需要 session_id（持久化到 SharedPreferences）
   - Device 不需要 session_id
3. **消息协议**: 
   - Chat 使用 Pico Protocol (`message.send`, `message.create` 等)
   - Device 使用自定义协议（根据实际后端定义）

---

## 代码位置索引

### Chat WebSocket
- **UI 页面**: `lib/src/ui/chat_page.dart`
- **连接逻辑**: 第 63-125 行 (`_connectToGateway` 方法)
- **消息处理**: 第 127-177 行 (`_handleGatewayMessage` 方法)
- **发送消息**: 第 199-233 行 (`_sendMessage` 方法)

### Device Control WebSocket
- **UI 页面**: `lib/src/ui/smart_home_page.dart`
- **状态管理**: `lib/src/core/smart_home_provider.dart`
- **客户端实现**: `lib/src/core/homeocto_client.dart`
- **连接逻辑**: 第 34-63 行 (`connect` 方法)
- **消息处理**: 第 132-141 行 (`_handleMessage` 方法)

---

## 调试技巧

### 查看 Chat WebSocket 连接
```dart
// 在 chat_page.dart 中添加调试日志
void _connectToGateway() {
  debugPrint('[Chat] Connecting to ws://127.0.0.1:18790/pico/ws');
  debugPrint('[Chat] Session ID: $_sessionId');
  debugPrint('[Chat] Token: $_picoToken');
  // ...
}
```

### 查看 Device Control WebSocket 连接
```dart
// 在 homeocto_client.dart 中已有调试日志
debugPrint('[HomeOctoClient] Connecting to $_wsUrl with token');
debugPrint('[HomeOctoClient] WebSocket closed');
debugPrint('[HomeOctoClient] Connection failed: $e');
```

---

## 常见问题

### Q1: 为什么不在应用启动时就连接？
**A**: 按需连接可以节省资源，避免后台空转。用户可能不使用聊天或设备控制功能。

### Q2: 如果用户频繁切换页面怎么办？
**A**: WebSocket 连接和断开很快，频繁切换不会有问题。如果需要优化，可以实现连接池或延迟断开。

### Q3: Token 会在什么时候更新？
**A**: Token 是硬编码的 (`picoclaw-android-local`)，一般不会变化。每次连接时都会重新获取。

### Q4: 如果连接失败怎么办？
**A**: 都有重试机制：
- Chat: 显示错误消息，用户可以手动重连
- Device: 自动重试（最多 5 次，指数退避）
