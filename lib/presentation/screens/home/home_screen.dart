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
      appBar: AppBar(
        title: const Text('Bridge Phone'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 16),
                    SizedBox(width: 4),
                    Text('Not Connected', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_outlined),
            selectedIcon: Icon(Icons.phone),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Dashboard Tab
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device role card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Platform.isAndroid ? Icons.phone_android : Icons.phone_iphone,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Platform.isAndroid ? 'Android Bridge Device' : 'iPhone Controller',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'This device provides SMS, calls, and connectivity'
                        : 'Use this device to control your Android phone',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Connection status
          Text(
            'Connection Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.bluetooth, color: Colors.grey),
              title: Text('Bluetooth'),
              subtitle: Text('Not connected'),
              trailing: Icon(Icons.circle, color: Colors.grey, size: 12),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.wifi, color: Colors.grey),
              title: Text('Wi-Fi Hotspot'),
              subtitle: Text('Not active'),
              trailing: Icon(Icons.circle, color: Colors.grey, size: 12),
            ),
          ),
          const SizedBox(height: 20),
          
          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (Platform.isAndroid)
            ElevatedButton.icon(
              onPressed: () {
                // Will be implemented in later phases
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pairing will be implemented in Phase 5')),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Generate Pairing QR Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                // Will be implemented in later phases
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pairing will be implemented in Phase 5')),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Pairing QR Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }
}

// SMS Tab (placeholder)
class SMSTab extends StatelessWidget {
  const SMSTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('SMS functionality will be added in Phase 8-9'),
        ],
      ),
    );
  }
}

// Calls Tab (placeholder)
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Call functionality will be added in Phase 10-12'),
        ],
      ),
    );
  }
}

// Notifications Tab (placeholder)
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Notification mirroring will be added in Phase 13'),
        ],
      ),
    );
  }
}

// Settings Tab (placeholder)
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ListTile(
          title: Text('App Settings'),
          subtitle: Text('Phase 1 - Basic UI Complete'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: const Text('Bridge Phone v1.0.0'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Bridge Phone',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.phone_android, size: 48),
              children: [
                const Text('Cross-platform phone bridge for non-PTA iPhones'),
              ],
            );
          },
        ),
      ],
    );
  }
}
