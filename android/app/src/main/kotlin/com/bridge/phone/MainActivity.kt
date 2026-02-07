package com.bridge.phone

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

import com.bridge.phone.ble.BLEConstants
import com.bridge.phone.ble.BLEEventHandler
import com.bridge.phone.ble.BLEPeripheralManager
import com.bridge.phone.hotspot.HotspotManager
import com.bridge.phone.websocket.WebSocketServer
import com.bridge.phone.sms.SMSManager
import com.bridge.phone.sms.SMSReceiver
import com.bridge.phone.call.CallManager
import com.bridge.phone.call.PhoneStateReceiver
import com.bridge.phone.call.AudioStreamManager
import com.bridge.phone.notification.BridgerNotificationListenerService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.bridge.phone.services.BridgeForegroundService
import java.net.NetworkInterface

class MainActivity: FlutterActivity(), BLEEventHandler {
    
    companion object {
        private const val CHANNEL_NATIVE = "com.bridge.phone/native"
        private const val CHANNEL_BLE = "com.bridge.phone/ble"
        private const val EVENT_CHANNEL_BLE = "com.bridge.phone/ble_events"
        private const val CHANNEL_HOTSPOT = "com.bridge.phone/hotspot"
        private const val EVENT_CHANNEL_HOTSPOT = "com.bridge.phone/hotspot_events"
        private const val CHANNEL_WEBSOCKET = "com.bridge.phone/websocket"
        private const val EVENT_CHANNEL_WEBSOCKET = "com.bridge.phone/websocket_events"
        private const val CHANNEL_SMS = "com.bridge.phone/sms"
        private const val EVENT_CHANNEL_SMS = "com.bridge.phone/sms_events"
        private const val CHANNEL_CALL = "com.bridge.phone/call"
        private const val EVENT_CHANNEL_CALL = "com.bridge.phone/call_events"
        private const val CHANNEL_NOTIFICATION = "com.bridge.phone/notification"
        private const val EVENT_CHANNEL_NOTIFICATION = "com.bridge.phone/notification_events"
        private const val CHANNEL_AUDIO = "com.bridge.phone/audio"
        private const val EVENT_CHANNEL_AUDIO = "com.bridge.phone/audio_events"
    }

    private var bleManager: BLEPeripheralManager? = null
    private var hotspotManager: HotspotManager? = null
    private var webSocketServer: WebSocketServer? = null
    private var smsManager: SMSManager? = null
    private var smsReceiver: SMSReceiver? = null
    private var callManager: CallManager? = null
    private var phoneStateReceiver: PhoneStateReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var hotspotEventSink: EventChannel.EventSink? = null
    private var webSocketEventSink: EventChannel.EventSink? = null
    private var smsEventSink: EventChannel.EventSink? = null
    private var callEventSink: EventChannel.EventSink? = null
    private var notificationEventSink: EventChannel.EventSink? = null
    private var audioEventSink: EventChannel.EventSink? = null
    private var notificationBroadcastReceiver: BroadcastReceiver? = null
    private var audioStreamManager: AudioStreamManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize BLE Manager
        bleManager = BLEPeripheralManager(this, this)
        
        // Initialize Hotspot Manager
        hotspotManager = HotspotManager(this)
        hotspotManager?.setCallback(hotspotCallback)
        
        // Start Foreground Service for background persistence
        BridgeForegroundService.start(this)
        
