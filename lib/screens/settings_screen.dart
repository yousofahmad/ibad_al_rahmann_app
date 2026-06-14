import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/services/backup_service.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/remote_config_service.dart';
import 'package:ibad_al_rahmann/screens/muezzin_selection_screen.dart';
import 'package:ibad_al_rahmann/screens/prayer_alarms_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ibad_al_rahmann/main.dart'; // To access scaffoldMessengerKey

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PrayerService _prayerService = PrayerService();

  Future<void> _showNativeLog(BuildContext context) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/native_prayer_log.txt');
      String content = "لا يوجد سجل متاح حالياً.";
      if (await file.exists()) {
        content = await file.readAsString();
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("سجل الأذان (النيتف)"),
          content: SingleChildScrollView(
            child: SelectableText(content, textDirection: TextDirection.ltr),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ السجل كله', textDirection: TextDirection.rtl)),
                );
              },
              child: const Text("نسخ السجل كله"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إغلاق"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  late bool _is24Hour;
  int _hijriOffset = 0;
  int _localHijriDelta = 0;
  bool _persistentNotification = true;
  bool _autoSyncDrive = false;
  bool _flipToMute = false;
  bool _overrideSilent = false;
  bool _useCustomVolume = false;
  int _customVolume = 100;
  String? _googleEmail;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _is24Hour = _prayerService.is24Hour;
    _hijriOffset = _prayerService.manualHijriOffset;
    _localHijriDelta = _prayerService.localHijriDelta;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final email = await BackupService.getSignedInEmail();
    final syncTime = await BackupService.getLastSyncTime();
    if (context.mounted) {
      setState(() {
        _persistentNotification =
            prefs.getBool('persistent_notification_enabled') ?? true;
        _autoSyncDrive = prefs.getBool('auto_sync_drive') ?? false;
        _flipToMute = prefs.getBool('flip_to_mute') ?? false;
        _overrideSilent = prefs.getBool('override_silent_mode') ?? false;
        _useCustomVolume = prefs.getBool('use_custom_notif_volume') ?? false;
        _customVolume = prefs.getInt('custom_notif_volume_level') ?? 100;
        _googleEmail = email;
        _lastSyncTime = syncTime;
      });
    }
  }

  String _formatSyncTime(String? isoTime) {
    if (isoTime == null) return "لم يتم إجراء مزامنة بعد";
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);

      int h12 = dt.hour % 12;
      if (h12 == 0) h12 = 12;
      String amPm = dt.hour >= 12 ? 'م' : 'ص';
      String formattedTime = "$h12:${dt.minute.toString().padLeft(2, '0')} $amPm";

      if (diff.inMinutes < 1) return "الآن";
      if (diff.inHours < 1) return "منذ ${diff.inMinutes} دقيقة";
      if (diff.inDays < 1 && now.day == dt.day) {
        return "اليوم الساعة $formattedTime";
      } else if (diff.inDays < 2 && now.day != dt.day) {
        return "أمس الساعة $formattedTime";
      }
      return "منذ ${diff.inDays} يوم الساعة $formattedTime";
    } catch (e) {
      return "غير معروف";
    }
  }

  Future<void> _showHijriDialog() async {
    int tempManual = _hijriOffset;
    int tempLocal = _localHijriDelta;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
              title: Text(
                "تعديل التاريخ الهجري",
                style: TextStyle(color: gold, fontFamily: 'Cairo', fontSize: 18.sp),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Firebase offset (read-only) — مصر كمرجع ─────────────
                  Builder(
                    builder: (context) {
                      final remoteVal = RemoteConfigService.globalHijriOffset;
                      final remoteLabel = remoteVal > 0
                          ? '+$remoteVal'
                          : '$remoteVal';
                      return Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 14.w,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(
                              Icons.public,
                              size: 16.sp,
                              color: const Color(0xFFD0A871),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'التاريخ حسب مصر (من السيرفر)',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            Text(
                              remoteLabel,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFD0A871),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16.h),

                  // ── Manual correction (resets each month) ──────────────
                  Text(
                    "تعديل يدوي (يُصفَّر تلقائياً في بداية كل شهر)",
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 11.sp,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: gold, size: 24.sp),
                        onPressed: () => setDialogState(() => tempManual--),
                      ),
                      Text(
                        tempManual >= 0 ? '+$tempManual' : '$tempManual',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: gold, size: 24.sp),
                        onPressed: () => setDialogState(() => tempManual++),
                      ),
                    ],
                  ),

                  Divider(height: 24.h),

                  // ── Local country delta (permanent) ────────────────────
                  Text(
                    "تعديل دائم لاختلاف رؤية الهلال بحسب البلد",
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 11.sp,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "يبقى ثابتاً ولا يُصفَّر مع تغيّر الشهر",
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                      fontSize: 10.sp,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: gold, size: 24.sp),
                        onPressed: () => setDialogState(() => tempLocal--),
                      ),
                      Text(
                        tempLocal >= 0 ? '+$tempLocal' : '$tempLocal',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: gold, size: 24.sp),
                        onPressed: () => setDialogState(() => tempLocal++),
                      ),
                    ],
                  ),

                  SizedBox(height: 8.h),
                  // Summary: remote + manual + local
                  Builder(
                    builder: (context) {
                      final remote = RemoteConfigService.globalHijriOffset;
                      final total = remote + tempManual + tempLocal;
                      final totalLabel = total >= 0 ? '+$total' : '$total';
                      return Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8.h,
                          horizontal: 12.w,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'المجموع الكلي (مصر + يدوي + البلد): $totalLabel يوم',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: gold,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(
                    "إلغاء",
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text(
                    "حفظ",
                    style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 14.sp),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await _prayerService.setHijriOffset(tempManual);
                    await _prayerService.setLocalHijriDelta(tempLocal);
                    setState(() {
                      _hijriOffset = tempManual;
                      _localHijriDelta = tempLocal;
                    });
                    if (mounted) navigator.pop();
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
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5);

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
              activeThumbColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                await _prayerService.setIs24Hour(val);
                setState(() => _is24Hour = val);
              },
            ),
          ),
          _buildListTile(
            "تاريخ الهجري",
            "يدوي: ${_hijriOffset >= 0 ? '+$_hijriOffset' : '$_hijriOffset'} | بلد: ${_localHijriDelta >= 0 ? '+$_localHijriDelta' : '$_localHijriDelta'} | مجموع: ${(_hijriOffset + _localHijriDelta) >= 0 ? '+${_hijriOffset + _localHijriDelta}' : '${_hijriOffset + _localHijriDelta}'}",
            FontAwesomeIcons.calendarDays,
            onTap: _showHijriDialog,
          ),

          // 2. Appearance
          _buildSectionHeader("المظهر"),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              // Fix: Check the actual brightness of the theme currently applied.
              // This covers ThemeMode.system when it resolves to dark.
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              return _buildListTile(
                "الوضع الليلي",
                "تفعيل الوضع الداكن للتطبيق",
                FontAwesomeIcons.moon,
                trailing: Switch(
                  value: isDarkMode,
                  activeThumbColor: const Color(0xFFD0A871),
                  onChanged: (val) {
                    // Fix: Explicitly set the mode based on the new switch value.
                    context.read<ThemeCubit>().forceThemeMode(
                          val ? ThemeMode.dark : ThemeMode.light,
                        );
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
            onTap: _showMadhabDialog,
          ),

          // 4. Notifications & Adjustments
          _buildSectionHeader("التنبيهات والتعديلات"),
          _buildListTile(
            "إمالة الهاتف للصمت",
            "إيقاف صوت الأذان أو التنبيه عند قلب الهاتف",
            Icons.phonelink_ring_rounded,
            trailing: Switch(
              value: _flipToMute,
              activeThumbColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('flip_to_mute', val);
                setState(() => _flipToMute = val);
              },
            ),
          ),
          _buildListTile(
            "الإشعار الثابت",
            "عرض أوقات الصلاة دائمًا في شريط الإشعارات",
            FontAwesomeIcons.mobileScreen,
            trailing: Switch(
              value: _persistentNotification,
              activeThumbColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('persistent_notification_enabled', val);
                setState(() => _persistentNotification = val);
                _prayerService.scheduleNotifications();
              },
            ),
          ),
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
            "إشعارات الصلوات والأذان",
            "ضبط أصوات الأذان، الإقامة وتعديل المواقيت",
            FontAwesomeIcons.bell,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrayerAlarmsScreen()),
            ),
          ),
          // Advanced Notifications
          _buildSectionHeader("إعدادات متقدمة للتنبيهات"),
          _buildListTile(
            "تخطي الوضع الصامت",
            "تشغيل صوت الأذان والتنبيهات حتى لو كان الهاتف صامتاً",
            Icons.volume_off_rounded,
            trailing: Switch(
              value: _overrideSilent,
              activeThumbColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('override_silent_mode', val);
                setState(() => _overrideSilent = val);
              },
            ),
          ),
          _buildListTile(
            "مستوى صوت مخصص",
            "تحديد مستوى صوت ثابت للتنبيهات واستعادته تلقائياً",
            Icons.volume_up_rounded,
            trailing: Switch(
              value: _useCustomVolume,
              activeThumbColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('use_custom_notif_volume', val);
                setState(() => _useCustomVolume = val);
              },
            ),
          ),
          if (_useCustomVolume)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Row(
                children: [
                  Icon(Icons.volume_down, color: Colors.grey, size: 20.sp),
                  Expanded(
                    child: Slider(
                      value: _customVolume.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      activeColor: const Color(0xFFD0A871),
                      label: "$_customVolume%",
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('custom_notif_volume_level', val.toInt());
                        setState(() => _customVolume = val.toInt());
                      },
                    ),
                  ),
                  Icon(Icons.volume_up, color: const Color(0xFFD0A871), size: 20.sp),
                ],
              ),
            ),

          // 5. Backup & Data
          _buildSectionHeader("النسخ الاحتياطي والبيانات"),
          _buildListTile(
            "تصدير البيانات",
            "حفظ الإعدادات والعلامات المرجعية في ملف",
            Icons.upload_file_rounded,
            onTap: () async {
              showModalBottomSheet(
                context: context,
                backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                builder: (context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.share_rounded, color: const Color(0xFFD0A871), size: 24.sp),
                        title: Text("مشاركة الملف", style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp)),
                        onTap: () async {
                          if (mounted) Navigator.pop(context); // Close the bottom sheet first
                          
                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(child: CircularProgressIndicator(color: const Color(0xFFD0A871), strokeWidth: 3.w)),
                          );

                          final success = await BackupService.exportBackup();
                          
                          // ignore: use_build_context_synchronously
                          if (mounted) Navigator.pop(context); // Close loading

                          if (success) {
                            scaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(content: Text('تم فتح نافذة المشاركة')),
                            );
                          } else {
                             scaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(content: Text('فشل تصدير البيانات')),
                            );
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.save_alt_rounded, color: const Color(0xFFD0A871), size: 24.sp),
                        title: Text("حفظ على الجهاز", style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp)),
                        onTap: () async {
                          if (mounted) Navigator.pop(context);

                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(child: CircularProgressIndicator(color: const Color(0xFFD0A871), strokeWidth: 3.w)),
                          );

                          final success = await BackupService.saveBackupToDevice();

                          // ignore: use_build_context_synchronously
                          if (mounted) Navigator.pop(context); // Close loading

                          if (success) {
                            scaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(content: Text('تم حفظ البيانات بنجاح')),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 16.h),
                    ],
                  );
                },
              );
            },
          ),
          _buildListTile(
            "استيراد البيانات",
            "استعادة الإعدادات من ملف نسخة احتياطية",
            Icons.file_download_rounded,
            onTap: () async {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator(color: const Color(0xFFD0A871), strokeWidth: 3.w)),
              );

              final success = await BackupService.importBackup();

              // ignore: use_build_context_synchronously
              if (mounted) Navigator.pop(context); // Close loading

              if (success) {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('تم استيراد البيانات بنجاح، يرجى إعادة تشغيل التطبيق')),
                );
                setState(() {
                  _is24Hour = _prayerService.is24Hour;
                  _hijriOffset = _prayerService.manualHijriOffset;
                  _localHijriDelta = _prayerService.localHijriDelta;
                });
                _loadSettings();
                _showRestartDialog();
              } else {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('فشل استيراد البيانات أو تم إلغاء العملية')),
                );
              }
            },
          ),
          _buildListTile(
            "مزامنة جوجل درايف",
            _googleEmail != null 
                ? "مرتبط بـ: $_googleEmail\nآخر مزامنة: ${_formatSyncTime(_lastSyncTime)}" 
                : "حفظ واستعادة الإعدادات تلقائياً من سحابة جوجل",
            FontAwesomeIcons.googleDrive,
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator(color: const Color(0xFFD0A871), strokeWidth: 3.w)),
              );
              final success = await BackupService.syncToDrive();
              final email = await BackupService.getSignedInEmail();
              final syncTime = await BackupService.getLastSyncTime();
              if (mounted) {
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.pop(context);

                setState(() {
                  _googleEmail = email;
                  _lastSyncTime = syncTime;
                });
              }
              
              if (success) {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('تمت المزامنة مع جوجل درايف بنجاح')),
                );
              } else {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('فشلت المزامنة. تأكد من تفعيل خدمة Google Drive ومنح الصلاحيات المطلوبة.')),
                );
              }
            },
          ),
          _buildListTile(
            "استعادة من جوجل درايف",
            "تحميل آخر نسخة محفوظة من السحابة",
            Icons.cloud_download_rounded,
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator(color: const Color(0xFFD0A871), strokeWidth: 3.w)),
              );
              final success = await BackupService.syncFromDrive();
              final email = await BackupService.getSignedInEmail();
              final syncTime = await BackupService.getLastSyncTime();
              if (mounted) {
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.pop(context);

                setState(() {
                  _googleEmail = email;
                  _lastSyncTime = syncTime;
                });
              }

              if (success) {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('تمت استعادة البيانات من جوجل درايف بنجاح')),
                );
                setState(() {
                  _is24Hour = _prayerService.is24Hour;
                  _hijriOffset = _prayerService.manualHijriOffset;
                  _localHijriDelta = _prayerService.localHijriDelta;
                });
                _loadSettings();
                _showRestartDialog();
              } else {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('فشلت الاستعادة. قد لا يوجد ملف نسخة احتياطية أو تم رفض الوصول.')),
                );
              }
            },
          ),
          _buildListTile(
            "المزامنة التلقائية يومياً",
            "حفظ الإعدادات تلقائياً في السحاب يومياً بعد صلاة العشاء بساعة",
            Icons.sync_rounded,
            trailing: Switch(
              value: _autoSyncDrive,
              activeThumbColor: const Color(0xFFD0A871),
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('auto_sync_drive', val);
                await BackupService.toggleAutoSync(val);
                setState(() => _autoSyncDrive = val);
                if (val && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تفعيل المزامنة التلقائية اليومية')),
                  );
                }
              },
            ),
          ),

          // 6. Support
          _buildSectionHeader("الدعم"),
          _buildListTile(
            "تواصل معنا",
            "أرسل لنا ملاحظاتك أو استفساراتك",
            Icons.mail_outline,
            onTap: () => _showContactSheet(),
          ),
          _buildListTile(
            "عن التطبيق",
            "الإصدار 1.1.0",
            Icons.info_outline,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "عباد الرحمن",
                applicationVersion: "1.1.0",
                applicationIcon: Image.asset(
                  "assets/images/logo.png",
                  width: 50.w,
                  height: 50.w,
                ),
                children: [
                  Text(
                    "تطبيق إسلامي شامل يهدف لخدمة المسلمين في شتى بقاع الأرض.",
                    style: TextStyle(fontSize: 14.sp, fontFamily: 'Cairo'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Contact bottom-sheet ────────────────────────────────────────────────
  void _showContactSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'تواصل معنا',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD0A871),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'نسعد بسماع ملاحظاتك وأسئلتك',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.sp,
                    color: subColor,
                  ),
                ),
                SizedBox(height: 24.h),

                // ── WhatsApp ──────────────────────────────────────────
                _contactTile(
                  icon: Icons.chat_rounded,
                  iconColor: const Color(0xFF25D366),
                  title: 'واتساب',
                  subtitle: '+201552323060',
                  textColor: textColor,
                  subColor: subColor,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final uri = Uri.parse(
                      'https://wa.me/201552323060'
                      '?text=${Uri.encodeComponent('السلام عليكم،\nأكتب إليكم من تطبيق عباد الرحمن.\n\n')}',
                    );
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لا يمكن فتح واتساب، يرجى التأكد من تثبيته.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                SizedBox(height: 12.h),

                // ── Email ─────────────────────────────────────────────
                _contactTile(
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFFD0A871),
                  title: 'البريد الإلكتروني',
                  subtitle: 'yousefahmedfawzy@gmail.com',
                  textColor: textColor,
                  subColor: subColor,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final uri = Uri(
                      scheme: 'mailto',
                      path: 'yousefahmedfawzy@gmail.com',
                      queryParameters: {
                        'subject': 'ملاحظة من تطبيق عباد الرحمن',
                        'body': 'السلام عليكم،\nأكتب إليكم بخصوص:\n\n',
                      },
                    );
                    try {
                      await launchUrl(uri);
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لا يمكن فتح البريد، يرجى التأكد من تثبيت تطبيق بريد.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _contactTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
            width: 1.0.w,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.sp,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14.sp,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          "اكتملت الاستعادة",
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18.sp, color: const Color(0xFFD0A871)),
        ),
        content: Text(
          "تم استعادة البيانات والختمة والإعدادات بنجاح. يجب إغلاق التطبيق وإعادة فتحه ليتم تطبيق التغييرات وإعادة جدولة المنبهات.",
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14.sp),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: () => exit(0),
              child: Text("إغلاق التطبيق الآن", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ),
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
        color: isDark ? const Color(0xFF000000) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1.0.w),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD0A871), size: 20.sp),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontFamily: 'Cairo',
            fontSize: 12.sp,
          ),
        ),
        trailing:
            trailing ??
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16.sp),
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
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(16.w),
          children: methods.entries.map((entry) {
            return ListTile(
              title: Text(
                entry.value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Cairo',
                  fontSize: 14.sp,
                ),
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                await _prayerService.saveMethod(entry.key);
                setState(() {});
                if (mounted) navigator.pop();
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showMadhabDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final madhabs = {
      'shafi': 'الشافعي (الجمهور)',
      'hanafi': 'الحنفي',
    };

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(16.w),
          children: madhabs.entries.map((entry) {
            return ListTile(
              title: Text(
                entry.value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Cairo',
                  fontSize: 14.sp,
                ),
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                await _prayerService.saveMadhab(entry.key);
                setState(() {});
                if (mounted) navigator.pop();
              },
            );
          }).toList(),
        );
      },
    );
  }
}
