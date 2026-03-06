import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'full_page_rich_text_mobile.dart';
import 'single_tap_menu.dart';

class FullQuranWidget extends StatefulWidget {
  const FullQuranWidget({super.key, this.currentPage});
  final int? currentPage;

  @override
  State<FullQuranWidget> createState() => _FullQuranWidgetState();
}

class _FullQuranWidgetState extends State<FullQuranWidget> {
  bool _showOverlays = false;

  @override
  void initState() {
    // Hide status bar for immersive reading experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.currentPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<QuranCubit>().fullQuranController.jumpToPage(
          widget.currentPage!,
        );
        _showIntroIfNeeded();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIntroIfNeeded();
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    // Restore status bar visibility when leaving Full Screen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  void _showIntroIfNeeded() {
    // Show intro tutorial only if it hasn't been shown before
    if (!IntroService.hasShownDoubleTapIntro()) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showDoubleTapHint();
          // Mark as shown after starting
          IntroService.markDoubleTapIntroAsShown();
        }
      });
    }
  }

  void _showDoubleTapHint() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app, color: AppColors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'اضغط ضغطتين لتصغير الشاشة',
                style: context.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'يمكنك تصغير الشاشة عبر الضغط مرتين على الآيات',
                style: context.headlineLarge.copyWith(fontSize: 20.sp),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(
                'حسنًا',
                style: TextStyle(
                  color: AppColors.white,
                  fontFamily: AppConsts.uthmanic,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showOverlays = !_showOverlays;
        });
      },
      onDoubleTap: () {
        context.read<QuranCubit>().changeLayout();
      },
      child: ColoredBox(
        color: context.onPrimary,
        child: Stack(
          children: [
            PageView.builder(
              controller: context.read<QuranCubit>().fullQuranController,
              itemCount: totalPagesCount,
              onPageChanged: (value) {
                context.read<QuranCubit>().onQuranPageChanged(value);
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(child: FullPageRichText(pageNumber: index + 1)),
                    ],
                  ),
                );
              },
            ),
            if (_showOverlays)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _showOverlays = false;
                    });
                  },
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: BlocBuilder<QuranCubit, QuranState>(
                          builder: (context, state) {
                            final currentPage = (state.currentPage ?? 0) + 1;
                            return PageActionBar(
                              pageNumber: currentPage,
                              onDismiss: () {
                                if (mounted) {
                                  setState(() {
                                    _showOverlays = false;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
