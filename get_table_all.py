import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    content = f.read()

match = re.search(r'\| المرحلة \| الحالة \|.*?(\n\n|$)', content, re.DOTALL)
if match:
    with open("table_all.txt", "w", encoding="utf-8") as out:
        out.write(match.group(0))
