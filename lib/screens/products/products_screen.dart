import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/utils/clickable_cursor.dart';
import '../../models/product_model.dart';
import '../../core/theme/cafe_colors.dart';
import '../../core/theme/nova_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/responsive_layout.dart';

({Uint8List bytes, int width, int height})? _normalizeProductImage(
  Uint8List bytes,
) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final longestSide =
      oriented.width > oriented.height ? oriented.width : oriented.height;
  final prepared = longestSide > 1600
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1600 : null,
          height: oriented.height > oriented.width ? 1600 : null,
          interpolation: img.Interpolation.cubic,
        )
      : oriented;
  return (
    bytes: Uint8List.fromList(img.encodeJpg(prepared, quality: 84)),
    width: prepared.width,
    height: prepared.height,
  );
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    this.inventoryMode = false,
    this.openAddOnStart = false,
  });

  final bool inventoryMode;
  final bool openAddOnStart;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  OverlayEntry? _productNoticeEntry;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _openedInitialAddForm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.openAddOnStart || _openedInitialAddForm) return;
    _openedInitialAddForm = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showProductForm(context);
    });
  }

  @override
  void dispose() {
    _productNoticeEntry?.remove();
    _productNoticeEntry = null;
    _searchController.dispose();
    super.dispose();
  }

  void _showProductSnackBar({
    required BuildContext context,
    required String message,
    required bool isError,
    IconData? icon,
    Color? backgroundColor,
  }) {
    if (!isError) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isDesktop = screenWidth >= ResponsiveLayout.desktopBreakpoint;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor ?? CafeColors.olive,
            behavior: SnackBarBehavior.floating,
            width: isDesktop ? 420 : null,
            margin: isDesktop
                ? null
                : const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _productNoticeEntry?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.paddingOf(overlayContext).top + 16,
        left: 16,
        right: 16,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: -1, end: 0),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, value * 80),
            child: Opacity(opacity: 1 + value, child: child),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: backgroundColor ??
                    (isError ? const Color(0xFFE53935) : CafeColors.olive),
                elevation: 12,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon ??
                            (isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline),
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _productNoticeEntry = entry;
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (_productNoticeEntry == entry) {
        entry.remove();
        _productNoticeEntry = null;
      }
    });
  }

  void _showProductForm(BuildContext context, {Product? product}) {
    const brandItems = [
      "Infinix",
      "Tecno",
      "Samsung",
      "Oppo",
      "Vivo",
      "Xiaomi",
      "Realme",
      "Apple",
      "Daw-Link",
      "Generic",
      "R.T",
      "HM",
      "Ronin",
      "Audionic",
      "Anker",
      "Baseus",
      "Remax",
      "Dany",
      "Joyroom",
      "Faster",
      "LDNIO",
      "Oraimo",
      "Yesido",
      "Other",
    ];
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(0) : '',
    );
    final purchasePriceController = TextEditingController(
      text: product != null && product.purchasePrice > 0
          ? product.purchasePrice.toStringAsFixed(0)
          : '',
    );
    final minSalePriceController = TextEditingController(
      text: product != null && product.minSalePrice > 0
          ? product.minSalePrice.toStringAsFixed(0)
          : '',
    );
    final maxDiscountController = TextEditingController(
      text: product != null && product.maxDiscountPercent > 0
          ? product.maxDiscountPercent.toStringAsFixed(0)
          : '',
    );
    final stockController = TextEditingController(
      text: (product?.stockQty ?? 0).toString(),
    );
    final lowStockController = TextEditingController(
      text: (product?.lowStockThreshold ?? 5).toString(),
    );
    final damagedController = TextEditingController(
      text: (product?.damagedQty ?? 0).toString(),
    );
    final modelCodeController =
        TextEditingController(text: product?.modelCode ?? '');
    final savedBrand = product?.brand.trim() ?? '';
    bool manualBrand =
        savedBrand.isNotEmpty && !brandItems.contains(savedBrand);
    String selectedBrand =
        manualBrand ? 'Other' : (savedBrand.isEmpty ? 'Infinix' : savedBrand);
    final customBrandController = TextEditingController(
      text: manualBrand ? savedBrand : '',
    );
    String selectedQualityTier = product?.qualityTier ?? 'Normal Copy';
    String selectedCategory = product?.category ?? 'panels';
    bool allowBargain = product?.allowBargain ?? false;
    Uint8List? selectedImageBytes;
    String? selectedImageFilename;
    bool isPickingImage = false;

    final formKey = GlobalKey<FormState>();
    final isEdit = product != null;
    final supportsCamera = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickProductImage(ImageSource source) async {
              if (isPickingImage) return;
              if (source == ImageSource.camera) {
                if (!supportsCamera) {
                  _showProductSnackBar(
                    context: sheetContext,
                    message:
                        'Camera is not available on this device. Use Gallery instead.',
                    isError: false,
                    icon: Icons.no_photography_outlined,
                    backgroundColor: const Color(0xFFF59E0B),
                  );
                  return;
                }
                final proceed = await showDialog<bool>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Camera access'),
                        content: const Text(
                          'Allow camera access to capture a product photo.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (!proceed || !sheetContext.mounted) return;
              }
              setSheetState(() => isPickingImage = true);
              try {
                final image = await ImagePicker().pickImage(
                  source: source,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 84,
                  requestFullMetadata: false,
                );
                if (image == null) return;
                final rawBytes = await image.readAsBytes();
                final prepared =
                    await compute(_normalizeProductImage, rawBytes);
                if (prepared == null || prepared.bytes.isEmpty) {
                  throw const FormatException('Unsupported image format');
                }
                if (prepared.width < 600 || prepared.height < 600) {
                  if (!sheetContext.mounted) return;
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Image is only ${prepared.width}×${prepared.height}. Choose an image at least 600×600 for a sharp POS card.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  selectedImageBytes = prepared.bytes;
                  selectedImageFilename =
                      'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              } on PlatformException catch (e) {
                if (!sheetContext.mounted) return;
                final denied = e.code.toLowerCase().contains('denied') ||
                    e.code.toLowerCase().contains('permission');
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      denied
                          ? 'Permission denied. Allow access in device settings.'
                          : 'Could not open the image picker.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (_) {
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This image format could not be read. Choose a JPG, PNG, or WebP image.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isPickingImage = false);
                }
              }
            }

            final media = MediaQuery.of(sheetContext);
            final sheetHeight = (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.top -
                    8)
                .clamp(220.0, media.size.height * 0.94);

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: SizedBox(
                    height: sheetHeight,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Form(
                        key: formKey,
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
                                    gradient: CafeColors.headerGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isEdit
                                        ? Icons.edit_rounded
                                        : Icons.add_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isEdit ? 'Edit Product' : 'Add Product',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: CafeColors.charcoal,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close',
                                  mouseCursor: SystemMouseCursors.click,
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: CafeColors.charcoal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: Scrollbar(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: NovaColors.bgSecondary,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: NovaColors.borderTertiary,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  width: 84,
                                                  height: 84,
                                                  color: NovaColors.bgPrimary,
                                                  child: selectedImageBytes ==
                                                          null
                                                      ? product?.imageUrl ==
                                                              null
                                                          ? const Icon(
                                                              Icons
                                                                  .add_photo_alternate_outlined,
                                                              color: NovaColors
                                                                  .violet,
                                                              size: 32,
                                                            )
                                                          : CachedNetworkImage(
                                                              imageUrl: product!
                                                                  .imageUrl!,
                                                              cacheKey: product
                                                                  .imageCacheKey,
                                                              fit: BoxFit.cover,
                                                              filterQuality:
                                                                  FilterQuality
                                                                      .high,
                                                              errorWidget: (_,
                                                                      __,
                                                                      ___) =>
                                                                  const Icon(
                                                                Icons
                                                                    .add_photo_alternate_outlined,
                                                                color:
                                                                    NovaColors
                                                                        .violet,
                                                                size: 32,
                                                              ),
                                                            )
                                                      : Image.memory(
                                                          selectedImageBytes!,
                                                          fit: BoxFit.cover,
                                                          filterQuality:
                                                              FilterQuality
                                                                  .high,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  const Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            color: NovaColors
                                                                .danger,
                                                            size: 32,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Product image',
                                                      style: TextStyle(
                                                        color: NovaColors
                                                            .textPrimary,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        OutlinedButton.icon(
                                                          onPressed:
                                                              isPickingImage
                                                                  ? null
                                                                  : () =>
                                                                      pickProductImage(
                                                                        ImageSource
                                                                            .gallery,
                                                                      ),
                                                          icon: const Icon(
                                                            Icons
                                                                .photo_library_outlined,
                                                            size: 18,
                                                          ),
                                                          label: const Text(
                                                              'Gallery'),
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            minimumSize:
                                                                const Size(
                                                                    112, 44),
                                                          ),
                                                        ),
                                                        OutlinedButton.icon(
                                                          onPressed:
                                                              isPickingImage
                                                                  ? null
                                                                  : () =>
                                                                      pickProductImage(
                                                                        ImageSource
                                                                            .camera,
                                                                      ),
                                                          icon: const Icon(
                                                            Icons
                                                                .photo_camera_outlined,
                                                            size: 18,
                                                          ),
                                                          label: const Text(
                                                              'Camera'),
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            minimumSize:
                                                                const Size(
                                                                    112, 44),
                                                          ),
                                                        ),
                                                        if (selectedImageBytes !=
                                                            null)
                                                          IconButton(
                                                            tooltip:
                                                                'Remove selected image',
                                                            onPressed: () =>
                                                                setSheetState(
                                                                    () {
                                                              selectedImageBytes =
                                                                  null;
                                                              selectedImageFilename =
                                                                  null;
                                                            }),
                                                            icon: const Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              color: NovaColors
                                                                  .danger,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _StyledField(
                                                controller: modelCodeController,
                                                label: 'Model Code',
                                                icon: Icons.code_rounded,
                                                validator: (v) => (v == null ||
                                                        v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child:
                                                  Builder(builder: (context) {
                                                if (manualBrand) {
                                                  return _StyledField(
                                                    controller:
                                                        customBrandController,
                                                    label: 'Enter Brand',
                                                    icon: Icons
                                                        .branding_watermark_outlined,
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .words,
                                                    validator: (value) =>
                                                        value == null ||
                                                                value
                                                                    .trim()
                                                                    .isEmpty
                                                            ? 'Required'
                                                            : null,
                                                    suffixIcon: IconButton(
                                                      tooltip:
                                                          'Choose brand from list',
                                                      onPressed: () {
                                                        setSheetState(() {
                                                          manualBrand = false;
                                                          selectedBrand =
                                                              'Infinix';
                                                        });
                                                      },
                                                      icon: const Icon(
                                                          Icons.list_rounded),
                                                    ),
                                                  );
                                                }
                                                return _StyledDropdown<String>(
                                                    value: selectedBrand,
                                                    label: 'Brand',
                                                    icon: Icons
                                                        .branding_watermark_outlined,
                                                    items: brandItems
                                                        .map((b) =>
                                                            DropdownMenuItem(
                                                                value: b,
                                                                child: Text(b)))
                                                        .toList(),
                                                    onChanged: (v) {
                                                      if (v == null) return;
                                                      setSheetState(() {
                                                        selectedBrand = v;
                                                        if (v == 'Other') {
                                                          manualBrand = true;
                                                          customBrandController
                                                              .clear();
                                                        }
                                                      });
                                                    });
                                              }),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _ResponsiveProductFormRow(
                                          first: _StyledField(
                                            controller: nameController,
                                            label: 'Product Name',
                                            icon: Icons.shopping_bag_outlined,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Name is required'
                                                    : null,
                                          ),
                                          second: Builder(builder: (context) {
                                            final qualityTierItems = [
                                              "Normal Copy",
                                              "Icon Quality",
                                              "Mabroor",
                                              "Original Pull"
                                            ];
                                            if (selectedQualityTier
                                                    .isNotEmpty &&
                                                !qualityTierItems.contains(
                                                    selectedQualityTier)) {
                                              qualityTierItems
                                                  .add(selectedQualityTier);
                                            }
                                            return _StyledDropdown<String>(
                                              value: selectedQualityTier,
                                              label: 'Quality Tier',
                                              icon: Icons.high_quality_outlined,
                                              items: qualityTierItems
                                                  .map((q) => DropdownMenuItem(
                                                      value: q, child: Text(q)))
                                                  .toList(),
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setSheetState(() =>
                                                      selectedQualityTier = v);
                                                }
                                              },
                                            );
                                          }),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _StyledField(
                                                controller:
                                                    purchasePriceController,
                                                label:
                                                    'Purchase Price (Wholesale)',
                                                icon: Icons
                                                    .shopping_cart_checkout_rounded,
                                                prefixText: 'Rs ',
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                validator: (v) {
                                                  if (v == null ||
                                                      v.trim().isEmpty) {
                                                    return 'Required';
                                                  }
                                                  if (double.tryParse(
                                                          v.trim()) ==
                                                      null) {
                                                    return 'Invalid';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _StyledField(
                                                controller: priceController,
                                                label: 'Sale Price (Retail)',
                                                icon: Icons.payments_outlined,
                                                prefixText: 'Rs ',
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                validator: (v) {
                                                  if (v == null ||
                                                      v.trim().isEmpty) {
                                                    return 'Required';
                                                  }
                                                  if (double.tryParse(
                                                          v.trim()) ==
                                                      null) {
                                                    return 'Invalid';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Material(
                                          color: Colors.transparent,
                                          child: SwitchListTile.adaptive(
                                            contentPadding: EdgeInsets.zero,
                                            value: allowBargain,
                                            activeColor: NovaColors.violet,
                                            title: const Text(
                                              'Allow bargaining',
                                              style: TextStyle(
                                                color: NovaColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: const Text(
                                              'Cashiers can enter a negotiated sale price.',
                                            ),
                                            onChanged: (value) => setSheetState(
                                              () => allowBargain = value,
                                            ),
                                          ),
                                        ),
                                        if (allowBargain) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _StyledField(
                                                  controller:
                                                      minSalePriceController,
                                                  label: 'Minimum Sale Price',
                                                  icon:
                                                      Icons.price_check_rounded,
                                                  prefixText: 'Rs ',
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                    decimal: true,
                                                  ),
                                                  validator: (v) {
                                                    final value =
                                                        double.tryParse(
                                                      v?.trim() ?? '',
                                                    );
                                                    if ((v?.trim().isNotEmpty ??
                                                            false) &&
                                                        value == null) {
                                                      return 'Invalid';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _StyledField(
                                                  controller:
                                                      maxDiscountController,
                                                  label: 'Max Discount',
                                                  icon: Icons.percent_rounded,
                                                  suffixText: '%',
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                    decimal: true,
                                                  ),
                                                  validator: (v) {
                                                    if (v == null ||
                                                        v.trim().isEmpty) {
                                                      return null;
                                                    }
                                                    final value =
                                                        double.tryParse(
                                                            v.trim());
                                                    if (value == null ||
                                                        value < 0 ||
                                                        value > 100) {
                                                      return 'Use 0 to 100';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Builder(builder: (context) {
                                          final categoryItems = [
                                            "panels",
                                            "chargers",
                                            "cables",
                                            "covers",
                                            "Audio",
                                            "Power",
                                            "Protection",
                                            "Mounts & Gear"
                                          ];
                                          if (selectedCategory.isNotEmpty &&
                                              !categoryItems
                                                  .contains(selectedCategory)) {
                                            categoryItems.add(selectedCategory);
                                          }
                                          return _StyledDropdown<String>(
                                            value: selectedCategory,
                                            label: 'Category',
                                            icon: Icons.category_outlined,
                                            items: categoryItems
                                                .map((c) => DropdownMenuItem(
                                                    value: c, child: Text(c)))
                                                .toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                setSheetState(
                                                    () => selectedCategory = v);
                                              }
                                            },
                                          );
                                        }),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _StyledField(
                                                controller: stockController,
                                                label: 'Stock Qty',
                                                icon:
                                                    Icons.inventory_2_outlined,
                                                keyboardType:
                                                    TextInputType.number,
                                                onTap: !isEdit
                                                    ? () {
                                                        if (stockController
                                                                .text ==
                                                            '0') {
                                                          stockController
                                                              .clear();
                                                        }
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _StyledField(
                                                controller: lowStockController,
                                                label: 'Low Alert',
                                                icon:
                                                    Icons.warning_amber_rounded,
                                                keyboardType:
                                                    TextInputType.number,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _StyledField(
                                          controller: damagedController,
                                          label: 'Damaged',
                                          icon: Icons.broken_image_outlined,
                                          keyboardType: TextInputType.number,
                                          onTap: !isEdit
                                              ? () {
                                                  if (damagedController.text ==
                                                      '0') {
                                                    damagedController.clear();
                                                  }
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Consumer<ProductProvider>(
                              builder: (context, provider, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: provider.isLoading
                                          ? null
                                          : CafeColors.headerGradient,
                                      color: provider.isLoading
                                          ? Colors.grey[200]
                                          : null,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: provider.isLoading
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: CafeColors.flame
                                                    .withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: provider.isLoading
                                          ? null
                                          : () async {
                                              if (!formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }

                                              final name =
                                                  nameController.text.trim();
                                              final price = double.parse(
                                                  priceController.text.trim());
                                              final purchasePrice =
                                                  double.tryParse(
                                                        purchasePriceController
                                                            .text
                                                            .trim(),
                                                      ) ??
                                                      0;
                                              final minSalePrice =
                                                  double.tryParse(
                                                        minSalePriceController
                                                            .text
                                                            .trim(),
                                                      ) ??
                                                      0;
                                              final maxDiscountPercent =
                                                  double.tryParse(
                                                        maxDiscountController
                                                            .text
                                                            .trim(),
                                                      ) ??
                                                      0;
                                              final stockQty = int.tryParse(
                                                      stockController.text
                                                          .trim()) ??
                                                  0;
                                              final lowStockThreshold =
                                                  int.tryParse(
                                                          lowStockController
                                                              .text
                                                              .trim()) ??
                                                      5;
                                              final damagedQty = int.tryParse(
                                                      damagedController.text
                                                          .trim()) ??
                                                  0;
                                              final modelCode =
                                                  modelCodeController.text
                                                      .trim();
                                              final brand = manualBrand
                                                  ? customBrandController.text
                                                      .trim()
                                                  : selectedBrand;

                                              String? error;
                                              if (isEdit) {
                                                error = await provider
                                                    .updateProduct(
                                                  id: product.id,
                                                  name: name,
                                                  price: price,
                                                  purchasePrice: purchasePrice,
                                                  minSalePrice: minSalePrice,
                                                  allowBargain: allowBargain,
                                                  maxDiscountPercent:
                                                      maxDiscountPercent,
                                                  category: selectedCategory,
                                                  modelCode: modelCode,
                                                  brand: brand,
                                                  qualityTier:
                                                      selectedQualityTier,
                                                  stockQty: stockQty,
                                                  lowStockThreshold:
                                                      lowStockThreshold,
                                                  damagedQty: damagedQty,
                                                  imageBytes:
                                                      selectedImageBytes,
                                                  imageFilename:
                                                      selectedImageFilename,
                                                );
                                              } else {
                                                error = await provider
                                                    .createProduct(
                                                  name: name,
                                                  price: price,
                                                  purchasePrice: purchasePrice,
                                                  minSalePrice: minSalePrice,
                                                  allowBargain: allowBargain,
                                                  maxDiscountPercent:
                                                      maxDiscountPercent,
                                                  category: selectedCategory,
                                                  modelCode: modelCode,
                                                  brand: brand,
                                                  qualityTier:
                                                      selectedQualityTier,
                                                  stockQty: stockQty,
                                                  lowStockThreshold:
                                                      lowStockThreshold,
                                                  damagedQty: damagedQty,
                                                  imageBytes:
                                                      selectedImageBytes,
                                                  imageFilename:
                                                      selectedImageFilename,
                                                );
                                              }

                                              if (!sheetContext.mounted) return;
                                              if (error != null) {
                                                _showProductSnackBar(
                                                  context: sheetContext,
                                                  message: error,
                                                  isError: true,
                                                );
                                                return;
                                              }
                                              Navigator.pop(sheetContext);
                                              _showProductSnackBar(
                                                context: context,
                                                message: isEdit
                                                    ? 'Product updated'
                                                    : 'Product added',
                                                isError: false,
                                              );
                                            },
                                      icon: provider.isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              isEdit
                                                  ? Icons.save_rounded
                                                  : Icons.add_rounded,
                                              color: Colors.white,
                                            ),
                                      label: Text(
                                        provider.isLoading
                                            ? (isEdit
                                                ? 'Saving...'
                                                : 'Adding...')
                                            : (isEdit
                                                ? 'Save Changes'
                                                : 'Add Product'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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
      },
    );
  }

  Future<void> _showBulkBargainDialog(
    BuildContext context,
    List<Product> products,
  ) async {
    if (products.isEmpty) return;

    final updatedCount = await showDialog<int>(
      context: context,
      builder: (_) => _BulkBargainDialog(
        products: products,
        provider: context.read<ProductProvider>(),
      ),
    );
    if (!context.mounted || updatedCount == null) return;
    _showProductSnackBar(
      context: context,
      message: 'Bargaining updated for $updatedCount products',
      isError: false,
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEDE8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: CafeColors.flame, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Product',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CafeColors.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${product.name}"? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: CafeColors.charcoal.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(
                              color: CafeColors.charcoal.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: CafeColors.charcoal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            final error = await context
                                .read<ProductProvider>()
                                .deleteProduct(product.id);
                            if (!context.mounted) return;
                            _showProductSnackBar(
                              context: context,
                              message: error ?? 'Product deleted',
                              isError: error != null,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (!auth.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/pos');
          });
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: NovaColors.violet)),
          );
        }

        final userEmail = auth.user?.email ?? 'No Email';
        final userName = auth.user?.name ?? userEmail.split('@').first;
        final photoUrl = auth.user?.photoUrl;

        return Scaffold(
          backgroundColor: NovaColors.bgTertiary,
          appBar: AppNavigationAppBar(
            title: widget.inventoryMode ? 'Inventory Products' : 'Products',
            icon: widget.inventoryMode
                ? Icons.warehouse_rounded
                : Icons.inventory_2_rounded,
            photoUrl: photoUrl,
            userName: userName,
          ),
          body: AppNavigationShell(
            auth: auth,
            currentRoute: widget.inventoryMode ? '/inventory' : '',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: NovaColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: NovaColors.borderTertiary,
                                width: 0.5,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              cursorColor: NovaColors.violet,
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.toLowerCase()),
                              style: const TextStyle(
                                  fontSize: 14, color: NovaColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: const TextStyle(
                                    color: NovaColors.textTertiary,
                                    fontSize: 14),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: NovaColors.textSecondary, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            color: NovaColors.textTertiary,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                filled: true,
                                fillColor: NovaColors.bgPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ClickableCursor(
                          child: GestureDetector(
                            onTap: () => _showProductForm(context),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: CafeColors.headerGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: CafeColors.flame.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<Product>>(
                      stream: context.read<ProductProvider>().productsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: CafeColors.flame),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }

                        final allProducts = snapshot.data ?? [];

                        if (allProducts.isEmpty) {
                          return _emptyProductsView(context);
                        }

                        final categories = [
                          'All',
                          ...{...allProducts.map((p) => p.category)},
                        ];

                        final filtered = allProducts.where((p) {
                          final matchesSearch = _searchQuery.isEmpty ||
                              p.name.toLowerCase().contains(_searchQuery) ||
                              p.category.toLowerCase().contains(_searchQuery);
                          final matchesCategory = _selectedCategory == 'All' ||
                              p.category == _selectedCategory;
                          return matchesSearch && matchesCategory;
                        }).toList();

                        return Column(
                          children: [
                            if (categories.length > 1)
                              SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.zero,
                                  itemCount: categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final cat = categories[i];
                                    final isSelected = _selectedCategory == cat;
                                    return ClickableCursor(
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedCategory = cat),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? CafeColors.headerGradient
                                                : null,
                                            color: isSelected
                                                ? null
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : CafeColors.flame
                                                      .withOpacity(0.2),
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: CafeColors.flame
                                                          .withOpacity(0.25),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            cat,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : CafeColors.charcoal
                                                      .withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          CafeColors.flame,
                                          CafeColors.olive
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '${filtered.length} product${filtered.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          CafeColors.charcoal.withOpacity(0.5),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: filtered.isEmpty
                                        ? null
                                        : () => _showBulkBargainDialog(
                                              context,
                                              filtered,
                                            ),
                                    icon: const Icon(
                                      Icons.handshake_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Bulk Bargaining'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: filtered.isEmpty
                                  ? _noResultsView()
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns =
                                            ResponsiveLayout.cardColumns(
                                          constraints.maxWidth,
                                        );

                                        if (columns == 1) {
                                          return ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(
                                                0, 4, 0, 100),
                                            itemCount: filtered.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (context, i) {
                                              final product = filtered[i];
                                              return _ProductCard(
                                                key: ValueKey(product.id),
                                                product: product,
                                                onEdit: () => _showProductForm(
                                                  context,
                                                  product: product,
                                                ),
                                                onDelete: () => _confirmDelete(
                                                    context, product),
                                              );
                                            },
                                          );
                                        }

                                        return GridView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 4, 0, 100),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            mainAxisExtent:
                                                constraints.maxWidth / columns <
                                                        360
                                                    ? 118
                                                    : 94,
                                          ),
                                          itemCount: filtered.length,
                                          itemBuilder: (context, i) {
                                            final product = filtered[i];
                                            return _ProductCard(
                                              key: ValueKey(product.id),
                                              product: product,
                                              onEdit: () => _showProductForm(
                                                context,
                                                product: product,
                                              ),
                                              onDelete: () => _confirmDelete(
                                                  context, product),
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyProductsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: CafeColors.flame),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CafeColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first product to get started',
            style: TextStyle(
              fontSize: 13,
              color: CafeColors.charcoal.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: CafeColors.headerGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showProductForm(context),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add First Product',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResultsView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: CafeColors.creme,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 36, color: CafeColors.flame),
          ),
          const SizedBox(height: 12),
          Text(
            'No results for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CafeColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveProductFormRow extends StatelessWidget {
  const _ResponsiveProductFormRow({
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? prefixText;
  final String? suffixText;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.prefixText,
    this.suffixText,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.validator,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      onTap: onTap,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: CafeColors.charcoal),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
        labelStyle: TextStyle(
            color: CafeColors.charcoal.withOpacity(0.55), fontSize: 13),
        prefixIcon: Icon(icon, color: CafeColors.flame, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CafeColors.flame, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: CafeColors.steam,
      ),
    );
  }
}

class _BulkBargainDialog extends StatefulWidget {
  const _BulkBargainDialog({
    required this.products,
    required this.provider,
  });

  final List<Product> products;
  final ProductProvider provider;

  @override
  State<_BulkBargainDialog> createState() => _BulkBargainDialogState();
}

class _BulkBargainDialogState extends State<_BulkBargainDialog> {
  final Set<String> _selectedIds = {};
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();
  bool _allowBargain = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty || _saving) return;
    final minSalePrice = double.tryParse(_minPriceController.text.trim()) ?? 0;
    final maxDiscountPercent =
        double.tryParse(_maxDiscountController.text.trim()) ?? 0;
    if (minSalePrice < 0 ||
        maxDiscountPercent < 0 ||
        maxDiscountPercent > 100) {
      setState(() {
        _error = 'Use a valid minimum price and discount from 0 to 100.';
      });
      return;
    }

    final selectedProducts = widget.products
        .where((product) => _selectedIds.contains(product.id))
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.provider.updateBargainPolicies(
      products: selectedProducts,
      allowBargain: _allowBargain,
      minSalePrice: _allowBargain ? minSalePrice : 0,
      maxDiscountPercent: _allowBargain ? maxDiscountPercent : 0,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop(selectedProducts.length);
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIds.length == widget.products.length;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Bulk Bargaining'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allSelected,
                    tristate: _selectedIds.isNotEmpty && !allSelected,
                    title: Text(
                      'Select all ${widget.products.length} products',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onChanged: _saving
                        ? null
                        : (_) => setState(() {
                              if (allSelected) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds
                                  ..clear()
                                  ..addAll(
                                    widget.products
                                        .map((product) => product.id),
                                  );
                              }
                            }),
                  ),
                ),
                const Divider(),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: widget.products.length,
                    itemBuilder: (_, index) {
                      final product = widget.products[index];
                      return Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _selectedIds.contains(product.id),
                          title: Text(product.name),
                          subtitle: Text(
                            'Sale Rs ${product.price.toStringAsFixed(0)}',
                          ),
                          onChanged: _saving
                              ? null
                              : (selected) => setState(() {
                                    if (selected == true) {
                                      _selectedIds.add(product.id);
                                    } else {
                                      _selectedIds.remove(product.id);
                                    }
                                  }),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _allowBargain,
                    title: const Text('Enable bargaining'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _allowBargain = value),
                  ),
                ),
                if (_allowBargain)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Minimum sale price',
                            prefixText: 'Rs ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxDiscountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Max discount',
                            suffixText: '%',
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: NovaColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _selectedIds.isEmpty || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
            label: Text(
              _saving ? 'Saving...' : 'Apply to ${_selectedIds.length}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: CafeColors.flame.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _ProductIcon(product: product),
                          const SizedBox(width: 10),
                          Expanded(child: _ProductCardInfo(product: product)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _ProductPrice(product: product)),
                          _ProductCardActions(
                            onEdit: onEdit,
                            onDelete: onDelete,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _ProductIcon(product: product),
                      const SizedBox(width: 12),
                      Expanded(child: _ProductCardInfo(product: product)),
                      const SizedBox(width: 8),
                      _ProductPrice(product: product),
                      const SizedBox(width: 4),
                      _ProductCardActions(onEdit: onEdit, onDelete: onDelete),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ProductIcon extends StatelessWidget {
  const _ProductIcon({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CafeColors.creme,
        borderRadius: BorderRadius.circular(14),
      ),
      child: imageUrl == null
          ? Icon(product.icon, color: CafeColors.flame, size: 24)
          : CachedNetworkImage(
              imageUrl: imageUrl,
              cacheKey: product.imageCacheKey,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              fadeInDuration: Duration.zero,
              errorWidget: (_, __, ___) =>
                  Icon(product.icon, color: CafeColors.flame, size: 24),
            ),
    );
  }
}

class _ProductCardInfo extends StatelessWidget {
  const _ProductCardInfo({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CafeColors.charcoal,
          ),
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: CafeColors.oliveLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CafeColors.olive,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductPrice extends StatelessWidget {
  const _ProductPrice({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Rs ${product.price.toStringAsFixed(0)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: CafeColors.flame,
      ),
    );
  }
}

class _ProductCardActions extends StatelessWidget {
  const _ProductCardActions({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Color(0xFF1976D2),
              size: 16,
            ),
          ),
          onPressed: onEdit,
          tooltip: 'Edit',
          mouseCursor: SystemMouseCursors.click,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDE8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: CafeColors.flame,
              size: 16,
            ),
          ),
          onPressed: onDelete,
          tooltip: 'Delete',
          mouseCursor: SystemMouseCursors.click,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ],
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String label;
  final IconData icon;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.icon,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      iconSize: 20,
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: CafeColors.charcoal),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: CafeColors.charcoal.withOpacity(0.55), fontSize: 13),
        prefixIcon: Icon(icon, color: CafeColors.flame, size: 19),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: CafeColors.flame.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CafeColors.flame, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
