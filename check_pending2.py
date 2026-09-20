import re

with open(".ai_plans/ibad_al_rahmann_master_plan_v5.md", "r", encoding="utf-8") as f:
    lines = f.readlines()

with open("pending.txt", "w", encoding="utf-8") as out:
    for line in lines:
        if "المرحلة" in line and "|" in line and "✅" not in line:
            out.write(line)
