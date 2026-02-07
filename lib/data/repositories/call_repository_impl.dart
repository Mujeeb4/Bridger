import 'package:drift/drift.dart';

import '../../datasources/local/database.dart';
import '../../../domain/entities/call_log.dart';
import '../../../domain/repositories/call_repository.dart';

/// Implementation of CallRepository using Drift database
class CallRepositoryImpl implements CallRepository {
  final AppDatabase _database;

  CallRepositoryImpl(this._database);

  @override
  Future<List<CallLogEntity>> getAllCallLogs() async {
    final logs = await _database.getAllCallLogs();
    return logs.map(_mapToEntity).toList();
  }

  @override
  Future<List<CallLogEntity>> getCallLogsForNumber(String phoneNumber) async {
    final logs = await (_database.select(_database.callLogs)
      ..where((c) => c.phoneNumber.equals(phoneNumber))
      ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
    ).get();
    return logs.map(_mapToEntity).toList();
  }

  @override
  Future<List<CallLogEntity>> getMissedCalls() async {
    final logs = await (_database.select(_database.callLogs)
      ..where((c) => c.callType.isIn(['missed', 'rejected']))
      ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
    ).get();
    return logs.map(_mapToEntity).toList();
  }

  @override
  Future<CallLogEntity> saveCallLog(CallLogEntity callLog) async {
    final id = await _database.insertCallLog(
      CallLogsCompanion.insert(
        phoneNumber: callLog.phoneNumber,
        contactName: Value(callLog.contactName),
        callType: CallLogEntity.callTypeToString(callLog.callType),
        duration: Value(callLog.duration),
        timestamp: callLog.timestamp,
        isNew: Value(callLog.isNew),
      ),
    );
    return callLog.copyWith(id: id);
  }

  @override
  Future<void> markCallLogAsRead(int id) async {
    await _database.markCallLogAsRead(id);
  }

  @override
  Future<void> markAllCallLogsAsRead() async {
    await (_database.update(_database.callLogs))
        .write(const CallLogsCompanion(isNew: Value(false)));
  }

  @override
  Future<void> deleteCallLog(int id) async {
    await _database.deleteCallLog(id);
  }

  @override
  Future<void> clearAllCallLogs() async {
    await _database.clearAllCallLogs();
  }

  @override
  Future<int> getNewCallsCount() async {
    final count = await (_database.select(_database.callLogs)
      ..where((c) => c.isNew.equals(true))
    ).get();
    return count.length;
  }

  CallLogEntity _mapToEntity(CallLog log) {
    return CallLogEntity(
      id: log.id,
      phoneNumber: log.phoneNumber,
      contactName: log.contactName,
      callType: CallLogEntity.callTypeFromString(log.callType),
      duration: log.duration,
      timestamp: log.timestamp,
      isNew: log.isNew,
    );
  }
}
