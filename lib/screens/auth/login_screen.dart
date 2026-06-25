import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/auth_login_result.dart';

class _LoginColors {
  static const Color flame = NovaColors.violet;
  static const Color espresso = NovaColors.textPrimary;
  static const Color charcoal = NovaColors.textPrimary;
  static const Color error = NovaColors.danger;

  static const LinearGradient bgGradient = LinearGradient(
    colors: [
      NovaColors.violet,
      NovaColors.violetDeep,
      NovaColors.tealDeep,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _Breakpoint {
  static const double xs = 360;
  static const double sm = 480;
  static const double md = 768;
  static const double lg = 1024;
}

class _ResponsiveLayout {
  _ResponsiveLayout(double screenWidth, double screenHeight) {
    screenWidth = screenWidth.isInfinite ? 400.0 : screenWidth;
    screenHeight = screenHeight.isInfinite ? 800.0 : screenHeight;

    if (screenWidth < _Breakpoint.xs) {
      cardMaxWidth = screenWidth - 32;
    } else if (screenWidth < _Breakpoint.sm) {
      cardMaxWidth = screenWidth - 48;
    } else if (screenWidth < _Breakpoint.md) {
      cardMaxWidth = 420;
    } else if (screenWidth < _Breakpoint.lg) {
      cardMaxWidth = 460;
    } else {
      cardMaxWidth = 480;
    }

    horizontalPadding = screenWidth < _Breakpoint.xs ? 12.0 : 24.0;
    verticalPadding = screenHeight < 600 ? 20.0 : 40.0;

    cardMaxWidth = cardMaxWidth.clamp(0, screenWidth - horizontalPadding * 2);

    if (screenWidth < _Breakpoint.xs || screenHeight < 600) {
      logoSize = 72.0;
      logoIconSize = 52.0;
    } else if (screenWidth < _Breakpoint.sm) {
      logoSize = 90.0;
      logoIconSize = 62.0;
    } else {
      logoSize = 118.0;
      logoIconSize = 74.0;
    }

    if (screenWidth < _Breakpoint.xs || screenHeight < 600) {
      titleFontSize = 36.0;
    } else if (screenWidth < _Breakpoint.sm) {
      titleFontSize = 46.0;
    } else {
      titleFontSize = 58.0;
    }

    final bool isCompact = screenHeight < 680;
    spacingAfterLogo = isCompact ? 6.0 : 12.0;
    spacingAfterTitle = isCompact ? 6.0 : 10.0;
    spacingBeforeCard = isCompact ? 20.0 : 36.0;
    spacingAfterCard = isCompact ? 20.0 : 36.0;

    cardPadding = screenWidth < _Breakpoint.xs
        ? const EdgeInsets.fromLTRB(14, 22, 14, 20)
        : const EdgeInsets.fromLTRB(24, 28, 24, 24);

    allowScroll = true;
  }

  late double cardMaxWidth;
  late double horizontalPadding;
  late double verticalPadding;
  late double logoSize;
  late double logoIconSize;
  late double titleFontSize;
  late double spacingAfterLogo;
  late double spacingAfterTitle;
  late double spacingBeforeCard;
  late double spacingAfterCard;
  late EdgeInsets cardPadding;
  late bool allowScroll;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finishSuccessfulLogin(AuthProvider auth) async {
    for (var attempt = 0; attempt < 10 && !auth.isRoleLoaded; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (!auth.isRoleLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account role is still loading.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login did not complete. Please retry.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (auth.role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Role not configured. Please contact admin.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);
    _navigateForRole(auth.role);
  }

  void _navigateForRole(String role) {
    final route = switch (role) {
      'admin' => '/admin',
      'cashier' => '/pos',
      _ => '/pos',
    };

    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  Future<void> _handleEmailLogin() async {
    if (_isLoading) return;

    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final AuthLoginResult? result = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (result == null) {
      await _finishSuccessfulLogin(auth);
    } else {
      setState(() {
        _emailError = result.emailError;
        _passwordError = result.passwordError;
        _isLoading = false;
      });
    }
  }

  Widget _buildEmailField() {
    final bool hasError = _emailError != null;
    final bool isEmptyError = _emailError == 'Please fill out required field!';
    return TextField(
      controller: _emailController,
      autofocus: false,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      cursorColor: _LoginColors.flame,
      style: const TextStyle(
        fontSize: 15,
        color: _LoginColors.charcoal,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        hint: 'Email address',
        icon: Icons.email_outlined,
        hasError: hasError,
        isEmptyError: isEmptyError,
        errorText: isEmptyError ? null : _emailError,
        suffixIcon: null,
      ),
    );
  }

  Widget _buildPasswordField() {
    final bool hasError = _passwordError != null;
    final bool isEmptyError =
        _passwordError == 'Please fill out required field!';
    return TextField(
      controller: _passwordController,
      autofocus: false,
      obscureText: _obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _isLoading ? null : _handleEmailLogin(),
      cursorColor: _LoginColors.flame,
      style: const TextStyle(
        fontSize: 15,
        color: _LoginColors.charcoal,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        hint: 'Password',
        icon: Icons.lock_outline_rounded,
        hasError: hasError,
        isEmptyError: isEmptyError,
        errorText: isEmptyError ? null : _passwordError,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _LoginColors.charcoal.withOpacity(0.4),
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    required bool hasError,
    required bool isEmptyError,
    required String? errorText,
    required Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.78),
      hintText: isEmptyError ? 'Please fill out required field!' : hint,
      hintStyle: TextStyle(
        color: isEmptyError
            ? _LoginColors.error
            : _LoginColors.charcoal.withOpacity(0.45),
        fontSize: 14,
        fontWeight: isEmptyError ? FontWeight.w700 : FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: hasError
            ? _LoginColors.error
            : _LoginColors.charcoal.withOpacity(0.55),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorText: errorText,
      errorStyle: const TextStyle(
        color: _LoginColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: hasError ? _LoginColors.error : Colors.transparent,
          width: hasError ? 1.5 : 0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: hasError
              ? _LoginColors.error
              : _LoginColors.flame.withOpacity(0.6),
          width: 2.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _LoginColors.espresso,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _ResponsiveLayout(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: constraints.maxHeight.isInfinite
                      ? 0
                      : constraints.maxHeight),
              child: IntrinsicHeight(
                child: Container(
                  decoration:
                      const BoxDecoration(gradient: _LoginColors.bgGradient),
                  child: CustomPaint(
                    painter: _MobileShopPatternPainter(),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.horizontalPadding,
                          vertical: layout.verticalPadding,
                        ),
                        child: _buildPageLayout(
                            layout,
                            constraints.maxWidth.isInfinite
                                ? 400.0
                                : constraints.maxWidth),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageLayout(_ResponsiveLayout layout, double screenWidth) {
    final bool isWide = screenWidth >= _Breakpoint.lg;

    if (!isWide) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.cardMaxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBrandStack(layout),
            SizedBox(height: layout.spacingBeforeCard),
            _buildLoginCard(layout),
            SizedBox(height: layout.spacingAfterCard),
            _buildFooter(),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: _buildWideBrandPanel(layout),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: 1,
                height: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.35),
                        Colors.white.withOpacity(0.35),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: layout.cardMaxWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLoginCard(layout),
                      SizedBox(height: layout.spacingAfterCard),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideBrandPanel(_ResponsiveLayout layout) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BrandMark(
          outerSize: layout.logoSize,
          iconSize: layout.logoIconSize,
        ),
        const SizedBox(height: 24),
        Text(
          'ORION',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: layout.titleFontSize + 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            height: 0.9,
            shadows: const [
              Shadow(
                color: Color(0x55000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildDividerRow('POS', shrinkWrap: true),
        const SizedBox(height: 28),
        Text(
          'Built for mobile shop teams\n— manage sales, repairs, stock,\nand daily cash with confidence.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.65,
          ),
        ),
      ],
    );
  }

  Widget _buildBrandStack(_ResponsiveLayout layout) {
    return Column(
      children: [
        _BrandMark(
          outerSize: layout.logoSize,
          iconSize: layout.logoIconSize,
        ),
        SizedBox(height: layout.spacingAfterLogo),
        Text(
          'ORION',
          style: TextStyle(
            color: Colors.white,
            fontSize: layout.titleFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            height: 0.95,
            shadows: const [
              Shadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        SizedBox(height: layout.spacingAfterTitle),
        Transform.translate(
          offset: Offset(0, layout.spacingBeforeCard * 0.55),
          child: Center(
            child: _buildDividerRow('POS', shrinkWrap: true),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(_ResponsiveLayout layout) {
    return Container(
      width: double.infinity,
      padding: layout.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _LoginColors.espresso.withOpacity(0.20),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.18),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back — enter your credentials to continue.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          _buildEmailField(),
          const SizedBox(height: 12),
          _buildPasswordField(),
          const SizedBox(height: 20),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _LoginColors.flame,
          foregroundColor: Colors.white,
          shadowColor: _LoginColors.flame.withOpacity(0.35),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'LOGIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
      ),
    );
  }

  Widget _buildDividerRow(String text, {bool shrinkWrap = false}) {
    return Row(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
            width: 42, child: Divider(color: Colors.white54, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(
            width: 42, child: Divider(color: Colors.white54, thickness: 1.5)),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 72,
                child: Divider(
                    color: Colors.white.withOpacity(0.35), thickness: 1)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.phone_android_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
            SizedBox(
                width: 72,
                child: Divider(
                    color: Colors.white.withOpacity(0.35), thickness: 1)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Software By Orion Solutions',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.outerSize = 118, this.iconSize = 74});

  final double outerSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final double innerSize = outerSize * 0.815;
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: innerSize + 16,
            height: innerSize + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _LoginColors.flame.withOpacity(0.05),
            ),
          ),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _LoginColors.flame.withOpacity(0.12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: innerSize * 0.08,
            left: innerSize * 0.22,
            child: Container(
              width: innerSize * 0.35,
              height: innerSize * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),
          Icon(
            Icons.phone_android_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        ],
      ),
    );
  }
}

class _MobileShopPatternPainter extends CustomPainter {
  const _MobileShopPatternPainter();

  static const List<_PatternIcon> _icons = [
    _PatternIcon(Icons.smartphone_outlined, Offset(0.07, 0.08), 58, -0.34),
    _PatternIcon(Icons.headphones_outlined, Offset(0.68, 0.06), 46, 0.26),
    _PatternIcon(Icons.tablet_android_outlined, Offset(0.88, 0.14), 58, 0.35),
    _PatternIcon(Icons.sim_card_outlined, Offset(0.26, 0.18), 42, -0.22),
    _PatternIcon(Icons.cable_outlined, Offset(0.08, 0.29), 44, 0.18),
    _PatternIcon(
        Icons.battery_charging_full_outlined, Offset(0.87, 0.31), 46, -0.10),
    _PatternIcon(Icons.point_of_sale_outlined, Offset(0.13, 0.45), 58, -0.42),
    _PatternIcon(Icons.qr_code_scanner_rounded, Offset(0.73, 0.42), 44, 0.16),
    _PatternIcon(Icons.phone_android_outlined, Offset(0.84, 0.60), 62, 0.34),
    _PatternIcon(Icons.mobile_friendly_outlined, Offset(0.57, 0.66), 50, -0.22),
    _PatternIcon(Icons.headset_mic_outlined, Offset(0.19, 0.72), 42, 0.16),
    _PatternIcon(Icons.smartphone_outlined, Offset(0.07, 0.91), 56, -0.38),
    _PatternIcon(Icons.cable_outlined, Offset(0.73, 0.89), 42, 0.12),
    _PatternIcon(Icons.sim_card_outlined, Offset(0.89, 0.80), 44, 0.28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0x18FFFFFF);
    for (final icon in _icons) {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.icon.codePoint),
          style: TextStyle(
            color: color,
            fontSize: icon.size,
            fontFamily: icon.icon.fontFamily,
            package: icon.icon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final position = Offset(
        size.width * icon.position.dx,
        size.height * icon.position.dy,
      );

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(icon.rotation);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatternIcon {
  const _PatternIcon(this.icon, this.position, this.size, this.rotation);
  final IconData icon;
  final Offset position;
  final double size;
  final double rotation;
}
