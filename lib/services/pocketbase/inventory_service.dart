import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import '../../models/inventory_transaction_model.dart';
import '../../models/product_model.dart';
import 'pocketbase_client.dart';

class InventorySummary {
  final int totalProducts;
  final double stockValue;
  final int lowStockCount;
  final int outOfStockCount;

  const InventorySummary({
    required this.totalProducts,
    required this.stockValue,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  factory InventorySummary.fromProducts(List<Product> products) {
    double value = 0;
    int low = 0;
    int out = 0;

    for (final p in products) {
      value += p.price * p.stockQty;
      if (p.stockQty <= 0) {
        out++;
      } else if (p.stockQty <= p.lowStockThreshold) {
        low++;
      }
    }

    return InventorySummary(
      totalProducts: products.length,
      stockValue: value,
      lowStockCount: low,
      outOfStockCount: out,
    );
  }
}

class InventoryService {
  final String ownerId;

  InventoryService(this.ownerId);

  Product _productFromRecord(RecordModel record) {
    return Product.fromMap(record.toJson(), record.id);
  }

  InventoryTransaction _txFromRecord(RecordModel record) {
    final data = record.toJson();
    if (data['createdAt'] == null && data['created'] != null) {
      data['createdAt'] = data['created'];
    }
    return InventoryTransaction.fromMap(data, record.id);
  }

  Future<List<Product>> getProducts() async {
    try {
      final pb = PocketBaseClient.pb;
      final records = await pb.collection('products').getFullList(
            filter: 'ownerId = "$ownerId"',
          );
      final list = records.map(_productFromRecord).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<Product> getProduct(String productId) async {
    final record =
        await PocketBaseClient.pb.collection('products').getOne(productId);
    return _productFromRecord(record);
  }

  Future<List<InventoryTransaction>> getTransactions({int limit = 50}) async {
    try {
      final pb = PocketBaseClient.pb;
      final records = await pb.collection('inventory_transactions').getList(
            filter: 'ownerId = "$ownerId"',
            sort: '-created',
            perPage: limit,
          );
      return records.items.map(_txFromRecord).toList();
    } catch (e) {
      return [];
    }
  }

  Stream<List<Product>> streamProducts() {
    final controller = StreamController<List<Product>>();
    UnsubscribeFunc? unsubscribe;
    var cancelled = false;

    Future<void> fetchAndAdd() async {
      try {
        final list = await getProducts();
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
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
      } catch (_) {}
    }

    start();

    controller.onCancel = () async {
      cancelled = true;
      await unsubscribe?.call();
    };

    return controller.stream;
  }

  Future<void> restock({
    required String productId,
    required String productName,
    required int quantity,
    String? note,
  }) async {
    assert(quantity > 0, 'restock quantity must be positive');

    final pb = PocketBaseClient.pb;
    final record = await pb.collection('products').getOne(productId);
    final product = _productFromRecord(record);
    final prev = product.stockQty;
    final next = prev + quantity;

    await pb.collection('products').update(productId, body: {'stockQty': next});

    await pb.collection('inventory_transactions').create(body: {
      'productId': productId,
      'productName': productName,
      'type': 'restock',
      'quantity': quantity,
      'previousStock': prev,
      'newStock': next,
      'note': note,
      'ownerId': ownerId,
    });
  }

  Future<void> adjust({
    required String productId,
    required String productName,
    required int delta,
    String? note,
  }) async {
    final pb = PocketBaseClient.pb;
    final record = await pb.collection('products').getOne(productId);
    final product = _productFromRecord(record);
    final prev = product.stockQty;
    final next = (prev + delta).clamp(0, 999999);

    await pb.collection('products').update(productId, body: {'stockQty': next});

    await pb.collection('inventory_transactions').create(body: {
      'productId': productId,
      'productName': productName,
      'type': 'adjustment',
      'quantity': delta.abs(),
      'previousStock': prev,
      'newStock': next,
      'note': note,
      'ownerId': ownerId,
    });
  }
}
