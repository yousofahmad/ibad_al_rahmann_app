import os
import subprocess

def run_cmd(cmd):
    return subprocess.check_output(cmd, shell=True, text=True, errors='replace')

diff_output = run_cmd('git diff HEAD')
files_with_diffs = []
current_file = None

for line in diff_output.split('\n'):
    if line.startswith('diff --git'):
        parts = line.split(' ')
        if len(parts) >= 3:
            current_file = parts[-1].strip()[2:] # remove b/
            files_with_diffs.append(current_file)

corrupted_files = []
for file in files_with_diffs:
    if file.startswith('lib/'):
        try:
            with open(file, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
                if '????' in content:
                    corrupted_files.append(file)
        except:
            pass

print('Corrupted files:', len(corrupted_files))
for f in corrupted_files:
    print(f)
