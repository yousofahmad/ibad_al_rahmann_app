import re
with open('.ai_plans/ibad_al_rahmann_master_plan_v5.md', 'r', encoding='utf-8') as f:
    text = f.read()

# find stage 11
match = re.search(r'(## المرحلة 11.*?)## المرحلة 12', text, re.DOTALL)
if match:
    print(match.group(1))
else:
    match = re.search(r'(## المرحلة 11.*)', text, re.DOTALL)
    if match:
        print(match.group(1))
