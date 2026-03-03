import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookmarksEmptyState extends StatelessWidget {
  const BookmarksEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80.w, color: Colors.grey[400]),
            SizedBox(height: 24.h),
            Text(
              'لا يوجد آيات محفوظة',
              style: AppStyles.style20.copyWith(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
