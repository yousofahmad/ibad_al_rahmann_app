import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

import '../widgets/double_tap_dialog.dart';
import '../widgets/quran_pages_list.dart';
import '../widgets/wbw_page_widget.dart';
import 'tablet_min_quran_bottom_section.dart';
import 'tablet_quran_top_bar.dart';

class MinQuranTablet extends StatefulWidget {
  const MinQuranTablet({super.key, this.currecntPage});
  final int? currecntPage;

  @override
  State<MinQuranTablet> createState() => _MinQuranTabletState();
}

class _MinQuranTabletState extends State<MinQuranTablet> {
  @override
  void initState() {
    if (widget.currecntPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<QuranCubit>().initControllers(widget.currecntPage!);
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
        return const DoubleTapDialog();
      },
    );
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
              const SafeArea(bottom: false, child: TabletQuranTopBar()),
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () => context.read<QuranCubit>().changeLayout(),
                  child: PageView.builder(
                    controller: context.read<QuranCubit>().minQuranController,
                    itemCount: totalPagesCount,
                    onPageChanged: (value) =>
                        context.read<QuranCubit>().onQuranPageChanged(value),
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(
                          left: index.isOdd ? 12 : 0,
                          right: index.isEven ? 12 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: state.mode == ThemeMode.dark
                              ? Colors.black
                              : const Color(0xfffffdf5),
                          borderRadius: borderRadius(index),
                          border: buildBorder(index),
                        ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 80.h,
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: const TabletMinQuranBottomSection(),
                    ),
                    SizedBox(height: 6.h),
                    SizedBox(
                      height: 60.h,
                      width: double.infinity,
                      child: const QuarnPagesList(),
                    ),
                    SizedBox(height: 10.h),
                  ],
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
          ? const Radius.circular(12)
          : const Radius.circular(0),
      left: index.isOdd ? const Radius.circular(12) : const Radius.circular(0),
    );
  }
}
