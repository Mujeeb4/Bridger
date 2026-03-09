package com.bridge.phone.services

import android.os.Build
import android.telecom.Call
import android.telecom.InCallService
import android.util.Log

/**
 * InCallService stub for managing in-call UI and call state.
 * Declared in AndroidManifest.xml - this service is required to exist
 * even if not yet fully implemented, to prevent class-not-found crashes.
 */
class BridgeInCallService : InCallService() {

    companion object {
        private const val TAG = "BridgeInCallService"
        var currentCall: Call? = null
            private set
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        currentCall = call
        Log.d(TAG, "Call added: ${call.details?.handle}")
        
        call.registerCallback(callCallback)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        call.unregisterCallback(callCallback)
        
        if (currentCall == call) {
            currentCall = null
        }
        Log.d(TAG, "Call removed")
    }

    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            Log.d(TAG, "Call state changed: $state")
        }
    }

    /**
     * Answer the current call
     */
    fun answerCall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            currentCall?.answer(android.telecom.VideoProfile.STATE_AUDIO_ONLY)
        }
    }

    /**
     * Reject / end the current call
     */
    fun endCall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            currentCall?.reject(false, null)
        } else {
            currentCall?.disconnect()
        }
    }
}
