import 'test_extractor.dart';

void main() {
  String sample = "بسم الله {1} الحمد لله {2} الرحمن الرحيم {3}";
  print(TafsirExtractor.extractAyah(sample, 2)); // Should be "الحمد لله {2}"
  print(TafsirExtractor.extractAyah(sample, 3)); // Should be "الرحمن الرحيم {3}"
  print(TafsirExtractor.extractAyah(sample, 1)); // Should be "بسم الله {1}"
}
