import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/screens/manual_adjustment_screen.dart';
import 'package:ibad_al_rahmann/screens/alarms_screen.dart';
import 'package:ibad_al_rahmann/screens/muezzin_selection_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PrayerService _prayerService = PrayerService();

  late bool _is24Hour;
  int _hijriOffset = 0;

  @override
  void initState() {
    super.initState();
    _is24Hour = _prayerService.is24Hour;
    _hijriOffset = _prayerService.hijriOffset;
  }

  Future<void> _showHijriDialog() async {
    int tempOffset = _hijriOffset;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: const Text(
                "تعديل التاريخ الهجري",
                style: TextStyle(color: Color(0xFFD0A871), fontFamily: 'Cairo'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "قم بزيادة أو إنقاص الأيام لتتوافق مع رؤية الهلال",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove,
                          color: Color(0xFFD0A871),
                        ),
                        onPressed: () => setDialogState(() => tempOffset--),
                      ),
                      Text(
                        "$tempOffset",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFFD0A871)),
                        onPressed: () => setDialogState(() => tempOffset++),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text(
                    "حفظ",
                    style: TextStyle(
                      color: Color(0xFFD0A871),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    await _prayerService.setHijriOffset(tempOffset);
                    setState(() => _hijriOffset = tempOffset);
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "الإعدادات",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: const Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // 1. General
          _buildSectionHeader("عام"),
          _buildListTile(
            "تنسيق 24 ساعة",
            "عرض الوقت بصيغة 24 ساعة",
            FontAwesomeIcons.clock,
            trailing: Switch(
              value: _is24Hour,
              activeColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                await _prayerService.setIs24Hour(val);
                setState(() => _is24Hour = val);
              },
            ),
          ),
          _buildListTile(
            "تاريخ الهجري",
            "تعديل التاريخ: $_hijriOffset يوم",
            FontAwesomeIcons.calendarDays,
            onTap: _showHijriDialog,
          ),

          // 2. Appearance
          _buildSectionHeader("المظهر"),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              final isDarkMode = state.mode == ThemeMode.dark;
              return _buildListTile(
                "الوضع الليلي",
                "تفعيل الوضع الداكن للتطبيق",
                FontAwesomeIcons.moon,
                trailing: Switch(
                  value: isDarkMode,
                  activeColor: const Color(0xFFD0A871),
                  onChanged: (val) {
                    context.read<ThemeCubit>().switchTheme();
                  },
                ),
              );
            },
          ),

          // 3. Account / Location
          _buildSectionHeader("الحساب والموقع"),
          _buildListTile(
            "طريقة الحساب",
            _getMethodName(_prayerService.method.toString()),
            FontAwesomeIcons.calculator,
            onTap: _showMethodDialog, // Implement helper for method selection
          ),
          _buildListTile(
            "المذهب الفقهي",
            _prayerService.madhab.toString().contains('hanafi')
                ? "الحنفي"
                : "الشافعي (الجمهور)",
            FontAwesomeIcons.personPraying,
            trailing: Switch(
              value: _prayerService.madhab.toString().contains('hanafi'),
              activeColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                await _prayerService.saveMadhab(val ? 'hanafi' : 'shafi');
                setState(() {});
              },
            ),
          ),

          // 4. Notifications & Adjustments
          _buildSectionHeader("التنبيهات والتعديلات"),
          _buildListTile(
            "صوت الأذان",
            "اختر المؤذن المفضل لديك",
            FontAwesomeIcons.towerBroadcast,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MuezzinSelectionScreen()),
            ),
          ),
          _buildListTile(
            "الإقامة والتنبيهات",
            "إعدادات التنبيه قبل الصلاة والإقامة",
            FontAwesomeIcons.bell,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmsScreen()),
            ),
          ),
          _buildListTile(
            "تعديل الأوقات يدويًا",
            "ضبط الدقائق (+/-) لكل صلاة",
            FontAwesomeIcons.sliders,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualAdjustmentScreen()),
            ),
          ),

          // 5. Support
          _buildSectionHeader("الدعم"),
          _buildListTile(
            "تواصل معنا",
            "أرسل لنا ملاحظاتك أو استفساراتك",
            Icons.mail_outline,
            onTap: () async {
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'support@ibadalrahman.com',
                query: 'subject=Ibad Al-Rahman Support',
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            },
          ),
          _buildListTile(
            "عن التطبيق",
            "الإصدار 1.0.0",
            Icons.info_outline,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "عباد الرحمن",
                applicationVersion: "1.0.0",
                applicationIcon: Image.asset(
                  "assets/icon/icon.png",
                  width: 50,
                  height: 50,
                ), // Ensure asset exists or remove
                children: [
                  const Text(
                    "تطبيق إسلامي شامل يهدف لخدمة المسلمين في شتى بقاع الأرض.",
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: const Color(0xFFD0A871),
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD0A871), size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontFamily: 'Cairo',
            fontSize: 12,
          ),
        ),
        trailing:
            trailing ??
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: onTap,
      ),
    );
  }

  String _getMethodName(String method) {
    if (method.contains('egyptian')) return 'الهيئة المصرية العامة للمساحة';
    if (method.contains('umm_al_qura')) return 'أم القرى (مكة المكرمة)';
    if (method.contains('karachi')) return 'جامعة العلوم الإسلامية بكراتشي';
    if (method.contains('north_america')) return 'أمريكا الشمالية (ISNA)';
    if (method.contains('muslim_world_league')) return 'رابطة العالم الإسلامي';
    if (method.contains('dubai')) return 'دبي';
    if (method.contains('kuwait')) return 'الكويت';
    if (method.contains('qatar')) return 'قطر';
    return 'الهيئة المصرية العامة للمساحة';
  }

  Future<void> _showMethodDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final methods = {
      'egypt': 'الهيئة المصرية العامة للمساحة',
      'makkah': 'أم القرى (مكة المكرمة)',
      'karachi': 'جامعة العلوم الإسلامية بكراتشي',
      'isna': 'أمريكا الشمالية (ISNA)',
      'mwl': 'رابطة العالم الإسلامي',
      'dubai': 'دبي',
      'kuwait': 'الكويت',
      'qatar': 'قطر',
    };

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: methods.entries.map((entry) {
            return ListTile(
              title: Text(
                entry.value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Cairo',
                ),
              ),
              onTap: () async {
                await _prayerService.saveMethod(entry.key);
                setState(() {});
                if (mounted) Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
