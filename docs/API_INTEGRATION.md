# Smart Home 页面 API 集成说明

## 概述

已成功创建4个智能家居页面,并集成了真实的HTTP和WebSocket API调用。

## 文件结构

```
lib/src/
├── core/
│   ├── homeocto_client.dart          # HTTP + WebSocket 客户端
│   ├── smart_home_api_service.dart   # 智能家居统一API服务
│   └── smart_home_provider.dart      # 状态管理Provider
└── ui/
    ├── smart_home_page.dart          # 主导航容器(TabBar)
    └── smart_home/
        ├── xiaomi_page.dart          # 小米页面 ✅ 已集成API
        ├── tuya_page.dart            # 涂鸦页面 ⏳ 待更新
        ├── apple_page.dart           # 苹果页面 ⏳ 待更新
        └── device_control_page.dart  # 设备控制页面 ⏳ 待更新
```

## API调用方式

### 1. HTTP REST API

用于认证、状态查询等简单操作:

```dart
final api = SmartHomeApiService();

// 小米
await api.getXiaomiStatus();
await api.xiaomiLogin(username: '', password: '');
await api.xiaomiLogout();

// 涂鸦  
await api.getTuyaStatus();
await api.tuyaLogin(region: '', username: '', password: '');
await api.saveTuyaToken(token: '');

// HomeKit
await api.getHomeKitDevices();
await api.pairHomeKitDevice(id: '', src: '', pin: '');
```

### 2. WebSocket API

用于设备控制、同步等需要实时通信的操作:

```dart
// 执行设备操作
await api.executeDeviceOperation(
  fromId: 'device_id',
  from: 'xiaomi',
  ops: 'turn_on',
  value: true,
);

// 批量分析设备(异步)
await api.batchAnalyzeDevicesAsync(brand: 'xiaomi');

// 获取设备操作列表
await api.listDeviceOps();

// 清除设备操作
await api.clearDeviceOps(brand: 'xiaomi');
```

## 消息格式

WebSocket消息遵循以下格式:

```json
{
  "type": "message.send",
  "id": "tool-hc_cli-exe-1234567890",
  "session_id": "device-control",
  "payload": {
    "content": "tool:hc_cli {\"brand\":\"xiaomi\",\"method\":\"exe\",\"params\":{...}}",
    "media": []
  }
}
```

响应格式:

```json
{
  "id": "tool-response-tool-hc_cli-exe-1234567890",
  "type": "message.receive",
  "payload": {
    "content": "操作成功"
  }
}
```

## 已完成的集成

### ✅ 小米页面 (xiaomi_page.dart)

- [x] 登录API (`/api/xiaomi/auth`)
- [x] 验证码处理 (401响应)
- [x] 二次验证处理
- [x] 登出API (`/api/xiaomi/logout`)
- [x] 家庭同步 (WebSocket)
- [x] 设备同步 (WebSocket)
- [x] 批量分析设备 (WebSocket异步)

### ⏳ 待更新页面

需要按照小米页面的模式更新以下页面:

1. **涂鸦页面** (tuya_page.dart)
   - Token保存/删除
   - 账号登录/登出
   - 家庭/设备同步
   - 批量分析

2. **苹果页面** (apple_page.dart)
   - 设备发现 (`/api/homekit/discovery`)
   - 设备配对 (`POST /api/homekit`)
   - 取消配对 (`DELETE /api/homekit`)

3. **设备控制页面** (device_control_page.dart)
   - 获取设备列表 (WebSocket `listOps`)
   - 执行设备操作 (WebSocket `exe`)
   - 各种控制类型(bool/int/enum/string/in)

## 更新指南

参考小米页面的实现,更新其他页面的步骤:

1. 导入API服务:
```dart
import '../../core/smart_home_api_service.dart';
```

2. 创建API实例:
```dart
final SmartHomeApiService _api = SmartHomeApiService();
```

3. 替换TODO注释的方法调用:
```dart
// 之前
await Future.delayed(const Duration(seconds: 1));

// 之后
final result = await _api.xxxx(...);
```

4. 处理响应和错误:
```dart
if (result['success'] == true) {
  // 成功处理
} else {
  // 错误处理
}
```

## 服务依赖

⚠️ **重要**: WebSocket连接依赖gateway服务(libhomeocto.so)已启动

- HTTP API: `http://127.0.0.1:18800`
- WebSocket: `ws://127.0.0.1:18801/home/ws`

用户需要先在Dashboard页面启动服务,然后才能使用智能家居功能。

## 测试建议

1. 启动gateway服务
2. 测试HTTP API调用(登录、状态查询)
3. 测试WebSocket连接
4. 测试设备控制命令
5. 验证错误处理和重连机制

## 下一步

1. 更新涂鸦页面使用真实API
2. 更新苹果页面使用真实API
3. 更新设备控制页面使用真实API
4. 添加家庭和设备数据的实际加载逻辑
5. 完善错误提示和用户反馈
