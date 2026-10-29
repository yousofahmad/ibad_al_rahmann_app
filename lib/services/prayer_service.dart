import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'notification_schedule_runner.dart';
import 'notification_schedule_helpers.dart';
import 'home_widget_service.dart';
import 'package:home_widget/home_widget.dart';
import 'prayer_notification_platform_channel.dart';

import 'package:ibad_al_rahmann/features/locations/models/city_profile.dart';
import 'package:hijri/hijri_calendar.dart';

import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:geocoding/geocoding.dart';

import 'remote_config_service.dart';

import 'package:ibad_al_rahmann/services/app_logger.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';

import 'hijri_source_service.dart';
import 'egyptian_hijri_calendar.dart';

@pragma('vm:entry-point')
Future<void> backgroundWidgetUpdateCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize().catchError((e) {
    debugPrint('AlarmManager background init error: $e');
    return false;
  });

  try {
    debugPrint("Background Task: Running Midnight Refresh...");
    await CacheHelper.init();
    // Official data must be ready before background scheduling decisions.
    try {
      await EgyptianHijriCalendar.instance.initialize();
    } catch (e) {
      debugPrint(
        'Official Egyptian Hijri calendar unavailable in background: $e',
      );
    }
    // Firebase/Remote Config are optional; local notifications must continue.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await RemoteConfigService.init();
    } catch (e) {
      debugPrint('Optional Firebase/Remote Config unavailable: $e');
    }
    HijriCalendar.setLocal('ar');
    Intl.defaultLocale = 'ar';

    final service = PrayerService();
    await service.init();
    await HijriSourceService.syncOffsetIfNeeded(rescheduleNotifications: false);
    await service.scheduleNotifications(isUserAction: true);
    debugPrint("Background Task: Refresh Complete.");
  } catch (e) {
    debugPrint("Background Widget Callback Error: $e");
    try {
      final now = DateTime.now();
      final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 5);
      await AndroidAlarmManager.oneShotAt(
        tomorrowMidnight,
        9999,
        backgroundWidgetUpdateCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> prayerLocationRefreshCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final callbackStartedAt = DateTime.now();
  PrayerService? service;
  String? prayerName;
  DateTime? expectedPrayerAt;
  try {
    await AndroidAlarmManager.initialize();
    await CacheHelper.init();
    await AppLogger.init();
    try {
      await EgyptianHijriCalendar.instance.initialize();
    } catch (error) {
      AppLogger.logEvent('PrayerLocationRefresh', 'calendar_init_failed', {
        'safe_failure_type': error.runtimeType.toString(),
      });
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await RemoteConfigService.init();
    } catch (error) {
      AppLogger.logEvent(
        'PrayerLocationRefresh',
        'optional_config_unavailable',
        {'safe_failure_type': error.runtimeType.toString()},
      );
    }
    HijriCalendar.setLocal('ar');
    Intl.defaultLocale = 'ar';
    final prefs = CacheHelper.prefs;
    prayerName = prefs.getString('prayer_location_refresh_expected_prayer');
    final expectedMillis = prefs.getInt(
      'prayer_location_refresh_expected_at_ms',
    );
    if (expectedMillis != null) {
      expectedPrayerAt = DateTime.fromMillisecondsSinceEpoch(expectedMillis);
    }
    service = PrayerService();
    await service._loadSettings();
    await service._refreshLocationInBackground(
      trigger: 'before_prayer',
      expectedPrayerAt: expectedPrayerAt,
      prayerName: prayerName,
    );
    await service._scheduleNextLocationRefresh(
      trigger: 'scheduled_refresh_completed',
    );
    AppLogger.logEvent('PrayerLocationRefresh', 'callback_finished', {
      'trigger': 'before_prayer',
      'expected_prayer': prayerName,
      'expected_prayer_at': expectedPrayerAt?.toIso8601String(),
      'actual_started_at': callbackStartedAt.toIso8601String(),
      'actual_finished_at': DateTime.now().toIso8601String(),
      'duration_ms': DateTime.now()
          .difference(callbackStartedAt)
          .inMilliseconds,
      'outcome': 'completed',
    });
  } catch (error) {
    AppLogger.logEvent('PrayerLocationRefresh', 'callback_failed', {
      'trigger': 'before_prayer',
      'expected_prayer': prayerName,
      'expected_prayer_at': expectedPrayerAt?.toIso8601String(),
      'actual_started_at': callbackStartedAt.toIso8601String(),
      'actual_finished_at': DateTime.now().toIso8601String(),
      'duration_ms': DateTime.now()
          .difference(callbackStartedAt)
          .inMilliseconds,
      'outcome': 'failed',
      'safe_failure_type': error.runtimeType.toString(),
    });
    try {
      await service?._scheduleNextLocationRefresh(
        trigger: 'callback_failure_recovery',
      );
    } catch (_) {}
  }
}

class PrayerService extends ChangeNotifier {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;

  PrayerService._internal() {
    _loadSettingsSync();
  }

  void _loadSettingsSync() {
    try {
      final prefs = CacheHelper.prefs;
      double? lat = prefs.getDouble('last_lat') ?? prefs.getDouble('latitude');
      double? lng = prefs.getDouble('last_lng') ?? prefs.getDouble('longitude');
      if (lat != null && lng != null) {
        _coordinates = Coordinates(lat, lng);
      } else {
        _coordinates = Coordinates(30.0444, 31.2357);
      }
      _hijriOffset = prefs.getInt(keyHijriOffset) ?? 0;
      _localHijriDelta = prefs.getInt(keyLocalHijriDelta) ?? 0;
      _is24Hour = prefs.getBool(keyIs24Hour) ?? false;
      _currentCityName = prefs.getString('last_city_name') ?? "";
      String? methodKey = prefs.getString(keyMethod);
      if (methodKey != null) _method = _getMethodFromKey(methodKey);
      String? madhabKey = prefs.getString(keyMadhab);
      if (madhabKey != null) {
        _madhab = madhabKey == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      }
      _ramadanIshaDelayMode = prefs.getInt(keyRamadanCycle) ?? 0;
      const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      for (String p in prayers) {
        _adjustments[p] = prefs.getInt('$keyAdjustPrefix$p') ?? 0;
      }
    } catch (_) {}
  }

  Coordinates? _coordinates;
  CalculationMethod _method = CalculationMethod.egyptian;
  Madhab _madhab = Madhab.shafi;
  int _ramadanIshaDelayMode = 0; // 0=Original, 90=90min, 120=120min
  int _hijriOffset = 0; // Manual user correction (-2 to +2)
  int _localHijriDelta = 0; // Country-based delta (+1/-1) – no Firebase needed
  bool _is24Hour = false;

  // Multi-Location
  List<CityProfile> _savedCities = [];
  CityProfile? _activeCity;
  String _currentCityName = "";

  // Manual adjustments in minutes
  final Map<String, int> _adjustments = {
    'Fajr': 0,
    'Sunrise': 0,
    'Dhuhr': 0,
    'Asr': 0,
    'Maghrib': 0,
    'Isha': 0,
  };

  // Keys for SharedPreferences
  static const String keyMethod = 'calculation_method';
  static const String keyMadhab = 'madhab';

  /// Key for the user's manual Hijri correction (NEVER written by Firebase).
  static const String keyHijriOffset = 'hijri_offset_manual';

  /// Key for the country-based local delta (independent of Firebase).
  static const String keyLocalHijriDelta = 'hijri_local_delta';

  /// Stores the Hijri month in which the user last set the manual offset.
  /// On a new month the offset is auto-reset to 0.
  static const String keyHijriOffsetMonth = 'hijri_offset_month';

  /// Returns true if it is currently the window for Surah Al-Kahf
  /// (From Thursday Maghrib to Friday Maghrib).
  bool isKahfTime() {
    final now = DateTime.now();
    final times = getPrayerTimes();
    if (times == null) return false;

    final maghrib = times.timeForPrayer(Prayer.maghrib);
    if (maghrib == null) return false;

    // Friday: Before Maghrib
    if (now.weekday == DateTime.friday) {
      return now.isBefore(maghrib);
    }

    // Thursday: After Maghrib
    if (now.weekday == DateTime.thursday) {
      return now.isAfter(maghrib);
    }

    return false;
  }

  static const String keyIs24Hour = 'is_24_hour';
  static const String keyAdjustPrefix = 'adjust_';
  static const String keyRamadanCycle = 'ramadan_isha_delay';
  static const String keySavedCities = 'saved_cities';
  static const String keyActiveCityId = 'active_city_id';

  bool _isInitializing = false;
  DateTime? _lastInitTime;

  Future<void> saveSettingsToPrefs() async {
    final prefs = CacheHelper.prefs;
    if (_coordinates != null) {
      await prefs.setDouble('latitude', _coordinates!.latitude);
      await prefs.setDouble('longitude', _coordinates!.longitude);
    }

    // Sync current calculation settings for native
    await prefs.setString(
      'calculation_method',
      _activeCity?.calculationMethod ?? _method.name.toUpperCase(),
    );
    await prefs.setString(
      'madhab',
      _activeCity?.madhab ?? _madhab.name.toUpperCase(),
    );
    // Save total offset (manual + delta + firebase) for Native Android to use
    await prefs.setInt('hijri_offset', hijriOffset);
    await prefs.setInt(
      'firebase_hijri_offset',
      RemoteConfigService.globalHijriOffset,
    );
  }

  Future<void> init() async {
    if (_isInitializing) return;
    if (_lastInitTime != null &&
        DateTime.now().difference(_lastInitTime!) <
            const Duration(seconds: 30)) {
      // If initialized recently, only update persistent elements without heavy rescheduling
      updatePersistentElements();
      return;
    }

    _isInitializing = true;
    _lastInitTime = DateTime.now();

    try {
      // Note: RemoteConfigService.init() is now handled in main() to avoid redundancy
      await _loadSettings();
      await Future.delayed(Duration.zero); // Yield

      // Non-blocking location acquisition: Use cached or default coordinates first,
      // then refresh in background.
      await _initializeLocationFromCache();

      // Save settings to prefs for native code
      await saveSettingsToPrefs();
      unawaited(
        _scheduleNextLocationRefresh(trigger: 'prayer_service_initialized'),
      );

      await Future.delayed(Duration.zero); // Yield

      // Defer heavy notification and alarm scheduling until after app startup
      Future.delayed(const Duration(seconds: 1), () {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _refreshLocationInBackground();
          // Also check if GPS is stale (> 7 days) and silently refresh in background
          refreshLocationIfStale();
        } else {
          scheduleNotifications(isUserAction: false);
        }
      });
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initializeLocationFromCache() async {
    final prefs = CacheHelper.prefs;
    double? lat = prefs.getDouble('last_lat');
    double? lng = prefs.getDouble('last_lng');

    if (lat != null && lng != null) {
      _coordinates = Coordinates(lat, lng);
      AppLogger.logEvent('PrayerLocationRefresh', 'cached_location_loaded', {
        'source': 'last_known_location',
        'coordinates_logged': false,
      });
    } else {
      _coordinates = Coordinates(30.0444, 31.2357);
      prefs.setDouble('last_lat', 30.0444);
      prefs.setDouble('last_lng', 31.2357);
      prefs.setDouble('latitude', 30.0444);
      prefs.setDouble('longitude', 31.2357);
      AppLogger.logEvent(
        'PrayerLocationRefresh',
        'location_fallback_selected',
        {'source': 'default_cairo_coordinates', 'coordinates_logged': false},
      );
    }
  }

  Future<void> _refreshLocationInBackground({
    String trigger = 'app_start',
    DateTime? expectedPrayerAt,
    String? prayerName,
  }) async {
    final startedAt = DateTime.now();
    void logFinished(String outcome, {String? reason, String? distanceBucket}) {
      AppLogger.logEvent('PrayerLocationRefresh', 'attempt_finished', {
        'trigger': trigger,
        'expected_prayer': prayerName,
        'expected_prayer_at': expectedPrayerAt?.toIso8601String(),
        'actual_started_at': startedAt.toIso8601String(),
        'actual_finished_at': DateTime.now().toIso8601String(),
        'duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
        'outcome': outcome,
        'reason': reason,
        'distance_bucket': distanceBucket,
        'coordinates_logged': false,
      });
    }

    AppLogger.logEvent('PrayerLocationRefresh', 'attempt_started', {
      'trigger': trigger,
      'expected_prayer': prayerName,
      'expected_prayer_at': expectedPrayerAt?.toIso8601String(),
      'actual_started_at': startedAt.toIso8601String(),
      'outcome': 'attempted',
      'coordinates_logged': false,
    });
    try {
      if (_activeCity != null) {
        logFinished('skipped', reason: 'manual_city_override');
        return;
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await scheduleNotifications(isUserAction: false);
        logFinished('skipped', reason: 'location_service_disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await scheduleNotifications(isUserAction: false);
        logFinished('skipped', reason: 'permission_denied_forever');
        return;
      }

      // Use high accuracy so we match other apps to within ~5 metres.
      // 20s timeout is generous enough for a cold GPS fix while still non-blocking.
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // Record timestamp of successful GPS fix for periodic refresh logic
      final prefs2 = CacheHelper.prefs;
      await prefs2.setInt(
        'last_gps_update_ms',
        DateTime.now().millisecondsSinceEpoch,
      );

      final oldLat = _coordinates?.latitude;
      final oldLng = _coordinates?.longitude;

      _coordinates = Coordinates(position.latitude, position.longitude);

      final prefs = CacheHelper.prefs;
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);

      bool shouldReschedule = true;
      double? distanceMeters;
      if (oldLat != null && oldLng != null) {
        distanceMeters = Geolocator.distanceBetween(
          oldLat,
          oldLng,
          position.latitude,
          position.longitude,
        );
        if (distanceMeters < 1000) {
          shouldReschedule = false;
        }
      }

      if (shouldReschedule) {
        await scheduleNotifications(isUserAction: false);
      } else {
        await updatePersistentElements();
      }

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final city = place.locality?.isNotEmpty == true
              ? place.locality
              : place.subAdministrativeArea;
          if (city != null && city.isNotEmpty) {
            await prefs.setString('last_city_name', city);
            _currentCityName = city;
            notifyListeners();
          }
        }
      } catch (error) {
        AppLogger.logEvent(
          'PrayerLocationRefresh',
          'reverse_geocoding_failed',
          {'safe_failure_type': error.runtimeType.toString()},
        );
      }
      logFinished(
        'success',
        reason: shouldReschedule
            ? 'location_updated_rescheduled'
            : 'location_updated_under_threshold',
        distanceBucket: distanceMeters == null
            ? null
            : _locationDistanceBucket(distanceMeters),
      );
    } catch (e) {
      try {
        await scheduleNotifications(isUserAction: false);
      } catch (scheduleError) {
        AppLogger.logEvent(
          'PrayerLocationRefresh',
          'fallback_schedule_failed',
          {'safe_failure_type': scheduleError.runtimeType.toString()},
        );
      }
      logFinished('failed', reason: 'exception_${e.runtimeType}');
    }
  }

  // ── Periodic Location Refresh ─────────────────────────────────────────────
  // Called on every app open (via init()) to refresh GPS if stale (> 7 days).
  // Falls back to cached coordinates on failure — never blocks the UI.
  Future<void> refreshLocationIfStale() async {
    // Skip when an active city is selected (user's explicit override)
    if (_activeCity != null) return;

    final prefs = CacheHelper.prefs;
    final lastMs = prefs.getInt('last_gps_update_ms') ?? 0;
    final daysSinceLast = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
        .inDays;

    if (daysSinceLast < 7) return; // Still fresh — no need to refresh

    debugPrint(
      'PrayerService: GPS stale ($daysSinceLast days old). Requesting fresh fix...',
    );
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      final oldLat = _coordinates?.latitude;
      final oldLng = _coordinates?.longitude;
      _coordinates = Coordinates(position.latitude, position.longitude);

      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
      await prefs.setDouble('latitude', position.latitude);
      await prefs.setDouble('longitude', position.longitude);
      await prefs.setInt(
        'last_gps_update_ms',
        DateTime.now().millisecondsSinceEpoch,
      );

      AppLogger.logEvent('PrayerLocationRefresh', 'stale_location_refreshed', {
        'trigger': 'app_open_stale_check',
        'age_days_before_update': daysSinceLast,
        'outcome': 'success',
        'coordinates_logged': false,
      });

      // Reschedule only if location moved more than 1km
      if (oldLat != null && oldLng != null) {
        final dist = Geolocator.distanceBetween(
          oldLat,
          oldLng,
          position.latitude,
          position.longitude,
        );
        if (dist > 1000) await scheduleNotifications(isUserAction: false);
      }
    } catch (e) {
      // Non-fatal: keep using cached coordinates
      AppLogger.logEvent(
        'PrayerLocationRefresh',
        'stale_location_refresh_failed',
        {
          'trigger': 'app_open_stale_check',
          'outcome': 'failed_using_cache',
          'safe_failure_type': e.runtimeType.toString(),
          'coordinates_logged': false,
        },
      );
    }
  }

  Future<void> _syncNativeEngineConfig() async {
    final prefs = CacheHelper.prefs;

    // Write effective coordinates so NativePrayerManager can read them even if an active city is selected
    if (_activeCity != null) {
      await prefs.setDouble('latitude', _activeCity!.latitude);
      await prefs.setDouble('longitude', _activeCity!.longitude);
      await prefs.setString(
        'calculation_method',
        _activeCity!.calculationMethod,
      );
      await prefs.setString('madhab', _activeCity!.madhab);
    } else if (_coordinates != null) {
      await prefs.setDouble('latitude', _coordinates!.latitude);
      await prefs.setDouble('longitude', _coordinates!.longitude);
    }

    // Write effective adjustments (offsets)
    final effectiveAdjustments = adjustments;
    await prefs.setInt('offset_Fajr', effectiveAdjustments['Fajr'] ?? 0);
    await prefs.setInt('offset_Sunrise', effectiveAdjustments['Sunrise'] ?? 0);
    await prefs.setInt('offset_Dhuhr', effectiveAdjustments['Dhuhr'] ?? 0);
    await prefs.setInt('offset_Asr', effectiveAdjustments['Asr'] ?? 0);
    await prefs.setInt('offset_Maghrib', effectiveAdjustments['Maghrib'] ?? 0);
    await prefs.setInt('offset_Isha', effectiveAdjustments['Isha'] ?? 0);
    await prefs.setInt('hijri_offset', hijriOffset);
    // Publish the civil-date Hijri contract before any native calculation.
    await cacheHijriDatesForNative(hijriOffset);
  }

  final _notificationScheduleRunner = NotificationScheduleRunner();

  Future<void> scheduleNotifications({bool isUserAction = true}) async {
    await _notificationScheduleRunner.run((userAction) async {
      await _syncNativeEngineConfig();
      final times = getPrayerTimes();
      if (times != null) {
        await NotificationService.schedulePrayerNotifications(
          times,
          isUserAction: userAction,
        );
        await updatePersistentElements();
      }
    }, isUserAction: isUserAction);
    unawaited(
      _scheduleNextLocationRefresh(trigger: 'prayer_notification_schedule'),
    );
  }

  static const int _prayerLocationRefreshAlarmId = 724618;
  static const Duration _locationRefreshLeadTime = Duration(minutes: 10);

  Future<void> _scheduleNextLocationRefresh({required String trigger}) async {
    final requestedAt = DateTime.now();
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        AppLogger.logEvent('PrayerLocationRefresh', 'schedule_skipped', {
          'trigger': trigger,
          'platform': defaultTargetPlatform.name,
          'reason': 'android_alarm_manager_unavailable_on_platform',
          'requested_at': requestedAt.toIso8601String(),
          'actual_at': DateTime.now().toIso8601String(),
          'delivery': 'unsupported_platform',
          'outcome': 'skipped',
        });
        return;
      }
      if (_activeCity != null) {
        final cancelled = await AndroidAlarmManager.cancel(
          _prayerLocationRefreshAlarmId,
        );
        AppLogger.logEvent('PrayerLocationRefresh', 'schedule_skipped', {
          'trigger': trigger,
          'reason': 'manual_city_override',
          'actual_at': DateTime.now().toIso8601String(),
          'cancelled_previous_alarm': cancelled,
          'outcome': 'skipped',
        });
        return;
      }

      final now = DateTime.now();
      final todayTimes = getPrayerTimes();
      if (todayTimes == null) {
        AppLogger.logEvent('PrayerLocationRefresh', 'schedule_skipped', {
          'trigger': trigger,
          'reason': 'prayer_times_unavailable',
          'requested_at': requestedAt.toIso8601String(),
          'actual_at': DateTime.now().toIso8601String(),
          'outcome': 'skipped',
        });
        return;
      }

      final today = <MapEntry<Prayer, DateTime>>[
        MapEntry(Prayer.fajr, todayTimes.fajr),
        MapEntry(Prayer.dhuhr, todayTimes.dhuhr),
        MapEntry(Prayer.asr, todayTimes.asr),
        MapEntry(Prayer.maghrib, todayTimes.maghrib),
        MapEntry(Prayer.isha, todayTimes.isha),
      ];
      MapEntry<Prayer, DateTime>? nextPrayer;
      for (final entry in today) {
        if (entry.value.isAfter(now)) {
          nextPrayer = entry;
          break;
        }
      }
      if (nextPrayer == null) {
        final tomorrow = NotificationScheduleHelpers.addCivilDays(now, 1);
        final tomorrowTimes = getPrayerTimesForDate(tomorrow);
        if (tomorrowTimes != null) {
          nextPrayer = MapEntry(Prayer.fajr, tomorrowTimes.fajr);
        }
      }
      if (nextPrayer == null) {
        AppLogger.logEvent('PrayerLocationRefresh', 'schedule_failed', {
          'trigger': trigger,
          'reason': 'next_prayer_unavailable',
          'requested_at': requestedAt.toIso8601String(),
          'actual_at': DateTime.now().toIso8601String(),
          'outcome': 'failed',
        });
        return;
      }

      final prayerKey = _locationPrayerKey(nextPrayer.key);
      final expectedAt = nextPrayer.value;
      final targetBeforePrayer = expectedAt.subtract(_locationRefreshLeadTime);
      final scheduledAt = targetBeforePrayer.isAfter(now)
          ? targetBeforePrayer
          : now.add(const Duration(seconds: 1));
      final prefs = CacheHelper.prefs;
      await prefs.setString(
        'prayer_location_refresh_expected_prayer',
        prayerKey,
      );
      await prefs.setInt(
        'prayer_location_refresh_expected_at_ms',
        expectedAt.millisecondsSinceEpoch,
      );
      final scheduled = await AndroidAlarmManager.oneShotAt(
        scheduledAt,
        _prayerLocationRefreshAlarmId,
        prayerLocationRefreshCallback,
        exact: false,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      AppLogger.logEvent('PrayerLocationRefresh', 'schedule_finished', {
        'trigger': trigger,
        'expected_prayer': prayerKey,
        'expected_prayer_at': expectedAt.toIso8601String(),
        'requested_at': requestedAt.toIso8601String(),
        'requested_run_at': scheduledAt.toIso8601String(),
        'actual_schedule_result_at': DateTime.now().toIso8601String(),
        'delivery': 'best_effort_inexact_alarm',
        'outcome': scheduled ? 'scheduled' : 'failed',
        'reason': scheduled ? null : 'platform_rejected_alarm',
      });
    } catch (error) {
      AppLogger.logEvent('PrayerLocationRefresh', 'schedule_failed', {
        'trigger': trigger,
        'requested_at': requestedAt.toIso8601String(),
        'actual_at': DateTime.now().toIso8601String(),
        'outcome': 'failed',
        'safe_failure_type': error.runtimeType.toString(),
      });
    }
  }

  String _locationPrayerKey(Prayer prayer) => switch (prayer) {
    Prayer.fajr => 'fajr',
    Prayer.dhuhr => 'dhuhr',
    Prayer.asr => 'asr',
    Prayer.maghrib => 'maghrib',
    Prayer.isha => 'isha',
    _ => 'unknown',
  };

  String _locationDistanceBucket(double meters) => meters < 1000
      ? 'under_1km'
      : meters < 10000
      ? '1_10km'
      : 'over_10km';

  static const String _ltr = '\u200E';

  Future<void> updatePersistentElements({bool updateThirtyDays = false}) async {
    final times = getPrayerTimes();
    if (times == null) return;

    final now = DateTime.now();

    Prayer nextPrayer = times.nextPrayer();
    if (nextPrayer == Prayer.sunrise) {
      nextPrayer = Prayer.dhuhr;
    }

    DateTime? nextTime;

    if (nextPrayer != Prayer.none) {
      nextTime = times.timeForPrayer(nextPrayer);
    } else {
      final tomorrow = NotificationScheduleHelpers.addCivilDays(now, 1);
      final tomorrowTimes = getPrayerTimesForDate(tomorrow);
      if (tomorrowTimes != null) {
        nextTime = tomorrowTimes.fajr;
        nextPrayer = Prayer.fajr;
      }
    }

    if (nextTime == null) return;

    Prayer currentPrayer = times.currentPrayer();
    if (currentPrayer == Prayer.sunrise) {
      currentPrayer = Prayer.fajr;
    }

    DateTime? currentTime;
    if (currentPrayer != Prayer.none) {
      currentTime = times.timeForPrayer(currentPrayer);
    } else {
      final yesterday = NotificationScheduleHelpers.addCivilDays(now, -1);
      final yesterdayTimes = getPrayerTimesForDate(yesterday);
      currentTime = yesterdayTimes?.isha;
    }

    int goldTargetEpoch = nextTime.millisecondsSinceEpoch;
    bool goldIsCountUp = false;

    if (currentTime != null) {
      final elapsed = now.difference(currentTime);
      final int countUpWindowMinutes;
      switch (currentPrayer) {
        case Prayer.fajr: // Fajr: 60-minute count-up window
        case Prayer.isha: // Isha: 60-minute count-up window
          countUpWindowMinutes = 60;
          break;
        case Prayer.maghrib:
          final ishaTime = times.isha;
          final diff = ishaTime.difference(currentTime);
          countUpWindowMinutes = diff.inMinutes ~/ 2;
          break;
        default:
          countUpWindowMinutes = 45;
      }
      if (elapsed.inMinutes >= 0 && elapsed.inMinutes < countUpWindowMinutes) {
        goldTargetEpoch = currentTime.millisecondsSinceEpoch;
        goldIsCountUp = true;
      }
    }

    DateTime countdownTargetTime = nextTime;
    Prayer goldNextPrayer = nextPrayer;
    DateTime? goldNextTime = nextTime;

    int highlightedPrayerIndex;
    if (goldIsCountUp) {
      highlightedPrayerIndex = _prayerToIndex(currentPrayer);
    } else {
      highlightedPrayerIndex = _prayerToIndex(goldNextPrayer);
    }

    String countdownStr;
    String goldNextName;

    if (goldIsCountUp && currentTime != null) {
      final elapsed = now.difference(currentTime);
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes.remainder(60);
      final seconds = elapsed.inSeconds.remainder(60);
      countdownStr =
          "$_ltr${AppFormatters.twoDigits(hours)}:${AppFormatters.twoDigits(minutes)}:${AppFormatters.twoDigits(seconds)}$_ltr";

      final cName = (currentPrayer == Prayer.none ? Prayer.isha : currentPrayer)
          .arabicName;
      goldNextName = "مضى على $cName";
    } else {
      final diff = countdownTargetTime.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      final seconds = diff.inSeconds.remainder(60);
      countdownStr =
          "$_ltr${AppFormatters.twoDigits(hours)}:${AppFormatters.twoDigits(minutes)}:${AppFormatters.twoDigits(seconds)}$_ltr";

      final gn = (goldNextPrayer == Prayer.none ? Prayer.fajr : goldNextPrayer)
          .arabicName;
      goldNextName = "متبقي على $gn";
    }

    HijriCalendar.setLocal('ar');
    final hDate = PrayerService.getHijriWithOffset(hijriOffset);
    String hijriStr =
        "\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\u200F";

    countdownStr = AppFormatters.toArabicDigits(countdownStr);
    hijriStr = AppFormatters.toArabicDigits(hijriStr);

    await cacheHijriDatesForNative(hijriOffset);

    final prefs = CacheHelper.prefs;
    final persistentEnabled =
        prefs.getBool('persistent_notification_enabled') ?? true;

    DateTime nextTriggerTime;
    if (goldIsCountUp && currentTime != null) {
      final int windowMins;
      switch (currentPrayer) {
        case Prayer.maghrib:
          windowMins = 20;
          break;
        default:
          windowMins = 60;
      }
      nextTriggerTime = currentTime.add(Duration(minutes: windowMins));
    } else {
      nextTriggerTime = countdownTargetTime;
    }

    await AndroidAlarmManager.oneShotAt(
      nextTriggerTime.add(const Duration(seconds: 1)),
      999,
      backgroundWidgetUpdateCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
    await AndroidAlarmManager.oneShotAt(
      tomorrowMidnight,
      9999,
      backgroundWidgetUpdateCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    if (persistentEnabled) {
      await PrayerNotificationServiceHelper.updateNotification(
        fajr: toArabicDigits(_ltrWrap(formatTime(times.fajr))),
        dhuhr: toArabicDigits(_ltrWrap(formatTime(times.dhuhr))),
        asr: toArabicDigits(_ltrWrap(formatTime(times.asr))),
        maghrib: toArabicDigits(_ltrWrap(formatTime(times.maghrib))),
        isha: toArabicDigits(_ltrWrap(formatTime(times.isha))),
        nextName: goldNextName,
        countdown: countdownStr,
        hijri: hijriStr,
        prayerIndex: highlightedPrayerIndex,
        nextPrayerEpoch: (goldIsCountUp && currentTime != null)
            ? currentTime.millisecondsSinceEpoch
            : countdownTargetTime.millisecondsSinceEpoch,
        isCountUp: goldIsCountUp,
      );
    } else {
      await PrayerNotificationServiceHelper.stopNotification();
    }

    await HomeWidgetService.updatePrayerWidget(
      fajr: toArabicDigits(_ltrWrap(formatTime(times.fajr))),
      dhuhr: toArabicDigits(_ltrWrap(formatTime(times.dhuhr))),
      asr: toArabicDigits(_ltrWrap(formatTime(times.asr))),
      maghrib: toArabicDigits(_ltrWrap(formatTime(times.maghrib))),
      isha: toArabicDigits(_ltrWrap(formatTime(times.isha))),
      nextName: goldNextName,
      countdown: countdownStr,
      hijri: hijriStr,
      hijriOffset: hijriOffset,
      prayerIndex: highlightedPrayerIndex,
      prayerTime: toArabicDigits(_ltrWrap(formatTime(goldNextTime))),
      nextPrayerEpoch: (goldIsCountUp && currentTime != null)
          ? currentTime.millisecondsSinceEpoch
          : countdownTargetTime.millisecondsSinceEpoch,
      sunriseTime: toArabicDigits(_ltrWrap(formatTime(times.sunrise))),
      locationName:
          _activeCity?.name ??
          (_currentCityName.isNotEmpty ? _currentCityName : "الموقع الحالي"),
      isCountUp: goldIsCountUp,
      persistentEnabled: persistentEnabled,
      fajrEpoch: times.fajr.millisecondsSinceEpoch,
      dhuhrEpoch: times.dhuhr.millisecondsSinceEpoch,
      asrEpoch: times.asr.millisecondsSinceEpoch,
      maghribEpoch: times.maghrib.millisecondsSinceEpoch,
      ishaEpoch: times.isha.millisecondsSinceEpoch,
      sunriseEpoch: times.sunrise.millisecondsSinceEpoch,
    );

    await HomeWidgetService.updateGoldWidgetData(
      targetEpoch: goldTargetEpoch,
      isCountUp: goldIsCountUp,
    );

    await HomeWidget.saveWidgetData<int>(
      'highlighted_prayer_index',
      highlightedPrayerIndex,
    );

    if (updateThirtyDays) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        Map<String, dynamic> thirtyDays = {};
        for (int i = 0; i < 30; i++) {
          DateTime d = NotificationScheduleHelpers.addCivilDays(now, i);
          var t = getPrayerTimesForDate(d);
          if (t != null) {
            String dateKey = DateFormat('yyyy-MM-dd', 'en').format(d);
            thirtyDays[dateKey] = {
              "f": t.fajr.millisecondsSinceEpoch,
              "d": t.dhuhr.millisecondsSinceEpoch,
              "a": t.asr.millisecondsSinceEpoch,
              "m": t.maghrib.millisecondsSinceEpoch,
              "i": t.isha.millisecondsSinceEpoch,
              "s": t.sunrise.millisecondsSinceEpoch,
              "f_str": toArabicDigits(_ltrWrap(formatTime(t.fajr))),
              "d_str": toArabicDigits(_ltrWrap(formatTime(t.dhuhr))),
              "a_str": toArabicDigits(_ltrWrap(formatTime(t.asr))),
              "m_str": toArabicDigits(_ltrWrap(formatTime(t.maghrib))),
              "i_str": toArabicDigits(_ltrWrap(formatTime(t.isha))),
              "s_str": toArabicDigits(_ltrWrap(formatTime(t.sunrise))),
            };
          }
          if (i % 5 == 0) await Future.delayed(Duration.zero);
        }
        await HomeWidgetService.updateThirtyDaysData(jsonEncode(thirtyDays));
      });
    }
  }

  static String toArabicDigits(dynamic input) =>
      AppFormatters.toArabicDigits(input);
  String _ltrWrap(String value) => AppFormatters.wrapLtr(value);

  int _prayerToIndex(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 0;
      case Prayer.sunrise:
        return 1;
      case Prayer.dhuhr:
        return 1;
      case Prayer.asr:
        return 2;
      case Prayer.maghrib:
        return 3;
      case Prayer.isha:
        return 4;
      default:
        return -1;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = CacheHelper.prefs;
    await _loadCities(prefs);
    await _loadActiveCity(prefs);
    _hijriOffset = prefs.getInt(keyHijriOffset) ?? 0;
    _localHijriDelta = prefs.getInt(keyLocalHijriDelta) ?? 0;
    _is24Hour = prefs.getBool(keyIs24Hour) ?? false;
    _currentCityName = prefs.getString('last_city_name') ?? "";
    final currentHijriMonth = getHijriWithOffset(
      hijriOffset,
      DateTime.now(),
    ).hMonth;
    final savedOffsetMonth = prefs.getInt(keyHijriOffsetMonth);
    if (savedOffsetMonth != null && savedOffsetMonth != currentHijriMonth) {
      _hijriOffset = 0;
      await prefs.setInt(keyHijriOffset, 0);
      await prefs.setInt(keyHijriOffsetMonth, currentHijriMonth);
    }
    String? methodKey = prefs.getString(keyMethod);
    if (methodKey != null) _method = _getMethodFromKey(methodKey);
    String? madhabKey = prefs.getString(keyMadhab);
    if (madhabKey != null) {
      _madhab = madhabKey == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }
    _ramadanIshaDelayMode = prefs.getInt(keyRamadanCycle) ?? 0;
    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (String p in prayers) {
      _adjustments[p] = prefs.getInt('$keyAdjustPrefix$p') ?? 0;
    }
  }

  CalculationMethod _getMethodFromKey(String key) => _methodFromKeyStatic(key);

  Future<void> updateLocation() async {
    await _getLocation();
    await scheduleNotifications(isUserAction: false);
  }

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _coordinates = Coordinates(position.latitude, position.longitude);
      final prefs = CacheHelper.prefs;
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final city = place.locality?.isNotEmpty == true
              ? place.locality
              : place.subAdministrativeArea;
          if (city != null && city.isNotEmpty) {
            await prefs.setString('last_city_name', city);
            _currentCityName = city;
            notifyListeners();
          }
        }
      } catch (_) {}
    } catch (e) {
      final prefs = CacheHelper.prefs;
      double lat = prefs.getDouble('last_lat') ?? 30.0444;
      double lng = prefs.getDouble('last_lng') ?? 31.2357;
      _coordinates = Coordinates(lat, lng);
    }
  }

  PrayerTimes _buildPrayerTimesWithRamadanIsha(
    Coordinates coordinates,
    DateTime date,
    CalculationParameters params,
  ) {
    final base = PrayerTimes(
      coordinates,
      DateComponents(date.year, date.month, date.day),
      params,
    );
    if (_ramadanIshaDelayMode > 0 && isRamadanNightForDate(date)) {
      final desiredIsha = base.maghrib.add(
        Duration(minutes: _ramadanIshaDelayMode),
      );
      params.adjustments.isha += desiredIsha.difference(base.isha).inMinutes;
      return PrayerTimes(
        coordinates,
        DateComponents(date.year, date.month, date.day),
        params,
      );
    }
    return base;
  }

  PrayerTimes? getPrayerTimes() {
    if (_activeCity != null) {
      final coords = Coordinates(_activeCity!.latitude, _activeCity!.longitude);
      final method = _getMethodFromKey(_activeCity!.calculationMethod);
      final params = method.getParameters();
      params.madhab = _activeCity!.madhab == 'hanafi'
          ? Madhab.hanafi
          : Madhab.shafi;
      params.adjustments.fajr = _activeCity!.offsets['Fajr'] ?? 0;
      params.adjustments.sunrise = _activeCity!.offsets['Sunrise'] ?? 0;
      params.adjustments.dhuhr = _activeCity!.offsets['Dhuhr'] ?? 0;
      params.adjustments.asr = _activeCity!.offsets['Asr'] ?? 0;
      params.adjustments.maghrib = _activeCity!.offsets['Maghrib'] ?? 0;
      params.adjustments.isha = _activeCity!.offsets['Isha'] ?? 0;
      final now = DateTime.now();
      return _buildPrayerTimesWithRamadanIsha(coords, now, params);
    }
    if (_coordinates == null) return null;
    final params = _method.getParameters();
    params.madhab = _madhab;
    params.adjustments.fajr = _adjustments['Fajr'] ?? 0;
    params.adjustments.sunrise = _adjustments['Sunrise'] ?? 0;
    params.adjustments.dhuhr = _adjustments['Dhuhr'] ?? 0;
    params.adjustments.asr = _adjustments['Asr'] ?? 0;
    params.adjustments.maghrib = _adjustments['Maghrib'] ?? 0;
    params.adjustments.isha = _adjustments['Isha'] ?? 0;
    final now = DateTime.now();
    return _buildPrayerTimesWithRamadanIsha(_coordinates!, now, params);
  }

  PrayerTimes? getPrayerTimesForDate(DateTime date) {
    if (_activeCity != null) {
      final coords = Coordinates(_activeCity!.latitude, _activeCity!.longitude);
      final method = _getMethodFromKey(_activeCity!.calculationMethod);
      final params = method.getParameters();
      params.madhab = _activeCity!.madhab == 'hanafi'
          ? Madhab.hanafi
          : Madhab.shafi;
      params.adjustments.fajr = _activeCity!.offsets['Fajr'] ?? 0;
      params.adjustments.sunrise = _activeCity!.offsets['Sunrise'] ?? 0;
      params.adjustments.dhuhr = _activeCity!.offsets['Dhuhr'] ?? 0;
      params.adjustments.asr = _activeCity!.offsets['Asr'] ?? 0;
      params.adjustments.maghrib = _activeCity!.offsets['Maghrib'] ?? 0;
      params.adjustments.isha = _activeCity!.offsets['Isha'] ?? 0;
      return _buildPrayerTimesWithRamadanIsha(coords, date, params);
    }
    if (_coordinates == null) return null;
    final params = _method.getParameters();
    params.madhab = _madhab;
    params.adjustments.fajr = _adjustments['Fajr'] ?? 0;
    params.adjustments.sunrise = _adjustments['Sunrise'] ?? 0;
    params.adjustments.dhuhr = _adjustments['Dhuhr'] ?? 0;
    params.adjustments.asr = _adjustments['Asr'] ?? 0;
    params.adjustments.maghrib = _adjustments['Maghrib'] ?? 0;
    params.adjustments.isha = _adjustments['Isha'] ?? 0;
    return _buildPrayerTimesWithRamadanIsha(_coordinates!, date, params);
  }

  static Future<PrayerTimes?> getPrayerTimesForDateStatic(DateTime date) async {
    final prefs = CacheHelper.prefs;
    CityProfile? activeCity;
    final activeCityId = prefs.getString(keyActiveCityId);
    final jsonStr = prefs.getString(keySavedCities);
    if (activeCityId != null && jsonStr != null) {
      try {
        final cities = (jsonDecode(jsonStr) as List)
            .map((e) => CityProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        activeCity = cities.firstWhere((c) => c.id == activeCityId);
      } catch (_) {}
    }

    final coords = activeCity == null
        ? Coordinates(
            prefs.getDouble('last_lat') ??
                prefs.getDouble('latitude') ??
                30.0444,
            prefs.getDouble('last_lng') ??
                prefs.getDouble('longitude') ??
                31.2357,
          )
        : Coordinates(activeCity.latitude, activeCity.longitude);
    final methodKey =
        activeCity?.calculationMethod ?? prefs.getString(keyMethod) ?? 'egypt';
    final params = _methodFromKeyStatic(methodKey).getParameters();
    final madhabKey =
        activeCity?.madhab ?? prefs.getString(keyMadhab) ?? 'shafi';
    params.madhab = madhabKey.trim().toLowerCase() == 'hanafi'
        ? Madhab.hanafi
        : Madhab.shafi;
    final offsets =
        activeCity?.offsets ??
        {
          for (final prayer in [
            'Fajr',
            'Sunrise',
            'Dhuhr',
            'Asr',
            'Maghrib',
            'Isha',
          ])
            prayer: prefs.getInt('$keyAdjustPrefix$prayer') ?? 0,
        };
    params.adjustments.fajr = offsets['Fajr'] ?? 0;
    params.adjustments.sunrise = offsets['Sunrise'] ?? 0;
    params.adjustments.dhuhr = offsets['Dhuhr'] ?? 0;
    params.adjustments.asr = offsets['Asr'] ?? 0;
    params.adjustments.maghrib = offsets['Maghrib'] ?? 0;
    params.adjustments.isha = offsets['Isha'] ?? 0;
    final base = PrayerTimes(
      coords,
      DateComponents(date.year, date.month, date.day),
      params,
    );
    final ramadanDelay = prefs.getInt(keyRamadanCycle) ?? 0;
    if (ramadanDelay > 0 && isRamadanNightForDate(date)) {
      params.adjustments.isha += base.maghrib
          .add(Duration(minutes: ramadanDelay))
          .difference(base.isha)
          .inMinutes;
      return PrayerTimes(
        coords,
        DateComponents(date.year, date.month, date.day),
        params,
      );
    }
    return base;
  }

  static CalculationMethod _methodFromKeyStatic(String key) {
    switch (key.trim().toLowerCase()) {
      case 'makkah':
      case 'umm_al_qura':
      case 'ummal_qura':
      case 'ummalqura':
        return CalculationMethod.umm_al_qura;
      case 'karachi':
        return CalculationMethod.karachi;
      case 'dubai':
        return CalculationMethod.dubai;
      case 'kuwait':
        return CalculationMethod.kuwait;
      case 'qatar':
        return CalculationMethod.qatar;
      case 'moonsighting':
      case 'moon_sighting_committee':
        return CalculationMethod.moon_sighting_committee;
      case 'singapore':
        return CalculationMethod.singapore;
      case 'turkey':
        return CalculationMethod.turkey;
      case 'tehran':
        return CalculationMethod.tehran;
      case 'isna':
      case 'north_america':
        return CalculationMethod.north_america;
      case 'mwl':
      case 'muslim_world_league':
        return CalculationMethod.muslim_world_league;
      case 'egypt':
      case 'egyptian':
      default:
        return CalculationMethod.egyptian;
    }
  }

  Prayer? getNextPrayer() {
    final times = getPrayerTimes();
    return times?.nextPrayer();
  }

  Future<void> saveMethod(String methodKey) async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(keyMethod, methodKey);
    _method = _getMethodFromKey(methodKey);
    await scheduleNotifications(isUserAction: true);
  }

  Future<void> saveMadhab(String madhabKey) async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(keyMadhab, madhabKey);
    _madhab = madhabKey == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    await scheduleNotifications(isUserAction: true);
  }

  Timer? _debounceTimer;

  Future<void> scheduleNotificationsDebounced({
    bool isUserAction = true,
  }) async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      scheduleNotifications(isUserAction: isUserAction);
    });
  }

  Future<void> saveAdjustment(String prayer, int minutes) async {
    final prefs = CacheHelper.prefs;
    if (_activeCity != null) {
      _activeCity!.offsets[prayer] = minutes;
      await _saveCities();
    } else {
      await prefs.setInt('$keyAdjustPrefix$prayer', minutes);
      _adjustments[prayer] = minutes;
    }
    notifyListeners();
    await scheduleNotificationsDebounced(isUserAction: true);
  }

  Future<void> saveRamadanIshaDelay(int mode) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyRamadanCycle, mode);
    _ramadanIshaDelayMode = mode;
    await scheduleNotifications(isUserAction: true);
  }

  Map<String, int> get adjustments =>
      _activeCity != null ? _activeCity!.offsets : _adjustments;
  CalculationMethod get method => _activeCity != null
      ? _getMethodFromKey(_activeCity!.calculationMethod)
      : _method;
  Madhab get madhab => _activeCity != null
      ? (_activeCity!.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi)
      : _madhab;
  int get ramadanIshaDelayMode => _ramadanIshaDelayMode;
  List<CityProfile> get savedCities => _savedCities;
  CityProfile? get activeCity => _activeCity;
  String get cityName =>
      _activeCity?.name ??
      (_currentCityName.isNotEmpty ? _currentCityName : "الموقع الحالي");

  Future<void> addCity(CityProfile city) async {
    _savedCities.add(city);
    await _saveCities();
    if (_savedCities.length == 1) await setActiveCity(city.id);
  }

  Future<void> updateCity(CityProfile city) async {
    int index = _savedCities.indexWhere((c) => c.id == city.id);
    if (index != -1) {
      _savedCities[index] = city;
      await _saveCities();
      if (_activeCity?.id == city.id) {
        _activeCity = city;
        await scheduleNotifications(isUserAction: true);
      }
    }
  }

  Future<void> removeCity(String id) async {
    _savedCities.removeWhere((c) => c.id == id);
    await _saveCities();
    if (_activeCity?.id == id) {
      _activeCity = null;
      final prefs = CacheHelper.prefs;
      await prefs.remove(keyActiveCityId);
      await scheduleNotifications(isUserAction: true);
    }
  }

  Future<void> setActiveCity(String? id) async {
    final prefs = CacheHelper.prefs;
    if (id == null) {
      _activeCity = null;
      await prefs.remove(keyActiveCityId);
    } else {
      try {
        _activeCity = _savedCities.firstWhere((c) => c.id == id);
        await prefs.setString(keyActiveCityId, id);
      } catch (_) {
        _activeCity = null;
      }
    }
    await scheduleNotifications(isUserAction: true);
  }

  Future<void> _loadCities(SharedPreferences prefs) async {
    String? jsonStr = prefs.getString(keySavedCities);
    if (jsonStr != null) {
      try {
        List<dynamic> list = jsonDecode(jsonStr);
        _savedCities = list.map((e) => CityProfile.fromJson(e)).toList();
      } catch (_) {}
    }
  }

  Future<void> _saveCities() async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(
      keySavedCities,
      jsonEncode(_savedCities.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _loadActiveCity(SharedPreferences prefs) async {
    String? id = prefs.getString(keyActiveCityId);
    if (id != null) {
      try {
        _activeCity = _savedCities.firstWhere((c) => c.id == id);
      } catch (_) {
        await prefs.remove(keyActiveCityId);
      }
    }
  }

  Future<List<ExtendedPrayer>> getExtendedPrayers({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final times = getPrayerTimesForDate(targetDate);
    final nextDayTimes = getPrayerTimesForDate(
      NotificationScheduleHelpers.addCivilDays(targetDate, 1),
    );
    if (times == null || nextDayTimes == null) return [];

    DateTime fajr = times.fajr;
    DateTime sunrise = times.sunrise;
    DateTime dhuhr = times.dhuhr;
    DateTime asr = times.asr;
    DateTime maghrib = times.maghrib;
    DateTime isha = times.isha;
    DateTime duha = sunrise.add(const Duration(minutes: 15));
    DateTime nextFajr = nextDayTimes.fajr;
    Duration nightDuration = nextFajr.difference(maghrib);
    DateTime midnight = maghrib.add(
      Duration(seconds: (nightDuration.inSeconds / 2).round()),
    );
    DateTime firstThird = maghrib.add(
      Duration(seconds: (nightDuration.inSeconds / 3).round()),
    );
    DateTime lastThird = nextFajr.subtract(
      Duration(seconds: (nightDuration.inSeconds / 3).round()),
    );

    return [
      ExtendedPrayer(
        id: 'fajr',
        name: 'الفجر',
        time: fajr,
        prayer: Prayer.fajr,
      ),
      ExtendedPrayer(
        id: 'sunrise',
        name: 'الشروق',
        time: sunrise,
        prayer: Prayer.sunrise,
      ),
      ExtendedPrayer(id: 'duha', name: 'الضحى', time: duha, prayer: null),
      ExtendedPrayer(
        id: 'dhuhr',
        name: 'الظهر',
        time: dhuhr,
        prayer: Prayer.dhuhr,
      ),
      ExtendedPrayer(id: 'asr', name: 'العصر', time: asr, prayer: Prayer.asr),
      ExtendedPrayer(
        id: 'maghrib',
        name: 'المغرب',
        time: maghrib,
        prayer: Prayer.maghrib,
      ),
      ExtendedPrayer(
        id: 'isha',
        name: 'العشاء',
        time: isha,
        prayer: Prayer.isha,
      ),
      ExtendedPrayer(
        id: 'first_third',
        name: 'ثلث الليل الأول',
        time: firstThird,
        prayer: null,
      ),
      ExtendedPrayer(
        id: 'midnight',
        name: 'منتصف الليل',
        time: midnight,
        prayer: null,
      ),
      ExtendedPrayer(
        id: 'last_third',
        name: 'ثلث الليل الأخير',
        time: lastThird,
        prayer: null,
      ),
    ];
  }

  /// The Islamic night starts at Maghrib of the preceding civil fasting date.
  /// Fajr/iftar still use the civil fasting date itself.
  static bool isRamadanNightForDate(DateTime date) {
    final next = getNotificationHijriForDate(
      NotificationScheduleHelpers.addCivilDays(date, 1),
    );
    if (next != null) return next.hMonth == 9;
    // A lunar month cannot finish before 29. This infers only the night,
    // never an unconfirmed 29/30-day month boundary or a new fasting date.
    final current = getNotificationHijriForDate(date);
    return current != null && current.hMonth == 9 && current.hDay < 29;
  }

  /// Strict source used by notification/Ramadan decisions.
  /// Egyptian dates come only from the official civil-date snapshot; missing
  /// rows stay null rather than being fabricated by a conversion library.
  static HijriCalendar? getNotificationHijriForDate(DateTime date) {
    HijriCalendar.setLocal('ar');
    if (isEgyptianSystem) {
      final official = EgyptianHijriCalendar.instance.lookup(date);
      if (official == null) return null;
      return _hijriCalendarFromEgyptianDate(official, date);
    }
    return getHijriWithOffset(
      RemoteConfigService.globalHijriOffset +
          (CacheHelper.prefs.getInt(keyHijriOffset) ?? 0) +
          (CacheHelper.prefs.getInt(keyLocalHijriDelta) ?? 0),
      date,
    );
  }

  static HijriCalendar getHijriWithOffset(int remoteOffset, [DateTime? date]) {
    HijriCalendar.setLocal('ar');
    final baseDate = date ?? DateTime.now();
    final isEgyptian = isEgyptianSystem;
    final egyptianDate = isEgyptian
        ? EgyptianHijriCalendar.instance.lookup(baseDate)
        : null;

    // تأكيد المستخدم النشط يتقدم على صف الهيئة؛ والجدول هو المرجع المعتاد.
    final localOffset = isEgyptian
        ? CacheHelper.prefs.getInt('local_hijri_offset')
        : null;
    final manualAdjustment = isEgyptian
        ? 0
        : (CacheHelper.prefs.getInt('manual_day_adjustment') ?? 0);

    // عند غياب أي تاريخ مصري موثوق نرجع إلى الإزاحة المحلية أو البعيدة.
    // أم القرى تستخدم التحويل الفلكي مع التعديل اليدوي.
    final offsetDays = (localOffset != null)
        ? localOffset
        : (isEgyptian ? remoteOffset : remoteOffset + manualAdjustment);

    final effectiveDate = egyptianDate == null
        ? NotificationScheduleHelpers.addCivilDays(baseDate, offsetDays)
        : baseDate;

    final h = egyptianDate == null
        ? HijriCalendar.fromDate(effectiveDate)
        : _hijriCalendarFromEgyptianDate(egyptianDate, baseDate);
    final hijriStr = "\u200F${h.hDay} ${h.longMonthName} ${h.hYear}\u200F";
    final gDateStr =
        "${baseDate.year}-${baseDate.month.toString().padLeft(2, '0')}-${baseDate.day.toString().padLeft(2, '0')}";
    CacheHelper.prefs.setString('shared_hijri_date', hijriStr);
    CacheHelper.prefs.setString('shared_hijri_date_$gDateStr', hijriStr);
    AppLogger.log(
      "PrayerService",
      "getHijriWithOffset() [${isEgyptian ? 'Egyptian' : 'UmmAlQura'}] -> baseDate: ${baseDate.toIso8601String()}, localOffset: $localOffset, manual: $manualAdjustment, remote: $remoteOffset, effective: ${effectiveDate.toIso8601String()}, Hijri: $hijriStr",
    );
    return h;
  }

  /// Uses an active user confirmation first, then the published Egyptian row;
  /// offset conversion remains the fallback when neither has a date.
  static HijriCalendar getDisplayHijriForDate(
    int remoteOffset, [
    DateTime? date,
  ]) {
    return getHijriWithOffset(remoteOffset, date);
  }

  /// The Egyptian calendar on the result card is not a conversion fallback:
  /// show the active user confirmation or the published ESA row only.
  static HijriCalendar? getEgyptianResultHijriForDate(DateTime date) {
    final official = EgyptianHijriCalendar.instance.lookup(date);
    if (official == null) return null;
    return _hijriCalendarFromEgyptianDate(official, date);
  }

  static HijriCalendar _hijriCalendarFromEgyptianDate(
    EgyptianHijriDate date,
    DateTime civilDate,
  ) {
    final hijri = HijriCalendar.fromDate(civilDate);
    hijri.hDate(date.hYear, date.hMonth, date.hDay);
    return hijri;
  }

  int get hijriOffset =>
      RemoteConfigService.globalHijriOffset + _hijriOffset + _localHijriDelta;
  int get manualHijriOffset => _hijriOffset;
  int get localHijriDelta => _localHijriDelta;
  bool get is24Hour => _is24Hour;

  void refreshUI() => notifyListeners();

  Future<void> setHijriOffset(int offset) async {
    _hijriOffset = offset;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyHijriOffset, offset);
    final hDate = getHijriWithOffset(offset);
    await prefs.setInt(keyHijriOffsetMonth, hDate.hMonth);
    await prefs.setString(
      'shared_hijri_date',
      "\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\u200F",
    );
    notifyListeners();
    try {
      await scheduleNotifications(isUserAction: true);
    } catch (_) {}
  }

  Future<void> setLocalHijriDelta(int delta) async {
    _localHijriDelta = delta;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyLocalHijriDelta, delta);
    notifyListeners();
    try {
      await scheduleNotifications(isUserAction: true);
    } catch (_) {}
  }

  static const String keyHijriSystem = 'hijri_system';
  static const String systemUmmAlQura = 'umm_alqura';
  static const String systemEgyptian = 'egyptian';

  static String get hijriSystem =>
      CacheHelper.prefs.getString(keyHijriSystem) ?? systemUmmAlQura;

  static bool get isEgyptianSystem => hijriSystem == systemEgyptian;

  /// Fallback day adjustment when no confirmed or published Egyptian row exists.
  static int get effectiveHijriDayAdjustment {
    final prefs = CacheHelper.prefs;
    final generalOffset =
        RemoteConfigService.globalHijriOffset +
        (prefs.getInt(keyHijriOffset) ?? 0) +
        (prefs.getInt(keyLocalHijriDelta) ?? 0);
    if (isEgyptianSystem) {
      return prefs.getInt('local_hijri_offset') ?? generalOffset;
    }
    return generalOffset + (prefs.getInt('manual_day_adjustment') ?? 0);
  }

  static DateTime hijriToGregorianDate(int year, int month, int day) {
    if (isEgyptianSystem) {
      final calendar = EgyptianHijriCalendar.instance;
      final confirmation = calendar.userConfirmation;
      if (confirmation != null) {
        for (var offset = 0; offset <= 29; offset++) {
          final civilDate = DateTime(
            confirmation.anchorDate.year,
            confirmation.anchorDate.month,
            confirmation.anchorDate.day + offset,
          );
          final confirmed = confirmation.lookup(civilDate);
          if (confirmed == null) break;
          if (confirmed.hYear == year &&
              confirmed.hMonth == month &&
              confirmed.hDay == day) {
            return DateTime(civilDate.year, civilDate.month, civilDate.day);
          }
        }
      }
      for (final entry in calendar.surveyDates.entries) {
        final civilDate = EgyptianHijriCalendar.parseCivilKey(entry.key);
        final hijri = calendar.lookup(civilDate);
        if (hijri != null &&
            hijri.hYear == year &&
            hijri.hMonth == month &&
            hijri.hDay == day) {
          return civilDate;
        }
      }
    }
    final calculated = HijriCalendar().hijriToGregorian(year, month, day);
    return NotificationScheduleHelpers.addCivilDays(
      calculated,
      -effectiveHijriDayAdjustment,
    );
  }

  Future<void> setHijriSystem(String system) async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(keyHijriSystem, system);
    if (system == systemEgyptian) {
      try {
        await HijriSourceService.syncOffsetIfNeeded(
          rescheduleNotifications: false,
        );
      } catch (_) {}
    }
    notifyListeners();
    try {
      await scheduleNotifications(isUserAction: true);
    } catch (_) {}
  }

  HijriCalendar getAdjustedHijri() => getHijriWithOffset(hijriOffset);

  String getAdjustedHijriString() {
    HijriCalendar.setLocal('ar');
    final h = getAdjustedHijri();
    return '${h.hDay} ${h.longMonthName} ${h.hYear} هـ';
  }

  Future<void> setIs24Hour(bool value) async {
    _is24Hour = value;
    final prefs = CacheHelper.prefs;
    await prefs.setBool(keyIs24Hour, value);
    notifyListeners();
  }

  String formatTime(DateTime time) => _is24Hour
      ? DateFormat('HH:mm').format(time)
      : DateFormat.jm('ar').format(time);

  static Future<void> cacheHijriDatesForNative(int offset) async {
    final prefs = CacheHelper.prefs;
    final egyptianSystem = isEgyptianSystem;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    await prefs.setInt('hijri_cache_start_epoch', todayStart);
    // Native look-ahead needs 30 days; one extra boundary cushion is retained.
    for (int i = 0; i < 33; i++) {
      final targetDate = DateTime(now.year, now.month, now.day + i);
      final hDate = getNotificationHijriForDate(targetDate);
      final civilKey = EgyptianHijriCalendar.civilKey(targetDate);
      final key = 'notification_hijri_$civilKey';
      final sourceKey = 'local_hijri_confirmed_source_$civilKey';
      if (hDate == null) {
        await prefs.remove(key);
        if (egyptianSystem) await prefs.remove(sourceKey);
      } else {
        // Stable numeric contract consumed by NativePrayerManager.
        await prefs.setString(
          key,
          '${hDate.hDay},${hDate.hMonth},${hDate.hYear}',
        );
        if (egyptianSystem) {
          final isManual =
              EgyptianHijriCalendar.instance.userConfirmation?.lookup(
                targetDate,
              ) !=
              null;
          await prefs.setString(
            sourceKey,
            isManual ? 'user_confirmation' : 'survey_authority_annual_calendar',
          );
        } else {
          await prefs.remove(sourceKey);
        }
      }
    }
  }
}

class ExtendedPrayer {
  final String id;
  final String name;
  final DateTime time;
  final Prayer? prayer;
  ExtendedPrayer({
    required this.id,
    required this.name,
    required this.time,
    this.prayer,
  });
}
