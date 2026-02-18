import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ibad_al_rahmann/core/theme/app_images.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  void _finish() async {
    // Show Pre-Permission Dialog for Location
    // طلب إذن الموقع (مهم للمواقيت والقبلة)
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text(
            "تنويه هام حول الأذونات",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD0A871),
            ),
            textDirection: TextDirection.rtl,
          ),
          content: const Text(
            "يحتاج التطبيق إلى معرفة موقعك الجغرافي فقط لحساب مواقيت الصلاة واتجاه القبلة بدقة.\n\n"
            "نحن نحترم خصوصيتك ولا نقوم بجمع أو مشاركة أي بيانات شخصية.\n"
            "هذا الإذن ضروري لعمل التطبيق بشكل صحيح.",
            style: TextStyle(fontFamily: AppConsts.expoArabic),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "فهمت ذلك",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Color(0xFFD0A871),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    await Permission.location.request();

    // 2. حفظ أن المستخدم شاف الـ onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحديد الألوان حسب المود
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white; // أسود حالك في الليلي

    // 🔥 إصلاح لون الآية: أبيض في الدارك، أسود في اللايت
    final verseColor = isDark ? Colors.white : Colors.black87;

    // ألوان النصوص الفرعية
    // final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    const goldColor = Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => isLastPage = index == 7); // 8 Pages (0-7)
              },
              children: [
                // 0. Welcome Screen (Splash Style)
                Stack(
                  children: [
                    // Background Image
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        'assets/images/mosque_bottom.webp',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Content Overlay
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Logo/Icon

                          // App Name
                          const Text(
                            'عِبَادُ الرَّحْمَٰن',
                            style: TextStyle(
                              fontFamily: AppConsts.motoNastaliq,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Ayah
                          Text(
                            'أَلاَ بِذِكْرِ اللّهِ تَطْمَئِنُّ الْقُلُوبُ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppConsts.uthmanic,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: verseColor,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 1. بدون إنترنت (Offline)
                _buildPage(
                  context,
                  imageWidget: const Icon(
                    Icons.wifi_off_rounded,
                    color: goldColor,
                    size: 100, // Explicit size for Icon
                  ),
                  title: "يعمل بدون إنترنت",
                  subtitle:
                      "استمتع بكافة المميزات دون نت (تحميل أصوات الأذان فقط يحتاج لاتصال).",
                  isDark: isDark,
                ),

                // 2. المصحف والورد (Quran + Wird)
                _buildPage(
                  context,
                  imageWidget: SvgPicture.asset(
                    isDark
                        ? AppImages.sectionsQuranDark
                        : AppImages.sectionsQuranLight,
                    width: 120,
                    height: 120,
                  ),
                  title: "القرآن والورد اليومي",
                  subtitle:
                      "اقرأ القرآن الكريم بسهولة مع خاصية الورد اليومي والتنبيهات الذكية.",
                  isDark: isDark,
                ),

                // 2. حصن المسلم والنووية (Hisn + Nawawi)
                _buildPage(
                  context,
                  imageWidget: const Icon(
                    FontAwesomeIcons.bookOpenReader,
                    color: goldColor,
                    size: 80,
                  ),
                  title: "حصن المسلم والنووية",
                  subtitle:
                      "موسوعة شاملة من الأذكار الصحيحة والأحاديث النبوية (الأربعين النووية).",
                  isDark: isDark,
                ),

                // 4. الأذكار (Azkar) - Using Sebha Image
                _buildPage(
                  context,
                  imageWidget: Image.asset(
                    'assets/images/pngtree-luxury-islamic-prayer-beads-macro-png-image_18712828.webp',
                    fit: BoxFit.contain,
                  ),
                  title: "أذكار الصباح والمساء",
                  subtitle:
                      "حافظ على أذكار الصباح والمساء\nلتكون في حفظ الله ورعايته.",
                  isDark: isDark,
                ),

                // 5. مواقيت الصلاة والقبلة (Prayer + Qiblah)
                _buildPage(
                  context,
                  imageWidget: const Icon(
                    FontAwesomeIcons.mosque,
                    color: goldColor,
                    size: 80,
                  ),
                  title: "مواقيت الصلاة والقبلة",
                  subtitle:
                      "تعرف على مواقيت الصلاة بدقة واتجاه القبلة أينما كنت.",
                  isDark: isDark,
                ),

                // 6. حاسب نفسك (Accountability)
                _buildPage(
                  context,
                  imageWidget: const Icon(
                    FontAwesomeIcons.listCheck,
                    color: goldColor,
                    size: 80,
                  ),
                  title: "حاسب نفسك",
                  subtitle:
                      "جدول لمحاسبة النفس ومتابعة الصلوات والسنن بانتظام.",
                  isDark: isDark,
                ),

                // 7. الصلاة على النبي (Friday Reminders)
                _buildPage(
                  context,
                  imageWidget: const Text(
                    'ﷺ',
                    style: TextStyle(fontSize: 70, color: goldColor),
                  ),
                  title: "الصلاة على النبي ﷺ",
                  subtitle:
                      "تذكير دائم بالصلاة على النبي ﷺ\nخصوصاً في يوم الجمعة المبارك.",
                  isDark: isDark,
                ),
              ],
            ),

            // ================= الزرار والنقط (ثابتين) =================
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      elevation: 5,
                    ),
                    onPressed: () {
                      if (isLastPage) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(
                      isLastPage ? "ابدأ" : "التالي",
                      style: const TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SmoothPageIndicator(
                    controller: _controller,
                    count: 8, // 1 Welcome + 7 Features
                    effect: ExpandingDotsEffect(
                      activeDotColor: goldColor,
                      dotColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت لبناء الصفحات المتكررة بسهولة
  Widget _buildPage(
    BuildContext context, {
    required Widget imageWidget,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      color: isDark ? Colors.black : Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // الصورة أو الأيقونة
          Container(
            width: 220, // Fixed width
            height: 220, // Fixed height
            padding: const EdgeInsets.all(40), // Adjusted padding
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: FittedBox(child: imageWidget), // Ensure icon fits
          ),
          const SizedBox(height: 40),

          // العنوان
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD0A871),
            ),
          ),
          const SizedBox(height: 15),

          // الوصف
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 16,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
