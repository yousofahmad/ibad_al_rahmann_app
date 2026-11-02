import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import '../services/app_logger.dart';
import 'permissions_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'package:ibad_al_rahmann/main.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;

      final imageStopwatch = Stopwatch()..start();
      AppLogger.logEvent('Splash', 'image_precache_started');
      unawaited(
        precacheImage(
          const AssetImage('assets/images/mosque_bottom.webp'),
          context,
        )
            .then((_) {
              imageStopwatch.stop();
              AppLogger.logEvent('Splash', 'image_precache_finished', {
                'outcome': 'success',
                'elapsedMs': imageStopwatch.elapsedMilliseconds,
              });
            })
            .catchError((error) {
              imageStopwatch.stop();
              AppLogger.logEvent('Splash', 'image_precache_finished', {
                'outcome': 'failure',
                'elapsedMs': imageStopwatch.elapsedMilliseconds,
                'errorType': error.runtimeType,
              });
              debugPrint('Splash image precache error type: ${error.runtimeType}');
            }),
      );

      // Do not keep the native splash up while the decorative image decodes.
      FlutterNativeSplash.remove();
      unawaited(_checkUser());
    }
  }

  Future<void> _checkUser() async {
    NotificationService.nativeLog('SplashScreen._checkUser: started');

    // Keep the ordinary splash visible briefly, but don't delay notification navigation.
    final timerFuture = Future.delayed(const Duration(milliseconds: 800));

    final payloadFuture = NotificationService.checkLaunchPayload();
    final permissionFuture = Permission.notification.status;

    final results = await Future.wait([payloadFuture, permissionFuture]);

    final String? startPayload = results[0] as String?;
    final PermissionStatus notificationStatus = results[1] as PermissionStatus;
    if (startPayload == null) await timerFuture;

    NotificationService.nativeLog(
      'SplashScreen._checkUser: startPayload=$startPayload',
    );

    final prefs = CacheHelper.prefs;

    if (!mounted) {
      NotificationService.nativeLog(
        'SplashScreen._checkUser: not mounted, abort',
      );
      return;
    }

    // A. Handle Payload (Click from notification) — FAST PATH (instant navigation)
    if (startPayload != null) {
      final payload = startPayload;
      NotificationService.nativeLog(
        'SplashScreen: fast-path navigation for payload=$payload',
      );
      AppLogger.log(
        'SplashScreen',
        'fast-path navigation for payload=$payload',
      );
      // Push HomeScreen underneath
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      // Immediately navigate to payload on next frame without waiting
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleGlobalNavigation(payload);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. الخلفية
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              'assets/images/mosque_bottom.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.white);
              },
            ),
          ),

          // 2. المحتوى (الاسم والآية)
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
