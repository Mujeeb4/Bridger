package com.bridge.phone.call

import android.Manifest
import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioManager
import android.provider.CallLog
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Manages call operations: reading call log, controlling calls, audio routing.
 */
class CallManager(private val context: Context) {

    companion object {
        private const val TAG = "CallManager"
        private const val MAX_CALL_LOG_ENTRIES = 100
    }

    private val contentResolver: ContentResolver = context.contentResolver
    private val audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val telecomManager: TelecomManager? = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager

    // ========================================================================
    // Call Log
    // ========================================================================

    /**
     * Get call history
     */
    fun getCallLog(limit: Int = MAX_CALL_LOG_ENTRIES): List<Map<String, Any>> {
        if (!hasReadCallLogPermission()) {
            Log.w(TAG, "No READ_CALL_LOG permission")
            return emptyList()
        }

        val entries = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION
        )

        try {
            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                "${CallLog.Calls.DATE} DESC LIMIT $limit"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    entries.add(mapOf(
                        "id" to it.getLong(it.getColumnIndexOrThrow(CallLog.Calls._ID)),
                        "number" to (it.getString(it.getColumnIndexOrThrow(CallLog.Calls.NUMBER)) ?: ""),
                        "name" to (it.getString(it.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME)) ?: ""),
                        "type" to it.getInt(it.getColumnIndexOrThrow(CallLog.Calls.TYPE)),
                        "timestamp" to it.getLong(it.getColumnIndexOrThrow(CallLog.Calls.DATE)),
                        "duration" to it.getLong(it.getColumnIndexOrThrow(CallLog.Calls.DURATION))
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading call log", e)
        }

        return entries
    }

    /**
     * Get call type as string
     */
    fun getCallTypeString(type: Int): String {
        return when (type) {
            CallLog.Calls.INCOMING_TYPE -> "incoming"
            CallLog.Calls.OUTGOING_TYPE -> "outgoing"
            CallLog.Calls.MISSED_TYPE -> "missed"
            CallLog.Calls.REJECTED_TYPE -> "rejected"
            CallLog.Calls.BLOCKED_TYPE -> "blocked"
            CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
            else -> "unknown"
        }
    }

    // ========================================================================
    // Call Controls
    // ========================================================================

    /**
     * Answer incoming call (requires default dialer or accessibility)
     */
    @Suppress("DEPRECATION")
    fun answerCall(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.ANSWER_PHONE_CALLS) 
                    == PackageManager.PERMISSION_GRANTED) {
                    telecomManager?.acceptRingingCall()
                    true
                } else {
                    Log.w(TAG, "No ANSWER_PHONE_CALLS permission")
                    false
                }
            } else {
                // Fallback for older versions - use headset hook simulation
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error answering call", e)
            false
        }
    }

    /**
     * Reject/end current call
     */
    @Suppress("DEPRECATION")
    fun endCall(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.ANSWER_PHONE_CALLS) 
                    == PackageManager.PERMISSION_GRANTED) {
                    telecomManager?.endCall() ?: false
                } else {
                    Log.w(TAG, "No ANSWER_PHONE_CALLS permission")
                    false
                }
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error ending call", e)
            false
        }
    }

    // ========================================================================
    // Audio Controls
    // ========================================================================

    /**
     * Toggle speakerphone
     */
    fun setSpeakerphone(enabled: Boolean) {
        audioManager.isSpeakerphoneOn = enabled
        Log.d(TAG, "Speakerphone: $enabled")
    }

    /**
     * Check if speakerphone is on
     */
    fun isSpeakerphoneOn(): Boolean {
        return audioManager.isSpeakerphoneOn
    }

    /**
     * Mute/unmute microphone
     */
    fun setMicMuted(muted: Boolean) {
        audioManager.isMicrophoneMute = muted
        Log.d(TAG, "Microphone muted: $muted")
    }

    /**
     * Check if microphone is muted
     */
    fun isMicMuted(): Boolean {
        return audioManager.isMicrophoneMute
    }

    // ========================================================================
    // Permissions
    // ========================================================================

    private fun hasReadCallLogPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Convert call log to JSON string for transmission
     */
    fun callLogToJson(entries: List<Map<String, Any>>): String {
        val jsonArray = JSONArray()
        entries.forEach { entry ->
            val json = JSONObject()
            entry.forEach { (key, value) ->
                json.put(key, value)
            }
            jsonArray.put(json)
        }
        return jsonArray.toString()
    }
}
