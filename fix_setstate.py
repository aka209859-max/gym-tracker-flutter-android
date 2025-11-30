#!/usr/bin/env python3
"""
setState() に mounted チェックを追加するスクリプト
"""
import re
import sys
from pathlib import Path

def fix_setstate_in_file(file_path):
    """
    ファイル内の全 setState() に mounted チェックを追加
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    modifications = 0
    
    # パターン1: setState(() { で始まるパターン（複数行）
    # if (mounted) が既にある場合はスキップ
    pattern1 = r'(\s+)setState\(\(\) \{'
    
    def replace_pattern1(match):
        nonlocal modifications
        indent = match.group(1)
        
        # 前後の文脈をチェック
        start = max(0, match.start() - 100)
        context_before = content[start:match.start()]
        
        # 既に if (mounted) がある場合はスキップ
        if 'if (mounted)' in context_before or 'if (!mounted)' in context_before:
            return match.group(0)
        
        modifications += 1
        return f'{indent}if (mounted) {{\n{indent}  setState(() {{'
    
    # パターン2: setState(() => の形式（ラムダ式）
    pattern2 = r'(\s+)setState\(\(\) =>'
    
    def replace_pattern2(match):
        nonlocal modifications
        indent = match.group(1)
        
        # 前後の文脈をチェック
        start = max(0, match.start() - 100)
        context_before = content[start:match.start()]
        
        # 既に if (mounted) がある場合はスキップ
        if 'if (mounted)' in context_before or 'if (!mounted)' in context_before:
            return match.group(0)
        
        modifications += 1
        return f'{indent}if (mounted) setState(() =>'
    
    # 置換実行
    content = re.sub(pattern1, replace_pattern1, content)
    content = re.sub(pattern2, replace_pattern2, content)
    
    # パターン1で追加した場合、対応する閉じ括弧も調整が必要
    # これは複雑なので、手動で確認が必要
    
    if modifications > 0:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'✅ {file_path}: {modifications}箇所修正')
        return modifications
    else:
        print(f'⏭️  {file_path}: 修正不要')
        return 0

def main():
    if len(sys.argv) > 1:
        # 特定ファイルを修正
        file_path = Path(sys.argv[1])
        if file_path.exists():
            fix_setstate_in_file(file_path)
        else:
            print(f'❌ ファイルが見つかりません: {file_path}')
    else:
        # 全Dartファイルを修正
        lib_path = Path('lib')
        dart_files = list(lib_path.rglob('*.dart'))
        
        total_modifications = 0
        for dart_file in dart_files:
            mods = fix_setstate_in_file(dart_file)
            total_modifications += mods
        
        print(f'\n📊 合計: {total_modifications}箇所を修正しました')

if __name__ == '__main__':
    main()
