with open(".ai_plans/ibad_al_rahmann_master_plan_v6.md", "r", encoding="utf-8") as f:
    lines = f.readlines()

with open("stage13_clean2.txt", "w", encoding="utf-8") as out:
    start = False
    for line in lines:
        if 'المرحلة 13' in line and '##' in line:
            start = True
        if start:
            out.write(line)
