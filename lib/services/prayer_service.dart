import 'package:flutter/foundation.dart';
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

class PrayerService extends ChangeNotifier {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

  Coordinates? _coordinates;
  CalculationMethod _method = CalculationMethod.egyptian;
  Madhab _madhab = Madhab.shafi;
  int _ramadanIshaDelayMode = 0; // 0=Original, 90=90min, 120=120min
  int _hijriOffset = 0; // -2 to +2
  bool _is24Hour = false;

  // Multi-Location
  List<CityProfile> _savedCities = [];
  CityProfile? _activeCity;

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
  static const String keyHijriOffset = 'hijri_offset';
  static const String keyIs24Hour = 'is_24_hour';
  static const String keyAdjustPrefix = 'adjust_';
  static const String keyRamadanCycle = 'ramadan_isha_delay';
  static const String keySavedCities = 'saved_cities';
  static const String keyActiveCityId = 'active_city_id';

  Future<void> init() async {
    await _loadSettings();
    await _getLocation();
    scheduleNotifications(); // Schedule on init
  }

  void scheduleNotifications() {
    final times = getPrayerTimes();
    if (times != null) {
      NotificationService.schedulePrayerNotifications(times);
      updatePersistentElements();
    }
  }

  /// Unicode LTR mark to prevent garbled Arabic+number rendering in Android RemoteViews
  static const String _ltr = '\u200E';

  Future<void> updatePersistentElements() async {
    final times = getPrayerTimes();
    if (times == null) return;

    final now = DateTime.now();

    // Determine Next Prayer (Logic for skipping Sunrise entirely)
    Prayer nextPrayer = times.nextPrayer();
    if (nextPrayer == Prayer.sunrise) {
      nextPrayer = Prayer.dhuhr; // Skip sunrise, go straight to Dhuhr
    }

    DateTime? nextTime;

    if (nextPrayer != Prayer.none) {
      nextTime = times.timeForPrayer(nextPrayer);
    } else {
      // Logic for tomorrow's fajr
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowTimes = getPrayerTimesForDate(tomorrow);
      if (tomorrowTimes != null) {
        nextTime = tomorrowTimes.fajr;
        nextPrayer = Prayer.fajr;
      }
    }

    if (nextTime == null) return;

    // --- 45-Minute Rule Logic ---
    Prayer currentPrayer = times.currentPrayer();
    if (currentPrayer == Prayer.sunrise) {
      currentPrayer = Prayer
          .fajr; // Treat Sunrise period as still being Fajr's post-prayer time
    }

    DateTime? currentTime;
    if (currentPrayer != Prayer.none) {
      currentTime = times.timeForPrayer(currentPrayer);
    } else {
      // Before Fajr (Night)
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayTimes = getPrayerTimesForDate(yesterday);
      currentTime = yesterdayTimes?.isha;
    }

    int goldTargetEpoch = nextTime.millisecondsSinceEpoch;
    bool goldIsCountUp = false;

    if (currentTime != null) {
      final elapsed = now.difference(currentTime);
      // If within 45 mins after a prayer started
      if (elapsed.inMinutes >= 0 && elapsed.inMinutes < 45) {
        goldTargetEpoch = currentTime.millisecondsSinceEpoch;
        goldIsCountUp = true;
      }
    }

    // --- Countdown target time vs Highlighted prayer ---
    DateTime countdownTargetTime = nextTime;

    // Since we skipped Sunrise above, goldNextPrayer is just nextPrayer
    Prayer goldNextPrayer = nextPrayer;
    DateTime? goldNextTime = nextTime;

    // ── Highlighted Prayer Index (separate from countdown target) ──
    // This is the index (0-4) that should "light up" in the native 5-prayer row.
    int highlightedPrayerIndex;
    if (goldIsCountUp) {
      // Highlight the prayer that just passed (count-up mode)
      highlightedPrayerIndex = _prayerToIndex(currentPrayer);
    } else {
      // Highlight the next prayer (countdown mode)
      highlightedPrayerIndex = _prayerToIndex(goldNextPrayer);
    }

    // Format Countdown & Name (with LTR marks for Android RTL safety)
    String countdownStr;
    String goldNextName;
    String twoDigits(int n) => n.toString().padLeft(2, '0');

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

      // Gold widget label uses the highlighted prayer (skips Sunrise → Dhuhr)
      final gn = _getPrayerName(
        goldNextPrayer == Prayer.none ? Prayer.fajr : goldNextPrayer,
      );
      goldNextName = "$gn متبقي";
    }

