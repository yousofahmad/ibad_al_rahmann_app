/// A downloadable language/edition of a tafsir. The ID remains the cache key,
/// so adding a family never invalidates existing downloads or selections.
class TafsirBook {
  final String id;
  final String name;
  final String author;
  final bool isBuiltIn;
  final String? url;
  final String? size;
  final String? groupId;
  final String? groupName;
  final String languageCode;
  final String? languageName;
  final String? direction;
  final String? edition;
  final int? sourceId;

  const TafsirBook({
    required this.id,
    required this.name,
    required this.author,
    this.isBuiltIn = false,
    this.url,
    this.size,
    this.groupId,
    this.groupName,
    this.languageCode = 'und',
    this.languageName,
    this.direction,
    this.edition,
    this.sourceId,
  });

  static const nativeLanguageNames = <String, String>{
    'ar': 'العربية',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'it': 'Italiano',
    'de': 'Deutsch',
    'pt': 'Português',
    'sq': 'Shqip',
    'as': 'অসমীয়া',
    'az': 'Azərbaycanca',
    'bn': 'বাংলা',
    'bs': 'Bosanski',
    'km': 'ភាសាខ្មែរ',
    'zh': '中文',
    'ff': 'Fulfulde',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'ja': '日本語',
    'ky': 'Кыргызча',
    'ku': 'Kurdî',
    'ckb': 'کوردی',
    'fa': 'فارسی',
    'ps': 'پښتو',
    'ru': 'Русский',
    'sr': 'Српски',
    'si': 'සිංහල',
    'tl': 'Filipino',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'th': 'ไทย',
    'ug': 'ئۇيغۇرچە',
    'ur': 'اردو',
    'uz': 'Oʻzbekcha',
    'vi': 'Tiếng Việt',
    'tr': 'Türkçe',
    'ml': 'മലയാളം',
    'und': 'لغة غير محددة',
  };

  String get familyId => TafsirCatalog.isValidId(groupId) ? groupId! : id;
  String get familyName => _nonEmpty(groupName) ?? name;
  String get displayName =>
      TafsirCatalog.familyDisplayName(familyId, familyName, [this]);
  String get languageLabel =>
      _nonEmpty(languageName) ??
      nativeLanguageNames[languageCode.toLowerCase().split('-').first] ??
      languageCode;

