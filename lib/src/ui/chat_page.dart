import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 聊天页面 - 启动原生 Android MiniCPM-V Demo Activity
/// 直接复用原生 Android 的聊天和模型下载功能，不重新实现
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const platform = MethodChannel('com.homeocto.app/chat');

  @override
  void initState() {
    super.initState();
    // 页面加载时自动启动原生聊天Activity
    _launchNativeChat();
  }

  Future<void> _launchNativeChat() async {
    try {
      await platform.invokeMethod('openChat');
    } on PlatformException catch (e) {
      debugPrint('Failed to launch native chat: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在打开 AI Chat...'),
          ],
        ),
      ),
    );
  }
}
