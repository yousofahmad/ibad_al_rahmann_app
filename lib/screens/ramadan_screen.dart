import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'qada_list_screen.dart';

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  bool _iftarAlarm = false;
  bool _suhoorAlarm = false;
  bool _eidAlarm = false;
  int _qadaCount = 0;
  int _ishaDelayMode = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final service = PrayerService();
    // Count missed days
    int missed = 0;
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    int year = HijriCalendar.fromDate(adjustedDate).hYear;
    // Assuming standard 30 days checking
    for (int i = 1; i <= 30; i++) {
      if (prefs.getBool('qada_${year}_$i') ?? false) {
        missed++;
      }
    }

    setState(() {
      _iftarAlarm = prefs.getBool('iftar_alarm') ?? false;
      _suhoorAlarm = prefs.getBool('suhoor_alarm') ?? false;
      _eidAlarm = prefs.getBool('eid_alarm') ?? false;
      _qadaCount = missed;
      _ishaDelayMode = service.ramadanIshaDelayMode;
    });
  }

  Future<void> _toggleAlarm(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'iftar_alarm') _iftarAlarm = value;
      if (key == 'suhoor_alarm') _suhoorAlarm = value;
      if (key == 'eid_alarm') _eidAlarm = value;
    });
    // Notification logic would go here
    PrayerService().scheduleNotifications();
  }

  Future<void> _setIshaMode(int mode) async {
    await PrayerService().saveRamadanIshaDelay(mode);
    setState(() => _ishaDelayMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 120.h,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "رمضان كريم",
          style: TextStyle(
            fontFamily: AppConsts.motoNastaliq,
            color: const Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
            fontSize: 40.sp, // Increased size
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section C: Qada Tracker (Prominent)
            SizedBox(height: 20.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QadaListScreen()),
                  );
                  _loadSettings(); // Refresh count on return
                },
                child: Container(
                  height: 120.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD0A871), Color(0xFFB88E50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "أيام القضاء",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "الأيام التي فاتتك: $_qadaCount",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: Colors.white70,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 24.w,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Section B: Alarms
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                "تنبيهات رمضان",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: const Color(0xFFD0A871),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withAlpha(20),
                ),
                boxShadow: Theme.of(context).brightness == Brightness.light
                    ? [
                        BoxShadow(
                          color: Colors.grey.withAlpha(20),
                          blurRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  _buildSwitch(
                    "منبه الإفطار",
                    "30 دقيقة قبل المغرب",
                    _iftarAlarm,
                    'iftar_alarm',
                  ),
                  Divider(
                    color: Theme.of(context).dividerColor.withAlpha(20),
                    height: 1,
                  ),
                  _buildSwitch(
                    "منبه السحور",
                    "ساعة قبل الفجر",
                    _suhoorAlarm,
                    'suhoor_alarm',
                  ),
                  Divider(
                    color: Theme.of(context).dividerColor.withAlpha(20),
                    height: 1,
                  ),
                  _buildSwitch(
                    "منبه العيد",
                    "30 دقيقة قبل شروق العيد",
                    _eidAlarm,
                    'eid_alarm',
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Section D: Isha Time Settings
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                "وقت العشاء",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: const Color(0xFFD0A871),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withAlpha(20),
                ),
                boxShadow: Theme.of(context).brightness == Brightness.light
                    ? [
                        BoxShadow(
                          color: Colors.grey.withAlpha(20),
                          blurRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: RadioGroup<int>(
                groupValue: _ishaDelayMode,
                onChanged: (v) {
                  if (v != null) _setIshaMode(v);
                },
                child: Column(
                  children: [
                    _buildRadioTile("الوقت الأصلي", "حسب الحساب الفلكي", 0),
                    Divider(
                      color: Theme.of(context).dividerColor.withAlpha(20),
                      height: 1,
                    ),
                    _buildRadioTile("بعد المغرب بـ 90 دقيقة", "توقيت شائع", 90),
                    Divider(
                      color: Theme.of(context).dividerColor.withAlpha(20),
                      height: 1,
                    ),
                    _buildRadioTile(
                      "بعد المغرب بـ 120 دقيقة",
                      "تأخير رمضاني",
                      120,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, String key) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return SwitchListTile(
      activeThumbColor: const Color(0xFFD0A871),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      value: value,
      onChanged: (v) => _toggleAlarm(key, v),
    );
  }

  Widget _buildRadioTile(String title, String subtitle, int value) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return RadioListTile<int>(
      activeColor: const Color(0xFFD0A871),
      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      value: value,
    );
  }
}
