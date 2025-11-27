import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RoutineAnalysisService {
  static const String baseUrl = 'https://autofms.mycafe24.com/dynamic_api.php';
  static const String holidayApiKey = 'GgQ%2FfdIp9mcf5iowhHT4g0dFzwa%2FRNOEM%2F4Rqvjn0SAQHR80WMt3nPIAKY7YSPkacRyW4adSD%2BpUbBKve10xYQ%3D%3D';
  
  // 캐시된 데이터
  static List<Map<String, dynamic>> _holidaysCache = [];
  static Map<int, Map<String, int>> _priceDataCache = {};
  static int _cachedYear = 0;

  /// 메인 분석 함수
  static Future<Map<String, dynamic>> analyzeReservation(Map<String, dynamic> params) async {
    try {
      if (kDebugMode) {
        print('🔍 [루틴 분석] 분석 시작');
        print('📋 [루틴 분석] 파라미터: ${jsonEncode(params)}');
      }

      // 파라미터 검증
      _validateParams(params);

      // branchId 추가
      final branchId = params['branch_id'] as String?;

      // 공휴일 정보 로드
      final year = int.parse(params['base_date'].toString().substring(0, 4));
      await _loadHolidays(year);

      // 가격 정보 로드
      await _loadPriceData(branchId: branchId);

      // 타석 예약 가능성 분석
      final teeAnalysis = await _analyzeTeeAvailability(params);

      // 레슨 예약 가능성 분석
      final lessonAnalysis = await _analyzeLessonAvailability(params);

      // 종합 분석 결과 생성
      final comprehensiveResult = _generateComprehensiveResult(teeAnalysis, lessonAnalysis, params);

      if (kDebugMode) {
        print('✅ [루틴 분석] 분석 완료');
      }

      return {
        'success': true,
        'data': comprehensiveResult
      };

    } catch (e) {
      if (kDebugMode) {
        print('❌ [루틴 분석] 분석 오류: $e');
      }
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  /// 파라미터 검증
  static void _validateParams(Map<String, dynamic> params) {
    final requiredFields = ['base_date', 'member_id', 'target_weekdays', 'selected_dates', 'search_dates'];
    
    for (String field in requiredFields) {
      if (!params.containsKey(field)) {
        throw Exception('필수 파라미터가 누락되었습니다: $field');
      }
    }

    // 날짜 형식 검증
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!datePattern.hasMatch(params['base_date'])) {
      throw Exception('잘못된 날짜 형식입니다: ${params['base_date']}');
    }
  }

  /// 공휴일 정보 로드
  static Future<void> _loadHolidays(int year) async {
    if (_cachedYear == year && _holidaysCache.isNotEmpty) {
      return; // 이미 캐시된 데이터 사용
    }

    try {
      final url = 'http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo';
      final params = {
        'ServiceKey': Uri.decodeComponent(holidayApiKey),
        'solYear': year.toString(),
        'numOfRows': '100',
        '_type': 'json'
      };

      final uri = Uri.parse(url).replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['response']?['body']?['items'] != null) {
          var items = data['response']['body']['items']['item'];
          
          // 단일 항목인 경우 배열로 변환
          if (items is Map) {
            items = [items];
          }

          _holidaysCache = [];
          for (var item in items) {
            if (item['locdate'] != null && item['dateName'] != null) {
              final dateStr = _formatDate(item['locdate'].toString());
              _holidaysCache.add({
                'date': dateStr,
                'name': item['dateName'],
                'weekday': DateTime.parse(dateStr).weekday % 7
              });
            }
          }
        }
      }

      // 주말 추가
      _addWeekends(year);
      _cachedYear = year;

      if (kDebugMode) {
        print('📅 [공휴일] ${year}년 공휴일 ${_holidaysCache.length}개 로드됨');
      }

    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [공휴일] API 호출 실패, 주말만 추가: $e');
      }
      _holidaysCache = [];
      _addWeekends(year);
      _cachedYear = year;
    }
  }

  /// 주말 추가
  static void _addWeekends(int year) {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);
    
    for (var date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        // 이미 추가된 날짜인지 확인
        final exists = _holidaysCache.any((holiday) => holiday['date'] == dateStr);
        if (!exists) {
          _holidaysCache.add({
            'date': dateStr,
            'name': date.weekday == DateTime.saturday ? '토요일' : '일요일',
            'weekday': date.weekday % 7
          });
        }
      }
    }
  }

  /// 가격 정보 로드
  static Future<void> _loadPriceData({String? branchId}) async {
    if (_priceDataCache.isNotEmpty) {
      return; // 이미 캐시된 데이터 사용
    }

    try {
      final requestData = <String, dynamic>{
        'operation': 'get',
        'table': 'v2_Price_table'
      };

      // branchId가 제공된 경우 WHERE 조건 추가
      if (branchId != null && branchId.isNotEmpty) {
        requestData['where'] = [
          {'field': 'branch_id', 'operator': '=', 'value': branchId}
        ];
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          _priceDataCache = {};
          
          for (var item in data['data']) {
            final tsId = int.parse(item['ts_id'].toString());
            _priceDataCache[tsId] = {
              '조조': int.parse(item['ts_price_morning'].toString()),
              '일반': int.parse(item['ts_price_normal'].toString()),
              '피크': int.parse(item['ts_price_peak'].toString()),
              '심야': int.parse(item['ts_price_night'].toString()),
            };
          }

          if (kDebugMode) {
            print('💰 [가격정보] ${_priceDataCache.length}개 타석 가격 정보 로드됨');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [가격정보] 로드 실패: $e');
      }
      _priceDataCache = {};
    }
  }

  /// 타석 예약 가능성 분석
  static Future<List<Map<String, dynamic>>> _analyzeTeeAvailability(Map<String, dynamic> params) async {
    if (kDebugMode) {
      print('🎯 [타석 분석] 시작');
    }

    // 예약 가능 날짜 생성
    final dates = _generateAvailableDates(
      params['base_date'],
      List<List<String>>.from(params['target_weekdays']),
      params['search_dates']
    );

    final preferredTsIds = List<int>.from(params['preferred_ts_ids'] ?? [4, 1, 7, 8, 9]);
    final nonPreferredTsIds = List<int>.from(params['non_preferred_ts_ids'] ?? [2, 3, 5, 6]);

    if (kDebugMode) {
      print('🎯 [타석 분석] 선호 타석: $preferredTsIds');
      print('🎯 [타석 분석] 비선호 타석: $nonPreferredTsIds');
    }

    // 기존 예약 데이터 조회
    final allDates = dates.map((d) => d['date'] as String).toList();
    final existingReservations = await _getExistingReservations(allDates);

    final results = <Map<String, dynamic>>[];

    for (var dateInfo in dates) {
      final date = dateInfo['date'];
      final startTime = dateInfo['start_time'];
      final endTime = dateInfo['end_time'];
      final weekday = dateInfo['weekday'];

      // 공휴일 여부 확인
      final holidayInfo = _getHolidayStatus(date);
      final isHoliday = holidayInfo['is_holiday'];

      // 시간대 분류
      final timeClassification = _getTimeZoneClassification(startTime, endTime, isHoliday);

      // 해당 날짜의 기존 예약 찾기
      final dateReservations = existingReservations.where((res) => res['ts_date'] == date).toList();

      // 시간 겹침이 있는 타석들 찾기
      final unavailableTsIds = <int>[];
      
      for (var reservation in dateReservations) {
        final resStart = reservation['ts_start'];
        final resEnd = reservation['ts_end'];
        final tsId = int.parse(reservation['ts_id'].toString());

        if (_checkTimeOverlap(startTime, endTime, resStart, resEnd)) {
          unavailableTsIds.add(tsId);
        }
      }

      // 예약 가능한 타석들 계산
      final allTsIds = [...preferredTsIds, ...nonPreferredTsIds];
      final availableTsIds = allTsIds.where((id) => !unavailableTsIds.contains(id)).toList();

      // 선호 타석과 비선호 타석 분류
      final availablePreferred = preferredTsIds.where((id) => availableTsIds.contains(id)).toList();
      final availableNonPreferred = nonPreferredTsIds.where((id) => availableTsIds.contains(id)).toList();

      // 최적 타석 배정 (선호도 순서대로)
      int? assignedTsId;
      if (availablePreferred.isNotEmpty) {
        // 선호 타석 중에서 우선순위가 가장 높은 타석 선택
        for (int preferredId in preferredTsIds) {
          if (availablePreferred.contains(preferredId)) {
            assignedTsId = preferredId;
            break;
          }
        }
      } else if (availableNonPreferred.isNotEmpty) {
        // 선호 타석이 없으면 비선호 타석 중에서 첫 번째 선택
        assignedTsId = availableNonPreferred.first;
      }

      // 결과 저장
      String status;
      Map<String, dynamic>? costInfo;

      if (availableTsIds.isNotEmpty) {
        if (assignedTsId != null) {
          status = "배정완료";
          // 비용 계산
          costInfo = _calculateCost(assignedTsId, timeClassification, params['member_id'], date, isHoliday, startTime, endTime);
        } else {
          status = "배정실패";
          costInfo = null;
        }
      } else {
        status = "예약불가";
        assignedTsId = null;
        costInfo = null;
      }

      results.add({
        'date': date,
        'weekday': weekday,
        'status': status,
        'assigned_ts_id': assignedTsId,
        'start_time': startTime,
        'end_time': endTime,
        'is_holiday': isHoliday,
        'holiday_name': holidayInfo['holiday_name'],
        'time_classification': timeClassification,
        'available_preferred': availablePreferred,
        'available_non_preferred': availableNonPreferred,
        'unavailable_ts_ids': unavailableTsIds,
        'cost_info': costInfo
      });
    }

    if (kDebugMode) {
      print('✅ [타석 분석] 완료: ${results.length}개 날짜 분석됨');
    }

    return results;
  }

  /// 레슨 예약 가능성 분석
  static Future<List<Map<String, dynamic>>> _analyzeLessonAvailability(Map<String, dynamic> params) async {
    if (params['target_lesson_weekdays'] == null || 
        (params['target_lesson_weekdays'] as List).isEmpty ||
        params['ls_contract_pro'] == null) {
      if (kDebugMode) {
        print('⏭️ [레슨 분석] 건너뛰기: 레슨 요일 또는 계약 프로 없음');
      }
      return [];
    }

    if (kDebugMode) {
      print('📚 [레슨 분석] 시작');
    }

    final branchId = params['branch_id'] as String?;

    // 레슨 계약 정보 조회
    final lessonContracts = await _getLessonContracts(params['member_id'], branchId, params['ls_contract_pro']);
    if (lessonContracts.isEmpty) {
      if (kDebugMode) {
        print('⚠️ [레슨 분석] 유효한 레슨 계약 없음');
      }
      return [];
    }

    // 레슨 예약 가능 날짜 생성
    final dates = _generateLessonAvailableDates(
      params['base_date'],
      List<List<String>>.from(params['target_lesson_weekdays']),
      params['search_dates']
    );

    final proName = params['ls_contract_pro'];

    // 강사 닉네임 조회
    final staffNickname = await _getStaffNickname(proName);

    final results = <Map<String, dynamic>>[];

    for (var dateInfo in dates) {
      final date = dateInfo['date'];
      var startTime = dateInfo['start_time'];
      var endTime = dateInfo['end_time'];

      // 시간 형식 정규화 (초 단위 추가)
      if (startTime.length == 5) startTime += ':00';
      if (endTime.length == 5) endTime += ':00';

      // 계약 만료일 확인
      bool contractValid = false;
      for (var contract in lessonContracts) {
        if (DateTime.parse(date).isBefore(DateTime.parse(contract['expiry_date']).add(const Duration(days: 1)))) {
          contractValid = true;
          break;
        }
      }

      if (!contractValid) {
        results.add({
          'date': date,
          'start_time': startTime,
          'end_time': endTime,
          'available': false,
          'reason': '계약만료'
        });
        continue;
      }

      // 강사 스케줄 조회
      final scheduleInfo = await _getStaffSchedule(staffNickname, date);

      // 기존 레슨 예약 조회
      final ordersInfo = await _getLessonOrders(proName, [date]);

      // 레슨 가능 여부 확인
      final availability = _checkLessonAvailability(startTime, endTime, scheduleInfo, ordersInfo[date] ?? []);

      results.add({
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'available': availability['available'],
        'reason': availability['reason']
      });
    }

    if (kDebugMode) {
      print('✅ [레슨 분석] 완료: ${results.length}개 날짜 분석됨');
    }

    return results;
  }

  /// 기존 예약 데이터 조회
  static Future<List<Map<String, dynamic>>> _getExistingReservations(List<String> dates) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': [
            {'field': 'ts_status', 'operator': '=', 'value': '결제완료'}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ [기존예약] 조회 실패: $e');
      }
      return [];
    }
  }

  /// 레슨 계약 정보 조회
  static Future<List<Map<String, dynamic>>> _getLessonContracts(int memberId, String? branchId, String proName) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'LS_expiry_date', 'operator': '>', 'value': today},
        {'field': 'LS_contract_pro', 'operator': '=', 'value': proName}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_contracts',
          'where': whereConditions
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']).map((contract) => {
            'contract_id': int.parse(contract['LS_contract_id'].toString()),
            'pro_name': contract['LS_contract_pro'],
            'expiry_date': contract['LS_expiry_date']
          }).toList();
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨계약] 조회 실패: $e');
      }
      return [];
    }
  }

  /// 강사 닉네임 조회
  static Future<String> _getStaffNickname(String proName) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_staff_pro',
          'where': [
            {'field': 'pro_name', 'operator': '=', 'value': proName}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
          return data['data'][0]['staff_nickname'] ?? '';
        }
      }
      return '';
    } catch (e) {
      if (kDebugMode) {
        print('❌ [강사닉네임] 조회 실패: $e');
      }
      return '';
    }
  }

  /// 강사 스케줄 조회
  static Future<Map<String, dynamic>?> _getStaffSchedule(String staffNickname, String date) async {
    try {
      // 먼저 조정된 스케줄 확인
      var response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_schedule_adjusted_pro',
          'where': [
            {'field': 'staff_nickname', 'operator': '=', 'value': staffNickname},
            {'field': 'scheduled_date', 'operator': '=', 'value': date}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
          return Map<String, dynamic>.from(data['data'][0]);
        }
      }

      // 조정된 스케줄이 없으면 기본 스케줄 확인
      final weekday = DateTime.parse(date).weekday % 7; // 0=일요일, 1=월요일, ...
      
      response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'schedule_weekly_base',
          'where': [
            {'field': 'staff_nickname', 'operator': '=', 'value': staffNickname},
            {'field': 'day_of_week', 'operator': '=', 'value': weekday}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
          return Map<String, dynamic>.from(data['data'][0]);
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [강사스케줄] 조회 실패: $e');
      }
      return null;
    }
  }

  /// 레슨 주문 조회
  static Future<Map<String, List<Map<String, dynamic>>>> _getLessonOrders(String proName, List<String> dates) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'where': [
            {'field': 'pro_id', 'operator': '=', 'value': proName},
            {'field': 'LS_date', 'operator': 'IN', 'value': dates},
            {'field': 'LS_status', 'operator': '=', 'value': '예약완료'}
          ]
        }),
      );

      final result = <String, List<Map<String, dynamic>>>{};
      for (String date in dates) {
        result[date] = [];
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          for (var order in data['data']) {
            final orderDate = order['LS_date'];
            if (result.containsKey(orderDate)) {
              result[orderDate]!.add(Map<String, dynamic>.from(order));
            }
          }
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨주문] 조회 실패: $e');
      }
      return {};
    }
  }

  /// 시간 겹침 검사
  static bool _checkTimeOverlap(String start1, String end1, String start2, String end2) {
    final start1Minutes = _timeToMinutes(start1);
    final end1Minutes = _timeToMinutes(end1);
    final start2Minutes = _timeToMinutes(start2);
    final end2Minutes = _timeToMinutes(end2);

    return start1Minutes < end2Minutes && end1Minutes > start2Minutes;
  }

  /// 시간을 분으로 변환
  static int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 레슨 가능 여부 확인
  static Map<String, dynamic> _checkLessonAvailability(String startTime, String endTime, Map<String, dynamic>? scheduleInfo, List<Map<String, dynamic>> ordersInfo) {
    // 스케줄 정보가 없으면 불가능
    if (scheduleInfo == null) {
      return {'available': false, 'reason': '스케줄 정보 없음'};
    }

    // 휴무일 확인
    if (scheduleInfo['is_day_off'] == 1 || scheduleInfo['is_day_off'] == '1') {
      return {'available': false, 'reason': '휴무일'};
    }

    // 근무 시간 확인
    final workStart = scheduleInfo['work_start_time'];
    final workEnd = scheduleInfo['work_end_time'];
    
    if (workStart == null || workEnd == null) {
      return {'available': false, 'reason': '근무시간 정보 없음'};
    }

    final requestStartMinutes = _timeToMinutes(startTime);
    final requestEndMinutes = _timeToMinutes(endTime);
    final workStartMinutes = _timeToMinutes(workStart);
    final workEndMinutes = _timeToMinutes(workEnd);

    if (requestStartMinutes < workStartMinutes || requestEndMinutes > workEndMinutes) {
      return {'available': false, 'reason': '근무시간 외'};
    }

    // 기존 예약과 겹치는지 확인
    for (var order in ordersInfo) {
      final orderStart = order['LS_start'];
      final orderEnd = order['LS_end'];
      
      if (orderStart != null && orderEnd != null) {
        if (_checkTimeOverlap(startTime, endTime, orderStart, orderEnd)) {
          return {'available': false, 'reason': '기존 예약과 겹침'};
        }
      }
    }

    return {'available': true, 'reason': '예약 가능'};
  }

  /// 예약 가능 날짜 생성
  static List<Map<String, dynamic>> _generateAvailableDates(String baseDate, List<List<String>> targetWeekdays, int maxCount) {
    final results = <Map<String, dynamic>>[];
    final baseDateTime = DateTime.parse(baseDate);
    var currentDate = baseDateTime;
    
    // 요일별 시간 정보 매핑
    final weekdayMap = <int, Map<String, String>>{};
    for (var weekdayInfo in targetWeekdays) {
      final weekdayName = weekdayInfo[0];
      final startTime = weekdayInfo[1];
      final endTime = weekdayInfo[2];
      
      final weekdayNum = _getWeekdayNumber(weekdayName);
      weekdayMap[weekdayNum] = {
        'start_time': startTime,
        'end_time': endTime
      };
    }

    // 최대 60일까지 검색
    for (int i = 0; i < 60 && results.length < maxCount; i++) {
      final weekday = currentDate.weekday % 7;
      
      if (weekdayMap.containsKey(weekday)) {
        final timeInfo = weekdayMap[weekday]!;
        results.add({
          'date': '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}',
          'weekday': _getKoreanWeekday(weekday),
          'start_time': timeInfo['start_time'],
          'end_time': timeInfo['end_time']
        });
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return results;
  }

  /// 레슨 예약 가능 날짜 생성
  static List<Map<String, dynamic>> _generateLessonAvailableDates(String baseDate, List<List<String>> targetLessonWeekdays, int maxCount) {
    return _generateAvailableDates(baseDate, targetLessonWeekdays, maxCount);
  }

  /// 요일 이름을 숫자로 변환
  static int _getWeekdayNumber(String weekdayName) {
    const weekdayMap = {
      '일요일': 0, '월요일': 1, '화요일': 2, '수요일': 3,
      '목요일': 4, '금요일': 5, '토요일': 6
    };
    return weekdayMap[weekdayName] ?? 0;
  }

  /// 숫자를 한글 요일로 변환
  static String _getKoreanWeekday(int weekdayNum) {
    const weekdays = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
    return weekdays[weekdayNum];
  }

  /// 공휴일 상태 확인
  static Map<String, dynamic> _getHolidayStatus(String date) {
    for (var holiday in _holidaysCache) {
      if (holiday['date'] == date) {
        return {
          'is_holiday': true,
          'holiday_name': holiday['name']
        };
      }
    }
    return {
      'is_holiday': false,
      'holiday_name': null
    };
  }

  /// 시간대 분류
  static dynamic _getTimeZoneClassification(String startTime, String endTime, bool isHoliday) {
    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);
    final duration = endMinutes - startMinutes;

    // 단일 시간대인지 확인
    String? singleZone;
    
    if (isHoliday) {
      // 공휴일은 모든 시간이 피크
      singleZone = '피크';
    } else {
      // 평일 시간대 구분
      if (endMinutes <= 480) { // 08:00 이전
        singleZone = '조조';
      } else if (startMinutes >= 1320) { // 22:00 이후
        singleZone = '심야';
      } else if (startMinutes >= 1080 && endMinutes <= 1320) { // 18:00-22:00
        singleZone = '피크';
      } else if (startMinutes >= 480 && endMinutes <= 1080) { // 08:00-18:00
        singleZone = '일반';
      }
    }

    if (singleZone != null) {
      return singleZone;
    }

    // 복합 시간대 계산
    final zones = <String, int>{};
    
    for (int minute = startMinutes; minute < endMinutes; minute++) {
      String zone;
      if (isHoliday) {
        zone = '피크';
      } else if (minute < 480) {
        zone = '조조';
      } else if (minute < 1080) {
        zone = '일반';
      } else if (minute < 1320) {
        zone = '피크';
      } else {
        zone = '심야';
      }
      
      zones[zone] = (zones[zone] ?? 0) + 1;
    }

    return zones;
  }

  /// 비용 계산
  static Map<String, dynamic> _calculateCost(int tsId, dynamic timeClassification, int memberId, String date, bool isHoliday, String startTime, String endTime) {
    if (!_priceDataCache.containsKey(tsId)) {
      return {
        'final_cost': 0,
        'base_cost': 0,
        'member_discount': 0,
        'time_discount': 0,
        'time_discount_desc': '',
        'term_discount': 0,
        'term_discount_desc': '',
        'total_minutes': 0,
        'cost_details': [],
        'error': '가격 정보 없음'
      };
    }

    // 시간대별 분류가 문자열인 경우 (단일 시간대)
    Map<String, int> zones;
    if (timeClassification is String) {
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = _timeToMinutes(endTime);
      final minutes = endMinutes - startMinutes;
      zones = {timeClassification: minutes};
    } else {
      zones = Map<String, int>.from(timeClassification);
    }

    // 기본 금액 계산
    int baseCost = 0;
    final costDetails = <String>[];
    int totalMinutes = 0;

    final tsPrice = _priceDataCache[tsId]!;
    
    for (var entry in zones.entries) {
      final zone = entry.key;
      final minutes = entry.value;
      
      if (minutes > 0 && tsPrice.containsKey(zone)) {
        final pricePerMinute = tsPrice[zone]!;
        final zoneCost = pricePerMinute * minutes;
        baseCost += zoneCost;
        totalMinutes += minutes;
        costDetails.add('$zone:${minutes}분×${pricePerMinute}원=${zoneCost}원');
      }
    }

    if (baseCost == 0) {
      return {
        'final_cost': 0,
        'base_cost': 0,
        'member_discount': 0,
        'time_discount': 0,
        'time_discount_desc': '',
        'term_discount': 0,
        'term_discount_desc': '',
        'total_minutes': 0,
        'cost_details': [],
        'error': '0원'
      };
    }

    // 등록회원 할인 적용 (25%)
    final memberDiscountRate = 0.25;
    final memberDiscountAmount = (baseCost * memberDiscountRate).round();

    // 시간별 할인 적용 (집중연습할인)
    int timeDiscount = 0;
    String timeDiscountDesc = "";
    if (totalMinutes >= 120) {
      timeDiscount = 4000;
      timeDiscountDesc = "집중연습할인: -4,000원(120분 이상)";
    } else if (totalMinutes >= 90) {
      timeDiscount = 2000;
      timeDiscountDesc = "집중연습할인: -2,000원(90분 이상)";
    }

    // 기간권 할인 계산 (여기서는 간단히 0으로 처리, 필요시 구현)
    final termDiscount = 0;
    final termDiscountDesc = "";

    // 최종 결제 금액 계산
    final discountedCost = baseCost - memberDiscountAmount;
    final finalCost = max(1, discountedCost - timeDiscount - termDiscount);

    return {
      'final_cost': finalCost,
      'base_cost': baseCost,
      'member_discount': memberDiscountAmount,
      'time_discount': timeDiscount,
      'time_discount_desc': timeDiscountDesc,
      'term_discount': termDiscount,
      'term_discount_desc': termDiscountDesc,
      'total_minutes': totalMinutes,
      'cost_details': costDetails
    };
  }

  /// 종합 분석 결과 생성
  static Map<String, dynamic> _generateComprehensiveResult(List<Map<String, dynamic>> teeAnalysis, List<Map<String, dynamic>> lessonAnalysis, Map<String, dynamic> params) {
    final selectedDates = params['selected_dates'] ?? 5;
    
    // 타석 예약 가능한 날짜들
    final availableTeeResults = teeAnalysis.where((result) => result['status'] == '배정완료').toList();
    
    // 레슨 예약 가능한 날짜들
    final availableLessonResults = lessonAnalysis.where((result) => result['available'] == true).toList();

    // 상태 결정
    String status;
    if (availableTeeResults.length >= selectedDates) {
      if (lessonAnalysis.isEmpty || availableLessonResults.length >= selectedDates) {
        status = '예약가능';
      } else {
        status = '타석만가능';
      }
    } else {
      status = '예약불가';
    }

    return {
      'status': status,
      'selected_dates': selectedDates,
      'tee_analysis': teeAnalysis,
      'lesson_analysis': lessonAnalysis,
      'available_tee_count': availableTeeResults.length,
      'available_lesson_count': availableLessonResults.length,
      'summary': {
        'total_analyzed': teeAnalysis.length,
        'tee_available': availableTeeResults.length,
        'lesson_available': availableLessonResults.length,
        'final_status': status
      }
    };
  }

  /// 날짜 포맷 변환 (YYYYMMDD -> YYYY-MM-DD)
  static String _formatDate(String dateStr) {
    if (dateStr.length == 8) {
      return '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
    }
    return dateStr;
  }
} 