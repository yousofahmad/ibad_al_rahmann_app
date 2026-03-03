import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../bloc_observer.dart';
import '../services/prayer_times_cache.dart';
import 'quran_json_helper.dart';

class AppInitializer {
  static Future<void> mainInit() async {
    setupGetIt();
    Bloc.observer = CustomBlocObserver();
    await Future.wait([
      _initHive(),
      _handleOrientation(),
      _handleFullScreen(),
      QuranJsonHelper.initQuranData(),
      JustAudioBackground.init(
        androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    ]);

    await PrayerTimesCache.clearStaleEntries();
  }

  static Future<void> _initHive() async {
    Hive.registerAdapter(VerseModelAdapter());
    await Hive.initFlutter();
  }

  static void homeInit() {
    Future.wait([TafsirHelper.initTafsir(), BookmarkService.init()]);
  }

  static Future<void> _handleFullScreen() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  static Future<void> _handleOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // static Future<void> _handleScheduleNotifications() async {
  //   final repo = PrayerTimesRepo();
  //   Future<void> getPrayerTimes() async {
  //     switch (getIt<CacheService>().getString(AppConsts.locationMethod)) {}
  //   }
  // }
}

// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     switch (task) {
//       case 'schedule_notifications':
//         await LocalNotificationService.instance.scheduleAt();
//         break;
//     }

//     return Future.value(true);
//   });
// }
