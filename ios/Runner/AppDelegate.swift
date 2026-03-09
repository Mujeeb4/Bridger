import Flutter
import UIKit
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    private static let CHANNEL_BLE = "com.bridge.phone/ble"
    private static let EVENT_CHANNEL_BLE = "com.bridge.phone/ble_events"
    private static let CHANNEL_NOTIFICATION = "com.bridge.phone/notification"
    private static let CHANNEL_AUDIO = "com.bridge.phone/audio"
    private static let EVENT_CHANNEL_AUDIO = "com.bridge.phone/audio_events"
    private static let CHANNEL_WEBSOCKET = "com.bridge.phone/websocket"
    private static let EVENT_CHANNEL_WEBSOCKET = "com.bridge.phone/websocket_events"
    private static let CHANNEL_CALL = "com.bridge.phone/call"
    private static let EVENT_CHANNEL_CALL = "com.bridge.phone/call_events"
    private static let CHANNEL_HOTSPOT = "com.bridge.phone/hotspot"
    private static let EVENT_CHANNEL_HOTSPOT = "com.bridge.phone/hotspot_events"

    private var bleManager: BLECentralManager?
    private var callKitHandler: CallKitHandler?
    private var eventSink: FlutterEventSink?
    private var callEventSink: FlutterEventSink?

    static var audioEventSink: FlutterEventSink?
    private var webSocketEventSink: FlutterEventSink?
    private var hotspotEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Initialize BLE Manager (use singleton)
        bleManager = BLECentralManager.shared
        bleManager?.delegate = self

        // Initialize CallKit Handler
        callKitHandler = CallKitHandler.shared
        callKitHandler?.delegate = self

        // Register with PowerManager for background optimization
        PowerManager.shared.register(service: BLECentralManager.shared)

        // Setup platform channels
        setupMethodChannel()
        setupNotificationChannel()
        setupAudioChannel()
        setupWebSocketChannel()
        setupCallChannel()
        setupHotspotChannel()
        setupEventChannel()

        // Background task registration is handled by flutter_foreground_task plugin.
        // Do NOT register BGTask identifiers here — the plugin already does it,
        // and duplicate registration causes a fatal NSInternalInconsistencyException.

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.CHANNEL_BLE,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(
                    FlutterError(
                        code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
                return
            }

            switch call.method {
            case "initialize":
                // BLE manager is already initialized
                result(true)

            case "startScanning":
                self.bleManager?.startScanning()
                result(nil)

            case "stopScanning":
                self.bleManager?.stopScanning()
                result(nil)

            case "connect":
                guard let args = call.arguments as? [String: Any],
                    let deviceId = args["deviceId"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "deviceId required", details: nil))
                    return
                }
                self.bleManager?.connect(deviceId: deviceId)
                result(nil)

            case "disconnect":
                self.bleManager?.disconnect()
                result(nil)

            case "isConnected":
                result(self.bleManager?.isConnected() ?? false)

            case "getConnectedDeviceId":
                result(self.bleManager?.getConnectedDeviceId())

            case "getState":
                result(self.bleManager?.getState().rawValue ?? "IDLE")

            case "getServicesReady":
                result(self.bleManager?.isReadyForCommunication() ?? false)

            case "sendCommand":
                guard let args = call.arguments as? [String: Any] else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "command required", details: nil))
                    return
                }
                // Dart side sends the command as a JSON string OR a dictionary.
                // Handle both cases so the bridge never silently drops commands.
                var success = false
                if let commandDict = args["command"] as? [String: Any] {
                    // Already a dictionary — pass directly
                    success = self.bleManager?.sendCommand(commandDict) ?? false
                } else if let commandStr = args["command"] as? String,
                          let data = commandStr.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // JSON string — deserialize then pass
                    success = self.bleManager?.sendCommand(json) ?? false
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "command must be a map or JSON string", details: nil))
                    return
                }
                result(success)

            case "discoverServices":
                self.bleManager?.rediscoverServices()
                result(nil)

            case "startPairing":
                guard let args = call.arguments as? [String: Any],
                      let code = args["code"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "code required", details: nil)
                    )
                    return
                }
                self.bleManager?.startPairing(code: code)
                result(nil)


            case "sendSMS":
                guard let args = call.arguments as? [String: Any],
                    let to = args["to"] as? String,
                    let body = args["body"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "to and body required", details: nil)
                    )
                    return
                }
                let success = self.bleManager?.sendSMS(to: to, body: body) ?? false
                result(success)

            case "makeCall":
                guard let args = call.arguments as? [String: Any],
                    let phoneNumber = args["phoneNumber"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "phoneNumber required", details: nil)
                    )
                    return
                }
                let success = self.bleManager?.makeCall(to: phoneNumber) ?? false
                result(success)

            case "sendBulkData":
                guard let args = call.arguments as? [String: Any],
                    let data = args["data"] as? FlutterStandardTypedData
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "data required", details: nil))
                    return
                }
                let success = self.bleManager?.sendBulkData(data.data) ?? false
                result(success)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupCallChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.CHANNEL_CALL,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
                return
            }

            switch call.method {
            case "reportIncomingCall":
                guard let args = call.arguments as? [String: Any],
                      let phoneNumber = args["phoneNumber"] as? String
                else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "phoneNumber required", details: nil))
                    return
                }
                self.callKitHandler?.reportIncomingCall(phoneNumber: phoneNumber) { error in
                    if let error = error {
                        result(FlutterError(code: "CALLKIT_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        result(true)
                    }
                }

            case "endCall":
                self.callKitHandler?.endCall { error in
                    result(error == nil)
                }

            case "reportCallEnded":
                self.callKitHandler?.reportCallEnded()
                result(nil)

            case "reportCallConnected":
                self.callKitHandler?.reportCallConnected()
                result(nil)

            case "answerCall":
                // iOS can't programmatically answer — CallKit handles this via UI
                result(true)

            case "setSpeakerphone":
                if let args = call.arguments as? [String: Any],
                   let enabled = args["enabled"] as? Bool {
                    do {
                        let session = AVAudioSession.sharedInstance()
                        if enabled {
                            try session.overrideOutputAudioPort(.speaker)
                        } else {
                            try session.overrideOutputAudioPort(.none)
                        }
                        result(true)
                    } catch {
                        result(FlutterError(code: "AUDIO_ERROR", message: error.localizedDescription, details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "enabled required", details: nil))
                }

            case "setMuted":
                // Muting is handled by the audio engine; not directly via CallKit
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Call Event Channel — sends CallKit events (answer/end/mute) to Flutter
        let callEventChannel = FlutterEventChannel(
            name: AppDelegate.EVENT_CHANNEL_CALL,
            binaryMessenger: controller.binaryMessenger
        )
        callEventChannel.setStreamHandler(CallEventStreamHandler(delegate: self))
    }

    private func setupHotspotChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.CHANNEL_HOTSPOT,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
                return
            }

            switch call.method {
            case "isSupported":
                result(true)

            case "connectToHotspot":
                guard let args = call.arguments as? [String: Any],
                      let ssid = args["ssid"] as? String,
                      let password = args["password"] as? String
                else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "ssid and password required", details: nil))
                    return
                }

                let manager = HotspotManager.shared
                manager.delegate = self
                self.pendingHotspotResult = result
                manager.connectToHotspot(ssid: ssid, password: password)

            case "disconnectFromHotspot":
                HotspotManager.shared.disconnect()
                self.sendHotspotEvent(type: "disconnected", data: [:])
                result(nil)

            case "isActive":
                result(HotspotManager.shared.isConnected)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Hotspot Event Channel
        let eventChannel = FlutterEventChannel(
            name: AppDelegate.EVENT_CHANNEL_HOTSPOT,
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(HotspotEventStreamHandler(delegate: self))
    }

    private var pendingHotspotResult: FlutterResult?

    private func sendHotspotEvent(type: String, data: [String: Any]) {
        guard let sink = hotspotEventSink else { return }
        DispatchQueue.main.async {
            sink([
                "type": type,
                "data": data,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            ])
        }
    }

    func registerHotspotEventSink(_ sink: FlutterEventSink?) {
        self.hotspotEventSink = sink
    }

    private func setupEventChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let eventChannel = FlutterEventChannel(
            name: AppDelegate.EVENT_CHANNEL_BLE,
            binaryMessenger: controller.binaryMessenger
        )

        eventChannel.setStreamHandler(self)
    }

    private func setupNotificationChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.CHANNEL_NOTIFICATION,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "requestPermission":
                NotificationHandler.shared.requestPermission()
                result(true)

            case "showNotification":
                if let args = call.arguments as? [String: Any],
                    let title = args["title"] as? String,
                    let body = args["body"] as? String,
                    let id = args["id"] as? String
                {
                    let packageName = args["packageName"] as? String ?? ""
                    let appName = args["appName"] as? String ?? packageName
                    NotificationHandler.shared.showNotification(
                        title: title,
                        body: body,
                        identifier: id,
                        userInfo: [
                            "packageName": packageName,
                            "appName": appName,
                        ]
                    )
                    result(nil)
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "Missing arguments", details: nil))
                }

            case "removeNotification":
                if let args = call.arguments as? [String: Any],
                    let id = args["id"] as? String
                {
                    NotificationHandler.shared.removeNotification(identifier: id)
                    result(nil)
                } else {
                    result(
                        FlutterError(code: "INVALID_ARGUMENT", message: "id required", details: nil)
                    )
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupAudioChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.CHANNEL_AUDIO,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "startStreaming":
                AudioStreamHandler.shared.delegate = self
                AudioStreamHandler.shared.startStreaming()
                result(nil)

            case "stopStreaming":
                AudioStreamHandler.shared.stopStreaming()
                result(nil)

            case "writeAudioChunk":
                if let args = call.arguments as? FlutterStandardTypedData {
                    AudioStreamHandler.shared.playAudioChunk(data: args.data)
                    result(nil)
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "Audio data required", details: nil))
                }

            case "setEncryptionKey":
                if let args = call.arguments as? FlutterStandardTypedData, args.data.count == 32 {
                    AudioStreamHandler.shared.setEncryptionKey(args.data)
                    result(nil)
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_KEY", message: "Encryption key must be 32 bytes", details: nil))
                }

            case "clearEncryptionKey":
                AudioStreamHandler.shared.clearEncryptionKey()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Audio Event Channel
        let eventChannel = FlutterEventChannel(
            name: AppDelegate.EVENT_CHANNEL_AUDIO,
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(AudioStreamHandlerDelegate())
    }

    private func setupWebSocketChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.CHANNEL_WEBSOCKET,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "connect":
                if let args = call.arguments as? [String: Any],
                    let host = args["host"] as? String
                {
                    let port = args["port"] as? Int ?? 8765
                    WebSocketClient.shared.delegate = self
                    WebSocketClient.shared.connect(host: host, port: port)
                    result(true)
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "host required", details: nil))
                }

            case "disconnect":
                WebSocketClient.shared.disconnect()
                result(nil)

            case "send":
                if let args = call.arguments as? [String: Any],
                    let message = args["message"] as? String
                {
                    WebSocketClient.shared.send(message) { error in
                        if let error = error {
                            result(
                                FlutterError(
                                    code: "SEND_FAILED", message: error.localizedDescription,
                                    details: nil))
                        } else {
                            result(true)
                        }
                    }
                } else if let args = call.arguments as? [String: Any],
                    let dataBytes = args["data"] as? FlutterStandardTypedData
                {
                    // Support for sending binary from Flutter to WebSocket
                    WebSocketClient.shared.send(data: dataBytes.data) { error in
                        if let error = error {
                            result(
                                FlutterError(
                                    code: "SEND_FAILED", message: error.localizedDescription,
                                    details: nil))
                        } else {
                            result(true)
                        }
                    }
                } else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "message or data required",
                            details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // WebSocket Event Channel
        let eventChannel = FlutterEventChannel(
            name: AppDelegate.EVENT_CHANNEL_WEBSOCKET,
            binaryMessenger: controller.binaryMessenger
        )
        eventChannel.setStreamHandler(WebSocketStreamHandlerDelegate(delegate: self))
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        // BLE continues in background with proper Info.plist configuration
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        // Reconnect if needed
    }

    private func sendEvent(type: String, data: [String: Any]) {
        guard let sink = eventSink else { return }

        DispatchQueue.main.async {
            sink([
                "type": type,
                "data": data,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            ])
        }
    }

    /// Send call-specific events via the call EventChannel
    private func sendCallEvent(type: String, data: [String: Any]) {
        guard let sink = callEventSink else { return }

        DispatchQueue.main.async {
            sink([
                "type": type,
                "data": data,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            ])
        }
    }

    func registerCallEventSink(_ sink: FlutterEventSink?) {
        self.callEventSink = sink
    }
}

