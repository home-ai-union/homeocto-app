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
    }

    private var server: Any? = null
    private val engine = JniLlamaEngine.instance
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // 延迟加载模型：仅在首次调用时加载
    @Volatile
    private var isModelLoaded = false
    private val modelLoadLock = Any()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val port = intent?.getIntExtra("port", DEFAULT_PORT) ?: DEFAULT_PORT

        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification("AI Inference Service (standby)"))

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
        stopServer()
        engine.destroy()
        serviceScope.cancel()
    }

    private fun startServer(port: Int) {
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

        Log.i(TAG, "HTTP server started on port $port")
    }

    private fun stopServer() {
        (server as? io.ktor.server.engine.ApplicationEngine)?.stop(
            gracePeriodMillis = 1000,
            timeoutMillis = 2000
        )
        server = null
        Log.i(TAG, "HTTP server stopped")
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
        return Class.forName("${applicationContext.packageName}.MainActivity")
    }

    private fun findModelForPath(modelPath: String): ModelInfo? {
        val fileName = File(modelPath).name
        return ModelInfo.AVAILABLE_MODELS.find { it.ggufFileName == fileName }
    }

    // ===== HTTP Handlers =====

    private suspend fun handleHealth(call: ApplicationCall) {
        val response = HealthResponse(
            status = "ok",
            modelLoaded = isModelLoaded,
            modelVersion = engine.getModelVersion()
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
     * 确保模型已加载（延迟加载，仅在首次调用时执行）
     */
    private suspend fun ensureModelLoaded() {
        if (isModelLoaded) {
            return
        }

        synchronized(modelLoadLock) {
            // 双重检查，避免并发加载
            if (isModelLoaded) {
                return
            }

            Log.i(TAG, "Loading default model on first request...")
            updateNotification("AI Inference Service (loading model...)")

            try {
                // 加载默认模型
                val defaultModel = ModelInfo.DEFAULT_MODEL
                val downloadDir = File(getExternalFilesDir(null), "models")
                val ggufFile = File(downloadDir, defaultModel.ggufFileName)
                val mmprojFile = File(downloadDir, defaultModel.mmprojFileName)

                // 检查模型文件是否存在
                if (!ggufFile.exists()) {
                    throw IllegalStateException(
                        "Model file not found: ${ggufFile.absolutePath}. " +
                        "Please download the model first using ModelDownloadService."
                    )
                }

                val mmprojPath = if (mmprojFile.exists()) mmprojFile.absolutePath else null
                
                val success = engine.loadModel(
                    modelPath = ggufFile.absolutePath,
                    mmprojPath = mmprojPath,
                    modelVersion = defaultModel.version
                )

                if (success) {
                    isModelLoaded = true
                    Log.i(TAG, "Model loaded successfully: ${defaultModel.displayName}")
                    updateNotification("AI Inference Service (ready)")
                } else {
                    throw IllegalStateException("Failed to load model: ${defaultModel.displayName}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load model on first request", e)
                updateNotification("AI Inference Service (model load failed)")
                throw e
            }
        }
    }

    // ===== Data Classes =====

    @Serializable
    data class HealthResponse(
        val status: String,
        val modelLoaded: Boolean,
        val modelVersion: Int
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
}
