import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
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
import 'screens/tasbeeh_screen.dart';
import 'services/backup_service.dart';
import 'services/app_logger.dart';

import 'core/di/di.dart';
import 'core/helpers/tafsir_helper.dart';
import 'core/theme/theme_manager/theme_cubit.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

// Screens for Global Navigation
import 'package:ibad_al_rahmann/screens/azkar_page.dart';
import 'package:ibad_al_rahmann/screens/ruqyah_screen.dart';
import 'package:ibad_al_rahmann/features/wird/ui/wird_dashboard_screen.dart';
import 'package:ibad_al_rahmann/features/wird/ui/isolated_wird_screen.dart';
import 'package:ibad_al_rahmann/screens/fasting_days_screen.dart';
import 'package:ibad_al_rahmann/screens/prayer_times_screen.dart';

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
  await CacheHelper.init();
  await AppLogger.init(); // ← يجب أن يكون بعد CacheHelper مباشرةً
  AppLogger.log('main', 'app started — Flutter init complete');
  
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
  await Hive.openBox('appDataBox');
  await serviceLocatorInit();
  
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(VerseModelAdapter());
  }

  // 4. Init notification channel BEFORE runApp so the handler is ready
  //    when SplashScreen calls checkLaunchPayload() during cold-start navigation
  await NotificationService.init();

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

  // 5. Background non-critical inits
  _runBackgroundInits();
}


Future<void> _runBackgroundInits() async {
  await WidgetsBinding.instance.endOfFrame;
  await Future.delayed(const Duration(milliseconds: 500));

  AppLogger.log('BgInit', 'start');

  NotificationService.nativeLog('_runBackgroundInits: registering listener');
  NotificationService.onNotificationTap.addListener(() {
    final payload = NotificationService.onNotificationTap.value;
    NotificationService.nativeLog('listener fired: payload=$payload');
    AppLogger.log('NavListener', 'payload=$payload');
    if (payload != null) {
      handleGlobalNavigation(payload);
      Future.microtask(() {
        NotificationService.onNotificationTap.value = null;
      });
    }
  });

  final pendingPayload = NotificationService.onNotificationTap.value;
  NotificationService.nativeLog('_runBackgroundInits: pendingPayload=$pendingPayload');
  if (pendingPayload != null) {
    debugPrint("Flushing pre-listener payload: $pendingPayload");
    AppLogger.log('BgInit', 'flushing pre-listener payload=$pendingPayload');
    handleGlobalNavigation(pendingPayload);
    NotificationService.onNotificationTap.value = null;
  }

  AppLogger.log('BgInit', 'BookmarkService.init start');
  await BookmarkService.init();
  AppLogger.log('BgInit', 'BookmarkService.init done');

  await Future.delayed(const Duration(seconds: 1));
  AppLogger.log('BgInit', 'AlarmManager.initialize start');
  AndroidAlarmManager.initialize().catchError((e) {
    AppLogger.log('BgInit', 'AlarmManager error: $e');
    debugPrint('AlarmManager error: $e');
    return false;
  });
  AppLogger.log('BgInit', 'AlarmManager.initialize triggered');

  await Future.delayed(const Duration(seconds: 1));
  AppLogger.log('BgInit', 'DailyTrackerService.initStatsForToday start');
  await DailyTrackerService.initStatsForToday();
  AppLogger.log('BgInit', 'DailyTrackerService.initStatsForToday done');

  final prefs = CacheHelper.prefs;
  if (prefs.getBool('auto_sync_drive') == true) {
    BackupService.scheduleNextAutoSync();
  }

  await Future.delayed(const Duration(seconds: 1));
  AppLogger.log('BgInit', 'NotificationService.init start');
  await NotificationService.init();
  AppLogger.log('BgInit', 'NotificationService.init done');

  await Future.delayed(const Duration(seconds: 5));
  AppLogger.log('BgInit', 'PrayerService.init start');
  PrayerService().init();
  AppLogger.log('BgInit', 'PrayerService.init triggered');

  await Future.delayed(const Duration(seconds: 2));
  AppLogger.log('BgInit', 'RemoteConfigService.init start');
  RemoteConfigService.init().catchError((e) {
    AppLogger.log('BgInit', 'RemoteConfig error: $e');
    debugPrint('RemoteConfig error: $e');
  });

  await Future.delayed(const Duration(seconds: 2));
  AppLogger.log('BgInit', 'FCMService.init start');
  FCMService.init().catchError((e) {
    AppLogger.log('BgInit', 'FCM error: $e');
    debugPrint('FCM error: $e');
  });

  await Future.delayed(const Duration(seconds: 2));
  AppLogger.log('BgInit', 'JustAudioBackground.init start');
  JustAudioBackground.init(
    androidNotificationChannelId: 'app.ibad_al_rahmann.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  ).catchError((e) {
    AppLogger.log('BgInit', 'JustAudio error: $e');
    debugPrint('JustAudio error: $e');
  });


  // Phase 3: Background Heavy Preloading
  await Future.delayed(const Duration(seconds: 20));
  TafsirHelper.initTafsir().catchError((e) => debugPrint('Tafsir error: $e'));
  QuranWbwDbHelper.instance.preloadAllPagesInBackground();
}

