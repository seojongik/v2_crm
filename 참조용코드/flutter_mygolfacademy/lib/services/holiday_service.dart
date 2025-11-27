import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// 한국 공휴일 및 영업시간 관리 서비스
/// 
/// 공공데이터포털 API를 이용해 한국 공휴일 정보를 가져오고, 
/// 해당 정보에 기반해 특정 날짜가 공휴일인지 판별하는 기능을 제공합니다.
class HolidayService {
  // API 키 (실제 사용 시 보안상 더 안전한 방법으로 관리 필요)
  static const String _serviceKey = "GgQ/fdIp9mcf5iowhHT4g0dFzwa/RNOEM/4Rqvjn0SAQHR80WMt3nPIAKY7YSPkacRyW4adSD+pUbBKve10xYQ==";
  
  // 캐시된 공휴일 데이터
  static Map<int, List<String>> _holidaysCache = {};
  
  // 주말(일요일만)을 공휴일로 간주
  static bool includeSundays = true;
  
  /// 특정 연도의 공휴일 데이터를 가져옵니다.
  /// 
  /// [year]: 공휴일 정보를 조회할 연도 (예: 2024)
  /// [forceRefresh]: 캐시된 데이터가 있어도 강제로 새로 요청할지 여부
  /// 
  /// 반환값: 해당 연도의 공휴일 목록 (YYYY-MM-DD 형식의 문자열 리스트)
  static Future<List<String>> getHolidays(int year, {bool forceRefresh = false}) async {
    // 이미 캐시된 데이터가 있고 강제 갱신이 아니면 캐시된 데이터 반환
    if (_holidaysCache.containsKey(year) && !forceRefresh) {
      return _holidaysCache[year]!;
    }
    
    try {
      // 공공데이터포털 API에서 공휴일 데이터 요청
      final response = await _fetchHolidaysFromApi(year);
      final List<String> officialHolidays = _parseHolidaysResponse(response);
      
      // 일요일 추가 (설정에 따라)
      List<String> allHolidays = [...officialHolidays];
      if (includeSundays) {
        final List<String> sundays = _getSundaysForYear(year);
        allHolidays.addAll(sundays);
      }
      
      // 중복 제거 및 정렬
      final Set<String> uniqueDates = Set<String>.from(allHolidays);
      allHolidays = uniqueDates.toList()..sort();
      
      // 캐시에 저장
      _holidaysCache[year] = allHolidays;
      
      return allHolidays;
    } catch (e) {
      // API 호출 실패 시 빈 목록 반환하고 오류 로깅
      print('공휴일 데이터 조회 실패: $e');
      return [];
    }
  }
  
  /// 공공데이터포털 API에서 공휴일 정보를 요청합니다.
  static Future<http.Response> _fetchHolidaysFromApi(int year) async {
    final String url = 'http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo';
    
    final Map<String, String> params = {
      'ServiceKey': _serviceKey,
      'solYear': year.toString(),
      'numOfRows': '100',
      '_type': 'json',
    };
    
    final Uri uri = Uri.parse(url).replace(queryParameters: params);
    return http.get(uri);
  }
  
