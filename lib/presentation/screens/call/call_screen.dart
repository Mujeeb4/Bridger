import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/call_models.dart';
import '../../../services/call_service.dart';
import '../../../core/di/injection.dart';

/// Active call screen
class CallScreen extends StatefulWidget {
  final CallInfo callInfo;

  const CallScreen({super.key, required this.callInfo});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallService _callService;
  late CallInfo _callInfo;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _callService = getIt<CallService>();
    _callInfo = widget.callInfo;

    // Listen for call state changes
    _callService.callStateStream.listen((info) {
      if (info == null) {
        // Call ended
        Navigator.of(context).pop();
      } else {
        setState(() => _callInfo = info);
      }
    });

    // Start duration timer if call is active
    if (_callInfo.state == CallState.active) {
      _startDurationTimer();
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            _buildCallerInfo(),
            const Spacer(),
            _buildCallControls(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      children: [
        // Caller avatar
        CircleAvatar(
          radius: 60,
          backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.2),
          child: Text(
            _callInfo.displayName.isNotEmpty 
                ? _callInfo.displayName[0].toUpperCase() 
                : '?',
            style: const TextStyle(
              fontSize: 48,
              color: Color(0xFF6C5CE7),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Caller name
        Text(
          _callInfo.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Call status / duration
        Text(
          _callInfo.state == CallState.active 
              ? _callInfo.formattedDuration
              : _callInfo.state.displayName,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls() {
    if (_callInfo.state == CallState.ringing && _callInfo.type == CallType.incoming) {
      // Incoming call - show accept/reject
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: _rejectCall,
          ),
          _buildActionButton(
            icon: Icons.call,
            color: Colors.green,
            onPressed: _answerCall,
          ),
        ],
      );
    }

    // Active call - show control buttons
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _callInfo.isMuted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              isActive: _callInfo.isMuted,
              onPressed: _toggleMute,
            ),
            _buildControlButton(
              icon: Icons.dialpad,
              label: 'Keypad',
              onPressed: () {},
            ),
            _buildControlButton(
              icon: _callInfo.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              isActive: _callInfo.isSpeakerOn,
              onPressed: _toggleSpeaker,
            ),
          ],
        ),
        const SizedBox(height: 40),
        _buildActionButton(
          icon: Icons.call_end,
          color: Colors.red,
          size: 72,
          onPressed: _endCall,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 64,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _answerCall() async {
    await _callService.answerCall();
    _startDurationTimer();
  }

  void _rejectCall() async {
    await _callService.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  void _endCall() async {
    await _callService.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    _callService.setMuted(!_callInfo.isMuted);
  }

  void _toggleSpeaker() {
    _callService.setSpeakerphone(!_callInfo.isSpeakerOn);
  }
}
