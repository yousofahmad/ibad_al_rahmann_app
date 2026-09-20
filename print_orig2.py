with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

in_section = False
count = 0
for line in lines:
    if 'Widget _buildSection' in line:
        in_section = True
    if in_section and 'Text(' in line:
        count += 1
        if count == 1: # Maybe the first Text is title?
            pass
    if in_section and 'title,' in line:
        print("FOUND TITLE!")
        break
