import '../entities/call_log.dart';

/// Repository interface for call log operations
abstract class CallRepository {
  /// Get all call logs sorted by most recent
  Future<List<CallLogEntity>> getAllCallLogs();

  /// Get call logs for a specific phone number
  Future<List<CallLogEntity>> getCallLogsForNumber(String phoneNumber);

  /// Get only missed calls
  Future<List<CallLogEntity>> getMissedCalls();

  /// Save a new call log entry
  Future<CallLogEntity> saveCallLog(CallLogEntity callLog);

  /// Mark a call log as read (not new)
  Future<void> markCallLogAsRead(int id);

  /// Mark all call logs as read
  Future<void> markAllCallLogsAsRead();

  /// Delete a specific call log entry
  Future<void> deleteCallLog(int id);

  /// Clear all call logs
  Future<void> clearAllCallLogs();

  /// Get count of new (unread) calls
  Future<int> getNewCallsCount();
}
