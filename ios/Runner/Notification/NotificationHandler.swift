import UserNotifications

@objc class NotificationHandler: NSObject {
    
    static let shared = NotificationHandler()
    
    override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func showNotification(title: String, body: String, identifier: String, userInfo: [String: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        // content.badge = 1 
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }
    
    func removeNotification(identifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension NotificationHandler: UNUserNotificationCenterDelegate {
    
    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    
    // Handle notification tap — post to NotificationCenter so Flutter can navigate
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let packageName = userInfo["packageName"] as? String ?? ""
        let appName = userInfo["appName"] as? String ?? ""
        let identifier = response.notification.request.identifier
        
        // Post notification for AppDelegate to forward to Flutter
        NotificationCenter.default.post(
            name: NSNotification.Name("BridgerNotificationTapped"),
            object: nil,
            userInfo: [
                "id": identifier,
                "packageName": packageName,
                "appName": appName,
                "actionIdentifier": response.actionIdentifier,
            ]
        )
        
        completionHandler()
    }
}
