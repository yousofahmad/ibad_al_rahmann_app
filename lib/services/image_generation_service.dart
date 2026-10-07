import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gal/gal.dart';
import 'package:ibad_al_rahmann/services/app_logger.dart';

class ImageGenerationService {
  static Future<Uint8List> captureAsPng(
    GlobalKey boundaryKey, {
    double? pixelRatio,
  }) async {
    final double targetRatio = (pixelRatio != null && pixelRatio > 3.0)
        ? 3.0
        : (pixelRatio ?? 2.5);

    for (int attempt = 0; attempt < 8; attempt++) {
      try {
        final currentContext = boundaryKey.currentContext;
        if (currentContext == null || !currentContext.mounted) {
          await Future.delayed(const Duration(milliseconds: 60));
          await WidgetsBinding.instance.endOfFrame;
          continue;
        }

        final renderObject = currentContext.findRenderObject();
        if (renderObject is! RenderRepaintBoundary ||
            !renderObject.hasSize ||
            renderObject.size.width <= 0 ||
            renderObject.size.height <= 0) {
          await Future.delayed(const Duration(milliseconds: 60));
          await WidgetsBinding.instance.endOfFrame;
          continue;
        }

        final double effectiveRatio = attempt == 0
            ? targetRatio
            : (attempt == 1 ? 2.0 : 1.5);

        AppLogger.log(
          "ImageGenerationService",
          "Capturing boundary at ratio $effectiveRatio (attempt $attempt, size: ${renderObject.size})",
        );

        final ui.Image image = await renderObject.toImage(
          pixelRatio: effectiveRatio,
        );
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData == null) {
          throw StateError('Failed to convert image to byte data.');
        }

        return byteData.buffer.asUint8List();
      } catch (e) {
        AppLogger.log(
          "ImageGenerationService",
          "Capture attempt $attempt failed: $e",
        );
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }

    throw StateError('تعذر التقاط الصورة بعد محاولات متعددة.');
  }

  static Future<String> saveTempAndGetPath(
    Uint8List bytes, {
    String filename = 'verse_share.png',
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<void> saveToGallery(Uint8List bytes) async {
    // Check/request permissions
    bool hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      hasAccess = await Gal.requestAccess(toAlbum: true);
    }

    if (!hasAccess) {
      throw StateError('يجب منح صلاحية الوصول للمعرض لحفظ الصورة.');
    }

    try {
      // Step 1: Save to a temporary file first (more stable than direct bytes)
      final tempPath = await saveTempAndGetPath(
        bytes,
        filename: "ubad_share_${DateTime.now().millisecondsSinceEpoch}.png",
      );

      // Step 2: Use Gal to save the file to the gallery
      await Gal.putImage(tempPath, album: 'عباد الرحمن');

      // Optional: Cleanup temp file
      try {
        await File(tempPath).delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('Gallery save error: $e');
      throw StateError('خطأ أثناء الحفظ: $e');
    }
  }
}
