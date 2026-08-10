import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'azkar_page.dart';
import 'ruqyah_screen.dart';
import 'azkar_statistics_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class MuslimAzkarScreen extends StatelessWidget {
  const MuslimAzkarScreen({super.key});

  Widget _buildAzkarButton(
    BuildContext context,
    String title,
    IconData icon,
    Widget targetScreen,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).cardColor, // Theme Card Color
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: const BorderSide(color: Color(0xFFD0A871), width: 1),
          ),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFFD0A871), size: 28.w),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyLarge?.color, // Theme Text
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Theme BG
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Stats & Alerts
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderButton(
                      context,
                      "الإحصائيات",
                      FontAwesomeIcons.chartBar,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AzkarStatisticsScreen(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildHeaderButton(
                      context,
                      "التنبيهات",
                      FontAwesomeIcons.solidBell,
                      () => _showNotificationSettings(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Vertical List
              Expanded(
                child: ListView(
                  children: [
                    _buildAzkarButton(
                      context,
                      "أذكار الصباح",
                      Icons.wb_sunny,
                      const AzkarPage(
                        title: "أذكار الصباح",
                        jsonFile: "morning.json",
                        image: "assets/images/morning.jpg",
                      ),
                    ),
                    _buildAzkarButton(
                      context,
                      "أذكار المساء",
                      Icons.nights_stay,
                      const AzkarPage(
                        title: "أذكار المساء",
                        jsonFile: "evening.json",
                        image: "assets/images/night.jpg",
                      ),
                    ),
                    _buildAzkarButton(
                      context,
                      "أذكار الصلاة",
                      Icons.mosque,
                      const AzkarPage(
                        title: "أذكار الصلاة",
                        jsonFile: "prayer.json",
                        image: "assets/images/mosque.jpg",
                      ),
                    ),
                    _buildAzkarButton(
                      context,
                      "الرقية الشرعية",
                      Icons.shield,
                      const RuqyahScreen(),
                    ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار المسجد",
                    //   Icons.location_city,
                    //   const AzkarPage(title: "أذكار المسجد", jsonFile: "mosque.json", image: "assets/images/mosque.jpg"),
                    // ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار الوضوء",
                    //   Icons.water_drop,
                    //   const AzkarPage(title: "أذكار الوضوء", jsonFile: "wudu.json", image: "assets/images/mosque.jpg"),
                    // ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار النوم",
                    //   Icons.bed,
                    //   const AzkarPage(title: "أذكار النوم", jsonFile: "sleep.json", image: "assets/images/night.jpg"),
                    // ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار الاستيقاظ",
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    const borderColor = Color(0xFFD0A871);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: borderColor, width: 1.w),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.grey.withAlpha(20),
                    blurRadius: 5.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: borderColor, size: 18.w),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => const _AzkarAlertsSheet(),
    );
  }
}

class _AzkarAlertsSheet extends StatefulWidget {
  const _AzkarAlertsSheet();

  @override
  State<_AzkarAlertsSheet> createState() => _AzkarAlertsSheetState();
}

class _AzkarAlertsSheetState extends State<_AzkarAlertsSheet> {
  // State
  String _morningMode = 'sound'; // 'sound' | 'silent_notif' | 'none'
  String _eveningMode = 'sound';

  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = CacheHelper.prefs;
    setState(() {
      final morningLegacy = prefs.getBool('notif_azkar_morning') ?? true;
      _morningMode =
          prefs.getString('azkar_morning_mode') ??
          (morningLegacy ? 'sound' : 'none');

      final eveningLegacy = prefs.getBool('notif_azkar_evening') ?? true;
      _eveningMode =
          prefs.getString('azkar_evening_mode') ??
          (eveningLegacy ? 'sound' : 'none');

      final m = (prefs.getString('time_azkar_morning') ?? "06:00").split(":");
      _morningTime = TimeOfDay(hour: int.parse(m[0]), minute: int.parse(m[1]));

      final e = (prefs.getString('time_azkar_evening') ?? "17:00").split(":");
      _eveningTime = TimeOfDay(hour: int.parse(e[0]), minute: int.parse(e[1]));
    });
  }

  Future<void> _savePrefs() async {
    final prefs = CacheHelper.prefs;
    await prefs.setString('azkar_morning_mode', _morningMode);
    await prefs.setBool('notif_azkar_morning', _morningMode != 'none');

    await prefs.setString('azkar_evening_mode', _eveningMode);
    await prefs.setBool('notif_azkar_evening', _eveningMode != 'none');

    await prefs.setString(
      'time_azkar_morning',
      "${_morningTime.hour}:${_morningTime.minute}",
    );
    await prefs.setString(
      'time_azkar_evening',
      "${_eveningTime.hour}:${_eveningTime.minute}",
    );

    // Reschedule
    PrayerService().scheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "تنبيهات الأذكار",
            style: TextStyle(
              color: const Color(0xFFD0A871),
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          SizedBox(height: 20.h),
          _buildModeItem(
            "أذكار الصباح",
            _morningMode,
            (v) => setState(() => _morningMode = v),
            _morningTime,
            (t) => setState(() => _morningTime = t),
          ),
          Divider(height: 30.h),
          _buildModeItem(
            "أذكار المساء",
            _eveningMode,
            (v) => setState(() => _eveningMode = v),
            _eveningTime,
            (t) => setState(() => _eveningTime = t),
          ),

          SizedBox(height: 30.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              onPressed: () async {
                await _savePrefs();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "حفظ الإعدادات",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeItem(
    String title,
    String mode,
    ValueChanged<String> onModeChanged,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onTime,
  ) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Column(
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (mode != 'none')
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (t != null) onTime(t);
                },
                child: Text(
                  "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    color: Color(0xFFD0A871),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            _buildModeToggle(mode, onModeChanged),
          ],
        ),
        if (mode != 'none')
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              mode == 'sound' ? 'تنبيه مع صوت' : 'تنبيه صامت (إشعار فقط)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11.sp,
                fontFamily: 'Cairo',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModeToggle(String current, ValueChanged<String> onChanged) {
    final modes = [
      ('sound', Icons.volume_up, const Color(0xFFD0A871)),
      ('silent_notif', Icons.notifications_outlined, Colors.blueGrey),
      ('none', Icons.block_outlined, Colors.red.shade300),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: modes.map((m) {
        final selected = current == m.$1;
        return GestureDetector(
          onTap: () => onChanged(m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32.w,
            height: 32.h,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: selected ? m.$3 : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? m.$3 : Colors.grey.withAlpha(80),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Icon(
              m.$2,
              size: 16.w,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        );
      }).toList(),
    );
  }
}
