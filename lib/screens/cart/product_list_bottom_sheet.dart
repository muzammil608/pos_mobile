import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard/pos_keyboard_system.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/clickable_cursor.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/pocketbase/product_service.dart';

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

class ProductListBottomSheet extends StatefulWidget {
  const ProductListBottomSheet({super.key});

  @override
  State<ProductListBottomSheet> createState() => _ProductListBottomSheetState();
}

class _ProductListBottomSheetState extends State<ProductListBottomSheet> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'ProductListBottomSheet');
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<PosSearchBarState> _searchBarKey =
      GlobalKey<PosSearchBarState>();
  final GlobalKey<PosCategoryChipsState> _categoryChipsKey =
      GlobalKey<PosCategoryChipsState>();
  final Map<int, GlobalKey> _productItemKeys = {};
  int _focusedIndex = 0;
  int _columns = 3;
  String _query = '';
  String _selectedCategory = 'All';
  List<Product> _products = const [];

  late final ProductService _productService;
  late final Stream<List<Product>> _productsStream;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _productService = ProductService(auth.ownerId);
    _productsStream = _productService.streamProducts;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _columnCount(double width) {
    if (width < 380) return 1;
    if (width < 600) return 1;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  void _moveFocus(int delta) {
    if (_products.isEmpty) return;
    setState(() {
      _focusedIndex = (_focusedIndex + delta).clamp(0, _products.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedProductIntoView();
    });
  }

  void _setFocusedIndex(int index) {
    if (!mounted) return;
    setState(() {
      _focusedIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedProductIntoView(index);
    });
  }

  void _scrollFocusedProductIntoView([int? index]) {
    final focusedIndex = index ?? _focusedIndex;
    final context = _productItemKeys[focusedIndex]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.18,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  List<String> _getCategories(List<Product> products) {
    final categories = products.map((p) => p.category).toSet().toList()..sort();
    return ['All', ...categories];
  }

  void _addFocusedProduct(BuildContext context) {
    if (_products.isEmpty) return;
    _addProduct(context, _products[_focusedIndex]);
  }

  void _addProduct(BuildContext context, Product product) {
    context.read<CartProvider>().addItem({
      'id': product.id,
      ...product.toMap(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.slash): _SheetFocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _SheetFocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _SheetNextCategoryIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _SheetPrevCategoryIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SheetMoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SheetMoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _SheetMoveRowIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _SheetMoveRowIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _SheetSelectIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _SheetSelectIntent(),
        SingleActivator(LogicalKeyboardKey.keyE): _SheetSelectIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _SheetCloseIntent(),
      },
      child: Actions(
        actions: {
          _SheetFocusSearchIntent: CallbackAction<_SheetFocusSearchIntent>(
            onInvoke: (_) {
              _searchBarKey.currentState?.requestFocus();
              return null;
            },
          ),
          _SheetNextCategoryIntent: CallbackAction<_SheetNextCategoryIntent>(
            onInvoke: (_) {
              _categoryChipsKey.currentState?.nextCategory();
              return null;
            },
          ),
          _SheetPrevCategoryIntent: CallbackAction<_SheetPrevCategoryIntent>(
            onInvoke: (_) {
              _categoryChipsKey.currentState?.prevCategory();
              return null;
            },
          ),
          _SheetMoveIntent: CallbackAction<_SheetMoveIntent>(
            onInvoke: (intent) {
              _moveFocus(intent.delta);
              return null;
            },
          ),
          _SheetMoveRowIntent: CallbackAction<_SheetMoveRowIntent>(
            onInvoke: (intent) {
              _moveFocus(intent.delta * _columns);
              return null;
            },
          ),
          _SheetSelectIntent: CallbackAction<_SheetSelectIntent>(
            onInvoke: (_) {
              _addFocusedProduct(context);
              return null;
            },
          ),
          _SheetCloseIntent: CallbackAction<_SheetCloseIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
              maxWidth: 560,
            ),
            decoration: const BoxDecoration(
              color: NovaColors.bgTertiary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: NovaColors.borderSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NovaColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: NovaColors.borderTertiary,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: NovaColors.violetLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: NovaColors.violet,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Items',
                        style: TextStyle(
                          color: NovaColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: NovaColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PosSearchBar(
                    key: _searchBarKey,
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                      _setFocusedIndex(0);
                    },
                    onClear: () {
                      setState(() {
                        _query = '';
                      });
                      _focusNode.requestFocus();
                      _setFocusedIndex(0);
                    },
                    hintText: 'Search products…  ( / or Ctrl+F )',
                    height: 44,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: StreamBuilder<List<Product>>(
                    stream: _productsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: NovaColors.violet,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        _products = const [];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: NovaColors.bgPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: NovaColors.borderTertiary,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 36,
                                    color: NovaColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No products available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: NovaColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final allProducts = snapshot.data!;
                      final categories = _getCategories(allProducts);
                      if (!categories.contains(_selectedCategory)) {
                        _selectedCategory = 'All';
                      }
                      final filteredProducts = allProducts.where((product) {
                        final matchesQuery = _query.isEmpty ||
                            product.name.toLowerCase().contains(_query) ||
                            product.category.toLowerCase().contains(_query);
                        final matchesCategory = _selectedCategory == 'All' ||
                            product.category == _selectedCategory;
                        return matchesQuery && matchesCategory;
                      }).toList();

                      _products = filteredProducts;
                      if (_products.isEmpty) {
                        return const Center(
                          child: Text(
                            'No matching products',
                            style: TextStyle(
                              color: NovaColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      if (_focusedIndex >= _products.length) {
                        _focusedIndex = _products.length - 1;
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final showChips = categories.length > 1;

                          if (constraints.maxWidth < 600) {
                            _columns = 1;
                            return Column(
                              children: [
                                if (showChips)
                                  PosCategoryChips(
                                    key: _categoryChipsKey,
                                    categories: categories,
                                    selected: _selectedCategory,
                                    onSelected: (category) {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                      _setFocusedIndex(0);
                                    },
                                  ),
                                if (showChips) const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 24),
                                    itemCount: _products.length,
                                    itemBuilder: (context, index) {
                                      final product = _products[index];
                                      return _BottomSheetProductTile(
                                        key: _productItemKeys.putIfAbsent(
                                          index,
                                          GlobalKey.new,
                                        ),
                                        product: product,
                                        isFocused: index == _focusedIndex,
                                        onTap: () =>
                                            _addProduct(context, product),
                                        onFocus: () => setState(
                                            () => _focusedIndex = index),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }

                          _columns = _columnCount(constraints.maxWidth);
                          return Column(
                            children: [
                              if (showChips)
                                PosCategoryChips(
                                  key: _categoryChipsKey,
                                  categories: categories,
                                  selected: _selectedCategory,
                                  onSelected: (category) {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                    _setFocusedIndex(0);
                                  },
                                ),
                              if (showChips) const SizedBox(height: 10),
                              Expanded(
                                child: GridView.builder(
                                  controller: _scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _columns,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: constraints.maxWidth < 380
                                        ? 1.35
                                        : 0.92,
                                  ),
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    final product = _products[index];
                                    return _BottomSheetProductGridCard(
                                      key: _productItemKeys.putIfAbsent(
                                        index,
                                        GlobalKey.new,
                                      ),
                                      product: product,
                                      isFocused: index == _focusedIndex,
                                      onTap: () =>
                                          _addProduct(context, product),
                                      onFocus: () =>
                                          setState(() => _focusedIndex = index),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
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

class _BottomSheetProductTile extends StatefulWidget {
  final Product product;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  const _BottomSheetProductTile({
    super.key,
    required this.product,
    required this.isFocused,
    required this.onTap,
    required this.onFocus,
  });

  @override
  State<_BottomSheetProductTile> createState() =>
      _BottomSheetProductTileState();
}

class _BottomSheetProductTileState extends State<_BottomSheetProductTile>
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
                      ),
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
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NovaColors.textPrimary,
                        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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

class _BottomSheetProductGridCard extends StatefulWidget {
  final Product product;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  const _BottomSheetProductGridCard({
    super.key,
    required this.product,
    required this.isFocused,
    required this.onTap,
    required this.onFocus,
  });

  @override
  State<_BottomSheetProductGridCard> createState() =>
      _BottomSheetProductGridCardState();
}

class _BottomSheetProductGridCardState
    extends State<_BottomSheetProductGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onFocusChange: (v) {
              if (v) widget.onFocus();
            },
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _ProductImage(
                    product: widget.product,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: NovaColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: NovaColors.violetLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rs ${widget.product.price.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: NovaColors.violet,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: NovaColors.violetLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: NovaColors.violet, size: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _SheetMoveIntent extends Intent {
  final int delta;
  const _SheetMoveIntent(this.delta);
}

class _SheetMoveRowIntent extends Intent {
  final int delta;
  const _SheetMoveRowIntent(this.delta);
}

class _SheetSelectIntent extends Intent {
  const _SheetSelectIntent();
}

class _SheetCloseIntent extends Intent {
  const _SheetCloseIntent();
}

class _SheetFocusSearchIntent extends Intent {
  const _SheetFocusSearchIntent();
}

class _SheetNextCategoryIntent extends Intent {
  const _SheetNextCategoryIntent();
}

class _SheetPrevCategoryIntent extends Intent {
  const _SheetPrevCategoryIntent();
}
