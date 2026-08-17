import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'muezzin_selection_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class PrayerAlarmsScreen extends StatefulWidget {
  const PrayerAlarmsScreen({super.key});

  @override
  State<PrayerAlarmsScreen> createState() => _PrayerAlarmsScreenState();
}

class _PrayerAlarmsScreenState extends State<PrayerAlarmsScreen> {
  bool _isLoading = true;
  late SharedPreferences _prefs;
  static const Color _gold = Color(0xFFD0A871);

  final Map<String, bool> _fardEnabled = {
    'Fajr': false, 'Dhuhr': false, 'Jumuah': false, 'Asr': false, 'Maghrib': false, 'Isha': false,
  };
  final Map<String, int> _fardMinutes = {};
  final Map<String, int> _iqamaMinutes = {};
  final Map<String, String> _adhanMode = {};
  final Map<String, String> _preMode = {};
  final Map<String, String> _iqamaMode = {};
  final Map<String, int> _adjustments = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    PrayerService().scheduleNotifications(isUserAction: true);
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    _prefs = CacheHelper.prefs;
    setState(() {
      for (var key in _fardEnabled.keys) {
        final lower = key.toLowerCase();
        _adhanMode[key] = _prefs.getString('adhan_mode_$key') ??
            ((_prefs.getBool('notif_prayer_$lower') ?? true) ? 'sound' : 'none');
        _preMode[key] = _prefs.getString('pre_mode_$key') ??
            ((_prefs.getBool('notif_pre_$key') ?? false) ? 'sound' : 'none');
        _iqamaMode[key] = _prefs.getString('iqama_mode_$key') ??
            ((_prefs.getBool('iqama_enabled_$key') ?? false) ? 'sound' : 'none');
        _fardEnabled[key] = _prefs.getBool('notif_pre_$key') ?? false;
        _fardMinutes[key] = _prefs.getInt('time_pre_$key') ?? 15;
        _iqamaMinutes[key] = _prefs.getInt('iqama_minutes_$key') ?? 15;
        _adjustments[key] = _prefs.getInt('adjust_$key') ?? 0;
      }
      _isLoading = false;
    });
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("تفعيل الإشعارات", style: TextStyle(fontFamily: AppConsts.expoArabic, color: _gold), textDirection: TextDirection.rtl),
        content: const Text("لن تصلك هذه التنبيهات بدون إذن الإشعارات.\nهل تريد تفعيله الآن؟", style: TextStyle(fontFamily: AppConsts.expoArabic), textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("لا، شكراً", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await Permission.notification.request();
              if (result.isPermanentlyDenied) await openAppSettings();
            },
            child: const Text("تفعيل", style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePrayerMode(String modeKey, String legacyBoolKey, String value) async {
    await _prefs.setString(modeKey, value);
    await _prefs.setBool(legacyBoolKey, value != 'none');
    if (value != 'none') await _checkNotificationPermission();
    PrayerService().scheduleNotificationsDebounced();
  }

  Future<void> _openSoundPicker(String prefsKey, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MuezzinSelectionScreen(
          prefsKey: prefsKey,
          title: title,
        ),
      ),
    );
    setState(() {}); // Refresh to show new sound name
    PrayerService().scheduleNotificationsDebounced();
  }

