import re

with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    'child: ExpansionTile(',
    'child: ExpansionTile(\n          initiallyExpanded: true,'
)

# And also let's change the Awrad title font to Nastaliq since we missed it (it was ExpoArabic)
content = content.replace(
    'fontFamily: AppConsts.expoArabic,\n              fontSize: 18.sp,\n              fontWeight: FontWeight.bold,\n              color: const Color(0xFFD0A871),',
    'fontFamily: AppConsts.motoNastaliq,\n              fontSize: 22.sp,\n              fontWeight: FontWeight.normal,\n              color: const Color(0xFFD0A871),\n              height: 1.5,'
)

with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("Added initiallyExpanded and Nastaliq font for Awrad")
