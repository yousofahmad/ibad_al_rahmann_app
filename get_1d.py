import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v5.md", "r", encoding="utf-8") as f:
    content = f.read()

match = re.search(r'(## 1د.*?)(?=##)', content, re.DOTALL)
if match:
    print(match.group(1))
else:
    match = re.search(r'(1د.*)', content)
    if match:
        print(match.group(1))
