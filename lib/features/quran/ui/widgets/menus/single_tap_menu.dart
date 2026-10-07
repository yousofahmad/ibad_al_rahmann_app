import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/ui/quran_readers_screen.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/theme/quran_theme_cubit.dart';
import 'package:ibad_al_rahmann/core/theme/theme_manager/theme_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/quran/quran_cubit.dart';
import '../../../bloc/verse_player/verse_player_cubit.dart';
import '../bookmark_widget/bookmarks_dialog.dart';

import 'package:ibad_al_rahmann/core/helpers/share_helper.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

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
                    ? (quranCubit.state.kahfPaperColor ??
                          const Color(0xFFF0F9ED))
                    : (isWirdMode
                          ? (quranCubit.state.wirdPaperColor ??
                                const Color(0xFFFFF9E5))
                          : (quranCubit.state.quranPaperColor ??
                                (isDark
                                    ? Colors.black
                                    : const Color(0xFFFFF9E5))));

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

                final headerColor =
                    ThemeData.estimateBrightnessForColor(
                          currentTheme.primaryColor,
                        ) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87;

                final headerColorSubtle =
                    ThemeData.estimateBrightnessForColor(
                          currentTheme.primaryColor,
                        ) ==
                        Brightness.dark
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
                                      isSelected:
                                          currentColor.toARGB32() ==
                                          Colors.white.toARGB32(),
                                      onTap: () =>
                                          updateColorLocal(Colors.white),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: const Color(0xFFFFF9E5),
                                      label: 'كريمي',
                                      isSelected:
                                          currentColor.toARGB32() ==
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
                                      isSelected:
                                          currentColor.toARGB32() ==
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
                                      isSelected:
                                          currentColor.toARGB32() ==
                                          Colors.black.toARGB32(),
                                      onTap: () =>
                                          updateColorLocal(Colors.black),
                                      onHeaderColor: headerColor,
                                    ),
                                    const SizedBox(width: 12),
                                    _ColorCircle(
                                      color: const Color(0xFF1E1E1E),
                                      label: 'داكن',
                                      isSelected:
                                          currentColor.toARGB32() ==
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
                                      isSelected:
                                          currentColor.toARGB32() ==
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
    const gold = Color(0xFFD0A871);
    double selectedQuality = 3.0;

    final qualities = [
      {
        'title': 'فائقة (4K Ultra HD)',
        'subtitle': 'أعلى وضوح ونقاء فائق لصفحة المصحف (أعلى جودة)',
        'value': 5.0,
        'badge': 'أفضل نقاء 🌟',
      },
      {
        'title': 'عالية (QHD)',
        'subtitle': 'دقة ممتازة وسريعة في الحفظ والمشاركة',
        'value': 3.0,
        'badge': 'سريعة ومتوازنة ⚡',
      },
      {
        'title': 'قياسية (Full HD)',
        'subtitle': 'حجم صغير ومناسب للمشاركة السريعة',
        'value': 1.5,
        'badge': 'خفيفة وسريعة 📱',
      },
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_filter_rounded,
                  color: gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'اختر دقة صورة المصحف',
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: gold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: qualities.map((q) {
                final double val = q['value'] as double;
                final bool isSelected = selectedQuality == val;
                return InkWell(
                  onTap: () => setDlgState(() => selectedQuality = val),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? gold.withValues(alpha: 0.12)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? gold : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? gold : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      q['title'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isSelected
                                            ? gold
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? gold.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      q['badge'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? gold : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                q['subtitle'] as String,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.4),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      onSelected(selectedQuality);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'متابعة',
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSaveImage() async {
    if (_isBusy) return;

    await _showQualityPicker((selectedQuality) async {
      setState(() => _isBusy = true);
      final quranCubit = context.read<QuranCubit>();

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
        if (mounted) setState(() => _isBusy = false);
      }
    });
  }

  Future<void> _onShare() async {
    if (_isBusy) return;

    await _showQualityPicker((selectedQuality) async {
      setState(() => _isBusy = true);
      final quranCubit = context.read<QuranCubit>();

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
                        icon: FontAwesomeIcons.headphones,
                        label: 'المصحف الصوتي',
                        onTap: () {
                          widget.onDismiss();
                          context.push(QuranReadersScreen(paperColor: null));
                        },
                        isEnabled: !_isBusy,
                        color: onBar,
                      ),
                      _divider(onBarSubtle),
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
