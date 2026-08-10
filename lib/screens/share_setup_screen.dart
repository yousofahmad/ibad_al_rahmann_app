import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';

import '../features/quran/bloc/quran/quran_cubit.dart';
import '../features/quran/bloc/theme/quran_theme_cubit.dart';
import '../features/quran/data/quran_word.dart';
import '../features/quran/providers/share_provider.dart';
import '../services/image_generation_service.dart';
import '../core/helpers/fonts_helper.dart';
import '../core/theme/theme_manager/theme_cubit.dart';
import '../core/helpers/share_helper.dart';

import '../features/quran/ui/widgets/components/db_mushaf_text.dart';
import '../features/quran/ui/widgets/components/ayah_marker_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry – kept for backward compat; now wraps the bottom sheet.
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the share menu as a modal bottom sheet (like the bookmark dialog).
class ShareSetupScreen extends StatelessWidget {
  final int surahNumber;
  final int initialVerse;

  const ShareSetupScreen({
    super.key,
    required this.surahNumber,
    required this.initialVerse,
  });

  @override
  Widget build(BuildContext context) {
    // This widget is never pushed as a route any more.
    // Call [ShareSetupScreen.show] instead.
    return const SizedBox.shrink();
  }

  /// Shows the share bottom sheet. Reads [QuranCubit] from [context] if present.
  static void show(
    BuildContext context, {
    required int surahNumber,
    required int initialVerse,
  }) {
    QuranCubit? quranCubit;
    ThemeCubit? themeCubit;
    try {
      quranCubit = context.read<QuranCubit>();
    } catch (_) {}
    try {
      // Try to get Quran-specific theme first, fallback to global theme
      themeCubit = context.read<QuranThemeCubit>();
    } catch (_) {
      try {
        themeCubit = context.read<ThemeCubit>();
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget body = ChangeNotifierProvider(
          create: (_) => ShareProvider(
            surahNumber: surahNumber,
            initialVerse: initialVerse,
          ),
          child: const _ShareSheetBody(),
        );
        if (quranCubit != null) {
          body = BlocProvider.value(value: quranCubit, child: body);
        }
        if (themeCubit != null) {
          // Provide as ThemeCubit so BlocBuilder<ThemeCubit> finds it
          body = BlocProvider<ThemeCubit>.value(value: themeCubit, child: body);
        }
        return body;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet body
// ─────────────────────────────────────────────────────────────────────────────

class _ShareSheetBody extends StatefulWidget {
  const _ShareSheetBody();

  @override
  State<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends State<_ShareSheetBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey _previewBoundaryKey = GlobalKey();
  bool _isCapturing = false;

  // ── Paper-colour helpers ───────────────────────────────────────────────────

  Color? _customPaperColor;

  Color get _paperColor {
    if (_customPaperColor != null) return _customPaperColor!;
    try {
      return context.read<QuranCubit>().state.quranPaperColor ??
          Theme.of(context).scaffoldBackgroundColor;
    } catch (_) {
      return Theme.of(context).scaffoldBackgroundColor;
    }
  }

  void _cyclePaperColor() {
    setState(() {
      if (_customPaperColor == null || _customPaperColor == Theme.of(context).scaffoldBackgroundColor) {
        _customPaperColor = Colors.white;
      } else if (_customPaperColor == Colors.white) {
        _customPaperColor = const Color(0xFFF4ECD8);
      } else if (_customPaperColor == const Color(0xFFF4ECD8)) {
        _customPaperColor = const Color(0xFF151515);
      } else if (_customPaperColor == const Color(0xFF151515)) {
        _customPaperColor = Colors.black;
      } else {
        _customPaperColor = Theme.of(context).scaffoldBackgroundColor;
      }
    });
  }

  bool get _isLightBg => _paperColor.computeLuminance() > 0.5;
  Color get _sheetBg => _isLightBg ? Colors.white : Colors.black;
  Color get _onSurface => _isLightBg ? Colors.black87 : Colors.white;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final initialMode = context.read<ShareProvider>().shareMode;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialMode == ShareMode.text ? 1 : 0);
    _tabController.addListener(() {
      final provider = context.read<ShareProvider>();
      final mode = _tabController.index == 0 ? ShareMode.image : ShareMode.text;
      if (provider.shareMode != mode) provider.setShareMode(mode);
    });

    // Initial load of words
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShareProvider>().loadWords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _showQualityPicker(Function(double) onSelected) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);
    double quality = 5.0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: const Text(
            'اختر جودة الصورة',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold, color: gold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQualityOption('عالية', 5.0, quality == 5.0, (v) => setDlgState(() => quality = v)),
                  const SizedBox(width: 8),
                  _buildQualityOption('متوسطة', 3.0, quality == 3.0, (v) => setDlgState(() => quality = v)),
                  const SizedBox(width: 8),
                  _buildQualityOption('منخفضة', 1.0, quality == 1.0, (v) => setDlgState(() => quality = v)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    onSelected(quality);
                    Navigator.pop(ctx);
                  },
                  child: const Text('تأكيد', style: TextStyle(fontFamily: 'cairo', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityOption(String label, double value, bool isSelected, Function(double) onTap) {
    const gold = Color(0xFFD0A871);
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : gold,
          ),
        ),
      ),
    );
  }

  /// Capture BEFORE setState to avoid rebuild interfering with RenderObject.
  Future<void> _shareImage() async {
    final provider = context.read<ShareProvider>();
    if (_isCapturing || provider.isLoading) return;

    await _showQualityPicker((quality) async {
      setState(() => _isCapturing = true);

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        final bytes = await ImageGenerationService.captureAsPng(
          _previewBoundaryKey,
          pixelRatio: quality,
        );

        final path = await ImageGenerationService.saveTempAndGetPath(bytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path, mimeType: 'image/png')]),
        );
      } catch (e) {
        if (mounted) {
          ShareHelper.showTopNotification(context, 'حدث خطأ أثناء توليد الصورة: ${e.toString()}', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    });
  }

