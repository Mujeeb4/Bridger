package com.bridge.phone.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telephony.SmsMessage
import android.util.Log

/**
 * BroadcastReceiver for intercepting incoming SMS messages.
 * Forwards SMS data to SMSManager for processing.
 */
class SMSReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SMSReceiver"
        const val SMS_RECEIVED_ACTION = "android.provider.Telephony.SMS_RECEIVED"
    }

    var listener: SMSReceiverListener? = null

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != SMS_RECEIVED_ACTION) return

        try {
            val bundle: Bundle? = intent.extras
            if (bundle != null) {
                val pdus = bundle.get("pdus") as Array<*>?
                val format = bundle.getString("format")

                if (pdus != null) {
                    val messages = mutableListOf<SmsMessage>()

                    for (pdu in pdus) {
                        val smsMessage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            SmsMessage.createFromPdu(pdu as ByteArray, format)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsMessage.createFromPdu(pdu as ByteArray)
                        }
                        messages.add(smsMessage)
                    }

                    // Combine message parts
                    val sender = messages.firstOrNull()?.originatingAddress ?: "Unknown"
                    val body = messages.joinToString("") { it.messageBody ?: "" }
                    val timestamp = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()

                    Log.d(TAG, "SMS received from $sender: ${body.take(50)}...")

                    listener?.onSMSReceived(
                        sender = sender,
                        body = body,
                        timestamp = timestamp
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing incoming SMS", e)
        }
    }

    interface SMSReceiverListener {
        fun onSMSReceived(sender: String, body: String, timestamp: Long)
    }
}
