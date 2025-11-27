import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DiscountRevisit {
  static const String _apiKey = 'autofms_secure_key_2025';
  static const String _serverHost = 'autofms.mycafe24.com';

  /// 직전 1주일(오늘 제외) 결제완료+30분이상+일반 예약 내역 조회 (디버깅용)
  static Future<void> debugRevisitReservations({
    required int memberId,
    String? branchId,
    required String baseDate,
  }) async {
    DateTime base = DateTime.parse(baseDate);
    List<String> tsDates = List.generate(7, (i) =>
      DateFormat('yyyy-MM-dd').format(base.subtract(Duration(days: i + 1)))
    );

    try {
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'scheduled_date', 'operator': 'IN', 'value': tsDates},
        {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        {'field': 'ts_type', 'operator': '=', 'value': '일반'}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse('https://$_serverHost/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'fields': ['reservation_id', 'ts_min', 'ts_type', 'ts_status', 'scheduled_date'],
          'where': whereConditions
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final reservations = responseData['data'] as List<dynamic>;
          final filtered = reservations.where((r) =>
            (r['ts_min'] is int ? r['ts_min'] >= 30 : int.tryParse(r['ts_min'].toString()) ?? 0 >= 30)
          ).toList();
          final ids = filtered.map((r) => r['reservation_id']).toList();
          // ts_min 합산 및 환산시간 계산
          int totalMinutes = filtered.fold(0, (sum, r) {
            int min = r['ts_min'] is int ? r['ts_min'] : int.tryParse(r['ts_min'].toString()) ?? 0;
            return sum + min;
          });
          double hours = totalMinutes / 60.0;
          int hourFloor = hours.floor();
          print('🟢 [직전 1주일 결제완료+30분이상+일반 예약]');
          print('reservation_id 목록: $ids');
          print('총 개수: ${ids.length}');
          print('합산 이용 분(totalMinutes): $totalMinutes');
          print('환산 이용 횟수(hours): ${hours.toStringAsFixed(2)}');
          print('내림 환산 횟수(hourFloor): $hourFloor');
        } else {
          print('❌ 예약 내역 조회 실패: ${responseData['error']}');
        }
      } else {
        print('❌ 서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 예약 내역 조회 중 예외: $e');
    }
  }

  /// 직전 1주일(오늘 제외) 결제완료+30분이상+일반 예약 재방문 할인액 계산
  static Future<Map<String, dynamic>> calculateRevisitDiscountAmount({
    required int memberId,
    String? branchId,
    required String baseDate,
  }) async {
    DateTime base = DateTime.parse(baseDate);
    List<String> tsDates = List.generate(7, (i) =>
      DateFormat('yyyy-MM-dd').format(base.subtract(Duration(days: i + 1)))
    );

    try {
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'scheduled_date', 'operator': 'IN', 'value': tsDates},
        {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        {'field': 'ts_type', 'operator': '=', 'value': '일반'}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse('https://$_serverHost/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'fields': ['reservation_id', 'ts_min', 'ts_type', 'ts_status', 'scheduled_date'],
          'where': whereConditions
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final reservations = responseData['data'] as List<dynamic>;
          final filtered = reservations.where((r) =>
            (r['ts_min'] is int ? r['ts_min'] >= 30 : int.tryParse(r['ts_min'].toString()) ?? 0 >= 30)
          ).toList();
          // ts_min 합산
          int totalMinutes = filtered.fold(0, (sum, r) {
            int min = r['ts_min'] is int ? r['ts_min'] : int.tryParse(r['ts_min'].toString()) ?? 0;
            return sum + min;
          });
          double hours = totalMinutes / 60.0;
          int hourFloor = hours.floor();
          int discount = 0;
          if (hourFloor >= 1 && hourFloor < 2) discount = 1000;
          else if (hourFloor >= 2 && hourFloor < 3) discount = 2000;
          else if (hourFloor >= 3) discount = 3000;
          return {
            'discount': discount,
            'count': hourFloor, // 환산시간의 내림값
            'reservationIds': filtered.map((r) => r['reservation_id']).toList(),
            'totalMinutes': totalMinutes,
            'hours': hours,
          };
        }
      }
      return {'discount': 0, 'count': 0, 'reservationIds': [], 'totalMinutes': 0, 'hours': 0.0};
    } catch (e) {
      return {'discount': 0, 'count': 0, 'reservationIds': [], 'totalMinutes': 0, 'hours': 0.0, 'error': e.toString()};
    }
  }
} 