import re

with open("lib/features/wird/ui/new_khatma_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Let's extract the Accountability Label block
acc_block = re.search(r'(\s*// ═══ Accountability Label ═══.*?\),\n\s*const SizedBox\(height: 20\),)', content, re.DOTALL)
if acc_block:
    content = content.replace(acc_block.group(1), "")
    
    # Where is Distribution block? Let's search for `// ═══ التوزيع والتنبيهات ═══` or `// ═══ Distribution`
    dist_block = re.search(r'(\s*// ═══.*?Distribution.*?\n.*?)(?=\s*// ═══)', content, re.DOTALL | re.IGNORECASE)
    if not dist_block:
        # maybe no "Distribution" in english. Let's look for `_reminderType`
        rem_block = re.search(r'(\s*// ═══.*?_reminderType.*?)(?=\s*// ═══)', content, re.DOTALL)
        if rem_block:
            print("Found reminder block using _reminderType")
            dist_block = rem_block
        else:
            # let's just find the `FloatingActionButton` or the end of the `Column` inside `SingleChildScrollView`
            submit_btn = re.search(r'(\s*SizedBox\(height: 80\),)', content)
            if submit_btn:
                print("Found SizedBox(height: 80), inserting Accountability block here")
                content = content.replace(submit_btn.group(1), "\n" + acc_block.group(1) + submit_btn.group(1))

    with open("lib/features/wird/ui/new_khatma_screen.dart", "w", encoding="utf-8") as out:
        out.write(content)
    print("Replaced!")
else:
    print("Not found Accountability block")
