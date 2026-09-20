import re

with open('lib/features/quran/ui/widgets/core/wbw_page_widget.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('right: isTablet ? 32 : 22,', 'right: isTablet ? 24 : 16,')

target = """                // Right side in RTL: Juz Number + Hizb badge
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'juz${juzNum.toString().padLeft(3, '0')}',
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: AppConsts.quranCommon,
                            color: headerTextColor,
                            fontSize: hizbText.isNotEmpty
                                ? (isTablet ? 24 : 18)
                                : (isTablet ? 28 : 20),
                            height: 1.0,
                          ),
                        ),"""

replacement = """                // Right side in RTL: Juz Number + Hizb badge
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
                            'juz${juzNum.toString().padLeft(3, '0')}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: AppConsts.quranCommon,
                              color: headerTextColor,
                              fontSize: hizbText.isNotEmpty
                                  ? (isTablet ? 24 : 16)
                                  : (isTablet ? 28 : 20),
                              height: 1.0,
                            ),
                          ),"""

content = content.replace(target, replacement)

# Now we need to close FittedBox
target_close = """                            ),
                          ),
                      ],
                    ),
                  ),
                ),"""

replacement_close = """                            ),
                          ),
                      ],
                    ),
                    ),
                  ),
                ),"""

content = content.replace(target_close, replacement_close)

with open('lib/features/quran/ui/widgets/core/wbw_page_widget.dart', 'w', encoding='utf-8') as f:
    f.write(content)
