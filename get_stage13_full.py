import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    content = f.read()

lines = content.split('\n')
start = -1
for i, line in enumerate(lines):
    if '## المرحلة 13' in line:
        start = i
        break

if start != -1:
    with open("stage13_full.txt", "w", encoding="utf-8") as out:
        for line in lines[start:]:
            out.write(line + '\n')
            if '## ✅' in line:
                break
