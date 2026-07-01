import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/cafe_colors.dart';
import '../../core/theme/receipt_fonts.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/app_notice.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/pay_later_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/no_animation_route.dart';
import '../../screens/pay_later/pay_later_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../services/pay_later_service.dart';
import '../../services/pocketbase/inventory_service.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/report_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/receipt_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  InventoryService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _service ??= InventoryService(auth.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) return const _LoadingScaffold();

        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const _LoadingScaffold();
        }

        final userEmail = auth.user?.email ?? '';
        final userName = auth.user?.name ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoUrl;

        final isDesktop = AppNavigationShell.isDesktop(context);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          drawer: null,
          bottomNavigationBar:
              !isDesktop ? const AppMobileBottomNavBar(currentIndex: 3) : null,
          appBar: AppNavigationAppBar(
            title: 'Inventory Dashboard',
            icon: Icons.warehouse_rounded,
            photoUrl: photoUrl,
            userName: userName,
            actions: [
              if (_service != null) _StockAlertBadge(service: _service!),
              IconButton(
                tooltip: 'Refresh',
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
          body: AppNoticeHost(
            child: AppNavigationShell(
              auth: auth,
              currentRoute: '/inventory',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: _InventoryBody(service: _service!),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockAlertBadge extends StatefulWidget {
  const _StockAlertBadge({required this.service});

  final InventoryService service;

  @override
  State<_StockAlertBadge> createState() => _StockAlertBadgeState();
}

class _StockAlertBadgeState extends State<_StockAlertBadge> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;
  List<Product> _latestAlerts = const <Product>[];
  bool _overlaySyncQueued = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_latestAlerts.isEmpty) return;
    _hideTimer?.cancel();

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      _showMobileBottomSheet();
      return;
    }

    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final size = MediaQuery.sizeOf(overlayContext);
        final menuWidth = (size.width - 24).clamp(280.0, 360.0).toDouble();
        final outCount = _latestAlerts.where((p) => p.stockQty <= 0).length;
        final lowCount = _latestAlerts.length - outCount;
        final urgentColor = outCount > 0 ? NovaColors.danger : NovaColors.amber;

        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                onTap: _removeOverlay,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: UnconstrainedBox(
                  alignment: Alignment.topRight,
                  child: MouseRegion(
                    onEnter: (_) => _hideTimer?.cancel(),
                    onExit: (_) => _scheduleHideOverlay(),
                    child: SafeArea(
                      minimum: const EdgeInsets.symmetric(horizontal: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: _StockAlertDropdown(
                          width: menuWidth,
                          alerts: _latestAlerts,
                          outCount: outCount,
                          lowCount: lowCount,
                          urgentColor: urgentColor,
                          onManage: () {
                            _removeOverlay();
                            if (!mounted) return;
                            Navigator.of(context).push(
                              NoAnimationPageRoute(
                                builder: (_) =>
                                    const ProductsScreen(inventoryMode: true),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showMobileBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final outCount = _latestAlerts.where((p) => p.stockQty <= 0).length;
        final lowCount = _latestAlerts.length - outCount;
        final urgentColor = outCount > 0 ? NovaColors.danger : NovaColors.amber;

        return GestureDetector(
          onTap: () => Navigator.pop(sheetContext),
          behavior: HitTestBehavior.translucent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: const BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: NovaColors.borderSecondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active_rounded,
                                  color: urgentColor, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Stock Notifications',
                                  style: TextStyle(
                                    color: NovaColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$outCount out | $lowCount low',
                                  style: TextStyle(
                                    color: urgentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                            height: 1, color: NovaColors.borderTertiary),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(sheetContext).size.height * 0.5,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: _latestAlerts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final product = _latestAlerts[index];
                              return _StockAlertProductTile(product: product);
                            },
                          ),
                        ),
                        const Divider(
                            height: 1, color: NovaColors.borderTertiary),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                Navigator.of(context).push(
                                  NoAnimationPageRoute(
                                    builder: (_) => const ProductsScreen(
                                        inventoryMode: true),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NovaColors.violet,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.inventory_2_rounded,
                                  size: 18),
                              label: const Text(
                                'Manage Products',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleHideOverlay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 180), _removeOverlay);
  }

  void _removeOverlay() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _syncOverlayAfterBuild(bool hasAlerts) {
    if (_overlaySyncQueued) return;
    _overlaySyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncQueued = false;
      if (!mounted) return;
      if (!hasAlerts) {
        _removeOverlay();
        return;
      }
      _overlayEntry?.markNeedsBuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: widget.service.streamProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Product>[];
        final alerts = products
            .where((p) => p.stockQty <= p.lowStockThreshold)
            .toList()
          ..sort((a, b) => a.stockQty.compareTo(b.stockQty));
        final totalAlerts = alerts.length;
        final outCount = alerts.where((p) => p.stockQty <= 0).length;
        final lowCount = totalAlerts - outCount;
        final hasAlerts = totalAlerts > 0;
        _latestAlerts = alerts;
        _syncOverlayAfterBuild(hasAlerts);

        return CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) => _showOverlay(),
            onExit: (_) => _scheduleHideOverlay(),
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: IconButton(
                tooltip: hasAlerts
                    ? '$outCount out of stock, $lowCount low stock'
                    : 'No stock alerts',
                mouseCursor: hasAlerts
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                onPressed: hasAlerts ? _showOverlay : null,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      hasAlerts
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    if (hasAlerts)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFE11D2E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  child: Text(
                                    totalAlerts > 99 ? '99+' : '$totalAlerts',
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockAlertDropdown extends StatelessWidget {
  const _StockAlertDropdown({
    required this.width,
    required this.alerts,
    required this.outCount,
    required this.lowCount,
    required this.urgentColor,
    required this.onManage,
  });

  final double width;
  final List<Product> alerts;
  final int outCount;
  final int lowCount;
  final Color urgentColor;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    color: urgentColor, size: 19),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Stock Notifications',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$outCount out | $lowCount low',
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: NovaColors.borderTertiary),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final product in alerts)
                    _StockAlertProductTile(product: product),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: NovaColors.borderTertiary),
          InkWell(
            onTap: onManage,
            mouseCursor: SystemMouseCursors.click,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded,
                      size: 18, color: NovaColors.violet),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Manage Products',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NovaColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockAlertProductTile extends StatelessWidget {
  const _StockAlertProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final out = product.stockQty <= 0;
    final color = out ? NovaColors.danger : NovaColors.amber;
    final backgroundColor =
        out ? NovaColors.dangerLight : NovaColors.amberLight;
    final statusText = out ? 'Out of stock' : 'Low stock';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              out ? Icons.block_rounded : Icons.priority_high_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _StockMiniPill(
                      label: statusText,
                      color: color,
                      backgroundColor: backgroundColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${product.category} | Alert ${product.lowStockThreshold}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${product.stockQty}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockMiniPill extends StatelessWidget {
  const _StockMiniPill({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InventoryBody extends StatefulWidget {
  const _InventoryBody({required this.service});
  final InventoryService service;

  @override
  State<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<_InventoryBody> {
  late final OrderService _orderService;
  late Future<
      (
        List<Product>,
        List<InventoryTransaction>,
        List<Map<String, dynamic>>,
        List<PayLaterPerson>
      )> _future;
  StreamSubscription<List<Product>>? _productsSub;
  Timer? _midnightRefreshTimer;
  bool _profitExpanded = false;

  Future<
      (
        List<Product>,
        List<InventoryTransaction>,
        List<Map<String, dynamic>>,
        List<PayLaterPerson>
      )> _loadData() async {
    final (products, transactions, orders, payLaterPeople) = await (
      widget.service.getProducts(),
      widget.service.getTransactions(limit: 120),
      _orderService.getOrdersList(),
      PayLaterService(widget.service.ownerId).getPeople(),
    ).wait;

    return (
      products,
      transactions,
      orders
          .map(
            (order) => <String, dynamic>{
              ...order.toMap(),
              'id': order.id,
              'createdAtDate': order.createdAt,
            },
          )
          .toList(),
      payLaterPeople,
    );
  }

  @override
  void initState() {
    super.initState();
    _orderService = OrderService(widget.service.ownerId);
    _future = _loadData();
    _productsSub = widget.service.streamProducts().listen((_) {
      _refresh();
    });
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _midnightRefreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightRefreshTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        _refresh();
        _scheduleMidnightRefresh();
      },
    );
  }

  void _refresh() {
    if (!mounted) return;
    final next = _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _future = next;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        (
          List<Product>,
          List<InventoryTransaction>,
          List<Map<String, dynamic>>,
          List<PayLaterPerson>
        )>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading inventory:\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: NovaColors.textSecondary, fontSize: 13),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: NovaColors.teal));
        }

        final (products, transactions, orders, payLaterPeople) = snapshot.data!;
        final summary = InventorySummary.fromProducts(products);

        final categorySet = products.map((e) => e.category.trim()).toSet();
        final categories = categorySet.where((e) => e.isNotEmpty).toList()
          ..sort();

        return ListView(
          children: [
            _HeaderRow(
              totalProducts: products.length,
              onRefresh: _refresh,
            ),
            const SizedBox(height: 12),
            _ProfitExpansionPanel(
              products: products,
              transactions: transactions,
              orders: orders,
              payLaterPeople: payLaterPeople,
              expanded: _profitExpanded,
              onToggle: () =>
                  setState(() => _profitExpanded = !_profitExpanded),
            ),
            const SizedBox(height: 12),
            _MetricsGrid(summary: summary, products: products),
            const SizedBox(height: 14),
            _InventoryTablePanel(
              products: products,
              categories: categories,
              service: widget.service,
              onMutated: _refresh,
            ),
          ],
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.totalProducts, required this.onRefresh});
  final int totalProducts;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 760;

      final titleCol = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Overview',
            style: TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Showing $totalProducts products',
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
          ),
        ],
      );

      final actionButtonWidth = isMobile ? double.infinity : 148.0;
      const actionButtonHeight = 40.0;

      Widget buildActionButton({required Widget child}) {
        return SizedBox(
          width: actionButtonWidth,
          height: actionButtonHeight,
          child: child,
        );
      }

      final reportButton = buildActionButton(
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              NoAnimationPageRoute<void>(
                builder: (_) => const _InventoryOrdersReportScreen(),
              ),
            );
          },
          icon: const Icon(Icons.receipt_long_rounded, size: 16),
          label: const Text('Orders Report'),
          style: OutlinedButton.styleFrom(
            foregroundColor: NovaColors.violet,
            side: const BorderSide(color: NovaColors.violet),
            backgroundColor: NovaColors.bgPrimary,
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).copyWith(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
        ),
      );
      final payLaterButton = buildActionButton(
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              NoAnimationPageRoute<void>(
                builder: (_) => const PayLaterScreen(),
              ),
            );
          },
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
          label: const Text('Pay Later'),
          style: OutlinedButton.styleFrom(
            foregroundColor: NovaColors.teal,
            side: const BorderSide(color: NovaColors.teal),
            backgroundColor: NovaColors.bgPrimary,
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).copyWith(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
        ),
      );
      final addProductButton = buildActionButton(
        child: FilledButton.icon(
          onPressed: () {
            Navigator.of(context)
                .push(
                  NoAnimationPageRoute<void>(
                    builder: (_) => const ProductsScreen(
                      inventoryMode: true,
                      openAddOnStart: true,
                    ),
                  ),
                )
                .then((_) => onRefresh());
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Product'),
          style: FilledButton.styleFrom(
            backgroundColor: NovaColors.violet,
            foregroundColor: Colors.white,
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).copyWith(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
        ),
      );
      final actions = isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                reportButton,
                const SizedBox(height: 8),
                payLaterButton,
                const SizedBox(height: 8),
                addProductButton,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                reportButton,
                const SizedBox(width: 8),
                payLaterButton,
                const SizedBox(width: 8),
                addProductButton,
              ],
            );

      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleCol, const SizedBox(height: 10), actions],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [titleCol, actions],
      );
    });
  }
}

