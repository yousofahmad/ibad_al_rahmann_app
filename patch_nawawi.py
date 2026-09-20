import re
with open("lib/screens/nawawi_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

if "arabic_search_helper.dart" not in content:
    content = "import 'package:ibad_al_rahmann/core/helpers/arabic_search_helper.dart';\n" + content

content = re.sub(r"\(h\['title'\] as String\? \?\? ''\)\.contains\(_searchQuery\)",
                 r"ArabicSearchHelper.normalizeArabic(h['title'] as String? ?? '').contains(ArabicSearchHelper.normalizeArabic(_searchQuery))", content)

content = re.sub(r"\(h\['hadith'\] as String\? \?\? ''\)\.contains\(_searchQuery\)",
                 r"ArabicSearchHelper.normalizeArabic(h['hadith'] as String? ?? '').contains(ArabicSearchHelper.normalizeArabic(_searchQuery))", content)


highlight_target = r'''                    Builder\(builder: \(context\) \{
                      final String textStr = widget.hadithText;
                      if \(widget.searchQuery != null && widget.searchQuery!\.isNotEmpty && textStr.contains\(widget.searchQuery!\)\) \{
                        final query = widget.searchQuery!;
                        final parts = textStr.split\(query\);
                        final spans = <TextSpan>\[\];
                        for \(int i = 0; i < parts.length; i\+\+\) \{
                          spans.add\(TextSpan\(text: parts\[i\]\)\);
                          if \(i != parts.length - 1\) \{
                            spans.add\(TextSpan\(
                              text: query,
                              style: TextStyle\(
                                backgroundColor: Colors.yellow.withOpacity\(0.4\),
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              \),
                            \)\);
                          \}
                        \}
                        return RichText\(
                          text: TextSpan\(
                            style: AppStyles.style24harmattan.copyWith\(
                              color: isDark \? Colors.white : Colors.black87,
                              height: 1.8,
                            \),
                            children: spans,
                          \),
                          textAlign: TextAlign.center,
                        \);
                      \} else \{
                        return Text\(
                          textStr,
                          style: AppStyles.style24harmattan.copyWith\(
                            color: isDark \? Colors.white : Colors.black87,
                            height: 1.8,
                          \),
                          textAlign: TextAlign.center,
                        \);
                      \}
                    \}\),'''

highlight_replacement = r'''                    Builder(builder: (context) {
                      final String textStr = widget.hadithText;
                      final baseStyle = AppStyles.style24harmattan.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.8,
                      );
                      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
                        return RichText(
                          text: TextSpan(
                            style: baseStyle,
                            children: ArabicSearchHelper.highlightMatch(
                              textStr,
                              widget.searchQuery!,
                              TextStyle(
                                backgroundColor: Colors.yellow.withOpacity(0.4),
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          textAlign: TextAlign.center,
                        );
                      } else {
                        return Text(
                          textStr,
                          style: baseStyle,
                          textAlign: TextAlign.center,
                        );
                      }
                    }),'''

content = re.sub(highlight_target, highlight_replacement, content)

with open("lib/screens/nawawi_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Patched nawawi_screen.dart")
