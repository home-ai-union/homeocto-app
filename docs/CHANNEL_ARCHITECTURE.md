# Channel 架构说明

## 概述

HomeOcto Android 应用使用**单个 MethodChannel** 进行服务控制，通过**两个独立的 WebSocket 端点**处理业务逻辑：

1. **MethodChannel**: 用于服务生命周期管理（启动/停止/状态）
2. **WebSocket 1**: Chat 功能（AI 助手对话）
3. **WebSocket 2**: 智能设备控制（Device Control）

## 架构设计

### 1. MethodChannel（服务控制）

- **Channel Name**: `com.homeai.homeocto/picoclaw`
- **Kotlin 实现**: `PicoClawMethodChannel.kt`
- **Dart 实现**: `lib/src/core/picoclaw_channel.dart`
- **用途**: 仅用于服务生命周期管理和配置获取

#### 主要功能
- 启动/停止 PicoClaw 服务
- 获取服务状态和健康检查
- 获取配置和 Token
- 存储权限管理
- 友盟分析集成

#### 不用于业务数据传输
⚠️ **重要**: MethodChannel **不用于**传输聊天消息或设备控制数据，仅用于服务管理。

---

### 2. WebSocket 端点（业务逻辑）

所有业务数据通过 WebSocket 直接传输到 `libpicoclaw.so`，不经过 MethodChannel。

#### WebSocket 1: Chat（AI 助手对话）

- **URL**: `ws://127.0.0.1:18790/pico/ws?session_id={chatId}`
- **Token**: `picoclaw-android-local`
- **协议**: Pico Protocol（自定义 JSON 格式）
- **用途**: AI 助手聊天功能

##### 消息格式示例

**发送消息:**
```json
{
  "type": "message.send",
  "id": "uuid-v4",
  "session_id": "会话ID",
  "payload": {
    "content": "用户消息内容"
  }
}
```

**接收消息:**
```json
{
  "type": "message.create",
  "payload": {
    "content": "AI 回复内容"
  }
}
```

##### 消息类型
| 方向 | type | 说明 |
|------|------|------|
| **发送** | `message.send` | 用户发送消息 |
| **接收** | `typing.start` | AI 开始思考 |
| **接收** | `typing.stop` | AI 停止思考 |
| **接收** | `message.create` | AI 回复消息 |
| **接收** | `message.update` | 消息更新（流式） |
| **接收** | `error` | 错误信息 |
| **双向** | `ping` / `pong` | 心跳保活 |

---

#### WebSocket 2: Device Control（智能设备控制）

- **URL**: `ws://127.0.0.1:18791/home/ws`
- **Token**: `picoclaw-android-local`（与 Chat 相同）
- **协议**: Pico Protocol（自定义 JSON 格式）
- **用途**: 智能设备管理和控制

##### 连接方式
```dart
final uri = Uri.parse('ws://127.0.0.1:18791/home/ws');
final channel = IOWebSocketChannel.connect(
  uri,
  headers: {'Authorization': 'Bearer $token'},
);
```

##### 参考实现
Web 端参考: `G:\code\homeocto\web\frontend\src\homeocto\api\device-control-websocket.ts`

---

## 架构设计原则

### 职责分离
- **MethodChannel**: 仅用于服务生命周期管理（启动/停止/状态/配置）
- **WebSocket**: 用于所有业务数据传输（聊天消息、设备控制）

### 为什么不用两个 MethodChannel？
1. ✅ **两个 WebSocket 端点由同一个 .so 文件提供** (`libpicoclaw.so`)
2. ✅ **Token 相同** (`picoclaw-android-local`)
3. ✅ **都是 WebSocket 协议**（不经过 MethodChannel）
4. ✅ **PicoClawService 已经启动了这两个服务**

### 单一服务管理
- 只有一个 Service: `PicoClawService`
- 只启动一个二进制文件: `libpicoclaw.so`
- 该二进制文件提供两个 WebSocket 端点 (18790 和 18791)

---

## Dart 端使用示例

### 1. 服务控制（通过 MethodChannel）

```dart
import 'package:homeocto_app/src/core/picoclaw_channel.dart';

// 启动服务
await PicoClawChannel.startService(args: '-public');

// 获取 Token（用于 WebSocket 连接）
final token = await PicoClawChannel.getPicoToken();

// 获取服务状态
final status = await PicoClawChannel.getServiceStatus();
```

### 2. Chat WebSocket 连接

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

// 建立 Chat WebSocket 连接
final chatUri = Uri.parse('ws://127.0.0.1:18790/pico/ws?session_id=$sessionId');
final chatChannel = IOWebSocketChannel.connect(
  chatUri,
  headers: {'Authorization': 'Bearer $token'},
);

// 发送消息
chatChannel.sink.add(jsonEncode({
  'type': 'message.send',
  'id': uuid.v4(),
  'session_id': sessionId,
  'payload': {'content': '你好'},
}));

// 接收消息
chatChannel.stream.listen((data) {
  final msg = jsonDecode(data.toString());
  // 处理消息...
});
```

### 3. Device Control WebSocket 连接

```dart
// 建立设备控制 WebSocket 连接
final deviceUri = Uri.parse('ws://127.0.0.1:18791/home/ws');
final deviceChannel = IOWebSocketChannel.connect(
  deviceUri,
  headers: {'Authorization': 'Bearer $token'},
);

// 发送设备控制命令
deviceChannel.sink.add(jsonEncode({
  'type': 'device.control',
  'payload': {
    'device_id': 'device-123',
    'action': 'turn_on',
  },
}));

// 接收设备状态
deviceChannel.stream.listen((data) {
  final msg = jsonDecode(data.toString());
  // 处理设备状态...
});
```

---

## Kotlin 端注册

在 `MainActivity.kt` 中注册单个 MethodChannel:

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // 仅注册一个 MethodChannel 用于服务控制
    methodChannel = PicoClawMethodChannel(this, flutterEngine)
}
```

---

## 配置文件路径

- **Config**: `{context.filesDir}/picoclaw/config.json`

---

## 服务二进制文件

- **libpicoclaw.so**: 核心网关服务
  - 提供 WebSocket 端点 1: `18790/pico/ws` (Chat)
  - 提供 WebSocket 端点 2: `18791/home/ws` (Device Control)
- **libpicoclaw-web.so**: Web 控制台服务
  - 端口: 18800
  - 自动启动并管理 `libpicoclaw.so`

---

## 注意事项

1. **MethodChannel 仅用于服务控制**: 不要用它传输业务数据（聊天消息、设备控制）
2. **业务数据通过 WebSocket 传输**: 所有聊天和设备控制数据都通过 WebSocket
3. **两个 WebSocket 端点**: 
   - `18790/pico/ws`: Chat（带 session_id 参数）
   - `18791/home/ws`: Device Control（不带 session_id）
4. **Token 相同**: 两个 WebSocket 使用相同的 token (`picoclaw-android-local`)
5. **单一服务**: 只需启动 `PicoClawService`，它会自动启动两个 WebSocket 端点
