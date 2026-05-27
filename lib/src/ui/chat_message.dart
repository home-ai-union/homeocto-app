import 'dart:ui';

/// 聊天消息基类
abstract class ChatMessage {
  final int id;

  const ChatMessage({required this.id});
}

/// 用户消息
class UserMessage extends ChatMessage {
  final String text;
  final Image? image;
  final String? imageInfo;
  final bool isPrefilling;
  final bool isVideo;

  const UserMessage({
    required super.id,
    required this.text,
    this.image,
    this.imageInfo,
    this.isPrefilling = false,
    this.isVideo = false,
  });
}

/// AI消息
class AiMessage extends ChatMessage {
  final String text;
  final bool isGenerating;

  const AiMessage({
    required super.id,
    required this.text,
    this.isGenerating = false,
  });
}

/// 欢迎卡片消息
class WelcomeMessage extends ChatMessage {
  const WelcomeMessage({super.id = 0});
}
