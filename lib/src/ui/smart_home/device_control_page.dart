import 'package:flutter/material.dart';
import '../../core/smart_home_api_service.dart';

/// 设备控制页面
class DeviceControlPage extends StatefulWidget {
  const DeviceControlPage({super.key});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  final SmartHomeApiService _api = SmartHomeApiService();

  bool _isLoading = false;
  String? _error;

  List<RoomGroup> _rooms = [];

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
      final result = await _api.listDeviceOps();

      if (result['success'] == true && result['rooms'] != null) {
        final roomsData = List<Map<String, dynamic>>.from(result['rooms']);
        final rooms = <RoomGroup>[];

        for (final roomData in roomsData) {
          final devicesData = List<Map<String, dynamic>>.from(
            roomData['devices'] ?? [],
          );
          final devices = <DeviceWithOps>[];

          for (final deviceData in devicesData) {
            final opsData = List<Map<String, dynamic>>.from(
              deviceData['ops'] ?? [],
            );
            final ops = <DeviceOp>[];

            for (final opData in opsData) {
              ops.add(
                DeviceOp(
                  urn: opData['urn'] ?? '',
                  from: opData['from'] ?? '',
                  ops: opData['ops'] ?? '',
                  paramType: _parseParamType(opData['param_type']),
                  paramValue: opData['param_value'],
                  method: opData['method'] ?? '',
                  methodParam: opData['method_param'] ?? '',
                ),
              );
            }

            devices.add(
              DeviceWithOps(
                fromId: deviceData['from_id'] ?? '',
                from: deviceData['from'] ?? '',
                name: deviceData['name'] ?? 'Unknown',
                type: deviceData['type'] ?? 'unknown',
                urn: deviceData['urn'] ?? '',
                spaceName: deviceData['space_name'] ?? '',
                ops: ops,
              ),
            );
          }

          rooms.add(
            RoomGroup(
              roomName: roomData['room_name'] ?? 'Unknown',
              devices: devices,
            ),
          );
        }

        setState(() {
          _rooms = rooms;
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

  ParamType _parseParamType(String type) {
    switch (type) {
      case 'bool':
        return ParamType.bool;
      case 'int':
        return ParamType.int;
      case 'enum':
        return ParamType.typeEnum;
      case 'string':
        return ParamType.string;
      case 'in':
        return ParamType.typeIn;
      default:
        return ParamType.string;
    }
  }

  Future<void> _executeBoolOp(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
    bool value,
  ) async {
    try {
      final result = await _api.executeDeviceOperation(
        fromId: fromId,
        from: from,
        ops: op.ops,
        value: value,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deviceName} ${value ? "已开启" : "已关闭"}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeIntOp(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
    int value,
  ) async {
    try {
      final result = await _api.executeDeviceOperation(
        fromId: fromId,
        from: from,
        ops: op.ops,
        value: value,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deviceName} ${op.ops} → $value'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeEnumOp(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
    String value,
  ) async {
    try {
      final result = await _api.executeDeviceOperation(
        fromId: fromId,
        from: from,
        ops: op.ops,
        value: value,
      );

      if (result['success'] == true && mounted) {
        final label = (op.paramValue as Map)[value] ?? value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deviceName} ${op.ops} → $label'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeInOp(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
  ) async {
    try {
      final result = await _api.executeDeviceOperation(
        fromId: fromId,
        from: from,
        ops: op.ops,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deviceName} ${op.ops}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBoolControl(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
  ) {
    final isOn = op.paramValue == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(op.ops, style: const TextStyle(fontSize: 14)),
        Switch(
          value: isOn,
          onChanged: (value) =>
              _executeBoolOp(op, fromId, from, deviceName, value),
        ),
      ],
    );
  }

  Widget _buildIntControl(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
  ) {
    final range = _parseRange(op.paramValue);
    final value = range[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(op.ops, style: const TextStyle(fontSize: 14)),
            Text(
              '$value',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        Slider(
          min: range[0].toDouble(),
          max: range[1].toDouble(),
          divisions: range[1] - range[0],
          value: value.toDouble(),
          onChanged: (val) =>
              _executeIntOp(op, fromId, from, deviceName, val.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${range[0]}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              '${range[1]}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnumControl(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
  ) {
    final options = _parseEnumOptions(op.paramValue);
    final value = options.isNotEmpty ? options.keys.first : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(op.ops, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              _executeEnumOp(op, fromId, from, deviceName, val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildInControl(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName, {
    bool compact = false,
  }) {
    if (compact) {
      return OutlinedButton(
        onPressed: () => _executeInOp(op, fromId, from, deviceName),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: Text(op.ops, style: const TextStyle(fontSize: 12)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(op.ops, style: const TextStyle(fontSize: 14)),
        OutlinedButton(
          onPressed: () => _executeInOp(op, fromId, from, deviceName),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: Text(op.ops, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildStringControl(
    DeviceOp op,
    String fromId,
    String from,
    String deviceName,
  ) {
    final controller = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(op.ops, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '输入值...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  // TODO: 执行字符串操作
                  controller.clear();
                }
              },
              child: const Text('发送'),
            ),
          ],
        ),
      ],
    );
  }

  List<int> _parseRange(dynamic paramValue) {
    if (paramValue is String) {
      final parts = paramValue.split('-').map(int.tryParse).toList();
      if (parts.length == 2 && parts[0] != null && parts[1] != null) {
        return [parts[0]!, parts[1]!];
      }
    }
    return [0, 100];
  }

  Map<String, String> _parseEnumOptions(dynamic paramValue) {
    if (paramValue is Map) {
      return paramValue.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBar(title: const Text('设备控制')),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.signal_wifi_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(_error!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadDevices,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _rooms.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('暂无设备'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final room = _rooms[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.roomName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: room.devices.length,
                              itemBuilder: (context, deviceIndex) {
                                final device = room.devices[deviceIndex];
                                return _buildDeviceCard(device);
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DeviceWithOps device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    device.type,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
            Text(
              '${device.from} · ${device.fromId}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // In类型控制（按钮）
                    if (device.ops
                        .where((op) => op.paramType == ParamType.typeIn)
                        .isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: device.ops
                            .where((op) => op.paramType == ParamType.typeIn)
                            .map(
                              (op) => _buildInControl(
                                op,
                                device.fromId,
                                device.from,
                                device.name,
                                compact: true,
                              ),
                            )
                            .toList(),
                      ),
                    // Bool类型控制（开关）
                    if (device.ops
                        .where((op) => op.paramType == ParamType.bool)
                        .isNotEmpty)
                      ...device.ops
                          .where((op) => op.paramType == ParamType.bool)
                          .map(
                            (op) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildBoolControl(
                                op,
                                device.fromId,
                                device.from,
                                device.name,
                              ),
                            ),
                          ),
                    // Enum类型控制（下拉）
                    if (device.ops
                        .where((op) => op.paramType == ParamType.typeEnum)
                        .isNotEmpty)
                      ...device.ops
                          .where((op) => op.paramType == ParamType.typeEnum)
                          .map(
                            (op) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildEnumControl(
                                op,
                                device.fromId,
                                device.from,
                                device.name,
                              ),
                            ),
                          ),
                    // Int类型控制（滑块）
                    if (device.ops
                        .where((op) => op.paramType == ParamType.int)
                        .isNotEmpty)
                      ...device.ops
                          .where((op) => op.paramType == ParamType.int)
                          .map(
                            (op) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildIntControl(
                                op,
                                device.fromId,
                                device.from,
                                device.name,
                              ),
                            ),
                          ),
                    // String类型控制（输入框）
                    if (device.ops
                        .where((op) => op.paramType == ParamType.string)
                        .isNotEmpty)
                      ...device.ops
                          .where((op) => op.paramType == ParamType.string)
                          .map(
                            (op) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildStringControl(
                                op,
                                device.fromId,
                                device.from,
                                device.name,
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
    );
  }
}

/// 设备操作参数类型
enum ParamType { bool, int, typeEnum, string, typeIn }

/// 设备操作
class DeviceOp {
  final String urn;
  final String from;
  final String ops;
  final ParamType paramType;
  final dynamic paramValue;
  final String method;
  final String methodParam;

  DeviceOp({
    required this.urn,
    required this.from,
    required this.ops,
    required this.paramType,
    required this.paramValue,
    required this.method,
    required this.methodParam,
  });
}

/// 设备（带操作）
class DeviceWithOps {
  final String fromId;
  final String from;
  final String name;
  final String type;
  final String urn;
  final String spaceName;
  final List<DeviceOp> ops;

  DeviceWithOps({
    required this.fromId,
    required this.from,
    required this.name,
    required this.type,
    required this.urn,
    required this.spaceName,
    required this.ops,
  });
}

/// 房间分组
class RoomGroup {
  final String roomName;
  final List<DeviceWithOps> devices;

  RoomGroup({required this.roomName, required this.devices});
}
