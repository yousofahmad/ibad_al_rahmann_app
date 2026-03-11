import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/services/intro_service.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';

import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/quran_pages_list.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'mobile_min_quran_bottom_section.dart';
import 'mobile_quran_top_bar.dart';
import '../widgets/wbw_page_widget.dart';

class MinQuranMobile extends StatefulWidget {
  const MinQuranMobile({super.key, this.currentPage});
  final int? currentPage;

  @override
  State<MinQuranMobile> createState() => _MinQuranMobileState();
}

class _MinQuranMobileState extends State<MinQuranMobile> {
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
    // Show intro tutorial only if it hasn't been shown before
    if (!IntroService.hasShownDoubleTapIntro()) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          IntroService.showQuranIntro(context);
          // Mark as shown after starting
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
                  child: const MobileQuranTopBar(),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 60.h,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: const MobileMinQuranBottomSection(),
                    ),
                    SizedBox(height: 6.h),
                    SizedBox(
                      height: 50.h,
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
          ? const Radius.circular(16)
          : const Radius.circular(0),
      left: index.isOdd ? const Radius.circular(16) : const Radius.circular(0),
    );
  }
}
