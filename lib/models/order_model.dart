class Order {
  final String id;
  final int orderNumber;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status;
  final DateTime createdAt;
  final String? ownerId;
  final String? customerName;
  final String? paymentMethod;
  final double tenderedAmount;
  final double change;
  final String? createdBy;

  Order({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    this.ownerId,
    this.customerName,
    this.paymentMethod = 'cash',
    this.tenderedAmount = 0.0,
    this.change = 0.0,
    this.createdBy,
  });

  factory Order.fromMap(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      orderNumber: (data['orderNumber'] as num?)?.toInt() ?? 0,
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      ownerId: data['ownerId'],
      customerName: data['customerName'],
      paymentMethod: data['paymentMethod'] ?? 'cash',
      tenderedAmount: (data['tenderedAmount'] as num?)?.toDouble() ?? 0.0,
      change: (data['change'] as num?)?.toDouble() ?? 0.0,
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items,
      'total': total,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'orderNumber': orderNumber,
      'paymentMethod': paymentMethod ?? 'cash',
      'tenderedAmount': tenderedAmount,
      'change': change,
      if (ownerId != null) 'ownerId': ownerId,
      if (customerName != null) 'customerName': customerName,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}
