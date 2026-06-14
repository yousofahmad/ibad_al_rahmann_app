import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/screens/alarms_screen.dart'; // As Alarms
import 'package:ibad_al_rahmann/screens/settings_screen.dart';
import 'occasions_screen.dart';
import 'fasting_days_screen.dart';
import 'package:ibad_al_rahmann/features/share_cards/ui/share_cards_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';

import 'package:flutter/services.dart';

import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adaptive BG
      appBar: AppBar(
        title: const Text(
          "المزيد",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871), // Keep Gold Title
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildMenuButton(
            context: context,
            title: "أيام الصيام",
            imagePath: "assets/images/fasting_days_icon.png",
            imageSize: 45.w,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FastingDaysScreen()),
            ),
          ),
          _buildMenuButton(
            context: context,
            title: "المناسبات",
            imagePath: "assets/images/occasions_icon.png",
            imageSize: 45.w,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OccasionsScreen()),
            ),
          ),
          _buildMenuButton(
            context: context,
            title: "المنبه",
            icon: Icons.alarm,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmsScreen()),
            ),
          ),

          _buildMenuButton(
            context: context,
            title: "تنبيهات الصلاة على النبي",
            iconWidget: Text(
              'ﷺ',
              style: TextStyle(
                fontSize: 30.sp,
                color: const Color(0xFFD0A871),
                height: 1.0,
              ),
            ),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => const SalawatReminderDialog(),
            ),
          ),

          _buildMenuButton(
            context: context,
            title: "بطاقات المشاركة",
            icon: Icons.grid_view_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareCardsScreen()),
            ),
          ),

          _buildMenuButton(
            context: context,
            title: "الإعدادات",
            icon: Icons.settings,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    IconData? icon,
    Widget? iconWidget,
    required VoidCallback onTap,
    String? imagePath,
    double? imageSize,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.withAlpha(50);
    final textColor = isDark ? Colors.white : Colors.black;
    final double size = imageSize ?? 30.w;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      height: 80.h,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                if (imagePath != null)
                  imagePath.endsWith('.svg')
                      ? SvgPicture.asset(
                          imagePath,
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          imagePath,
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                        )
                else if (icon != null)
                  Icon(icon, color: const Color(0xFFD0A871), size: 30.w)
                else if (iconWidget != null)
                  iconWidget,
                SizedBox(width: 20.w),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 20.w,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SalawatReminderDialog extends StatefulWidget {
  const SalawatReminderDialog({super.key});

  @override
  State<SalawatReminderDialog> createState() => _SalawatReminderDialogState();
}

class _SalawatReminderDialogState extends State<SalawatReminderDialog> {
  bool _isEnabled = false;
  final TextEditingController _controller = TextEditingController();
  List<int> _selectedDays = [DateTime.friday];
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);

  final Map<int, String> _daysMap = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('salawat_reminder_enabled') ?? false;
    final minutes = prefs.getInt('salawat_reminder_minutes') ?? 60;
    final daysList =
        prefs.getStringList('salawat_reminder_days') ??
        [DateTime.friday.toString()];

    final qhStartHour = prefs.getInt('quiet_hours_start_hour') ?? 23;
    final qhStartMin = prefs.getInt('quiet_hours_start_minute') ?? 0;
    final qhEndHour = prefs.getInt('quiet_hours_end_hour') ?? 7;
    final qhEndMin = prefs.getInt('quiet_hours_end_minute') ?? 0;

    setState(() {
      _isEnabled = enabled;
      _controller.text = minutes.toString();
      _selectedDays = daysList.map((e) => int.parse(e)).toList();
      _quietHoursStart = TimeOfDay(hour: qhStartHour, minute: qhStartMin);
      _quietHoursEnd = TimeOfDay(hour: qhEndHour, minute: qhEndMin);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = int.tryParse(_controller.text) ?? 60;

    // Save preferences immediately (fast)
    await prefs.setBool('salawat_reminder_enabled', _isEnabled);
    await prefs.setInt('salawat_reminder_minutes', minutes);
    await prefs.setStringList(
      'salawat_reminder_days',
      _selectedDays.map((e) => e.toString()).toList(),
    );

    await prefs.setInt('quiet_hours_start_hour', _quietHoursStart.hour);
    await prefs.setInt('quiet_hours_start_minute', _quietHoursStart.minute);
    await prefs.setInt('quiet_hours_end_hour', _quietHoursEnd.hour);
    await prefs.setInt('quiet_hours_end_minute', _quietHoursEnd.minute);

    // Close dialog immediately — don't wait for scheduling
    if (mounted) {
      Navigator.pop(context);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text(
            'تم حفظ إعدادات',
            style: TextStyle(fontFamily: AppConsts.expoArabic),
          ),
          backgroundColor: const Color(0xFFD0A871),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
      );
    }

    // Schedule notifications in background (no await blocking UI)
    if (_isEnabled && minutes > 0 && _selectedDays.isNotEmpty) {
      NotificationService.scheduleSalawatReminders(minutes, _selectedDays);
    } else {
      NotificationService.scheduleSalawatReminders(0, []);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietHoursStart : _quietHoursEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD0A871),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      title: const Text(
        "تنبيهات الصلاة على النبي",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          fontWeight: FontWeight.bold,
          color: Color(0xFFD0A871),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "تنبيهات دورية بالصلاة على النبي ﷺ",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppConsts.expoArabic),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "تفعيل التنبيهات",
                  style: TextStyle(fontFamily: AppConsts.expoArabic),
                ),
                Switch(
                  value: _isEnabled,
                  activeThumbColor: const Color(0xFFD0A871),
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
              ],
            ),
            if (_isEnabled) ...[
              Divider(height: 24.h),
              const Text(
                "اختر الأيام:",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                children: _daysMap.entries.map((entry) {
                  final isSelected = _selectedDays.contains(entry.key);
                  return FilterChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 12.sp,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(entry.key);
                        } else {
                          _selectedDays.remove(entry.key);
                        }
                      });
                    },
                    selectedColor: const Color(0xFFD0A871),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "الفاصل الزمني (بالدقيقة)",
                  labelStyle: const TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.grey,
                  ),
                  suffixText: "دقيقة",
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFD0A871)),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                style: const TextStyle(fontFamily: AppConsts.expoArabic),
              ),
              SizedBox(height: 20.h),
              const Text(
                "ساعات الهدوء:",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _quietTimePicker(
                    "من",
                    _quietHoursStart,
                    () => _pickTime(true),
                  ),
                  _quietTimePicker(
                    "إلى",
                    _quietHoursEnd,
                    () => _pickTime(false),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                "سيتم التذكير في الأيام المختارة حسب الفاصل المحدد، مع التوقف خلال ساعات الهدوء.",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 11.sp,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "إلغاء",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.grey,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD0A871),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          child: const Text(
            "حفظ",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quietTimePicker(String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          Text(
            time.format(context),
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD0A871),
            ),
          ),
        ],
      ),
    );
  }
}
