package com.bridge.phone.sms

import android.Manifest
import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Manages SMS operations: reading inbox, sending, and syncing.
 */
class SMSManager(private val context: Context) {

    companion object {
        private const val TAG = "SMSManager"
        private const val MAX_SMS_TO_SYNC = 100
    }

    private val contentResolver: ContentResolver = context.contentResolver

    // ========================================================================
    // Read SMS
    // ========================================================================

    /**
     * Get all SMS conversations (threads)
     */
    fun getConversations(): List<Map<String, Any>> {
        if (!hasReadPermission()) {
            Log.w(TAG, "No READ_SMS permission")
            return emptyList()
        }

        val conversations = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            Telephony.Sms.Conversations.THREAD_ID,
            Telephony.Sms.Conversations.MESSAGE_COUNT,
            Telephony.Sms.Conversations.SNIPPET
        )

        try {
            val cursor = contentResolver.query(
                Telephony.Sms.Conversations.CONTENT_URI,
                projection,
                null,
                null,
                "${Telephony.Sms.Conversations.DEFAULT_SORT_ORDER} LIMIT 50"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val threadId = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.Conversations.THREAD_ID))
                    val count = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.Conversations.MESSAGE_COUNT))
                    val snippet = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.Conversations.SNIPPET)) ?: ""

                    // Get address for this thread
                    val address = getAddressForThread(threadId)

                    conversations.add(mapOf(
                        "threadId" to threadId,
                        "address" to address,
                        "messageCount" to count,
                        "snippet" to snippet,
                        "timestamp" to getLatestTimestamp(threadId)
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading conversations", e)
        }

        return conversations
    }

    /**
     * Get messages for a specific thread
     */
    fun getMessagesForThread(threadId: Long, limit: Int = 50): List<Map<String, Any>> {
        if (!hasReadPermission()) return emptyList()

        val messages = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )

        try {
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                "${Telephony.Sms.THREAD_ID} = ?",
                arrayOf(threadId.toString()),
                "${Telephony.Sms.DATE} DESC LIMIT $limit"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    messages.add(mapOf(
                        "id" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID)),
                        "address" to (it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""),
                        "body" to (it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""),
                        "timestamp" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE)),
                        "type" to it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE)),
                        "isRead" to (it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.READ)) == 1)
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading messages for thread $threadId", e)
        }

        return messages.reversed() // Return in chronological order
    }

    /**
     * Get recent messages (for sync)
     */
    fun getRecentMessages(count: Int = MAX_SMS_TO_SYNC): List<Map<String, Any>> {
        if (!hasReadPermission()) return emptyList()

        val messages = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )

        try {
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                null,
                null,
                "${Telephony.Sms.DATE} DESC LIMIT $count"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    messages.add(mapOf(
                        "id" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID)),
                        "threadId" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)),
                        "address" to (it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""),
                        "body" to (it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""),
                        "timestamp" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE)),
                        "type" to it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE)),
                        "isRead" to (it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.READ)) == 1)
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading recent messages", e)
        }

        return messages
    }

    // ========================================================================
    // Send SMS
    // ========================================================================

    /**
     * Send an SMS message
     */
    fun sendSMS(phoneNumber: String, message: String): Boolean {
        if (!hasSendPermission()) {
            Log.w(TAG, "No SEND_SMS permission")
            return false
        }

        return try {
            val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Split message if too long
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            }

            Log.d(TAG, "SMS sent to $phoneNumber")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error sending SMS to $phoneNumber", e)
            false
        }
    }

    // ========================================================================
    // Helper Methods
    // ========================================================================

    private fun getAddressForThread(threadId: Long): String {
        try {
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS),
                "${Telephony.Sms.THREAD_ID} = ?",
                arrayOf(threadId.toString()),
                "${Telephony.Sms.DATE} DESC LIMIT 1"
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    return it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting address for thread $threadId", e)
        }
        return ""
    }

    private fun getLatestTimestamp(threadId: Long): Long {
        try {
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(Telephony.Sms.DATE),
                "${Telephony.Sms.THREAD_ID} = ?",
                arrayOf(threadId.toString()),
                "${Telephony.Sms.DATE} DESC LIMIT 1"
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    return it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting timestamp for thread $threadId", e)
        }
        return 0L
    }

    private fun hasReadPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasSendPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Convert messages list to JSON string for transmission
     */
    fun messagesToJson(messages: List<Map<String, Any>>): String {
        val jsonArray = JSONArray()
        messages.forEach { msg ->
            val json = JSONObject()
            msg.forEach { (key, value) ->
                json.put(key, value)
            }
            jsonArray.put(json)
        }
        return jsonArray.toString()
    }
}
