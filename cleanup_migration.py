#!/usr/bin/env python3
"""
Cleanup script to fix remaining issues from migration
"""

import re
from pathlib import Path

def cleanup_file(file_path):
    """Cleanup a migrated file"""
    print(f"\n  Processing: {file_path.name}")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Fix 1: Remove duplicated .timeout() calls
    content = re.sub(
        r'\)\.timeout\(Duration\(seconds: \d+\)\);\s*\)\.timeout\(Duration\(seconds: \d+\)\);',
        ');',
        content
    )
    
    # Fix 2: Remove http.post calls that were partially migrated
    # Pattern: lines that have http.post with dynamic_api.php
    lines = content.split('\n')
    cleaned_lines = []
    skip_until_semicolon = False
    
    for i, line in enumerate(lines):
        # Check if this is an incomplete http.post line
        if 'http.post(' in line and 'dynamic_api.php' in line and 'await' in line:
            skip_until_semicolon = True
            continue
        
        # Continue skip mode until we find a semicolon
        if skip_until_semicolon:
            if ';' in line:
                skip_until_semicolon = False
            continue
        
        cleaned_lines.append(line)
    
    content = '\n'.join(cleaned_lines)
    
    # Fix 3: Clean up malformed if statements
    content = re.sub(
        r'200\)\s*\{\s*//\s*Response already parsed',
        'if (checkResponse.isNotEmpty) {',
        content
    )
    
    content = re.sub(
        r'\}\s*\)\.timeout.*?\{',
        '{',
        content
    )
    
    # Fix 4: Fix getData response handling
    # Change: final checkResponse = await SupabaseAdapter.getData(...);200) {
    # To: final checkResponse = await SupabaseAdapter.getData(...);
    #     if (checkResponse.isNotEmpty) {
    content = re.sub(
        r'(final\s+\w+\s*=\s*await\s+SupabaseAdapter\.getData\([^;]+\);)\s*\d+\)\s*\{',
        r'\1\n      if (checkResponse.isNotEmpty) {',
        content,
        flags=re.DOTALL
    )
    
    # Fix 5: Remove references to result['success'] after getData
    # getData returns List<Map> directly, not {success: true, data: [...]}
    content = re.sub(
        r"checkResult\['success'\]\s*==\s*true\s*&&\s*checkResult\['data'\]\.isNotEmpty",
        "checkResponse.isNotEmpty",
        content
    )
    
    content = re.sub(
        r"result\['success'\]\s*==\s*true",
        "data.isNotEmpty",
        content
    )
    
    # Fix 6: Change result['data'] to direct data use after getData
    content = re.sub(
        r"final\s+scheduleData\s*=\s*result\['data'\]\s*as\s*List;",
        "final scheduleData = response as List;",
        content
    )
    
    # Fix 7: Fix variable naming - if we used 'data' from getData, 
    # references to 'result' should be 'data'
    # But this is context-sensitive, so we'll be careful
    
    # Fix 8: Remove leftover json.encode blocks that still reference http
    content = re.sub(
        r'body:\s*json\.encode\(\{[^}]*\}\),\s*\)',
        '',
        content
    )
    
    # Fix 9: Remove orphaned headers blocks
    content = re.sub(
        r"headers:\s*\{\s*'Content-Type':\s*'application/json',\s*'Accept':\s*'application/json',\s*\},",
        '',
        content
    )
    
    # Fix 10: Clean up double braces/parens
    content = re.sub(r'\)\);', ');', content)
    content = re.sub(r'\{\{', '{', content)
    content = re.sub(r'\}\}', '}', content)
    
    # Fix 11: Remove Uri.parse lines
    content = re.sub(
        r"Uri\.parse\('.*?dynamic_api\.php'\),",
        '',
        content
    )
    
    # Fix 12: Clean up malformed print statements
    content = re.sub(
        r'답:\s*\$\{checkResponse\.statusCode\}',
        '',
        content
    )
    
    content = re.sub(
        r'k\s+추가\s+응답\s+상태:\s*\$\{insertResponse\.statusCode\}',
        '',
        content
    )
    
    # Fix 13: Remove references to .statusCode (SupabaseAdapter doesn't return HTTP responses)
    content = re.sub(
        r'print\([^)]*\.statusCode[^)]*\);',
        '',
        content
    )
    
    content = re.sub(
        r'print\([^)]*\.body[^)]*\);',
        '',
        content
    )
    
    # Fix 14: Remove response status checks after SupabaseAdapter calls
    content = re.sub(
        r'if\s*\(\s*\w+Response\.statusCode\s*!=\s*200\)\s*\{[^}]+\}',
        '',
        content
    )
    
    # Write if changed
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"    ✅ Cleaned up file")
        return True
    else:
        print(f"    ℹ️  No cleanup needed")
        return False

def main():
    """Main function"""
    base_path = Path("/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages")
    
    files_to_cleanup = [
        base_path / "crm5_hr/tab2_staff_schedule/tab9_manager_hours.dart",
        base_path / "crm9_setting/sub_menu/tab5_operating_hours.dart",
        base_path / "crm5_hr/tab4_staff_pro_register/tab2_2_pro_contract.dart",
        base_path / "crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract.dart",
    ]
    
    print("=" * 60)
    print("Cleanup Migration Script")
    print("=" * 60)
    
    cleaned_count = 0
    for file_path in files_to_cleanup:
        if file_path.exists():
            if cleanup_file(file_path):
                cleaned_count += 1
        else:
            print(f"\n  ❌ File not found: {file_path}")
    
    print(f"\n✅ Cleaned {cleaned_count} files")
    print("=" * 60)

if __name__ == '__main__':
    main()
