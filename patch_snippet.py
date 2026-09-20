import re
with open("lib/screens/nawawi_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = r'''  String _getSnippet\(String text, String query\) \{
    if \(query.isEmpty\) return text.length > 50 \? text.substring\(0, 50\) \+ '\.\.\.' : text;
    final qLower = query.toLowerCase\(\);
    final tLower = text.toLowerCase\(\);
    final idx = tLower.indexOf\(qLower\);
    if \(idx == -1\) return text.length > 50 \? text.substring\(0, 50\) \+ '\.\.\.' : text;

    int start = \(idx - 30\) < 0 \? 0 : idx - 30;
    int end = \(idx \+ query.length \+ 30\) > text.length \? text.length : idx \+ query.length \+ 30;

    String snippet = text.substring\(start, end\);
    if \(start > 0\) snippet = '\.\.\.' \+ snippet;
    if \(end < text.length\) snippet = snippet \+ '\.\.\.';

    return snippet;
  \}'''

replacement = r'''  String _getSnippet(String text, String query) {
    if (query.isEmpty) return text.length > 50 ? text.substring(0, 50) + '...' : text;
    
    final normalizedText = ArabicSearchHelper.normalizeArabic(text);
    final normalizedQuery = ArabicSearchHelper.normalizeArabic(query);
    final idx = normalizedText.indexOf(normalizedQuery);
    
    if (idx == -1) return text.length > 50 ? text.substring(0, 50) + '...' : text;

    // Map the index back to the original text approximately
    int mappingIdx = 0;
    int originalIdx = 0;
    for (int i = 0; i < text.length; i++) {
      if (!RegExp(r'[\u064B-\u065F\u0670]').hasMatch(text[i])) {
        if (mappingIdx == idx) {
          originalIdx = i;
          break;
        }
        mappingIdx++;
      }
    }

    int start = (originalIdx - 30) < 0 ? 0 : originalIdx - 30;
    int end = (originalIdx + query.length + 30) > text.length ? text.length : originalIdx + query.length + 30;

    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...' + snippet;
    if (end < text.length) snippet = snippet + '...';

    return snippet;
  }'''

content = re.sub(target, replacement, content)

with open("lib/screens/nawawi_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Patched _getSnippet in nawawi_screen")

# Check if _getSnippet exists in hisn_muslim_screen
with open("lib/screens/hisn_muslim_screen.dart", "r", encoding="utf-8") as f:
    hisn_content = f.read()

if "_getSnippet" in hisn_content:
    hisn_content = re.sub(target, replacement, hisn_content)
    with open("lib/screens/hisn_muslim_screen.dart", "w", encoding="utf-8") as f:
        f.write(hisn_content)
    print("Patched _getSnippet in hisn_muslim_screen")
