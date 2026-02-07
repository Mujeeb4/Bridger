import Foundation
import CallKit
import AVFoundation

/// CallKit handler for native iOS call UI
class CallKitHandler: NSObject {
    
    static let shared = CallKitHandler()
    
    // MARK: - Properties
    
    private let provider: CXProvider
    private let callController: CXCallController
    private var activeCallUUID: UUID?
    private var activeCallNumber: String?
    
    weak var delegate: CallKitHandlerDelegate?
    
    // MARK: - Init
    
    private override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.phoneNumber]
        
        provider = CXProvider(configuration: configuration)
        callController = CXCallController()
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    // MARK: - Report Incoming Call
    
    /// Report an incoming call from Android
    func reportIncomingCall(phoneNumber: String, completion: @escaping (Error?) -> Void) {
        let uuid = UUID()
        activeCallUUID = uuid
        activeCallNumber = phoneNumber
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: phoneNumber)
        update.hasVideo = false
        update.localizedCallerName = phoneNumber
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                self.activeCallUUID = nil
                self.activeCallNumber = nil
            }
            completion(error)
        }
    }
    
    // MARK: - Report Call Ended
    
    /// Report that call ended (from Android)
    func reportCallEnded(reason: CXCallEndedReason = .remoteEnded) {
        guard let uuid = activeCallUUID else { return }
        
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        activeCallUUID = nil
        activeCallNumber = nil
    }
    
    // MARK: - Report Call Connected
    
    /// Report that call was answered/connected
    func reportCallConnected() {
        guard let uuid = activeCallUUID else { return }
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }
    
    // MARK: - End Call (User Action)
    
    /// End call from user action
    func endCall(completion: ((Error?) -> Void)? = nil) {
        guard let uuid = activeCallUUID else {
            completion?(nil)
            return
        }
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            completion?(error)
        }
    }
    
    // MARK: - Current Call State
    
    var hasActiveCall: Bool {
        return activeCallUUID != nil
    }
    
    var currentCallNumber: String? {
        return activeCallNumber
    }
}

// MARK: - CXProviderDelegate

extension CallKitHandler: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
        activeCallNumber = nil
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // User answered the call
        delegate?.callKitHandler(self, didAnswerCall: activeCallNumber ?? "")
        
        // Configure audio session
        configureAudioSession()
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // User rejected/ended the call
        delegate?.callKitHandler(self, didEndCall: activeCallNumber ?? "")
        
        activeCallUUID = nil
        activeCallNumber = nil
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        delegate?.callKitHandler(self, didMuteCall: action.isMuted)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Audio session is now active
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // Audio session deactivated
    }
    
    // MARK: - Audio Configuration
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("CallKit: Failed to configure audio session: \(error)")
        }
    }
}

// MARK: - Delegate Protocol

protocol CallKitHandlerDelegate: AnyObject {
    func callKitHandler(_ handler: CallKitHandler, didAnswerCall phoneNumber: String)
    func callKitHandler(_ handler: CallKitHandler, didEndCall phoneNumber: String)
    func callKitHandler(_ handler: CallKitHandler, didMuteCall muted: Bool)
}
