import re
with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = r'Text\(\s*title,\s*style:\s*TextStyle\(\s*fontFamily:\s*AppConsts\.expoArabic,\s*fontSize:\s*16\.5\.sp,\s*fontWeight:\s*FontWeight\.bold,\s*color:\s*const Color\(0xFFD0A871\),\s*\),\s*\),'
replacement = r'''Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFFD0A871),
                            height: 1.5,
                          ),
                        ),'''

content, num = re.subn(target, replacement, content)
with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print(f"Replaced {num} occurrences!")
