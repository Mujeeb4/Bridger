import AVFoundation
import CommonCrypto
import CryptoKit

protocol AudioStreamDelegate: AnyObject {
    func onAudioDataCaptured(data: Data)
}

class AudioStreamHandler {
    
    static let shared = AudioStreamHandler()
    weak var delegate: AudioStreamDelegate?
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    // 16kHz, Mono, 16-bit PCM (Int16)
    // Common format for VoIP
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    
    private var isStreaming = false
    
    // Audio protocol byte
    private static let audioProtocolId: UInt8 = 0x01
    
    // AES-256-GCM encryption key (set after pairing)
    private var encryptionKey: Data?
    
    init() {
        setupEngine()
    }
    
    // MARK: - Encryption Key
    
    /// Set the encryption key for audio packets (called after pairing)
    func setEncryptionKey(_ key: Data) {
        guard key.count == 32 else {
            print("[AudioStreamHandler] Invalid key length: \(key.count), expected 32")
            return
        }
        encryptionKey = key
        print("[AudioStreamHandler] Encryption key set (\(key.count) bytes)")
    }
    
    func clearEncryptionKey() {
        encryptionKey = nil
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }
    
    func startStreaming() {
        if isStreaming { return }
        
        setupAudioSession()
        
        do {
            let inputNode = engine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            
            // CRITICAL FIX: Validate format before installing tap
            if inputFormat.sampleRate == 0 || inputFormat.channelCount == 0 {
                print("[AudioStreamHandler] Invalid input format: \(inputFormat)")
                return
            }
            
            print("[AudioStreamHandler] Input format: \(inputFormat)")
            
            // Use the native input format for the tap, then convert
            // Calculate buffer size for ~40ms at input sample rate
            let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.04)
            
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] (buffer, time) in
                guard let self = self else { return }
                