  Future<void> _saveImage() async {
    final provider = context.read<ShareProvider>();
    if (_isCapturing || provider.isLoading) return;

    try {
      final access = await Gal.requestAccess(toAlbum: true);
      if (!access) {
        if (mounted) {
          ShareHelper.showTopNotification(context, 'تم رفض صلاحية الوصول للمعرض. يرجى تفعيلها من الإعدادات.', isError: true);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ShareHelper.showTopNotification(context, 'فشل طلب الصلاحيات: ${e.toString()}', isError: true);
      }
      return;
    }

    await _showQualityPicker((quality) async {
      setState(() => _isCapturing = true);

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        final bytes = await ImageGenerationService.captureAsPng(
          _previewBoundaryKey,
          pixelRatio: quality,
        );

        await ImageGenerationService.saveToGallery(bytes);
        if (mounted) {
          ShareHelper.showTopNotification(context, 'تم حفظ الصورة في المعرض ✓');
        }
      } catch (e) {
        if (mounted) {
          ShareHelper.showTopNotification(context, 'فشل الحفظ: ${e.toString()}', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    });
  }

  Future<void> _shareText(ShareProvider provider) async {
    final text = provider.buildShareText(withLogo: provider.showLogo);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final provider = context.watch<ShareProvider>();
        final primary = Theme.of(context).primaryColor;
        final surahArabic = quran.getSurahNameArabic(provider.surahNumber);
        final isLightBg = _isLightBg;
        final sheetBg = _sheetBg;
        final onSurface = _onSurface;

        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
          ),
          child: Column(
            children: [
              // ── Drag handle ───────────────────────────────────────────────────
              SizedBox(height: 8.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 4.h),

              // ── Header ────────────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                decoration: BoxDecoration(color: primary),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20.w,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'مشاركة من سورة $surahArabic',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    // Format toggle
                    _HeaderIconButton(
                      onTap: provider.toggleMushafFormat,
                      isActive: provider.isMushafFormat,
                      icon: provider.isMushafFormat
                          ? Icons.segment_rounded
                          : Icons.notes_rounded,
                      tooltip: provider.isMushafFormat ? 'تنسيق مفرود' : 'تنسيق المصحف',
                    ),
                    // Logo toggle
                    _HeaderIconButton(
                      onTap: provider.toggleLogo,
                      isActive: provider.showLogo,
                      tooltip: provider.showLogo ? 'إخفاء الشعار' : 'إظهار الشعار',
                      child: ClipOval(
                        child: Opacity(
                          opacity: provider.showLogo ? 1.0 : 0.3,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 24.w,
                            height: 24.h,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.mosque_rounded,
                              color: Colors.white,
                              size: 18.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── TabBar ────────────────────────────────────────────────────────
              SizedBox(
                height: 45.h,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: primary,
                  labelColor: primary,
                  unselectedLabelColor: onSurface.withValues(alpha: 0.45),
                  labelStyle: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 16.w),
                          SizedBox(width: 6.w),
                          const Text('صورة'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.text_fields, size: 16.w),
                          SizedBox(width: 6.w),
                          const Text('نص'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Verse range dropdowns ─────────────────────────────────────────
              _VerseRangeDropdowns(
                provider: provider,
                isLightBg: isLightBg,
                onSurface: onSurface,
              ),

              // ── Preview area ──────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ImagePreviewTab(
                      boundaryKey: _previewBoundaryKey,
                      provider: provider,
                      isLightBg: isLightBg,
                      paperColor: _paperColor,
                    ),
                    _TextPreviewTab(
                      provider: provider,
                      onSurface: onSurface,
                      isLightBg: isLightBg,
                    ),
                  ],
                ),
              ),

              // ── Toolbar ───────────────────────────────────────────────────────
              _Toolbar(
                primary: primary,
                isCapturing: _isCapturing || provider.isLoading,
                sheetBg: sheetBg,
                onShare: provider.shareMode == ShareMode.image
                    ? _shareImage
                    : () => _shareText(provider),
                onSave: provider.shareMode == ShareMode.image ? _saveImage : null,
                onToggleColor: provider.shareMode == ShareMode.image ? _cyclePaperColor : null,
                onCopy: provider.shareMode == ShareMode.text
                    ? () {
                        final text = provider.buildShareText(withLogo: provider.showLogo);
                        Clipboard.setData(ClipboardData(text: text));
                        ShareHelper.showTopNotification(context, 'تم نسخ النص ✓');
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;
  final IconData? icon;
  final Widget? child;
  final String tooltip;

  const _HeaderIconButton({
    required this.onTap,
    required this.isActive,
    this.icon,
    this.child,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 34.w,
          height: 34.h,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.0.w,
            ),
          ),
          child: Center(
            child: child ??
                Icon(
                  icon,
                  color: Colors.white,
                  size: 18.w,
                ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Preview Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePreviewTab extends StatelessWidget {
  final GlobalKey? boundaryKey;
  final ShareProvider provider;
  final bool isLightBg;
  final Color paperColor;

  const _ImagePreviewTab({
    required this.boundaryKey,
    required this.provider,
    required this.isLightBg,
    required this.paperColor,
  });

  @override
  Widget build(BuildContext context) {
    // For high-quality, consistent capture, we use absolute logical pixels.
    // We wrap it in a FittedBox to display a scaled-down preview in the UI,
    // while the RepaintBoundary captures the true 1080px resolution.
    final Widget captureContent = RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: 1080.0, 
        // Allow height to be dynamic
        color: paperColor,
        child: _ShareableImageCard(provider: provider, isLightBg: isLightBg, paperColor: paperColor),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: captureContent,
        ),
      ),
    );
  }
}

class _ShareableImageCard extends StatelessWidget {
  final ShareProvider provider;
  final bool isLightBg;
  final Color paperColor;

  const _ShareableImageCard({required this.provider, required this.isLightBg, required this.paperColor});

  @override
  Widget build(BuildContext context) {
    final surahNum = provider.surahNumber;
    final surahArabic = quran.getSurahNameArabic(surahNum);
    final surahNameCode = 'surah${surahNum.toString().padLeft(3, '0')}';

    final bgColor = paperColor;
    final textColor = paperColor.computeLuminance() > 0.5 ? Colors.black87 : const Color(0xFFF0F0F0);
    final primary = Theme.of(context).primaryColor;

    return Container(
      width: 1080.0,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 6.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPremiumHeaderPattern(primary),
          const SizedBox(height: 40.0),
          _SurahNameFrame(
            surahArabic: surahArabic,
            surahNameCode: surahNameCode,
            textColor: textColor,
          ),
          const SizedBox(height: 30.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50.0),
            child: _VersesSection(provider: provider, textColor: textColor),
          ),
          const SizedBox(height: 60.0),
          if (provider.showLogo) ...[
            _ShareFooter(isLightBg: isLightBg),
            const SizedBox(height: 40.0),
          ],
          _buildPremiumFooterPattern(primary),
        ],
      ),
    );
  }

  Widget _buildPremiumHeaderPattern(Color color) {
    const gold = Color(0xFFD0A871);
    return Container(
      height: 24.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: 0.0), gold.withValues(alpha: 0.6), gold.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  Widget _buildPremiumFooterPattern(Color color) {
    const gold = Color(0xFFD0A871);
    return Container(
      height: 24.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: 0.0), gold.withValues(alpha: 0.6), gold.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

class _SurahNameFrame extends StatelessWidget {
  final String surahArabic;
  final String surahNameCode;
  final Color textColor;

  const _SurahNameFrame({
    required this.surahArabic,
    required this.surahNameCode,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    const goldenColor = Color(0xFFD0A871);
    const double frameH = 120.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: SizedBox(
        width: double.infinity,
        height: frameH,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/aya_frame.png',
                fit: BoxFit.fill,
                color: goldenColor,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80.0),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                surahNameCode,
                style: const TextStyle(
                  fontFamily: 'SurahNames',
                  fontSize: 70.0, 
                  color: goldenColor,
                  height: 1.0,
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

class _VersesSection extends StatelessWidget {
  final ShareProvider provider;
  final Color textColor;

  const _VersesSection({required this.provider, required this.textColor});

  bool _isMarker(QuranWord word) {
    final allWords = provider.allWords;
    if (allWords == null) return false;
    final currentAyah = word.ayahNumber ?? 0;
    if (currentAyah == 0) return false;

    final index = allWords.indexWhere((w) => identical(w, word));
    if (index == -1) return false;

    if (index == allWords.length - 1) return true;

    return allWords[index + 1].ayahNumber != currentAyah;
  }

  Widget _buildWordWidget(
    QuranWord word,
    bool isMarker,
    double fontSize,
    String fontFamily,
  ) {
    if (word.lineType == 'surah_name') {
      final surahNum = word.headerSurah ?? word.suraNumber ?? 1;
      final code = 'surah${surahNum.toString().padLeft(3, '0')}';
      return Text(
        code,
        style: TextStyle(
          fontFamily: 'SurahNames',
          fontSize: fontSize * 0.6,
          color: const Color(0xFFD0A871),
          height: 1.0,
        ),
      );
    }

    if (word.lineType == 'basmallah') {
      return Text(
        'بسم الله الرحمن الرحيم',
        style: TextStyle(
          fontFamily: 'uthmanic',
          fontSize: fontSize * 0.8,
          color: textColor,
          height: 1.0,
        ),
      );
    }

    if (isMarker) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: AyahMarkerWidget(
          ayahNumber: word.ayahNumber ?? 0,
          size: fontSize * 1.4,
          fontSize: fontSize * 0.42,
          numberColor: textColor.computeLuminance() > 0.5
              ? const Color(0xFFFFF8E1)
              : const Color(0xFF3E2723),
        ),
      );
    }
    return Text(
      word.text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: textColor,
        height: 1.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double contentWidth = 980.0; // 1080 - 50 - 50

    if (provider.isLoading || provider.allWords == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50.0),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD0A871)),
        ),
      );
    }

    if (provider.isMushafFormat && provider.mushafLines != null) {
      const double baseFontSize = 75.0; // Optimized for 980px width
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: provider.mushafLines!.map((line) {
          final firstWord = line.first;
          final pageNum = firstWord.pageNumber ?? 1;
          final fontFamily = FontsHelper.getFontFamily(pageNum);
          final isCentered = firstWord.isCentered ?? false;

          final bool isFullLine =
              provider.isInRange(line.first.ayahNumber ?? 0) &&
              provider.isInRange(line.last.ayahNumber ?? 0) &&
              line.first.suraNumber == provider.surahNumber &&
              line.last.suraNumber == provider.surahNumber;

          final bool shouldJustify = !isCentered && isFullLine && line.length > 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: contentWidth,
              // FittedBox ensures that wide lines never overflow horizontally!
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: shouldJustify ? contentWidth : 0.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: shouldJustify
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: line.map((word) {
                      final isSelected =
                          word.suraNumber == provider.surahNumber &&
                          provider.isInRange(word.ayahNumber ?? 0);

                      return Opacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        child: _buildWordWidget(
                          word,
                          _isMarker(word),
                          baseFontSize,
                          fontFamily,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    // Normal / Linear Format
    final List<InlineSpan> spans = [];
    final allWords = provider.allWords!;
    const double normalFontSize = 65.0; 

    for (int i = 0; i < allWords.length; i++) {
      final word = allWords[i];
      final fontFamily = FontsHelper.getFontFamily(word.pageNumber ?? 1);
      final isMarker = _isMarker(word);

      if (word.lineType == 'surah_name' || word.lineType == 'basmallah') {
        if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
        spans.add(WidgetSpan(
          child: Container(
            width: contentWidth,
            alignment: Alignment.center,
            child: _buildWordWidget(word, false, normalFontSize * 1.5, fontFamily), 
          ),
        ));
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      if (isMarker) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildWordWidget(word, true, normalFontSize, fontFamily),
        ));
        spans.add(const TextSpan(text: ' '));
      } else {
        spans.add(TextSpan(
          text: word.text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: normalFontSize,
            color: textColor,
            height: 1.3, 
          ),
        ));
        if (i < allWords.length - 1 && allWords[i+1].lineType != 'surah_name') {
          spans.add(const TextSpan(text: ' '));
        }
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: contentWidth,
        padding: EdgeInsets.zero,
        child: Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}

class _ShareFooter extends StatelessWidget {
  final bool isLightBg;

  const _ShareFooter({required this.isLightBg});

  @override
  Widget build(BuildContext context) {
    final textColor = isLightBg ? Colors.black54 : Colors.white60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 80.0,
          height: 80.0,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.mosque_rounded,
            color: Color(0xFFD0A871),
            size: 50.0,
          ),
        ),
        const SizedBox(height: 10.0),
        Text(
          'صنع بواسطة تطبيق عباد الرحمن',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _TextPreviewTab extends StatelessWidget {
  final ShareProvider provider;
  final Color onSurface;
  final bool isLightBg;

  const _TextPreviewTab({
    required this.provider,
    required this.onSurface,
    required this.isLightBg,
  });

  @override
  Widget build(BuildContext context) {
    final shareText = provider.buildShareText(withLogo: provider.showLogo);
    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isLightBg ? Colors.grey.shade50 : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isLightBg ? Colors.black12 : Colors.white12,
            width: 1.0.w,
          ),
        ),
        child: SingleChildScrollView(
          child: Text(
            shareText,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 20.sp,
              height: 1.9,
              color: onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final Color primary;
  final Color sheetBg;
  final bool isCapturing;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  final VoidCallback? onToggleColor;
  final VoidCallback? onCopy;

  const _Toolbar({
    required this.primary,
    required this.sheetBg,
    required this.isCapturing,
    required this.onShare,
    this.onSave,
    this.onToggleColor,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: sheetBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8.r,
              offset: Offset(0, -2.h),
            ),
          ],
        ),
        child: Row(
          children: [
            if (onSave != null) ...[
              _ToolbarButton(
                icon: Icons.download_rounded,
                label: 'حفظ',
                primary: primary,
                onTap: isCapturing ? null : onSave,
              ),
              SizedBox(width: 8.w),
            ],
            if (onToggleColor != null) ...[
              _ToolbarButton(
                icon: Icons.color_lens_rounded,
                label: 'لون الورقة',
                primary: primary,
                onTap: isCapturing ? null : onToggleColor,
              ),
              SizedBox(width: 8.w),
            ],
            if (onCopy != null) ...[
              _ToolbarButton(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                primary: primary,
                onTap: isCapturing ? null : onCopy,
              ),
              SizedBox(width: 8.w),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isCapturing ? null : onShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: isCapturing
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.w,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.share_rounded, size: 20.sp),
                label: Text(
                  isCapturing ? 'جارٍ المعالجة...' : 'مشاركة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
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

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primary;
  final VoidCallback? onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.0.w),
            ),
            child: Icon(icon, color: primary, size: 22.sp),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 10.sp, color: primary),
        ),
      ],
    );
  }
}

class _VerseRangeDropdowns extends StatelessWidget {
  final ShareProvider provider;
  final bool isLightBg;
  final Color onSurface;

  const _VerseRangeDropdowns({
    required this.provider,
    required this.isLightBg,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final bgColor = isLightBg ? Colors.grey.shade100 : Colors.grey.shade900;
    final surahNum = provider.surahNumber;
    final total = provider.totalVerses;
    final verses = List.generate(total, (i) => i + 1);

    return ColoredBox(
      color: bgColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          children: [
            Expanded(
              child: _VerseDropdown(
                label: 'من الآية',
                value: provider.fromVerse,
                verses: verses,
                surahNumber: surahNum,
                primary: primary,
                isLightBg: isLightBg,
                bgColor: bgColor,
                onChanged: (v) {
                  if (v != null) provider.setFromVerse(v);
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _VerseDropdown(
                label: 'إلى الآية',
                value: provider.toVerse,
                verses: verses,
                surahNumber: surahNum,
                primary: primary,
                isLightBg: isLightBg,
                bgColor: bgColor,
                onChanged: (v) {
                  if (v != null) provider.setToVerse(v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> verses;
  final int surahNumber;
  final Color primary;
  final bool isLightBg;
  final Color bgColor;
  final ValueChanged<int?> onChanged;

  const _VerseDropdown({
    required this.label,
    required this.value,
    required this.verses,
    required this.surahNumber,
    required this.primary,
    required this.isLightBg,
    required this.bgColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveTextColor = isLightBg ? Colors.black87 : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: effectiveTextColor.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: primary.withValues(alpha: 0.5),
              width: 1.0.w,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: bgColor,
              icon: Icon(Icons.expand_more_rounded, color: primary, size: 18.sp),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.sp,
                color: effectiveTextColor,
              ),
              items: verses.map((v) {
                return DropdownMenuItem<int>(
                  value: v,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        _PremiumVerseStarPainter(number: v, size: 28.w),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: DbMushafText(
                            surahNumber: surahNumber,
                            verseNumber: v,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: effectiveTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(height: 4.h),
        DbMushafText(
          surahNumber: surahNumber,
          verseNumber: value,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.4,
            color: effectiveTextColor,
          ),
        ),
      ],
    );
  }
}

class _PremiumVerseStarPainter extends StatelessWidget {
  final int number;
  final double size;
  const _PremiumVerseStarPainter({required this.number, this.size = 40.0});

  static String _toArabic(int n) {
    const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const a = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = n.toString();
    for (int i = 0; i < w.length; i++) {
      s = s.replaceAll(w[i], a[i]);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _PremiumStarPainter(),
        child: Center(
          child: Text(
            _toArabic(number),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: size * 0.30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.0,
              shadows: const [
                Shadow(
                  color: Color(0x55000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumStarPainter extends CustomPainter {
  const _PremiumStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final glowPaint = Paint()
      ..color = const Color(0xFFD0A871).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    _drawEightStar(canvas, cx, cy, r * 0.98, glowPaint);

    final gradientPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.3),
        radius: 0.9,
        colors: [Color(0xFFEDD08A), Color(0xFFD0A871), Color(0xFFB8894C)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    _drawEightStar(canvas, cx, cy, r * 0.92, gradientPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFF5DFA0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawEightStar(canvas, cx, cy, r * 0.92, borderPaint);
  }

  void _drawEightStar(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Paint paint,
  ) {
    void drawSquare(double angleDeg) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angleDeg * 3.14159265 / 180);
      final side = r * 1.22;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: side,
        height: side,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.18));
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }

    drawSquare(0);
    drawSquare(45);
  }

  @override
  bool shouldRepaint(_PremiumStarPainter old) => false;
}
