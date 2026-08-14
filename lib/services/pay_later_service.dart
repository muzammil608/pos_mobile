import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/pay_later_model.dart';
import 'pocketbase/pocketbase_client.dart';

class PayLaterService {
  PayLaterService(this.ownerId);

  final String ownerId;
  static const _uuid = Uuid();

  String get _prefsKey => 'pay_later_people_v1_$ownerId';
  String get _updatedPrefsKey => '${_prefsKey}_updated_at';

  Future<List<PayLaterPerson>> getPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _decodePeople(prefs.getString(_prefsKey));
    final localUpdated =
        DateTime.tryParse(prefs.getString(_updatedPrefsKey) ?? '');

    if (ownerId.trim().isEmpty) return _sortPeople(local);

    try {
      final result = await PocketBaseClient.pb
          .collection('pay_later_ledgers')
          .getList(page: 1, perPage: 1, filter: 'ownerId = "$ownerId"');
      if (result.items.isEmpty) {
        if (local.isNotEmpty) await _saveRemote(local, localUpdated);
        return _sortPeople(local);
      }

      final record = result.items.first;
      final remote = _decodePeopleValue(record.data['people']);
      final remoteUpdated =
          DateTime.tryParse(record.data['clientUpdatedAt']?.toString() ?? '');
      if (localUpdated != null &&
          (remoteUpdated == null || localUpdated.isAfter(remoteUpdated))) {
        await _saveRemote(local, localUpdated, recordId: record.id);
        return _sortPeople(local);
      }

      await _saveLocal(prefs, remote, remoteUpdated);
      return _sortPeople(remote);
    } catch (_) {
      return _sortPeople(local);
    }
  }

  List<PayLaterPerson> _decodePeople(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      return _decodePeopleValue(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  List<PayLaterPerson> _decodePeopleValue(dynamic decoded) {
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((person) => PayLaterPerson.fromMap(
              Map<String, dynamic>.from(person),
            ))
        .where((person) => person.id.isNotEmpty)
        .toList();
  }

  List<PayLaterPerson> _sortPeople(List<PayLaterPerson> people) {
    final sorted = [...people];
    sorted.sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    return sorted;
  }

  Future<void> savePeople(List<PayLaterPerson> people) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedAt = DateTime.now().toUtc();
    await _saveLocal(prefs, people, updatedAt);
    if (ownerId.trim().isEmpty) return;
    try {
      await _saveRemote(people, updatedAt);
    } catch (_) {
      // The timestamp keeps the local copy authoritative until it can sync.
    }
  }

  Future<void> _saveLocal(
    SharedPreferences prefs,
    List<PayLaterPerson> people,
    DateTime? updatedAt,
  ) async {
    await prefs.setString(
      _prefsKey,
      jsonEncode(people.map((person) => person.toMap()).toList()),
    );
    if (updatedAt != null) {
      await prefs.setString(
          _updatedPrefsKey, updatedAt.toUtc().toIso8601String());
    }
  }

  Future<void> _saveRemote(
    List<PayLaterPerson> people,
    DateTime? updatedAt, {
    String? recordId,
  }) async {
    final collection = PocketBaseClient.pb.collection('pay_later_ledgers');
    var id = recordId;
    if (id == null) {
      final result = await collection.getList(
        page: 1,
        perPage: 1,
        filter: 'ownerId = "$ownerId"',
      );
      if (result.items.isNotEmpty) id = result.items.first.id;
    }
    final body = <String, dynamic>{
      'ownerId': ownerId,
      'people': people.map((person) => person.toMap()).toList(),
      'clientUpdatedAt':
          (updatedAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
    if (id == null) {
      await collection.create(body: body);
    } else {
      await collection.update(id, body: body);
    }
  }

  Future<PayLaterPerson> upsertPerson({
    String? id,
    required String name,
    required String phone,
    String khataType = KhataType.accessory,
    String address = '',
    String note = '',
    DateTime? dueDate,
  }) async {
    final people = await getPeople();
    final now = DateTime.now();
    final index = id == null ? -1 : people.indexWhere((p) => p.id == id);

    late final PayLaterPerson person;
    if (index >= 0) {
      person = people[index].copyWith(
        name: name.trim(),
        phone: phone.trim(),
        khataType: khataType,
        address: address.trim(),
        note: note.trim(),
        dueDate: dueDate,
        clearDueDate: dueDate == null,
      );
      people[index] = person;
    } else {
      person = PayLaterPerson(
        id: _uuid.v4(),
        name: name.trim(),
        phone: phone.trim(),
        khataType: khataType,
        address: address.trim(),
        note: note.trim(),
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
      );
      people.add(person);
    }

    await savePeople(people);
    return person;
  }

  Future<bool> addEntry({
    required String personId,
    required String type,
    required double amount,
    String note = '',
    String? orderNumber,
  }) async {
    if (amount <= 0) return false;

    final people = await getPeople();
    final index = people.indexWhere((person) => person.id == personId);
    if (index < 0) return false;

    final current = people[index];
    final entries = [
      PayLaterEntry(
        id: _uuid.v4(),
        type: type == 'payment' ? 'payment' : 'debit',
        amount: amount,
        note: note.trim(),
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
      ),
      ...current.entries,
    ];
    people[index] = current.copyWith(entries: entries);
    await savePeople(people);
    return true;
  }

  Future<void> createDebitForOrder({
    required String customerName,
    required double amount,
    String phone = '',
    String note = '',
    String? orderNumber,
  }) async {
    if (amount <= 0) return;

    final people = await getPeople();
    final normalizedName = customerName.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    var index = people.indexWhere((person) {
      if (person.khataType != KhataType.accessory) return false;
      final samePhone =
          normalizedPhone.isNotEmpty && person.phone.trim() == normalizedPhone;
      final sameName = normalizedName.isNotEmpty &&
          person.name.trim().toLowerCase() == normalizedName;
      return samePhone || sameName;
    });

    if (index < 0) {
      final now = DateTime.now();
      people.add(PayLaterPerson(
        id: _uuid.v4(),
        name: customerName.trim().isEmpty ? 'Walk-in Customer' : customerName,
        phone: normalizedPhone,
        khataType: KhataType.accessory,
        createdAt: now,
        updatedAt: now,
      ));
      index = people.length - 1;
    }

    final current = people[index];
    final entries = [
      PayLaterEntry(
        id: _uuid.v4(),
        type: 'debit',
        amount: amount,
        note: note.trim().isEmpty ? 'Pay later sale' : note.trim(),
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
      ),
      ...current.entries,
    ];
    people[index] = current.copyWith(
      phone: current.phone.trim().isEmpty && normalizedPhone.isNotEmpty
          ? normalizedPhone
          : current.phone,
      entries: entries,
    );
    await savePeople(people);
  }

  Future<void> syncDebitForReference({
    required String reference,
    required String customerName,
    required double amount,
    String phone = '',
    String note = '',
    String khataType = KhataType.repair,
  }) async {
    final people = await getPeople();
    final normalizedName = customerName.trim().toLowerCase();
    final normalizedPhone = phone.trim();

    var matchingPersonIndex = -1;
    var matchingEntryIndex = -1;
    for (var personIndex = 0; personIndex < people.length; personIndex++) {
      final entryIndex = people[personIndex].entries.indexWhere(
            (entry) => !entry.isPayment && entry.orderNumber == reference,
          );
      if (entryIndex >= 0) {
        matchingPersonIndex = personIndex;
        matchingEntryIndex = entryIndex;
        break;
      }
    }

    if (amount <= 0) {
      if (matchingPersonIndex < 0) return;
      final person = people[matchingPersonIndex];
      final entries = [...person.entries]..removeAt(matchingEntryIndex);
      people[matchingPersonIndex] = person.copyWith(entries: entries);
      await savePeople(people);
      return;
    }

    var personIndex = matchingPersonIndex;
    if (personIndex < 0) {
      personIndex = people.indexWhere((person) {
        if (person.khataType != khataType) return false;
        final samePhone = normalizedPhone.isNotEmpty &&
            person.phone.trim() == normalizedPhone;
        final sameName = normalizedName.isNotEmpty &&
            person.name.trim().toLowerCase() == normalizedName;
        return samePhone || sameName;
      });
    }

    if (personIndex < 0) {
      final now = DateTime.now();
      people.add(
        PayLaterPerson(
          id: _uuid.v4(),
          name: customerName.trim().isEmpty
              ? 'Walk-in Customer'
              : customerName.trim(),
          phone: normalizedPhone,
          khataType: khataType,
          createdAt: now,
          updatedAt: now,
        ),
      );
      personIndex = people.length - 1;
    }

    final person = people[personIndex];
    final entries = [...person.entries];
    final replacement = PayLaterEntry(
      id: matchingEntryIndex >= 0 ? entries[matchingEntryIndex].id : _uuid.v4(),
      type: 'debit',
      amount: amount,
      note: note.trim(),
      orderNumber: reference,
      createdAt: matchingEntryIndex >= 0
          ? entries[matchingEntryIndex].createdAt
          : DateTime.now(),
    );
    if (matchingEntryIndex >= 0) {
      entries[matchingEntryIndex] = replacement;
    } else {
      entries.insert(0, replacement);
    }

    people[personIndex] = person.copyWith(
      name: customerName.trim().isEmpty ? person.name : customerName.trim(),
      phone: normalizedPhone.isEmpty ? person.phone : normalizedPhone,
      khataType: khataType,
      entries: entries,
    );
    await savePeople(people);
  }

  Future<bool> deletePerson(String personId) async {
    final people = await getPeople();
    final before = people.length;
    people.removeWhere((person) => person.id == personId);
    if (people.length == before) return false;
    await savePeople(people);
    return true;
  }
}
