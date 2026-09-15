import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  static const String _versionKey = 'last_seen_whats_new_version';
  static const String _currentVersion = '1.2.0';

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
        'icon': Icons.audiotrack_rounded,
        'color': const Color(0xFF00897B),
        'title': 'مشغل القرآن الصوتي والمكتبة الشاملة (41 قارئ)',
        'desc': 'مشغل صوتي حديث وعالي السرعة يضم أكثر من 40 قارئاً من كبار قراء العالم الإسلامي بمختلف الروايات والمصاحف المعلمة، مع تظليل الآيات المتزامن بالمللي ثانية، وسرعات قراءة متعددة، والتحميل للاستماع بدون إنترنت.',
      },
      {
        'icon': Icons.auto_stories_rounded,
        'color': const Color(0xFF5C6BC0),
        'title': 'إضافة تفاسير جديدة (ابن كثير والطبري)',
        'desc': 'إمكانية تحميل وتثبيت تفسير ابن كثير وتفسير الطبري وقراءتها بالكامل بدون إنترنت مع التبديل الفوري بين كتب التفسير لكل آية.',
      },
      {
        'icon': Icons.notifications_active_rounded,
        'color': const Color(0xFF0288D1),
        'title': 'الصلاة على النبي ﷺ عند فتح الشاشة',
        'desc': 'تشغيل تذكير صوتي بالصلاة على النبي ﷺ تلقائياً عند فتح قفل الهاتف، مع إمكانية اختيار نغمة مخصصة من هاتفك وتفعيل مستوى صوت مستقل ومرتفع.',
      },
      {
        'icon': Icons.alarm_on_rounded,
        'color': const Color(0xFFD0A871),
        'title': 'نافذة "صلاتي" الذكية للتنبيه بالصلوات',
        'desc': 'ظهور نافذة تنبيه أنيقة فوق التطبيقات عند دخول وقت الصلاة لتسجيل أدائها (في وقتها أو متأخراً) أو تأجيل التنبيه بكل سهولة.',
      },
      {
        'icon': Icons.insights_rounded,
        'color': const Color(0xFF00897B),
        'title': 'رسوم بيانية وإحصائيات تفاعلية لصلواتك',
        'desc': 'رسم بياني منحني لإتمام الصلوات أسبوعياً، وأعمدة مقارنة مدى الانتظام، وتحليل الصلاة الأكثر تأخيراً مع تقويم شهري هجري وميلادي متكامل.',
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFE65100),
        'title': 'نظام الستريك الشامل للصلوات',
        'desc': 'حساب الستريك بشكل تراكمي ومتواصل عبر الشهور دون انقطاع، سواء سُجلت الصلاة من نافذة التنبيهات أو يدوياً من داخل التطبيق.',
      },
      {
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF2E7D32),
        'title': 'تطوير المصحف الشريف وعلامات الأحزاب',
        'desc': 'إظهار علامات الحزب (بداية، نصف، ثلاثة أرباع) بتناسق مميز، مع سلاسة فائقة في التبديل بين الوضعين المكبر والمصغر بالضغط المزدوج.',
      },
      {
        'icon': Icons.wb_sunny_rounded,
        'color': const Color(0xFFF57F17),
        'title': 'تطوير ستريك وإحصائيات الأذكار',
        'desc': 'احتساب ستريك الأذكار تلقائياً عند إنجاز 50% من العدادات، واستعراض إجمالي تكرار كل ذكر عبر التاريخ بالضغط على علامة (i).',
      },
      {
        'icon': Icons.cloud_sync_rounded,
        'color': const Color(0xFF6A1B9A),
        'title': 'تخصيص النسخ الاحتياطي والمزامنة السحابية',
        'desc': 'إمكانية تحديد الأقسام المراد تصديرها أو استيرادها بدقة، مع مزامنة سحابية مستقرة مع Google Drive وتسمية الملفات بالتاريخ والوقت.',
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
