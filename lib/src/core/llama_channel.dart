import 'package:flutter/services.dart';

/// MethodChannel wrapper for JniInferenceService
/// Provides Flutter interface to llama.cpp inference engine
class LlamaChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.homeai.homeocto/llama',
  );

  /// Load a specific model into JniInferenceService
  ///
  /// Returns true if model was loaded successfully
  static Future<bool> loadModel(String modelId) async {
    try {
      final result = await _channel.invokeMethod<bool>('loadModel', {
        'modelId': modelId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to load model: ${e.message}');
    }
  }

  /// Check if model files exist on device
  ///
  /// Returns true if both GGUF and MMProj files exist
  static Future<bool> modelFilesExist(String modelId) async {
    try {
      final result = await _channel.invokeMethod<bool>('modelFilesExist', {
        'modelId': modelId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check model files: ${e.message}');
    }
  }

  /// Get the currently loaded model ID
  ///
  /// Returns null if no model is loaded
  static Future<String?> getLoadedModelId() async {
    try {
      final result = await _channel.invokeMethod<String?>('getLoadedModelId');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to get loaded model: ${e.message}');
    }
  }

  /// Start JniInferenceService (if not already running)
  static Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startService');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to start service: ${e.message}');
    }
  }

  /// Stop JniInferenceService
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop service: ${e.message}');
    }
  }

  /// Check if JniInferenceService is running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check service status: ${e.message}');
    }
  }
}
