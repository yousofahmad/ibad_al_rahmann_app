with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()
import re
build_match = re.search(r'Widget build.*?Scaffold\((.*?)\);', content, re.DOTALL)
if build_match:
    print(build_match.group(1)[-500:])
