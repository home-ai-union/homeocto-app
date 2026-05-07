package com.homeai.homeocto

import android.app.NotificationChannel
import android.app.NotificationManager
import io.flutter.app.FlutterApplication

class HomeOctoApp : FlutterApplication() {

    companion object {
        const val CHANNEL_ID = "homeocto_service"
        const val CHANNEL_NAME = "HomeOcto Service"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        AnalyticsReporter.preInit(this)
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "HomeOcto smart home background service"
            setShowBadge(false)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
