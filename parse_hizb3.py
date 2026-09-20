with open('lib/features/quran/ui/quran_hizb_data.dart', 'r', encoding='utf-8') as f:
    lines = [f"Line {i+1}: {line.strip()}" for i, line in enumerate(f) if '546' in line]
with open('hizb_out2.txt', 'w', encoding='utf-8') as out:
    out.write('\n'.join(lines))