class _InventoryOrdersReportScreen extends StatefulWidget {
  const _InventoryOrdersReportScreen();

  @override
  State<_InventoryOrdersReportScreen> createState() =>
      _InventoryOrdersReportScreenState();
}

class _InventoryOrdersReportScreenState
    extends State<_InventoryOrdersReportScreen> {
  ReportService? _reportService;
  String _period = 'weekly';
  String _selectedCashierId = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _reportService ??= ReportService(auth.ownerId);
  }

  String _periodLabel(String value) {
    return switch (value) {
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => 'Weekly',
    };
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  Map<String, String> _cashierNames(
    AuthProvider auth,
    List<Map<String, dynamic>> employees,
  ) {
    final names = <String, String>{};
    final adminEmail = auth.user?.email ?? '';
    final adminName = (auth.user?.name ?? '').trim();
    if (auth.currentUid.isNotEmpty && auth.currentUid != 'guest') {
      names[auth.currentUid] =
          adminName.isNotEmpty ? adminName : adminEmail.split('@').first;
    }

    for (final employee in employees) {
      final id = employee['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final rawName = (employee['name']?.toString() ?? '').trim();
      final email = employee['email']?.toString() ?? '';
      names[id] = rawName.isNotEmpty ? rawName : email.split('@').first;
    }
    return names;
  }

  String _cashierName(Map<String, String> names, Map<String, dynamic> order) {
    final id = order['createdBy']?.toString() ?? '';
    if (id.isEmpty) return 'Unassigned';
    return names[id] ?? 'Unknown Cashier';
  }

  List<Map<String, dynamic>> _filteredOrders(
    List<Map<String, dynamic>> orders,
  ) {
    if (_selectedCashierId == 'all') return orders;
    return orders
        .where((order) =>
            (order['createdBy']?.toString() ?? '') == _selectedCashierId)
        .toList();
  }

  Future<void> _openReceipt(
    BuildContext context,
    Map<String, dynamic> order,
    String cashier,
  ) {
    final orderNumber = (order['orderNumber'] as num?)?.toInt() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final tendered = (order['tenderedAmount'] as num?)?.toDouble() ?? total;
    final change = (order['change'] as num?)?.toDouble() ?? 0.0;
    final createdAt = order['createdAtDate'] as DateTime? ?? DateTime.now();
    final customerName = (order['customerName']?.toString() ?? '').trim();
    final items = List<Map<String, dynamic>>.from(
      (order['items'] as List? ?? const []).map(
        (item) {
          final data = Map<String, dynamic>.from(item as Map);
          final quantity = (data['qty'] as num?)?.toInt() ??
              (data['quantity'] as num?)?.toInt() ??
              1;
          final unitPrice = ((data['unitPrice'] ??
                      data['price'] ??
                      data['retail_rate']) as num?)
                  ?.toDouble() ??
              0.0;
          return <String, dynamic>{
            ...data,
            'name': data['name'] ??
                data['productName'] ??
                data['item_name'] ??
                'Item',
            'qty': quantity,
            'quantity': quantity,
            'price': unitPrice,
            'unitPrice': unitPrice,
            'lineTotal':
                (data['lineTotal'] as num?)?.toDouble() ?? quantity * unitPrice,
          };
        },
      ),
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptDialog(
        companyName: 'ShopFlow POS',
        phone: '+92-317-7921817',
        email: 'info@orion.com',
        website: 'www.orion.com',
        servedBy: cashier,
        customerName: customerName.isEmpty ? 'Walk-in Customer' : customerName,
        items: items,
        total: total,
        cash: tendered,
        change: change,
        tax: 0.0,
        paymentMethod: order['paymentMethod']?.toString() ?? 'cash',
        orderNo: 'ORDER-$orderNumber',
        date: _formatDate(createdAt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) return const _LoadingScaffold();
        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const _LoadingScaffold();
        }

        final userEmail = auth.user?.email ?? '';
        final userName = auth.user?.name ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoUrl;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          appBar: AppNavigationAppBar(
            title: 'Inventory Order Reports',
            icon: Icons.receipt_long_rounded,
            photoUrl: photoUrl,
            userName: userName,
          ),
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/inventory',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: auth.getEmployees(),
                builder: (context, employeeSnapshot) {
                  if (employeeSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading cashiers:\n${employeeSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: NovaColors.textSecondary, fontSize: 13),
                      ),
                    );
                  }

                  final employees = employeeSnapshot.data ?? const [];
                  final cashierNames = _cashierNames(auth, employees);

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _reportService!.getOrdersByPeriod(_period),
                    builder: (context, orderSnapshot) {
                      if (!orderSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: NovaColors.violet),
                        );
                      }

                      final orders = orderSnapshot.data!;
                      final visibleOrders = _filteredOrders(orders);
                      final grandTotal = visibleOrders.fold<double>(
                        0,
                        (sum, order) =>
                            sum + ((order['total'] as num?)?.toDouble() ?? 0.0),
                      );
                      final cashierStats = _buildCashierStats(
                        orders,
                        cashierNames,
                      );

                      return LayoutBuilder(builder: (context, c) {
                        final isWide = c.maxWidth >= 1100;
                        final availableHeight = c.hasBoundedHeight
                            ? c.maxHeight
                            : MediaQuery.sizeOf(context).height;

                        final topBar = _OrdersReportTopBar(
                          period: _period,
                          periodLabel: _periodLabel,
                          onPeriodChanged: (value) {
                            setState(() {
                              _period = value;
                              _selectedCashierId = 'all';
                            });
                          },
                          total: grandTotal,
                          count: visibleOrders.length,
                        );

                        final cashierSidebar = _CashierReportSidebar(
                          stats: cashierStats,
                          selectedCashierId: _selectedCashierId,
                          allOrderCount: orders.length,
                          allTotal: orders.fold<double>(
                            0,
                            (sum, order) =>
                                sum +
                                ((order['total'] as num?)?.toDouble() ?? 0.0),
                          ),
                          onSelected: (id) =>
                              setState(() => _selectedCashierId = id),
                        );

                        final orderList = _OrdersReportList(
                          orders: visibleOrders,
                          cashierNames: cashierNames,
                          formatDate: _formatDate,
                          cashierName: _cashierName,
                          onOpen: (order, cashier) =>
                              _openReceipt(context, order, cashier),
                          scrollable: isWide,
                        );

                        if (isWide) {
                          return SizedBox(
                            height: availableHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                topBar,
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: 280,
                                        child: cashierSidebar,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: orderList),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView(
                          children: [
                            topBar,
                            const SizedBox(height: 12),
                            _CashierReportCategories(
                              stats: cashierStats,
                              selectedCashierId: _selectedCashierId,
                              allOrderCount: orders.length,
                              allTotal: orders.fold<double>(
                                0,
                                (sum, order) =>
                                    sum +
                                    ((order['total'] as num?)?.toDouble() ??
                                        0.0),
                              ),
                              onSelected: (id) =>
                                  setState(() => _selectedCashierId = id),
                            ),
                            const SizedBox(height: 12),
                            orderList,
                          ],
                        );
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

List<_CashierOrderStats> _buildCashierStats(
  List<Map<String, dynamic>> orders,
  Map<String, String> cashierNames,
) {
  final stats = <String, _CashierOrderStats>{};
  for (final order in orders) {
    final id = order['createdBy']?.toString() ?? '';
    final key = id.isEmpty ? 'unassigned' : id;
    final name =
        id.isEmpty ? 'Unassigned' : (cashierNames[id] ?? 'Unknown Cashier');
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final current = stats[key] ?? _CashierOrderStats(id: key, name: name);
    stats[key] = current.copyWith(
      orderCount: current.orderCount + 1,
      total: current.total + total,
    );
  }
  final values = stats.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return values;
}

class _CashierOrderStats {
  const _CashierOrderStats({
    required this.id,
    required this.name,
    this.orderCount = 0,
    this.total = 0,
  });

  final String id;
  final String name;
  final int orderCount;
  final double total;

  _CashierOrderStats copyWith({int? orderCount, double? total}) {
    return _CashierOrderStats(
      id: id,
      name: name,
      orderCount: orderCount ?? this.orderCount,
      total: total ?? this.total,
    );
  }
}

class _OrdersReportTopBar extends StatelessWidget {
  const _OrdersReportTopBar({
    required this.period,
    required this.periodLabel,
    required this.onPeriodChanged,
    required this.total,
    required this.count,
  });

  final String period;
  final String Function(String) periodLabel;
  final ValueChanged<String> onPeriodChanged;
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < AppBreakpoints.mobile;
        final summary = Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NovaColors.violetLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.summarize_rounded,
                  color: NovaColors.violetDeep, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${periodLabel(period)} Orders',
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count orders | ${_formatMoney(total)}',
                    style: const TextStyle(
                      color: NovaColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final selector = SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ButtonSegment(value: 'yearly', label: Text('Yearly')),
          ],
          selected: {period},
          onSelectionChanged: (values) => onPeriodChanged(values.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : NovaColors.textSecondary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? NovaColors.violet
                  : NovaColors.bgSecondary;
            }),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 12), selector],
          );
        }

        return Row(
          children: [
            Expanded(child: summary),
            const SizedBox(width: 12),
            selector,
          ],
        );
      }),
    );
  }
}

class _CashierReportCategories extends StatelessWidget {
  const _CashierReportCategories({
    required this.stats,
    required this.selectedCashierId,
    required this.allOrderCount,
    required this.allTotal,
    required this.onSelected,
  });

