# Device Control WebSocket 架构简化

## 📊 最终架构

### **三个文件的关系**

```
SmartHomePage (UI层)
    ↓ 使用
SmartHomeProvider (状态管理层)
    ↓ 依赖
HomeOctoClient (网络通信层)
    ├─ WebSocket: ws://127.0.0.1:18791/home/ws
    ├─ HTTP API: http://127.0.0.1:18791
    └─ 自动重连机制

DeviceControlWebSocket (已废弃，待删除)
    - 功能与 HomeOctoClient 重叠
    - 建议删除
```

---

## 🔧 简化后的实现

### **1. HomeOctoClient - 硬编码端口 18791**

```dart
class HomeOctoClient {
  static const String _baseUrl = 'http://127.0.0.1:18791';
  static const String _wsUrl = 'ws://127.0.0.1:18791/home/ws';
  
  // 直接使用静态常量，无需配置
}
```

**优势**:
- ✅ 简单直接
- ✅ 无需配置
- ✅ 端口固定为 18791

---

### **2. SmartHomeProvider - 无需 ServiceManager**

```dart
class SmartHomeProvider extends ChangeNotifier {
  final HomeOctoClient _client;

  SmartHomeProvider({HomeOctoClient? client})
    : _client = client ?? HomeOctoClient() {
    _init();
  }
}
```

**优势**:
- ✅ 不依赖 ServiceManager
- ✅ 构造函数简单
- ✅ 支持注入自定义客户端（用于测试）

---

### **3. SmartHomePage - 直接创建**

```dart
class _SmartHomePageState extends State<SmartHomePage> {
  late SmartHomeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SmartHomeProvider();  // ← 直接创建，无需参数
    _initConnection();
  }
}
```

**优势**:
- ✅ 无需从 context 读取 ServiceManager
- ✅ 代码更简洁

---

## 📋 WebSocket 端点

### **固定端口分配**

```
18790 → Chat (AI 助手)
  └─ ws://127.0.0.1:18790/pico/ws?session_id=xxx

18791 → Device Control (智能设备)
  └─ ws://127.0.0.1:18791/home/ws

18800 → Web 控制台
  └─ http://127.0.0.1:18800
```

**说明**:
- ✅ Chat 固定使用 18790
- ✅ Device Control 固定使用 18791
- ✅ Web 控制台固定使用 18800
- ✅ 所有端口都是硬编码，无需配置

---

## 🗑️ DeviceControlWebSocket 处理

### **建议：直接删除**

由于：
1. 功能与 HomeOctoClient 完全重叠
2. 未被任何页面使用
3. 端口硬编码（不支持修改）
4. 缺少自动重连机制

**删除文件**:
- `lib/src/core/device_control_ws.dart`
- `docs/DEVICE_CONTROL_WS.md`
- `docs/DEVICE_CONTROL_WS_OPTIMIZATION.md`

---

## ✅ 总结

### **简化前后对比**

| 特性 | 简化前 | 简化后 |
|------|--------|--------|
| **端口配置** | 从 ServiceManager 读取 | ✅ 硬编码 18791 |
| **ServiceManager 依赖** | 需要注入 | ✅ 无需依赖 |
| **构造函数复杂度** | 需要传参 | ✅ 无参数 |
| **代码行数** | 更多 | ✅ 更少 |
| **可维护性** | 复杂 | ✅ 简单 |

### **核心改动**

1. ✅ **HomeOctoClient**: 移除构造函数参数，使用静态常量
2. ✅ **SmartHomeProvider**: 移除 ServiceManager 依赖
3. ✅ **SmartHomePage**: 直接创建 Provider，无需传参
4. ✅ **ServiceManager**: 移除 gatewayPort 字段

### **端口分配**

- **18790**: Chat (AI 助手) - 硬编码
- **18791**: Device Control (智能设备) - 硬编码
- **18800**: Web 控制台 - 可配置

现在架构更简单、更清晰了！🎉
