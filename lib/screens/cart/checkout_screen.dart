import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/keyboard/pos_keyboard_system.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/app_notice.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/printer/thermal_printer_service.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/inventory_service.dart';
import '../../services/pocketbase/product_service.dart';
import '../../models/product_model.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';
import 'product_list_bottom_sheet.dart';

String itemEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('coffee') || n.contains('espresso') || n.contains('latte')) {
    return '☕';
  }
  if (n.contains('juice') || n.contains('cold') || n.contains('drink')) {
    return '🧃';
  }
  if (n.contains('burger') || n.contains('sandwich')) return '🥪';
  if (n.contains('pizza')) return '🍕';
  if (n.contains('cake') || n.contains('dessert') || n.contains('sweet')) {
    return '🍰';
  }
  if (n.contains('salad')) return '🥗';
  return '🍴';
}

class _CartActionOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;

  const _CartActionOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.enabled = true,
  });
}

class _EditQuantityDialog extends StatefulWidget {
  final String itemName;
  final int initialQty;
  final InputDecoration fieldDecoration;

  const _EditQuantityDialog({
    required this.itemName,
    required this.initialQty,
    required this.fieldDecoration,
  });

  @override
  State<_EditQuantityDialog> createState() => _EditQuantityDialogState();
}

class _EditQuantityDialogState extends State<_EditQuantityDialog> {
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.initialQty.toString(),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _save() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      AppNotice.show(
        context,
        'Enter a valid quantity greater than 0.',
        type: AppNoticeType.error,
      );
      return;
    }
    Navigator.pop(context, qty);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: NovaColors.bgPrimary,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 330;
            final cancelButton = OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: NovaColors.borderSecondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: NovaColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
            final saveButton = ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.violet,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );

            return Padding(
              padding: EdgeInsets.all(compact ? 16 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: NovaColors.violet,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit ${widget.itemName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onSubmitted: (_) => _save(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimary,
                    ),
                    decoration: widget.fieldDecoration,
                  ),
                  const SizedBox(height: 18),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 10),
                        saveButton,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: cancelButton),
                        const SizedBox(width: 10),
                        Expanded(child: saveButton),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Color itemBgColor(String name) {
  const colors = [
    NovaColors.violetLight,
    NovaColors.tealLight,
    NovaColors.amberLight,
    Color(0xFFFFEEF3),
    Color(0xFFE8F4FD),
  ];
  return colors[name.codeUnitAt(0) % colors.length];
}