// MARK: - FlutterStreamHandler

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - BLECentralManagerDelegate

extension AppDelegate: BLECentralManagerDelegate {
    func didDiscoverDevice(id: String, name: String?, rssi: Int) {
        sendEvent(
            type: "deviceDiscovered",
            data: [
                "id": id,
                "name": name ?? "Unknown",
                "rssi": rssi,
            ])
    }

    func didConnect(deviceId: String) {
        sendEvent(
            type: "deviceConnected",
            data: [
                "address": deviceId
            ])
    }

    func didDisconnect(deviceId: String, error: Error?) {
        sendEvent(
            type: "deviceDisconnected",
            data: [
                "address": deviceId,
                "error": error?.localizedDescription ?? "",
            ])
    }

    func didReceiveSmsAlert(data: String) {
        sendEvent(type: "smsAlert", data: ["data": data])
    }

    func didReceiveCallAlert(data: String) {
        sendEvent(type: "callAlert", data: ["data": data])
    }

    func didReceiveAppNotification(data: String) {
        sendEvent(type: "appNotification", data: ["data": data])
    }

    func didReceiveStatusUpdate(data: String) {
        sendEvent(type: "statusUpdate", data: ["data": data])
    }

    func didReceiveBulkData(data: Data) {
        sendEvent(type: "bulkData", data: ["data": data.base64EncodedString()])
    }

