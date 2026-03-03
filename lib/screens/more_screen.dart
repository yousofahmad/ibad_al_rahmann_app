import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/screens/alarms_screen.dart'; // As Alarms
import 'package:ibad_al_rahmann/screens/settings_screen.dart';
import 'package:ibad_al_rahmann/screens/tasbeeh_screen.dart';
import 'occasions_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
            title: "السبحة",
            icon: Icons.data_saver_off,
            imagePath:
                'assets/images/pngtree-luxury-islamic-prayer-beads-macro-png-image_18712828.webp',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TasbeehScreen()),
            ),
          ),
          _buildMenuButton(
            context: context,
            title: "المناسبات",
            icon: Icons.event,
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
            iconWidget: const Text(
              'ﷺ',
              style: TextStyle(
                fontSize: 30,
                color: Color(0xFFD0A871),
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF121212) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.withAlpha(50);
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      height: 80.h,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
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
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                if (imagePath != null)
                  imagePath.endsWith('.svg')
                      ? SvgPicture.asset(
                          imagePath,
                          width: 30.w,
                          height: 30.w,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          imagePath,
                          width: 30.w,
                          height: 30.w,
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
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 20,
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

    setState(() {
      _isEnabled = enabled;
      _controller.text = minutes.toString();
      _selectedDays = daysList.map((e) => int.parse(e)).toList();
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = int.tryParse(_controller.text) ?? 60;

    await prefs.setBool('salawat_reminder_enabled', _isEnabled);
    await prefs.setInt('salawat_reminder_minutes', minutes);
    await prefs.setStringList(
      'salawat_reminder_days',
      _selectedDays.map((e) => e.toString()).toList(),
    );

    if (_isEnabled && minutes > 0 && _selectedDays.isNotEmpty) {
      await NotificationService.scheduleSalawatReminders(
        minutes,
        _selectedDays,
      );
    } else {
      await NotificationService.scheduleSalawatReminders(0, []);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم حفظ الإعدادات',
            style: TextStyle(fontFamily: AppConsts.expoArabic),
          ),
          backgroundColor: const Color(0xFFD0A871),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
            const SizedBox(height: 12),
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
              const Divider(height: 24),
              const Text(
                "اختر الأيام:",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
              const SizedBox(height: 20),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFD0A871)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                style: const TextStyle(fontFamily: AppConsts.expoArabic),
              ),
              const SizedBox(height: 10),
              const Text(
                "سيتم التذكير في الأيام المختارة حسب الفاصل المحدد.",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 11,
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
              borderRadius: BorderRadius.circular(10),
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
}