bool _cashIsInsufficient(double tendered, double total) {
  return tendered.round() < total.round();
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final OrderService _orderService;
  late final InventoryService _inventoryService;
  late final ProductService _productService;
  Stream<List<Product>>? _productsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _orderService = OrderService(auth.ownerId);
    _inventoryService = InventoryService(auth.ownerId);
    _productService = ProductService(auth.ownerId);
    _productsStream = _productService.streamProducts.asBroadcastStream();
  }

  String? _getStockStatus(String productId, List<Product> products) {
    try {
      final p = products.firstWhere((p) => p.id == productId);
      if (p.stockQty <= 0) return 'OUT OF STOCK';
      if (p.stockQty <= p.lowStockThreshold) {
        return 'LOW STOCK (${p.stockQty})';
      }
    } catch (_) {}
    return null;
  }

  String _customerName = '';
  String _paymentMethod = 'cash';
  double _tenderedAmount = 0.0;
  bool _isSubmitting = false;
  int _focusedCartIndex = 0;

  bool _actionsDialogOpen = false;
  bool _productSheetOpen = false;
  bool _editDialogOpen = false;

  final FocusNode _cashFocus = FocusNode();
  final FocusNode _checkoutShortcutFocus =
      FocusNode(debugLabel: 'CheckoutShortcuts');
  final TextEditingController _cashController = TextEditingController();
  final GlobalKey<AppNoticeHostState> _noticeKey =
      GlobalKey<AppNoticeHostState>();
  final Map<String, GlobalKey> _cartItemMenuKeys = {};

  @override
  void initState() {
    super.initState();
    _cashFocus.addListener(_onCashFocusChange);
    _focusCashTendered();
  }

  void _onCashFocusChange() {
    if (mounted) setState(() {});
  }

  void _focusCashTendered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paymentMethod != 'cash') return;
      _cashFocus.requestFocus();
    });
  }

  void _focusCheckoutShortcuts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paymentMethod != 'card') return;
      _checkoutShortcutFocus.requestFocus();
    });
  }

  void _selectPaymentMethod(String method) {
    if (method != 'cash' && method != 'card') return;

    setState(() {
      _paymentMethod = method;
      if (method != 'cash') {
        _cashController.clear();
        _tenderedAmount = 0.0;
      }
    });

    if (method == 'cash') {
      _focusCashTendered();
    } else {
      _cashFocus.unfocus();
      _focusCheckoutShortcuts();
    }
  }

  int _safeCartIndex(CartProvider cart) {
    if (cart.items.isEmpty) return 0;
    return _focusedCartIndex.clamp(0, cart.items.length - 1);
  }

  void _focusCartShortcuts() {
    _cashFocus.unfocus();
    if (mounted) _checkoutShortcutFocus.requestFocus();
  }

  void _selectCartItem(int index) {
    setState(() => _focusedCartIndex = index);
    _focusCartShortcuts();
  }

  void _moveFocusedCartItem(CartProvider cart, int direction) {
    if (cart.items.isEmpty) return;
    final next = (_safeCartIndex(cart) + direction).clamp(
      0,
      cart.items.length - 1,
    );
    setState(() => _focusedCartIndex = next);
    _focusCartShortcuts();
  }

  Future<void> _editFocusedCartItem(
      BuildContext context, CartProvider cart) async {
    if (cart.items.isEmpty) return;
    if (_actionsDialogOpen) return;
    _focusCartShortcuts();
    await _showCartItemActions(context, cart, cart.items[_safeCartIndex(cart)]);
  }

  Future<void> _deleteCartItem(
      CartProvider cart, Map<String, dynamic> item) async {
    if (cart.items.isEmpty) return;
    final index = cart.items.indexWhere(
      (cartItem) => cartItem['cartDocId'] == item['cartDocId'],
    );
    final cartDocId = item['cartDocId'] as String? ?? '';
    if (cartDocId.isEmpty || index < 0) return;

    await cart.removeItem(cartDocId);
    if (mounted) {
      setState(() {
        if (cart.items.isEmpty) {
          _focusedCartIndex = 0;
        } else {
          _focusedCartIndex = index.clamp(0, cart.items.length - 1);
        }
      });
    }
  }

  Future<void> _deleteFocusedCartItem(CartProvider cart) async {
    if (cart.items.isEmpty) return;
    await _deleteCartItem(cart, cart.items[_safeCartIndex(cart)]);
    if (!mounted) return;
    if (cart.items.isEmpty) {
      _navigateBackToPos();
      return;
    }
    _focusCartShortcuts();
  }

  Future<void> _editCartItemQuantity(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    await _showEditItemDialog(context, cart, item);
  }

  Future<void> _openProductBottomSheet(BuildContext context) async {
    if (_productSheetOpen) return;
    _productSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final size = MediaQuery.of(sheetContext).size;
          final isWide = size.width >= 900;
          final panelWidth = isWide ? size.width / 3 : size.width;
          final panelHeight = size.height * 0.82;

          return Align(
            alignment: Alignment.bottomRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isWide ? 360 : 0,
                maxWidth: isWide
                    ? panelWidth.clamp(360.0, 560.0).toDouble()
                    : panelWidth,
                maxHeight: panelHeight,
              ),
              child: const ProductListBottomSheet(),
            ),
          );
        },
      );
    } finally {
      _productSheetOpen = false;
      if (mounted) _focusCartShortcuts();
    }
  }

  Future<void> _showCartItemActions(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    if (_actionsDialogOpen) return;
    _actionsDialogOpen = true;

    final cartDocId = item['cartDocId'] as String? ?? '';
    final menuKey = _cartItemMenuKeys[cartDocId];
    final actions = [
      const _CartActionOption(
        value: 'add',
        label: 'Add More',
        icon: Icons.add_circle_outline,
        color: NovaColors.violet,
      ),
      const _CartActionOption(
        value: 'edit',
        label: 'Edit Qty',
        icon: Icons.edit_outlined,
        color: NovaColors.amber,
      ),
      _CartActionOption(
        value: 'delete',
        label: 'Remove',
        icon: Icons.delete_outline,
        color: NovaColors.danger,
        enabled: cartDocId.isNotEmpty,
      ),
    ];

    String? value;
    try {
      value = await showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cart actions',
        barrierColor: Colors.black12,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (dialogContext, _, __) => _CartItemActionsDialog(
          itemName: item['name']?.toString() ?? 'Item',
          actions: actions,
          anchorKey: menuKey,
        ),
      );
    } finally {
      _actionsDialogOpen = false;
    }

    if (!mounted || !context.mounted || value == null) {
      _focusCartShortcuts();
      return;
    }

    if (value == 'add') {
      await _openProductBottomSheet(context);
    } else if (value == 'edit') {
      if (_editDialogOpen) return;
      _editDialogOpen = true;
      try {
        await _editCartItemQuantity(context, cart, item);
      } finally {
        _editDialogOpen = false;
        if (mounted) _focusCartShortcuts();
      }
    } else if (value == 'delete') {
      await _deleteCartItem(cart, item);
      if (mounted) _focusCartShortcuts();
    }
  }

  void _navigateBackToPos() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/pos');
    }
  }

  @override
  void dispose() {
    _cashFocus.removeListener(_onCashFocusChange);
    _cashFocus.dispose();
    _checkoutShortcutFocus.dispose();
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(BuildContext context, CartProvider cart) async {
    if (cart.items.isEmpty) return;
    if (_paymentMethod == 'cash' &&
        _cashIsInsufficient(_tenderedAmount, cart.total)) {
      _noticeKey.currentState?.show(
        'Insufficient cash amount.',
        type: AppNoticeType.warning,
      );
      return;
    }
    if (_isSubmitting) return;

    _noticeKey.currentState?.clear();

    final changeAmount =
        _paymentMethod == 'cash' ? _tenderedAmount - cart.total : 0.0;
    final orderTotal = cart.total;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isSubmitting = true);

    try {
      final cartSnapshot = cart.items.map((item) {
        final qty = (item['qty'] as num?)?.toInt() ??
            (item['quantity'] as num?)?.toInt() ??
            1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        return <String, dynamic>{
          'name': item['name'] ?? 'Unknown',
          'qty': qty,
          'quantity': qty,
          'price': price,
          'unitPrice': price,
          'lineTotal': price * qty,
          if (item['productId'] != null) 'productId': item['productId'],
        };
      }).toList();

      final stockIssueMessage = await _validateStockBeforePlace(cartSnapshot);
      if (stockIssueMessage != null) {
        if (context.mounted) {
          _noticeKey.currentState?.showOutOfStock(stockIssueMessage);
        }
        return;
      }

      final order = await _orderService.createOrder(
        items: cartSnapshot,
        total: orderTotal,
        status: 'ready',
        customerName: _customerName,
        paymentMethod: _paymentMethod,
        tenderedAmount: _paymentMethod == 'cash' ? _tenderedAmount : 0.0,
        change: changeAmount,
      );
      if (!context.mounted) return;

      try {
        await ThermalPrinterService.instance.printReceiptAuto(
          ThermalReceiptData(
            companyName: 'Orion POS',
            phone: '+92-317-7921817',
            email: 'info@orion.com',
            website: 'www.orion.com',
            servedBy: auth.role,
            customerName: _customerName.trim().isEmpty
                ? 'Walk-in Customer'
                : _customerName.trim(),
            items: order.items,
            total: order.total,
            cash: order.tenderedAmount,
            change: order.change,
            tax: 0.0,
            paymentMethod: order.paymentMethod ?? _paymentMethod,
            orderNo: 'ORDER-${order.orderNumber}',
            date:
                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} '
                '${order.createdAt.hour.toString().padLeft(2, '0')}:'
                '${order.createdAt.minute.toString().padLeft(2, '0')}',
          ),
        );
      } catch (e) {
        debugPrint('Printing skipped or failed on this platform: $e');
      }

      cart.clear();

      if (mounted) {
        _checkoutShortcutFocus.unfocus();
        if (context.mounted) {
          _noticeKey.currentState?.showOrderSuccess(
            orderNo: order.orderNumber.toString(),
            total: orderTotal,
            paymentMethod: _paymentMethod,
            change: changeAmount,
          );
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted || !context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/pos', (route) => false);
        });
      }
    } catch (e) {
      if (!context.mounted) return;

      final errorMsg = e.toString().toLowerCase().contains('network') ||
              e.toString().toLowerCase().contains('internet') ||
              e.toString().toLowerCase().contains('connect') ||
              e.toString().toLowerCase().contains('timeout') ||
              e.toString().toLowerCase().contains('unavailable')
          ? 'No internet connection. Please check your connection and try again.'
          : 'Error: $e';

      _noticeKey.currentState?.show(
        errorMsg,
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _validateStockBeforePlace(
    List<Map<String, dynamic>> cartSnapshot,
  ) async {
    final issues = <String>[];

    for (final item in cartSnapshot) {
      final productId = item['productId']?.toString() ?? '';
      final name = item['name']?.toString() ?? 'Item';
      final requestedQty = (item['qty'] as num?)?.toInt() ??
          (item['quantity'] as num?)?.toInt() ??
          1;

      if (productId.isEmpty) {
        issues.add('$name: product mapping missing');
        continue;
      }

      try {
        final product = await _inventoryService.getProduct(productId);
        final available = product.stockQty;
        if (available <= 0) {
          issues.add('$name is out of stock');
        } else if (requestedQty > available) {
          issues.add(
            '$name: only $available available (requested $requestedQty)',
          );
        }
      } catch (_) {
        issues.add('Could not verify stock for $name');
      }
    }

    if (issues.isEmpty) return null;
    return issues.join('\n');
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: NovaColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: NovaColors.textTertiary, size: 16)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NovaColors.borderTertiary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: NovaColors.borderTertiary, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NovaColors.violet, width: 1.5),
      ),
      filled: true,
      fillColor: NovaColors.bgSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    final newQty = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => _EditQuantityDialog(
        itemName: item['name']?.toString() ?? 'Item',
        initialQty: (item['qty'] as num?)?.toInt() ?? 1,
        fieldDecoration: _fieldDecoration(
          'Quantity',
          icon: Icons.format_list_numbered,
        ),
      ),
    );

    if (newQty != null && newQty > 0) {
      await cart.updateItemQuantity(item['cartDocId'] as String, newQty);
    }
    if (mounted) {
      _focusCartShortcuts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (context, auth, child) {
      if (!auth.isAdmin && !auth.isCashier) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/pos');
        });
        return const Scaffold(
            backgroundColor: NovaColors.bgTertiary,
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)));
      }

      final userEmail = auth.user?.email ?? 'No Email';
      final userName = auth.user?.displayName ?? userEmail.split('@').first;
      final photoUrl = auth.user?.photoURL;

      return Scaffold(
        backgroundColor: NovaColors.bgTertiary,
        drawer: AppNavigationShell.isDesktop(context)
            ? null
            : AppNavigationDrawer(auth: auth, currentRoute: '/checkout'),
        appBar: AppNavigationAppBar(
          title: 'Checkout',
          icon: Icons.shopping_bag_outlined,
          photoUrl: photoUrl,
          userName: userName,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: AppNoticeHost(
          key: _noticeKey,
          child: Consumer<CartProvider>(
            builder: (context, cart, _) {
              return StreamBuilder<List<Product>>(
                stream: _productsStream,
                builder: (context, snapshot) {
                  final allProducts = snapshot.data ?? [];

                  return CheckoutKeyboardScope(
                    cashController: _cashController,
                    cashFocusNode: _cashFocus,
                    shortcutFocusNode: _checkoutShortcutFocus,
                    onCashChanged: (value) {
                      setState(() =>
                          _tenderedAmount = double.tryParse(value) ?? 0.0);
                    },
                    onBack: () {
                      _checkoutShortcutFocus.unfocus();
                      _navigateBackToPos();
                    },
                    onConfirm: () => _placeOrder(context, cart),
                    onEditFocusedItem: () =>
                        _editFocusedCartItem(context, cart),
                    onDeleteFocusedItem: () => _deleteFocusedCartItem(cart),
                    onArrowUp: () => _moveFocusedCartItem(cart, -1),
                    onArrowDown: () => _moveFocusedCartItem(cart, 1),
                    onSelectPaymentMethod: _selectPaymentMethod,
                    child: AppNavigationShell(
                      auth: auth,
                      currentRoute: '/checkout',
                      child: Builder(
                        builder: (noticeContext) {
                          final keyboardOpen =
                              MediaQuery.of(noticeContext).viewInsets.bottom >
                                  0;
                          final keyboardInset =
                              MediaQuery.of(noticeContext).viewInsets.bottom;

                          final List<String> stockAlerts = [];
                          for (var item in cart.items) {
                            final status = _getStockStatus(
                                item['productId'] ?? '', allProducts);
                            if (status != null) {
                              stockAlerts.add("${item['name']}: $status");
                            }
                          }

                          final stockAlertBanner = stockAlerts.isEmpty
                              ? const SizedBox.shrink()
                              : Container(
                                  margin:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFFDD99B)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              color: Color(0xFF7A4100),
                                              size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            'Inventory Alerts',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF7A4100),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ...stockAlerts.map(
                                        (msg) => Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '• $msg',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFA35A00),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                          final topForm = Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: NovaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: NovaColors.borderTertiary, width: 0.5),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  onChanged: (value) => _customerName = value,
                                  decoration: _fieldDecoration('Customer Name',
                                      icon: Icons.person_outline_rounded),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _paymentMethod,
                                  decoration: _fieldDecoration('Payment Method',
                                      icon: Icons.payment_outlined),
                                  dropdownColor: NovaColors.bgPrimary,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'cash', child: Text('Cash')),
                                    DropdownMenuItem(
                                        value: 'card', child: Text('Card')),
                                  ],
                                  onChanged: (value) =>
                                      _selectPaymentMethod(value ?? 'cash'),
                                ),
                                if (_paymentMethod == 'cash') ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                    focusNode: _cashFocus,
                                    controller: _cashController,
                                    textInputAction: TextInputAction.done,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (value) => setState(() {
                                      _tenderedAmount =
                                          double.tryParse(value) ?? 0.0;
                                    }),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: NovaColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: _fieldDecoration(
                                      'Cash Tendered',
                                      icon: Icons.money_rounded,
                                    ).copyWith(
                                      prefixText: 'Rs  ',
                                      prefixStyle: const TextStyle(
                                        color: NovaColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_tenderedAmount > 0 &&
                                      _cashIsInsufficient(
                                          _tenderedAmount, cart.total))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4, top: 6),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: NovaColors.danger,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Amount is less than total',
                                            style: TextStyle(
                                              color: NovaColors.danger,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_cashIsInsufficient(
                                              _tenderedAmount, cart.total)
                                          ? NovaColors.tealLight
                                          : NovaColors.dangerLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: !_cashIsInsufficient(
                                                _tenderedAmount, cart.total)
                                            ? NovaColors.teal
                                                .withValues(alpha: 0.3)
                                            : NovaColors.danger
                                                .withValues(alpha: 0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.change_circle_outlined,
                                              size: 15,
                                              color: !_cashIsInsufficient(
                                                      _tenderedAmount,
                                                      cart.total)
                                                  ? NovaColors.teal
                                                  : NovaColors.danger,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Change Due',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                                color: NovaColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Rs ${(_tenderedAmount - cart.total).toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: !_cashIsInsufficient(
                                                    _tenderedAmount, cart.total)
                                                ? NovaColors.teal
                                                : NovaColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );

                          final cartSection = Container(
                            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            decoration: BoxDecoration(
                              color: NovaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: NovaColors.borderTertiary, width: 0.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: const BoxDecoration(
                                    color: NovaColors.bgSecondary,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                  ),
                                  child: const Text('Cart Items',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (cart.items.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Center(
                                        child: Text('No items in cart',
                                            style: TextStyle(
                                                color:
                                                    NovaColors.textTertiary))),
                                  )
                                else
                                  ListView.separated(
                                    itemCount: cart.items.length,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 10),
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final item = cart.items[i];
                                      final name = item['name'] ?? 'Item';
                                      final qty = item['qty'] ?? 1;
                                      final productId =
                                          item['productId']?.toString() ?? '';
                                      final stockStatus = _getStockStatus(
                                          productId, allProducts);
                                      final isFocused =
                                          i == _safeCartIndex(cart);

                                      return InkWell(
                                        onTap: () => _selectCartItem(i),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isFocused
                                                ? NovaColors.violetLight
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(name,
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    if (stockStatus !=
                                                        null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        stockStatus,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: stockStatus
                                                                  .startsWith(
                                                                      'OUT')
                                                              ? NovaColors
                                                                  .danger
                                                              : NovaColors
                                                                  .amber,
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 4),
                                                    Text('Qty: $qty',
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: NovaColors
                                                                .textSecondary)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );

                          return ResponsiveCenter(
                            child: Column(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isWide =
                                          constraints.maxWidth >= 800;
                                      return ListView(
                                        padding: EdgeInsets.only(
                                            bottom: keyboardOpen
                                                ? keyboardInset + 12
                                                : 12),
                                        children: [
                                          stockAlertBanner,
                                          if (isWide)
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: topForm),
                                                const SizedBox(width: 8),
                                                Expanded(child: cartSection),
                                              ],
                                            )
                                          else ...[
                                            topForm,
                                            cartSection,
                                          ],
                                          const SizedBox(height: 8),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (!keyboardOpen)
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: NovaColors.bgPrimary,
                                      border: Border(
                                        top: BorderSide(
                                            color: NovaColors.borderTertiary,
                                            width: 0.5),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 20),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Rs ${cart.total.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: ElevatedButton(
                                            onPressed: () => _placeOrder(
                                                noticeContext, cart),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  NovaColors.violet,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                            child: const Text('Place Order',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    });
  }
}

class _CartItemActionsDialog extends StatefulWidget {
  final String itemName;
  final List<_CartActionOption> actions;
  final GlobalKey? anchorKey;

  const _CartItemActionsDialog({
    required this.itemName,
    required this.actions,
    this.anchorKey,
  });

  @override
  State<_CartItemActionsDialog> createState() => _CartItemActionsDialogState();
}

class _CartItemActionsDialogState extends State<_CartItemActionsDialog> {
  late final FocusNode _focusNode;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'CartItemActionsDialog');
    _selectedIndex = widget.actions.indexWhere((a) => a.enabled);
    if (_selectedIndex < 0) _selectedIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    if (widget.actions.isEmpty) return;
    var next = _selectedIndex;
    for (var i = 0; i < widget.actions.length; i++) {
      next = (next + delta) % widget.actions.length;
      if (next < 0) next = widget.actions.length - 1;
      if (widget.actions[next].enabled) {
        setState(() => _selectedIndex = next);
        return;
      }
    }
  }

  void _submitSelection() {
    if (widget.actions.isEmpty) return;
    final action = widget.actions[_selectedIndex];
    if (!action.enabled) return;
    Navigator.of(context, rootNavigator: false).pop(action.value);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _moveSelection(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveSelection(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _submitSelection();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context, rootNavigator: false).pop();
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const menuWidth = 320.0;
    const horizontalMargin = 12.0;
    const verticalMargin = 12.0;

    double left = (media.size.width - menuWidth) / 2;
    double top = media.size.height * 0.3;

    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    final anchorBox =
        widget.anchorKey?.currentContext?.findRenderObject() as RenderBox?;

    if (overlay != null && anchorBox != null) {
      final anchorTopLeft =
          anchorBox.localToGlobal(Offset.zero, ancestor: overlay);
      final anchorBottomRight = anchorBox.localToGlobal(
        anchorBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      );

      left = (anchorBottomRight.dx - menuWidth).clamp(
        horizontalMargin,
        media.size.width - menuWidth - horizontalMargin,
      );
      top = (anchorBottomRight.dy + 6).clamp(
        verticalMargin,
        media.size.height - 240,
      );
      if (top > media.size.height - 220) {
        top = (anchorTopLeft.dy - 196).clamp(
          verticalMargin,
          media.size.height - 220,
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context, rootNavigator: false).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: menuWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NovaColors.borderSecondary),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: NovaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use arrow keys and Enter',
                        style: TextStyle(
                          fontSize: 12,
                          color: NovaColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < widget.actions.length; i++)
                        _CartActionTile(
                          action: widget.actions[i],
                          selected: i == _selectedIndex,
                          onTap: widget.actions[i].enabled
                              ? () =>
                                  Navigator.of(context, rootNavigator: false)
                                      .pop(widget.actions[i].value)
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartActionTile extends StatelessWidget {
  final _CartActionOption action;
  final bool selected;
  final VoidCallback? onTap;

  const _CartActionTile({
    required this.action,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = action.enabled ? action.color : NovaColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? NovaColors.violetLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? NovaColors.violet : NovaColors.borderSecondary,
            ),
          ),
          child: Row(
            children: [
              Icon(action.icon, color: foreground, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: action.enabled
                        ? NovaColors.textPrimary
                        : NovaColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
