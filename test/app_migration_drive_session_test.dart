import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:hive/hive.dart';
import 'package:ibad_al_rahmann/core/helpers/app_migration_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late GoogleSignInPlatform originalGoogleSignInPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppMigrationHelper.keyAppVersionCode:
          AppMigrationHelper.currentVersionCode - 1,
      'last_sync_email': 'account@example.com',
      'last_sync_time': '2026-11-02T22:00:00.000',
      'legacy_obsolete_value': 'remove-me',
    });
    hiveDirectory = await Directory.systemTemp.createTemp(
      'app_migration_drive_session_test_',
    );
    Hive.init(hiveDirectory.path);
    originalGoogleSignInPlatform = GoogleSignInPlatform.instance;
  });

  tearDown(() async {
    GoogleSignInPlatform.instance = originalGoogleSignInPlatform;
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('app version migration preserves the Google Drive session', () async {
    final fakePlatform = _FakeGoogleSignInPlatform();
    GoogleSignInPlatform.instance = fakePlatform;

    await AppMigrationHelper.checkAndPerformMigration(
      refreshPrayerSchedule: () async {},
    );

    final prefs = await SharedPreferences.getInstance();
    expect(fakePlatform.signOutCalls, 0);
    expect(prefs.getString('last_sync_email'), 'account@example.com');
    expect(prefs.getString('last_sync_time'), '2026-11-02T22:00:00.000');
    expect(prefs.containsKey('legacy_obsolete_value'), isFalse);
    expect(
      prefs.getInt(AppMigrationHelper.keyAppVersionCode),
      AppMigrationHelper.currentVersionCode,
    );
  });
}

class _FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  int signOutCalls = 0;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) {
    throw UnimplementedError();
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalls++;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}
