import 'package:flutter/material.dart';
import 'smart_home/xiaomi_page.dart';
import 'smart_home/tuya_page.dart';
import 'smart_home/apple_page.dart';
import 'smart_home/device_control_page.dart';

/// 智能家居管理页面 - 导航容器
class SmartHomePage extends StatefulWidget {
  const SmartHomePage({super.key});

  @override
  State<SmartHomePage> createState() => _SmartHomePageState();
}

class _SmartHomePageState extends State<SmartHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标签栏
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withAlpha(31),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.home), text: '小米'),
                  Tab(icon: Icon(Icons.devices), text: '涂鸦'),
                  Tab(icon: Icon(Icons.apple), text: '苹果'),
                  Tab(icon: Icon(Icons.settings_remote), text: '设备控制'),
                ],
              ),
            ),
            // 页面内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  XiaomiPage(),
                  TuyaPage(),
                  ApplePage(),
                  DeviceControlPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
