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
import com.bridge.phone.contacts.ContactsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
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
        private const val CHANNEL_CONTACTS = "com.bridge.phone/contacts"
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
    private var contactsManager: ContactsManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var bluetoothStateReceiver: BroadcastReceiver? = null
    // Track whether advertising was requested so we can auto-start when BT turns on
    private var advertisingRequested = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize BLE Manager
        bleManager = BLEPeripheralManager(this, this)
        
        // Listen for Bluetooth state changes so we can auto-init+advertise when BT turns on
        bluetoothStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == android.bluetooth.BluetoothAdapter.ACTION_STATE_CHANGED) {
                    val state = intent.getIntExtra(android.bluetooth.BluetoothAdapter.EXTRA_STATE, -1)
                    if (state == android.bluetooth.BluetoothAdapter.STATE_ON) {
                        Log.i("MainActivity", "Bluetooth turned ON — auto-initializing BLE")
                        mainHandler.postDelayed({
                            if (bleManager?.isInitialized() != true) {
                                bleManager?.initialize()
                            }
                            if (advertisingRequested && bleManager?.isAdvertising() != true) {
                                bleManager?.startAdvertising()
                            }
                        }, 1000) // Small delay for BT stack to fully settle
                    }
                }
            }
        }
        val btFilter = IntentFilter(android.bluetooth.BluetoothAdapter.ACTION_STATE_CHANGED)
        registerReceiver(bluetoothStateReceiver, btFilter)
        
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
                        advertisingRequested = true
                        // Auto-initialize if not yet initialized (e.g. Bluetooth was off at startup)
                        if (bleManager?.isInitialized() != true) {
                            val initOk = bleManager?.initialize() ?: false
                            if (!initOk) {
                                // BT adapter may still be settling — retry after a short delay
                                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                    if (bleManager?.isInitialized() != true) {
                                        bleManager?.initialize()
                                    }
                                    bleManager?.startAdvertising()
                                }, 2000)
                                result.success(null)
                                return@setMethodCallHandler
                            }
                        }
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
                    "sendStatusUpdate" -> {
                        val data = call.argument<String>("data")
                        if (data != null) {
                            bleManager?.sendStatusUpdate(data)
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
                        val pendingResult = result
                        val originalCallback = hotspotCallback

                        hotspotManager?.setCallback(object : HotspotManager.HotspotCallback {
                            override fun onHotspotStarted(ssid: String, password: String) {
                                hotspotManager?.setCallback(originalCallback)
                                pendingResult.success(mapOf(
                                    "ssid" to ssid,
                                    "password" to password
                                ))
                                sendHotspotEvent("started", mapOf("ssid" to ssid, "password" to password))
                            }

                            override fun onHotspotStopped() {
                                hotspotManager?.setCallback(originalCallback)
                                pendingResult.success(null)
                                sendHotspotEvent("stopped", emptyMap())
                            }

                            override fun onError(message: String) {
                                hotspotManager?.setCallback(originalCallback)
                                pendingResult.error("HOTSPOT_ERROR", message, null)
                                sendHotspotEvent("error", mapOf("message" to message))
                            }
                        })

                        hotspotManager?.startHotspot()
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
                    "broadcastBinary" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data != null) {
                            webSocketServer?.broadcastBinary(data)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "data required", null)
                        }
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
        // Register at runtime so THIS instance (with listener) receives broadcasts
        val smsFilter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        smsFilter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, smsFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(smsReceiver, smsFilter)
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
        // Register at runtime so THIS instance (with listener) receives broadcasts
        val phoneFilter = IntentFilter().apply {
            addAction("android.intent.action.PHONE_STATE")
            addAction("android.intent.action.NEW_OUTGOING_CALL")
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(phoneStateReceiver, phoneFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(phoneStateReceiver, phoneFilter)
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
                    "makeCall" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber != null) {
                            val success = callManager?.makeCall(phoneNumber) ?: false
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
                        }
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
                        val appName = intent.getStringExtra("appName") ?: packageName
                        val title = intent.getStringExtra("title") ?: ""
                        val text = intent.getStringExtra("text") ?: ""
                        val id = intent.getIntExtra("id", 0)
                        val timestamp = intent.getLongExtra("timestamp", 0)
                        
                        sendNotificationEvent("notificationPosted", mapOf(
                            "packageName" to packageName,
                            "appName" to appName,
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
                // Send audio directly to iOS via WebSocket (native path, bypasses Flutter)
                sendAudioNatively(data)
                
                // Also send to Flutter EventSink for monitoring/UI (non-critical)
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
                    "setEncryptionKey" -> {
                        val keyBytes = call.arguments as? ByteArray
                        if (keyBytes != null && keyBytes.size == 32) {
                            setAudioEncryptionKey(keyBytes)
                            result.success(null)
                        } else {
                            result.error("INVALID_KEY", "Encryption key must be 32 bytes", null)
                        }
                    }
                    "clearEncryptionKey" -> {
                        clearAudioEncryptionKey()
                        result.success(null)
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

        // ====================================================================
        // Contacts Channel
        // ====================================================================
        contactsManager = ContactsManager(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CONTACTS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getContacts" -> {
                        try {
                            val contacts = contactsManager?.getContacts() ?: emptyList()
                            result.success(contacts)
                        } catch (e: Exception) {
                            result.error("CONTACTS_ERROR", e.message, null)
                        }
                    }
                    "getContactCount" -> {
                        try {
                            val count = contactsManager?.getContactCount() ?: 0
                            result.success(count)
                        } catch (e: Exception) {
                            result.error("CONTACTS_ERROR", e.message, null)
                        }
                    }
                    "getContactByPhoneNumber" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber != null) {
                            try {
                                val contact = contactsManager?.getContactByPhoneNumber(phoneNumber)
                                result.success(contact)
                            } catch (e: Exception) {
                                result.error("CONTACTS_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "phoneNumber required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        bleManager?.shutdown()
        hotspotManager?.cleanup()
        webSocketServer?.stop()
        if (notificationBroadcastReceiver != null) {
            LocalBroadcastManager.getInstance(this).unregisterReceiver(notificationBroadcastReceiver!!)
        }
        // Unregister Bluetooth state receiver
        try { bluetoothStateReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        // Unregister runtime broadcast receivers
        try { smsReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        try { phoneStateReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
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

        override fun onBinaryMessageReceived(clientId: String, data: ByteArray) {
            // Check for audio protocol (0x01 prefix) — route directly to native audio
            // engine for minimum latency, bypassing Flutter entirely
            if (data.isNotEmpty() && data[0] == 0x01.toByte()) {
                val audioPayload = data.copyOfRange(1, data.size)
                handleIncomingAudioNatively(audioPayload)
            } else {
                // Forward non-audio binary data to Flutter
                sendWebSocketEvent("binaryMessageReceived", mapOf(
                    "clientId" to clientId,
                    "data" to data
                ))
            }
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
    // Native Audio Path (bypasses Flutter for minimum latency)
    // ========================================================================

    private var audioEncryptionKey: ByteArray? = null

    /** Set the AES-256 encryption key for audio (called after pairing) */
    fun setAudioEncryptionKey(key: ByteArray) {
        if (key.size != 32) {
            Log.w("MainActivity", "Invalid audio encryption key size: ${key.size}")
            return
        }
        audioEncryptionKey = key
        Log.i("MainActivity", "Audio encryption key set (${key.size} bytes)")
    }

    fun clearAudioEncryptionKey() {
        audioEncryptionKey = null
    }

    /**
     * Handle incoming audio from iOS via WebSocket — route directly to native
     * AudioStreamManager without passing through Flutter Dart.
     * Payload format: [encryptedFlag (1 byte)] [audio data]
     *   encryptedFlag 0x01 = AES-256-GCM encrypted, 0x00 = raw PCM
     */
    private fun handleIncomingAudioNatively(payload: ByteArray) {
        if (payload.isEmpty()) return

        val encryptedFlag = payload[0]
        val audioData = payload.copyOfRange(1, payload.size)

        val pcmData = if (encryptedFlag == 0x01.toByte() && audioEncryptionKey != null) {
            decryptAudioChunk(audioData, audioEncryptionKey!!) ?: return
        } else {
            audioData
        }

        // Feed directly to native audio playback
        audioStreamManager?.playAudioChunk(pcmData)
    }

    /**
     * Send audio from native Android mic capture directly to iOS via WebSocket.
     * Called from AudioStreamManager callback. Bypasses Flutter Dart entirely.
     * Packet format: [0x01 protocol] [encryptedFlag] [audio data]
     */
    private fun sendAudioNatively(pcmData: ByteArray) {
        val key = audioEncryptionKey

        val payload: ByteArray
        if (key != null) {
            val encrypted = encryptAudioChunk(pcmData, key) ?: return
            // [0x01] [0x01 = encrypted] [encrypted data]
            payload = ByteArray(2 + encrypted.size)
            payload[0] = 0x01
            payload[1] = 0x01
            System.arraycopy(encrypted, 0, payload, 2, encrypted.size)
        } else {
            // [0x01] [0x00 = unencrypted] [PCM data]
            payload = ByteArray(2 + pcmData.size)
            payload[0] = 0x01
            payload[1] = 0x00
            System.arraycopy(pcmData, 0, payload, 2, pcmData.size)
        }

        webSocketServer?.broadcastBinary(payload)
    }

    // ========================================================================
    // AES-256-GCM Audio Encryption (Android)
    // ========================================================================

    private fun encryptAudioChunk(plaintext: ByteArray, key: ByteArray): ByteArray? {
        return try {
            val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
            val secretKey = javax.crypto.spec.SecretKeySpec(key, "AES")
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, secretKey)
            val iv = cipher.iv // GCM generates a 12-byte IV automatically
            val ciphertext = cipher.doFinal(plaintext)
            // Output: [12-byte IV] [ciphertext + 16-byte tag (appended by GCM)]
            val result = ByteArray(iv.size + ciphertext.size)
            System.arraycopy(iv, 0, result, 0, iv.size)
            System.arraycopy(ciphertext, 0, result, iv.size, ciphertext.size)
            result
        } catch (e: Exception) {
            Log.e("MainActivity", "Audio encrypt error: ${e.message}")
            null
        }
    }

    private fun decryptAudioChunk(encrypted: ByteArray, key: ByteArray): ByteArray? {
        return try {
            if (encrypted.size < 28) return null // 12 IV + 16 tag minimum
            val iv = encrypted.copyOfRange(0, 12)
            val ciphertext = encrypted.copyOfRange(12, encrypted.size)
            val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
            val secretKey = javax.crypto.spec.SecretKeySpec(key, "AES")
            val spec = javax.crypto.spec.GCMParameterSpec(128, iv)
            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKey, spec)
            cipher.doFinal(ciphertext)
        } catch (e: Exception) {
            Log.e("MainActivity", "Audio decrypt error: ${e.message}")
            null
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

