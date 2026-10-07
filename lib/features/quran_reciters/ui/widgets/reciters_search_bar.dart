import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/logic/quran_readers_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RecitersSearchBar extends StatelessWidget {
  const RecitersSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : primaryColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontSize: context.isLandscape ? 13.sp : 14.sp,
          color: isDark ? Colors.white : Colors.black87,
        ),
        controller: context.read<QuranReadersCubit>().searchController,
        onChanged: (value) {
          context.read<QuranReadersCubit>().onSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'ابحث باسم القارئ أو الرواية...',
          hintStyle: TextStyle(
            fontFamily: AppConsts.cairo,
            fontSize: context.isLandscape ? 12.sp : 13.sp,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
          hintTextDirection: TextDirection.rtl,
          contentPadding: EdgeInsets.symmetric(
            vertical: 10.h,
            horizontal: 20.w,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: primaryColor, size: 22.sp),
          suffixIcon:
              context.read<QuranReadersCubit>().searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: primaryColor, size: 18.sp),
                  onPressed: () {
                    context.read<QuranReadersCubit>().searchController.clear();
                    context.read<QuranReadersCubit>().onSearch('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}
