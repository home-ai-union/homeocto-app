import 'package:flutter/material.dart';
import '../../core/smart_home_api_service.dart';

/// 小米智能家居页面
class XiaomiPage extends StatefulWidget {
  const XiaomiPage({super.key});

  @override
  State<XiaomiPage> createState() => _XiaomiPageState();
}

class _XiaomiPageState extends State<XiaomiPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _verifyController = TextEditingController();

  final SmartHomeApiService _api = SmartHomeApiService();

  bool _isLoggingIn = false;
  bool _isSyncingHomes = false;
  bool _isSyncingDevices = false;
  bool _isGeneratingOps = false;

  String? _error;
  String? _userId;
  bool _isLoggedIn = false;
  String _loginStep = 'login'; // login, captcha, verify
  String? _captchaImage;
  String? _verifyTarget;
  String? _verifyType;

  List<Map<String, dynamic>> _homes = [];
  String? _selectedHomeId;
  List<Map<String, dynamic>> _devices = [];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _verifyController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = '请输入用户名和密码';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _error = null;
    });

    try {
      final result = await _api.xiaomiLogin(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (result['success'] == true || result['logged_in'] == true) {
        // 登录成功，获取状态
        final status = await _api.getXiaomiStatus();
        setState(() {
          _isLoggedIn = true;
          _userId = status['user_id'];
          _loginStep = 'login';
          _passwordController.clear();
        });
      } else {
        // 需要验证码或二次验证
        setState(() {
          _error = result['error'];
          if (result['captcha'] != null) {
            _loginStep = 'captcha';
            _captchaImage = result['captcha'];
          } else if (result['verify_phone'] != null) {
            _loginStep = 'verify';
            _verifyTarget = result['verify_phone'];
            _verifyType = 'phone';
          } else if (result['verify_email'] != null) {
            _loginStep = 'verify';
            _verifyTarget = result['verify_email'];
            _verifyType = 'email';
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = '登录失败: $e';
        _loginStep = 'login';
      });
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _handleCaptcha() async {
    if (_captchaController.text.isEmpty) {
      setState(() {
        _error = '请输入验证码';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _error = null;
    });

    try {
      // TODO: 调用验证码验证API
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isLoggedIn = true;
        _loginStep = 'login';
        _captchaController.clear();
      });
    } catch (e) {
      setState(() {
        _error = '验证码验证失败: $e';
      });
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _handleVerify() async {
    if (_verifyController.text.isEmpty) {
      setState(() {
        _error = '请输入验证码';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _error = null;
    });

    try {
      // TODO: 调用二次验证API
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isLoggedIn = true;
        _loginStep = 'login';
        _verifyController.clear();
      });
    } catch (e) {
      setState(() {
        _error = '验证失败: $e';
      });
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _api.xiaomiLogout();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      setState(() {
        _isLoggedIn = false;
        _userId = null;
        _homes = [];
        _selectedHomeId = null;
        _devices = [];
      });
    }
  }

  Future<void> _handleReset() {
    setState(() {
      _loginStep = 'login';
      _captchaController.clear();
      _verifyController.clear();
      _error = null;
    });
    return Future.value();
  }

  Future<void> _handleSyncHomes() async {
    setState(() {
      _isSyncingHomes = true;
      _error = null;
    });

    try {
      // 调用WebSocket同步家庭
      final result = await _api.executeDeviceOperation(
        fromId: '',
        from: 'xiaomi',
        ops: 'sync_homes',
      );

      if (result['success'] == true) {
        // 同步成功后，设备列表会自动更新
        // 这里可以添加获取家庭列表的逻辑
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

    // 加载设备
    await _handleSyncDevices();
  }

  Future<void> _handleSyncDevices() async {
    if (_selectedHomeId == null) return;

    setState(() {
      _isSyncingDevices = true;
      _error = null;
    });

    try {
      // 调用WebSocket同步设备
      final result = await _api.executeDeviceOperation(
        fromId: _selectedHomeId!,
        from: 'xiaomi',
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
      // 调用批量分析设备（异步执行）
      final result = await _api.batchAnalyzeDevicesAsync(brand: 'xiaomi');

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

  Widget _buildLoginForm() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '小米账号登录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '使用小米账号授权访问智能家居设备',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入小米账号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoggingIn ? null : _handleLogin,
                child: _isLoggingIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptchaForm() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '验证码',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '请输入图片中的验证码',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_captchaImage != null)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Placeholder(
                    fallbackHeight: 100,
                    fallbackWidth: 200,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _captchaController,
              decoration: const InputDecoration(
                labelText: '验证码',
                hintText: '请输入验证码',
                border: OutlineInputBorder(),
              ),
              maxLength: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : _handleCaptcha,
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('提交'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleReset,
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyForm() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '二次验证',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _verifyType == 'phone'
                  ? '验证码已发送至 $_verifyTarget'
                  : '验证码已发送至邮箱 $_verifyTarget',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _verifyTarget ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _verifyController,
              decoration: const InputDecoration(
                labelText: '验证码',
                hintText: '请输入验证码',
                border: OutlineInputBorder(),
              ),
              maxLength: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : _handleVerify,
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('提交'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleReset,
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection() {
    if (_isLoggedIn) {
      return Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              if (_userId != null) ...[
                const Text(
                  '用户ID:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                Text(
                  _userId!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: const Text('退出登录', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (_loginStep == 'captcha') {
      return _buildCaptchaForm();
    }
    if (_loginStep == 'verify') {
      return _buildVerifyForm();
    }
    return _buildLoginForm();
  }

  Widget _buildHomeSection() {
    if (!_isLoggedIn) return const SizedBox.shrink();

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
    if (!_isLoggedIn || _selectedHomeId == null) return const SizedBox.shrink();

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
            SliverAppBar(title: const Text('小米智能家居'), floating: true),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAuthSection(),
                  if (_isLoggedIn) _buildHomeSection(),
                  if (_isLoggedIn) _buildDeviceSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
