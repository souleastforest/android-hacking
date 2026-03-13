package com.souleastforest.smsotp.pipe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.souleastforest.smsotp.accessibility.OtpAccessibilityService
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.File
import java.io.FileReader

/**
 * OtpForegroundService
 *
 * 前台服务，持续读取 KSU service.sh 写入的 FIFO 管道
 * 收到 OTP 后通过本地广播通知 [OtpAccessibilityService]
 */
class OtpForegroundService : Service() {

    companion object {
        const val TAG = "OtpFifoService"
        const val FIFO_PATH = "/data/local/tmp/sms_otp.fifo"
        const val CHANNEL_ID = "otp_service_channel"
        const val NOTIFICATION_ID = 1001
    }

    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.IO + job)

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        startFifoReader()
        Log.i(TAG, "OtpForegroundService started, watching: $FIFO_PATH")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        job.cancel()
        super.onDestroy()
        Log.i(TAG, "OtpForegroundService destroyed")
    }

    // ── FIFO 读取循环 ────────────────────────────────────────────
    private fun startFifoReader() {
        scope.launch {
            while (isActive) {
                try {
                    val fifo = File(FIFO_PATH)
                    if (!fifo.exists()) {
                        Log.w(TAG, "FIFO not found, waiting 3s...")
                        delay(3000)
                        continue
                    }
                    // 打开 FIFO（阻塞，直到写端写数据）
                    BufferedReader(FileReader(fifo)).use { reader ->
                        Log.d(TAG, "FIFO opened, waiting for OTP...")
                        val line = reader.readLine()
                        if (!line.isNullOrBlank()) {
                            val otp = line.trim()
                            Log.i(TAG, "Got OTP from FIFO: $otp")
                            broadcastOtp(otp)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "FIFO read error: ${e.message}")
                    delay(2000)
                }
            }
        }
    }

    private fun broadcastOtp(otp: String) {
        val intent = Intent(OtpAccessibilityService.ACTION_OTP_RECEIVED).apply {
            putExtra(OtpAccessibilityService.EXTRA_OTP, otp)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    // ── 通知频道（前台服务必须）───────────────────────────────────
    private fun createNotificationChannel() {
        val nm = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(com.souleastforest.smsotp.R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(com.souleastforest.smsotp.R.string.notification_title))
            .setContentText(getString(com.souleastforest.smsotp.R.string.notification_text))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }
}
