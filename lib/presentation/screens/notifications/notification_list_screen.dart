import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../services/notification_service.dart';

/// Notification history / list screen — embedded in the Notifications tab.
class NotificationListScreen extends StatefulWidget {
  /// When true the widget is embedded inside the HomeScreen (no own Scaffold).
  final bool embedded;

  const NotificationListScreen({super.key, this.embedded = false});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final NotificationRepository _repo;
  late final NotificationService _notificationService;

  List<AppNotificationEntity> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = getIt<NotificationRepository>();
    _notificationService = getIt<NotificationService>();
    _loadNotifications();

    // Live updates
    _notificationService.notificationStream.listen((_) {
      if (mounted) _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.getAllNotifications();
      if (mounted) setState(() => _notifications = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _repo.markAllNotificationsAsRead();
    _loadNotifications();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'This will permanently delete all mirrored notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.clearAllNotifications();
      _loadNotifications();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.embedded) {
      // Embedded in HomeScreen — no Scaffold, the parent provides AppBar
      return Container(
        color: const Color(0xFF0A0F0A),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white70),
              tooltip: 'Mark all read',
              onPressed: _markAllRead,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: body,
    );
  }

  // ── Header (for embedded mode) ────────────────────────────────────────

  Widget _buildHeader() {
    final unread = _notifications.where((n) => !n.isRead).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          if (unread > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF166534),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unread unread',
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white54, size: 20),
              tooltip: 'Mark all read',
              onPressed: _markAllRead,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep,
                  color: Colors.white54, size: 20),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            onPressed: _loadNotifications,
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return StreamBuilder<bool>(
      stream: _notificationService.syncStateStream,
      initialData: _notificationService.isSyncing,
      builder: (context, snapshot) {
        final isSyncing = snapshot.data ?? false;
        return Column(
          children: [
            if (isSyncing)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFF4ADE80),
                minHeight: 2,
              ),
            Expanded(child: _buildList()),
          ],
        );
      },
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading notifications',
                style: TextStyle(color: Colors.red[300], fontSize: 16)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF166534).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none,
                  size: 48, color: Color(0xFF4ADE80)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Notifications',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mirrored notifications from your\nAndroid device will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF4ADE80),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _buildNotificationTile(_notifications[index]),
      ),
    );
  }

  // ── Notification tile ──────────────────────────────────────────────────

  Widget _buildNotificationTile(AppNotificationEntity n) {
    final hasIcon = n.iconBase64 != null && n.iconBase64!.isNotEmpty;

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) {
        _repo.deleteNotification(n.id);
        setState(() => _notifications.removeWhere((x) => x.id == n.id));
      },
      child: GestureDetector(
        onTap: () async {
          if (!n.isRead) {
            await _repo.markNotificationAsRead(n.id);
            _loadNotifications();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: n.isRead ? const Color(0xFF0F1A0F) : const Color(0xFF0F1A0F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.isRead
                  ? const Color(0xFF1A2A1A)
                  : const Color(0xFF166534).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: hasIcon
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(n.iconBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.apps,
                              color: Color(0xFF4ADE80), size: 22),
                        ),
                      )
                    : const Icon(Icons.apps,
                        color: Color(0xFF4ADE80), size: 22),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.appName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(n.timestamp),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (n.title != null && n.title!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        n.title!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight:
                              n.isRead ? FontWeight.w400 : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (n.body != null && n.body!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        n.body!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Unread dot
              if (!n.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
