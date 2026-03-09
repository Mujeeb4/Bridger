import Foundation
import CoreBluetooth

/// Delegate protocol for receiving BLE events
protocol BLECentralManagerDelegate: AnyObject {
    func didDiscoverDevice(id: String, name: String?, rssi: Int)
    func didConnect(deviceId: String)
    func didDisconnect(deviceId: String, error: Error?)
    func didUpdateState(state: BLEConstants.ConnectionState)
    func didError(code: Int, message: String)
    func didLog(message: String) // New: Send logs to Flutter
    
    // Data/Notifications
    func didReceiveSmsAlert(data: String)
    func didReceiveCallAlert(data: String)
    func didReceiveAppNotification(data: String)
    func didReceiveStatusUpdate(data: String)
    func didReceiveBulkData(data: Data)
    
    // Pairing/Ready
    func didBecomeReadyForCommunication()
}

/// BLE Central Manager for iOS
/// Scans for, connects to, and communicates with Android BLE peripheral
@available(iOS 13.0, *)
class BLECentralManager: NSObject {
    
    // MARK: - Singleton
    
    static let shared = BLECentralManager()
    
    // MARK: - Properties
    
    weak var delegate: BLECentralManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var peripheralDelegate: PeripheralDelegate?
    
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var isScanning = false
    private var currentState: BLEConstants.ConnectionState = .idle
    private(set) var servicesReady = false
    
    // Track how many services we've discovered characteristics for
    private var discoveredServiceCount = 0
    private let expectedServiceCount = 3 // control, notification, data
    
    // Auto-reconnect properties
    private var shouldAutoReconnect = true
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 50  // Many attempts — connection should persist
    private var reconnectTimer: Timer?
    private var lastConnectedDeviceId: String? {
        get { UserDefaults.standard.string(forKey: "BridgePhone_LastConnectedDevice") }
        set { UserDefaults.standard.set(newValue, forKey: "BridgePhone_LastConnectedDevice") }
    }
    
    // Service characteristics references
    private var commandCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var smsAlertCharacteristic: CBCharacteristic?
    private var callAlertCharacteristic: CBCharacteristic?
    private var appNotificationCharacteristic: CBCharacteristic?
    private var bulkTransferCharacteristic: CBCharacteristic?
    
    // Chunk reassembly buffers keyed by characteristic UUID string
    private var chunkBuffers: [String: ChunkBuffer] = [:]
    
    private struct ChunkBuffer {
        let totalChunks: Int
        var chunks: [Int: Data]
        var lastReceived: Date
        
        var isComplete: Bool { chunks.count == totalChunks }
        var isStale: Bool { Date().timeIntervalSince(lastReceived) > 5.0 }
        
        func reassemble() -> Data? {
            guard isComplete else { return nil }
            var result = Data()
            for i in 0..<totalChunks {
                guard let chunk = chunks[i] else { return nil }
                result.append(chunk)
            }
            return result
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Initialize with background restoration support
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: "com.bridge.phone.central"
        ]
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }
    
    // MARK: - Public API
    
