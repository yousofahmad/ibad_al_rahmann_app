import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'splash_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool isNotificationGranted = false;
  bool isExactAlarmGranted   = true; // assume granted; corrected in _checkPermissions

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  // ── Status Check ────────────────────────────────────────────────────────────
  Future<void> _checkPermissions() async {
    final notifStatus = await Permission.notification.status;
    final exactStatus = await Permission.scheduleExactAlarm.status;
    if (!mounted) return;
    setState(() {
      isNotificationGranted = notifStatus.isGranted;
      isExactAlarmGranted   = exactStatus.isGranted;
    });

    // Auto-proceed when both are granted
    if (isNotificationGranted && isExactAlarmGranted) {
      final prefs = CacheHelper.prefs;
      await prefs.setBool('notif_permission_decided', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    }
  }

  // ── Request: POST_NOTIFICATIONS ─────────────────────────────────────────────
  Future<void> _requestNotification() async {
    // Rationale dialog before the system dialog
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text(
            'تنويه هام',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD0A871),
              fontSize: 18.sp,
            ),
            textDirection: TextDirection.rtl,
          ),
          content: Text(
            'نحتاج إذن الإشعارات فقط لتذكيرك بأوقات الصلاة والأذكار.\n\n'
            'تطبيقنا يحترم خصوصيتك ولا يجمع أي بيانات، وهذا الإذن ضروري لخدمتك.',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.black87,
              fontSize: 14.sp,
            ),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'استمرار',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: const Color(0xFFD0A871),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final status = await Permission.notification.request();

    if (status.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text(
            'الإذن مطلوب',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
            textDirection: TextDirection.rtl,
          ),
          content: Text(
            'يجب تفعيل الإشعارات من إعدادات الهاتف لضمان عمل التطبيق.',
            style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Colors.grey,
                  fontSize: 14.sp,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: Text(
                'الإعدادات',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: const Color(0xFFD0A871),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      await _checkPermissions();
    }
  }

  // ── Request: SCHEDULE_EXACT_ALARM ───────────────────────────────────────────
  Future<void> _requestExactAlarm() async {
    final status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) {
      await _checkPermissions();
    } else {
      // On Android 12+ the system may send to settings directly.
      // If still denied, open settings manually.
      await openAppSettings();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header icon
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security_rounded,
                  size: 60.sp,
                  color: const Color(0xFFD0A871),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'الإعدادات المطلوبة',
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'إذنان فقط لضمان وصول الأذان في موعده',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 14.sp,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 32.h),

              // ── Card 1: Notifications ──
              _PermissionCard(
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.green,
                title: 'إشعارات الصلاة والأذكار',
                subtitle: 'ضروري لإعلامك بأوقات الأذان والأذكار اليومية',
                isGranted: isNotificationGranted,
                buttonLabel: 'سماح بالإشعارات',
                onTap: isNotificationGranted ? null : _requestNotification,
              ),
              SizedBox(height: 14.h),

              // ── Card 2: Exact Alarm ──
              _PermissionCard(
                icon: Icons.alarm_on_rounded,
                iconColor: const Color(0xFFD0A871),
                title: 'دقة مواعيد الأذان',
                subtitle: 'يضمن وصول الأذان في وقته الدقيق حتى في وضع توفير الطاقة',
                isGranted: isExactAlarmGranted,
                buttonLabel: 'سماح بالتنبيه الدقيق',
                onTap: isExactAlarmGranted ? null : _requestExactAlarm,
              ),
              SizedBox(height: 32.h),

              // ── Proceed Button ──
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: isNotificationGranted
                      ? () async {
                          final nav   = Navigator.of(context);
                          final prefs = CacheHelper.prefs;
                          await prefs.setBool('notif_permission_decided', true);
                          if (!mounted) return;
                          nav.pushReplacement(
                            MaterialPageRoute(builder: (_) => const SplashScreen()),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0A871),
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    isNotificationGranted ? 'متابعة' : 'يرجى السماح بالإشعارات أولاً',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: isNotificationGranted ? Colors.white : Colors.grey,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // ── Skip link ──
              TextButton(
                onPressed: () async {
                  final nav   = Navigator.of(context);
                  final prefs = CacheHelper.prefs;
                  await prefs.setBool('notif_permission_decided', true);
                  if (!mounted) return;
                  nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                  );
                },
                child: Text(
                  'دخول التطبيق بدون تنبيهات',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.grey,
                    fontSize: 13.sp,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable Permission Card Widget ──────────────────────────────────────────
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final bool     isGranted;
  final String   buttonLabel;
  final VoidCallback? onTap;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.buttonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isGranted ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withValues(alpha: 0.12)
                  : iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? Colors.green : iconColor,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: Colors.black87,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                SizedBox(height: 3.h),
                Text(
                  isGranted ? 'تم السماح ✓' : subtitle,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 12.sp,
                    color: isGranted ? Colors.green : Colors.grey.shade600,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          // Action button
          if (!isGranted) ...[
            SizedBox(width: 8.w),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: iconColor.withValues(alpha: 0.1),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                buttonLabel,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: iconColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
