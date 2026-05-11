import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'homeocto_client.dart';

/// 智能家居API服务 - 统一管理所有智能家居品牌的HTTP和WebSocket调用
class SmartHomeApiService {
  static const String _baseUrl = 'http://127.0.0.1:18800';

  final HomeOctoClient _client;

  SmartHomeApiService({HomeOctoClient? client})
    : _client = client ?? HomeOctoClient();

  // ==================== 小米API ====================

  /// 获取小米状态
  Future<Map<String, dynamic>> getXiaomiStatus() async {
    return await _client.get('/api/xiaomi/status');
  }

  /// 小米登录
  Future<Map<String, dynamic>> xiaomiLogin({
    required String username,
    required String password,
  }) async {
    final url = '$_baseUrl/api/xiaomi/auth';
    final response = await http.post(
      Uri.parse(url),
      body: {'username': username, 'password': password},
    );
    return _parseAuthResponse(response);
  }

  /// 小米验证码
  Future<Map<String, dynamic>> xiaomiCaptcha({required String captcha}) async {
    final url = '$_baseUrl/api/xiaomi/auth';
    final response = await http.post(
      Uri.parse(url),
      body: {'captcha': captcha},
    );
    return _parseAuthResponse(response);
  }

  /// 小米二次验证
  Future<Map<String, dynamic>> xiaomiVerify({required String verify}) async {
    final url = '$_baseUrl/api/xiaomi/auth';
    final response = await http.post(Uri.parse(url), body: {'verify': verify});
    return _parseAuthResponse(response);
  }

  /// 小米登出
  Future<Map<String, dynamic>> xiaomiLogout() async {
    return await _client.post('/api/xiaomi/logout');
  }

  // ==================== 涂鸦API ====================

  /// 获取涂鸦区域列表
  Future<Map<String, dynamic>> getTuyaRegions() async {
    return await _client.get('/api/tuya/regions');
  }

  /// 获取涂鸦状态
  Future<Map<String, dynamic>> getTuyaStatus() async {
    return await _client.get('/api/tuya/status');
  }

  /// 涂鸦登录
  Future<Map<String, dynamic>> tuyaLogin({
    required String region,
    required String username,
    required String password,
  }) async {
    return await _client.post(
      '/api/tuya/login',
      body: {'region': region, 'username': username, 'password': password},
    );
  }

  /// 涂鸦登出
  Future<Map<String, dynamic>> tuyaLogout() async {
    return await _client.post('/api/tuya/logout');
  }

  /// 删除涂鸦凭证
  Future<Map<String, dynamic>> deleteTuyaCredentials() async {
    return await _client.delete('/api/tuya/credentials');
  }

  /// 保存涂鸦Token
  Future<Map<String, dynamic>> saveTuyaToken({required String token}) async {
    return await _client.post('/api/tuya/token', body: {'token': token});
  }

  /// 删除涂鸦Token
  Future<Map<String, dynamic>> deleteTuyaToken() async {
    return await _client.delete('/api/tuya/token');
  }

  // ==================== Apple HomeKit API ====================

  /// 获取HomeKit设备列表
  Future<Map<String, dynamic>> getHomeKitDevices() async {
    return await _client.get('/api/homekit/discovery');
  }

  /// 配对HomeKit设备
  Future<void> pairHomeKitDevice({
    required String id,
    required String src,
    required String pin,
  }) async {
    final url = '$_baseUrl/api/homekit';
    await http.post(Uri.parse(url), body: {'id': id, 'src': src, 'pin': pin});
  }

  /// 取消配对HomeKit设备
  Future<void> unpairHomeKitDevice({required String id}) async {
    final url = '$_baseUrl/api/homekit?id=$id';
    await http.delete(Uri.parse(url));
  }

  // ==================== 设备控制API (WebSocket) ====================

  /// 通过WebSocket执行设备操作
  Future<Map<String, dynamic>> executeDeviceOperation({
    required String fromId,
    required String from,
    required String ops,
    dynamic value,
    int timeout = 60000,
  }) async {
    // 构建WebSocket消息
    final messageId =
        'tool-hc_cli-exe-${DateTime.now().millisecondsSinceEpoch}';
    final commandJson = jsonEncode({
      'brand': from,
      'method': 'exe',
      'params': {
        'from_id': fromId,
        'from': from,
        'ops': ops,
        if (value != null) 'value': value,
      },
    });

    final message = {
      'type': 'message.send',
      'id': messageId,
      'session_id': 'device-control',
      'payload': {'content': 'tool:hc_cli $commandJson', 'media': []},
    };

    // 发送消息并等待响应
    return await _sendWebSocketMessage(message, timeout);
  }

  /// 获取设备操作列表
  Future<Map<String, dynamic>> listDeviceOps() async {
    final messageId =
        'tool-hc_cli-listOps-${DateTime.now().millisecondsSinceEpoch}';
    final commandJson = jsonEncode({
      'brand': '',
      'method': 'listOps',
      'params': {},
    });

    final message = {
      'type': 'message.send',
      'id': messageId,
      'session_id': 'device-control',
      'payload': {'content': 'tool:hc_cli $commandJson', 'media': []},
    };

    return await _sendWebSocketMessage(message, 30000);
  }

  /// 批量分析设备（异步）
  Future<Map<String, dynamic>> batchAnalyzeDevicesAsync({
    required String brand,
  }) async {
    final messageId =
        'tool-hc_llm-batchAnalyze-${DateTime.now().millisecondsSinceEpoch}';
    final commandJson = jsonEncode({
      'brand': brand,
      'method': 'batchAnalyzeDevicesAsync',
      'params': {'brand': brand},
    });

    final message = {
      'type': 'message.send',
      'id': messageId,
      'session_id': 'device-control',
      'payload': {'content': 'tool:hc_llm $commandJson', 'media': []},
    };

    // 异步执行，不等待响应
    _client.sendMessage(message);

    return {
      'success': true,
      'message': '设备操作分析已启动，请耐心等待分析完成',
      'fireAndForget': true,
    };
  }

  /// 清除设备操作配置
  Future<Map<String, dynamic>> clearDeviceOps({required String brand}) async {
    final messageId =
        'tool-hc_cli-clearOps-${DateTime.now().millisecondsSinceEpoch}';
    final commandJson = jsonEncode({
      'brand': brand,
      'method': 'clearOps',
      'params': {'brand': brand},
    });

    final message = {
      'type': 'message.send',
      'id': messageId,
      'session_id': 'device-control',
      'payload': {'content': 'tool:hc_cli $commandJson', 'media': []},
    };

    return await _sendWebSocketMessage(message, 30000);
  }

  // ==================== 私有方法 ====================

  /// 发送WebSocket消息并等待响应
  Future<Map<String, dynamic>> _sendWebSocketMessage(
    Map<String, dynamic> message,
    int timeout,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final messageId = message['id'] as String;
    final expectedResponseId = 'tool-response-$messageId';

    // 监听响应
    final subscription = _client.messageStream.listen((data) {
      if (data['id'] == expectedResponseId) {
        completer.complete(data);
      }
    });

    // 发送消息
    _client.sendMessage(message);

    // 设置超时
    Future.delayed(Duration(milliseconds: timeout), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('操作超时'));
      }
    });

    try {
      final response = await completer.future;
      subscription.cancel();
      return response;
    } catch (e) {
      subscription.cancel();
      rethrow;
    }
  }

  /// 解析认证响应（处理401特殊情况）
  Map<String, dynamic> _parseAuthResponse(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      // 401返回登录步骤信息（验证码/二次验证）
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'step': 'login', ...data};
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}

/// 超时异常
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
