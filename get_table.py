import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    content = f.read()

# Extract the table status
match = re.search(r'\| المرحلة \| الحالة \|.*?(\n\n|$)', content, re.DOTALL)
if match:
    table = match.group(0)
    for line in table.split('\n'):
        if 'المرحلة' in line and '|' in line and '✅' not in line:
            print(line.strip())
