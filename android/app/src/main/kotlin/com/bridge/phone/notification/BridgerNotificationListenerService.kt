package com.bridge.phone.notification

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager

/**
 * Service to intercept system notifications.
 */
class BridgerNotificationListenerService : NotificationListenerService() {

    companion object {
        const val ACTION_NOTIFICATION_POSTED = "com.bridge.phone.NOTIFICATION_POSTED"
        const val ACTION_NOTIFICATION_REMOVED = "com.bridge.phone.NOTIFICATION_REMOVED"
        private const val TAG = "NotifListenerService"
        
        var instance: BridgerNotificationListenerService? = null
            private set
    }

    override fun onListenerConnected() {
        Log.d(TAG, "Notification Listener connected")
        instance = this
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (instance == this) {
            instance = null
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!shouldMirror(sbn)) return

        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        
        // Resolve human-readable app name from package name
        val appName = try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(sbn.packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            sbn.packageName // fallback to package name
        }
        
        Log.d(TAG, "Notification Posted: [$appName] $title - $text")

        val intent = Intent(ACTION_NOTIFICATION_POSTED)
        intent.putExtra("packageName", sbn.packageName)
        intent.putExtra("appName", appName)
        intent.putExtra("title", title)
        intent.putExtra("text", text)
        intent.putExtra("id", sbn.id)
        intent.putExtra("timestamp", sbn.postTime)
        
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (!shouldMirror(sbn)) return

        Log.d(TAG, "Notification Removed: ${sbn.packageName}")

        val intent = Intent(ACTION_NOTIFICATION_REMOVED)
        intent.putExtra("packageName", sbn.packageName)
        intent.putExtra("id", sbn.id)
        
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }

    private fun shouldMirror(sbn: StatusBarNotification): Boolean {
        // Filter out system notifications or own app if needed
        if (sbn.packageName == packageName) return false
        if (sbn.isOngoing) return false // Ignore persistent notifications (like music players for now)
        return true
    }
}
