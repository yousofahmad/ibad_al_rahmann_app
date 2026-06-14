import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool isNotificationGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.notification.status;
    setState(() {
      isNotificationGranted = status.isGranted;
    });

    if (isNotificationGranted && mounted) {
      // Mark decision as made when user grants permission
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_permission_decided', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    }
  }

  Future<void> _requestPermission() async {
    // Show Pre-Permission Dialog
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text(
            "تنويه هام",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD0A871),
              fontSize: 18.sp,
            ),
            textDirection: TextDirection.rtl,
          ),
          content: Text(
            "نحتاج إذن الإشعارات فقط لتذكيرك بأوقات الصلاة والأذكار.\n\n"
            "تطبيقنا يحترم خصوصيتك ولا يجمع أي بيانات، وهذا الإذن ضروري لخدمتك.",
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
                "استمرار",
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

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
            title: Text(
              "الإذن مطلوب",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
              textDirection: TextDirection.rtl,
            ),
            content: Text(
              "يجب تفعيل الإشعارات من إعدادات الهاتف لضمان عمل التطبيق.",
              style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 14.sp),
              textDirection: TextDirection.rtl,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "إلغاء",
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
                  "الإعدادات",
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
    } else {
      _checkPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(25.0.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 60.sp,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 25.h),
              Text(
                "تفعيل التنبيهات",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                "حتى يصلك تذكير الأذكار والرقية في موعدها",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 16.sp,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 40.h),

              // زر التفعيل
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0A871),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    "سماح بالإشعارات",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Colors.white,
                      fontSize: 18.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15.h),
              // زر التخطي
              TextButton(
                onPressed: () async {
                  // Save decision so screen won't show again
                  final nav = Navigator.of(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notif_permission_decided', true);
                  if (!mounted) return;
                  nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                  );
                },
                child: Text(
                  "دخول التطبيق بدون تنبيهات",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.grey,
                    fontSize: 14.sp,
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
