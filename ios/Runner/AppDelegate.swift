import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    private static let CHANNEL_BLE = "com.bridge.phone/ble"
    private static let EVENT_CHANNEL_BLE = "com.bridge.phone/ble_events"
    private static let CHANNEL_NOTIFICATION = "com.bridge.phone/notification"
    private static let CHANNEL_AUDIO = "com.bridge.phone/audio"
    private static let EVENT_CHANNEL_AUDIO = "com.bridge.phone/audio_events"
    private static let CHANNEL_WEBSOCKET = "com.bridge.phone/websocket"
    private static let EVENT_CHANNEL_WEBSOCKET = "com.bridge.phone/websocket_events"
    
    private var bleManager: BLECentralManager?
    private var eventSink: FlutterEventSink?
    private var eventSink: FlutterEventSink?
    static var audioEventSink: FlutterEventSink?
    private var webSocketEventSink: FlutterEventSink?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Initialize BLE Manager (use singleton)
        bleManager = BLECentralManager.shared
        bleManager?.delegate = self
        
        // Register with PowerManager for background optimization
        PowerManager.shared.register(service: BLECentralManager.shared)
        
        // Setup platform channels
        setupMethodChannel()
        setupNotificationChannel()
        setupAudioChannel()
        setupWebSocketChannel()
        setupEventChannel()
        
        // Configure for background execution
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
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
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
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
                      let deviceId = args["deviceId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "deviceId required", details: nil))
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
                
            case "sendCommand":
                guard let args = call.arguments as? [String: Any],
                      let command = args["command"] as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "command required", details: nil))
                    return
                }
                let success = self.bleManager?.sendCommand(command) ?? false
                result(success)
                
            case "sendSMS":
                guard let args = call.arguments as? [String: Any],
                      let to = args["to"] as? String,
                      let body = args["body"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "to and body required", details: nil))
                    return
                }
                let success = self.bleManager?.sendSMS(to: to, body: body) ?? false
                result(success)
                
            case "makeCall":
                guard let args = call.arguments as? [String: Any],
                      let phoneNumber = args["phoneNumber"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "phoneNumber required", details: nil))
                    return
                }
                let success = self.bleManager?.makeCall(to: phoneNumber) ?? false
                result(success)
                
            case "sendBulkData":
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? FlutterStandardTypedData else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "data required", details: nil))
                    return
                }
                let success = self.bleManager?.sendBulkData(data.data) ?? false
                result(success)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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
                   let id = args["id"] as? String {
                    let packageName = args["packageName"] as? String ?? ""
                    NotificationHandler.shared.showNotification(
                        title: title,
                        body: body,
                        identifier: id,
                        userInfo: ["packageName": packageName]
                    )
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing arguments", details: nil))
                }
                
            case "removeNotification":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String {
                    NotificationHandler.shared.removeNotification(identifier: id)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "id required", details: nil))
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
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Audio data required", details: nil))
                }
                
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
                   let host = args["host"] as? String {
                    let port = args["port"] as? Int ?? 8765
                    WebSocketClient.shared.delegate = self
                    WebSocketClient.shared.connect(host: host, port: port)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "host required", details: nil))
                }
                
            case "disconnect":
                WebSocketClient.shared.disconnect()
                result(nil)
                
            case "send":
                if let args = call.arguments as? [String: Any],
                   let message = args["message"] as? String {
                    WebSocketClient.shared.send(message) { error in
                        if let error = error {
                            result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
                        } else {
                            result(true)
                        }
                    }
                } else if let args = call.arguments as? [String: Any],
                          let dataBytes = args["data"] as? FlutterStandardTypedData {
                     // Support for sending binary from Flutter to WebSocket
                     WebSocketClient.shared.send(data: dataBytes.data) { error in
                        if let error = error {
                            result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
                        } else {
                            result(true)
                        }
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "message or data required", details: nil))
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
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
        }
    }
}

// MARK: - FlutterStreamHandler

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
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
        sendEvent(type: "deviceDiscovered", data: [
            "id": id,
            "name": name ?? "Unknown",
            "rssi": rssi
        ])
    }
    
    func didConnect(deviceId: String) {
        sendEvent(type: "deviceConnected", data: [
            "address": deviceId
        ])
    }
    
    func didDisconnect(deviceId: String, error: Error?) {
        sendEvent(type: "deviceDisconnected", data: [
            "address": deviceId,
            "error": error?.localizedDescription ?? ""
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
        sendEvent(type: "error", data: [
            "code": code,
            "message": message
        ])
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
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
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
             let audioData = data.subdata(in: 1..<data.count)
             AudioStreamHandler.shared.playAudioChunk(data: audioData)
        } else {
            // Send generic binary event to Flutter
            if let sink = webSocketEventSink {
                sink([
                    "type": "binaryMessageReceived",
                    "data": ["data": FlutterStandardTypedData(bytes: data)],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
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
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
        }
    }
}

class WebSocketStreamHandlerDelegate: NSObject, FlutterStreamHandler {
    weak var delegate: AppDelegate?
    
    init(delegate: AppDelegate) {
        self.delegate = delegate
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
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
