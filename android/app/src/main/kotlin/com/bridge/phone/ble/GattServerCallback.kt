package com.bridge.phone.ble

import android.bluetooth.*
import android.util.Log

/**
 * Callback handler for GATT server events
 * Handles connection state changes, read/write requests, and notifications
 */
class GattServerCallback(
    private val eventHandler: BLEEventHandler,
    private val onReadRequest: (BluetoothDevice, Int, BluetoothGattCharacteristic) -> ByteArray?,
    private val onWriteRequest: (BluetoothDevice, BluetoothGattCharacteristic, ByteArray) -> Boolean
) : BluetoothGattServerCallback() {

    companion object {
        private const val TAG = "GattServerCallback"
    }

    private val connectedDevices = mutableSetOf<BluetoothDevice>()
    private var currentMtu = BLEConstants.DEFAULT_MTU

    // ============================================================================
    // Connection State
    // ============================================================================

    override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
        super.onConnectionStateChange(device, status, newState)
        
        when (newState) {
            BluetoothProfile.STATE_CONNECTED -> {
                Log.i(TAG, "Device connected: ${device.address}")
                connectedDevices.add(device)
                eventHandler.onDeviceConnected(device.address, device.name)
                
                if (connectedDevices.size == 1) {
                    eventHandler.onStatusChanged(BLEConstants.Status.CONNECTED)
                }
            }
            BluetoothProfile.STATE_DISCONNECTED -> {
                Log.i(TAG, "Device disconnected: ${device.address}")
                connectedDevices.remove(device)
                eventHandler.onDeviceDisconnected(device.address)
                
                if (connectedDevices.isEmpty()) {
                    eventHandler.onStatusChanged(BLEConstants.Status.ADVERTISING)
                }
            }
        }
        
        if (status != BluetoothGatt.GATT_SUCCESS) {
            Log.e(TAG, "Connection state change error: status=$status")
            eventHandler.onError(status, "Connection state change failed")
        }
    }

    // ============================================================================
    // Read Requests
    // ============================================================================

    override fun onCharacteristicReadRequest(
        device: BluetoothDevice,
        requestId: Int,
        offset: Int,
        characteristic: BluetoothGattCharacteristic
    ) {
        Log.d(TAG, "Read request for ${characteristic.uuid}")
        
        val data = onReadRequest(device, offset, characteristic)
        
        if (data != null) {
            gattServer?.sendResponse(
                device,
                requestId,
                BluetoothGatt.GATT_SUCCESS,
                offset,
                data
            )
        } else {
            gattServer?.sendResponse(
                device,
                requestId,
                BluetoothGatt.GATT_FAILURE,
                0,
                null
            )
        }
    }

    // ============================================================================
    // Write Requests
    // ============================================================================

    override fun onCharacteristicWriteRequest(
        device: BluetoothDevice,
        requestId: Int,
        characteristic: BluetoothGattCharacteristic,
        preparedWrite: Boolean,
        responseNeeded: Boolean,
        offset: Int,
        value: ByteArray
    ) {
        Log.d(TAG, "Write request for ${characteristic.uuid}, ${value.size} bytes")
        
        val success = onWriteRequest(device, characteristic, value)
        
        if (responseNeeded) {
            gattServer?.sendResponse(
                device,
                requestId,
                if (success) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_FAILURE,
                0,
                null
            )
        }
    }

    // ============================================================================
    // Descriptor Requests (for CCCD - notification subscriptions)
    // ============================================================================

    override fun onDescriptorReadRequest(
        device: BluetoothDevice,
        requestId: Int,
        offset: Int,
        descriptor: BluetoothGattDescriptor
    ) {
        if (descriptor.uuid == BLEConstants.DESCRIPTOR_CCCD) {
            val value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
        } else {
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
        }
    }

    override fun onDescriptorWriteRequest(
        device: BluetoothDevice,
        requestId: Int,
        descriptor: BluetoothGattDescriptor,
        preparedWrite: Boolean,
        responseNeeded: Boolean,
        offset: Int,
        value: ByteArray
    ) {
        if (descriptor.uuid == BLEConstants.DESCRIPTOR_CCCD) {
            // Client is subscribing to notifications
            val notificationsEnabled = value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            Log.d(TAG, "Notifications ${if (notificationsEnabled) "enabled" else "disabled"} for ${descriptor.characteristic?.uuid}")
            
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }
        } else {
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
            }
        }
    }

    // ============================================================================
    // MTU Negotiation
    // ============================================================================

    override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
        Log.i(TAG, "MTU changed to $mtu for device ${device.address}")
        currentMtu = mtu
        eventHandler.onMtuChanged(mtu)
    }

    // ============================================================================
    // Notification Confirmation
    // ============================================================================

    override fun onNotificationSent(device: BluetoothDevice, status: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) {
            Log.w(TAG, "Notification send failed with status $status")
        }
    }

    // ============================================================================
    // Service Added Confirmation
    // ============================================================================

    override fun onServiceAdded(status: Int, service: BluetoothGattService) {
        if (status == BluetoothGatt.GATT_SUCCESS) {
            Log.i(TAG, "Service added: ${service.uuid}")
        } else {
            Log.e(TAG, "Failed to add service ${service.uuid}, status=$status")
            eventHandler.onError(status, "Failed to add service ${service.uuid}")
        }
    }

    // ============================================================================
    // Helpers
    // ============================================================================

    fun getConnectedDevices(): Set<BluetoothDevice> = connectedDevices.toSet()
    
    fun getCurrentMtu(): Int = currentMtu
    
    fun isDeviceConnected(address: String): Boolean = 
        connectedDevices.any { it.address == address }

    // Reference to GATT server (set by BLEPeripheralManager)
    var gattServer: BluetoothGattServer? = null
}
