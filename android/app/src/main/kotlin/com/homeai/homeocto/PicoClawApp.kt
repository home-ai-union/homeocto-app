package com.homeai.homeocto

import android.app.NotificationChannel
import android.app.NotificationManager
import io.flutter.app.FlutterApplication
import com.example.minicpm_v_demo.LocaleManager

class PicoClawApp : FlutterApplication() {

    companion object {
        const val CHANNEL_ID = "picoclaw_service"
        const val CHANNEL_NAME = "PicoClaw Service"
        const val MINICPM_DOWNLOAD_CHANNEL_ID = "minicpm_download"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        AnalyticsReporter.preInit(this)

        // MiniCPM-V initialization
        LocaleManager.applyOnAppStart(this)
        createMiniCPMNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "PicoClaw AI Assistant background service"
            setShowBadge(false)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun createMiniCPMNotificationChannel() {
        val channel = NotificationChannel(
            MINICPM_DOWNLOAD_CHANNEL_ID,
            "Model Download",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "MiniCPM-V model download progress"
            setShowBadge(false)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
