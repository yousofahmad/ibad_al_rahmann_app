import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
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
          title: const Text(
            "تنويه هام",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD0A871),
            ),
            textDirection: TextDirection.rtl,
          ),
          content: const Text(
            "نحتاج إذن الإشعارات فقط لتذكيرك بأوقات الصلاة والأذكار.\n\n"
            "تطبيقنا يحترم خصوصيتك ولا يجمع أي بيانات، وهذا الإذن ضروري لخدمتك.",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.black87,
            ),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "استمرار",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Color(0xFFD0A871),
                  fontWeight: FontWeight.bold,
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
            title: const Text(
              "الإذن مطلوب",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            content: const Text(
              "يجب تفعيل الإشعارات من إعدادات الهاتف لضمان عمل التطبيق.",
              style: TextStyle(fontFamily: AppConsts.expoArabic),
              textDirection: TextDirection.rtl,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "إلغاء",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.grey,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text(
                  "الإعدادات",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Color(0xFFD0A871),
                    fontWeight: FontWeight.bold,
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
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "تفعيل التنبيهات",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "حتى يصلك تذكير الأذكار والرقية في موعدها",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // زر التفعيل
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0A871),
                  ),
                  child: const Text(
                    "سماح بالإشعارات",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              if (isNotificationGranted) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                  ),
                  child: const Text(
                    "دخول التطبيق",
                    style: TextStyle(fontFamily: AppConsts.expoArabic),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
