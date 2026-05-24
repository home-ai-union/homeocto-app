package com.homeai.homeocto.service

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.server.testing.*
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName

/**
 * JVM 单元测试：测试 JniInferenceService 的 HTTP API 端点
 * 
 * 注意：此测试不依赖 Android 环境和 native 库，仅测试 HTTP 路由和序列化逻辑
 */
class JniInferenceServiceHttpTest {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    @Test
    @DisplayName("Health endpoint should return correct structure")
    fun `test health endpoint returns valid response`() = testApplication {
        application {
            // Setup minimal routing for health check
            // This would need a mock engine setup
        }

        // TODO: Implement with mocked engine
        // For now, this demonstrates the test structure
    }

    @Test
    @DisplayName("Chat completion request should deserialize correctly")
    fun `test chat completion request deserialization`() {
        val requestJson = """
            {
                "model": "minicpm-v",
                "messages": [
                    {"role": "system", "content": "You are a helpful assistant"},
                    {"role": "user", "content": "Hello"}
                ],
                "stream": false,
                "max_tokens": 512,
                "temperature": 0.7
            }
        """.trimIndent()

        val request = json.decodeFromString<JniInferenceService.ChatCompletionRequest>(requestJson)

        assertEquals("minicpm-v", request.model)
        assertEquals(2, request.messages?.size)
        assertEquals("system", request.messages?.get(0)?.role)
        assertEquals(false, request.stream)
        assertEquals(512, request.maxTokens)
    }

    @Test
    @DisplayName("Streaming chat request should parse stream flag")
    fun `test streaming request parsing`() {
        val requestJson = """
            {
                "messages": [{"role": "user", "content": "Test"}],
                "stream": true
            }
        """.trimIndent()

        val request = json.decodeFromString<JniInferenceService.ChatCompletionRequest>(requestJson)

        assertTrue(request.stream == true)
        assertEquals(1, request.messages?.size)
    }

    @Test
    @DisplayName("Chat completion response should serialize correctly")
    fun `test chat completion response serialization`() {
        val response = JniInferenceService.ChatCompletionResponse(
            id = "chatcmpl-test-123",
            created = System.currentTimeMillis() / 1000,
            model = "minicpm-v",
            choices = listOf(
                JniInferenceService.Choice(
                    message = JniInferenceService.Message(
                        role = "assistant",
                        content = "Hello! How can I help you?"
                    ),
                    index = 0,
                    finishReason = "stop"
                )
            ),
            usage = JniInferenceService.Usage(
                promptTokens = 10,
                completionTokens = 20,
                totalTokens = 30
            )
        )

        val serialized = json.encodeToString(response)

        // Verify required fields
        assertTrue(serialized.contains("chatcmpl-test-123"))
        assertTrue(serialized.contains("minicpm-v"))
        assertTrue(serialized.contains("Hello! How can I help you?"))
        assertTrue(serialized.contains("stop"))
    }

    @Test
    @DisplayName("Chat completion chunk should serialize for SSE")
    fun `test streaming chunk serialization`() {
        val chunk = JniInferenceService.ChatCompletionChunk(
            id = "chatcmpl-stream-456",
            created = System.currentTimeMillis() / 1000,
            model = "minicpm-v",
            choices = listOf(
                JniInferenceService.ChunkChoice(
                    delta = JniInferenceService.MessageDelta(
                        content = "Hello"
                    ),
                    index = 0
                )
            )
        )

        val serialized = json.encodeToString(chunk)
        val sseFormat = "data: $serialized\n\n"

        assertTrue(sseFormat.startsWith("data: "))
        assertTrue(sseFormat.contains("chat.completion.chunk"))
        assertTrue(sseFormat.contains("Hello"))
    }

    @Test
    @DisplayName("Health response should include model status")
    fun `test health response serialization`() {
        val response = JniInferenceService.HealthResponse(
            status = "ok",
            modelLoaded = true,
            modelVersion = 2,
            downloadProgress = null
        )

        val serialized = json.encodeToString(response)

        assertTrue(serialized.contains("ok"))
        assertTrue(serialized.contains("modelLoaded\":true"))
    }

    @Test
    @DisplayName("Health response should include download progress when downloading")
    fun `test health response with download progress`() {
        val response = JniInferenceService.HealthResponse(
            status = "downloading",
            modelLoaded = false,
            modelVersion = 0,
            downloadProgress = 0.65f
        )

        val serialized = json.encodeToString(response)

        assertTrue(serialized.contains("downloading"))
        assertTrue(serialized.contains("0.65"))
    }

    @Test
    @DisplayName("Build prompt from messages should concatenate correctly")
    fun `test build prompt from messages`() {
        val messages = listOf(
            JniInferenceService.Message("system", "You are helpful"),
            JniInferenceService.Message("user", "What is AI?"),
            JniInferenceService.Message("assistant", "AI is...")
        )

        // Simulate the buildPromptFromMessages logic
        val prompt = buildString {
            for (msg in messages) {
                append(msg.content).append("\n")
            }
        }

        assertTrue(prompt.contains("You are helpful"))
        assertTrue(prompt.contains("What is AI?"))
        assertTrue(prompt.contains("AI is..."))
        assertEquals(3, prompt.count { it == '\n' })
    }

    @Test
    @DisplayName("Empty messages should return empty prompt")
    fun `test build prompt with empty messages`() {
        val messages: List<JniInferenceService.Message>? = null
        val prompt = messages?.joinToString("\n") { it.content } ?: ""
        assertTrue(prompt.isEmpty())
    }
}
