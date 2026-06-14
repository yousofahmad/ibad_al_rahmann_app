import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/quran/quran_cubit.dart';
import '../../../bloc/verse_player/verse_player_cubit.dart';
import '../bookmark_widget/bookmarks_dialog.dart';

import 'package:ibad_al_rahmann/core/helpers/share_helper.dart';

// To access scaffoldMessengerKey

/// A floating action bar that appears on **single tap anywhere** on a Mushaf page.
/// Inspired by Microsoft Word's mini toolbar on selection.
///
/// Shows: Bookmark · Share · Copy · Save as Image
/// Animates in with scale+fade and a haptic "notification" buzz.
class PageActionBar extends StatefulWidget {
  final int pageNumber;
  final VoidCallback onDismiss;

  const PageActionBar({
    super.key,
    required this.pageNumber,
    required this.onDismiss,
  });

  @override
  State<PageActionBar> createState() => _PageActionBarState();

  static void showColorPalette(BuildContext context) {
    final quranCubit = context.read<QuranCubit>();
    final isWirdMode = quranCubit.state.isWirdMode;
    final isKahfMode = quranCubit.state.isKahfMode;
    
    // Safely look up QuranThemeCubit, if not found try casting ThemeCubit
    QuranThemeCubit themeCubit;
    try {
      themeCubit = context.read<QuranThemeCubit>();
    } catch (_) {
      themeCubit = context.read<ThemeCubit>() as QuranThemeCubit;
    }
    
    final currentTheme = Theme.of(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Colors',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Theme(
          data: currentTheme,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: quranCubit),
              BlocProvider.value(value: themeCubit),
            ],
            child: StatefulBuilder(
              builder: (context, setStateLocal) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                
                // Get the effective currentColor, applying fallbacks if null
                final currentColor = isKahfMode
                    ? (quranCubit.state.kahfPaperColor ?? const Color(0xFFF0F9ED))
                    : (isWirdMode
                        ? (quranCubit.state.wirdPaperColor ?? const Color(0xFFFFF9E5))
                        : (quranCubit.state.quranPaperColor ?? (isDark ? Colors.black : const Color(0xFFFFF9E5))));

                void updateColorLocal(Color? color) {
                  if (isKahfMode) {
                    quranCubit.setKahfColor(color);
                  } else if (isWirdMode) {
                    quranCubit.setWirdColor(color);
                  } else {
                    quranCubit.setPaperColor(color);
                  }
                  setStateLocal(() {});
                }

                final headerColor = ThemeData.estimateBrightnessForColor(
                  currentTheme.primaryColor,
                ) == Brightness.dark
                    ? Colors.white
                    : Colors.black87;

                final headerColorSubtle = ThemeData.estimateBrightnessForColor(
                  currentTheme.primaryColor,
                ) == Brightness.dark
                    ? Colors.white70
                    : Colors.black87;

                return Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      margin: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 10,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: currentTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title indicating the mode
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  isKahfMode
                                      ? 'لون خلفية الكهف'
                                      : (isWirdMode
                                          ? 'لون خلفية الورد'
                                          : 'لون خلفية المصحف'),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: headerColorSubtle,
                                  ),
                                ),
                              ),
                              // Color circles row (scrollable if too many, but centered)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ColorCircle(
                                      color: Colors.white,
                                      label: 'أبيض',
                                      isSelected: currentColor.toARGB32() ==
                                          Colors.white.toARGB32(),
                                      onTap: () =>
                                          updateColorLocal(Colors.white),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: const Color(0xFFFFF9E5),
                                      label: 'كريمي',
                                      isSelected: currentColor.toARGB32() ==
                                          const Color(0xFFFFF9E5).toARGB32(),
                                      onTap: () => updateColorLocal(
                                        const Color(0xFFFFF9E5),
                                      ),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: const Color(0xFFF5F5DC),
                                      label: 'قديم',
                                      isSelected: currentColor.toARGB32() ==
                                          const Color(0xFFF5F5DC).toARGB32(),
                                      onTap: () => updateColorLocal(
                                        const Color(0xFFF5F5DC),
                                      ),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: Colors.white30,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: Colors.black,
                                      label: 'أسود',
                                      isSelected: currentColor.toARGB32() ==
                                          Colors.black.toARGB32(),
                                      onTap: () =>
                                          updateColorLocal(Colors.black),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: const Color(0xFF1E1E1E),
                                      label: 'داكن',
                                      isSelected: currentColor.toARGB32() ==
                                          const Color(0xFF1E1E1E).toARGB32(),
                                      onTap: () => updateColorLocal(
                                        const Color(0xFF1E1E1E),
                                      ),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: const Color(0xFF001F3F),
                                      label: 'كحلي',
                                      isSelected: currentColor.toARGB32() ==
                                          const Color(0xFF001F3F).toARGB32(),
                                      onTap: () => updateColorLocal(
                                        const Color(0xFF001F3F),
                                      ),
                                      onHeaderColor: headerColor,
                                    ),
                                  ],
                                ),
                              ),
                              // Margin slider
                              const SizedBox(height: 8),
                              Container(height: 1, color: Colors.white24),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.format_indent_increase_rounded,
                                    color: headerColorSubtle,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'هامش الصفحة',
                                    style: TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 11,
                                      color: headerColorSubtle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 130,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        thumbColor: headerColor,
                                        activeTrackColor: headerColor,
                                        inactiveTrackColor: Colors.black
                                            .withAlpha(40),
                                        overlayShape:
                                            SliderComponentShape.noOverlay,
                                      ),
                                      child: Slider(
                                        min: 0,
                                        max: 40,
                                        value: quranCubit.state.quranPageMargin,
                                        onChanged: (val) {
                                          quranCubit.setPageMargin(val);
                                          setStateLocal(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  static void showBookmarksList(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<QuranCubit>()),
          BlocProvider.value(value: context.read<VersePlayerCubit>()),
        ],
        child: const BookmarksDialog(),
      ),
    );
  }
}

