import Foundation
import CoreBluetooth

/// Delegate protocol for receiving BLE events
protocol BLECentralManagerDelegate: AnyObject {
    func didDiscoverDevice(id: String, name: String?, rssi: Int)
    func didConnect(deviceId: String)
    func didDisconnect(deviceId: String, error: Error?)
    func didReceiveSmsAlert(data: String)
    func didReceiveCallAlert(data: String)
    func didReceiveAppNotification(data: String)
    func didReceiveStatusUpdate(data: String)
    func didReceiveBulkData(data: Data)
    func didUpdateState(state: BLEConstants.ConnectionState)
    func didError(code: Int, message: String)
}

/// BLE Central Manager for iOS
/// Scans for, connects to, and communicates with Android BLE peripheral
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
    
    // Auto-reconnect properties
    private var shouldAutoReconnect = true
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
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
    
    /// Start scanning for Bridge Phone devices
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
    
    // MARK: - Send Commands (iPhone -> Android)
    
    /// Send a command to the Android device
    func sendCommand(_ command: [String: Any]) -> Bool {
        guard let characteristic = commandCharacteristic,
              let peripheral = connectedPeripheral else {
            return false
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: command)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            return true
        } catch {
            print("[BLECentralManager] Failed to serialize command: \(error)")
            return false
        }
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
    
    /// Send bulk data
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
            // Discover characteristics for each service
            for service in services {
                connectedPeripheral?.discoverCharacteristics(nil, for: service)
            }
            
        case .discoveredCharacteristics(let characteristics, let service):
            storeCharacteristics(characteristics, for: service)
            
        case .characteristicValueUpdated(let characteristic, let data):
            handleCharacteristicUpdate(characteristic, data: data)
            
        case .error(let error):
            delegate?.didError(code: -3, message: error.localizedDescription)
        }
    }
    
    private func storeCharacteristics(_ characteristics: [CBCharacteristic], for service: CBService) {
        for char in characteristics {
            switch char.uuid {
            case BLEConstants.charCommandUUID:
                commandCharacteristic = char
                
            case BLEConstants.charStatusUUID:
                statusCharacteristic = char
                subscribeToCharacteristic(char)
                
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
                break
            }
        }
    }
    
    private func subscribeToCharacteristic(_ characteristic: CBCharacteristic) {
        guard characteristic.properties.contains(.notify) else { return }
        connectedPeripheral?.setNotifyValue(true, for: characteristic)
    }
    
    private func handleCharacteristicUpdate(_ characteristic: CBCharacteristic, data: Data?) {
        guard let data = data else { return }
        
        switch characteristic.uuid {
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
    }
    
    // MARK: - Auto-Reconnect
    
    private func scheduleReconnect(to peripheral: CBPeripheral) {
        reconnectTimer?.invalidate()
        
        // Exponential backoff: 1s, 2s, 4s, 8s, ... up to 30s
        let baseDelay: Double = 1.0
        let delay = min(baseDelay * pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1
        
        print("[BLECentralManager] Scheduling reconnect attempt \(reconnectAttempts) in \(delay)s")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.centralManager.state == .poweredOn {
                print("[BLECentralManager] Attempting reconnect to \(peripheral.identifier.uuidString)")
                self.updateState(.connecting)
                self.centralManager.connect(peripheral, options: [
                    CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                ])
            }
        }
    }
    
    /// Enable/disable auto-reconnect
    func setAutoReconnect(_ enabled: Bool) {
        shouldAutoReconnect = enabled
        if !enabled {
            reconnectTimer?.invalidate()
            reconnectTimer = nil
        }
    }
    
    /// Attempt to reconnect to last connected device
    func reconnectToLastDevice() {
        guard let deviceId = lastConnectedDeviceId,
              let peripheral = discoveredPeripherals[deviceId] else {
            print("[BLECentralManager] No last device to reconnect to")
            return
        }
        
        reconnectAttempts = 0
        scheduleReconnect(to: peripheral)
    }
    
    // MARK: - Heartbeat (for background keepalive)
    
    /// Send a minimal heartbeat to keep BLE connection alive
    func sendHeartbeat() {
        guard isConnected(), let peripheral = connectedPeripheral else { return }
        
        // Read RSSI to keep connection alive without sending data
        peripheral.readRSSI()
        print("[BLECentralManager] Heartbeat sent (RSSI read)")
    }
}

// MARK: - PowerManagedService

extension BLECentralManager: PowerManagedService {
    
    func pauseForBackground() {
        // Stop scanning if in progress
        if isScanning {
            stopScanning()
        }
        
        // Cancel reconnect timer (PowerManager handles heartbeat)
        reconnectTimer?.invalidate()
        
        print("[BLECentralManager] Paused for background")
    }
    
    func resumeFromBackground() {
        // If we were connected but got disconnected, try to reconnect
        if connectedPeripheral == nil && lastConnectedDeviceId != nil {
            reconnectToLastDevice()
        }
        
        print("[BLECentralManager] Resumed from background")
    }
}