  final List<_CashierOrderStats> stats;
  final String selectedCashierId;
  final int allOrderCount;
  final double allTotal;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = [
      _CashierOrderStats(
        id: 'all',
        name: 'All Cashiers',
        orderCount: allOrderCount,
        total: allTotal,
      ),
      ...stats,
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final stat = categories[index];
          final selected = stat.id == selectedCashierId;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            onTap: () => onSelected(stat.id),
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? NovaColors.violetLight : NovaColors.bgPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      selected ? NovaColors.violet : NovaColors.borderTertiary,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.person_pin_rounded,
                        color: selected
                            ? NovaColors.violetDeep
                            : NovaColors.textTertiary,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          stat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NovaColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _formatMoney(stat.total),
                    style: NovaFonts.price(
                      color: NovaColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stat.orderCount} order${stat.orderCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: NovaColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CashierReportSidebar extends StatelessWidget {
  const _CashierReportSidebar({
    required this.stats,
    required this.selectedCashierId,
    required this.allOrderCount,
    required this.allTotal,
    required this.onSelected,
  });

  final List<_CashierOrderStats> stats;
  final String selectedCashierId;
  final int allOrderCount;
  final double allTotal;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = [
      _CashierOrderStats(
        id: 'all',
        name: 'All Cashiers',
        orderCount: allOrderCount,
        total: allTotal,
      ),
      ...stats,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cashiers',
            style: TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final stat = categories[index];
                final selected = stat.id == selectedCashierId;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  mouseCursor: SystemMouseCursors.click,
                  onTap: () => onSelected(stat.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? NovaColors.violetLight
                          : NovaColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? NovaColors.violet
                            : NovaColors.borderTertiary,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.person_pin_rounded,
                          color: selected
                              ? NovaColors.violetDeep
                              : NovaColors.textTertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NovaColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${stat.orderCount} order${stat.orderCount == 1 ? '' : 's'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NovaColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMoney(stat.total),
                          style: NovaFonts.price(
                            color: NovaColors.violetDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersReportList extends StatelessWidget {
  const _OrdersReportList({
    required this.orders,
    required this.cashierNames,
    required this.formatDate,
    required this.cashierName,
    required this.onOpen,
    this.scrollable = false,
  });

  final List<Map<String, dynamic>> orders;
  final Map<String, String> cashierNames;
  final String Function(DateTime) formatDate;
  final String Function(Map<String, String>, Map<String, dynamic>) cashierName;
  final void Function(Map<String, dynamic>, String) onOpen;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: NovaColors.textTertiary, size: 42),
            SizedBox(height: 10),
            Text(
              'No orders found',
              style: TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Orders will appear here after checkout.',
              style: TextStyle(color: NovaColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final listItems = List<Widget>.generate(orders.length * 2 - 1, (index) {
      if (index.isOdd) return const SizedBox(height: 10);
      final order = orders[index ~/ 2];
      final cashier = cashierName(cashierNames, order);
      return _InventoryOrderReportCard(
        order: order,
        cashier: cashier,
        formatDate: formatDate,
        onTap: () => onOpen(order, cashier),
      );
    });

    if (scrollable) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Order Receipts',
                style: TextStyle(
                  color: NovaColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: listItems,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Order Receipts',
            style: TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ...listItems,
      ],
    );
  }
}

class _InventoryOrderReportCard extends StatelessWidget {
  const _InventoryOrderReportCard({
    required this.order,
    required this.cashier,
    required this.formatDate,
    required this.onTap,
  });

  final Map<String, dynamic> order;
  final String cashier;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  Color get _statusColor {
    return switch (order['status']?.toString() ?? '') {
      'completed' => NovaColors.tealDeep,
      'ready' => NovaColors.amberDeep,
      'pending' => NovaColors.danger,
      _ => NovaColors.textSecondary,
    };
  }

  Color get _statusBg {
    return switch (order['status']?.toString() ?? '') {
      'completed' => NovaColors.tealLight,
      'ready' => NovaColors.amberLight,
      'pending' => NovaColors.dangerLight,
      _ => NovaColors.bgSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = order['createdAtDate'] as DateTime? ?? DateTime.now();
    final orderNumber = (order['orderNumber'] as num?)?.toInt() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final orderItems = (order['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final itemCount = orderItems.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item['qty'] as num?)?.toInt() ??
              (item['quantity'] as num?)?.toInt() ??
              1),
    );
    final productSummary = orderItems
        .map((item) {
          final name =
              (item['name'] ?? item['productName'] ?? item['item_name'])
                      ?.toString()
                      .trim() ??
                  '';
          final quantity = (item['qty'] as num?)?.toInt() ??
              (item['quantity'] as num?)?.toInt() ??
              1;
          return name.isEmpty ? '' : '$name ×$quantity';
        })
        .where((label) => label.isNotEmpty)
        .join(', ');
    final status = order['status']?.toString() ?? 'unknown';
    final payment = order['paymentMethod']?.toString() ?? 'cash';

    return Material(
      color: NovaColors.bgPrimary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.borderTertiary),
          ),
          child: LayoutBuilder(builder: (context, c) {
            final compact = c.maxWidth < AppBreakpoints.mobile;
            final leading = Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NovaColors.violetLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_rounded,
                  color: NovaColors.violetDeep, size: 21),
            );

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order #$orderNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NovaColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatMoney(total),
                      style: const TextStyle(
                        color: NovaColors.violetDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Cashier: $cashier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (productSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    productSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _OrderReportChip(
                      icon: Icons.schedule_rounded,
                      label: formatDate(createdAt),
                    ),
                    _OrderReportChip(
                      icon: Icons.shopping_bag_outlined,
                      label: '$itemCount items',
                    ),
                    _OrderReportChip(
                      icon: Icons.payment_rounded,
                      label: payment.toUpperCase(),
                    ),
                    _OrderReportChip(
                      label: status.toUpperCase(),
                      color: _statusColor,
                      backgroundColor: _statusBg,
                    ),
                  ],
                ),
              ],
            );

            final openIcon = IconButton(
              tooltip: 'Open receipt',
              onPressed: onTap,
              icon: const Icon(Icons.open_in_new_rounded,
                  color: NovaColors.textSecondary, size: 20),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [leading, const Spacer(), openIcon]),
                  const SizedBox(height: 10),
                  details,
                ],
              );
            }

            return Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 8),
                openIcon,
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _OrderReportChip extends StatelessWidget {
  const _OrderReportChip({
    required this.label,
    this.icon,
    this.color = NovaColors.textSecondary,
    this.backgroundColor = NovaColors.bgSecondary,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCodeRestockPanel extends StatefulWidget {
  const _ProductCodeRestockPanel({
    required this.products,
    required this.service,
    required this.onMutated,
  });

  final List<Product> products;
  final InventoryService service;
  final VoidCallback onMutated;

  @override
  State<_ProductCodeRestockPanel> createState() =>
      _ProductCodeRestockPanelState();
}

class _ProductCodeRestockPanelState extends State<_ProductCodeRestockPanel> {
  final _productCodeController = TextEditingController();
  final _productCodeFocusNode = FocusNode(debugLabel: 'InventoryProductCode');
  bool _isSaving = false;

  @override
  void dispose() {
    _productCodeController.dispose();
    _productCodeFocusNode.dispose();
    super.dispose();
  }

  Product? _findProduct(String rawCode) {
    final code = rawCode.trim().toLowerCase();
    if (code.isEmpty) return null;

    for (final product in widget.products) {
      if (product.id.trim().toLowerCase() == code) {
        return product;
      }
    }
    return null;
  }

  Future<void> _handleScan(String rawCode) async {
    if (_isSaving) return;

    final code = rawCode.trim();
    if (code.isEmpty) return;

    final product = _findProduct(code);
    if (product == null) {
      AppNotice.show(
        context,
        'No product found for code $code.',
        type: AppNoticeType.error,
      );
      _productCodeController.clear();
      _productCodeFocusNode.requestFocus();
      return;
    }

    final qty = await _showProductCodeQtyDialog(product);
    if (qty == null || qty <= 0 || !mounted) {
      _productCodeController.clear();
      _productCodeFocusNode.requestFocus();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.service.restock(
        productId: product.id,
        productName: product.name,
        quantity: qty,
        note: 'Product code restock: $code',
      );
      if (!mounted) return;
      AppNotice.show(
        context,
        'Added $qty to ${product.name}.',
        type: AppNoticeType.success,
      );
      widget.onMutated();
    } catch (e) {
      if (mounted) {
        AppNotice.show(
          context,
          'Product code restock failed: $e',
          type: AppNoticeType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        _productCodeController.clear();
        _productCodeFocusNode.requestFocus();
      }
    }
  }

  Future<int?> _showProductCodeQtyDialog(Product product) {
    final formKey = GlobalKey<FormState>();
    var quantityText = '1';

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Add stock - ${product.name}',
          style: const TextStyle(
            color: NovaColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current stock: ${product.stockQty}',
                style: const TextStyle(
                  color: NovaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: quantityText,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: NovaColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: _productCodeInputDecoration(
                  label: 'Quantity to add',
                  icon: Icons.add_box_outlined,
                ),
                onChanged: (value) => quantityText = value,
                validator: (value) {
                  final qty = int.tryParse(value ?? '');
                  if (qty == null || qty <= 0) {
                    return 'Enter a positive quantity';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, int.parse(quantityText.trim()));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NovaColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(quantityText.trim()));
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: NovaColors.teal,
              foregroundColor: Colors.white,
            ).copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            ),
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  InputDecoration _productCodeInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: NovaColors.textSecondary),
      prefixIcon: Icon(icon, color: NovaColors.teal, size: 18),
      filled: true,
      fillColor: NovaColors.bgSecondary,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.borderTertiary),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.teal, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD85A30)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD85A30)),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.mobile;
        final title = Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: NovaColors.tealLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: NovaColors.tealDeep,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Code Restock',
                    style: TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Enter an existing product code, then enter quantity',
                    style: TextStyle(
                      color: NovaColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final input = TextField(
          controller: _productCodeController,
          focusNode: _productCodeFocusNode,
          enabled: !_isSaving,
          textInputAction: TextInputAction.done,
          onSubmitted: _handleScan,
          style: const TextStyle(color: NovaColors.textPrimary, fontSize: 13),
          decoration: _productCodeInputDecoration(
            label: 'Enter product code',
            icon: Icons.tag_outlined,
          ).copyWith(
            suffixIcon: _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NovaColors.teal,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Submit product code',
                    mouseCursor: SystemMouseCursors.click,
                    onPressed: () => _handleScan(_productCodeController.text),
                    icon: const Icon(
                      Icons.keyboard_return_rounded,
                      color: NovaColors.textSecondary,
                      size: 18,
                    ),
                  ),
          ),
        );

        if (compact) {
          return Column(
            children: [
              title,
              const SizedBox(height: 12),
              input,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 14),
            SizedBox(width: 320, child: input),
          ],
        );
      }),
    );
  }
}

class _ProfitExpansionPanel extends StatelessWidget {
  const _ProfitExpansionPanel({
    required this.products,
    required this.transactions,
    required this.orders,
    required this.payLaterPeople,
    required this.expanded,
    required this.onToggle,
  });

