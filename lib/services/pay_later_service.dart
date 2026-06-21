import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/pay_later_model.dart';

class PayLaterService {
  PayLaterService(this.ownerId);

  final String ownerId;
  static const _uuid = Uuid();

  String get _prefsKey => 'pay_later_people_v1_$ownerId';

  Future<List<PayLaterPerson>> getPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final people = decoded
        .whereType<Map>()
        .map((person) => PayLaterPerson.fromMap(
              Map<String, dynamic>.from(person),
            ))
        .where((person) => person.id.isNotEmpty)
        .toList();
    people.sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    return people;
  }

  Future<void> savePeople(List<PayLaterPerson> people) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(people.map((person) => person.toMap()).toList()),
    );
  }

  Future<PayLaterPerson> upsertPerson({
    String? id,
    required String name,
    required String phone,
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

  Future<bool> deletePerson(String personId) async {
    final people = await getPeople();
    final before = people.length;
    people.removeWhere((person) => person.id == personId);
    if (people.length == before) return false;
    await savePeople(people);
    return true;
  }
}
