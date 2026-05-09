# Device Control 架构说明与端口配置化

## 📊 三个核心文件的关系

### **架构图**

```
┌─────────────────────────────────────────────────────┐
│                  UI Layer (界面层)                    │
│                                                      │
│  SmartHomePage          ChatPage                    │
│  - 设备列表显示         - 聊天界面                   │
│  - 服务状态检查         - 消息显示                   │
│  - 错误UI展示           - 连接状态                   │
│         │                        │                   │
└─────────┼────────────────────────┼───────────────────┘
          │                        │
          ▼                        ▼
┌─────────────────────┐  ┌──────────────────────────┐
│  State Management   │  │   Direct WebSocket       │
│  (状态管理层)        │  │   (直接 WebSocket)        │
│                      │  │                           │
│ SmartHomeProvider   │  │   _channel (内部)         │
│ - 连接状态管理       │  │   - 直接管理 WebSocket    │
│ - 设备列表管理       │  │   - 无状态管理            │
│ - 业务逻辑处理       │  │                           │
│         │            │  │                           │
└─────────┼────────────┘  └──────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────┐
│              Network Layer (网络层)                   │
│                                                      │
│  HomeOctoClient                                      │
│  - WebSocket 连接管理                                 │
│  - HTTP REST API (GET/POST/PUT/DELETE)               │
│  - 自动重连机制                                       │
│  - Stream 流式API                                    │
│                                                      │
│  DeviceControlWebSocket (已废弃，待删除)              │
│  - 轻量级 WebSocket 封装                              │
│  - 单例模式                                          │
│  - 事件驱动（回调机制）                               │
└─────────────────────────────────────────────────────┘
```

---

## 🔍 详细关系说明

### **1. HomeOctoClient（完整的网络客户端）**

**职责**: 提供完整的网络通信能力

**功能**:
- ✅ WebSocket 实时通信
- ✅ HTTP REST API (GET/POST/PUT/DELETE)
- ✅ 自动重连机制（最多5次，指数退避）
- ✅ Stream 流式API（connectionStream, messageStream）
- ✅ 连接状态管理（ConnectionState 枚举）

**使用场景**: 
- SmartHomeProvider 依赖它进行网络通信
- 需要完整 CRUD 操作的智能家居管理

**代码位置**: `lib/src/core/homeocto_client.dart`

---

### **2. SmartHomeProvider（状态管理器）**

**职责**: 为 SmartHomePage 提供状态管理和业务逻辑

**功能**:
- ✅ 封装 HomeOctoClient
- ✅ 管理设备列表（加载、添加、删除、更新）
- ✅ 处理设备操作（控制设备）
- ✅ ChangeNotifier（配合 Provider 使用）
- ✅ 从 ServiceManager 读取配置（host, gatewayPort）

**依赖**:
- `HomeOctoClient` - 网络通信
- `ServiceManager` - 配置信息（host, gatewayPort）

**使用场景**: 
- SmartHomePage 的状态管理
- 通过 `context.read<ServiceManager>()` 获取配置

**代码位置**: `lib/src/core/smart_home_provider.dart`

---

### **3. DeviceControlWebSocket（轻量级单例，已废弃）**

**职责**: 简单的 WebSocket 封装（不推荐使用）

**功能**:
- ✅ 单例模式（全局唯一实例）
- ✅ 事件驱动（onMessage/onStatus 回调）
- ✅ 发送消息并等待响应（sendAndWait）
- ❌ 不包含 HTTP API
- ❌ 无自动重连机制

**问题**:
- ⚠️ 与 HomeOctoClient 功能重叠
- ⚠️ 端口硬编码（18791）
- ⚠️ 未被任何页面使用

**建议**: 
- 🗑️ 标记为废弃（@Deprecated）
- 🗑️ 或直接删除
- 🗑️ 统一使用 HomeOctoClient

**代码位置**: `lib/src/core/device_control_ws.dart`

---

## 🔧 端口配置化改造

### **改造前**

```dart
// ❌ 硬编码端口
class HomeOctoClient {
  static const String _baseUrl = 'http://127.0.0.1:18791';
  static const String _wsUrl = 'ws://127.0.0.1:18791/home/ws';
}

class _ChatPageState extends State<ChatPage> {
  static const _gatewayPort = 18790;  // ❌ 硬编码
}
```

