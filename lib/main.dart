import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
// import 'package:timezone/timezone.dart' as tz; // Unused
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';

import 'screens/splash_screen.dart';

import 'screens/azkar_page.dart';
import 'screens/home_screen.dart';
import 'screens/ruqyah_screen.dart';
import 'services/notification_service.dart';
import 'services/daily_tracker_service.dart';
import 'services/prayer_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'features/wird/ui/wird_dashboard_screen.dart';
import 'features/wird/ui/isolated_wird_screen.dart';
import 'features/wird/data/khatma_model.dart';

import 'core/di/di.dart';
import 'core/helpers/tafsir_helper.dart';
import 'core/theme/theme_manager/theme_cubit.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const platform = MethodChannel(
  'com.example.ibad_al_rahmann/native_notifications',
);

@pragma('vm:entry-point')
void callbackDispatcher() {
  // This is used by background services like android_alarm_manager
  WidgetsFlutterBinding.ensureInitialized();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Date Formatting (REQUIRED for intl DateFormat)
  await initializeDateFormatting('ar_SA', null);

  // Initialize Android Alarm Manager
  await AndroidAlarmManager.initialize();

  // Initialize Timezones
  tz.initializeTimeZones();

  // Initialize JustAudioBackground
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  // Initialize Services - SINGLE CALL each
  await NotificationService.init();
  final prayerService = PrayerService();
  await prayerService.init();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(VerseModelAdapter());
  await BookmarkService.init();

  // Initialize Daily Stats
  await DailyTrackerService.initStatsForToday();

  // Initialize DI & Tafsir
  await serviceLocatorInit();
  await TafsirHelper.initTafsir();

  // إعداد مستمع الإشعارات العالمي
  NotificationService.onNotificationTap.addListener(() {
    final payload = NotificationService.onNotificationTap.value;
    if (payload != null) {
      debugPrint("Global Listener: Navigating to $payload");
      _handleGlobalNavigation(payload);
      NotificationService.onNotificationTap.value = null;
    }
  });

  runApp(const MyApp());
}

Future<void> _handleGlobalNavigation(String payload) async {
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
    // Load khatma data to get current wird info
    try {
      final prefs = await SharedPreferences.getInstance();
      KhatmaModel? targetKhatma;
      final parts = payload.split(':');
      // Pattern: wird:{startPage}:{khatmaId}

      if (parts.length >= 3) {
        final targetId = parts[2];
        final data = prefs.getString('khatma_$targetId');
        if (data != null) {
          targetKhatma = KhatmaModel.fromJson(jsonDecode(data));
        }
      }

      // Fallback: If no khatmaId supplied or not found, try getting any active khatma
      if (targetKhatma == null) {
        final keys = prefs.getKeys();
        for (String key in keys) {
          if (key.startsWith('khatma_')) {
            final data = prefs.getString(key);
            if (data != null) {
              targetKhatma = KhatmaModel.fromJson(jsonDecode(data));
              break;
            }
          }
        }
      }

      if (targetKhatma != null) {
        int targetIndex = targetKhatma.currentWirdIndex;
        if (parts.length > 1) {
          final targetStartPage = int.tryParse(parts[1]);
          if (targetStartPage != null) {
            final foundIndex = targetKhatma.wirds.indexWhere(
              (w) => w.startPage == targetStartPage,
            );
            if (foundIndex != -1) targetIndex = foundIndex;
          }
        }

        if (targetIndex < targetKhatma.wirds.length) {
          final wird = targetKhatma.wirds[targetIndex];
          targetScreen = IsolatedWirdScreen(
            khatmaId: targetKhatma.id,
            wirdIndex: targetIndex,
            targetStartPage: wird.startPage,
            targetEndPage: wird.endPage,
          );
        }
      }
    } catch (_) {}
    // Fallback if no khatma data or error
    targetScreen ??= const WirdDashboardScreen();
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
            BlocProvider(create: (context) => KhatmaCubit()..loadKhatma()),
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
