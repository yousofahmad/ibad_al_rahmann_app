with open('lib/features/quran/ui/quran_hizb_data.dart', 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if '546' in line or '449' in line:
            print(f"Line {i+1}: {line.strip()}")
