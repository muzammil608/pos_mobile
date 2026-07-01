import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/cafe_colors.dart';
import '../core/utils/clickable_cursor.dart';
import '../providers/auth_provider.dart';
import '../services/pocketbase/order_service.dart';

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.photoUrl,
    required this.userName,
    this.radius = 20,
    this.fontSize = 16,
  });

  final String? photoUrl;
  final String userName;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    String? resolvedUrl;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      resolvedUrl = photoUrl!.contains('googleusercontent.com')
          ? '${photoUrl!.split('=').first}=s400'
          : photoUrl;
    }

    if (resolvedUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: CafeColors.flame,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolvedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => _InitialAvatar(
              userName: userName,
              radius: radius,
              fontSize: fontSize,
            ),
            errorWidget: (context, url, error) => _InitialAvatar(
              userName: userName,
              radius: radius,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    return _InitialAvatar(
      userName: userName,
      radius: radius,
      fontSize: fontSize,
    );
  }
}

class AppDrawerAvatarButton extends StatelessWidget {
  const AppDrawerAvatarButton({
    super.key,
    required this.photoUrl,
    required this.userName,
  });

  final String? photoUrl;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: ClickableCursor(
          child: GestureDetector(
            onTap: () => Scaffold.of(builderContext).openDrawer(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AppUserAvatar(
                photoUrl: photoUrl,
                userName: userName,
                radius: 18,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.auth,
    required this.currentRoute,
    this.compact = false,
  });

  final AuthProvider auth;
  final String currentRoute;
  final bool compact;

  Color _roleBgColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return CafeColors.creme;
      default:
        return CafeColors.creme;
    }
  }

