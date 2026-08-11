import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/pocketbase/pocketbase_client.dart';
import 'services/pocketbase/pocketbase_server_manager.dart';
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
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      PocketBaseServerManager.stop();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
