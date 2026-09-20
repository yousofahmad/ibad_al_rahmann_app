import re
with open('.ai_plans/ibad_al_rahmann_master_plan_v5.md', 'r', encoding='utf-8') as f:
    text = f.read()

match = re.search(r'(## المرحلة 11.*)', text, re.DOTALL)
if match:
    with open('stage11_12.txt', 'w', encoding='utf-8') as out:
        out.write(match.group(1))
