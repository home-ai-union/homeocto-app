package com.homeai.homeocto

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val LLAMA_CHANNEL = "com.homeai.homeocto/llama"
    }

    private var methodChannel: PicoClawMethodChannel? = null
    private var llamaChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logIncomingIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = PicoClawMethodChannel(this, flutterEngine)
        
        // Setup Llama MethodChannel
        llamaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LLAMA_CHANNEL)
        llamaChannel?.setMethodCallHandler { call, result ->
            handleLlamaMethodCall(call, result)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        logIncomingIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // Android 11+ 需要 MANAGE_EXTERNAL_STORAGE 才能写 Downloads 目录。
        // 若未授予，跳转系统设置页引导用户开启（只弹一次，直到用户授予或主动拒绝）。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            !Environment.isExternalStorageManager()
        ) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                )
            } catch (e: Exception) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        }
    }

    /**
     * Handle Llama MethodChannel calls from Flutter
     */
    private fun handleLlamaMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val modelId = call.argument<String>("modelId")
                if (modelId == null) {
                    result.error("INVALID_ARGS", "modelId is required", null)
                    return
                }
                
                try {
                    // 获取或启动 JniInferenceService
                    var service = com.homeai.homeocto.service.JniInferenceService.instance
                    
                    if (service == null) {
                        // 服务未运行，启动它
                        Log.i(TAG, "JniInferenceService not running, starting...")
                        val intent = Intent(this, com.homeai.homeocto.service.JniInferenceService::class.java).apply {
                            putExtra("port", com.homeai.homeocto.service.JniInferenceService.DEFAULT_PORT)
                        }
                        startForegroundService(intent)
                        
                        // 等待服务初始化（最多等待5秒）
                        var waitTime = 0
                        while (com.homeai.homeocto.service.JniInferenceService.instance == null && waitTime < 5000) {
                            Thread.sleep(200)
                            waitTime += 200
                        }
                        
                        service = com.homeai.homeocto.service.JniInferenceService.instance
                        if (service == null) {
                            Log.e(TAG, "Failed to start JniInferenceService")
                            result.error("SERVICE_START_FAILED", "Service failed to start", null)
                            return
                        }
                        Log.i(TAG, "JniInferenceService started successfully")
                    } else {
                        Log.i(TAG, "JniInferenceService already running")
                    }
                    
                    // 加载选中的模型
                    Log.i(TAG, "Loading model: $modelId")
                    val success = service.loadSelectedModel(modelId)
                    
                    if (success) {
                        Log.i(TAG, "Model loaded successfully: $modelId")
                    } else {
                        Log.w(TAG, "Failed to load model: $modelId")
                    }
                    
                    result.success(success)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to load model: $modelId", e)
                    result.error("LOAD_FAILED", e.message, null)
                }
            }
            
            "modelFilesExist" -> {
                val modelId = call.argument<String>("modelId")
                if (modelId == null) {
                    result.error("INVALID_ARGS", "modelId is required", null)
                    return
                }
                
                try {
                    val service = com.homeai.homeocto.service.JniInferenceService.instance
                    val exists = service?.checkModelFilesExist(modelId) ?: false
                    result.success(exists)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to check model files: $modelId", e)
                    result.error("CHECK_FAILED", e.message, null)
                }
            }
            
            "getLoadedModelId" -> {
                try {
                    val service = com.homeai.homeocto.service.JniInferenceService.instance
                    val loadedModelId = service?.getLoadedModelId()
                    result.success(loadedModelId)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to get loaded model ID", e)
                    result.error("GET_FAILED", e.message, null)
                }
            }
            
            "startService" -> {
                try {
                    // 检查服务是否已在运行
                    val isRunning = com.homeai.homeocto.service.JniInferenceService.instance != null
                    if (isRunning) {
                        Log.i(TAG, "JniInferenceService already running")
                        result.success(true)
                        return
                    }
                    
                    // 启动服务，传递port参数（与 PicoClawService 保持一致）
                    val intent = Intent(this, com.homeai.homeocto.service.JniInferenceService::class.java).apply {
                        putExtra("port", com.homeai.homeocto.service.JniInferenceService.DEFAULT_PORT)
                    }
                    startForegroundService(intent)
                    Log.i(TAG, "JniInferenceService started")
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start service", e)
                    result.error("START_FAILED", e.message, null)
                }
            }
            
            "stopService" -> {
                try {
                    val intent = Intent(this, com.homeai.homeocto.service.JniInferenceService::class.java)
                    stopService(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop service", e)
                    result.error("STOP_FAILED", e.message, null)
                }
            }
            
            "isServiceRunning" -> {
                try {
                    val isRunning = com.homeai.homeocto.service.JniInferenceService.instance != null
                    result.success(isRunning)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to check service status", e)
                    result.error("CHECK_FAILED", e.message, null)
                }
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        methodChannel?.dispose()
        methodChannel = null
        llamaChannel?.setMethodCallHandler(null)
        llamaChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun logIncomingIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme == BuildConfig.PICOCLAW_UMENG_LINK_SCHEME) {
            Log.i(TAG, "Received Umeng link: $data")
        }
    }
}
