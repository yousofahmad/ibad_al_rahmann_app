import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
// تأكد إن أسماء الملفات دي مطابقة للي عندك بالظبط (ممكن تكون بشرطة - أو underscore _)
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import 'azkar_page.dart';
import 'permissions_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'package:ibad_al_rahmann/features/qadaa/ui/qadaa_screen.dart';
import 'package:ibad_al_rahmann/features/quran/ui/quran_screen.dart';
import 'ramadan_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Remove native splash as early as possible to show the custom lanterns
      FlutterNativeSplash.remove();
      _checkUser();
    }
  }

  Future<void> _checkUser() async {
    // 1. Minimum visibility timer for the Lanterns splash
    final timerFuture = Future.delayed(const Duration(milliseconds: 500));

    // 2. Check Launch Payload (Parallel)
    final payloadFuture = NotificationService.checkLaunchPayload();

    // 3. Check Permissions (Parallel)
    final permissionFuture = Permission.notification.status;

    // Wait for critical logic only
    final results = await Future.wait([
      timerFuture,
      payloadFuture,
      permissionFuture,
    ]);

    // Extract results
    final String? startPayload = results[1] as String?;
    final PermissionStatus notificationStatus = results[2] as PermissionStatus;
    
    // Defer SharedPreferences a bit to avoid CPU spike
    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    // A. Handle Payload (Click from terminated)
    if (startPayload != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      // Wait a bit then push payload
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (startPayload == 'morning' || startPayload == 'sabah') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AzkarPage(
                title: 'أذكار الصباح',
                jsonFile: 'morning.json',
                image: 'assets/images/morning.jpg',
              ),
            ),
          );
        } else if (startPayload == 'evening' || startPayload == 'masaa') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AzkarPage(
                title: 'أذكار المساء',
                jsonFile: 'evening.json',
                image: 'assets/images/night.jpg',
              ),
            ),
          );
        } else if (startPayload == 'qadaa') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QadaaScreen()),
          );
        } else if (startPayload == 'kahf') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const QuranScreen(isKahfMode: true),
            ),
          );
        } else if (startPayload == 'fasting') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RamadanScreen()),
          );
        }
      });
      return;
    }

    // B. Check Permissions
    final bool permissionDecided =
        prefs.getBool('notif_permission_decided') ?? false;
    if (!permissionDecided &&
        (notificationStatus.isDenied ||
            notificationStatus.isPermanentlyDenied)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PermissionsScreen()),
      );
      return;
    }

    // C. Check Onboarding
    bool seen = prefs.getBool('seenOnboarding') ?? false;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            seen ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // لون أبيض احتياطي
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. الخلفية (صورة المسجد الأصلية بتاعتك)
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              'assets/images/mosque_bottom.webp', // تأكد إن الصورة دي موجودة في مجلد الصور
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.white);
              },
            ),
          ),

          // 2. المحتوى (الاسم والآية) زي ما كان
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'عِبَادُ الرَّحْمَٰن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConsts.motoNastaliq,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD0A871),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