    /// Start scanning for Bridger devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            delegate?.didError(code: -1, message: "Bluetooth not ready")
            return
        }
        
        guard !isScanning else { return }
        
        isScanning = true
        discoveredPeripherals.removeAll()
        
        // Scan for our specific services
        centralManager.scanForPeripherals(
            withServices: [BLEConstants.serviceControlUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        updateState(.scanning)
        print("[BLECentralManager] Started scanning for devices")
    }
    
    /// Stop scanning
    func stopScanning() {
        guard isScanning else { return }
        
        centralManager.stopScan()
        isScanning = false
        updateState(.idle)
        print("[BLECentralManager] Stopped scanning")
    }
    
    /// Connect to a discovered peripheral
    func connect(deviceId: String) {
        guard let peripheral = discoveredPeripherals[deviceId] else {
            delegate?.didError(code: -2, message: "Device not found: \(deviceId)")
            return
        }
        
        stopScanning()
        updateState(.connecting)
        
        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
        
        print("[BLECentralManager] Connecting to \(deviceId)")
    }
    
    /// Disconnect from current peripheral
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        centralManager.cancelPeripheralConnection(peripheral)
        print("[BLECentralManager] Disconnecting")
    }
    
    /// Check if connected
    func isConnected() -> Bool {
        return connectedPeripheral?.state == .connected
    }
    
    /// Get connection state
    func getState() -> BLEConstants.ConnectionState {
        return currentState
    }
    
    /// Get connected device ID
    func getConnectedDeviceId() -> String? {
        return connectedPeripheral?.identifier.uuidString
    }
    
    // MARK: - Pairing
    
    private var pairingCode: String?
    
    /// Start pairing process with a device (Auto-scans and connects)
    func startPairing(code: String) {
        print("[BLECentralManager] Starting pairing with code=\(code)")
        self.pairingCode = code
        
        // If already connected and ready, send request immediately
        if isConnected() && isReadyForCommunication() {
            sendPairingRequest()
        } else {
            // Otherwise start scanning to find a device
            print("[BLECentralManager] Not connected, starting scan for pairing...")
            startScanning()
        }
    }
    
    private func sendPairingRequest() {
        guard let code = pairingCode else { return }
        print("[BLECentralManager] Sending PAIRING_REQUEST...")
        
        let request: [String: Any] = [
             "cmd": "PAIRING_REQUEST",
             "payload": [
                 "pairingCode": code,
                 "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
                 "deviceName": UIDevice.current.name,
                 "platform": "ios"
             ],
             "requestId": UUID().uuidString
        ]
        
        // Send as PLAINTEXT (bypass encryption)
        _ = sendRawCommand(request)
    }

    private func handlePairingResponse(_ json: [String: Any]) {
        print("[BLECentralManager] Handling PAIRING_RESPONSE")
        guard let success = json["success"] as? Bool, success else {
            print("[BLECentralManager] Pairing failed: \(json["errorMessage"] ?? "Unknown error")")
            pairingCode = nil
            delegate?.didError(code: -100, message: "Pairing failed: \(json["errorMessage"] ?? "Unknown")")
            return
        }
        
        if let keyBase64 = json["sharedKey"] as? String {
            print("[BLECentralManager] Received shared key. Saving to Keychain...")
            if EncryptionManager.shared.saveKey(keyBase64) {
                print("[BLECentralManager] Key saved successfully")
                
                // Notify Flutter of success
                // We construct a similar payload to what Dart expects
                let responseStr = "{\"cmd\":\"NATIVE_PAIRING_SUCCESS\",\"payload\":{\"deviceId\":\"\(getConnectedDeviceId() ?? "")\",\"deviceName\":\"Android Device\",\"platform\":\"android\",\"sharedKey\":\"\(keyBase64)\"}}"
                delegate?.didReceiveStatusUpdate(data: responseStr) // Re-use status update path to notify Dart
            } else {
                print("[BLECentralManager] Failed to save key to Keychain")
                delegate?.didError(code: -101, message: "Failed to save pairing key")
            }
        }
        
        pairingCode = nil
    }

    // MARK: - Send Commands (iPhone -> Android)
    
    /// Check if services are discovered and ready for communication
    func isReadyForCommunication() -> Bool {
        return servicesReady && commandCharacteristic != nil && connectedPeripheral?.state == .connected
    }
    
    /// Force re-discover services on the connected peripheral.
    /// Use when iOS connected before Android finished registering services.
    func rediscoverServices() {
        guard let peripheral = connectedPeripheral, peripheral.state == .connected else {
            print("[BLECentralManager] Cannot rediscover: no connected peripheral")
            delegate?.didError(code: -30, message: "No connected peripheral for service discovery")
            return
        }
        
        // Reset all characteristic references and tracking state
        clearCharacteristicReferences()
        chunkBuffers.removeAll()
        
        // Re-setup delegate in case it was lost
        if peripheral.delegate == nil {
            setupPeripheralDelegate(for: peripheral)
        }
        
        print("[BLECentralManager] Re-discovering services...")
        delegate?.didLog(message: "[BLECentralManager] Re-discovering services on connected peripheral")
        peripheral.discoverServices(BLEConstants.allServiceUUIDs)
    }
    
    /// Send a command to the Android device as plaintext JSON.
    /// BLE encryption is not used — the link is short-range and point-to-point.
    /// WebSocket and audio paths handle their own encryption separately.
    func sendCommand(_ command: [String: Any]) -> Bool {
        return sendRawCommand(command)
    }
    
    /// Internal: Send raw command without encryption attempt
    private func sendRawCommand(_ command: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: command) else { return false }
        return sendRawData(data)
    }
    
    private func sendRawData(_ data: Data) -> Bool {
        guard let characteristic = commandCharacteristic,
              let peripheral = connectedPeripheral else { return false }
              
        let maxLen = peripheral.maximumWriteValueLength(for: .withResponse)
        
        if data.count <= maxLen {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else {
            var offset = 0
            while offset < data.count {
                let end = min(offset + maxLen, data.count)
                let chunk = data.subdata(in: offset..<end)
                peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
                offset = end
            }
        }
        return true
    }
    
    /// Convenience method to send SMS
    func sendSMS(to phoneNumber: String, body: String) -> Bool {
        let command: [String: Any] = [
            "cmd": BLEConstants.Commands.sendSMS,
            "payload": [
                "to": phoneNumber,
                "body": body
            ],
            "requestId": UUID().uuidString
        ]
        return sendCommand(command)
    }
    
    /// Convenience method to make a call
    func makeCall(to phoneNumber: String) -> Bool {
        let command: [String: Any] = [
            "cmd": BLEConstants.Commands.makeCall,
            "payload": ["phoneNumber": phoneNumber],
            "requestId": UUID().uuidString
        ]
        return sendCommand(command)
    }
    
    /// Send bulk data (plaintext — no BLE encryption)
    func sendBulkData(_ data: Data) -> Bool {
        guard let characteristic = bulkTransferCharacteristic,
              let peripheral = connectedPeripheral else {
            return false
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        return true
    }
    
    // MARK: - Private Helpers
    
    private func updateState(_ state: BLEConstants.ConnectionState) {
        currentState = state
        delegate?.didUpdateState(state: state)
    }
    
    private func setupPeripheralDelegate(for peripheral: CBPeripheral) {
        peripheralDelegate = PeripheralDelegate { [weak self] event in
            self?.handlePeripheralEvent(event)
        }
        peripheral.delegate = peripheralDelegate
    }
    
    private func handlePeripheralEvent(_ event: PeripheralEvent) {
        switch event {
        case .discoveredServices(let services):
            let msg = "[BLECentralManager] Did discover \(services.count) services"
            print(msg)
            delegate?.didLog(message: msg)
            
            // Discover characteristics for each service
            for service in services {
                let sMsg = "[BLECentralManager] Discovered service: \(service.uuid)"
                print(sMsg)
                delegate?.didLog(message: sMsg)
                connectedPeripheral?.discoverCharacteristics(nil, for: service)
            }
            
        case .discoveredCharacteristics(let characteristics, let service):
            let msg = "[BLECentralManager] Did discover \(characteristics.count) characteristics for service \(service.uuid)"
            print(msg)
            delegate?.didLog(message: msg)
            storeCharacteristics(characteristics, for: service)
            
        case .characteristicValueUpdated(let characteristic, let data):
            handleCharacteristicUpdate(characteristic, data: data)
            
        case .servicesInvalidated(let services):
            let msg = "[BLECentralManager] Services invalidated: \(services.map { $0.uuid }) — re-discovering"
            print(msg)
            delegate?.didLog(message: msg)
            rediscoverServices()
            
        case .error(let error):
            delegate?.didError(code: -3, message: error.localizedDescription)
        }
    }
    
    private func storeCharacteristics(_ characteristics: [CBCharacteristic], for service: CBService) {
        for char in characteristics {
            let msg = "[BLECentralManager] Processing characteristic: \(char.uuid) (Properties: \(char.properties))"
            print(msg)
            delegate?.didLog(message: msg)
            
            switch char.uuid {
            case BLEConstants.charCommandUUID:
                commandCharacteristic = char
                let log = "[BLECentralManager] ✓ commandCharacteristic stored"
                print(log)
                delegate?.didLog(message: log)
                
            case BLEConstants.charStatusUUID:
                statusCharacteristic = char
                subscribeToCharacteristic(char)
                let log = "[BLECentralManager] ✓ statusCharacteristic stored + subscribed"
                print(log)
                delegate?.didLog(message: log)
                
            case BLEConstants.charSmsAlertUUID:
                smsAlertCharacteristic = char
                subscribeToCharacteristic(char)
                
            case BLEConstants.charCallAlertUUID:
                callAlertCharacteristic = char
                subscribeToCharacteristic(char)
                
            case BLEConstants.charAppNotificationUUID:
                appNotificationCharacteristic = char
                subscribeToCharacteristic(char)
                
            case BLEConstants.charBulkTransferUUID:
                bulkTransferCharacteristic = char
                subscribeToCharacteristic(char)
                
            default:
                let log = "[BLECentralManager] Unhandled characteristic: \(char.uuid)"
                print(log)
                delegate?.didLog(message: log)
                break
            }
        }
        
        // Track service discovery progress
        discoveredServiceCount += 1
        let progressMsg = "[BLECentralManager] Service characteristics stored: \(discoveredServiceCount)/\(expectedServiceCount) for \(service.uuid)"
        print(progressMsg)
        delegate?.didLog(message: progressMsg)
        
        // Check if we have the critical characteristic (command) ready
        // Once commandCharacteristic + statusCharacteristic are available, we're ready
        if !servicesReady && commandCharacteristic != nil && statusCharacteristic != nil {
            servicesReady = true
            let readyMsg = "[BLECentralManager] ✅ Services READY for communication"
            print(readyMsg)
            delegate?.didLog(message: readyMsg)
            delegate?.didBecomeReadyForCommunication()
            
            // Trigger pairing request if pending
            if let _ = pairingCode {
                sendPairingRequest()
            }
        } else {
             let notReadyMsg = "[BLECentralManager] Services NOT ready yet. Command: \(commandCharacteristic != nil), Status: \(statusCharacteristic != nil)"
             print(notReadyMsg)
             delegate?.didLog(message: notReadyMsg)
        }
    }
    
    private func subscribeToCharacteristic(_ characteristic: CBCharacteristic) {
        guard characteristic.properties.contains(.notify) else { return }
        connectedPeripheral?.setNotifyValue(true, for: characteristic)
    }
    
    private func handleCharacteristicUpdate(_ characteristic: CBCharacteristic, data: Data?) {
        guard let data = data, !data.isEmpty else { return }
        
        let uuid = characteristic.uuid
        var finalData = data
        
        // Check if this is chunked data from Android's sendNotification.
        // Chunked packets have a 2-byte header: [chunkIndex, totalChunks].
        if data.count >= 3 && Int(data[1]) > 1 && Int(data[0]) < Int(data[1]) {
             let chunkIndex = Int(data[0])
             let totalChunks = Int(data[1])
             if totalChunks > 1 && totalChunks <= 128 && chunkIndex < totalChunks {
                 let key = uuid.uuidString
                 let payload = data.subdata(in: 2..<data.count)
                 chunkBuffers = chunkBuffers.filter { !$0.value.isStale }
                 if chunkIndex == 0 {
                     var buffer = ChunkBuffer(totalChunks: totalChunks, chunks: [:], lastReceived: Date())
                     buffer.chunks[0] = payload
                     chunkBuffers[key] = buffer
                 } else if var buffer = chunkBuffers[key], buffer.totalChunks == totalChunks {
                     buffer.chunks[chunkIndex] = payload
                     buffer.lastReceived = Date()
                     chunkBuffers[key] = buffer
                     if buffer.isComplete, let fullData = buffer.reassemble() {
                         chunkBuffers.removeValue(forKey: key)
                         processData(uuid: uuid, data: fullData)
                     }
                 }
                 return
             }
        }
        
        // Non-chunked
        processData(uuid: uuid, data: data)
    }
    
    private func processData(uuid: CBUUID, data: Data) {
        // Check for PAIRING_RESPONSE on the status characteristic
        if uuid == BLEConstants.charStatusUUID && pairingCode != nil {
             if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let cmd = json["cmd"] as? String, (cmd == "PAIRING_RESPONSE" || json["success"] != nil) {
                 handlePairingResponse(json)
                 return
             }
        }
        
        // All BLE data is plaintext — no decryption needed
        deliverCharacteristicData(uuid: uuid, data: data)
    }
    
    private func deliverCharacteristicData(uuid: CBUUID, data: Data) {
        switch uuid {
        case BLEConstants.charStatusUUID:
            if let str = String(data: data, encoding: .utf8) {
                delegate?.didReceiveStatusUpdate(data: str)
            }
            
        case BLEConstants.charSmsAlertUUID:
            if let str = String(data: data, encoding: .utf8) {
                delegate?.didReceiveSmsAlert(data: str)
            }
            
        case BLEConstants.charCallAlertUUID:
            if let str = String(data: data, encoding: .utf8) {
                delegate?.didReceiveCallAlert(data: str)
            }
            
        case BLEConstants.charAppNotificationUUID:
            if let str = String(data: data, encoding: .utf8) {
                delegate?.didReceiveAppNotification(data: str)
            }
            
        case BLEConstants.charBulkTransferUUID:
            delegate?.didReceiveBulkData(data: data)
            
        default:
            break
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLECentralManager: CBCentralManagerDelegate {
    // ... same as before ...
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[BLECentralManager] Bluetooth powered on")
            updateState(.idle)
        case .poweredOff:
            print("[BLECentralManager] Bluetooth powered off")
            updateState(.error)
            delegate?.didError(code: -10, message: "Bluetooth is turned off")
        case .unauthorized:
            print("[BLECentralManager] Bluetooth unauthorized")
            delegate?.didError(code: -11, message: "Bluetooth permission denied")
        case .unsupported:
            print("[BLECentralManager] Bluetooth unsupported")
            delegate?.didError(code: -12, message: "Bluetooth not supported")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        discoveredPeripherals[deviceId] = peripheral
        
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        
        
        delegate?.didDiscoverDevice(id: deviceId, name: name, rssi: RSSI.intValue)
        print("[BLECentralManager] Discovered: \(name ?? "Unknown") (\(deviceId)) RSSI: \(RSSI)")
        
        // AUTO-CONNECT IF PAIRING
        if pairingCode != nil {
             print("[BLECentralManager] Auto-connecting to \(name ?? "Unknown") for pairing...")
             connect(deviceId: deviceId)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLECentralManager] Connected to \(peripheral.identifier.uuidString)")
        
        // Reset reconnect state
        reconnectAttempts = 0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        connectedPeripheral = peripheral
        setupPeripheralDelegate(for: peripheral)
        updateState(.connected)
        
        // Persist for future auto-reconnect
        lastConnectedDeviceId = peripheral.identifier.uuidString
        
        delegate?.didConnect(deviceId: peripheral.identifier.uuidString)
        
        // Discover services
        peripheral.discoverServices(BLEConstants.allServiceUUIDs)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[BLECentralManager] Failed to connect: \(error?.localizedDescription ?? "Unknown")")
        updateState(.error)
        delegate?.didError(code: -20, message: error?.localizedDescription ?? "Failed to connect")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BLECentralManager] Disconnected from \(peripheral.identifier.uuidString)")
        
        let deviceId = peripheral.identifier.uuidString
        
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            peripheralDelegate = nil
            clearCharacteristicReferences()
        }
        
        updateState(.disconnected)
        delegate?.didDisconnect(deviceId: deviceId, error: error)
        
        // Auto-reconnect if enabled
        if shouldAutoReconnect && reconnectAttempts < maxReconnectAttempts {
            scheduleReconnect(to: peripheral)
        }
    }
    
    // State restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                discoveredPeripherals[peripheral.identifier.uuidString] = peripheral
                
                if peripheral.state == .connected {
                    connectedPeripheral = peripheral
                    setupPeripheralDelegate(for: peripheral)
                    updateState(.connected)
                    lastConnectedDeviceId = peripheral.identifier.uuidString
                } else if peripheral.state == .disconnected {
                    // Reconnect to the restored peripheral
                    scheduleReconnect(to: peripheral)
                }
            }
        }
    }
    
    private func clearCharacteristicReferences() {
        commandCharacteristic = nil
        statusCharacteristic = nil
        smsAlertCharacteristic = nil
        callAlertCharacteristic = nil
        appNotificationCharacteristic = nil
        bulkTransferCharacteristic = nil
        servicesReady = false
        discoveredServiceCount = 0
    }
    
    // ... Auto Reconnect and Heartbeat ...
    
    private func scheduleReconnect(to peripheral: CBPeripheral) {
        reconnectTimer?.invalidate()
        let baseDelay: Double = 1.0
        let delay = min(baseDelay * pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1
        
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            if self.centralManager.state == .poweredOn {
                DispatchQueue.main.async {
                    self.updateState(.connecting)
                    self.centralManager.connect(peripheral, options: [
                        CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                    ])
                }
            } else {
                if self.reconnectAttempts < self.maxReconnectAttempts {
                    self.scheduleReconnect(to: peripheral)
                }
            }
        }
    }
    
    func setAutoReconnect(_ enabled: Bool) {
        shouldAutoReconnect = enabled
        if !enabled {
            reconnectTimer?.invalidate()
            reconnectTimer = nil
        }
    }
    
    func reconnectToLastDevice() {
        guard let deviceId = lastConnectedDeviceId else { return }
        reconnectAttempts = 0
        if let peripheral = discoveredPeripherals[deviceId] {
            scheduleReconnect(to: peripheral)
            return
        }
        if let uuid = UUID(uuidString: deviceId) {
            let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = knownPeripherals.first {
                discoveredPeripherals[deviceId] = peripheral
                scheduleReconnect(to: peripheral)
                return
            }
            let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: BLEConstants.allServiceUUIDs)
            if let peripheral = connectedPeripherals.first(where: { $0.identifier.uuidString == deviceId }) {
                discoveredPeripherals[deviceId] = peripheral
                scheduleReconnect(to: peripheral)
                return
            }
        }
        startScanning()
    }
    
    func sendHeartbeat() {
        guard isConnected(), let peripheral = connectedPeripheral else { return }
        peripheral.readRSSI()
    }
}


// MARK: - PowerManagedService

extension BLECentralManager: PowerManagedService {
    
    func pauseForBackground() {
        // Stop scanning if in progress (saves battery)
        if isScanning {
            stopScanning()
        }
        
        // NOTE: Do NOT cancel reconnect timer in background!
        // The BLE reconnect must continue even while backgrounded,
        // otherwise a momentary disconnect kills the connection permanently.
        
        print("[BLECentralManager] Paused for background (reconnect timer preserved)")
    }
    
    func resumeFromBackground() {
        // If we were connected but got disconnected, try to reconnect
        if connectedPeripheral == nil && lastConnectedDeviceId != nil {
            reconnectToLastDevice()
        }
        
        print("[BLECentralManager] Resumed from background")
    }
}

