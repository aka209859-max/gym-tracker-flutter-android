#!/usr/bin/env python3
import re
import sys

def fix_data_null_safety(file_path):
    """Fix .data()! patterns in a Dart file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern: final xxx = yyy.data()!;
    # Replace with null check
    pattern = r'([ \t]+)final (\w+) = (\w+)\.data\(\)!;'
    
    def replace_with_null_check(match):
        indent = match.group(1)
        var_name = match.group(2)
        doc_name = match.group(3)
        
        return f'''{indent}final {var_name} = {doc_name}.data();
{indent}if ({var_name} == null) {{
{indent}  throw Exception('データの取得に失敗しました');
{indent}}}'''
    
    content = re.sub(pattern, replace_with_null_check, content)
    
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'✅ Fixed: {file_path}')
        return True
    return False

# Files to fix
files = [
    'lib/services/friend_request_service.dart',
    'lib/services/trial_service.dart',
    'lib/screens/personal_training/pt_password_screen.dart',
    'lib/screens/po/gym_equipment_editor_screen.dart',
]

fixed_count = 0
for file_path in files:
    if fix_data_null_safety(file_path):
        fixed_count += 1

print(f'\n📊 Total: {fixed_count} files fixed')