                // Convert to target format (16kHz Int16 Mono)
                if let convertedBuffer = self.convertBuffer(buffer: buffer, to: self.format) {
                    let pcmData = self.dataFromBuffer(buffer: convertedBuffer)
                    
                    // ---- Native audio send path (bypasses Flutter for minimum latency) ----
                    self.sendAudioNatively(pcmData: pcmData)
                    
                    // Also notify Flutter delegate
                    self.delegate?.onAudioDataCaptured(data: pcmData)
                }
            }
            
            try engine.start()
            playerNode.play()
            
            isStreaming = true
            print("[AudioStreamHandler] Engine started successfully")
        } catch {
            print("[AudioStreamHandler] Audio Engine Start Error: \(error)")
        }
    }
    
    func stopStreaming() {
        guard isStreaming else { return }
        
        engine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()
        isStreaming = false
        
        // Deactivate audio session to save battery
        deactivateAudioSession()
    }
    
    // MARK: - Native Audio Send (bypasses Flutter for minimum latency)
    
    /// Send audio directly from native Swift to Android via WebSocket.
    /// This avoids the Native → EventChannel → Dart → MethodChannel → Native roundtrip.
    private func sendAudioNatively(pcmData: Data) {
        guard WebSocketClient.shared.isConnected else { return }
        
        // Encrypt if key is available
        let payload: Data
        if let key = encryptionKey {
            guard let encrypted = encryptAudioChunk(pcmData, key: key) else {
                return // encryption failed, skip this chunk
            }
            // Packet: [0x01 (protocol)] [0x01 (encrypted flag)] [encrypted data]
            var packet = Data([AudioStreamHandler.audioProtocolId, 0x01])
            packet.append(encrypted)
            payload = packet
        } else {
            // Unencrypted: [0x01 (protocol)] [0x00 (unencrypted flag)] [PCM data]
            var packet = Data([AudioStreamHandler.audioProtocolId, 0x00])
            packet.append(pcmData)
            payload = packet
        }
        
        WebSocketClient.shared.send(data: payload, completion: nil)
    }
    
    // MARK: - Receive & Play Audio (from Android)
    
    /// Called when audio data arrives from Android via WebSocket.
    /// This is called directly from the WebSocket receive callback (native path).
    func receiveAudioFromRemote(data: Data) {
        guard data.count > 1 else { return }
        
        let encryptedFlag = data[0]
        let audioPayload = data.subdata(in: 1..<data.count)
        
        let pcmData: Data
        if encryptedFlag == 0x01, let key = encryptionKey {
            guard let decrypted = decryptAudioChunk(audioPayload, key: key) else {
                return // decryption failed
            }
            pcmData = decrypted
        } else {
            pcmData = audioPayload
        }
        
        playAudioChunk(data: pcmData)
    }
    
    func playAudioChunk(data: Data) {
        // Convert Data -> AVAudioPCMBuffer
        if let buffer = bufferFromData(data: data, format: format) {
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(16000)
            try session.setPreferredIOBufferDuration(0.02) // 20ms
            try session.setActive(true)
        } catch {
            print("Audio Session Error: \(error)")
        }
    }
    
    /// Deactivate audio session to minimize battery usage
    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("[AudioStreamHandler] Audio session deactivated")
        } catch {
            print("Audio Session Deactivation Error: \(error)")
        }
    }
    
    // MARK: - AES-256-GCM Encryption
    
    /// Encrypt audio chunk using AES-256-GCM
    /// Output: [12-byte nonce] [ciphertext] [16-byte tag]
    private func encryptAudioChunk(_ plaintext: Data, key: Data) -> Data? {
        // Generate random 12-byte nonce
        var nonce = Data(count: 12)
        let nonceResult = nonce.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!) }
        guard nonceResult == errSecSuccess else { return nil }
        
        // AES-GCM using CryptoKit-like approach via CommonCrypto / Security framework
        // iOS 13+ has CryptoKit, but we use CCCrypt for broader support
        // Actually, let's use CryptoKit directly (iOS 13+ which we certainly target)
        if #available(iOS 13.0, *) {
            return encryptWithCryptoKit(plaintext, key: key, nonce: nonce)
        }
        return nil
    }
    
    private func decryptAudioChunk(_ encrypted: Data, key: Data) -> Data? {
        // 12 nonce + 16 tag minimum = 28 bytes
        guard encrypted.count > 28 else { 
            print("[AudioStreamHandler] Decrypt failed: Data too short (\(encrypted.count) bytes)")
            return nil 
        }
        
        if #available(iOS 13.0, *) {
            return decryptWithCryptoKit(encrypted, key: key)
        }
        return nil
    }
    
    @available(iOS 13.0, *)
    private func encryptWithCryptoKit(_ plaintext: Data, key: Data, nonce: Data) -> Data? {
        do {
            let symmetricKey = CryptoKit.SymmetricKey(data: key)
            let gcmNonce = try CryptoKit.AES.GCM.Nonce(data: nonce)
            let sealedBox = try CryptoKit.AES.GCM.seal(plaintext, using: symmetricKey, nonce: gcmNonce)
            
            // combined = nonce + ciphertext + tag
            guard let combined = sealedBox.combined else { return nil }
            return combined
        } catch {
            print("[AudioStreamHandler] Encryption error: \(error)")
            return nil
        }
    }
    
    @available(iOS 13.0, *)
    private func decryptWithCryptoKit(_ combined: Data, key: Data) -> Data? {
        do {
            let symmetricKey = CryptoKit.SymmetricKey(data: key)
            let sealedBox = try CryptoKit.AES.GCM.SealedBox(combined: combined)
            let decrypted = try CryptoKit.AES.GCM.open(sealedBox, using: symmetricKey)
            return decrypted
        } catch {
            print("[AudioStreamHandler] Decryption error: \(error)")
            return nil
        }
    }
    
    // MARK: - Buffer Helpers
    
    private func convertBuffer(buffer: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == outputFormat { return buffer }
        
        guard let converter = AVAudioConverter(from: buffer.format, to: outputFormat) else { return nil }
        
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(outputFormat.sampleRate * 0.1))! // 100ms buffer capacity
        
        var error: NSError? = nil
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error || error != nil {
            return nil
        }
        
        return outputBuffer
    }
    
    private func dataFromBuffer(buffer: AVAudioPCMBuffer) -> Data {
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        // Assuming Int16 format
        if buffer.format.commonFormat == .pcmFormatInt16 {
            let channels = UnsafeBufferPointer(start: buffer.int16ChannelData, count: channelCount)
            let data = Data(bytes: channels[0], count: frameLength * 2) // 2 bytes per sample
            return data
        }
        return Data()
    }
    
    private func bufferFromData(data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / format.streamDescription.pointee.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        let dst = buffer.int16ChannelData![0]
        
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            if let src = pointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                dst.assign(from: src, count: Int(frameCount))
            }
        }
        
        return buffer
    }
}
