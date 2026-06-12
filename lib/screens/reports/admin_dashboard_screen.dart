import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pocketbase/report_service.dart';
import '../../../widgets/status_donut_chart.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final ReportService _reportService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _reportService = ReportService(auth.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user == null) {
          return const Scaffold(
            backgroundColor: NovaColors.bgSecondary,
            body: Center(
              child: CircularProgressIndicator(color: NovaColors.violet),
            ),
          );
        }

        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            backgroundColor: NovaColors.bgSecondary,
            body: Center(
              child: CircularProgressIndicator(color: NovaColors.violet),
            ),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.displayName ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoURL;
        final isDesktop = AppNavigationShell.isDesktop(context);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: null,
          bottomNavigationBar:
              !isDesktop ? const AppMobileBottomNavBar(currentIndex: 1) : null,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
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
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Row(
                    children: [
                      Icon(Icons.dashboard_customize_rounded,
                          color: Colors.white70, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Admin Dashboard',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    if (!isDesktop)
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
                                '/login',
                                (route) => false,
                              );
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
            ),
          ),
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/admin',
            child: ResponsiveCenter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
                child: _DashboardContent(
                  auth: auth,
                  reportService: _reportService,
                  isDesktop: isDesktop,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final AuthProvider auth;
  final ReportService reportService;
  final bool isDesktop;

  const _DashboardContent({
    required this.auth,
    required this.reportService,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<double>(
          stream: reportService.getTodayRevenue(),
          builder: (context, snapshot) {
            final revenue = snapshot.data ?? 0.0;
            final revenueLoading = !snapshot.hasData;

            return StreamBuilder<int>(
              stream: reportService.getTodayOrderCount(),
              builder: (context, ordersSnapshot) {
                final ordersToday = ordersSnapshot.data ?? 0;
                final ordersLoading = !ordersSnapshot.hasData;

                return StreamBuilder<Map<String, int>>(
                  stream: reportService.getTodayOrderFlowStats(),
                  builder: (context, flowSnapshot) {
                    final flowStats = flowSnapshot.data ??
                        const {
                          'total': 0,
                          'pending': 0,
                          'ready': 0,
                          'completed': 0,
                        };
                    final flowLoading = !flowSnapshot.hasData;
                    final totalOrders = flowStats['total'] ?? 0;
                    final completedOrders = flowStats['completed'] ?? 0;
                    final satisfaction = totalOrders == 0
                        ? 0.0
                        : (completedOrders / totalOrders) * 100;
                    final satisfactionDelta = totalOrders == 0
                        ? 'No orders yet today'
                        : '$completedOrders of $totalOrders completed';

                    final cards = [
                      _StatCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: NovaColors.violet,
                        label: "Today's Revenue",
                        value: revenueLoading
                            ? '—'
                            : 'Rs ${revenue.toStringAsFixed(0)}',
                        delta: 'Live total',
                        deltaUp: true,
                        isLoading: revenueLoading,
                        fullWidth: !isDesktop,
                      ),
                      _StatCard(
                        icon: Icons.receipt_long_rounded,
                        iconColor: NovaColors.teal,
                        label: 'Orders Today',
                        value: ordersLoading ? '—' : '$ordersToday',
                        delta: 'Updated live',
                        deltaUp: true,
                        isLoading: ordersLoading,
                        fullWidth: !isDesktop,
                      ),
                      _StatCard(
                        icon: Icons.star_rounded,
                        iconColor: NovaColors.rose,
                        label: 'Satisfaction',
                        value: flowLoading
                            ? '—'
                            : '${satisfaction.toStringAsFixed(1)}%',
                        delta: satisfactionDelta,
                        deltaUp: totalOrders > 0 ? satisfaction >= 70 : null,
                        isLoading: flowLoading,
                        fullWidth: !isDesktop,
                      ),
                    ];

                    if (isDesktop) {
                      return Row(
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      );
                    }

                    return Column(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          cards[i],
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
        SizedBox(height: isDesktop ? 16 : 16),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Order Status',
                    ),
                    const SizedBox(height: 12),
                    _OrderStatusCards(reportService: reportService),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      icon: Icons.flash_on_rounded,
                      title: 'Quick Actions',
                    ),
                    const SizedBox(height: 12),
                    _QuickActionsRow(isDesktop: true),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Order Breakdown',
                    ),
                    const SizedBox(height: 12),
                    _OrderBreakdownCard(auth: auth, isDesktop: true),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Order Status',
          ),
          const SizedBox(height: 12),
          _OrderStatusCards(reportService: reportService),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Order Breakdown',
          ),
          const SizedBox(height: 12),
          _OrderBreakdownCard(auth: auth, isDesktop: false),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.flash_on_rounded,
            title: 'Quick Actions',
          ),
          const SizedBox(height: 12),
          _QuickActionsRow(isDesktop: false),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String delta;
  final bool? deltaUp;
  final bool isLoading;
  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.delta,
    this.deltaUp,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Color deltaColor = NovaColors.textTertiary;
    if (deltaUp == true) deltaColor = NovaColors.teal;
    if (deltaUp == false) deltaColor = NovaColors.danger;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth > 0 && constraints.maxWidth < 190;

        return Container(
          width: fullWidth ? double.infinity : null,
          constraints: const BoxConstraints(minHeight: 118),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: NovaColors.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: NovaColors.violet,
                        strokeWidth: 2,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: compact ? 20 : 22,
                          fontWeight: FontWeight.w500,
                          color: NovaColors.textPrimary,
                        ),
                      ),
                    ),
              const SizedBox(height: 6),
              Text(
                delta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: compact ? 11 : 12, color: deltaColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderStatusCards extends StatelessWidget {
  final ReportService reportService;

  const _OrderStatusCards({required this.reportService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: reportService.getOrderStatusStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: NovaColors.violet),
            ),
          );
        }
        final stats = snapshot.data!;
        final cards = [
          _StatusCardData(
            key: 'pending',
            value: stats['pending'] ?? 0,
            label: 'Pending',
            icon: Icons.hourglass_top_rounded,
            color: NovaColors.danger,
            bgColor: NovaColors.dangerLight,
          ),
          _StatusCardData(
            key: 'ready',
            value: stats['ready'] ?? 0,
            label: 'Ready',
            icon: Icons.check_circle_outline_rounded,
            color: NovaColors.teal,
            bgColor: NovaColors.tealLight,
          ),
          _StatusCardData(
            key: 'completed',
            value: stats['completed'] ?? 0,
            label: 'Done',
            icon: Icons.task_alt_rounded,
            color: NovaColors.textSecondary,
            bgColor: NovaColors.bgSecondary,
          ),
        ];
        return Row(
          children: cards
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: c.key == 'pending' ? 0 : 6,
                      right: c.key == 'completed' ? 0 : 6,
                    ),
                    child: _StatusCard(data: c),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OrderBreakdownCard extends StatelessWidget {
  final AuthProvider auth;
  final bool isDesktop;

  const _OrderBreakdownCard({required this.auth, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return StatusDonutChart(
      ownerId: auth.ownerId,
      cardHeight: isDesktop ? 224 : null,
      chartSize: isDesktop ? 116 : 160,
      showSegmentBar: !isDesktop,
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool isDesktop;

  const _QuickActionsRow({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.point_of_sale_rounded,
            label: 'POS',
            subtitle: 'Order Station',
            color: NovaColors.violet,
            bgColor: NovaColors.violetLight,
            onTap: () => Navigator.pushNamed(context, '/pos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.warehouse_rounded,
            label: 'Inventory',
            subtitle: 'Reports & Stock',
            color: NovaColors.teal,
            bgColor: NovaColors.tealLight,
            onTap: () => Navigator.pushNamed(context, '/inventory'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.badge_rounded,
            label: 'Employees',
            subtitle: 'Manage Staff',
            color: NovaColors.rose,
            bgColor: NovaColors.roseLight,
            onTap: () => Navigator.pushNamed(context, '/employees'),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: NovaColors.violet),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: NovaColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusCardData {
  final String key;
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatusCardData({
    required this.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class _StatusCard extends StatelessWidget {
  final _StatusCardData data;

  const _StatusCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.value}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: data.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11,
              color: NovaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: NovaColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: NovaColors.textTertiary,
                    ),
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
