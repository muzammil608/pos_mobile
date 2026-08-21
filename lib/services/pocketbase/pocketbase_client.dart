import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/pocketbase_config.dart';
import 'pocketbase_server_manager.dart';

class PocketBaseClient {
  static late final PocketBase pb;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String currentInstallId = PocketBaseConfig.buildSignature;
    bool isFreshInstalledDesktopApp = false;

    try {
      if (!kIsWeb && Platform.isWindows) {
        // The marker lives outside the application directory so the app can
        // write it when installed under Program Files. The Windows
        // uninstaller removes this backend directory, while normal updates
        // leave it in place.
        final stateDir = PocketBaseServerManager.installationStateDirectory;
        final installIdFile = File(p.join(stateDir, 'install_id.txt'));

        if (installIdFile.existsSync()) {
          final content = installIdFile.readAsStringSync().trim();
          if (content.isNotEmpty) {
            currentInstallId = content;
          }
        } else {
          isFreshInstalledDesktopApp = true;
          currentInstallId =
              '${PocketBaseConfig.buildSignature}_${DateTime.now().microsecondsSinceEpoch}';
          installIdFile.parent.createSync(recursive: true);
          installIdFile.writeAsStringSync(currentInstallId, flush: true);
        }
      }
    } catch (e) {
      debugPrint('[PocketBaseClient] Error reading install_id: $e');
    }

    if (isFreshInstalledDesktopApp && prefs.getString('pb_auth') != null) {
      // Preferences can survive a Windows uninstall. Do not reuse the old
      // PocketBase token on a genuinely fresh installation.
      await prefs.remove('pb_auth');
      debugPrint('[PocketBaseClient] Fresh installation detected; cleared saved auth session.');
    }

    if (prefs.getString('app_last_install_id') != currentInstallId) {
      await prefs.setString('app_last_install_id', currentInstallId);
    }

    final store = AsyncAuthStore(
      initial: prefs.getString('pb_auth'),
      save: (String data) async => prefs.setString('pb_auth', data),
    );
    pb = PocketBase(PocketBaseConfig.baseUrl, authStore: store);
  }
}
