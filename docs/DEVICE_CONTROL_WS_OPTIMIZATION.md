# Device Control WebSocket 优化说明

## 优化概述

参考 Chat 页面的 WebSocket 连接实现，对 Device Control (18791) 的 WebSocket 连接进行了全面优化，使其具备：
- ✅ 完善的错误处理和提示
- ✅ 服务状态检查
- ✅ 友好的用户界面反馈
- ✅ 完整的调试日志
- ✅ Ready 状态确认机制

---

## 优化对比

### **优化前**

```dart
// homeocto_client.dart - 旧版本
Future<void> connect() async {
  if (_state == ConnectionState.connected) return;
  
  _setState(ConnectionState.connecting);
  
  try {
    _channel = IOWebSocketChannel.connect(Uri.parse(_wsUrl));
    
    _wsSubscription = _channel!.stream.listen(
      (data) { /* ... */ },
      onError: (error) { /* 简单处理 */ },
      onDone: () { /* 简单处理 */ },
    );
  } catch (e) {
    _setState(ConnectionState.error);
  }
}

// smart_home_page.dart - 旧版本
@override
void initState() {
  super.initState();
  _provider = SmartHomeProvider();
  // ❌ 没有检查服务状态
  // ❌ 没有错误提示
  // ❌ 没有友好的 UI 反馈
}
```

**问题**：
- ❌ 没有检查 Gateway 服务是否运行
- ❌ 连接失败时用户不知道原因
- ❌ 没有 Ready 状态确认
- ❌ 调试信息不足
- ❌ 错误提示不友好

---

### **优化后**

```dart
// homeocto_client.dart - 新版本
Future<void> connect() async {
  if (_state == ConnectionState.connected) return;

  _setState(ConnectionState.connecting);
  debugPrint('[HomeOctoClient] Starting connection to $_wsUrl');

  try {
    // 获取 Token
    String token = 'picoclaw-android-local';
    try {
      token = await PicoClawChannel.getPicoToken();
      debugPrint('[HomeOctoClient] Token obtained successfully');
    } catch (e) {
      debugPrint('[HomeOctoClient] Failed to get token, using default: $e');
    }

    debugPrint('[HomeOctoClient] Connecting to $_wsUrl with token');

    // 建立 WebSocket 连接（带 Token 认证）
    _channel = IOWebSocketChannel.connect(
      Uri.parse(_wsUrl),
      headers: {'Authorization': 'Bearer $token'},
    );

    debugPrint('[HomeOctoClient] WebSocket channel created, waiting for ready');

    // ✅ 监听 WebSocket ready 状态（参考 Chat 页面实现）
    _channel!.ready
        .then((_) {
          debugPrint('[HomeOctoClient] WebSocket ready, connection established');
          _reconnectAttempts = 0;
          if (_state != ConnectionState.connected) {
            _setState(ConnectionState.connected);
          }
        })
        .catchError((e) {
          debugPrint('[HomeOctoClient] WebSocket ready failed: $e');
          _setState(ConnectionState.error);
          _scheduleReconnect();
        });

    // 监听消息流
    _wsSubscription = _channel!.stream.listen(
      (data) { /* ... */ },
      onError: (error) {
        debugPrint('[HomeOctoClient] WebSocket error: $error');
        _setState(ConnectionState.error);
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[HomeOctoClient] WebSocket closed');
        _setState(ConnectionState.disconnected);
        _scheduleReconnect();
      },
    );
  } catch (e) {
    debugPrint('[HomeOctoClient] Connection failed: $e');
    _setState(ConnectionState.error);
    _scheduleReconnect();
  }
}
```

**改进**：
- ✅ 添加完整的调试日志
- ✅ 添加 Ready 状态确认（与 Chat 一致）
- ✅ 详细的错误日志输出
- ✅ Token 获取状态监控

---

## 主要优化点

### **1. HomeOctoClient 优化**

#### **添加 Ready 状态监听**
```dart
// 参考 Chat 页面的 _channel!.ready 机制
_channel!.ready
    .then((_) {
      debugPrint('[HomeOctoClient] WebSocket ready, connection established');
      _reconnectAttempts = 0;
      if (_state != ConnectionState.connected) {
        _setState(ConnectionState.connected);
      }
    })
    .catchError((e) {
      debugPrint('[HomeOctoClient] WebSocket ready failed: $e');
      _setState(ConnectionState.error);
      _scheduleReconnect();
    });
```

**作用**：
- 确认 WebSocket 真正建立连接
- 避免"假连接"状态
- 与 Chat 页面保持一致的连接确认机制

#### **添加详细的调试日志**
```dart
debugPrint('[HomeOctoClient] Starting connection to $_wsUrl');
debugPrint('[HomeOctoClient] Token obtained successfully');
debugPrint('[HomeOctoClient] WebSocket channel created, waiting for ready');
debugPrint('[HomeOctoClient] WebSocket ready, connection established');
debugPrint('[HomeOctoClient] WebSocket error: $error');
debugPrint('[HomeOctoClient] WebSocket closed');
debugPrint('[HomeOctoClient] Connection failed: $e');
```