**问题**:
- ❌ 端口无法修改
- ❌ 不同环境需要重新编译
- ❌ Chat 和 Device Control 端口不一致

---

### **改造后**

#### **1. ServiceManager 添加 gatewayPort**

```dart
// lib/src/core/service_manager.dart
class ServiceManager extends ChangeNotifier {
  String _host = '127.0.0.1';
  int _port = 18800;  // Web 控制台端口
  int _gatewayPort = 18790;  // Gateway WebSocket 端口（Chat 和 Device Control 共用）

  // Getters
  String get webUrl => 'http://$_host:$_port';
  String get host => _host;
  int get port => _port;
  int get gatewayPort => _gatewayPort;  // ← 新增

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('host') ?? '127.0.0.1';
    _port = prefs.getInt('port') ?? 18800;
    _gatewayPort = prefs.getInt('gatewayPort') ?? 18790;  // ← 从配置读取
  }
}
```

**说明**:
- ✅ `gatewayPort` 是 Chat 和 Device Control 共用的 WebSocket 端口
- ✅ 默认值 18790（Chat 和 Device Control 使用相同端口，不同路径）
- ✅ 从 SharedPreferences 读取，用户可在设置页面修改

---

#### **2. HomeOctoClient 从配置读取**

```dart
// lib/src/core/homeocto_client.dart
class HomeOctoClient {
  final String _host;
  final int _gatewayPort;

  // 构造函数支持自定义端口
  HomeOctoClient({
    String host = '127.0.0.1',
    int gatewayPort = 18790,
  })  : _host = host,
        _gatewayPort = gatewayPort;

  // 动态生成 URL
  String get _baseUrl => 'http://$_host:$_gatewayPort';
  String get _wsUrl => 'ws://$_host:$_gatewayPort/home/ws';
}
```

**说明**:
- ✅ 端口通过构造函数传入
- ✅ 支持自定义 host 和 gatewayPort
- ✅ URL 动态生成

---

#### **3. SmartHomeProvider 传递配置**

```dart
// lib/src/core/smart_home_provider.dart
class SmartHomeProvider extends ChangeNotifier {
  final HomeOctoClient _client;
  final ServiceManager _serviceManager;

  SmartHomeProvider({
    HomeOctoClient? client,
    required ServiceManager serviceManager,  // ← 必须传入
  })  : _client = client ??
            HomeOctoClient(
              host: serviceManager.host,
              gatewayPort: serviceManager.gatewayPort,  // ← 从配置读取
            ),
        _serviceManager = serviceManager {
    debugPrint(
      '[SmartHomeProvider] Initializing with gateway port: ${serviceManager.gatewayPort}',
    );
    _init();
  }
}
```

**说明**:
- ✅ 必须传入 ServiceManager
- ✅ 自动从 ServiceManager 读取配置
- ✅ 支持传入自定义的 HomeOctoClient（用于测试）

---

#### **4. SmartHomePage 使用**

```dart
// lib/src/ui/smart_home_page.dart
class _SmartHomePageState extends State<SmartHomePage> {
  late SmartHomeProvider _provider;

  @override
  void initState() {
    super.initState();
    final serviceManager = context.read<ServiceManager>();
    _provider = SmartHomeProvider(serviceManager: serviceManager);  // ← 传入配置
    _initConnection();
  }
}
```

---

#### **5. ChatPage 也改为从配置读取**

```dart
// lib/src/ui/chat_page.dart
class _ChatPageState extends State<ChatPage> {
  static const _gatewayHost = '127.0.0.1';
  late int _gatewayPort;  // ← 改为从配置读取

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // 从 ServiceManager 读取 Gateway 端口
    final serviceManager = context.read<ServiceManager>();
    _gatewayPort = serviceManager.gatewayPort;
    debugPrint('[ChatPage] Using gateway port: $_gatewayPort');

    // ... 其余代码
    _connectToGateway();
  }

  void _connectToGateway() {
    final uri = Uri.parse(
      'ws://$_gatewayHost:$_gatewayPort/pico/ws?session_id=$_sessionId',
    );
    // ...
  }
}
```

---

## 📋 WebSocket 端点说明

### **统一的 Gateway 端口**

```
Gateway 端口（默认 18790）
├── /pico/ws?session_id=xxx  → Chat（AI 助手）
│    - Token: picoclaw-android-local
│    - 协议: Pico Protocol
│
└── /home/ws                 → Device Control（智能设备）
     - Token: picoclaw-android-local
     - 协议: HomeOcto Protocol
```

