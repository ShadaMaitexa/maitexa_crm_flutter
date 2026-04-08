import os
import re

def fix_colors(directory):
    # Regex to match .withValues(alpha: ...) or .withValues(\n alpha: ...)
    # It captures the value provided to alpha.
    pattern = re.compile(r'\.withValues\(\s*alpha:\s*([^,)]+)\s*,?\s*\)', re.MULTILINE)

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = pattern.sub(r'.withOpacity(\1)', content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f'Fixed {path}')

if __name__ == '__main__':
    fix_colors('lib')
    fix_colors('test')
