import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

class SupplicationsScreen extends StatelessWidget {
  const SupplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. تعريف الألوان حسب الوضع (ليلي / نهاري)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    // خلفية الجزء المفتوح (الرد)
    final expandedColor = isDark
        ? Colors.black26
        : const Color(0xFFD0A871).withValues(alpha: 0.05);

    final List<Map<String, String>> supplications = [
      {
        'title': '🔹 دعاء الثوب الجديد',
        'content':
            'اللَّهُمَّ لَكَ الْحَمْدُ أَنْتَ كَسَوْتَنِيهِ، أَسْأَلُكَ خَيْرَهُ، وَخَيْرَ مَا صُنِعَ لَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّهِ، وَشرِّ مَا صُنِعَ لَهُ.',
      },
      {
        'title': '🔹 دعاء دخول المسجد',
        'content':
            'بِسْمِ اللَّهِ، وَالصَّلَاةُ وَالسَّلَامُ عَلَى رَسُولِ اللَّهِ، اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ.',
      },
      {
        'title': '🔹 دعاء الكرب',
        'content':
            'لا إله إلا الله العظيم الحليم، لا إله إلا الله رب العرش العظيم، لا إله إلا الله رب السموات والأرض ورب العرش الكريم.\n\nودعاء يونس عليه السلام:\nلا إله إلا أنت سبحانك إني كنت من الظالمين.',
      },
      {
        'title': '🔹 دعاء الاستخارة',
        'content':
            'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ، فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ، وَتَعْلَمُ وَلَا أَعْلَمُ، وَأَنْتَ عَلَّامُ الْغُيُوبِ.\n\nاللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ (ويُسَمِّي حاجته) خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي، فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي، ثُمَّ بَارِكْ لِي فِيهِ.\n\nوَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الْأَمْرَ شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي، فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ، وَاقْدُرْ لِيَ الْخَيْرَ حَيْثُ كَانَ، ثُمَّ أَرْضِنِي بِهِ.',
      },
      {
        'title': '🔹 دعاء النوم',
        'content': 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.',
      },
      {
        'title': '🔹 دعاء السفر',
        'content':
            'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ ۝ وَإِنَّا إِلَىٰ رَبِّنَا لَمُنقَلِبُونَ،\n\nاللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَىٰ، وَمِنَ الْعَمَلِ مَا تَرْضَى.',
      },
      {
        'title': '🔹 دعاء الخروج من البيت',
        'content':
            'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ.',
      },
      {
        'title': '🔹 دعاء دخول الخلاء',
        'content':
            'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ.',
      },
      {'title': '🔹 دعاء الخروج من الخلاء', 'content': 'غُفْرَانَكَ.'},
      {'title': '🔹 دعاء قبل الأكل', 'content': 'بِسْمِ اللَّهِ.'},
      {
        'title': '🔹 دعاء بعد الأكل',
        'content':
            'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ.',
      },
      {
        'title': '🔹 دعاء قضاء الدين',
        'content':
            'اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ، وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ.',
      },
      {
        'title': '🔹 دعاء الهم والحزن',
        'content':
            'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْجُبْنِ وَالْبُخْلِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ.',
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'جميع الأدعية',
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
          // ==========================================
          // الهيدر الموحد
          // ==========================================
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF2D69D),
                  Color(0xFFD0A871),
                  Color(0xFFB88A4A),
                ],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: supplications.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  // إزالة الخطوط الفاصلة الافتراضية للـ ExpansionTile
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: const Border(), // إزالة الحدود الداخلية
                    leading: const Icon(
                      Icons.auto_stories,
                      color: Color(0xFFD0A871),
                    ),
                    title: Text(
                      supplications[index]['title']!,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: expandedColor,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              supplications[index]['content']!,
                              textAlign: TextAlign.center,
                              // استخدام خط أميري للقراءة الواضحة
                              style: TextStyle(
                                fontFamily: AppConsts.amiri,
                                fontSize: 20,
                                height: 1.8,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 15),

                            // زر النسخ
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: supplications[index]['content']!,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "تم نسخ الدعاء",
                                      style: TextStyle(
                                        fontFamily: AppConsts.expoArabic,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Color(0xFFD0A871),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.copy,
                                size: 18,
                                color: Color(0xFFD0A871),
                              ),
                              label: const Text(
                                'نسخ الدعاء',
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: Color(0xFFD0A871),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFFD0A871,
                                ).withValues(alpha: 0.1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