**说明**:
- ✅ Chat 和 Device Control 使用**相同的端口**（18790）
- ✅ 通过**不同的路径**区分（`/pico/ws` vs `/home/ws`）
- ✅ 使用**相同的 Token** 认证
- ✅ 用户只需配置一个 `gatewayPort`

---

## 🎯 配置优先级

```
1. 用户配置（SharedPreferences）
   ↓
2. 默认值
   - host: 127.0.0.1
   - gatewayPort: 18790
   - port: 18800 (Web 控制台)
```

**配置存储**:
```dart
// 保存配置
await prefs.setInt('gatewayPort', 18790);
await prefs.setString('host', '127.0.0.1');

// 读取配置
_gatewayPort = prefs.getInt('gatewayPort') ?? 18790;
_host = prefs.getString('host') ?? '127.0.0.1';
```

---

## 🗑️ DeviceControlWebSocket 处理建议

### **方案 1: 标记为废弃（推荐）**

```dart
// lib/src/core/device_control_ws.dart

/// @deprecated 请使用 HomeOctoClient 代替
/// 
/// 此类已被废弃，原因：
/// 1. 与 HomeOctoClient 功能重叠
/// 2. 端口硬编码，不支持配置
/// 3. 缺少自动重连机制
/// 4. 未在任何页面中使用
///
/// 迁移指南:
/// ```dart
/// // 旧代码
/// await deviceControlWS.connect();
/// deviceControlWS.sendMessage({'type': 'device.control'});
///
/// // 新代码
/// final client = HomeOctoClient(
///   host: serviceManager.host,
///   gatewayPort: serviceManager.gatewayPort,
/// );
/// await client.connect();
/// client.sendMessage({'type': 'device.control'});
/// ```
@Deprecated('Use HomeOctoClient instead')
class DeviceControlWebSocket {
  // ... 保留代码但标记为废弃
}
```

### **方案 2: 直接删除**

如果确认没有其他地方使用，可以直接删除文件：
```bash
rm lib/src/core/device_control_ws.dart
rm docs/DEVICE_CONTROL_WS.md
```

---

## 📊 改造对比

| 特性 | 改造前 | 改造后 |
|------|--------|--------|
| **Chat 端口** | 硬编码 18790 | ✅ 从配置读取 |
| **Device Control 端口** | 硬编码 18791 | ✅ 从配置读取（与 Chat 共用 18790） |
| **配置来源** | 无 | ✅ ServiceManager + SharedPreferences |
| **可配置性** | ❌ 需重新编译 | ✅ 用户可在设置中修改 |
| **端口一致性** | ❌ Chat(18790) ≠ Device(18791) | ✅ 统一使用 18790 |
| **依赖注入** | ❌ 无 | ✅ ServiceManager 注入 |

---

## 🔍 调试日志

### **启动时**
```
[ServiceManager] Loading config: gatewayPort=18790
[ChatPage] Using gateway port: 18790
[SmartHomeProvider] Initializing with gateway port: 18790
[HomeOctoClient] Starting connection to ws://127.0.0.1:18790/home/ws
```

### **连接成功**
```
[HomeOctoClient] WebSocket ready, connection established
[SmartHomeProvider] Connection state changed: ConnectionState.connected
[SmartHomeProvider] Connected, loading devices
```

### **连接失败**
```
[HomeOctoClient] WebSocket ready failed: Connection refused
[SmartHomeProvider] Connection state changed: ConnectionState.error
[SmartHomeProvider] Connection error
```

---

## ✅ 总结

### **三个文件的关系**
1. **HomeOctoClient**: 网络通信层（WebSocket + HTTP）
2. **SmartHomeProvider**: 状态管理层（依赖 HomeOctoClient）
3. **DeviceControlWebSocket**: 已废弃（功能重叠）

### **端口配置化**
1. ✅ ServiceManager 统一管理配置（host, gatewayPort）
2. ✅ 从 SharedPreferences 读取，支持用户自定义
3. ✅ Chat 和 Device Control 共用同一端口（18790）
4. ✅ 通过不同路径区分服务（/pico/ws vs /home/ws）

### **下一步建议**
1. 🗑️ 删除或废弃 DeviceControlWebSocket
2. 📝 在设置页面添加 gatewayPort 配置选项
3. 🧪 添加单元测试验证配置读取逻辑
