class WirdModel {
  final int wirdIndex;
  final String startSurahName;
  final int startAyah;
  final String endSurahName;
  final int endAyah;
  final int startPage;
  final int endPage;
  final bool isCompleted;
  final bool isPartial;
  final int startSuraNumber;
  final int endSuraNumber;

  WirdModel({
    required this.wirdIndex,
    required this.startSurahName,
    required this.startAyah,
    required this.endSurahName,
    required this.endAyah,
    required this.startPage,
    required this.endPage,
    this.isCompleted = false,
    this.isPartial = false,
    required this.startSuraNumber,
    required this.endSuraNumber,
  });

  WirdModel copyWith({
    int? wirdIndex,
    String? startSurahName,
    int? startAyah,
    String? endSurahName,
    int? endAyah,
    int? startPage,
    int? endPage,
    bool? isCompleted,
    bool? isPartial,
    int? startSuraNumber,
    int? endSuraNumber,
  }) {
    return WirdModel(
      wirdIndex: wirdIndex ?? this.wirdIndex,
      startSurahName: startSurahName ?? this.startSurahName,
      startAyah: startAyah ?? this.startAyah,
      endSurahName: endSurahName ?? this.endSurahName,
      endAyah: endAyah ?? this.endAyah,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      isCompleted: isCompleted ?? this.isCompleted,
      isPartial: isPartial ?? this.isPartial,
      startSuraNumber: startSuraNumber ?? this.startSuraNumber,
      endSuraNumber: endSuraNumber ?? this.endSuraNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wirdIndex': wirdIndex,
      'startSurahName': startSurahName,
      'startAyah': startAyah,
      'endSurahName': endSurahName,
      'endAyah': endAyah,
      'startPage': startPage,
      'endPage': endPage,
      'isCompleted': isCompleted,
      'isPartial': isPartial,
      'startSuraNumber': startSuraNumber,
      'endSuraNumber': endSuraNumber,
    };
  }

  factory WirdModel.fromJson(Map<String, dynamic> json) {
    return WirdModel(
      wirdIndex: json['wirdIndex'] as int? ?? 0,
      startSurahName: json['startSurahName'] as String? ?? '',
      startAyah: json['startAyah'] as int? ?? 1,
      endSurahName: json['endSurahName'] as String? ?? '',
      endAyah: json['endAyah'] as int? ?? 1,
      startPage: json['startPage'] as int? ?? 1,
      endPage: json['endPage'] as int? ?? 1,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isPartial: json['isPartial'] as bool? ?? false,
      startSuraNumber: json['startSuraNumber'] as int? ?? 1,
      endSuraNumber: json['endSuraNumber'] as int? ?? 1,
    );
  }
}
