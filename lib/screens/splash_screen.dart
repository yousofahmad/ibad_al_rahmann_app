import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
// تأكد إن أسماء الملفات دي مطابقة للي عندك بالظبط (ممكن تكون بشرطة - أو underscore _)
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import 'azkar_page.dart';
import 'permissions_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

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
      _checkUser();
    }
  }

  Future<void> _precacheImages() async {
    try {
      await Future.wait([
        precacheImage(const AssetImage('assets/images/morning.jpg'), context),
        precacheImage(const AssetImage('assets/images/night.jpg'), context),
        precacheImage(const AssetImage('assets/images/mosque.jpg'), context),
        precacheImage(
          const AssetImage("assets/images/mosque_bottom.webp"),
          context,
        ),
        precacheImage(
          const AssetImage(
            'assets/images/pngtree-luxury-islamic-prayer-beads-macro-png-image_18712828.webp',
          ),
          context,
        ),
      ]);
    } catch (e) {
      debugPrint("خطأ في تحميل الصور: $e");
    }
  }

  Future<void> _checkUser() async {
    // 1. Start Timer (Parallel)
    final timerFuture = Future.delayed(const Duration(milliseconds: 1500));

    // 2. Precache Images (Parallel)
    final imageFuture = _precacheImages();

    // 3. Check Launch Payload (Parallel)
    final payloadFuture = NotificationService.checkLaunchPayload();

    // 4. Check Permissions (Parallel)
    final permissionFuture = Permission.notification.status;

    // Wait for all checks
    final results = await Future.wait([
      timerFuture,
      imageFuture,
      payloadFuture,
      permissionFuture,
    ]);

    // Extract results
    // results[0] is timer, results[1] is images
    final String? startPayload = results[2] as String?;
    final PermissionStatus notificationStatus = results[3] as PermissionStatus;
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    // A. Handle Payload (Click from terminated)
    if (startPayload != null) {
      // Navigate to Home first, then handle payload (using global navigator or passing arg)
      // Since we are in Splash, we can pushAndRemoveUntil Home, then Push Payload
      // But _handleGlobalNavigation in main.dart uses navigatorKey.
      // We will access it via main's global methods if possible or replicate simple logic here.

      // Let's use the navigatorKey from main if accessible, or just pushReplacement logic.
      // Simpler: Go to Home, then let Home/Main handle it?
      // Actually, NotificationService.onNotificationTap might have already fired if we set it up early?
      // No, checkLaunchPayload is for cold start.

      debugPrint("Splash: Found payload $startPayload");
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      // Wait a bit then push payload
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (startPayload == 'morning') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AzkarPage(
                title: 'أذكار الصباح',
                jsonFile: 'morning.json',
                image: 'assets/images/morning_background.webp',
              ),
            ),
          );
        } else if (startPayload == 'evening') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AzkarPage(
                title: 'أذكار المساء',
                jsonFile: 'evening.json',
                image: 'assets/images/evening_background.webp',
              ),
            ),
          );
        }
      });
      return;
    }

    // B. Check Permissions
    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      // Check if we should ask (Android 13+ requires explicit ask, before 13 it's granted by default usually)
      // If denied, go to PermissionsScreen
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
