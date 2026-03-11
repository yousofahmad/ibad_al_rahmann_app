import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gal/gal.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:ibad_al_rahmann/core/helpers/share_helper.dart';
import 'package:share_plus/share_plus.dart';
import '../bloc/khatma_cubit.dart';
import '../../quran/bloc/quran/quran_cubit.dart';
import '../../quran/ui/widgets/wbw_page_widget.dart';
import '../../../../main.dart';
import 'isolated_wird_screen.dart';
import 'wird_list_screen.dart';
import '../data/khatma_model.dart';

class KhatmaDetailsView extends StatefulWidget {
  final KhatmaModel khatma;

  const KhatmaDetailsView({super.key, required this.khatma});

  @override
  State<KhatmaDetailsView> createState() => _KhatmaDetailsViewState();
}

class _KhatmaDetailsViewState extends State<KhatmaDetailsView> {
  bool _isExporting = false;
  int _exportCompleted = 0;
  int _exportTotal = 0;

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
    final savedPage =
        cache.getInt('wird_${khatma.id}_${currentWirdIndex}_current_page') ?? 0;
    final hasStartedReading = savedPage > 0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 100,
          ), // add bottom padding for FAB
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (daysLate > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                    _buildWirdLine(
                      "من قوله تعالى:",
                      "سورة ${currentWird.startSurahName} - آية ${currentWird.startAyah}",
                    ),
                    const SizedBox(height: 8),
                    _buildWirdLine(
                      "إلى قوله تعالى:",
                      "سورة ${currentWird.endSurahName} - آية ${currentWird.endAyah}",
                    ),
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isShare ? 'مشاركة صور الورد' : 'حفظ صور الورد',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'سيتم فتح صفحات الورد وتصديرها كصور بجودة عالية. قد تستغرق العملية بعض الوقت.',
                      style: TextStyle(fontFamily: 'cairo', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isShare ? const Color(0xFFD0A871) : Colors.green.shade700,
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
                  );
                },
                icon: Icon(isShare ? Icons.share_rounded : Icons.download_rounded),
                label: Text(
                  isShare ? 'مشاركة الآن' : 'حفظ في الجهاز الآن',
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontFamily: 'cairo', color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportWirdPages({
    required int wirdIndex,
    required int startPage,
    required int endPage,
    required bool saveToGallery,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم التقاط أي صفحة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (saveToGallery) {
      try {
        int savedCount = 0;
        for (final path in capturedPaths) {
          try {
            // Rule 3: Explicit Extension Check
            if (path.isEmpty || !path.toLowerCase().endsWith('.png')) {
              debugPrint('Skipping invalid file path: $path');
              continue;
            }

            // Rule 1: Sequential saving (already in for loop)
            await Gal.putImage(path, album: 'عباد الرحمن');
            savedCount++;

            // Optional: small delay between gal saves to prevent IO overload
            await Future.delayed(const Duration(milliseconds: 50));
          } catch (e) {
            // Rule 4: Graceful Error Handling inside the loop
            debugPrint('Failed to save individual page $path to gallery: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                savedCount > 0
                    ? '✅ تم حفظ $savedCount صفحة في المعرض بنجاح'
                    : '❌ فشل حفظ الصور في المعرض',
              ),
              backgroundColor: savedCount > 0 ? Colors.green : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ عام أثناء الحفظ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: capturedPaths.map((p) => XFile(p)).toList(),
            text: 'ورد اليوم — من تطبيق عِبَادُ الرَّحْمَٰن 📖',
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ أثناء المشاركة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

class _ExportWirdRenderer extends StatefulWidget {
  final int wirdIndex;
  final int startPage;
  final int endPage;
  final void Function(int completed, int total) onProgress;
  final void Function(List<String> paths) onComplete;

  const _ExportWirdRenderer({
    required this.wirdIndex,
    required this.startPage,
    required this.endPage,
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
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await WidgetsBinding.instance.endOfFrame;
        // Additional stabilizing delay
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final realPage = widget.startPage + i;
        final key = cubit.getPageKey(realPage);

        // Rule 3: Explicit Extension
        final fileName = 'wird_page_$realPage.png';

        // Rule 1: Sequential Loop (standard for loop)
        final paths = await ShareHelper.captureMultiplePages(
          keys: [key],
          fileNames: [fileName],
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _totalPages,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final realPage = widget.startPage + index;
            return WbwPageWidget(
              pageNumber: realPage,
              isZoomEnabled: false,
              paperColorOverride: Colors.white,
              textColorOverride: Colors.black,
            );
          },
        ),
      ),
    );
  }
}
