package com.bridge.phone.ble

import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import org.json.JSONObject
import java.nio.charset.StandardCharsets

/**
 * Manages BLE peripheral functionality - GATT server and advertising
 * Android device acts as a BLE peripheral that iPhone connects to
 */
class BLEPeripheralManager(
    private val context: Context,
    private val eventHandler: BLEEventHandler
) {
    companion object {
        private const val TAG = "BLEPeripheralManager"
    }

    private val bluetoothManager: BluetoothManager by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    }
    
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        bluetoothManager.adapter
    }
    
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattCallback: GattServerCallback? = null
    
    private var isAdvertising = false
    private var statusCharacteristic: BluetoothGattCharacteristic? = null
    private var smsAlertCharacteristic: BluetoothGattCharacteristic? = null
    private var callAlertCharacteristic: BluetoothGattCharacteristic? = null
    private var appNotificationCharacteristic: BluetoothGattCharacteristic? = null
    private var bulkTransferCharacteristic: BluetoothGattCharacteristic? = null

    // ============================================================================
    // Initialization
    // ============================================================================

    /**
     * Initialize the BLE peripheral - creates GATT server and services
     * @return true if successful
     */
    fun initialize(): Boolean {
        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not supported")
            eventHandler.onError(-1, "Bluetooth not supported")
            return false
        }

        if (!bluetoothAdapter!!.isEnabled) {
            Log.e(TAG, "Bluetooth not enabled")
            eventHandler.onError(-2, "Bluetooth not enabled")
            return false
        }

        advertiser = bluetoothAdapter!!.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e(TAG, "BLE advertising not supported")
            eventHandler.onError(-3, "BLE advertising not supported")
            return false
        }

        // Create GATT callback
        gattCallback = GattServerCallback(
            eventHandler = eventHandler,
            onReadRequest = ::handleReadRequest,
            onWriteRequest = ::handleWriteRequest
        )

        // Open GATT server
        gattServer = bluetoothManager.openGattServer(context, gattCallback)
        if (gattServer == null) {
            Log.e(TAG, "Failed to open GATT server")
            eventHandler.onError(-4, "Failed to open GATT server")
            return false
        }

        gattCallback!!.gattServer = gattServer

        // Add services
        addControlService()
        addNotificationService()
        addDataService()

        Log.i(TAG, "BLE Peripheral initialized successfully")
        eventHandler.onStatusChanged(BLEConstants.Status.IDLE)
        return true
    }

    // ============================================================================
    // Service Setup
    // ============================================================================

    private fun addControlService() {
        val service = BluetoothGattService(
            BLEConstants.SERVICE_CONTROL,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        // Command characteristic (write only)
        val commandChar = BluetoothGattCharacteristic(
            BLEConstants.CHAR_COMMAND,
            BluetoothGattCharacteristic.PROPERTY_WRITE or 
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(commandChar)

        // Status characteristic (read + notify)
        statusCharacteristic = BluetoothGattCharacteristic(
            BLEConstants.CHAR_STATUS,
            BluetoothGattCharacteristic.PROPERTY_READ or 
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        statusCharacteristic!!.addDescriptor(createCccdDescriptor())
        service.addCharacteristic(statusCharacteristic!!)

        gattServer?.addService(service)
        Log.d(TAG, "Control service added")
    }

    private fun addNotificationService() {
        val service = BluetoothGattService(
            BLEConstants.SERVICE_NOTIFICATION,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        // SMS Alert characteristic (notify only)
        smsAlertCharacteristic = BluetoothGattCharacteristic(
            BLEConstants.CHAR_SMS_ALERT,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        smsAlertCharacteristic!!.addDescriptor(createCccdDescriptor())
        service.addCharacteristic(smsAlertCharacteristic!!)

        // Call Alert characteristic (notify only)
        callAlertCharacteristic = BluetoothGattCharacteristic(
            BLEConstants.CHAR_CALL_ALERT,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        callAlertCharacteristic!!.addDescriptor(createCccdDescriptor())
        service.addCharacteristic(callAlertCharacteristic!!)

        // App Notification characteristic (notify only)
        appNotificationCharacteristic = BluetoothGattCharacteristic(
            BLEConstants.CHAR_APP_NOTIFICATION,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        appNotificationCharacteristic!!.addDescriptor(createCccdDescriptor())
        service.addCharacteristic(appNotificationCharacteristic!!)

        gattServer?.addService(service)
        Log.d(TAG, "Notification service added")
    }

    private fun addDataService() {
        val service = BluetoothGattService(
            BLEConstants.SERVICE_DATA,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        // Bulk Transfer characteristic (read + write + notify)
        bulkTransferCharacteristic = BluetoothGattCharacteristic(
            BLEConstants.CHAR_BULK_TRANSFER,
            BluetoothGattCharacteristic.PROPERTY_READ or
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or 
                BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        bulkTransferCharacteristic!!.addDescriptor(createCccdDescriptor())
        service.addCharacteristic(bulkTransferCharacteristic!!)

        gattServer?.addService(service)
        Log.d(TAG, "Data service added")
    }

    private fun createCccdDescriptor(): BluetoothGattDescriptor {
        return BluetoothGattDescriptor(
            BLEConstants.DESCRIPTOR_CCCD,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
    }

    // ============================================================================
    // Advertising
    // ============================================================================

    /**
     * Start BLE advertising
     */
    fun startAdvertising() {
        if (isAdvertising) {
            Log.w(TAG, "Already advertising")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0) // Advertise indefinitely
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(BLEConstants.SERVICE_CONTROL))
            .build()

        val scanResponse = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(BLEConstants.SERVICE_NOTIFICATION))
            .addServiceUuid(ParcelUuid(BLEConstants.SERVICE_DATA))
            .build()

        advertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
    }

    /**
     * Stop BLE advertising
     */
    fun stopAdvertising() {
        if (!isAdvertising) {
            Log.w(TAG, "Not advertising")
            return
        }

        advertiser?.stopAdvertising(advertiseCallback)
        isAdvertising = false
        eventHandler.onStatusChanged(BLEConstants.Status.IDLE)
        Log.i(TAG, "Advertising stopped")
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            isAdvertising = true
            eventHandler.onStatusChanged(BLEConstants.Status.ADVERTISING)
            Log.i(TAG, "Advertising started successfully")
        }

        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
            val message = when (errorCode) {
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                ADVERTISE_FAILED_ALREADY_STARTED -> "Already started"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                else -> "Unknown error"
            }
            Log.e(TAG, "Advertising failed: $message (code: $errorCode)")
            eventHandler.onError(errorCode, "Advertising failed: $message")
        }
    }

    // ============================================================================
    // Request Handlers
    // ============================================================================

    private fun handleReadRequest(
        device: BluetoothDevice,
        offset: Int,
        characteristic: BluetoothGattCharacteristic
    ): ByteArray? {
        return when (characteristic.uuid) {
            BLEConstants.CHAR_STATUS -> {
                val status = JSONObject().apply {
                    put("status", if (isAdvertising) "ADVERTISING" else "CONNECTED")
                    put("timestamp", System.currentTimeMillis())
                }
                status.toString().toByteArray(StandardCharsets.UTF_8)
            }
            BLEConstants.CHAR_BULK_TRANSFER -> {
                // Return current bulk transfer data if any
                characteristic.value
            }
            else -> null
        }
    }

    private fun handleWriteRequest(
        device: BluetoothDevice,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ): Boolean {
        return when (characteristic.uuid) {
            BLEConstants.CHAR_COMMAND -> {
                try {
                    val command = String(value, StandardCharsets.UTF_8)
                    val json = JSONObject(command)
                    val cmd = json.optString("cmd", "")
                    val requestId = json.optString("requestId", null)
                    
                    Log.d(TAG, "Received command: $cmd")
                    eventHandler.onCommandReceived(command, requestId)
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse command", e)
                    false
                }
            }
            BLEConstants.CHAR_BULK_TRANSFER -> {
                // Handle bulk data write
                Log.d(TAG, "Received bulk data: ${value.size} bytes")
                true
            }
            else -> false
        }
    }

    // ============================================================================
    // Notifications (Android -> iPhone)
    // ============================================================================

    /**
     * Send SMS alert notification to connected device
     */
    fun sendSmsAlert(data: String) {
        sendNotification(smsAlertCharacteristic, data)
    }

    /**
     * Send call alert notification to connected device
     */
    fun sendCallAlert(data: String) {
        sendNotification(callAlertCharacteristic, data)
    }

    /**
     * Send app notification to connected device
     */
    fun sendAppNotification(data: String) {
        sendNotification(appNotificationCharacteristic, data)
    }

    /**
     * Send status update to connected device
     */
    fun sendStatusUpdate(data: String) {
        sendNotification(statusCharacteristic, data)
    }

    /**
     * Send bulk data to connected device
     */
    fun sendBulkData(data: ByteArray) {
        val connectedDevices = gattCallback?.getConnectedDevices() ?: return
        
        for (device in connectedDevices) {
            bulkTransferCharacteristic?.let { char ->
                char.value = data
                gattServer?.notifyCharacteristicChanged(device, char, false)
            }
        }
    }

    private fun sendNotification(characteristic: BluetoothGattCharacteristic?, data: String) {
        if (characteristic == null) {
            Log.w(TAG, "Characteristic not initialized")
            return
        }

        val connectedDevices = gattCallback?.getConnectedDevices() ?: return
        if (connectedDevices.isEmpty()) {
            Log.w(TAG, "No connected devices")
            return
        }

        val bytes = data.toByteArray(StandardCharsets.UTF_8)
        
        for (device in connectedDevices) {
            characteristic.value = bytes
            val success = gattServer?.notifyCharacteristicChanged(device, characteristic, false)
            if (success != true) {
                Log.w(TAG, "Failed to send notification to ${device.address}")
            }
        }
    }

    // ============================================================================
    // State
    // ============================================================================

    fun isAdvertising(): Boolean = isAdvertising

    fun getConnectedDevices(): List<String> {
        return gattCallback?.getConnectedDevices()?.map { it.address } ?: emptyList()
    }

    fun isConnected(): Boolean {
        return gattCallback?.getConnectedDevices()?.isNotEmpty() == true
    }

    // ============================================================================
    // Cleanup
    // ============================================================================

    /**
     * Stop all BLE operations and cleanup resources
     */
    fun shutdown() {
        stopAdvertising()
        gattServer?.close()
        gattServer = null
        gattCallback = null
        eventHandler.onStatusChanged(BLEConstants.Status.DISCONNECTED)
        Log.i(TAG, "BLE Peripheral shutdown complete")
    }
}
