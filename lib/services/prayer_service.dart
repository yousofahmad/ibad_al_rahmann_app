import 'package:flutter/widgets.dart';
import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
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
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

@pragma('vm:entry-point')
Future<void> backgroundWidgetUpdateCallback() async {
  // Ensure Flutter is initialized in the background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AlarmManager in this isolate
  await AndroidAlarmManager.initialize().catchError((e) {
    debugPrint('AlarmManager background init error: $e');
    return false;
  });

  try {
    debugPrint("Background Task: Running Midnight Refresh...");
    // Initialize Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Refresh the remote config inside background
    await RemoteConfigService.init();

    // Force Arabic locale
    HijriCalendar.setLocal('ar');
    Intl.defaultLocale = 'ar';

    final service = PrayerService();
    await service.init();
    // Perform full refresh in background (isUserAction: true) to update all alarms
    await service.scheduleNotifications(isUserAction: true);
    debugPrint("Background Task: Refresh Complete.");
  } catch (e) {
    debugPrint("Background Widget Callback Error: $e");
    // If it fails, try to schedule for tomorrow anyway to prevent the chain from breaking
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

class PrayerService extends ChangeNotifier {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

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
    await prefs.setString('calculation_method', _activeCity?.calculationMethod ?? _method.name.toUpperCase());
    await prefs.setString('madhab', _activeCity?.madhab ?? _madhab.name.toUpperCase());
    // Save total offset (manual + delta + firebase) for Native Android to use
    await prefs.setInt('hijri_offset', hijriOffset);
    await prefs.setInt('firebase_hijri_offset', RemoteConfigService.globalHijriOffset);
  }

  Future<void> init() async {
    if (_isInitializing) return;
    if (_lastInitTime != null && 
        DateTime.now().difference(_lastInitTime!) < const Duration(seconds: 30)) {
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
      
      await Future.delayed(Duration.zero); // Yield

      // Defer heavy notification and alarm scheduling until after app startup
      Future.delayed(const Duration(seconds: 1), () {
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
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
      debugPrint('PrayerService: Initialized from cached location: $lat, $lng');
    } else {
      _coordinates = Coordinates(30.0444, 31.2357);
      prefs.setDouble('last_lat', 30.0444);
      prefs.setDouble('last_lng', 31.2357);
      prefs.setDouble('latitude', 30.0444);
      prefs.setDouble('longitude', 31.2357);
      debugPrint('PrayerService: No cached location, using default (Cairo)');
    }
  }

  Future<void> _refreshLocationInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await scheduleNotifications(isUserAction: false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await scheduleNotifications(isUserAction: false);
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
      await prefs2.setInt('last_gps_update_ms', DateTime.now().millisecondsSinceEpoch);

      final oldLat = _coordinates?.latitude;
      final oldLng = _coordinates?.longitude;

      _coordinates = Coordinates(position.latitude, position.longitude);

      final prefs = CacheHelper.prefs;
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);

      debugPrint(
        'PrayerService: Location refreshed in background: ${position.latitude}, ${position.longitude}',
      );

      bool shouldReschedule = true;
      if (oldLat != null && oldLng != null) {
        double distance = Geolocator.distanceBetween(oldLat, oldLng, position.latitude, position.longitude);
        if (distance < 1000) {
           shouldReschedule = false;
           debugPrint('PrayerService: Location change insignificant ($distance m). Skipping reschedule.');
        }
      }

      if (shouldReschedule) {
        await scheduleNotifications(isUserAction: false);
      } else {
        updatePersistentElements();
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
      } catch (_) {}
    } catch (e) {
      debugPrint('PrayerService: Background location refresh failed: $e');
      await scheduleNotifications(isUserAction: false);
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
    final daysSinceLast = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastMs),
    ).inDays;

    if (daysSinceLast < 7) return; // Still fresh — no need to refresh

    debugPrint('PrayerService: GPS stale ($daysSinceLast days old). Requesting fresh fix...');
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
      await prefs.setInt('last_gps_update_ms', DateTime.now().millisecondsSinceEpoch);

      debugPrint('PrayerService: Periodic refresh done: ${position.latitude}, ${position.longitude}');

      // Reschedule only if location moved more than 1km
      if (oldLat != null && oldLng != null) {
        final dist = Geolocator.distanceBetween(oldLat, oldLng, position.latitude, position.longitude);
        if (dist > 1000) await scheduleNotifications(isUserAction: false);
      }
    } catch (e) {
      // Non-fatal: keep using cached coordinates
      debugPrint('PrayerService: Periodic location refresh failed (using cache): $e');
    }
  }

  DateTime? _lastScheduleTime;

  Future<void> _syncNativeEngineConfig() async {
    final prefs = CacheHelper.prefs;
    
    // Write effective coordinates so NativePrayerManager can read them even if an active city is selected
    if (_activeCity != null) {
      await prefs.setDouble('latitude', _activeCity!.latitude);
      await prefs.setDouble('longitude', _activeCity!.longitude);
      await prefs.setString('calculation_method', _activeCity!.calculationMethod);
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
  }

  Future<void> scheduleNotifications({bool isUserAction = true}) async {
    _lastScheduleTime = DateTime.now();

    await _syncNativeEngineConfig();

    final times = getPrayerTimes();
    if (times != null) {
      await NotificationService.schedulePrayerNotifications(times, isUserAction: isUserAction);
      await updatePersistentElements();
      
      try {
        final now = DateTime.now();
        // Schedule refresh 1 hour after Isha
        DateTime scheduleTime = times.isha.add(const Duration(hours: 1));
        if (scheduleTime.isBefore(now)) {
          scheduleTime = scheduleTime.add(const Duration(days: 1));
        }
        
        AndroidAlarmManager.periodic(
          const Duration(hours: 24),
          0,
          backgroundWidgetUpdateCallback,
          startAt: scheduleTime,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      } catch (e) {
        debugPrint("Error scheduling periodic background refresh: $e");
      }
    }
  }

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
      final tomorrow = now.add(const Duration(days: 1));
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
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayTimes = getPrayerTimesForDate(yesterday);
      currentTime = yesterdayTimes?.isha;
    }

    int goldTargetEpoch = nextTime.millisecondsSinceEpoch;
    bool goldIsCountUp = false;

    if (currentTime != null) {
      final elapsed = now.difference(currentTime);
      final int countUpWindowMinutes;
      switch (currentPrayer) {
        case Prayer.fajr:  // Fajr: 60-minute count-up window
        case Prayer.isha:  // Isha: 60-minute count-up window
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
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String toArabicDigits(String input) {
      const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < english.length; i++) {
        input = input.replaceAll(english[i], arabic[i]);
      }
      return input;
    }

    if (goldIsCountUp && currentTime != null) {
      final elapsed = now.difference(currentTime);
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes.remainder(60);
      final seconds = elapsed.inSeconds.remainder(60);
      countdownStr =
          "$_ltr${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}$_ltr";

      final cName = _getPrayerName(
        currentPrayer == Prayer.none ? Prayer.isha : currentPrayer,
      );
      goldNextName = "مضى على $cName";
    } else {
      final diff = countdownTargetTime.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      final seconds = diff.inSeconds.remainder(60);
      countdownStr =
          "$_ltr${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}$_ltr";

      final gn = _getPrayerName(
        goldNextPrayer == Prayer.none ? Prayer.fajr : goldNextPrayer,
      );
      goldNextName = "متبقي على $gn";
    }

    HijriCalendar.setLocal('ar');
    final hDate = PrayerService.getHijriWithOffset(hijriOffset);
    String hijriStr =
        "\u200F${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}\u200F";

    countdownStr = toArabicDigits(countdownStr);
    hijriStr = toArabicDigits(hijriStr);

    final prefs = CacheHelper.prefs;
    final persistentEnabled = prefs.getBool('persistent_notification_enabled') ?? true;

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
          DateTime d = now.add(Duration(days: i));
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

  String _ltrWrap(String value) => '$_ltr$value$_ltr';

  int _prayerToIndex(Prayer p) {
    switch (p) {
      case Prayer.fajr: return 0;
      case Prayer.sunrise: return 1;
      case Prayer.dhuhr: return 1;
      case Prayer.asr: return 2;
      case Prayer.maghrib: return 3;
      case Prayer.isha: return 4;
      default: return -1;
    }
  }

  String _getPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr: return "الفجر";
      case Prayer.sunrise: return "الشروق";
      case Prayer.dhuhr: return "الظهر";
      case Prayer.asr: return "العصر";
      case Prayer.maghrib: return "المغرب";
      case Prayer.isha: return "العشاء";
      default: return "الفجر";
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
    final currentHijriMonth = HijriCalendar.fromDate(DateTime.now()).hMonth;
    final savedOffsetMonth = prefs.getInt(keyHijriOffsetMonth);
    if (savedOffsetMonth != null && savedOffsetMonth != currentHijriMonth) {
      _hijriOffset = 0;
      await prefs.setInt(keyHijriOffset, 0);
      await prefs.setInt(keyHijriOffsetMonth, currentHijriMonth);
    }
    String? methodKey = prefs.getString(keyMethod);
    if (methodKey != null) _method = _getMethodFromKey(methodKey);
    String? madhabKey = prefs.getString(keyMadhab);
    if (madhabKey != null) _madhab = madhabKey == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    _ramadanIshaDelayMode = prefs.getInt(keyRamadanCycle) ?? 0;
    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (String p in prayers) {
      _adjustments[p] = prefs.getInt('$keyAdjustPrefix$p') ?? 0;
    }
  }

  CalculationMethod _getMethodFromKey(String key) {
    switch (key) {
      case 'egypt': return CalculationMethod.egyptian;
      case 'makkah': return CalculationMethod.umm_al_qura;
      case 'karachi': return CalculationMethod.karachi;
      case 'dubai': return CalculationMethod.dubai;
      case 'kuwait': return CalculationMethod.kuwait;
      case 'qatar': return CalculationMethod.qatar;
      case 'moonsighting': return CalculationMethod.moon_sighting_committee;
      case 'singapore': return CalculationMethod.singapore;
      case 'turkey': return CalculationMethod.turkey;
      case 'tehran': return CalculationMethod.tehran;
      case 'isna': return CalculationMethod.north_america;
      case 'mwl': return CalculationMethod.muslim_world_league;
      default: return CalculationMethod.egyptian;
    }
  }

  Future<void> updateLocation() async {
    await _getLocation();
    await scheduleNotifications(isUserAction: false);
  }

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      _coordinates = Coordinates(position.latitude, position.longitude);
      final prefs = CacheHelper.prefs;
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final city = place.locality?.isNotEmpty == true ? place.locality : place.subAdministrativeArea;
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

  PrayerTimes? getPrayerTimes() {
    if (_activeCity != null) {
      final coords = Coordinates(_activeCity!.latitude, _activeCity!.longitude);
      final method = _getMethodFromKey(_activeCity!.calculationMethod);
      final params = method.getParameters();
      params.madhab = _activeCity!.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      params.adjustments.fajr = _activeCity!.offsets['Fajr'] ?? 0;
      params.adjustments.sunrise = _activeCity!.offsets['Sunrise'] ?? 0;
      params.adjustments.dhuhr = _activeCity!.offsets['Dhuhr'] ?? 0;
      params.adjustments.asr = _activeCity!.offsets['Asr'] ?? 0;
      params.adjustments.maghrib = _activeCity!.offsets['Maghrib'] ?? 0;
      params.adjustments.isha = _activeCity!.offsets['Isha'] ?? 0;
      final now = DateTime.now();
      return PrayerTimes(coords, DateComponents(now.year, now.month, now.day), params);
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
    return PrayerTimes(_coordinates!, DateComponents(now.year, now.month, now.day), params);
  }

  PrayerTimes? getPrayerTimesForDate(DateTime date) {
    if (_activeCity != null) {
      final coords = Coordinates(_activeCity!.latitude, _activeCity!.longitude);
      final method = _getMethodFromKey(_activeCity!.calculationMethod);
      final params = method.getParameters();
      params.madhab = _activeCity!.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      params.adjustments.fajr = _activeCity!.offsets['Fajr'] ?? 0;
      params.adjustments.sunrise = _activeCity!.offsets['Sunrise'] ?? 0;
      params.adjustments.dhuhr = _activeCity!.offsets['Dhuhr'] ?? 0;
      params.adjustments.asr = _activeCity!.offsets['Asr'] ?? 0;
      params.adjustments.maghrib = _activeCity!.offsets['Maghrib'] ?? 0;
      params.adjustments.isha = _activeCity!.offsets['Isha'] ?? 0;
      return PrayerTimes(coords, DateComponents(date.year, date.month, date.day), params);
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
    return PrayerTimes(_coordinates!, DateComponents(date.year, date.month, date.day), params);
  }

  static Future<PrayerTimes?> getPrayerTimesForDateStatic(DateTime date) async {
    final prefs = CacheHelper.prefs;
    String? activeCityId = prefs.getString(keyActiveCityId);
    if (activeCityId != null) {
      String? jsonStr = prefs.getString(keySavedCities);
      if (jsonStr != null) {
        try {
          List<dynamic> list = jsonDecode(jsonStr);
          var cities = list.map((e) => CityProfile.fromJson(e)).toList();
          var activeCity = cities.firstWhere((c) => c.id == activeCityId);
          final coords = Coordinates(activeCity.latitude, activeCity.longitude);
          CalculationMethod methodEnum = CalculationMethod.egyptian;
          final params = methodEnum.getParameters();
          params.madhab = activeCity.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
          params.adjustments.fajr = activeCity.offsets['Fajr'] ?? 0;
          params.adjustments.sunrise = activeCity.offsets['Sunrise'] ?? 0;
          params.adjustments.dhuhr = activeCity.offsets['Dhuhr'] ?? 0;
          params.adjustments.asr = activeCity.offsets['Asr'] ?? 0;
          params.adjustments.maghrib = activeCity.offsets['Maghrib'] ?? 0;
          params.adjustments.isha = activeCity.offsets['Isha'] ?? 0;
          return PrayerTimes(coords, DateComponents(date.year, date.month, date.day), params);
        } catch (_) {}
      }
    }
    double lat = prefs.getDouble('last_lat') ?? 30.0444;
    double lng = prefs.getDouble('last_lng') ?? 31.2357;
    final params = CalculationMethod.egyptian.getParameters();
    return PrayerTimes(Coordinates(lat, lng), DateComponents(date.year, date.month, date.day), params);
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

  Future<void> scheduleNotificationsDebounced({bool isUserAction = true}) async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 2500), () {
      scheduleNotifications(isUserAction: isUserAction);
    });
  }

  Future<void> saveAdjustment(String prayer, int minutes) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt('$keyAdjustPrefix$prayer', minutes);
    _adjustments[prayer] = minutes;
    scheduleNotificationsDebounced(isUserAction: true);
  }

  Future<void> saveRamadanIshaDelay(int mode) async {
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyRamadanCycle, mode);
    _ramadanIshaDelayMode = mode;
    await scheduleNotifications(isUserAction: true);
  }

  Map<String, int> get adjustments => _activeCity != null ? _activeCity!.offsets : _adjustments;
  CalculationMethod get method => _activeCity != null ? _getMethodFromKey(_activeCity!.calculationMethod) : _method;
  Madhab get madhab => _activeCity != null ? (_activeCity!.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi) : _madhab;
  int get ramadanIshaDelayMode => _ramadanIshaDelayMode;
  List<CityProfile> get savedCities => _savedCities;
  CityProfile? get activeCity => _activeCity;
  String get cityName => _activeCity?.name ?? (_currentCityName.isNotEmpty ? _currentCityName : "الموقع الحالي");

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
      if (_activeCity?.id == city.id) { _activeCity = city; await scheduleNotifications(isUserAction: true); }
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
    if (id == null) { _activeCity = null; await prefs.remove(keyActiveCityId); }
    else { try { _activeCity = _savedCities.firstWhere((c) => c.id == id); await prefs.setString(keyActiveCityId, id); } catch (_) { _activeCity = null; } }
    await scheduleNotifications(isUserAction: true);
  }

  Future<void> _loadCities(SharedPreferences prefs) async {
    String? jsonStr = prefs.getString(keySavedCities);
    if (jsonStr != null) { try { List<dynamic> list = jsonDecode(jsonStr); _savedCities = list.map((e) => CityProfile.fromJson(e)).toList(); } catch (_) {} }
  }

  Future<void> _saveCities() async {
    final prefs = CacheHelper.prefs;
    await prefs.setString(keySavedCities, jsonEncode(_savedCities.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadActiveCity(SharedPreferences prefs) async {
    String? id = prefs.getString(keyActiveCityId);
    if (id != null) { try { _activeCity = _savedCities.firstWhere((c) => c.id == id); } catch (_) { await prefs.remove(keyActiveCityId); } }
  }

  Future<List<ExtendedPrayer>> getExtendedPrayers({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    if (_coordinates == null) return [];
    final params = _method.getParameters();
    params.madhab = _madhab;
    final times = PrayerTimes(_coordinates!, DateComponents(targetDate.year, targetDate.month, targetDate.day), params);
    final nextDayTimes = PrayerTimes(_coordinates!, DateComponents(targetDate.add(const Duration(days: 1)).year, targetDate.add(const Duration(days: 1)).month, targetDate.add(const Duration(days: 1)).day), params);

    DateTime fajr = _applyOffset(times.fajr, 'Fajr');
    DateTime sunrise = _applyOffset(times.sunrise, 'Sunrise');
    DateTime dhuhr = _applyOffset(times.dhuhr, 'Dhuhr');
    DateTime asr = _applyOffset(times.asr, 'Asr');
    DateTime maghrib = _applyOffset(times.maghrib, 'Maghrib');
    DateTime isha = _ramadanIshaDelayMode > 0 ? maghrib.add(Duration(minutes: _ramadanIshaDelayMode)) : _applyOffset(times.isha, 'Isha');
    DateTime duha = sunrise.add(const Duration(minutes: 15));
    DateTime nextFajr = _applyOffset(nextDayTimes.fajr, 'Fajr');
    Duration nightDuration = nextFajr.difference(maghrib);
    DateTime midnight = maghrib.add(Duration(seconds: (nightDuration.inSeconds / 2).round()));
    DateTime firstThird = maghrib.add(Duration(seconds: (nightDuration.inSeconds / 3).round()));
    DateTime lastThird = nextFajr.subtract(Duration(seconds: (nightDuration.inSeconds / 3).round()));

    return [
      ExtendedPrayer(id: 'fajr', name: 'الفجر', time: fajr, prayer: Prayer.fajr),
      ExtendedPrayer(id: 'sunrise', name: 'الشروق', time: sunrise, prayer: Prayer.sunrise),
      ExtendedPrayer(id: 'duha', name: 'الضحى', time: duha, prayer: null),
      ExtendedPrayer(id: 'dhuhr', name: 'الظهر', time: dhuhr, prayer: Prayer.dhuhr),
      ExtendedPrayer(id: 'asr', name: 'العصر', time: asr, prayer: Prayer.asr),
      ExtendedPrayer(id: 'maghrib', name: 'المغرب', time: maghrib, prayer: Prayer.maghrib),
      ExtendedPrayer(id: 'isha', name: 'العشاء', time: isha, prayer: Prayer.isha),
      ExtendedPrayer(id: 'first_third', name: 'ثلث الليل الأول', time: firstThird, prayer: null),
      ExtendedPrayer(id: 'midnight', name: 'منتصف الليل', time: midnight, prayer: null),
      ExtendedPrayer(id: 'last_third', name: 'ثلث الليل الأخير', time: lastThird, prayer: null),
    ];
  }

  DateTime _applyOffset(DateTime original, String key) {
    return original.add(Duration(minutes: _adjustments[key] ?? 0));
  }

  static HijriCalendar getHijriWithOffset(int offsetDays, [DateTime? date]) {
    final baseDate = date ?? DateTime.now();
    final adjustedDate = baseDate.add(Duration(days: offsetDays));
    final h = HijriCalendar.fromDate(adjustedDate);
    // ── تصحيح يوم 29 → 30 ──────────────────────────────────────────────
    // بعض الأشهر الهجرية 29 يوماً لكن المكتبة تُرجع 29 حتى لو اليوم هو 30
    // نتحقق: لو اليوم 29 وبكرا هيكون أول الشهر الجاي → نعرض 30
    if (h.hDay == 29) {
      final tomorrow = adjustedDate.add(const Duration(days: 1));
      final tomorrowH = HijriCalendar.fromDate(tomorrow);
      if (tomorrowH.hMonth != h.hMonth || tomorrowH.hYear != h.hYear) {
        // اليوم آخر الشهر — تحقق هل الشهر 29 فعلاً أم المكتبة قصّرته
        // نُرجع نفس الكائن مع تعديل hDay لـ 30 إذا كان الشهر الجاي بدأ مبكراً
        final lastDayCheck = adjustedDate.add(const Duration(days: 1));
        final nextH = HijriCalendar.fromDate(lastDayCheck);
        if (nextH.hDay == 1) {
          // المكتبة انتقلت للشهر الجديد بعد 29 — نعرض 30 للمستخدم
          final corrected = HijriCalendar();
          corrected.hYear = h.hYear;
          corrected.hMonth = h.hMonth;
          corrected.hDay = 30;
          return corrected;
        }
      }
    }
    return h;
  }

  int get hijriOffset => RemoteConfigService.globalHijriOffset + _hijriOffset + _localHijriDelta;
  int get manualHijriOffset => _hijriOffset;
  int get localHijriDelta => _localHijriDelta;
  bool get is24Hour => _is24Hour;

  Future<void> setHijriOffset(int offset) async {
    _hijriOffset = offset;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyHijriOffset, offset);
    // احفظ الشهر الهجري المُعدَّل (مع الـ offset) وليس raw الشهر
    await prefs.setInt(keyHijriOffsetMonth, getHijriWithOffset(offset).hMonth);
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }

  Future<void> setLocalHijriDelta(int delta) async {
    _localHijriDelta = delta;
    final prefs = CacheHelper.prefs;
    await prefs.setInt(keyLocalHijriDelta, delta);
    notifyListeners();
    await scheduleNotifications(isUserAction: true);
  }

  HijriCalendar getAdjustedHijri() => getHijriWithOffset(hijriOffset);
  String getAdjustedHijriString() { HijriCalendar.setLocal('ar'); final h = getAdjustedHijri(); return '${h.hDay} ${h.longMonthName} ${h.hYear} هـ'; }
  Future<void> setIs24Hour(bool value) async { _is24Hour = value; final prefs = CacheHelper.prefs; await prefs.setBool(keyIs24Hour, value); notifyListeners(); }
  String formatTime(DateTime time) => _is24Hour ? DateFormat('HH:mm').format(time) : DateFormat.jm('ar').format(time);
}

class ExtendedPrayer {
  final String id;
  final String name;
  final DateTime time;
  final Prayer? prayer;
  ExtendedPrayer({required this.id, required this.name, required this.time, this.prayer});
}
