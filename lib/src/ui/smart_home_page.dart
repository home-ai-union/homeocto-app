import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/smart_home_provider.dart';
import '../core/homeocto_client.dart';

/// 智能家居管理页面
class SmartHomePage extends StatefulWidget {
  const SmartHomePage({super.key});

  @override
  State<SmartHomePage> createState() => _SmartHomePageState();
}

class _SmartHomePageState extends State<SmartHomePage> {
  late SmartHomeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SmartHomeProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              _buildAppBar(),
              // 连接状态条
              _buildConnectionStatus(),
              // 设备列表
              Expanded(child: _buildDeviceList()),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部应用栏
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(31),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Smart Home',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // 刷新按钮
          Consumer<SmartHomeProvider>(
            builder: (context, provider, _) {
              return IconButton(
                onPressed: provider.isConnected
                    ? provider.reconnect
                    : provider.connect,
                icon: Icon(provider.isLoading ? Icons.refresh : Icons.sync),
                tooltip: provider.isConnected ? 'Refresh' : 'Connect',
              );
            },
          ),
        ],
      ),
    );
  }

  /// 连接状态条
  Widget _buildConnectionStatus() {
    return Consumer<SmartHomeProvider>(
      builder: (context, provider, _) {
        final isConnected = provider.isConnected;
        final isConnecting =
            provider.connectionState == ConnectionState.connecting;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isConnected
              ? Colors.green.withAlpha(20)
              : isConnecting
              ? Colors.orange.withAlpha(20)
              : Colors.red.withAlpha(20),
          child: Row(
            children: [
              Icon(
                isConnected
                    ? Icons.check_circle
                    : isConnecting
                    ? Icons.hourglass_empty
                    : Icons.error,
                size: 16,
                color: isConnected
                    ? Colors.green
                    : isConnecting
                    ? Colors.orange
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected
                    ? 'Connected'
                    : isConnecting
                    ? 'Connecting...'
                    : 'Disconnected',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected
                      ? Colors.green
                      : isConnecting
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              if (!isConnected && !isConnecting)
                TextButton(
                  onPressed: provider.connect,
                  child: const Text(
                    'Reconnect',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 设备列表
  Widget _buildDeviceList() {
    return Consumer<SmartHomeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.devices.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.signal_wifi_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(provider.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: provider.reconnect,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No devices connected'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddDeviceDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Device'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.devices.length,
          itemBuilder: (context, index) {
            final device = provider.devices[index];
            return _buildDeviceCard(device, provider);
          },
        );
      },
    );
  }

  /// 设备卡片
  Widget _buildDeviceCard(
    Map<String, dynamic> device,
    SmartHomeProvider provider,
  ) {
    final name = device['name'] ?? 'Unknown Device';
    final type = device['type'] ?? 'unknown';
    final isOnline = device['online'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _getDeviceIcon(type),
          color: isOnline
              ? Theme.of(context).colorScheme.secondary
              : Colors.grey,
        ),
        title: Text(name),
        subtitle: Text(
          '${_getDeviceTypeLabel(type)} - ${isOnline ? "Online" : "Offline"}',
        ),
        trailing: Switch(
          value: device['enabled'] ?? false,
          onChanged: isOnline
              ? (value) => provider.handleDeviceAction(device['id'], 'toggle', {
                  'enabled': value,
                })
              : null,
        ),
        onTap: () => _showDeviceDetails(context, device, provider),
      ),
    );
  }

  /// 获取设备图标
  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
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

  /// 获取设备类型标签
  String _getDeviceTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'light':
        return 'Light';
      case 'switch':
        return 'Switch';
      case 'sensor':
        return 'Sensor';
      case 'camera':
        return 'Camera';
      case 'thermostat':
        return 'Thermostat';
      default:
        return 'Device';
    }
  }

  /// 显示设备详情
  void _showDeviceDetails(
    BuildContext context,
    Map<String, dynamic> device,
    SmartHomeProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(device['name'] ?? 'Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${_getDeviceTypeLabel(device['type'] ?? "unknown")}'),
            Text('Status: ${device['online'] ?? false ? "Online" : "Offline"}'),
            if (device.containsKey('last_seen'))
              Text('Last seen: ${device['last_seen']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              provider.removeDevice(device['id']);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 显示添加设备对话框
  void _showAddDeviceDialog(BuildContext context, SmartHomeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Device'),
        content: const Text(
          'Device discovery and pairing will be implemented here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 实现设备添加逻辑
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
