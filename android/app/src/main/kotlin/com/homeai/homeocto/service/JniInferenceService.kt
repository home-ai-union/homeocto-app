package com.homeai.homeocto.service

import android.app.Notification
import android.app.PendingIntent
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
class JniInferenceService : androidx.core.app.Service() {

    companion object {
        private const val TAG = "JniInferenceService"
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "jni_inference_service"
        private const val CHANNEL_NAME = "AI Inference Service"

        // Default HTTP server port
        const val DEFAULT_PORT = 8080
    }

    private var server: EmbeddedServer<NettyApplicationEngine, NettyApplicationEngine.Configuration>? = null
    private val engine = JniLlamaEngine.instance
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val port = intent?.getIntExtra("port", DEFAULT_PORT) ?: DEFAULT_PORT
        val modelPath = intent?.getStringExtra("model_path")
        val mmprojPath = intent?.getStringExtra("mmproj_path")

        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification())

        // Initialize engine
        engine.initialize(this)

        // Load model if specified
        if (modelPath != null) {
            val modelInfo = findModelForPath(modelPath)
            serviceScope.launch {
                val success = engine.loadModel(
                    modelPath = modelPath,
                    mmprojPath = mmprojPath,
                    modelVersion = modelInfo?.version ?: 0
                )
                Log.i(TAG, "Model loading ${if (success) "succeeded" else "failed"}: $modelPath")
            }
        }

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
        server?.stop(1000, 2000)
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
            val manager = getSystemService(android.app.NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, getMainActivityClass()),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI Inference Service")
            .setContentText("OpenAI-compatible API server running")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun getMainActivityClass(): Class<*> {
        return Class.forName("${packageName}.MainActivity")
    }

    private fun findModelForPath(modelPath: String): ModelInfo? {
        val fileName = File(modelPath).name
        return ModelInfo.AVAILABLE_MODELS.find { it.ggufFileName == fileName }
    }

    // ===== HTTP Handlers =====

    private suspend fun handleHealth(call: ApplicationCall) {
        val response = HealthResponse(
            status = "ok",
            modelLoaded = true,
            modelVersion = engine.getModelVersion()
        )
        call.respond(response)
    }

    private suspend fun handleChatCompletions(call: ApplicationCall) {
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
                    write("data: ${Json.encodeToString(ChatCompletionChunk.serializer(), chunk)}\n\n")
                    flush()
                }
                write("data: [DONE]\n\n")
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
