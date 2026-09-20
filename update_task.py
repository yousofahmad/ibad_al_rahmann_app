import re

with open('C:\\Users\\youse\\.gemini\\antigravity\\brain\\e3703144-1fb4-4673-ba6d-b4911b095dba\\task.md', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('- [ ] Revert `EasyPageScrollPhysics`', '- [x] Revert `EasyPageScrollPhysics`')
content = content.replace('- [ ] Fix Juz number alignment in header', '- [x] Fix Juz number alignment in header')
content = content.replace('- [ ] Move "Quran Readers" to Mini Mushaf Menu and fix theme/click', '- [x] Move "Quran Readers" to Mini Mushaf Menu and fix theme/click')
content = content.replace('- [ ] Fix Long-Press Selection Player', '- [x] Fix Long-Press Selection Player')
content = content.replace('- [ ] Show content snippet in 40 Nawawi search results', '- [x] Show content snippet in 40 Nawawi search results')
content = content.replace('- [ ] Force Arabic locale on numbers', '- [x] Force Arabic locale on numbers')
content = content.replace('- [ ] Fix Native Hijri Widget update', '- [x] Fix Native Hijri Widget update')
content = content.replace('- [ ] Fix Salawat screen-on receiver', '- [x] Fix Salawat screen-on receiver')

with open('C:\\Users\\youse\\.gemini\\antigravity\\brain\\e3703144-1fb4-4673-ba6d-b4911b095dba\\task.md', 'w', encoding='utf-8') as f:
    f.write(content)
