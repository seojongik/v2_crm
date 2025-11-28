#!/usr/bin/env python3
"""
CRM Cafe24 to Supabase Migration Script - Remaining Files
Migrates http.post calls to SupabaseAdapter in:
1. tab2_2_pro_contract.dart (14 calls)
2. tab2_1_manager_contract.dart (17 calls)
3. tab9_manager_hours.dart (12 calls)
4. tab5_operating_hours.dart (9 calls)
"""

import re
import os

def migrate_http_to_supabase(content):
    """
    Migrates http.post calls to SupabaseAdapter.
    Handles all operation types: get, add, update, delete
    """
    migrated_content = content

    # Pattern to match http.post calls with dynamic_api.php
    # This pattern captures the entire http.post block including body
    pattern = r'''(final|var|final\s+\w+|)\s*(\w*)\s*=?\s*await\s+http\.post\(
        \s*Uri\.parse\(['"](https://autofms\.mycafe24\.com)?/dynamic_api\.php['"]\),
        \s*headers:\s*\{[^}]+\},
        \s*body:\s*json\.encode\((\{[^}]*(?:\{[^}]*\}[^}]*)*\})\),?\s*
    \)(?:\.timeout\([^)]+\))?;'''

    # More flexible pattern
    def replace_http_call(match):
        full_match = match.group(0)

        # Extract operation from body
        operation_match = re.search(r"'operation':\s*'(\w+)'", full_match)
        if not operation_match:
            return full_match

        operation = operation_match.group(1)

        # Extract table
        table_match = re.search(r"'table':\s*'(\w+)'", full_match)
        if not table_match:
            return full_match

        table = table_match.group(1)

        # Extract variable name (if any)
        var_match = re.search(r'(?:final|var|final\s+\w+)\s+(\w+)\s*=', full_match)
        var_name = var_match.group(1) if var_match else 'response'

        # Build SupabaseAdapter call based on operation
        if operation == 'get':
            # Extract where, orderBy, fields, limit
            where_match = re.search(r"'where':\s*(\[[^\]]*(?:\[[^\]]*\][^\]]*)*\])", full_match)
            where_clause = where_match.group(1) if where_match else '[]'

            order_match = re.search(r"'orderBy':\s*(\[[^\]]*(?:\[[^\]]*\][^\]]*)*\])", full_match)
            order_clause = order_match.group(1) if order_match else None

            fields_match = re.search(r"'fields':\s*(\[[^\]]*\])", full_match)
            fields_clause = fields_match.group(1) if fields_match else None

            limit_match = re.search(r"'limit':\s*(\d+)", full_match)
            limit_clause = limit_match.group(1) if limit_match else None

            # Build getData call
            params = [f"table: '{table}'"]
            if where_clause and where_clause != '[]':
                params.append(f"where: {where_clause}")
            if fields_clause:
                params.append(f"fields: {fields_clause}")
            if order_clause:
                params.append(f"orderBy: {order_clause}")
            if limit_clause:
                params.append(f"limit: {limit_clause}")

            return f"final {var_name} = await SupabaseAdapter.getData(\n        {',\n        '.join(params)},\n      );"

        elif operation == 'add':
            # Extract data
            data_match = re.search(r"'data':\s*(\{[^}]*(?:\{[^}]*\}[^}]*)*\})", full_match)
            if not data_match:
                return full_match

            data_clause = data_match.group(1)

            return f"final {var_name} = await SupabaseAdapter.addData(\n        table: '{table}',\n        data: {data_clause},\n      );"

        elif operation == 'update':
            # Extract data and where
            data_match = re.search(r"'data':\s*(\{[^}]*(?:\{[^}]*\}[^}]*)*\})", full_match)
            where_match = re.search(r"'where':\s*(\[[^\]]*(?:\[[^\]]*\][^\]]*)*\])", full_match)

            if not data_match or not where_match:
                return full_match

            data_clause = data_match.group(1)
            where_clause = where_match.group(1)

            return f"final {var_name} = await SupabaseAdapter.updateData(\n        table: '{table}',\n        data: {data_clause},\n        where: {where_clause},\n      );"

        elif operation == 'delete':
            # Extract where
            where_match = re.search(r"'where':\s*(\[[^\]]*(?:\[[^\]]*\][^\]]*)*\])", full_match)
            if not where_match:
                return full_match

            where_clause = where_match.group(1)

            return f"final {var_name} = await SupabaseAdapter.deleteData(\n        table: '{table}',\n        where: {where_clause},\n      );"

        return full_match

    # Try simple line-by-line approach for better reliability
    lines = migrated_content.split('\n')
    in_http_call = False
    http_call_buffer = []
    http_call_start_idx = -1
    result_lines = []

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if this line starts an http.post call
        if 'http.post(' in line and 'dynamic_api.php' in line:
            in_http_call = True
            http_call_buffer = [line]
            http_call_start_idx = len(result_lines)
            i += 1
            continue

        if in_http_call:
            http_call_buffer.append(line)

            # Check if we've reached the end of the http call
            if line.strip().endswith(';') and ('timeout' in line or ')' in line):
                # Process the complete http call
                full_call = '\n'.join(http_call_buffer)
                migrated_call = migrate_single_http_call(full_call)

                result_lines.append(migrated_call)
                in_http_call = False
                http_call_buffer = []
                i += 1
                continue
        else:
            result_lines.append(line)

        i += 1

    return '\n'.join(result_lines)

