import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';

class ReciterDropdown extends StatelessWidget {
  final VersePlayerCubit cubit;

  const ReciterDropdown({super.key, required this.cubit});

  void _showReciterSelectionModal(BuildContext context) {
    final activeId = cubit.reciter ?? VersePlayerCubit.defaultReciters.keys.first;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
            final textColor = isDark ? Colors.white : Colors.black87;
            const gold = Color(0xFFD0A871);

            final entries = VersePlayerCubit.defaultReciters.entries.where((e) {
              if (searchQuery.trim().isEmpty) return true;
              return e.value.toLowerCase().contains(searchQuery.trim().toLowerCase());
            }).toList();

            return Container(
              height: context.screenHeight * 0.72,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    child: Row(
                      children: [
                        Icon(Icons.record_voice_over_rounded, color: gold, size: 24.sp),
                        SizedBox(width: 10.w),
                        Text(
                          'اختر قارئ الآيات',
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.bold,
                            color: gold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 13.5.sp, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم القارئ...',
                        hintStyle: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 13.sp, color: textColor.withValues(alpha: 0.45)),
                        prefixIcon: Icon(Icons.search_rounded, color: gold, size: 20.sp),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Reciters List
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: textColor.withValues(alpha: 0.08)),
                      itemBuilder: (context, index) {
                        final item = entries[index];
                        final isSelected = item.key == activeId;

                        return InkWell(
                          onTap: () {
                            cubit.changeReciter(item.key);
                            Navigator.pop(modalCtx);
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: isSelected ? gold.withValues(alpha: 0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36.w,
                                  height: 36.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? gold : gold.withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check_rounded : Icons.mic_rounded,
                                    color: isSelected ? Colors.white : gold,
                                    size: 18.sp,
                                  ),
                                ),
                                SizedBox(width: 14.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.value,
                                        style: TextStyle(
                                          fontFamily: AppConsts.expoArabic,
                                          fontSize: 14.sp,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? gold : textColor,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'أصوات متقسمة آيات',
                                        style: TextStyle(
                                          fontFamily: AppConsts.expoArabic,
                                          fontSize: 10.sp,
                                          color: gold.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: gold,
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      'المحدد',
                                      style: TextStyle(
                                        fontFamily: AppConsts.expoArabic,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeId = cubit.reciter ?? VersePlayerCubit.defaultReciters.keys.first;
    final reciterName = VersePlayerCubit.defaultReciters[activeId] ?? 'اختر القارئ';

    return InkWell(
      onTap: () => _showReciterSelectionModal(context),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 14.sp),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                reciterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 2.w),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 15.sp),
          ],
        ),
      ),
    );
  }
}
