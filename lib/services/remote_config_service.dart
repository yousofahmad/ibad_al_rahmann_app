import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig get _remoteConfig {
    try {
      return FirebaseRemoteConfig.instance;
    } catch (e) {
      // If Firebase is not initialized, this will throw.
      // We should ideally ensure initialization in main.dart, 
      // but a fallback or late initialization check here adds safety.
      rethrow;
    }
  }

  static Future<void> init() async {
    // Disabled: Replaced by local Dar Al-Ifta offline calculation
  }

  /// The global correction offset pushed from Firebase Console (Deprecated in favor of Dar Al-Ifta).
  static int get globalHijriOffset => 0;
}
