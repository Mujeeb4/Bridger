import Foundation
import CoreBluetooth

/// BLE Constants matching Android and Flutter
/// These UUIDs define the GATT services and characteristics for Bridge Phone
struct BLEConstants {
    
    // MARK: - Service UUIDs
    
    /// Control Service - Commands and status
    static let serviceControlUUID = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
    
    /// Notification Service - Real-time SMS/Call/App alerts
    static let serviceNotificationUUID = CBUUID(string: "0000180B-0000-1000-8000-00805F9B34FB")
    
    /// Data Service - Bulk data transfer
    static let serviceDataUUID = CBUUID(string: "0000180C-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Characteristic UUIDs - Control Service
    
    /// Command characteristic - Write only, send commands to Android
    static let charCommandUUID = CBUUID(string: "00002A00-0000-1000-8000-00805F9B34FB")
    
    /// Status characteristic - Read/Notify, device/connection status
    static let charStatusUUID = CBUUID(string: "00002A01-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Characteristic UUIDs - Notification Service
    
    /// SMS Alert characteristic - Notify, receive SMS alerts
    static let charSmsAlertUUID = CBUUID(string: "00002A10-0000-1000-8000-00805F9B34FB")
    
    /// Call Alert characteristic - Notify, receive call status
    static let charCallAlertUUID = CBUUID(string: "00002A11-0000-1000-8000-00805F9B34FB")
    
    /// App Notification characteristic - Notify, receive app notifications
    static let charAppNotificationUUID = CBUUID(string: "00002A12-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Characteristic UUIDs - Data Service
    
    /// Bulk Transfer characteristic - Read/Write/Notify for large data
    static let charBulkTransferUUID = CBUUID(string: "00002A20-0000-1000-8000-00805F9B34FB")
    
    // MARK: - All Service UUIDs for scanning
    
    static let allServiceUUIDs: [CBUUID] = [
        serviceControlUUID,
        serviceNotificationUUID,
        serviceDataUUID
    ]
    
    // MARK: - Target Device Name
    
    static let targetDeviceName = "Bridge Phone"
    
    // MARK: - Connection State
    
    enum ConnectionState: String {
        case idle = "IDLE"
        case scanning = "SCANNING"
        case connecting = "CONNECTING"
        case connected = "CONNECTED"
        case disconnected = "DISCONNECTED"
        case error = "ERROR"
    }
    
    // MARK: - Command Types (to Android)
    
    struct Commands {
        static let sendSMS = "SEND_SMS"
        static let makeCall = "MAKE_CALL"
        static let endCall = "END_CALL"
        static let answerCall = "ANSWER_CALL"
        static let rejectCall = "REJECT_CALL"
        static let getSMSThreads = "GET_SMS_THREADS"
        static let getSMSMessages = "GET_SMS_MESSAGES"
        static let getCallLogs = "GET_CALL_LOGS"
        static let getContacts = "GET_CONTACTS"
        static let startHotspot = "START_HOTSPOT"
        static let stopHotspot = "STOP_HOTSPOT"
        static let ping = "PING"
    }
    
    // MARK: - Notification Types (from Android)
    
    struct NotificationTypes {
        static let smsReceived = "SMS_RECEIVED"
        static let smsSent = "SMS_SENT"
        static let callIncoming = "CALL_INCOMING"
        static let callOutgoing = "CALL_OUTGOING"
        static let callEnded = "CALL_ENDED"
        static let callMissed = "CALL_MISSED"
        static let appNotification = "APP_NOTIFICATION"
        static let hotspotStatus = "HOTSPOT_STATUS"
        static let connectionStatus = "CONNECTION_STATUS"
        static let pong = "PONG"
    }
}
