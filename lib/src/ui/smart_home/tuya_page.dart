import 'package:flutter/material.dart';
import '../../core/smart_home_api_service.dart';

/// 涂鸦智能家居页面
class TuyaPage extends StatefulWidget {
  const TuyaPage({super.key});

  @override
  State<TuyaPage> createState() => _TuyaPageState();
}

class _TuyaPageState extends State<TuyaPage> {
  final _tokenController = TextEditingController();
  final _regionController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final SmartHomeApiService _api = SmartHomeApiService();

  bool _isSavingToken = false;
  bool _isLoggingIn = false;
  bool _isSyncingHomes = false;
  bool _isSyncingDevices = false;
  bool _isGeneratingOps = false;

  String? _tokenError;
  String? _loginError;
  String? _error;

  bool _isTokenConnected = false;
  bool _isCredentialsConnected = false;
  String? _authType;

  List<Map<String, dynamic>> _regions = [
    {'name': 'AY', 'description': '亚洲'},
    {'name': 'AZ', 'description': '美洲'},
    {'name': 'EU', 'description': '欧洲'},
    {'name': 'IN', 'description': '印度'},
  ];
  String? _selectedRegion;

  List<Map<String, dynamic>> _homes = [];
  String? _selectedHomeId;
  List<Map<String, dynamic>> _devices = [];

