import subprocess

out = subprocess.check_output(['git', 'show', 'HEAD:scenes/chapters/main/starting_forest.tscn'], text=True, encoding='utf-8')
lines = out.splitlines()
in_foliage = False
for idx, line in enumerate(lines, 1):
    if '[node name="Foliage"' in line:
        in_foliage = True
    elif in_foliage and line.startswith('[node '):
        if 'parent="Foliage"' not in line:
            break
        print(f"{idx}: {line}")
