import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/helpers/alert_helper.dart';
import '../../../../core/theme/theme_manager/theme_cubit.dart';
import '../../bloc/quran/quran_cubit.dart';
import '../../bloc/verse_player/verse_player_cubit.dart';
import '../../data/services/bookmark_service.dart';
import 'bookmark_widget/bookmarks_dialog.dart';

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
}

class _PageActionBarState extends State<PageActionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    // Haptic feedback – notification-style buzz
    HapticFeedback.mediumImpact();

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─── Actions ───

  void _onBookmark() {
    // Open the saved bookmarks list
    final bookmarks = BookmarkService.getAllBookmarks();
    final versePlayerCubit = context.read<VersePlayerCubit>();
    final quranCubit = context.read<QuranCubit>();

    widget.onDismiss();

    if (bookmarks.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'الآيات المحفوظة',
            style: TextStyle(fontFamily: 'cairo'),
          ),
          content: const Text(
            'لم تقم بحفظ أى آية إلى الآن',
            style: TextStyle(fontFamily: 'cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسنًا', style: TextStyle(fontFamily: 'cairo')),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: versePlayerCubit),
            BlocProvider.value(value: quranCubit),
          ],
          child: const BookmarksDialog(),
        ),
      );
    }
  }

  Future<void> _onShare() async {
    try {
      final cubit = context.read<QuranCubit>();
      final repaintKey = cubit.getPageKey(widget.pageNumber);
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _shareAsText();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 5.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        _shareAsText();
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'quran_page_${widget.pageNumber}.png',
      );
      widget.onDismiss();
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text:
              'صفحة ${widget.pageNumber} من المصحف الشريف\nمن تطبيق عِبَادُ الرَّحْمَٰن 📖',
        ),
      );
    } catch (e) {
      _shareAsText();
    }
  }

  void _shareAsText() async {
    widget.onDismiss();
    await SharePlus.instance.share(
      ShareParams(
        text:
            'صفحة ${widget.pageNumber} من المصحف الشريف\nمن تطبيق عِبَادُ الرَّحْمَٰن 📖',
      ),
    );
  }

  Future<void> _onSaveAsImage() async {
    try {
      // Request gallery permission
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
        final granted = await Gal.hasAccess();
        if (!granted) {
          if (mounted) {
            AlertHelper.showWarningAlert(
              context,
              message: 'مطلوب إذن الوصول للمعرض',
            );
          }
          widget.onDismiss();
          return;
        }
      }

      final cubit = context.read<QuranCubit>();
      final repaintKey = cubit.getPageKey(widget.pageNumber);
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          AlertHelper.showWarningAlert(context, message: 'تعذر التقاط الصفحة');
        }
        widget.onDismiss();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 5.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          AlertHelper.showWarningAlert(context, message: 'تعذر التقاط الصفحة');
        }
        widget.onDismiss();
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save directly to gallery
      await Gal.putImageBytes(pngBytes, album: 'عباد الرحمن');

      if (mounted) {
        AlertHelper.showSuccessAlert(
          context,
          message: 'تم حفظ صفحة ${widget.pageNumber} في المعرض ✓',
        );
      }
      widget.onDismiss();
    } on GalException catch (e) {
      if (mounted) {
        String msg = 'حدث خطأ أثناء الحفظ';
        if (e.type == GalExceptionType.accessDenied) {
          msg = 'تم رفض إذن الوصول للمعرض';
        } else if (e.type == GalExceptionType.notEnoughSpace) {
          msg = 'لا توجد مساحة كافية';
        }
        AlertHelper.showWarningAlert(context, message: msg);
      }
      widget.onDismiss();
    } catch (e) {
      if (mounted) {
        AlertHelper.showWarningAlert(context, message: 'حدث خطأ أثناء الحفظ');
      }
      widget.onDismiss();
    }
  }

  void _onToggleTheme() {
    context.read<ThemeCubit>().switchTheme();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: Icons.bookmark_rounded,
                  label: 'بوك مارك',
                  onTap: _onBookmark,
                ),
                _divider(),
                _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'مشاركة',
                  onTap: _onShare,
                ),
                _divider(),
                _ActionButton(
                  icon: Icons.image_rounded,
                  label: 'حفظ صورة',
                  onTap: _onSaveAsImage,
                ),
                _divider(),
                BlocBuilder<ThemeCubit, ThemeState>(
                  builder: (context, themeState) {
                    final isDark = themeState.mode == ThemeMode.dark;
                    return _ActionButton(
                      icon: isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      label: isDark ? 'فاتح' : 'داكن',
                      onTap: _onToggleTheme,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.white.withAlpha(60),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