  @override
  void dispose() {
    _tokenController.dispose();
    _regionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // 加载区域列表
      final regionsData = await _api.getTuyaRegions();
      if (regionsData['regions'] != null) {
        setState(() {
          _regions = List<Map<String, dynamic>>.from(regionsData['regions']);
        });
      }

      // 加载状态
      final status = await _api.getTuyaStatus();
      setState(() {
        _isTokenConnected = status['auth_type'] == 'token';
        _isCredentialsConnected = status['auth_type'] == 'credentials';
        _authType = status['auth_type'];
        if (status['region'] != null) {
          _selectedRegion = status['region'];
        }
      });
    } catch (e) {
      debugPrint('Failed to load initial data: $e');
    }
  }

  Future<void> _handleSaveToken() async {
    if (_tokenController.text.trim().isEmpty) {
      setState(() {
        _tokenError = '请输入Token';
      });
      return;
    }

    setState(() {
      _isSavingToken = true;
      _tokenError = null;
    });

    try {
      final result = await _api.saveTuyaToken(
        token: _tokenController.text.trim(),
      );

      if (result['success'] == true) {
        setState(() {
          _isTokenConnected = true;
          _authType = 'token';
          _tokenController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token保存成功'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        setState(() {
          _tokenError = result['error'] ?? '保存Token失败';
        });
      }
    } catch (e) {
      setState(() {
        _tokenError = '保存Token失败: $e';
      });
    } finally {
      setState(() {
        _isSavingToken = false;
      });
    }
  }

  Future<void> _handleDeleteToken() async {
    try {
      await _api.deleteTuyaToken();
      setState(() {
        _isTokenConnected = false;
        _authType = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除Token失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_selectedRegion == null ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _loginError = '请填写完整信息';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      final result = await _api.tuyaLogin(
        region: _selectedRegion!,
        username: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (result['success'] == true) {
        setState(() {
          _isCredentialsConnected = true;
          _authType = 'credentials';
          _emailController.clear();
          _passwordController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功'), duration: Duration(seconds: 1)),
        );
      } else {
        setState(() {
          _loginError = result['error'] ?? '登录失败';
        });
      }
    } catch (e) {
      setState(() {
        _loginError = '登录失败: $e';
      });
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _api.tuyaLogout();
      setState(() {
        _isCredentialsConnected = false;
        _authType = null;
      });
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<void> _handleDeleteCredentials() async {
    try {
      await _api.deleteTuyaCredentials();
      setState(() {
        _isCredentialsConnected = false;
        _authType = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除凭证失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSyncHomes() async {
    setState(() {
      _isSyncingHomes = true;
      _error = null;
    });

    try {
      final result = await _api.executeDeviceOperation(
        fromId: '',
        from: 'tuya',
        ops: 'sync_homes',
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('家庭同步成功'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '同步家庭失败: $e';
      });
    } finally {
      setState(() {
        _isSyncingHomes = false;
      });
    }
  }

  Future<void> _handleSelectHome(String homeId) async {
    setState(() {
      _selectedHomeId = homeId;
    });

    await _handleSyncDevices();
  }

  Future<void> _handleSyncDevices() async {
    if (_selectedHomeId == null) return;

    setState(() {
      _isSyncingDevices = true;
      _error = null;
    });

    try {
      final result = await _api.executeDeviceOperation(
        fromId: _selectedHomeId!,
        from: 'tuya',
        ops: 'sync_devices',
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设备同步成功'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '同步设备失败: $e';
      });
    } finally {
      setState(() {
        _isSyncingDevices = false;
      });
    }
  }

  Future<void> _handleGenerateOps() async {
    if (_selectedHomeId == null) return;

    setState(() {
      _isGeneratingOps = true;
    });

    try {
      final result = await _api.batchAnalyzeDevicesAsync(brand: 'tuya');

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '分析已启动'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动分析失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isGeneratingOps = false;
      });
    }
  }

  Widget _buildAuthSection() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '授权认证',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Token认证
            _buildTokenAuth(),
            const Divider(height: 32),
            // 账号密码认证
            _buildCredentialsAuth(),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Token认证',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (_isTokenConnected)
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              const Text('已连接 (Token)', style: TextStyle(fontSize: 12)),
              const Spacer(),
              TextButton(
                onPressed: _handleDeleteToken,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Text('删除Token', style: TextStyle(fontSize: 12)),
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        hintText: '请输入Token',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      obscureText: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSavingToken ? null : _handleSaveToken,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: _isSavingToken
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
              if (_tokenError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _tokenError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildCredentialsAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '账号登录',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (_isCredentialsConnected)
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(_selectedRegion ?? '', style: const TextStyle(fontSize: 12)),
              const Spacer(),
              OutlinedButton(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Text('退出', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _handleDeleteCredentials,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  foregroundColor: Colors.red,
                ),
                child: const Text('删除凭证', style: TextStyle(fontSize: 12)),
              ),
            ],
          )
        else
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '海外用户请选择对应区域',
                  style: TextStyle(fontSize: 11, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                decoration: const InputDecoration(
                  hintText: '选择区域',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _regions
                    .map(
                      (region) => DropdownMenuItem<String>(
                        value: region['name'] as String,
                        child: Text(
                          '${region['description']} (${region['name']})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: '邮箱',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        hintText: '密码',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoggingIn ? null : _handleLogin,
                  child: _isLoggingIn
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
              ),
              if (_loginError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _loginError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildHomeSection() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '家庭管理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isSyncingHomes ? null : _handleSyncHomes,
                  icon: _isSyncingHomes
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: const Text('同步家庭'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_homes.isEmpty)
              const Text(
                '暂无家庭，请点击同步家庭',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              ..._homes.map(
                (home) => RadioListTile<String>(
                  title: Text(home['name']),
                  value: home['id'],
                  groupValue: _selectedHomeId,
                  onChanged: (value) => _handleSelectHome(value!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection() {
    if (_selectedHomeId == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '设备列表',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isSyncingDevices ? null : _handleSyncDevices,
                  icon: _isSyncingDevices
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: const Text('同步设备'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isGeneratingOps ? null : _handleGenerateOps,
                  icon: _isGeneratingOps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('生成操作'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_devices.isEmpty)
              const Text(
                '暂无设备，请点击同步设备',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              ..._devices.map(
                (device) => ListTile(
                  leading: Icon(_getDeviceIcon(device['type'])),
                  title: Text(device['name']),
                  subtitle: Text(_getDeviceTypeLabel(device['type'])),
                  trailing: Icon(
                    device['online'] ? Icons.check_circle : Icons.cancel,
                    color: device['online'] ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type?.toLowerCase()) {
      case 'light':
        return Icons.lightbulb;
      case 'switch':
        return Icons.toggle_on;
      case 'sensor':
        return Icons.sensors;
      case 'camera':
        return Icons.camera_alt;
      case 'thermostat':
        return Icons.thermostat;
      default:
        return Icons.devices_other;
    }
  }

  String _getDeviceTypeLabel(String type) {
    switch (type?.toLowerCase()) {
      case 'light':
        return '灯具';
      case 'switch':
        return '开关';
      case 'sensor':
        return '传感器';
      case 'camera':
        return '摄像头';
      case 'thermostat':
        return '温控器';
      default:
        return '设备';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(title: const Text('涂鸦智能家居'), floating: true),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAuthSection(),
                  _buildHomeSection(),
                  _buildDeviceSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
