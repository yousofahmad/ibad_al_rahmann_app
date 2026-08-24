import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  static const String _versionKey = 'last_seen_whats_new_version';
  static const String _currentVersion = '1.1.5';

  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = CacheHelper.prefs;
    final lastSeen = prefs.getString(_versionKey);
    if (lastSeen != _currentVersion) {
      // Small delay after first render
      await Future.delayed(const Duration(milliseconds: 800));
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const WhatsNewDialog(),
      );
      await prefs.setString(_versionKey, _currentVersion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFD0A871);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1A18);

    final List<Map<String, dynamic>> items = [
      {
        'icon': Icons.insights_rounded,
        'color': const Color(0xFF00897B),
        'title': 'رسوم بيانية وإحصائيات تفاعلية في "صلاتي"',
        'desc': 'إتمام الصلاة الأسبوعي بمنحنى بياني تفاعلي، ومقارنة الانتظام (في وقتها / متأخراً / فائتة)، وتحليل الصلاة الأكثر تأخيراً مع تقويم شهري هجري وميلادي شامل.',
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFE65100),
        'title': 'الستريك الشامل ودقة تسجيل الصلوات',
        'desc': 'الستريك الآن متواصل وغير مقيد بشهر واحد، مع استجابة فورية عند تسجيل الصلاة وضمان عدم تكرار ظهور النافذة.',
      },
      {
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF2E7D32),
        'title': 'تطوير المصحف الشريف ومواضع الأحزاب',
        'desc': 'عرض علامات الحزب (بداية، نصف، ثلاثة أرباع) بتنسيق متناسق، مع تبديل فوري وسلس بين الوضعين المصغر والمكبر بالضغط المزدوج.',
      },
      {
        'icon': Icons.notifications_active_rounded,
        'color': const Color(0xFF0288D1),
        'title': 'تحسين الصلاة على النبي ﷺ وقفل الشاشة',
        'desc': 'نافذة متناسقة وأنيقة مع دعم اختيار صوت مخصص من الهاتف وتفعيل مستوى صوت مستقل وتلقائي.',
      },
      {
        'icon': Icons.cloud_sync_rounded,
        'color': const Color(0xFF6A1B9A),
        'title': 'مزامنة ونسخ احتياطي فائق الاستقرار',
        'desc': 'تحديث شامل لآلية تسجيل الدخول في Google Drive وحفظ النسخ الاحتياطية بأمان تام دون تعليق.',
      },
      {
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFD0A871),
        'title': 'استقرار تام وتحديث تلقائي دائم',
        'desc': 'تحديث ذاتي ومستمر للمواقيت والتاريخ الهجري حتى دون فتح التطبيق، واستجابة فائقة لإيقاف الصوت ونظام قلب الهاتف دون أي تهنيج بعد إعادة تشغيل الجهاز.',
      },
    ];

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 6.h),
                  Text(
                    "ما الجديد في هذا التحديث ",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                  Text(
                    "الإصدار $_currentVersion",
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(height: 14.h),
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              item['desc'] as String,
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontSize: 12.sp,
                                height: 1.5,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Dismiss Button
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "متابعة واستخدام التطبيق",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
