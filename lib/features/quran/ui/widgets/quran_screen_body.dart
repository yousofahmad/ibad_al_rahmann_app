import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions/screen_details.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme_manager/theme_cubit.dart';
import '../../bloc/quran/quran_cubit.dart';
import '../layouts/min_quran_widget.dart';
import '../widgets/full_quran_mobile.dart';
import '../widgets/verse_player.dart';
import '../widgets/wird_quran_widget.dart';
import 'quran_landscape_widget.dart';

class QuranScreenBody extends StatelessWidget {
  const QuranScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranCubit, QuranState>(
      buildWhen: (previous, current) => previous.layout != current.layout,
      builder: (context, state) {
        final bool isFull = state.layout == QuranLayout.full;
        final isDark = context.watch<ThemeCubit>().state.mode == ThemeMode.dark;

        return BlocListener<QuranCubit, QuranState>(
          listenWhen: (p, c) => p.layout != c.layout,
          listener: (context, state) {
            if (state.layout == QuranLayout.full) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            } else {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            }
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: Stack(
              children: [
                if (context.isLandscape) const LandscapeQuranWidget(),
                if (!context.isLandscape)
                  SafeArea(
                    top: !isFull, // Hide Top SafeArea padding in Full Screen
                    left: false,
                    right: false,
                    bottom: true,
                    child: BlocBuilder<QuranCubit, QuranState>(
                      buildWhen: (previous, current) {
                        return previous.layout != current.layout ||
                            previous.currentPage != current.currentPage ||
                            previous.isWirdMode != current.isWirdMode;
                      },
                      builder: (context, state) {
                        if (state.isWirdMode) {
                          return WirdQuranWidget(
                            initialAbsolutePage: state.currentPage ?? 1,
                          );
                        }
                        switch (state.layout) {
                          case QuranLayout.full:
                            return FullQuranWidget(
                              currentPage: state.currentPage,
                            );
                          case QuranLayout.min:
                            return MinQuranWidget(
                              currentPage: state.currentPage,
                            );
                        }
                      },
                    ),
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
