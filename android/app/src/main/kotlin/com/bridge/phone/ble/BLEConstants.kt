package com.bridge.phone.ble

import java.util.UUID

/**
 * BLE Constants matching Flutter's app_constants.dart
 * These UUIDs define the GATT services and characteristics for Bridge Phone
 */
object BLEConstants {
    
    // ============================================================================
    // Service UUIDs
    // ============================================================================
    
    /** Control Service - Commands and status */
    val SERVICE_CONTROL: UUID = UUID.fromString("0000180A-0000-1000-8000-00805F9B34FB")
    
    /** Notification Service - Real-time SMS/Call/App alerts */
    val SERVICE_NOTIFICATION: UUID = UUID.fromString("0000180B-0000-1000-8000-00805F9B34FB")
    
    /** Data Service - Bulk data transfer */
    val SERVICE_DATA: UUID = UUID.fromString("0000180C-0000-1000-8000-00805F9B34FB")
    
    // ============================================================================
    // Characteristic UUIDs - Control Service
    // ============================================================================
    
    /** Command characteristic - Write only, receives commands from iPhone */
    val CHAR_COMMAND: UUID = UUID.fromString("00002A00-0000-1000-8000-00805F9B34FB")
    
    /** Status characteristic - Read/Notify, reports device/connection status */
    val CHAR_STATUS: UUID = UUID.fromString("00002A01-0000-1000-8000-00805F9B34FB")
    
    // ============================================================================
    // Characteristic UUIDs - Notification Service
    // ============================================================================
    
    /** SMS Alert characteristic - Notify only, pushes new SMS alerts */
    val CHAR_SMS_ALERT: UUID = UUID.fromString("00002A10-0000-1000-8000-00805F9B34FB")
    
    /** Call Alert characteristic - Notify only, pushes call status */
    val CHAR_CALL_ALERT: UUID = UUID.fromString("00002A11-0000-1000-8000-00805F9B34FB")
    
    /** App Notification characteristic - Notify only, pushes app notifications */
    val CHAR_APP_NOTIFICATION: UUID = UUID.fromString("00002A12-0000-1000-8000-00805F9B34FB")
    
    // ============================================================================
    // Characteristic UUIDs - Data Service
    // ============================================================================
    
    /** Bulk Transfer characteristic - Read/Write/Notify for large data */
    val CHAR_BULK_TRANSFER: UUID = UUID.fromString("00002A20-0000-1000-8000-00805F9B34FB")
    
    // ============================================================================
    // Standard Descriptors
    // ============================================================================
    
    /** Client Characteristic Configuration Descriptor (CCCD) */
    val DESCRIPTOR_CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    
    // ============================================================================
    // Advertising Constants
    // ============================================================================
    
    const val DEVICE_NAME = "Bridge Phone"
    const val MANUFACTURER_ID = 0x1234 // Custom manufacturer ID
    
    // ============================================================================
    // Command Types (from iPhone)
    // ============================================================================
    
    object Commands {
        const val SEND_SMS = "SEND_SMS"
        const val MAKE_CALL = "MAKE_CALL"
        const val END_CALL = "END_CALL"
        const val ANSWER_CALL = "ANSWER_CALL"
        const val REJECT_CALL = "REJECT_CALL"
        const val GET_SMS_THREADS = "GET_SMS_THREADS"
        const val GET_SMS_MESSAGES = "GET_SMS_MESSAGES"
        const val GET_CALL_LOGS = "GET_CALL_LOGS"
        const val GET_CONTACTS = "GET_CONTACTS"
        const val START_HOTSPOT = "START_HOTSPOT"
        const val STOP_HOTSPOT = "STOP_HOTSPOT"
        const val PING = "PING"
    }
    
    // ============================================================================
    // Notification Types (to iPhone)
    // ============================================================================
    
    object NotificationTypes {
        const val SMS_RECEIVED = "SMS_RECEIVED"
        const val SMS_SENT = "SMS_SENT"
        const val CALL_INCOMING = "CALL_INCOMING"
        const val CALL_OUTGOING = "CALL_OUTGOING"
        const val CALL_ENDED = "CALL_ENDED"
        const val CALL_MISSED = "CALL_MISSED"
        const val APP_NOTIFICATION = "APP_NOTIFICATION"
        const val HOTSPOT_STATUS = "HOTSPOT_STATUS"
        const val CONNECTION_STATUS = "CONNECTION_STATUS"
        const val PONG = "PONG"
    }
    
    // ============================================================================
    // Status Values
    // ============================================================================
    
    object Status {
        const val IDLE = "IDLE"
        const val ADVERTISING = "ADVERTISING"
        const val CONNECTED = "CONNECTED"
        const val DISCONNECTED = "DISCONNECTED"
        const val ERROR = "ERROR"
    }
    
    // ============================================================================
    // Data Transfer Constants
    // ============================================================================
    
    /** Maximum bytes per BLE packet (ATT MTU - 3 overhead) */
    const val MAX_PACKET_SIZE = 509 // Typical max with MTU negotiation
    
    /** Default MTU size */
    const val DEFAULT_MTU = 23
}
