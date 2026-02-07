import 'package:flutter/material.dart';

import '../../../data/models/call_models.dart';
import '../../../services/call_service.dart';
import '../../../core/di/injection.dart';

/// Call log/history screen
class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  late final CallService _callService;
  
  List<CallLogEntry> _callLog = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _callService = getIt<CallService>();
    _loadCallLog();
    
    // Listen for updates
    _callService.callLogStream.listen((entries) {
      if (mounted) {
        setState(() => _callLog = entries);
      }
    });
  }

  Future<void> _loadCallLog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final log = await _callService.loadCallLog();
      if (mounted) {
        setState(() {
          _callLog = log;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load call history';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Call History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadCallLog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6C5CE7),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCallLog,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_callLog.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No call history',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCallLog,
      child: ListView.builder(
        itemCount: _callLog.length,
        itemBuilder: (context, index) => _buildCallLogTile(_callLog[index]),
      ),
    );
  }

  Widget _buildCallLogTile(CallLogEntry entry) {
    final icon = _getCallTypeIcon(entry.type);
    final color = _getCallTypeColor(entry.type);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        entry.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 14),
          const SizedBox(width: 4),
          Text(
            entry.type.displayName,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          if (entry.formattedDuration.isNotEmpty) ...[
            Text(
              ' • ',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              entry.formattedDuration,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ],
      ),
      trailing: Text(
        entry.formattedTime,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      onTap: () {
        // Could launch dialer or show options
      },
    );
  }

  IconData _getCallTypeIcon(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
      case CallType.rejected:
        return Icons.call_end;
      case CallType.blocked:
        return Icons.block;
      case CallType.voicemail:
        return Icons.voicemail;
    }
  }

  Color _getCallTypeColor(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
      case CallType.rejected:
        return Colors.red;
      case CallType.blocked:
        return Colors.orange;
      case CallType.voicemail:
        return Colors.purple;
    }
  }
}
