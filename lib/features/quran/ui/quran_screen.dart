import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
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
  const QuranScreen({super.key, this.initialPage});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int? _cachedPage;
  bool _isInitialized = false;

  @override
  void initState() {
    WakelockPlus.enable();
    if (widget.initialPage != null) {
      _cachedPage = widget.initialPage;
      _isInitialized = true;
    } else {
      _initializeCache();
    }
    super.initState();
  }

  Future<void> _initializeCache() async {
    _cachedPage = getIt<CacheService>().getInt('last_quran_page');
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
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
        BlocProvider(
          create: (_) => QuranCubit(
            QuranRepo(
              tablet: context.screenWidth > SizeConfig.tablet,
              initialPage: _cachedPage,
            ),
          ),
        ),
        BlocProvider(create: (context) => VersePlayerCubit()),
        // Provide QuranThemeCubit as ThemeCubit to isolate Quran theme
        BlocProvider<ThemeCubit>(create: (context) => QuranThemeCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          final ThemeData themeData = state.mode == ThemeMode.dark
              ? state.theme.dark
              : state.theme.light;

          return Theme(
            data: themeData,
            child: Scaffold(
              backgroundColor: themeData.scaffoldBackgroundColor,
              resizeToAvoidBottomInset: false,
              body: const QuranScreenBody(),
            ),
          );
        },
      ),
    );
  }
}
