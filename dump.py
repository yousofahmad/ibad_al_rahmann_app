import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\more_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('class SalawatReminderDialog')
end = content.find('// end SalawatReminderDialog')
if end == -1:
    # Just print the next 500 lines to see where it ends
    print(content[start:start+4000])
else:
    print(content[start:end])