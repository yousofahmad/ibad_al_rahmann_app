import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/helpers/size_config.dart';
import 'widgets/quran_screen_body.dart';

class QuranScreen extends StatefulWidget {
  final int? initialPage;
  final bool isWirdMode;
  final int? targetStartPage;
  final int? targetEndPage;
  final int? wirdIndex;

  const QuranScreen({
    super.key,
    this.initialPage,
    this.isWirdMode = false,
    this.targetStartPage,
    this.targetEndPage,
    this.wirdIndex,
  });

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int? _cachedPage;
  bool _isInitialized = false;
  late QuranCubit _quranCubit;
  late VersePlayerCubit _versePlayerCubit;
  late QuranThemeCubit _quranThemeCubit;

  @override
  void initState() {
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeCache();
    super.initState();
  }

  Future<void> _initializeCache() async {
    try {
      final cacheService = getIt<CacheService>();
      await cacheService.init();
      _cachedPage =
          widget.initialPage ?? cacheService.getInt('last_quran_page');

      _quranCubit = QuranCubit(
        QuranRepo(tablet: true, initialPage: _cachedPage),
        isWirdMode: widget.isWirdMode,
        wirdStartPage: widget.targetStartPage,
        targetEndPage: widget.targetEndPage,
        wirdIndex: widget.wirdIndex,
      );
      _versePlayerCubit = VersePlayerCubit();
      _quranThemeCubit = QuranThemeCubit();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error initializing Quran Screen: $e");
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<QuranCubit>.value(value: _quranCubit),
        BlocProvider<VersePlayerCubit>.value(value: _versePlayerCubit),
        BlocProvider<ThemeCubit>.value(value: _quranThemeCubit),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          final ThemeData themeData = state.mode == ThemeMode.dark
              ? state.theme.dark
              : state.theme.light;

          return Theme(
            data: themeData,
            child: Scaffold(
              backgroundColor: state.mode == ThemeMode.dark
                  ? Colors.black
                  : themeData.scaffoldBackgroundColor,
              resizeToAvoidBottomInset: false,
              body: const QuranScreenBody(),
            ),
          );
        },
      ),
    );
  }
}
