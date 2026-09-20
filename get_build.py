with open("lib/features/wird/ui/khatma_details_view.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'class _ExportWirdRendererState' in line:
        start = i
        break
for i in range(start, len(lines)):
    print(lines[i].rstrip())
