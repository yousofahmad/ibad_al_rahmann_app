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
    try {
      final config = _remoteConfig;
      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await config.setDefaults(const {"global_hijri_offset": 0});
      await config.fetchAndActivate();

      // Save remote offset under its OWN key – never overwrites the user's
      // manual 'hijri_offset' key stored by PrayerService.
      final offset = config.getInt("global_hijri_offset");
      final prefs = CacheHelper.prefs;
      await prefs.setInt("remote_hijri_offset", offset);
      await HomeWidget.saveWidgetData<int>("widget_hijri_offset", offset);
      await HomeWidget.updateWidget(
        name: 'PrayerWidgetProvider',
        androidName: 'PrayerWidgetProvider',
      );
    } catch (e) {
      debugPrint("Remote Config Error: $e");
    }
  }

  /// The global correction offset pushed from Firebase Console.
  /// This is intentionally separate from the user's manual offset.
  static int get globalHijriOffset {
    try {
      // Check if Firebase is initialized before trying to get instance
      if (Firebase.apps.isEmpty) return 0;
      return _remoteConfig.getInt("global_hijri_offset");
    } catch (e) {
      debugPrint("Error getting globalHijriOffset: $e");
      return 0;
    }
  }
}