def migrate_single_http_call(http_call):
    """Migrate a single http.post call to SupabaseAdapter"""

    # Extract operation
    operation_match = re.search(r"'operation':\s*'(\w+)'", http_call)
    if not operation_match:
        return http_call
    operation = operation_match.group(1)

    # Extract table
    table_match = re.search(r"'table':\s*'([\w_]+)'", http_call)
    if not table_match:
        return http_call
    table = table_match.group(1)

    # Extract variable name
    var_match = re.search(r'(final|var)\s+(\w+)\s*=\s*await', http_call)
    var_name = var_match.group(2) if var_match else 'response'

    if operation == 'get':
        # Extract components
        where = extract_json_value(http_call, 'where')
        orderBy = extract_json_value(http_call, 'orderBy')
        fields = extract_json_value(http_call, 'fields')
        limit = extract_json_value(http_call, 'limit')

        # Build parameters
        params = [f"table: '{table}'"]
        if where:
            params.append(f"where: {where}")
        if fields:
            params.append(f"fields: {fields}")
        if orderBy:
            params.append(f"orderBy: {orderBy}")
        if limit:
            params.append(f"limit: {limit}")

        return f"      final {var_name} = await SupabaseAdapter.getData(\n        {',\n        '.join(params)},\n      );"

    elif operation == 'add':
        data = extract_json_value(http_call, 'data')
        if not data:
            return http_call

        return f"      final {var_name} = await SupabaseAdapter.addData(\n        table: '{table}',\n        data: {data},\n      );"

    elif operation == 'update':
        data = extract_json_value(http_call, 'data')
        where = extract_json_value(http_call, 'where')

        if not data or not where:
            return http_call

        return f"      final {var_name} = await SupabaseAdapter.updateData(\n        table: '{table}',\n        data: {data},\n        where: {where},\n      );"

    elif operation == 'delete':
        where = extract_json_value(http_call, 'where')
        if not where:
            return http_call

        return f"      final {var_name} = await SupabaseAdapter.deleteData(\n        table: '{table}',\n        where: {where},\n      );"

    return http_call

def extract_json_value(text, key):
    """Extract a JSON value for a given key"""
    pattern = f"'{key}':\\s*([\\[{{][^\\]}}]*(?:[\\[{{][^\\]}}]*[\\]}}][^\\]}}]*)*[\\]}}]|\\d+)"
    match = re.search(pattern, text)
    return match.group(1) if match else None

def update_imports(content):
    """Update imports - add SupabaseAdapter, potentially remove http"""
    lines = content.split('\n')

    # Check if SupabaseAdapter import exists
    has_supabase_import = any("import '/services/supabase_adapter.dart'" in line or
                               'import "/services/supabase_adapter.dart"' in line
                               for line in lines)

    # Check if http import exists
    has_http_import = any("import 'package:http/http.dart' as http;" in line for line in lines)

    # Check if there are any remaining http.post calls
    has_http_usage = 'http.post' in content or 'http.get' in content or 'http.put' in content or 'http.delete' in content

    result_lines = []
    http_import_removed = False

    for line in lines:
        # Add SupabaseAdapter import after other service imports if not present
        if not has_supabase_import and "import '/services/" in line and '/services/supabase_adapter.dart' not in line:
            result_lines.append(line)
            result_lines.append("import '/services/supabase_adapter.dart';")
            has_supabase_import = True
        # Remove http import if no longer used
        elif "import 'package:http/http.dart' as http;" in line and not has_http_usage:
            http_import_removed = True
            continue
        else:
            result_lines.append(line)

    return '\n'.join(result_lines), http_import_removed

