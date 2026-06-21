import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../models/product_model.dart';
import 'pocketbase_client.dart';

class ProductService {
  final String ownerId;

  ProductService(this.ownerId);

  Product _productFromRecord(RecordModel record) {
    return Product.fromMap({
      ...record.toJson(),
      'collectionId': record.collectionId,
    }, record.id);
  }

  Stream<List<Product>> get streamProducts {
    final controller = StreamController<List<Product>>();
    UnsubscribeFunc? unsubscribe;
    var cancelled = false;

    Future<void> fetchAndAdd() async {
      try {
        final list = await getProducts();
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        debugPrint('Error streaming products: $e');
      }
    }

    Future<void> start() async {
      await fetchAndAdd();
      if (ownerId.trim().isEmpty || cancelled) return;

      try {
        final cancel = await PocketBaseClient.pb
            .collection('products')
            .subscribe('*', (_) => fetchAndAdd());
        if (cancelled) {
          await cancel();
        } else {
          unsubscribe = cancel;
        }
      } catch (err) {
        debugPrint('ProductService products subscribe error: $err');
      }
    }

    start();

    controller.onCancel = () async {
      cancelled = true;
      await unsubscribe?.call();
    };

    return controller.stream;
  }

  Future<List<Product>> getProducts() async {
    try {
      final records = await _getProductRecords();
      final list = records.map(_productFromRecord).toList();
      return _dedupeProducts(list);
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  Future<List<RecordModel>> _getProductRecords() {
    return PocketBaseClient.pb.collection('products').getFullList(
          filter: 'ownerId = "$ownerId"',
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
    try {
      final record = await PocketBaseClient.pb.collection('products').create(
        body: {
          'item_name': name,
          'retail_rate': price,
          'wholesale_rate': purchasePrice,
          'min_sale_price': minSalePrice,
          'allow_bargain': allowBargain,
          'max_discount_percent': maxDiscountPercent,
          'category': category.trim().isEmpty ? 'panels' : category.trim(),
          'model_code': modelCode,
          'brand': brand,
          'quality_tier': qualityTier,
          'ownerId': ownerId,
          'stockQty': stockQty,
          'lowStockThreshold': lowStockThreshold,
          'damagedQty': damagedQty,
        },
        files: _imageFiles(imageBytes, imageFilename),
      );
      final saved = _productFromRecord(record);
      final bargainError = _verifyBargainPolicy(
        saved,
        allowBargain: allowBargain,
        minSalePrice: minSalePrice,
        maxDiscountPercent: maxDiscountPercent,
      );
      if (bargainError != null) return bargainError;
      return null;
    } catch (e) {
      return 'Error: $e';
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
    try {
      final record =
          await PocketBaseClient.pb.collection('products').getOne(id);
      final existing = _productFromRecord(record);

      final updatedRecord =
          await PocketBaseClient.pb.collection('products').update(
                id,
                body: {
                  'item_name': name,
                  'retail_rate': price,
                  'wholesale_rate': purchasePrice ?? existing.purchasePrice,
                  'min_sale_price': minSalePrice ?? existing.minSalePrice,
                  'allow_bargain': allowBargain ?? existing.allowBargain,
                  'max_discount_percent':
                      maxDiscountPercent ?? existing.maxDiscountPercent,
                  'category':
                      category.trim().isEmpty ? 'panels' : category.trim(),
                  'model_code': modelCode,
                  'brand': brand,
                  'quality_tier': qualityTier,
                  'stockQty': stockQty ?? existing.stockQty,
                  'lowStockThreshold':
                      lowStockThreshold ?? existing.lowStockThreshold,
                  'damagedQty': damagedQty ?? existing.damagedQty,
                },
                files: _imageFiles(imageBytes, imageFilename),
              );
      final saved = _productFromRecord(updatedRecord);
      final bargainError = _verifyBargainPolicy(
        saved,
        allowBargain: allowBargain ?? existing.allowBargain,
        minSalePrice: minSalePrice ?? existing.minSalePrice,
        maxDiscountPercent: maxDiscountPercent ?? existing.maxDiscountPercent,
      );
      if (bargainError != null) return bargainError;
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String?> deleteProduct(String id) async {
    try {
      await PocketBaseClient.pb.collection('products').delete(id);
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String?> updateBargainPolicy({
    required String id,
    required bool allowBargain,
    required double minSalePrice,
    required double maxDiscountPercent,
  }) async {
    try {
      final record = await PocketBaseClient.pb.collection('products').update(
        id,
        body: {
          'allow_bargain': allowBargain,
          'min_sale_price': minSalePrice,
          'max_discount_percent': maxDiscountPercent,
        },
      );
      return _verifyBargainPolicy(
        _productFromRecord(record),
        allowBargain: allowBargain,
        minSalePrice: minSalePrice,
        maxDiscountPercent: maxDiscountPercent,
      );
    } catch (e) {
      return 'Error: $e';
    }
  }

  String? _verifyBargainPolicy(
    Product product, {
    required bool allowBargain,
    required double minSalePrice,
    required double maxDiscountPercent,
  }) {
    const tolerance = 0.001;
    final matches = product.allowBargain == allowBargain &&
        (product.minSalePrice - minSalePrice).abs() < tolerance &&
        (product.maxDiscountPercent - maxDiscountPercent).abs() < tolerance;
    if (matches) return null;
    return 'Bargaining settings were not saved. Apply PocketBase migration '
        '1783015000_add_product_bargaining.js, then try again.';
  }

  List<http.MultipartFile> _imageFiles(
    Uint8List? imageBytes,
    String? imageFilename,
  ) {
    if (imageBytes == null || imageBytes.isEmpty) return const [];
    return [
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imageFilename?.trim().isNotEmpty == true
            ? imageFilename!.trim()
            : 'product.jpg',
      ),
    ];
  }

  List<Product> _dedupeProducts(List<Product> products) {
    final deduped = <String, Product>{};
    for (final product in products) {
      final key = product.name.trim().toLowerCase();
      final existing = deduped[key];
      if (existing == null ||
          _scoreProduct(product) > _scoreProduct(existing)) {
        deduped[key] = product;
      }
    }
    return deduped.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  int _scoreProduct(Product product) {
    var score = 0;
    if (product.category.trim().isNotEmpty &&
        product.category.toLowerCase() != 'other') {
      score += 3;
    }
    return score;
  }
}
