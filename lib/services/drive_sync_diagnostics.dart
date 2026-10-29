import 'package:googleapis/drive/v3.dart' as drive;

class DriveSyncDiagnostics {
  static bool requiresAuthorizationRefresh(Object error) =>
      error is drive.DetailedApiRequestError && error.status == 401;

  static Map<String, Object?> failureFields(
    Object error, {
    required String operation,
  }) {
    if (error is drive.DetailedApiRequestError) {
      final safeReasons = error.errors
          .map((detail) => detail.reason)
          .whereType<String>()
          .map(
            (reason) => RegExp(r'^[A-Za-z0-9_]+$').hasMatch(reason)
                ? reason
                : 'unknown',
          )
          .take(3)
          .toList(growable: false);
      return {
        'operation': operation,
        'statusCode': error.status,
        'reason': 'api_http_${error.status ?? 'unknown'}',
        if (safeReasons.isNotEmpty) 'apiReasonCodes': safeReasons.join(','),
      };
    }
    return {'operation': operation, 'reason': 'exception_${error.runtimeType}'};
  }
}
