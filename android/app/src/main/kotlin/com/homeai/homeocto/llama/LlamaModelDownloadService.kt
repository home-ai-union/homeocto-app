package com.homeai.homeocto.llama

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.homeai.homeocto.MainActivity
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

data class ModelSource(
    val displayName: String,
    val ggufUrl: String,
    val mmprojUrl: String?,
    val expectedMd5: String?
)

object ModelPresets {
    val MiniCPM_V_4_6 = ModelSource(
        displayName = "MiniCPM-V-4.6 (Q4_K_M)",
        ggufUrl = "https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/MiniCPM-V-4_6-Q4_K_M.gguf",
        mmprojUrl = "https://huggingface.co/openbmb/MiniCPM-V-4.6-gguf/resolve/main/mmproj-model-f16.gguf",
        expectedMd5 = "fd778481dd56b6036dd8f9cf7c1519cf"
    )

    val MiniCPM_V_4 = ModelSource(
        displayName = "MiniCPM-V-4 (Q4_K_M)",
        ggufUrl = "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/ggml-model-Q4_K_M.gguf",
        mmprojUrl = "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/mmproj-model-f16.gguf",
        expectedMd5 = null
    )

    fun getPreset(modelId: String): ModelSource? = when (modelId) {
        "minicpm-v-4.6" -> MiniCPM_V_4_6
        "minicpm-v-4" -> MiniCPM_V_4
        else -> null
    }
}

class LlamaModelDownloadService : Service() {

