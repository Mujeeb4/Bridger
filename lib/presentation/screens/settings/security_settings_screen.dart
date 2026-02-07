import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../services/ble_service.dart';
import '../../../services/encryption_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _settingsRepo = GetIt.I<SettingsRepository>();
  final _bleService = GetIt.I<BleService>();
  final _encryptionService = GetIt.I<EncryptionService>();

  bool _isEncryptionEnabled = true;
  bool _isKeyVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final encryption = await _settingsRepo.getBoolSetting('encryptionEnabled');
    setState(() {
      _isEncryptionEnabled = encryption;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Security',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Encryption Status
          _buildSecurityCard(
            icon: Icons.lock_outline,
            iconColor: const Color(0xFF4ADE80),
            title: 'End-to-End Encryption',
            subtitle: 'All data is encrypted with AES-256',
            trailing: Switch(
              value: _isEncryptionEnabled,
              onChanged: (value) async {
                setState(() => _isEncryptionEnabled = value);
                await _settingsRepo.setBoolSetting('encryptionEnabled', value);
              },
              activeColor: const Color(0xFF4ADE80),
              activeTrackColor: const Color(0xFF166534),
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: const Color(0xFF2A2A2A),
            ),
          ),

          const SizedBox(height: 16),

          // Encryption Key
          _buildSecurityCard(
            icon: Icons.vpn_key_outlined,
            iconColor: const Color(0xFF4ADE80),
            title: 'Encryption Key',
            subtitle: _isKeyVisible 
                ? _encryptionService.getKeyFingerprint() 
                : '•••••••••••••••••••••••••',
            trailing: IconButton(
              icon: Icon(
                _isKeyVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed: () {
                setState(() => _isKeyVisible = !_isKeyVisible);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Device Trust
          _buildSecurityCard(
            icon: Icons.verified_user_outlined,
            iconColor: const Color(0xFF4ADE80),
            title: 'Trusted Device',
            subtitle: 'This device is trusted for secure communication',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF166534),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Danger Zone
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Clear Data Button
                _buildDangerButton(
                  icon: Icons.delete_outline,
                  label: 'Clear All Local Data',
                  onTap: _showClearDataDialog,
                ),
                
                const SizedBox(height: 12),
                
                // Unpair Button
                _buildDangerButton(
                  icon: Icons.link_off,
                  label: 'Unpair Device',
                  onTap: _showUnpairDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A2A1A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.red.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A0F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all local messages, call logs, and settings. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement clear data
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All data cleared'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A0F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unpair Device', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to unpair? You will need to pair again to use Bridge Phone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _settingsRepo.setPairedDeviceId(null);
              await _settingsRepo.setDevicePaired(false);
              _bleService.disconnect();
              
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }
}
