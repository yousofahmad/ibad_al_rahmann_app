import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class ShareHelper {
  /// Captures the widget bound to [key] as a high-resolution PNG image.
  static Future<ui.Image?> _captureImage(GlobalKey key, {double pixelRatio = 5.0}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('🔴 ShareHelper: Boundary is null for key $key');
        return null;
      }
      debugPrint('🟢 ShareHelper: Starting capture with pixelRatio $pixelRatio...');
      return await boundary.toImage(pixelRatio: pixelRatio);
    } catch (e) {
      debugPrint('🔴 ShareHelper: Error in _captureImage at ratio $pixelRatio: $e');
      // Fallback logic
      if (pixelRatio > 2.0) {
        debugPrint('🟡 ShareHelper: High-res capture failed. Falling back to lower ratio...');
        return _captureImage(key, pixelRatio: pixelRatio / 2);
      }
      return null;
    }
  }

  /// Writes the captured image to a temporary file and returns its path.
  static Future<String?> _saveToTempFile(GlobalKey key, String fileName, {double quality = 5.0}) async {
    try {
      // Wait for the UI to be fully settled (e.g. after long-press or tap)
      await Future.delayed(const Duration(milliseconds: 600));

      final image = await _captureImage(key, pixelRatio: quality);
      if (image == null) return null;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final buffer = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      
      // FIX: Ensure the filename has a valid image extension (.png) for Gal compatibility
      String safeName = fileName;
      if (!safeName.toLowerCase().endsWith('.png')) {
        safeName = '$safeName.png';
      }
      
      final filePath = '${directory.path}/$safeName';
      final file = File(filePath);

      await file.writeAsBytes(buffer);
      debugPrint('🟢 ShareHelper: Image saved to temp file: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('🔴 ShareHelper: Exception in _saveToTempFile: $e');
      return null;
    }
  }

  static void showTopNotification(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        isError: isError,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  /// Shares the currently visible Mushaf page as an HD PNG image.
  static Future<void> sharePageImage(
    BuildContext context,
    GlobalKey key,
    String fileName, {
    double quality = 5.0,
  }) async {
    try {
      final filePath = await _saveToTempFile(key, fileName, quality: quality);
      if (filePath == null) {
        if (!context.mounted) return;
        showTopNotification(context, 'تعذر التقاط الصفحة للمشاركة', isError: true);
        return;
      }

      debugPrint('🟢 ShareHelper: Invoking Share for $filePath');
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'من تطبيق عِبَادُ الرَّحْمَٰن 📖',
      );
    } catch (e) {
      debugPrint('🔴 ShareHelper: Share error: $e');
      if (!context.mounted) return;
      showTopNotification(context, 'خطأ أثناء المشاركة: $e', isError: true);
    }
  }

  /// Saves the currently visible Mushaf page directly to the device gallery.
  static Future<void> savePageToGallery(
    BuildContext context,
    GlobalKey key,
    String fileName, {
    double quality = 5.0,
  }) async {
    try {
      final filePath = await _saveToTempFile(key, fileName, quality: quality);
      if (filePath == null) {
        if (!context.mounted) return;
        showTopNotification(context, 'تعذر التقاط الصفحة للحفظ', isError: true);
        return;
      }

      debugPrint('🟢 ShareHelper: Saving $filePath to gallery via Gal...');
      // Request permission explicitly if possible (some devices need this)
      await Gal.putImage(filePath, album: 'عباد الرحمن');

      if (!context.mounted) return;
      showTopNotification(context, '✅ تم حفظ الصفحة في المعرض بنجاح');
    } catch (e) {
      debugPrint('🔴 ShareHelper: Gallery save error: $e');
      if (!context.mounted) return;
      showTopNotification(context, 'فشل الحفظ: $e', isError: true);
    }
  }

  // ─── Multi-page Methods (for Wird export) ─────────────────────────

  /// Captures multiple pages sequentially (one at a time to prevent
  /// memory crashes) and returns a list of temp file paths.
  ///
  /// [onProgress] is called with (completed, total) for UI updates.
  static Future<List<String>> captureMultiplePages({
    required List<GlobalKey> keys,
    required List<String> fileNames,
    void Function(int completed, int total)? onProgress,
    double quality = 5.0,
  }) async {
    final List<String> paths = [];
    final total = keys.length;

    for (int i = 0; i < total; i++) {
      final path = await _saveToTempFile(keys[i], fileNames[i], quality: quality);
      if (path != null) {
        paths.add(path);
      }
      onProgress?.call(i + 1, total);

      // Yield to the event loop so the UI can update & GC can run
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return paths;
  }

  /// Shares multiple page images at once via native share sheet.
  static Future<void> shareMultiplePageImages(
    BuildContext context, {
    required List<GlobalKey> keys,
    required List<String> fileNames,
    void Function(int completed, int total)? onProgress,
    double quality = 5.0,
  }) async {
    try {
      final paths = await captureMultiplePages(
        keys: keys,
        fileNames: fileNames,
        onProgress: onProgress,
        quality: quality,
      );

      if (paths.isEmpty) {
        if (!context.mounted) return;
        showTopNotification(context, 'لم يتم التقاط أي صفحة', isError: true);
        return;
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        paths.map((p) => XFile(p)).toList(),
        text: 'ورد اليوم — من تطبيق عِبَادُ الرَّحْمَٰن 📖',
      );
    } catch (e) {
      if (!context.mounted) return;
      showTopNotification(context, 'خطأ أثناء المشاركة: $e', isError: true);
    }
  }

  /// Saves multiple page images to the gallery one by one.
  static Future<void> saveMultiplePagesToGallery(
    BuildContext context, {
    required List<GlobalKey> keys,
    required List<String> fileNames,
    void Function(int completed, int total)? onProgress,
    double quality = 5.0,
  }) async {
    try {
      final paths = await captureMultiplePages(
        keys: keys,
        fileNames: fileNames,
        onProgress: onProgress,
        quality: quality,
      );

      if (paths.isEmpty) {
        if (!context.mounted) return;
        showTopNotification(context, 'لم يتم التقاط أي صفحة', isError: true);
        return;
      }

      // Save each image individually to avoid large batch failures
      int savedCount = 0;
      for (final path in paths) {
        try {
          if (path.isEmpty || !path.toLowerCase().endsWith('.png')) continue;
          await Gal.putImage(path, album: 'عباد الرحمن');
          savedCount++;
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('Failed to save page $path to gallery: $e');
        }
      }

      if (!context.mounted) return;
      showTopNotification(context, '✅ تم حفظ $savedCount صفحة في المعرض بنجاح');
    } catch (e) {
      if (!context.mounted) return;
      showTopNotification(context, 'خطأ أثناء الحفظ: $e', isError: true);
    }
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _offsetAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isError ? Colors.red : Colors.green,
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
              widget.message,
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
  }
}
