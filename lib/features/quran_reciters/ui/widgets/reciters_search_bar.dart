import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/logic/quran_readers_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

class RecitersSearchBar extends StatelessWidget {
  const RecitersSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var outlineInputBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white),
      borderRadius: BorderRadius.circular(100),
    );
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(100),
      child: TextField(
        textAlign: TextAlign.center,
        style: AppStyles.style20harmattan.copyWith(
            fontSize: context.isLandscape ? 14.sp : null, color: Colors.black),
        controller: context.read<QuranReadersCubit>().searchController,
        onChanged: (value) {
          context.read<QuranReadersCubit>().onSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'ابحث باسم القارئ',
          hintStyle: AppStyles.style20harmattan
              .copyWith(fontSize: context.isLandscape ? 14.sp : null),
          contentPadding: EdgeInsets.symmetric(
            vertical: 8.h,
            horizontal: 24.w,
          ),
          border: outlineInputBorder,
          enabledBorder: outlineInputBorder,
          focusedBorder: outlineInputBorder,
          filled: true,
          fillColor: const Color(0xffE7E7E7),
          suffixIcon: Padding(
            padding: EdgeInsets.all(context.isTablet ? 24 : 12),
            child: SvgPicture.asset(
              AppAssets.svgsSearchIcon,
              width: context.isLandscape
                  ? 10.w
                  : context.isTablet
                      ? 20.w
                      : 10.w,
            ),
          ),
        ),
      ),
    );
  }
}
