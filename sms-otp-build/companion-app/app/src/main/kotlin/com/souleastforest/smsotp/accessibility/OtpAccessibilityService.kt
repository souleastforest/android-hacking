package com.souleastforest.smsotp.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * OtpAccessibilityService
 *
 * 工作流程：
 *  1. [OtpForegroundService] 从 FIFO 读到 OTP 后，发本地广播 ACTION_OTP_RECEIVED
 *  2. 本 Service 收到广播，遍历当前窗口找第一个可输入的 EditText
 *  3. 通过 ACTION_SET_TEXT 或 ACTION_PASTE 填入 OTP
 */
class OtpAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "OtpA11yService"
        const val ACTION_OTP_RECEIVED = "com.souleastforest.smsotp.ACTION_OTP_RECEIVED"
        const val EXTRA_OTP = "otp"
    }

    private var pendingOtp: String? = null

    private val otpReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val otp = intent.getStringExtra(EXTRA_OTP) ?: return
            Log.d(TAG, "Received OTP broadcast: $otp")
            pendingOtp = otp
            tryFillOtp()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "AccessibilityService connected")
        val filter = IntentFilter(ACTION_OTP_RECEIVED)
        registerReceiver(otpReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // 窗口状态变化或焦点变化时，尝试填入待填 OTP
        val type = event.eventType
        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            type == AccessibilityEvent.TYPE_VIEW_FOCUSED
        ) {
            if (pendingOtp != null) {
                tryFillOtp()
            }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(otpReceiver)
    }

    // ── 核心：找到焦点输入框并填入 OTP ───────────────────────
    private fun tryFillOtp() {
        val otp = pendingOtp ?: return
        val root = rootInActiveWindow ?: run {
            Log.w(TAG, "No active window, will retry on next event")
            return
        }

        val targetNode = findOtpInputNode(root)
        if (targetNode == null) {
            Log.d(TAG, "No suitable input node found yet")
            root.recycle()
            return
        }

        val filled = fillNode(targetNode, otp)
        if (filled) {
            Log.i(TAG, "OTP '$otp' filled successfully")
            pendingOtp = null
        }

        targetNode.recycle()
        root.recycle()
    }

    /**
     * 策略：
     * 1. 优先找 当前焦点 且 className 含 EditText 的节点
     * 2. 退而求其次：找任意可编辑、可聚焦的节点
     */
    private fun findOtpInputNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // 方案 A：当前焦点节点
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (focused != null && focused.isEditable) {
            return focused
        }

        // 方案 B：递归找可编辑节点
        return findEditableNode(root)
    }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable && node.isEnabled) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findEditableNode(child)
            if (result != null) {
                if (result != child) child.recycle()
                return result
            }
            child.recycle()
        }
        return null
    }

    private fun fillNode(node: AccessibilityNodeInfo, otp: String): Boolean {
        // 首选：ACTION_SET_TEXT（API 21+，最干净）
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                otp
            )
        }
        if (node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
            return true
        }

        // 备选：把 OTP 放到剪贴板，再 PASTE
        Log.w(TAG, "ACTION_SET_TEXT failed, trying clipboard paste")
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE)
            as android.content.ClipboardManager
        clipboard.setPrimaryClip(
            android.content.ClipData.newPlainText("otp", otp)
        )
        return node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
    }
}
