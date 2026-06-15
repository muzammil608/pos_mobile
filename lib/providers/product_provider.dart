import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/pocketbase/product_service.dart';
import '../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  late final ProductService _service;
  late final Stream<List<Product>> _productsStream;
  StreamSubscription<List<Product>>? _productsSubscription;
  final StreamController<List<Product>> _productUpdates =
      StreamController<List<Product>>.broadcast();
  final List<Product> _products = [];
  bool _hasLoadedProducts = false;
  bool _isLoading = false;
  final String ownerId;

  bool get isLoading => _isLoading;
  Stream<List<Product>> get productsStream => _productsStream;

  ProductProvider(this.ownerId) {
    _service = ProductService(ownerId);
    if (ownerId.trim().isEmpty) {
      _hasLoadedProducts = true;
      _productsStream = Stream<List<Product>>.value(const <Product>[]);
      return;
    }

    _productsStream = Stream<List<Product>>.multi((listener) {
      if (_hasLoadedProducts) {
        listener.add(List<Product>.unmodifiable(_products));
      }
      final subscription = _productUpdates.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = subscription.cancel;
    });
    _productsSubscription = _service.streamProducts.listen(
      (products) {
        _products
          ..clear()
          ..addAll(products);
        _hasLoadedProducts = true;
        _productUpdates.add(List<Product>.unmodifiable(_products));
      },
      onError: _productUpdates.addError,
    );
  }

  Future<String?> createProduct({
    required String name,
    required double price,
    double purchasePrice = 0,
    double minSalePrice = 0,
    bool allowBargain = false,
    double maxDiscountPercent = 0,
    required String category,
    required String modelCode,
    required String brand,
    required String qualityTier,
    int stockQty = 0,
    int lowStockThreshold = 5,
    int damagedQty = 0,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    _setLoading(true);
    try {
      final result = await _service.createProduct(
        name: name,
        price: price,
        purchasePrice: purchasePrice,
        minSalePrice: minSalePrice,
        allowBargain: allowBargain,
        maxDiscountPercent: maxDiscountPercent,
        category: category,
        modelCode: modelCode,
        brand: brand,
        qualityTier: qualityTier,
        stockQty: stockQty,
        lowStockThreshold: lowStockThreshold,
        damagedQty: damagedQty,
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      );
      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> updateProduct({
    required String id,
    required String name,
    required double price,
    double? purchasePrice,
    double? minSalePrice,
    bool? allowBargain,
    double? maxDiscountPercent,
    required String category,
    required String modelCode,
    required String brand,
    required String qualityTier,
    int? stockQty,
    int? lowStockThreshold,
    int? damagedQty,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    _setLoading(true);
    try {
      final result = await _service.updateProduct(
        id: id,
        name: name,
        price: price,
        purchasePrice: purchasePrice,
        minSalePrice: minSalePrice,
        allowBargain: allowBargain,
        maxDiscountPercent: maxDiscountPercent,
        category: category,
        modelCode: modelCode,
        brand: brand,
        qualityTier: qualityTier,
        stockQty: stockQty,
        lowStockThreshold: lowStockThreshold,
        damagedQty: damagedQty,
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      );
      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> deleteProduct(String id) async {
    _setLoading(true);
    try {
      final result = await _service.deleteProduct(id);
      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> updateBargainPolicies({
    required List<Product> products,
    required bool allowBargain,
    required double minSalePrice,
    required double maxDiscountPercent,
  }) async {
    _setLoading(true);
    try {
      for (final product in products) {
        final error = await _service.updateBargainPolicy(
          id: product.id,
          allowBargain: allowBargain,
          minSalePrice: minSalePrice,
          maxDiscountPercent: maxDiscountPercent,
        );
        if (error != null) {
          return '${product.name}: $error';
        }
      }
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _productUpdates.close();
    super.dispose();
  }
}
