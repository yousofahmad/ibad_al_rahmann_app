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
      wirdIndex: json['wirdIndex'],
      startSurahName: json['startSurahName'],
      startAyah: json['startAyah'],
      endSurahName: json['endSurahName'],
      endAyah: json['endAyah'],
      startPage: json['startPage'],
      endPage: json['endPage'],
      isCompleted: json['isCompleted'] ?? false,
      isPartial: json['isPartial'] ?? false,
      startSuraNumber: json['startSuraNumber'] ?? 1,
      endSuraNumber: json['endSuraNumber'] ?? 1,
    );
  }
}
