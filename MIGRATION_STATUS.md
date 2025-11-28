# Cafe24 to Supabase Migration Status - CRM Project

## Overview
This document tracks the migration of all Cafe24 API calls (`https://autofms.mycafe24.com/dynamic_api.php`) to SupabaseAdapter in the CRM project.

## SupabaseAdapter Location
`/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/services/supabase_adapter.dart`

## SupabaseAdapter Methods
- `SupabaseAdapter.getData(table, fields, where, orderBy, limit, offset)` - for 'get' operations
- `SupabaseAdapter.addData(table, data)` - for 'add' operations
- `SupabaseAdapter.updateData(table, data, where)` - for 'update' operations
- `SupabaseAdapter.deleteData(table, where)` - for 'delete' operations

## Migration Pattern

### Before (Cafe24 API):
```dart
final response = await http.post(
  Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
  body: json.encode({
    'operation': 'get',
    'table': 'v2_staff_pro',
    'where': [
      {'field': 'branch_id', 'operator': '=', 'value': branchId},
    ],
    'orderBy': [
      {'field': 'pro_name', 'direction': 'ASC'}
    ],
  }),
).timeout(Duration(seconds: 15));

if (response.statusCode == 200) {
  final result = json.decode(response.body);
  if (result['success'] == true && result['data'].isNotEmpty) {
    final data = result['data'] as List;
    // Process data...
  }
}
```

### After (Supabase Adapter):
```dart
final data = await SupabaseAdapter.getData(
  table: 'v2_staff_pro',
  where: [
    {'field': 'branch_id', 'operator': '=', 'value': branchId},
  ],
  orderBy: [
    {'field': 'pro_name', 'direction': 'ASC'}
  ],
);

if (data.isNotEmpty) {
  // Process data...
}
```

### Key Changes:
1. **Import**: Add `import '../../../services/supabase_adapter.dart';` (adjust path as needed)
2. **Remove**: `http.post`, `Uri.parse`, `headers`, `body`, `json.encode`, `.timeout()`
3. **Remove**: `json.decode(response.body)` - SupabaseAdapter returns decoded data directly
4. **Replace**: `response.statusCode == 200` with direct data checks or `result['success']`
5. **Replace**: `result['error']` with `result['message']` in error handling
6. **Simplify**: No need for nested if statements checking success and data

## Files Migration Status

### ✅ COMPLETED

#### 1. tab11_lesson_hours.dart (8 URLs) - FULLY MIGRATED
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab3_pro_schedule/tab11_lesson_hours.dart`

**Changes Made**:
- ✅ Added SupabaseAdapter import
- ✅ Removed `dart:convert` and `http` imports
- ✅ Migrated `_loadProList()` - v2_staff_pro getData
- ✅ Migrated `_saveLessonHours()` - v2_weekly_schedule_pro check/update/add (3 operations)
- ✅ Migrated `_saveMonthlySchedule()` - v2_schedule_adjusted_pro check/update/add (3 operations)
- ✅ Migrated `_loadProSchedule()` - v2_weekly_schedule_pro getData
- ✅ Migrated `_loadMonthlySchedule()` - v2_schedule_adjusted_pro getData with orderBy
- ✅ Migrated `_updateDateSchedule()` - v2_schedule_adjusted_pro check/update/add (2 operations)

**Total**: 8 http.post calls → 8 SupabaseAdapter calls

---

### 🔄 IN PROGRESS

#### 2. tab2_2_pro_contract.dart (17 URLs) - PARTIALLY MIGRATED
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab4_staff_pro_register/tab2_2_pro_contract.dart`

**Changes Made**:
- ✅ Added SupabaseAdapter import
- ✅ Migrated first `_saveProSchedule()` section - v2_weekly_schedule_pro check/update/add (3 operations)

**Remaining** (14 URLs):
- ⏳ Second `_saveProSchedule()` section - v2_schedule_adjusted_pro check/update/add (3 operations) - lines ~806-920
- ⏳ `_checkDuplicateStaff()` - v2_staff_manager and v2_staff_pro getData (2 operations) - lines ~968-1000
- ⏳ `_loadContract()` - v2_staff_pro getData - line ~1106
- ⏳ `_saveContract()` - v2_staff_pro addData - line ~3630
- ⏳ `_updateContract()` - v2_staff_pro updateData - line ~3734
- ⏳ `_loadProSchedule()` - v2_weekly_schedule_pro getData - line ~3787
- ⏳ `_loadMonthlySchedule()` - v2_schedule_adjusted_pro getData - line ~3914
- ⏳ `_checkProMemberMatch()` - v2_member_pro_match check/addData (2 operations) - lines ~3960-4000
- ⏳ `_deleteContract()` - v2_staff_pro deleteData - line ~4026
- ⏳ `_deleteSchedule()` - combined delete operations - line ~4061
- ⏳ `_resignContract()` - v2_staff_pro updateData - line ~4123

