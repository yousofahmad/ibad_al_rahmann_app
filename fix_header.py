import re

with open('lib/features/quran/ui/widgets/core/wbw_page_widget.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix right padding to 16
content = content.replace('right: isTablet ? 32 : 22,', 'right: isTablet ? 24 : 16,')

# Wrap the Right side Row in a FittedBox to prevent ellipsis cutting off the long glyph, and use Flexible properly
# Actually, the best way to prevent the glyph from being eaten is to remove the TextOverflow.ellipsis and wrap it in a Flexible with FittedBox
# Or simply just wrap the right-side Row in a FittedBox!

replacement = '''
                // Right side in RTL: Juz Number + Hizb badge
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'juz',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: AppConsts.quranCommon,
                              color: headerTextColor,
                              fontSize: hizbText.isNotEmpty
                                  ? (isTablet ? 24 : 16)
                                  : (isTablet ? 28 : 20),
                              height: 1.0,
                            ),
                          ),
'''

content = re.sub(r'''\s*// Right side in RTL: Juz Number \+ Hizb badge\s*Flexible\(\s*child: Align\(\s*alignment: Alignment\.centerRight,\s*child: Row\(\s*mainAxisSize: MainAxisSize\.min,\s*crossAxisAlignment: CrossAxisAlignment\.center,\s*children: \[\s*Text\(\s*'juz\$\{juzNum\.toString\(\)\.padLeft\(3, '0'\)\}',\s*overflow: TextOverflow\.ellipsis,\s*textAlign: TextAlign\.right,\s*style: TextStyle\(\s*fontFamily: AppConsts\.quranCommon,\s*color: headerTextColor,\s*fontSize: hizbText\.isNotEmpty\s*\?\s*\(isTablet \?\s*24\s*:\s*18\)\s*:\s*\(isTablet \?\s*28\s*:\s*20\),\s*height: 1\.0,\s*\),\s*\),''', replacement, content)

with open('lib/features/quran/ui/widgets/core/wbw_page_widget.dart', 'w', encoding='utf-8') as f:
    f.write(content)
