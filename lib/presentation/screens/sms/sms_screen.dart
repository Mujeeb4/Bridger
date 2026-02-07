import 'package:flutter/material.dart';

import '../../../data/models/sms_models.dart';
import '../../../services/sms_service.dart';
import '../../../core/di/injection.dart';
import 'conversation_screen.dart';

/// SMS inbox screen showing all conversation threads
class SMSScreen extends StatefulWidget {
  const SMSScreen({super.key});

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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
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
        backgroundColor: const Color(0xFF6C5CE7),
        child: const Icon(Icons.message, color: Colors.white),
      ),
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
              onPressed: _loadThreads,
              child: const Text('Retry'),
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
            Icon(Icons.inbox, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
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
      onRefresh: _loadThreads,
      child: ListView.builder(
        itemCount: _threads.length,
        itemBuilder: (context, index) => _buildThreadTile(_threads[index]),
      ),
    );
  }

  Widget _buildThreadTile(SMSThread thread) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.2),
        child: Text(
          thread.displayName.isNotEmpty ? thread.displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFF6C5CE7),
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
              color: const Color(0xFF6C5CE7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${thread.messageCount}',
              style: const TextStyle(
                color: Color(0xFF6C5CE7),
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
    // Show dialog to enter phone number
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
      backgroundColor: const Color(0xFF1E1E1E),
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
          hintStyle: TextStyle(color: Colors.grey[600]),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[700]!),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF6C5CE7)),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context);
              widget.onStart(_controller.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
          ),
          child: const Text('Start'),
        ),
      ],
    );
  }
}
