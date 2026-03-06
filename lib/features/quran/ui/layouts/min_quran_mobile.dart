import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
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
          title: const Text(
            'تلميحات التصفح',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFFD0A871),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHintRow(Icons.touch_app, 'ضغطتين', 'تكبير / تصغير الصفحة'),
              const SizedBox(height: 12),
              _buildHintRow(
                Icons.touch_app_outlined,
                'ضغطة مطولة',
                'التفسير والمشاركة ومشغل الآيات',
              ),
              const SizedBox(height: 12),
              _buildHintRow(
                Icons.bookmark_outline,
                'ضغطة واحدة',
                ' قائمة المحفوظات و تغيير الثيم والمشاركة او الحفظ وضغطة اخري تختفي',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'حسنًا',
                style: TextStyle(
                  color: Color(0xFFD0A871),
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHintRow(IconData icon, String title, String desc) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD0A871), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ],
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
          ? const Radius.circular(12)
          : const Radius.circular(0),
      left: index.isOdd ? const Radius.circular(12) : const Radius.circular(0),
    );
  }
}
