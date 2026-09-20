import re

with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = r'''Text\(
\s*title,
\s*style: TextStyle\(
\s*fontFamily: AppConsts\.cairo,
\s*fontSize: 18\.sp,
\s*fontWeight: FontWeight\.bold,
\s*color: textColor,
\s*\),
\s*textAlign: TextAlign\.center,
\s*\)'''

replacement = r'''Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.normal,
                            color: textColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        )'''

# Let's search if the original is like that
match = re.search(r'Text\(\s*title,[\s\S]*?textAlign: TextAlign\.center,\s*\)', content)
if match:
    content = content.replace(match.group(0), replacement)
    with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced font for title")
else:
    print("Could not find Text(title...)")
