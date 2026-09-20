with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = '''Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 16.5.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD0A871),
                          ),
                        ),'''

replacement = '''Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppConsts.motoNastaliq,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFFD0A871),
                            height: 1.5,
                          ),
                        ),'''

if target in content:
    content = content.replace(target, replacement)
    with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced!")
else:
    print("Target not found!")