    func didUpdateState(state: BLEConstants.ConnectionState) {
        sendEvent(type: "statusChanged", data: ["status": state.rawValue])
    }

    func didError(code: Int, message: String) {
        sendEvent(
            type: "error",
            data: [
                "code": code,
                "message": message,
            ])
    }

    func didBecomeReadyForCommunication() {
        sendEvent(type: "servicesReady", data: [:])
    }

    func didLog(message: String) {
        sendEvent(type: "log", data: ["message": message])
    }
}

// MARK: - AudioStreamDelegate
extension AppDelegate: AudioStreamDelegate {
    func onAudioDataCaptured(data: Data) {
        // Send raw bytes via EventChannel
        if let sink = AppDelegate.audioEventSink {
            sink(FlutterStandardTypedData(bytes: data))
        }
    }
}

// Helper class for Audio Event Channel
class AudioStreamHandlerDelegate: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        AppDelegate.audioEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        AppDelegate.audioEventSink = nil
        return nil
    }
}

// MARK: - WebSocketClientDelegate
extension AppDelegate: WebSocketClientDelegate {
    func webSocketClientDidConnect(_ client: WebSocketClient) {
        sendWebSocketEvent(type: "connected", data: [:])
    }

    func webSocketClientDidDisconnect(_ client: WebSocketClient) {
        sendWebSocketEvent(type: "disconnected", data: [:])
    }

