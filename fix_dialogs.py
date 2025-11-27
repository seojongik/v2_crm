#!/usr/bin/env python3
"""
reservation 폴더의 모든 다트 파일에서 showDialog에 useRootNavigator: false를 추가하는 스크립트
"""

import os
import re

# 수정할 폴더 경로
reservation_dir = "/Users/seojongik/enableTech/AutoGolfCRM/myxplanner_app/lib/pages/reservation"

# 이미 useRootNavigator가 있는지 확인하는 패턴
has_use_root_pattern = re.compile(r'showDialog\s*\([^)]*useRootNavigator\s*:', re.DOTALL)

# showDialog 패턴 (context: context 다음에 useRootNavigator를 추가)
# 케이스 1: showDialog(context: context, builder: ...)
pattern1 = re.compile(
    r'(showDialog\s*\(\s*\n\s*context:\s*context,)(\s*\n)',
    re.MULTILINE
)

# 케이스 2: showDialog(context: context, barrierDismissible: ..., builder: ...)
pattern2 = re.compile(
    r'(showDialog\s*\(\s*\n\s*context:\s*context,\s*\n\s*barrierDismissible:\s*[^,]+,)(\s*\n)',
    re.MULTILINE
)

def fix_file(filepath):
    """파일의 showDialog에 useRootNavigator: false를 추가"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # 이미 useRootNavigator가 있으면 건너뛰기
    if has_use_root_pattern.search(content):
        # 일부만 있을 수 있으므로, 없는 것들만 수정
        pass

    # 패턴 2 먼저 처리 (barrierDismissible이 있는 경우)
    def replace_pattern2(match):
        if 'useRootNavigator' in match.group(0):
            return match.group(0)
        return match.group(1) + '\n      useRootNavigator: false,' + match.group(2)

    content = pattern2.sub(replace_pattern2, content)

    # 패턴 1 처리 (barrierDismissible이 없는 경우)
    def replace_pattern1(match):
        # 이미 useRootNavigator가 있는지 다시 확인
        next_lines = content[match.end():match.end()+200]
        if 'useRootNavigator' in next_lines[:next_lines.find('builder')]:
            return match.group(0)
        return match.group(1) + '\n      useRootNavigator: false,' + match.group(2)

    content = pattern1.sub(replace_pattern1, content)

    # 변경사항이 있으면 파일에 쓰기
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def main():
    """모든 다트 파일 처리"""
    modified_files = []

    for root, dirs, files in os.walk(reservation_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    if fix_file(filepath):
                        rel_path = os.path.relpath(filepath, reservation_dir)
                        modified_files.append(rel_path)
                        print(f"✅ Modified: {rel_path}")
                except Exception as e:
                    print(f"❌ Error processing {file}: {e}")

    print(f"\n수정된 파일 수: {len(modified_files)}")
    if modified_files:
        print("\n수정된 파일 목록:")
        for f in modified_files:
            print(f"  - {f}")

if __name__ == '__main__':
    main()
