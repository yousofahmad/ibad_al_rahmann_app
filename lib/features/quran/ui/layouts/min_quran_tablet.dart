import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/helpers/extensions/screen_details.dart';

import '../widgets/core/quran_pages_list.dart';
import '../widgets/core/wbw_page_widget.dart';
import 'tablet_min_quran_bottom_section.dart';
import 'tablet_quran_top_bar.dart';

/// Tablet-optimized minimized Quran layout.
/// Uses the same WbwPageWidget as mobile but with tablet-appropriate
/// spacing, top bar, and bottom section.
class MinQuranTablet extends StatefulWidget {
  const MinQuranTablet({super.key, this.currentPage});
  final int? currentPage;

  @override
  State<MinQuranTablet> createState() => _MinQuranTabletState();
}

class _MinQuranTabletState extends State<MinQuranTablet> {
  @override
  void initState() {
    if (widget.currentPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<QuranCubit>().initControllers(widget.currentPage!);
        _showIntroIfNeeded();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIntroIfNeeded();
      });
    }
    super.initState();
  }

  void _showIntroIfNeeded() {
    if (!IntroService.hasShownDoubleTapIntro()) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          IntroService.showQuranIntro(context);
          IntroService.markDoubleTapIntroAsShown();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: context.isLandscape ? 85 : 140.h,
                  child: const TabletQuranTopBar(),
                ),
              ),
              Expanded(
                child: _TapListener(
                  onDoubleTap: () => context.read<QuranCubit>().changeLayout(),
                  child: PageView.builder(
      allowImplicitScrolling: true,
                    controller: context.read<QuranCubit>().minQuranController,
                    itemCount: 604,
                    onPageChanged: (value) =>
                        context.read<QuranCubit>().onQuranPageChanged(value),
                    itemBuilder: (context, index) {
                      final quranState = context.watch<QuranCubit>().state;
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final Color effectivePaperColor =
                          quranState.quranPaperColor ??
                          (isDark ? Colors.black : const Color(0xfffffdf5));
                      final isLight =
                          effectivePaperColor.computeLuminance() > 0.15;
                      final textColor = isLight ? Colors.black : Colors.white;

                      return Container(
                        margin: EdgeInsets.only(
                          top: 15.h,
                          bottom: 15.h,
                          right: index.isEven ? 20.w : 0,
                          left: index.isOdd ? 20.w : 0,
                        ),
                        decoration: BoxDecoration(
                          color: effectivePaperColor,
                          borderRadius: borderRadius(index),
                          border: buildBorder(index, state.mode),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: WbwPageWidget(
                          pageNumber: index + 1,
                          showHeader: false,
                          showPageNumber: false,
                          paperColorOverride: effectivePaperColor,
                          textColorOverride: textColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  color: Colors.transparent,
                  child: Builder(
                    builder: (context) {
                      final themeState = context.watch<ThemeCubit>().state;
                      return Theme(
                        data: themeState.mode == ThemeMode.dark
                            ? themeState.theme.dark
                            : themeState.theme.light,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: context.isLandscape ? 80 : 100.h,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: const TabletMinQuranBottomSection(),
                            ),
                            if (!context.isLandscape) SizedBox(height: 12.h),
                            const SizedBox(
                              height:
                                  80, // Increased from 60 to accommodate the large star
                              width: double.infinity,
                              child: QuranPagesList(),
                            ),
                            if (!context.isLandscape) SizedBox(height: 20.h),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Border buildBorder(int index, ThemeMode mode) {
    Color borderColor = mode == ThemeMode.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;

    return Border(
      right: index.isOdd
          ? BorderSide(width: 2, color: borderColor)
          : BorderSide.none,
      left: index.isEven
          ? BorderSide(width: 2, color: borderColor)
          : BorderSide.none,
    );
  }

  BorderRadius borderRadius(int index) {
    return BorderRadius.horizontal(
      right: index.isEven
          ? const Radius.circular(16)
          : const Radius.circular(0),
      left: index.isOdd ? const Radius.circular(16) : const Radius.circular(0),
    );
  }
}

/// Detects taps / double-taps via raw pointer events so it doesn't
/// interfere with the [PageView] horizontal gesture arena.
class _TapListener extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDoubleTap;

  const _TapListener({required this.child, this.onDoubleTap});

  @override
  State<_TapListener> createState() => _TapListenerState();
}

class _TapListenerState extends State<_TapListener> {
  Offset? _downPos;
  DateTime? _lastTap;
  Timer? _timer;

  static const double _maxDelta = 10.0;
  static const Duration _window = Duration(milliseconds: 300);
  static const Duration _delay = Duration(milliseconds: 320);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _downPos = e.localPosition,
      onPointerUp: (e) {
        if (_downPos == null) return;
        final delta = (e.localPosition - _downPos!).distance;
        _downPos = null;
        if (delta > _maxDelta) return;

        final now = DateTime.now();
        if (_lastTap != null && now.difference(_lastTap!) < _window) {
          _timer?.cancel();
          _lastTap = null;
          widget.onDoubleTap?.call();
        } else {
          _lastTap = now;
          _timer?.cancel();
          _timer = Timer(_delay, () {
            if (mounted) {
              /* single-tap – no action in min mode */
            }
          });
        }
      },
      child: widget.child,
    );
  }
}
