class InventoryTransaction {
  final String id;
  final String productId;
  final String productName;
  final String type;
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? note;
  final String? orderId;
  final DateTime createdAt;

  InventoryTransaction({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.note,
    this.orderId,
    required this.createdAt,
  });

  factory InventoryTransaction.fromMap(Map<String, dynamic> data, String id) {
    return InventoryTransaction(
      id: id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      type: data['type'] ?? '',
      quantity: _readInt(data['quantity']) ?? 0,
      previousStock: _readInt(data['previousStock']) ?? 0,
      newStock: _readInt(data['newStock']) ?? 0,
      note: data['note'],
      orderId: data['orderId'],
      createdAt:
          DateTime.tryParse(data['createdAt'] ?? data['created'] ?? '') ??
              DateTime.now(),
    );
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
