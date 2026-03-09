import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Global error handler for the application
/// 
/// Handles uncaught exceptions, Flutter errors, and provides
/// user-friendly error messages via snackbars.
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Initialize error handling
  void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(details.exception, details.stack);
    };

    // Handle errors outside of Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(error, stack);
      return true;
    };
  }

  /// Log error to console and crash reporting service
  void _logError(Object error, StackTrace? stack) {
    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('=== ERROR CAUGHT BY ERROR HANDLER ===');
      debugPrint('Error: $error');
      if (stack != null) {
        debugPrint('Stack trace:\n$stack');
      }
      debugPrint('=====================================');
    }

    // Log to Firebase Crashlytics in release mode
    // Uncomment when Firebase is configured:
    // if (!kDebugMode) {
    //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    // }
  }

  /// Log a non-fatal error
  void logError(Object error, [StackTrace? stack, String? reason]) {
    if (kDebugMode) {
      debugPrint('Non-fatal error: $error');
      if (reason != null) debugPrint('Reason: $reason');
    }
    
    // Uncomment when Firebase is configured:
    // if (!kDebugMode) {
    //   FirebaseCrashlytics.instance.recordError(
    //     error, 
    //     stack, 
    //     reason: reason,
    //     fatal: false,
    //   );
    // }
  }

  /// Log a message to crash reporting
  void log(String message) {
    if (kDebugMode) {
      debugPrint('[LOG] $message');
    }
    
    // Uncomment when Firebase is configured:
    // FirebaseCrashlytics.instance.log(message);
  }

  /// Set user identifier for crash reports
  void setUserId(String userId) {
    // Uncomment when Firebase is configured:
    // FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  /// Show user-friendly error snackbar
  static void showErrorSnackbar(
    BuildContext context, 
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF166534),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show warning snackbar
  static void showWarningSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();
    
    // BLE related errors
    if (errorString.contains('bluetooth') || errorString.contains('ble')) {
      if (errorString.contains('not available') || errorString.contains('off')) {
        return 'Bluetooth is turned off. Please enable Bluetooth to continue.';
      }
      if (errorString.contains('disconnected')) {
        return 'Device disconnected. Attempting to reconnect...';
      }
      if (errorString.contains('not found')) {
        return 'Device not found. Make sure the paired device is nearby.';
      }
      return 'Bluetooth connection error. Please try again.';
    }
    
    // Network errors
    if (errorString.contains('socket') || errorString.contains('network') || 
        errorString.contains('connection refused')) {
      return 'Network connection error. Please check your connection.';
    }
    
    // Permission errors
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please grant the required permissions in settings.';
    }
    
    // Database errors
    if (errorString.contains('database') || errorString.contains('sqlite')) {
      return 'Local storage error. Please restart the app.';
    }
    
    // Platform channel errors
    if (errorString.contains('missingpluginexception') || 
        errorString.contains('platform')) {
      return 'Feature not available on this device.';
    }
    
    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    }
    
    // Generic fallback
    return 'An unexpected error occurred. Please try again.';
  }
}

/// Extension to easily show errors from exceptions
extension ErrorHandlerContext on BuildContext {
  void showError(Object error) {
    final message = ErrorHandler.getUserFriendlyMessage(error);
    ErrorHandler.showErrorSnackbar(this, message);
    ErrorHandler().logError(error, StackTrace.current);
  }
  
  void showSuccess(String message) {
    ErrorHandler.showSuccessSnackbar(this, message);
  }
  
  void showWarning(String message) {
    ErrorHandler.showWarningSnackbar(this, message);
  }
}
