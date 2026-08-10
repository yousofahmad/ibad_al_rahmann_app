import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ibad_al_rahmann/core/theme/app_images.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'home_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final GlobalKey _captureKey = GlobalKey(); // Add capture key
  bool isLastPage = false;

  void _finish() async {
    // Show Pre-Permission Dialog for Location — user can grant or skip freely
    if (mounted) {
      bool? userWantsLocation;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text(
            "إذن الموقع",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD0A871),
            ),
            textDirection: TextDirection.rtl,
          ),
          content: const Text(
            "يستخدم التطبيق موقعك لحساب مواقيت الصلاة واتجاه القبلة بدقة.\n\n"
            "يمكنك تفعيله لاحقاً من إعدادات التطبيق إن أردت.",
            style: TextStyle(fontFamily: AppConsts.expoArabic),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () {
                userWantsLocation = false;
                Navigator.pop(ctx);
              },
              child: const Text(
                "تخطي",
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                userWantsLocation = true;
                Navigator.pop(ctx);
              },
              child: const Text(
                "السماح",
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
      if (userWantsLocation == true) {
        await Permission.location.request();
      }
    }

    // 2. Request Battery Optimization Permission (Critical for reliable Adhan)
    if (mounted) {
      await NotificationService.checkAndRequestBatteryPermission(context);
    }

    // 3. حفظ أن المستخدم شاف الـ onboarding
    final prefs = CacheHelper.prefs;
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
        child: RepaintBoundary(
          key: _captureKey,
          child: Stack(
            children: [
              PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => isLastPage = index == 9); // 10 Pages total (0-9)
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
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'عِبَادُ الرَّحْمَٰن',
                              style: TextStyle(
                                fontFamily: AppConsts.motoNastaliq,
                                fontSize: 40.sp,
                                fontWeight: FontWeight.bold,
                                color: goldColor,
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              'أَلاَ بِذِكْرِ اللّهِ تَطْمَئِنُّ الْقُلُوبُ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppConsts.uthmanic,
                                fontSize: 22.sp,
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

                  // 1. بدون إنترنت (Offline First)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      Icons.wifi_off_rounded,
                      color: goldColor,
                      size: 100.w,
                    ),
                    title: "يعمل بدون إنترنت تماماً",
                    subtitle:
                        "المصحف، الأذكار، والقبلة متاحة دائماً بدون نت. نحتاج للإنترنت فقط عند: تحميل أصوات الأذان، تحديث موقعك، أو استقبال التنبيهات.",
                    isDark: isDark,
                  ),

                  // 2. مشاركة الصور (HD Sharing)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      Icons.auto_awesome_mosaic_rounded,
                      color: goldColor,
                      size: 100.w,
                    ),
                    title: "مشاركة القرآن بجودة HD",
                    subtitle:
                        "حول أي آية إلى بطاقة دعوية جميلة بجودة فائقة (HD) وشاركها بلمسة واحدة مع أهلك وأصحابك.",
                    isDark: isDark,
                  ),

                  // 3. مزامنة البيانات (Drive Sync)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      FontAwesomeIcons.googleDrive,
                      color: goldColor,
                      size: 90.w,
                    ),
                    title: "مزامنة بياناتك وسجلاتك",
                    subtitle:
                        "اربط حسابك بـ Google Drive لتضمن حفظ ختماتك، صلواتك، وإعداداتك واستعادتها بسهولة على أي جهاز.",
                    isDark: isDark,
                  ),

                  // 4. إشعارات ذكية (Smart Notifications)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      Icons.notifications_active_outlined,
                      color: goldColor,
                      size: 100.w,
                    ),
                    title: "إشعارات ذكية ومستمرة",
                    subtitle:
                        "شريط مواقيت الصلاة يرافقك دائماً بالعد التنازلي، مع دعم كامل لوضع رمضان والتعديل اليدوي للمواقيت.",
                    isDark: isDark,
                  ),

                  // 5. الختمات (Khatma Planning)
                  _buildPage(
                    context,
                    imageWidget: SvgPicture.asset(
                      isDark
                          ? AppImages.sectionsQuranDark
                          : AppImages.sectionsQuranLight,
                      width: 120.w,
                      height: 120.h,
                    ),
                    title: "خطط لختمتك القادمة",
                    subtitle:
                        "نظام ذكي لجدولة الختمات ومتابعة وردك اليومي، مع تنبيهات ذكية لتذكيرك في الوقت الذي تحدده.",
                    isDark: isDark,
                  ),

                  // 6. المكتبة الشاملة (Library)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      FontAwesomeIcons.bookOpenReader,
                      color: goldColor,
                      size: 80.w,
                    ),
                    title: "مكتبة شاملة في جيبك",
                    subtitle:
                        "أذكار حصن المسلم، الأربعون النووية، الرقية الشرعية، وأكثر.. كلها بين يديك بتصميم مريح للعين.",
                    isDark: isDark,
                  ),

                  // 7. حاسب نفسك (Accountability)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      FontAwesomeIcons.listCheck,
                      color: goldColor,
                      size: 80.w,
                    ),
                    title: "حاسب نفسك",
                    subtitle:
                        "سجل صلواتك، صيامك، وسننك اليومية لتقيم أداءك وتستمر في التقدم والنمو الإيماني.",
                    isDark: isDark,
                  ),

                  // 8. الصلاة على النبي (Friday Reminders)
                  _buildPage(
                    context,
                    imageWidget: Text(
                      'ﷺ',
                      style: TextStyle(fontSize: 70.sp, color: goldColor),
                    ),
                    title: "الصلاة على النبي ﷺ",
                    subtitle:
                        "نظام تنبيهات خاص للصلاة على النبي ﷺ تذكراً بسنته الشريفة، مع اهتمام خاص بيوم الجمعة.",
                    isDark: isDark,
                  ),

                  // 9. مميزات متقدمة (Advanced Features)
                  _buildPage(
                    context,
                    imageWidget: Icon(
                      Icons.settings_suggest_rounded,
                      color: goldColor,
                      size: 100.w,
                    ),
                    title: "تحكم كامل وتنبيهات ذكية",
                    subtitle:
                        "يمكنك الآن تخطي وضع الصامت للأذان، وتحديد مستوى صوت مخصص للإشعارات يستعيد نفسه تلقائياً.. ستجد هذه الخيارات في 'الإعدادات المتقدمة'.",
                    isDark: isDark,
                  ),
                ],
              ),

              // ================= الزرار والنقط (ثابتين) =================
              Positioned(
                bottom: 40.h,
                left: 20.w,
                right: 20.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 40.w,
                          vertical: 12.h,
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
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 18.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SmoothPageIndicator(
                      controller: _controller,
                      count: 10, // 1 Welcome + 9 Features
                      effect: ExpandingDotsEffect(
                        activeDotColor: goldColor,
                        dotColor: isDark
                            ? Colors.grey[800]!
                            : Colors.grey[300]!,
                        dotHeight: 8.h,
                        dotWidth: 8.w,
                        spacing: 5.w,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // الصورة أو الأيقونة
          Container(
            width: 220.w, // Fixed width
            height: 220.h, // Fixed height
            padding: EdgeInsets.all(40.w), // Adjusted padding
            decoration: BoxDecoration(
              color: const Color(0xFFD0A871).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: FittedBox(child: imageWidget), // Ensure icon fits
          ),
          SizedBox(height: 40.h),

          // العنوان
          Text(
            title,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 30.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD0A871),
            ),
          ),
          SizedBox(height: 15.h),

          // الوصف
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 16.sp,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
