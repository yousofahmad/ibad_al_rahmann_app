import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // ... (State variables are fine, skipping to limit tokens if possible, but replace_file_content needs context)
  // Actually I should target the top of file for import, and the body for methods.
  // Splitting into 2 edits is safer.

  // Azkar
  bool _morningAzkar = true;
  bool _eveningAzkar = true;
  String _morningTime = "06:00";
  String _eveningTime = "17:00";
  bool _vibTasbeeh = true;
  bool _vibCounter = true;

  // Nawafil
  bool _qiyamAlert = false;
  bool _sunriseAlert = false;
  bool _duhaAlert = false;
  bool _jumuaAlert = false;
  bool _persistentNotification = true;

  // Pre-Prayer (Fard) - Enabled Toggles
  final Map<String, bool> _prePrayerEnabled = {
    'Fajr': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };
  // Pre-Prayer - Minutes
  final Map<String, int> _prePrayerMinutes = {
    'Fajr': 15,
    'Dhuhr': 15,
    'Asr': 15,
    'Maghrib': 15,
    'Isha': 15,
  };

  // Seasonal
  bool _iftarAlert = false;
  bool _suhoorAlert = false;
  bool _eidAlert = false;
  bool _takbeeratAlert = false;
  bool _arafahAlert = false;

  // Iqama
  final Map<String, bool> _iqamaEnabled = {
    'Fajr': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };
  final Map<String, int> _iqamaMinutes = {
    'Fajr': 20,
    'Dhuhr': 15,
    'Asr': 15,
    'Maghrib': 10,
    'Isha': 15,
  };

  // Adhan
  final Map<String, bool> _adhanEnabled = {
    'Fajr': true,
    'Dhuhr': true,
    'Asr': true,
    'Maghrib': true,
    'Isha': true,
  };

  // Permissions
  bool _hasAlarmPerm = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool p = await NotificationService.checkExactAlarmPermission();
    if (mounted) setState(() => _hasAlarmPerm = p);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morningAzkar = prefs.getBool('notif_azkar_morning') ?? true;
      _eveningAzkar = prefs.getBool('notif_azkar_evening') ?? true;
      _morningTime = prefs.getString('time_azkar_morning') ?? "06:00";
      _eveningTime = prefs.getString('time_azkar_evening') ?? "17:00";
      _vibTasbeeh = prefs.getBool('vib_tasbeeh') ?? true;
      _vibTasbeeh = prefs.getBool('vib_tasbeeh') ?? true;
      _vibCounter = prefs.getBool('vib_counter') ?? true;

      _qiyamAlert = prefs.getBool('notif_qiyam') ?? false;
      _sunriseAlert = prefs.getBool('notif_sunrise') ?? true;
      _duhaAlert = prefs.getBool('notif_duha') ?? false;
      _jumuaAlert = prefs.getBool('notif_jumua') ?? false;
      _persistentNotification =
          prefs.getBool('persistent_notification') ?? true;

      // Pre-Prayer
      for (var p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        _prePrayerEnabled[p] = prefs.getBool('notif_pre_$p') ?? false;
        _prePrayerMinutes[p] = prefs.getInt('time_pre_$p') ?? 15;
      }

      // Seasonal
      _iftarAlert = prefs.getBool('iftar_alarm') ?? false;
      _suhoorAlert = prefs.getBool('suhoor_alarm') ?? false;
      _eidAlert = prefs.getBool('eid_alarm') ?? false;

      _takbeeratAlert = prefs.getBool('notif_takbeerat') ?? false;
      _arafahAlert = prefs.getBool('notif_arafah') ?? false;

      // Iqama
      for (var p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        _iqamaEnabled[p] = prefs.getBool('iqama_enabled_$p') ?? false;
        _iqamaMinutes[p] =
            prefs.getInt('iqama_minutes_$p') ??
            (p == 'Maghrib' ? 10 : (p == 'Fajr' ? 20 : 15));
      }

      // Adhan
      for (var p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        _adhanEnabled[p] =
            prefs.getBool('notif_prayer_${p.toLowerCase()}') ?? true;
      }
    });
  }

  // ... save methods ...
  Future<void> _saveBool(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    PrayerService().scheduleNotifications();
  }

  Future<void> _saveString(String key, String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
    PrayerService().scheduleNotifications();
  }

  Future<void> _saveInt(String key, int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, val);
    PrayerService().scheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "الإشعارات والتنبيهات",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          if (!_hasAlarmPerm)
            Container(
              margin: EdgeInsets.only(bottom: 20.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber),
                  SizedBox(width: 10.w),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "تنبيه: إذن المنبهات الدقيقة معطل",
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppConsts.expoArabic,
                          ),
                        ),
                        Text(
                          "قد لا تعمل الإشعارات بدقة. يرجى تفعيل الإذن من الإعدادات.",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    child: const Text("تفعيل"),
                  ),
                ],
              ),
            ),

          _buildGroupTitle("تنبيهات الأذكار"),
          _buildGroupContainer([
            _buildTimePickerTile(
              "أذكار الصباح",
              _morningAzkar,
              _morningTime,
              (val) {
                setState(() => _morningAzkar = val);
                _saveBool('notif_azkar_morning', val);
              },
              (time) {
                setState(() => _morningTime = time);
                _saveString('time_azkar_morning', time);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم حفظ موعد أذكار الصباح",
                        style: TextStyle(fontFamily: AppConsts.expoArabic),
                      ),
                      backgroundColor: Color(0xFFD0A871),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildTimePickerTile(
              "أذكار المساء",
              _eveningAzkar,
              _eveningTime,
              (val) {
                setState(() => _eveningAzkar = val);
                _saveBool('notif_azkar_evening', val);
              },
              (time) {
                setState(() => _eveningTime = time);
                _saveString('time_azkar_evening', time);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم حفظ موعد أذكار المساء",
                        style: TextStyle(fontFamily: AppConsts.expoArabic),
                      ),
                      backgroundColor: Color(0xFFD0A871),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "اهتزاز التسبيح",
              "عند النقر على السبحة",
              _vibTasbeeh,
              (val) {
                setState(() => _vibTasbeeh = val);
                _saveBool('vib_tasbeeh', val);
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "اهتزاز العداد",
              "عند اكتمال الدورة",
              _vibCounter,
              (val) {
                setState(() => _vibCounter = val);
                _saveBool('vib_counter', val);
              },
            ),
          ]),

          _buildGroupTitle("النوافل والمنبهات العامة"),
          _buildGroupContainer([
            _buildSwitchTile(
              "قيام الليل",
              "في الثلث الأخير من الليل",
              _qiyamAlert,
              (val) {
                setState(() => _qiyamAlert = val);
                _saveBool('notif_qiyam', val);
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "شروق الشمس",
              "في موعد الشروق تماماً",
              _sunriseAlert,
              (val) {
                setState(() => _sunriseAlert = val);
                _saveBool('notif_sunrise', val);
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "صلاة الضحى",
              "بعد الشروق بـ 20 دقيقة",
              _duhaAlert,
              (val) {
                setState(() => _duhaAlert = val);
                _saveBool('notif_duha', val);
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile("تنبيه الجمعة", "قبل الصلاة بساعة", _jumuaAlert, (
              val,
            ) {
              setState(() => _jumuaAlert = val);
              _saveBool('notif_jumua', val);
            }),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "الإشعار الثابت",
              "عرض أوقات الصلاة في شريط الإشعارات",
              _persistentNotification,
              (val) {
                setState(() => _persistentNotification = val);
                _saveBool('persistent_notification', val);
              },
            ),
          ]),

          _buildGroupTitle("تنبيه الأذان (الصوت)"),
          _buildGroupContainer(
            _adhanEnabled.keys
                .map((prayer) {
                  return Column(
                    children: [
                      _buildAdhanTile(prayer),
                      if (prayer != 'Isha')
                        const Divider(color: Color(0xFF333333)),
                    ],
                  );
                })
                .toList()
                .cast<Widget>(),
          ),

          _buildGroupTitle("تنبيه قبل الأذان (الصلوات المفروضة)"),
          _buildGroupContainer(
            _prePrayerEnabled.keys
                .map((prayer) {
                  return Column(
                    children: [
                      _buildPrePrayerTile(prayer),
                      if (prayer != 'Isha')
                        const Divider(color: Color(0xFF333333)),
                    ],
                  );
                })
                .toList()
                .cast<Widget>(),
          ),

          _buildGroupTitle("تنبيه الإقامة (بعد الأذان)"),
          _buildGroupContainer(
            _iqamaEnabled.keys
                .map((prayer) {
                  return Column(
                    children: [
                      _buildIqamaTile(prayer),
                      if (prayer != 'Isha')
                        const Divider(color: Color(0xFF333333)),
                    ],
                  );
                })
                .toList()
                .cast<Widget>(),
          ),

          _buildGroupTitle("رمضان والمناسبات"),
          _buildGroupContainer([
            _buildSwitchTile("إفطار الصائم", "عند موعد المغرب", _iftarAlert, (
              val,
            ) {
              setState(() => _iftarAlert = val);
              _saveBool('iftar_alarm', val); // Matches RamadanScreen
            }),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile("السحور", "قبل الفجر بساعة", _suhoorAlert, (val) {
              setState(() => _suhoorAlert = val);
              _saveBool('suhoor_alarm', val);
            }),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile("صلاة العيد", "قبل صلاة العيد", _eidAlert, (val) {
              setState(() => _eidAlert = val);
              _saveBool('eid_alarm', val);
            }),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "تكبيرات العيد",
              "كل ساعة في 10 ذي الحجة",
              _takbeeratAlert,
              (val) {
                setState(() => _takbeeratAlert = val);
                _saveBool('notif_takbeerat', val);
              },
            ),
            const Divider(color: Color(0xFF333333)),
            _buildSwitchTile(
              "يوم عرفة",
              "تذكير بالسحور والإفطار",
              _arafahAlert,
              (val) {
                setState(() => _arafahAlert = val);
                _saveBool('notif_arafah', val);
              },
            ),
          ]),

          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 10.h, right: 5.w),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: const Color(0xFFD0A871),
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGroupContainer(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool val,
    Function(bool) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      activeThumbColor: const Color(0xFFD0A871),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16.sp,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: isDark ? Colors.grey : Colors.grey[700],
          fontSize: 12.sp,
        ),
      ),
      value: val,
      onChanged: onChanged,
    );
  }

  Widget _buildTimePickerTile(
    String title,
    bool val,
    String time,
    Function(bool) onSwitch,
    Function(String) onTime,
  ) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: Colors.white,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
      subtitle: val
          ? GestureDetector(
              onTap: () async {
                TimeOfDay? t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: int.parse(time.split(":")[0]),
                    minute: int.parse(time.split(":")[1]),
                  ),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFFD0A871),
                          onPrimary: Colors.black,
                          surface: Color(0xFF121212),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (t != null) {
                  // Force 2 digits
                  String h = t.hour.toString().padLeft(2, '0');
                  String m = t.minute.toString().padLeft(2, '0');
                  onTime("$h:$m");
                }
              },
              child: Text(
                "الوقت: $time (اضغط للتغيير)",
                style: const TextStyle(color: Color(0xFFD0A871), fontSize: 13),
              ),
            )
          : null,
      trailing: Switch(
        value: val,
        activeThumbColor: const Color(0xFFD0A871),
        onChanged: onSwitch,
      ),
    );
  }

  Widget _buildPrePrayerTile(String prayer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String arabicName = _getArabicName(prayer);
    bool enabled = _prePrayerEnabled[prayer] ?? false;
    int mins = _prePrayerMinutes[prayer] ?? 15;

    return ListTile(
      title: Text(
        arabicName,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16.sp,
        ),
      ),
      subtitle: Text(
        enabled ? "التنبيه قبل $mins دقيقة" : "التنبيه معطل",
        style: TextStyle(
          color: isDark ? Colors.grey : Colors.grey[700],
          fontSize: 12.sp,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabled)
            IconButton(
              icon: Icon(
                Icons.edit,
                color: isDark ? Colors.white54 : Colors.black54,
                size: 20,
              ),
              onPressed: () => _showMinutesDialog(prayer, mins),
            ),
          Switch(
            value: enabled,
            activeThumbColor: const Color(0xFFD0A871),
            onChanged: (val) {
              setState(() => _prePrayerEnabled[prayer] = val);
              _saveBool('notif_pre_$prayer', val);
            },
          ),
        ],
      ),
    );
  }

  void _showMinutesDialog(String prayer, int current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController controller = TextEditingController(
      text: current.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          "وقت التنبيه ($prayer)",
          style: const TextStyle(color: Color(0xFFD0A871)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "تنبيه قبل الأذان بـ (دقائق):",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey : Colors.black12,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD0A871)),
                ),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              "حفظ",
              style: TextStyle(color: Color(0xFFD0A871)),
            ),
            onPressed: () {
              int? newVal = int.tryParse(controller.text);
              if (newVal != null && newVal > 0) {
                setState(() => _prePrayerMinutes[prayer] = newVal);
                _saveInt('time_pre_$prayer', newVal);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم حفظ التوقيت بنجاح",
                        style: TextStyle(fontFamily: AppConsts.expoArabic),
                      ),
                      backgroundColor: Color(0xFFD0A871),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  String _getArabicName(String en) {
    switch (en) {
      case 'Fajr':
        return "الفجر";
      case 'Dhuhr':
        return "الظهر";
      case 'Asr':
        return "العصر";
      case 'Maghrib':
        return "المغرب";
      case 'Isha':
        return "العشاء";
      default:
        return en;
    }
  }

  Widget _buildAdhanTile(String prayer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String arabicName = _getArabicName(prayer);
    bool enabled = _adhanEnabled[prayer] ?? true;

    return SwitchListTile(
      activeThumbColor: const Color(0xFFD0A871),
      title: Text(
        "أذان $arabicName",
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16.sp,
        ),
      ),
      subtitle: Text(
        enabled ? "صوت الأذان مفعل" : "صوت الأذان معطل",
        style: TextStyle(
          color: isDark ? Colors.grey : Colors.grey[700],
          fontSize: 12.sp,
        ),
      ),
      value: enabled,
      onChanged: (val) {
        setState(() => _adhanEnabled[prayer] = val);
        _saveBool('notif_prayer_${prayer.toLowerCase()}', val);
      },
    );
  }

  Widget _buildIqamaTile(String prayer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String arabicName = _getArabicName(prayer);
    bool enabled = _iqamaEnabled[prayer] ?? false;
    int mins = _iqamaMinutes[prayer] ?? 15;

    return ListTile(
      title: Text(
        arabicName,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16.sp,
        ),
      ),
      subtitle: Text(
        enabled ? "الإقامة بعد الأذان بـ $mins دقيقة" : "تنبيه الإقامة معطل",
        style: TextStyle(
          color: isDark ? Colors.grey : Colors.grey[700],
          fontSize: 12.sp,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabled)
            IconButton(
              icon: Icon(
                Icons.edit,
                color: isDark ? Colors.white54 : Colors.black54,
                size: 20,
              ),
              onPressed: () => _showIqamaDialog(prayer, mins),
            ),
          Switch(
            value: enabled,
            activeThumbColor: const Color(0xFFD0A871),
            onChanged: (val) {
              setState(() => _iqamaEnabled[prayer] = val);
              _saveBool('iqama_enabled_$prayer', val);
            },
          ),
        ],
      ),
    );
  }

  void _showIqamaDialog(String prayer, int current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TextEditingController controller = TextEditingController(
      text: current.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          "وقت الإقامة ($prayer)",
          style: const TextStyle(color: Color(0xFFD0A871)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "الإقامة بعد الأذان بـ (دقائق):",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey : Colors.black12,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD0A871)),
                ),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              "حفظ",
              style: TextStyle(color: Color(0xFFD0A871)),
            ),
            onPressed: () {
              int? newVal = int.tryParse(controller.text);
              if (newVal != null && newVal > 0) {
                setState(() => _iqamaMinutes[prayer] = newVal);
                _saveInt('iqama_minutes_$prayer', newVal);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "تم حفظ التوقيت بنجاح",
                        style: TextStyle(fontFamily: AppConsts.expoArabic),
                      ),
                      backgroundColor: Color(0xFFD0A871),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