**作用**：
- 便于调试和排查问题
- 清晰展示连接流程
- 快速定位失败原因

---

### **2. SmartHomePage 优化**

#### **添加服务状态检查**
```dart
/// 初始化连接（参考 Chat 页面实现）
Future<void> _initConnection() async {
  // 检查服务是否运行
  final service = context.read<ServiceManager>();
  if (service.status != ServiceStatus.running) {
    debugPrint('[SmartHomePage] Gateway service not running, status: ${service.status}');
    setState(() {
      _connectionError = 'Gateway 服务未运行，请先在 Dashboard 页面启动服务';
    });
    return;
  }

  debugPrint('[SmartHomePage] Gateway service is running, connecting to device control WebSocket');
  
  try {
    await _provider.connect();
  } catch (e) {
    debugPrint('[SmartHomePage] Connection failed: $e');
    if (mounted) {
      setState(() {
        _connectionError = '连接失败: $e\n请确保 Gateway 服务正在运行';
      });
    }
  }
}
```

**作用**：
- ✅ 连接前检查 Gateway 服务状态
- ✅ 服务未运行时给出明确提示
- ✅ 引导用户到 Dashboard 启动服务
- ✅ 捕获连接异常并友好提示

#### **添加友好的错误 UI**
```dart
// 显示连接错误（参考 Chat 页面）
if (_connectionError != null && !provider.isConnected) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_connectionError!, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _initConnection,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go to Dashboard'),
        ),
      ],
    ),
  );
}
```

**作用**：
- ✅ 清晰的错误图标和提示
- ✅ 提供"重试"按钮
- ✅ 提供"前往 Dashboard"按钮
- ✅ 与 Chat 页面的错误提示风格一致

#### **优化连接状态条**
```dart
Widget _buildConnectionStatus() {
  return Consumer<SmartHomeProvider>(
    builder: (context, provider, _) {
      final isConnected = provider.isConnected;
      final isConnecting = provider.connectionState == homeocto.ConnectionState.connecting;
      final hasError = provider.connectionState == homeocto.ConnectionState.error;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isConnected
            ? Colors.green.withAlpha(20)
            : isConnecting
            ? Colors.orange.withAlpha(20)
            : Colors.red.withAlpha(20),
        child: Row(
          children: [
            Icon(/* 状态图标 */),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isConnected
                    ? 'Connected'
                    : isConnecting
                    ? 'Connecting...'
                    : hasError
                    ? (_connectionError ?? 'Disconnected')
                    : 'Disconnected',
              ),
            ),
            if (!isConnected && !isConnecting)
              TextButton(
                onPressed: _initConnection,  // ← 使用优化后的连接方法
                child: const Text('Reconnect'),
              ),
          ],
        ),
      );
    },
  );
}
```

**改进**：
- ✅ 显示详细的错误信息（而非简单的"Disconnected"）
- ✅ Reconnect 按钮使用完整的连接流程（包含服务检查）
- ✅ 状态条使用 Expanded 避免文本截断

---

### **3. SmartHomeProvider 优化**

#### **添加连接状态日志**
```dart
void _init() {
  // 监听连接状态变化
  _client.connectionStream.listen((state) {
    debugPrint('[SmartHomeProvider] Connection state changed: $state');
    _connectionState = state;
    notifyListeners();

    if (state == ConnectionState.connected) {
      debugPrint('[SmartHomeProvider] Connected, loading devices');
      _loadDevices();
    } else if (state == ConnectionState.error) {
      debugPrint('[SmartHomeProvider] Connection error');
      _error = 'WebSocket 连接失败，请检查 Gateway 服务是否运行';
      notifyListeners();
    }
  });

  // 监听服务器消息
  _client.messageStream.listen((message) {
    debugPrint('[SmartHomeProvider] Received message: $message');
    _handleServerMessage(message);
  });
}
```

**改进**：
- ✅ 记录连接状态变化
- ✅ 连接错误时设置友好的错误提示
- ✅ 记录收到的消息

#### **优化 connect 方法**
```dart
Future<void> connect() async {
  debugPrint('[SmartHomeProvider] Connecting to device control WebSocket');
  try {
    await _client.connect();
  } catch (e) {
    debugPrint('[SmartHomeProvider] Connection failed: $e');
    rethrow;  // ← 抛出异常让上层处理
  }
}
```

**改进**：
- ✅ 添加日志
- ✅ 捕获并重新抛出异常（让 SmartHomePage 处理）

#### **优化 _loadDevices 方法**
```dart
Future<void> _loadDevices() async {
  if (_isLoading) return;  // ← 防止重复加载

  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    debugPrint('[SmartHomeProvider] Loading devices from API');
    final response = await _client.get('/api/devices');
    if (response.containsKey('devices')) {
      _devices = List<Map<String, dynamic>>.from(response['devices']);
      debugPrint('[SmartHomeProvider] Loaded ${_devices.length} devices');
    } else {
      _devices = [];
      debugPrint('[SmartHomeProvider] No devices found');
    }
  } catch (e) {
    debugPrint('[SmartHomeProvider] Failed to load devices: $e');
    _error = '加载设备失败: $e';  // ← 中文提示
    _devices = [];
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

**改进**：
- ✅ 防止重复加载
- ✅ 详细的日志输出
- ✅ 中文错误提示

---

## 完整连接流程

### **优化后的流程**

```
用户进入 SmartHomePage
    ↓
