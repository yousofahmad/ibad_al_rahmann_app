import re

with open('lib/screens/nawawi_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _getSnippet method inside _NawawiScreenState
snippet_method = '''  String _getSnippet(String text, String query) {
    if (query.isEmpty) return text.length > 50 ? text.substring(0, 50) + '...' : text;
    final qLower = query.toLowerCase();
    final tLower = text.toLowerCase();
    final idx = tLower.indexOf(qLower);
    if (idx == -1) return text.length > 50 ? text.substring(0, 50) + '...' : text;
    
    int start = (idx - 30) < 0 ? 0 : idx - 30;
    int end = (idx + query.length + 30) > text.length ? text.length : idx + query.length + 30;
    
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...' + snippet;
    if (end < text.length) snippet = snippet + '...';
    
    return snippet;
  }
'''
content = content.replace('class _NawawiScreenState extends State<NawawiScreen> {', 'class _NawawiScreenState extends State<NawawiScreen> {\n' + snippet_method)

# Add subtitle
subtitle_code = '''
                    subtitle: _searchQuery.isNotEmpty
                        ? Text(
                            _getSnippet(hadith['hadith'] ?? '', _searchQuery),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontSize: 13.sp,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          )
                        : null,
'''
content = content.replace('''
                    title: Text(
                      hadith['title'],''', subtitle_code.strip('\n') + '''
                    title: Text(
                      hadith['title'],''')

with open('lib/screens/nawawi_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
