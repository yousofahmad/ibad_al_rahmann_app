import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  // Preferences Cache
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // General States
  bool _qiyam = false;
  bool _sunrise = false;
  bool _duha = false;
  bool _jumuah = false;

  // Seasonal
  bool _takbeerat = false;
  bool _arafah = false;
  bool _eidDhulHijjah = false;
  bool _iftar = false;
  bool _suhoor = false;
  bool _eidFitr = false;

  // Fard Pre-Alerts (Enabled + Minutes)
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

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _qiyam = _prefs.getBool('notif_qiyam') ?? false;
      _sunrise = _prefs.getBool('notif_sunrise') ?? true;
      _duha = _prefs.getBool('notif_duha') ?? false;
      _jumuah = _prefs.getBool('notif_jumua') ?? false;

      _takbeerat = _prefs.getBool('notif_takbeerat') ?? false;
      _arafah = _prefs.getBool('notif_arafah') ?? false;
      _eidDhulHijjah = _prefs.getBool('notif_eid_dhulhijjah') ?? false;

      _iftar = _prefs.getBool('iftar_alarm') ?? false;
      _suhoor = _prefs.getBool('suhoor_alarm') ?? false;
      _eidFitr = _prefs.getBool('eid_alarm') ?? false;

      for (var key in _fardEnabled.keys) {
        _fardEnabled[key] = _prefs.getBool('notif_pre_$key') ?? false;
        _fardMinutes[key] = _prefs.getInt('time_pre_$key') ?? 15;
      }
      _isLoading = false;
    });
  }

  Future<void> _toggle(String key, bool val) async {
    await _prefs.setBool(key, val);
    PrayerService().scheduleNotifications();
  }

  Future<void> _setMinutes(String key, int val) async {
    await _prefs.setInt('time_pre_$key', val);
    setState(() {
      _fardMinutes[key] = val;
    });
    PrayerService().scheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "المنبهات",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildSectionHeader("تنبيهات عامة"),
          _buildSwitchTile("منبه القيام", "الثلث الأخير من الليل", _qiyam, (v) {
            setState(() => _qiyam = v);
            _toggle('notif_qiyam', v);
          }),
          _buildSwitchTile("منبه الشروق", "عند وقت الشروق", _sunrise, (v) {
            setState(() => _sunrise = v);
            _toggle('notif_sunrise', v);
          }),
          _buildSwitchTile("منبه الضحى", "قبل الظهر بساعتين", _duha, (v) {
            setState(() => _duha = v);
            _toggle('notif_duha', v);
          }),
          _buildSwitchTile("منبه الجمعة", "قبل صلاة الجمعة بساعة", _jumuah, (
            v,
          ) {
            setState(() => _jumuah = v);
            _toggle('notif_jumua', v);
          }),

          SizedBox(height: 20.h),
          _buildSectionHeader("تنبيهات الصلوات (قبل الأذان)"),
          _buildFardTile("الفجر", 'Fajr'),
          _buildFardTile("الظهر", 'Dhuhr'),
          _buildFardTile("العصر", 'Asr'),
          _buildFardTile("المغرب", 'Maghrib'),
          _buildFardTile("العشاء", 'Isha'),

          SizedBox(height: 20.h),
          _buildSectionHeader("تنبيهات ذو الحجة"),
          _buildSwitchTile("تكبيرات العشر", "تذكير كل ساعة", _takbeerat, (v) {
            setState(() => _takbeerat = v);
            _toggle('notif_takbeerat', v);
          }),
          _buildSwitchTile("يوم عرفة", "تنبيه السحور والإفطار", _arafah, (v) {
            setState(() => _arafah = v);
            _toggle('notif_arafah', v);
          }),
          _buildSwitchTile(
            "عيد الأضحى",
            "قبل الصلاة بـ 30 دقيقة",
            _eidDhulHijjah,
            (v) {
              setState(() => _eidDhulHijjah = v);
              _toggle('notif_eid_dhulhijjah', v);
            },
          ),

          SizedBox(height: 20.h),
          _buildSectionHeader("تنبيهات رمضان"),
          _buildSwitchTile("موعد الإفطار", "عند أذان المغرب", _iftar, (v) {
            setState(() => _iftar = v);
            _toggle('iftar_alarm', v);
          }),
          _buildSwitchTile("موعد السحور", "قبل الفجر بساعة", _suhoor, (v) {
            setState(() => _suhoor = v);
            _toggle('suhoor_alarm', v);
          }),
          _buildSwitchTile("عيد الفطر", "قبل الصلاة بـ 30 دقيقة", _eidFitr, (
            v,
          ) {
            setState(() => _eidFitr = v);
            _toggle('eid_alarm', v);
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: const Color(0xFFD0A871),
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.white10 : Colors.grey.withAlpha(50);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: SwitchListTile(
        activeThumbColor: const Color(0xFFD0A871),
        activeTrackColor: const Color(0xFFD0A871).withValues(alpha: 0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: isDark ? Colors.black : Colors.grey.shade300,
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: isDark ? Colors.white60 : Colors.grey,
            fontSize: 12.sp,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFardTile(String prayerName, String key) {
    bool enabled = _fardEnabled[key] ?? false;
    int mins = _fardMinutes[key] ?? 15;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.white10 : Colors.grey.withAlpha(50);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerName,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  enabled ? "تنبيه قبل $mins دقيقة" : "تم الإيقاف",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: enabled ? const Color(0xFFD0A871) : Colors.grey,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: const Color(0xFFD0A871),
            inactiveTrackColor: isDark ? Colors.black : Colors.grey.shade300,
            onChanged: (v) {
              setState(() {
                _fardEnabled[key] = v;
              });
              _toggle('notif_pre_$key', v);
            },
          ),
          if (enabled)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => _showMinutePicker(key, mins),
            ),
        ],
      ),
    );
  }

  void _showMinutePicker(String key, int currentMins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) {
        int selected = currentMins;
        return Container(
          padding: EdgeInsets.all(20.w),
          height: 250.h,
          child: Column(
            children: [
              Text(
                "وقت التنبيه قبل الأذان (دقائق)",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () {
                        if (selected > 5) {
                          selected -= 5;
                          (ctx as Element).markNeedsBuild();
                        }
                      },
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD0A871)),
                      ),
                      child: Text(
                        "$selected",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: const Color(0xFFD0A871),
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        if (selected < 60) {
                          selected += 5;
                          (ctx as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0A871),
                ),
                onPressed: () {
                  _setMinutes(key, selected);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "حفظ",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
