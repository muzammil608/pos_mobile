class RepairStatus {
  static const received = 'received';
  static const diagnosing = 'diagnosing';
  static const awaitingApproval = 'awaiting_approval';
  static const waitingForParts = 'waiting_for_parts';
  static const inProgress = 'in_progress';
  static const readyForPickup = 'ready_for_pickup';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const values = <String>[
    received,
    diagnosing,
    awaitingApproval,
    waitingForParts,
    inProgress,
    readyForPickup,
    completed,
    cancelled,
  ];

  static String label(String status) {
    switch (status) {
      case received:
        return 'Received';
      case diagnosing:
        return 'Diagnosing';
      case awaitingApproval:
        return 'Awaiting approval';
      case waitingForParts:
        return 'Waiting for parts';
      case inProgress:
        return 'In progress';
      case readyForPickup:
        return 'Ready for pickup';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class RepairPart {
  final String name;
  final int quantity;
  final double purchasePrice;
  final double salePrice;

  const RepairPart({
    required this.name,
    this.quantity = 1,
    this.purchasePrice = 0,
    this.salePrice = 0,
  });

  double get purchaseTotal => purchasePrice * quantity;
  double get saleTotal => salePrice * quantity;

  factory RepairPart.fromMap(Map<String, dynamic> data) {
    return RepairPart(
      name: data['name']?.toString().trim() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      salePrice: (data['salePrice'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'salePrice': salePrice,
      };
}

class Repair {
  final String id;
  final int jobNumber;
  final String customerName;
  final String customerPhone;
  final String deviceBrand;
  final String deviceModel;
  final String serialNumber;
  final String problemDescription;
  final String technicianNotes;
  final String assignedTechnician;
  final String status;
  final double estimatedCost;
  final double labourCost;
  final double advancePayment;
  final List<RepairPart> partsUsed;
  final DateTime createdAt;
  final DateTime? expectedDeliveryDate;
  final DateTime? completedDate;
  final String ownerId;
  final String createdBy;

  const Repair({
    required this.id,
    required this.jobNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deviceBrand,
    required this.deviceModel,
    required this.serialNumber,
    required this.problemDescription,
    required this.technicianNotes,
    required this.assignedTechnician,
    required this.status,
    required this.estimatedCost,
    required this.labourCost,
    required this.advancePayment,
    required this.partsUsed,
    required this.createdAt,
    required this.expectedDeliveryDate,
    required this.completedDate,
    required this.ownerId,
    required this.createdBy,
  });

  double get remainingBalance =>
      (estimatedCost - advancePayment).clamp(0, double.infinity).toDouble();

  double get partsPurchaseTotal =>
      partsUsed.fold(0.0, (sum, part) => sum + part.purchaseTotal);

  double get partsSaleTotal =>
      partsUsed.fold(0.0, (sum, part) => sum + part.saleTotal);

  double get profit => estimatedCost - partsPurchaseTotal;

  String get jobId => 'R-${jobNumber.toString().padLeft(5, '0')}';

  String get deviceName =>
      [deviceBrand, deviceModel].where((value) => value.isNotEmpty).join(' ');

  factory Repair.fromMap(Map<String, dynamic> data, String id) {
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final rawParts = data['partsUsed'];
    final parts = rawParts is List
        ? rawParts
            .map((part) {
              if (part is Map) {
                return RepairPart.fromMap(Map<String, dynamic>.from(part));
              }
              return RepairPart(name: part.toString().trim());
            })
            .where((part) => part.name.isNotEmpty)
            .toList()
        : <RepairPart>[];

    return Repair(
      id: id,
      jobNumber: (data['jobNumber'] as num?)?.toInt() ?? 0,
      customerName: data['customerName']?.toString() ?? '',
      customerPhone: data['customerPhone']?.toString() ?? '',
      deviceBrand: data['deviceBrand']?.toString() ?? '',
      deviceModel: data['deviceModel']?.toString() ?? '',
      serialNumber: data['serialNumber']?.toString() ?? '',
      problemDescription: data['problemDescription']?.toString() ?? '',
      technicianNotes: data['technicianNotes']?.toString() ?? '',
      assignedTechnician: data['assignedTechnician']?.toString() ?? '',
      status: data['status']?.toString() ?? RepairStatus.received,
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble() ?? 0,
      labourCost: (data['labourCost'] as num?)?.toDouble() ?? 0,
      advancePayment: (data['advancePayment'] as num?)?.toDouble() ?? 0,
      partsUsed: parts,
      createdAt:
          optionalDate(data['createdAt'] ?? data['created']) ?? DateTime.now(),
      expectedDeliveryDate: optionalDate(data['expectedDeliveryDate']),
      completedDate: optionalDate(data['completedDate']),
      ownerId: data['ownerId']?.toString() ?? '',
      createdBy: data['createdBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobNumber': jobNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deviceBrand': deviceBrand,
      'deviceModel': deviceModel,
      'serialNumber': serialNumber,
      'problemDescription': problemDescription,
      'technicianNotes': technicianNotes,
      'assignedTechnician': assignedTechnician,
      'status': status,
      'estimatedCost': estimatedCost,
      'labourCost': labourCost,
      'advancePayment': advancePayment,
      'partsUsed': partsUsed.map((part) => part.toMap()).toList(),
      'ownerId': ownerId,
      'createdBy': createdBy,
      if (expectedDeliveryDate != null)
        'expectedDeliveryDate': expectedDeliveryDate!.toUtc().toIso8601String(),
      if (completedDate != null)
        'completedDate': completedDate!.toUtc().toIso8601String(),
    };
  }
}
