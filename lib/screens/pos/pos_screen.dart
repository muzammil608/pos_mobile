import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard/pos_keyboard_system.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/utils/clickable_cursor.dart';
import '../../core/utils/app_notice.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/printer/thermal_printer_service.dart';
import '../../services/pocketbase/order_service.dart';
import '../../services/pocketbase/inventory_service.dart';
import '../../services/pocketbase/product_service.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/responsive_layout.dart';
import '../cart/product_list_bottom_sheet.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

String _itemEmoji(String name) {
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

Color _itemBgColor(String name) {
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
      default:
        return KeyEventResult.ignored;
    }
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

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  ProductService? _productService;
  OrderService? _orderService;
  InventoryService? _inventoryService;

  Stream<List<Product>>? _productsStream;
  Stream<OrderRecordSnapshot>? _ordersStream;

  List<Product>? _lastProducts;
  OrderRecordSnapshot? _lastOrders;
  String? _cachedOwnerId;

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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final FocusNode _cashFocusNode = FocusNode(debugLabel: 'PosCashTendered');
  final FocusNode _checkoutShortcutFocusNode =
      FocusNode(debugLabel: 'PosCheckoutShortcuts');
  final ScrollController _productScrollController = ScrollController();
  final GlobalKey<PosSearchBarState> _searchBarKey =
      GlobalKey<PosSearchBarState>();
  final GlobalKey<PosCategoryChipsState> _categoryChipsKey =
      GlobalKey<PosCategoryChipsState>();
  final Map<String, GlobalKey> _cartItemKeys = {};
  final GlobalKey<AppNoticeHostState> _noticeKey =
      GlobalKey<AppNoticeHostState>();
  final Map<String, GlobalKey> _cartItemMenuKeys = {};
  final Map<int, GlobalKey> _productItemKeys = {};

  late AnimationController _pulseController;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _customerName = '';
  String _paymentMethod = 'cash';

  int _focusedProductIndex = -1;
  int _currentCrossAxisCount = 2;
  List<Product> _lastFilteredProducts = [];
  int _focusedCartIndex = 0;

  double _tenderedAmount = 0.0;
  bool _isSubmitting = false;
  bool _actionsDialogOpen = false;
  bool _productSheetOpen = false;
  bool _checkoutKeyboardMode = false;

  bool _readyOrdersSheetOpen = false;

  String _normalizeSearch(String value) => value.toLowerCase().trim();

  int _matchScore(Product product, String normalizedQuery) {
    final name = product.name.toLowerCase();
    final category = product.category.toLowerCase();

    if (name == normalizedQuery) return 0;
    if (name.startsWith(normalizedQuery)) return 1;
    if (name.contains(' $normalizedQuery')) return 2;
    if (category == normalizedQuery) return 3;
    if (category.startsWith(normalizedQuery)) return 4;
    if (name.contains(normalizedQuery)) return 5;
    if (category.contains(normalizedQuery)) return 6;
    return 99;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _registerHotkeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppMobileBottomNavBar.autoShowReadyOrders) {
        AppMobileBottomNavBar.autoShowReadyOrders = false;
        _showReadyOrdersSheet(context);
      }
    });
  }

  Future<void> _registerHotkeys() async {
    await PosHotkeyRegistry.register(
      onF1NewOrder: () {
        if (mounted) _startNewOrder();
      },
      onF2Cart: () {
        if (!mounted) return;
        _showReadyOrdersSheet(context);
      },
      onF3HoldOrder: () {
        if (mounted) _clearCurrentOrderWithUndo();
      },
      onF4AddCustomer: () {
        if (mounted) _openProducts();
      },
      onF5Refresh: () {
        if (mounted) setState(() {});
      },
      onF6Inventory: () {
        if (mounted) _openInventory();
      },
      onCtrlF: () {
        _searchBarKey.currentState?.requestFocus();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.ownerId.isNotEmpty && auth.ownerId != _cachedOwnerId) {
      _cachedOwnerId = auth.ownerId;
      _productService = ProductService(auth.ownerId);
      _orderService = OrderService(auth.ownerId);
      _inventoryService = InventoryService(auth.ownerId);

      _productsStream = _productService?.streamProducts.asBroadcastStream();
      _ordersStream = _orderService?.getOrders().asBroadcastStream();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _cashController.dispose();
    _cashFocusNode.dispose();
    _checkoutShortcutFocusNode.dispose();
    _productScrollController.dispose();
    _pulseController.dispose();
    PosHotkeyRegistry.unregisterAll();
    super.dispose();
  }

  void _onArrowDown() {
    if (_isCheckoutKeyboardActive) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) {
        _focusPosForNewOrder();
        return;
      }
      _moveFocusedCartItem(cart, 1);
      return;
    }

    if (_lastFilteredProducts.isEmpty) return;
    final step = _currentCrossAxisCount;
    final nextIndex = _focusedProductIndex + step;
    if (nextIndex < _lastFilteredProducts.length) {
      _setFocusedProductIndex(nextIndex);
    }
  }

  void _onArrowUp() {
    if (_isCheckoutKeyboardActive) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) {
        _focusPosForNewOrder();
        return;
      }
      _moveFocusedCartItem(cart, -1);
      return;
    }

    if (_lastFilteredProducts.isEmpty) return;
    final step = _currentCrossAxisCount;
    final nextIndex = _focusedProductIndex - step;
    if (nextIndex >= 0) {
      _setFocusedProductIndex(nextIndex);
    }
  }

  void _onArrowRight() {
    if (_isCheckoutKeyboardActive) return;
    if (_lastFilteredProducts.isEmpty) return;
    _setFocusedProductIndex(
      (_focusedProductIndex + 1).clamp(0, _lastFilteredProducts.length - 1),
    );
  }

  void _onArrowLeft() {
    if (_isCheckoutKeyboardActive) return;
    if (_lastFilteredProducts.isEmpty) return;
    _setFocusedProductIndex(
      (_focusedProductIndex - 1).clamp(0, _lastFilteredProducts.length - 1),
    );
  }

  void _onConfirmFocusedItem() {
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (_isCheckoutKeyboardActive) {
      _placeOrder(context, cart).then((success) {
        if (!mounted || !success) return;
        _focusPosForNewOrder();
      });
      return;
    }

    if (_focusedProductIndex < 0 ||
        _focusedProductIndex >= _lastFilteredProducts.length) {
      return;
    }
    final product = _lastFilteredProducts[_focusedProductIndex];
    _addProductWithQtyDialog(product);
  }

  void _onDeleteFocusedItem() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    _deleteFocusedCartItem(cart);
  }

  void _onEditFocusedItem() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    _showCartItemActions(context, cart, cart.items[_safeCartIndex(cart)]);
  }

  void _setFocusedProductIndex(int index) {
    if (!mounted) return;
    setState(() {
      _focusedProductIndex = index;
      _checkoutKeyboardMode = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedProductIntoView(index);
    });
  }

  void _scrollFocusedProductIntoView([int? index]) {
    final focusedIndex = index ?? _focusedProductIndex;
    final context = _productItemKeys[focusedIndex]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.18,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUndoCart() {
    final stack = CartUndoStack.instance;
    if (stack.canUndo) {
      final description = stack.lastDescription ?? 'last action';
      stack.undo();
      if (mounted) {
        _noticeKey.currentState?.show(
          'Undone: $description',
          type: AppNoticeType.info,
        );
      }
    }
  }

  void _onCheckout() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    _focusCheckoutForOrder(cart);
  }

  void _onClearCart() {
    _clearCurrentOrderWithUndo();
    _resetCheckoutForm();
  }

  void _clearCurrentOrderWithUndo() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    final snapshot = List<Map<String, dynamic>>.from(cart.items);
    CartUndoStack.instance.push('Clear cart', () {
      for (final item in snapshot) {
        cart.addItem(item);
      }
    });
    cart.clear();
  }

  void _startNewOrder() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isNotEmpty) {
      _clearCurrentOrderWithUndo();
    }
    _searchBarKey.currentState?.clear();
    _resetCheckoutForm();
  }

  void _resetCheckoutForm() {
    _customerName = '';
    _customerNameController.clear();
    _paymentMethod = 'cash';
    _tenderedAmount = 0.0;
    _cashController.clear();
    _focusedCartIndex = 0;
    _actionsDialogOpen = false;
    _checkoutKeyboardMode = false;
  }

  void _focusCheckoutForOrder(CartProvider cart) {
    if (cart.items.isEmpty) return;
    setState(() {
      _focusedCartIndex = cart.items.length - 1;
      _checkoutKeyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cashFocusNode.requestFocus();
    });
  }

  void _focusPosForNewOrder() {
    setState(() {
      _checkoutKeyboardMode = false;
      _focusedCartIndex = 0;
    });
    _cashFocusNode.unfocus();
    _checkoutShortcutFocusNode.unfocus();
  }

  void _openProducts() {
    Navigator.pushNamed(context, '/products');
  }

  void _openInventory() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      _noticeKey.currentState?.show(
        'Inventory is available for admins.',
        type: AppNoticeType.warning,
      );
      return;
    }
    Navigator.pushNamed(context, '/inventory');
  }

  Future<void> _addProductWithQtyDialog(Product product) async {
    final qty = await _showQtyDialog(context, product.name, product.price);
    if (qty != null && qty > 0 && mounted) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final productMap = product.toMap();
      productMap['id'] = product.id;
      productMap['qty'] = qty;
      await cart.addItem(productMap);

      CartUndoStack.instance.push('Add ${product.name}', () {
        final addedItem = cart.items.lastWhere(
          (item) => item['productId'] == product.id,
          orElse: () => const <String, dynamic>{},
        );
        final cartDocId = addedItem['cartDocId']?.toString();
        if (cartDocId != null && cartDocId.isNotEmpty) {
          cart.removeItem(cartDocId);
        }
      });
    }

    if (mounted) {
      _searchBarKey.currentState?.clear();
    }
  }

  int _safeCartIndex(CartProvider cart) {
    if (cart.items.isEmpty) return 0;
    return _focusedCartIndex.clamp(0, cart.items.length - 1);
  }

  bool get _isCheckoutKeyboardActive {
    final searchHasFocus = _searchBarKey.currentState?.hasFocus ?? false;
    if (searchHasFocus) return false;
    return _checkoutKeyboardMode ||
        _checkoutShortcutFocusNode.hasFocus ||
        _cashFocusNode.hasFocus;
  }

  void _moveFocusedCartItem(CartProvider cart, int direction) {
    if (cart.items.isEmpty) {
      _focusPosForNewOrder();
      return;
    }
    final next = (_safeCartIndex(cart) + direction).clamp(
      0,
      cart.items.length - 1,
    );
    setState(() {
      _focusedCartIndex = next;
      _checkoutKeyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkoutShortcutFocusNode.requestFocus();
    });
  }

  void _selectCartItem(int index) {
    setState(() {
      _focusedCartIndex = index;
      _checkoutKeyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkoutShortcutFocusNode.requestFocus();
    });
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

  void _selectPaymentMethod(String method) {
    if (method != 'cash' && method != 'card') return;

    setState(() {
      _checkoutKeyboardMode = true;
      _paymentMethod = method;
      if (method != 'cash') {
        _cashController.clear();
        _tenderedAmount = 0.0;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (method == 'cash') {
        _cashFocusNode.requestFocus();
      } else {
        _checkoutShortcutFocusNode.requestFocus();
      }
    });
  }

  Future<void> _showEditItemDialog(
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
  }

  Future<void> _deleteCartItem(
    CartProvider cart,
    Map<String, dynamic> item,
  ) async {
    final cartDocId = item['cartDocId'] as String? ?? '';
    if (cartDocId.isEmpty) return;

    CartUndoStack.instance.push('Remove ${item['name'] ?? 'item'}', () {
      cart.addItem(item);
    });
    await cart.removeItem(cartDocId);
  }

  Future<void> _deleteFocusedCartItem(CartProvider cart) async {
    if (cart.items.isEmpty) return;
    await _deleteCartItem(cart, cart.items[_safeCartIndex(cart)]);
    if (!mounted) return;
    if (cart.items.isEmpty) {
      _focusPosForNewOrder();
    }
  }

  Future<void> _openProductBottomSheet(BuildContext context) async {
    if (_productSheetOpen) return;
    _productSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
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
      if (mounted) {
        _checkoutShortcutFocusNode.requestFocus();
      }
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

    if (!mounted || !context.mounted || value == null) return;
    if (value == 'add') {
      await _openProductBottomSheet(context);
    } else if (value == 'edit') {
      await _showEditItemDialog(cart, item);
    } else if (value == 'delete') {
      await _deleteCartItem(cart, item);
      if (!mounted) return;
      if (cart.items.isEmpty) {
        _focusPosForNewOrder();
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
        final product = await _inventoryService!.getProduct(productId);
        final available = product.stockQty;
        if (available <= 0) {
          issues.add('$name is out of stock');
        } else if (requestedQty > available) {
          issues.add(
              '$name has only $available in stock (requested $requestedQty)');
        }
      } catch (_) {
        issues.add('Could not verify stock for $name');
      }
    }

    if (issues.isEmpty) return null;
    return 'Cannot place order:\n${issues.join('\n')}';
  }

  Future<bool> _placeOrder(BuildContext context, CartProvider cart) async {
    if (cart.items.isEmpty) return false;
    if (_paymentMethod == 'cash' &&
        _cashIsInsufficient(_tenderedAmount, cart.total)) {
      _noticeKey.currentState?.show(
        'Insufficient cash amount.',
        type: AppNoticeType.warning,
      );
      return false;
    }
    if (_isSubmitting) return false;
    final changeAmount =
        _paymentMethod == 'cash' ? _tenderedAmount - cart.total : 0.0;
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
        _noticeKey.currentState?.showOutOfStock(stockIssueMessage);
        return false;
      }

      final order = await _orderService!.createOrder(
        items: cartSnapshot,
        total: cart.total,
        status: 'ready',
        customerName: _customerName,
        paymentMethod: _paymentMethod,
        tenderedAmount: _paymentMethod == 'cash' ? _tenderedAmount : 0.0,
        change: changeAmount,
      );
      if (!mounted) return false;

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

      await cart.clear();
      _resetCheckoutForm();
      _noticeKey.currentState?.showOrderSuccess(
        orderNo: order.orderNumber.toString(),
        total: order.total,
        paymentMethod: _paymentMethod,
        change: changeAmount,
      );
      _focusPosForNewOrder();
      return true;
    } catch (e) {
      final errorMsg = e.toString().toLowerCase().contains('network') ||
              e.toString().toLowerCase().contains('internet') ||
              e.toString().toLowerCase().contains('connect') ||
              e.toString().toLowerCase().contains('timeout') ||
              e.toString().toLowerCase().contains('unavailable')
          ? 'No internet connection. Please check your connection and try again.'
          : 'Error: $e';

      if (context.mounted) {
        _noticeKey.currentState?.show(
          errorMsg,
          type: AppNoticeType.error,
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleSearchSubmitted(
    String value,
  ) async {
    if (value.trim().isEmpty) return;

    if (_lastFilteredProducts.isNotEmpty) {
      final index = _focusedProductIndex >= 0 &&
              _focusedProductIndex < _lastFilteredProducts.length
          ? _focusedProductIndex
          : 0;
      final selectedProduct = _lastFilteredProducts[index];
      await _addProductWithQtyDialog(selectedProduct);
    }
  }

  Future<int?> _showQtyDialog(
      BuildContext context, String productName, double price) async {
    int qty = 1;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final isDesktop = screenWidth >= 768;

        return Dialog(
          insetPadding: isDesktop
              ? EdgeInsets.symmetric(
                  horizontal: (screenWidth - 400) / 2,
                  vertical: 80,
                )
              : const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: NovaColors.bgPrimary,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 400 : double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                        child: const Icon(Icons.add_shopping_cart_rounded,
                            color: NovaColors.violet, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(Icons.close_rounded,
                            color: NovaColors.textTertiary, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rs ${price.toStringAsFixed(0)} / item',
                    style: const TextStyle(
                        fontSize: 13, color: NovaColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) => qty = int.tryParse(value) ?? 1,
                    onSubmitted: (_) => Navigator.pop(dialogContext, qty),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                      labelStyle: const TextStyle(
                          color: NovaColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.format_list_numbered,
                          color: NovaColors.violet, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: NovaColors.borderTertiary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: NovaColors.borderTertiary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: NovaColors.violet, width: 1.5),
                      ),
                      filled: true,
                      fillColor: NovaColors.bgSecondary,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(
                                color: NovaColors.borderSecondary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  color: NovaColors.textSecondary,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, qty),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NovaColors.violet,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Add to Cart',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _readyOrderCount(AsyncSnapshot<OrderRecordSnapshot> snapshot) {
    if (!snapshot.hasData) return 0;
    return snapshot.data!.docs
        .where((doc) => doc.data()['status'] == 'ready')
        .length;
  }

  Future<void> _completeReadyOrder({
    required BuildContext sheetContext,
    required BuildContext rootContext,
    required OrderRecordDocument doc,
  }) async {
    final data = doc.data();
    final orderId = doc.id;
    final customerName = data['customerName']?.toString().trim();
    final items = List<Map<String, dynamic>>.from(
      (data['items'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    Navigator.pop(sheetContext);
    await _orderService?.updateStatus(orderId, 'completed');
    if (!rootContext.mounted) return;

    final orderNumber = (data['orderNumber'] as num?)?.toInt() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final tendered = (data['tenderedAmount'] as num?)?.toDouble() ?? total;
    final change = (data['change'] as num?)?.toDouble() ?? 0.0;
    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is DateTime
        ? rawCreatedAt
        : (rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null);
    final localCreatedAt = createdAt?.toLocal();
    final date = localCreatedAt != null
        ? '${localCreatedAt.day}/${localCreatedAt.month}/${localCreatedAt.year} '
            '${localCreatedAt.hour.toString().padLeft(2, '0')}:'
            '${localCreatedAt.minute.toString().padLeft(2, '0')}'
        : '';
    final servedBy = Provider.of<AuthProvider>(rootContext, listen: false).role;

    await showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) => ReceiptDialog(
        companyName: 'Orion POS',
        phone: '+92-317-7921817',
        email: 'info@orion.com',
        website: 'www.orion.com',
        servedBy: servedBy,
        customerName: customerName ?? 'Walk-in Customer',
        items: items,
        total: total,
        cash: tendered,
        change: change,
        tax: 0.0,
        paymentMethod: data['paymentMethod'] ?? 'cash',
        orderNo: 'ORDER-$orderNumber',
        date: date,
      ),
    );
  }

  Future<void> _showReadyOrdersSheet(BuildContext context) async {
    if (_readyOrdersSheetOpen) return;
    _readyOrdersSheetOpen = true;

    final rootContext = context;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return GestureDetector(
            onTap: () => Navigator.pop(sheetContext),
            behavior: HitTestBehavior.translucent,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Container(
                    height: MediaQuery.of(sheetContext).size.height * 0.85,
                    decoration: const BoxDecoration(
                      color: NovaColors.bgSecondary,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 2),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: NovaColors.borderSecondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: NovaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: NovaColors.borderTertiary, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: NovaColors.tealLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: NovaColors.teal,
                                      size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ready to Collect',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: NovaColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Tap Print & Complete to close order',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: NovaColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StreamBuilder<OrderRecordSnapshot>(
                                  stream: _ordersStream,
                                  initialData: _lastOrders,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      _lastOrders = snapshot.data;
                                    }
                                    if (_orderService == null) {
                                      return const SizedBox.shrink();
                                    }
                                    if (snapshot.hasError ||
                                        snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                      return const SizedBox.shrink();
                                    }
                                    final count = _readyOrderCount(snapshot);
                                    if (count == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: NovaColors.tealLight,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: NovaColors.teal,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: StreamBuilder<OrderRecordSnapshot>(
                              stream: _ordersStream,
                              initialData: _lastOrders,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  _lastOrders = snapshot.data;
                                }
                                if (_orderService == null) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        color: NovaColors.violet),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Error: ${snapshot.error}',
                                      style: const TextStyle(
                                          color: NovaColors.textSecondary),
                                    ),
                                  );
                                }
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        color: NovaColors.violet),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return _emptyOrdersView();
                                }

                                final readyDocs =
                                    snapshot.data!.docs.where((doc) {
                                  return doc.data()['status'] == 'ready';
                                }).toList();

                                readyDocs.sort((a, b) {
                                  final rawADate = a.data()['createdAt'];
                                  final aDate = rawADate is DateTime
                                      ? rawADate
                                      : (rawADate is String
                                          ? DateTime.tryParse(rawADate)
                                          : null);
                                  final rawBDate = b.data()['createdAt'];
                                  final bDate = rawBDate is DateTime
                                      ? rawBDate
                                      : (rawBDate is String
                                          ? DateTime.tryParse(rawBDate)
                                          : null);
                                  final aMs =
                                      aDate?.millisecondsSinceEpoch ?? 0;
                                  final bMs =
                                      bDate?.millisecondsSinceEpoch ?? 0;
                                  return bMs.compareTo(aMs);
                                });

                                if (readyDocs.isEmpty) {
                                  return _emptyOrdersView();
                                }

                                return Shortcuts(
                                  shortcuts: const {
                                    SingleActivator(LogicalKeyboardKey.enter):
                                        ConfirmItemIntent(),
                                    SingleActivator(
                                            LogicalKeyboardKey.numpadEnter):
                                        ConfirmItemIntent(),
                                  },
                                  child: Actions(
                                    actions: {
                                      ConfirmItemIntent:
                                          CallbackAction<ConfirmItemIntent>(
                                        onInvoke: (_) {
                                          _completeReadyOrder(
                                            sheetContext: sheetContext,
                                            rootContext: rootContext,
                                            doc: readyDocs.first,
                                          );
                                          return null;
                                        },
                                      ),
                                    },
                                    child: Focus(
                                      autofocus: true,
                                      child: ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 24),
                                        itemCount: readyDocs.length,
                                        itemBuilder: (context, index) {
                                          final doc = readyDocs[index];
                                          final data = doc.data();

                                          final orderLabel =
                                              '#${data['orderNumber'] ?? doc.id.substring(0, 6)}';
                                          final items =
                                              List<Map<String, dynamic>>.from(
                                            (data['items'] as List? ?? []).map(
                                              (item) =>
                                                  Map<String, dynamic>.from(
                                                      item as Map),
                                            ),
                                          );

                                          return _ReadyOrderCard(
                                            orderLabel: orderLabel,
                                            items: items,
                                            total: (data['total'] as num?)
                                                    ?.toDouble() ??
                                                0,
                                            index: index,
                                            onComplete: () =>
                                                _completeReadyOrder(
                                              sheetContext: sheetContext,
                                              rootContext: rootContext,
                                              doc: doc,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
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
    } finally {
      if (mounted) {
        setState(() => _readyOrdersSheetOpen = false);
      }
    }
  }

  Widget _emptyOrdersView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NovaColors.bgSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: NovaColors.borderTertiary),
              ),
              child: const Icon(Icons.coffee_outlined,
                  size: 40, color: NovaColors.textTertiary),
            ),
            const SizedBox(height: 14),
            const Text('No ready orders yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: NovaColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('New orders will appear here',
                style: TextStyle(fontSize: 13, color: NovaColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  int _crossAxisCount(double width) {
    if (width < 380) {
      return 1;
    }
    return ResponsiveLayout.productColumns(width);
  }

  List<String> _getCategories(List<Product> products) {
    final cats = products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  Widget _buildMobileCartBar(CartProvider cart) {
    if (cart.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = cart.items.length;
    final total = cart.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: CafeColors.headerGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: NovaColors.violet.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onCheckout,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$itemCount Item${itemCount == 1 ? "" : "s"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Rs ${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'Go to Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CartProvider>(
      builder: (context, auth, cart, child) {
        if (auth.user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/', (route) => false);
          });
          return const Scaffold(
              backgroundColor: NovaColors.bgTertiary,
              body: Center(
                  child: CircularProgressIndicator(color: NovaColors.violet)));
        }

        final user = auth.user!;
        final userEmail = user.email;
        final userName = user.displayName ?? userEmail.split('@').first;
        final photoUrl = user.photoURL;

        final isMobileUI = !AppNavigationShell.isDesktop(context);

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          resizeToAvoidBottomInset: isMobileUI ? true : false,
          drawer: isMobileUI
              ? null
              : (AppNavigationShell.isDesktop(context)
                  ? null
                  : AppNavigationDrawer(auth: auth, currentRoute: '/pos')),
          appBar: isMobileUI
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(88),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: CafeColors.headerGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x22111111),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Row(
                                  children: [
                                    Icon(Icons.wifi,
                                        color: Colors.white70, size: 12),
                                    SizedBox(width: 4),
                                    Icon(Icons.signal_cellular_4_bar,
                                        color: Colors.white70, size: 12),
                                    SizedBox(width: 4),
                                    Icon(Icons.battery_std,
                                        color: Colors.white70, size: 12),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.point_of_sale_rounded,
                                      color: Colors.white70, size: 22),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Order Station',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  ExcludeFocus(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StreamBuilder<OrderRecordSnapshot>(
                                          stream: _ordersStream,
                                          initialData: _lastOrders,
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) {
                                              _lastOrders = snapshot.data;
                                            }
                                            final readyCount =
                                                _readyOrderCount(snapshot);
                                            return IconButton(
                                              tooltip: 'Ready Orders',
                                              onPressed: () =>
                                                  _showReadyOrdersSheet(
                                                      context),
                                              icon: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Icon(
                                                    readyCount > 0
                                                        ? Icons
                                                            .notifications_active_rounded
                                                        : Icons
                                                            .notifications_outlined,
                                                    color: readyCount > 0
                                                        ? Colors.white
                                                        : Colors.white70,
                                                    size: 22,
                                                  ),
                                                  if (readyCount > 0)
                                                    Positioned(
                                                      top: -3,
                                                      right: -3,
                                                      child: Container(
                                                        width: 14,
                                                        height: 14,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              NovaColors.teal,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                              color: CafeColors
                                                                  .flame,
                                                              width: 1.5),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '$readyCount',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 7,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Logout',
                                          icon: const Icon(Icons.logout_rounded,
                                              color: Colors.white70),
                                          onPressed: () async {
                                            final isMobile =
                                                MediaQuery.sizeOf(context)
                                                        .width <
                                                    600;
                                            bool confirm = true;
                                            if (!isMobile) {
                                              confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogCtx) =>
                                                        AlertDialog(
                                                      title:
                                                          const Text('Logout'),
                                                      content: const Text(
                                                          'Are you sure you want to logout?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  dialogCtx,
                                                                  false),
                                                          child: const Text(
                                                              'Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  dialogCtx,
                                                                  true),
                                                          style: TextButton
                                                              .styleFrom(
                                                            foregroundColor:
                                                                Colors.red,
                                                          ),
                                                          child: const Text(
                                                              'Logout'),
                                                        ),
                                                      ],
                                                    ),
                                                  ) ??
                                                  false;
                                            }
                                            if (confirm && context.mounted) {
                                              await Provider.of<AuthProvider>(
                                                      context,
                                                      listen: false)
                                                  .logout();
                                              if (context.mounted) {
                                                Navigator.of(context)
                                                    .pushNamedAndRemoveUntil(
                                                  '/login',
                                                  (route) => false,
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 12, left: 4),
                                          child: AppUserAvatar(
                                            photoUrl: photoUrl,
                                            userName: userName,
                                            radius: 16,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : AppNavigationAppBar(
                  title: 'Order Station',
                  icon: Icons.point_of_sale_rounded,
                  photoUrl: photoUrl,
                  userName: userName,
                  actions: [
                    if (_isDesktop)
                      IconButton(
                        tooltip: 'Keyboard Shortcuts (?)',
                        onPressed: () => PosShortcutHelp.show(context),
                        icon: const Icon(Icons.keyboard_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    StreamBuilder<OrderRecordSnapshot>(
                      stream: _ordersStream,
                      initialData: _lastOrders,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          _lastOrders = snapshot.data;
                        }
                        final readyCount = _readyOrderCount(snapshot);
                        return IconButton(
                          tooltip: 'Ready Orders  (F2)',
                          onPressed: () => _showReadyOrdersSheet(context),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                readyCount > 0
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_outlined,
                                color: readyCount > 0
                                    ? NovaColors.violet
                                    : NovaColors.textSecondary,
                                size: 22,
                              ),
                              if (readyCount > 0)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: NovaColors.teal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: NovaColors.bgPrimary,
                                          width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$readyCount',
                                        style: const TextStyle(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
          bottomNavigationBar: isMobileUI
              ? AppMobileBottomNavBar(
                  currentIndex: 0,
                  onPosTap: () {
                    if (_checkoutKeyboardMode) {
                      setState(() {
                        _checkoutKeyboardMode = false;
                      });
                    }
                  },
                )
              : null,
          body: AppNavigationShell(
            auth: auth,
            currentRoute: '/pos',
            child: AppNoticeHost(
              key: _noticeKey,
              child: PosKeyboardScope(
                searchBarKey: _searchBarKey,
                categoryChipsKey: _categoryChipsKey,
                onNewOrder: _startNewOrder,
                onCheckout: _onCheckout,
                onReadyOrders: () => _showReadyOrdersSheet(context),
                onProducts: _openProducts,
                onClearCart: _onClearCart,
                onDeleteFocusedItem: _onDeleteFocusedItem,
                onEditFocusedItem: _onEditFocusedItem,
                onUndoCart: _onUndoCart,
                onConfirmFocusedItem: _onConfirmFocusedItem,
                onArrowUp: _onArrowUp,
                onArrowDown: _onArrowDown,
                onArrowLeft: _onArrowLeft,
                onArrowRight: _onArrowRight,
                onRefresh: () => setState(() {}),
                onEscape: () {
                  if (_checkoutKeyboardMode) {
                    _focusPosForNewOrder();
                  } else {
                    _searchBarKey.currentState?.clear();
                  }
                },
                onSelectPaymentMethod: _selectPaymentMethod,
                onInventory: _openInventory,
                child: StreamBuilder<List<Product>>(
                  stream: _productsStream ??
                      Stream<List<Product>>.value(_lastProducts ?? []),
                  initialData: _lastProducts,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _lastProducts = snapshot.data;
                    }

                    final allProducts = snapshot.data ?? [];
                    final categories = _getCategories(allProducts);

                    final normalizedQuery = _normalizeSearch(_searchQuery);

                    final filteredProducts = allProducts.where((product) {
                      final name = product.name.toLowerCase();
                      final category = product.category.toLowerCase();
                      final matchSearch = normalizedQuery.isEmpty ||
                          name.contains(normalizedQuery) ||
                          category.contains(normalizedQuery);
                      final matchCategory = _selectedCategory == 'All' ||
                          product.category == _selectedCategory;
                      return matchSearch && matchCategory;
                    }).toList();

                    if (normalizedQuery.isNotEmpty) {
                      filteredProducts.sort((a, b) {
                        final scoreCompare = _matchScore(a, normalizedQuery)
                            .compareTo(_matchScore(b, normalizedQuery));
                        if (scoreCompare != 0) {
                          return scoreCompare;
                        }
                        return a.name.toLowerCase().compareTo(
                              b.name.toLowerCase(),
                            );
                      });
                    }

                    _lastFilteredProducts = filteredProducts;
                    if (_lastFilteredProducts.isEmpty) {
                      _focusedProductIndex = -1;
                    } else if (_focusedProductIndex < 0 ||
                        _focusedProductIndex >= _lastFilteredProducts.length) {
                      _focusedProductIndex = 0;
                    }

                    return LayoutBuilder(
                      builder: (context, viewportConstraints) {
                        final screenWidth = viewportConstraints.maxWidth;

                        final isWide = screenWidth >= 800;

                        final isDesktop = screenWidth >= 1100;

                        final cartFlex = screenWidth >= 1100 ? 1 : 3;
                        final productFlex = screenWidth >= 1100 ? 3 : 4;

                        Widget buildProductArea({
                          required EdgeInsets searchPadding,
                          required EdgeInsets chipPadding,
                          required EdgeInsets listPadding,
                          required bool includeFooter,
                        }) {
                          Widget buildProductList() {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: NovaColors.violet),
                              );
                            }
                            if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Error loading products',
                                  style: TextStyle(
                                    color: NovaColors.textSecondary,
                                  ),
                                ),
                              );
                            }
                            if (filteredProducts.isEmpty) {
                              return Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: NovaColors.bgSecondary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: NovaColors.borderTertiary,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.coffee_maker_outlined,
                                          size: 40,
                                          color: NovaColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No items match "$_searchQuery"'
                                            : 'No items in this category',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: NovaColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobile = constraints.maxWidth < 600;
                                _currentCrossAxisCount = isMobile
                                    ? 1
                                    : _crossAxisCount(constraints.maxWidth);

                                if (isMobile) {
                                  return ListView.builder(
                                    controller: _productScrollController,
                                    padding: listPadding,
                                    itemCount: filteredProducts.length,
                                    itemBuilder: (_, index) {
                                      final product = filteredProducts[index];
                                      final isFocused =
                                          _focusedProductIndex == index;
                                      return _ProductListTile(
                                        key: _productItemKeys.putIfAbsent(
                                          index,
                                          GlobalKey.new,
                                        ),
                                        product: product,
                                        isFocused: isFocused,
                                        onTap: () =>
                                            _addProductWithQtyDialog(product),
                                      );
                                    },
                                  );
                                }

                                return GridView.builder(
                                  controller: _productScrollController,
                                  padding: listPadding,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        _crossAxisCount(constraints.maxWidth),
                                    childAspectRatio: constraints.maxWidth < 380
                                        ? 1.35
                                        : 0.78,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (_, index) {
                                    final product = filteredProducts[index];
                                    final isFocused =
                                        _focusedProductIndex == index;
                                    return _ProductCard(
                                      key: _productItemKeys.putIfAbsent(
                                        index,
                                        GlobalKey.new,
                                      ),
                                      product: product,
                                      isFocused: isFocused,
                                      onTap: () =>
                                          _addProductWithQtyDialog(product),
                                    );
                                  },
                                );
                              },
                            );
                          }

                          return Column(
                            children: [
                              Padding(
                                padding: searchPadding,
                                child: PosSearchBar(
                                  key: _searchBarKey,
                                  controller: _searchController,
                                  onChanged: (v) {
                                    setState(() {
                                      _searchQuery = v;
                                    });
                                    _setFocusedProductIndex(0);
                                  },
                                  onSubmitted: (v) => _handleSearchSubmitted(v),
                                  onClear: () {
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                    _focusedProductIndex = -1;
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (allProducts.isNotEmpty)
                                Padding(
                                  padding: chipPadding,
                                  child: PosCategoryChips(
                                    key: _categoryChipsKey,
                                    categories: categories,
                                    selected: _selectedCategory,
                                    onSelected: (cat) {
                                      setState(() {
                                        _selectedCategory = cat;
                                      });
                                      _setFocusedProductIndex(0);
                                    },
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Expanded(child: buildProductList()),
                              if (includeFooter)
                                SafeArea(
                                  top: false,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: NovaColors.bgPrimary,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                      border: const Border(
                                        top: BorderSide(
                                          color: NovaColors.borderTertiary,
                                          width: 0.5,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 18,
                                          offset: const Offset(0, -4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _BottomBarButton(
                                            onPressed: cart.items.isEmpty
                                                ? null
                                                : _onCheckout,
                                            icon: Icons.shopping_bag_outlined,
                                            label: 'Checkout',
                                            badge: cart.items.isNotEmpty
                                                ? '${cart.items.length}'
                                                : null,
                                            isPrimary: true,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: StreamBuilder<
                                              OrderRecordSnapshot>(
                                            stream: _ordersStream,
                                            initialData: _lastOrders,
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                _lastOrders = snapshot.data;
                                              }
                                              final readyCount =
                                                  _readyOrderCount(snapshot);
                                              return _BottomBarButton(
                                                onPressed: () =>
                                                    _showReadyOrdersSheet(
                                                        context),
                                                icon:
                                                    Icons.receipt_long_outlined,
                                                label: 'Ready Orders',
                                                badge: readyCount > 0
                                                    ? '$readyCount'
                                                    : null,
                                                isPrimary: false,
                                                badgeColor: NovaColors.teal,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }

                        Widget buildCheckoutPanel(
                            {bool showBackButton = true}) {
                          final itemCount = cart.items.length;

                          return Focus(
                              focusNode: _checkoutShortcutFocusNode,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: NovaColors.bgPrimary,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: NovaColors.borderTertiary,
                                    width: 0.75,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: const BoxDecoration(
                                        color: NovaColors.bgSecondary,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(18),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (showBackButton)
                                            InkWell(
                                              onTap: _focusPosForNewOrder,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: NovaColors.violetLight,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .arrow_back_ios_new_rounded,
                                                  color: NovaColors.violet,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          if (showBackButton)
                                            const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: NovaColors.violetLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons
                                                  .shopping_cart_checkout_rounded,
                                              color: NovaColors.violet,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Checkout',
                                              style: TextStyle(
                                                color: NovaColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (itemCount > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: NovaColors.violetLight,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '$itemCount item${itemCount == 1 ? '' : 's'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: NovaColors.violet,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 14, 16, 0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: NovaColors.bgSecondary,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: NovaColors.borderTertiary,
                                            width: 0.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Order Details',
                                              style: TextStyle(
                                                color: NovaColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller:
                                                  _customerNameController,
                                              onChanged: (value) => setState(
                                                () => _customerName = value,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: NovaColors.textPrimary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              decoration: _fieldDecoration(
                                                'Customer Name',
                                                icon: Icons
                                                    .person_outline_rounded,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              value: _paymentMethod,
                                              decoration: _fieldDecoration(
                                                'Payment Method',
                                                icon: Icons.payment_outlined,
                                              ),
                                              dropdownColor:
                                                  NovaColors.bgPrimary,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: NovaColors.textPrimary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'cash',
                                                  child: Text('Cash'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'card',
                                                  child: Text('Card'),
                                                ),
                                              ],
                                              onChanged: (value) =>
                                                  _selectPaymentMethod(
                                                value ?? 'cash',
                                              ),
                                            ),
                                            if (_paymentMethod == 'cash') ...[
                                              const SizedBox(height: 10),
                                              TextField(
                                                focusNode: _cashFocusNode,
                                                controller: _cashController,
                                                textInputAction:
                                                    TextInputAction.done,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                  decimal: true,
                                                ),
                                                onChanged: (value) =>
                                                    setState(() {
                                                  _tenderedAmount =
                                                      double.tryParse(value) ??
                                                          0.0;
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
                                                    color: NovaColors
                                                        .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (_tenderedAmount > 0 &&
                                                  _cashIsInsufficient(
                                                    _tenderedAmount,
                                                    cart.total,
                                                  ))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    left: 4,
                                                    top: 6,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        color:
                                                            NovaColors.danger,
                                                        size: 13,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Amount is less than total',
                                                        style: TextStyle(
                                                          color:
                                                              NovaColors.danger,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              const SizedBox(height: 10),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: !_cashIsInsufficient(
                                                    _tenderedAmount,
                                                    cart.total,
                                                  )
                                                      ? NovaColors.tealLight
                                                      : NovaColors.dangerLight,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: !_cashIsInsufficient(
                                                      _tenderedAmount,
                                                      cart.total,
                                                    )
                                                        ? NovaColors.teal
                                                            .withValues(
                                                            alpha: 0.3,
                                                          )
                                                        : NovaColors.danger
                                                            .withValues(
                                                                alpha: 0.2),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .change_circle_outlined,
                                                          size: 15,
                                                          color: !_cashIsInsufficient(
                                                                  _tenderedAmount,
                                                                  cart.total)
                                                              ? NovaColors.teal
                                                              : NovaColors
                                                                  .danger,
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        const Text(
                                                          'Change Due',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 13,
                                                            color: NovaColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      'Rs ${(_tenderedAmount - cart.total).toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: !_cashIsInsufficient(
                                                                _tenderedAmount,
                                                                cart.total)
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
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: cart.items.isEmpty
                                          ? Center(
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              18),
                                                      decoration: BoxDecoration(
                                                        color: NovaColors
                                                            .bgSecondary,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: NovaColors
                                                              .borderTertiary,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .shopping_bag_outlined,
                                                        size: 34,
                                                        color: NovaColors
                                                            .textTertiary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Text(
                                                      'No items in cart',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: NovaColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                      ),
                                                      child: Text(
                                                        'Add products from the left side to start checkout.',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: NovaColors
                                                              .textTertiary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                16,
                                                8,
                                                16,
                                                12,
                                              ),
                                              itemCount: cart.items.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(
                                                height: 16,
                                                color:
                                                    NovaColors.borderTertiary,
                                              ),
                                              itemBuilder: (context, index) {
                                                final item = cart.items[index];
                                                final cartDocId =
                                                    item['cartDocId']
                                                            as String? ??
                                                        '';
                                                final price =
                                                    ((item['unitPrice'] ??
                                                                    item[
                                                                        'price'])
                                                                as num?)
                                                            ?.toDouble() ??
                                                        0.0;
                                                final qty =
                                                    (item['qty'] as num?)
                                                            ?.toInt() ??
                                                        1;
                                                final lineTotal =
                                                    ((item['lineTotal'])
                                                                as num?)
                                                            ?.toDouble() ??
                                                        price * qty;
                                                final name =
                                                    item['name']?.toString() ??
                                                        'Item';
                                                final productId =
                                                    item['productId']
                                                            ?.toString() ??
                                                        '';
                                                final stockStatus =
                                                    _getStockStatus(
                                                        productId, allProducts);
                                                final isFocused = index ==
                                                    _safeCartIndex(cart);
                                                final itemKey =
                                                    _cartItemKeys.putIfAbsent(
                                                  cartDocId,
                                                  GlobalKey.new,
                                                );
                                                final menuButtonKey =
                                                    _cartItemMenuKeys
                                                        .putIfAbsent(
                                                  cartDocId,
                                                  GlobalKey.new,
                                                );

                                                return InkWell(
                                                  key: itemKey,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  onTap: () =>
                                                      _selectCartItem(index),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 140,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: isFocused
                                                          ? NovaColors
                                                              .violetLight
                                                          : NovaColors
                                                              .bgSecondary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                      border: Border.all(
                                                        color: isFocused
                                                            ? NovaColors.violet
                                                            : NovaColors
                                                                .borderTertiary,
                                                        width:
                                                            isFocused ? 1 : 0.5,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 42,
                                                          height: 42,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _itemBgColor(
                                                                name),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              10,
                                                            ),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              _itemEmoji(name),
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 18,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                name,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: NovaColors
                                                                      .textPrimary,
                                                                ),
                                                              ),
                                                              if (stockStatus !=
                                                                  null) ...[
                                                                const SizedBox(
                                                                    height: 2),
                                                                Text(
                                                                    stockStatus,
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: stockStatus.startsWith('OUT')
                                                                            ? NovaColors.danger
                                                                            : NovaColors.amber)),
                                                              ],
                                                              const SizedBox(
                                                                  height: 4),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: isFocused
                                                                          ? NovaColors
                                                                              .bgPrimary
                                                                          : NovaColors
                                                                              .violetLight,
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                        5,
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      '×$qty',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: NovaColors
                                                                            .violet,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Rs ${price.toStringAsFixed(0)} each',
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: NovaColors
                                                                            .textTertiary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        ConstrainedBox(
                                                          constraints:
                                                              const BoxConstraints(
                                                            maxWidth: 72,
                                                          ),
                                                          child: FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: Text(
                                                              'Rs ${lineTotal.toStringAsFixed(0)}',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: NovaColors
                                                                    .textPrimary,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          key: menuButtonKey,
                                                          icon: const Icon(
                                                            Icons
                                                                .more_vert_rounded,
                                                            color: NovaColors
                                                                .textTertiary,
                                                            size: 16,
                                                          ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                          splashRadius: 18,
                                                          onPressed: () async {
                                                            _selectCartItem(
                                                                index);
                                                            await _showCartItemActions(
                                                              context,
                                                              cart,
                                                              item,
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: NovaColors.bgSecondary,
                                        borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(18),
                                        ),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        14,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Total',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      NovaColors.textTertiary,
                                                ),
                                              ),
                                              Text(
                                                'Rs ${cart.total.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700,
                                                  color: NovaColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _BottomBarButton(
                                                  onPressed: cart
                                                              .items.isEmpty ||
                                                          (_paymentMethod ==
                                                                  'cash' &&
                                                              _cashIsInsufficient(
                                                                  _tenderedAmount,
                                                                  cart.total)) ||
                                                          _isSubmitting
                                                      ? null
                                                      : () => _placeOrder(
                                                            context,
                                                            cart,
                                                          ),
                                                  icon: _isSubmitting
                                                      ? Icons
                                                          .hourglass_top_rounded
                                                      : Icons.send_rounded,
                                                  label: _isSubmitting
                                                      ? 'Placing...'
                                                      : 'Place Order',
                                                  badge: itemCount > 0
                                                      ? '$itemCount'
                                                      : null,
                                                  isPrimary: true,
                                                ),
                                              ),
                                              if (isDesktop) ...[
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: StreamBuilder<
                                                      OrderRecordSnapshot>(
                                                    stream: _ordersStream,
                                                    initialData: _lastOrders,
                                                    builder:
                                                        (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        _lastOrders =
                                                            snapshot.data;
                                                      }
                                                      final readyCount =
                                                          _readyOrderCount(
                                                              snapshot);
                                                      return _BottomBarButton(
                                                        onPressed: () =>
                                                            _showReadyOrdersSheet(
                                                                context),
                                                        icon: Icons
                                                            .receipt_long_outlined,
                                                        label: 'Ready Orders',
                                                        badge: readyCount > 0
                                                            ? '$readyCount'
                                                            : null,
                                                        isPrimary: false,
                                                        badgeColor:
                                                            NovaColors.teal,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ));
                        }

                        if (isWide) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: productFlex,
                                  child: buildProductArea(
                                    searchPadding: const EdgeInsets.fromLTRB(
                                      0,
                                      14,
                                      12,
                                      0,
                                    ),
                                    chipPadding:
                                        const EdgeInsets.only(right: 12),
                                    listPadding: const EdgeInsets.fromLTRB(
                                      0,
                                      4,
                                      12,
                                      0,
                                    ),
                                    includeFooter: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: cartFlex,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: buildCheckoutPanel(
                                        showBackButton: false),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ResponsiveCenter(
                          padding: EdgeInsets.zero,
                          child: _checkoutKeyboardMode
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child:
                                      buildCheckoutPanel(showBackButton: true),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: buildProductArea(
                                        searchPadding:
                                            const EdgeInsets.fromLTRB(
                                          16,
                                          14,
                                          16,
                                          0,
                                        ),
                                        chipPadding: EdgeInsets.zero,
                                        listPadding: const EdgeInsets.fromLTRB(
                                          16,
                                          4,
                                          16,
                                          12,
                                        ),
                                        includeFooter: false,
                                      ),
                                    ),
                                    _buildMobileCartBar(cart),
                                  ],
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductImage extends StatelessWidget {
  final Product product;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const _ProductImage({
    required this.product,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: product.imageCacheKey,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          fadeInDuration: Duration.zero,
          errorWidget: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final iconColor = _getProductColor();
    final bgColor = iconColor.withValues(alpha: 0.1);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getProductIcon(),
              size: width != null ? (width! * 0.36).clamp(16.0, 44.0) : 28.0,
              color: iconColor,
            ),
            const SizedBox(height: 4),
            Text(
              product.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: iconColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProductIcon() {
    final value = '${product.name} ${product.category}'.toLowerCase();
    if (value.contains('case') || value.contains('cover')) {
      return Icons.phone_android_rounded;
    }
    if (value.contains('glass') || value.contains('protector')) {
      return Icons.screenshot_monitor_rounded;
    }
    if (value.contains('ear') ||
        value.contains('headphone') ||
        value.contains('speaker')) {
      return Icons.headphones_rounded;
    }
    if (value.contains('power bank') || value.contains('battery')) {
      return Icons.battery_charging_full_rounded;
    }
    if (value.contains('charger')) return Icons.electric_bolt_rounded;
    if (value.contains('cable') || value.contains('adapter')) {
      return Icons.cable_rounded;
    }
    if (value.contains('watch') || value.contains('strap')) {
      return Icons.watch_rounded;
    }
    if (value.contains('memory') ||
        value.contains('microsd') ||
        value.contains('flash')) {
      return Icons.sd_card_rounded;
    }
    if (value.contains('holder') ||
        value.contains('mount') ||
        value.contains('stand')) {
      return Icons.phone_in_talk_rounded;
    }
    return product.icon;
  }

  Color _getProductColor() {
    const colors = [
      NovaColors.violet,
      NovaColors.teal,
      NovaColors.amber,
      NovaColors.rose,
      Color(0xFF1976D2),
      Color(0xFF00838F),
    ];
    return colors[product.name.hashCode.abs() % colors.length];
  }
}

class _ProductListTile extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isFocused;

  const _ProductListTile({
    super.key,
    required this.product,
    required this.onTap,
    this.isFocused = false,
  });

  @override
  State<_ProductListTile> createState() => _ProductListTileState();
}

class _ProductListTileState extends State<_ProductListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClickableCursor(
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: NovaColors.bgPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isFocused
                    ? NovaColors.violet
                    : NovaColors.borderTertiary,
                width: widget.isFocused ? 1.5 : 0.5,
              ),
              boxShadow: widget.isFocused
                  ? [
                      BoxShadow(
                        color: NovaColors.violet.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: _ProductImage(
                    product: widget.product,
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: NovaColors.textPrimary,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: NovaColors.bgTertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.product.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: NovaColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Rs ${widget.product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: NovaColors.violet,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: NovaColors.violetLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: NovaColors.violet, size: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isFocused;

  const _ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isFocused = false,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClickableCursor(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: NovaColors.bgPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isFocused
                    ? NovaColors.violet
                    : NovaColors.borderTertiary,
                width: widget.isFocused ? 1.5 : 0.5,
              ),
              boxShadow: widget.isFocused
                  ? [
                      BoxShadow(
                        color: NovaColors.violet.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageHeight = constraints.maxHeight * 0.75;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: _ProductImage(
                        product: widget.product,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: NovaColors.textPrimary,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NovaColors.violetLight,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      'Rs ${widget.product.price.toStringAsFixed(0)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: NovaColors.violet,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 23,
                                  height: 23,
                                  decoration: const BoxDecoration(
                                    color: NovaColors.violetLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: NovaColors.violet,
                                    size: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? badge;
  final bool isPrimary;
  final Color badgeColor;

  const _BottomBarButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.badge,
    this.isPrimary = true,
    this.badgeColor = NovaColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 44,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon,
                size: 16,
                color: isDisabled
                    ? NovaColors.textTertiary
                    : isPrimary
                        ? Colors.white
                        : NovaColors.violet),
            label: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: isDisabled
                    ? NovaColors.textTertiary
                    : isPrimary
                        ? Colors.white
                        : NovaColors.violet,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled
                  ? NovaColors.bgSecondary
                  : isPrimary
                      ? NovaColors.violet
                      : NovaColors.violetLight,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDisabled
                      ? NovaColors.borderTertiary
                      : isPrimary
                          ? NovaColors.violet
                          : NovaColors.violet.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: NovaColors.bgPrimary, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadyOrderCard extends StatelessWidget {
  final String orderLabel;
  final List<Map<String, dynamic>> items;
  final double total;
  final int index;
  final VoidCallback onComplete;

  const _ReadyOrderCard({
    required this.orderLabel,
    required this.items,
    required this.total,
    required this.index,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NovaColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.borderTertiary, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: NovaColors.bgSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: NovaColors.borderTertiary, width: 0.5),
                  ),
                  child: Center(
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: NovaColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order $orderLabel',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: items.map((item) {
                final name = item['name'] ?? 'Unknown';
                final rawQty = item['qty'] ??
                    item['quantity'] ??
                    item['count'] ??
                    item['amount'] ??
                    1;
                final qty = int.tryParse(rawQty.toString()) ?? 1;
                final price = (item['price'] as num?)?.toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: const BoxDecoration(
                          color: NovaColors.violet,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13, color: NovaColors.textPrimary)),
                      ),
                      if (price != null)
                        Text(
                          'Rs ${(price * qty).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, color: NovaColors.textSecondary),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('×$qty',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: NovaColors.violet)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
                color: NovaColors.borderTertiary, height: 20, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 11, color: NovaColors.textTertiary)),
                    Text(
                      'Rs ${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.print_rounded,
                      color: Colors.white, size: 15),
                  label: const Text('Print & Complete',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.teal,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
