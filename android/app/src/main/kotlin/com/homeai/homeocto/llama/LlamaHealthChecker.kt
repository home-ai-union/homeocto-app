package com.homeai.homeocto.llama

import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class LlamaHealthStatus(
    val isHealthy: Boolean,
    val status: String,
    val modelLoaded: Boolean
)

object LlamaHealthChecker {
    private const val TAG = "LlamaHealthChecker"

    /**
     * Check the health of the llama-server via GET /health endpoint
     */
    fun check(host: String = "127.0.0.1", port: Int): LlamaHealthStatus {
        return try {
            val url = URL("http://$host:$port/health")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 3000
            connection.readTimeout = 3000

            val responseCode = connection.responseCode
            val responseBody = try {
                connection.inputStream.bufferedReader().readText()
            } catch (e: Exception) {
                connection.errorStream?.bufferedReader()?.readText() ?: ""
            } finally {
                connection.disconnect()
            }

            if (responseCode == 200) {
                val json = JSONObject(responseBody)
                LlamaHealthStatus(
                    isHealthy = true,
                    status = json.optString("status", "ok"),
                    modelLoaded = json.optBoolean("model_loaded", false)
                )
            } else {
                LlamaHealthStatus(
                    isHealthy = false,
                    status = "HTTP $responseCode",
                    modelLoaded = false
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Health check failed: ${e.message}")
            LlamaHealthStatus(
                isHealthy = false,
                status = e.message ?: "Unknown error",
                modelLoaded = false
            )
        }
    }
}
