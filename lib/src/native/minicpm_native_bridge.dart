import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter bridge to MiniCPM-V native Android Activities.
///
/// Uses the existing PicoClaw MethodChannel to launch native Activities
/// for model management and AI chat.
class MiniCPMNativeBridge {
  static const _channel = MethodChannel('com.homeai.homeocto/picoclaw');

  /// Opens the MiniCPM-V Model Manager Activity (model download/switch).
  ///
  /// Returns `true` if the Activity was launched successfully.
  static Future<bool> openModelManager() async {
    try {
      await _channel.invokeMethod('openModelManager');
      return true;
    } catch (e) {
      debugPrint('MiniCPMBridge.openModelManager failed: $e');
      return false;
    }
  }

  /// Opens the MiniCPM-V Chat Activity (local AI conversation).
  ///
  /// Returns `true` if the Activity was launched successfully.
  static Future<bool> openMiniCPMChat() async {
    try {
      await _channel.invokeMethod('openMiniCPMChat');
      return true;
    } catch (e) {
      debugPrint('MiniCPMBridge.openMiniCPMChat failed: $e');
      return false;
    }
  }
}
