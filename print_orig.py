with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

in_section = False
for line in lines:
    if 'Widget _buildSection' in line:
        in_section = True
    if in_section and 'Text(' in line and 'title' in line:
        print(line.strip())
        break