    companion object {
        private const val TAG = "LlamaModelDownload"
        private const val NOTIFICATION_ID = 3
        private const val ACTION_DOWNLOAD = "com.homeai.homeocto.llama.action.DOWNLOAD"
        private const val EXTRA_MODEL_ID = "model_id"

        const val DOWNLOAD_BROADCAST_ACTION = "com.homeai.homeocto.llama.DOWNLOAD_PROGRESS"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_STATUS = "status"
        const val EXTRA_SPEED = "speed"

        // Shared download state
        @Volatile
        var downloadProgress = 0.0
            private set

        @Volatile
        var downloadStatus = "idle"
            private set

        @Volatile
        var downloadSpeed = 0L // bytes per second
            private set

        fun startDownload(context: Context, modelId: String) {
            val intent = Intent(context, LlamaModelDownloadService::class.java).apply {
                action = ACTION_DOWNLOAD
                putExtra(EXTRA_MODEL_ID, modelId)
            }
            context.startForegroundService(intent)
        }

        private fun computeMd5(file: File): String {
            val digest = MessageDigest.getInstance("MD5")
            file.inputStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    digest.update(buffer, 0, bytesRead)
                }
            }
            return digest.digest().joinToString("") { "%02x".format(it) }
        }
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var downloadJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DOWNLOAD -> {
                val modelId = intent.getStringExtra(EXTRA_MODEL_ID)
                    ?: run {
                        stopSelf()
                        return START_NOT_STICKY
                    }
                startForeground(NOTIFICATION_ID, createNotification("Starting download..."))
                downloadModel(modelId)
            }
            else -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        downloadJob?.cancel()
        serviceScope.cancel()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun downloadModel(modelId: String) {
        val model = ModelPresets.getPreset(modelId)
            ?: run {
                Log.e(TAG, "Unknown model ID: $modelId")
                downloadStatus = "error: Unknown model"
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return
            }

        val modelDir = File(
            getExternalFilesDir(null),
            "llama_models"
        ).apply { mkdirs() }

        val ggufFile = File(modelDir, File(model.ggufUrl).name)
        val mmprojFile = if (model.mmprojUrl != null) {
            File(modelDir, File(model.mmprojUrl).name)
        } else {
            null
        }

        downloadJob = serviceScope.launch {
            try {
                // Download GGUF
                downloadStatus = "Downloading ${model.displayName} (GGUF)..."
                updateNotification(downloadStatus)
                downloadFileWithResume(model.ggufUrl, ggufFile) { progress, speed ->
                    downloadProgress = progress
                    downloadSpeed = speed
                    broadcastProgress()
                    updateNotification("$downloadStatus ${"%.0f".format(progress * 100)}%")
                }

                // Download MMPROJ if available
                if (mmprojFile != null && model.mmprojUrl != null) {
                    downloadStatus = "Downloading ${model.displayName} (MMProj)..."
                    updateNotification(downloadStatus)
                    downloadFileWithResume(model.mmprojUrl, mmprojFile) { progress, speed ->
                        downloadProgress = progress
                        downloadSpeed = speed
                        broadcastProgress()
                        updateNotification("$downloadStatus ${"%.0f".format(progress * 100)}%")
                    }
                }

                // Verify MD5 if available
                if (model.expectedMd5 != null) {
                    downloadStatus = "Verifying checksum..."
                    updateNotification(downloadStatus)
                    val actualMd5 = computeMd5(ggufFile)
                    if (actualMd5 != model.expectedMd5) {
                        downloadStatus = "error: MD5 mismatch"
                        updateNotification("Error: Checksum mismatch")
                        throw RuntimeException("MD5 mismatch: expected ${model.expectedMd5}, got $actualMd5")
                    }
                }

                downloadStatus = "Download complete"
                downloadProgress = 1.0
                updateNotification("Download complete")
                broadcastProgress()

                // Stop foreground service after successful download
                withContext(Dispatchers.Main) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            } catch (e: CancellationException) {
                Log.i(TAG, "Download cancelled")
                downloadStatus = "cancelled"
            } catch (e: Exception) {
                Log.e(TAG, "Download failed: ${e.message}")
                downloadStatus = "error: ${e.message}"
                updateNotification("Error: ${e.message}")
            }
        }
    }

    private suspend fun downloadFileWithResume(
        url: String,
        outputFile: File,
        onProgress: (Double, Long) -> Unit
    ) = withContext(Dispatchers.IO) {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 30000
        connection.readTimeout = 60000

        var startByte = 0L
        if (outputFile.exists()) {
            startByte = outputFile.length()
            connection.setRequestProperty("Range", "bytes=$startByte-")
        }

        val responseCode = connection.responseCode
        if (responseCode != HttpURLConnection.HTTP_OK &&
            responseCode != HttpURLConnection.HTTP_PARTIAL) {
            throw RuntimeException("HTTP error: $responseCode")
        }

        val totalSize = if (responseCode == HttpURLConnection.HTTP_PARTIAL) {
            connection.getContentLengthLong() + startByte
        } else {
            connection.contentLengthLong
        }

        val input = connection.inputStream
        val output = FileOutputStream(outputFile, true)

        val buffer = ByteArray(8192)
        var bytesRead: Int
        var totalBytesRead = startByte
        var lastTime = System.currentTimeMillis()
        var lastBytes = startByte

        try {
            while (isActive) {
                bytesRead = input.read(buffer)
                if (bytesRead == -1) break

                output.write(buffer, 0, bytesRead)
                totalBytesRead += bytesRead

                // Calculate speed every second
                val now = System.currentTimeMillis()
                if (now - lastTime >= 1000) {
                    val speed = (totalBytesRead - lastBytes) * 1000 / (now - lastTime)
                    val progress = if (totalSize > 0) totalBytesRead.toDouble() / totalSize else 0.0
                    withContext(Dispatchers.Main) {
                        onProgress(progress, speed)
                    }
                    lastTime = now
                    lastBytes = totalBytesRead
                }
            }
        } finally {
            input.close()
            output.close()
            connection.disconnect()
        }
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

    private fun createNotification(status: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, "llama_download")
            .setContentTitle("llama-model-download")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setProgress(100, (downloadProgress * 100).toInt(), downloadProgress == 0.0)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun broadcastProgress() {
        try {
            val intent = Intent(DOWNLOAD_BROADCAST_ACTION).apply {
                putExtra(EXTRA_PROGRESS, downloadProgress)
                putExtra(EXTRA_STATUS, downloadStatus)
                putExtra(EXTRA_SPEED, downloadSpeed)
                setPackage(packageName)
            }
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to broadcast progress", e)
        }
    }
}
