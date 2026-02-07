import AVFoundation

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
    
    init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // We might need to convert input format to our target format if hardware doesn't support 16kHz natively
        // but installTap usually gives us what the hardware provides. 
        // We often need a mixer/converter. 
        
        // For simplicity in this step, let's try to request 16kHz from session, 
        // but we might need to handle resampling manually if mismatched.
    }
    
    func startStreaming() {
        if isStreaming { return }
        
        setupAudioSession()
        
        do {
            try engine.start()
            playerNode.play()
            
            let inputNode = engine.inputNode
            // Install tap on input node
            // Note: inputNode format depends on hardware. We might need to downsample.
            // Let's assume for MVP we capture at native and let Flutter/Backend handle, 
            // OR perform simple resampling here.
            // Actually, best is to ask AVAudioEngine's mainMixer to handle output, 
            // but for INPUT we must match hardware or convert.
            
            // Installing tap with nil format uses the node's output format.
            // We'll install tap and if format is different, we should convert.
            // For now, let's buffer what we get.
            
            let inputFormat = inputNode.inputFormat(forBus: 0)
            
            // 40ms buffer size: 16000 * 0.04 = 640 samples
            inputNode.installTap(onBus: 0, bufferSize: 640, format: inputFormat) { [weak self] (buffer, time) in
                guard let self = self else { return }
                
                // Convert to target format (16kHz Int16 Mono) if needed
                if let convertedBuffer = self.convertBuffer(buffer: buffer, to: self.format) {
                    let audioData = self.dataFromBuffer(buffer: convertedBuffer)
                    self.delegate?.onAudioDataCaptured(data: audioData)
                }
            }
            
            isStreaming = true
        } catch {
            print("Audio Engine Start Error: \(error)")
        }
    }
    
    func stopStreaming() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        isStreaming = false
        
        // Deactivate audio session to save battery
        deactivateAudioSession()
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
    
    // MARK: - Helpers
    
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
