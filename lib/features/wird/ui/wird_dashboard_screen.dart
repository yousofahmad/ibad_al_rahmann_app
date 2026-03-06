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
import 'new_khatma_screen.dart';

class WirdDashboardScreen extends StatefulWidget {
  const WirdDashboardScreen({super.key});

  @override
  State<WirdDashboardScreen> createState() => _WirdDashboardScreenState();
}

class _WirdDashboardScreenState extends State<WirdDashboardScreen> {
  // Export progress tracking
  bool _isExporting = false;
  int _exportCompleted = 0;
  int _exportTotal = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "الورد اليومي",
          style: TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          BlocBuilder<KhatmaCubit, KhatmaState>(
            builder: (context, state) {
              if (state is KhatmaLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD0A871)),
                );
              } else if (state is KhatmaEmpty) {
                return _buildEmptyState(context);
              } else if (state is KhatmaLoaded) {
                return _buildDashboard(context, state, isDark);
              } else if (state is KhatmaError) {
                return Center(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Blocking progress overlay during export
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.bookOpenReader,
            size: 80,
            color: Color(0xFFD0A871),
          ),
          const SizedBox(height: 20),
          Text(
            "لا توجد ختمة نشطة حالياً",
            style: TextStyle(
              fontSize: 22,
              fontFamily: AppConsts.expoArabic,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A871),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewKhatmaScreen()),
              );
            },
            child: const Text(
              "بدء ختمة جديدة",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    KhatmaLoaded state,
    bool isDark,
  ) {
    final khatma = state.khatma;
    final currentIndex = khatma.currentWirdIndex;
    final totalWirds = khatma.wirds.length;
    final progress = currentIndex / totalWirds;

    final currentWird = khatma.wirds[currentIndex];

    // Calculate days/wirds late
    final daysLate = context.read<KhatmaCubit>().getDaysLate();

    // Check if user has started reading this wird (has a saved page > 0)
    final cache = getIt<CacheService>();
    final savedPage = cache.getInt('wird_${currentIndex}_current_page') ?? 0;
    final hasStartedReading = savedPage > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Late Warning Banner — show "متأخر عدد X من الأوراد"
          if (daysLate > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // Current Wird Card
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
                const Text(
                  "الورد الحالي",
                  style: TextStyle(
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

                // Row 1: Read / Continue + Mark Complete
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
                          hasStartedReading ? "تابع قراءة الورد" : "اقرأ الورد",
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
                          navigatorKey.currentState!
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => IsolatedWirdScreen(
                                    wirdIndex: currentIndex,
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
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          context.read<KhatmaCubit>().markWirdAsCompleted(
                            currentIndex,
                          );
                          // Reset saved page for this wird
                          cache.setInt('wird_${currentIndex}_current_page', 0);
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

                // Row 2: Share / Save buttons
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
                        onPressed: () => _showExportDialog(
                          currentIndex,
                          currentWird.startPage,
                          currentWird.endPage,
                        ),
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
                        onPressed: () => _exportWirdPages(
                          wirdIndex: currentIndex,
                          startPage: currentWird.startPage,
                          endPage: currentWird.endPage,
                          saveToGallery: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Progress indicator
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
            "أتممت $currentIndex من أصل $totalWirds وِرد",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const SizedBox(height: 30),

          // Navigation buttons
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
                      builder: (_) => const WirdListScreen(showPrevious: true),
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
                      builder: (_) => const WirdListScreen(showPrevious: false),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Settings
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: ListTile(
              leading: const Icon(
                FontAwesomeIcons.arrowsRotate,
                color: Colors.redAccent,
              ),
              title: const Text(
                "بدء ختمة جديدة",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.redAccent,
              ),
              onTap: () {
                _showDeleteWarningDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Export Dialog (moved from IsolatedWirdScreen) ─────────────
  void _showExportDialog(int wirdIndex, int startPage, int endPage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تصدير صور الورد',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold),
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
                  backgroundColor: const Color(0xFFD0A871),
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
                    saveToGallery: false,
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  'مشاركة صور الورد',
                  style: TextStyle(fontFamily: 'cairo', fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
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
                    saveToGallery: true,
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text(
                  'حفظ صور الورد في الجهاز',
                  style: TextStyle(fontFamily: 'cairo', fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens an IsolatedWirdScreen offscreen, navigates through pages,
  /// captures each as an image, then shares or saves.
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

    // Navigate to a temporary renderer screen for page capture
    final completer = Completer<List<String>>();

    // We need to push the Wird screen to render pages, capture, then pop
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
        for (final path in capturedPaths) {
          await Gal.putImage(path, album: 'عباد الرحمن');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ تم حفظ ${capturedPaths.length} صفحة في المعرض بنجاح',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ أثناء الحفظ: $e'),
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

  void _showDeleteWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "تنبيه",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontFamily: AppConsts.cairo,
          ),
        ),
        content: const Text(
          "هل أنت متأكد؟ سيتم إلغاء الختمة الحالية والبدء من جديد.",
          style: TextStyle(fontFamily: AppConsts.cairo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<KhatmaCubit>().deleteKhatma();
            },
            child: const Text(
              "نعم، متأكد",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Temporary screen that renders Wird pages for export capture
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
      if (_pageController.hasClients) {
        _pageController.jumpToPage(i);
      }
      // Wait longer to ensure font + layout is fully rendered
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final realPage = widget.startPage + i;
      final key = cubit.getPageKey(realPage);
      final paths = await ShareHelper.captureMultiplePages(
        keys: [key],
        fileNames: ['wird_page_$realPage'],
      );
      capturedPaths.addAll(paths);

      widget.onProgress(i + 1, _totalPages);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onComplete(capturedPaths);
  }

  @override
  Widget build(BuildContext context) {
    // Use full screen size to match the reading mode exactly
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
