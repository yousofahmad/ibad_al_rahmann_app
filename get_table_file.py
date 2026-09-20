import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    content = f.read()

match = re.search(r'\| المرحلة \| الحالة \|.*?(\n\n|$)', content, re.DOTALL)
if match:
    with open("table_pending.txt", "w", encoding="utf-8") as out:
        for line in match.group(0).split('\n'):
            if 'المرحلة' in line and '|' in line and '✅' not in line:
                out.write(line + '\n')
