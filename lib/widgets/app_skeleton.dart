import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class AppSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;

  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  // --- Specialized Skeleton Factories ---

  static Widget prayerRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      child: Row(
        children: [
          AppSkeleton(width: 120.w, height: 20.h),
          const Spacer(),
          AppSkeleton(width: 60.w, height: 20.h),
        ],
      ),
    );
  }

  static Widget quranPage() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: List.generate(
          12, // Reduced from 15 to fit better in all modes
          (index) => AppSkeleton(
            width: double.infinity,
            height: 20.h, // Reduced from 25
            margin: EdgeInsets.symmetric(vertical: 8.h),
          ),
        ),
      ),
    );
  }

  static Widget indexItem() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          AppSkeleton(width: 40.w, height: 40.w, borderRadius: 20),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 100.w, height: 16.h),
              SizedBox(height: 8.h),
              AppSkeleton(width: 60.w, height: 12.h),
            ],
          ),
          const Spacer(),
          AppSkeleton(width: 40.w, height: 14.h),
        ],
      ),
    );
  }

  static Widget gridItem() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppSkeleton(width: 60.w, height: 60.w, borderRadius: 30),
          SizedBox(height: 12.h),
          AppSkeleton(width: 80.w, height: 16.h),
        ],
      ),
    );
  }

  static Widget card({double? height}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 150.w, height: 20.h),
          SizedBox(height: 12.h),
          AppSkeleton(width: double.infinity, height: height ?? 100.h),
        ],
      ),
    );
  }
}
