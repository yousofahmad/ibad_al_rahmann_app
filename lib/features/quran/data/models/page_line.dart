class PageLine {
  final int pageNumber;
  final int lineNumber;
  final String lineType;
  final bool isCentered;
  final int firstWordId;
  final int lastWordId;
  final int? surahNumber;

  PageLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    required this.firstWordId,
    required this.lastWordId,
    this.surahNumber,
  });

  factory PageLine.fromJson(Map<String, dynamic> json) {
    return PageLine(
      pageNumber: int.tryParse(json['page_number'].toString()) ?? 0,
      lineNumber: int.tryParse(json['line_number'].toString()) ?? 0,
      lineType: json['line_type']?.toString() ?? 'ayah',
      isCentered: (int.tryParse(json['is_centered'].toString()) ?? 0) == 1,
      firstWordId: int.tryParse(json['first_word_id'].toString()) ?? 0,
      lastWordId: int.tryParse(json['last_word_id'].toString()) ?? 0,
      surahNumber: int.tryParse(json['surah_number']?.toString() ?? ''),
    );
  }
}
