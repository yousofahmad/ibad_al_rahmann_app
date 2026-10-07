import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';

class ReciterDropdown extends StatelessWidget {
  final VersePlayerCubit cubit;

  const ReciterDropdown({super.key, required this.cubit});

  static void showReciterSelectionModal(BuildContext context, VersePlayerCubit cubit) {
    final activeModel =
        cubit.currentReciterModel ??
        ReciterAudioHelper.getReciterById(cubit.reciter ?? 'mishari_alafasy');
    String searchQuery = '';
    String? selectedCategory;

    final allReciters = VersePlayerCubit.allReciters;
    final categories = [
      'الكل',
      'عمالقة القراء (مصر)',
      'أئمة الحرمين الشريفين',
      'مشاهير القراء',
      'المصحف المعلم',
      'قراءات وروايات',
    ];

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

            final filteredReciters = allReciters.where((r) {
              if (selectedCategory != null &&
                  selectedCategory != 'الكل' &&
                  r.category != selectedCategory) {
                return false;
              }
              if (searchQuery.trim().isEmpty) return true;
              final q = searchQuery.trim().toLowerCase();
              return r.name.toLowerCase().contains(q) ||
                  r.style.toLowerCase().contains(q) ||
                  r.category.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: context.screenHeight * 0.82,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 6.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.record_voice_over_rounded,
                          color: gold,
                          size: 24.sp,
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'اختيار القارئ ونمط التظليل',
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 16.5.sp,
                            fontWeight: FontWeight.bold,
                            color: gold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mode Toggle Bar (Word by Word vs Verse Only)
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: gold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              cubit.setHighlightMode(true);
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(12.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                color: cubit.isHighlightWordByWord
                                    ? gold
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.spellcheck_rounded,
                                    size: 16.sp,
                                    color: cubit.isHighlightWordByWord
                                        ? Colors.white
                                        : textColor.withValues(alpha: 0.6),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'مقسم كلمات (تظليل كلمة)',
                                    style: TextStyle(
                                      fontFamily: AppConsts.expoArabic,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: cubit.isHighlightWordByWord
                                          ? Colors.white
                                          : textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              cubit.setHighlightMode(false);
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(12.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                color: !cubit.isHighlightWordByWord
                                    ? gold
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories_rounded,
                                    size: 16.sp,
                                    color: !cubit.isHighlightWordByWord
                                        ? Colors.white
                                        : textColor.withValues(alpha: 0.6),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'مقسم آيات (تظليل آية)',
                                    style: TextStyle(
                                      fontFamily: AppConsts.expoArabic,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: !cubit.isHighlightWordByWord
                                          ? Colors.white
                                          : textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 4.h,
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 13.5.sp,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم القارئ...',
                        hintStyle: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 13.sp,
                          color: textColor.withValues(alpha: 0.45),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: gold,
                          size: 20.sp,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Category Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    child: Row(
                      children: categories.map((cat) {
                        final isCatSelected =
                            (selectedCategory == cat) ||
                            (selectedCategory == null && cat == 'الكل');
                        return Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedCategory = cat == 'الكل' ? null : cat;
                              });
                            },
                            borderRadius: BorderRadius.circular(12.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 5.h,
                              ),
                              decoration: BoxDecoration(
                                color: isCatSelected
                                    ? gold
                                    : (isDark
                                          ? Colors.white10
                                          : Colors.black.withValues(
                                              alpha: 0.04,
                                            )),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isCatSelected
                                      ? Colors.white
                                      : textColor.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Reciters List
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 6.h,
                      ),
                      itemCount: filteredReciters.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: textColor.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, index) {
                        final reciterItem = filteredReciters[index];
                        final isSelected = reciterItem.id == activeModel.id;
                        final hasWbw =
                            reciterItem.highlightSupport ==
                            ReciterHighlightSupport.wordByWord;

                        return InkWell(
                          onTap: () {
                            cubit.selectReciter(reciterItem);
                            Navigator.pop(modalCtx);
                          },
                          borderRadius: BorderRadius.circular(14.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? gold.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38.w,
                                  height: 38.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? gold
                                        : gold.withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_rounded
                                        : Icons.headphones_rounded,
                                    color: isSelected ? Colors.white : gold,
                                    size: 18.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        reciterItem.name,
                                        style: TextStyle(
                                          fontFamily: AppConsts.expoArabic,
                                          fontSize: 14.sp,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isSelected ? gold : textColor,
                                        ),
                                      ),
                                      SizedBox(height: 3.h),
                                      Wrap(
                                        spacing: 6.w,
                                        runSpacing: 4.h,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 1.5.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: (isDark
                                                  ? Colors.white12
                                                  : Colors.black12),
                                              borderRadius:
                                                  BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              reciterItem.style,
                                              style: TextStyle(
                                                fontFamily: AppConsts.cairo,
                                                fontSize: 9.5.sp,
                                                fontWeight: FontWeight.bold,
                                                color: textColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 1.5.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: hasWbw
                                                  ? const Color(0xFF4CAF50)
                                                      .withValues(alpha: 0.15)
                                                  : const Color(0xFFD0A871)
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              hasWbw
                                                  ? '🔤 تظليل كلمة بكلمة وآيات'
                                                  : (reciterItem.hasSegments
                                                        ? '📖 تظليل بالآيات'
                                                        : '🎧 تلاوة السورة'),
                                              style: TextStyle(
                                                fontFamily: AppConsts.cairo,
                                                fontSize: 9.5.sp,
                                                fontWeight: FontWeight.bold,
                                                color: hasWbw
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFFD0A871),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 3.h,
                                    ),
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
    final activeModel =
        cubit.currentReciterModel ??
        ReciterAudioHelper.getReciterById(cubit.reciter ?? 'mishari_alafasy');

    return InkWell(
      onTap: () => showReciterSelectionModal(context, cubit),
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
            Icon(
              Icons.record_voice_over_rounded,
              color: Colors.white,
              size: 14.sp,
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                activeModel.name,
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
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 15.sp,
            ),
          ],
        ),
      ),
    );
  }
}
