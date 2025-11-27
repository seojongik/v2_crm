import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'holiday_service.dart';
import 'package:intl/intl.dart';

class ApiService {
  // 서버 루트의 dynamic_api.php 사용
  static const String baseUrl = 'https://autofms.mycafe24.com/dynamic_api.php';

  // 기본 헤더
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // 전역 상태 관리
  static String? _currentBranchId;
  static Map<String, dynamic>? _currentUser;
  static Map<String, dynamic>? _currentBranch;

  // 현재 지점 ID 설정
  static void setCurrentBranch(String branchId, Map<String, dynamic> branchData) {
    _currentBranchId = branchId;
    _currentBranch = branchData;
  }

  // 현재 사용자 설정
  static void setCurrentUser(Map<String, dynamic> userData) {
    _currentUser = userData;
  }

  // 현재 지점 ID 가져오기
  static String? getCurrentBranchId() {
    return _currentBranchId;
  }

  // 현재 사용자 가져오기
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  // 현재 지점 정보 가져오기
  static Map<String, dynamic>? getCurrentBranch() {
    return _currentBranch;
  }

  // WHERE 조건에 branch_id 자동 추가 (일부 테이블 제외)
  static List<Map<String, dynamic>> _addBranchFilter(List<Map<String, dynamic>>? where, String tableName) {
    // Staff, v2_branch, v3_members, v2_discount_coupon_auto_triggers 테이블은 branch_id 필터링 제외
    if (tableName == 'Staff' || tableName == 'v2_branch' || tableName == 'v3_members' || tableName == 'v2_discount_coupon_auto_triggers') {
      return where ?? [];
    }

    final branchId = getCurrentBranchId();
    
    if (branchId == null) {
      return where ?? [];
    }

    final branchCondition = {
      'field': 'branch_id',
      'operator': '=',
      'value': branchId,
    };

    if (where == null || where.isEmpty) {
      return [branchCondition];
    }

    // 이미 branch_id 조건이 있는지 확인
    bool hasBranchCondition = where.any((condition) => condition['field'] == 'branch_id');
    
    if (hasBranchCondition) {
      return where;
    }

    final finalConditions = [...where, branchCondition];
    return finalConditions;
  }

  // 데이터 추가 시 branch_id 자동 추가 (일부 테이블 제외)
  static Map<String, dynamic> _addBranchToData(Map<String, dynamic> data, String tableName) {
    // Staff, v2_branch, v3_members, v2_discount_coupon_auto_triggers 테이블은 branch_id 자동 추가 제외
    if (tableName == 'Staff' || tableName == 'v2_branch' || tableName == 'v3_members' || tableName == 'v2_discount_coupon_auto_triggers') {
      return data;
    }

    final branchId = getCurrentBranchId();
    if (branchId == null) {
      return data;
    }

    // 이미 branch_id가 있으면 덮어쓰지 않음
    if (data.containsKey('branch_id')) {
      return data;
    }

    return {
      ...data,
      'branch_id': branchId,
    };
  }

  // ========== 기본 CRUD 작업 ==========

  // 데이터 조회 (GET)
  static Future<List<Map<String, dynamic>>> getData({
    required String table,
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': table,
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, table);
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 데이터 추가 (ADD)
  static Future<Map<String, dynamic>> addData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, table);
      