        // ====================================================================
        // Background Service Channel
        // ====================================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bridge.phone/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        BridgeForegroundService.start(this)
                        result.success(true)
                    }
                    "stopService" -> {
                        BridgeForegroundService.stop(this)
                        result.success(true)
                    }
                    "isServiceRunning" -> {
                        result.success(BridgeForegroundService.isServiceRunning())
                    }
                    else -> result.notImplemented()
                }
            }

        // ====================================================================
        // Native Channel (general utilities)
        // ====================================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NATIVE)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPlatformVersion" -> {
                        result.success("Android ${android.os.Build.VERSION.RELEASE}")
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====================================================================
        // BLE Channel (BLE operations)
        // ====================================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BLE)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        val success = bleManager?.initialize() ?: false
                        result.success(success)
                    }
                    "startAdvertising" -> {
                        bleManager?.startAdvertising()
                        result.success(null)
                    }
                    "stopAdvertising" -> {
                        bleManager?.stopAdvertising()
                        result.success(null)
                    }
                    "isAdvertising" -> {
                        result.success(bleManager?.isAdvertising() ?: false)
                    }
                    "isConnected" -> {
                        result.success(bleManager?.isConnected() ?: false)
                    }
                    "getConnectedDevices" -> {
                        result.success(bleManager?.getConnectedDevices() ?: emptyList<String>())
                    }
                    "sendSmsAlert" -> {
                        val data = call.argument<String>("data")
                        if (data != null) {
                            bleManager?.sendSmsAlert(data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "data is required", null)
                        }
                    }
                    "sendCallAlert" -> {
                        val data = call.argument<String>("data")
                        if (data != null) {
                            bleManager?.sendCallAlert(data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "data is required", null)
                        }
                    }
                    "sendAppNotification" -> {
                        val data = call.argument<String>("data")
                        if (data != null) {
                            bleManager?.sendAppNotification(data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "data is required", null)
                        }
                    }
                    "sendBulkData" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data != null) {
                            bleManager?.sendBulkData(data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "data is required", null)
                        }
                    }
                    "shutdown" -> {
                        bleManager?.shutdown()
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====================================================================
        // BLE Event Channel (for streaming events to Flutter)
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_BLE)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        
        // ====================================================================
        // Hotspot Channel (hotspot operations)
        // ====================================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_HOTSPOT)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> {
                        result.success(hotspotManager?.isSupported() ?: false)
                    }
                    "startHotspot" -> {
                        hotspotManager?.startHotspot()
                        // Result will be sent via callback
                        result.success(null)
                    }
                    "stopHotspot" -> {
                        hotspotManager?.stopHotspot()
                        result.success(null)
                    }
                    "getCredentials" -> {
                        val credentials = hotspotManager?.getCredentials()
                        if (credentials != null) {
                            result.success(mapOf(
                                "ssid" to credentials.first,
                                "password" to credentials.second
                            ))
                        } else {
                            result.success(null)
                        }
                    }
                    "isActive" -> {
                        result.success(hotspotManager?.isHotspotActive ?: false)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====================================================================
        // Hotspot Event Channel
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_HOTSPOT)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    hotspotEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    hotspotEventSink = null
                }
            })
        
        // ====================================================================
        // WebSocket Channel
        // ====================================================================
        webSocketServer = WebSocketServer()
        webSocketServer?.callback = webSocketCallback
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WEBSOCKET)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startServer" -> {
                        val port = call.argument<Int>("port") ?: WebSocketServer.DEFAULT_PORT
                        webSocketServer?.start()
                        result.success(port)
                    }
                    "stopServer" -> {
                        webSocketServer?.stop()
                        result.success(null)
                    }
                    "sendMessage" -> {
                        val clientId = call.argument<String>("clientId")
                        val message = call.argument<String>("message")
                        if (clientId != null && message != null) {
                            webSocketServer?.sendMessage(clientId, message)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "clientId and message required", null)
                        }
                    }
                    "broadcast" -> {
                        val message = call.argument<String>("message")
                        if (message != null) {
                            webSocketServer?.broadcast(message)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "message required", null)
                        }
                    }
                    "getServerAddress" -> {
                        result.success(getLocalIpAddress())
                    }
                    "getConnectedClients" -> {
                        result.success(webSocketServer?.getConnectedClients() ?: emptyList<String>())
                    }
                    "isRunning" -> {
                        result.success(webSocketServer?.isRunning() ?: false)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====================================================================
        // WebSocket Event Channel
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_WEBSOCKET)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    webSocketEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    webSocketEventSink = null
                }
            })
        
        // ====================================================================
        // SMS Channel
        // ====================================================================
        smsManager = SMSManager(this)
        smsReceiver = SMSReceiver()
        smsReceiver?.listener = object : SMSReceiver.SMSReceiverListener {
            override fun onSMSReceived(sender: String, body: String, timestamp: Long) {
                sendSMSEvent("smsReceived", mapOf(
                    "sender" to sender,
                    "body" to body,
                    "timestamp" to timestamp
                ))
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SMS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConversations" -> {
                        val conversations = smsManager?.getConversations() ?: emptyList()
                        result.success(conversations)
                    }
                    "getMessages" -> {
                        val threadId = call.argument<Number>("threadId")?.toLong() ?: 0L
                        val limit = call.argument<Int>("limit") ?: 50
                        val messages = smsManager?.getMessagesForThread(threadId, limit) ?: emptyList()
                        result.success(messages)
                    }
                    "getRecentMessages" -> {
                        val count = call.argument<Int>("count") ?: 100
                        val messages = smsManager?.getRecentMessages(count) ?: emptyList()
                        result.success(messages)
                    }
                    "sendSMS" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")
                        if (phoneNumber != null && message != null) {
                            val success = smsManager?.sendSMS(phoneNumber, message) ?: false
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "phoneNumber and message required", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====================================================================
        // SMS Event Channel
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_SMS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                }
            })

        // ====================================================================
        // Call Channel
        // ====================================================================
        callManager = CallManager(this)
        phoneStateReceiver = PhoneStateReceiver()
        phoneStateReceiver?.listener = object : PhoneStateReceiver.PhoneStateListener {
            override fun onIncomingCall(phoneNumber: String) {
                sendCallEvent("incomingCall", mapOf("phoneNumber" to phoneNumber))
            }
            override fun onOutgoingCall(phoneNumber: String) {
                sendCallEvent("outgoingCall", mapOf("phoneNumber" to phoneNumber))
            }
            override fun onCallAnswered(phoneNumber: String, isIncoming: Boolean) {
                sendCallEvent("callAnswered", mapOf(
                    "phoneNumber" to phoneNumber,
                    "isIncoming" to isIncoming
                ))
            }
            override fun onCallEnded(phoneNumber: String, wasIncoming: Boolean) {
                sendCallEvent("callEnded", mapOf(
                    "phoneNumber" to phoneNumber,
                    "wasIncoming" to wasIncoming
                ))
            }
            override fun onMissedCall(phoneNumber: String) {
                sendCallEvent("missedCall", mapOf("phoneNumber" to phoneNumber))
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CALL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCallLog" -> {
                        val limit = call.argument<Int>("limit") ?: 100
                        val entries = callManager?.getCallLog(limit) ?: emptyList()
                        result.success(entries)
                    }
                    "answerCall" -> {
                        val success = callManager?.answerCall() ?: false
                        result.success(success)
                    }
                    "endCall" -> {
                        val success = callManager?.endCall() ?: false
                        result.success(success)
                    }
                    "setSpeakerphone" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        callManager?.setSpeakerphone(enabled)
                        result.success(null)
                    }
                    "setMuted" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        callManager?.setMicMuted(muted)
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // ====================================================================
        // Call Event Channel
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_CALL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    callEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    callEventSink = null
                }
            })

        // ====================================================================
        // Notification Channel
        // ====================================================================
        notificationBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                
                when (intent.action) {
                    BridgerNotificationListenerService.ACTION_NOTIFICATION_POSTED -> {
                        val packageName = intent.getStringExtra("packageName") ?: ""
                        val title = intent.getStringExtra("title") ?: ""
                        val text = intent.getStringExtra("text") ?: ""
                        val id = intent.getIntExtra("id", 0)
                        val timestamp = intent.getLongExtra("timestamp", 0)
                        
                        sendNotificationEvent("notificationPosted", mapOf(
                            "packageName" to packageName,
                            "title" to title,
                            "text" to text,
                            "id" to id,
                            "timestamp" to timestamp
                        ))
                    }
                    BridgerNotificationListenerService.ACTION_NOTIFICATION_REMOVED -> {
                        val packageName = intent.getStringExtra("packageName") ?: ""
                        val id = intent.getIntExtra("id", 0)
                        
                        sendNotificationEvent("notificationRemoved", mapOf(
                            "packageName" to packageName,
                            "id" to id
                        ))
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(BridgerNotificationListenerService.ACTION_NOTIFICATION_POSTED)
            addAction(BridgerNotificationListenerService.ACTION_NOTIFICATION_REMOVED)
        }
        LocalBroadcastManager.getInstance(this).registerReceiver(notificationBroadcastReceiver!!, filter)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NOTIFICATION)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> {
                        val enabledListeners = android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val packageName = packageName
                        val isEnabled = enabledListeners != null && enabledListeners.contains(packageName)
                        result.success(isEnabled)
                    }
                    "requestPermission" -> {
                        startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ====================================================================
        // Notification Event Channel
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NOTIFICATION)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    notificationEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    notificationEventSink = null
                }
            })

        // ====================================================================
        // Audio Channel
        // ====================================================================
        audioStreamManager = AudioStreamManager(object : AudioStreamManager.AudioStreamListener {
            override fun onAudioDataCaptured(data: ByteArray) {
                // Send raw bytes to Flutter via EventChannel
                mainHandler.post {
                    audioEventSink?.success(data)
                }
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_AUDIO)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startStreaming" -> {
                        audioStreamManager?.startStreaming()
                        result.success(null)
                    }
                    "stopStreaming" -> {
                        audioStreamManager?.stopStreaming()
                        result.success(null)
                    }
                    "writeAudioChunk" -> {
                        val data = call.arguments as? ByteArray
                        if (data != null) {
                            audioStreamManager?.playAudioChunk(data)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "Audio data is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ====================================================================
        // Audio Event Channel
        // ====================================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_AUDIO)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            })
    }

    override fun onDestroy() {
        bleManager?.shutdown()
        hotspotManager?.cleanup()
        webSocketServer?.stop()
        if (notificationBroadcastReceiver != null) {
            LocalBroadcastManager.getInstance(this).unregisterReceiver(notificationBroadcastReceiver!!)
        }
        audioStreamManager?.stopStreaming()
        super.onDestroy()
    }

    // ========================================================================
    // BLEEventHandler Implementation
    // ========================================================================

    override fun onDeviceConnected(deviceAddress: String, deviceName: String?) {
        sendEvent("deviceConnected", mapOf(
            "address" to deviceAddress,
            "name" to (deviceName ?: "Unknown")
        ))
    }

    override fun onDeviceDisconnected(deviceAddress: String) {
        sendEvent("deviceDisconnected", mapOf(
            "address" to deviceAddress
        ))
    }

    override fun onCommandReceived(command: String, requestId: String?) {
        sendEvent("commandReceived", mapOf(
            "command" to command,
            "requestId" to (requestId ?: "")
        ))
    }

    override fun onStatusChanged(status: String) {
        sendEvent("statusChanged", mapOf(
            "status" to status
        ))
    }

    override fun onError(errorCode: Int, errorMessage: String) {
        sendEvent("error", mapOf(
            "code" to errorCode,
            "message" to errorMessage
        ))
    }

    override fun onMtuChanged(mtu: Int) {
        sendEvent("mtuChanged", mapOf(
            "mtu" to mtu
        ))
    }

    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    // ========================================================================
    // Hotspot Callback Implementation
    // ========================================================================

    private val hotspotCallback = object : HotspotManager.HotspotCallback {
        override fun onHotspotStarted(ssid: String, password: String) {
            sendHotspotEvent("started", mapOf(
                "ssid" to ssid,
                "password" to password
            ))
        }

        override fun onHotspotStopped() {
            sendHotspotEvent("stopped", emptyMap())
        }

        override fun onError(message: String) {
            sendHotspotEvent("error", mapOf(
                "message" to message
            ))
        }
    }

    private fun sendHotspotEvent(eventType: String, data: Map<String, Any>) {
        mainHandler.post {
            hotspotEventSink?.success(mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    // ========================================================================
    // WebSocket Callback Implementation
    // ========================================================================

    private val webSocketCallback = object : WebSocketServer.WebSocketCallback {
        override fun onServerStarted(port: Int) {
            sendWebSocketEvent("serverStarted", mapOf(
                "port" to port
            ))
        }

        override fun onServerStopped() {
            sendWebSocketEvent("serverStopped", emptyMap())
        }

        override fun onClientConnected(clientId: String) {
            sendWebSocketEvent("clientConnected", mapOf(
                "clientId" to clientId
            ))
        }

        override fun onClientDisconnected(clientId: String) {
            sendWebSocketEvent("clientDisconnected", mapOf(
                "clientId" to clientId
            ))
        }

        override fun onMessageReceived(clientId: String, message: String) {
            sendWebSocketEvent("messageReceived", mapOf(
                "clientId" to clientId,
                "message" to message
            ))
        }

        override fun onError(message: String) {
            sendWebSocketEvent("error", mapOf(
                "message" to message
            ))
        }
    }

    private fun sendWebSocketEvent(eventType: String, data: Map<String, Any>) {
        mainHandler.post {
            webSocketEventSink?.success(mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    // ========================================================================
    // Utility Methods
    // ========================================================================

    private fun getLocalIpAddress(): String? {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                        return address.hostAddress
                    }
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
        return null
    }

    private fun sendSMSEvent(eventType: String, data: Map<String, Any>) {
        mainHandler.post {
            smsEventSink?.success(mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    private fun sendCallEvent(eventType: String, data: Map<String, Any>) {
        mainHandler.post {
            callEventSink?.success(mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    private fun sendNotificationEvent(eventType: String, data: Map<String, Any>) {
        mainHandler.post {
            notificationEventSink?.success(mapOf(
                "type" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }
}

