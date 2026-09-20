import re

with open('lib/screens/hisn_muslim_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace Text(widget.texts[index]) with a highlighted TextSpan
replacement = '''
          final String textStr = widget.texts[index];
          Widget textWidget;
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
                    backgroundColor: Colors.yellow.withOpacity(0.5),
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ));
              }
            }
            textWidget = RichText(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: AppConsts.hafs,
                  fontSize: 20.sp,
                  color: textColor,
                  height: 1.8.h,
                ),
                children: spans,
              ),
            );
          } else {
            textWidget = Text(
              textStr,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppConsts.hafs,
                fontSize: 20.sp,
                color: textColor,
                height: 1.8.h,
              ),
            );
          }
'''

content = re.sub(r'Text\(\s*widget\.texts\[index\],\s*textAlign: TextAlign\.center,\s*textDirection: TextDirection\.rtl,\s*style: TextStyle\(\s*fontFamily: AppConsts\.hafs,\s*fontSize: 20\.sp,\s*color: textColor,\s*height: 1\.8\.h,\s*\),\s*\)', replacement.strip(), content)

with open('lib/screens/hisn_muslim_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