  /// Maps a raw sound ID to a human-readable Arabic name for display.
  String _soundDisplayName(String id) {
    const Map<String, String> names = {
      // الأذان
      'nafis': 'أحمد النفيس',
      'mishary': 'مشاري العفاسي (1)',
      'mishary_2': 'مشاري العفاسي (2)',
      'abdulbasit': 'عبد الباسط (1)',
      'abdulbasit_2': 'عبد الباسط (2)',
      'abdulbasit_isha': 'عبد الباسط (العشاء)',
      'abdulbasit_cairo': 'عبد الباسط (القاهرة)',
      'rifat': 'محمد رفعت',
      'banna': 'محمود علي البنا',
      'mustafa_ismail': 'مصطفى إسماعيل',
      'shaisha': 'أبو العينين شعيشع',
      'hussary': 'محمود خليل الحصري',
      'minshawi': 'المنشاوي (1)',
      'minshawi_2': 'المنشاوي (2)',
      'naina_cairo': 'أحمد نعينع',
      'metwalli': 'السيد متولي',
      'nawaf': 'أحمد نواف',
      'mulla': 'علي ملا (مكة)',
      'raml': 'محمد رمل',
      'makkah_16': 'أذان مكة (16)',
      'makkah_19': 'أذان مكة (19)',
      'makkah_20': 'أذان مكة (20)',
      'makkah_3': 'أذان مكة (قديم 1)',
      'makkah_4': 'أذان مكة (قديم 2)',
      'bishi': 'مهدي البيشي',
      'saleh': 'عبد الرزاق صالح',
      'madinah': 'أذان المدينة',
      'madinah_18': 'أذان المدينة (18)',
      'madinah_2': 'أذان المدينة (2)',
      'surayhi': 'السريحي',
      'quds': 'أذان القدس',
      'aqsa_qazzaz': 'ناجي قزاز (1)',
      'aqsa_qazzaz_2': 'ناجي قزاز (2)',
      'turkey_1': 'تركيا (1)',
      'turkey_2': 'تركيا (2)',
      'duman': 'حسين إيرك (تركيا)',
      'syria': 'سوريا',
      'algeria': 'الجزائر',
      'tunisia': 'تونس',
      'kuwait_3': 'الكويت',
      'dubai': 'دبي',
      'oman': 'مسقط',
      'india': 'الهند',
      'pakistan': 'باكستان',
      'indonesia': 'إندونيسيا',
      'malaysia': 'ماليزيا',
      'brunei_1': 'بروني',
      'maldives': 'جزر المالديف',
      'rajhi': 'جامع الراجحي (1)',
      'rajhi_2': 'جامع الراجحي (2)',
      'halabiya': 'حمزة الحلبية',
      'emadi': 'أحمد العمادي',
      'taresh': 'زهير طارش',
      'ajman': 'عجمان',
      'georgia': 'جورجيا',
      'fajr_makkah': 'فجر مكة',
      'fajr_madinah': 'فجر المدينة',
      'fajr_egypt': 'فجر مصر',
      'fajr_quds': 'فجر القدس',
      'fajr_kuwait_1': 'فجر الكويت',
      'fajr_mishary_1': 'فجر مشاري (1)',
      'fajr_mishary_2': 'فجر مشاري (2)',
      'fajr_abdulbasit': 'فجر عبد الباسط',
      // قبل الأذان — الصوت المخصص لكل صلاة
      'pre_adhan': 'تنبيه عام قبل الأذان',
      'pre_fajr': 'تنبيه قبل الفجر',
      'pre_dhuhr': 'تنبيه قبل الظهر',
      'pre_asr': 'تنبيه قبل العصر',
      'pre_maghrib': 'تنبيه قبل المغرب',
      'pre_isha': 'تنبيه قبل العشاء',
      // الإقامة
      'iqama': 'الإقامة الافتراضية',
      'full_adhan_makkah': 'أذان مكة الكامل',
      'full_adhan_madina': 'أذان المدينة الكامل',
      'takbeer_makkah': 'تكبيرات مكة',
      'takbeer_madina': 'تكبيرات المدينة',
      // التكبيرات
      'eid_takbeerat': 'تكبيرات العيد',
      // الأذكار
      'sabah': 'أذكار الصباح',
      'masaa': 'أذكار المساء',
      'saly_3ala_mo7amad': 'صلاة على النبي ﷺ',
      // ساعات الليل
      'night_last': 'ثلث الليل الأخير',
      'night_first': 'ثلث الليل الأول',
      'night_mid': 'منتصف الليل',
      // نهار
      'time_duha': 'صلاة الضحى',
      'time_shurooq': 'الشروق',
      // رمضان
      'time_suhoor': 'تنبيه السحور',
      'pre_iftar': 'تنبيه الإفطار',
      // التطبيق
      'ibad_al_rahmann_tone': 'نغمة التطبيق الافتراضية',
      'default': 'نغمة النظام',
    };
    return '🎵 ${names[id] ?? id}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: 6,
          itemBuilder: (_, __) => AppSkeleton.card(height: 100.h),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إشعارات الصلوات", style: TextStyle(fontFamily: AppConsts.expoArabic, color: _gold, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _gold),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeLegend(Icons.volume_up, 'صوت', _gold),
                SizedBox(width: 14.w),
                _modeLegend(Icons.notifications_outlined, 'صامت', Colors.blueGrey),
                SizedBox(width: 14.w),
                _modeLegend(Icons.block_outlined, 'إيقاف', Colors.red.shade300),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          ..._buildPrayerCards(),
        ],
      ),
    );
  }

  List<Widget> _buildPrayerCards() {
    const prayers = [
      ('Fajr', 'الفجر', Icons.brightness_3_outlined),
      ('Dhuhr', 'الظهر', Icons.wb_sunny_outlined),
      ('Jumuah', 'الجمعة', Icons.group_outlined),
      ('Asr', 'العصر', Icons.brightness_5_outlined),
      ('Maghrib', 'المغرب', Icons.nights_stay_outlined),
      ('Isha', 'العشاء', Icons.dark_mode_outlined),
    ];
    return prayers.map((p) => _buildSinglePrayerCard(p.$1, p.$2, p.$3)).toList();
  }

  Widget _buildSinglePrayerCard(String key, String name, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final divColor = isDark ? Colors.white10 : Colors.grey.withAlpha(30);
    final preEnabled = _preMode[key] != 'none';
    final iqamaEnabled = _iqamaMode[key] != 'none';
    final adhanEnabled = _adhanMode[key] != 'none';
    final preMins = _fardMinutes[key] ?? 15;
    final iqamaMins = _iqamaMinutes[key] ?? 15;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(40),
          width: 1.0.w,
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(icon, color: _gold, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1.h, color: divColor),

          // ─ قبل ─
          _notifSubRow(
            label: 'قبل الأذان',
            icon: Icons.alarm_outlined,
            mode: _preMode[key]!,
            soundName: _prefs.getString('pre_sound_$key') ?? 'pre_adhan',
            onSoundTap: () => _openSoundPicker('pre_sound_$key', 'صوت تنبيه قبل الأذان'),
            textColor: textColor,
            onModeChanged: (v) {
              setState(() {
                _preMode[key] = v;
                _fardEnabled[key] = v != 'none';
              });
              _savePrayerMode('pre_mode_$key', 'notif_pre_$key', v);
            },
          ),
          if (preEnabled)
            Padding(
              padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 10.h),
              child: _compactMinutesPicker(
                prefix: 'قبل الأذان بـ',
                value: preMins,
                min: 1,
                max: 60,
                step: 1,
                onChanged: (v) {
                  setState(() => _fardMinutes[key] = v);
                  _prefs.setInt('time_pre_$key', v);
                  PrayerService().scheduleNotificationsDebounced();
                },
              ),
            ),
          Divider(height: 1.h, color: divColor),

          // ─ أذان ─
          _notifSubRow(
            label: 'الأذان',
            icon: Icons.surround_sound_outlined,
            mode: _adhanMode[key]!,
            soundName: _prefs.getString('adhan_sound_$key') ?? (_prefs.getString('adhan_muezzin_id') ?? 'nafis'),
            onSoundTap: () => _openSoundPicker('adhan_sound_$key', 'صوت الأذان'),
            textColor: textColor,
            onModeChanged: (v) {
              setState(() => _adhanMode[key] = v);
              _savePrayerMode(
                'adhan_mode_$key',
                'notif_prayer_${key.toLowerCase()}',
                v,
              );
            },
          ),
          if (adhanEnabled)
            Padding(
              padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 10.h),
              child: CompactMinutesPickerWidget(
                prefix: 'تعديل الوقت (دقيقة)',
                initialValue: _adjustments[key] ?? 0,
                min: -60,
                max: 60,
                step: 1,
                goldColor: _gold,
                onChanged: (v) {
                  _adjustments[key] = v;
                  _prefs.setInt('adjust_$key', v);
                  PrayerService().scheduleNotificationsDebounced();
                },
              ),
            ),
          Divider(height: 1.h, color: divColor),

          // ─ إقامة ─
          _notifSubRow(
            label: 'الإقامة',
            icon: Icons.timer_outlined,
            mode: _iqamaMode[key]!,
            soundName: _prefs.getString('iqama_sound_$key') ?? 'iqama',
            onSoundTap: () => _openSoundPicker('iqama_sound_$key', 'صوت الإقامة'),
            textColor: textColor,
            onModeChanged: (v) {
              setState(() => _iqamaMode[key] = v);
              _savePrayerMode('iqama_mode_$key', 'iqama_enabled_$key', v);
            },
          ),
          if (iqamaEnabled)
            Padding(
              padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 10.h),
              child: CompactMinutesPickerWidget(
                prefix: 'بعد الأذان بـ',
                initialValue: iqamaMins,
                min: 1,
                max: 60,
                step: 1,
                goldColor: _gold,
                onChanged: (v) {
                  _iqamaMinutes[key] = v;
                  _prefs.setInt('iqama_minutes_$key', v);
                  PrayerService().scheduleNotificationsDebounced();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _notifSubRow({
    required String label,
    required IconData icon,
    required String mode,
    required Color textColor,
    String? soundName,
    VoidCallback? onSoundTap,
    required Function(String) onModeChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16.sp, color: Colors.grey),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 13.sp,
                  color: textColor,
                ),
              ),
              const Spacer(),
              _modeToggle(mode, onModeChanged),
            ],
          ),
          if (mode != 'none' && soundName != null) ...[
            SizedBox(height: 4.h),
            InkWell(
              onTap: onSoundTap,
              child: Row(
                children: [
                  SizedBox(width: 24.w),
                  Icon(Icons.audiotrack, size: 12.sp, color: _gold),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      _soundDisplayName(soundName),
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 11.sp,
                        color: _gold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeToggle(String currentMode, Function(String) onChanged) {
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeIconBtn(Icons.volume_up, 'sound', currentMode, _gold, onChanged),
          _modeIconBtn(
            Icons.notifications_outlined,
            'silent_notif',
            currentMode,
            Colors.blueGrey,
            onChanged,
          ),
          _modeIconBtn(
            Icons.block_outlined,
            'none',
            currentMode,
            Colors.red.shade300,
            onChanged,
          ),
        ],
      ),
    );
  }

  Widget _modeIconBtn(
    IconData icon,
    String val,
    String currentMode,
    Color activeColor,
    Function(String) onChanged,
  ) {
    final isActive = val == currentMode;
    return InkWell(
      onTap: () => onChanged(val),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16.sp,
          color: isActive ? activeColor : Colors.grey,
        ),
      ),
    );
  }

  Widget _modeLegend(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            fontSize: 11.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class CompactMinutesPickerWidget extends StatefulWidget {
  final String prefix;
  final int initialValue;
  final int min;
  final int max;
  final int step;
  final Color goldColor;
  final ValueChanged<int> onChanged;

  const CompactMinutesPickerWidget({
    super.key,
    required this.prefix,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.step,
    required this.goldColor,
    required this.onChanged,
  });

  @override
  State<CompactMinutesPickerWidget> createState() => _CompactMinutesPickerWidgetState();
}

class _CompactMinutesPickerWidgetState extends State<CompactMinutesPickerWidget> {
  late int _val;

  @override
  void initState() {
    super.initState();
    _val = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant CompactMinutesPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _val = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.prefix,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              if (_val > widget.min) {
                setState(() => _val -= widget.step);
                widget.onChanged(_val);
              }
            },
            child: Icon(Icons.remove_circle_outline, color: widget.goldColor, size: 20.sp),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Text(
              '$_val دق',
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              if (_val < widget.max) {
                setState(() => _val += widget.step);
                widget.onChanged(_val);
              }
            },
            child: Icon(Icons.add_circle_outline, color: widget.goldColor, size: 20.sp),
          ),
        ],
      ),
    );
  }
}
