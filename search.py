import sys
with open('lib/features/wird/ui/khatma_details_view.dart', 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if 'تعديل' in line:
            print(f'Line {i+1}: {line.strip()}')
