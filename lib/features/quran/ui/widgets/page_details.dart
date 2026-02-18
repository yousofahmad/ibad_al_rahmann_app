import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

class FullPageDetails extends StatelessWidget {
  const FullPageDetails({
    super.key,
    required this.surahNumber,
    required this.firstVerse,
  });
  final int surahNumber, firstVerse;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          getJuzNumber(surahNumber, firstVerse).toJuzName,
          style: context.labelSmall.copyWith(
            fontSize: context.isTablet ? 16.sp : null,
          ),
        ),
        Text(
          'سورة ${getSurahNameArabic(surahNumber)}',
          style: context.labelSmall.copyWith(
            fontSize: context.isTablet ? 16.sp : null,
          ),
        ),
      ],
    );
  }
}

// class MinPageDetailsMobile extends StatelessWidget {
//   const MinPageDetailsMobile({super.key, required this.surahNumber});
//   final int surahNumber;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           getJuzNumber(surahNumber, 1).toJuzName,
//           style: context.labelSmall.copyWith(fontSize: 15.sp),
//         ),
//         Text(
//           'سورة ${getSurahNameArabic(surahNumber)}',
//           style: context.labelSmall.copyWith(fontSize: 15.sp),
//         ),
//       ],
//     );
//   }
// }