  /// API 응답에서 공휴일 데이터를 파싱합니다.
  static List<String> _parseHolidaysResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('API 호출 실패: ${response.statusCode}');
    }
    
    final Map<String, dynamic> data = json.decode(response.body);
    final items = data['response']?['body']?['items']?['item'];
    
    if (items == null) {
      return [];
    }
    
    final List<dynamic> itemsList = items is List ? items : [items];
    
    return itemsList.map<String>((item) {
      final String dateStr = item['locdate'].toString();
      // YYYYMMDD 형식을 YYYY-MM-DD로 변환
      return '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
    }).toList();
  }
  
  /// 특정 연도의 모든 일요일 날짜를 구합니다.
  static List<String> _getSundaysForYear(int year) {
    final List<String> sundays = [];
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    
    // 1월 1일부터 12월 31일까지 모든 날짜 확인
    final DateTime startDate = DateTime(year, 1, 1);
    final DateTime endDate = DateTime(year, 12, 31);
    
    for (DateTime date = startDate; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); date = date.add(Duration(days: 1))) {
      // 일요일(7)인 경우에만 추가
      if (date.weekday == DateTime.sunday) {
        sundays.add(formatter.format(date));
      }
    }
    
    return sundays;
  }
  
  /// 특정 날짜가 공휴일인지 확인합니다.
  /// 
  /// [date]: 확인할 날짜 (DateTime 객체)
  /// 
  /// 반환값: 공휴일 여부 (true/false)
  static Future<bool> isHoliday(DateTime date) async {
    // 일요일인 경우 바로 true 반환
    if (date.weekday == DateTime.sunday) {
      return true;
    }
    
    // 토요일은 공휴일로 간주하지 않음 (명시적으로 표현)
    if (date.weekday == DateTime.saturday) {
      return false;
    }
    
    final year = date.year;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    
    // 해당 연도의 공휴일 데이터 조회 (API에서 불러온 공휴일만)
    final holidays = await getHolidays(year);
    
    // 해당 날짜가 공휴일 목록에 있는지 확인
    return holidays.contains(formattedDate);
  }
  
  /// 현재 날짜가 공휴일인지 확인합니다.
  /// 
  /// 반환값: 공휴일 여부 (true/false)
  static Future<bool> isTodayHoliday() async {
    return isHoliday(DateTime.now());
  }
  
  /// [date], [branchId]에 해당하는 영업 시작 시간을 DB에서 조회합니다.
  static Future<TimeOfDay> getBusinessStartTime(DateTime date, String branchId) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_schedule_adjusted_ts',
          'fields': ['business_start'],
          'where': [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'ts_date', 'operator': '=', 'value': formattedDate}
          ],
          'limit': 1
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
        final startStr = data['data'][0]['business_start'];
        if (startStr != null && startStr.toString().isNotEmpty) {
          final parts = startStr.split(':');
          if (parts.length >= 2) {
            return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        }
      }
    } catch (e) {
      print('영업 시작 시간 조회 오류: $e');
    }
    // fallback: 06:00
    return const TimeOfDay(hour: 6, minute: 0);
  }
  
  /// [date], [branchId]에 해당하는 영업 종료 시간을 DB에서 조회합니다.
  static Future<TimeOfDay> getBusinessEndTime(DateTime date, String branchId) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_schedule_adjusted_ts',
          'fields': ['business_end'],
          'where': [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'ts_date', 'operator': '=', 'value': formattedDate}
          ],
          'limit': 1
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
        final endStr = data['data'][0]['business_end'];
        if (endStr != null && endStr.toString().isNotEmpty) {
          final parts = endStr.split(':');
          if (parts.length >= 2) {
            return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        }
      }
    } catch (e) {
      print('영업 종료 시간 조회 오류: $e');
    }
    // fallback: 24:00
    return const TimeOfDay(hour: 24, minute: 0);
  }
  
  /// 특정 날짜의 마지막 예약 가능 시간을 가져옵니다.
  /// (최소 연습 시간 30분을 고려하여 영업 종료 30분 전까지만 예약 가능)
  /// 
  /// [date]: 확인할 날짜 (DateTime 객체)
  /// [branchId]: 지점 ID
  /// [minimumDuration]: 최소 연습 시간(분)
  /// 
  /// 반환값: 마지막 예약 가능 시간 (TimeOfDay 객체)
  static Future<TimeOfDay> getLastReservationTime(DateTime date, String branchId, {int minimumDuration = 30}) async {
    final endTime = await getBusinessEndTime(date, branchId);
    // 종료 시간에서 최소 연습 시간만큼 빼기
    int totalMinutes = endTime.hour * 60 + endTime.minute - minimumDuration;
    int hour = totalMinutes ~/ 60;
    int minute = totalMinutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
} 