def process_response_handling(content):
    """Update response handling from HTTP format to SupabaseAdapter format"""

    # Pattern 1: response.statusCode == 200 checks -> remove (Supabase throws on error)
    # Pattern 2: json.decode(response.body) -> direct use (Supabase returns parsed data)
    # Pattern 3: result['success'] checks -> adapt to Supabase format

    # For GET operations: Supabase returns List<Map> directly
    # Replace: final result = json.decode(response.body); if (result['success'] == true) { final data = result['data']
    # With: final data = response (since getData returns List<Map> directly)

    content = re.sub(
        r'if\s*\(\s*(\w+)\.statusCode\s*==\s*200\s*\)\s*\{',
        r'try {',
        content
    )

    # Replace json.decode(response.body) with direct response usage for GET
    content = re.sub(
        r'final\s+result\s*=\s*json\.decode\((\w+)\.body\);',
        r'// Using SupabaseAdapter - response is already parsed',
        content
    )

    # Replace result['success'] checks for getData (which returns List directly)
    content = re.sub(
        r"if\s*\(\s*result\['success'\]\s*==\s*true\s*\)\s*\{",
        r'// SupabaseAdapter getData returns List<Map> directly',
        content
    )

    # For ADD operations: {success: true, insertId: X, data: {...}}
    # For UPDATE/DELETE: {success: true, message: '...'}

    return content

def migrate_file(file_path):
    """Migrate a single file"""
    print(f"\nProcessing: {file_path}")

    if not os.path.exists(file_path):
        print(f"  ❌ File not found: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        original_content = f.read()

    # Count http.post calls before migration
    http_count_before = original_content.count('http.post(')

    # Perform migration
    migrated_content = migrate_http_to_supabase(original_content)

    # Update imports
    migrated_content, http_removed = update_imports(migrated_content)

    # Count http.post calls after migration
    http_count_after = migrated_content.count('http.post(')

    # Write migrated content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(migrated_content)

    migrated_count = http_count_before - http_count_after
    print(f"  ✅ Migrated {migrated_count} http.post calls")
    print(f"  📊 Remaining: {http_count_after} http.post calls")

    if http_removed:
        print(f"  🗑️  Removed unused http import")

    return http_count_after == 0

def main():
    """Main migration function"""
    base_path = "/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages"

    files_to_migrate = [
        {
            "path": f"{base_path}/crm5_hr/tab4_staff_pro_register/tab2_2_pro_contract.dart",
            "name": "tab2_2_pro_contract.dart",
            "expected_calls": 14
        },
        {
            "path": f"{base_path}/crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract.dart",
            "name": "tab2_1_manager_contract.dart",
            "expected_calls": 17
        },
        {
            "path": f"{base_path}/crm5_hr/tab2_staff_schedule/tab9_manager_hours.dart",
            "name": "tab9_manager_hours.dart",
            "expected_calls": 12
        },
        {
            "path": f"{base_path}/crm9_setting/sub_menu/tab5_operating_hours.dart",
            "name": "tab5_operating_hours.dart",
            "expected_calls": 9
        },
    ]

    print("=" * 60)
    print("CRM Cafe24 to Supabase Migration - Remaining Files")
    print("=" * 60)

    fully_migrated = []
    partially_migrated = []
    failed = []

    for file_info in files_to_migrate:
        try:
            is_complete = migrate_file(file_info["path"])
            if is_complete:
                fully_migrated.append(file_info["name"])
            else:
                partially_migrated.append(file_info["name"])
        except Exception as e:
            print(f"  ❌ Error: {e}")
            failed.append(file_info["name"])

    # Print summary
    print("\n" + "=" * 60)
    print("MIGRATION SUMMARY")
    print("=" * 60)

    if fully_migrated:
        print(f"\n✅ Fully Migrated ({len(fully_migrated)}):")
        for name in fully_migrated:
            print(f"   - {name}")

    if partially_migrated:
        print(f"\n⚠️  Partially Migrated ({len(partially_migrated)}):")
        for name in partially_migrated:
            print(f"   - {name}")

    if failed:
        print(f"\n❌ Failed ({len(failed)}):")
        for name in failed:
            print(f"   - {name}")

    print("\n" + "=" * 60)
    print(f"Total: {len(fully_migrated)} fully migrated, {len(partially_migrated)} partially migrated, {len(failed)} failed")
    print("=" * 60)

if __name__ == "__main__":
    main()
