import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:homeocto_app/src/ui/chat_message.dart';
import 'package:homeocto_app/src/ui/model_download_page.dart';

/// 本地AI聊天页面 - 使用llama-server HTTP API
class LocalChatPage extends StatefulWidget {
  const LocalChatPage({super.key});

  @override
  State<LocalChatPage> createState() => _LocalChatPageState();
}

class _LocalChatPageState extends State<LocalChatPage> {
  static const _serverHost = '127.0.0.1';
  static const _serverPort = 18792;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  int _messageIdCounter = 1;

  bool _isModelReady = false;
  bool _isGenerating = false;
  String _serverStatus = '正在连接...';

  Timer? _healthCheckTimer;

  @override
  void initState() {
    super.initState();
    _addMessage(const WelcomeMessage());
    _startHealthCheck();
  }

  /// 启动健康检查定时器
  void _startHealthCheck() {
    _checkServerHealth();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkServerHealth(),
    );
  }

  /// 检查服务器健康状态
  Future<void> _checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_serverHost:$_serverPort/health'))
          .timeout(const Duration(seconds: 2));

      if (mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;

        setState(() {
          _isModelReady = status == 'ok';
          _serverStatus = _isModelReady ? '模型已就绪' : '模型未就绪';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isModelReady = false;
          _serverStatus = '服务未启动';
        });
      }
    }
  }

  /// 添加消息
  void _addMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    if (!_isModelReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模型未就绪，请先在模型管理中下载并加载模型')));
      return;
    }

    _messageController.clear();
    _addMessage(UserMessage(id: _messageIdCounter++, text: text));

    // 创建AI消息占位符
    final aiMessageId = _messageIdCounter++;
    _addMessage(AiMessage(id: aiMessageId, text: '', isGenerating: true));

    setState(() => _isGenerating = true);

    try {
      await _streamCompletion(text, aiMessageId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          // 更新AI消息为错误状态
          final index = _messages.indexWhere((m) => m.id == aiMessageId);
          if (index != -1) {
            _messages[index] = AiMessage(
              id: aiMessageId,
              text: '❌ 生成失败: $e',
              isGenerating: false,
            );
          }
        });
      }
    }
  }

  /// 流式补全
  Future<void> _streamCompletion(String prompt, int messageId) async {
    final uri = Uri.parse('http://$_serverHost:$_serverPort/completion');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        'stream': true,
        'n_predict': 2048,
        'temperature': 0.7,
        'top_k': 40,
        'top_p': 0.9,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    // 解析流式响应
    final lines = utf8.decode(response.bodyBytes).split('\n');
    String fullText = '';

    for (final line in lines) {
      if (!mounted) return;

      if (line.startsWith('data: ')) {
        final data = line.substring(6);
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final content = json['content'] as String? ?? '';
          final stop = json['stop'] as bool? ?? false;

          fullText += content;

          // 更新UI
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              _messages[index] = AiMessage(
                id: messageId,
                text: fullText,
                isGenerating: !stop,
              );
            }
            _isGenerating = stop ? false : _isGenerating;
          });
          _scrollToBottom();

          if (stop) break;
        } catch (e) {
          // 跳过解析错误的行
        }
      }
    }
  }

  /// 清空聊天
  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(const WelcomeMessage());
      _isGenerating = false;
    });
  }

  /// 打开模型管理
  void _openModelManager() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ModelDownloadPage()));
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Chat',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          // 服务器状态指示
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_isModelReady ? Colors.green : Colors.orange).withAlpha(
                30,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isModelReady ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _serverStatus,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isModelReady ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          // 模型管理按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '模型管理',
            onPressed: _openModelManager,
          ),
          // 清空聊天
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          // 输入区域
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _isModelReady && !_isGenerating,
                      decoration: InputDecoration(
                        hintText: _isModelReady ? '输入消息...' : '请先加载模型',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: (!_isModelReady || _isGenerating)
                        ? colorScheme.outline
                        : colorScheme.secondary,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: (!_isModelReady || _isGenerating)
                          ? null
                          : _sendMessage,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _isGenerating ? Icons.stop : Icons.send_rounded,
                          color: colorScheme.onSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 消息气泡组件
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message is WelcomeMessage) {
      return _WelcomeBubble();
    } else if (message is UserMessage) {
      return _UserMessageBubble(message: message as UserMessage);
    } else if (message is AiMessage) {
      return _AiMessageBubble(message: message as AiMessage);
    }
    return const SizedBox.shrink();
  }
}

/// 欢迎消息气泡
class _WelcomeBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            '你好！我是本地 AI 助手',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '基于 MiniCPM-V 模型，支持文本对话',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 用户消息气泡
class _UserMessageBubble extends StatelessWidget {
  final UserMessage message;

  const _UserMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(100),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primary.withAlpha(30),
            child: Icon(
              Icons.person_outline,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI消息气泡
class _AiMessageBubble extends StatelessWidget {
  final AiMessage message;

  const _AiMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.secondary.withAlpha(30),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: message.isGenerating && message.text.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在生成...',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(150),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  : SelectableText(
                      message.text,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
