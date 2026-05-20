package com.homeai.homeocto.llama

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class LlamaMethodChannel(
    private val context: Context,
    flutterEngine: FlutterEngine
) {
    companion object {
        private const val TAG = "LlamaMethodChannel"
        private const val CHANNEL_NAME = "com.homeai.homeocto/llama"
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME
    )

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startLlamaServer" -> {
                    try {
                        val modelPath = call.argument<String>("modelPath")
                            ?: return@setMethodCallHandler result.error("INVALID_ARGS", "modelPath is required", null)
                        val mmprojPath = call.argument<String>("mmprojPath")
                        val port = call.argument<Int>("port") ?: 18900
                        val ctxSize = call.argument<Int>("ctxSize") ?: 2048
                        val threads = call.argument<Int>("threads") ?: 4

                        val params = LlamaServerParams(
                            modelPath = modelPath,
                            mmprojPath = mmprojPath,
                            port = port,
                            ctxSize = ctxSize,
                            threads = threads
                        )

                        LlamaServerService.start(context, params)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }

                "stopLlamaServer" -> {
                    try {
                        LlamaServerService.stop(context)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }

                "getLlamaServerStatus" -> {
                    result.success(mapOf(
                        "isRunning" to LlamaServerService.isRunning,
                        "pid" to LlamaServerService.processId,
                        "lastLog" to LlamaServerService.lastLog,
                        "port" to LlamaServerService.actualPort,
                        "modelPath" to LlamaServerService.currentModelPath
                    ))
                }

                "checkLlamaHealth" -> {
                    Thread {
                        try {
                            val port = LlamaServerService.actualPort
                            if (port == 0) {
                                result.success(mapOf(
                                    "isHealthy" to false,
                                    "status" to "Server not started",
                                    "modelLoaded" to false
                                ))
                                return@Thread
                            }

                            val health = LlamaHealthChecker.check(port = port)
                            result.success(mapOf(
                                "isHealthy" to health.isHealthy,
                                "status" to health.status,
                                "modelLoaded" to health.modelLoaded
                            ))
                        } catch (e: Exception) {
                            result.error("HEALTH_CHECK_FAILED", e.message, null)
                        }
                    }.start()
                }

                "getDefaultModelDir" -> {
                    try {
                        val modelDir = File(
                            context.getExternalFilesDir(null),
                            "llama_models"
                        ).apply {
                            mkdirs()
                        }
                        result.success(modelDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("MODEL_DIR_FAILED", e.message, null)
                    }
                }

                "getLlamaVersion" -> {
                    try {
                        val binaryFile = LlamaBinaryResolver.resolveBinary(context)
                        val pb = ProcessBuilder(binaryFile.absolutePath, "--version")
                            .directory(context.filesDir)
                            .redirectErrorStream(true)

                        val proc = pb.start()
                        val output = proc.inputStream.bufferedReader().readText().trim()
                        proc.waitFor()

                        // Extract version from output
                        val versionRegex = Regex("version:\\s*(\\S+)")
                        val version = versionRegex.find(output)?.groupValues?.get(1) ?: "unknown"
                        result.success(version)
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }

                "downloadModel" -> {
                    try {
                        val modelId = call.argument<String>("modelId")
                            ?: return@setMethodCallHandler result.error("INVALID_ARGS", "modelId is required", null)

                        // TODO: Trigger LlamaModelDownloadService
                        // For now, return not implemented
                        result.error("NOT_IMPLEMENTED", "Model download not yet implemented", null)
                    } catch (e: Exception) {
                        result.error("DOWNLOAD_FAILED", e.message, null)
                    }
                }

                "getDownloadProgress" -> {
                    // TODO: Return download progress from LlamaModelDownloadService
                    result.success(mapOf(
                        "progress" to 0.0,
                        "speed" to 0,
                        "status" to "idle"
                    ))
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
