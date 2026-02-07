package com.bridge.phone.ble

/**
 * Interface for handling BLE events and routing them to Flutter via platform channel
 */
interface BLEEventHandler {
    
    /**
     * Called when a device connects
     * @param deviceAddress MAC address of connected device
     * @param deviceName Name of connected device (if available)
     */
    fun onDeviceConnected(deviceAddress: String, deviceName: String?)
    
    /**
     * Called when a device disconnects
     * @param deviceAddress MAC address of disconnected device
     */
    fun onDeviceDisconnected(deviceAddress: String)
    
    /**
     * Called when a command is received from connected device
     * @param command JSON command string
     * @param requestId Request ID for response correlation
     */
    fun onCommandReceived(command: String, requestId: String?)
    
    /**
     * Called when connection status changes
     * @param status One of BLEConstants.Status values
     */
    fun onStatusChanged(status: String)
    
    /**
     * Called when an error occurs
     * @param errorCode Error code
     * @param errorMessage Human-readable error message
     */
    fun onError(errorCode: Int, errorMessage: String)
    
    /**
     * Called when MTU is negotiated with connected device
     * @param mtu The negotiated MTU size
     */
    fun onMtuChanged(mtu: Int)
}
