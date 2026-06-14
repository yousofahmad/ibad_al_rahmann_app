import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/repo/quran_repo.dart';
import 'package:ibad_al_rahmann/services/daily_tracker_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'widgets/core/quran_screen_body.dart';

import '../../../widgets/app_skeleton.dart';

class QuranScreen extends StatefulWidget {
  final int? initialPage;
  final bool isWirdMode;
  final bool isKahfMode;
  final String? khatmaId;
  final int? targetStartPage;
  final int? targetEndPage;
  final int? wirdIndex;

  const QuranScreen({
    super.key,
    this.initialPage,
    this.isWirdMode = false,
    this.isKahfMode = false,
    this.khatmaId,
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
  late SearchCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    // Default to edgeToEdge (shows status bar).
    // It will be toggled to immersiveSticky only when in "Full Screen" Mushaf mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.enable();
    _initializeCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _initializeCache() async {
    try {
      final cacheService = getIt<CacheService>();
      await cacheService.init();

      // Load separate page progress for Mushaf vs Wird vs Kahf
      if (widget.initialPage != null) {
        _cachedPage = widget.initialPage;
      } else if (widget.isKahfMode) {
        _cachedPage = await DailyTrackerService.getKahfProgress();
      } else if (widget.isWirdMode) {
        _cachedPage = cacheService.getInt('last_wird_page');
      } else {
        _cachedPage = cacheService.getInt('last_quran_page');
      }

      _quranCubit = QuranCubit(
        QuranRepo(tablet: true, initialPage: _cachedPage),
        isWirdMode: widget.isWirdMode,
        isKahfMode: widget.isKahfMode,
        khatmaId: widget.khatmaId,
        wirdStartPage: widget.targetStartPage,
        targetEndPage: widget.targetEndPage,
        wirdIndex: widget.wirdIndex,
      );
      _versePlayerCubit = VersePlayerCubit();
      _quranThemeCubit = QuranThemeCubit();
      _searchCubit = SearchCubit();

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
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();
    _searchCubit.close();
    _quranCubit.close();
    _versePlayerCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppSkeleton.quranPage(),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<QuranCubit>.value(value: _quranCubit),
        BlocProvider<VersePlayerCubit>.value(value: _versePlayerCubit),
        BlocProvider<SearchCubit>.value(value: _searchCubit),
        BlocProvider<QuranThemeCubit>.value(value: _quranThemeCubit),
        BlocProvider<ThemeCubit>.value(value: _quranThemeCubit),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return BlocBuilder<QuranCubit, QuranState>(
            builder: (context, quranState) {
              ThemeData themeData = themeState.mode == ThemeMode.dark
                  ? themeState.theme.dark
                  : themeState.theme.light;

              final paperColor = quranState.isKahfMode
                  ? quranState.kahfPaperColor
                  : (quranState.isWirdMode
                      ? quranState.wirdPaperColor
                      : quranState.quranPaperColor);

              final isFullLayout =
                  quranState.layout == QuranLayout.full ||
                  quranState.isWirdMode ||
                  quranState.isKahfMode;

              // The Mushaf background has two states:
              // 1. Full Layout: Entire screen is the paper color (Special Treatment).
              // 2. Minimized Layout: Background follows the app's primary theme color.
              final effectiveBg = isFullLayout
                  ? (paperColor ?? themeData.scaffoldBackgroundColor)
                  : themeData.primaryColor;

              final isLight = effectiveBg.computeLuminance() > 0.5;

              themeData = themeData.copyWith(
                brightness: isLight ? Brightness.light : Brightness.dark,
                scaffoldBackgroundColor: effectiveBg,
                // Removed forced primaryColor/canvasColor overrides to respect the original theme colors
                iconTheme: const IconThemeData(color: Colors.grey),
              );

              final bgColor = effectiveBg;

              return Theme(
                data: themeData,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: isLight
                        ? Brightness.dark
                        : Brightness.light,
                    systemNavigationBarColor: Colors.transparent,
                  ),
                  child: Container(
                    color: bgColor,
                    child: Scaffold(
                      backgroundColor: bgColor,
                      extendBody: true, // FIX: Extends body behind bottom nav
                      extendBodyBehindAppBar:
                          true, // FIX: Extends body behind app bar
                      resizeToAvoidBottomInset: false,
                      body: const QuranScreenBody(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
