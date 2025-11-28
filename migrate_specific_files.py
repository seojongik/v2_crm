#!/usr/bin/env python3
"""
Migrate specific CRM files from cafe24 to Supabase
"""

import re
from pathlib import Path

def migrate_http_call(match_text, file_content, start_pos):
    """
    Migrate a single http.post call to SupabaseAdapter.
    Returns the replacement text.
    """
    # Extract the operation type
    op_match = re.search(r"'operation':\s*'(\w+)'", match_text)
    if not op_match:
        return match_text
    
    operation = op_match.group(1)
    
    # Extract table name
    table_match = re.search(r"'table':\s*'([\w_]+)'", match_text)
    if not table_match:
        return match_text
    
    table = table_match.group(1)
    
    # Extract variable name from the assignment
    var_match = re.search(r'final\s+(\w+)\s*=\s*await\s+http\.post', match_text)
    if not var_match:
        var_match = re.search(r'(\w+)\s*=\s*await\s+http\.post', match_text)
    
    var_name = var_match.group(1) if var_match else 'response'
    
    # Build the replacement based on operation type
    if operation == 'get':
        where = extract_field(match_text, 'where')
        orderBy = extract_field(match_text, 'orderBy')
        fields = extract_field(match_text, 'fields')
        limit = extract_field(match_text, 'limit')
        
        params = [f"table: '{table}'"]
        if where:
            params.append(f"where: {where}")
        if fields:
            params.append(f"fields: {fields}")
        if orderBy:
            params.append(f"orderBy: {orderBy}")
        if limit:
            params.append(f"limit: {limit}")
        
        indent = get_indent(match_text)
        params_str = f',\n{indent}  '.join(params)
        return f"{indent}final {var_name} = await SupabaseAdapter.getData(\n{indent}  {params_str},\n{indent});"
    
    elif operation == 'add':
        data = extract_field(match_text, 'data')
        if not data:
            return match_text
        
        indent = get_indent(match_text)
        return f"{indent}final {var_name} = await SupabaseAdapter.addData(\n{indent}  table: '{table}',\n{indent}  data: {data},\n{indent});"
    
    elif operation == 'update':
        data = extract_field(match_text, 'data')
        where = extract_field(match_text, 'where')
        
        if not data or not where:
            return match_text
        
        indent = get_indent(match_text)
        return f"{indent}final {var_name} = await SupabaseAdapter.updateData(\n{indent}  table: '{table}',\n{indent}  data: {data},\n{indent}  where: {where},\n{indent});"
    
    elif operation == 'delete':
        where = extract_field(match_text, 'where')
        if not where:
            return match_text
        
        indent = get_indent(match_text)
        return f"{indent}final {var_name} = await SupabaseAdapter.deleteData(\n{indent}  table: '{table}',\n{indent}  where: {where},\n{indent});"
    
    return match_text

def get_indent(text):
    """Get the indentation of the first line"""
    first_line = text.split('\n')[0]
    return re.match(r'^(\s*)', first_line).group(1)

def extract_field(text, field_name):
    """Extract a field value from the JSON-like structure"""
    # Handle arrays
    if field_name in ['where', 'orderBy', 'fields']:
        pattern = f"'{field_name}':\\s*(\\[[^\\]]*(?:\\[[^\\]]*\\][^\\]]*)*\\])"
        match = re.search(pattern, text, re.DOTALL)
        if match:
            return match.group(1).strip()
    
    # Handle objects
    elif field_name == 'data':
        pattern = f"'{field_name}':\\s*(\\{{[^}}]*(?:\\{{[^}}]*\\}}[^}}]*)*\\}})"
        match = re.search(pattern, text, re.DOTALL)
        if match:
            return match.group(1).strip()
    
    # Handle simple values
    else:
        pattern = f"'{field_name}':\\s*([^,}}\\]]+)"
        match = re.search(pattern, text)
        if match:
            return match.group(1).strip()
    
    return None

def find_http_post_blocks(content):
    """
    Find all http.post blocks in the content.
    Returns list of (start_pos, end_pos, block_text) tuples.
    """
    blocks = []
    
    # Split into lines for easier processing
    lines = content.split('\n')
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check if line contains http.post and dynamic_api.php
        if 'http.post(' in line and ('dynamic_api.php' in line or i + 1 < len(lines) and 'dynamic_api.php' in lines[i + 1]):
            # Found the start, now find the end
            block_lines = [line]
            block_start = sum(len(l) + 1 for l in lines[:i])  # +1 for newline
            
            i += 1
            depth = line.count('(') - line.count(')')
            
            while i < len(lines) and not (';' in lines[i] and depth <= 0):
                block_lines.append(lines[i])
                depth += lines[i].count('(') - lines[i].count(')')
                depth += lines[i].count('{') - lines[i].count('}')
                depth += lines[i].count('[') - lines[i].count(']')
                
                if ';' in lines[i] and depth <= 0:
                    break
                
                i += 1
            
            if i < len(lines):
                block_lines.append(lines[i])
            
            block_text = '\n'.join(block_lines)
            block_end = block_start + len(block_text)
            
            blocks.append((block_start, block_end, block_text))
        
        i += 1
    
    return blocks

