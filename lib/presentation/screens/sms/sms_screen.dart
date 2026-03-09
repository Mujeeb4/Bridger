import 'package:flutter/material.dart';

import '../../../data/models/sms_models.dart';
import '../../../services/sms_service.dart';
import '../../../core/di/injection.dart';
import 'conversation_screen.dart';

/// SMS inbox screen showing all conversation threads
class SMSScreen extends StatefulWidget {
  /// When true, the screen is embedded in the HomeScreen tab (no own Scaffold).
  final bool embedded;

  const SMSScreen({super.key, this.embedded = false});

  @override
  State<SMSScreen> createState() => _SMSScreenState();
}

class _SMSScreenState extends State<SMSScreen> {
  late final SMSService _smsService;

  List<SMSThread> _threads = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _smsService = getIt<SMSService>();
    _loadThreads();

    // Listen for updates
    _smsService.threadsStream.listen((threads) {
      if (mounted) {
        setState(() => _threads = threads);
      }
    });
  }

  Future<void> _loadThreads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final threads = await _smsService.loadThreads();
      if (mounted) {
        setState(() {
          _threads = threads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load messages';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      // Embedded mode — body only, parent provides AppBar
      return Container(
        color: const Color(0xFF0A0F0A),
        child: Column(
          children: [
            // Inline header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    '${_threads.length} conversations',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white54, size: 20),
                    onPressed: _loadThreads,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadThreads,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewConversation,
        backgroundColor: const Color(0xFF166534),
        child: const Icon(Icons.message, color: Color(0xFF4ADE80)),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<bool>(
      stream: _smsService.syncStateStream,
      initialData: _smsService.isSyncing,
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
        child: CircularProgressIndicator(
          color: Color(0xFF4ADE80),
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
            FilledButton.icon(
              onPressed: _loadThreads,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_threads.isEmpty) {
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
              child: const Icon(Icons.message_outlined,
                  size: 48, color: Color(0xFF4ADE80)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Messages',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'SMS conversations will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadThreads,
          color: const Color(0xFF4ADE80),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, index) => _buildThreadTile(_threads[index]),
          ),
        ),
        // FAB for embedded mode too
        if (widget.embedded)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _startNewConversation,
              backgroundColor: const Color(0xFF166534),
              child: const Icon(Icons.message, color: Color(0xFF4ADE80)),
            ),
          ),
      ],
    );
  }

  Widget _buildThreadTile(SMSThread thread) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF166534),
        child: Text(
          thread.displayName.isNotEmpty
              ? thread.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Color(0xFF4ADE80),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        thread.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        thread.snippet,
        style: TextStyle(color: Colors.grey[500]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            thread.formattedTime,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF166534).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${thread.messageCount}',
              style: const TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      onTap: () => _openConversation(thread),
    );
  }

  void _openConversation(SMSThread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          threadId: thread.threadId,
          address: thread.address,
          displayName: thread.displayName,
        ),
      ),
    );
  }

  void _startNewConversation() {
    showDialog(
      context: context,
      builder: (context) => _NewConversationDialog(
        onStart: (phoneNumber) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationScreen(
                threadId: null,
                address: phoneNumber,
                displayName: phoneNumber,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewConversationDialog extends StatefulWidget {
  final void Function(String phoneNumber) onStart;

  const _NewConversationDialog({required this.onStart});

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1A0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'New Message',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Enter phone number',
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF1A2A1A)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF4ADE80)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context);
              widget.onStart(_controller.text);
            }
          },
          child: const Text('Start'),
        ),
      ],
    );
  }
}
