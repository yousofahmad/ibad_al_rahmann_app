import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/services/hijri_source_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class HijriConfirmationScreen extends StatefulWidget {
  const HijriConfirmationScreen({super.key});

  @override
  State<HijriConfirmationScreen> createState() => _HijriConfirmationScreenState();
}

class _HijriConfirmationScreenState extends State<HijriConfirmationScreen> {
  bool _isLoading = false;

  Future<void> _syncOnline() async {
    setState(() => _isLoading = true);
    final success = await HijriSourceService.forceSync();
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد التاريخ الهجري وتحديثه بنجاح من المصدر الرسمي.')),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بالمصدر الرسمي. يرجى التحقق من الإنترنت أو التأكيد يدوياً.')),
      );
    }
  }

  Future<void> _manualConfirm(bool isNewMonth) async {
    // Save manual offset
    final currentLocalOffset = CacheHelper.prefs.getInt('local_hijri_offset') ?? 0;
    
    if (isNewMonth) {
      // Advance by 1 day
      await HijriSourceService.setManualOffset(currentLocalOffset + 1);
    } else {
      // Keep same offset
      await HijriSourceService.setManualOffset(currentLocalOffset);
    }
    
    // Set source flag for manual confirmation
    final todayStr = DateTime.now().toString().substring(0, 10);
    await CacheHelper.prefs.setString('local_hijri_confirmed_source_$todayStr', 'manual');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل التأكيد اليدوي بنجاح.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // For manual adjustment display
    final currentManualAdjustment = CacheHelper.prefs.getInt('manual_day_adjustment') ?? 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد التاريخ الهجري', style: TextStyle(fontFamily: AppConsts.cairo)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 64, color: Color(0xFFD0A871)),
            const SizedBox(height: 24),
            Text(
              "تعذر التأكد من التاريخ الهجري الدقيق لليوم لعدم وجود اتصال بالإنترنت وقت الفحص التلقائي.\n\nنحتاج لمعرفة ما إذا كان الشهر الهجري قد انتهى أم لا لتصحيح الأوراد والأذكار.",
              style: TextStyle(fontSize: 16, fontFamily: AppConsts.cairo, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _syncOnline,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync),
              label: const Text('تحديث من الإنترنت الآن', style: TextStyle(fontFamily: AppConsts.cairo, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              "أو أكّد بنفسك (الخطة البديلة):",
              style: TextStyle(fontSize: 18, fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _manualConfirm(false),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('لسه يوم 29\n(الشهر مخلصش)', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppConsts.cairo)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _manualConfirm(true),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('بدأ الشهر الجديد\n(غرة شهر جديد)', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppConsts.cairo)),
                  ),
                ),
              ],
            ),
            if (!PrayerService.isEgyptianSystem) ...[
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "ضبط يدوي إضافي",
                style: TextStyle(fontSize: 18, fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "في حالة وجود خطأ دائم رغم التأكيد، يمكنك تعديل التاريخ يدوياً.",
                style: TextStyle(fontSize: 14, fontFamily: AppConsts.cairo, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      CacheHelper.prefs.setInt('manual_day_adjustment', currentManualAdjustment + 1);
                      Provider.of<PrayerService>(context, listen: false).refreshUI();
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
                        style: const TextStyle(fontSize: 18, fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold, color: Color(0xFFD0A871)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "التعديل: $currentManualAdjustment يوم",
                        style: const TextStyle(fontSize: 14, fontFamily: AppConsts.cairo, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      CacheHelper.prefs.setInt('manual_day_adjustment', currentManualAdjustment - 1);
                      Provider.of<PrayerService>(context, listen: false).refreshUI();
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
                    Provider.of<PrayerService>(context, listen: false).refreshUI();
                    setState(() {});
                  },
                  child: const Text("إعادة ضبط", style: TextStyle(fontFamily: AppConsts.cairo, color: Colors.red)),
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
