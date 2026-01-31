import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/onboarding/splash_screen.dart';
import 'presentation/screens/home/home_screen.dart';

class BridgePhoneApp extends StatelessWidget {
  const BridgePhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Bridge Phone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
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
    // Additional routes will be added in later phases
    // GoRoute(
    //   path: '/onboarding',
    //   builder: (context, state) => const OnboardingScreen(),
    // ),
    // GoRoute(
    //   path: '/pairing',
    //   builder: (context, state) => const PairingScreen(),
    // ),
    // GoRoute(
    //   path: '/sms',
    //   builder: (context, state) => const SMSInboxScreen(),
    // ),
    // GoRoute(
    //   path: '/calls',
    //   builder: (context, state) => const CallsScreen(),
    // ),
    // GoRoute(
    //   path: '/notifications',
    //   builder: (context, state) => const NotificationsScreen(),
    // ),
    // GoRoute(
    //   path: '/settings',
    //   builder: (context, state) => const SettingsScreen(),
    // ),
  ],
);
