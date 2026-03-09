import 'package:flutter/material.dart';
import 'dart:io';

import '../../../services/hotspot_service.dart';
import '../../../data/models/hotspot_models.dart';

import '../../../services/ble_service.dart';
import '../../../data/models/ble_models.dart';
import '../../../core/di/injection.dart';
import '../pairing/pairing_screen.dart';
import '../sms/sms_screen.dart';
import '../call/call_log_screen.dart';
import '../notifications/notification_list_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Listen for hotspot errors (e.g. NO_INTERNET)
    getIt<HotspotService>().errorStream.listen((error) {
      if (mounted) {
        final message = error == 'NO_INTERNET'
            ? 'No internet connection. Please enable mobile data.'
            : error;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        elevation: 0,
        title: const Text(
          'Bridger',
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
              child: StreamBuilder<BleConnectionState>(
                stream: getIt<BleService>().connectionStateStream,
                initialData: getIt<BleService>().connectionState,
                builder: (context, snapshot) {
                  final state =
                      snapshot.data ?? BleConnectionState.disconnected;
                  final isConnected = state == BleConnectionState.connected;

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF166534)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isConnected
                            ? const Color(0xFF4ADE80).withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          size: 14,
                          color: isConnected
                              ? const Color(0xFF4ADE80)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 12,
                            color: isConnected
                                ? const Color(0xFF4ADE80)
                                : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          SMSScreen(embedded: true),
          CallLogScreen(embedded: true),
          NotificationListScreen(embedded: true),
          _SettingsTabWrapper(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A0F),
          border: Border(
            top: BorderSide(
                color: const Color(0xFF1A2A1A).withValues(alpha: 0.5)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF166534),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
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
              label: 'Alerts',
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

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard Tab
// ═══════════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

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
                    const Color(0xFF166534).withValues(alpha: 0.3),
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
                      Platform.isAndroid
                          ? Icons.phone_android
                          : Icons.phone_iphone,
                      size: 40,
                      color: const Color(0xFF4ADE80),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Platform.isAndroid
                        ? 'Android Bridge Device'
                        : 'iPhone Controller',
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
            StreamBuilder<BleConnectionState>(
              stream: getIt<BleService>().connectionStateStream,
              initialData: getIt<BleService>().connectionState,
              builder: (context, snapshot) {
                final state = snapshot.data ?? BleConnectionState.disconnected;
                final isConnected = state == BleConnectionState.connected;

                return _buildStatusCard(
                  icon: isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  iconColor:
                      isConnected ? const Color(0xFF4ADE80) : Colors.grey,
                  title: 'Bluetooth',
                  subtitle: isConnected ? 'Connected' : 'Disconnected',
                  isActive: isConnected,
                );
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<HotspotState>(
              stream: getIt<HotspotService>().stateStream,
              initialData: getIt<HotspotService>().state,
              builder: (context, snapshot) {
                final state = snapshot.data ?? HotspotState.idle;
                // Determine active state for UI
                final isActive = state == HotspotState.active ||
                    state == HotspotState.connected ||
                    state == HotspotState.starting;

                String subtitle;
                switch (state) {
                  case HotspotState.idle:
                    subtitle = 'Tap to enable';
                    break;
                  case HotspotState.starting:
                  case HotspotState.connecting:
                    subtitle = 'Activating...';
                    break;
                  case HotspotState.active:
                    subtitle = 'Active (Android)';
                    break;
                  case HotspotState.connected:
                    subtitle = 'Connected (iOS)';
                    break;
                  case HotspotState.stopping:
                    subtitle = 'Stopping...';
                    break;
                  case HotspotState.error:
                    subtitle = 'Error (Tap to retry)';
                    break;
                }

                // If error, show message from stream? (handled by listener usually)
                // For now just basic state.

                return GestureDetector(
                  onTap: () =>
                      _toggleHotspot(context, getIt<HotspotService>(), state),
                  child: _buildStatusCard(
                    icon: Icons.wifi,
                    iconColor:
                        isActive ? const Color(0xFF4ADE80) : Colors.white54,
                    title: 'Wi-Fi Hotspot',
                    subtitle: subtitle,
                    isActive: isActive,
                  ),
                );
              },
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
              label: Platform.isAndroid
                  ? 'Generate Pairing QR'
                  : 'Scan Pairing QR',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PairingScreen()),
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
              color:
                  isActive ? const Color(0xFF166534) : const Color(0xFF1A2A1A),
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

  Widget _buildActionButton(
    BuildContext context, {
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

  Future<void> _toggleHotspot(BuildContext context, HotspotService service,
      HotspotState currentState) async {
    if (currentState == HotspotState.starting ||
        currentState == HotspotState.stopping ||
        currentState == HotspotState.connecting) {
      return;
    }

    if (currentState == HotspotState.active ||
        currentState == HotspotState.connected) {
      if (Platform.isAndroid) {
        await service.stopHotspot();
      } else {
        await service.requestStopHotspot();
      }
    } else {
      if (Platform.isAndroid) {
        await service.startHotspot();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Requesting Android to enable hotspot...')),
        );

        final creds = await service.requestStartHotspot();
        if (creds != null) {
          await service.connectToHotspot(creds);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to receive hotspot credentials')),
          );
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Settings Tab — delegates to the full SettingsScreen (embedded mode)
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsTabWrapper extends StatelessWidget {
  const _SettingsTabWrapper();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(embedded: true);
  }
}
