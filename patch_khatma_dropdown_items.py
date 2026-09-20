with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    'items: _accountabilityLabels.map((label) {',
    'items: (_isPerPrayer ? [\'+ بند جديد بنفس اسم الختمة\'] : _accountabilityLabels).map((label) {'
)

with open("lib/features/wird/ui/new_khatma_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
