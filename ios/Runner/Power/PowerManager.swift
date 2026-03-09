import Foundation
import UIKit

/// Centralized power management for iOS background optimization.
/// Manages all timers, background tasks, and resource usage to minimize battery drain.
class PowerManager {
    
    static let shared = PowerManager()
    
    // MARK: - Properties
    
    private var isInBackground = false
    private var backgroundWorkItems: [String: DispatchWorkItem] = [:]
    
    /// Registered services that need pause/resume notifications
    private var services: [PowerManagedService] = []
    
    // Heartbeat interval (25s to avoid 30s disconnect timeout)
    private let heartbeatInterval: TimeInterval = 25.0
    
    // Background heartbeat timer — uses a background-safe dispatch source
    private var heartbeatTimer: DispatchSourceTimer?
    
    // Background task for extended runtime
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Service Registration
    
    func register(service: PowerManagedService) {
        services.append(service)
    }
    
    func unregister(service: PowerManagedService) {
        services.removeAll { $0 === service }
    }
    
    // MARK: - Lifecycle
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        isInBackground = true
        print("[PowerManager] App entered background - pausing non-essential activity")
        
        // Notify all services to pause
        for service in services {
            service.pauseForBackground()
        }
        
        // Cancel all non-essential work items
        cancelAllNonEssentialWork()
        
        // Begin a background task to keep heartbeat running
        beginBackgroundTask()
        
        // Start minimal heartbeat for BLE
        startMinimalHeartbeat()
    }
    
    @objc private func appWillEnterForeground() {
        isInBackground = false
        print("[PowerManager] App entering foreground - resuming activity")
        
        // Stop minimal heartbeat
        stopMinimalHeartbeat()
        
        // End background task
        endBackgroundTask()
        
        // Notify all services to resume
        for service in services {
            service.resumeFromBackground()
        }
    }
    
    // MARK: - Background Task
    
    private func beginBackgroundTask() {
        endBackgroundTask() // Clean up any prior task
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "BridgePhoneHeartbeat") { [weak self] in
            // Expiration handler — OS is about to kill, clean up
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // MARK: - Work Item Management
    
    /// Schedule a cancellable work item
    func scheduleWork(id: String, delay: TimeInterval, work: @escaping () -> Void) {
        // Cancel existing work with same ID
        backgroundWorkItems[id]?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard self?.isInBackground == false else { return }
            work()
        }
        
        backgroundWorkItems[id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// Cancel a specific work item
    func cancelWork(id: String) {
        backgroundWorkItems[id]?.cancel()
        backgroundWorkItems.removeValue(forKey: id)
    }
    
    /// Cancel all non-essential work
    func cancelAllNonEssentialWork() {
        for (_, workItem) in backgroundWorkItems {
            workItem.cancel()
        }
        backgroundWorkItems.removeAll()
    }
    
    // MARK: - Heartbeat
    
    private func startMinimalHeartbeat() {
        stopMinimalHeartbeat()
        
        // Use DispatchSourceTimer on a background queue — fires even when
        // the main run loop is suspended in background mode.
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + heartbeatInterval, repeating: heartbeatInterval, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isInBackground else { return }
            
            // Minimal BLE keepalive
            DispatchQueue.main.async {
                BLECentralManager.shared.sendHeartbeat()
            }
        }
        timer.resume()
        heartbeatTimer = timer
    }
    
    private func stopMinimalHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }
    
    // MARK: - State
    
    var isAppInBackground: Bool {
        return isInBackground
    }
}

// MARK: - Protocol

protocol PowerManagedService: AnyObject {
    func pauseForBackground()
    func resumeFromBackground()
}
