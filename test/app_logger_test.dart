import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('AppLogger sensitive-data redaction', () {
    test(
      'redacts emails, bearer tokens, secret fields and URL credentials',
      () {
        const input =
            'account=user@example.com Authorization: Bearer abc.def-123 '
            'standalone=Bearer standalone-xyz '
            'access_token=access-123 refresh_token=refresh-456 '
            'password="hunter two" client_secret=secret-value '
            'https://alice:private-pass@example.com/resource';

        final safe = AppLogger.redactForTesting(input);

        expect(safe, contains('[email redacted]'));
        expect(safe, contains('Bearer [redacted]'));
        expect(safe, contains('access_token=[redacted]'));
        expect(safe, contains('refresh_token=[redacted]'));
        expect(safe, contains('password=[redacted]'));
        expect(safe, contains('client_secret=[redacted]'));
        expect(safe, contains('https://[redacted]@'));
        for (final secret in [
          'user@example.com',
          'abc.def-123',
          'standalone-xyz',
          'access-123',
          'refresh-456',
          'hunter two',
          'secret-value',
          'private-pass',
        ]) {
          expect(safe, isNot(contains(secret)));
        }
      },
    );

    test(
      'uses the installed version and build number for diagnostic reports',
      () async {
        PackageInfo.setMockInitialValues(
          appName: 'Ibad',
          packageName: 'app.ibad',
          version: '1.3.3',
          buildNumber: '13',
          buildSignature: '',
        );

        expect(
          await AppLogger.getInstalledVersionLabelForTesting(),
          '1.3.3+13',
        );
      },
    );
  });
}
