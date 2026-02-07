import Foundation
import NetworkExtension

/// Manages Wi-Fi hotspot connection on iOS.
/// Uses NEHotspotConfiguration to connect to Android's hotspot.
class HotspotManager: NSObject {
    
    static let shared = HotspotManager()
    
    // MARK: - Properties
    
    private(set) var isConnecting = false
    private(set) var isConnected = false
    private(set) var currentSSID: String?
    
    // MARK: - Delegate
    
    weak var delegate: HotspotManagerDelegate?
    
    // MARK: - Connect to Hotspot
    
    /// Connect to an Android hotspot using credentials received via BLE.
    /// - Parameters:
    ///   - ssid: The SSID of the hotspot
    ///   - password: The password for the hotspot
    ///   - isWEP: Whether the hotspot uses WEP encryption (default: false)
    func connectToHotspot(ssid: String, password: String, isWEP: Bool = false) {
        guard !isConnecting else {
            delegate?.hotspotManager(self, didFailWithError: "Already connecting")
            return
        }
        
        isConnecting = true
        currentSSID = ssid
        
        let configuration: NEHotspotConfiguration
        
        if password.isEmpty {
            // Open network
            configuration = NEHotspotConfiguration(ssid: ssid)
        } else {
            // Secured network
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: isWEP)
        }
        
        // Join once, don't persist
        configuration.joinOnce = true
        
        NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
            guard let self = self else { return }
            
            self.isConnecting = false
            
            if let error = error as NSError? {
                if error.domain == NEHotspotConfigurationErrorDomain {
                    switch error.code {
                    case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                        // Already connected to this network
                        self.isConnected = true
                        self.delegate?.hotspotManagerDidConnect(self, ssid: ssid)
                        return
                    case NEHotspotConfigurationError.userDenied.rawValue:
                        self.delegate?.hotspotManager(self, didFailWithError: "User denied the connection")
                        return
                    case NEHotspotConfigurationError.invalid.rawValue:
                        self.delegate?.hotspotManager(self, didFailWithError: "Invalid configuration")
                        return
                    case NEHotspotConfigurationError.invalidSSID.rawValue:
                        self.delegate?.hotspotManager(self, didFailWithError: "Invalid SSID")
                        return
                    case NEHotspotConfigurationError.invalidWPAPassphrase.rawValue:
                        self.delegate?.hotspotManager(self, didFailWithError: "Invalid password")
                        return
                    default:
                        self.delegate?.hotspotManager(self, didFailWithError: error.localizedDescription)
                        return
                    }
                }
                
                self.delegate?.hotspotManager(self, didFailWithError: error.localizedDescription)
                return
            }
            
            // Success
            self.isConnected = true
            self.delegate?.hotspotManagerDidConnect(self, ssid: ssid)
        }
    }
    
    /// Disconnect from the current hotspot.
    func disconnect() {
        guard let ssid = currentSSID else { return }
        
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        isConnected = false
        currentSSID = nil
        delegate?.hotspotManagerDidDisconnect(self)
    }
    
    /// Check if we're connected to a specific SSID.
    func isConnectedToSSID(_ ssid: String) -> Bool {
        return isConnected && currentSSID == ssid
    }
    
    /// Get the currently connected SSID (if any).
    /// Note: This requires additional entitlements to work reliably.
    func getCurrentSSID() -> String? {
        return currentSSID
    }
}

// MARK: - Delegate Protocol

protocol HotspotManagerDelegate: AnyObject {
    func hotspotManagerDidConnect(_ manager: HotspotManager, ssid: String)
    func hotspotManagerDidDisconnect(_ manager: HotspotManager)
    func hotspotManager(_ manager: HotspotManager, didFailWithError error: String)
}
