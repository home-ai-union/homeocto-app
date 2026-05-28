package com.homeai.homeocto.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.app.FlutterApplication
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * Android Service that runs the llama.cpp inference engine with an
 * OpenAI-compatible HTTP API via Ktor embedded server.
 *
 * Endpoints:
 * - GET  /health                    - Health check
 * - POST /v1/chat/completions       - Chat completions (text + images)
 */
class JniInferenceService : Service() {

    companion object {
        private const val TAG = "JniInferenceService"
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "jni_inference_service"
        private const val CHANNEL_NAME = "AI Inference Service"

        // Default HTTP server port
        const val DEFAULT_PORT = 18792
        
        // 日志缓冲区（供 PicoClawService 读取）
        @Volatile
        var lastLog = ""
            private set
        private val logBuffer = StringBuilder()
        private const val MAX_LOG_SIZE = 32 * 1024 // 32KB
        
        // 保存当前运行的实例引用
        @Volatile
        var instance: JniInferenceService? = null
            private set
        
        /**
         * 静态方法：获取日志（供 PicoClawService 调用）
         */
        @JvmStatic
        fun getLog(): String {
            return instance?.getFullLog() ?: ""
        }
    }

    private var server: Any? = null
    private val engine = JniLlamaEngine.instance
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val modelDownloadService = ModelDownloadService()
    
