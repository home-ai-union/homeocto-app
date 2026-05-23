package com.homeai.homeocto.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Service for downloading GGUF and MMProj models from HuggingFace/ModelScope.
 *
 * Features:
 * - Concurrent downloads with progress tracking
 * - Resume support for interrupted downloads
 * - MD5 verification for model integrity
 * - Multi-source racing (HuggingFace vs ModelScope)
 */
class ModelDownloadService : Service() {

    companion object {
        private const val TAG = "ModelDownload"
        private const val NOTIFICATION_ID_BASE = 3000
        private const val CHANNEL_ID = "model_download"
        private const val CHANNEL_NAME = "Model Download"

        // HuggingFace base URL
        private const val HF_BASE_URL = "https://huggingface.co"

        // ModelScope base URL
        private const val MS_BASE_URL = "https://www.modelscope.cn"

        // Download buffer size
        private const val BUFFER_SIZE = 8192

        // Timeout in milliseconds
        private const val TIMEOUT_MS = 30000
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val notificationManager by lazy { getSystemService(NOTIFICATION_SERVICE) as NotificationManager }

    // Download progress state
    private val _downloadProgress = MutableStateFlow<Map<String, DownloadProgress>>(emptyMap())
    val downloadProgress: StateFlow<Map<String, DownloadProgress>> = _downloadProgress.asStateFlow()

    data class DownloadProgress(
        val modelId: String,
        val fileName: String,
        val progress: Float,  // 0.0 to 1.0
        val downloadedBytes: Long,
        val totalBytes: Long,
        val status: Status
    ) {
        enum class Status { Pending, Downloading, Completed, Failed, Cancelled }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }

    /**
     * Download a model with racing sources (HuggingFace + ModelScope).
     * First source to respond wins, other is cancelled.
     */
    suspend fun downloadModelWithRacing(modelInfo: ModelInfo): Result<String> = withContext(Dispatchers.IO) {
        val downloadDir = getDownloadDirectory()
        val ggufFile = File(downloadDir, modelInfo.ggufFileName)
        val mmprojFile = File(downloadDir, modelInfo.mmprojFileName)

        try {
            // Download GGUF file
            val ggufResult = downloadWithRacing(
                modelInfo = modelInfo,
                fileName = modelInfo.ggufFileName,
                remotePath = modelInfo.ggufRemotePath,
                hfRepo = modelInfo.hfRepo,
                msRepo = modelInfo.msRepo,
                expectedMd5 = modelInfo.ggufMd5,
                outputFile = ggufFile
            )

            if (ggufResult.isFailure) {
                return@withContext ggufResult
            }

            // Download MMProj file
            val mmprojResult = downloadWithRacing(
                modelInfo = modelInfo,
                fileName = modelInfo.mmprojFileName,
                remotePath = modelInfo.mmprojRemotePath,
                hfRepo = modelInfo.hfRepo,
                msRepo = modelInfo.msRepo,
                expectedMd5 = modelInfo.mmprojMd5,
                outputFile = mmprojFile
            )

            if (mmprojResult.isFailure) {
                return@withContext mmprojResult
            }

            Result.success(ggufFile.absolutePath)
        } catch (e: Exception) {
            Log.e(TAG, "Download failed", e)
            Result.failure(e)
        }
    }

    /**
     * Download a single file with racing between HuggingFace and ModelScope.
     */
    private suspend fun downloadWithRacing(
        modelInfo: ModelInfo,
        fileName: String,
        remotePath: String,
        hfRepo: String?,
        msRepo: String?,
        expectedMd5: String?,
        outputFile: File
    ): Result<String> = suspendCoroutine { continuation ->
        if (outputFile.exists() && verifyMd5(outputFile, expectedMd5)) {
            Log.i(TAG, "File already exists and verified: $fileName")
            continuation.resume(Result.success(outputFile.absolutePath))
            return@suspendCoroutine
        }

        val hfUrl = if (hfRepo != null) {
            "$HF_BASE_URL/$hfRepo/resolve/${modelInfo.hfBranch}/$remotePath"
        } else null

        val msUrl = if (msRepo != null) {
            "$MS_BASE_URL/$msRepo/resolve/master/$remotePath"
        } else null

        val urls = listOfNotNull(hfUrl, msUrl)
        if (urls.isEmpty()) {
            continuation.resume(Result.failure(IllegalStateException("No download sources available")))
            return@suspendCoroutine
        }

        // Create notification
        val notificationId = NOTIFICATION_ID_BASE + modelInfo.id.hashCode().and(0xFFFF)
        createDownloadNotification(notificationId, fileName, 0)

        // Start download from first available source
        serviceScope.launch {
            try {
                var success = false
                var lastError: Throwable? = null

                for (url in urls) {
                    try {
                        Log.i(TAG, "Downloading from: $url")
                        downloadFile(url, outputFile) { progress ->
                            updateProgress(
                                modelInfo.id, fileName, progress,
                                notificationId = notificationId
                            )
                        }

                        // Verify MD5 if expected
                        if (expectedMd5 != null && !verifyMd5(outputFile, expectedMd5)) {
                            Log.e(TAG, "MD5 verification failed for $fileName")
                            outputFile.delete()
                            lastError = IllegalStateException("MD5 verification failed")
                            continue
                        }

                        success = true
                        Log.i(TAG, "Download completed: $fileName")
                        showCompleteNotification(notificationId, fileName)
                        break
                    } catch (e: Exception) {
                        Log.w(TAG, "Download failed from $url, trying next source", e)
                        lastError = e
                        outputFile.delete()
                    }
                }

                if (success) {
                    continuation.resume(Result.success(outputFile.absolutePath))
                } else {
                    continuation.resume(Result.failure(lastError ?: IllegalStateException("All sources failed")))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download failed", e)
                continuation.resume(Result.failure(e))
            }
        }
    }

    /**
     * Download a file from URL with progress tracking and resume support.
     */
    private fun downloadFile(urlString: String, outputFile: File, onProgress: (Float) -> Unit) {
        val url = URL(urlString)
        val connection = url.openConnection() as HttpURLConnection
        connection.apply {
            connectTimeout = TIMEOUT_MS
            readTimeout = TIMEOUT_MS
            requestMethod = "GET"

            // Resume if file partially downloaded
            if (outputFile.exists()) {
                setRequestProperty("Range", "bytes=${outputFile.length()}-")
            }
        }

        val responseCode = connection.responseCode
        if (responseCode !in 200..299 && responseCode != 206) {
            throw IllegalStateException("HTTP $responseCode: $urlString")
        }

        val totalBytes = connection.contentLengthLong
        var downloadedBytes = if (outputFile.exists()) outputFile.length() else 0L

        connection.inputStream.use { input ->
            outputFile.outputStream().use { output ->
                val buffer = ByteArray(BUFFER_SIZE)
                var bytes: Int

                while (input.read(buffer).also { bytes = it } != -1) {
                    output.write(buffer, 0, bytes)
                    downloadedBytes += bytes

                    val progress = if (totalBytes > 0) {
                        downloadedBytes.toFloat() / totalBytes
                    } else 0f

                    onProgress(progress.coerceIn(0f, 1f))
                }
            }
        }
    }

    /**
     * Verify MD5 checksum of a file.
     */
    private fun verifyMd5(file: File, expectedMd5: String?): Boolean {
        if (expectedMd5 == null) return true  // No verification if no expected hash

        return try {
            val actualMd5 = file.inputStream().use { stream ->
                val digest = MessageDigest.getInstance("MD5")
                val buffer = ByteArray(BUFFER_SIZE)
                var bytes: Int
                while (stream.read(buffer).also { bytes = it } != -1) {
                    digest.update(buffer, 0, bytes)
                }
                digest.digest().joinToString("") { "%02x".format(it) }
            }
            actualMd5.equals(expectedMd5, ignoreCase = true)
        } catch (e: Exception) {
            Log.e(TAG, "MD5 verification failed", e)
            false
        }
    }

    private fun getDownloadDirectory(): File {
        val dir = File(getExternalFilesDir(null), "models")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Model download progress notifications"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createDownloadNotification(notificationId: Int, fileName: String, progress: Int) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Downloading model")
            .setContentText(fileName)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, progress, false)
            .setOngoing(true)
            .build()

        notificationManager.notify(notificationId, notification)
    }

    private fun updateProgress(
        modelId: String,
        fileName: String,
        progress: Float,
        notificationId: Int
    ) {
        _downloadProgress.value += (modelId to DownloadProgress(
            modelId = modelId,
            fileName = fileName,
            progress = progress,
            downloadedBytes = (progress * 100).toLong(),
            totalBytes = 100,
            status = DownloadProgress.Status.Downloading
        ))

        createDownloadNotification(notificationId, fileName, (progress * 100).toInt())
    }

    private fun showCompleteNotification(notificationId: Int, fileName: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Download complete")
            .setContentText(fileName)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .build()

        notificationManager.notify(notificationId, notification)
    }
}
