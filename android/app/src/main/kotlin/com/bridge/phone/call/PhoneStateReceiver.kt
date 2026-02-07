package com.bridge.phone.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

/**
 * BroadcastReceiver for detecting phone call state changes.
 */
class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneStateReceiver"
    }

    var listener: PhoneStateListener? = null
    
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var isIncoming = false
    private var savedNumber: String? = null

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            if (number != null) {
                savedNumber = number
            }

            val state = when (stateStr) {
                TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
                TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
                TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
                else -> return
            }

            onCallStateChanged(state, savedNumber)
        }
        
        // Outgoing call
        if (intent?.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            savedNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            isIncoming = false
        }
    }

    private fun onCallStateChanged(state: Int, phoneNumber: String?) {
        if (lastState == state) return

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                // Incoming call starting
                isIncoming = true
                Log.d(TAG, "Incoming call from $phoneNumber")
                listener?.onIncomingCall(phoneNumber ?: "Unknown")
            }

            TelephonyManager.CALL_STATE_OFFHOOK -> {
                // Call answered
                if (lastState == TelephonyManager.CALL_STATE_RINGING) {
                    // Incoming call answered
                    Log.d(TAG, "Incoming call answered")
                    listener?.onCallAnswered(phoneNumber ?: "Unknown", isIncoming)
                } else {
                    // Outgoing call started
                    Log.d(TAG, "Outgoing call started to $phoneNumber")
                    listener?.onOutgoingCall(phoneNumber ?: "Unknown")
                }
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                // Call ended
                when (lastState) {
                    TelephonyManager.CALL_STATE_RINGING -> {
                        // Missed call
                        Log.d(TAG, "Missed call from $phoneNumber")
                        listener?.onMissedCall(phoneNumber ?: "Unknown")
                    }
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        // Call ended
                        Log.d(TAG, "Call ended")
                        listener?.onCallEnded(phoneNumber ?: "Unknown", isIncoming)
                    }
                }
                savedNumber = null
                isIncoming = false
            }
        }

        lastState = state
    }

    interface PhoneStateListener {
        fun onIncomingCall(phoneNumber: String)
        fun onOutgoingCall(phoneNumber: String)
        fun onCallAnswered(phoneNumber: String, isIncoming: Boolean)
        fun onCallEnded(phoneNumber: String, wasIncoming: Boolean)
        fun onMissedCall(phoneNumber: String)
    }
}
