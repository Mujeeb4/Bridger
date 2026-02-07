import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../services/ble_service.dart';
import '../../../services/communication_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepo = GetIt.I<SettingsRepository>();
  final _bleService = GetIt.I<BleService>();
  final _communicationService = GetIt.I<CommunicationService>();

  bool _isAutoConnect = true;
  bool _isNotificationsEnabled = true;
  bool _isSyncing = false;
  String _pairedDeviceName = 'Not Connected';
  String _lastSyncTime = 'Never';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoConnect = await _settingsRepo.isAutoConnectEnabled();
    final deviceId = await _settingsRepo.getPairedDeviceId();
    
    setState(() {
      _isAutoConnect = autoConnect;
      _pairedDeviceName = deviceId ?? 'Not Connected';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Connection Card
            SliverToBoxAdapter(
              child: _buildSectionCard(
                title: 'Connection',
                icon: Icons.bluetooth,
                children: [
                  _buildDeviceStatusTile(),
                  const Divider(color: Color(0xFF2A3A2A), height: 1),
                  _buildSwitchTile(
                    title: 'Auto-Connect',
                    subtitle: 'Automatically connect when device is nearby',
                    value: _isAutoConnect,
                    onChanged: (value) async {
                      await _settingsRepo.setAutoConnectEnabled(value);
                      setState(() => _isAutoConnect = value);
                    },
                  ),
                ],
              ),
            ),

            // Sync Card
            SliverToBoxAdapter(
              child: _buildSectionCard(
                title: 'Sync',
                icon: Icons.sync,
                children: [
                  _buildActionTile(
                    title: 'Sync Contacts',
                    subtitle: 'Last synced: $_lastSyncTime',
                    trailing: _isSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4ADE80),
                            ),
                          )
                        : const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: _syncContacts,
                  ),
                ],
              ),
            ),

            // Notifications Card
            SliverToBoxAdapter(
              child: _buildSectionCard(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                children: [
                  _buildSwitchTile(
                    title: 'Mirror Notifications',
                    subtitle: 'Show Android notifications on this device',
                    value: _isNotificationsEnabled,
                    onChanged: (value) {
                      setState(() => _isNotificationsEnabled = value);
                    },
                  ),
                  const Divider(color: Color(0xFF2A3A2A), height: 1),
                  _buildActionTile(
                    title: 'App Filter',
                    subtitle: 'Choose which apps to mirror',
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      // TODO: Navigate to app filter screen
                    },
                  ),
                ],
              ),
            ),

            // Security Card
            SliverToBoxAdapter(
              child: _buildSectionCard(
                title: 'Security',
                icon: Icons.security,
                children: [
                  _buildActionTile(
                    title: 'Encryption',
                    subtitle: 'AES-256 encryption enabled',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF166534),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () {},
                  ),
                  const Divider(color: Color(0xFF2A3A2A), height: 1),
                  _buildActionTile(
                    title: 'Unpair Device',
                    subtitle: 'Disconnect and remove paired device',
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: _showUnpairDialog,
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            // About Card
            SliverToBoxAdapter(
              child: _buildSectionCard(
                title: 'About',
                icon: Icons.info_outline,
                children: [
                  _buildInfoTile('Version', '1.0.0'),
                  const Divider(color: Color(0xFF2A3A2A), height: 1),
                  _buildInfoTile('Build', '2024.02.07'),
                  const Divider(color: Color(0xFF2A3A2A), height: 1),
                  _buildActionTile(
                    title: 'Licenses',
                    subtitle: 'Open source licenses',
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Bridge Phone',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1A2A1A),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ADE80).withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF4ADE80), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1A2A1A), height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDeviceStatusTile() {
    final isConnected = _bleService.isConnected;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isConnected 
                  ? const Color(0xFF166534) 
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected ? Icons.phone_android : Icons.phone_android_outlined,
              color: isConnected 
                  ? const Color(0xFF4ADE80) 
                  : Colors.white54,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pairedDeviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConnected 
                            ? const Color(0xFF4ADE80) 
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: isConnected 
                            ? const Color(0xFF4ADE80) 
                            : Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'BLE',
                style: TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4ADE80),
            activeTrackColor: const Color(0xFF166534),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: const Color(0xFF2A2A2A),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? Colors.red : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncContacts() async {
    setState(() => _isSyncing = true);
    
    try {
      // TODO: Implement actual contact sync
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _lastSyncTime = 'Just now';
        _isSyncing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contacts synced successfully'),
            backgroundColor: const Color(0xFF166534),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showUnpairDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A0F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Unpair Device',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to unpair this device? You will need to pair again to use Bridge Phone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }
}
