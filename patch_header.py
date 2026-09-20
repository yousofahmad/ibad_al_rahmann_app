with open("lib/features/quran/ui/widgets/components/header_widget.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("height: 0.7", "height: 1.2")

with open("lib/features/quran/ui/widgets/components/header_widget.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Replaced height 0.7 with 1.2")
