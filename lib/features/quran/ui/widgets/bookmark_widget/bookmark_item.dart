import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/date_time_ext.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart' as quran;

class BookmarkItem extends StatefulWidget {
  final VerseModel verse;
  final VoidCallback onTap;
  final Widget? trailing;

  const BookmarkItem({
    super.key,
    required this.verse,
    required this.onTap,
    this.trailing,
  });

  @override
  State<BookmarkItem> createState() => _BookmarkItemState();
}

class _BookmarkItemState extends State<BookmarkItem> {
  bool fontLoaded = false;
  void init() async {
    FontsHelper.loadFontFromFamily(widget.verse.fontFamily).whenComplete(() {
      setState(() {
        fontLoaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final paperColor =
        context.read<QuranCubit>().state.quranPaperColor ??
        Theme.of(context).scaffoldBackgroundColor;
    final bool isLightBg = paperColor.computeLuminance() > 0.5;

    final textColor = isLightBg ? Colors.black87 : Colors.white;
    final subtleText = isLightBg ? Colors.black54 : Colors.white70;
    final bgColor = isLightBg ? Colors.white : Colors.black;
    final borderColor = Theme.of(context).primaryColor;

    final onPrimary =
        ThemeData.estimateBrightnessForColor(borderColor) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: widget.onTap,
      onLongPress: () {
        setState(() {
          BookmarkService.removeBookmark(widget.verse);
        });
        context.pop();
        AlertHelper.showSuccessAlert(
          context,
          message: 'تم ازالة الآية من المحفوظات',
        );
      },
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.trailing != null) widget.trailing!,
                if (widget.trailing == null) const SizedBox(),
                if (widget.verse.label != null &&
                    widget.verse.label!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      widget.verse.label!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: onPrimary,
                        fontFamily: 'cairo',
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              widget.verse.verse,
              style: TextStyle(
                fontSize: 22.sp,
                fontFamily: widget.verse.fontFamily,
                color: textColor,
                height: 1.2,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16.h),
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12.w,
                      color: Colors.grey[500],
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      widget.verse.bookmarkedAt.toSimpleDate,
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 11,
                        color: subtleText,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'سورة ${quran.getSurahNameArabic(widget.verse.surahNumber)}',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '| آية ${widget.verse.verseNumber.toArabicNums}',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 12,
                        color: subtleText,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '| ص ${quran.getPageNumber(widget.verse.surahNumber, widget.verse.verseNumber).toArabicNums}',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 12,
                        color: subtleText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
