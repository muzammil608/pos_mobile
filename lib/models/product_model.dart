import 'package:flutter/material.dart';

import '../core/constants/pocketbase_config.dart';
import '../core/utils/icon_helper.dart';

class Product {
  final String id;
  final String modelCode;
  final String brand;
  final String name;
  final String qualityTier;
  final double price;
  final double purchasePrice;
  final String category;
  final String imageFilename;
  final String collectionId;
  final String updatedAt;
  final String? ownerId;
  final int stockQty;
  final int lowStockThreshold;
  final int damagedQty;

  Product({
    required this.id,
    required this.modelCode,
    required this.brand,
    required this.name,
    required this.qualityTier,
    required this.price,
    this.purchasePrice = 0,
    required this.category,
    this.imageFilename = '',
    this.collectionId = 'pbc_4092854851',
    this.updatedAt = '',
    this.ownerId,
    this.stockQty = 0,
    this.lowStockThreshold = 5,
    this.damagedQty = 0,
  });

  IconData get icon {
    return IconHelper.getDefaultIcon(category);
  }

  String? get imageUrl {
    if (imageFilename.isEmpty || id.isEmpty || collectionId.isEmpty) {
      return null;
    }
    final baseUrl =
        '${PocketBaseConfig.baseUrl}/api/files/$collectionId/$id/$imageFilename';
    if (updatedAt.isEmpty) return baseUrl;
    return '$baseUrl?v=${Uri.encodeQueryComponent(updatedAt)}';
  }

  String get imageCacheKey => '$id:$imageFilename:$updatedAt';

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    final rawModelCode = data['model_code'];
    final rawBrand = data['brand'];
    final rawName = data['item_name'] ??
        data['name'] ??
        data['productName'] ??
        data['title'];
    final rawQualityTier = data['quality_tier'];
    final rawPrice = data['retail_rate'] ??
        data['price'] ??
        data['unitPrice'] ??
        data['amount'];
    final rawPurchasePrice = data['wholesale_rate'] ??
        data['purchasePrice'] ??
        data['costPrice'] ??
        data['cost_price'];
    final rawCategory = data['category'] ?? data['type'];

    final parsedModelCode = rawModelCode?.toString().trim() ?? '';
    final parsedBrand = rawBrand?.toString().trim() ?? '';
    final parsedName = rawName?.toString().trim() ?? '';
    final parsedQualityTier = rawQualityTier?.toString().trim() ?? '';
    final parsedCategory = rawCategory?.toString().trim() ?? '';

    final double? numericPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');
    final double? numericPurchasePrice = rawPurchasePrice is num
        ? rawPurchasePrice.toDouble()
        : double.tryParse(rawPurchasePrice?.toString() ?? '');

    final String modelCode = parsedModelCode.isEmpty ? 'N/A' : parsedModelCode;
    final String brand = parsedBrand.isEmpty ? 'Other' : parsedBrand;
    final String name = parsedName.isEmpty ? 'Unnamed Product' : parsedName;
    final String qualityTier =
        parsedQualityTier.isEmpty ? 'Normal Copy' : parsedQualityTier;
    final double price = numericPrice ?? 0.0;
    final double purchasePrice = numericPurchasePrice ?? 0.0;
    final String category = parsedCategory.isEmpty ? 'Other' : parsedCategory;

    return Product(
      id: id,
      modelCode: modelCode,
      brand: brand,
      name: name,
      qualityTier: qualityTier,
      price: price,
      purchasePrice: purchasePrice,
      category: category,
      imageFilename: data['image']?.toString() ?? '',
      collectionId: data['collectionId']?.toString() ?? 'pbc_4092854851',
      updatedAt: data['updated']?.toString() ?? '',
      ownerId: data['ownerId'] ?? data['owner_id'],
      stockQty: _readInt(data['stock_qty'] ?? data['stockQty']) ?? 0,
      lowStockThreshold:
          _readInt(data['low_stock_threshold'] ?? data['lowStockThreshold']) ??
              5,
      damagedQty: _readInt(data['damaged_qty'] ?? data['damagedQty']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model_code': modelCode,
      'brand': brand,
      'item_name': name,
      'quality_tier': qualityTier,
      'wholesale_rate': purchasePrice,
      'retail_rate': price,
      'category': category,
      if (ownerId != null) 'owner_id': ownerId,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'damaged_qty': damagedQty,
    };
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
