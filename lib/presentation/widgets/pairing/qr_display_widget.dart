import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/models/pairing_models.dart';

/// Widget that displays a QR code for pairing (Android only)
class QRDisplayWidget extends StatelessWidget {
  final PairingQRData qrData;
  final String? pairingCode;
  final Duration? remainingTime;
  final VoidCallback? onRefresh;

  const QRDisplayWidget({
    super.key,
    required this.qrData,
    this.pairingCode,
    this.remainingTime,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        Text(
          'Pair with iPhone',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan this QR code with Bridge Phone on your iPhone',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // QR Code Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: QrImageView(
            data: qrData.encode(),
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.roundedRect,
              color: colorScheme.primary,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.roundedRect,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Manual Code
        if (pairingCode != null) ...[
          Text(
            'Or enter this code manually:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatCode(pairingCode!),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Expiry/Refresh
        if (remainingTime != null) ...[
          _buildExpiryIndicator(context),
          const SizedBox(height: 16),
        ],

        // Refresh button
        if (onRefresh != null)
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate New Code'),
          ),
      ],
    );
  }

  String _formatCode(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  Widget _buildExpiryIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = remainingTime!.inSeconds;
    final isExpiringSoon = seconds < 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: isExpiringSoon 
              ? theme.colorScheme.error 
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Expires in ${_formatDuration(remainingTime!)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isExpiringSoon 
                ? theme.colorScheme.error 
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
