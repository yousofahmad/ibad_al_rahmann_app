import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class QuarnPagesList extends StatefulWidget {
  const QuarnPagesList({super.key});

  @override
  State<QuarnPagesList> createState() => _QuarnPagesListState();
}

class _QuarnPagesListState extends State<QuarnPagesList> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with the current page from the controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<QuranCubit>().pagesController;
      if (controller.hasClients) {
        setState(() {
          _selectedIndex = controller.page?.round() ?? 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: context.read<QuranCubit>().pagesController,
      scrollDirection: Axis.horizontal,
      itemCount: 604,
      onPageChanged: (value) {
        setState(() {
          _selectedIndex = value;
        });
        context.read<QuranCubit>().onPagesListChanged(_selectedIndex);
      },
      itemBuilder: (context, index) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: pi / 4,
              child: Container(
                height: context.isTablet ? 14.w : 18.w,
                width: context.isTablet ? 14.w : 18.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _selectedIndex == index
                      ? Colors.white
                      : AppColors.white,
                ),
              ),
            ),
            Text(
              (index + 1).toArabicNums,
              style: AppStyles.style14u.copyWith(fontSize: 12.sp),
            ),
            if (_selectedIndex == index)
              SvgPicture.asset(AppAssets.svgsStar, width: 50.w),
          ],
        );
      },
    );
  }
}
