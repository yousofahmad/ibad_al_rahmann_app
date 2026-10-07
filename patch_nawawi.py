with open("lib/screens/nawawi_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target1 = r'''        for \(var item in jsonData\) \{
          temp\.add\(\{
            "title": item\['title'\],
            "hadith": item\['hadith'\],
            "description": item\['description'\],
          \}\);
        \}'''

replacement1 = r'''        for (var item in jsonData) {
          temp.add({
            "title": item['title'],
            "hadith": item['hadith'],
            "description": item['description'],
            "normalizedTitle": ArabicSearchHelper.normalizeArabic(item['title'] ?? ''),
            "normalizedHadith": ArabicSearchHelper.normalizeArabic(item['hadith'] ?? ''),
          });
        }'''

content = re.sub(target1, replacement1, content)

target2 = r'''      final displayedHadiths = _searchQuery\.isEmpty
          \? baseHadiths
          : baseHadiths
              \.where\(
                \(h\) =>
                    ArabicSearchHelper\.normalizeArabic\(h\['title'\] as String\? \?\? ''\)\.contains\(ArabicSearchHelper\.normalizeArabic\(_searchQuery\)\) \|\|
                    ArabicSearchHelper\.normalizeArabic\(h\['hadith'\] as String\? \?\? ''\)\.contains\(ArabicSearchHelper\.normalizeArabic\(_searchQuery\)\),
              \)
              \.toList\(\);'''

replacement2 = r'''      final normalizedQuery = ArabicSearchHelper.normalizeArabic(_searchQuery);
      final displayedHadiths = _searchQuery.isEmpty
          ? baseHadiths
          : baseHadiths
              .where(
                (h) =>
                    (h['normalizedTitle'] as String).contains(normalizedQuery) ||
                    (h['normalizedHadith'] as String).contains(normalizedQuery),
              )
              .toList();'''

content = re.sub(target2, replacement2, content)

with open("lib/screens/nawawi_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Patched nawawi_screen.dart")
