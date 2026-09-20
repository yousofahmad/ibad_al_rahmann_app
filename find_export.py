import glob

for f in glob.glob('lib/**/*.dart', recursive=True):
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
        if '_ExportWirdRenderer' in content or 'ExportWirdRenderer' in content:
            print(f)
