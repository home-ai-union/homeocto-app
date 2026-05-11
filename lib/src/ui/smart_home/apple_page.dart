import 'package:flutter/material.dart';
import '../../core/smart_home_api_service.dart';

/// 苹果HomeKit智能家居页面
class ApplePage extends StatefulWidget {
  const ApplePage({super.key});

  @override
  State<ApplePage> createState() => _ApplePageState();
}

class _ApplePageState extends State<ApplePage> {
  final _pinController = TextEditingController();

  final SmartHomeApiService _api = SmartHomeApiService();

  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  List<Map<String, dynamic>> _unpairedDevices = [];
  List<Map<String, dynamic>> _pairedDevices = [];

  Map<String, dynamic>? _pairingDevice;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.getHomeKitDevices();

      if (result['sources'] != null) {
        final sources = List<Map<String, dynamic>>.from(result['sources']);
        final unpaired = <Map<String, dynamic>>[];
        final paired = <Map<String, dynamic>>[];

        for (final source in sources) {
          final info = source['info'] ?? '';
          final isPaired = !info.toString().contains('status=1');

          final device = {
            'id': source['id'],
            'name': source['name'],
            'ip': source['location'] ?? '',
            'info': _parseInfoString(info.toString()),
            'paired': isPaired,
          };

          if (isPaired) {
            device['pairedId'] = source['url'];
            paired.add(device);
          } else {
            unpaired.add(device);
          }
        }

        setState(() {
          _unpairedDevices = unpaired;
          _pairedDevices = paired;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载设备失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, String> _parseInfoString(String info) {
    final result = <String, String>{};
    final parts = info.split(' ');

    for (final part in parts) {
      final splitIdx = part.indexOf('=');
      if (splitIdx > 0 && splitIdx < part.length - 1) {
        final key = part.substring(0, splitIdx);
        final value = part.substring(splitIdx + 1);
        result[key] = value;
      }
    }

    return result;
  }

  Future<void> _handlePair(Map<String, dynamic> device) async {
    if (_pinController.text.trim().isEmpty) {
      setState(() {
        _error = '请输入PIN码';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _api.pairHomeKitDevice(
        id: device['id'],
        src: device['ip'],
        pin: _pinController.text.trim(),
      );

      setState(() {
        _pinController.clear();
        _pairingDevice = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配对成功'), duration: Duration(seconds: 1)),
      );

      await _loadDevices();
    } catch (e) {
      setState(() {
        _error = '配对失败: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleUnpair(Map<String, dynamic> device) async {
    final pairedId = device['pairedId'];
    if (pairedId == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await _api.unpairHomeKitDevice(id: pairedId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取消配对成功'), duration: Duration(seconds: 1)),
      );

      await _loadDevices();
    } catch (e) {
      setState(() {
        _error = '取消配对失败: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Widget _buildDeviceCard(Map<String, dynamic> device, bool isPaired) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(device['name'] ?? 'Unknown Device'),
            subtitle: Row(
              children: [
                Text(device['ip'] ?? ''),
                if (device['info']?['status'] != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device['info']['status'] == '1'
                          ? Colors.amber
                          : Colors.green,
                    ),
                  ),
                ],
              ],
            ),
            trailing: isPaired
                ? OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _handleUnpair(device),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('取消配对', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _pairingDevice = device;
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('配对', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...(device['info'] ?? {}).entries
                    .where((e) => e.key != 'status')
                    .take(4)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${entry.key}:',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingDialog() {
    if (_pairingDevice == null) return const SizedBox.shrink();

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '配对设备',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '正在配对: ${_pairingDevice!['name']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN码',
                hintText: '请输入8位PIN码',
                border: OutlineInputBorder(),
              ),
              maxLength: 8,
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
                    onPressed: _isProcessing
                        ? null
                        : () => _handlePair(_pairingDevice!),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('配对'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            setState(() {
                              _pairingDevice = null;
                              _pinController.clear();
                              _error = null;
                            });
                          },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            AppBar(title: const Text('Apple HomeKit')),
            // 描述
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 0),
              child: Text(
                '管理和配对HomeKit设备',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            // 内容
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '未配对设备',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (_unpairedDevices.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(32),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              style: BorderStyle.solid,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '暂无未配对设备',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ..._unpairedDevices.map(
                                          (device) =>
                                              _buildDeviceCard(device, false),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '已配对设备',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (_pairedDevices.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(32),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              style: BorderStyle.solid,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '暂无已配对设备',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ..._pairedDevices.map(
                                          (device) =>
                                              _buildDeviceCard(device, true),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            // 错误提示
            if (_error != null && _pairingDevice == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      // 配对对话框
      persistentFooterButtons: _pairingDevice != null
          ? [SizedBox(width: double.infinity, child: _buildPairingDialog())]
          : null,
    );
  }
}
