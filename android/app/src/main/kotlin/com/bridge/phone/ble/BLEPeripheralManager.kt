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

    // Service queue for sequential addService calls
    private val pendingServices = ArrayDeque<BluetoothGattService>()
    private var isAddingService = false
    private var allServicesRegistered = false
    private var registeredServiceCount = 0
    private val totalExpectedServices = 3

    // ============================================================================
    // Initialization
    // ============================================================================

    /**
     * Initialize the BLE peripheral - creates GATT server and services
     * @return true if successful
     */
    fun initialize(): Boolean {
        // Already initialized — skip
        if (gattServer != null) {
            Log.d(TAG, "Already initialized, skipping")
            return true
        }

        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not supported")
            eventHandler.onError(-1, "Bluetooth not supported")
            return false
        }

        if (!bluetoothAdapter!!.isEnabled) {
            Log.w(TAG, "Bluetooth not enabled yet — will retry when adapter turns on")
            return false
        }

        advertiser = bluetoothAdapter!!.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e(TAG, "BLE advertising not supported")
            eventHandler.onError(-3, "BLE advertising not supported")
            return false
        }

        // Set Bluetooth adapter name so iOS can discover us by name
        try {
            val currentName = bluetoothAdapter!!.name
            if (currentName != BLEConstants.DEVICE_NAME) {
                bluetoothAdapter!!.name = BLEConstants.DEVICE_NAME
                Log.i(TAG, "Bluetooth name set to '${BLEConstants.DEVICE_NAME}' (was '$currentName')")
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Could not set Bluetooth name: ${e.message}")
        }

        // Create GATT callback
        gattCallback = GattServerCallback(
            eventHandler = eventHandler,
            onReadRequest = ::handleReadRequest,
            onWriteRequest = ::handleWriteRequest,
            onServiceAddedCallback = ::onServiceAdded,
            onAllDevicesDisconnected = ::onAllDevicesDisconnected
        )

        // Open GATT server
        gattServer = bluetoothManager.openGattServer(context, gattCallback)
        if (gattServer == null) {
            Log.e(TAG, "Failed to open GATT server")
            eventHandler.onError(-4, "Failed to open GATT server")
            return false
        }

        gattCallback!!.gattServer = gattServer

        // Queue services for sequential addition (Android requires waiting
        // for onServiceAdded before adding the next service)
        queueService(createControlService())
        queueService(createNotificationService())
        queueService(createDataService())
        addNextService()

        Log.i(TAG, "BLE Peripheral initialized — registering $totalExpectedServices GATT services...")
        return true
    }

    // ============================================================================
    // Service Queue Management
    // ============================================================================

    private fun queueService(service: BluetoothGattService) {
        pendingServices.addLast(service)
    }

    private fun addNextService() {
        if (isAddingService || pendingServices.isEmpty()) return
        isAddingService = true
        val service = pendingServices.removeFirst()
        val added = gattServer?.addService(service)
        if (added != true) {
            Log.e(TAG, "addService() returned false for ${service.uuid}")
            isAddingService = false
            addNextService() // try the next one
        }
    }

    private var processedServiceCount = 0

    private fun onServiceAdded(status: Int, service: BluetoothGattService) {
        isAddingService = false
        processedServiceCount++

        if (status == BluetoothGatt.GATT_SUCCESS) {
            registeredServiceCount++
            Log.i(TAG, "Service registered: ${service.uuid} ($registeredServiceCount/$totalExpectedServices)")
        } else {
            Log.e(TAG, "Service registration failed: ${service.uuid}, status=$status")
            eventHandler.onError(status, "Failed to register GATT service ${service.uuid}")
        }

        // Check if all services have been processed (pass or fail)
        if (processedServiceCount >= totalExpectedServices && !allServicesRegistered) {
            if (registeredServiceCount >= totalExpectedServices) {
                allServicesRegistered = true
                Log.i(TAG, "All $totalExpectedServices GATT services registered — ready for connections")
                eventHandler.onStatusChanged(BLEConstants.Status.IDLE)
            } else {
                Log.e(TAG, "Only $registeredServiceCount/$totalExpectedServices services registered — BLE may not function correctly")
                eventHandler.onError(-5, "Not all GATT services registered ($registeredServiceCount/$totalExpectedServices)")
            }
        }

        // Add the next queued service
        addNextService()
    }

    fun areServicesRegistered(): Boolean = allServicesRegistered

    // ============================================================================
    // Service Setup
    // ============================================================================

    private fun createControlService(): BluetoothGattService {
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

        Log.d(TAG, "Control service created")
        return service
    }

    private fun createNotificationService(): BluetoothGattService {
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

        Log.d(TAG, "Notification service created")
        return service
    }

    private fun createDataService(): BluetoothGattService {
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

        Log.d(TAG, "Data service created")
        return service
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
            .setIncludeDeviceName(false) // Remove name to save space for 128-bit UUID
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(ParcelUuid(BLEConstants.SERVICE_CONTROL))
            .build()

        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true) // Put name in scan response
            // Notification/Data services don't need to be advertised, just discovered
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
                // All BLE commands are plaintext JSON — no encryption on BLE path
                try {
                    val command = String(value, StandardCharsets.UTF_8)
                    val json = JSONObject(command)
                    val cmd = json.optString("cmd", "")
                    val requestId = json.optString("requestId", null)
                    
                    Log.d(TAG, "Received command: $cmd")
                    eventHandler.onCommandReceived(command, requestId)
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse BLE command as JSON", e)
                    false
                }
            }
            BLEConstants.CHAR_BULK_TRANSFER -> {
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
     * Send bulk data to connected device.
     * Uses the same chunking protocol as sendNotification when data exceeds MTU.
     */
    fun sendBulkData(data: ByteArray) {
        if (bulkTransferCharacteristic == null) {
            Log.w(TAG, "Bulk transfer characteristic not initialized")
            return
        }

        val connectedDevices = gattCallback?.getConnectedDevices() ?: return
        if (connectedDevices.isEmpty()) {
            Log.w(TAG, "No connected devices for bulk data")
            return
        }

        val mtu = gattCallback?.getCurrentMtu() ?: BLEConstants.DEFAULT_MTU
        val maxPayload = mtu - 3

        for (device in connectedDevices) {
            bulkTransferCharacteristic?.let { char ->
                if (data.size <= maxPayload) {
                    char.value = data
                    gattServer?.notifyCharacteristicChanged(device, char, false)
                } else {
                    val chunkDataSize = maxPayload - 2
                    if (chunkDataSize <= 0) {
                        Log.e(TAG, "MTU too small for bulk chunking (mtu=$mtu)")
                        return
                    }
                    val totalChunks = (data.size + chunkDataSize - 1) / chunkDataSize
                    if (totalChunks > 255) {
                        Log.e(TAG, "Bulk data too large for BLE (${data.size} bytes, $totalChunks chunks)")
                        return
                    }

                    Log.d(TAG, "Chunking bulk data: ${data.size} bytes into $totalChunks chunks")
                    for (i in 0 until totalChunks) {
                        val start = i * chunkDataSize
                        val end = minOf(start + chunkDataSize, data.size)
                        val chunk = ByteArray(2 + (end - start))
                        chunk[0] = i.toByte()
                        chunk[1] = totalChunks.toByte()
                        System.arraycopy(data, start, chunk, 2, end - start)

                        char.value = chunk
                        val success = gattServer?.notifyCharacteristicChanged(device, char, false)
                        if (success != true) {
                            Log.w(TAG, "Failed to send bulk chunk $i/$totalChunks")
                            break
                        }
                        if (i < totalChunks - 1) {
                            try { Thread.sleep(20) } catch (_: InterruptedException) {}
                        }
                    }
                }
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
        val mtu = gattCallback?.getCurrentMtu() ?: BLEConstants.DEFAULT_MTU
        val maxPayload = mtu - 3 // 3 bytes ATT overhead

        for (device in connectedDevices) {
            if (bytes.size <= maxPayload) {
                // Fits in a single notification
                characteristic.value = bytes
                val success = gattServer?.notifyCharacteristicChanged(device, characteristic, false)
                if (success != true) {
                    Log.w(TAG, "Failed to send notification to ${device.address}")
                }
            } else {
                // Chunk the data across multiple notifications
                // Each chunk is prefixed with a 2-byte header: [chunkIndex, totalChunks]
                val chunkDataSize = maxPayload - 2 // reserve 2 bytes for header
                if (chunkDataSize <= 0) {
                    Log.e(TAG, "MTU too small to send chunked data (mtu=$mtu)")
                    return
                }
                val totalChunks = (bytes.size + chunkDataSize - 1) / chunkDataSize
                if (totalChunks > 255) {
                    Log.e(TAG, "Data too large for BLE chunking (${bytes.size} bytes, $totalChunks chunks)")
                    return
                }

                Log.d(TAG, "Chunking ${bytes.size} bytes into $totalChunks chunks (maxPayload=$maxPayload)")
                for (i in 0 until totalChunks) {
                    val start = i * chunkDataSize
                    val end = minOf(start + chunkDataSize, bytes.size)
                    val chunk = ByteArray(2 + (end - start))
                    chunk[0] = i.toByte()
                    chunk[1] = totalChunks.toByte()
                    System.arraycopy(bytes, start, chunk, 2, end - start)

                    characteristic.value = chunk
                    val success = gattServer?.notifyCharacteristicChanged(device, characteristic, false)
                    if (success != true) {
                        Log.w(TAG, "Failed to send chunk $i/$totalChunks to ${device.address}")
                        break
                    }
                    // Small delay between chunks to avoid overwhelming the BLE stack
                    if (i < totalChunks - 1) {
                        try { Thread.sleep(20) } catch (_: InterruptedException) {}
                    }
                }
            }
        }
    }

    // ============================================================================
    // State
    // ============================================================================

    fun isInitialized(): Boolean = gattServer != null

    fun isAdvertising(): Boolean = isAdvertising

    fun getConnectedDevices(): List<String> {
        return gattCallback?.getConnectedDevices()?.map { it.address } ?: emptyList()
    }

    fun isConnected(): Boolean {
        return gattCallback?.getConnectedDevices()?.isNotEmpty() == true
    }

    // ============================================================================
    // Auto Re-Advertise on Disconnect
    // ============================================================================

    /**
     * Called when all iOS devices disconnect.
     * Automatically restarts advertising so the iOS device can reconnect.
     */
    private fun onAllDevicesDisconnected() {
        Log.i(TAG, "All devices disconnected — restarting advertising for reconnection")
        // Restart advertising so iOS central can rediscover and reconnect
        if (!isAdvertising) {
            startAdvertising()
        }
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
