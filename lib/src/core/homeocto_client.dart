import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// HomeOcto 客户端 - 负责与 HomeOcto Go 后端通信
/// 支持 WebSocket 实时通信和 HTTP REST API
class HomeOctoClient {
  static const String _baseUrl = 'http://127.0.0.1:18790';
  static const String _wsUrl = 'ws://127.0.0.1:18790/ws';

  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  final _connectionController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionStream => _connectionController.stream;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// 连接到 WebSocket 服务器
  Future<void> connect() async {
    if (_state == ConnectionState.connected) return;

    _setState(ConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _wsSubscription = _channel!.stream.listen(
        (data) {
          _reconnectAttempts = 0; // 重置重连计数
          if (_state != ConnectionState.connected) {
            _setState(ConnectionState.connected);
          }
          _handleMessage(data);
        },
        onError: (error) {
          _setState(ConnectionState.error);
          _scheduleReconnect();
        },
        onDone: () {
          _setState(ConnectionState.disconnected);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _setState(ConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    await _wsSubscription?.cancel();
    await _channel?.sink.close(status.normalClosure);

    _channel = null;
    _wsSubscription = null;
    _setState(ConnectionState.disconnected);
  }

  /// 发送消息到服务器
  void sendMessage(Map<String, dynamic> message) {
    if (_state == ConnectionState.connected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// HTTP GET 请求
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final url = '$_baseUrl$path';
    final response = await http.get(Uri.parse(url), headers: headers);
    return _parseResponse(response);
  }

  /// HTTP POST 请求
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = '$_baseUrl$path';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  /// HTTP PUT 请求
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = '$_baseUrl$path';
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  /// HTTP DELETE 请求
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final url = '$_baseUrl$path';
    final response = await http.delete(Uri.parse(url), headers: headers);
    return _parseResponse(response);
  }

  /// 处理接收到的消息
  void _handleMessage(dynamic data) {
    try {
      if (data is String) {
        final message = jsonDecode(data) as Map<String, dynamic>;
        _messageController.add(message);
      }
    } catch (e) {
      // 忽略无法解析的消息
    }
  }

  /// 解析 HTTP 响应
  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) return; // 最大重连次数

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // 指数退避

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_state != ConnectionState.connected) {
        connect();
      }
    });
  }

  /// 设置连接状态
  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _connectionController.add(newState);
    }
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _connectionController.close();
    _messageController.close();
  }
}

/// 连接状态枚举
enum ConnectionState { disconnected, connecting, connected, error }
