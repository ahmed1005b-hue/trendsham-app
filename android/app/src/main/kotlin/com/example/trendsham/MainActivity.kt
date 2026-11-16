package com.example.trendsham

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // قناة الإشعارات التي يرسل إليها الخادم (channel_id = trendsham_default) بأولوية عالية.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager?.getNotificationChannel("trendsham_default") == null) {
                val channel = NotificationChannel(
                    "trendsham_default",
                    "إشعارات تريند شام",
                    NotificationManager.IMPORTANCE_HIGH,
                )
                channel.description = "الطلبات والرسائل والعروض"
                manager?.createNotificationChannel(channel)
            }
        }
    }
}
