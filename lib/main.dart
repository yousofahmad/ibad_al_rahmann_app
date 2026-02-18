import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
// import 'package:timezone/timezone.dart' as tz; // Unused
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';

import 'screens/splash_screen.dart';

import 'screens/azkar_page.dart';
import 'screens/home_screen.dart';
import 'screens/ruqyah_screen.dart';
import 'services/notification_service.dart';
import 'services/daily_tracker_service.dart';
import 'services/prayer_service.dart';
import 'features/quran/ui/quran_screen.dart';

import 'core/di/di.dart';
import 'core/theme/theme_manager/theme_cubit.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const platform = MethodChannel('com.example.azkar/bubble');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Timezones
  tz.initializeTimeZones();
  // Note: Without flutter_timezone, we rely on default local or UTC.
  // Ideally: tz.setLocalLocation(tz.getLocation('Africa/Cairo')); manually or via user setting.

  // Initialize Services
  await NotificationService.init();
  await PrayerService().init();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(VerseModelAdapter());
  await BookmarkService.init();

  // إعداد مستمع الإشعارات العالمي
  NotificationService.onNotificationTap.addListener(() {
    final payload = NotificationService.onNotificationTap.value;
    if (payload != null) {
      debugPrint("Global Listener: Navigating to $payload");
      _handleGlobalNavigation(payload);
      NotificationService.onNotificationTap.value = null;
    }
  });

  try {
    await NotificationService.init();
    await NotificationService.scheduleDefaults();
  } catch (e) {
    debugPrint("Error init notifications: $e");
  }

  // Initialize Daily Stats for "Hasib Nafsak"
  await DailyTrackerService.initStatsForToday();

  // Initialize DI
  await serviceLocatorInit();

  // Schedule Prayer Notifications
  try {
    final prayerService = PrayerService();
    await prayerService.init(); // Init loads settings & location & schedules
  } catch (e) {
    debugPrint("Error init prayer service: $e");
  }

  runApp(const MyApp());
}

void _handleGlobalNavigation(String payload) {
  if (navigatorKey.currentState == null) return;

  // Navigate based on payload
  Widget? targetScreen;

  if (payload == 'sabah') {
    targetScreen = const AzkarPage(
      title: 'أذكار الصباح',
      jsonFile: 'morning.json',
      image: 'assets/images/morning.jpg',
    );
  } else if (payload == 'masaa') {
    targetScreen = const AzkarPage(
      title: 'أذكار المساء',
      jsonFile: 'evening.json',
      image: 'assets/images/night.jpg',
    );
  } else if (payload == 'ruqyah') {
    targetScreen = const RuqyahScreen();
  } else if (payload.startsWith('wird')) {
    int? page;
    try {
      final parts = payload.split(':');
      if (parts.length > 1) page = int.tryParse(parts[1]);
    } catch (_) {}
    targetScreen = QuranScreen(initialPage: page);
  }
  // For prayer payloads (fajr, dhuhr, etc.) and others, just go to HomeScreen

  // Clear stack and go to Home, then push target if any
  navigatorKey.currentState!.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );

  if (targetScreen != null) {
    navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => targetScreen!),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(
        392.72,
        800.72,
      ), // Updated to match Quran Source App
      minTextAdapt: true,
      splitScreenMode: false, // Updated to match Source
      builder: (_, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => ThemeCubit()),
            BlocProvider(create: (context) => QuranCubit(QuranRepo())),
            BlocProvider(create: (context) => VersePlayerCubit()),
            BlocProvider(create: (context) => SearchCubit()),
          ],
          child: BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Ibad Al-Rahman',
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('ar', 'AE')],
                locale: const Locale('ar', 'AE'),
                themeMode: state.mode,
                theme: state.theme.light,
                darkTheme: state.theme.dark,
                navigatorKey: navigatorKey,
                home: const SplashScreen(),
              );
            },
          ),
        );
      },
    );
  }
}
