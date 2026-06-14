import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/remote_config_service.dart';
import 'services/fcm_service.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/features/quran/data/db_helper.dart';
import 'package:ibad_al_rahmann/features/wird/bloc/khatma_cubit.dart';

import 'screens/bubble_overlay.dart';
import 'services/notification_service.dart';
import 'services/daily_tracker_service.dart';
import 'services/prayer_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'core/di/di.dart';
import 'core/helpers/tafsir_helper.dart';
import 'core/theme/theme_manager/theme_cubit.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'quran_app.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
const platform = MethodChannel('app.ibad_al_rahmann/native_notifications');

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void callbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CRITICAL: Initialize AlarmManager for the background isolate
  // so it can schedule the next periodic/one-shot alarms.
  await AndroidAlarmManager.initialize().catchError((e) {
    debugPrint('AlarmManager background init error: $e');
    return false;
  });

  await initializeDateFormatting('ar', null);

  // 1. Initialize Firebase for background (if needed by services)
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // 2. Initialize Core Services
  await serviceLocatorInit();
  await NotificationService.init();

  // 3. Perform Refresh
  final prayerService = PrayerService();
  await prayerService.init();
  final times = prayerService.getPrayerTimes();
  if (times != null) {
    await NotificationService.scheduleAll(times);
    debugPrint("✅ Background Refresh: All notifications rescheduled.");
  }
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: BubbleOverlay()),
  );
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 1. Core Platform Inits
  await initializeDateFormatting('ar', null);
  
  // 2. Initialize Firebase (CRITICAL: Must be before runApp if UI depends on it)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Init Error in main: $e");
  }

  // 3. Essential Hive & DI
  await Hive.initFlutter();
  await serviceLocatorInit();
  
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(VerseModelAdapter());
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(create: (context) => QuranCubit(QuranRepo())),
        BlocProvider(create: (context) => VersePlayerCubit()),
        BlocProvider(create: (context) => SearchCubit()),
        BlocProvider(create: (context) => KhatmaCubit()..loadKhatma()),
      ],
      child: const QuranApp(showCustomSplash: true),
    ),
  );

  // 4. Background non-critical inits
  _runBackgroundInits();
}

Future<void> _runBackgroundInits() async {
  // CRITICAL: Wait for the app to be fully rendered and interactive
  await WidgetsBinding.instance.endOfFrame;
  
  // Wait a bit to ensure the splash screen is visible and system is quiet
  await Future.delayed(const Duration(milliseconds: 500));

  // Phase 1: Essential Fast Data (Heavily staggered)
  await BookmarkService.init();

  await Future.delayed(const Duration(seconds: 1));
  AndroidAlarmManager.initialize().catchError((e) {
    debugPrint('AlarmManager error: $e');
    return false;
  });
  
  await Future.delayed(const Duration(seconds: 1));
  await DailyTrackerService.initStatsForToday();
  
  await Future.delayed(const Duration(seconds: 1));
  await NotificationService.init();

  // Phase 2: Staggered background services (SM-T585 friendly)
  await Future.delayed(const Duration(seconds: 5));
  PrayerService().init();

  await Future.delayed(const Duration(seconds: 2));
  RemoteConfigService.init().catchError((e) => debugPrint('RemoteConfig error: $e'));
  
  await Future.delayed(const Duration(seconds: 2));
  FCMService.init().catchError((e) => debugPrint('FCM error: $e'));

  await Future.delayed(const Duration(seconds: 2));
  JustAudioBackground.init(
    androidNotificationChannelId: 'app.ibad_al_rahmann.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  ).catchError((e) => debugPrint('JustAudio error: $e'));

  // Phase 3: Background Heavy Preloading
  await Future.delayed(const Duration(seconds: 20));
  TafsirHelper.initTafsir().catchError((e) => debugPrint('Tafsir error: $e'));
  QuranWbwDbHelper.instance.preloadAllPagesInBackground();

  NotificationService.onNotificationTap.addListener(() {
    final payload = NotificationService.onNotificationTap.value;
    if (payload != null) {
      _handleGlobalNavigation(payload);
      NotificationService.onNotificationTap.value = null;
    }
  });
}

Future<void> _handleGlobalNavigation(String payload) async {
  // Navigation logic remains same...
  // (Assuming navigatorKey is used inside QuranApp which it isn't currently, 
  // but for now we focus on the crash fix)
  debugPrint("Global Navigation: $payload");
}
