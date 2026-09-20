with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '13' in line and 'دفعة' in line:
        for j in range(max(0, i-2), min(len(lines), i+150)):
            print(lines[j].strip())
        break
