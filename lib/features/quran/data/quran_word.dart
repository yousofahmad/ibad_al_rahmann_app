class QuranWord {
  final int? suraNumber;
  final int? ayahNumber;
  final int? pageNumber;
  final int? lineNumber;
  final String text;

  final int? wordId;
  final int? position;

  // Layout Properties
  final String? lineType;
  final bool? isCentered;
  final int? headerSurah;

  QuranWord({
    this.suraNumber,
    this.ayahNumber,
    this.pageNumber,
    this.lineNumber,
    required this.text,
    this.wordId,
    this.position,
    this.lineType,
    this.isCentered,
    this.headerSurah,
  });

  factory QuranWord.fromJson(Map<String, dynamic> json) {
    final int? sura = json['sura'] ?? json['sura_number'] ?? json['surah'];
    final int? ayah = json['ayah'] ?? json['ayah_number'] ?? json['aya'];
    final int? page = json['page'] ?? json['page_number'] ?? json['page_id'];
    final int? line = json['line'] ?? json['line_number'] ?? json['line_id'];

    final String textVal =
        json['text']?.toString() ??
        json['glyph']?.toString() ??
        json['word']?.toString() ??
        json['text_uthmani']?.toString() ??
        '';

    return QuranWord(
      suraNumber: sura,
      ayahNumber: ayah,
      pageNumber: page,
      lineNumber: line,
      text: textVal,
      wordId: json['id'] ?? json['word_id'],
      position: json['position'] ?? json['word_position'],
      lineType: json['lineType'] ?? json['line_type'],
      isCentered: json['isCentered'] ?? json['is_centered'] == 1,
      headerSurah: json['headerSurah'] ?? json['header_surah'],
    );
  }
}
