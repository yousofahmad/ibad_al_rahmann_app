import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v5.md", "r", encoding="utf-8") as f:
    content = f.read()

match = re.search(r'(## المرحلة 1.*?)(?=## المرحلة 2)', content, re.DOTALL)
if match:
    with open("stage1.txt", "w", encoding="utf-8") as f:
        f.write(match.group(1))
    print("saved")
