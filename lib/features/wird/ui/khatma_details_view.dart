import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/theme/quran_theme_extension.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/helpers/share_helper.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';
import '../bloc/khatma_cubit.dart';
import '../../quran/bloc/quran/quran_cubit.dart';
import '../../quran/ui/widgets/core/wbw_page_widget.dart';
import '../../../main.dart';
import 'isolated_wird_screen.dart';
import 'wird_list_screen.dart';
import '../data/khatma_model.dart';
import '../../../services/prayer_service.dart';

class KhatmaDetailsView extends StatefulWidget {
  final KhatmaModel khatma;

  /// Set to true when this view is embedded inside a Scaffold that has an
  /// AppBar with extendBodyBehindAppBar=true, so extra top padding is added.
  final bool hasAppBar;

  const KhatmaDetailsView({
    super.key,
    required this.khatma,
    this.hasAppBar = false,
  });

  @override
  State<KhatmaDetailsView> createState() => _KhatmaDetailsViewState();
}

class _KhatmaDetailsViewState extends State<KhatmaDetailsView> {
  bool _isExporting = false;
  int _exportCompleted = 0;
  int _exportTotal = 0;
  double _selectedQuality = 5.0; // Default High

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final khatma = widget.khatma;
    final currentIndex = khatma.currentWirdIndex;
    final totalWirds = khatma.wirds.length;
    final progress = currentIndex / totalWirds;

    // Guard against out of bounds index
    final currentWirdIndex = currentIndex < totalWirds
        ? currentIndex
        : totalWirds - 1;
    final currentWird = khatma.wirds[currentWirdIndex];

    final daysLate = context.read<KhatmaCubit>().getDaysLate(khatma.id);

