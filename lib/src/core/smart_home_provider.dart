import 'package:flutter/foundation.dart';
import 'homeocto_client.dart';

/// 智能家居状态管理器
/// 管理设备列表、连接状态和设备操作
class SmartHomeProvider extends ChangeNotifier {
  final HomeOctoClient _client;

  ConnectionState _connectionState = ConnectionState.disconnected;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  ConnectionState get connectionState => _connectionState;
  List<Map<String, dynamic>> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _connectionState == ConnectionState.connected;

  SmartHomeProvider({HomeOctoClient? client})
    : _client = client ?? HomeOctoClient() {
    _init();
  }

  /// 初始化（参考 Chat 页面的消息监听机制）
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

  /// 连接服务器（参考 Chat 页面的连接逻辑）
  Future<void> connect() async {
    debugPrint('[SmartHomeProvider] Connecting to device control WebSocket');
    try {
      await _client.connect();
    } catch (e) {
      debugPrint('[SmartHomeProvider] Connection failed: $e');
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _client.disconnect();
  }

  /// 重新连接
  Future<void> reconnect() async {
    await _client.disconnect();
    await _client.connect();
  }

  /// 加载设备列表
  Future<void> _loadDevices() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[SmartHomeProvider] Loading devices from API');
      // 尝试从 HTTP API 获取设备列表
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
      _error = '加载设备失败: $e';
      _devices = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 处理设备操作
  Future<void> handleDeviceAction(
    String deviceId,
    String action, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      await _client.post(
        '/api/devices/$deviceId/action',
        body: {'action': action, ...?params},
      );
    } catch (e) {
      _error = 'Action failed: $e';
      notifyListeners();
    }
  }

  /// 添加设备
  Future<void> addDevice(Map<String, dynamic> deviceData) async {
    try {
      await _client.post('/api/devices', body: deviceData);
      await _loadDevices(); // 重新加载
    } catch (e) {
      _error = 'Failed to add device: $e';
      notifyListeners();
    }
  }

  /// 删除设备
  Future<void> removeDevice(String deviceId) async {
    try {
      await _client.delete('/api/devices/$deviceId');
      _devices.removeWhere((d) => d['id'] == deviceId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove device: $e';
      notifyListeners();
    }
  }

  /// 处理来自服务器的实时消息
  void _handleServerMessage(Map<String, dynamic> message) {
    final type = message['type'];

    switch (type) {
      case 'device_update':
        _updateDevice(message['device']);
        break;
      case 'device_added':
        _devices.add(message['device'] as Map<String, dynamic>);
        notifyListeners();
        break;
      case 'device_removed':
        _devices.removeWhere((d) => d['id'] == message['device_id']);
        notifyListeners();
        break;
      case 'error':
        _error = message['message'];
        notifyListeners();
        break;
    }
  }

  /// 更新单个设备信息
  void _updateDevice(Map<String, dynamic> updatedDevice) {
    final index = _devices.indexWhere((d) => d['id'] == updatedDevice['id']);
    if (index != -1) {
      _devices[index] = updatedDevice;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}
