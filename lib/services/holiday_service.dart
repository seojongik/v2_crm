import 'dart:convert';
import '../constants/font_sizes.dart';
import 'package:http/http.dart' as http;

/// 공휴일 정보를 관리하는 서비스 클래스
class HolidayService {
  static final Map<int, List<String>> _holidayCache = {};
  static final Map<int, Map<String, String>> _holidayNameCache = {}; // 날짜 -> 공휴일 이름 매핑
  static const String _baseUrl = 'http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService';
  // API 키 (실제 사용 시 보안상 더 안전한 방법으로 관리 필요)
  static const String _serviceKey = "GgQ/fdIp9mcf5iowhHT4g0dFzwa/RNOEM/4Rqvjn0SAQHR80WMt3nPIAKY7YSPkacRyW4adSD+pUbBKve10xYQ==";

  /// 지정된 연도의 공휴일 목록을 가져옵니다.
  /// 
  /// [year] 조회할 연도
  /// 반환값: 'YYYY-MM-DD' 형식의 공휴일 날짜 목록
  static Future<List<String>> getHolidays(int year) async {
    // 캐시에서 먼저 확인
    if (_holidayCache.containsKey(year)) {
      return _holidayCache[year]!;
    }

    try {
      // API에서 공휴일 데이터 가져오기
      final holidayData = await _fetchHolidaysFromApi(year);
      final holidays = holidayData.keys.toList();
      
      // 일요일 추가
      final sundays = _getAllSundays(year);
      holidays.addAll(sundays);
      
      // 중복 제거 및 정렬
      final uniqueHolidays = holidays.toSet().toList();
      uniqueHolidays.sort();
      
      // 캐시에 저장
      _holidayCache[year] = uniqueHolidays;
      _holidayNameCache[year] = holidayData;
      
      return uniqueHolidays;
    } catch (e) {
      // 실패 시 일요일만 반환
      final sundays = _getAllSundays(year);
      _holidayCache[year] = sundays;
      _holidayNameCache[year] = {};
      return sundays;
    }
  }

  /// API에서 공휴일 데이터를 가져옵니다.
  static Future<Map<String, String>> _fetchHolidaysFromApi(int year) async {
    try {
      final url = Uri.parse('$_baseUrl/getRestDeInfo')
          .replace(queryParameters: {
        'serviceKey': _serviceKey,
        'solYear': year.toString(),
        'numOfRows': '100',
        '_type': 'json',
      });

      final response = await http.get(url, headers: {
        'Accept': 'application/json; charset=utf-8',
      });
      
      if (response.statusCode == 200) {
        // UTF-8로 디코딩
        final decodedBody = utf8.decode(response.bodyBytes);
        return _parseHolidaysResponse(decodedBody);
      } else {
        throw Exception('API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// API 응답을 파싱하여 공휴일 목록을 반환합니다.
  static Map<String, String> _parseHolidaysResponse(String responseBody) {
    try {
      final jsonData = json.decode(responseBody);
      final items = jsonData['response']['body']['items']['item'];
      
      Map<String, String> holidays = {};
      
      if (items is List) {
        for (var item in items) {
          final dateStr = item['locdate'].toString();
          final holidayName = item['dateName']?.toString() ?? '';
          if (dateStr.length == 8) {
            final formattedDate = '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
            holidays[formattedDate] = holidayName;
          }
        }
      } else if (items is Map) {
        // 단일 항목인 경우
        final dateStr = items['locdate'].toString();
        final holidayName = items['dateName']?.toString() ?? '';
        if (dateStr.length == 8) {
          final formattedDate = '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
          holidays[formattedDate] = holidayName;
        }
      }
      
      return holidays;
    } catch (e) {
      return {};
    }
  }

  /// 지정된 연도의 모든 일요일을 가져옵니다.
  static List<String> _getAllSundays(int year) {
    List<String> sundays = [];
    
    for (int month = 1; month <= 12; month++) {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      
      for (int day = 1; day <= lastDay.day; day++) {
        final date = DateTime(year, month, day);
        if (date.weekday == DateTime.sunday) {
          final formattedDate = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          sundays.add(formattedDate);
        }
      }
    }
    
    return sundays;
  }

  /// 특정 날짜가 공휴일인지 확인합니다.
  /// 
  /// [date] 확인할 날짜
  /// 반환값: 공휴일이면 true, 아니면 false
  static Future<bool> isHoliday(DateTime date) async {
    final holidays = await getHolidays(date.year);
    final dateString = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return holidays.contains(dateString);
  }

  /// 특정 날짜의 공휴일 이름을 가져옵니다.
  /// 
  /// [date] 확인할 날짜
  /// 반환값: 공휴일 이름 (공휴일이 아니면 null)
  static String? getHolidayName(DateTime date) {
    final year = date.year;
    if (!_holidayNameCache.containsKey(year)) {
      return null;
    }
    
    final dateString = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _holidayNameCache[year]![dateString];
  }

  /// 캐시를 초기화합니다.
  static void clearCache() {
    _holidayCache.clear();
    _holidayNameCache.clear();
  }

  /// 특정 연도의 캐시를 삭제합니다.
  static void clearYearCache(int year) {
    _holidayCache.remove(year);
    _holidayNameCache.remove(year);
  }

  /// 현재 캐시된 연도 목록을 반환합니다.
  static List<int> getCachedYears() {
    return _holidayCache.keys.toList()..sort();
  }
} 