package com.homeai.homeocto.llama

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.homeai.homeocto.MainActivity
import com.homeai.homeocto.PicoClawApp
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

data class LlamaServerParams(
    val modelPath: String,
    val mmprojPath: String?,
    val port: Int = 18900,
    val ctxSize: Int = 2048,
    val threads: Int = 4
)

class LlamaServerService : Service() {

    companion object {
        private const val TAG = "LlamaServerService"
        private const val NOTIFICATION_ID = 2
        private val ANSI_ESCAPE_REGEX = Regex("\\u001B(?:[@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~])")

        const val ACTION_START = "com.homeai.homeocto.llama.action.START"
        const val ACTION_STOP = "com.homeai.homeocto.llama.action.STOP"
        const val EXTRA_PARAMS = "llama_server_params"

        // Shared state for UI
        @Volatile
        var isRunning = false
            private set

        @Volatile
        var lastLog = ""
            private set

        @Volatile
        var processId: Int = -1
            private set

        @Volatile
        var actualPort: Int = 0
            private set

        @Volatile
        var currentModelPath: String = ""
            private set

        fun start(context: Context, params: LlamaServerParams) {
            val intent = Intent(context, LlamaServerService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PARAMS, params)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, LlamaServerService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var process: Process? = null
    private var serviceThread: Thread? = null
    private var logThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val logBuffer = StringBuilder()
    private val maxLogSize = 64 * 1024 // 64KB log buffer
    private val serviceLock = Object()
    @Volatile
    private var stopped = false
    @Volatile
    private var currentParams: LlamaServerParams? = null
    private var restartCount = 0
    private val maxRestartAttempts = 3

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopService()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                currentParams = intent.getSerializableExtra(EXTRA_PARAMS) as? LlamaServerParams
                if (currentParams == null) {
                    lastLog = "Error: Missing server parameters"
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, createNotification("Starting..."))
                acquireWakeLock()
                startService()
                return START_STICKY
            }
            else -> {
                // Default action: start with params from intent
                currentParams = intent?.getSerializableExtra(EXTRA_PARAMS) as? LlamaServerParams
                if (currentParams == null) {
                    lastLog = "Error: Missing server parameters"
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, createNotification("Starting..."))
                acquireWakeLock()
                startService()
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        stopService()
        releaseWakeLock()
        isRunning = false
        Log.i(TAG, "Service destroyed")
        super.onDestroy()
    }

    private fun startService() {
        synchronized(serviceLock) {
            if (serviceThread?.isAlive == true || process?.isAlive == true) {
                Log.w(TAG, "Service is already running, ignoring duplicate start request")
                return
            }
            stopped = false
            restartCount = 0

            serviceThread = Thread {
                try {
                    val params = currentParams ?: return@Thread
                    runServer(params)
                } catch (e: Exception) {
                    if (!stopped) {
                        Log.e(TAG, "Failed to start service", e)
                        lastLog = "Error: ${e.message}"
                        updateNotification("Error: ${e.message}")
                    }
                }
            }.also { it.start() }
        }
    }

    private fun runServer(params: LlamaServerParams) {
        if (stopped) return

        val binaryFile = LlamaBinaryResolver.resolveBinary(this)
        testBinary(binaryFile)

        // Check if model files exist
        if (!File(params.modelPath).exists()) {
            throw RuntimeException("Model file not found: ${params.modelPath}")
        }
        if (!params.mmprojPath.isNullOrEmpty() && !File(params.mmprojPath).exists()) {
            throw RuntimeException("MMProj file not found: ${params.mmprojPath}")
        }

        // Try to find an available port
        var port = params.port
        for (i in 0 until 10) {
            val testPort = params.port + i
            if (isPortAvailable(testPort)) {
                port = testPort
                break
            }
        }
        actualPort = port
        currentModelPath = params.modelPath

        // Build command line
        val cmdList = mutableListOf(
            binaryFile.absolutePath,
            "--model", params.modelPath,
            "--host", "127.0.0.1",
            "--port", port.toString(),
            "--ctx-size", params.ctxSize.toString(),
            "--threads", params.threads.toString()
        )

        if (!params.mmprojPath.isNullOrEmpty()) {
            cmdList.addAll(listOf("--mmproj", params.mmprojPath))
        }

        val env = buildEnvironment()

        val pb = ProcessBuilder(cmdList)
            .directory(filesDir)
            .redirectErrorStream(true)

        pb.environment().putAll(env)

        Log.i(TAG, "Starting llama-server on port $port...")
        updateNotification("Starting llama-server...")

        val proc = pb.start()
        synchronized(serviceLock) {
            if (stopped) {
                Log.i(TAG, "Service stopped during startup, killing new process")
                proc.destroyForcibly()
                return
            }
            process = proc
            isRunning = true
        }

        processId = try {
            val pidField = proc.javaClass.getDeclaredField("pid")
            pidField.isAccessible = true
            pidField.getInt(proc)
        } catch (e: Exception) {
            -1
        }

        updateNotification("Running (PID: $processId, Port: $port)")
        Log.i(TAG, "llama-server started with PID: $processId, listening on port $port")

        // Log reader thread
        logThread = Thread({
            try {
                val reader = BufferedReader(InputStreamReader(proc.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    val logLine = line ?: continue
                    Log.d(TAG, logLine)
                    appendLog(logLine)
                }
            } catch (e: Exception) {
                if (!stopped) {
                    Log.w(TAG, "Log reader interrupted", e)
                }
            }
        }, "llama-server-log-reader").apply {
            isDaemon = true
            start()
        }

        // Wait for process exit
        val exitCode = proc.waitFor()
        isRunning = false
        processId = -1

        try { logThread?.join(2000) } catch (_: InterruptedException) {}

        if (stopped) {
            Log.i(TAG, "llama-server exited due to stop request (code $exitCode)")
            return
        }

        val lastOutput = logBuffer.toString().takeLast(500)
        Log.w(TAG, "llama-server exited with code: $exitCode, last output: $lastOutput")
        lastLog = "Process exited (code $exitCode)\n$lastOutput"
        updateNotification("Stopped (exit code $exitCode)")

        // Auto-restart on failure (limited attempts)
        if (exitCode != 0) {
            restartCount++
            if (restartCount > maxRestartAttempts) {
                Log.e(TAG, "llama-server has failed $restartCount times, giving up restart")
                lastLog = "Service crashed $restartCount times, stopped retrying"
                updateNotification("Error: too many restarts")
                return
            }
            Log.i(TAG, "Scheduling restart in 5 seconds... (attempt $restartCount/$maxRestartAttempts)")
            killOrphanProcesses()
            Thread.sleep(5000)
            if (stopped) return
            runServer(params)
        }
    }

    private fun testBinary(binaryFile: File) {
        Log.i(TAG, "Testing llama-server binary at ${binaryFile.absolutePath}...")
        val env = buildEnvironment()

        val pb = ProcessBuilder(binaryFile.absolutePath, "--help")
            .directory(filesDir)
            .redirectErrorStream(true)

        pb.environment().putAll(env)

        try {
            val proc = pb.start()
            proc.inputStream.bufferedReader().readText()
            val exitCode = proc.waitFor()
            Log.i(TAG, "Binary test: exit=$exitCode")

            if (exitCode != 0) {
                Log.w(TAG, "Binary returned non-zero exit code (expected for --help)")
            }
        } catch (e: java.io.IOException) {
            throw RuntimeException(
                "Cannot execute llama-server binary at ${binaryFile.absolutePath}: ${e.message}", e
            )
        }
    }

    private fun buildEnvironment(): Map<String, String> {
        return mapOf(
            "HOME" to filesDir.absolutePath,
            "TMPDIR" to cacheDir.absolutePath,
            "PATH" to "/system/bin:/system/xbin",
            "LANG" to "en_US.UTF-8",
        )
    }

    private fun isPortAvailable(port: Int): Boolean {
        return try {
            java.net.ServerSocket(port).use { true }
        } catch (e: java.net.BindException) {
            false
        } catch (e: Exception) {
            true // Assume available if we can't check
        }
    }

    private fun killOrphanProcesses() {
        try {
            val myPid = android.os.Process.myPid()
            val myUid = android.os.Process.myUid()
            val procDir = File("/proc")
            procDir.listFiles()?.forEach { pidDir ->
                val pid = pidDir.name.toIntOrNull() ?: return@forEach
                if (pid == myPid) return@forEach
                try {
                    val statusFile = File(pidDir, "status")
                    if (!statusFile.canRead()) return@forEach
                    val statusContent = statusFile.readText()

                    val uidLine = statusContent.lineSequence()
                        .firstOrNull { it.startsWith("Uid:") } ?: return@forEach
                    val uidFields = uidLine.substringAfter("Uid:").trim().split(Regex("\\s+"))
                    val processUid = uidFields.firstOrNull()?.toIntOrNull() ?: return@forEach

                    if (processUid != myUid) return@forEach

                    val cmdlineFile = File(pidDir, "cmdline")
                    if (!cmdlineFile.canRead()) return@forEach
                    val cmdline = cmdlineFile.readText()
                    if (!cmdline.contains("llama-server")) return@forEach

                    Log.i(TAG, "Killing orphan llama-server process: PID=$pid, UID=$processUid")
                    android.os.Process.killProcess(pid)
                } catch (e: Exception) {
                    // Ignore
                }
            }
            Log.i(TAG, "Cleaned up orphan llama-server processes")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cleanup orphan processes: ${e.message}")
        }
    }

    private fun stopService() {
        Log.i(TAG, "Stopping service...")

        synchronized(serviceLock) {
            stopped = true

            process?.let { proc ->
                try {
                    proc.destroy()

                    val thread = Thread {
                        try {
                            proc.waitFor()
                        } catch (_: InterruptedException) {}
                    }
                    thread.start()
                    thread.join(10_000)

                    if (proc.isAlive) {
                        Log.w(TAG, "Force killing llama-server process")
                        proc.destroyForcibly()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping llama-server process", e)
                }
            }

            process = null
            isRunning = false
            processId = -1

            logThread?.interrupt()
            logThread = null
        }

        serviceThread?.let { thread ->
            try {
                thread.join(5_000)
            } catch (_: InterruptedException) {}
        }
        serviceThread = null

        killOrphanProcesses()
        restartCount = 0

        Log.i(TAG, "Service stopped and cleaned up")
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "LlamaServer::ServiceWakeLock"
        ).apply {
            acquire(24 * 60 * 60 * 1000L) // 24 hours max
        }
        Log.i(TAG, "Wake lock acquired")
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.i(TAG, "Wake lock released")
            }
        }
        wakeLock = null
    }

    @Synchronized
    private fun appendLog(line: String) {
        logBuffer.appendLine(line)
        if (logBuffer.length > maxLogSize) {
            logBuffer.delete(0, logBuffer.length - maxLogSize)
        }
        lastLog = line
    }

    @Synchronized
    fun getFullLog(): String = logBuffer.toString()

    private fun createNotification(status: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, LlamaServerService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, "llama_server")
            .setContentTitle("llama-server")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
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
}
