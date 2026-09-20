import re

with open('lib/features/wird/ui/khatma_details_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('                    },\n                } catch (_) {}', '                    },\n                  );\n                } catch (_) {}')

with open('lib/features/wird/ui/khatma_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
