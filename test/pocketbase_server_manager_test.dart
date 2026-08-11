import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/pocketbase/pocketbase_server_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PocketBaseServerManager Tests', () {
    test('isServerRunning returns false for unused port', () async {
      final isRunning = await PocketBaseServerManager.isServerRunning(
        host: '127.0.0.1',
        port: 59999, // Unused port for test
      );

      expect(isRunning, isFalse);
    });

    test('startIfNeeded completes without throwing unhandled exceptions', () async {
      final result = await PocketBaseServerManager.startIfNeeded();
      expect(result, isA<bool>());
    });

    test('stop completes without error', () async {
      await PocketBaseServerManager.stop();
    });
  });
}