def migrate_file(file_path):
    """Migrate a single file"""
    print(f"\n Processing: {file_path.name}")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Add SupabaseAdapter import if not present
    if 'supabase_adapter.dart' not in content:
        # Find the last import
        import_pattern = r"(import [^;]+;)"
        imports = list(re.finditer(import_pattern, content))
        
        if imports:
            last_import = imports[-1]
            insert_pos = last_import.end()
            content = (
                content[:insert_pos] +
                "\nimport '/services/supabase_adapter.dart';" +
                content[insert_pos:]
            )
            print("  ✅ Added SupabaseAdapter import")
    
    # Remove http import if it exists
    content = re.sub(
        r"import 'package:http/http.dart' as http;\n?",
        "",
        content
    )
    
    # Find and replace all http.post blocks
    blocks = find_http_post_blocks(content)
    
    if blocks:
        print(f"  Found {len(blocks)} http.post calls")
        
        # Replace from end to start to preserve positions
        for start, end, block_text in reversed(blocks):
            replacement = migrate_http_call(block_text, content, start)
            content = content[:start] + replacement + content[end:]
            
            if replacement != block_text:
                print(f"  ✅ Migrated http.post call")
    
    # Clean up response handling
    # Remove statusCode checks after getData (which returns data directly)
    content = re.sub(
        r'\s*if\s*\(\s*\w+\.statusCode\s*==\s*200\s*\)\s*\{\s*\n\s*final\s+result\s*=\s*json\.decode\(\w+\.body\);?\s*\n\s*if\s*\(\s*result\[.success.\]\s*==\s*true\s*(?:&&\s*result\[.data.\]\.isNotEmpty)?\s*\)\s*\{',
        '      if (data.isNotEmpty) {',
        content
    )
    
    # Remove remaining json.decode calls
    content = re.sub(
        r'final\s+(\w+)\s*=\s*json\.decode\((\w+)\.body\);',
        r'// Response already parsed by SupabaseAdapter',
        content
    )
    
    # Remove statusCode checks
    content = re.sub(
        r'if\s*\(\s*(\w+)\.statusCode\s*==\s*200\s*\)\s*\{',
        'if (true) {  // SupabaseAdapter throws on error',
        content
    )
    
    # Update error messages to use 'message' instead of 'error'
    content = re.sub(
        r"\$\{result\['error'\]",
        r"${result['message']",
        content
    )
    
    content = re.sub(
        r"result\['error'\]\s*\?\?",
        r"result['message'] ??",
        content
    )
    
    # Write the file if changed
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        # Count remaining http calls
        remaining = content.count('http.post(')
        print(f"  📊 Remaining http.post calls: {remaining}")
        return True, remaining == 0
    else:
        print("  ℹ️  No changes needed")
        return False, True

def main():
    """Main function"""
    base_path = Path("/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages")
    
    files_to_migrate = [
        base_path / "crm5_hr/tab2_staff_schedule/tab9_manager_hours.dart",
        base_path / "crm9_setting/sub_menu/tab5_operating_hours.dart",
        base_path / "crm5_hr/tab4_staff_pro_register/tab2_2_pro_contract.dart",
        base_path / "crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract.dart",
    ]
    
    print("=" * 60)
    print("CRM Cafe24 to Supabase Migration")
    print("=" * 60)
    
    migrated_count = 0
    fully_migrated = []
    partially_migrated = []
    
    for file_path in files_to_migrate:
        if file_path.exists():
            changed, complete = migrate_file(file_path)
            if changed:
                migrated_count += 1
                if complete:
                    fully_migrated.append(file_path.name)
                else:
                    partially_migrated.append(file_path.name)
        else:
            print(f"\n❌ File not found: {file_path}")
    
    print("\n" + "=" * 60)
    print("MIGRATION SUMMARY")
    print("=" * 60)
    
    if fully_migrated:
        print(f"\n✅ Fully Migrated ({len(fully_migrated)}):")
        for name in fully_migrated:
            print(f"   - {name}")
    
    if partially_migrated:
        print(f"\n⚠️  Partially Migrated (manual review needed) ({len(partially_migrated)}):")
        for name in partially_migrated:
            print(f"   - {name}")
    
    print(f"\n📊 Total: {len(fully_migrated)} complete, {len(partially_migrated)} partial")
    print("=" * 60)

if __name__ == '__main__':
    main()
