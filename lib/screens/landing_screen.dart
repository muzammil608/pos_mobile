import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  void _redirect() {
    if (_navigated) return;
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isLoading || !auth.isRoleLoaded) return;

    if (auth.user != null && auth.userData != null) {
      _navigated = true;
      final role = auth.role;
      if (role.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Role not configured. Please contact admin.')),
        );
        return;
      }
      switch (role) {
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        case 'cashier':
          Navigator.pushReplacementNamed(context, '/pos');
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unknown role: $role. Defaulting to POS.')),
          );
          Navigator.pushReplacementNamed(context, '/pos');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.user != null && auth.userData != null && !_navigated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
    }

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.user == null) {
      return const LoginScreen();
    }

    if (auth.userData == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Auth data loaded, but role data is missing.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
