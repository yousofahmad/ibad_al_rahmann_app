with open("lib/screens/accountability_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Change 'present' to 'ontime'
content = content.replace("'status': 'present'", "'status': 'ontime'")

with open("lib/screens/accountability_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Replaced present to ontime in accountability_screen.dart")
