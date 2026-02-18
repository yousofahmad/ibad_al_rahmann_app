import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/date_time_ext.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/surahs_tashkeel.dart';

class BookmarkItem extends StatefulWidget {
  final VerseModel verse;
  final VoidCallback onTap;

  const BookmarkItem({
    super.key,
    required this.verse,
    required this.onTap,
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
  void initState() {
    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            !fontLoaded
                ? const CircularProgressIndicator()
                : Text(
                    widget.verse.verse,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontFamily: widget.verse.fontFamily,
                      color: Colors.black,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
            SizedBox(height: 12.h),
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
                  style: AppStyles.style18u.copyWith(color: Colors.black),
                ),
                const Spacer(),
                Text(
                  'سورة ${surahArabicTashkel[widget.verse.surahNumber - 1]}',
                  style: AppStyles.style18u.copyWith(color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