  final List<Product> products;
  final List<InventoryTransaction> transactions;
  final List<Map<String, dynamic>> orders;
  final List<PayLaterPerson> payLaterPeople;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final productById = {
      for (final p in products) p.id: p,
    };
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day);
    final saleTx = transactions.where(
      (t) =>
          t.type.toLowerCase() == 'sale' &&
          !t.createdAt.toLocal().isBefore(cutoff),
    );
    final soldQtyByProduct = <String, int>{};
    for (final tx in saleTx) {
      soldQtyByProduct[tx.productId] =
          (soldQtyByProduct[tx.productId] ?? 0) + tx.quantity;
    }

    final orderProfitByProduct =
        _orderProfitByProduct(orders, cutoff, payLaterPeople);
    final hasActualOrderProfit = orderProfitByProduct.isNotEmpty;
    final productsWithCost = products.where((p) => p.purchasePrice > 0).length;
    final saleValue = hasActualOrderProfit
        ? orderProfitByProduct.values.fold<double>(
            0,
            (sum, item) => sum + item.saleValue,
          )
        : soldQtyByProduct.entries.fold<double>(0, (sum, entry) {
            final p = productById[entry.key];
            if (p == null) return sum;
            return sum + (p.price * entry.value);
          });
    final purchaseValue = hasActualOrderProfit
        ? orderProfitByProduct.values.fold<double>(
            0,
            (sum, item) => sum + item.purchaseValue,
          )
        : soldQtyByProduct.entries.fold<double>(0, (sum, entry) {
            final p = productById[entry.key];
            if (p == null) return sum;
            return sum + (p.purchasePrice * entry.value);
          });
    final stockSaleValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.price * p.stockQty),
    );
    final stockCostValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.purchasePrice * p.stockQty),
    );
    final stockProfit = stockSaleValue - stockCostValue;
    final profit = hasActualOrderProfit
        ? orderProfitByProduct.values.fold<double>(
            0,
            (sum, item) => sum + item.profit,
          )
        : saleValue - purchaseValue;
    final margin = saleValue <= 0 ? 0 : (profit / saleValue) * 100;
    final soldProducts = hasActualOrderProfit
        ? <Product>[]
        : soldQtyByProduct.keys
            .map((id) => productById[id])
            .whereType<Product>()
            .toList();
    if (!hasActualOrderProfit) {
      soldProducts.sort(
        (a, b) => _salesProfit(b, soldQtyByProduct[b.id] ?? 0)
            .compareTo(_salesProfit(a, soldQtyByProduct[a.id] ?? 0)),
      );
    }
    final actualProfitRows = orderProfitByProduct.values.toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));

    return Container(
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: NovaColors.violetLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: NovaColors.violet, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profit',
                          style: TextStyle(
                            color: NovaColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expanded
                              ? 'Sales margin ${margin.toStringAsFixed(1)}%'
                              : hasActualOrderProfit
                                  ? 'Collected profit from paid and khata orders'
                                  : 'Estimated from stock sale records',
                          style: const TextStyle(
                              color: NovaColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMoney(profit),
                    style: NovaFonts.price(
                      color:
                          profit >= 0 ? NovaColors.violet : NovaColors.danger,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: NovaColors.violetLight,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: NovaColors.violet,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1, color: NovaColors.borderTertiary),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, c) {
                    final compact = c.maxWidth < AppBreakpoints.mobile;
                    final stats = [
                      _ProfitStat(
                        label: 'Sold Value',
                        value: _formatMoney(saleValue),
                      ),
                      _ProfitStat(
                        label: 'COGS',
                        value: _formatMoney(purchaseValue),
                      ),
                      _ProfitStat(
                        label: 'Profit Margin',
                        value: '${margin.toStringAsFixed(1)}%',
                      ),
                      _ProfitStat(
                        label: 'Cost Prices',
                        value: '$productsWithCost/${products.length}',
                      ),
                      _ProfitStat(
                        label: 'Stock Profit',
                        value: _formatMoney(stockProfit),
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            stats[i],
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: stats[i]),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  if (hasActualOrderProfit)
                    Column(
                      children: actualProfitRows.take(3).map((row) {
                        return _ProfitProductRow.actual(row: row);
                      }).toList(),
                    )
                  else if (soldProducts.isEmpty)
                    const _MutedText(text: 'No sales yet to calculate profit.')
                  else
                    Column(
                      children: soldProducts.take(3).map((p) {
                        return _ProfitProductRow.estimated(
                          product: p,
                          soldQty: soldQtyByProduct[p.id] ?? 0,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _ProfitStat extends StatelessWidget {
  const _ProfitStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: NovaColors.violet,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductProfitSummary {
  _ProductProfitSummary({
    required this.productId,
    required this.name,
  });

  final String productId;
  final String name;
  int quantity = 0;
  double saleValue = 0;
  double purchaseValue = 0;
  double profit = 0;

  double get averageUnitSale => quantity <= 0 ? 0 : saleValue / quantity;
  double get averageUnitCost => quantity <= 0 ? 0 : purchaseValue / quantity;
}

Map<String, _ProductProfitSummary> _orderProfitByProduct(
  List<Map<String, dynamic>> orders,
  DateTime cutoff,
  List<PayLaterPerson> payLaterPeople,
) {
  final result = <String, _ProductProfitSummary>{};

  for (final order in orders) {
    final paymentMethod = order['paymentMethod']?.toString() ?? 'cash';
    final paidRatio = _orderPaidRatio(order, paymentMethod, payLaterPeople);
    if (paidRatio <= 0) continue;

    final createdAt =
        _readOrderDate(order['createdAtDate'] ?? order['createdAt']);
    if (createdAt == null || createdAt.toLocal().isBefore(cutoff)) continue;

    final items = order['items'];
    if (items is! List) continue;

    for (final rawItem in items) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final productId = item['productId']?.toString() ?? '';
      if (productId.isEmpty) continue;

      final qty = _readInt(item['qty'] ?? item['quantity']) ?? 1;
      final unitPrice = _readDouble(item['unitPrice'] ?? item['price']);
      final rawLineTotal = item['lineTotal'] == null
          ? unitPrice * qty
          : _readDouble(item['lineTotal']);
      final lineTotal = rawLineTotal * paidRatio;
      final purchasePrice = _readDouble(item['purchasePrice']);
      final rawPurchaseValue = purchasePrice * qty;
      final purchaseValue = rawPurchaseValue * paidRatio;
      final fallbackProfit = rawLineTotal - rawPurchaseValue;
      final rawLineProfit = item['lineProfit'] == null
          ? fallbackProfit
          : _readDouble(item['lineProfit']);
      final lineProfit = rawLineProfit * paidRatio;

      final current = result[productId] ??
          _ProductProfitSummary(
            productId: productId,
            name: item['name']?.toString() ?? 'Item',
          );
      current.quantity += qty;
      current.saleValue += lineTotal;
      current.purchaseValue += purchaseValue;
      current.profit += lineProfit;
      result[productId] = current;
    }
  }

  return result;
}

double _orderPaidRatio(
  Map<String, dynamic> order,
  String paymentMethod,
  List<PayLaterPerson> payLaterPeople,
) {
  if (paymentMethod == 'pay_later') {
    return _payLaterPaidRatio(order, payLaterPeople);
  }
  if (paymentMethod == 'partial') {
    final total = _readDouble(order['total']);
    if (total <= 0) return 0;
    final paidNow = _readDouble(order['tenderedAmount']).clamp(0.0, total);
    final dueLater = (total - paidNow).clamp(0.0, double.infinity);
    if (dueLater <= 0) return 1;
    final paidLaterRatio = _payLaterPaidRatio(order, payLaterPeople);
    return ((paidNow + (dueLater * paidLaterRatio)) / total).clamp(0.0, 1.0);
  }
  return 1.0;
}

double _payLaterPaidRatio(
  Map<String, dynamic> order,
  List<PayLaterPerson> payLaterPeople,
) {
  final customerName = (order['customerName']?.toString() ?? '').trim();
  if (customerName.isEmpty) return 0;

  final normalized = customerName.toLowerCase();
  PayLaterPerson? person;
  for (final candidate in payLaterPeople) {
    if (candidate.name.trim().toLowerCase() == normalized) {
      person = candidate;
      break;
    }
  }
  if (person == null || person.totalDebit <= 0) return 0;

  final orderNumber = order['orderNumber']?.toString();
  if (orderNumber == null || orderNumber.isEmpty) {
    return (person.totalPaid / person.totalDebit).clamp(0.0, 1.0);
  }

  final debits = person.entries.where((entry) => !entry.isPayment).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final orderDebit = debits
      .where((entry) => entry.orderNumber == orderNumber)
      .fold<double>(0, (sum, entry) => sum + entry.amount);
  if (orderDebit <= 0) {
    return (person.totalPaid / person.totalDebit).clamp(0.0, 1.0);
  }

  var remainingPaid = person.totalPaid;
  var paidForOrder = 0.0;
  for (final debit in debits) {
    if (remainingPaid <= 0) break;
    final paidForDebit = remainingPaid.clamp(0.0, debit.amount).toDouble();
    if (debit.orderNumber == orderNumber) {
      paidForOrder += paidForDebit;
    }
    remainingPaid -= paidForDebit;
  }

  return (paidForOrder / orderDebit).clamp(0.0, 1.0);
}

DateTime? _readOrderDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

int? _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

double _readDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}

class _ProfitProductRow extends StatelessWidget {
  const _ProfitProductRow.estimated({
    required this.product,
    required this.soldQty,
  }) : row = null;

  const _ProfitProductRow.actual({
    required this.row,
  })  : product = null,
        soldQty = 0;

  final Product? product;
  final int soldQty;
  final _ProductProfitSummary? row;

  @override
  Widget build(BuildContext context) {
    final actual = row;
    final estimatedProduct = product;
    final name = actual?.name ?? estimatedProduct?.name ?? 'Item';
    final qty = actual?.quantity ?? soldQty;
    final priceLabel = actual != null
        ? '${_formatMoney(actual.averageUnitCost)} -> ${_formatMoney(actual.averageUnitSale)}'
        : '${_formatMoney(estimatedProduct!.purchasePrice)} -> ${_formatMoney(estimatedProduct.price)}';
    final profit = actual?.profit ?? _salesProfit(estimatedProduct!, soldQty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: NovaColors.textPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'x$qty',
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text(
            priceLabel,
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text(
            _formatMoney(profit),
            style: TextStyle(
              color: profit >= 0 ? NovaColors.violet : NovaColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary, required this.products});
  final InventorySummary summary;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final cards = _buildMetricCards(summary, products);

    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 700 ? 4 : 2;

      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += columns) {
        final rowCards = cards.sublist(i, (i + columns).clamp(0, cards.length));
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < rowCards.length; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(child: rowCards[j]),
                ],
              ],
            ),
          ),
        );
        if (i + columns < cards.length) rows.add(const SizedBox(height: 10));
      }

      return Column(children: rows);
    });
  }
}

List<Widget> _buildMetricCards(
  InventorySummary summary,
  List<Product> products,
) {
  final out = products.where((p) => p.stockQty <= 0).length;

  return [
    _MetricCard(
      title: 'Total SKUs',
      value: '${summary.totalProducts}',
      subText: '${products.where((p) => p.stockQty > 0).length} in stock',
      icon: Icons.inventory_2_rounded,
      iconColor: NovaColors.teal,
    ),
    _MetricCard(
      title: 'Stock Value',
      value: 'Rs ${summary.stockValue.toStringAsFixed(0)}',
      subText: 'Current inventory value',
      icon: Icons.payments_rounded,
      iconColor: NovaColors.violet,
    ),
    _MetricCard(
      title: 'Low Stock',
      value: '${summary.lowStockCount}',
      subText:
          summary.lowStockCount == 0 ? 'All healthy' : 'Needs reorder soon',
      icon: Icons.warning_rounded,
      iconColor: NovaColors.amber,
    ),
    _MetricCard(
      title: 'Out of Stock',
      value: '$out',
      subText: out == 0 ? 'No blockers' : 'Action required',
      icon: Icons.block_rounded,
      iconColor: NovaColors.danger,
    ),
  ];
}

double _unitProfit(Product product) => product.price - product.purchasePrice;
double _salesProfit(Product product, int soldQty) =>
    _unitProfit(product) * soldQty;

String _formatMoney(num value) => 'Rs ${value.toStringAsFixed(0)}';

class _InventoryTablePanel extends StatefulWidget {
  const _InventoryTablePanel({
    required this.products,
    required this.categories,
    required this.service,
    required this.onMutated,
  });

  final List<Product> products;
  final List<String> categories;
  final InventoryService service;
  final VoidCallback onMutated;

  @override
  State<_InventoryTablePanel> createState() => _InventoryTablePanelState();
}

class _InventoryTablePanelState extends State<_InventoryTablePanel> {
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';
  int _visibleCount = 10;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode =
      FocusNode(debugLabel: 'InventorySearchField');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyboard);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyboard);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _handleKeyboard(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final keyboard = HardwareKeyboard.instance;
    final isCtrlOrMeta = keyboard.isControlPressed || keyboard.isMetaPressed;
    final isFocusSearch =
        (isCtrlOrMeta && event.logicalKey == LogicalKeyboardKey.keyF) ||
            event.logicalKey == LogicalKeyboardKey.slash;

    if (isFocusSearch) {
      _focusSearch();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty)) {
      _clearSearch();
      _searchFocusNode.unfocus();
      return true;
    }

    return false;
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _visibleCount = 10;
    });
  }

  List<Product> get _filtered {
    List<Product> list = _selectedCategory == 'All Categories'
        ? widget.products
        : widget.products
            .where((p) => p.category == _selectedCategory)
            .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;

    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 760;
      final compactTable = c.maxWidth < 1080;
      final tableColumnSpacing = compactTable ? 8.0 : 18.0;
      final tableHorizontalMargin = compactTable ? 8.0 : 12.0;
      final productWidth = compactTable ? 150.0 : 190.0;
      final categoryWidth = compactTable ? 70.0 : 96.0;
      final moneyWidth = compactTable ? 50.0 : 62.0;
      final stockWidth = compactTable ? 76.0 : 94.0;
      final reorderWidth = compactTable ? 42.0 : 62.0;
      final statusWidth = compactTable ? 96.0 : 108.0;
      final actionsWidth = compactTable ? 102.0 : 120.0;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final double contentHeight =
          (viewportHeight - (isMobile ? 360 : 330)).clamp(320.0, 900.0);

      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: NovaColors.bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NovaColors.borderTertiary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  const Text(
                    'Product Inventory',
                    style: TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox.shrink(),
                    dropdownColor: NovaColors.bgSecondary,
                    style: const TextStyle(
                        color: NovaColors.textPrimary, fontSize: 12),
                    items: [
                      const DropdownMenuItem(
                        value: 'All Categories',
                        child: Text('All Categories'),
                      ),
                      ...widget.categories.map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedCategory = v!;
                      _visibleCount = 10;
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                      color: NovaColors.textPrimary, fontSize: 13),
                  onChanged: (v) => setState(() {
                    _searchQuery = v.trim();
                    _visibleCount = 10;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search by name or category…  ( / or Ctrl+F )',
                    hintStyle: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: NovaColors.violet, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear search',
                            mouseCursor: SystemMouseCursors.click,
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded,
                                color: NovaColors.textSecondary, size: 16),
                          )
                        : null,
                    filled: true,
                    fillColor: NovaColors.bgSecondary,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: NovaColors.borderTertiary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: NovaColors.borderTertiary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: NovaColors.violet),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: NovaColors.borderTertiary),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No products found.',
                  style:
                      TextStyle(color: NovaColors.textSecondary, fontSize: 12),
                ),
              )
            else if (isMobile)
              SizedBox(
                height: contentHeight,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      _ProductCardList(
                        products: visible.take(_visibleCount).toList(),
                        onRestock: (p) => _showRestockDialog(context, p),
                        onAdjust: (p) => _showAdjustDialog(context, p),
                        onOrder: (p) => _openSupplierOrder(context, p, visible),
                      ),
                      if (visible.length > _visibleCount)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _visibleCount += 10;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NovaColors.violetLight,
                                foregroundColor: NovaColors.violet,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                      color: NovaColors.violet, width: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              icon: const Icon(Icons.expand_more_rounded,
                                  size: 18),
                              label: Text(
                                'Load More (${visible.length - _visibleCount} remaining)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: contentHeight,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 54,
                      dataRowMaxHeight: 60,
                      columnSpacing: tableColumnSpacing,
                      horizontalMargin: tableHorizontalMargin,
                      headingTextStyle: const TextStyle(
                        color: NovaColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      columns: [
                        DataColumn(
                          label: SizedBox(
                            width: productWidth,
                            child: const Text('Product'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: categoryWidth,
                            child: const Text('Category'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: moneyWidth,
                            child: const Text('Purchase'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: moneyWidth,
                            child: const Text('Sale'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: moneyWidth,
                            child: const Text('Profit'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: stockWidth,
                            child: const Text('Stock'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: reorderWidth,
                            child: const Text('Alert'),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: statusWidth,
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Status'),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: actionsWidth,
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Actions'),
                            ),
                          ),
                        ),
                      ],
                      rows: visible.map((p) {
                        return DataRow(cells: [
                          DataCell(
                            SizedBox(
                              width: productWidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NovaColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    p.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NovaColors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: categoryWidth,
                              child: Text(
                                p.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NovaColors.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          DataCell(SizedBox(
                            width: moneyWidth,
                            child: _MoneyCell(value: p.purchasePrice),
                          )),
                          DataCell(SizedBox(
                            width: moneyWidth,
                            child: _MoneyCell(value: p.price),
                          )),
                          DataCell(SizedBox(
                            width: moneyWidth,
                            child: _MoneyCell(
                              value: _unitProfit(p),
                              emphasize: true,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: stockWidth,
                            child: _StockCell(
                              product: p,
                              compact: compactTable,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: reorderWidth,
                            child: Text(
                              '${p.lowStockThreshold}',
                              style: const TextStyle(
                                color: NovaColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: statusWidth,
                            child: Transform.translate(
                              offset: const Offset(-4, 0),
                              child: _StatusPill(product: p),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: actionsWidth,
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _TableActionButton(
                                  tooltip: 'Restock',
                                  icon: Icons.add_circle_outline_rounded,
                                  color: NovaColors.teal,
                                  onPressed: () =>
                                      _showRestockDialog(context, p),
                                ),
                                _TableActionButton(
                                  tooltip: 'Adjust stock',
                                  icon: Icons.tune_rounded,
                                  color: NovaColors.textSecondary,
                                  onPressed: () =>
                                      _showAdjustDialog(context, p),
                                ),
                                _TableActionButton(
                                  tooltip: 'Supplier order',
                                  icon: Icons.local_shipping_outlined,
                                  color: NovaColors.violet,
                                  onPressed: () =>
                                      _openSupplierOrder(context, p, visible),
                                ),
                              ],
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Text(
                'Showing ${visible.length} of ${widget.products.length} products'
                '${_searchQuery.isNotEmpty ? ' · filtered by "$_searchQuery"' : ''}',
                style: const TextStyle(
                    color: NovaColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _openSupplierOrder(
    BuildContext context,
    Product product,
    List<Product> availableProducts,
  ) {
    Navigator.of(context).push(
      NoAnimationPageRoute(
        builder: (_) => _SupplierOrderScreen(
          product: product,
          products: availableProducts,
        ),
      ),
    );
  }

  Future<void> _showRestockDialog(BuildContext context, Product p) async {
    final formKey = GlobalKey<FormState>();
    var quantityText = '';
    var note = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _StockActionSheet(
        icon: Icons.add_circle_outline_rounded,
        iconColor: NovaColors.violet,
        title: 'Restock',
        product: p,
        subtitle: 'Use a positive quantity to add stock.',
        actionLabel: 'Confirm Restock',
        actionColor: NovaColors.violet,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(ctx, true);
          }
        },
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CurrentStockChip(product: p),
              const SizedBox(height: 14),
              TextFormField(
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Quantity to add'),
                onChanged: (value) => quantityText = value,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Note (optional)'),
                onChanged: (value) => note = value,
              ),
            ],
          ),
        ),
      ),
    );

    final quantity = confirmed == true ? int.parse(quantityText.trim()) : null;
    note = note.trim();

    if (quantity != null) {
      try {
        await widget.service.restock(
          productId: p.id,
          productName: p.name,
          quantity: quantity,
          note: note.isEmpty ? null : note,
        );
        if (!context.mounted) return;
        AppNotice.show(
          context,
          'Restocked ${p.name} successfully.',
          type: AppNoticeType.success,
          subtitle: 'Added $quantity units to stock',
        );
        try {
          widget.onMutated();
        } catch (e) {
          debugPrint('[Inventory] refresh after restock skipped: $e');
        }
      } catch (e) {
        if (context.mounted) {
          AppNotice.show(
            context,
            'Restock failed: $e',
            type: AppNoticeType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  Future<void> _showAdjustDialog(BuildContext context, Product p) async {
    final formKey = GlobalKey<FormState>();
    var deltaText = '';
    var note = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _StockActionSheet(
        icon: Icons.tune_rounded,
        iconColor: NovaColors.violet,
        title: 'Adjust Stock',
        product: p,
        subtitle: 'Use +10 to add or -5 to remove.',
        actionLabel: 'Apply Adjustment',
        actionColor: NovaColors.violet,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(ctx, true);
          }
        },
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CurrentStockChip(product: p),
              const SizedBox(height: 14),
              TextFormField(
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                autofocus: true,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Delta (e.g. +10 or -3)'),
                onChanged: (value) => deltaText = value,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n == 0) return 'Enter a non-zero integer';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Reason (optional)'),
                onChanged: (value) => note = value,
              ),
            ],
          ),
        ),
      ),
    );

    final delta = confirmed == true ? int.parse(deltaText.trim()) : null;
    note = note.trim();

    if (delta != null) {
      try {
        await widget.service.adjust(
          productId: p.id,
          productName: p.name,
          delta: delta,
          note: note.isEmpty ? null : note,
        );
        if (!context.mounted) return;
        AppNotice.show(
          context,
          'Adjusted ${p.name} successfully.',
          type: AppNoticeType.success,
          subtitle: 'Stock changed by ${delta > 0 ? '+' : ''}$delta',
        );
        widget.onMutated();
      } catch (e) {
        if (context.mounted) {
          AppNotice.show(
            context,
            'Adjustment failed: $e',
            type: AppNoticeType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
        filled: true,
        fillColor: NovaColors.bgSecondary,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NovaColors.borderTertiary),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NovaColors.violet),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD85A30)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD85A30)),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

class _StockActionSheet extends StatelessWidget {
  const _StockActionSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.product,
    this.subtitle,
    required this.child,
    required this.actionLabel,
    required this.actionColor,
    required this.onCancel,
    required this.onConfirm,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Product product;
  final String? subtitle;
  final Widget child;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(14, 16, 14, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: BoxDecoration(
                color: NovaColors.bgPrimary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NovaColors.borderSecondary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: CafeColors.headerGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 17),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CafeColors.charcoal,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle ?? product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: NovaColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        mouseCursor: SystemMouseCursors.click,
                        visualDensity: VisualDensity.compact,
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded,
                            color: NovaColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  child,
                  const SizedBox(height: 10),
                  LayoutBuilder(builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final cancelButton = OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NovaColors.textSecondary,
                        side:
                            const BorderSide(color: NovaColors.borderSecondary),
                        minimumSize: const Size.fromHeight(38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ).copyWith(
                        mouseCursor: WidgetStateProperty.all(
                          SystemMouseCursors.click,
                        ),
                      ),
                      child: const Text('Cancel'),
                    );
                    final actionButton = FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ).copyWith(
                        mouseCursor: WidgetStateProperty.all(
                          SystemMouseCursors.click,
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          actionButton,
                          const SizedBox(height: 8),
                          cancelButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: cancelButton),
                        const SizedBox(width: 10),
                        Expanded(child: actionButton),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentStockChip extends StatelessWidget {
  const _CurrentStockChip({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: CafeColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NovaColors.tealLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(product.icon, color: NovaColors.tealDeep, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 46),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: NovaColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NovaColors.borderTertiary),
            ),
            child: Text(
              '${product.stockQty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCardList extends StatelessWidget {
  const _ProductCardList({
    required this.products,
    required this.onRestock,
    required this.onAdjust,
    required this.onOrder,
  });

  final List<Product> products;
  final void Function(Product) onRestock;
  final void Function(Product) onAdjust;
  final void Function(Product) onOrder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: products.map((p) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: () => onRestock(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: NovaColors.borderTertiary)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NovaColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NovaColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Buy ${_formatMoney(p.purchasePrice)}  |  Sell ${_formatMoney(p.price)}  |  Profit ${_formatMoney(_unitProfit(p))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NovaColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _StatusPill(product: p),
                            const SizedBox(width: 8),
                            Flexible(child: _StockCell(product: p)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Restock',
                        mouseCursor: SystemMouseCursors.click,
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 20, color: NovaColors.teal),
                        onPressed: () => onRestock(p),
                      ),
                      IconButton(
                        tooltip: 'Adjust',
                        mouseCursor: SystemMouseCursors.click,
                        icon: const Icon(Icons.tune_rounded,
                            size: 20, color: NovaColors.textSecondary),
                        onPressed: () => onAdjust(p),
                      ),
                      IconButton(
                        tooltip: 'Supplier order',
                        mouseCursor: SystemMouseCursors.click,
                        icon: const Icon(Icons.local_shipping_outlined,
                            size: 20, color: NovaColors.violet),
                        onPressed: () => onOrder(p),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SupplierOrderScreen extends StatefulWidget {
  const _SupplierOrderScreen({
    required this.product,
    this.products,
  });

  final Product product;
  final List<Product>? products;

  @override
  State<_SupplierOrderScreen> createState() => _SupplierOrderScreenState();
}

class _SupplierOrderScreenState extends State<_SupplierOrderScreen> {
  static const String _suppliersPrefsKey = 'supplier_order_suppliers_v1';
  static const Set<String> _starterSupplierNames = {
    'metro wholesale',
    'fresh stock traders',
    'daily goods supplier',
  };

  final _supplierFormKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();
  final _supplierContactController = TextEditingController();
  final _supplierEmailController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _supplierLeadTimeController = TextEditingController();
  final _supplierTermsController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _productsScrollController = ScrollController();
  final Map<String, TextEditingController> _qtyControllers = {};
  final Set<String> _selectedProductIds = {};
  String _productSearchQuery = '';
  late List<_SupplierInfo> _suppliers;
  int _selectedSupplier = 0;
  int? _editingSupplierIndex;

  late final List<Product> _orderProducts;

  @override
  void initState() {
    super.initState();
    _suppliers = <_SupplierInfo>[];
    _loadSuppliers();
    final products = widget.products ?? [widget.product];
    final byId = <String, Product>{};
    for (final product in products) {
      byId[product.id] = product;
    }
    byId[widget.product.id] = widget.product;
    _orderProducts = byId.values.toList()
      ..sort((a, b) {
        if (a.id == widget.product.id) return -1;
        if (b.id == widget.product.id) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    for (final product in _orderProducts) {
      _qtyControllers[product.id] = TextEditingController(
        text: _suggestedOrderQty(product).toString(),
      );
    }
    _selectedProductIds.add(widget.product.id);
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    _supplierNameController.dispose();
    _supplierContactController.dispose();
    _supplierEmailController.dispose();
    _supplierAddressController.dispose();
    _supplierLeadTimeController.dispose();
    _supplierTermsController.dispose();
    _productSearchController.dispose();
    _productsScrollController.dispose();
    super.dispose();
  }

  int _suggestedOrderQty(Product product) {
    final needed =
        (product.lowStockThreshold - product.stockQty).clamp(0, 999).toInt();
    return needed <= 0 ? 5 : needed + 5;
  }

  List<_SupplierOrderLine> _selectedOrderLines() {
    return _orderProducts
        .where((product) => _selectedProductIds.contains(product.id))
        .map((product) {
          final qty =
              int.tryParse(_qtyControllers[product.id]?.text.trim() ?? '') ?? 0;
          return _SupplierOrderLine(product: product, qty: qty);
        })
        .where((line) => line.qty > 0)
        .toList();
  }

  int get _selectedItemCount => _selectedProductIds.length;

  void _selectAllOrderProducts() {
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(_orderProducts.map((product) => product.id));
    });
  }

  void _selectLowStockOrderProducts() {
    final lowStockIds = _orderProducts
        .where((product) => product.stockQty <= product.lowStockThreshold)
        .map((product) => product.id);
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(lowStockIds);
    });
  }

  void _clearOrderProducts() {
    setState(_selectedProductIds.clear);
  }

  void _addSupplier() {
    if (!_supplierFormKey.currentState!.validate()) return;

    final supplier = _SupplierInfo(
      name: _supplierNameController.text.trim(),
      contact: _supplierContactController.text.trim(),
      email: _supplierEmailController.text.trim(),
      address: _supplierAddressController.text.trim(),
      leadTime: _supplierLeadTimeController.text.trim().isEmpty
          ? 'Not set'
          : _supplierLeadTimeController.text.trim(),
      terms: _supplierTermsController.text.trim().isEmpty
          ? 'Not set'
          : _supplierTermsController.text.trim(),
    );

    setState(() {
      _suppliers.add(supplier);
      _selectedSupplier = _suppliers.length - 1;
      _supplierNameController.clear();
      _supplierContactController.clear();
      _supplierEmailController.clear();
      _supplierAddressController.clear();
      _supplierLeadTimeController.clear();
      _supplierTermsController.clear();
    });
    _saveSuppliers();
  }

  void _startEditSupplier(int index) {
    final supplier = _suppliers[index];
    setState(() {
      _editingSupplierIndex = index;
      _supplierNameController.text = supplier.name;
      _supplierContactController.text = supplier.contact;
      _supplierEmailController.text = supplier.email;
      _supplierAddressController.text = supplier.address;
      _supplierLeadTimeController.text =
          supplier.leadTime == 'Not set' ? '' : supplier.leadTime;
      _supplierTermsController.text =
          supplier.terms == 'Not set' ? '' : supplier.terms;
    });
  }

  void _cancelEditSupplier() {
    setState(() {
      _editingSupplierIndex = null;
      _supplierNameController.clear();
      _supplierContactController.clear();
      _supplierEmailController.clear();
      _supplierAddressController.clear();
      _supplierLeadTimeController.clear();
      _supplierTermsController.clear();
    });
  }

  void _submitSupplierForm() {
    if (_editingSupplierIndex != null) {
      _updateSupplier(_editingSupplierIndex!);
      return;
    }
    _addSupplier();
  }

  void _updateSupplier(int index) {
    if (!_supplierFormKey.currentState!.validate()) return;

    final updated = _SupplierInfo(
      name: _supplierNameController.text.trim(),
      contact: _supplierContactController.text.trim(),
      email: _supplierEmailController.text.trim(),
      address: _supplierAddressController.text.trim(),
      leadTime: _supplierLeadTimeController.text.trim().isEmpty
          ? 'Not set'
          : _supplierLeadTimeController.text.trim(),
      terms: _supplierTermsController.text.trim().isEmpty
          ? 'Not set'
          : _supplierTermsController.text.trim(),
    );

    setState(() {
      _suppliers[index] = updated;
      _selectedSupplier = index;
      _editingSupplierIndex = null;
      _supplierNameController.clear();
      _supplierContactController.clear();
      _supplierEmailController.clear();
      _supplierAddressController.clear();
      _supplierLeadTimeController.clear();
      _supplierTermsController.clear();
    });
    _saveSuppliers();
  }

  void _deleteSupplier(int index) {
    setState(() {
      _suppliers.removeAt(index);
      if (_editingSupplierIndex == index) {
        _editingSupplierIndex = null;
        _supplierNameController.clear();
        _supplierContactController.clear();
        _supplierEmailController.clear();
        _supplierAddressController.clear();
        _supplierLeadTimeController.clear();
        _supplierTermsController.clear();
      } else if (_editingSupplierIndex != null &&
          _editingSupplierIndex! > index) {
        _editingSupplierIndex = _editingSupplierIndex! - 1;
      }
      _selectedSupplier = _suppliers.isEmpty
          ? 0
          : _selectedSupplier.clamp(0, _suppliers.length - 1);
    });
    _saveSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_suppliersPrefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;
      final loaded = parsed
          .whereType<Map>()
          .map((e) => _SupplierInfo.fromMap(Map<String, dynamic>.from(e)))
          .where((supplier) => !_starterSupplierNames.contains(
                supplier.name.trim().toLowerCase(),
              ))
          .toList();
      if (loaded.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _suppliers = loaded;
        _selectedSupplier = _selectedSupplier.clamp(0, _suppliers.length - 1);
      });
      if (loaded.length != parsed.length) {
        await _saveSuppliers();
      }
    } catch (_) {}
  }

  Future<void> _saveSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_suppliers.map((s) => s.toMap()).toList());
    await prefs.setString(_suppliersPrefsKey, payload);
  }

  Future<void> _showSuppliersDialog() async {
    final searchController = TextEditingController();
    var searchQuery = '';

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final visibleSuppliers = searchQuery.isEmpty
                ? _suppliers.indexed.toList()
                : _suppliers.indexed.where((entry) {
                    final supplier = entry.$2;
                    final searchable = [
                      supplier.name,
                      supplier.contact,
                      supplier.email,
                      supplier.address,
                      supplier.leadTime,
                      supplier.terms,
                    ].join(' ').toLowerCase();
                    return searchable.contains(searchQuery);
                  }).toList();

            return Dialog(
              backgroundColor: NovaColors.bgPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 620,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Suppliers',
                              style: TextStyle(
                                color: NovaColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) => setDialogState(
                          () => searchQuery = value.trim().toLowerCase(),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search suppliers',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() => searchQuery = '');
                                  },
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                ),
                          filled: true,
                          fillColor: NovaColors.bgSecondary,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: NovaColors.borderTertiary,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: NovaColors.borderTertiary,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: NovaColors.violet),
                          ),
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      color: NovaColors.borderTertiary,
                    ),
                    Expanded(
                      child: visibleSuppliers.isEmpty
                          ? const Center(
                              child: _MutedText(
                                text: 'No matching suppliers found.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: visibleSuppliers.length,
                              itemBuilder: (context, index) {
                                final entry = visibleSuppliers[index];
                                final supplierIndex = entry.$1;
                                return _SupplierOption(
                                  supplier: entry.$2,
                                  selected: supplierIndex == _selectedSupplier,
                                  onTap: () {
                                    setState(
                                      () => _selectedSupplier = supplierIndex,
                                    );
                                    Navigator.pop(dialogContext);
                                  },
                                  onEdit: () {
                                    Navigator.pop(dialogContext);
                                    _startEditSupplier(supplierIndex);
                                  },
                                  onDelete: () {
                                    _deleteSupplier(supplierIndex);
                                    setDialogState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _prepareAndSendOrder() async {
    final lines = _selectedOrderLines();
    if (lines.isEmpty) {
      AppNotice.show(
        context,
        'Select at least one product and enter quantity.',
        type: AppNoticeType.error,
      );
      return;
    }

    final supplier = _suppliers[_selectedSupplier];
    final message = StringBuffer()
      ..writeln('Order Request')
      ..writeln('Items:');
    for (final line in lines) {
      message.writeln('- ${line.product.name}: ${line.qty}');
    }
    message.writeln('Total Items: ${lines.length}');
    message.writeln('Total Quantity: ${lines.fold<int>(
      0,
      (sum, line) => sum + line.qty,
    )}');

    final bodyText = message.toString().trim();
    final normalizedPhone = supplier.contact.replaceAll(RegExp(r'[^\d+]'), '');
    final whatsappPhone = normalizedPhone.startsWith('+')
        ? normalizedPhone.substring(1)
        : normalizedPhone;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Send Supplier Order',
          style: TextStyle(
            color: NovaColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplier.name,
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bodyText,
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              mouseCursor: SystemMouseCursors.click,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 18,
              ),
              title: Text(
                'WhatsApp ${supplier.contact}',
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final opened = await _openExternal(
                  Uri.parse(
                    'https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(bodyText)}',
                  ),
                );
                if (opened) {
                  _showOrderPlacedNotification(
                    channel: 'WhatsApp',
                    lines: lines,
                    supplier: supplier,
                  );
                }
              },
            ),
            ListTile(
              mouseCursor: SystemMouseCursors.click,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const FaIcon(
                FontAwesomeIcons.commentSms,
                color: NovaColors.violet,
                size: 18,
              ),
              title: Text(
                'SMS ${supplier.contact}',
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final opened = await _openExternal(
                  Uri.parse(
                    'sms:$normalizedPhone?body=${Uri.encodeComponent(bodyText)}',
                  ),
                );
                if (opened) {
                  _showOrderPlacedNotification(
                    channel: 'SMS',
                    lines: lines,
                    supplier: supplier,
                  );
                }
              },
            ),
            ListTile(
              mouseCursor: supplier.email.isEmpty
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const FaIcon(
                FontAwesomeIcons.google,
                color: Color(0xFFEA4335),
                size: 18,
              ),
              title: Text(
                supplier.email.isEmpty ? 'Email not provided' : supplier.email,
                style: const TextStyle(
                    color: NovaColors.textPrimary, fontSize: 13),
              ),
              onTap: supplier.email.isEmpty
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      final gmailUri = Uri.https(
                        'mail.google.com',
                        '/mail/',
                        {
                          'view': 'cm',
                          'fs': '1',
                          'to': supplier.email,
                          'su': 'Supplier order request',
                          'body': bodyText,
                        },
                      );
                      final opened = await _openExternal(
                        gmailUri,
                      );
                      if (opened) {
                        _showOrderPlacedNotification(
                          channel: 'Email',
                          lines: lines,
                          supplier: supplier,
                        );
                      }
                    },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: NovaColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _createOrderReference() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final tail = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'PO-$datePart-$timePart-$tail';
  }

  void _showOrderPlacedNotification({
    required String channel,
    required List<_SupplierOrderLine> lines,
    required _SupplierInfo supplier,
  }) {
    if (!mounted) return;
    final orderRef = _createOrderReference();
    final totalQty = lines.fold<int>(0, (sum, line) => sum + line.qty);
    AppNotice.show(
      context,
      'Order placed [$orderRef] via $channel: ${lines.length} item(s), $totalQty qty to ${supplier.name}.',
      type: AppNoticeType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<bool> _openExternal(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppNotice.show(
        context,
        'Could not open this app on device.',
        type: AppNoticeType.error,
      );
    }
    return opened;
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _suppliers.isEmpty ? null : _suppliers[_selectedSupplier];
    final lines = _selectedOrderLines();
    final totalQty = lines.fold<int>(0, (sum, line) => sum + line.qty);

    return Scaffold(
      backgroundColor: NovaColors.bgTertiary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
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
        ),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_outlined,
                color: Colors.white70, size: 21),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Supplier Order',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white24),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useSidePanel = constraints.maxWidth >= 860;

          final productsCard = _PanelCard(
            title: 'Products to Order',
            child: _SupplierOrderItemsList(
              products: _orderProducts,
              searchController: _productSearchController,
              searchQuery: _productSearchQuery,
              selectedProductIds: _selectedProductIds,
              qtyControllers: _qtyControllers,
              onSearchChanged: (value) {
                setState(
                    () => _productSearchQuery = value.trim().toLowerCase());
              },
              onSelectAll: _selectAllOrderProducts,
              onSelectLowStock: _selectLowStockOrderProducts,
              onClear: _clearOrderProducts,
              onSelectionChanged: (product, selected) {
                setState(() {
                  if (selected) {
                    _selectedProductIds.add(product.id);
                  } else {
                    _selectedProductIds.remove(product.id);
                  }
                });
              },
              onQtyChanged: () => setState(() {}),
            ),
          );

          final supplierDetailsContent = _suppliers.isEmpty
              ? const _MutedText(text: 'No suppliers yet. Add one below.')
              : _SupplierOption(
                  supplier: _suppliers[_selectedSupplier],
                  selected: true,
                  onTap: _showSuppliersDialog,
                  onEdit: () => _startEditSupplier(_selectedSupplier),
                  onDelete: () => _deleteSupplier(_selectedSupplier),
                );

          final supplierDetailsCard = _PanelCard(
            title: 'Supplier Details',
            action: TextButton.icon(
              onPressed: _showSuppliersDialog,
              icon: const Icon(Icons.people_outline_rounded, size: 16),
              label: const Text('View Suppliers'),
              style: TextButton.styleFrom(
                foregroundColor: NovaColors.violet,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            child: supplierDetailsContent,
          );

          final supplierFormCard = _PanelCard(
            title: _editingSupplierIndex == null
                ? 'Add Supplier'
                : 'Edit Supplier',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _ManualSupplierForm(
                formKey: _supplierFormKey,
                nameController: _supplierNameController,
                contactController: _supplierContactController,
                emailController: _supplierEmailController,
                addressController: _supplierAddressController,
                leadTimeController: _supplierLeadTimeController,
                termsController: _supplierTermsController,
                onSubmit: _submitSupplierForm,
                onCancel:
                    _editingSupplierIndex == null ? null : _cancelEditSupplier,
                submitLabel: _editingSupplierIndex == null
                    ? 'Add Supplier'
                    : 'Save Changes',
              ),
            ),
          );

          final orderCard = _PanelCard(
            title: 'Order',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  _OrderSummaryRow(
                    label: 'Supplier',
                    value: supplier?.name ?? 'None selected',
                  ),
                  _OrderSummaryRow(
                    label: 'Selected Items',
                    value: '$_selectedItemCount',
                  ),
                  _OrderSummaryRow(
                    label: 'Total Quantity',
                    value: '$totalQty',
                    strong: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: (lines.isEmpty || _suppliers.isEmpty)
                          ? null
                          : _prepareAndSendOrder,
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Prepare Order'),
                      style: FilledButton.styleFrom(
                        backgroundColor: NovaColors.violet,
                        foregroundColor: Colors.white,
                      ).copyWith(
                        mouseCursor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? SystemMouseCursors.basic
                              : SystemMouseCursors.click,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (!useSidePanel) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                productsCard,
                const SizedBox(height: 14),
                supplierDetailsCard,
                const SizedBox(height: 14),
                supplierFormCard,
                const SizedBox(height: 14),
                orderCard,
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Scrollbar(
                    controller: _productsScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _productsScrollController,
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        children: [
                          productsCard,
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: supplierDetailsCard),
                      const SizedBox(height: 10),
                      supplierFormCard,
                      const SizedBox(height: 10),
                      orderCard,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupplierInfo {
  const _SupplierInfo({
    required this.name,
    required this.contact,
    required this.email,
    required this.address,
    required this.leadTime,
    required this.terms,
  });

  final String name;
  final String contact;
  final String email;
  final String address;
  final String leadTime;
  final String terms;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'email': email,
      'address': address,
      'leadTime': leadTime,
      'terms': terms,
    };
  }

  factory _SupplierInfo.fromMap(Map<String, dynamic> data) {
    return _SupplierInfo(
      name: (data['name'] ?? '').toString(),
      contact: (data['contact'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      leadTime: (data['leadTime'] ?? 'Not set').toString(),
      terms: (data['terms'] ?? 'Not set').toString(),
    );
  }
}

class _SupplierOrderLine {
  const _SupplierOrderLine({
    required this.product,
    required this.qty,
  });

  final Product product;
  final int qty;
}

class _SupplierOrderItemsList extends StatelessWidget {
  const _SupplierOrderItemsList({
    required this.products,
    required this.searchController,
    required this.searchQuery,
    required this.selectedProductIds,
    required this.qtyControllers,
    required this.onSearchChanged,
    required this.onSelectAll,
    required this.onSelectLowStock,
    required this.onClear,
    required this.onSelectionChanged,
    required this.onQtyChanged,
  });

  final List<Product> products;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<String> selectedProductIds;
  final Map<String, TextEditingController> qtyControllers;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectLowStock;
  final VoidCallback onClear;
  final void Function(Product product, bool selected) onSelectionChanged;
  final VoidCallback onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final visibleProducts = searchQuery.isEmpty
        ? products
        : products.where((product) {
            return product.name.toLowerCase().contains(searchQuery) ||
                product.modelCode.toLowerCase().contains(searchQuery) ||
                product.brand.toLowerCase().contains(searchQuery) ||
                product.category.toLowerCase().contains(searchQuery);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Search products',
              hintStyle: const TextStyle(
                color: NovaColors.textTertiary,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: NovaColors.textSecondary,
                size: 19,
              ),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: NovaColors.bgSecondary,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: NovaColors.borderTertiary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: NovaColors.borderTertiary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: NovaColors.violet),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: LayoutBuilder(builder: (context, constraints) {
            final count = Text(
              searchQuery.isEmpty
                  ? '${selectedProductIds.length}/${products.length} selected'
                  : '${visibleProducts.length} of ${products.length} products',
              style: const TextStyle(
                color: NovaColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _SupplierBulkButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low stock',
                  color: NovaColors.amber,
                  onPressed: onSelectLowStock,
                ),
                _SupplierBulkButton(
                  icon: Icons.done_all_rounded,
                  label: 'All',
                  color: NovaColors.violet,
                  onPressed: onSelectAll,
                ),
                _SupplierBulkButton(
                  icon: Icons.clear_rounded,
                  label: 'Clear',
                  color: const Color(0xFFE53935),
                  onPressed: onClear,
                ),
              ],
            );

            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  count,
                  const SizedBox(height: 8),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                count,
                const SizedBox(width: 12),
                Expanded(child: actions),
              ],
            );
          }),
        ),
        if (visibleProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 20, 14, 24),
            child: _MutedText(text: 'No matching products found.'),
          )
        else
          for (var i = 0; i < visibleProducts.length; i++) ...[
            _SupplierOrderItemRow(
              product: visibleProducts[i],
              selected: selectedProductIds.contains(visibleProducts[i].id),
              controller: qtyControllers[visibleProducts[i].id]!,
              onSelected: (selected) =>
                  onSelectionChanged(visibleProducts[i], selected ?? false),
              onQtyChanged: onQtyChanged,
            ),
            if (i < visibleProducts.length - 1)
              const Divider(height: 1, color: NovaColors.borderTertiary),
          ],
      ],
    );
  }
}

class _SupplierOrderItemRow extends StatelessWidget {
  const _SupplierOrderItemRow({
    required this.product,
    required this.selected,
    required this.controller,
    required this.onSelected,
    required this.onQtyChanged,
  });

  final Product product;
  final bool selected;
  final TextEditingController controller;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final isOut = product.stockQty <= 0;
    final isLow = !isOut && product.stockQty <= product.lowStockThreshold;
    final stockColor = isOut
        ? NovaColors.danger
        : isLow
            ? NovaColors.amber
            : NovaColors.tealDeep;
    final stockBackground = isOut
        ? NovaColors.dangerLight
        : isLow
            ? NovaColors.amberLight
            : NovaColors.tealLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: onSelected,
            mouseCursor: SystemMouseCursors.click,
            activeColor: NovaColors.violet,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NovaColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: stockBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Stock ${product.stockQty} | Alert ${product.lowStockThreshold}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            height: 38,
            child: TextField(
              controller: controller,
              enabled: selected,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => onQtyChanged(),
              style: const TextStyle(
                color: NovaColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: _orderInputDecoration().copyWith(
                hintText: 'Qty',
                prefixIcon: null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierBulkButton extends StatelessWidget {
  const _SupplierBulkButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.08),
        side: BorderSide(color: color.withOpacity(0.32)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: const Size(74, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    );
  }
}

class _SupplierOption extends StatelessWidget {
  const _SupplierOption({
    required this.supplier,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final _SupplierInfo supplier;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? NovaColors.violetLight : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: NovaColors.borderTertiary),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? NovaColors.violet : NovaColors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${supplier.contact} | ${supplier.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NovaColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supplier.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lead time: ${supplier.leadTime} | Terms: ${supplier.terms}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NovaColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Edit supplier',
              mouseCursor: SystemMouseCursors.click,
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                color: NovaColors.textSecondary,
                size: 18,
              ),
            ),
            IconButton(
              tooltip: 'Delete supplier',
              mouseCursor: SystemMouseCursors.click,
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFB54724),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSupplierForm extends StatelessWidget {
  const _ManualSupplierForm({
    required this.formKey,
    required this.nameController,
    required this.contactController,
    required this.emailController,
    required this.addressController,
    required this.leadTimeController,
    required this.termsController,
    required this.onSubmit,
    this.onCancel,
    required this.submitLabel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController contactController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController leadTimeController;
  final TextEditingController termsController;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: LayoutBuilder(builder: (context, c) {
        final isCompact = c.maxWidth < AppBreakpoints.mobile;

        final fields = [
          _SupplierTextField(
            controller: nameController,
            label: 'Supplier Name',
            icon: Icons.storefront_outlined,
            requiredField: true,
          ),
          _SupplierTextField(
            controller: contactController,
            label: 'Contact Number',
            icon: Icons.phone_outlined,
            requiredField: true,
            keyboardType: TextInputType.phone,
          ),
          _SupplierTextField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return null;
              return email.contains('@') ? null : 'Enter a valid email';
            },
          ),
          _SupplierTextField(
            controller: addressController,
            label: 'Address',
            icon: Icons.location_on_outlined,
            requiredField: true,
          ),
          _SupplierTextField(
            controller: leadTimeController,
            label: 'Lead Time',
            icon: Icons.schedule_outlined,
          ),
          _SupplierTextField(
            controller: termsController,
            label: 'Payment Terms',
            icon: Icons.receipt_long_outlined,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isCompact)
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                fields[i],
              ]
            else ...[
              Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: fields[2]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[3]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: fields[4]),
                  const SizedBox(width: 10),
                  Expanded(child: fields[5]),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCancel != null) ...[
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NovaColors.textSecondary,
                        side:
                            const BorderSide(color: NovaColors.borderSecondary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ).copyWith(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: Icon(
                      onCancel == null
                          ? Icons.add_business_outlined
                          : Icons.save_outlined,
                      size: 17,
                    ),
                    label: Text(submitLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: NovaColors.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ).copyWith(
                      mouseCursor:
                          WidgetStateProperty.all(SystemMouseCursors.click),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SupplierTextField extends StatelessWidget {
  const _SupplierTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.requiredField = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NovaColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: NovaColors.textPrimary, fontSize: 13),
          validator: validator ??
              (requiredField
                  ? (value) => value == null || value.trim().isEmpty
                      ? '$label is required'
                      : null
                  : null),
          decoration: InputDecoration(
            hintText: label,
            hintStyle:
                const TextStyle(color: NovaColors.textTertiary, fontSize: 12),
            filled: true,
            fillColor: NovaColors.bgSecondary,
            prefixIcon: Icon(icon, color: NovaColors.textSecondary, size: 18),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: NovaColors.borderTertiary),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: NovaColors.violet),
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFD85A30)),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFD85A30)),
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _OrderSummaryRow extends StatelessWidget {
  const _OrderSummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: NovaColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                color: NovaColors.textPrimary,
                fontSize: strong ? 14 : 12,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _orderInputDecoration() => InputDecoration(
      hintText: 'Enter quantity',
      hintStyle: const TextStyle(color: NovaColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: NovaColors.bgSecondary,
      prefixIcon: const Icon(Icons.inventory_2_outlined,
          color: NovaColors.textSecondary, size: 18),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.borderTertiary),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: NovaColors.violet),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    );

class _StockCell extends StatelessWidget {
  const _StockCell({required this.product, this.compact = false});
  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final threshold =
        product.lowStockThreshold <= 0 ? 1 : product.lowStockThreshold;
    final isOut = product.stockQty <= 0;
    final ratio =
        isOut ? 1.0 : (product.stockQty / (threshold * 4)).clamp(0.0, 1.0);

    Color barColor;
    Color trackColor;
    Color qtyColor;
    if (isOut) {
      barColor = const Color(0xFFE53935);
      trackColor = const Color(0xFFFFEDE8);
      qtyColor = const Color(0xFFE53935);
    } else if (product.stockQty <= product.lowStockThreshold) {
      barColor = const Color(0xFFFB8C00);
      trackColor = const Color(0xFFFFF3E0);
      qtyColor = const Color(0xFFEF6C00);
    } else {
      barColor = NovaColors.teal;
      trackColor = NovaColors.tealLight;
      qtyColor = NovaColors.tealDeep;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = compact ? 76.0 : 94.0;
        final cellWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : fallbackWidth;
        final qtyWidth = compact ? 34.0 : 40.0;
        final gap = compact ? 6.0 : 8.0;
        final barWidth = (cellWidth - qtyWidth - gap).clamp(20.0, 60.0);

        return SizedBox(
          width: constraints.hasBoundedWidth ? double.infinity : fallbackWidth,
          child: Row(
            children: [
              Container(
                width: barWidth,
                height: 6,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: qtyWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${product.stockQty}',
                    maxLines: 1,
                    style: TextStyle(
                      color: qtyColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      mouseCursor: SystemMouseCursors.click,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.value, this.emphasize = false});
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatMoney(value),
      style: NovaFonts.price(
        color: emphasize && value < 0
            ? NovaColors.danger
            : emphasize
                ? NovaColors.violet
                : NovaColors.textPrimary,
        fontSize: 13,
        fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color fg;

    if (product.stockQty <= 0) {
      label = 'Out of stock';
      fg = NovaColors.danger;
    } else if (product.stockQty <= product.lowStockThreshold) {
      label = 'Low stock';
      fg = NovaColors.amberDeep;
    } else {
      label = 'In stock';
      fg = NovaColors.tealDeep;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: NovaColors.bgSecondary,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: fg.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NovaColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subText,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String subText;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: NovaColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style:
                const TextStyle(color: NovaColors.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NovaColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  action!,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: NovaColors.borderTertiary),
          child,
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: const TextStyle(color: NovaColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NovaColors.bgTertiary,
      body: Center(
        child: CircularProgressIndicator(color: NovaColors.teal),
      ),
    );
  }
}
