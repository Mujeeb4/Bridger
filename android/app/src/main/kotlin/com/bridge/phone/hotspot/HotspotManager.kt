package com.bridge.phone.hotspot

import android.content.Context
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Manages Wi-Fi hotspot functionality on Android.
 * Uses LocalOnlyHotspotReservation for API 26+ compatibility.
 */
class HotspotManager(private val context: Context) {

    companion object {
        private const val TAG = "HotspotManager"
    }

    private val wifiManager: WifiManager by lazy {
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    }

    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Hotspot credentials (available after starting)
    var ssid: String? = null
        private set
    var password: String? = null
        private set

    // State
    var isHotspotActive: Boolean = false
        private set

    // Callback interface
    interface HotspotCallback {
        fun onHotspotStarted(ssid: String, password: String)
        fun onHotspotStopped()
        fun onError(message: String)
    }

    private var callback: HotspotCallback? = null

    fun setCallback(callback: HotspotCallback) {
        this.callback = callback
    }

    /**
     * Start a local-only hotspot.
     * This creates an AP that can be used for device-to-device communication.
     * 
     * Note: This requires Android 8.0 (API 26) or higher.
     * Note: Location permission must be granted.
     */
    fun startHotspot() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            callback?.onError("Hotspot requires Android 8.0 or higher")
            return
        }

        if (isHotspotActive) {
            Log.d(TAG, "Hotspot already active")
            ssid?.let { s ->
                password?.let { p ->
                    callback?.onHotspotStarted(s, p)
                }
            }
            return
        }

        try {
            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation?) {
                    super.onStarted(reservation)
                    hotspotReservation = reservation
                    
                    val config = reservation?.wifiConfiguration
                    if (config != null) {
                        ssid = config.SSID
                        password = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            // API 30+ uses different method
                            config.preSharedKey
                        } else {
                            @Suppress("DEPRECATION")
                            config.preSharedKey
                        }
                        
                        isHotspotActive = true
                        Log.d(TAG, "Hotspot started: SSID=$ssid")
                        
                        mainHandler.post {
                            callback?.onHotspotStarted(ssid!!, password ?: "")
                        }
                    } else {
                        mainHandler.post {
                            callback?.onError("Failed to get hotspot configuration")
                        }
                    }
                }

                override fun onStopped() {
                    super.onStopped()
                    Log.d(TAG, "Hotspot stopped")
                    isHotspotActive = false
                    ssid = null
                    password = null
                    hotspotReservation = null
                    
                    mainHandler.post {
                        callback?.onHotspotStopped()
                    }
                }

                override fun onFailed(reason: Int) {
                    super.onFailed(reason)
                    val errorMessage = when (reason) {
                        ERROR_NO_CHANNEL -> "No channel available"
                        ERROR_GENERIC -> "Generic error"
                        ERROR_INCOMPATIBLE_MODE -> "Incompatible mode - disable Wi-Fi first"
                        ERROR_TETHERING_DISALLOWED -> "Tethering disallowed"
                        else -> "Unknown error: $reason"
                    }
                    Log.e(TAG, "Hotspot failed: $errorMessage")
                    
                    mainHandler.post {
                        callback?.onError(errorMessage)
                    }
                }
            }, mainHandler)
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception starting hotspot", e)
            callback?.onError("Permission denied: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting hotspot", e)
            callback?.onError("Error: ${e.message}")
        }
    }

    /**
     * Stop the local-only hotspot.
     */
    fun stopHotspot() {
        try {
            hotspotReservation?.close()
            hotspotReservation = null
            isHotspotActive = false
            ssid = null
            password = null
            Log.d(TAG, "Hotspot stopped by request")
            callback?.onHotspotStopped()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping hotspot", e)
            callback?.onError("Error stopping: ${e.message}")
        }
    }

    /**
     * Get current hotspot credentials.
     * Returns null if hotspot is not active.
     */
    fun getCredentials(): Pair<String, String>? {
        if (!isHotspotActive || ssid == null) return null
        return Pair(ssid!!, password ?: "")
    }

    /**
     * Check if the device supports local-only hotspot.
     */
    fun isSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
    }

    /**
     * Clean up resources.
     */
    fun cleanup() {
        stopHotspot()
        callback = null
    }
}
