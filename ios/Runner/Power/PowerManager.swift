import Foundation
import UIKit

/// Centralized power management for iOS background optimization.
/// Manages all timers, background tasks, and resource usage to minimize battery drain.
class PowerManager {
    
    static let shared = PowerManager()
    
    // MARK: - Properties
    
    private var isInBackground = false
    private var backgroundWorkItems: [String: DispatchWorkItem] = [:]
    private var heartbeatWorkItem: DispatchWorkItem?
    
    /// Registered services that need pause/resume notifications
    private var services: [PowerManagedService] = []
    
    // Heartbeat interval (25s to avoid 30s disconnect timeout)
    private let heartbeatInterval: TimeInterval = 25.0
    
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
        
        // Start minimal heartbeat for BLE
        startMinimalHeartbeat()
    }
    
    @objc private func appWillEnterForeground() {
        isInBackground = false
        print("[PowerManager] App entering foreground - resuming activity")
        
        // Stop minimal heartbeat
        stopMinimalHeartbeat()
        
        // Notify all services to resume
        for service in services {
            service.resumeFromBackground()
        }
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
        
        heartbeatWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isInBackground else { return }
            
            // Minimal BLE keepalive
            BLECentralManager.shared.sendHeartbeat()
            
            // Reschedule
            self.startMinimalHeartbeat()
        }
        
        if let workItem = heartbeatWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + heartbeatInterval, execute: workItem)
        }
    }
    
    private func stopMinimalHeartbeat() {
        heartbeatWorkItem?.cancel()
        heartbeatWorkItem = nil
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
