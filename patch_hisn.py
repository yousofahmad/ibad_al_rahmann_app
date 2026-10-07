with open("lib/screens/hisn_muslim_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re

target1 = r'''        temp\.add\(\{
          "title": key,
          "text": List<String>\.from\(value\['text'\]\),
          "footnote": List<String>\.from\(value\['footnote'\] \?\? \[\]\),
        \}\);'''

replacement1 = r'''        temp.add({
          "title": key,
          "text": List<String>.from(value['text']),
          "footnote": List<String>.from(value['footnote'] ?? []),
          "normalizedTitle": ArabicSearchHelper.normalizeArabic(key),
          "normalizedText": List<String>.from(value['text']).map((t) => ArabicSearchHelper.normalizeArabic(t)).toList(),
        });'''

content = re.sub(target1, replacement1, content)

target2 = r'''      final displayedChapters = _searchQuery\.isEmpty
          \? baseChapters
          : baseChapters
              \.where\(
                \(c\) => ArabicSearchHelper\.normalizeArabic\(c\['title'\] as String\? \?\? ''\)\.contains\(ArabicSearchHelper\.normalizeArabic\(_searchQuery\)\) \|\| \(c\['text'\] as List<String>\)\.any\(\(t\) => ArabicSearchHelper\.normalizeArabic\(t\)\.contains\(ArabicSearchHelper\.normalizeArabic\(_searchQuery\)\)\),
              \)
              \.toList\(\);'''

replacement2 = r'''      final normalizedQuery = ArabicSearchHelper.normalizeArabic(_searchQuery);
      final displayedChapters = _searchQuery.isEmpty
          ? baseChapters
          : baseChapters
              .where(
                (c) => (c['normalizedTitle'] as String).contains(normalizedQuery) || 
                       (c['normalizedText'] as List<String>).any((t) => t.contains(normalizedQuery)),
              )
              .toList();'''

content = re.sub(target2, replacement2, content)

with open("lib/screens/hisn_muslim_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Patched hisn_muslim_screen.dart")
