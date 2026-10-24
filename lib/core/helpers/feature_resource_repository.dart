import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Read-only access to an optional, developer-provided local feature tree.
///
/// The configured tree is intentionally disabled in release builds. This class
/// never creates, deletes, or writes files.
class FeatureResourceRepository {
  static final FeatureResourceRepository configured = FeatureResourceRepository(
    rootPath: const String.fromEnvironment(
      'IBAD_LOCAL_RESOURCE_ROOT',
      defaultValue: '',
    ),
  );

  final String rootPath;
  String? _canonicalRoot;

  FeatureResourceRepository({required this.rootPath});

  bool get enabled => rootPath.trim().isNotEmpty && !kReleaseMode;

  Future<String?> _safePath(String relativePath) async {
    if (!enabled || relativePath.isEmpty || relativePath.contains('\\')) {
      return null;
    }
    if (relativePath.startsWith('/') || relativePath.startsWith('~')) {
      return null;
    }
    final parsed = Uri.tryParse(relativePath);
    if (parsed == null || parsed.hasScheme || parsed.hasAuthority) return null;
    if (relativePath.contains('%')) return null;

    final segments = relativePath.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      return null;
    }
    try {
      final root = _canonicalRoot ??= await Directory(
        rootPath,
      ).resolveSymbolicLinks();
      final candidate = File('$root/$relativePath');
      final resolved = await candidate.resolveSymbolicLinks();
      final rootPrefix = root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
      if (!resolved.startsWith(rootPrefix)) return null;
      return resolved;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> readBytes(String relativePath) async {
    final path = await _safePath(relativePath);
    if (path == null) return null;
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readJson(String relativePath) async {
    final bytes = await readBytes(relativePath);
    if (bytes == null) return null;
    try {
      final decoded = json.decode(utf8.decode(bytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> fileUri(String relativePath) async {
    final path = await _safePath(relativePath);
    return path == null ? null : Uri.file(path).toString();
  }

  Future<bool> containsFileUri(Uri uri) async {
    if (!enabled ||
        uri.scheme != 'file' ||
        uri.host.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    try {
      final root = _canonicalRoot ??= await Directory(
        rootPath,
      ).resolveSymbolicLinks();
      final prefix = root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
      final path = uri.toFilePath();
      if (!path.startsWith(prefix)) return false;
      final relative = path.substring(prefix.length).replaceAll('\\', '/');
      return await _safePath(relative) == path;
    } catch (_) {
      return false;
    }
  }
}