/// Public so that SplashScreen can call it directly on cold start.
Future<void> handleGlobalNavigation(String payload) async {
  NotificationService.nativeLog('handleGlobalNavigation: payload=$payload, state=${navigatorKey.currentState != null ? "ready" : "null"}');

  // Use currentState directly — more reliable than context lookup mid-transition
  if (navigatorKey.currentState == null) {
    NotificationService.nativeLog('handleGlobalNavigation: state null, retrying in 500ms');
    Future.delayed(const Duration(milliseconds: 500), () {
      handleGlobalNavigation(payload);
    });
    return;
  }

  final nav = navigatorKey.currentState!;
  NotificationService.nativeLog('handleGlobalNavigation: calling nav.push for $payload');
  switch (payload) {
    case 'sabah':
    case 'morning':
      nav.push(MaterialPageRoute(builder: (_) => const AzkarPage(title: 'أذكار الصباح', jsonFile: 'morning.json', image: 'assets/images/morning.jpg')));
      break;
    case 'masaa':
    case 'night':
      nav.push(MaterialPageRoute(builder: (_) => const AzkarPage(title: 'أذكار المساء', jsonFile: 'evening.json', image: 'assets/images/night.jpg')));
      break;
    case 'ruqyah':
      nav.push(MaterialPageRoute(builder: (_) => const RuqyahScreen()));
      break;
    case 'khatma':
    case 'wird':
      nav.push(MaterialPageRoute(builder: (_) => const WirdDashboardScreen()));
      break;
    case 'jumuah':
    case 'kahf':
      nav.push(MaterialPageRoute(builder: (_) => const IsolatedWirdScreen(isKahfMode: true, targetStartPage: 293, targetEndPage: 304)));
      break;
    case 'fasting':
      nav.push(MaterialPageRoute(builder: (_) => const FastingDaysScreen()));
      break;
    case 'salawat':
      nav.push(MaterialPageRoute(builder: (_) => const TasbeehScreen()));
      break;
    case 'prayer':
    case 'prayer_times':
      nav.push(MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
      break;

    case 'home':
    default:
      if (payload.startsWith('khatma_')) {
        // Payload format: khatma_{id}_{wirdIdx}_{startPage}_{endPage}
        // The khatma ID itself may contain underscores (e.g. a timestamp like 1783413467488),
        // so we split from the right: last 3 segments are wirdIdx, startPage, endPage.
        final parts = payload.substring('khatma_'.length).split('_');
        if (parts.length >= 4) {
          final endPage   = int.tryParse(parts.last)              ?? 604;
          final startPage = int.tryParse(parts[parts.length - 2]) ?? 1;
          final wirdIdx   = int.tryParse(parts[parts.length - 3]) ?? 0;
          final khatmaId  = parts.sublist(0, parts.length - 3).join('_');
          nav.push(MaterialPageRoute(
            builder: (_) => IsolatedWirdScreen(
              isWirdMode: true,
              khatmaId: khatmaId,
              wirdIndex: wirdIdx,
              targetStartPage: startPage,
              targetEndPage: endPage,
            ),
          ));
        } else {
          // Fallback for old-format payloads without page info
          final khatmaId = parts.join('_');
          nav.push(MaterialPageRoute(
            builder: (_) => IsolatedWirdScreen(
              isWirdMode: true,
              khatmaId: khatmaId,
            ),
          ));
        }
      } else {
        nav.popUntil((route) => route.isFirst);
      }
      break;
  }
}