    // 延迟加载模型：仅在首次调用时加载
    @Volatile
    private var isModelLoaded = false
    @Volatile
    private var isModelDownloading = false
    @Volatile
    private var downloadProgress = 0.0f
    @Volatile
    private var selectedModelId: String? = null  // 用户选择的模型ID
    private val modelLoadLock = Any()

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val port = intent?.getIntExtra("port", DEFAULT_PORT) ?: DEFAULT_PORT

        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification("AI Inference Service (standby)"))

        // 尝试加载 native 库，失败则不启动引擎
        JniLlamaEngine.tryLoadNativeLibrary()
        
        // 仅初始化引擎，不加载模型（延迟到首次调用时）
        engine.initialize(this)
        Log.i(TAG, "Engine initialized, model will be loaded on first request")

        // Start HTTP server
        startServer(port)

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        appendLog("JniInferenceService destroying...")
        stopServer()
        engine.destroy()
        serviceScope.cancel()
        appendLog("JniInferenceService destroyed")
        instance = null
    }

    private fun startServer(port: Int) {
        try {
            appendLog("Starting llama HTTP server on port $port...")
            
            server = embeddedServer(Netty, port = port, watchPaths = emptyList()) {
                install(ContentNegotiation) {
                    json(Json {
                        ignoreUnknownKeys = true
                        coerceInputValues = true
                    })
                }

                routing {
                    get("/health") { handleHealth(call) }
                    post("/v1/chat/completions") { handleChatCompletions(call) }
                }
            }.start(wait = false)

            val serverUrl = "http://127.0.0.1:$port"
            appendLog("✓ llama HTTP server started successfully")
            appendLog("🔗 Server URL: $serverUrl")
            Log.i(TAG, "HTTP server started on port $port, URL: $serverUrl")
        } catch (e: Exception) {
            appendLog("✗ Failed to start llama HTTP server: ${e.message}")
            Log.e(TAG, "Failed to start HTTP server", e)
            throw e
        }
    }

    private fun stopServer() {
        try {
            (server as? io.ktor.server.engine.ApplicationEngine)?.stop(
                gracePeriodMillis = 1000,
                timeoutMillis = 2000
            )
            server = null
            appendLog("llama HTTP server stopped")
            Log.i(TAG, "HTTP server stopped")
        } catch (e: Exception) {
            appendLog("Error stopping llama HTTP server: ${e.message}")
            Log.e(TAG, "Error stopping HTTP server", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                android.app.NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "AI inference service running OpenAI-compatible API"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(status: String = "AI Inference Service (standby)"): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, getMainActivityClass()),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Inference Service")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(status: String) {
        try {
            val notification = createNotification(status)
            val manager = getSystemService(android.app.NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update notification", e)
        }
    }

    private fun getMainActivityClass(): Class<*> {
        // Use fixed package name since Kotlin source package doesn't change with applicationId
        return Class.forName("com.homeai.homeocto.MainActivity")
    }

    private fun findModelForPath(modelPath: String): ModelInfo? {
        val fileName = File(modelPath).name
        return ModelInfo.AVAILABLE_MODELS.find { it.ggufFileName == fileName }
    }

    // ===== HTTP Handlers =====

    private suspend fun handleHealth(call: ApplicationCall) {
        val response = HealthResponse(
            status = if (isModelDownloading) "downloading" else if (isModelLoaded) "ok" else "starting",
            modelLoaded = isModelLoaded,
            loadedModelId = selectedModelId,
            modelVersion = engine.getModelVersion(),
            downloadProgress = if (isModelDownloading) downloadProgress else null
        )
        call.respond(response)
    }

    private suspend fun handleChatCompletions(call: ApplicationCall) {
        // 延迟加载模型：首次调用时加载默认模型
        ensureModelLoaded()
        
        val request = call.receive<ChatCompletionRequest>()

        val completionId = "chatcmpl-${UUID.randomUUID()}"
        val created = System.currentTimeMillis() / 1000

        if (request.stream == true) {
            // Streaming response
            call.response.headers.append(HttpHeaders.ContentType, "text/event-stream")
            call.respondOutputStream {
                engine.generateStream(
                    prompt = buildPromptFromMessages(request.messages),
                    maxTokens = request.maxTokens ?: 512
                ).catch { e ->
                    Log.e(TAG, "Generation error", e)
                }.collect { token ->
                    val chunk = ChatCompletionChunk(
                        id = completionId,
                        created = created,
                        model = request.model ?: "minicpm-v",
                        choices = listOf(
                            ChunkChoice(
                                delta = MessageDelta(content = token),
                                index = 0
                            )
                        )
                    )
                    val jsonString = Json.encodeToString(chunk)
                    write("data: $jsonString\n\n".toByteArray())
                    flush()
                }
                write("data: [DONE]\n\n".toByteArray())
                flush()
            }
        } else {
            // Non-streaming response
            val content = buildString {
                engine.generateStream(
                    prompt = buildPromptFromMessages(request.messages),
                    maxTokens = request.maxTokens ?: 512
                ).collect { token ->
                    append(token)
                }
            }

            val response = ChatCompletionResponse(
                id = completionId,
                created = created,
                model = request.model ?: "minicpm-v",
                choices = listOf(
                    Choice(
                        message = Message(role = "assistant", content = content),
                        index = 0,
                        finishReason = "stop"
                    )
                ),
                usage = Usage(
                    promptTokens = 0,  // TODO: track actual token counts
                    completionTokens = 0,
                    totalTokens = 0
                )
            )
            call.respond(response)
        }
    }

    private fun buildPromptFromMessages(messages: List<Message>?): String {
        if (messages.isNullOrEmpty()) {
            return ""
        }

        // Build a simple prompt from messages
        val sb = StringBuilder()
        for (msg in messages) {
            when (msg.role) {
                "system" -> sb.append(msg.content).append("\n")
                "user" -> sb.append(msg.content).append("\n")
                "assistant" -> sb.append(msg.content).append("\n")
            }
        }
        return sb.toString()
    }

    /**
     * 公开方法：加载用户选择的模型
     * 从模型管理页面调用
     */
    fun loadSelectedModel(modelId: String): Boolean {
        val modelInfo = ModelInfo.findById(modelId)
        if (modelInfo == null) {
            Log.e(TAG, "Model not found: $modelId")
            return false
        }

        synchronized(modelLoadLock) {
            // 如果已经加载了相同的模型，直接返回成功
            if (isModelLoaded && selectedModelId == modelId) {
                Log.i(TAG, "Model already loaded: $modelId")
                return true
            }

            // 如果已加载了不同的模型，先卸载
            if (isModelLoaded) {
                Log.i(TAG, "Unloading previous model: $selectedModelId")
                engine.unloadModel()
                isModelLoaded = false
            }

            // 检查模型文件是否存在
            val downloadDir = File(getExternalFilesDir(null), "models")
            val ggufFile = File(downloadDir, modelInfo.ggufFileName)
            val mmprojFile = File(downloadDir, modelInfo.mmprojFileName)

            if (!ggufFile.exists()) {
                Log.e(TAG, "Model file not found: ${modelInfo.ggufFileName}")
                return false
            }

            Log.i(TAG, "Loading selected model: ${modelInfo.displayName}")
            updateNotification("AI Inference Service (loading ${modelInfo.displayName}...)")

            try {
                val mmprojPath = if (mmprojFile.exists()) mmprojFile.absolutePath else null
                
                val success = engine.loadModel(
                    modelPath = ggufFile.absolutePath,
                    mmprojPath = mmprojPath,
                    modelVersion = modelInfo.version
                )

                if (success) {
                    isModelLoaded = true
                    selectedModelId = modelId
                    Log.i(TAG, "Model loaded successfully: ${modelInfo.displayName}")
                    updateNotification("AI Inference Service (ready: ${modelInfo.displayName})")
                    return true
                } else {
                    Log.e(TAG, "Failed to load model: ${modelInfo.displayName}")
                    updateNotification("AI Inference Service (model load failed)")
                    return false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading model: ${modelInfo.displayName}", e)
                updateNotification("AI Inference Service (model load failed)")
                return false
            }
        }
    }

    /**
     * 获取当前加载的模型ID
     */
    fun getLoadedModelId(): String? {
        return if (isModelLoaded) selectedModelId else null
    }

    /**
     * 检查模型文件是否存在
     */
    fun checkModelFilesExist(modelId: String): Boolean {
        val modelInfo = ModelInfo.findById(modelId) ?: return false
        val downloadDir = File(getExternalFilesDir(null), "models")
        val ggufFile = File(downloadDir, modelInfo.ggufFileName)
        val mmprojFile = File(downloadDir, modelInfo.mmprojFileName)
        return ggufFile.exists() && mmprojFile.exists()
    }
    /**
     * 确保模型已加载（延迟加载，仅在首次调用时执行）
     * 如果用户已选择模型，加载用户选择的模型；否则加载默认模型
     */
    private suspend fun ensureModelLoaded() {
        if (isModelLoaded) {
            return
        }

        // 使用用户选择的模型，或默认模型
        val modelToLoad = selectedModelId?.let { ModelInfo.findById(it) } ?: ModelInfo.DEFAULT_MODEL
        
        // 检查是否需要下载模型（在锁外执行suspend函数）
        val downloadDir = File(getExternalFilesDir(null), "models")
        val ggufFile = File(downloadDir, modelToLoad.ggufFileName)
        val mmprojFile = File(downloadDir, modelToLoad.mmprojFileName)
        
        val needsDownload = !ggufFile.exists()
        
        if (needsDownload) {
            // 在锁外执行下载
            Log.i(TAG, "Model file not found, starting automatic download...")
            downloadModel(modelToLoad)
        }
        
        // 下载完成后，在锁内加载模型
        synchronized(modelLoadLock) {
            // 双重检查，避免并发加载
            if (isModelLoaded) {
                return
            }

            Log.i(TAG, "Loading model on first request: ${modelToLoad.displayName}")
            updateNotification("AI Inference Service (loading model...)")

            try {
                val mmprojPath = if (mmprojFile.exists()) mmprojFile.absolutePath else null
                
                val success = engine.loadModel(
                    modelPath = ggufFile.absolutePath,
                    mmprojPath = mmprojPath,
                    modelVersion = modelToLoad.version
                )

                if (success) {
                    isModelLoaded = true
                    // 如果是自动加载默认模型，更新selectedModelId
                    if (selectedModelId == null) {
                        selectedModelId = modelToLoad.id
                    }
                    Log.i(TAG, "Model loaded successfully: ${modelToLoad.displayName}")
                    updateNotification("AI Inference Service (ready)")
                } else {
                    throw IllegalStateException("Failed to load model: ${modelToLoad.displayName}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load model on first request", e)
                updateNotification("AI Inference Service (model load failed)")
                throw e
            }
        }
    }

    /**
     * 下载模型文件（带进度跟踪）
     */
    private suspend fun downloadModel(modelInfo: ModelInfo) {
        if (isModelDownloading) {
            // 如果已经在下载，等待下载完成
            Log.i(TAG, "Model download already in progress, waiting...")
            while (isModelDownloading) {
                delay(1000)
                updateNotification("AI Inference Service (downloading: ${(downloadProgress * 100).toInt()}%)")
            }
            return
        }

        isModelDownloading = true
        downloadProgress = 0.0f

        try {
            Log.i(TAG, "Starting model download: ${modelInfo.displayName}")
            updateNotification("AI Inference Service (downloading: 0%)")

            // 启动下载并跟踪进度
            val result = modelDownloadService.downloadModelWithRacing(
                modelInfo = modelInfo,
                progressCallback = { progress ->
                    downloadProgress = progress
                    val percent = (progress * 100).toInt()
                    Log.d(TAG, "Download progress: $percent%")
                    updateNotification("AI Inference Service (downloading: $percent%)")
                }
            )
            
            if (result.isSuccess) {
                Log.i(TAG, "Model download completed: ${modelInfo.displayName}")
                downloadProgress = 1.0f
                updateNotification("AI Inference Service (download complete, loading...)")
            } else {
                val error = result.exceptionOrNull()?.message ?: "Unknown error"
                throw IllegalStateException("Model download failed: $error")
            }
        } finally {
            isModelDownloading = false
        }
    }

    // ===== Data Classes =====

    @Serializable
    data class HealthResponse(
        val status: String,
        val modelLoaded: Boolean,
        val loadedModelId: String? = null,
        val modelVersion: Int,
        val downloadProgress: Float? = null
    )

    @Serializable
    data class ChatCompletionRequest(
        val model: String? = null,
        val messages: List<Message>? = null,
        val stream: Boolean? = false,
        @SerialName("max_tokens") val maxTokens: Int? = null,
        val temperature: Float? = null,
        @SerialName("top_p") val topP: Float? = null
    )

    @Serializable
    data class Message(
        val role: String,
        val content: String
    )

    @Serializable
    data class MessageDelta(
        val role: String? = null,
        val content: String? = null
    )

    @Serializable
    data class ChatCompletionChunk(
        val id: String,
        val `object`: String = "chat.completion.chunk",
        val created: Long,
        val model: String,
        val choices: List<ChunkChoice>
    )

    @Serializable
    data class ChunkChoice(
        val delta: MessageDelta,
        val index: Int,
        @SerialName("finish_reason") val finishReason: String? = null
    )

    @Serializable
    data class ChatCompletionResponse(
        val id: String,
        val `object`: String = "chat.completion",
        val created: Long,
        val model: String,
        val choices: List<Choice>,
        val usage: Usage
    )

    @Serializable
    data class Choice(
        val message: Message,
        val index: Int,
        @SerialName("finish_reason") val finishReason: String
    )

    @Serializable
    data class Usage(
        @SerialName("prompt_tokens") val promptTokens: Int,
        @SerialName("completion_tokens") val completionTokens: Int,
        @SerialName("total_tokens") val totalTokens: Int
    )
    

    @Synchronized
    private fun getFullLog(): String = logBuffer.toString()
    
    @Synchronized
    private fun appendLog(line: String) {
        if (line.isEmpty()) return
        logBuffer.appendLine(line)
        if (logBuffer.length > MAX_LOG_SIZE) {
            logBuffer.delete(0, logBuffer.length - MAX_LOG_SIZE)
        }
        lastLog = line
    }
}
