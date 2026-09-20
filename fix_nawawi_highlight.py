import re

with open('lib/screens/nawawi_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
                  Builder(builder: (context) {
                    final String textStr = widget.hadithText;
                    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty && textStr.contains(widget.searchQuery!)) {
                      final query = widget.searchQuery!;
                      final parts = textStr.split(query);
                      final spans = <TextSpan>[];
                      for (int i = 0; i < parts.length; i++) {
                        spans.add(TextSpan(text: parts[i]));
                        if (i != parts.length - 1) {
                          spans.add(TextSpan(
                            text: query,
                            style: TextStyle(
                              backgroundColor: Colors.yellow.withOpacity(0.4),
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ));
                        }
                      }
                      return RichText(
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: AppConsts.amiri,
                            fontSize: 20.sp,
                            height: 1.8,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          children: spans,
                        ),
                      );
                    }
                    return Text(
                      textStr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppConsts.amiri,
                        fontSize: 20.sp,
                        height: 1.8,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }),
'''

content = re.sub(r'Text\(\s*widget\.hadithText,\s*textAlign: TextAlign\.center,\s*style: TextStyle\(\s*fontFamily: AppConsts\.amiri,\s*fontSize: 20\.sp,\s*height: 1\.8,\s*color: textColor,\s*fontWeight: FontWeight\.w500,\s*\),\s*\),', replacement.strip(), content)

with open('lib/screens/nawawi_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
