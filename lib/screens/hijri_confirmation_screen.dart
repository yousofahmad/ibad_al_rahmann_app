import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/hijri_source_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class HijriConfirmationScreen extends StatefulWidget {
  const HijriConfirmationScreen({super.key});

  @override
  State<HijriConfirmationScreen> createState() =>
      _HijriConfirmationScreenState();
}

class _HijriConfirmationScreenState extends State<HijriConfirmationScreen> {
  bool _isLoading = false;

  Future<void> _syncOnline() async {
    setState(() => _isLoading = true);
    final success = await HijriSourceService.forceSync();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تأكيد التاريخ الهجري وتحديثه بنجاح من المصدر الرسمي.',
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر الاتصال بالمصدر الرسمي. يرجى التحقق من الإنترنت أو التأكيد يدوياً.',
          ),
        ),
      );
    }
  }

  Future<void> _manualConfirm(bool isNewMonth) async {
    if (PrayerService.isEgyptianSystem) {
      final current = Provider.of<PrayerService>(
        context,
        listen: false,
      ).getAdjustedHijri();
      var month = current.hMonth;
      var year = current.hYear;
      if (isNewMonth && current.hDay != 1) {
        if (month == 12) {
          month = 1;
          year++;
        } else {
          month++;
        }
      } else if (!isNewMonth && current.hDay == 1) {
        if (month == 1) {
          month = 12;
          year--;
        } else {
          month--;
        }
      }
      final success = await HijriSourceService.setManualHijriDate(
        HijriSourceDate(day: isNewMonth ? 1 : 30, month: month, year: year),
      );
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر مطابقة التاريخ المختار مع تقويم المكتبة. جرّب التحديث من الإنترنت.',
            ),
          ),
        );
        return;
      }
    } else {
      // Umm al-Qura stays library-based; the manual day adjustment remains
      // independent from the Egyptian authority date.
      final prefs = CacheHelper.prefs;
      final currentAdjustment = prefs.getInt('manual_day_adjustment') ?? 0;
      await prefs.setInt(
        'manual_day_adjustment',
        currentAdjustment + (isNewMonth ? 1 : 0),
      );
      Provider.of<PrayerService>(context, listen: false).refreshUI();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل التأكيد اليدوي بنجاح.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEgyptian = PrayerService.isEgyptianSystem;
    final currentHijri = Provider.of<PrayerService>(context).getAdjustedHijri();
    final savedDate = HijriSourceService.storedHijriDate;
    final hasTrustedDate = HijriSourceService.hasTrustedStoredDate;

    // For manual adjustment display
    final currentManualAdjustment =
        CacheHelper.prefs.getInt('manual_day_adjustment') ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تأكيد التاريخ الهجري',
          style: TextStyle(fontFamily: AppConsts.cairo),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: Color(0xFFD0A871),
            ),
            const SizedBox(height: 24),
            Text(
              'التاريخ المعروض الآن: ${currentHijri.hDay} ${currentHijri.longMonthName} ${currentHijri.hYear} هـ',
              style: TextStyle(
                fontSize: 16,
                fontFamily: AppConsts.cairo,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD0A871),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isEgyptian
                  ? savedDate == null || !hasTrustedDate
                        ? 'لا يوجد تاريخ موثوق محفوظ من API دار الإفتاء؛ يعرض التطبيق تاريخ المكتبة مؤقتًا مع هذا التحذير. بعد اكتمال يوم 29 وعند منتصف الليل التالي يحاول التطبيق التحديث من دار الإفتاء، ويستخدم جدول هيئة المساحة الكامل للتحقق يوميًا حتى يتطابق، ويعيد المحاولة عند فتح الجهاز إذا كان مغلقًا.'
                        : 'التاريخ المصري المحفوظ: ${savedDate.day}/${savedDate.month}/${savedDate.year} هـ. بعد اكتمال يوم 29 وعند منتصف الليل التالي يحاول التطبيق التحديث من دار الإفتاء، ثم يعيد مقارنة بيانات هيئة المساحة يوميًا إذا لم تتطابق. الإشعار خارج التطبيق إشعار نظام Android عادي قابل للضغط، وليس منبه صلاة.'
                  : 'يعرض هذا النظام تاريخ أم القرى المحسوب بالمكتبة. التعديلات اليدوية تبقى محلية ولا تحتاج إلى اتصال بالإنترنت.',
              style: TextStyle(
                fontSize: 16,
                fontFamily: AppConsts.cairo,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (isEgyptian) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _syncOnline,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: const Text(
                  'تحديث من الإنترنت الآن',
                  style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: const Color(0xFFD0A871),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
            ],
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              "أو أكّد بنفسك (الخطة البديلة):",
              style: TextStyle(
                fontSize: 18,
                fontFamily: AppConsts.cairo,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _manualConfirm(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(
                      isEgyptian
                          ? 'اليوم 30\nمن الشهر الحالي'
                          : 'لسه يوم 29\n(الشهر مخلصش)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: AppConsts.cairo),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _manualConfirm(true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(
                      isEgyptian
                          ? 'غرة الشهر الجديد\n(اليوم 1)'
                          : 'بدأ الشهر الجديد\n(غرة شهر جديد)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: AppConsts.cairo),
                    ),
                  ),
                ),
              ],
            ),
            if (!isEgyptian) ...[
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "ضبط يدوي إضافي",
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "في حالة وجود خطأ دائم رغم التأكيد، يمكنك تعديل التاريخ يدوياً.",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: AppConsts.cairo,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      CacheHelper.prefs.setInt(
                        'manual_day_adjustment',
                        currentManualAdjustment + 1,
                      );
                      Provider.of<PrayerService>(
                        context,
                        listen: false,
                      ).refreshUI();
                      setState(() {});
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFFD0A871),
                    iconSize: 32,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text(
                        "التاريخ: ${Provider.of<PrayerService>(context).getAdjustedHijriString()}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: AppConsts.cairo,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD0A871),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "التعديل: $currentManualAdjustment يوم",
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: AppConsts.cairo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      CacheHelper.prefs.setInt(
                        'manual_day_adjustment',
                        currentManualAdjustment - 1,
                      );
                      Provider.of<PrayerService>(
                        context,
                        listen: false,
                      ).refreshUI();
                      setState(() {});
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    color: const Color(0xFFD0A871),
                    iconSize: 32,
                  ),
                ],
              ),
              if (currentManualAdjustment != 0) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    CacheHelper.prefs.setInt('manual_day_adjustment', 0);
                    Provider.of<PrayerService>(
                      context,
                      listen: false,
                    ).refreshUI();
                    setState(() {});
                  },
                  child: const Text(
                    "إعادة ضبط",
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
