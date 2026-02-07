import 'package:flutter/material.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardTab(),
    const SMSTab(),
    const CallsTab(),
    const NotificationsTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        elevation: 0,
        title: const Text(
          'Bridge Phone',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF166534),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bluetooth_connected, size: 14, color: Color(0xFF4ADE80)),
                    SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A0F),
          border: Border(
            top: BorderSide(color: const Color(0xFF1A2A1A).withOpacity(0.5)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF166534),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFF4ADE80)),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.message_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.message, color: Color(0xFF4ADE80)),
              label: 'SMS',
            ),
            NavigationDestination(
              icon: Icon(Icons.phone_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.phone, color: Color(0xFF4ADE80)),
              label: 'Calls',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.notifications, color: Color(0xFF4ADE80)),
              label: 'Notifications',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF4ADE80)),
              label: 'Settings',
            ),
          ],
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}

// Dashboard Tab
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F0A),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device role card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF166534).withOpacity(0.3),
                    const Color(0xFF0F1A0F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1A2A1A)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF166534),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Platform.isAndroid ? Icons.phone_android : Icons.phone_iphone,
                      size: 40,
                      color: const Color(0xFF4ADE80),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Platform.isAndroid ? 'Android Bridge Device' : 'iPhone Controller',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'This device provides SMS, calls, and connectivity'
                        : 'Use this device to control your Android phone',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Connection status
            const Text(
              'Connection Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusCard(
              icon: Icons.bluetooth,
              iconColor: const Color(0xFF4ADE80),
              title: 'Bluetooth',
              subtitle: 'Connected',
              isActive: true,
            ),
            const SizedBox(height: 8),
            _buildStatusCard(
              icon: Icons.wifi,
              iconColor: Colors.white54,
              title: 'Wi-Fi Hotspot',
              subtitle: 'Not active',
              isActive: false,
            ),
            const SizedBox(height: 24),
            
            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Platform.isAndroid ? Icons.qr_code : Icons.qr_code_scanner,
              label: Platform.isAndroid ? 'Generate Pairing QR' : 'Scan Pairing QR',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Navigate to pairing screen'),
                    backgroundColor: const Color(0xFF166534),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isActive,
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF166534) : const Color(0xFF1A2A1A),
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
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF4ADE80) : Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF4ADE80) : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF166534),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF4ADE80)),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SMS Tab (placeholder)
class SMSTab extends StatelessWidget {
  const SMSTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F0A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF166534).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.message_outlined, size: 48, color: Color(0xFF4ADE80)),
            ),
            const SizedBox(height: 20),
            const Text(
              'SMS Messages',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your messages will appear here',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// Calls Tab (placeholder)
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F0A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF166534).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_outlined, size: 48, color: Color(0xFF4ADE80)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Call History',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your call logs will appear here',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// Notifications Tab (placeholder)
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F0A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF166534).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_outlined, size: 48, color: Color(0xFF4ADE80)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Notifications',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mirrored notifications will appear here',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Tab - Full Implementation
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Navigate directly to SettingsScreen
    return const _SettingsTabContent();
  }
}

class _SettingsTabContent extends StatefulWidget {
  const _SettingsTabContent();

  @override
  State<_SettingsTabContent> createState() => _SettingsTabContentState();
}

class _SettingsTabContentState extends State<_SettingsTabContent> {
  bool _autoConnect = true;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F0A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Section
          _buildSection(
            title: 'Connection',
            icon: Icons.bluetooth,
            children: [
              _buildDeviceStatus(),
              _buildSwitchTile(
                'Auto-Connect',
                'Automatically connect to paired device',
                _autoConnect,
                (v) => setState(() => _autoConnect = v),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Notifications Section
          _buildSection(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              _buildSwitchTile(
                'Mirror Notifications',
                'Show Android notifications',
                _notificationsEnabled,
                (v) => setState(() => _notificationsEnabled = v),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // About Section
          _buildSection(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              _buildInfoTile('Version', '1.0.0'),
              _buildInfoTile('Build', '2024.02.07'),
              _buildActionTile(
                'Licenses',
                Icons.chevron_right,
                () => showLicensePage(
                  context: context,
                  applicationName: 'Bridge Phone',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A2A1A)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF4ADE80), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

  Widget _buildDeviceStatus() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF166534),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_android, color: Color(0xFF4ADE80), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bridge Device',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  'Connected',
                  style: TextStyle(color: Color(0xFF4ADE80), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF166534),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'BLE',
              style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4ADE80),
            activeTrackColor: const Color(0xFF166534),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData trailing, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            Icon(trailing, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}
