package com.example.orto

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createMessagesChannel()
        hideContentFromRecents()
    }

    // 履歴の一覧（アプリスイッチャー）にトークの内容を残さない（機能仕様書4.2.4.3）。
    // Android 13より前はこれだけを止める手段が無いため、スクリーンショットごと止める。
    private fun hideContentFromRecents() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        } else {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VideoProcessingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    // プッシュ通知用の通知チャンネルを作る（機能仕様書4.4.6）。
    // 重要度を「高」にして、ロック解除中もポップアップ・音で知らせる（FCMの既定のチャンネルは重要度が
    // 「中」のため、通知センターに入るだけでポップアップしない）。IDはCloud Functionsの送信時の
    // android.notification.channelIdと、AndroidManifestの既定のチャンネルIDとそろえること。
    // 作成済みなら何もしない（重要度は作成後に変えられないため、変えるならIDごと変える）。
    private fun createMessagesChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            MESSAGES_CHANNEL_ID,
            getString(R.string.notification_channel_messages_name),
            NotificationManager.IMPORTANCE_HIGH,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private const val MESSAGES_CHANNEL_ID = "messages"
    }
}
