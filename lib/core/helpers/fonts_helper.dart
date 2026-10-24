import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mushaf_format_repository.dart';

class FontsHelper {
  static final Set<String> _loadedFonts = <String>{};
  static final Map<String, Future<void>> _loadingFutures =
      <String, Future<void>>{};

  static bool isFontLoaded(String family) => _loadedFonts.contains(family);

  static Future<void> loadFont(String family, String path) async {
    if (_loadedFonts.contains(family)) return;
    final existing = _loadingFutures[family];
    if (existing != null) return existing;
    final future = _loadFontInternal(family, path);
    _loadingFutures[family] = future;
    try {
      await future;
    } finally {
      _loadingFutures.remove(family);
    }
  }

  static Future<void> _loadFontInternal(String family, String path) async {
    try {
      final loader = FontLoader(family)..addFont(rootBundle.load(path));
      await loader.load();
      _loadedFonts.add(family);
    } catch (e) {
      debugPrint('Error loading font $family: $e');
    }
  }

  static String getFontFamily(int pageNumber) =>
      MushafFormatRepository.instance.fontFamily(pageNumber);

  static Future<void> loadFontFromFamily(String family) async {
    if (_loadedFonts.contains(family)) return;
    final builtinMatch = RegExp(r'^QCF_V1_P(\d+)$').firstMatch(family);
    if (builtinMatch != null) {
      final page = int.tryParse(builtinMatch.group(1)!);
      if (page != null) await loadFont(family, getFontPath(page));
      return;
    }

    final packMatch = RegExp(r'^IBAD_[A-Z0-9_]+_P(\d+)$').firstMatch(family);
    if (packMatch == null) return;
    final page = int.tryParse(packMatch.group(1)!);
    if (page == null) return;
    final repository = MushafFormatRepository.instance;
    await repository.initialize();
    // A caller awaiting an old pack must not load the newly selected pack's
    // trusted file under the old family alias after a selection change.
    if (repository.current.isBuiltin || repository.fontFamily(page) != family) {
      throw StateError('Stale mushaf font family request');
    }
    final path = repository.pageFontPath(page);
    if (path == null) throw StateError('Installed mushaf font is missing');
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Installed mushaf font is missing');
    }
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loadedFonts.add(family);
  }

  /// Returns whether two valid Mushaf font families belong to the same format.
  /// The page number is deliberately ignored, while unrelated formats are not.
  static bool sameFormatFamily(String left, String right) {
    final leftPrefix = _formatPrefix(left);
    final rightPrefix = _formatPrefix(right);
    return leftPrefix != null && leftPrefix == rightPrefix;
  }

  static String? _formatPrefix(String family) {
    if (RegExp(r'^QCF_V1_P[1-9]\d*$').hasMatch(family)) {
      return 'QCF_V1';
    }
    final match = RegExp(
      r'^(IBAD_QPC_V[124](?:_[A-Z0-9]+)*)_P[1-9]\d*$',
    ).firstMatch(family);
    return match?.group(1);
  }

  static String getFontPath(int pageNumber) =>
      'assets/fonts/QPC V1 Font.ttf/p$pageNumber.ttf';
}
