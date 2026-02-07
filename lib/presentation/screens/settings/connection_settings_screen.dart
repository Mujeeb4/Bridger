import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../domain/repositories/settings_repository.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _settingsRepo = GetIt.I<SettingsRepository>();

  double _connectionTimeout = 30.0;
  int _reconnectAttempts = 5;
  bool _batteryMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final timeout = await _settingsRepo.getIntSetting('connectionTimeout', defaultValue: 30);
    final attempts = await _settingsRepo.getIntSetting('reconnectAttempts', defaultValue: 5);
    final battery = await _settingsRepo.getBoolSetting('batteryMode');
    
    setState(() {
      _connectionTimeout = timeout.toDouble();
      _reconnectAttempts = attempts;
      _batteryMode = battery;
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
          'Connection Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Connection Timeout
          _buildSettingCard(
            title: 'Connection Timeout',
            subtitle: '${_connectionTimeout.toInt()} seconds',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF4ADE80),
                inactiveTrackColor: const Color(0xFF2A3A2A),
                thumbColor: const Color(0xFF4ADE80),
                overlayColor: const Color(0xFF4ADE80).withOpacity(0.2),
              ),
              child: Slider(
                value: _connectionTimeout,
                min: 10,
                max: 120,
                divisions: 11,
                onChanged: (value) async {
                  setState(() => _connectionTimeout = value);
                  await _settingsRepo.setIntSetting('connectionTimeout', value.toInt());
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reconnect Attempts
          _buildSettingCard(
            title: 'Reconnect Attempts',
            subtitle: 'Number of times to retry connection',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNumberButton(
                  icon: Icons.remove,
                  onTap: () async {
                    if (_reconnectAttempts > 1) {
                      setState(() => _reconnectAttempts--);
                      await _settingsRepo.setIntSetting('reconnectAttempts', _reconnectAttempts);
                    }
                  },
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_reconnectAttempts',
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildNumberButton(
                  icon: Icons.add,
                  onTap: () async {
                    if (_reconnectAttempts < 20) {
                      setState(() => _reconnectAttempts++);
                      await _settingsRepo.setIntSetting('reconnectAttempts', _reconnectAttempts);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Battery Mode
          _buildSettingCard(
            title: 'Battery Saver Mode',
            subtitle: 'Reduce connection frequency to save battery',
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      label: 'Performance',
                      isSelected: !_batteryMode,
                      onTap: () async {
                        setState(() => _batteryMode = false);
                        await _settingsRepo.setBoolSetting('batteryMode', false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModeButton(
                      label: 'Battery Saver',
                      isSelected: _batteryMode,
                      onTap: () async {
                        setState(() => _batteryMode = true);
                        await _settingsRepo.setBoolSetting('batteryMode', true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Info Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A1A).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3A2A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF4ADE80), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Battery Saver Mode may cause slight delays in receiving notifications.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A2A1A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildNumberButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1A2A1A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF166534) : const Color(0xFF1A2A1A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF4ADE80) : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
