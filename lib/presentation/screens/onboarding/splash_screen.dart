import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import '../../../services/permission_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Brief splash display
    await Future.delayed(const Duration(seconds: 1));

    // Request all required runtime permissions
    if (mounted) setState(() => _statusMessage = 'Requesting permissions...');
    final results = await PermissionService.requestAll();

    // Log denied permissions for debugging
    final denied = results.entries
        .where((e) => !e.value)
        .map((e) => e.key.toString())
        .toList();
    if (denied.isNotEmpty) {
      debugPrint('Permissions denied: $denied');
    }

    if (mounted) setState(() => _statusMessage = 'Starting services...');
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF166534),
              Color(0xFF0A0F0A),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A0F),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_android,
                  size: 60,
                  color: Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Bridger',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                Platform.isAndroid ? 'Android Bridge' : 'iPhone Controller',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
              ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
