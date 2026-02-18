import 'package:hive/hive.dart';

part 'selected_verse_model.g.dart';

@HiveType(typeId: 0)
class VerseModel extends HiveObject {
  @HiveField(0)
  final int surahNumber;

  @HiveField(1)
  final int verseNumber;

  @HiveField(2)
  final String verse;

  @HiveField(3)
  final String fontFamily;

  @HiveField(4)
  final DateTime bookmarkedAt;

  VerseModel({
    required this.surahNumber,
    required this.verseNumber,
    required this.verse,
    required this.fontFamily,
    DateTime? bookmarkedAt,
  }) : bookmarkedAt = bookmarkedAt ?? DateTime.now();

  // Helper method to create a unique key for this verse
  String get uniqueKey => '${surahNumber}_$verseNumber';

  // Helper method to get surah name
  String get surahName => 'Surah $surahNumber';

  // Helper method to get verse reference
  String get verseReference => '$surahName, Verse $verseNumber';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerseModel &&
        other.surahNumber == surahNumber &&
        other.verseNumber == verseNumber;
  }

  @override
  int get hashCode => surahNumber.hashCode ^ verseNumber.hashCode;
}
