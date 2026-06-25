class KhataType {
  static const accessory = 'accessory';
  static const repair = 'repair';
  static const cash = 'cash';

  static const values = [accessory, repair, cash];

  static String label(String value) {
    switch (value) {
      case repair:
        return 'Repair Khata';
      case cash:
        return 'Cash Udhaar';
      default:
        return 'Accessory Khata';
    }
  }
}

class PayLaterEntry {
  const PayLaterEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.note = '',
    this.orderNumber,
  });

  final String id;
  final String type;
  final double amount;
  final DateTime createdAt;
  final String note;
  final String? orderNumber;

  bool get isPayment => type == 'payment';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      if (orderNumber != null) 'orderNumber': orderNumber,
    };
  }

  factory PayLaterEntry.fromMap(Map<String, dynamic> data) {
    return PayLaterEntry(
      id: data['id']?.toString() ?? '',
      type: data['type']?.toString() == 'payment' ? 'payment' : 'debit',
      amount: _readDouble(data['amount']),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      note: data['note']?.toString() ?? '',
      orderNumber: data['orderNumber']?.toString(),
    );
  }
}

class PayLaterPerson {
  const PayLaterPerson({
    required this.id,
    required this.name,
    required this.phone,
    this.khataType = KhataType.accessory,
    this.address = '',
    this.note = '',
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.entries = const <PayLaterEntry>[],
  });

  final String id;
  final String name;
  final String phone;
  final String khataType;
  final String address;
  final String note;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<PayLaterEntry> entries;

  double get totalDebit => entries
      .where((entry) => !entry.isPayment)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get totalPaid => entries
      .where((entry) => entry.isPayment)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get balance => totalDebit - totalPaid;

  bool get isSettled => balance <= 0.01;

  bool get isOverdue {
    if (isSettled || dueDate == null) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final current = DateTime(today.year, today.month, today.day);
    return due.isBefore(current);
  }

  PayLaterPerson copyWith({
    String? name,
    String? phone,
    String? khataType,
    String? address,
    String? note,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<PayLaterEntry>? entries,
  }) {
    return PayLaterPerson(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      khataType: khataType ?? this.khataType,
      address: address ?? this.address,
      note: note ?? this.note,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'khataType': khataType,
      'address': address,
      'note': note,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      'entries': entries.map((entry) => entry.toMap()).toList(),
    };
  }

  factory PayLaterPerson.fromMap(Map<String, dynamic> data) {
    final rawEntries = data['entries'];
    final entries = rawEntries is List
        ? rawEntries
            .whereType<Map>()
            .map((entry) =>
                PayLaterEntry.fromMap(Map<String, dynamic>.from(entry)))
            .toList()
        : const <PayLaterEntry>[];
    final savedType = data['khataType']?.toString();
    final inferredType = entries.isNotEmpty &&
            entries.every(
              (entry) => (entry.orderNumber ?? '').startsWith('REPAIR-'),
            )
        ? KhataType.repair
        : KhataType.accessory;
    return PayLaterPerson(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Customer',
      phone: data['phone']?.toString() ?? '',
      khataType:
          KhataType.values.contains(savedType) ? savedType! : inferredType,
      address: data['address']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? ''),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      entries: entries,
    );
  }
}

double _readDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}
