#!/usr/bin/env python3
"""
Script to migrate Cafe24 API calls to Supabase Adapter calls in Dart files.
"""

import re
import sys
from pathlib import Path

def migrate_get_operation(content):
    """Migrate operation: 'get' to SupabaseAdapter.getData()"""

    # Pattern 1: GET operation with response status check
    pattern1 = r'''final (\w+) = await http\.post\(
\s+Uri\.parse\('https://autofms\.mycafe24\.com/dynamic_api\.php'\),
\s+headers: \{[^}]+\},
\s+body: json\.encode\(\{
\s+'operation': 'get',
\s+'table': '([^']+)',
\s+'where': (\[[^\]]+\]),
\s*(?:'orderBy': (\[[^\]]+\]),)?
\s*\}\),
\s*\)(?:\.timeout\([^)]+\))?;

\s*if \(\1\.statusCode == 200\) \{
\s*final (\w+) = json\.decode\(\1\.body\);
\s*(?:if \(\5\['success'\] == true && \5\['data'\]\.isNotEmpty\) \{)?'''

    def replace1(match):
        var_name = match.group(1)
        table = match.group(2)
        where = match.group(3)
        order_by = match.group(4) if match.group(4) else None
        result_var = match.group(5)

        replacement = f'''final {result_var}_data = await SupabaseAdapter.getData(
        table: '{table}',
        where: {where},'''

        if order_by:
            replacement += f'''
        orderBy: {order_by},'''

        replacement += '''
      );

      if ('''

        # Check if there was an isEmpty check
        if 'isNotEmpty' in content[match.end():match.end()+100]:
            replacement += f'''{result_var}_data.isNotEmpty) {{'''
        else:
            replacement += f'''{result_var}_data != null) {{'''

        return replacement

    content = re.sub(pattern1, replace1, content, flags=re.MULTILINE | re.DOTALL)

    # Pattern 2: Simple GET without nested if
    pattern2 = r'''final (\w+) = await http\.post\(
\s+Uri\.parse\('https://autofms\.mycafe24\.com/dynamic_api\.php'\),
\s+headers: \{[^}]+\},
\s+body: json\.encode\(\{
\s+'operation': 'get',
\s+'table': '([^']+)',
\s+'where': (\[[^\]]+\]),
\s*(?:'orderBy': (\[[^\]]+\]),)?
\s*\}\),
\s*\)(?:\.timeout\([^)]+\))?;'''

    def replace2(match):
        var_name = match.group(1)
        table = match.group(2)
        where = match.group(3)
        order_by = match.group(4) if match.group(4) else None

        replacement = f'''final {var_name}_data = await SupabaseAdapter.getData(
        table: '{table}',
        where: {where},'''

        if order_by:
            replacement += f'''
        orderBy: {order_by},'''

        replacement += '''
      );'''

        return replacement

    content = re.sub(pattern2, replace2, content, flags=re.MULTILINE | re.DOTALL)

    return content

def migrate_update_operation(content):
    """Migrate operation: 'update' to SupabaseAdapter.updateData()"""

    pattern = r'''final (\w+) = await http\.post\(
\s+Uri\.parse\('https://autofms\.mycafe24\.com/dynamic_api\.php'\),
\s+headers: \{[^}]+\},
\s+body: json\.encode\(\{
\s+'operation': 'update',
\s+'table': '([^']+)',
\s+'data': ([^,]+),
\s+'where': (\[[^\]]+\]),
\s*\}\),
\s*\)(?:\.timeout\([^)]+\))?;'''

    def replace(match):
        var_name = match.group(1)
        table = match.group(2)
        data = match.group(3).strip()
        where = match.group(4)

        return f'''final {var_name} = await SupabaseAdapter.updateData(
        table: '{table}',
        data: {data},
        where: {where},
      );'''

    return re.sub(pattern, replace, content, flags=re.MULTILINE | re.DOTALL)

def migrate_add_operation(content):
    """Migrate operation: 'add' to SupabaseAdapter.addData()"""

    pattern = r'''final (\w+) = await http\.post\(
\s+Uri\.parse\('https://autofms\.mycafe24\.com/dynamic_api\.php'\),
\s+headers: \{[^}]+\},
\s+body: json\.encode\(\{
\s+'operation': 'add',
\s+'table': '([^']+)',
\s+'data': ([^,]+),
\s*\}\),
\s*\)(?:\.timeout\([^)]+\))?;'''

    def replace(match):
        var_name = match.group(1)
        table = match.group(2)
        data = match.group(3).strip()

        return f'''final {var_name} = await SupabaseAdapter.addData(
        table: '{table}',
        data: {data},
      );'''

    return re.sub(pattern, replace, content, flags=re.MULTILINE | re.DOTALL)

def migrate_response_checks(content):
    """Migrate status code and JSON response checks"""

    # Replace statusCode checks
    content = re.sub(
        r'if \((\w+)\.statusCode != 200\) \{',
        r'if (\1[\'success\'] != true) {',
        content
    )

    content = re.sub(
        r'if \((\w+)\.statusCode == 200\) \{',
        r'if (\1[\'success\'] == true) {',
        content
    )

    # Replace json.decode checks
    content = re.sub(
        r'final (\w+) = json\.decode\((\w+)\.body\);',
        r'// Response already decoded by SupabaseAdapter',
        content
    )

    # Replace error field access
    content = re.sub(
        r"\$\{(\w+)\['error'\]",
        r"${\1['message']",
        content
    )

    content = re.sub(
        r"'error' \?\? '",
        r"'message' ?? '",
        content
    )

    return content

def add_supabase_import(content, file_path):
    """Add SupabaseAdapter import if not present"""

    if 'supabase_adapter.dart' in content:
        return content

    # Determine the relative path to services
    path_parts = Path(file_path).parts
    lib_index = path_parts.index('lib')
    depth = len(path_parts) - lib_index - 2  # -2 for lib and filename

    relative_path = '../' * depth + 'services/supabase_adapter.dart'

    # Find the last import statement
    import_pattern = r"(import [^;]+;)"
    imports = list(re.finditer(import_pattern, content))

    if imports:
        last_import = imports[-1]
        insert_pos = last_import.end()
        content = (
            content[:insert_pos] +
            f"\nimport '{relative_path}';" +
            content[insert_pos:]
        )

    return content

def migrate_file(file_path):
    """Migrate a single Dart file"""

    print(f"Migrating {file_path}...")

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Add import
    content = add_supabase_import(content, file_path)

    # Migrate operations
    content = migrate_get_operation(content)
    content = migrate_update_operation(content)
    content = migrate_add_operation(content)
    content = migrate_response_checks(content)

    # Only write if changes were made
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Migrated {file_path}")
        return True
    else:
        print(f"ℹ️  No changes needed for {file_path}")
        return False

def main():
    """Main function"""

    if len(sys.argv) < 2:
        print("Usage: python3 migrate_cafe24_to_supabase.py <file_or_directory>")
        sys.exit(1)

    target = Path(sys.argv[1])

    if target.is_file():
        files = [target]
    elif target.is_dir():
        files = list(target.rglob('*.dart'))
    else:
        print(f"Error: {target} is not a valid file or directory")
        sys.exit(1)

    # Filter out backup files
    files = [f for f in files if 'backup' not in str(f).lower()]

    migrated_count = 0
    for file_path in files:
        if migrate_file(file_path):
            migrated_count += 1

    print(f"\n✅ Migration complete! {migrated_count}/{len(files)} files migrated.")

if __name__ == '__main__':
    main()
