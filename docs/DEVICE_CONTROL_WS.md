# Device Control WebSocket 使用指南

## 概述

`DeviceControlWebSocket` 用于连接到 `libpicoclaw.so` 提供的设备控制端点：
- **URL**: `ws://127.0.0.1:18791/home/ws`
- **Token**: `picoclaw-android-local`（与 Chat 端点相同）

## 快速开始

### 1. 基本使用

```dart
import 'package:homeocto_app/src/core/device_control_ws.dart';

// 连接
await deviceControlWS.connect();

// 发送消息
deviceControlWS.sendMessage({
  'type': 'device.control',
  'device_id': 'light-001',
  'action': 'turn_on',
});

// 监听消息
deviceControlWS.onMessage((message) {
  print('Received: $message');
});

// 断开连接
await deviceControlWS.disconnect();
```

### 2. 完整示例

```dart
class MyDeviceController extends StatefulWidget {
  @override
  State<MyDeviceController> createState() => _MyDeviceControllerState();
}

class _MyDeviceControllerState extends State<MyDeviceController> {
  @override
  void initState() {
    super.initState();
    _setupWebSocket();
  }
  
  void _setupWebSocket() {
    // 监听连接状态
    deviceControlWS.onStatus((connected) {
      print('Connected: $connected');
    });
    
    // 监听消息
    deviceControlWS.onMessage((message) {
      final type = message['type'];
      switch (type) {
        case 'device.status':
          print('Device status: ${message['status']}');
          break;
        case 'device.event':
          print('Device event: ${message['event']}');
          break;
        case 'error':
          print('Error: ${message['message']}');
          break;
      }
    });
  }
  
  Future<void> controlDevice(String deviceId, String action) async {
    try {
      await deviceControlWS.connect();
      
      deviceControlWS.sendMessage({
        'type': 'device.control',
        'device_id': deviceId,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed: $e');
    }
  }
  
  @override
  void dispose() {
    // 不断开连接（可能在其他地方使用）
    super.dispose();
  }
}
```

### 3. 发送并等待响应

```dart
try {
  final response = await deviceControlWS.sendAndWait(
    {
      'type': 'device.query',
      'device_id': 'light-001',
    },
    timeout: Duration(seconds: 10),
  );
  
  print('Response: $response');
} catch (e) {
  print('Timeout or error: $e');
}
```

## API 参考

### 连接管理

| 方法 | 说明 |
|------|------|
| `connect()` | 连接到 WebSocket |
| `disconnect()` | 断开连接 |
| `isConnected` | 获取连接状态 |

### 消息发送

| 方法 | 说明 |
|------|------|
| `sendMessage(message)` | 发送消息（不等待响应） |
| `sendAndWait(message, timeout)` | 发送消息并等待响应 |

### 事件监听

| 方法 | 说明 |
|------|------|
| `onMessage(handler)` | 添加消息处理器 |
| `offMessage(handler)` | 移除消息处理器 |
| `onStatus(handler)` | 添加状态处理器 |
| `offStatus(handler)` | 移除状态处理器 |

## 消息格式

### 发送消息示例

#### 控制设备
```json
{
  "type": "device.control",
  "device_id": "light-001",
  "action": "turn_on",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

#### 查询状态
```json
{
  "type": "device.query",
  "device_id": "light-001"
}
```

#### 订阅事件
```json
{
  "type": "device.subscribe",
  "device_id": "light-001",
  "events": ["status_change", "error"]
}
```

### 接收消息示例

#### 设备状态
```json
{
  "type": "device.status",
  "device_id": "light-001",
  "status": "on",
  "brightness": 80
}
```

#### 设备事件
```json
{
  "type": "device.event",
  "device_id": "light-001",
  "event": "temperature_change",
  "data": {"temperature": 25.5}
}
```

#### 错误消息
```json
{
  "type": "error",
  "message": "Device not found",
  "code": 404
}
```

## 完整示例页面

参考 `lib/src/ui/device_control_page.dart`，这是一个完整的设备控制页面示例，包含：
- 连接/断开按钮
- 设备控制按钮
- 实时日志显示
- 连接状态指示

## 注意事项

1. **单例模式**: `deviceControlWS` 是单例，可以在多个页面共享
2. **自动获取 Token**: 会自动从 `PicoClawChannel` 获取 token
3. **连接状态**: 使用 `onStatus` 监听连接状态变化
4. **错误处理**: 所有方法都有 try-catch 错误处理
5. **资源释放**: 在 `dispose` 中不需要断开连接（除非确定不再使用）

## 与 Chat WebSocket 的区别

| 特性 | Chat WS | Device Control WS |
|------|---------|-------------------|
| **端口** | 18790 | 18791 |
| **路径** | `/pico/ws` | `/home/ws` |
| **参数** | `?session_id=xxx` | 无参数 |
| **Token** | 相同 | 相同 |
| **协议** | Pico Protocol | Pico Protocol |