SmartHomePage.initState()
    ↓
_initConnection()
    ↓
检查 ServiceManager.status
    ↓
┌─ 服务未运行 ─→ 显示错误提示
│               - "Gateway 服务未运行"
│               - 显示"Retry"按钮
│               - 显示"Go to Dashboard"按钮
│
└─ 服务已运行 ─→ SmartHomeProvider.connect()
                ↓
                HomeOctoClient.connect()
                ↓
                获取 Token
                ↓
                建立 WebSocket 连接
                ↓
                等待 _channel!.ready
                ↓
          ┌─ 成功 ─→ ConnectionState.connected
          │          ↓
          │          加载设备列表
          │          ↓
          │          显示设备列表
          │
          └─ 失败 ─→ ConnectionState.error
                     ↓
                     显示错误提示
                     - "连接失败: [错误信息]"
                     - 显示"Retry"按钮
```

---

## 调试日志示例

### **成功连接**
```
[SmartHomePage] Gateway service is running, connecting to device control WebSocket
[SmartHomeProvider] Connecting to device control WebSocket
[HomeOctoClient] Starting connection to ws://127.0.0.1:18791/home/ws
[HomeOctoClient] Token obtained successfully
[HomeOctoClient] Connecting to ws://127.0.0.1:18791/home/ws with token
[HomeOctoClient] WebSocket channel created, waiting for ready
[HomeOctoClient] WebSocket ready, connection established
[SmartHomeProvider] Connection state changed: ConnectionState.connected
[SmartHomeProvider] Connected, loading devices
[SmartHomeProvider] Loading devices from API
[SmartHomeProvider] Loaded 5 devices
```

### **服务未运行**
```
[SmartHomePage] Gateway service not running, status: ServiceStatus.stopped
```

### **连接失败**
```
[SmartHomePage] Gateway service is running, connecting to device control WebSocket
[SmartHomeProvider] Connecting to device control WebSocket
[HomeOctoClient] Starting connection to ws://127.0.0.1:18791/home/ws
[HomeOctoClient] Token obtained successfully
[HomeOctoClient] Connecting to ws://127.0.0.1:18791/home/ws with token
[HomeOctoClient] WebSocket channel created, waiting for ready
[HomeOctoClient] WebSocket ready failed: Connection refused
[SmartHomeProvider] Connection state changed: ConnectionState.error
[SmartHomeProvider] Connection error
```

---

## 与 Chat 页面对比

| 特性 | Chat 页面 | Device Control 页面（优化后） |
|------|-----------|------------------------------|
| **服务检查** | ❌ 无 | ✅ 检查 ServiceManager.status |
| **Ready 确认** | ✅ `_channel!.ready` | ✅ `_channel!.ready` |
| **错误提示** | ✅ 聊天消息显示 | ✅ 专用错误 UI + 状态条 |
| **调试日志** | ✅ 基础日志 | ✅ 详细日志（每个步骤） |
| **重连机制** | ✅ 发送消息时重连 | ✅ 自动重连 + 手动重连按钮 |
| **中文提示** | ✅ | ✅ |
| **引导用户** | ❌ 无 | ✅ "Go to Dashboard" 按钮 |

---

## 测试建议

### **1. 服务未运行场景**
```
1. 确保 Gateway 服务未启动
2. 进入 Smart Home 页面
3. 验证：显示"Gateway 服务未运行"提示
4. 验证：显示"Retry"和"Go to Dashboard"按钮
```

### **2. 正常连接场景**
```
1. 在 Dashboard 启动 Gateway 服务
2. 进入 Smart Home 页面
3. 验证：连接状态变为"Connected"（绿色）
4. 验证：设备列表正常加载
5. 验证：日志输出完整连接流程
```

### **3. 连接失败场景**
```
1. 启动 Gateway 服务但端口被占用
2. 进入 Smart Home 页面
3. 验证：显示连接失败错误
4. 点击"Retry"按钮
5. 验证：重新尝试连接
```

### **4. 连接断开场景**
```
1. 正常连接后停止 Gateway 服务
2. 验证：WebSocket onDone 触发
3. 验证：状态变为"Disconnected"
4. 验证：自动重连机制启动
```

---

## 总结

通过参考 Chat 页面的实现，Device Control WebSocket 连接现在具备：

✅ **完善的错误处理**：服务检查 + Ready 确认 + 异常捕获  
✅ **友好的用户提示**：清晰的错误信息 + 操作引导  
✅ **完整的调试日志**：每个关键步骤都有日志输出  
✅ **一致的用户体验**：与 Chat 页面保持相同的交互模式  
✅ **可靠的连接机制**：自动重连 + 手动重连 + 状态监控  

现在两个 WebSocket 的连接质量达到了相同的标准！🎉
