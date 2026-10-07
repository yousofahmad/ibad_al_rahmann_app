import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/screens/app_features_guide_screen.dart';

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  static const String _versionKey = 'last_seen_whats_new_version';
  static const String _currentVersion = '1.3.0';

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
        'title': 'المكتبة الصوتية الشاملة الموحدة (41 قارئاً) وتظليل الكلمات',
        'desc':
            'توحيد قاعدة بيانات القراء كاملة (41 قارئاً) في جميع شاشات التطبيق والمصحف، مع دعم وضع القراءة كلمة بكلمة والتظليل المتزامن الذهبي والتشغيل المباشر بسلاسة تامة.',
      },
      {
        'icon': Icons.auto_stories_rounded,
        'color': const Color(0xFFD0A871),
        'title': 'دعاء ختم القرآن المأثور (كتاب الأذكار للنووي) وبطاقات المشاركة',
        'desc':
            'اعتماد نص دعاء ختم القرآن المأثور والمستحب من كتاب الأذكار للإمام النووي، مع إمكانية مشاركته أو حفظه كصورة إسلامية فاخرة بثيمات متعددة عالية الدقة.',
      },
      {
        'icon': Icons.checklist_rounded,
        'color': const Color(0xFF2E7D32),
        'title': 'احتساب الختمات في إنجاز "حاسب نفسك" والخط القرآني',
        'desc':
            'احتساب أوراد الختمات النشطة وسورة الكهف تلقائياً في نسبة الإنجاز اليومي بمجرد إتمام الورد، مع تزيين العناوين بالخط القرآني الأصيل.',
      },
      {
        'icon': Icons.stay_current_portrait_rounded,
        'color': const Color(0xFFE65100),
        'title': 'وضع ستوري واتساب (9:16) فائق الدقة لأيام الصيام',
        'desc':
            'مشاركة بطاقات صيام التطوع بحجم ستوري كامل (9:16) وبدقة تصل إلى 4K فائقة الوضوح وبأبعاد 1080×1920 القياسية بدون أي بكسلة أو هوامش سوداء، مع إرفاق 29 نية مباركة لصيام التطوع.',
      },
      {
        'icon': Icons.dark_mode_rounded,
        'color': const Color(0xFF7B1FA2),
        'title': 'التوافق الكامل مع الخلفيات السوداء والداكنة',
        'desc':
            'عند اختيار خلفية سوداء أو داكنة لتصميم الصيام، تتناسق البطاقات وصناديق النوايا تلقائياً باللون الفحمي الفاخر والخطوط الذهبية والكريمة بدون ظهور مربعات بيضاء داخلية.',
      },
      {
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFFC2185B),
        'title': 'تثبيت وقفل التاريخ الهجري المصري طوال الشهر',
        'desc':
            'تثبيت التاريخ الرسمي لجمهورية مصر العربية تلقائياً من دار الإفتاء وهيئة المساحة، وقفل الإزاحة طوال أيام الشهر حتى يوم 29 لضمان أقصى درجات الدقة والاستقرار.',
      },
      {
        'icon': Icons.sync_rounded,
        'color': const Color(0xFF00897B),
        'title': 'مزامنة شاشة "حاسب نفسك" التلقائية في الخلفية',
        'desc':
            'حساب إنجاز اليوم والصلوات وحفظها فورياً من خلال شاشة القفل والإشعارات بدون الحاجة لفتح الشاشة، مع تصفير نظيف كل فجر وحماية السلاسل التاريخية.',
      },
      {
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF2E7D32),
        'title': 'استعادة العرض الكامل لصفحة المصحف في الورد',
        'desc':
            'عرض صفحات المصحف الشريف في قارئ الورد القرآني بـ 15 سطراً أصيلاً وأبعاد مطابقة تماماً للمصحف العادي مع تجربة قراءة خاشعة وغامرة.',
      },
      {
        'icon': Icons.nightlight_round,
        'color': const Color(0xFF0288D1),
        'title': 'معالجة توقيت العشاء المتأخر بعد منتصف الليل',
        'desc':
            'توحيد تسجيل صلاة العشاء المتأخرة بعد منتصف الليل وحتى أذان الفجر لتُحتسب دائماً ضمن اليوم النشط الفعلي الصحيح.',
      },
    ];

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                    "ما الجديد في هذا التحديث ✨",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 19.sp,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
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
                          color: (item['color'] as Color).withValues(
                            alpha: 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: item['color'] as Color,
                          size: 22.sp,
                        ),
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
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              item['desc'] as String,
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontSize: 11.5.sp,
                                height: 1.45,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
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

            // Features Guide Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: SizedBox(
                width: double.infinity,
                height: 42.h,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldColor,
                    side: const BorderSide(color: goldColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: Icon(Icons.explore_rounded, size: 18.sp),
                  label: Text(
                    "📖 استكشف دليل مميزات التطبيق الشامل",
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppFeaturesGuideScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Dismiss Button
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "متابعة واستخدام التطبيق",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 14.sp,
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
