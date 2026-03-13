package com.souleastforest.smsotp

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.souleastforest.smsotp.accessibility.OtpAccessibilityService
import com.souleastforest.smsotp.pipe.OtpForegroundService

/**
 * MainActivity
 *
 * 简单的状态页：
 *  - 显示 AccessibilityService 是否已开启
 *  - 提供跳转到无障碍设置的按钮
 *  - 启动前台服务
 */
class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // 启动前台 FIFO 读取服务
        startForegroundService(Intent(this, OtpForegroundService::class.java))

        updateStatus()
    }

    override fun onResume() {
        super.onResume()
        updateStatus()
    }

    private fun updateStatus() {
        val enabled = isAccessibilityServiceEnabled()
        val tvStatus = findViewById<TextView>(R.id.tv_status)
        val btnEnable = findViewById<Button>(R.id.btn_enable_accessibility)

        if (enabled) {
            tvStatus.text = "✅ SMS OTP AutoFill 已启用"
        } else {
            tvStatus.text = "⚠️ 请在无障碍设置中启用「SMS OTP 自动填写」"
            btnEnable.setOnClickListener {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, OtpAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) return true
        }
        return false
    }
}
