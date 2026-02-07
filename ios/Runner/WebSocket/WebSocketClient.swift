import Foundation

/// WebSocket client for iOS to connect to Android's WebSocket server.
class WebSocketClient: NSObject {
    
    static let shared = WebSocketClient()
    
    // MARK: - Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var serverURL: URL?
    
    private(set) var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    
    weak var delegate: WebSocketClientDelegate?
    
    // MARK: - Connection
    
    /// Connect to Android WebSocket server.
    /// - Parameters:
    ///   - host: The IP address of the Android device
    ///   - port: The port number (default: 8765)
    func connect(host: String, port: Int = 8765) {
        guard !isConnected else {
            delegate?.webSocketClient(self, didFailWithError: "Already connected")
            return
        }
        
        guard let url = URL(string: "ws://\(host):\(port)") else {
            delegate?.webSocketClient(self, didFailWithError: "Invalid URL")
            return
        }
        
        serverURL = url
        reconnectAttempts = 0
        performConnect(url: url)
    }
    
    private func performConnect(url: URL) {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        webSocketTask = urlSession?.webSocketTask(with: url)
        
        webSocketTask?.resume()
        startReceiving()
    }
    
    /// Disconnect from the server.
    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        isConnected = false
        
        delegate?.webSocketClientDidDisconnect(self)
    }
    
    // MARK: - Reconnection
    
    private func attemptReconnect() {
        guard let url = serverURL, reconnectAttempts < maxReconnectAttempts else {
            delegate?.webSocketClient(self, didFailWithError: "Max reconnection attempts reached")
            return
        }
        
        reconnectAttempts += 1
        let delay = Double(min(reconnectAttempts * 2, 10)) // Exponential backoff, max 10s
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performConnect(url: url)
        }
    }
    
    // MARK: - Sending
    
    /// Send a text message to the server.
    func send(_ message: String, completion: ((Error?) -> Void)? = nil) {
        guard isConnected else {
            completion?(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"]))
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                self.delegate?.webSocketClient(self, didFailWithError: error.localizedDescription)
            }
            completion?(error)
        }
    }
    
    /// Send binary data to the server.
    func send(data: Data, completion: ((Error?) -> Void)? = nil) {
        guard isConnected else {
            completion?(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"]))
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                self.delegate?.webSocketClient(self, didFailWithError: error.localizedDescription)
            }
            completion?(error)
        }
    }
    
    // MARK: - Receiving
    
    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.delegate?.webSocketClient(self, didReceiveMessage: text)
                case .data(let data):
                    // Try to decode as string first (legacy support) if desired, OR just treat as binary
                    // For now, let's treat all data frames as binary to avoid ambiguity
                    self.delegate?.webSocketClient(self, didReceiveData: data)
                @unknown default:
                    break
                }
                
                // Continue receiving
                self.startReceiving()
                
            case .failure(let error):
                self.isConnected = false
                self.delegate?.webSocketClient(self, didFailWithError: error.localizedDescription)
                self.attemptReconnect()
            }
        }
    }
    
    // MARK: - Ping/Pong
    
    func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.delegate?.webSocketClient(self!, didFailWithError: "Ping failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketClient: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        reconnectAttempts = 0
        delegate?.webSocketClientDidConnect(self)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        delegate?.webSocketClientDidDisconnect(self)
    }
}

// MARK: - Delegate Protocol

protocol WebSocketClientDelegate: AnyObject {
    func webSocketClientDidConnect(_ client: WebSocketClient)
    func webSocketClientDidDisconnect(_ client: WebSocketClient)
    func webSocketClient(_ client: WebSocketClient, didReceiveMessage message: String)
    func webSocketClient(_ client: WebSocketClient, didReceiveData data: Data)
    func webSocketClient(_ client: WebSocketClient, didFailWithError error: String)
}