  Color _roleTextColor(String role) {
    switch (role.toLowerCase()) {
      default:
        return CafeColors.flame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final userEmail = user?.email ?? 'No Email';
    final userName = user?.name ??
        (userEmail.contains('@') ? userEmail.split('@').first : userEmail);
    final photoUrl = user?.photoUrl;

    final navItems = [
      if (auth.isAdmin || auth.isCashier)
        _DrawerItem(
          icon: Icons.point_of_sale_rounded,
          title: 'Order Station',
          route: '/pos',
          currentRoute: currentRoute,
          compact: compact,
        ),
      if (auth.isAdmin || auth.isCashier)
        _DrawerItem(
          icon: Icons.build_circle_rounded,
          title: 'Repair Desk',
          route: '/repairs',
          currentRoute: currentRoute,
          compact: compact,
        ),
      if (auth.isAdmin)
        _DrawerItem(
          icon: Icons.dashboard_customize_rounded,
          title: 'Admin Dashboard',
          route: '/admin',
          currentRoute: currentRoute,
          compact: compact,
        ),
      if (auth.isAdmin)
        _DrawerItem(
          icon: Icons.warehouse_rounded,
          title: 'Inventory',
          route: '/inventory',
          currentRoute: currentRoute,
          compact: compact,
        ),
      if (auth.isAdmin)
        _DrawerItem(
          icon: Icons.badge_rounded,
          title: 'Employee Manager',
          route: '/employees',
          currentRoute: currentRoute,
          compact: compact,
        ),
    ];

    return Drawer(
      width: compact ? 76 : 300,
      backgroundColor: Colors.transparent,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: CafeColors.headerGradient,
              ),
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 20,
                52,
                compact ? 10 : 20,
                compact ? 16 : 24,
              ),
              child: compact
                  ? Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.point_of_sale_rounded,
                                  color: CafeColors.flame,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.point_of_sale_rounded,
                                    color: CafeColors.flame,
                                    size: 30,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ShopFlow POS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'POS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: compact ? 8 : 12,
                  ),
                  children: navItems,
                ),
              ),
            ),
            if (!compact)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          AppUserAvatar(
                            photoUrl: photoUrl,
                            userName: userName,
                            radius: 24,
                            fontSize: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: CafeColors.espresso,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CafeColors.espresso.withOpacity(0.6),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _roleBgColor(auth.role),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              auth.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _roleTextColor(auth.role),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B3B), Color(0xFFFF6B6B)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await Provider.of<AuthProvider>(context,
                                    listen: false)
                                .logout();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.logout_rounded,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppNavigationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AppNavigationAppBar({
    super.key,
    required this.title,
    required this.icon,
    required this.photoUrl,
    required this.userName,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.height = 64,
  });

  final String title;
  final IconData icon;
  final String? photoUrl;
  final String userName;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: const BoxDecoration(
          gradient: CafeColors.headerGradient,
          boxShadow: [
            BoxShadow(
              color: Color(0x33534AB7),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: leading,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: subtitle == null
                      ? Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              subtitle!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            actions: [
              ExcludeFocus(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...actions,
                    if (!AppNavigationShell.isDesktop(context))
                      IconButton(
                        tooltip: 'Logout',
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white70),
                        onPressed: () async {
                          final isMobile =
                              MediaQuery.sizeOf(context).width < 600;
                          bool confirm = true;
                          if (!isMobile) {
                            confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Logout'),
                                    content: const Text(
                                        'Are you sure you want to logout?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, true),
                                        style: TextButton.styleFrom(
                                            foregroundColor: Colors.red),
                                        child: const Text('Logout'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          }
                          if (confirm && context.mounted) {
                            await Provider.of<AuthProvider>(context,
                                    listen: false)
                                .logout();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login', (route) => false);
                            }
                          }
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppDrawerAvatarButton(
                        photoUrl: photoUrl,
                        userName: userName,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.auth,
    required this.currentRoute,
    required this.child,
  });

  final AuthProvider auth;
  final String currentRoute;
  final Widget child;

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  bool _hovered = false;
  bool _navigatingToPos = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyboard);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboard);
    super.dispose();
  }

  bool _handleKeyboard(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    if (event.logicalKey == LogicalKeyboardKey.f10) {
      _goToOrderStation();
      return true;
    }

    return false;
  }

  Future<void> _goToOrderStation() async {
    if (_navigatingToPos || widget.currentRoute == '/pos') return;
    _navigatingToPos = true;

    final navigator = Navigator.of(context);
    await navigator.pushNamedAndRemoveUntil('/pos', (route) => false);

    _navigatingToPos = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!AppNavigationShell.isDesktop(context)) return widget.child;

    return Row(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: SizedBox(
            width: _hovered ? 300 : 76,
            child: ExcludeFocus(
              child: AppNavigationDrawer(
                auth: widget.auth,
                currentRoute: widget.currentRoute,
                compact: !_hovered,
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _DrawerItem extends StatefulWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.currentRoute,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String route;
  final String currentRoute;
  final bool compact;

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _isNavigating = false;

  Future<void> _handleTap(BuildContext context) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    final selected = widget.route == widget.currentRoute;
    final navigator = Navigator.of(context);
    final scaffoldState = Scaffold.maybeOf(context);
    final drawerIsOpen = scaffoldState?.isDrawerOpen ?? false;

    if (drawerIsOpen) {
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    if (!mounted) return;
    if (!selected) {
      await navigator.pushReplacementNamed(widget.route);
    }

    if (!mounted) return;
    setState(() => _isNavigating = false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.route == widget.currentRoute;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = widget.compact || constraints.maxWidth < 150;

        if (compact) {
          return Tooltip(
            message: widget.title,
            child: _NavIconTile(
              icon: widget.icon,
              selected: selected,
              isNavigating: _isNavigating,
              onTap: () => _handleTap(context),
            ),
          );
        }

        return _NavExpandedTile(
          icon: widget.icon,
          title: widget.title,
          selected: selected,
          isNavigating: _isNavigating,
          onTap: () => _handleTap(context),
        );
      },
    );
  }
}

class _NavIconTile extends StatelessWidget {
  const _NavIconTile({
    required this.icon,
    required this.selected,
    required this.isNavigating,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final bool isNavigating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compactTile = Container(
      width: double.infinity,
      height: 52,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: selected ? CafeColors.headerGradient : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          mouseCursor: isNavigating
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onTap: isNavigating ? null : onTap,
          child: Center(
            child: Icon(
              icon,
              color: selected
                  ? Colors.white
                  : CafeColors.charcoal.withOpacity(0.68),
              size: 22,
            ),
          ),
        ),
      ),
    );

    return compactTile;
  }
}

class _NavExpandedTile extends StatelessWidget {
  const _NavExpandedTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.isNavigating,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final bool isNavigating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: selected ? CafeColors.headerGradient : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          mouseCursor: isNavigating
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onTap: isNavigating ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : CafeColors.charcoal.withOpacity(0.68),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : CafeColors.charcoal.withOpacity(0.78),
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tile;
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.userName,
    required this.radius,
    required this.fontSize,
  });

  final String userName;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: CafeColors.headerGradient,
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class AppMobileBottomNavBar extends StatelessWidget {
  static bool autoShowReadyOrders = false;

  final int currentIndex;
  final VoidCallback? onPosTap;

  const AppMobileBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onPosTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderService = OrderService(auth.ownerId);

    return StreamBuilder<OrderRecordSnapshot>(
      stream: orderService.getOrders(),
      builder: (context, snapshot) {
        int readyCount = 0;
        if (snapshot.hasData) {
          readyCount = snapshot.data!.docs
              .where((doc) => doc.data()['status'] == 'ready')
              .length;
        }

        return BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF534AB7),
          unselectedItemColor: const Color(0xFF9999AE),
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_rounded),
              label: 'POS',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_customize_rounded),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.receipt_long_outlined),
                  if (readyCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$readyCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_rounded),
              label: 'Inventory',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.build_circle_rounded),
              label: 'Repairs',
            ),
          ],
          onTap: (index) {
            if (index == currentIndex) {
              if (index == 0 && onPosTap != null) {
                onPosTap!();
              }
              return;
            }

            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/pos');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/admin');
                break;
              case 2:
                autoShowReadyOrders = true;
                Navigator.pushReplacementNamed(context, '/pos');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/inventory');
                break;
              case 4:
                Navigator.pushReplacementNamed(context, '/repairs');
                break;
            }
          },
        );
      },
    );
  }
}
