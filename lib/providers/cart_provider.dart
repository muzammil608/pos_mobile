import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class CartProvider with ChangeNotifier {
  static const String _cartPrefsKey = 'pos_cart_items_v1';
  final _uuid = const Uuid();
  final List<Map<String, dynamic>> _items = [];

  bool _disposed = false;
  bool _loaded = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  double get total => _items.fold(
        0.0,
        (sum, item) {
          final qty = (item['qty'] as num?)?.toDouble() ?? 1.0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          return sum + (qty * price);
        },
      );

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  CartProvider() {
    _restoreCart();
  }

  Future<void> _restoreCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cartPrefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _loaded = true;
        _safeNotify();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final restoredItems = decoded
            .whereType<Map>()
            .map(
              (e) => Map<String, dynamic>.from(e),
            )
            .toList();

        // Self-healing: if any item has name == 'Unknown' or price == 0.0, clear it
        final hasCorrupted = restoredItems.any((item) =>
            item['name'] == 'Unknown' ||
            (item['price'] as num?)?.toDouble() == 0.0);

        if (hasCorrupted) {
          debugPrint(
              'CartProvider: Wiping old corrupted cart data from cache.');
          _items.clear();
          await _persistCart();
        } else {
          _items
            ..clear()
            ..addAll(restoredItems);
        }
      }
      _loaded = true;
      _safeNotify();
    } catch (_) {
      _loaded = true;
      _safeNotify();
    }
  }

  Future<void> _persistCart() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartPrefsKey, jsonEncode(_items));
    } catch (_) {}
  }

  Future<void> addItem(Map<String, dynamic> product) async {
    if (_disposed) return;

    final qty = (product['qty'] as num?)?.toInt() ?? 1;
    final productId = product['id']?.toString() ?? _uuid.v4();

    final existingIndex =
        _items.indexWhere((item) => item['productId'] == productId);

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];

      final newQty = ((existing['qty'] as num?)?.toInt() ?? 1) + qty;

      final price = (existing['price'] as num?)?.toDouble() ?? 0.0;
      final purchasePrice =
          (existing['purchasePrice'] as num?)?.toDouble() ?? 0.0;

      _items[existingIndex] = {
        ...existing,
        'qty': newQty,
        'quantity': newQty,
        'lineTotal': price * newQty,
        'unitProfit': price - purchasePrice,
        'lineProfit': (price - purchasePrice) * newQty,
      };
    } else {
      final rawPrice = product['price'] ?? product['retail_rate'];
      final price = rawPrice is num
          ? rawPrice.toDouble()
          : (double.tryParse(rawPrice?.toString() ?? '') ?? 0.0);
      final originalPrice = _readDouble(
        product['originalPrice'] ?? product['price'] ?? product['retail_rate'],
      );
      final purchasePrice =
          _readDouble(product['purchasePrice'] ?? product['wholesale_rate']);
      final discountPercent = originalPrice > 0 && price < originalPrice
          ? ((originalPrice - price) / originalPrice) * 100
          : 0.0;
      final unitProfit = price - purchasePrice;

      final name =
          (product['name'] ?? product['item_name'])?.toString() ?? 'Unknown';

      _items.add({
        'cartDocId': _uuid.v4(),
        'productId': productId,
        'name': name,
        'price': price,
        'unitPrice': price,
        'originalPrice': originalPrice,
        'purchasePrice': purchasePrice,
        'discountPercent': discountPercent,
        'isBargained': price != originalPrice,
        'unitProfit': unitProfit,
        'lineProfit': unitProfit * qty,
        'minSalePrice':
            _readDouble(product['minSalePrice'] ?? product['min_sale_price']),
        'allowBargain':
            product['allowBargain'] == true || product['allow_bargain'] == true,
        'maxDiscountPercent': _readDouble(
          product['maxDiscountPercent'] ?? product['max_discount_percent'],
        ),
        'qty': qty,
        'quantity': qty,
        'lineTotal': price * qty,
      });
    }

    _safeNotify();
    await _persistCart();
  }

  Future<void> removeItem(String cartDocId) async {
    if (_disposed) return;

    _items.removeWhere((item) => item['cartDocId'] == cartDocId);

    _safeNotify();
    await _persistCart();
  }

  Future<void> updateItemQuantity(String cartDocId, int qty) async {
    if (_disposed) return;

    if (qty <= 0) {
      await removeItem(cartDocId);
      return;
    }

    final index = _items.indexWhere((item) => item['cartDocId'] == cartDocId);

    if (index < 0) return;

    final item = _items[index];

    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final purchasePrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;

    _items[index] = {
      ...item,
      'qty': qty,
      'quantity': qty,
      'lineTotal': price * qty,
      'unitProfit': price - purchasePrice,
      'lineProfit': (price - purchasePrice) * qty,
    };

    _safeNotify();
    await _persistCart();
  }

  Future<void> updateItemPrice(
    String cartDocId,
    double price, {
    bool requiresApproval = false,
    String? approvedBy,
  }) async {
    if (_disposed || price < 0) return;

    final index = _items.indexWhere((item) => item['cartDocId'] == cartDocId);
    if (index < 0) return;

    final item = _items[index];
    final qty = (item['qty'] as num?)?.toInt() ?? 1;
    final originalPrice = (item['originalPrice'] as num?)?.toDouble() ??
        (item['price'] as num?)?.toDouble() ??
        price;
    final discountPercent = originalPrice > 0 && price < originalPrice
        ? ((originalPrice - price) / originalPrice) * 100
        : 0.0;
    final purchasePrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;
    final unitProfit = price - purchasePrice;

    final updatedItem = {
      ...item,
      'price': price,
      'unitPrice': price,
      'originalPrice': originalPrice,
      'discountPercent': discountPercent,
      'isBargained': price != originalPrice,
      'requiresAdminApproval': requiresApproval,
      'adminApproved': requiresApproval && approvedBy != null,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedBy != null) 'approvedAt': DateTime.now().toIso8601String(),
      'lineTotal': price * qty,
      'unitProfit': unitProfit,
      'lineProfit': unitProfit * qty,
    };
    if (approvedBy == null) {
      updatedItem.remove('approvedBy');
      updatedItem.remove('approvedAt');
    }

    _items[index] = updatedItem;

    _safeNotify();
    await _persistCart();
  }

  Future<void> clear() async {
    if (_disposed) return;

    _items.clear();

    _safeNotify();
    await _persistCart();
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
