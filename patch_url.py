import re

with open("lib/services/hijri_source_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("http://di107.dar-alifta.org", "https://di107.dar-alifta.org")

with open("lib/services/hijri_source_service.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("URL changed to HTTPS")
