import 'package:quran/quran.dart';

class SearchingSurahModel {
  final String name, place;
  final int surahNumber, firstPage, juzNumber;

  SearchingSurahModel({
    required this.name,
    required this.place,
    required this.surahNumber,
    required this.firstPage,
    required this.juzNumber,
  });

  factory SearchingSurahModel.fromMap(Map<String, dynamic> map) {
    final surahNumber = map['id'];

    return SearchingSurahModel(
      name: map['arabic'],
      place: getPlaceOfRevelation(surahNumber) == 'Makkah' ? 'مكية' : 'مدنية',
      surahNumber: surahNumber,
      firstPage: getPageNumber(surahNumber, 1),
      juzNumber: getJuzNumber(surahNumber, 1),
    );
  }
}
