with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

in_build = False
for line in lines:
    if 'Widget build(BuildContext context)' in line:
        in_build = True
    if in_build and 'void _showNumberInputDialog' in line:
        break
    if in_build:
        print(line.strip()[:100])