---

### ⏳ PENDING

#### 3. tab2_1_manager_contract.dart (17 URLs)
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract.dart`

**Required**:
- Add SupabaseAdapter import
- Similar pattern to tab2_2_pro_contract.dart but for manager (v2_staff_manager table)
- Migrate all http.post calls following the same pattern

#### 4. tab9_manager_hours.dart (10 URLs)
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab2_staff_schedule/tab9_manager_hours.dart`

**Required**:
- Add SupabaseAdapter import
- Similar to tab11_lesson_hours.dart but for managers
- Tables: v2_weekly_schedule_manager, v2_schedule_adjusted_manager

#### 5. tab5_operating_hours.dart (9 URLs)
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm9_setting/sub_menu/tab5_operating_hours.dart`

**Required**:
- Add SupabaseAdapter import
- Likely uses v2_operating_hours or similar table
- Follow standard migration pattern

#### 6. tab11_cancellation_policy.dart (8 URLs)
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm9_setting/sub_menu/tab11_cancellation_policy.dart`

**Required**:
- Add SupabaseAdapter import
- Likely uses v2_cancellation_policy table
- Follow standard migration pattern

#### 7. tab10_discount_coupon_setting.dart (7 URLs)
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm9_setting/sub_menu/tab10_discount_coupon_setting.dart`

**Required**:
- Add SupabaseAdapter import
- Likely uses v2_discount_coupon table
- Follow standard migration pattern

#### 8. tab4_contract_setting.dart (7 URLs)
**File**: `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm9_setting/sub_menu/tab4_contract_setting.dart`

**Required**:
- Add SupabaseAdapter import
- Likely uses v2_contract_settings table
- Follow standard migration pattern

#### 9-18. Remaining Files
**Files**:
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm9_setting/sub_menu/tab4_contract_setting_program.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm7_communication/sub_menu/tab3_message_send.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab4_staff_pro_register/tab2_2_pro_contract_list.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract_list.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab2_staff_schedule/tab9_manager_total_schedule.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm5_hr/tab1_salary/tab9_manager_salary.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm2_member/tab2_statistics/pages/ts_usage_ranking_page.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm2_member/tab2_statistics/pages/lesson_usage_ranking_page.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm2_member/tab1_membership/member_page/tab8_junior.dart`
- `/Users/seojongik/enableTech/v2_autogolf-project/crm/lib/pages/crm2_member/tab1_membership/member_page/tab2_contract_program_viewer.dart`

**Required**: Add SupabaseAdapter import and migrate all http.post calls

---

## Migration Checklist

For each file:
- [ ] Add `import '../../../services/supabase_adapter.dart';` (adjust path based on file location)
- [ ] Find all `http.post` calls with `'autofms.mycafe24.com/dynamic_api.php'`
- [ ] For each call, identify the operation type ('get', 'add', 'update', 'delete')
- [ ] Replace with appropriate SupabaseAdapter method
- [ ] Remove status code checks, replace with success/data checks
- [ ] Update error handling to use 'message' instead of 'error'
- [ ] Test the changes

## Notes

1. **DO NOT modify**:
   - `api_service_backup.dart` (it's a backup file)
   - `api_service.dart` (the commented line is intentional)

2. **Error Handling**: SupabaseAdapter throws exceptions on error, so try-catch blocks should remain

3. **Response Format**: SupabaseAdapter returns:
   - `getData()`: `List<Map<String, dynamic>>`
   - `addData()`: `Map<String, dynamic>` with 'success', 'message', 'insertId', 'data'
   - `updateData()`: `Map<String, dynamic>` with 'success', 'message'
   - `deleteData()`: `Map<String, dynamic>` with 'success', 'message'

4. **Table Names**: PostgreSQL stores table/column names in lowercase, but SupabaseAdapter handles the conversion

## Progress Summary

- ✅ **Completed**: 1 file (tab11_lesson_hours.dart)
- 🔄 **In Progress**: 1 file (tab2_2_pro_contract.dart - 3/17 calls migrated)
- ⏳ **Pending**: 16 files
- 📊 **Total**: 18 files

**Estimated Total API Calls**: ~100+ calls across all files

## Next Steps

1. Complete tab2_2_pro_contract.dart (14 remaining calls)
2. Migrate tab2_1_manager_contract.dart (17 calls)
3. Migrate tab9_manager_hours.dart (10 calls)
4. Continue with remaining files in priority order
5. Test each migrated file
6. Remove unused `http` and `dart:convert` imports after migration complete