    func webSocketClient(_ client: WebSocketClient, didReceiveMessage message: String) {
        sendWebSocketEvent(type: "messageReceived", data: ["message": message])
    }

    func webSocketClient(_ client: WebSocketClient, didReceiveData data: Data) {
        // Check for Audio Protocol (0x01 prefix)
        if !data.isEmpty && data[0] == 0x01 {
            // Audio data — route directly to native audio engine (bypasses Flutter for low latency)
            let audioPayload = data.subdata(in: 1..<data.count)
            AudioStreamHandler.shared.receiveAudioFromRemote(data: audioPayload)
        } else {
            // Send generic binary event to Flutter
            if let sink = webSocketEventSink {
                sink([
                    "type": "binaryMessageReceived",
                    "data": ["data": FlutterStandardTypedData(bytes: data)],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                ])
            }
        }
    }

    func webSocketClient(_ client: WebSocketClient, didFailWithError error: String) {
        sendWebSocketEvent(type: "error", data: ["message": error])
    }

    private func sendWebSocketEvent(type: String, data: [String: Any]) {
        guard let sink = webSocketEventSink else { return }

        DispatchQueue.main.async {
            sink([
                "type": type,
                "data": data,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            ])
        }
    }
}

class WebSocketStreamHandlerDelegate: NSObject, FlutterStreamHandler {
    weak var delegate: AppDelegate?