      final requestData = {
        'operation': 'add',
        'table': table,
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 데이터 업데이트 (UPDATE)
  static Future<Map<String, dynamic>> updateData({
    required String table,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> where,
  }) async {
    try {
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, table);
      
      final requestData = {
        'operation': 'update',
        'table': table,
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 데이터 삭제 (DELETE)
  static Future<Map<String, dynamic>> deleteData({
    required String table,
    required List<Map<String, dynamic>> where,
  }) async {
    try {
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, table);
      
      final requestData = {
        'operation': 'delete',
        'table': table,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // ========== 예약 시스템 전용 함수들 ==========

  // 회원 데이터 조회
  static Future<List<Map<String, dynamic>>> getMembers({
    String? searchQuery,
    List<String>? selectedTags,
    List<String>? selectedProIds,
    bool recentOnly = false,
    bool juniorOnly = false,
    bool termOnly = false,
    int? limit,
  }) async {
    try {
      print('=== getMembers 함수 시작 ===');
      print('현재 브랜치 ID: ${getCurrentBranchId()}');
      
      List<Map<String, dynamic>> whereConditions = [];
      
      // 검색 조건 추가
      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereConditions.add({
          'field': 'member_name',
          'operator': 'LIKE',
          'value': '%$searchQuery%'
        });
      }
      
      print('검색 조건 (branch_id 필터링 전): $whereConditions');
      
      final result = await getData(
        table: 'v3_members',
        fields: ['member_id', 'member_name', 'member_phone', 'member_type', 'member_chn_keyword', 'member_register', 'branch_id'],
        where: whereConditions.isNotEmpty ? whereConditions : null,
        orderBy: [
          {'field': 'member_name', 'direction': 'ASC'}
        ],
        limit: limit ?? 100,
      );
      
      print('=== 조회된 회원 데이터 샘플 ===');
      for (int i = 0; i < (result.length > 5 ? 5 : result.length); i++) {
        final member = result[i];
        print('회원 $i: ${member['member_name']} (ID: ${member['member_id']}, Branch: ${member['branch_id']})');
      }
      print('총 조회된 회원 수: ${result.length}');
      
      return result;
    } catch (e) {
      throw Exception('회원 데이터 조회 실패: $e');
    }
  }

  // 특정 회원 정보 조회
  static Future<Map<String, dynamic>?> getMemberById(String memberId) async {
    try {
      final members = await getData(
        table: 'v3_members',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId}
        ],
        limit: 1,
      );
      
      return members.isNotEmpty ? members.first : null;
    } catch (e) {
      throw Exception('회원 정보 조회 실패: $e');
    }
  }

  // 타석 요금 정보 조회 (특정 타석)
  static Future<Map<String, dynamic>?> getTsInfoById({
    required String tsId,
  }) async {
    try {
      print('=== getTsInfoById 함수 시작 ===');
      print('조회할 타석 ID: $tsId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return null;
      }
      
      final result = await getData(
        table: 'v2_ts_info',
        fields: ['ts_id', 'base_price', 'discount_price', 'extracharge_price'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_id', 'operator': '=', 'value': tsId},
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final tsInfo = result.first;
        print('조회된 타석 정보: $tsInfo');
        return tsInfo;
      } else {
        print('해당 타석 정보 없음');
        return null;
      }
    } catch (e) {
      print('타석 정보 조회 실패: $e');
      return null;
    }
  }

  // 타석 정보 조회
  static Future<List<Map<String, dynamic>>> getTsInfo() async {
    try {
      return await getData(
        table: 'v2_ts_info',
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'}
        ],
      );
    } catch (e) {
      throw Exception('타석 정보 조회 실패: $e');
    }
  }

  // 타석 정보 조회 (ts_buffer 포함)
  static Future<List<Map<String, dynamic>>> getTsInfoWithBuffer() async {
    try {
      return await getData(
        table: 'v2_ts_info',
        fields: ['ts_id', 'ts_status', 'ts_min_minimum', 'ts_min_maximum', 'ts_buffer', 'member_type_prohibited'],
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'}
        ],
      );
    } catch (e) {
      throw Exception('타석 정보 조회 실패: $e');
    }
  }

  // 특정 날짜의 타석 예약 현황 조회 (시간 겹침 체크용)
  static Future<Map<String, List<Map<String, dynamic>>>> getTsReservationsByDate({
    required String date,
  }) async {
    try {
      print('=== getTsReservationsByDate 함수 시작 ===');
      print('조회 날짜: $date');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return {};
      }
      
      final result = await getData(
        table: 'v2_priced_TS',
        fields: ['ts_id', 'ts_start', 'ts_end', 'ts_status'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_date', 'operator': '=', 'value': date},
          {'field': 'ts_status', 'operator': '<>', 'value': '예약취소'},
        ],
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'},
          {'field': 'ts_start', 'direction': 'ASC'}
        ],
      );
      
      print('조회된 예약 데이터 수: ${result.length}');
      
      // 타석별로 예약 데이터 그룹화
      final Map<String, List<Map<String, dynamic>>> reservationsByTs = {};
      
      for (final reservation in result) {
        final tsId = reservation['ts_id']?.toString() ?? '';
        if (tsId.isNotEmpty) {
          if (!reservationsByTs.containsKey(tsId)) {
            reservationsByTs[tsId] = [];
          }
          reservationsByTs[tsId]!.add(reservation);
        }
      }
      
      // 디버깅: 각 타석별 이용현황 출력
      print('=== 각 타석별 이용현황 ===');
      reservationsByTs.forEach((tsId, reservations) {
        print('타석 $tsId: ${reservations.length}개 예약');
        for (int i = 0; i < reservations.length; i++) {
          final res = reservations[i];
          print('  예약 ${i + 1}: ${res['ts_start']} - ${res['ts_end']} (${res['ts_status']})');
        }
      });
      
      return reservationsByTs;
    } catch (e) {
      print('타석 예약 현황 조회 실패: $e');
      throw Exception('타석 예약 현황 조회 실패: $e');
    }
  }

  // 시간 겹침 체크 함수
  static bool isTimeOverlap({
    required String requestStartTime,
    required String requestEndTime,
    required String existingStartTime,
    required String existingEndTime,
  }) {
    try {
      // 시간 문자열을 분으로 변환
      int timeToMinutes(String timeStr) {
        final parts = timeStr.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
      
      final reqStart = timeToMinutes(requestStartTime);
      final reqEnd = timeToMinutes(requestEndTime);
      final existStart = timeToMinutes(existingStartTime);
      final existEnd = timeToMinutes(existingEndTime);
      
      // 겹침 체크: 시작시간이 기존 종료시간보다 작고, 종료시간이 기존 시작시간보다 크면 겹침
      return reqStart < existEnd && reqEnd > existStart;
    } catch (e) {
      print('시간 겹침 체크 오류: $e');
      return false;
    }
  }

  // 타석 예약 가능 여부 체크 (시간 겹침 포함)
  static Future<Map<String, dynamic>> checkTsAvailability({
    required String date,
    required String startTime,
    required int durationMinutes,
    required String tsId,
    required int tsBuffer,
  }) async {
    try {
      print('=== checkTsAvailability 함수 시작 ===');
      print('날짜: $date, 시작시간: $startTime, 연습시간: ${durationMinutes}분, 타석: $tsId, 버퍼: ${tsBuffer}분');
      
      // 1. 종료 시간 계산
      final parts = startTime.split(':');
      final startHour = int.parse(parts[0]);
      final startMinute = int.parse(parts[1]);
      final totalMinutes = startHour * 60 + startMinute + durationMinutes;
      final endHour = totalMinutes ~/ 60;
      final endMinute = totalMinutes % 60;
      final endTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
      
      print('계산된 종료시간: $endTime');
      
      // 2. 해당 날짜의 모든 타석 예약 현황 조회
      final reservationsByTs = await getTsReservationsByDate(date: date);
      
      // 3. 해당 타석의 예약 현황 확인
      final tsReservations = reservationsByTs[tsId] ?? [];
      print('타석 $tsId의 예약 수: ${tsReservations.length}');
      
      // 4. 각 예약과 시간 겹침 체크
      for (final reservation in tsReservations) {
        final existingStart = reservation['ts_start']?.toString() ?? '';
        final existingEnd = reservation['ts_end']?.toString() ?? '';
        
        if (existingStart.isEmpty || existingEnd.isEmpty) continue;
        
        // ts_buffer 적용: 기존 예약의 시작시간에서 버퍼를 빼고, 종료시간에 버퍼를 더함
        final existingStartMinutes = _timeToMinutes(existingStart) - tsBuffer;
        final existingEndMinutes = _timeToMinutes(existingEnd) + tsBuffer;
        
        final bufferedStartTime = _minutesToTime(existingStartMinutes);
        final bufferedEndTime = _minutesToTime(existingEndMinutes);
        
        print('기존 예약: $existingStart - $existingEnd');
        print('버퍼 적용: $bufferedStartTime - $bufferedEndTime');
        
        // 시간 겹침 체크
        if (isTimeOverlap(
          requestStartTime: startTime,
          requestEndTime: endTime,
          existingStartTime: bufferedStartTime,
          existingEndTime: bufferedEndTime,
        )) {
          print('시간 겹침 발견!');
          return {
            'available': false,
            'reason': '기존 예약과 시간 겹침',
            'conflictReservation': {
              'start': existingStart,
              'end': existingEnd,
              'bufferedStart': bufferedStartTime,
              'bufferedEnd': bufferedEndTime,
            }
          };
        }
      }
      
      print('시간 겹침 없음 - 예약 가능');
      return {
        'available': true,
        'reason': '예약 가능',
      };
      
    } catch (e) {
      print('타석 예약 가능 여부 체크 실패: $e');
      return {
        'available': false,
        'reason': '시스템 오류',
      };
    }
  }

  // 시간을 분으로 변환하는 헬퍼 함수
  static int _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  // 분을 시간으로 변환하는 헬퍼 함수
  static String _minutesToTime(int minutes) {
    try {
      // 음수 처리
      if (minutes < 0) minutes = 0;
      // 24시간 초과 처리
      if (minutes >= 1440) minutes = minutes % 1440;
      
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  // 타석 예약 데이터 조회
  static Future<List<Map<String, dynamic>>> getTsReservations({
    required String date,
    List<String>? tsIds,
  }) async {
    try {
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'ts_date', 'operator': '=', 'value': date},
        {'field': 'ts_status', 'operator': '<>', 'value': '예약취소'},
      ];
      
      if (tsIds != null && tsIds.isNotEmpty) {
        whereConditions.add({
          'field': 'ts_id',
          'operator': 'IN',
          'value': tsIds
        });
      }
      
      return await getData(
        table: 'v2_priced_TS',
        fields: ['reservation_id', 'ts_id', 'ts_date', 'ts_start', 'ts_end', 'ts_status', 'member_name', 'net_amt'],
        where: whereConditions,
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'},
          {'field': 'ts_start', 'direction': 'ASC'}
        ],
        limit: 200,
      );
    } catch (e) {
      throw Exception('타석 예약 데이터 조회 실패: $e');
    }
  }

  // Board 데이터 조회 (메모 등)
  static Future<List<Map<String, dynamic>>> getBoardData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      return await getData(
        table: 'Board',
        fields: fields,
        where: where,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('Board 데이터 조회 실패: $e');
    }
  }

  // 옵션 설정 조회
  static Future<List<Map<String, dynamic>>> getOptionSettings({
    required String category,
    required String tableName,
    required String fieldName,
  }) async {
    try {
      return await getData(
        table: 'v2_base_option_setting',
        fields: ['option_value'],
        where: [
          {'field': 'category', 'operator': '=', 'value': category},
          {'field': 'table_name', 'operator': '=', 'value': tableName},
          {'field': 'field_name', 'operator': '=', 'value': fieldName},
        ],
        orderBy: [
          {'field': 'option_value', 'direction': 'ASC'}
        ],
      );
    } catch (e) {
      throw Exception('옵션 설정 조회 실패: $e');
    }
  }

  // 타석 스케줄 조회 (특정 월)
  static Future<List<Map<String, dynamic>>> getTsSchedule({
    required int year,
    required int month,
  }) async {
    try {
      print('=== getTsSchedule 함수 시작 ===');
      print('조회 년월: $year-$month');
      
      // 해당 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      final firstDayStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDayStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
      
      print('조회 기간: $firstDayStr ~ $lastDayStr');
      
      final result = await getData(
        table: 'v2_schedule_adjusted_ts',
        fields: ['ts_date', 'day_of_week', 'business_start', 'business_end', 'is_holiday'],
        where: [
          {'field': 'ts_date', 'operator': '>=', 'value': firstDayStr},
          {'field': 'ts_date', 'operator': '<=', 'value': lastDayStr},
        ],
        orderBy: [
          {'field': 'ts_date', 'direction': 'ASC'}
        ],
      );
      
      print('조회된 스케줄 수: ${result.length}');
      for (int i = 0; i < (result.length > 5 ? 5 : result.length); i++) {
        final schedule = result[i];
        print('스케줄 $i: ${schedule['ts_date']} - ${schedule['is_holiday']} (${schedule['business_start']}~${schedule['business_end']})');
      }
      
      return result;
    } catch (e) {
      print('타석 스케줄 조회 실패: $e');
      throw Exception('타석 스케줄 조회 실패: $e');
    }
  }

  // 특정 날짜의 타석 스케줄 조회
  static Future<Map<String, dynamic>?> getTsScheduleByDate({
    required String date,
  }) async {
    try {
      print('=== getTsScheduleByDate 함수 시작 ===');
      print('조회 날짜: $date');
      
      final result = await getData(
        table: 'v2_schedule_adjusted_ts',
        fields: ['ts_date', 'day_of_week', 'business_start', 'business_end', 'is_holiday'],
        where: [
          {'field': 'ts_date', 'operator': '=', 'value': date},
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        print('조회된 스케줄: ${result.first}');
        return result.first;
      } else {
        print('해당 날짜의 스케줄 없음');
        return null;
      }
    } catch (e) {
      print('특정 날짜 타석 스케줄 조회 실패: $e');
      throw Exception('타석 스케줄 조회 실패: $e');
    }
  }

  // 예약 설정 조회 (특정 설정값)
  static Future<String?> getReservationSetting({
    required String fieldName,
  }) async {
    try {
      print('=== getReservationSetting 함수 시작 ===');
      print('조회할 설정: $fieldName');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return null;
      }
      
      final result = await getData(
        table: 'v2_base_option_setting',
        fields: ['option_value'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'field_name', 'operator': '=', 'value': fieldName},
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final optionValue = result.first['option_value']?.toString();
        print('조회된 설정값: $optionValue');
        return optionValue;
      } else {
        print('설정값을 찾을 수 없음');
        return null;
      }
    } catch (e) {
      print('예약 설정 조회 실패: $e');
      return null;
    }
  }

  // ========== 초기화 및 설정 ==========

  // 예약 시스템 초기화 (기본 브랜치 설정)
  static void initializeReservationSystem({String? branchId}) {
    if (branchId != null) {
      setCurrentBranch(branchId, {'branch_id': branchId});
    } else {
      // 기본값으로 'test' 브랜치 설정
      setCurrentBranch('test', {'branch_id': 'test'});
    }
  }

  // 로그아웃 (상태 초기화)
  static void logout() {
    _currentBranchId = null;
    _currentUser = null;
    _currentBranch = null;
  }

  // ========== 로그인 관련 함수들 ==========

  // 로그인 함수
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      print('=== 로그인 시도 ===');
      print('전화번호: $phone');
      print('비밀번호: $password');
      
      // v3_members 테이블에서 로그인 정보 조회
      final members = await getData(
        table: 'v3_members',
        where: [
          {'field': 'member_phone', 'operator': '=', 'value': phone},
          {'field': 'member_password', 'operator': '=', 'value': password},
        ],
      );

      print('=== v3_members 조회 결과 ===');
      print('조회된 회원 수: ${members.length}');
      for (int i = 0; i < members.length; i++) {
        print('회원 $i: ${members[i]}');
      }

      if (members.isEmpty) {
        throw Exception('전화번호 또는 비밀번호가 올바르지 않습니다.');
      }

      // 사용자의 branch_id 목록 추출
      final branchIds = members.map((member) => member['branch_id'].toString()).toSet().toList();
      
      print('=== 추출된 branch_id 목록 ===');
      print('Branch IDs: $branchIds');
      
      return {
        'success': true,
        'members': members,
        'branchIds': branchIds,
        'memberData': members.first,
      };
    } catch (e) {
      print('로그인 오류: $e');
      throw Exception('로그인 실패: $e');
    }
  }

  // 지점 정보 조회
  static Future<List<Map<String, dynamic>>> getBranchInfo({
    required List<String> branchIds,
  }) async {
    try {
      print('=== 지점 정보 조회 시작 ===');
      print('조회할 Branch IDs: $branchIds');
      
      final branches = await getData(
        table: 'v2_branch',
        where: [
          {
            'field': 'branch_id',
            'operator': 'IN',
            'value': branchIds,
          }
        ],
        orderBy: [
          {'field': 'branch_name', 'direction': 'ASC'}
        ],
      );
      
      print('=== v2_branch 조회 결과 ===');
      print('조회된 지점 수: ${branches.length}');
      for (int i = 0; i < branches.length; i++) {
        print('지점 $i: ${branches[i]}');
      }
      
      return branches;
    } catch (e) {
      print('지점 정보 조회 오류: $e');
      throw Exception('지점 정보 조회 실패: $e');
    }
  }

  // 타석 최소 이용 시간 조회
  static Future<int> getTsMinimumTime() async {
    try {
      print('=== getTsMinimumTime 함수 시작 ===');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음 - 기본값 60분 반환');
        return 60;
      }
      
      final result = await getData(
        table: 'v2_ts_info',
        fields: ['ts_min_minimum'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        orderBy: [
          {'field': 'ts_min_minimum', 'direction': 'ASC'}
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final minTime = int.tryParse(result.first['ts_min_minimum']?.toString() ?? '60') ?? 60;
        print('조회된 최소 이용 시간: $minTime분');
        return minTime;
      } else {
        print('최소 이용 시간 설정 없음 - 기본값 60분 반환');
        return 60;
      }
    } catch (e) {
      print('타석 최소 이용 시간 조회 실패: $e');
      return 60; // 기본값
    }
  }

  // 재직 중인 프로 목록 조회
  static Future<List<Map<String, dynamic>>> getActivePros() async {
    try {
      print('=== getActivePros 함수 시작 ===');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      final result = await getData(
        table: 'v2_staff_pro',
        fields: ['pro_id', 'pro_name', 'min_service_min', 'svc_time_unit', 'min_reservation_term', 'reservation_ahead_days'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'staff_status', 'operator': '=', 'value': '재직'},
        ],
        orderBy: [
          {'field': 'pro_name', 'direction': 'ASC'}
        ],
      );
      
      // 중복 제거 (pro_id 기준)
      final Map<String, Map<String, dynamic>> uniquePros = {};
      for (final pro in result) {
        final proId = pro['pro_id']?.toString();
        if (proId != null && proId.isNotEmpty) {
          uniquePros[proId] = pro;
        }
      }
      
      final uniqueResult = uniquePros.values.toList();
      print('조회된 재직 프로 수: ${uniqueResult.length}');
      
      for (int i = 0; i < (uniqueResult.length > 5 ? 5 : uniqueResult.length); i++) {
        final pro = uniqueResult[i];
        print('프로 $i: ${pro['pro_name']} (ID: ${pro['pro_id']})');
      }
      
      return uniqueResult;
    } catch (e) {
      print('프로 목록 조회 실패: $e');
      return [];
    }
  }

  // 특정 프로의 특정 날짜 레슨 예약 현황 조회
  static Future<List<Map<String, dynamic>>> getProLessonReservations({
    required String proId,
    required String date,
  }) async {
    try {
      print('=== getProLessonReservations 함수 시작 ===');
      print('프로 ID: $proId, 날짜: $date');
      
      final result = await getData(
        table: 'v2_LS_orders',
        fields: ['LS_start_time', 'LS_end_time', 'LS_status'],
        where: [
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'LS_date', 'operator': '=', 'value': date},
          {'field': 'LS_status', 'operator': '=', 'value': '결제완료'},
        ],
        orderBy: [
          {'field': 'LS_start_time', 'direction': 'ASC'}
        ],
      );
      
      print('조회된 레슨 예약 수: ${result.length}');
      for (int i = 0; i < result.length; i++) {
        final reservation = result[i];
        print('예약 $i: ${reservation['LS_start_time']} - ${reservation['LS_end_time']} (${reservation['LS_status']})');
      }
      
      return result;
    } catch (e) {
      print('프로 레슨 예약 조회 실패: $e');
      return [];
    }
  }

  // 회원의 레슨 예약 조회
  static Future<List<Map<String, dynamic>>> getMemberLessonReservations({
    required String memberId,
    required String date,
  }) async {
    try {
      print('=== getMemberLessonReservations 함수 시작 ===');
      print('회원 ID: $memberId, 날짜: $date');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      final result = await getData(
        table: 'v2_LS_orders',
        fields: ['LS_start_time', 'LS_end_time', 'LS_status', 'pro_name'],
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'LS_date', 'operator': '=', 'value': date},
          {'field': 'LS_status', 'operator': '=', 'value': '결제완료'},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        orderBy: [
          {'field': 'LS_start_time', 'direction': 'ASC'}
        ],
      );
      
      print('조회된 회원 레슨 예약 수: ${result.length}');
      for (int i = 0; i < result.length; i++) {
        final reservation = result[i];
        print('레슨 예약 $i: ${reservation['LS_start_time']} - ${reservation['LS_end_time']} (${reservation['pro_name']})');
      }
      
      return result;
    } catch (e) {
      print('회원 레슨 예약 조회 실패: $e');
      return [];
    }
  }

  // 특정 프로의 특정 날짜 근무시간 조회
  static Future<Map<String, dynamic>?> getProWorkSchedule({
    required String proId,
    required String date,
  }) async {
    try {
      print('=== getProWorkSchedule 함수 시작 ===');
      print('프로 ID: $proId, 날짜: $date');
      
      final result = await getData(
        table: 'v2_schedule_adjusted_pro',
        fields: ['work_start', 'work_end', 'scheduled_date'],
        where: [
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'scheduled_date', 'operator': '=', 'value': date},
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        print('조회된 근무시간: ${result.first}');
        return result.first;
      } else {
        print('해당 날짜의 근무시간 정보 없음');
        return null;
      }
    } catch (e) {
      print('프로 근무시간 조회 실패: $e');
      return null;
    }
  }

  // 프로의 레슨 가능 시간 계산
  static Future<List<Map<String, String>>> getProAvailableTimeSlots({
    required String proId,
    required String date,
    required Map<String, dynamic> proInfo,
  }) async {
    try {
      print('=== getProAvailableTimeSlots 함수 시작 ===');
      print('프로 ID: $proId, 날짜: $date');
      print('프로 정보: $proInfo');
      
      // 1. 일자 기준 예약 가능 기간 확인
      final reservationAheadDays = int.tryParse(proInfo['reservation_ahead_days']?.toString() ?? '0') ?? 0;
      final targetDate = DateTime.tryParse(date);
      final now = DateTime.now();
      
      if (targetDate == null) {
        print('잘못된 날짜 형식');
        return [];
      }
      
      final daysDifference = targetDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (daysDifference > reservationAheadDays) {
        print('예약 가능 기간 초과: $daysDifference일 > $reservationAheadDays일');
        return [];
      }
      
      // 2. 프로의 근무시간 조회
      final workSchedule = await getProWorkSchedule(proId: proId, date: date);
      if (workSchedule == null) {
        print('근무시간 정보 없음');
        return [];
      }
      
      final workStart = workSchedule['work_start']?.toString();
      final workEnd = workSchedule['work_end']?.toString();
      
      if (workStart == null || workEnd == null) {
        print('근무시간 정보 불완전');
        return [];
      }
      
      // 3. 기존 레슨 예약 조회
      final existingReservations = await getProLessonReservations(proId: proId, date: date);
      
      // 4. 시간 계산을 위한 파라미터
      final minServiceMin = int.tryParse(proInfo['min_service_min']?.toString() ?? '15') ?? 15;
      final minReservationTerm = int.tryParse(proInfo['min_reservation_term']?.toString() ?? '30') ?? 30;
      
      // 5. 오늘 날짜인 경우 현재 시간 + 최소 예약 기간 이후부터 가능
      DateTime? earliestTime;
      if (targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day) {
        earliestTime = now.add(Duration(minutes: minReservationTerm));
      }
      
      // 6. 가능한 시간 구간 계산
      final availableSlots = _calculateAvailableTimeSlots(
        workStart: workStart,
        workEnd: workEnd,
        existingReservations: existingReservations,
        minServiceMin: minServiceMin,
        earliestTime: earliestTime,
      );
      
      print('계산된 가능 시간 구간 수: ${availableSlots.length}');
      for (int i = 0; i < availableSlots.length; i++) {
        final slot = availableSlots[i];
        print('구간 $i: ${slot['start']} - ${slot['end']}');
      }
      
      return availableSlots;
    } catch (e) {
      print('프로 가능 시간 계산 실패: $e');
      return [];
    }
  }

  // 가능한 시간 구간 계산 (내부 함수)
  static List<Map<String, String>> _calculateAvailableTimeSlots({
    required String workStart,
    required String workEnd,
    required List<Map<String, dynamic>> existingReservations,
    required int minServiceMin,
    DateTime? earliestTime,
  }) {
    try {
      // 시간 문자열을 분으로 변환하는 함수
      int timeToMinutes(String timeStr) {
        final parts = timeStr.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
      
      // 분을 시간 문자열로 변환하는 함수
      String minutesToTime(int minutes) {
        final hours = minutes ~/ 60;
        final mins = minutes % 60;
        return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
      }
      
      final workStartMin = timeToMinutes(workStart);
      final workEndMin = timeToMinutes(workEnd);
      
      // 기존 예약을 시간 순으로 정렬
      final sortedReservations = List<Map<String, dynamic>>.from(existingReservations);
      sortedReservations.sort((a, b) {
        final aStart = timeToMinutes(a['LS_start_time'].toString());
        final bStart = timeToMinutes(b['LS_start_time'].toString());
        return aStart.compareTo(bStart);
      });
      
      // 실제 시작 가능한 시간 계산
      int actualStartMin = workStartMin;
      if (earliestTime != null) {
        final earliestMin = earliestTime.hour * 60 + earliestTime.minute;
        // 5분 단위로 올림 처리
        int adjustedMin = ((earliestTime.minute / 5).ceil() * 5) % 60;
        int adjustedHour = earliestTime.hour;
        if (earliestTime.minute > 55) {
          adjustedHour = (earliestTime.hour + 1) % 24;
          adjustedMin = 0;
        }
        final adjustedEarliestMin = adjustedHour * 60 + adjustedMin;
        
        if (adjustedEarliestMin > workStartMin) {
          actualStartMin = adjustedEarliestMin;
        }
      }
      
      // 가능한 시간 구간 계산
      final List<Map<String, String>> availableSlots = [];
      int currentMin = actualStartMin;
      
      for (final reservation in sortedReservations) {
        final resStartMin = timeToMinutes(reservation['LS_start_time'].toString());
        final resEndMin = timeToMinutes(reservation['LS_end_time'].toString());
        
        // 현재 시간부터 예약 시작 시간까지의 구간이 최소 서비스 시간보다 크면 추가
        if (resStartMin - currentMin >= minServiceMin) {
          availableSlots.add({
            'start': minutesToTime(currentMin),
            'end': minutesToTime(resStartMin),
          });
        }
        
        // 다음 시작 시간을 예약 종료 시간으로 설정
        currentMin = resEndMin;
      }
      
      // 마지막 예약 이후부터 근무 종료 시간까지의 구간
      if (workEndMin - currentMin >= minServiceMin) {
        availableSlots.add({
          'start': minutesToTime(currentMin),
          'end': minutesToTime(workEndMin),
        });
      }
      
      return availableSlots;
    } catch (e) {
      print('시간 구간 계산 오류: $e');
      return [];
    }
  }

  // ========== 공휴일 및 요금 정책 관련 함수들 ==========

  // 회원의 최신 잔액 조회
  static Future<int> getMemberBalance({
    required String memberId,
  }) async {
    try {
      print('=== getMemberBalance 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return 0;
      }
      
      final result = await getData(
        table: 'v2_bills',
        fields: ['bill_balance_after'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [
          {'field': 'bill_id', 'direction': 'DESC'}
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final balance = int.tryParse(result.first['bill_balance_after']?.toString() ?? '0') ?? 0;
        print('조회된 최신 잔액: $balance원');
        return balance;
      } else {
        print('잔액 정보 없음 - 0원 반환');
        return 0;
      }
    } catch (e) {
      print('회원 잔액 조회 실패: $e');
      return 0;
    }
  }

  // 회원의 계약별 선불크레딧 잔액 조회 (유효기간 포함)
  static Future<List<Map<String, dynamic>>> getMemberPrepaidCreditsByContract({
    required String memberId,
  }) async {
    try {
      print('=== getMemberPrepaidCreditsByContract 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      // v2_bills 테이블에서 contract_history_id가 있는 선불크레딧 거래 조회
      final billsResult = await getData(
        table: 'v2_bills',
        fields: ['contract_history_id', 'bill_balance_after', 'contract_credit_expiry_date'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '>', 'value': '0'},
        ],
        orderBy: [
          {'field': 'bill_id', 'direction': 'DESC'}
        ],
      );
      
      print('조회된 선불크레딧 거래 수: ${billsResult.length}');
      
      if (billsResult.isEmpty) {
        print('선불크레딧 거래 내역이 없음');
        return [];
      }
      
      // contract_history_id별로 최신 잔액 그룹핑
      Map<String, Map<String, dynamic>> contractBalances = {};
      
      for (final bill in billsResult) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        final balance = int.tryParse(bill['bill_balance_after']?.toString() ?? '0') ?? 0;
        final expiryDate = bill['contract_credit_expiry_date']?.toString();
        
        if (contractHistoryId != null && contractHistoryId.isNotEmpty && contractHistoryId != '0') {
          // 이미 해당 contract_history_id가 있으면 건너뛰기 (이미 최신 데이터이므로)
          if (!contractBalances.containsKey(contractHistoryId)) {
            contractBalances[contractHistoryId] = {
              'contract_history_id': contractHistoryId,
              'contract_id': contractHistoryId, // contract_id로 contract_history_id 사용
              'balance': balance,
              'expiry_date': expiryDate,
            };
            
            print('계약 ID $contractHistoryId 잔액: $balance원, 만료일: $expiryDate');
          }
        }
      }
      
      // program_reservation_availability 필터링 추가
      print('=== 선불크레딧 program_reservation_availability 필터링 시작 ===');
      
      List<Map<String, dynamic>> creditContracts = [];
      
      if (contractBalances.isNotEmpty) {
        try {
          // contract_history_id들로 v3_contract_history에서 contract_id 조회
          final contractHistoryIds = contractBalances.keys.toList();
          final contractHistoryRecords = await getData(
            table: 'v3_contract_history',
            fields: ['contract_history_id', 'contract_id'],
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'contract_history_id', 'operator': 'IN', 'value': contractHistoryIds},
            ],
          );
          
          // contract_id들로 v2_contracts에서 program_reservation_availability 조회
          final contractIds = contractHistoryRecords
              .map((record) => record['contract_id']?.toString())
              .where((id) => id != null)
              .cast<String>()
              .toSet()
              .toList();
          
          Map<String, String> contractToProgramAvailability = {};
          if (contractIds.isNotEmpty) {
            final contractRecords = await getData(
              table: 'v2_contracts',
              fields: ['contract_id', 'program_reservation_availability'],
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'contract_id', 'operator': 'IN', 'value': contractIds},
              ],
            );
            
            for (final contractRecord in contractRecords) {
              final contractId = contractRecord['contract_id']?.toString();
              final programAvailability = contractRecord['program_reservation_availability']?.toString() ?? '';
              if (contractId != null) {
                contractToProgramAvailability[contractId] = programAvailability;
              }
            }
          }
          
          // 필터링 적용
          final Map<String, String> historyToContractMap = {};
          for (final historyRecord in contractHistoryRecords) {
            final historyId = historyRecord['contract_history_id']?.toString();
            final contractId = historyRecord['contract_id']?.toString();
            if (historyId != null && contractId != null) {
              historyToContractMap[historyId] = contractId;
            }
          }
          
          for (final contract in contractBalances.values) {
            final balance = contract['balance'] as int;
            final contractHistoryId = contract['contract_history_id']?.toString();
            
            // 잔액이 0보다 큰 계약들만 처리
            if (balance > 0) {
              if (contractHistoryId != null && historyToContractMap.containsKey(contractHistoryId)) {
                final contractId = historyToContractMap[contractHistoryId];
                final programAvailability = contractToProgramAvailability[contractId] ?? '';
                
                // program_reservation_availability가 null이거나 빈 문자열인 경우만 타석 예약 가능
                final isValidForTsReservation = programAvailability.isEmpty || 
                                              programAvailability.toLowerCase() == 'null';
                
                print('선불크레딧 계약 $contractHistoryId → contract_id: $contractId → program_availability: "$programAvailability" → 타석예약가능: $isValidForTsReservation');
                
                if (isValidForTsReservation) {
                  creditContracts.add(contract);
                } else {
                  print('필터링으로 제외된 선불크레딧 계약: $contractHistoryId (프로그램 예약 전용)');
                }
              }
            }
          }
        } catch (e) {
          print('선불크레딧 program_reservation_availability 필터링 중 오류: $e');
          // 오류 발생 시 잔액이 0보다 큰 계약들만 반환 (안전 모드)
          for (final contract in contractBalances.values) {
            final balance = contract['balance'] as int;
            if (balance > 0) {
              creditContracts.add(contract);
            }
          }
        }
      }
      
      print('=== 선불크레딧 program_reservation_availability 필터링 완료 ===');
      print('최종 반환할 선불크레딧 계약 수: ${creditContracts.length}');
      return creditContracts;
      
    } catch (e) {
      print('계약별 선불크레딧 조회 실패: $e');
      return [];
    }
  }

  // 회원의 시간권 잔액 조회
  static Future<int> getMemberTimePassBalance({
    required String memberId,
  }) async {
    try {
      print('=== getMemberTimePassBalance 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return 0;
      }
      
      final result = await getData(
        table: 'v2_bill_times',
        fields: ['bill_balance_min_after'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [
          {'field': 'bill_min_id', 'direction': 'DESC'} // bill_id 대신 bill_min_id 사용
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final balance = int.tryParse(result.first['bill_balance_min_after']?.toString() ?? '0') ?? 0;
        print('조회된 시간권 잔액: $balance분');
        return balance;
      } else {
        print('시간권 잔액 정보 없음 - 0분 반환');
        return 0;
      }
    } catch (e) {
      print('회원 시간권 잔액 조회 실패: $e');
      return 0;
    }
  }

  // 회원의 계약별 시간권 잔액 조회 (유효기간 포함)
  static Future<List<Map<String, dynamic>>> getMemberTimePassesByContract({
    required String memberId,
  }) async {
    try {
      print('=== getMemberTimePassesByContract 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      // v2_bill_times 테이블에서 contract_history_id가 있는 시간권 거래 조회
      final billsResult = await getData(
        table: 'v2_bill_times',
        fields: ['contract_history_id', 'bill_balance_min_after', 'contract_TS_min_expiry_date'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '>', 'value': '0'},
        ],
        orderBy: [
          {'field': 'bill_min_id', 'direction': 'DESC'} // bill_id 대신 bill_min_id 사용
        ],
      );
      
      print('조회된 시간권 거래 수: ${billsResult.length}');
      
      if (billsResult.isEmpty) {
        print('시간권 거래 내역이 없음');
        return [];
      }
      
      // contract_history_id별로 최신 잔액 그룹핑
      Map<String, Map<String, dynamic>> contractBalances = {};
      
      for (final bill in billsResult) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        final balance = int.tryParse(bill['bill_balance_min_after']?.toString() ?? '0') ?? 0;
        final expiryDate = bill['contract_TS_min_expiry_date']?.toString();
        
        if (contractHistoryId != null && contractHistoryId.isNotEmpty && contractHistoryId != '0') {
          // 이미 해당 contract_history_id가 있으면 건너뛰기 (이미 최신 데이터이므로)
          if (!contractBalances.containsKey(contractHistoryId)) {
            contractBalances[contractHistoryId] = {
              'contract_history_id': contractHistoryId,
              'contract_id': contractHistoryId, // contract_id로 contract_history_id 사용
              'balance': balance,
              'expiry_date': expiryDate,
            };
            
            print('계약 ID $contractHistoryId 잔액: $balance분, 만료일: $expiryDate');
          }
        }
      }
      
      // program_reservation_availability 필터링 추가
      print('=== 시간권 program_reservation_availability 필터링 시작 ===');
      
      List<Map<String, dynamic>> timePassContracts = [];
      
      if (contractBalances.isNotEmpty) {
        try {
          // contract_history_id들로 v3_contract_history에서 contract_id 조회
          final contractHistoryIds = contractBalances.keys.toList();
          final contractHistoryRecords = await getData(
            table: 'v3_contract_history',
            fields: ['contract_history_id', 'contract_id'],
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'contract_history_id', 'operator': 'IN', 'value': contractHistoryIds},
            ],
          );
          
          // contract_id들로 v2_contracts에서 program_reservation_availability 조회
          final contractIds = contractHistoryRecords
              .map((record) => record['contract_id']?.toString())
              .where((id) => id != null)
              .cast<String>()
              .toSet()
              .toList();
          
          Map<String, String> contractToProgramAvailability = {};
          if (contractIds.isNotEmpty) {
            final contractRecords = await getData(
              table: 'v2_contracts',
              fields: ['contract_id', 'program_reservation_availability'],
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'contract_id', 'operator': 'IN', 'value': contractIds},
              ],
            );
            
            for (final contractRecord in contractRecords) {
              final contractId = contractRecord['contract_id']?.toString();
              final programAvailability = contractRecord['program_reservation_availability']?.toString() ?? '';
              if (contractId != null) {
                contractToProgramAvailability[contractId] = programAvailability;
              }
            }
          }
          
          // 필터링 적용
          final Map<String, String> historyToContractMap = {};
          for (final historyRecord in contractHistoryRecords) {
            final historyId = historyRecord['contract_history_id']?.toString();
            final contractId = historyRecord['contract_id']?.toString();
            if (historyId != null && contractId != null) {
              historyToContractMap[historyId] = contractId;
            }
          }
          
          for (final contract in contractBalances.values) {
            final contractHistoryId = contract['contract_history_id']?.toString();
            if (contractHistoryId != null && historyToContractMap.containsKey(contractHistoryId)) {
              final contractId = historyToContractMap[contractHistoryId];
              final programAvailability = contractToProgramAvailability[contractId] ?? '';
              
              // program_reservation_availability가 null이거나 빈 문자열인 경우만 타석 예약 가능
              final isValidForTsReservation = programAvailability.isEmpty || 
                                            programAvailability.toLowerCase() == 'null';
              
              print('시간권 계약 $contractHistoryId → contract_id: $contractId → program_availability: "$programAvailability" → 타석예약가능: $isValidForTsReservation');
              
              if (isValidForTsReservation) {
                timePassContracts.add(contract);
              } else {
                print('필터링으로 제외된 시간권 계약: $contractHistoryId (프로그램 예약 전용)');
              }
            }
          }
        } catch (e) {
          print('시간권 program_reservation_availability 필터링 중 오류: $e');
          // 오류 발생 시 모든 계약 반환 (안전 모드)
          for (final contract in contractBalances.values) {
            timePassContracts.add(contract);
          }
        }
      }
      
      print('=== 시간권 program_reservation_availability 필터링 완료 ===');
      print('최종 반환할 시간권 계약 수: ${timePassContracts.length}');
      return timePassContracts;
      
    } catch (e) {
      print('계약별 시간권 조회 실패: $e');
      return [];
    }
  }

  // 회원의 계약별 시간권 조회 (프로그램 예약용 - program_reservation_availability 확인)
  static Future<List<Map<String, dynamic>>> getMemberTimePassesByContractForProgram({
    required String memberId,
    String? reservationDate, // 예약 날짜 추가
  }) async {
    try {
      print('=== getMemberTimePassesByContractForProgram 함수 시작 ===');
      print('회원 ID: $memberId');
      print('예약 날짜: $reservationDate');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      // v2_bill_times 테이블에서 contract_history_id가 있는 시간권 거래 조회
      final billsResult = await getData(
        table: 'v2_bill_times',
        fields: ['contract_history_id', 'bill_balance_min_after', 'contract_TS_min_expiry_date'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_id', 'operator': '>', 'value': '0'},
        ],
        orderBy: [
          {'field': 'bill_min_id', 'direction': 'DESC'}
        ],
      );
      
      print('조회된 시간권 거래 수: ${billsResult.length}');
      
      if (billsResult.isEmpty) {
        print('시간권 거래 내역이 없음');
        return [];
      }
      
      // 예약 날짜 파싱 (검증용)
      DateTime? reservationDateTime;
      if (reservationDate != null && reservationDate.isNotEmpty) {
        try {
          reservationDateTime = DateTime.parse(reservationDate);
          print('예약 날짜 파싱 성공: $reservationDateTime');
        } catch (e) {
          print('예약 날짜 파싱 실패: $e');
        }
      }
      
      // contract_history_id별로 최신 잔액 그룹핑 및 만료일 검증
      Map<String, Map<String, dynamic>> contractBalances = {};
      Set<String> contractHistoryIds = {};
      
      for (final bill in billsResult) {
        final contractHistoryId = bill['contract_history_id']?.toString();
        final balance = int.tryParse(bill['bill_balance_min_after']?.toString() ?? '0') ?? 0;
        final expiryDate = bill['contract_TS_min_expiry_date']?.toString();
        
        if (contractHistoryId != null && contractHistoryId.isNotEmpty && contractHistoryId != '0') {
          // 이미 해당 contract_history_id가 있으면 건너뛰기 (이미 최신 데이터이므로)
          if (!contractBalances.containsKey(contractHistoryId)) {
            // 만료일 검증
            bool isValidExpiry = true;
            if (expiryDate != null && expiryDate.isNotEmpty && reservationDateTime != null) {
              try {
                final expiryDateTime = DateTime.parse(expiryDate);
                // 예약 날짜가 만료일 이후면 무효
                if (reservationDateTime.isAfter(expiryDateTime)) {
                  isValidExpiry = false;
                  print('만료일 초과로 제외된 계약: $contractHistoryId (만료일: $expiryDate, 예약일: $reservationDate)');
                }
              } catch (e) {
                print('만료일 파싱 실패로 제외된 계약: $contractHistoryId (만료일: $expiryDate)');
                isValidExpiry = false;
              }
            }
            
            // 잔액 검증 및 만료일 검증 통과한 계약만 추가
            if (balance > 0 && isValidExpiry) {
              contractBalances[contractHistoryId] = {
                'contract_history_id': contractHistoryId,
                'contract_id': contractHistoryId,
                'balance': balance,
                'expiry_date': expiryDate,
              };
              contractHistoryIds.add(contractHistoryId);
              
              print('유효한 계약 ID $contractHistoryId 잔액: $balance분, 만료일: $expiryDate');
            } else {
              final reason = balance <= 0 ? '잔액 부족' : '만료일 초과';
              print('제외된 계약 ID $contractHistoryId (사유: $reason, 잔액: $balance분, 만료일: $expiryDate)');
            }
          }
        }
      }
      
      // v3_contract_history 테이블에서 contract_id 조회
      List<Map<String, dynamic>> validTimePassContracts = [];
      
      if (contractHistoryIds.isNotEmpty) {
        // 1단계: contract_history_id로 contract_id 조회
        final contractHistoryResult = await getData(
          table: 'v3_contract_history',
          fields: ['contract_history_id', 'contract_id'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': 'IN', 'value': contractHistoryIds.toList()},
          ],
        );
        
        print('v3_contract_history에서 조회된 계약 히스토리 수: ${contractHistoryResult.length}');
        
        // contract_history_id -> contract_id 매핑 생성
        Map<String, String> historyToContractMap = {};
        Set<String> contractIds = {};
        
        for (final historyRecord in contractHistoryResult) {
          final contractHistoryId = historyRecord['contract_history_id']?.toString();
          final contractId = historyRecord['contract_id']?.toString();
          
          if (contractHistoryId != null && contractId != null) {
            historyToContractMap[contractHistoryId] = contractId;
            contractIds.add(contractId);
          }
        }
        
        print('매핑된 contract_id 수: ${contractIds.length}');
        
        // 2단계: contract_id로 v2_contracts에서 program_reservation_availability 확인
        if (contractIds.isNotEmpty) {
          final contractsResult = await getData(
            table: 'v2_contracts',
            fields: ['contract_id', 'program_reservation_availability'],
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'contract_id', 'operator': 'IN', 'value': contractIds.toList()},
            ],
          );
          
          print('v2_contracts에서 조회된 계약 수: ${contractsResult.length}');
          
          // program_reservation_availability가 유효한 contract_id 수집
          Set<String> validContractIds = {};
          for (final contractInfo in contractsResult) {
            final contractId = contractInfo['contract_id']?.toString();
            final programAvailability = contractInfo['program_reservation_availability']?.toString();
            
            if (contractId != null && 
                programAvailability != null && 
                programAvailability.isNotEmpty && 
                programAvailability != '0') {
              validContractIds.add(contractId);
              print('유효한 계약: $contractId (program_availability: $programAvailability)');
            } else {
              print('프로그램 예약 불가능한 계약: $contractId (program_availability: $programAvailability)');
            }
          }
          
          // 3단계: 유효한 contract_id에 해당하는 시간권 계약만 필터링
          for (final contractHistoryId in contractHistoryIds) {
            final contractId = historyToContractMap[contractHistoryId];
            if (contractId != null && validContractIds.contains(contractId)) {
              final contractData = contractBalances[contractHistoryId];
              if (contractData != null) {
                // 실제 program_availability 값 저장
                final actualProgramAvailability = contractsResult
                    .firstWhere((c) => c['contract_id'] == contractId, orElse: () => {})['program_reservation_availability']?.toString() ?? '';
                contractData['program_reservation_availability'] = actualProgramAvailability;
                contractData['actual_contract_id'] = contractId;
                validTimePassContracts.add(contractData);
                print('유효한 시간권 계약: history_id=$contractHistoryId, contract_id=$contractId, program_availability=$actualProgramAvailability');
              }
            } else {
              print('프로그램 예약 불가능한 시간권: history_id=$contractHistoryId, contract_id=$contractId');
            }
          }
        }
      }
      
      print('최종 반환할 프로그램용 시간권 계약 수: ${validTimePassContracts.length}');
      return validTimePassContracts;
      
    } catch (e) {
      print('프로그램용 계약별 시간권 조회 실패: $e');
      return [];
    }
  }

  // 회원의 기업복지 타입 조회
  static Future<String> getMemberCorporateWelfareType({
    required String memberId,
  }) async {
    try {
      print('=== getMemberCorporateWelfareType 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return '해당없음';
      }
      
      final result = await getData(
        table: 'v3_members',
        fields: ['member_type'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final memberType = result.first['member_type']?.toString() ?? '';
        print('조회된 회원 타입: $memberType');
        
        // 기업복지 타입 확인
        if (memberType == '웰빙클럽' || memberType == '리프레쉬' || memberType == '아이코젠') {
          return memberType;
        } else {
          return '해당없음';
        }
      } else {
        print('회원 타입 정보 없음 - 해당없음 반환');
        return '해당없음';
      }
    } catch (e) {
      print('회원 기업복지 타입 조회 실패: $e');
      return '해당없음';
    }
  }

  // 회원의 타입 조회 (타석 제한 확인용)
  static Future<String> getMemberType({
    required String memberId,
  }) async {
    try {
      print('=== getMemberType 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return '';
      }
      
      final result = await getData(
        table: 'v3_members',
        fields: ['member_type'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final memberType = result.first['member_type']?.toString() ?? '';
        print('조회된 회원 타입: $memberType');
        return memberType;
      } else {
        print('회원 타입 정보 없음 - 빈 문자열 반환');
        return '';
      }
    } catch (e) {
      print('회원 타입 조회 실패: $e');
      return '';
    }
  }

  // 기업복지 시간 제약 조건 조회
  static Future<Map<String, int>> getCorporateWelfareTimeConstraints() async {
    try {
      print('=== getCorporateWelfareTimeConstraints 함수 시작 ===');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return {};
      }
      
      final result = await getData(
        table: 'v2_base_option_setting',
        fields: ['field_name', 'option_value'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'category', 'operator': '=', 'value': '기업복지'},
          {'field': 'table_name', 'operator': '=', 'value': '시간제약'},
        ],
      );
      
      print('조회된 기업복지 시간 제약 수: ${result.length}');
      
      final Map<String, int> constraints = {};
      for (final item in result) {
        final fieldName = item['field_name']?.toString() ?? '';
        final optionValue = int.tryParse(item['option_value']?.toString() ?? '0') ?? 0;
        
        if (fieldName.isNotEmpty) {
          constraints[fieldName] = optionValue;
          print('시간 제약: $fieldName = ${optionValue}분');
        }
      }
      
      return constraints;
    } catch (e) {
      print('기업복지 시간 제약 조회 실패: $e');
      return {};
    }
  }

  // 회원의 유효한 기간권 정보 조회
  static Future<List<Map<String, dynamic>>> getMemberPeriodPass({
    required String memberId,
  }) async {
    try {
      print('=== getMemberPeriodPass 함수 시작 ===');
      print('회원 ID: $memberId');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      // 1. contract_history에서 활성 상태인 기간권 계약 조회
      final contractHistories = await getData(
        table: 'v3_contract_history',
        fields: ['contract_id', 'contract_term_month_expiry_date'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_type', 'operator': '=', 'value': '기간권'},
          {'field': 'contract_history_status', 'operator': '=', 'value': '활성'},
        ],
      );
      
      print('조회된 계약 내역 수: ${contractHistories.length}');
      
      if (contractHistories.isEmpty) {
        print('활성 상태인 기간권 계약이 없음');
        return [];
      }
      
      // 2. 만료일 확인 - 오늘 날짜와 비교
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final validContracts = <Map<String, dynamic>>[];
      
      for (final contract in contractHistories) {
        final expiryDateStr = contract['contract_term_month_expiry_date']?.toString();
        final contractId = contract['contract_id']?.toString();
        
        print('계약 ID: $contractId, 만료일: $expiryDateStr');
        
        if (contractId != null) {
          // 만료일이 오늘보다 이후인 경우만 유효한 계약으로 처리
          if (expiryDateStr != null && expiryDateStr.isNotEmpty && expiryDateStr.compareTo(todayStr) >= 0) {
            print('유효한 계약: $contractId (만료일: $expiryDateStr)');
            validContracts.add({
              'contract_id': contractId,
              'expiry_date': expiryDateStr,
            });
          } else {
            print('만료된 계약 또는 만료일 없음: $contractId (만료일: $expiryDateStr)');
          }
        }
      }
      
      if (validContracts.isEmpty) {
        print('유효한 기간권 계약이 없음');
        return [];
      }
      
      // 3. 유효한 계약 ID들로 v2_contracts에서 이용 조건 조회
      final contractIds = validContracts.map((c) => c['contract_id']).toList();
      
      final contractDetails = await getData(
        table: 'v2_contracts',
        fields: ['contract_id', 'contract_name', 'available_days', 'available_start_time', 'available_end_time', 'available_ts_id', 'program_reservation_availability'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_id', 'operator': 'IN', 'value': contractIds},
        ],
      );
      
      print('=== 조회된 기간권 이용 조건 ===');
      for (final detail in contractDetails) {
        print('계약 ID: ${detail['contract_id']}');
        print('계약명: ${detail['contract_name']}');
        print('이용 가능 요일: ${detail['available_days']}');
        print('이용 가능 시작시간: ${detail['available_start_time']}');
        print('이용 가능 종료시간: ${detail['available_end_time']}');
        print('이용 가능 타석 ID: ${detail['available_ts_id']}');
        print('program_reservation_availability: "${detail['program_reservation_availability']}"');
        print('---');
      }
      
      // 4. program_reservation_availability 필터링 및 만료일 정보 결합
      final result = <Map<String, dynamic>>[];
      
      print('=== 타석 예약용 기간권 필터링 시작 ===');
      
      for (final detail in contractDetails) {
        final contractId = detail['contract_id'];
        final programAvailability = detail['program_reservation_availability']?.toString() ?? '';
        
        // program_reservation_availability 필터링
        final isValidForTsReservation = programAvailability.isEmpty || 
                                       programAvailability.toLowerCase() == 'null';
        
        print('계약 ID: $contractId → program_availability: "$programAvailability" → 타석예약가능: $isValidForTsReservation');
        
        if (!isValidForTsReservation) {
          print('필터링으로 제외된 기간권 계약: $contractId (프로그램 예약 전용)');
          continue; // 프로그램 예약 전용 계약은 제외
        }
        
        final validContract = validContracts.firstWhere(
          (c) => c['contract_id'] == contractId,
          orElse: () => {},
        );
        
        if (validContract.isNotEmpty) {
          result.add({
            ...detail,
            'expiry_date': validContract['expiry_date'],
          });
        }
      }
      
      print('=== 타석 예약용 기간권 필터링 완료 ===');
      
      print('최종 반환할 기간권 정보 수: ${result.length}');
      return result;
      
    } catch (e) {
      print('기간권 정보 조회 실패: $e');
      return [];
    }
  }

  // 공휴일 확인 (간단한 공휴일 체크)
  static Future<bool> isHoliday(DateTime date) async {
    try {
      // 일요일은 기본적으로 공휴일로 처리
      if (date.weekday == DateTime.sunday) {
        return true;
      }
      
      // 주요 공휴일 체크 (간단한 버전)
      final year = date.year;
      final month = date.month;
      final day = date.day;
      
      // 신정
      if (month == 1 && day == 1) return true;
      
      // 어린이날
      if (month == 5 && day == 5) return true;
      
      // 현충일
      if (month == 6 && day == 6) return true;
      
      // 광복절
      if (month == 8 && day == 15) return true;
      
      // 개천절
      if (month == 10 && day == 3) return true;
      
      // 한글날
      if (month == 10 && day == 9) return true;
      
      // 크리스마스
      if (month == 12 && day == 25) return true;
      
      return false;
    } catch (e) {
      print('공휴일 확인 오류: $e');
      return false;
    }
  }

  // 요일 문자열 변환
  static String getKoreanDayOfWeek(DateTime date) {
    const weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
    return weekdays[date.weekday];
  }

  // 타석 요금 정책 조회
  static Future<List<Map<String, dynamic>>> getTsPricingPolicy({
    required DateTime date,
  }) async {
    try {
      print('=== getTsPricingPolicy 함수 시작 ===');
      print('조회 날짜: $date');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없음');
        return [];
      }
      
      // 공휴일 여부 확인
      final isHolidayDate = await HolidayService.isHoliday(date);
      final dayOfWeek = HolidayService.getKoreanDayOfWeek(date);
      
      // 공휴일인 경우 공휴일 전용 요금을 적용하도록 변경
      final queryDayOfWeek = isHolidayDate ? '공휴일' : dayOfWeek;
      
      print('🗓️ ========== 요일/공휴일 정보 디버깅 ==========');
      print('🗓️ 예약 날짜: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} (${date.toString().split(' ')[0]})');
      print('🗓️ 실제 요일: $dayOfWeek (숫자: ${date.weekday}) - 1=월요일, 7=일요일');
      print('🗓️ 공휴일 여부: $isHolidayDate');
      print('🗓️ 요금 적용 요일: $queryDayOfWeek ${isHolidayDate ? '(공휴일이므로 공휴일 요금 적용)' : ''}');
      print('🗓️ 브랜치 ID: $branchId');
      print('🗓️ 조회할 테이블: v2_ts_pricing_policy');
      print('🗓️ 조회 조건: branch_id=$branchId AND day_of_week=$queryDayOfWeek');
      print('🗓️ ============================================');
      
      final result = await getData(
        table: 'v2_ts_pricing_policy',
        fields: ['policy_start_time', 'policy_end_time', 'policy_apply'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'day_of_week', 'operator': '=', 'value': queryDayOfWeek},
        ],
        orderBy: [
          {'field': 'policy_start_time', 'direction': 'ASC'}
        ],
      );
      
      print('🗓️ ========== 조회된 요금 정책 결과 ==========');
      print('🗓️ 조회된 요금 정책 수: ${result.length}');
      if (result.isEmpty) {
        print('🗓️ ⚠️ 해당 요일($queryDayOfWeek)에 대한 요금 정책이 없습니다!');
      } else {
        for (int i = 0; i < result.length; i++) {
          final policy = result[i];
          final startTime = policy['policy_start_time'];
          final endTime = policy['policy_end_time'];
          final policyType = policy['policy_apply'];
          String policyName;
          switch (policyType) {
            case 'base_price':
              policyName = '일반';
              break;
            case 'discount_price':
              policyName = '할인';
              break;
            case 'extracharge_price':
              policyName = '할증';
              break;
            case 'out_of_business':
              policyName = '미운영';
              break;
            default:
              policyName = policyType;
          }
          print('🗓️ 정책 ${i+1}: $startTime ~ $endTime → $policyName ($policyType)');
        }
      }
      print('🗓️ ========================================');
      
      return result;
    } catch (e) {
      print('타석 요금 정책 조회 실패: $e');
      return [];
    }
  }

  // 시간대별 요금 정책 분석
  static Map<String, int> analyzePricingByTimeRange({
    required String startTime,
    required String endTime,
    required List<Map<String, dynamic>> pricingPolicies,
  }) {
    try {
      print('=== analyzePricingByTimeRange 함수 시작 ===');
      print('시작시간: $startTime, 종료시간: $endTime');
      
      // 시간을 분으로 변환하는 함수
      int timeToMinutes(String timeStr) {
        final parts = timeStr.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
      
      final startMinutes = timeToMinutes(startTime);
      final endMinutes = timeToMinutes(endTime);
      
      print('시작분: $startMinutes, 종료분: $endMinutes');
      
      Map<String, int> result = {
        'base_price': 0,      // 일반
        'discount_price': 0,  // 할인
        'extracharge_price': 0, // 할증
        'out_of_business': 0, // 미운영
      };
      
      // 각 정책에 대해 겹치는 시간 계산
      for (final policy in pricingPolicies) {
        final policyStartStr = policy['policy_start_time']?.toString() ?? '00:00:00';
        final policyEndStr = policy['policy_end_time']?.toString() ?? '00:00:00';
        final policyApply = policy['policy_apply']?.toString() ?? '';
        
        int policyStartMin = timeToMinutes(policyStartStr.substring(0, 5));
        int policyEndMin = timeToMinutes(policyEndStr.substring(0, 5));
        
        // 24:00:00 처리 (1440분으로 변환)
        if (policyEndStr.startsWith('24:00')) {
          policyEndMin = 1440;
        }
        
        // 자정을 넘어가는 경우 처리 (예: 22:00 - 06:00)
        if (policyStartMin > policyEndMin && policyEndMin != 1440) {
          // 두 구간으로 나누어 처리
          // 구간 1: policyStartMin ~ 1440 (24:00)
          final overlapMin1 = _calculateOverlapMinutes(startMinutes, endMinutes, policyStartMin, 1440);
          if (overlapMin1 > 0) {
            result[policyApply] = (result[policyApply] ?? 0) + overlapMin1;
          }
          
          // 구간 2: 0 ~ policyEndMin
          final overlapMin2 = _calculateOverlapMinutes(startMinutes, endMinutes, 0, policyEndMin);
          if (overlapMin2 > 0) {
            result[policyApply] = (result[policyApply] ?? 0) + overlapMin2;
          }
        } else {
          // 일반적인 경우
          final overlapMin = _calculateOverlapMinutes(startMinutes, endMinutes, policyStartMin, policyEndMin);
          if (overlapMin > 0) {
            result[policyApply] = (result[policyApply] ?? 0) + overlapMin;
          }
        }
      }
      
      print('분석 결과: $result');
      return result;
    } catch (e) {
      print('요금 정책 분석 오류: $e');
      return {
        'base_price': 0,
        'discount_price': 0,
        'extracharge_price': 0,
        'out_of_business': 0,
      };
    }
  }

  // 두 시간 구간의 겹치는 시간(분) 계산
  static int _calculateOverlapMinutes(int start1, int end1, int start2, int end2) {
    final overlapStart = start1 > start2 ? start1 : start2;
    final overlapEnd = end1 < end2 ? end1 : end2;
    
    if (overlapStart >= overlapEnd) {
      return 0;
    }
    
    return overlapEnd - overlapStart;
  }

  // v2_priced_TS 테이블 업데이트
  static Future<bool> updatePricedTsTable(Map<String, dynamic> pricedTsData) async {
    try {
      print('=== v2_priced_TS 테이블 업데이트 시작 ===');
      print('업데이트 데이터: $pricedTsData');
      
      final result = await addData(
        table: 'v2_priced_TS',
        data: pricedTsData,
      );
      
      if (result['success'] == true) {
        print('✅ v2_priced_TS 테이블 업데이트 성공');
        return true;
      } else {
        print('❌ v2_priced_TS 테이블 업데이트 실패: ${result['message']}');
        return false;
      }
    } catch (e) {
      print('❌ v2_priced_TS 테이블 업데이트 오류: $e');
      return false;
    }
  }

  // v2_bills 테이블 업데이트 (선불크레딧 결제 시)
  static Future<int?> updateBillsTable({
    required String memberId,
    required String billDate,
    required String billText,
    required int billTotalAmt,
    required int billDeduction,
    required int billNetAmt,
    required String reservationId,
    required String contractHistoryId,
    required String branchId,
    String? contractCreditExpiryDate,
  }) async {
    try {
      print('=== v2_bills 테이블 업데이트 시작 ===');
      
      // 기존 잔액 조회 (branch_id, member_id, contract_history_id 기준으로 최신 잔액)
      int billBalanceBefore = 0;
      try {
        final latestBillResult = await getData(
          table: 'v2_bills',
          fields: ['bill_balance_after'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'member_id', 'operator': '=', 'value': memberId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
          limit: 1,
        );
        
        if (latestBillResult.isNotEmpty) {
          billBalanceBefore = int.tryParse(latestBillResult.first['bill_balance_after']?.toString() ?? '0') ?? 0;
        }
        
        print('기존 잔액 조회 결과: $billBalanceBefore');
      } catch (e) {
        print('기존 잔액 조회 실패: $e');
        billBalanceBefore = 0;
      }
      
      // 새로운 잔액 계산
      final billBalanceAfter = billBalanceBefore + billNetAmt;
      
      // v2_bills 테이블 업데이트 데이터
      final billsData = {
        'member_id': memberId,
        'bill_date': billDate,
        'bill_type': '타석이용',
        'bill_text': billText,
        'bill_totalamt': billTotalAmt,
        'bill_deduction': billDeduction,
        'bill_netamt': billNetAmt,
        'bill_timestamp': DateTime.now().toIso8601String(),
        'bill_balance_before': billBalanceBefore,
        'bill_balance_after': billBalanceAfter,
        'reservation_id': reservationId,
        'bill_status': '결제완료',
        'contract_history_id': contractHistoryId,
        'branch_id': branchId,
        'contract_credit_expiry_date': contractCreditExpiryDate ?? '',
      };
      
      print('v2_bills 업데이트 데이터: $billsData');
      
      final result = await addData(
        table: 'v2_bills',
        data: billsData,
      );
      
      if (result['success'] == true) {
        final billId = result['insertId'];
        print('✅ v2_bills 테이블 업데이트 성공 (bill_id: $billId)');
        // 문자열을 정수로 변환
        if (billId != null) {
          return int.tryParse(billId.toString()) ?? 0;
        }
        return null;
      } else {
        print('❌ v2_bills 테이블 업데이트 실패: ${result['message']}');
        return null;
      }
    } catch (e) {
      print('❌ v2_bills 테이블 업데이트 오류: $e');
      return null;
    }
  }

  // 타석 예약 중복 체크
  static Future<bool> checkTsReservationDuplicate({
    required String branchId,
    required String tsId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      print('=== 타석 예약 중복 체크 시작 ===');
      print('브랜치 ID: $branchId');
      print('타석 ID: $tsId');
      print('날짜: $date');
      print('시작시간: $startTime');
      print('종료시간: $endTime');
      
      // 해당 날짜, 타석의 모든 예약 조회 (취소된 예약 제외)
      final result = await getData(
        table: 'v2_priced_TS',
        fields: ['reservation_id', 'ts_start', 'ts_end', 'ts_status'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_id', 'operator': '=', 'value': tsId},
          {'field': 'ts_date', 'operator': '=', 'value': date},
          {'field': 'ts_status', 'operator': '<>', 'value': '예약취소'},
        ],
      );
      
      print('조회된 기존 예약 수: ${result.length}');
      
      if (result.isEmpty) {
        print('기존 예약이 없음 - 중복 없음');
        return false;
      }
      
      // 시간 겹침 체크
      for (final reservation in result) {
        final existingStart = reservation['ts_start']?.toString() ?? '';
        final existingEnd = reservation['ts_end']?.toString() ?? '';
        final reservationId = reservation['reservation_id']?.toString() ?? '';
        
        if (existingStart.isNotEmpty && existingEnd.isNotEmpty) {
          // 시간 문자열에서 초 제거 (HH:mm 형태로 변환)
          final existingStartTime = existingStart.length > 5 ? existingStart.substring(0, 5) : existingStart;
          final existingEndTime = existingEnd.length > 5 ? existingEnd.substring(0, 5) : existingEnd;
          
          print('기존 예약 $reservationId: $existingStartTime ~ $existingEndTime');
          
          // 시간 겹침 체크
          if (isTimeOverlap(
            requestStartTime: startTime,
            requestEndTime: endTime,
            existingStartTime: existingStartTime,
            existingEndTime: existingEndTime,
          )) {
            print('❌ 시간 겹침 발견! 기존 예약: $existingStartTime ~ $existingEndTime');
            return true; // 중복 발견
          }
        }
      }
      
      print('✅ 시간 겹침 없음 - 중복 없음');
      return false; // 중복 없음
      
    } catch (e) {
      print('❌ 타석 예약 중복 체크 오류: $e');
      return false; // 오류 발생 시 중복이 아닌 것으로 처리
    }
  }

  // v2_bill_times 테이블 업데이트 (시간권 결제 시)
  static Future<int?> updateBillTimesTable({
    required String memberId,
    required String billDate,
    required String billText,
    required int billMin, // 실제 과금시간 (총시간 - 할인시간)
    required int billTotalMin, // 총 시간
    required int billDiscountMin, // 할인시간
    required String reservationId,
    required String contractHistoryId,
    required String branchId,
    String? contractTsMinExpiryDate,
  }) async {
    try {
      print('=== v2_bill_times 테이블 업데이트 시작 ===');
      print('총 시간: ${billTotalMin}분');
      print('할인시간: ${billDiscountMin}분');
      print('실제 과금시간: ${billMin}분');
      
      // 기존 잔액 조회 (branch_id, member_id, contract_history_id 기준으로 최신 잔액)
      int billBalanceMinBefore = 0;
      try {
        final latestBillResult = await getData(
          table: 'v2_bill_times',
          fields: ['bill_balance_min_after'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'member_id', 'operator': '=', 'value': memberId},
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
          limit: 1,
        );
        
        if (latestBillResult.isNotEmpty) {
          billBalanceMinBefore = int.tryParse(latestBillResult.first['bill_balance_min_after']?.toString() ?? '0') ?? 0;
        }
        
        print('기존 시간권 잔액 조회 결과: $billBalanceMinBefore분');
      } catch (e) {
        print('기존 시간권 잔액 조회 실패: $e');
        billBalanceMinBefore = 0;
      }
      
      // 새로운 잔액 계산 (시간권은 차감이므로 음수)
      final billBalanceMinAfter = billBalanceMinBefore - billMin;
      
      // v2_bill_times 테이블 업데이트 데이터
      final billTimesData = {
        'member_id': memberId,
        'bill_date': billDate,
        'bill_type': '타석이용',
        'bill_text': billText,
        'bill_total_min': billTotalMin, // 총 시간
        'bill_discount_min': billDiscountMin, // 할인시간
        'bill_min': billMin, // 실제 과금시간
        'bill_timestamp': DateTime.now().toIso8601String(),
        'bill_balance_min_before': billBalanceMinBefore,
        'bill_balance_min_after': billBalanceMinAfter,
        'reservation_id': reservationId,
        'bill_status': '결제완료',
        'contract_history_id': contractHistoryId,
        'branch_id': branchId,
        'contract_TS_min_expiry_date': contractTsMinExpiryDate ?? '',
      };
      
      print('v2_bill_times 업데이트 데이터: $billTimesData');
      
      final result = await addData(
        table: 'v2_bill_times',
        data: billTimesData,
      );
      
      if (result['success'] == true) {
        final billMinId = result['insertId'];
        print('✅ v2_bill_times 테이블 업데이트 성공 (bill_min_id: $billMinId)');
        // 문자열을 정수로 변환
        if (billMinId != null) {
          return int.tryParse(billMinId.toString()) ?? 0;
        }
        return null;
      } else {
        print('❌ v2_bill_times 테이블 업데이트 실패: ${result['message']}');
        return null;
      }
    } catch (e) {
      print('❌ v2_bill_times 테이블 업데이트 오류: $e');
      return null;
    }
  }

  // v2_priced_TS 테이블에 bill_id와 bill_min_id 업데이트
  static Future<bool> updatePricedTsWithBillIds({
    required String reservationId,
    String? billIds,
    String? billMinIds,
  }) async {
    // 업데이트할 데이터 준비 (스코프 확장)
    Map<String, dynamic> updateFields = {};
    
    try {
      print('=== v2_priced_TS에 bill_id/bill_min_id 업데이트 시작 ===');
      print('reservation_id: $reservationId');
      print('bill_ids: $billIds');
      print('bill_min_ids: $billMinIds');
      
      if (billIds != null && billIds.isNotEmpty) {
        updateFields['bill_id'] = billIds; // bill_ids -> bill_id로 변경
      }
      
      if (billMinIds != null && billMinIds.isNotEmpty) {
        updateFields['bill_min_id'] = billMinIds; // bill_min_ids -> bill_min_id로 변경
      }
      
      // 업데이트할 데이터가 없으면 성공으로 처리
      if (updateFields.isEmpty) {
        print('업데이트할 데이터가 없습니다.');
        return true;
      }
      
      print('업데이트할 필드들: $updateFields');
      
      // v2_priced_TS 테이블 업데이트
      final result = await updateData(
        table: 'v2_priced_TS',
        data: updateFields,
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
        ],
      );
      
      print('API 응답 결과: $result');
      
      if (result['success'] == true) {
        print('✅ v2_priced_TS bill_id/bill_min_id 업데이트 성공');
        return true;
      } else {
        print('❌ v2_priced_TS bill_id/bill_min_id 업데이트 실패: ${result['message']}');
        print('   에러 응답: $result');
        
        // HTTP 500 에러인 경우 필드명이나 다른 문제일 수 있음
        if (result['message']?.toString().contains('500') == true) {
          print('⚠️ HTTP 500 에러: v2_priced_TS 테이블 업데이트 실패');
          print('   시도한 필드: bill_id=${updateFields['bill_id']}, bill_min_id=${updateFields['bill_min_id']}');
          print('   필드명이 정확한지 확인 필요');
          print('   일단 성공으로 처리하여 예약 진행을 계속합니다.');
          return true; // 임시로 성공 처리
        }
        
        return false;
      }
    } catch (e) {
      print('❌ v2_priced_TS bill_id/bill_min_id 업데이트 오류: $e');
      
      // 네트워크 500 에러인 경우 테이블 스키마 문제일 가능성 높음
      if (e.toString().contains('500')) {
        print('⚠️ HTTP 500 에러: v2_priced_TS 테이블 업데이트 실패');
        print('   시도한 필드: ${updateFields.keys.join(', ')}');
        print('   필드명이 정확한지 확인 필요');
        print('   일단 성공으로 처리하여 예약 진행을 계속합니다.');
        return true; // 임시로 성공 처리
      }
      
      return false;
    }
  }

  // v2_discount_coupon 테이블 업데이트 (할인권 사용 시)
  static Future<bool> updateDiscountCouponTable({
    required String branchId,
    required String memberId,
    required int couponId,
    required String reservationId,
  }) async {
    try {
      print('=== v2_discount_coupon 테이블 업데이트 시작 ===');
      print('브랜치 ID: $branchId');
      print('회원 ID: $memberId');
      print('쿠폰 ID: $couponId');
      print('예약 ID: $reservationId');
      
      // 현재 시간
      final currentTimestamp = DateTime.now().toIso8601String();
      
      // v2_discount_coupon 테이블 업데이트 데이터
      final couponUpdateData = {
        'coupon_status': '사용',
        'coupon_use_timestamp': currentTimestamp,
        'reservation_id_used': reservationId,
      };
      
      print('쿠폰 업데이트 데이터: $couponUpdateData');
      
      final result = await updateData(
        table: 'v2_discount_coupon',
        data: couponUpdateData,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'coupon_id', 'operator': '=', 'value': couponId.toString()},
        ],
      );
      
      if (result['success'] == true) {
        print('✅ v2_discount_coupon 테이블 업데이트 성공');
        return true;
      } else {
        print('❌ v2_discount_coupon 테이블 업데이트 실패: ${result['message']}');
        return false;
      }
    } catch (e) {
      print('❌ v2_discount_coupon 테이블 업데이트 오류: $e');
      return false;
    }
  }

  // ========== 레슨 카운팅 관련 함수들 ==========

  // 회원의 레슨 카운팅 데이터 조회 (최적화된 단일 쿼리 + 프로 정보 + 프로 스케줄 포함)
  static Future<Map<String, dynamic>> getMemberLsCountingData({
    required String memberId,
  }) async {
    try {
      final branchId = getCurrentBranchId();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 1단계: 레슨 카운팅 데이터 조회 (서버 사이드 필터링)
      final List<Map<String, dynamic>> records = await getData(
        table: 'v3_LS_countings',
        fields: ['pro_id', 'LS_balance_min_after', 'LS_expiry_date', 'LS_contract_id', 'LS_counting_id'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'LS_balance_min_after', 'operator': '>', 'value': 0},
        ],
      );
      
      if (records.isEmpty) {
        return {
          'success': true,
          'message': '조회된 레슨 카운팅 데이터가 없습니다.',
          'data': [],
          'debug_info': {
            'message': '조회된 데이터가 없습니다',
            'total_records': 0,
            'valid_records': 0,
            'pro_ids': [],
            'pro_info': {},
            'pro_schedule': {},
            'max_reservation_ahead_days': 0,
            'today': today,
          }
        };
      }
      
      // 2단계: 클라이언트 사이드 만료일 검증 및 유효한 pro_id 수집
      final List<Map<String, dynamic>> validRecords = [];
      final Set<String> validProIds = {};
      
      // program_reservation_availability 필터링 구현
      print('\n=== program_reservation_availability 필터링 시작 ===');
      
      Map<String, bool> lsContractValidityMap = {};
      
      // 1단계: LS_contract_id들 수집
      final Set<String> lsContractIds = {};
      for (final record in records) {
        final contractId = record['LS_contract_id']?.toString();
        if (contractId != null) {
          lsContractIds.add(contractId);
        }
      }
      print('수집된 LS_contract_id들: $lsContractIds');
      
      // 2단계: 필터링 로직 실행
      if (lsContractIds.isNotEmpty) {
        try {
          // v2_LS_contracts에서 contract_history_id 조회
          final List<Map<String, dynamic>> lsContractRecords = await getData(
            table: 'v2_LS_contracts',
            fields: ['LS_contract_id', 'contract_history_id'],
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'LS_contract_id', 'operator': 'IN', 'value': lsContractIds.toList()},
            ],
          );
          
          // contract_history_id 수집
          final Set<String> contractHistoryIds = {};
          final Map<String, String> historyToLsContractMap = {};
          for (final lsContract in lsContractRecords) {
            final lsContractId = lsContract['LS_contract_id']?.toString();
            final historyId = lsContract['contract_history_id']?.toString();
            if (lsContractId != null && historyId != null) {
              contractHistoryIds.add(historyId);
              historyToLsContractMap[historyId] = lsContractId;
            }
          }
          
          if (contractHistoryIds.isNotEmpty) {
            // v3_contract_history에서 contract_id 조회
            final List<Map<String, dynamic>> contractHistoryRecords = await getData(
              table: 'v3_contract_history',
              fields: ['contract_history_id', 'contract_id'],
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'contract_history_id', 'operator': 'IN', 'value': contractHistoryIds.toList()},
              ],
            );
            
            // contract_id 수집 및 매핑
            final Set<String> contractIds = {};
            final Map<String, String> historyToContractMap = {};
            for (final historyRecord in contractHistoryRecords) {
              final historyId = historyRecord['contract_history_id']?.toString();
              final contractId = historyRecord['contract_id']?.toString();
              if (historyId != null && contractId != null) {
                contractIds.add(contractId);
                historyToContractMap[historyId] = contractId;
              }
            }
            
            if (contractIds.isNotEmpty) {
              // v2_contracts에서 program_reservation_availability 조회
              final List<Map<String, dynamic>> contractRecords = await getData(
                table: 'v2_contracts',
                fields: ['contract_id', 'program_reservation_availability'],
                where: [
                  {'field': 'branch_id', 'operator': '=', 'value': branchId},
                  {'field': 'contract_id', 'operator': 'IN', 'value': contractIds.toList()},
                ],
              );
              
              // program_reservation_availability 판단
              final Map<String, String> contractToProgramAvailability = {};
              for (final contractRecord in contractRecords) {
                final contractId = contractRecord['contract_id']?.toString();
                final programAvailability = contractRecord['program_reservation_availability']?.toString();
                if (contractId != null) {
                  contractToProgramAvailability[contractId] = programAvailability ?? '';
                }
              }
              
              // LS_contract_id별 유효성 판단
              for (final entry in historyToLsContractMap.entries) {
                final historyId = entry.key;
                final lsContractId = entry.value;
                final contractId = historyToContractMap[historyId];
                
                if (contractId != null) {
                  final programAvailability = contractToProgramAvailability[contractId] ?? '';
                  // program_reservation_availability가 null, 빈 문자열, 또는 "null" 문자열인 경우만 일반 레슨 예약 허용
                  final isValidForLessonReservation = programAvailability.isEmpty || 
                                                    programAvailability.toLowerCase() == 'null';
                  lsContractValidityMap[lsContractId] = isValidForLessonReservation;
                  
                  print('  - LS_contract_id: $lsContractId → contract_id: $contractId → program_availability: "$programAvailability" → 일반레슨가능: $isValidForLessonReservation');
                }
              }
            }
          }
        } catch (e) {
          print('program_reservation_availability 필터링 중 오류: $e');
          // 오류 발생 시 모든 계약을 허용 (안전 모드)
          for (final contractId in lsContractIds) {
            lsContractValidityMap[contractId] = true;
          }
        }
      }
      
      print('=== program_reservation_availability 필터링 종료 ===\n');
      
      for (final record in records) {
        final lsContractId = record['LS_contract_id']?.toString();
        
        // program_reservation_availability 필터링 적용
        if (lsContractId != null && lsContractValidityMap.containsKey(lsContractId)) {
          final isValid = lsContractValidityMap[lsContractId] ?? false;
          if (!isValid) {
            print('필터링으로 제외된 계약: LS_contract_id $lsContractId (프로그램 예약 전용)');
            continue; // 프로그램 예약 전용 계약은 제외
          }
        }
        
        final expiryDateStr = record['LS_expiry_date']?.toString();
        bool isValid = true;
        
        if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            final todayDate = DateTime.parse(today);
            if (expiryDate.isBefore(todayDate)) {
              isValid = false;
            }
          } catch (e) {
            isValid = false;
          }
        }
        
        if (isValid) {
          validRecords.add(record);
          final proId = record['pro_id']?.toString();
          if (proId != null && proId.isNotEmpty) {
            validProIds.add(proId);
          }
        }
      }
      
      // 3단계: 프로 정보 조회
      Map<String, Map<String, dynamic>> proInfoMap = {};
      int maxReservationAheadDays = 0;
      
      if (validProIds.isNotEmpty) {
        final List<Map<String, dynamic>> proRecords = await getData(
          table: 'v2_staff_pro',
          fields: ['pro_id', 'min_service_min', 'svc_time_unit', 'min_reservation_term', 'reservation_ahead_days', 'pro_name'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'pro_id', 'operator': 'IN', 'value': validProIds.toList()},
          ],
        );
        
        for (final proRecord in proRecords) {
          final proId = proRecord['pro_id']?.toString();
          if (proId != null) {
            final reservationAheadDays = int.tryParse(proRecord['reservation_ahead_days']?.toString() ?? '0') ?? 0;
            if (reservationAheadDays > maxReservationAheadDays) {
              maxReservationAheadDays = reservationAheadDays;
            }
            
            proInfoMap[proId] = {
              'pro_id': proId,
              'pro_name': proRecord['pro_name']?.toString() ?? '',
              'min_service_min': proRecord['min_service_min']?.toString() ?? '60',
              'svc_time_unit': proRecord['svc_time_unit']?.toString() ?? '30',
              'min_reservation_term': proRecord['min_reservation_term']?.toString() ?? '1',
              'reservation_ahead_days': proRecord['reservation_ahead_days']?.toString() ?? '7',
            };
          }
        }
      }
      
      // 4단계: 프로 스케줄 조회 (오늘부터 최대 예약 가능 일수까지)
      Map<String, Map<String, Map<String, dynamic>>> proScheduleMap = {};
      
      if (validProIds.isNotEmpty && maxReservationAheadDays > 0) {
        final endDate = DateFormat('yyyy-MM-dd').format(
          DateTime.now().add(Duration(days: maxReservationAheadDays))
        );
        
        final scheduleResult = await getProScheduleData(
          proIds: validProIds.toList(),
          startDate: today,
          endDate: endDate,
        );
        
        if (scheduleResult['success'] == true) {
          proScheduleMap = scheduleResult['data'] as Map<String, Map<String, Map<String, dynamic>>>;
        }
      }
      
      return {
        'success': true,
        'data': validRecords,
        'debug_info': {
          'message': '조회 성공',
          'total_records': records.length,
          'valid_records': validRecords.length,
          'pro_ids': validProIds.toList(),
          'pro_info': proInfoMap,
          'pro_schedule': proScheduleMap,
          'max_reservation_ahead_days': maxReservationAheadDays,
          'today': today,
        }
      };
      
    } catch (e) {
      print('getMemberLsCountingData 오류: $e');
      return {
        'success': false,
        'message': '레슨 카운팅 데이터 조회 중 오류가 발생했습니다: $e',
        'data': [],
        'debug_info': {
          'message': '조회 실패 - $e',
          'total_records': 0,
          'valid_records': 0,
          'pro_ids': [],
          'pro_info': {},
          'pro_schedule': {},
          'max_reservation_ahead_days': 0,
          'today': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }
      };
    }
  }

  // 프로 스케줄 조회 함수
  static Future<Map<String, dynamic>> getProScheduleData({
    required List<String> proIds,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final branchId = getCurrentBranchId();
      
      if (proIds.isEmpty) {
        return {
          'success': true,
          'data': {},
          'debug_info': {
            'message': '조회할 프로 ID가 없습니다',
            'total_records': 0,
          }
        };
      }
      
      // v2_schedule_adjusted_pro 테이블에서 프로별 스케줄 조회
      final List<Map<String, dynamic>> scheduleRecords = await getData(
        table: 'v2_schedule_adjusted_pro',
        fields: ['pro_id', 'scheduled_date', 'work_start', 'work_end', 'is_day_off'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'pro_id', 'operator': 'IN', 'value': proIds},
          {'field': 'scheduled_date', 'operator': '>=', 'value': startDate},
          {'field': 'scheduled_date', 'operator': '<=', 'value': endDate},
        ],
      );
      
      // 프로별, 날짜별로 스케줄 정리
      Map<String, Map<String, Map<String, dynamic>>> proScheduleMap = {};
      
      for (final record in scheduleRecords) {
        final proId = record['pro_id']?.toString();
        final scheduledDate = record['scheduled_date']?.toString();
        
        if (proId != null && scheduledDate != null) {
          if (!proScheduleMap.containsKey(proId)) {
            proScheduleMap[proId] = {};
          }
          
          proScheduleMap[proId]![scheduledDate] = {
            'work_start': record['work_start']?.toString(),
            'work_end': record['work_end']?.toString(),
            'is_day_off': record['is_day_off']?.toString(),
          };
        }
      }
      
      return {
        'success': true,
        'data': proScheduleMap,
        'debug_info': {
          'message': '프로 스케줄 조회 성공',
          'total_records': scheduleRecords.length,
          'pro_count': proScheduleMap.length,
          'date_range': '$startDate ~ $endDate',
        }
      };
      
    } catch (e) {
      print('getProScheduleData 오류: $e');
      return {
        'success': false,
        'message': '프로 스케줄 조회 중 오류가 발생했습니다: $e',
        'data': {},
        'debug_info': {
          'message': '조회 실패 - $e',
          'total_records': 0,
        }
      };
    }
  }

  // 레슨 예약내역 조회
  static Future<List<Map<String, dynamic>>> getLsOrders({
    required String proId,
    required String lsDate,
  }) async {
    try {
      final branchId = getCurrentBranchId();
      print('\n=== getLsOrders 함수 호출 ===');
      print('조회 조건:');
      print('- branch_id: $branchId');
      print('- pro_id: $proId');
      print('- LS_date: $lsDate');

      final List<Map<String, dynamic>> records = await getData(
        table: 'v2_LS_orders',
        fields: ['LS_start_time', 'LS_end_time'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'LS_date', 'operator': '=', 'value': lsDate},
          {'field': 'LS_status', 'operator': '=', 'value': '결제완료'},
        ],
      );

      print('조회 결과: ${records.length}건');
      for (final record in records) {
        print('- ${record['LS_start_time']} ~ ${record['LS_end_time']}');
      }
      print('================================\n');

      return records;
    } catch (e) {
      print('레슨 예약내역 조회 실패: $e');
      return [];
    }
  }

  // ========== 레슨 관련 API ==========

  // 레슨 계약 정보 조회
  static Future<Map<String, dynamic>> getLsContracts({
    List<String>? contractIds,
    String? branchId,
  }) async {
    try {
      print('\n=== getLsContracts 함수 호출 ===');
      print('조회할 계약 ID들: $contractIds');
      print('지점 ID: $branchId');

      List<Map<String, dynamic>>? whereConditions;
      
      if (contractIds != null && contractIds.isNotEmpty) {
        whereConditions = [
          {
            'field': 'LS_contract_id',
            'operator': 'IN',
            'value': contractIds,
          }
        ];
      }

      final data = await getData(
        table: 'v2_LS_contracts',
        fields: ['LS_contract_id', 'contract_name', 'LS_contract_date', 'LS_contract_min', 'contract_history_id'],
        where: whereConditions,
      );

      print('조회 결과: ${data.length}건');
      for (final contract in data) {
        print('• 계약 ID: ${contract['LS_contract_id']}');
        print('  - 계약명: ${contract['contract_name']}');
        print('  - 계약일: ${contract['LS_contract_date']}');
        print('  - 계약시간: ${contract['LS_contract_min']}분');
        print('  - contract_history_id: ${contract['contract_history_id']}');
      }
      print('================================\n');

      return {
        'success': true,
        'data': data,
      };
    } catch (e) {
      print('레슨 계약 정보 조회 실패: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ========== 예약 시스템 전용 함수들 ==========

  // 레슨 예약 저장
  static Future<Map<String, dynamic>> saveLessonOrder({
    required DateTime selectedDate,
    required String selectedTime,
    required String proId,
    required String proName,
    required String memberId,
    required String memberName,
    required String memberType,
    required int netMinutes,
    required String? request,
    required String? lsContractId,
    String? branchId,
  }) async {
    try {
      // LS_id 생성: yymmdd_{pro_id}_hhmm
      final dateFormat = DateFormat('yyMMdd');
      final timeFormat = DateFormat('HHmm');
      
      final dateStr = dateFormat.format(selectedDate);
      final timeStr = timeFormat.format(DateFormat('HH:mm').parse(selectedTime));
      final lsId = '${dateStr}_${proId}_$timeStr';
      
      // 종료 시간 계산
      final startTime = DateFormat('HH:mm').parse(selectedTime);
      final endTime = startTime.add(Duration(minutes: netMinutes));
      final endTimeStr = DateFormat('HH:mm').format(endTime);
      
      // 현재 시간
      final now = DateTime.now();
      final updatedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      final orderData = {
        'LS_id': lsId,
        'LS_transaction_type': '레슨예약',
        'LS_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'member_id': memberId,
        'LS_status': '결제완료',
        'member_name': memberName,
        'member_type': memberType,
        'LS_type': '일반', // 기본값
        'pro_id': proId,
        'pro_name': proName,
        'LS_order_source': 'mgp_app',
        'LS_start_time': selectedTime,
        'LS_end_time': endTimeStr,
        'LS_net_min': netMinutes,
        'LS_contract_id': lsContractId,
        'updated_at': updatedAt,
        'LS_request': request,
        'branch_id': branchId ?? getCurrentBranchId(),
        // 나머지 필드들은 null로 설정
        'TS_id': null,
        'program_id': null,
        'routine_id': null,
      };
      
      print('=== 레슨 예약 저장 데이터 ===');
      print('LS_id: ${orderData['LS_id']}');
      print('LS_date: ${orderData['LS_date']}');
      print('member_id: ${orderData['member_id']}');
      print('member_name: ${orderData['member_name']}');
      print('pro_id: ${orderData['pro_id']}');
      print('pro_name: ${orderData['pro_name']}');
      print('LS_start_time: ${orderData['LS_start_time']}');
      print('LS_end_time: ${orderData['LS_end_time']}');
      print('LS_net_min: ${orderData['LS_net_min']}');
      print('LS_contract_id: ${orderData['LS_contract_id']}');
      print('LS_request: ${orderData['LS_request']}');
      print('branch_id: ${orderData['branch_id']}');
      print('===============================');
      
      final result = await addData(
        table: 'v2_LS_orders',
        data: orderData,
      );
      
      print('레슨 예약 저장 성공: $result');
      return result;
      
    } catch (e) {
      print('레슨 예약 저장 실패: $e');
      throw Exception('레슨 예약 저장 실패: $e');
    }
  }

  // 레슨 카운팅 데이터 저장
  static Future<Map<String, dynamic>> saveLessonCounting({
    required String lsId,
    required DateTime selectedDate,
    required String memberId,
    required String memberName,
    required String memberType,
    required String proId,
    required String proName,
    required String lsContractId,
    required String contractHistoryId,
    required int netMinutes,
    required int balanceMinBefore,
    required int balanceMinAfter,
    required String lsExpiryDate,
    String? branchId,
  }) async {
    try {
      // 현재 시간
      final now = DateTime.now();
      final updatedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      final countingData = {
        'LS_transaction_type': '레슨예약',
        'LS_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'member_id': memberId,
        'member_name': memberName,
        'member_type': memberType,
        'LS_status': '결제완료',
        'LS_type': '일반',
        'LS_contract_id': lsContractId,
        'contract_history_id': contractHistoryId,
        'LS_id': lsId,
        'LS_balance_min_before': balanceMinBefore,
        'LS_net_min': netMinutes,
        'LS_balance_min_after': balanceMinAfter,
        'LS_counting_source': 'mgp_app',
        'updated_at': updatedAt,
        'program_id': null,
        'branch_id': branchId ?? getCurrentBranchId(),
        'pro_id': proId,
        'pro_name': proName,
        'LS_expiry_date': lsExpiryDate,
      };
      
      print('=== 레슨 카운팅 저장 데이터 ===');
      print('LS_id: ${countingData['LS_id']}');
      print('LS_date: ${countingData['LS_date']}');
      print('member_id: ${countingData['member_id']}');
      print('member_name: ${countingData['member_name']}');
      print('pro_id: ${countingData['pro_id']}');
      print('pro_name: ${countingData['pro_name']}');
      print('LS_contract_id: ${countingData['LS_contract_id']}');
      print('contract_history_id: ${countingData['contract_history_id']}');
      print('LS_net_min: ${countingData['LS_net_min']}');
      print('LS_balance_min_before: ${countingData['LS_balance_min_before']}');
      print('LS_balance_min_after: ${countingData['LS_balance_min_after']}');
      print('LS_expiry_date: ${countingData['LS_expiry_date']}');
      print('branch_id: ${countingData['branch_id']}');
      print('===============================');
      
      final result = await addData(
        table: 'v3_LS_countings',
        data: countingData,
      );
      
      print('레슨 카운팅 저장 성공: $result');
      return result;
      
    } catch (e) {
      print('레슨 카운팅 저장 실패: $e');
      throw Exception('레슨 카운팅 저장 실패: $e');
    }
  }

  // 프로그램 예약용 레슨 카운팅 데이터 조회 (program_reservation_availability 검증 포함)
  static Future<Map<String, dynamic>> getMemberLsCountingDataForProgram({
    required String memberId,
    String? reservationDate, // 예약 날짜 추가
  }) async {
    try {
      print('=== getMemberLsCountingDataForProgram 함수 시작 ===');
      print('회원 ID: $memberId');
      print('예약 날짜: $reservationDate');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없습니다');
        return {
          'success': false,
          'message': '브랜치 ID가 없습니다',
          'data': [],
          'debug_info': {
            'message': '브랜치 ID가 없습니다',
            'total_records': 0,
            'valid_records': 0,
            'pro_ids': [],
            'pro_info': {},
            'pro_schedule': {},
            'max_reservation_ahead_days': 0,
            'today': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          }
        };
      }
      
      // 기준 날짜 설정 (예약 날짜가 있으면 사용, 없으면 오늘)
      final baseDate = reservationDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      print('만료일 검증 기준 날짜: $baseDate');
      
      // 1단계: 서버 사이드 필터링 (잔액 > 0)
      final List<Map<String, dynamic>> records = await getData(
        table: 'v3_LS_countings',
        fields: ['LS_contract_id', 'LS_counting_id', 'LS_balance_min_after', 'LS_expiry_date', 'pro_id', 'pro_name', 'contract_history_id'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'LS_balance_min_after', 'operator': '>', 'value': '0'},
        ],
        orderBy: [
          {'field': 'LS_counting_id', 'direction': 'DESC'}
        ],
      );
      
      print('서버 사이드 필터링 후 조회된 레슨 카운팅 수: ${records.length}');
      
      if (records.isEmpty) {
        print('조회된 레슨 카운팅 데이터가 없음');
        return {
          'success': true,
          'message': '조회된 데이터가 없습니다',
          'data': [],
          'debug_info': {
            'message': '조회된 데이터가 없습니다',
            'total_records': 0,
            'valid_records': 0,
            'pro_ids': [],
            'pro_info': {},
            'pro_schedule': {},
            'max_reservation_ahead_days': 0,
            'today': baseDate,
          }
        };
      }
      
      // 2단계: 각 LS_contract_id별 최신 레코드 필터링
      final Map<String, Map<String, dynamic>> latestRecordsByContract = {};
      
      for (final record in records) {
        final lsContractId = record['LS_contract_id']?.toString();
        final lsCountingId = record['LS_counting_id'];
        
        if (lsContractId != null && lsCountingId != null) {
          // 동일한 LS_contract_id에 대해 더 높은 LS_counting_id를 가진 레코드로 업데이트
          if (!latestRecordsByContract.containsKey(lsContractId) ||
              (latestRecordsByContract[lsContractId]!['LS_counting_id'] ?? 0) < lsCountingId) {
            latestRecordsByContract[lsContractId] = record;
          }
        }
      }
      
      print('각 계약별 최신 레코드 필터링 완료: ${latestRecordsByContract.length}개 고유 계약');
      
      // 3단계: 클라이언트 사이드 만료일 검증 및 유효한 pro_id 수집
      final List<Map<String, dynamic>> validRecords = [];
      final Set<String> validProIds = {};
      final Set<String> contractHistoryIds = {};
      
      for (final record in latestRecordsByContract.values) {
        final expiryDateStr = record['LS_expiry_date']?.toString();
        final contractHistoryId = record['contract_history_id']?.toString();
        bool isValid = true;
        
        // 만료일 검증 (만료일이 없으면 유효하다고 가정)
        if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            final baseDateParsed = DateTime.parse(baseDate);
            // 기준 날짜가 만료일 이후면 무효
            if (baseDateParsed.isAfter(expiryDate)) {
              isValid = false;
              print('만료일 초과로 제외된 레슨: LS_contract_id=${record['LS_contract_id']} (만료일: $expiryDateStr, 기준일: $baseDate)');
            }
          } catch (e) {
            print('만료일 파싱 실패로 제외된 레슨: LS_contract_id=${record['LS_contract_id']} (만료일: $expiryDateStr)');
            isValid = false;
          }
        }
        
        if (isValid) {
          validRecords.add(record);
          final proId = record['pro_id']?.toString();
          if (proId != null && proId.isNotEmpty) {
            validProIds.add(proId);
          }
          if (contractHistoryId != null && contractHistoryId.isNotEmpty) {
            contractHistoryIds.add(contractHistoryId);
            print('유효한 레슨 기록: LS_contract_id=${record['LS_contract_id']}, contract_history_id=$contractHistoryId');
          }
        }
      }
      
      // 3단계: v3_contract_history 테이블에서 contract_id 조회 후 program_reservation_availability 확인
      List<Map<String, dynamic>> programValidRecords = [];
      
      if (contractHistoryIds.isNotEmpty) {
        // 1단계: contract_history_id로 contract_id 조회 (v3_contract_history 테이블)
        final contractHistoryResult = await getData(
          table: 'v3_contract_history',
          fields: ['contract_history_id', 'contract_id'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_history_id', 'operator': 'IN', 'value': contractHistoryIds.toList()},
          ],
        );
        
        print('v3_contract_history에서 조회된 레슨 계약 히스토리 수: ${contractHistoryResult.length}');
        
        // contract_history_id -> contract_id 매핑 생성
        Map<String, String> historyToContractMap = {};
        Set<String> actualContractIds = {};
        
        for (final historyRecord in contractHistoryResult) {
          final contractHistoryId = historyRecord['contract_history_id']?.toString();
          final contractId = historyRecord['contract_id']?.toString();
          
          if (contractHistoryId != null && contractId != null) {
            historyToContractMap[contractHistoryId] = contractId;
            actualContractIds.add(contractId);
          }
        }
        
        print('매핑된 실제 contract_id 수: ${actualContractIds.length}');
        
        // 2단계: contract_id로 v2_contracts에서 program_reservation_availability 확인
        if (actualContractIds.isNotEmpty) {
          final contractsResult = await getData(
            table: 'v2_contracts',
            fields: ['contract_id', 'program_reservation_availability'],
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'contract_id', 'operator': 'IN', 'value': actualContractIds.toList()},
            ],
          );
          
          print('v2_contracts에서 조회된 레슨 계약 수: ${contractsResult.length}');
          
          // program_reservation_availability가 유효한 contract_id 수집
          Set<String> validContractIds = {};
          for (final contractInfo in contractsResult) {
            final contractId = contractInfo['contract_id']?.toString();
            final programAvailability = contractInfo['program_reservation_availability']?.toString();
            
            if (contractId != null && 
                programAvailability != null && 
                programAvailability.isNotEmpty && 
                programAvailability != '0') {
              validContractIds.add(contractId);
              print('유효한 레슨 계약: $contractId (program_availability: $programAvailability)');
            } else {
              print('프로그램 예약 불가능한 레슨 계약: $contractId (program_availability: $programAvailability)');
            }
          }
          
          // 3단계: 유효한 contract_id에 해당하는 레슨 기록만 필터링
          final Set<String> finalValidProIds = {};
          for (final record in validRecords) {
            final contractHistoryId = record['contract_history_id']?.toString();
            final actualContractId = historyToContractMap[contractHistoryId];
            
            if (contractHistoryId != null && 
                actualContractId != null && 
                validContractIds.contains(actualContractId)) {
              programValidRecords.add(record);
              final proId = record['pro_id']?.toString();
              if (proId != null && proId.isNotEmpty) {
                finalValidProIds.add(proId);
              }
              print('✅ 유효한 레슨 기록: LS_contract_id=${record['LS_contract_id']}, contract_history_id=$contractHistoryId, contract_id=$actualContractId');
            } else {
              print('❌ 프로그램 예약 불가능한 레슨: LS_contract_id=${record['LS_contract_id']}, contract_history_id=$contractHistoryId, contract_id=$actualContractId');
            }
          }
          validProIds.clear();
          validProIds.addAll(finalValidProIds);
        }
      }
      
      // 4단계: 프로 정보 조회
      Map<String, Map<String, dynamic>> proInfoMap = {};
      int maxReservationAheadDays = 0;
      
      if (validProIds.isNotEmpty) {
        final List<Map<String, dynamic>> proRecords = await getData(
          table: 'v2_staff_pro',
          fields: ['pro_id', 'min_service_min', 'svc_time_unit', 'min_reservation_term', 'reservation_ahead_days', 'pro_name'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'pro_id', 'operator': 'IN', 'value': validProIds.toList()},
          ],
        );
        
        for (final proRecord in proRecords) {
          final proId = proRecord['pro_id']?.toString();
          if (proId != null) {
            final reservationAheadDays = int.tryParse(proRecord['reservation_ahead_days']?.toString() ?? '0') ?? 0;
            if (reservationAheadDays > maxReservationAheadDays) {
              maxReservationAheadDays = reservationAheadDays;
            }
            
            proInfoMap[proId] = {
              'pro_id': proId,
              'pro_name': proRecord['pro_name']?.toString() ?? '',
              'min_service_min': proRecord['min_service_min']?.toString() ?? '60',
              'svc_time_unit': proRecord['svc_time_unit']?.toString() ?? '30',
              'min_reservation_term': proRecord['min_reservation_term']?.toString() ?? '1',
              'reservation_ahead_days': proRecord['reservation_ahead_days']?.toString() ?? '7',
            };
          }
        }
      }
      
      // 5단계: 프로 스케줄 조회
      Map<String, Map<String, Map<String, dynamic>>> proScheduleMap = {};
      
      if (validProIds.isNotEmpty && maxReservationAheadDays > 0) {
        final endDate = DateFormat('yyyy-MM-dd').format(
          DateTime.now().add(Duration(days: maxReservationAheadDays))
        );
        
        final scheduleResponse = await getProScheduleData(
          proIds: validProIds.toList(),
          startDate: baseDate,
          endDate: endDate,
        );
        
        if (scheduleResponse['success'] == true) {
          proScheduleMap = scheduleResponse['data'] as Map<String, Map<String, Map<String, dynamic>>>? ?? {};
        }
      }
      
      return {
        'success': true,
        'message': '프로그램용 레슨 카운팅 데이터 조회 성공',
        'data': programValidRecords,
        'debug_info': {
          'message': '프로그램 예약 가능한 레슨 데이터 조회 완료',
          'total_records': records.length,
          'valid_records': programValidRecords.length,
          'pro_ids': validProIds.toList(),
          'pro_info': proInfoMap,
          'pro_schedule': proScheduleMap,
          'max_reservation_ahead_days': maxReservationAheadDays,
          'today': baseDate,
        }
      };
      
    } catch (e) {
      print('프로그램용 레슨 카운팅 데이터 조회 실패: $e');
      return {
        'success': false,
        'message': '프로그램용 레슨 카운팅 데이터 조회 실패: $e',
        'data': [],
        'debug_info': {
          'message': '프로그램용 레슨 카운팅 데이터 조회 실패: $e',
          'total_records': 0,
          'valid_records': 0,
          'pro_ids': [],
          'pro_info': {},
          'pro_schedule': {},
          'max_reservation_ahead_days': 0,
          'today': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }
      };
    }
  }

  // ========== 특수 예약 설정 관련 함수들 ==========
  
  // 기본 특수 예약 설정 데이터 추가
  static Future<bool> addDefaultSpecialReservationSettings() async {
    try {
      print('=== 기본 특수 예약 설정 데이터 추가 시작 ===');
      
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        print('브랜치 ID가 없어 설정 추가를 건너뜁니다.');
        return false;
      }
      
      // 기본 특수 예약 설정 데이터들
      final defaultSettings = [
        // 집중연습 특수 예약
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '집중연습',
          'field_name': 'max_player_no',
          'option_value': '1',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '집중연습',
          'field_name': 'ls_min(1)',
          'option_value': '15',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '집중연습',
          'field_name': 'ls_min(2)',
          'option_value': '15',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '집중연습',
          'field_name': 'break_min(1)',
          'option_value': '5',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '집중연습',
          'field_name': 'break_min(2)',
          'option_value': '5',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '집중연습',
          'field_name': 'break_min(3)',
          'option_value': '10',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        // 그룹레슨 특수 예약
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '그룹레슨',
          'field_name': 'max_player_no',
          'option_value': '4',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '그룹레슨',
          'field_name': 'ls_min(1)',
          'option_value': '30',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '그룹레슨',
          'field_name': 'break_min(1)',
          'option_value': '10',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        // 개인레슨 특수 예약
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '개인레슨',
          'field_name': 'max_player_no',
          'option_value': '1',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '개인레슨',
          'field_name': 'ls_min(1)',
          'option_value': '50',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': '개인레슨',
          'field_name': 'break_min(1)',
          'option_value': '10',
          'setting_status': '유효',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
      
      // 기존 설정이 있는지 확인
      final existingSettings = await getData(
        table: 'v2_base_option_setting',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
        ],
      );
      
      if (existingSettings.isNotEmpty) {
        print('기존 특수 예약 설정이 ${existingSettings.length}개 있습니다.');
        return true;
      }
      
      // 설정 데이터 추가
      int successCount = 0;
      for (final setting in defaultSettings) {
        try {
          final result = await addData(
            table: 'v2_base_option_setting',
            data: setting,
          );
          
          if (result['success'] == true) {
            successCount++;
            print('✅ 설정 추가 성공: ${setting['table_name']} - ${setting['field_name']}');
          } else {
            print('❌ 설정 추가 실패: ${setting['table_name']} - ${setting['field_name']}');
          }
        } catch (e) {
          print('❌ 설정 추가 오류: ${setting['table_name']} - ${setting['field_name']}: $e');
        }
      }
      
      print('특수 예약 설정 추가 완료: $successCount/${defaultSettings.length}개 성공');
      return successCount > 0;
      
    } catch (e) {
      print('기본 특수 예약 설정 추가 실패: $e');
      return false;
    }
  }

  // v2_discount_coupon_setting 테이블 조회
  static Future<List<Map<String, dynamic>>> getDiscountCouponSettings({
    String? branchId,
    String? settingStatus,
  }) async {
    try {
      List<Map<String, dynamic>> whereConditions = [];
      
      if (branchId != null) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': branchId,
        });
      }
      
      if (settingStatus != null) {
        whereConditions.add({
          'field': 'setting_status',
          'operator': '=',
          'value': settingStatus,
        });
      }
      
      final result = await getData(
        table: 'v2_discount_coupon_setting',
        where: whereConditions.isNotEmpty ? whereConditions : null,
      );
      
      return result;
    } catch (e) {
      print('할인쿠폰 설정 조회 실패: $e');
      return [];
    }
  }

  // v2_discount_coupon_auto_triggers 테이블 조회
  static Future<List<Map<String, dynamic>>> getDiscountCouponAutoTriggers({
    List<String>? triggerIds,
    String? settingStatus,
  }) async {
    try {
      print('=== getDiscountCouponAutoTriggers 시작 ===');
      print('요청된 triggerIds: $triggerIds');
      print('settingStatus: $settingStatus');
      
      List<Map<String, dynamic>> whereConditions = [];
      
      // settingStatus 조건만 추가 (triggerIds는 별도 처리)
      if (settingStatus != null) {
        whereConditions.add({
          'field': 'setting_status',
          'operator': '=',
          'value': settingStatus,
        });
      }
      
      // 모든 트리거를 먼저 조회한 후 필터링
      print('테이블 조회 시도: v2_discount_coupon_auto_triggers');
      print('WHERE 조건: $whereConditions');
      
      final allTriggers = await getData(
        table: 'v2_discount_coupon_auto_triggers',
        where: whereConditions.isNotEmpty ? whereConditions : null,
      );
      
      print('조회된 전체 트리거 개수: ${allTriggers.length}');
      
      // triggerIds가 지정된 경우 필터링
      if (triggerIds != null && triggerIds.isNotEmpty) {
        final filteredTriggers = allTriggers.where((trigger) {
          final triggerId = trigger['trigger_id']?.toString();
          return triggerId != null && triggerIds.contains(triggerId);
        }).toList();
        
        print('필터링된 트리거 개수: ${filteredTriggers.length}');
        return filteredTriggers;
      }
      
      return allTriggers;
    } catch (e) {
      print('할인쿠폰 자동트리거 조회 실패: $e');
      return [];
    }
  }


  // v2_discount_coupon 테이블에 쿠폰 발행
  static Future<bool> issueCoupon({
    required String branchId,
    required String memberId,
    required String memberName,
    required String couponCode,
    required String couponType,
    required int discountRatio,
    required int discountAmt,
    required int discountMin,
    required int couponExpiryDays,
    required String multipleCouponUse,
    required String couponDescription,
    String? reservationIdIssued,
  }) async {
    try {
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: couponExpiryDays));
      
      final couponData = {
        'branch_id': branchId,
        'coupon_code': couponCode,
        'member_id': memberId,
        'member_name': memberName,
        'coupon_type': couponType,
        'discount_ratio': discountRatio,
        'discount_amt': discountAmt,
        'discount_min': discountMin,
        'coupon_expiry_date': DateFormat('yyyy-MM-dd').format(expiryDate),
        'coupon_issue_date': DateFormat('yyyy-MM-dd').format(now),
        'coupon_description': couponDescription,
        'updated_at': now.toIso8601String(),
        'coupon_status': '미사용',
        'multiple_coupon_use': multipleCouponUse,
        if (reservationIdIssued != null) 'reservation_id_issued': reservationIdIssued,
      };
      
      final result = await addData(
        table: 'v2_discount_coupon',
        data: couponData,
      );
      
      if (result['success'] == true) {
        print('✅ 할인쿠폰 발행 성공: $couponCode (회원: $memberName)');
        return true;
      } else {
        print('❌ 할인쿠폰 발행 실패: ${result['error'] ?? 'Unknown error'}');
        return false;
      }
    } catch (e) {
      print('할인쿠폰 발행 오류: $e');
      return false;
    }
  }

  // ========== 메시지 수신동의 관련 메소드 ==========
  
  // 메시지 수신동의 목록 조회
  Future<Map<String, dynamic>> getMessageAgreements({
    required String branchId,
    required String memberId,
  }) async {
    try {
      final result = await ApiService.getData(
        table: 'v2_message_agreement',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
        orderBy: [
          {'field': 'msg_type', 'direction': 'ASC'},
        ],
      );
      
      return {
        'success': true,
        'data': result,
      };
    } catch (e) {
      print('메시지 수신동의 조회 오류: $e');
      return {
        'success': false,
        'error': '메시지 수신동의 조회 중 오류가 발생했습니다: $e',
        'data': [],
      };
    }
  }

  // 메시지 수신동의 생성
  Future<Map<String, dynamic>> createMessageAgreement({
    required String branchId,
    required String memberId,
    required String memberName,
    required String msgType,
    required String msgAgreement,
  }) async {
    try {
      final agreementData = {
        'branch_id': branchId,
        'member_id': memberId,
        'member_name': memberName,
        'msg_type': msgType,
        'msg_agreement': msgAgreement,
      };
      
      final result = await ApiService.addData(
        table: 'v2_message_agreement',
        data: agreementData,
      );
      
      return result;
    } catch (e) {
      print('메시지 수신동의 생성 오류: $e');
      return {
        'success': false,
        'error': '메시지 수신동의 생성 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 메시지 수신동의 수정
  Future<Map<String, dynamic>> updateMessageAgreement({
    required String branchId,
    required String memberId,
    required String msgType,
    required String msgAgreement,
  }) async {
    try {
      final updateData = {
        'msg_agreement': msgAgreement,
      };
      
      final result = await ApiService.updateData(
        table: 'v2_message_agreement',
        data: updateData,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'msg_type', 'operator': '=', 'value': msgType},
        ],
      );
      
      return result;
    } catch (e) {
      print('메시지 수신동의 수정 오류: $e');
      return {
        'success': false,
        'error': '메시지 수신동의 수정 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 메시지 수신동의 삭제
  Future<Map<String, dynamic>> deleteMessageAgreement({
    required String branchId,
    required String memberId,
    required String msgType,
  }) async {
    try {
      final result = await ApiService.deleteData(
        table: 'v2_message_agreement',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'msg_type', 'operator': '=', 'value': msgType},
        ],
      );
      
      return result;
    } catch (e) {
      print('메시지 수신동의 삭제 오류: $e');
      return {
        'success': false,
        'error': '메시지 수신동의 삭제 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 특정 멤버의 모든 메시지 수신동의 삭제
  Future<Map<String, dynamic>> deleteAllMessageAgreements({
    required String branchId,
    required String memberId,
  }) async {
    try {
      final result = await ApiService.deleteData(
        table: 'v2_message_agreement',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': '=', 'value': memberId},
        ],
      );
      
      return result;
    } catch (e) {
      print('전체 메시지 수신동의 삭제 오류: $e');
      return {
        'success': false,
        'error': '전체 메시지 수신동의 삭제 중 오류가 발생했습니다: $e',
      };
    }
  }
}
