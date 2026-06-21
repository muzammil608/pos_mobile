import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/pocketbase_config.dart';

class PocketBaseClient {
  static late final PocketBase pb;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      initial: prefs.getString('pb_auth'),
      save: (String data) async => prefs.setString('pb_auth', data),
    );
    pb = PocketBase(PocketBaseConfig.baseUrl, authStore: store);
  }
}
