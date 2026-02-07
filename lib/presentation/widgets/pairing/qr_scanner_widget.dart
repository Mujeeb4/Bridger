import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Widget for scanning QR codes (iOS only)
class QRScannerWidget extends StatefulWidget {
  final void Function(String qrData) onScanned;
  final VoidCallback? onCancel;

  const QRScannerWidget({
    super.key,
    required this.onScanned,
    this.onCancel,
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() => _hasScanned = true);
    widget.onScanned(barcode.rawValue!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Scan QR Code',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Point your camera at the QR code on your Android device',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Scanner
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outline,
                width: 2,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                
                // Scanning overlay
                _buildScanOverlay(context),
                
                // Controls
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Toggle flash
                      IconButton.filled(
                        onPressed: () => _controller.toggleTorch(),
                        icon: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, state, _) {
                            return Icon(
                              state.torchState == TorchState.on
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                            );
                          },
                        ),
                      ),
                      // Switch camera
                      IconButton.filled(
                        onPressed: () => _controller.switchCamera(),
                        icon: const Icon(Icons.cameraswitch),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Cancel button
        if (widget.onCancel != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text('Enter Code Manually Instead'),
            ),
          ),
      ],
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