class _PageActionBarState extends State<PageActionBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3), // Bug 5: slides in from above
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onOpenBookmarksList() {
    if (_isBusy) return;
    widget.onDismiss();
    PageActionBar.showBookmarksList(context);
  }

  Future<void> _showQualityPicker(Function(double) onSelected) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = Theme.of(context).primaryColor;
    double quality = 5.0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          title: Text(
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
    final gold = Theme.of(context).primaryColor;
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

  Future<void> _onSaveImage() async {
    if (_isBusy) return;
    
    await _showQualityPicker((selectedQuality) async {
      setState(() => _isBusy = true);
      final quranCubit = context.read<QuranCubit>();
      quranCubit.toggleExporting(true);

      try {
        final key = quranCubit.getPageKey(widget.pageNumber);
        await ShareHelper.savePageToGallery(
          context,
          key,
          'quran_page_${widget.pageNumber}',
          quality: selectedQuality,
        );
        widget.onDismiss();
      } catch (e) {
        debugPrint('Error in _onSaveImage: $e');
      } finally {
        quranCubit.toggleExporting(false);
        if (mounted) setState(() => _isBusy = false);
      }
    });
  }

  Future<void> _onShare() async {
    if (_isBusy) return;

    await _showQualityPicker((selectedQuality) async {
      setState(() => _isBusy = true);
      final quranCubit = context.read<QuranCubit>();
      quranCubit.toggleExporting(true);

      try {
        final key = quranCubit.getPageKey(widget.pageNumber);
        await ShareHelper.sharePageImage(
          context,
          key,
          'quran_page_${widget.pageNumber}',
          quality: selectedQuality,
        );
        widget.onDismiss();
      } catch (e) {
        debugPrint('Error in _onShare: $e');
      } finally {
        quranCubit.toggleExporting(false);
        if (mounted) setState(() => _isBusy = false);
      }
    });
  }

  void _onOpenColorPalette() {
    if (_isBusy) return;
    widget.onDismiss();
    PageActionBar.showColorPalette(context);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    // The bar background is now always the theme's primary color
    final barBg = primaryColor;
    
    // Since primary color is usually strong, we use white/white70 for contrast
    const onBar = Colors.white;
    const onBarSubtle = Colors.white70;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          alignment: Alignment.topCenter, // Bug 5: anchor at top
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              // Sit just below the safe area (status bar)
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(
                        icon: Icons.color_lens_rounded,
                        label: 'الألوان',
                        onTap: _onOpenColorPalette,
                        isEnabled: !_isBusy,
                        color: onBar,
                      ),
                      _divider(onBarSubtle),
                      BlocBuilder<QuranCubit, QuranState>(
                        builder: (context, state) {
                          if (state.isWirdMode) return const SizedBox.shrink();
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ActionButton(
                                icon: Icons.bookmarks_rounded,
                                label: 'المحفوظات',
                                onTap: _onOpenBookmarksList,
                                isEnabled: !_isBusy,
                                color: onBar,
                              ),
                              _divider(onBarSubtle),
                            ],
                          );
                        },
                      ),
                      BlocBuilder<QuranCubit, QuranState>(
                        builder: (context, state) {
                          final isAutoScrolling = state.isAutoScrolling;
                          return _ActionButton(
                            icon: isAutoScrolling
                                ? Icons.stop_circle_outlined
                                : Icons.keyboard_double_arrow_down,
                            label: isAutoScrolling ? 'إيقاف' : 'أوتو سكرول',
                            isEnabled: !_isBusy,
                            color: onBar,
                            onTap: () {
                              context.read<QuranCubit>().toggleAutoScroll();
                              widget.onDismiss();
                            },
                          );
                        },
                      ),
                      _divider(onBarSubtle),
                      _ActionButton(
                        icon: Icons.download_rounded,
                        label: _isBusy ? 'جاري..' : 'حفظ',
                        onTap: _onSaveImage,
                        isEnabled: !_isBusy,
                        isLoading: _isBusy,
                        color: onBar,
                      ),
                      _divider(onBarSubtle),
                      _ActionButton(
                        icon: Icons.share_rounded,
                        label: _isBusy ? 'جاري..' : 'مشاركة',
                        onTap: _onShare,
                        isEnabled: !_isBusy,
                        isLoading: _isBusy,
                        color: onBar,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(Color color) => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: color.withAlpha(60),
  );
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color onHeaderColor;

  const _ColorCircle({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.onHeaderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Colors.greenAccent
                    : onHeaderColor.withAlpha(150),
                width: isSelected ? 3 : 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: onHeaderColor,
              fontSize: 10,
              fontFamily: 'cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isLoading;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
