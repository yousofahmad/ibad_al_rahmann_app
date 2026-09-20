import re

with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Let's extract the Accountability Label block
acc_block = re.search(r'(\s*// ═══ Accountability Label ═══.*?\),\n\s*const SizedBox\(height: 20\),)', content, re.DOTALL)
if acc_block:
    print("Found Accountability block")
    content = content.replace(acc_block.group(1), "")
    
    # Let's find where to insert it. Let's insert it right before `// ═══ Save Button ═══`
    save_btn = re.search(r'(\s*// ═══ Save Button ═══)', content)
    if save_btn:
        print("Found Save button")
        # Ensure that if it is per prayer, we ONLY show the fixed string, and if not, we show the dropdown
        # Also in `onChanged`, we ensure that the value is tracked. But wait, if it's forced, it shouldn't even be a dropdown, but the instructions said: "يقتصر على بند موحد واحد باسم الختمة، مفيش اختيار من بنود موجودة خالص". A dropdown with 1 item does exactly this. Wait, if it has 1 item, can I change it? No, if there is only 1 item, the dropdown is functionally read-only.
        # But wait, if the user switches to 'per prayer', `_selectedAccountabilityLabel` might be something else! We should force it to '+ بند جديد بنفس اسم الختمة'.
        
        content = content.replace(save_btn.group(1), acc_block.group(1) + save_btn.group(1))
        with open("lib/features/wird/ui/new_khatma_screen.dart", "w", encoding="utf-8") as out:
            out.write(content)
        print("Replaced!")
else:
    print("Not found Accountability block")
