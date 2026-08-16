import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/pocketbase/pocketbase_client.dart';
import 'services/pocketbase/pocketbase_server_manager.dart';
import 'services/update_service.dart';
import 'package:pos_system/core/keyboard/pos_keyboard_system.dart';

import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';

import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/landing_screen.dart';

import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (error, stack) {
    final errStr = error.toString();
    if (errStr.contains('SSE connection') ||
        errStr.contains('Cannot add new events after calling close') ||
        errStr.contains('client id') ||
        errStr.contains('ClientException') ||
        errStr.contains('RealtimeService') ||
        errStr.contains('scope != null')) {
      debugPrint(
          'Suppressing background/transition error or assertion: $error');
      return true;
    }
    return false;
  };

  // Automatically start local PocketBase process on desktop platforms if not already running
  await PocketBaseServerManager.startIfNeeded();

  await PocketBaseClient.init();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }

  runApp(const MyApp());

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    unawaited(PosHotkeyRegistry.init());
  }

  // FIX: nothing previously read back whether the last background update
  // attempt failed -- update_runner.ps1 wrote a ".failed" marker + error log
  // on failure, but the app never checked for it, so a failed silent update
  // was invisible to the user. Runs after the first frame so it can safely
  // show UI via AutoUpdateManager.navigatorKey.
  if (!kIsWeb && Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await UpdateService.checkForPreviousUpdateFailure();
      if (result.failed) {
        final context = AutoUpdateManager.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              ),
              duration: const Duration(seconds: 6),
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last update attempt failed',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.message ??
                              'The last background update did not complete.',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    });
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      AutoUpdateManager.instance.stopPolling();
      PocketBaseServerManager.stop();
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Start background update polling (initial check after short startup delay, then every 5 minutes)
    if (!kIsWeb && Platform.isWindows) {
      AutoUpdateManager.instance.startPolling();
    }
  }

  @override
  void dispose() {
    AutoUpdateManager.instance.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
          create: (_) => ProductProvider(""),
          update: (_, auth, previous) {
            if (previous == null || previous.ownerId != auth.ownerId) {
              return ProductProvider(auth.ownerId);
            }
            return previous;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: AutoUpdateManager.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppEntry(),
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isRoleLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (auth.user == null) {
      return const LoginScreen();
    }

    return const LandingScreen();
  }
}
