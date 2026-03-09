import Foundation
import CryptoKit
import Security

@available(iOS 13.0, *)
class EncryptionManager {
    static let shared = EncryptionManager()
    
    private let serviceName = "com.bridge.phone.encryption"
    private let accountName = "shared_key"
    
    private init() {}
    
    // MARK: - Key Management
    
    func saveKey(_ keyBase64: String) -> Bool {
        guard let keyData = Data(base64Encoded: keyBase64) else { return false }
        return saveKeyData(keyData)
    }
    
    func saveKeyData(_ keyData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: keyData
        ]
        
        // Remove existing item if any
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyData = item as? Data else { return nil }
        return SymmetricKey(data: keyData)
    }
    
    func getKeyData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let keyData = item as? Data else { return nil }
        return keyData
    }
    
    func duplicateKeyCheck() {
       // Debug helper
    }

    func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Encryption / Decryption
    
    func encrypt(_ data: Data) -> Data? {
        guard let key = getKey() else { return nil }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("[EncryptionManager] Encryption failed: \(error)")
            return nil
        }
    }
    
    func decrypt(_ data: Data) -> Data? {
        guard let key = getKey() else { return nil }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            print("[EncryptionManager] Decryption failed: \(error)")
            return nil
        }
    }
}
