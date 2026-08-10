import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'prayer_alarms_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

const _gold = Color(0xFFD0A871);

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // ── General ──────────────────────────────────────────────────────────────
  String _qiyamMode = 'none';
  String _sunriseMode = 'sound';
  String _duhaModeNotif = 'none';
  bool _jumuah = false;
  String _duhaMode = 'start'; // 'start'|'mid'|'after_mins'|'before_dhuhr_mins'
  int _duhaCustomMins = 15;
  int _jumuaMinutesBefore = 60;

  // ── Quiet Hours ──
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);

  // Takbeerat specific quiet hours
  TimeOfDay _takbeeratQuietStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _takbeeratQuietEnd = const TimeOfDay(hour: 7, minute: 0);

  // ── General Reminders (Fasting, Kahf, etc.) ──────────────────────────────
  bool _fastingMonday = true;
  bool _fastingThursday = true;
  bool _fastingWhiteDays = true;
  bool _kahfSalawat = true;

  // ── Pre-Prayer Alerts ─────────────────────────────────────────────────────
  final Map<String, bool> _fardEnabled = {
    'Fajr': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };
  final Map<String, int> _fardMinutes = {
    'Fajr': 15,
    'Dhuhr': 15,
    'Asr': 15,
    'Maghrib': 15,
    'Isha': 15,
  };

  // ── Prayer Notification Modes (sound / silent_notif / none) ─────────────
  final Map<String, String> _adhanMode = {
    'Fajr': 'sound',
    'Dhuhr': 'sound',
    'Asr': 'sound',
    'Maghrib': 'sound',
    'Isha': 'sound',
  };
  final Map<String, String> _iqamaMode = {
    'Fajr': 'none',
    'Dhuhr': 'none',
    'Asr': 'none',
    'Maghrib': 'none',
    'Isha': 'none',
  };
  final Map<String, String> _preMode = {
    'Fajr': 'none',
    'Dhuhr': 'none',
    'Asr': 'none',
    'Maghrib': 'none',
    'Isha': 'none',
  };
  final Map<String, int> _iqamaMinutes = {
    'Fajr': 15,
    'Dhuhr': 15,
    'Asr': 15,
    'Maghrib': 15,
    'Isha': 15,
  };

  // ── Dhul-Hijja ─────────────────────────────────────────────────────────────
  bool _takbeerat = false;
  int _takbeeratIntervalHours = 1;
  int _takbeeratOffset = 0;
  bool _arafah = false;
  bool _eidDhulHijjah = false;
  int _eidAdhaMinutesAfterSunrise = 30;

  // ── Ramadan / Eid ─────────────────────────────────────────────────────────
  bool _iftar = false;
  bool _suhoor = false;
  bool _eidFitr = false;
  bool _eidFitrTakbeer = false;
  String _iftarMode = 'ramadan';
  String _suhoorMode = 'ramadan';
  int _iftarMinutesBefore = 30;
  int _suhoorMinutesBefore = 60;
  int _iftarDays = 0x7F; // All 7 days bitmask (bits 0-6 = Mon-Sun)
  int _suhoorDays = 0x7F;
  int _eidFitrTakbeerInterval = 15;
  int _eidFitrMinutesAfterSunrise = 30;
  TimeOfDay? _eidFitrTime;
  TimeOfDay? _eidAdhaTime;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkNotificationPermission();
  }

  /// Shows an optional dialog if notification permission is missing.
  /// Called on screen open and when user tries to enable an alarm.
  Future<void> _checkNotificationPermission({bool onToggle = false}) async {
    final status = await Permission.notification.status;
    if (status.isGranted) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text(
          "تفعيل الإشعارات",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD0A871),
          ),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          onToggle
              ? "لن تصلك هذه التنبيهات بدون إذن الإشعارات.\nهل تريد تفعيله الآن؟"
              : "المنبهات لن تعمل بدون إذن الإشعارات.\nهل تريد تفعيله الآن؟",
          style: const TextStyle(fontFamily: AppConsts.expoArabic),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "لا، شكراً",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await Permission.notification.request();
              if (!mounted) return;
              if (result.isPermanentlyDenied) {
                await openAppSettings();
              }
            },
            child: const Text(
              "تفعيل",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: Color(0xFFD0A871),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPrefs() async {
    _prefs = CacheHelper.prefs;
    setState(() {
      _qiyamMode =
          _prefs.getString('qiyam_mode_notif') ??
          ((_prefs.getBool('notif_qiyam') ?? true) ? 'sound' : 'none');
      _sunriseMode =
          _prefs.getString('sunrise_mode') ??
          ((_prefs.getBool('notif_sunrise') ?? true) ? 'sound' : 'none');
      _duhaModeNotif =
          _prefs.getString('duha_mode_notif') ??
          ((_prefs.getBool('notif_duha') ?? false) ? 'sound' : 'none');
      _jumuah = _prefs.getBool('notif_jumua') ?? false;
      _duhaMode = _prefs.getString('duha_mode') ?? 'start';
      _duhaCustomMins = _prefs.getInt('duha_custom_minutes') ?? 15;
      _jumuaMinutesBefore = _prefs.getInt('jumua_minutes_before') ?? 60;

      // ── General Reminders ──
      _fastingMonday = _prefs.getBool('notif_fasting_monday') ?? true;
      _fastingThursday = _prefs.getBool('notif_fasting_thursday') ?? true;
      _fastingWhiteDays = _prefs.getBool('notif_fasting_white_days') ?? true;
      _kahfSalawat = _prefs.getBool('notif_kahf_salawat') ?? true;

      final qhStartHour = _prefs.getInt('quiet_hours_start_hour') ?? 23;
      final qhStartMin = _prefs.getInt('quiet_hours_start_minute') ?? 0;
      _quietHoursStart = TimeOfDay(hour: qhStartHour, minute: qhStartMin);

      final qhEndHour = _prefs.getInt('quiet_hours_end_hour') ?? 7;
      final qhEndMin = _prefs.getInt('quiet_hours_end_minute') ?? 0;
      _quietHoursEnd = TimeOfDay(hour: qhEndHour, minute: qhEndMin);

      // Takbeerat quiet hours
      final tqhStartHour =
          _prefs.getInt('takbeerat_quiet_hours_start_hour') ?? 23;
      final tqhStartMin =
          _prefs.getInt('takbeerat_quiet_hours_start_minute') ?? 0;
      _takbeeratQuietStart = TimeOfDay(hour: tqhStartHour, minute: tqhStartMin);

      final tqhEndHour = _prefs.getInt('takbeerat_quiet_hours_end_hour') ?? 7;
      final tqhEndMin = _prefs.getInt('takbeerat_quiet_hours_end_minute') ?? 0;
      _takbeeratQuietEnd = TimeOfDay(hour: tqhEndHour, minute: tqhEndMin);

      for (var key in _fardEnabled.keys) {
        final lower = key.toLowerCase();
        _adhanMode[key] =
            _prefs.getString('adhan_mode_$key') ??
            ((_prefs.getBool('notif_prayer_$lower') ?? true)
                ? 'sound'
                : 'none');
        _preMode[key] =
            _prefs.getString('pre_mode_$key') ??
            ((_prefs.getBool('notif_pre_$key') ?? false) ? 'sound' : 'none');
        _iqamaMode[key] =
            _prefs.getString('iqama_mode_$key') ??
            ((_prefs.getBool('iqama_enabled_$key') ?? false)
                ? 'sound'
                : 'none');
        _fardEnabled[key] = _prefs.getBool('notif_pre_$key') ?? false;
        _fardMinutes[key] = _prefs.getInt('time_pre_$key') ?? 15;
        _iqamaMinutes[key] = _prefs.getInt('iqama_minutes_$key') ?? 15;
      }

      // Dhul-Hijja
      _takbeerat = _prefs.getBool('notif_takbeerat') ?? false;
      _takbeeratIntervalHours = _prefs.getInt('takbeerat_interval_hours') ?? 1;
      _takbeeratOffset = _prefs.getInt('takbeerat_offset') ?? 0;
      _arafah = _prefs.getBool('notif_arafah') ?? false;
      _eidDhulHijjah = _prefs.getBool('notif_eid_dhulhijjah') ?? false;
      _eidAdhaMinutesAfterSunrise =
          _prefs.getInt('eid_adha_minutes_after_sunrise') ?? 30;

      // Ramadan / Eid
      _iftar = _prefs.getBool('iftar_alarm') ?? false;
      _suhoor = _prefs.getBool('suhoor_alarm') ?? false;
      _eidFitr = _prefs.getBool('eid_fitr_alarm') ?? false;
      _eidFitrTakbeer = _prefs.getBool('eid_fitr_takbeer') ?? false;
      _iftarMode = _prefs.getString('iftar_mode') ?? 'ramadan';
      _suhoorMode = _prefs.getString('suhoor_mode') ?? 'ramadan';
      _iftarMinutesBefore = _prefs.getInt('iftar_minutes_before') ?? 30;
      _suhoorMinutesBefore = _prefs.getInt('suhoor_minutes_before') ?? 60;
      _iftarDays = _prefs.getInt('iftar_all_year_days') ?? 0x7F;
      _suhoorDays = _prefs.getInt('suhoor_all_year_days') ?? 0x7F;
      _eidFitrTakbeerInterval =
          _prefs.getInt('eid_fitr_takbeer_interval') ?? 15;
      _eidFitrMinutesAfterSunrise =
          _prefs.getInt('eid_prayer_minutes_after_sunrise') ?? 30;

      final fitrHour = _prefs.getInt('eid_fitr_hour');
      final fitrMin = _prefs.getInt('eid_fitr_minute');
      if (fitrHour != null && fitrMin != null) {
        _eidFitrTime = TimeOfDay(hour: fitrHour, minute: fitrMin);
      }

      final adhaHour = _prefs.getInt('eid_adha_hour');
      final adhaMin = _prefs.getInt('eid_adha_minute');
      if (adhaHour != null && adhaMin != null) {
        _eidAdhaTime = TimeOfDay(hour: adhaHour, minute: adhaMin);
      }

      _isLoading = false;
    });
  }

  Future<void> _pickEidTime(bool isAdha) async {
    final initialTime =
        (isAdha ? _eidAdhaTime : _eidFitrTime) ??
        const TimeOfDay(hour: 6, minute: 30);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _gold,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isAdha) {
          _eidAdhaTime = picked;
        } else {
          _eidFitrTime = picked;
        }
      });
      final prefix = isAdha ? 'eid_adha' : 'eid_fitr';
      await _prefs.setInt('${prefix}_hour', picked.hour);
      await _prefs.setInt('${prefix}_minute', picked.minute);
      PrayerService().scheduleNotificationsDebounced();
    }
  }

  Future<void> _pickQuietTime(bool isStart) async {
    final initialTime = isStart ? _quietHoursStart : _quietHoursEnd;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _gold,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietHoursStart = picked;
        } else {
          _quietHoursEnd = picked;
        }
      });
      final prefix = isStart ? 'quiet_hours_start' : 'quiet_hours_end';
      await _prefs.setInt('${prefix}_hour', picked.hour);
      await _prefs.setInt('${prefix}_minute', picked.minute);
      PrayerService().scheduleNotificationsDebounced();
    }
  }

  Future<void> _pickTakbeeratQuietTime(bool isStart) async {
    final initialTime = isStart ? _takbeeratQuietStart : _takbeeratQuietEnd;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _gold,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _takbeeratQuietStart = picked;
        } else {
          _takbeeratQuietEnd = picked;
        }
      });
      final prefix = isStart
          ? 'takbeerat_quiet_hours_start'
          : 'takbeerat_quiet_hours_end';
      await _prefs.setInt('${prefix}_hour', picked.hour);
      await _prefs.setInt('${prefix}_minute', picked.minute);
      PrayerService().scheduleNotificationsDebounced();
    }
  }

  Future<void> _save(String key, dynamic val) async {
    if (val is bool) await _prefs.setBool(key, val);
    if (val is int) await _prefs.setInt(key, val);
    if (val is String) await _prefs.setString(key, val);
    // If user is enabling an alarm (bool true), check notification permission
    if (val is bool && val == true) {
      await _checkNotificationPermission(onToggle: true);
    }
    PrayerService().scheduleNotificationsDebounced();
  }

  Future<void> _saveMode(String key, String legacyKey, String val) async {
    await _prefs.setString(key, val);
    await _prefs.setBool(legacyKey, val != 'none');
    if (val != 'none') {
      await _checkNotificationPermission(onToggle: true);
    }
    PrayerService().scheduleNotificationsDebounced();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          itemCount: 6,
          itemBuilder: (_, __) => AppSkeleton.card(height: 80.h),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "المنبهات",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: _gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _gold),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // ── Per-prayer notification controls ────────────────────────────
          Container(
            margin: EdgeInsets.only(bottom: 20.h),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrayerAlarmsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
              child: Text(
                'ضبط إشعارات الصلوات',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ── General ──────────────────────────────────────────────────────
          _sectionHeader("تنبيهات عامة"),
          _expandableCard(
            icon: Icons.nightlight_outlined,
            title: 'القيام',
            subtitle: 'الثلث الأخير من الليل',
            value: _qiyamMode != 'none',
            onToggle: (v) {
              final newMode = v ? 'sound' : 'none';
              setState(() => _qiyamMode = newMode);
              _saveMode('qiyam_mode_notif', 'notif_qiyam', newMode);
            },
            expanded: _qiyamMode != 'none',
            child: Row(
              children: [
                Text(
                  "وضعية التنبيه: ",
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    fontSize: 13.sp,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                _modeToggle(_qiyamMode, (v) {
                  setState(() => _qiyamMode = v);
                  _saveMode('qiyam_mode_notif', 'notif_qiyam', v);
                }),
              ],
            ),
          ),
          _expandableCard(
            icon: Icons.wb_sunny_outlined,
            title: 'الشروق',
            subtitle: 'عند وقت الشروق',
            value: _sunriseMode != 'none',
            onToggle: (v) {
              final newMode = v ? 'sound' : 'none';
              setState(() => _sunriseMode = newMode);
              _saveMode('sunrise_mode', 'notif_sunrise', newMode);
            },
            expanded: _sunriseMode != 'none',
            child: Row(
              children: [
                Text(
                  "وضعية التنبيه: ",
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    fontSize: 13.sp,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                _modeToggle(_sunriseMode, (v) {
                  setState(() => _sunriseMode = v);
                  _saveMode('sunrise_mode', 'notif_sunrise', v);
                }),
              ],
            ),
          ),

          // Duha — custom
          _expandableCard(
            icon: Icons.wb_twilight_outlined,
            title: 'الضحى',
            subtitle: _duhaSubtitle(),
            value: _duhaModeNotif != 'none',
            onToggle: (v) {
              final newMode = v ? 'sound' : 'none';
              setState(() => _duhaModeNotif = newMode);
              _saveMode('duha_mode_notif', 'notif_duha', newMode);
            },
            expanded: _duhaModeNotif != 'none',
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      "وضعية التنبيه: ",
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 13.sp,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    _modeToggle(_duhaModeNotif, (v) {
                      setState(() => _duhaModeNotif = v);
                      _saveMode('duha_mode_notif', 'notif_duha', v);
                    }),
                  ],
                ),
                Divider(height: 20.h),
                _buildDuhaOptions(),
              ],
            ),
          ),

          // Jumuah — custom minutes before
          _expandableCard(
            icon: Icons.mosque_outlined,
            title: 'الجمعة',
            subtitle: 'قبل أذان الجمعة بـ $_jumuaMinutesBefore دقيقة',
            value: _jumuah,
            onToggle: (v) {
              setState(() => _jumuah = v);
              _save('notif_jumua', v);
            },
            expanded: _jumuah,
            child: Column(
              children: [
                _minutesPicker(
                  label: 'الدقائق قبل الأذان',
                  value: _jumuaMinutesBefore,
                  min: 15,
                  max: 120,
                  step: 15,
                  onChanged: (v) {
                    setState(() => _jumuaMinutesBefore = v);
                    _save('jumua_minutes_before', v);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // ── Additional Reminders ──
          _sectionHeader("تذكيرات إضافية"),
          _switchTile(
            icon: Icons.calendar_today_outlined,
            title: 'صيام الاثنين والخميس',
            subtitle: 'تذكير ليلة الاثنين وليلة الخميس',
            value: _fastingMonday && _fastingThursday,
            onChanged: (v) {
              setState(() {
                _fastingMonday = v;
                _fastingThursday = v;
              });
              _save('notif_fasting_monday', v);
              _save('notif_fasting_thursday', v);
            },
          ),
          _switchTile(
            icon: Icons.wb_sunny_outlined,
            title: 'صيام الأيام البيض',
            subtitle: 'تذكير ليلة 13 و14 و15 من الشهر الهجري',
            value: _fastingWhiteDays,
            onChanged: (v) {
              setState(() => _fastingWhiteDays = v);
              _save('notif_fasting_white_days', v);
            },
          ),
          _switchTile(
            icon: Icons.menu_book_outlined,
            title: 'ليلة الجمعة (الكهف والصلاة على النبي)',
            subtitle: 'تذكير بقراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ',
            value: _kahfSalawat,
            onChanged: (v) {
              setState(() => _kahfSalawat = v);
              _save('notif_kahf_salawat', v);
            },
          ),

          SizedBox(height: 10.h),

          // Quiet Hours for Salawat
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.grey.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bedtime_outlined, color: _gold, size: 20.sp),
                    SizedBox(width: 8.w),
                    const Text(
                      'ساعات الهدوء للصلوات على النبي',
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _quietTimePicker(
                      'من',
                      _quietHoursStart,
                      () => _pickQuietTime(true),
                    ),
                    _quietTimePicker(
                      'إلى',
                      _quietHoursEnd,
                      () => _pickQuietTime(false),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Center(
                  child: Text(
                    'سيتم تخطي تنبيهات الصلاة على النبي في هذا الوقت',
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 10.sp,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // ── Dhul-Hijja ────────────────────────────────────────────────────
          _sectionHeader("تنبيهات ذو الحجة"),
          _expandableCard(
            icon: Icons.campaign_outlined,
            title: 'تكبيرات العشر',
            subtitle: _takbeeratIntervalHours >= 60
                ? 'كل ${_takbeeratIntervalHours ~/ 60} ${_takbeeratIntervalHours ~/ 60 == 1 ? 'ساعة' : 'ساعات'}${_takbeeratOffset > 0 ? ' و $_takbeeratOffset دق' : ''}'
                : 'كل $_takbeeratIntervalHours دقيقة${_takbeeratOffset > 0 ? ' و $_takbeeratOffset دق' : ''}',
            value: _takbeerat,
            onToggle: (v) {
              setState(() => _takbeerat = v);
              _save('notif_takbeerat', v);
            },
            expanded: _takbeerat,
            child: Column(
              children: [
                _intervalChips(
                  label: 'فترة التكرار',
                  options: const [2, 5, 10, 15, 30, 60, 120, 180, 240],
                  labels: const [
                    'دقيقتين',
                    '5 دق',
                    '10 دق',
                    '15 دق',
                    '30 دق',
                    'ساعة',
                    'ساعتين',
                    '3 ساعات',
                    '4 ساعات',
                  ],
                  value: _takbeeratIntervalHours,
                  onChanged: (v) {
                    setState(() => _takbeeratIntervalHours = v);
                    _save('takbeerat_interval_hours', v);
                  },
                ),
                SizedBox(height: 16.h),
                _minutesPicker(
                  label: 'إزاحة الوقت (دقائق)',
                  value: _takbeeratOffset,
                  min: 0,
                  max: 5,
                  step: 1,
                  onChanged: (v) {
                    setState(() => _takbeeratOffset = v);
                    _save('takbeerat_offset', v);
                  },
                ),
                const Divider(height: 24),
                const Text(
                  'ساعات الهدوء للتكبيرات',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _quietTimePicker(
                      'من',
                      _takbeeratQuietStart,
                      () => _pickTakbeeratQuietTime(true),
                    ),
                    _quietTimePicker(
                      'إلى',
                      _takbeeratQuietEnd,
                      () => _pickTakbeeratQuietTime(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _switchTile(
            icon: Icons.landscape, // Mountain icon for Arafah
            title: 'يوم عرفة',
            subtitle:
                'تنبيه السحور ($_suhoorMinutesBefore دق قبل الفجر) والإفطار ($_iftarMinutesBefore دق قبل المغرب)',
            value: _arafah,
            onChanged: (v) {
              setState(() => _arafah = v);
              _save('notif_arafah', v);
            },
          ),
          _expandableCard(
            icon: Icons.celebration, // Celebration icon matching Fitr
            title: 'عيد الأضحى',
            subtitle: _eidAdhaTime != null
                ? 'وقت التنبيه: ${_eidAdhaTime!.format(context)}'
                : '$_eidAdhaMinutesAfterSunrise دقيقة بعد الشروق',
            value: _eidDhulHijjah,
            onToggle: (v) {
              setState(() => _eidDhulHijjah = v);
              _save('notif_eid_dhulhijjah', v);
            },
            expanded: _eidDhulHijjah,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: _gold),
                  title: const Text(
                    'تحديد وقت صلاة العيد',
                    style: TextStyle(fontFamily: AppConsts.cairo),
                  ),
                  trailing: Text(
                    _eidAdhaTime?.format(context) ?? 'اختر الوقت',
                    style: const TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                    ),
                  ),
                  onTap: () => _pickEidTime(true),
                ),
                if (_eidAdhaTime == null)
                  _minutesPicker(
                    label: 'أو الدقائق بعد الشروق',
                    value: _eidAdhaMinutesAfterSunrise,
                    min: 10,
                    max: 90,
                    step: 10,
                    onChanged: (v) {
                      setState(() => _eidAdhaMinutesAfterSunrise = v);
                      _save('eid_adha_minutes_after_sunrise', v);
                    },
                  ),
                if (_eidAdhaTime != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _eidAdhaTime = null);
                      _prefs.remove('eid_adha_hour');
                      _prefs.remove('eid_adha_minute');
                      PrayerService().scheduleNotificationsDebounced();
                    },
                    child: const Text(
                      'العودة للحساب التلقائي (حسب الشروق)',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // ── Ramadan / Eid ─────────────────────────────────────────────────
          _sectionHeader("تنبيهات رمضان وعيد الفطر"),
          _buildIftarSuhoorCard(
            title: 'منبه الإفطار',
            icon: Icons.dinner_dining_outlined,
            alarmKey: 'iftar_alarm',
            modeKey: 'iftar_mode',
            minutesKey: 'iftar_minutes_before',
            daysKey: 'iftar_all_year_days',
            isOn: _iftar,
            mode: _iftarMode,
            minutes: _iftarMinutesBefore,
            days: _iftarDays,
            prayer: 'المغرب',
            onToggle: (v) {
              setState(() => _iftar = v);
              _save('iftar_alarm', v);
            },
            onMode: (v) {
              setState(() => _iftarMode = v);
              _save('iftar_mode', v);
            },
            onMinutes: (v) {
              setState(() => _iftarMinutesBefore = v);
              _save('iftar_minutes_before', v);
            },
            onDays: (v) {
              setState(() => _iftarDays = v);
              _save('iftar_all_year_days', v);
            },
          ),
          SizedBox(height: 10.h),
          _buildIftarSuhoorCard(
            title: 'منبه السحور',
            icon: Icons.restaurant_outlined,
            alarmKey: 'suhoor_alarm',
            modeKey: 'suhoor_mode',
            minutesKey: 'suhoor_minutes_before',
            daysKey: 'suhoor_all_year_days',
            isOn: _suhoor,
            mode: _suhoorMode,
            minutes: _suhoorMinutesBefore,
            days: _suhoorDays,
            prayer: 'الفجر',
            onToggle: (v) {
              setState(() => _suhoor = v);
              _save('suhoor_alarm', v);
            },
            onMode: (v) {
              setState(() => _suhoorMode = v);
              _save('suhoor_mode', v);
            },
            onMinutes: (v) {
              setState(() => _suhoorMinutesBefore = v);
              _save('suhoor_minutes_before', v);
            },
            onDays: (v) {
              setState(() => _suhoorDays = v);
              _save('suhoor_all_year_days', v);
            },
          ),
          SizedBox(height: 10.h),
          _expandableCard(
            icon: Icons.celebration_outlined,
            title: 'منبه عيد الفطر',
            subtitle: _eidFitrTime != null
                ? 'وقت التنبيه: ${_eidFitrTime!.format(context)}'
                : '$_eidFitrMinutesAfterSunrise دقيقة بعد الشروق',
            value: _eidFitr,
            onToggle: (v) {
              setState(() => _eidFitr = v);
              _save('eid_fitr_alarm', v);
            },
            expanded: _eidFitr,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: _gold),
                  title: const Text(
                    'تحديد وقت صلاة العيد',
                    style: TextStyle(fontFamily: AppConsts.cairo),
                  ),
                  trailing: Text(
                    _eidFitrTime?.format(context) ?? 'اختر الوقت',
                    style: const TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                    ),
                  ),
                  onTap: () => _pickEidTime(false),
                ),
                if (_eidFitrTime == null)
                  _minutesPicker(
                    label: 'أو الدقائق بعد الشروق',
                    value: _eidFitrMinutesAfterSunrise,
                    min: 10,
                    max: 90,
                    step: 10,
                    onChanged: (v) {
                      setState(() => _eidFitrMinutesAfterSunrise = v);
                      _save('eid_prayer_minutes_after_sunrise', v);
                    },
                  ),
                if (_eidFitrTime != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _eidFitrTime = null);
                      _prefs.remove('eid_fitr_hour');
                      _prefs.remove('eid_fitr_minute');
                      PrayerService().scheduleNotificationsDebounced();
                    },
                    child: const Text(
                      'العودة للحساب التلقائي (حسب الشروق)',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          _expandableCard(
            icon: Icons.graphic_eq_outlined,
            title: 'تكبيرات عيد الفطر',
            subtitle:
                'تكبير كل $_eidFitrTakbeerInterval دقيقة ابتداءً من ليلة العيد',
            value: _eidFitrTakbeer,
            onToggle: (v) {
              setState(() => _eidFitrTakbeer = v);
              _save('eid_fitr_takbeer', v);
            },
            expanded: _eidFitrTakbeer,
            child: _intervalChips(
              label: 'فترة التكرار',
              options: const [2, 5, 10, 15, 20, 30],
              labels: const ['دقيقتين', '5 دق', '10 دق', '15 دق', '20 دق', '30 دق'],
              value: _eidFitrTakbeerInterval,
              onChanged: (v) {
                setState(() => _eidFitrTakbeerInterval = v);
                _save('eid_fitr_takbeer_interval', v);
              },
            ),
          ),

          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  // ─── Section Header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, top: 4.h),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: _gold,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 3-button row: 🔔 sound | 🔕 silent_notif | ✖ none
  Widget _modeToggle(String current, ValueChanged<String> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modeBtn(
          Icons.volume_up,
          'sound',
          current,
          const Color(0xFFD0A871),
          onChanged,
        ),
        _modeBtn(
          Icons.notifications_outlined,
          'silent_notif',
          current,
          Colors.blueGrey,
          onChanged,
        ),
        _modeBtn(
          Icons.block_outlined,
          'none',
          current,
          Colors.red.shade300,
          onChanged,
        ),
      ],
    );
  }

  Widget _modeBtn(
    IconData icon,
    String value,
    String current,
    Color activeColor,
    ValueChanged<String> onChanged,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? activeColor : Colors.grey.withAlpha(70),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 13,
          color: selected ? Colors.white : Colors.grey,
        ),
      ),
    );
  }

  // ─── Simple Switch Tile ──────────────────────────────────────────────────────
  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: _gold, size: 22.sp),
        activeThumbColor: _gold,
        activeTrackColor: _gold.withAlpha(80),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: isDark ? Colors.black26 : Colors.grey.shade300,
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.grey,
            fontSize: 12.sp,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // ─── Expandable Card ─────────────────────────────────────────────────────────
  Widget _expandableCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onToggle,
    required bool expanded,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(icon, color: _gold, size: 22.sp),
            activeThumbColor: _gold,
            activeTrackColor: _gold.withAlpha(80),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: isDark ? Colors.black26 : Colors.grey.shade300,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                color: Colors.grey,
                fontSize: 12.sp,
              ),
            ),
            value: value,
            onChanged: onToggle,
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 14.h),
              child: child,
            ),
        ],
      ),
    );
  }

  // ─── Iftar / Suhoor Card ─────────────────────────────────────────────────────
  Widget _buildIftarSuhoorCard({
    required String title,
    required IconData icon,
    required String alarmKey,
    required String modeKey,
    required String minutesKey,
    required String daysKey,
    required bool isOn,
    required String mode,
    required int minutes,
    required int days,
    required String prayer,
    required ValueChanged<bool> onToggle,
    required ValueChanged<String> onMode,
    required ValueChanged<int> onMinutes,
    required ValueChanged<int> onDays,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            secondary: Icon(icon, color: _gold, size: 22.sp),
            activeThumbColor: _gold,
            activeTrackColor: _gold.withAlpha(80),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: isDark ? Colors.black26 : Colors.grey.shade300,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            subtitle: Text(
              '$minutes دقيقة قبل $prayer',
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                color: Colors.grey,
                fontSize: 12.sp,
              ),
            ),
            value: isOn,
            onChanged: onToggle,
          ),
          if (isOn) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Minutes picker
                  _minutesPicker(
                    label: 'الدقائق قبل $prayer',
                    value: minutes,
                    min: 1,
                    max: 120,
                    step: 1,
                    onChanged: onMinutes,
                  ),
                  SizedBox(height: 12.h),
                  // Mode selector
                  Text(
                    'متى يُشغَّل؟',
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      color: textColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _gold.withAlpha(220),
                      selectedForegroundColor: Colors.white,
                      foregroundColor: textColor,
                      textStyle: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 12.sp,
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 'ramadan',
                        label: Text('رمضان فقط'),
                        icon: Icon(Icons.nights_stay, size: 14),
                      ),
                      ButtonSegment(
                        value: 'all_year',
                        label: Text('طوال العام'),
                        icon: Icon(Icons.calendar_month, size: 14),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => onMode(s.first),
                  ),
                  // Days selector only if all_year
                  if (mode == 'all_year') ...[
                    SizedBox(height: 12.h),
                    Text(
                      'أيام الأسبوع',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        color: textColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _daysBitmaskPicker(days: days, onChanged: onDays),
                  ],
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Days bitmask picker ─────────────────────────────────────────────────────
  Widget _daysBitmaskPicker({
    required int days,
    required ValueChanged<int> onChanged,
  }) {
    const dayNames = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    const dayLabels = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return Wrap(
      spacing: 8.w,
      children: List.generate(7, (i) {
        final bit = 1 << i;
        final selected = (days & bit) != 0;
        return Tooltip(
          message: dayLabels[i],
          child: GestureDetector(
            onTap: () {
              final newDays = selected ? (days & ~bit) : (days | bit);
              onChanged(newDays);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38.w,
              height: 38.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _gold : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _gold : Colors.grey.withAlpha(100),
                ),
              ),
              child: Text(
                dayNames[i],
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  color: selected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Minutes Picker ──────────────────────────────────────────────────────────
  Widget _minutesPicker({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $value دقيقة',
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.grey,
            fontSize: 12.sp,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: _gold, size: 24.sp),
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _gold,
                  thumbColor: _gold,
                  inactiveTrackColor: _gold.withAlpha(60),
                  overlayColor: _gold.withAlpha(30),
                ),
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min) ~/ step,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: _gold, size: 24.sp),
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ─── Interval Chips ──────────────────────────────────────────────────────────
  Widget _intervalChips({
    required String label,
    required List<int> options,
    required List<String> labels,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.grey,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: List.generate(options.length, (i) {
            final selected = value == options[i];
            return GestureDetector(
              onTap: () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 8.h,
                ),
                decoration: BoxDecoration(
                  color: selected ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: selected ? _gold : Colors.grey.withAlpha(100),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    color: selected ? Colors.white : Colors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─── Duha Options ──────────────────────────────────────────────────────────
  Widget _buildDuhaOptions() {
    return RadioGroup<String>(
      groupValue: _duhaMode,
      onChanged: (v) {
        if (v != null) {
          setState(() => _duhaMode = v);
          _save('duha_mode', v);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _duhaOptionTile(
            'start',
            'عند بداية وقت الضحى',
            'بعد الشروق بـ 15 دقيقة',
          ),
          _duhaOptionTile(
            'mid',
            'في منتصف وقت الضحى',
            'منتصف ما بين الشروق والظهر',
          ),
          _duhaOptionTile(
            'after_mins',
            'بعد الشروق بـ $_duhaCustomMins دقيقة',
            'تحديد الدقائق يدوياً',
          ),
          _duhaOptionTile(
            'before_dhuhr_mins',
            'قبل الظهر بـ $_duhaCustomMins دقيقة',
            'تحديد الدقائق يدوياً',
          ),
          if (_duhaMode == 'after_mins' ||
              _duhaMode == 'before_dhuhr_mins') ...[
            SizedBox(height: 8.h),
            _minutesPicker(
              label: _duhaMode == 'after_mins'
                  ? 'الدقائق بعد الشروق'
                  : 'الدقائق قبل الظهر',
              value: _duhaCustomMins,
              min: 1,
              max: 120,
              step: 1,
              onChanged: (v) {
                setState(() => _duhaCustomMins = v);
                _save('duha_custom_minutes', v);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _duhaOptionTile(String mode, String title, String subtitle) {
    final selected = _duhaMode == mode;
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      activeColor: _gold,
      value: mode,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontSize: 13.sp,
          color: selected
              ? _gold
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontSize: 11.sp,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _duhaSubtitle() {
    switch (_duhaMode) {
      case 'start':
        return 'بعد الشروق بـ 15 دقيقة';
      case 'mid':
        return 'في منتصف وقت الضحى';
      case 'after_mins':
        return 'بعد الشروق بـ $_duhaCustomMins دقيقة';
      case 'before_dhuhr_mins':
        return 'قبل الظهر بـ $_duhaCustomMins دقيقة';
      default:
        return 'وقت الضحى';
    }
  }

  Widget _quietTimePicker(String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          Text(
            time.format(context),
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }
}