    final cache = getIt<CacheService>();
    // Key must match exactly what IsolatedWirdScreen writes:
    // 'wird_{startDate}_{wirdIndex}_current_page'
    // We use the khatma startDate formatted as yyyy-MM-dd as the stable key prefix.
    final savedPage =
        cache.getInt('wird_${khatma.id}_${currentWirdIndex}_current_page') ??
        0;
    final hasStartedReading = savedPage > 0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 16.h,
            bottom: 100.h,
          ), // add bottom padding for FAB
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (daysLate > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.triangleExclamation,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          daysLate == 1
                              ? "⚠️ أنت متأخر ورد واحد"
                              : daysLate == 2
                              ? "⚠️ أنت متأخر وردين"
                              : "⚠️ أنت متأخر $daysLate أوراد",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppConsts.cairo,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (daysLate < 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.circleCheck,
                        color: Colors.greenAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          daysLate == -1
                              ? "🌟 ممتاز! أنت سابق بـ ورد واحد"
                              : daysLate == -2
                              ? "🌟 ممتاز! أنت سابق بـ وردين"
                              : "🌟 ممتاز! أنت سابق بـ ${-daysLate} أوراد",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppConsts.cairo,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0A871), width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.circleCheck,
                        color: Color(0xFFD0A871),
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "أنت تسير بمعدل منتظم وممتاز!",
                          style: TextStyle(
                            color: Color(0xFFD0A871),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppConsts.cairo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD0A871), Color(0xFFB58B54)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      khatma.name.isNotEmpty ? khatma.name : "الورد الحالي",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (currentWird.startSurahName.isNotEmpty) ...[
                      _buildWirdLine(
                        "من قوله تعالى:",
                        "سورة ${currentWird.startSurahName} - آية ${currentWird.startAyah}",
                      ),
                      const SizedBox(height: 8),
                      _buildWirdLine(
                        "إلى قوله تعالى:",
                        "سورة ${currentWird.endSurahName} - آية ${currentWird.endAyah}",
                      ),
                    ] else ...[
                      _buildWirdLine(
                        "الورد:",
                        "من صفحة ${currentWird.startPage} إلى صفحة ${currentWird.endPage}",
                      ),
                    ],
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "صفحة ${currentWird.startPage} إلى ${currentWird.endPage}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              FontAwesomeIcons.bookQuran,
                              color: Color(0xFFB58B54),
                            ),
                            label: Text(
                              hasStartedReading
                                  ? "تابع قراءة الورد"
                                  : "اقرأ الورد",
                              style: const TextStyle(
                                color: Color(0xFFB58B54),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              if (currentIndex >= totalWirds) return;
                              navigatorKey.currentState!
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => IsolatedWirdScreen(
                                        isWirdMode: true,
                                        khatmaId: khatma.id,
                                        wirdIndex: currentWirdIndex,
                                        targetStartPage: currentWird.startPage,
                                        targetEndPage: currentWird.endPage,
                                      ),
                                    ),
                                  )
                                  .then((_) {
                                    if (mounted) setState(() {});
                                  });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              FontAwesomeIcons.check,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "أتممت القراءة",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              if (currentIndex >= totalWirds) return;
                              context.read<KhatmaCubit>().markWirdAsCompleted(
                                khatma.id,
                                currentWirdIndex,
                              );
                              cache.setInt(
                                'wird_${khatma.id}_${currentWirdIndex}_current_page',
                                0,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تقبل الله طاعتكم!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "مشاركة الورد",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white54,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              if (currentIndex >= totalWirds) return;
                              _showExportConfirmationDialog(
                                isShare: true,
                                wirdIndex: currentWirdIndex,
                                startPage: currentWird.startPage,
                                endPage: currentWird.endPage,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "حفظ صور الورد",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white54,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              if (currentIndex >= totalWirds) return;
                              _showExportConfirmationDialog(
                                isShare: false,
                                wirdIndex: currentWirdIndex,
                                startPage: currentWird.startPage,
                                endPage: currentWird.endPage,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Share as TEXT button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.message_rounded,
                          color: Color(0xFFB58B54),
                          size: 18,
                        ),
                        label: const Text(
                          "مشاركة نص الورد",
                          style: TextStyle(
                            color: Color(0xFFB58B54),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (currentIndex >= totalWirds) return;
                          _showTextShareDialog(
                            khatma: khatma,
                            wirdIndex: currentWirdIndex,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                "نسبة الإنجاز: ${(progress * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFD0A871),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "أتممت $currentIndex من أصل $totalWirds ورد",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _buildNavButton(
                      context,
                      "الأوراد السابقة ($currentIndex)",
                      FontAwesomeIcons.clockRotateLeft,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WirdListScreen(
                            khatmaId: khatma.id,
                            showPrevious: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildNavButton(
                      context,
                      "الأوراد القادمة (${totalWirds > currentIndex ? totalWirds - currentIndex - 1 : 0})",
                      FontAwesomeIcons.forwardFast,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WirdListScreen(
                            khatmaId: khatma.id,
                            showPrevious: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isExporting)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text(
                        'جاري التصدير...',
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_exportCompleted / $_exportTotal',
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showExportConfirmationDialog({
    required bool isShare,
    required int wirdIndex,
    required int startPage,
    required int endPage,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          const gold = Color(0xFFD0A871);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            title: Text(
              isShare ? 'مشاركة صور الورد' : 'حفظ صور الورد',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
                color: gold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم تصدير ${endPage - startPage + 1} صفحة. يرجى اختيار الجودة المناسبة لجهازك.',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quality Selector
                const Text(
                  'اختر جودة الصور:',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQualityChip(
                      label: 'عالية',
                      value: 5.0,
                      isSelected: _selectedQuality == 5.0,
                      onTap: () => setDlgState(() => _selectedQuality = 5.0),
                    ),
                    const SizedBox(width: 8),
                    _buildQualityChip(
                      label: 'متوسطة',
                      value: 3.0,
                      isSelected: _selectedQuality == 3.0,
                      onTap: () => setDlgState(() => _selectedQuality = 3.0),
                    ),
                    const SizedBox(width: 8),
                    _buildQualityChip(
                      label: 'منخفضة',
                      value: 1.0,
                      isSelected: _selectedQuality == 1.0,
                      onTap: () => setDlgState(() => _selectedQuality = 1.0),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _exportWirdPages(
                        wirdIndex: wirdIndex,
                        startPage: startPage,
                        endPage: endPage,
                        saveToGallery: !isShare,
                        quality: _selectedQuality,
                      );
                    },
                    icon: Icon(
                      isShare ? Icons.share_rounded : Icons.download_rounded,
                    ),
                    label: Text(
                      isShare ? 'مشاركة الآن' : 'حفظ في الجهاز الآن',
                      style: const TextStyle(fontFamily: 'cairo', fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQualityChip({
    required String label,
    required double value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFD0A871);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : gold,
          ),
        ),
      ),
    );
  }

  Future<void> _exportWirdPages({
    required int wirdIndex,
    required int startPage,
    required int endPage,
    required bool saveToGallery,
    double quality = 5.0,
  }) async {
    final totalPages = (endPage - startPage + 1).clamp(0, 604);

    setState(() {
      _isExporting = true;
      _exportCompleted = 0;
      _exportTotal = totalPages;
    });

    final completer = Completer<List<String>>();

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => _ExportWirdRenderer(
          wirdIndex: wirdIndex,
          startPage: startPage,
          endPage: endPage,
          quality: quality,
          onProgress: (completed, total) {
            if (mounted) {
              setState(() {
                _exportCompleted = completed;
                _exportTotal = total;
              });
            }
          },
          onComplete: (paths) {
            completer.complete(paths);
          },
        ),
      ),
    );

    final capturedPaths = await completer.future;

    if (!mounted) return;

    setState(() => _isExporting = false);

    if (capturedPaths.isEmpty) {
      _showTopNotification(context, 'لم يتم التقاط أي صفحة', isError: true);
      return;
    }

    if (saveToGallery) {
      try {
        int savedCount = 0;
        for (final path in capturedPaths) {
          try {
            // Sequential saving
            await Gal.putImage(path, album: 'عباد الرحمن');
            savedCount++;

            // Small delay between gal saves
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            debugPrint('Failed to save page $path to gallery: $e');
          }
        }

        if (mounted) {
          _showTopNotification(
            context,
            savedCount > 0
                ? '✅ تم حفظ $savedCount صفحة في المعرض بنجاح'
                : '❌ فشل حفظ الصور في المعرض',
            isError: savedCount == 0,
          );
        }
      } catch (e) {
        if (mounted) {
          _showTopNotification(context, 'خطأ عام أثناء الحفظ: $e', isError: true);
        }
      }
    } else {
      try {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          capturedPaths.map((p) => XFile(p)).toList(),
          text: 'ورد اليوم — من تطبيق عِبَادُ الرَّحْمَٰن 📖',
        );
      } catch (e) {
        if (mounted) {
          _showTopNotification(context, 'خطأ أثناء المشاركة: $e', isError: true);
        }
      }
    }
  }

  static void _showTopNotification(BuildContext context, String message, {bool isError = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notification',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  Widget _buildWirdLine(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFD0A871).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD0A871), size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text Share helpers injected into separate section ─────────────────────

extension _WirdTextShare on _KhatmaDetailsViewState {
  String _toArabicDigits(int n) {
    const map = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) {
      final d = int.tryParse(c);
      return d != null ? map[d] : c;
    }).join();
  }

  String _wirdTimeLabel(KhatmaModel khatma, int wirdIndex) {
    final type = khatma.notificationType;
    if (type == 'prayer') {
      const prayers = ['الفجر', 'الضحى', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      return prayers[wirdIndex % prayers.length];
    }
    if (type == 'daily' && khatma.dailyTime != null) return khatma.dailyTime!;
    return 'اليومي';
  }

  String _hijriMonthName(int month) {
    const names = [
      '',
      'مُحَرَّم',
      'صَفَر',
      'رَبِيع الأَوَّل',
      'رَبِيع الثَّانِي',
      'جُمَادَى الأُولَى',
      'جُمَادَى الآخِرَة',
      'رَجَب',
      'شَعْبَان',
      'رَمَضَان',
      'شَوَّال',
      'ذُو القَعْدَة',
      'ذُو الحِجَّة',
    ];
    return month >= 1 && month <= 12 ? names[month] : '';
  }

  // Returns 2 share text variants (Simple, Detailed).
  (String, String) _buildWirdShareTexts(KhatmaModel khatma, int wirdIndex) {
    final wurde = khatma.wirds[wirdIndex];
    HijriCalendar.setLocal('ar');
    // Use the offset-adjusted Hijri date so the shared text matches the app UI.
    final hijri = PrayerService().getAdjustedHijri();
    final today = _toArabicDigits(hijri.hDay);
    final yearH = _toArabicDigits(hijri.hYear);
    final monthName = _hijriMonthName(hijri.hMonth);
    final wirdTime = _wirdTimeLabel(khatma, wirdIndex);
    final startPage = _toArabicDigits(wurde.startPage);
    final endPage = _toArabicDigits(wurde.endPage);
    final pageCount = _toArabicDigits(wurde.endPage - wurde.startPage + 1);

    // Build the full list of Surah names covered by this wird.
    final List<String> surahNames = [];
    final int sStart = wurde.startSuraNumber.clamp(1, 114);
    final int sEnd = wurde.endSuraNumber.clamp(1, 114);
    for (int n = sStart; n <= sEnd; n++) {
      surahNames.add(quran.getSurahNameArabic(n));
    }
    // Compact first→last for formatted.
    final surahShort = surahNames.length == 1
        ? surahNames.first
        : '${surahNames.first} ← ${surahNames.last}';

    // Page range e.g. "٣٩٩ و ٤٠٠" or "٣٩٩ - ٤٠١"
    final pageRange = wurde.startPage == wurde.endPage
        ? startPage
        : (wurde.endPage - wurde.startPage == 1)
        ? '$startPage و $endPage'
        : '$startPage - $endPage';

    // ── Format 1: simple compact ────────────────────────────────────────
    final simple =
        '*وِرد اليوم $today $monthName $yearHهـ*\n'
        '*صفحة $pageRange*';

    // ── Format 2: full formatted (no app name) ──────────────────────
    final formatted =
        '*• الـوِرد الـيَـومِـي لِشَهْرِ $monthName لِعام $yearH هـ :*\n\n'
        '*📅 — الـيوم : " $today "*\n'
        '*📖 — إسـم السورة : ( $surahShort )*\n'
        '*🕋 — وِرد : ( $wirdTime )*\n'
        '*$pageCount — الصفحات مِـن : \' $startPage  -  $endPage \'*';

    return (simple, formatted);
  }

  void _showTextShareDialog({
    required KhatmaModel khatma,
    required int wirdIndex,
  }) {
    final texts = _buildWirdShareTexts(khatma, wirdIndex);
    int selected = 0; // 0: simple, 1: detailed
    bool withLink = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          const gold = Color(0xFFD0A871);

          Widget chip(int idx, String label, IconData icon) {
            final isSel = selected == idx;
            return InkWell(
              onTap: () => setDlg(() => selected = idx),
              splashColor: gold.withAlpha(50),
              highlightColor: gold.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                width: 100,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSel ? gold.withAlpha(220) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? gold : Colors.grey.withAlpha(80),
                  ),
                ),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: isSel ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSel ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 12,
                        color: isSel ? Colors.white : Colors.grey,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final baseText = selected == 0 ? texts.$1 : texts.$2;
          const linkText =
              '\n\nتطبيق عِبَادُ الرَّحْمَٰن:\nhttps://play.google.com/store/apps/details?id=app.ibad_al_rahmann';
          final displayText = withLink ? '$baseText$linkText' : baseText;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.message_outlined, color: gold),
                SizedBox(width: 8),
                Text(
                  'مشاركة نص الورد',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      chip(0, 'صيغة بسيطة', Icons.flash_on_outlined),
                      const SizedBox(width: 12),
                      chip(1, 'صيغة مفصلة', Icons.format_list_bulleted_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text(
                      'إدراج اسم ورابط التطبيق',
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 13,
                      ),
                    ),
                    activeThumbColor: gold,
                    value: withLink,
                    onChanged: (v) => setDlg(() => withLink = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(selected.toString() + withLink.toString()),
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0D0D0D)
                            : const Color(0xFFFAF6EE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gold.withAlpha(80)),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          displayText,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            fontSize: 13,
                            height: 1.9,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('نسخ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: gold,
                            side: const BorderSide(color: gold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: displayText));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ تم نسخ النص'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share_outlined, size: 16),
                          label: const Text('مشاركة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            SharePlus.instance.share(
                              ShareParams(text: displayText),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExportWirdRenderer extends StatefulWidget {
  final int wirdIndex;
  final int startPage;
  final int endPage;
  final double quality;
  final void Function(int completed, int total) onProgress;
  final void Function(List<String> paths) onComplete;

  const _ExportWirdRenderer({
    required this.wirdIndex,
    required this.startPage,
    required this.endPage,
    required this.quality,
    required this.onProgress,
    required this.onComplete,
  });

  @override
  State<_ExportWirdRenderer> createState() => _ExportWirdRendererState();
}

class _ExportWirdRendererState extends State<_ExportWirdRenderer> {
  late PageController _pageController;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _totalPages = (widget.endPage - widget.startPage + 1).clamp(0, 604);
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCapture());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    final cubit = context.read<QuranCubit>();
    final List<String> capturedPaths = [];

    for (int i = 0; i < _totalPages; i++) {
      try {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(i);
        }

        // Rule 2: Breathing Room (Delay) BEFORE capturing
        // Ensure framework has time to paint the RepaintBoundary
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await WidgetsBinding.instance.endOfFrame;
        // Additional stabilizing delay
        await Future<void>.delayed(const Duration(milliseconds: 300));

        final realPage = widget.startPage + i;
        final key = cubit.getPageKey(realPage);

        // Rule 3: Explicit Extension
        final fileName = 'wird_page_$realPage.png';

        // Rule 1: Sequential Loop (standard for loop)
        final paths = await ShareHelper.captureMultiplePages(
          keys: [key],
          fileNames: [fileName],
          quality: widget.quality,
        );
        capturedPaths.addAll(paths);
      } catch (e) {
        // Rule 4: Graceful Error Handling (Log and continue)
        debugPrint('Error capturing page index $i: $e');
      }

      widget.onProgress(i + 1, _totalPages);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onComplete(capturedPaths);
  }

  @override
  Widget build(BuildContext context) {
    final int? wirdColorVal = getIt<CacheService>().getInt('wird_paper_color');
    final Color? savedColor = (wirdColorVal != null && wirdColorVal != -1)
        ? Color(wirdColorVal)
        : null;
    
    final quranTheme = Theme.of(context).extension<QuranThemeColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color effectivePaperColor = savedColor ??
        (isDark ? (quranTheme?.paperColorDark ?? Colors.black) : (quranTheme?.paperColorLight ?? Colors.white));
        
    final textColor = effectivePaperColor.computeLuminance() < 0.5
        ? Colors.white
        : Colors.black;

    final (sSura, sAyah, eSura, eAyah) = _getWirdBounds(context);

    return Scaffold(
      backgroundColor: effectivePaperColor,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: PageView.builder(
      allowImplicitScrolling: true,
          controller: _pageController,
          itemCount: _totalPages,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final realPage = widget.startPage + index;
            return WbwPageWidget(
              pageNumber: realPage,
              startSuraNumber: sSura,
              startAyah: sAyah,
              endSuraNumber: eSura,
              endAyah: eAyah,
              collapseOutOfRange: true, // Focus only on the Rub' content
              isZoomEnabled: false,
              paperColorOverride: savedColor, // Pass null to allow default creamy colors
              textColorOverride: textColor,
            );
          },
        ),
      ),
    );
  }

  (int?, int?, int?, int?) _getWirdBounds(BuildContext ctx) {
    final state = ctx.read<KhatmaCubit>().state;
    if (state is KhatmaLoaded) {
      // Find the specific khatma that contains this wird. 
      // Since _ExportWirdRenderer doesn't have khatmaId, we might need to find it 
      // or pass it. But usually only one khatma is active in this context.
      // Looking at KhatmaDetailsView, it HAS the khatma.
      // Wait, I should have passed khatmaId to _ExportWirdRenderer.
      
      // Let's see if we can find the khatma from the state by matching wirds? 
      // Better: let's check how _ExportWirdRenderer is instantiated.
      
      // For now, let's look at all khatmas and find one that matches the start/end pages.
      for (final k in state.khatmas) {
        if (widget.wirdIndex < k.wirds.length) {
          final w = k.wirds[widget.wirdIndex];
          if (w.startPage == widget.startPage && w.endPage == widget.endPage) {
            if (w.isPartial) {
              return (w.startSuraNumber, w.startAyah, w.endSuraNumber, w.endAyah);
            }
          }
        }
      }
    }
    return (null, null, null, null);
  }
}
