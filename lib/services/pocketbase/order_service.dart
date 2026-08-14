import 'dart:async';
import 'package:pocketbase/pocketbase.dart';
import '../../models/order_model.dart';
import 'pocketbase_client.dart';

class OrderRecordDocument {
  final Order order;

  OrderRecordDocument(this.order);

  String get id => order.id;

  Map<String, dynamic> data() {
    return {
      ...order.toMap(),
      'id': order.id,
      'createdAt': order.createdAt.toIso8601String(),
    };
  }
}

class OrderRecordSnapshot {
  final List<OrderRecordDocument> docs;

  OrderRecordSnapshot(List<Order> orders)
      : docs = orders.map(OrderRecordDocument.new).toList();
}

class OrderService {
  final String ownerId;

  OrderService(this.ownerId);

  Order _orderFromRecord(RecordModel record) {
    final data = record.toJson();
    if (data['createdAt'] == null && data['created'] != null) {
      data['createdAt'] = data['created'];
    }
    return Order.fromMap(data, record.id);
  }

  Future<Order> createOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    String status = 'pending',
    String? customerName,
    String paymentMethod = 'cash',
    double tenderedAmount = 0.0,
    double change = 0.0,
  }) async {
    final pb = PocketBaseClient.pb;
    final currentUser = pb.authStore.model as RecordModel?;
    if (currentUser == null) {
      throw StateError('User not authenticated');
    }

    final nextNumber = await _getNextOrderNumber();

    final body = {
      'orderNumber': nextNumber,
      'items': items,
      'total': total,
      'status': status,
      'ownerId': ownerId,
      'customerName':
          customerName?.trim().isNotEmpty == true ? customerName!.trim() : null,
      'paymentMethod': paymentMethod,
      'tenderedAmount': tenderedAmount,
      'change': change,
      'createdBy': currentUser.id,
    };

    final record = await pb.collection('orders').create(body: body);
    return _orderFromRecord(record);
  }

  Future<int> _getNextOrderNumber() async {
    try {
      final pb = PocketBaseClient.pb;
      final records = await pb.collection('counters').getList(
            filter: 'ownerId = "$ownerId" && name = "order_number"',
            perPage: 1,
          );

      if (records.items.isEmpty) {
        await pb.collection('counters').create(body: {
          'name': 'order_number',
          'value': 1,
          'ownerId': ownerId,
        });
        return 1;
      }

      final record = records.items.first;
      final currentValue = (record.data['value'] as num?)?.toInt() ?? 0;
      final newValue = currentValue + 1;
      await pb.collection('counters').update(record.id, body: {
        'value': newValue,
      });
      return newValue;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch % 100000;
    }
  }

  Stream<List<Order>> getOrdersStream() {
    final controller = StreamController<List<Order>>();
    UnsubscribeFunc? unsubscribe;
    var cancelled = false;

    Future<void> fetchAndAdd() async {
      try {
        final list = await getOrdersList();
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
            .collection('orders')
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

  Stream<OrderRecordSnapshot> getOrders() {
    return getOrdersStream().map(OrderRecordSnapshot.new);
  }

  Future<List<Order>> getOrdersList() async {
    try {
      final pb = PocketBaseClient.pb;
      final records = await pb.collection('orders').getFullList(
            filter: 'ownerId = "$ownerId"',
          );
      final orders = records.map(_orderFromRecord).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      return [];
    }
  }

  Future<void> updateStatus(String id, String status) async {
    await PocketBaseClient.pb
        .collection('orders')
        .update(id, body: {'status': status});
  }
}
