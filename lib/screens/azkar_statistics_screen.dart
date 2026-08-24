import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';

class AzkarStatisticsScreen extends StatefulWidget {
  const AzkarStatisticsScreen({super.key});

  @override
  State<AzkarStatisticsScreen> createState() => _AzkarStatisticsScreenState();
}

class _AzkarStatisticsScreenState extends State<AzkarStatisticsScreen> {
  int _morningCount = 0;
  int _eveningCount = 0;
  int _prayerCount = 0;
  int _ruqyahCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = CacheHelper.prefs;
    setState(() {
      _morningCount = prefs.getInt('count_morning') ?? 0;
      _eveningCount = prefs.getInt('count_evening') ?? 0;
      _prayerCount = prefs.getInt('count_prayer') ?? 0;
      _ruqyahCount = prefs.getInt('count_ruqyah') ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _showZekrDetails(String title, String jsonFile) async {
    try {
      final String raw = await rootBundle.loadString('assets/data/$jsonFile');
      final List<dynamic> list = json.decode(raw);
      final prefs = CacheHelper.prefs;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF1C1A18);
          const goldColor = Color(0xFFD0A871);

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetCtx, scrollController) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 45.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "تفاصيل $title",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                          Text(
                            "${list.length.toArabicDigits} ذكر",
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontSize: 13.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Divider(color: goldColor.withValues(alpha: 0.2)),

                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: list.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, i) {
                            final item = list[i];
                            final text = (item['zekr'] ?? item['ARABIC_TEXT'] ?? item['content'] ?? '').toString().trim();
                            final requiredCount = item['count'] is int ? item['count'] as int : 1;
                            final itemTotalKey = 'azkar_item_total_${jsonFile}_$i';
                            final totalRepeats = prefs.getInt(itemTotalKey) ?? 0;

                            return Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: goldColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    text,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppConsts.amiri,
                                      fontSize: 17.sp,
                                      height: 1.7,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: goldColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          "التكرار بالجلسة: ${requiredCount.toArabicDigits}",
                                          style: TextStyle(
                                            fontFamily: AppConsts.expoArabic,
                                            fontSize: 11.sp,
                                            color: goldColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: totalRepeats > 0
                                              ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                                              : Colors.grey.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          "إجمالي التكرار: ${totalRepeats.toArabicDigits} مرة",
                                          style: TextStyle(
                                            fontFamily: AppConsts.expoArabic,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.bold,
                                            color: totalRepeats > 0
                                                ? const Color(0xFF2E7D32)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint("Error loading zekr details: $e");
    }
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required String jsonFile,
  }) {
    const goldColor = Color(0xFFD0A871);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: goldColor.withValues(alpha: 0.35),
          width: 1.2.w,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: goldColor),
                tooltip: "تفاصيل الأذكار وتكرارها",
                onPressed: () => _showZekrDetails(title, jsonFile),
              ),
              Icon(icon, color: goldColor, size: 36.sp),
              const SizedBox(width: 40), // Balance the (i) icon on left
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              fontFamily: AppConsts.cairo,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            count.toArabicDigits,
            style: TextStyle(
              color: goldColor,
              fontSize: 30.sp,
              fontWeight: FontWeight.bold,
              fontFamily: AppConsts.expoArabic,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            "مرات الإتمام بالكامل",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12.sp,
              fontFamily: AppConsts.cairo,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "إحصائيات الأذكار",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontFamily: AppConsts.cairo,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        centerTitle: true,
      ),
      body: _isLoading
          ? Column(
              children: [
                AppSkeleton.card(height: 140.h),
                SizedBox(height: 16.h),
                AppSkeleton.card(height: 140.h),
              ],
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                children: [
                  _buildStatCard(
                    title: "أذكار الصباح",
                    count: _morningCount,
                    icon: Icons.wb_sunny_rounded,
                    jsonFile: "morning.json",
                  ),
                  _buildStatCard(
                    title: "أذكار المساء",
                    count: _eveningCount,
                    icon: Icons.nights_stay_rounded,
                    jsonFile: "evening.json",
                  ),
                  _buildStatCard(
                    title: "أذكار الصلاة",
                    count: _prayerCount,
                    icon: Icons.mosque_rounded,
                    jsonFile: "prayer.json",
                  ),
                  _buildStatCard(
                    title: "الرقية الشرعية",
                    count: _ruqyahCount,
                    icon: Icons.shield_rounded,
                    jsonFile: "ruqyah.json",
                  ),
                ],
              ),
            ),
    );
  }
}