    // Format Hijri (with LTR marks around numbers)
    final hDate = HijriCalendar.fromDate(now.add(Duration(days: _hijriOffset)));
    final hijriStr =
        "$_ltr${hDate.hDay}$_ltr ${hDate.longMonthName} $_ltr${hDate.hYear}$_ltr";

    // Update Persistent Notification
    final prefs = await SharedPreferences.getInstance();
    final persistentEnabled = prefs.getBool('persistent_notification') ?? true;

    if (persistentEnabled) {
      await PrayerNotificationServiceHelper.updateNotification(
        fajr: _ltrWrap(formatTime(times.fajr)),
        dhuhr: _ltrWrap(formatTime(times.dhuhr)),
        asr: _ltrWrap(formatTime(times.asr)),
        maghrib: _ltrWrap(formatTime(times.maghrib)),
        isha: _ltrWrap(formatTime(times.isha)),
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

    // Update Widgets
    await HomeWidgetService.updatePrayerWidget(
      fajr: _ltrWrap(formatTime(times.fajr)),
      dhuhr: _ltrWrap(formatTime(times.dhuhr)),
      asr: _ltrWrap(formatTime(times.asr)),
      maghrib: _ltrWrap(formatTime(times.maghrib)),
      isha: _ltrWrap(formatTime(times.isha)),
      nextName: goldNextName,
      countdown: countdownStr,
      hijri: hijriStr,
      prayerIndex: highlightedPrayerIndex,
      prayerTime: _ltrWrap(formatTime(goldNextTime)),
      nextPrayerEpoch: (goldIsCountUp && currentTime != null)
          ? currentTime.millisecondsSinceEpoch
          : countdownTargetTime.millisecondsSinceEpoch,
      sunriseTime: _ltrWrap(formatTime(times.sunrise)),
      locationName: _activeCity?.name ?? "الموقع الحالي",
      isCountUp: goldIsCountUp,
    );

    // Update Golden Widget Specific Extra Data
    await HomeWidgetService.updateGoldWidgetData(
      targetEpoch: goldTargetEpoch,
      isCountUp: goldIsCountUp,
    );

    // Save highlighted_prayer_index for native Kotlin to read
    await HomeWidget.saveWidgetData<int>(
      'highlighted_prayer_index',
      highlightedPrayerIndex,
    );
  }

  /// Wraps a time/number string with LTR marks for safe Android RTL rendering
  String _ltrWrap(String value) => '$_ltr$value$_ltr';

  /// Maps a Prayer enum to a 0-4 index (Fajr=0, Dhuhr=1, Asr=2, Maghrib=3, Isha=4).
  /// Sunrise maps to 1 (Dhuhr). Unknown/none returns -1.
  int _prayerToIndex(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 0;
      case Prayer.sunrise:
        return 1; // Sunrise highlights Dhuhr
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

  String _getPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return "الفجر";
      case Prayer.sunrise:
        return "الشروق";
      case Prayer.dhuhr:
        return "الظهر";
      case Prayer.asr:
        return "العصر";
      case Prayer.maghrib:
        return "المغرب";
      case Prayer.isha:
        return "العشاء";
      default:
        return "الفجر";
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Cities
    _loadCities(prefs);
    _loadActiveCity(prefs);

    // Load Settings
    _hijriOffset = prefs.getInt(keyHijriOffset) ?? 0;
    _is24Hour = prefs.getBool(keyIs24Hour) ?? false;

    // Load Settings
    _hijriOffset = prefs.getInt(keyHijriOffset) ?? 0;
    _is24Hour = prefs.getBool(keyIs24Hour) ?? false;

    // If active city exists, settings are derived from it.
    // Otherwise fallback to global settings.

    // Load Method
    String? methodKey = prefs.getString(keyMethod);
    if (methodKey != null) {
      _method = _getMethodFromKey(methodKey);
    }

    // Load Madhab
    String? madhabKey = prefs.getString(keyMadhab);
    if (madhabKey != null) {
      _madhab = madhabKey == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }

    // Load Ramadan Isha Delay
    _ramadanIshaDelayMode = prefs.getInt(keyRamadanCycle) ?? 0;

    // Load Adjustments
    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (String p in prayers) {
      _adjustments[p] = prefs.getInt('$keyAdjustPrefix$p') ?? 0;
    }
  }

  CalculationMethod _getMethodFromKey(String key) {
    switch (key) {
      case 'egypt':
        return CalculationMethod.egyptian;
      case 'makkah':
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
        return CalculationMethod.moon_sighting_committee;
      case 'singapore':
        return CalculationMethod.singapore;
      case 'turkey':
        return CalculationMethod.turkey;
      case 'tehran':
        return CalculationMethod.tehran;
      case 'isna':
        return CalculationMethod.north_america;
      case 'mwl':
        return CalculationMethod.muslim_world_league;
      default:
        return CalculationMethod.egyptian;
    }
  }

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _coordinates = Coordinates(position.latitude, position.longitude);

      // If no active city, use this GPS location
      // But we keep _coordinates as the "GPS Coordinates" always.
      // If active city is set, getPrayerTimes uses it.
    } catch (e) {
      // Handle permission or location errors
      // Default to Cairo for example or keep null
      _coordinates = Coordinates(30.0444, 31.2357); // Cairo fallback
    }
  }

  PrayerTimes? getPrayerTimes() {
    // If Active City is set, use it
    if (_activeCity != null) {
      final coords = Coordinates(_activeCity!.latitude, _activeCity!.longitude);
      final method = _getMethodFromKey(_activeCity!.calculationMethod);
      final params = method.getParameters();
      params.madhab = _activeCity!.madhab == 'hanafi'
          ? Madhab.hanafi
          : Madhab.shafi;

      // Apply Active City Offsets
      params.adjustments.fajr = _activeCity!.offsets['Fajr'] ?? 0;
      params.adjustments.sunrise = _activeCity!.offsets['Sunrise'] ?? 0;
      params.adjustments.dhuhr = _activeCity!.offsets['Dhuhr'] ?? 0;
      params.adjustments.asr = _activeCity!.offsets['Asr'] ?? 0;
      params.adjustments.maghrib = _activeCity!.offsets['Maghrib'] ?? 0;
      params.adjustments.isha = _activeCity!.offsets['Isha'] ?? 0;

      final now = DateTime.now();
      final date = DateComponents(now.year, now.month, now.day);
      return PrayerTimes(coords, date, params);
    }

    // Fallback to GPS / Global Settings
    if (_coordinates == null) return null;

    final params = _method.getParameters();
    params.madhab = _madhab;
    params.adjustments.sunrise = _adjustments['Sunrise'] ?? 0;
    params.adjustments.dhuhr = _adjustments['Dhuhr'] ?? 0;
    params.adjustments.asr = _adjustments['Asr'] ?? 0;
    params.adjustments.maghrib = _adjustments['Maghrib'] ?? 0;
    params.adjustments.isha = _adjustments['Isha'] ?? 0;

    final now = DateTime.now();
    final date = DateComponents(now.year, now.month, now.day);

    return PrayerTimes(_coordinates!, date, params);
  }

  PrayerTimes? getPrayerTimesForDate(DateTime date) {
    // Fallback to GPS / Global Settings if no active city
    if (_activeCity != null) {
      final coords = Coordinates(_activeCity!.latitude, _activeCity!.longitude);
      final method = _getMethodFromKey(_activeCity!.calculationMethod);
      final params = method.getParameters();
      params.madhab = _activeCity!.madhab == 'hanafi'
          ? Madhab.hanafi
          : Madhab.shafi;

      // Apply Active City Offsets
      params.adjustments.fajr = _activeCity!.offsets['Fajr'] ?? 0;
      params.adjustments.sunrise = _activeCity!.offsets['Sunrise'] ?? 0;
      params.adjustments.dhuhr = _activeCity!.offsets['Dhuhr'] ?? 0;
      params.adjustments.asr = _activeCity!.offsets['Asr'] ?? 0;
      params.adjustments.maghrib = _activeCity!.offsets['Maghrib'] ?? 0;
      params.adjustments.isha = _activeCity!.offsets['Isha'] ?? 0;

      final dateComps = DateComponents(date.year, date.month, date.day);
      return PrayerTimes(coords, dateComps, params);
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

    final dateComps = DateComponents(date.year, date.month, date.day);
    return PrayerTimes(_coordinates!, dateComps, params);
  }

  Prayer? getNextPrayer() {
    final times = getPrayerTimes();
    if (times == null) return null;
    return times.nextPrayer();
  }

  Future<void> saveMethod(String methodKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyMethod, methodKey);
    _method = _getMethodFromKey(methodKey);
    scheduleNotifications(); // Reschedule
  }

  Future<void> saveMadhab(String madhabKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyMadhab, madhabKey);
    _madhab = madhabKey == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    scheduleNotifications(); // Reschedule
  }

  Future<void> saveAdjustment(String prayer, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$keyAdjustPrefix$prayer', minutes);
    _adjustments[prayer] = minutes;
    scheduleNotifications(); // Reschedule
  }

  Future<void> saveRamadanIshaDelay(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyRamadanCycle, mode);
    _ramadanIshaDelayMode = mode;
    scheduleNotifications();
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

  // --- City Management Methods ---

  Future<void> addCity(CityProfile city) async {
    _savedCities.add(city);
    await _saveCities();
    if (_savedCities.length == 1) {
      await setActiveCity(city.id);
    }
  }

  Future<void> updateCity(CityProfile city) async {
    int index = _savedCities.indexWhere((c) => c.id == city.id);
    if (index != -1) {
      _savedCities[index] = city;
      await _saveCities();
      if (_activeCity?.id == city.id) {
        _activeCity = city; // Update active ref
        scheduleNotifications();
      }
    }
  }

  Future<void> removeCity(String id) async {
    _savedCities.removeWhere((c) => c.id == id);
    await _saveCities();
    if (_activeCity?.id == id) {
      _activeCity = null; // Reset to GPS
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyActiveCityId);
      scheduleNotifications();
    }
  }

  Future<void> setActiveCity(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      _activeCity = null;
      await prefs.remove(keyActiveCityId);
    } else {
      try {
        _activeCity = _savedCities.firstWhere((c) => c.id == id);
        await prefs.setString(keyActiveCityId, id);
      } catch (e) {
        _activeCity = null;
      }
    }
    scheduleNotifications();
  }

  Future<void> _loadCities(SharedPreferences prefs) async {
    String? jsonStr = prefs.getString(keySavedCities);
    if (jsonStr != null) {
      try {
        List<dynamic> list = jsonDecode(jsonStr);
        _savedCities = list.map((e) => CityProfile.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error getting location: $e');
      }
    }
  }

  Future<void> _saveCities() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonStr = jsonEncode(_savedCities.map((e) => e.toJson()).toList());
    await prefs.setString(keySavedCities, jsonStr);
  }

  Future<void> _loadActiveCity(SharedPreferences prefs) async {
    String? id = prefs.getString(keyActiveCityId);
    if (id != null) {
      try {
        _activeCity = _savedCities.firstWhere((c) => c.id == id);
      } catch (e) {
        // id might not exist anymore
        await prefs.remove(keyActiveCityId);
      }
    }
  }

  // --- Extended Bilal-Style Logic ---

  /// Returns a full list of prayer times including extra calculated times.
  /// If [date] is provided, calculates for that specific day.
  /// If [date] is null, calculates for Today (and handles night logic across to tomorrow).
  Future<List<ExtendedPrayer>> getExtendedPrayers({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final DateComponents targetDateComps = DateComponents(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    if (_coordinates == null) return [];

    final params = _method.getParameters();
    params.madhab = _madhab;

    // Apply Adjustments to Params
    params.adjustments.fajr = _adjustments['Fajr'] ?? 0;
    params.adjustments.sunrise = _adjustments['Sunrise'] ?? 0;
    params.adjustments.dhuhr = _adjustments['Dhuhr'] ?? 0;
    params.adjustments.asr = _adjustments['Asr'] ?? 0;
    params.adjustments.maghrib = _adjustments['Maghrib'] ?? 0;
    params.adjustments.isha = _adjustments['Isha'] ?? 0;

    final times = PrayerTimes(_coordinates!, targetDateComps, params);

    // For Night Calculations (Thirds/Midnight), we need Maghrib of Target Date and Fajr of Next Day.

    final nextDay = targetDate.add(const Duration(days: 1));
    final nextDayComps = DateComponents(
      nextDay.year,
      nextDay.month,
      nextDay.day,
    );
    final nextDayTimes = PrayerTimes(_coordinates!, nextDayComps, params);

    // Determine basic times
    DateTime fajr = _applyOffset(times.fajr, 'Fajr');
    DateTime sunrise = _applyOffset(times.sunrise, 'Sunrise');
    DateTime dhuhr = _applyOffset(times.dhuhr, 'Dhuhr');
    DateTime asr = _applyOffset(times.asr, 'Asr');
    DateTime maghrib = _applyOffset(times.maghrib, 'Maghrib');

    // Isha Calculation
    DateTime isha;
    if (_ramadanIshaDelayMode > 0) {
      // Fixed Delay mode
      isha = maghrib.add(Duration(minutes: _ramadanIshaDelayMode));
      // Apply offset too? User said "Set Isha = Maghrib + 90". Usually fixed time overrides calc.
      // But maybe manual offset should still apply?
      // "Update PrayerService to apply this override ONLY if 'Ramadan Mode' is active."
      // Let's assume manual offset effectively becomes 0 or applies on top.
      // Prudent to apply manual offset ON TOP of the fixed delay if user wants fine tuning.
      isha = _applyOffset(isha, 'Isha');
    } else {
      isha = _applyOffset(times.isha, 'Isha');
    }

    // Extras
    DateTime duha = sunrise.add(
      const Duration(minutes: 20),
    ); // Fixed 20 min after Shurooq

    // Night Calculations
    // Night is from Maghrib (Target Date) to Fajr (Next Day)
    DateTime nextFajr = _applyOffset(nextDayTimes.fajr, 'Fajr');

    // If nextFajr is weirdly before Maghrib (shouldn't happen with correct date add), fix it.
    if (nextFajr.isBefore(maghrib)) {
      nextFajr = nextFajr.add(const Duration(days: 1));
    }

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
      ExtendedPrayer(
        id: 'duha',
        name: 'الضحى',
        time: duha,
        prayer: null,
      ), // No standard Prayer enum
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
      // ExtendedPrayer(id: 'witr', name: 'الوتر', time: witr, prayer: null), // Removed as requested
    ];
  }

  DateTime _applyOffset(DateTime original, String key) {
    int offset = _adjustments[key] ?? 0;
    return original.add(Duration(minutes: offset));
  }

  int get hijriOffset => _hijriOffset;
  bool get is24Hour => _is24Hour;

  Future<void> setHijriOffset(int offset) async {
    _hijriOffset = offset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyHijriOffset, offset);
    notifyListeners();
  }

  Future<void> setIs24Hour(bool value) async {
    _is24Hour = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIs24Hour, value);
    notifyListeners();
  }

  String formatTime(DateTime time) {
    if (_is24Hour) {
      return DateFormat('HH:mm').format(time);
    } else {
      return DateFormat.jm('ar').format(time);
    }
  }
}

// Helper Model
class ExtendedPrayer {
  final String id;
  final String name;
  final DateTime time;
  final Prayer? prayer; // Null for extras like Duha

  ExtendedPrayer({
    required this.id,
    required this.name,
    required this.time,
    this.prayer,
  });
}
