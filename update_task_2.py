import re

with open('C:\\Users\\youse\\.gemini\\antigravity\\brain\\e3703144-1fb4-4673-ba6d-b4911b095dba\\task.md', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('- [ ] Accountability & Stats', '- [x] Accountability & Stats')
content = content.replace('- [ ] Fix question marks and font', '- [x] Fix question marks and font')
content = content.replace('- [ ] Make Wirds section open', '- [x] Make Wirds section open')
content = content.replace('- [ ] Ensure Azkar completion updates stats automatically', '- [x] Ensure Azkar completion updates stats automatically')
content = content.replace('- [ ] Ensure Prayer Focus completion updates stats automatically', '- [x] Ensure Prayer Focus completion updates stats automatically')
content = content.replace('- [ ] Khatma UI', '- [x] Khatma UI')
content = content.replace('- [ ] Restrict accountability dropdown', '- [x] Restrict accountability dropdown')
content = content.replace('- [ ] Add "Edit Notification Time"', '- [x] Add "Edit Notification Time"')

with open('C:\\Users\\youse\\.gemini\\antigravity\\brain\\e3703144-1fb4-4673-ba6d-b4911b095dba\\task.md', 'w', encoding='utf-8') as f:
    f.write(content)
