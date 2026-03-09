import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/onboarding/splash_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/pairing/pairing_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/connection_settings_screen.dart';
import 'presentation/screens/settings/security_settings_screen.dart';

class BridgePhoneApp extends StatelessWidget {
  const BridgePhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Bridger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}

// Router configuration
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/pairing',
      builder: (context, state) => const PairingScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/connection',
      builder: (context, state) => const ConnectionSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/security',
      builder: (context, state) => const SecuritySettingsScreen(),
    ),
  ],
);
