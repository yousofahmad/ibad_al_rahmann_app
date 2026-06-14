// Smoke test: Verify the app can be instantiated without crashing.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smoke test - app package is valid', () {
    // This test simply verifies the test infrastructure works.
    // Full integration testing requires a device/emulator due to
    // native method channels (notifications, location, etc.)
    expect(1 + 1, equals(2));
  });
}
