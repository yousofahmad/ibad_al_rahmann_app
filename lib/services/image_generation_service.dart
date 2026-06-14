import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gal/gal.dart';

class ImageGenerationService {
  static Future<Uint8List> captureAsPng(GlobalKey boundaryKey, {double? pixelRatio}) async {
    // Very short delay to ensure the framework has rendered the RepaintBoundary
    await Future.delayed(const Duration(milliseconds: 20));

    final currentContext = boundaryKey.currentContext;
    if (currentContext == null || !currentContext.mounted) {
      throw StateError(
        'عذراً، لم يتم العثور على منطقة الرسم (Context is null). تأكد من اكتمال تحميل البيانات.',
      );
    }

    final renderObject = currentContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('RepaintBoundary not found for the given key.');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio ?? 6.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw StateError('Failed to convert image to byte data.');
    }

    return byteData.buffer.asUint8List();
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
