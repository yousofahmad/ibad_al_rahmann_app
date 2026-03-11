import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/quran_pages_list.dart';
import '../widgets/wbw_page_widget.dart';
import 'mobile_min_quran_bottom_section.dart';
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
      Future.delayed(const Duration(milliseconds: 500), () {
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
          color: state.mode == ThemeMode.dark
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 140.h,
                  child: const TabletQuranTopBar(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () => context.read<QuranCubit>().changeLayout(),
                  child: PageView.builder(
                    controller: context.read<QuranCubit>().minQuranController,
                    itemCount: 604,
                    onPageChanged: (value) =>
                        context.read<QuranCubit>().onQuranPageChanged(value),
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(left: index.isOdd ? 8 : 0),
                        decoration: BoxDecoration(
                          color: state.mode == ThemeMode.dark
                              ? Colors.black
                              : const Color(0xfffffdf5),
                          borderRadius: borderRadius(index),
                          border: buildBorder(index),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: WbwPageWidget(
                          pageNumber: index + 1,
                          showHeader: false,
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  color: state.mode == ThemeMode.dark
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 60.h,
                        child: const MobileMinQuranBottomSection(),
                      ),
                      SizedBox(
                        height: 60.h,
                        width: double.infinity,
                        child: const QuarnPagesList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Border buildBorder(int index) {
    return Border(
      right: index.isOdd
          ? BorderSide(width: 2, color: context.onPrimary)
          : BorderSide.none,
      left: index.isEven
          ? BorderSide(width: 2, color: context.onPrimary)
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
