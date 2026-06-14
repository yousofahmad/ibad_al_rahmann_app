import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/services.dart';
import '../../../../../core/theme/theme_manager/theme_cubit.dart';
import '../../../bloc/quran/quran_cubit.dart';
import '../../layouts/min_quran_widget.dart';
import './full_quran_mobile.dart';
import '../audio/verse_player.dart';
import './wird_quran_widget.dart';

class QuranScreenBody extends StatelessWidget {
  const QuranScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranCubit, QuranState>(
      buildWhen: (previous, current) =>
          previous.layout != current.layout ||
          previous.isWirdMode != current.isWirdMode ||
          previous.isKahfMode != current.isKahfMode,
      builder: (context, state) {
        final isDark = context.watch<ThemeCubit>().state.mode == ThemeMode.dark;
        final isMin =
            state.layout == QuranLayout.min &&
            !state.isWirdMode &&
            !state.isKahfMode;

        // For all modes, we use transparent status bar to allow the background to bleed through
        Color targetStatusBarColor = Colors.transparent;
        Brightness targetIconBrightness = isDark
            ? Brightness.light
            : Brightness.dark;

        if (isMin) {
          targetIconBrightness = Brightness.light;
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }

        return BlocListener<QuranCubit, QuranState>(
          listenWhen: (p, c) =>
              p.layout != c.layout ||
              p.isWirdMode != c.isWirdMode ||
              p.isKahfMode != c.isKahfMode,
          listener: (context, state) {
            // Layout specific orientation logic is handled in builder.
            // Full Screen toggle (status bar) is handled in FullQuranWidget/WirdQuranWidget.
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: targetStatusBarColor,
              statusBarIconBrightness: targetIconBrightness,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: Stack(
              children: [
                BlocBuilder<QuranCubit, QuranState>(
                  buildWhen: (previous, current) {
                    return previous.layout != current.layout ||
                        previous.isWirdMode != current.isWirdMode ||
                        previous.isKahfMode != current.isKahfMode;
                  },
                  builder: (context, state) {
                    if (state.isWirdMode || state.isKahfMode) {
                      return WirdQuranWidget(
                        // Wird mode handles its own internal initialization
                        targetStartPage: (state.currentPage ?? 0) + 1,
                      );
                    }

                    switch (state.layout) {
                      case QuranLayout.full:
                        // FullQuranWidget uses state.currentPage internally in initState once,
                        // and then listens to Bloc changes.
                        return FullQuranWidget(currentPage: state.currentPage);
                      case QuranLayout.min:
                        return MinQuranWidget(currentPage: state.currentPage);
                    }
                  },
                ),
                const Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: VersePlayer(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
