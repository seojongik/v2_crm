#!/bin/bash

# Script to migrate Cafe24 API calls to SupabaseAdapter in CRM Dart files
# This script handles the systematic replacement of http.post calls with SupabaseAdapter methods

set -e

CRM_LIB_DIR="/Users/seojongik/enableTech/v2_autogolf-project/crm/lib"

echo "🚀 Starting Cafe24 to Supabase migration..."
echo "📁 Working directory: $CRM_LIB_DIR"

# Find all Dart files with cafe24 URLs (excluding backups)
FILES=$(find "$CRM_LIB_DIR" -name "*.dart" -type f ! -name "*backup*" -exec grep -l "autofms.mycafe24.com" {} \;)

FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
echo "📊 Found $FILE_COUNT files to migrate"
echo ""

# Counter for processed files
PROCESSED=0

for FILE in $FILES; do
    echo "📝 Processing: $(basename $FILE)"

    # Check if supabase_adapter import already exists
    if ! grep -q "supabase_adapter.dart" "$FILE"; then
        # Calculate relative path to services directory
        FILE_DIR=$(dirname "$FILE")
        REL_PATH=$(python3 -c "import os.path; print(os.path.relpath('$CRM_LIB_DIR/services', '$FILE_DIR'))")

        # Add import after the last existing import
        # Find the line number of the last import
        LAST_IMPORT_LINE=$(grep -n "^import " "$FILE" | tail -1 | cut -d: -f1)

        if [ -n "$LAST_IMPORT_LINE" ]; then
            sed -i.bak "${LAST_IMPORT_LINE}a\\
import '${REL_PATH}/supabase_adapter.dart';
" "$FILE"
            echo "  ✅ Added SupabaseAdapter import"
        fi
    else
        echo "  ℹ️  SupabaseAdapter import already exists"
    fi

    ((PROCESSED++))
    echo ""
done

echo "✅ Migration preparation complete!"
echo "📊 Processed $PROCESSED files"
echo ""
echo "⚠️  NOTE: Due to the complexity of the code patterns, please review each file manually"
echo "   and apply the following transformations:"
echo ""
echo "   1. operation: 'get' -> SupabaseAdapter.getData()"
echo "      Remove: http.post, Uri.parse, headers, body, json.encode, .timeout()"
echo "      Replace statusCode checks with direct data checks"
echo ""
echo "   2. operation: 'update' -> SupabaseAdapter.updateData()"
echo "      Remove: http.post, Uri.parse, headers, body, json.encode, .timeout()"
echo "      Check result['success'] instead of statusCode"
echo ""
echo "   3. operation: 'add' -> SupabaseAdapter.addData()"
echo "      Remove: http.post, Uri.parse, headers, body, json.encode, .timeout()"
echo "      Check result['success'] instead of statusCode"
echo ""
echo "   4. operation: 'delete' -> SupabaseAdapter.deleteData()"
echo "      Remove: http.post, Uri.parse, headers, body, json.encode, .timeout()"
echo "      Check result['success'] instead of statusCode"
echo ""
echo "   5. Replace json.decode(response.body) with direct result access"
echo "   6. Replace 'error' with 'message' in error handling"
echo ""

# Clean up backup files
find "$CRM_LIB_DIR" -name "*.bak" -delete 2>/dev/null || true

echo "✅ Script complete!"
