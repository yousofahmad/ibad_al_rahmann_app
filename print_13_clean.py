with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    lines = f.readlines()

with open("stage13_clean.txt", "w", encoding="utf-8") as out:
    for i, line in enumerate(lines):
        if '13' in line and 'دفعة' in line:
            for j in range(max(0, i-2), min(len(lines), i+150)):
                out.write(lines[j])
            break
