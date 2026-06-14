import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';

class QuranPagesList extends StatefulWidget {
  const QuranPagesList({super.key});

  @override
  State<QuranPagesList> createState() => _QuranPagesListState();
}

class _QuranPagesListState extends State<QuranPagesList> {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranCubit>();

    return BlocBuilder<QuranCubit, QuranState>(
      buildWhen: (prev, curr) => prev.currentPage != curr.currentPage,
      builder: (context, state) {
        return PageView.builder(
          controller: cubit.pagesController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          // PageView naturally supports snapping "one-by-one" with PageScrollPhysics (default)
          // We can also use BouncingScrollPhysics() wrapped in PageScrollPhysics if we want
          physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
          onPageChanged: (index) {
            cubit.onPagesListChanged(index);
            HapticFeedback.selectionClick();
          },
          itemCount: 604,
          itemBuilder: (context, index) {
            // We use the state's currentPage for visual selection to keep it reactive
            final isSelected = index == state.currentPage;

            return Center(
              child: GestureDetector(
                onTap: () {
                  cubit.jumpToPage(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: 85.w, // Increased from 75.w to add more space
                  height: 100.0,
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Rotated diamond marker
                      Transform.rotate(
                        angle: pi / 4,
                        child: Container(
                          height: context.isTablet ? 14.w : 28.w,
                          width: context.isTablet ? 14.w : 28.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isSelected
                                ? Colors.white
                                : AppColors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      // Star SVG for selected page
                      if (isSelected)
                        OverflowBox(
                          maxWidth: 250.w,
                          maxHeight: 250.w,
                          child: Transform.scale(
                            scale: 1.8,
                            child: SvgPicture.asset(
                              AppAssets.svgsStar,
                              width: context.isTablet ? 20.w : 40.w,
                              height: context.isTablet ? 20.w : 40.w,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFD0A871),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      // Page number
                      Text(
                        (index + 1).toArabicNums,
                        style: AppStyles.style14u.copyWith(
                          fontSize: isSelected ? 14.sp : 12.sp,
                          color: isSelected
                              ? const Color(0xFF3E2723)
                              : Theme.of(context).textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.6) ??
                                    Colors.grey,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
