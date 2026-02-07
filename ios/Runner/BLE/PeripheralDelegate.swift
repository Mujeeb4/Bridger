import Foundation
import CoreBluetooth

/// Events from CBPeripheralDelegate
enum PeripheralEvent {
    case discoveredServices([CBService])
    case discoveredCharacteristics([CBCharacteristic], CBService)
    case characteristicValueUpdated(CBCharacteristic, Data?)
    case error(Error)
}

/// Delegate handler for CBPeripheral events
class PeripheralDelegate: NSObject, CBPeripheralDelegate {
    
    private let eventHandler: (PeripheralEvent) -> Void
    
    init(eventHandler: @escaping (PeripheralEvent) -> Void) {
        self.eventHandler = eventHandler
        super.init()
    }
    
    // MARK: - Service Discovery
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            eventHandler(.error(error))
            return
        }
        
        guard let services = peripheral.services else { return }
        
        print("[PeripheralDelegate] Discovered \(services.count) services")
        eventHandler(.discoveredServices(services))
    }
    
    // MARK: - Characteristic Discovery
    
    func peripheral(_ peripheral: CBPeripheral, 
                    didDiscoverCharacteristicsFor service: CBService, 
                    error: Error?) {
        if let error = error {
            eventHandler(.error(error))
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        print("[PeripheralDelegate] Discovered \(characteristics.count) characteristics for \(service.uuid)")
        eventHandler(.discoveredCharacteristics(characteristics, service))
    }
    
    // MARK: - Characteristic Value Updates
    
    func peripheral(_ peripheral: CBPeripheral, 
                    didUpdateValueFor characteristic: CBCharacteristic, 
                    error: Error?) {
        if let error = error {
            print("[PeripheralDelegate] Error reading characteristic: \(error)")
            eventHandler(.error(error))
            return
        }
        
        eventHandler(.characteristicValueUpdated(characteristic, characteristic.value))
    }
    
    // MARK: - Write Confirmation
    
    func peripheral(_ peripheral: CBPeripheral, 
                    didWriteValueFor characteristic: CBCharacteristic, 
                    error: Error?) {
        if let error = error {
            print("[PeripheralDelegate] Write error: \(error)")
            eventHandler(.error(error))
        } else {
            print("[PeripheralDelegate] Successfully wrote to \(characteristic.uuid)")
        }
    }
    
    // MARK: - Notification State
    
    func peripheral(_ peripheral: CBPeripheral, 
                    didUpdateNotificationStateFor characteristic: CBCharacteristic, 
                    error: Error?) {
        if let error = error {
            print("[PeripheralDelegate] Notification state error: \(error)")
            return
        }
        
        print("[PeripheralDelegate] Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
    }
    
    // MARK: - MTU Changed
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        print("[PeripheralDelegate] Ready to send write without response")
    }
}
