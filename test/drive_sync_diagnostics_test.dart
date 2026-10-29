import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:ibad_al_rahmann/services/drive_sync_diagnostics.dart';

void main() {
  test('records Drive HTTP status without exposing the raw API message', () {
    const privateMessage = 'private account detail must not be logged';
    final error = drive.DetailedApiRequestError(403, privateMessage);

    final fields = DriveSyncDiagnostics.failureFields(
      error,
      operation: 'list_backup_files',
    );

    expect(fields['operation'], 'list_backup_files');
    expect(fields['statusCode'], 403);
    expect(fields['reason'], 'api_http_403');
    expect(fields.values.join(' '), isNot(contains(privateMessage)));
  });

  test(
    'only an expired/unauthorized token status requests authorization refresh',
    () {
      expect(
        DriveSyncDiagnostics.requiresAuthorizationRefresh(
          drive.DetailedApiRequestError(401, 'unauthorized'),
        ),
        isTrue,
      );
      expect(
        DriveSyncDiagnostics.requiresAuthorizationRefresh(
          drive.DetailedApiRequestError(403, 'insufficient permissions'),
        ),
        isFalse,
      );
    },
  );
}
