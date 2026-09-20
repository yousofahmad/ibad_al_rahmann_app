import re

with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

acc_block_match = re.search(r'(\s*// ═══ Accountability Label ═══.*?\),\n\s*const SizedBox\(height: 20\),)', content, re.DOTALL)
if acc_block_match:
    acc_block = acc_block_match.group(1)
    # Remove it from its original place
    content = content.replace(acc_block, "")
    
    # Insert before ElevatedButton
    btn_match = re.search(r'(\s*const SizedBox\(height: 30\),\s*ElevatedButton)', content)
    if btn_match:
        content = content.replace(btn_match.group(1), acc_block + btn_match.group(1))
        with open("lib/features/wird/ui/new_khatma_screen.dart", "w", encoding="utf-8") as f:
            f.write(content)
        print("Moved Accountability Label to bottom!")
    else:
        print("ElevatedButton not found")
else:
    print("Accountability Label not found")
