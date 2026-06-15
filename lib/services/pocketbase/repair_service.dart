import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../../models/repair_model.dart';
import 'pocketbase_client.dart';

class RepairService {
  RepairService(this.ownerId);

  final String ownerId;

  Repair _fromRecord(RecordModel record) {
    final data = record.toJson();
    data['createdAt'] ??= data['created'];
    return Repair.fromMap(data, record.id);
  }

  Future<Repair> createRepair({
    required String customerName,
    required String customerPhone,
    required String deviceBrand,
    required String deviceModel,
    required String serialNumber,
    required String problemDescription,
    String technicianNotes = '',
    String assignedTechnician = '',
    String status = RepairStatus.received,
    double estimatedCost = 0,
    double labourCost = 0,
    double advancePayment = 0,
    List<RepairPart> partsUsed = const [],
    DateTime? expectedDeliveryDate,
    DateTime? completedDate,
  }) async {
    final pb = PocketBaseClient.pb;
    final currentUser = pb.authStore.model as RecordModel?;
    if (currentUser == null) throw StateError('User not authenticated');

    final body = {
      'jobNumber': await _getNextJobNumber(),
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
      'deviceBrand': deviceBrand.trim(),
      'deviceModel': deviceModel.trim(),
      'serialNumber': serialNumber.trim(),
      'problemDescription': problemDescription.trim(),
      'technicianNotes': technicianNotes.trim(),
      'assignedTechnician': assignedTechnician.trim(),
      'status': status,
      'estimatedCost': estimatedCost,
      'labourCost': labourCost,
      'advancePayment': advancePayment,
      'partsUsed': partsUsed.map((part) => part.toMap()).toList(),
      'ownerId': ownerId,
      'createdBy': currentUser.id,
      if (expectedDeliveryDate != null)
        'expectedDeliveryDate': expectedDeliveryDate.toUtc().toIso8601String(),
      if (completedDate != null)
        'completedDate': completedDate.toUtc().toIso8601String(),
    };

    return _fromRecord(
      await pb.collection('repairs').create(body: body),
    );
  }

  Future<Repair> updateRepair(
    String id, {
    required Map<String, dynamic> values,
  }) async {
    return _fromRecord(
      await PocketBaseClient.pb.collection('repairs').update(id, body: values),
    );
  }

  Future<Repair> updateStatus(String id, String status) async {
    final body = <String, dynamic>{'status': status};
    if (status == RepairStatus.completed) {
      body['completedDate'] = DateTime.now().toUtc().toIso8601String();
    }
    return _fromRecord(
      await PocketBaseClient.pb.collection('repairs').update(id, body: body),
    );
  }

  Future<void> deleteRepair(String id) async {
    await PocketBaseClient.pb.collection('repairs').delete(id);
  }

  Future<List<Repair>> getRepairsList() async {
    final records = await PocketBaseClient.pb.collection('repairs').getFullList(
          filter: 'ownerId = "$ownerId"',
          sort: '-created',
        );
    return records.map(_fromRecord).toList();
  }

  Stream<List<Repair>> getRepairsStream() {
    final controller = StreamController<List<Repair>>();
    UnsubscribeFunc? unsubscribe;
    var cancelled = false;

    Future<void> refresh() async {
      try {
        final repairs = await getRepairsList();
        if (!controller.isClosed) controller.add(repairs);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    Future<void> start() async {
      await refresh();
      if (cancelled || ownerId.isEmpty) return;
      try {
        final cancel = await PocketBaseClient.pb
            .collection('repairs')
            .subscribe('*', (_) => refresh());
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

  Future<int> _getNextJobNumber() async {
    final pb = PocketBaseClient.pb;
    try {
      final result = await pb.collection('counters').getList(
            filter: 'ownerId = "$ownerId" && name = "repair_job_number"',
            perPage: 1,
          );
      if (result.items.isEmpty) {
        await pb.collection('counters').create(body: {
          'name': 'repair_job_number',
          'value': 1,
          'ownerId': ownerId,
        });
        return 1;
      }

      final counter = result.items.first;
      final next = ((counter.data['value'] as num?)?.toInt() ?? 0) + 1;
      await pb.collection('counters').update(
        counter.id,
        body: {'value': next},
      );
      return next;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch % 100000;
    }
  }
}
