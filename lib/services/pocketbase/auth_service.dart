import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../models/user_model.dart';
import 'pocketbase_client.dart';

class AuthService {
  UserModel? _userFromRecord(RecordModel? record) {
    if (record == null) return null;
    final data = record.toJson();
    return UserModel.fromMap(data, record.id);
  }

  Future<UserModel?> get currentUser async {
    final store = PocketBaseClient.pb.authStore;
    if (!store.isValid) return null;
    return _userFromRecord(store.model as RecordModel?);
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final authData = await PocketBaseClient.pb
          .collection('users')
          .authWithPassword(email, password);

      final record = authData.record;
      final user = _userFromRecord(record)!;
      if (!user.isActive) {
        PocketBaseClient.pb.authStore.clear();
        throw Exception(
            'This account is inactive. Please contact your administrator.');
      }

      await PocketBaseClient.pb.collection('users').update(record.id, body: {
        'lastLoginAt': DateTime.now().toIso8601String(),
      });

      return user;
    } catch (e) {
      throw Exception('Invalid email or password.');
    }
  }

  Future<UserModel> createStaff({
    required String email,
    required String password,
    required String adminId,
    String role = 'cashier',
    String? name,
  }) async {
    try {
      final record =
          await PocketBaseClient.pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': role,
        'adminId': adminId,
        'isActive': true,
        'name': name?.trim().isNotEmpty == true
            ? name!.trim()
            : email.split('@').first,
      });

      return _userFromRecord(record)!;
    } catch (e) {
      throw Exception('Failed to create staff account: $e');
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await PocketBaseClient.pb.collection('users').update(userId, body: data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await PocketBaseClient.pb.collection('users').delete(userId);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getStaffStream(String adminId) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    UnsubscribeFunc? unsubscribe;
    var cancelled = false;

    Future<void> loadStaff() async {
      try {
        final records =
            await PocketBaseClient.pb.collection('users').getFullList(
                  filter: 'adminId = "$adminId" && isActive = true',
                );
        final list = records.map((record) {
          final user = _userFromRecord(record)!;
          final safeName = (user.name ?? '').trim().isEmpty
              ? user.email.split('@').first
              : user.name!.trim();
          return {
            ...user.toMap(),
            'id': user.id,
            'name': safeName,
          };
        }).toList();

        list.sort((a, b) {
          final nameA = (a['name'] as String).toLowerCase();
          final nameB = (b['name'] as String).toLowerCase();
          return nameA.compareTo(nameB);
        });

        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        debugPrint('Error loading staff: $e');
      }
    }

    Future<void> start() async {
      await loadStaff();
      if (adminId.trim().isEmpty || cancelled) return;

      try {
        final cancel = await PocketBaseClient.pb
            .collection('users')
            .subscribe('*', (_) => loadStaff());
        if (cancelled) {
          await cancel();
        } else {
          unsubscribe = cancel;
        }
      } catch (err) {
        debugPrint('AuthService users subscribe error: $err');
      }
    }

    start();

    controller.onCancel = () async {
      cancelled = true;
      await unsubscribe?.call();
    };

    return controller.stream;
  }

  Future<void> logout() async {
    PocketBaseClient.pb.authStore.clear();
  }
}
