import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/pocketbase_config.dart';

class PocketBaseClient {
  static late final PocketBase pb;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String currentInstallId = PocketBaseConfig.buildSignature;

    try {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        final resolvedExe = File(Platform.resolvedExecutable);
        final appDir = resolvedExe.parent.path;
        final installIdFile = File(p.join(appDir, 'install_id.txt'));

        if (installIdFile.existsSync()) {
          final content = installIdFile.readAsStringSync().trim();
          if (content.isNotEmpty) {
            currentInstallId = content;
          }
        } else if (resolvedExe.existsSync()) {
          final lastModified =
              resolvedExe.lastModifiedSync().millisecondsSinceEpoch;
          currentInstallId = '${PocketBaseConfig.buildSignature}_$lastModified';
        }
      }
    } catch (e) {
      debugPrint('[PocketBaseClient] Error reading install_id: $e');
    }

    final savedInstallId = prefs.getString('app_last_install_id');

    if (savedInstallId != currentInstallId) {
      // A normal application update changes the executable/build identity.
      // Preserve the authenticated session across updates; a missing
      // savedInstallId already represents a first run and has no session to clear.
      await prefs.setString('app_last_install_id', currentInstallId);
    }

    final store = AsyncAuthStore(
      initial: prefs.getString('pb_auth'),
      save: (String data) async => prefs.setString('pb_auth', data),
    );
    pb = PocketBase(PocketBaseConfig.baseUrl, authStore: store);
  }
}
