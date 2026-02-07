import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../data/models/pairing_models.dart';
import '../../../services/pairing_service.dart';
import '../../widgets/pairing/qr_display_widget.dart';
import '../../widgets/pairing/qr_scanner_widget.dart';
import '../../widgets/pairing/code_entry_widget.dart';

/// Main pairing screen that adapts to platform
/// - Android: Shows QR code for iOS to scan
/// - iOS: Shows scanner or manual code entry
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final PairingService _pairingService = GetIt.I<PairingService>();
  
  PairingState _state = PairingState.idle;
  PairingQRData? _qrData;
  String? _pairingCode;
  Duration? _remainingTime;
  Timer? _countdownTimer;
  
  // iOS: toggle between scanner and manual entry
  bool _showManualEntry = false;
  
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _pairingService.stateStream.listen((state) {
      setState(() => _state = state);
      if (state == PairingState.paired) {
        _onPaired();
      }
    });
    
    _initialize();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (Platform.isAndroid) {
      await _generatePairingCode();
    }
  }

  Future<void> _generatePairingCode() async {
    final qrData = await _pairingService.generatePairingCode();
    if (qrData != null) {
      setState(() {
        _qrData = qrData;
        _pairingCode = _pairingService.getPairingCodeString();
        _startCountdown();
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _pairingService.getCodeRemainingTime();
      setState(() => _remainingTime = remaining);
      
      if (remaining == null || remaining.inSeconds <= 0) {
        _countdownTimer?.cancel();
        _generatePairingCode();
      }
    });
  }

  void _onQRScanned(String qrData) async {
    final success = await _pairingService.processPairingQR(qrData);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pair. Please try again.')),
      );
      setState(() {}); // Reset scanner
    }
  }

  void _onCodeEntered(String code) async {
    // For manual entry, we need to know the device ID
    // In real implementation, this would be discovered via BLE scan
    final success = await _pairingService.enterPairingCode(code, 'manual-entry');
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid code. Please try again.')),
      );
    }
  }

  void _onPaired() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Successfully paired!'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Navigate back or to home
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair Devices'),
        actions: [
          if (_state == PairingState.paired)
            IconButton(
              onPressed: () async {
                await _pairingService.unpair();
                setState(() {});
              },
              icon: const Icon(Icons.link_off),
              tooltip: 'Unpair',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Show loading for transitional states
    if (_state == PairingState.generatingCode ||
        _state == PairingState.connecting ||
        _state == PairingState.exchangingKeys) {
      return _buildLoadingState();
    }

    // Show success state
    if (_state == PairingState.paired) {
      return _buildPairedState();
    }

    // Show failure
    if (_state == PairingState.failed) {
      return _buildFailedState();
    }

    // Platform-specific content
    if (Platform.isAndroid) {
      return _buildAndroidContent();
    } else {
      return _buildIOSContent();
    }
  }

  Widget _buildLoadingState() {
    String message = 'Loading...';
    switch (_state) {
      case PairingState.generatingCode:
        message = 'Generating pairing code...';
        break;
      case PairingState.connecting:
        message = 'Connecting to device...';
        break;
      case PairingState.exchangingKeys:
        message = 'Establishing secure connection...';
        break;
      default:
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildPairedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Devices Paired!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your devices are now connected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Pairing Failed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to pair devices. Please try again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              if (Platform.isAndroid) {
                _generatePairingCode();
              } else {
                setState(() {
                  _showManualEntry = false;
                });
              }
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidContent() {
    if (_qrData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: QRDisplayWidget(
        qrData: _qrData!,
        pairingCode: _pairingCode,
        remainingTime: _remainingTime,
        onRefresh: _generatePairingCode,
      ),
    );
  }

  Widget _buildIOSContent() {
    if (_showManualEntry) {
      return CodeEntryWidget(
        onSubmit: _onCodeEntered,
        onCancel: () => setState(() => _showManualEntry = false),
      );
    }

    return QRScannerWidget(
      onScanned: _onQRScanned,
      onCancel: () => setState(() => _showManualEntry = true),
    );
  }
}
