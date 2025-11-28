import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 어댑터 (CRM용)
/// 
/// 기존 dynamic_api.php와 동일한 요청/응답 형식을 유지하면서
/// 백엔드를 Supabase로 교체합니다.
/// 
/// 주요 역할:
/// 1. operation → Supabase 메서드 매핑
/// 2. where 조건 → .eq(), .gt(), .ilike() 등으로 변환
/// 3. PostgreSQL 응답 → 앱이 기대하는 형식으로 변환
class SupabaseAdapter {
  // Supabase 설정 (myxplanner와 동일한 프로젝트 사용)
  static const String supabaseUrl = 'https://yejialakeivdhwntmagf.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllamlhbGFrZWl2ZGh3bnRtYWdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5MTE0MjcsImV4cCI6MjA3OTQ4NzQyN30.a1WA6V7pD2tss1pkh1OSJcuknt6FTyeabvm9UzNjcfs';
  
  static SupabaseClient? _client;
  static bool _initialized = false;
  
  // Supabase 사용 여부 플래그 (전환 시 사용)
  static bool useSupabase = true;
  
  /// Supabase 초기화
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    _initialized = true;
    print('✅ [CRM] Supabase 초기화 완료');
  }
  
  /// Supabase 클라이언트 가져오기
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }
    return _client!;
  }
  
  /// 초기화 상태 확인
  static bool get isInitialized => _initialized;
  
  // ========== 데이터 조회 (GET) ==========
  
  // 테이블명 매핑 (legacy → v2)
  static String _mapTableName(String table) {
    const tableMapping = {
      'board': 'v2_board',
      'Board': 'v2_board',
      'staff': 'v2_staff_pro',
      'Staff': 'v2_staff_pro',
    };
    return tableMapping[table] ?? table;
  }
  
  static Future<List<Map<String, dynamic>>> getData({
    required String table,
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      // 테이블명 매핑 (legacy → v2)
      final mappedTable = _mapTableName(table);
      // PostgreSQL은 테이블/컬럼 이름을 소문자로 저장함
      final tableName = mappedTable.toLowerCase();
      
      // 1. SELECT 필드 설정 (컬럼명 소문자 변환)
      final selectFields = (fields == null || fields.isEmpty || fields.contains('*'))
          ? '*'
          : fields.map((f) => f.toLowerCase()).join(', ');
      
      // 2. 기본 쿼리 생성 (dynamic 타입으로 체이닝)
      dynamic query = client.from(tableName).select(selectFields);
      
      // 3. WHERE 조건 적용 (컬럼명 소문자 변환)
      if (where != null && where.isNotEmpty) {
        final lowerWhere = where.map((w) => <String, dynamic>{
          ...w,
          'field': (w['field'] as String?)?.toLowerCase(),
        }).toList();
        query = _applyWhereConditions(query, lowerWhere);
      }
      
      // 4. ORDER BY 적용 (컬럼명 소문자 변환)
      if (orderBy != null && orderBy.isNotEmpty) {
        for (final order in orderBy) {
          final field = (order['field'] as String?)?.toLowerCase();
          final direction = order['direction'] as String? ?? 'ASC';
          if (field != null) {
            query = query.order(field, ascending: direction.toUpperCase() == 'ASC');
          }
        }
      }
      
      // 5. LIMIT & OFFSET 적용
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 100) - 1);
      }
      
      // 6. 쿼리 실행
      final response = await query;
      
      // 7. 응답 변환 (PostgreSQL → 앱 형식)
      final List<Map<String, dynamic>> result = 
          List<Map<String, dynamic>>.from(response);
      
      return _convertResponseData(result);
      
    } catch (e) {
      print('❌ [CRM] Supabase getData 오류: $e');
      throw Exception('데이터 조회 오류: $e');
    }
  }
  
  // ========== 데이터 추가 (ADD) ==========
  
  // 테이블별 자동 증가(AUTO INCREMENT) primary key 컬럼 매핑
  static const Map<String, List<String>> _tableAutoIncrementColumns = {
    'v2_board_by_member': ['memberboard_id'],
    'v2_board_by_member_replies': ['reply_id'],
    'v2_bills': ['bill_id'],
    'v2_bill_term': ['bill_term_id'],
    'v2_bill_term_hold': ['term_hold_id'],
    'v2_bill_times': ['bill_min_id'],
    'v2_bill_games': ['bill_game_id'],
    'v2_bill_games_group': ['group_play_id'],
    'v2_members': ['member_id'],
    'v3_members': ['member_id'],
    'v2_contracts': ['contract_id'],
    'v3_contract_history': ['contract_history_id'],
    'v3_ls_countings': ['ls_counting_id'],
    'v2_discount_coupon': ['coupon_id'],
    'v2_discount_coupon_auto_triggers': ['trigger_id'],
    'v2_board': ['board_id'],
    'v2_board_comment': ['comment_id'],
    'v2_locker_status': ['locker_id'],
    'v2_locker_bill': ['locker_bill_id'],
    'v2_message': ['msg_id'],
    'v2_portone_payments': ['portone_payment_id'],
    'v2_schedule_adjusted_pro': ['scheduled_staff_id'],
    'v2_schedule_adjusted_manager': ['scheduled_staff_id'],
    'v2_staff_pro': ['pro_contract_id'],
    'v2_staff_manager': ['manager_contract_id'],
    'v2_term_member': ['term_id'],
    'v2_wol_settings': ['pc_id'],
    'v2_member_pro_match': ['member_pro_relation_id'],
  };

  static Future<Map<String, dynamic>> addData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      // 테이블명 매핑 (legacy → v2) + 소문자 변환
      final tableName = _mapTableName(table).toLowerCase();
      
      // 데이터 변환 (앱 형식 → PostgreSQL)
      final convertedData = _convertInputData(data);
      
      // 해당 테이블의 자동 증가 컬럼 목록 조회
      final autoIncrementCols = _tableAutoIncrementColumns[tableName] ?? [];
      
      // 컬럼명 소문자 변환 + 해당 테이블의 자동 증가 컬럼만 제거
      final cleanedData = <String, dynamic>{};
      for (final entry in convertedData.entries) {
        final lowerKey = entry.key.toLowerCase();
        // 해당 테이블의 자동 증가 컬럼만 제외
        if (!autoIncrementCols.contains(lowerKey)) {
          cleanedData[lowerKey] = entry.value;
        }
      }
      
      print('📝 [CRM] Supabase INSERT - 테이블: $tableName');
      
      final response = await client
          .from(tableName)
          .insert(cleanedData)
          .select()
          .single();
      
      // insertId 추출 (테이블의 primary key)
      // 주의: 순서가 중요함! 특정 테이블의 primary key를 먼저 체크
      final insertId = response['contract_history_id'] ??  // v3_contract_history
                       response['ls_counting_id'] ??       // v3_ls_countings
                       response['bill_id'] ??              // v2_bills
                       response['bill_term_id'] ??
                       response['term_hold_id'] ??
                       response['bill_min_id'] ??
                       response['bill_game_id'] ??
                       response['group_play_id'] ??
                       response['coupon_id'] ??
                       response['trigger_id'] ??
                       response['memberboard_id'] ??
                       response['reply_id'] ??
                       response['member_id'] ??            // member_id는 나중에
                       response['contract_id'] ??
                       response['board_id'] ??
                       response['comment_id'] ??
                       response['locker_id'] ??
                       response['locker_bill_id'] ??
                       response['msg_id'] ??
                       response['portone_payment_id'] ??
                       response['scheduled_staff_id'] ??
                       response['pro_contract_id'] ??
                       response['manager_contract_id'] ??
                       response['term_id'] ??
                       response['pc_id'] ??
                       response['member_pro_relation_id'] ??
                       response['id'] ??
                       response['reservation_id'] ??
                       'unknown';
      
      print('✅ [CRM] Supabase INSERT 성공 - insertId: $insertId');
      
      return {
        'success': true,
        'message': '데이터가 성공적으로 추가되었습니다.',
        'insertId': insertId,
        'data': _convertResponseRow(response),
      };
      
    } catch (e) {
      print('❌ [CRM] Supabase addData 오류: $e');
      throw Exception('데이터 추가 오류: $e');
    }
  }
  
  // ========== 데이터 업데이트 (UPDATE) ==========
  
  static Future<Map<String, dynamic>> updateData({
    required String table,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> where,
  }) async {
    try {
      // 테이블명 매핑 (legacy → v2) + 소문자 변환
      final tableName = _mapTableName(table).toLowerCase();
      
      if (where.isEmpty) {
        throw Exception('업데이트 조건이 지정되지 않았습니다.');
      }
      
      // 데이터 변환 (컬럼명 소문자 변환)
      final convertedData = _convertInputData(data);
      final lowerData = <String, dynamic>{};
      for (final entry in convertedData.entries) {
        lowerData[entry.key.toLowerCase()] = entry.value;
      }
      
      // WHERE 조건 컬럼명 소문자 변환
      final lowerWhere = where.map((w) => <String, dynamic>{
        ...w,
        'field': (w['field'] as String?)?.toLowerCase(),
      }).toList();
      
      // 기본 쿼리
      var query = client.from(tableName).update(lowerData);
      
      // WHERE 조건 적용
      query = _applyWhereConditions(query, lowerWhere);
      
      // 실행
      await query;
      
      return {
        'success': true,
        'message': '데이터가 성공적으로 업데이트되었습니다.',
      };
      
    } catch (e) {
      print('❌ [CRM] Supabase updateData 오류: $e');
      throw Exception('데이터 업데이트 오류: $e');
    }
  }
  
  // ========== 데이터 삭제 (DELETE) ==========
  
  static Future<Map<String, dynamic>> deleteData({
    required String table,
    required List<Map<String, dynamic>> where,
  }) async {
    try {
      // 테이블명 매핑 (legacy → v2) + 소문자 변환
      final tableName = _mapTableName(table).toLowerCase();
      
      if (where.isEmpty) {
        throw Exception('삭제 조건이 지정되지 않았습니다.');
      }
      
      // WHERE 조건 컬럼명 소문자 변환
      final lowerWhere = where.map((w) => <String, dynamic>{
        ...w,
        'field': (w['field'] as String?)?.toLowerCase(),
      }).toList();
      
      // 기본 쿼리
      var query = client.from(tableName).delete();
      
      // WHERE 조건 적용
      query = _applyWhereConditions(query, lowerWhere);
      
      // 실행
      await query;
      
      return {
        'success': true,
        'message': '데이터가 성공적으로 삭제되었습니다.',
      };
      
    } catch (e) {
      print('❌ [CRM] Supabase deleteData 오류: $e');
      throw Exception('데이터 삭제 오류: $e');
    }
  }
  
  // ========== WHERE 조건 변환 ==========
  
  /// PHP API의 where 조건을 Supabase 필터로 변환
  /// 
  /// 입력 형식:
  /// [{'field': 'name', 'operator': '=', 'value': '홍길동'}]
  /// 
  /// 지원 연산자:
  /// =, >, <, >=, <=, <>, LIKE, IN
  static dynamic _applyWhereConditions(
    dynamic query,
    List<Map<String, dynamic>> conditions,
  ) {
    for (final condition in conditions) {
      final field = condition['field'] as String?;
      final operator = condition['operator'] as String?;
      final value = condition['value'];
      
      if (field == null || operator == null) continue;
      
      switch (operator.toUpperCase()) {
        case '=':
          query = query.eq(field, value);
          break;
        case '>':
          query = query.gt(field, value);
          break;
        case '<':
          query = query.lt(field, value);
          break;
        case '>=':
          query = query.gte(field, value);
          break;
        case '<=':
          query = query.lte(field, value);
          break;
        case '<>':
        case '!=':
          query = query.neq(field, value);
          break;
        case 'LIKE':
          // MySQL의 LIKE '%값%' → Supabase의 ilike (대소문자 무시)
          String pattern = value.toString();
          query = query.ilike(field, pattern);
          break;
        case 'IN':
          if (value is List) {
            query = query.inFilter(field, value);
          }
          break;
        case 'IS NULL':
          query = query.isFilter(field, null);
          break;
        case 'IS NOT NULL':
          query = query.not(field, 'is', null);
          break;
        default:
          print('⚠️ [CRM] 지원하지 않는 연산자: $operator');
      }
    }
    
    return query;
  }
  
  // ========== 데이터 형식 변환 ==========
  
  /// PostgreSQL 응답 → 앱이 기대하는 형식으로 변환
  static List<Map<String, dynamic>> _convertResponseData(
    List<Map<String, dynamic>> data,
  ) {
    return data.map((row) => _convertResponseRow(row)).toList();
  }
  
  static Map<String, dynamic> _convertResponseRow(Map<String, dynamic> row) {
    final converted = <String, dynamic>{};
    
    for (final entry in row.entries) {
      // 컬럼명을 원래 패턴으로 복원 (PostgreSQL 소문자 → 원래 대소문자)
      final originalKey = _restoreColumnName(entry.key);
      converted[originalKey] = _convertValue(entry.value);
    }
    
    return converted;
  }
  
  /// PostgreSQL 소문자 컬럼명을 원래 대소문자 패턴으로 복원
  static String _restoreColumnName(String columnName) {
    String result = columnName;
    
    // 접두사 매핑 (소문자 → 대문자)
    final prefixMappings = <String, String>{
      'ls_': 'LS_',
      'fms_': 'FMS_',
      'chn_': 'CHN_',
      'wol_': 'WOL_',
    };
    
    for (final mapping in prefixMappings.entries) {
      if (result.startsWith(mapping.key)) {
        result = mapping.value + result.substring(mapping.key.length);
        break;
      }
    }
    
    // 중간 패턴 매핑
    final midPatternMappings = <String, String>{
      '_ls_': '_LS_',
      '_ts_': '_TS_',
    };
    
    for (final mapping in midPatternMappings.entries) {
      if (result.contains(mapping.key)) {
        result = result.replaceAll(mapping.key, mapping.value);
      }
    }
    
    return result;
  }
  
  static dynamic _convertValue(dynamic value) {
    if (value == null) return null;
    
    // BOOLEAN → int (MariaDB 호환)
    if (value is bool) {
      return value ? 1 : 0;
    }
    
    // DateTime → String (DATETIME 형식)
    if (value is DateTime) {
      return _formatDateTime(value);
    }
    
    // ISO 8601 문자열 → DATETIME 형식
    if (value is String && _isIsoDateTime(value)) {
      return _convertIsoToDateTime(value);
    }
    
    return value;
  }
  
  /// 앱 입력 데이터 → PostgreSQL 형식으로 변환
  static Map<String, dynamic> _convertInputData(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final value = entry.value;
      converted[entry.key] = value;
    }
    
    return converted;
  }
  
  // ========== 유틸리티 함수 ==========
  
  /// ISO 8601 형식인지 확인
  static bool _isIsoDateTime(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(value);
  }
  
  /// ISO 8601 → DATETIME 형식 (2024-01-01 14:30:00)
  static String _convertIsoToDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return _formatDateTime(dt);
    } catch (e) {
      return isoString;
    }
  }
  
  /// DateTime → "YYYY-MM-DD HH:MM:SS" 형식
  static String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