    init(delegate: AppDelegate) {
        self.delegate = delegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        delegate?.registerWebSocketSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        delegate?.registerWebSocketSink(nil)
        return nil
    }
}

extension AppDelegate {
    func registerWebSocketSink(_ sink: FlutterEventSink?) {
        self.webSocketEventSink = sink
    }
}

// Helper class for Call Event Channel
class CallEventStreamHandler: NSObject, FlutterStreamHandler {
    weak var delegate: AppDelegate?

    init(delegate: AppDelegate) {
        self.delegate = delegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        delegate?.registerCallEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        delegate?.registerCallEventSink(nil)
        return nil
    }
}

// MARK: - CallKitHandlerDelegate
extension AppDelegate: CallKitHandlerDelegate {
    func callKitHandler(_ handler: CallKitHandler, didAnswerCall phoneNumber: String) {
        // User tapped "Answer" on CallKit UI — send to Flutter CallService
        sendCallEvent(type: "answered", data: ["phoneNumber": phoneNumber])
        
        // Audio streaming is started by CallKitHandler in provider(_:didActivate:)
        // when the audio session is actually ready
    }

    func callKitHandler(_ handler: CallKitHandler, didEndCall phoneNumber: String) {
        // User tapped "End/Reject" on CallKit UI — send to Flutter CallService
        sendCallEvent(type: "ended", data: ["phoneNumber": phoneNumber])
        
        // Audio streaming is stopped by CallKitHandler in provider(_:didDeactivate:)
    }

    func callKitHandler(_ handler: CallKitHandler, didMuteCall muted: Bool) {
        sendCallEvent(type: "callMuted", data: ["muted": muted])
    }
}

// MARK: - HotspotManagerDelegate
extension AppDelegate: HotspotManagerDelegate {
    func hotspotManagerDidConnect(_ manager: HotspotManager, ssid: String) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingHotspotResult?(true)
            self?.pendingHotspotResult = nil
            self?.sendHotspotEvent(type: "connected", data: ["ssid": ssid])
        }
    }

    func hotspotManagerDidDisconnect(_ manager: HotspotManager) {
        sendHotspotEvent(type: "disconnected", data: [:])
    }

    func hotspotManager(_ manager: HotspotManager, didFailWithError error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingHotspotResult?(false)
            self?.pendingHotspotResult = nil
            self?.sendHotspotEvent(type: "error", data: ["message": error])
        }
    }
}

// MARK: - Hotspot Event Stream Handler
class HotspotEventStreamHandler: NSObject, FlutterStreamHandler {
    weak var delegate: AppDelegate?

    init(delegate: AppDelegate) {
        self.delegate = delegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        delegate?.registerHotspotEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        delegate?.registerHotspotEventSink(nil)
        return nil
    }
}