  bool get isRtl {
    if (direction == 'rtl') return true;
    if (direction == 'ltr') return false;
    return const {
      'ar',
      'ur',
      'fa',
      'ps',
      'ug',
      'ckb',
    }.contains(languageCode.toLowerCase().split('-').first);
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  factory TafsirBook.fromJson(Map<String, dynamic> json) => TafsirBook(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    author: json['author']?.toString() ?? '',
    isBuiltIn: json['is_builtin'] == true,
    url: json['url']?.toString(),
    size: json['size']?.toString(),
    groupId: json['group_id']?.toString(),
    groupName: json['group_name']?.toString(),
    languageCode: _nonEmpty(json['language_code']?.toString()) ?? 'und',
    languageName: json['language_name']?.toString(),
    direction: json['text_direction']?.toString(),
    edition: json['edition']?.toString(),
    sourceId: int.tryParse(json['source_id']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'author': author,
    'is_builtin': isBuiltIn,
    if (url != null) 'url': url,
    if (size != null) 'size': size,
    if (groupId != null) 'group_id': groupId,
    if (groupName != null) 'group_name': groupName,
    'language_code': languageCode,
    if (languageName != null) 'language_name': languageName,
    if (direction != null) 'text_direction': direction,
    if (edition != null) 'edition': edition,
    if (sourceId != null) 'source_id': sourceId,
  };
}

class TafsirBookGroup {
  final String id;
  final String name;
  final List<TafsirBook> variants;

  TafsirBookGroup({
    required this.id,
    required this.name,
    required Iterable<TafsirBook> variants,
  }) : variants = List.unmodifiable(variants);

  String variantLabel(TafsirBook book) {
    final edition = book.edition?.trim();
    if (edition != null && edition.isNotEmpty) {
      return '${book.languageLabel} — $edition';
    }
    final sameLanguage = variants.where(
      (other) => other.languageLabel == book.languageLabel,
    );
    // Preserve distinct source editions; never silently discard a resource.
    return sameLanguage.length > 1
        ? '${book.languageLabel} — ${book.id}'
        : book.languageLabel;
  }

  String get displayName => TafsirCatalog.familyDisplayName(id, name, variants);
}

class TafsirCatalog {
  static const _excludedSourceIds = <int>{41, 250};
  static const _excludedIds = <String>{'qul_tafsir_41', 'qul_tafsir_250'};
  static const canonicalGroupIds = <String, String>{
    'as_saadi': 'tafsir_al_saadi',
    'jalalayn': 'tafsir_al_jalalayn',
    'mukhtasar': 'tafsir_al_mukhtasar',
    'qul_tafsir_37': 'tabari',
  };

  static const _arabicFamilyNames = <String, String>{
    'muyassar': 'التفسير الميسر',
    'tafsir_al_muyassar': 'التفسير الميسر',
    'ibn_katheer': 'تفسير ابن كثير',
    'ibn_kathir': 'تفسير ابن كثير',
    'tafsir_ibn_kathir': 'تفسير ابن كثير',
    'tabari': 'تفسير الطبري',
    'tafsir_al_tabari': 'تفسير الطبري',
    'tafsir_al_saadi': 'تفسير السعدي',
    'as_saadi': 'تفسير السعدي',
    'saadi': 'تفسير السعدي',
    'jalalayn': 'تفسير الجلالين',
    'al_jalalayn': 'تفسير الجلالين',
    'tafsir_al_jalalayn': 'تفسير الجلالين',
    'mukhtasar': 'التفسير المختصر',
    'tafsir_al_mukhtasar': 'التفسير المختصر',
  };

  static String familyDisplayName(
    String id,
    String sourceName,
    Iterable<TafsirBook> variants,
  ) {
    final canonicalId = canonicalGroupIds[id] ?? id;
    final knownName = _arabicFamilyNames[id] ?? _arabicFamilyNames[canonicalId];
    if (knownName != null) return knownName;
    if (_containsArabic(sourceName)) return sourceName;
    for (final book in variants) {
      if (_containsArabic(book.name)) return book.name;
      if (_containsArabic(book.familyName)) return book.familyName;
    }
    return sourceName;
  }

  static bool _containsArabic(String value) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(value);

  static bool isValidId(String? id) =>
      id != null && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id);

  /// Blocks QUL exports known to be empty or mislabeled, and metadata explicitly
  /// marked as not successfully parsed. Old app-config entries have no audit
  /// status and remain eligible for backward compatibility.
  static bool isUsableCatalogItem(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    final sourceId = int.tryParse(item['source_id']?.toString() ?? '');
    if (!isValidId(id) ||
        _excludedIds.contains(id) ||
        (sourceId != null && _excludedSourceIds.contains(sourceId))) {
      return false;
    }
    final auditStatus = item['audit_status']?.toString().trim();
    if (auditStatus != null &&
        auditStatus.isNotEmpty &&
        auditStatus != 'parsed_valid') {
      return false;
    }
    if (item['is_builtin'] != true &&
        ((item['name']?.toString().trim().isEmpty ?? true) ||
            (item['url']?.toString().trim().isEmpty ?? true))) {
      return false;
    }
    return true;
  }

  static Map<String, dynamic> normalizeCatalogItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);
    final groupId = normalized['group_id']?.toString();
    final canonical = canonicalGroupIds[groupId];
    if (canonical != null) normalized['group_id'] = canonical;
    return normalized;
  }

  /// Identifies a second catalog ID for the same QUL source and language.
  /// This keeps existing Ibn Kathir and al-Tabari cache IDs as canonical IDs.
  static bool hasDuplicateSource(
    TafsirBook candidate,
    Iterable<TafsirBook> existingBooks,
  ) {
    final sourceId = candidate.sourceId;
    if (sourceId == null) return false;
    return existingBooks.any(
      (book) =>
          book.id != candidate.id &&
          book.sourceId == sourceId &&
          book.languageCode.toLowerCase() ==
              candidate.languageCode.toLowerCase(),
    );
  }

  /// Accept both the original flat index and explicit families with variants.
  /// Family membership is metadata-driven, never guessed from translated names.
  static List<Map<String, dynamic>> flattenItems(Iterable<dynamic> items) {
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map['variants'] is! List) {
        result.add(map);
        continue;
      }
      if (!isValidId(map['id']?.toString())) continue;
      for (final variant in map['variants'] as List) {
        if (variant is! Map) continue;
        result.add({
          'name': map['name']?.toString() ?? '',
          'author': map['author']?.toString() ?? '',
          ...Map<String, dynamic>.from(variant),
          'group_id': map['id'].toString(),
          'group_name': map['name']?.toString() ?? '',
        });
      }
    }
    return result;
  }

  static List<TafsirBookGroup> groupBooks(Iterable<TafsirBook> books) {
    final families = <String, List<TafsirBook>>{};
    for (final book in books) {
      if (!isValidId(book.id)) continue;
      final family = families.putIfAbsent(book.familyId, () => []);
      if (!family.any((other) => other.id == book.id)) family.add(book);
    }
    return List.unmodifiable([
      for (final entry in families.entries)
        TafsirBookGroup(
          id: entry.key,
          name: entry.value.first.familyName,
          variants: entry.value,
        ),
    ]);
  }
}
