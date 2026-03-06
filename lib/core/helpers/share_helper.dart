import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Helper class for sharing and saving Quran page images in HD.
class ShareHelper {
  ShareHelper._();

  /// Captures the widget bound to [key] as a high-resolution PNG image.
  /// Returns the raw PNG bytes, or `null` if the capture fails.
  static Future<ui.Image?> _captureImage(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // pixelRatio 5.0 for HD quality
    return boundary.toImage(pixelRatio: 5.0);
  }

  /// Writes the captured image to a temporary file and returns its path.
  static Future<String?> _saveToTempFile(GlobalKey key, String fileName) async {
    final image = await _captureImage(key);
    if (image == null) return null;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose(); // free GPU memory immediately
    if (byteData == null) return null;

    final pngBytes = byteData.buffer.asUint8List();
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName.png';
    final file = File(filePath);
    await file.writeAsBytes(pngBytes);
    return filePath;
  }

  /// Shares the currently visible Mushaf page as an HD PNG image.
  static Future<void> sharePageImage(
    BuildContext context,
    GlobalKey key,
    String fileName,
  ) async {
    try {
      final filePath = await _saveToTempFile(key, fileName);
      if (filePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر التقاط الصفحة'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'من تطبيق عِبَادُ الرَّحْمَٰن 📖',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء المشاركة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Saves the currently visible Mushaf page directly to the device gallery.
  static Future<void> savePageToGallery(
    BuildContext context,
    GlobalKey key,
    String fileName,
  ) async {
    try {
      final filePath = await _saveToTempFile(key, fileName);
      if (filePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر التقاط الصفحة'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Use gal to save the image to the device gallery
      await Gal.putImage(filePath, album: 'عباد الرحمن');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الصفحة في المعرض بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on GalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: ${e.type.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  }) async {
    final List<String> paths = [];
    final total = keys.length;

    for (int i = 0; i < total; i++) {
      final path = await _saveToTempFile(keys[i], fileNames[i]);
      if (path != null) {
        paths.add(path);
      }
      onProgress?.call(i + 1, total);

      // Yield to the event loop so the UI can update & GC can run
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return paths;
  }

  /// Shares multiple page images at once via native share sheet.
  static Future<void> shareMultiplePageImages(
    BuildContext context, {
    required List<GlobalKey> keys,
    required List<String> fileNames,
    void Function(int completed, int total)? onProgress,
  }) async {
    try {
      final paths = await captureMultiplePages(
        keys: keys,
        fileNames: fileNames,
        onProgress: onProgress,
      );

      if (paths.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم التقاط أي صفحة'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: paths.map((p) => XFile(p)).toList(),
          text: 'ورد اليوم — من تطبيق عِبَادُ الرَّحْمَٰن 📖',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء المشاركة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Saves multiple page images to the gallery one by one.
  static Future<void> saveMultiplePagesToGallery(
    BuildContext context, {
    required List<GlobalKey> keys,
    required List<String> fileNames,
    void Function(int completed, int total)? onProgress,
  }) async {
    try {
      final paths = await captureMultiplePages(
        keys: keys,
        fileNames: fileNames,
        onProgress: onProgress,
      );

      if (paths.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم التقاط أي صفحة'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Save each image individually to avoid large batch failures
      for (final path in paths) {
        await Gal.putImage(path, album: 'عباد الرحمن');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حفظ ${paths.length} صفحة في المعرض بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on GalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: ${e.type.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
