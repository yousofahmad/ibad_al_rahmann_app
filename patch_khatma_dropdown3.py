import re

with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

if "Accountability Label" in content:
    print("It is there")
else:
    print("Oh no it is gone!")
