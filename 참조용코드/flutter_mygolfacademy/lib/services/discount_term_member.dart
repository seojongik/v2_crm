import 'package:intl/intl.dart';
import 'holiday_service.dart';
import 'reservation_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DiscountTermMember {
  /// 기간권 할인 대상 금액 계산 (내부에서 시뮬레이션 및 시간 계산까지 모두 처리)
  ///
  /// [memberId]: 회원 ID
  /// [tsDate]: 예약 날짜 (yyyy-MM-dd)
  /// [timeSlots]: 시간대별 이용 시간(분) 맵 {'조조': 30, '일반': 20, ...}
  /// [startTimeHours]: 시작 시간 (시)
  /// [startTimeMinutes]: 시작 시간 (분)
  /// [durationMinutes]: 이용 시간(분)
  /// [dayType]: 평일/주말/공휴일
  /// [termType]: 회원의 기간권 타입
  /// 반환: 할인 대상 금액
  static Future<int> calculateTermDiscountTarget({
    required int memberId,
    required String tsDate,
    required Map<String, int> timeSlots,
    required int startTimeHours,
    required int startTimeMinutes,
    required int durationMinutes,
    required String dayType,
    required String termType,
    String? branchId,
  }) async {
    // 시뮬레이션용 값 계산 (1번 타석 기준, 60분)
    int simTotalAmount = 0;
    int simCoveredMinutes = 0;
    Map<String, int> simTimeSlots = {
      '조조': 0,
      '일반': 0,
      '피크': 0,
      '심야': 0,
    };
    final slotRanges = timeSlots.keys.toList();
    for (var slot in slotRanges) {
      if (timeSlots[slot]! > 0) {
        final ratio = timeSlots[slot]! / durationMinutes;
        simTimeSlots[slot] = (ratio * 60).round();
        simCoveredMinutes += simTimeSlots[slot]!;
      }
    }
    if (simCoveredMinutes < 60) {
      simTimeSlots['일반'] = (simTimeSlots['일반'] ?? 0) + (60 - simCoveredMinutes);
    }
    print('[기간권할인-DEBUG] 시뮬레이션용 simTimeSlots: ' + simTimeSlots.toString());
    // 요금표 가져오기
    final priceTable = await ReservationService.getPriceTable(branchId: branchId);
    final simPrices = priceTable[1];
    print('[기간권할인-DEBUG] 시뮬레이션용 priceTable[1]: ' + (simPrices?.toString() ?? 'null'));
    if (simPrices != null) {
      simTimeSlots.forEach((slot, minutes) {
        if (minutes > 0) {
          final int pricePerMinute = simPrices[slot] ?? simPrices['일반'] ?? 0;
          final int discountedPricePerMinute = (pricePerMinute * 0.75).round();
          final int amount = (discountedPricePerMinute * minutes).round();
          simTotalAmount += amount;
        }
      });
      if (simTotalAmount > 0) simTotalAmount -= 1;
    }
    print('[기간권할인-DEBUG] 시뮬레이션용 simTotalAmount: ' + simTotalAmount.toString());
    // 10시 이전 이용 시간(분) 계산
    int minutesBefore10AM = 0;
    final int tenAM = 10 * 60;
    if (startTimeHours * 60 + startTimeMinutes < tenAM) {
      if (startTimeHours * 60 + startTimeMinutes + durationMinutes <= tenAM) {
        minutesBefore10AM = durationMinutes;
      } else {
        minutesBefore10AM = tenAM - (startTimeHours * 60 + startTimeMinutes);
      }
    }
    int cappedMinutesBefore10AM = minutesBefore10AM > 60 ? 60 : minutesBefore10AM;
    int finalFee = 0;
    final ts1Prices = priceTable[1];
    final String earlyTimeSlot = timeSlots.keys.contains('조조') && timeSlots['조조']! > 0 ? '조조' : '일반';
    int earlyMorningPrice = ts1Prices != null
        ? (ts1Prices[earlyTimeSlot] ?? ts1Prices['일반'] ?? 0)
        : 0;
    final int discountedPrice = (earlyMorningPrice * 0.75).round();
    final int earlyMorningFee = discountedPrice * cappedMinutesBefore10AM;
    finalFee = earlyMorningFee > 0 ? earlyMorningFee - 1 : 0;

    // 할인 정책 적용 (기존 로직 재사용)
    int weekdayFlag = (dayType == '평일') ? 1 : 0;
    int holidayFlag = (dayType == '공휴일') ? 1 : 0;
    int weekdayPassFlag = (termType.contains('평일권')) ? 1 : 0;
    int allDayPassFlag = (termType.contains('전일권')) ? 1 : 0;
    int morningPassFlag = (termType.contains('조조권')) ? 1 : 0;
    int resultWeekday = simTotalAmount * weekdayFlag * weekdayPassFlag;
    int resultAllDay = simTotalAmount * allDayPassFlag;
    int resultMorning = finalFee * morningPassFlag;
    int totalPassResult = resultMorning + resultWeekday + resultAllDay;

    // 이미 할인받은 예약이 있는지 확인
    int termDiscountSum = 0;
    try {
      print('[기간권할인] 중복 체크용 API 파라미터: ts_date=$tsDate, member_id=$memberId');
      final url = 'https://autofms.mycafe24.com/dynamic_api.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': [
            {'field': 'member_id', 'operator': '=', 'value': memberId},
            {'field': 'ts_date', 'operator': '=', 'value': tsDate}
          ]
        }),
      );
      print('[기간권할인] 중복 체크 API 응답 status: [32m[1m${response.statusCode}[0m, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final reservations = List<Map<String, dynamic>>.from(data['data']);
          
          // 결제완료 상태인 예약만 필터링
          final paidReservations = reservations.where((r) => r['ts_status'] == '결제완료').toList();
          
          if (paidReservations.isNotEmpty) {
            print('🔍 [디버깅] 정기회원 할인 - 당일 결제완료 예약 ${paidReservations.length}건 발견');
            return 0;
          }
        }
      }
    } catch (e) {
      print('[기간권할인] 중복 체크 예외: $e');
    }
    if (termDiscountSum > 0) {
      return 0;
    } else {
      return totalPassResult;
    }
  }

  /// 기간권 할인 계산 (정기회원 할인)
  static Future<int> calculateTermMemberDiscount({
    required int memberId,
    String? branchId,
    required String tsDate,
    required int finalFee,
    required int simTotalAmount,
  }) async {
    // 기간권 정보 조회
    final membershipInfo = await getMembershipInfo(memberId, branchId, tsDate);
    final String termType = membershipInfo['termType'] ?? '';
    final bool hasMembership = membershipInfo['hasMembership'] == true;
    final String dayType = membershipInfo['dayType'] ?? '';

    if (!hasMembership || termType.isEmpty) {
      return 0;
    }

    // 날짜별 할인 적용 여부 확인
    int weekdayFlag = (dayType == '평일') ? 1 : 0;
    int weekdayPassFlag = (termType.contains('평일권')) ? 1 : 0;
    int allDayPassFlag = (termType.contains('전일권')) ? 1 : 0;
    int morningPassFlag = (termType.contains('조조권')) ? 1 : 0;
    int resultWeekday = simTotalAmount * weekdayFlag * weekdayPassFlag;
    int resultAllDay = simTotalAmount * allDayPassFlag;
    int resultMorning = finalFee * morningPassFlag;
    int totalPassResult = resultMorning + resultWeekday + resultAllDay;

    // 이미 할인받은 예약이 있는지 확인
    int termDiscountSum = 0;
    try {
      print('[기간권할인] 중복 체크용 API 파라미터: ts_date=$tsDate, member_id=$memberId, branch_id=$branchId');
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'ts_date', 'operator': '=', 'value': tsDate}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final url = 'https://autofms.mycafe24.com/dynamic_api.php';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': whereConditions
        }),
      );
      print('[기간권할인] 중복 체크 API 응답 status: [32m[1m${response.statusCode}[0m, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final reservations = List<Map<String, dynamic>>.from(data['data']);
          
          // 결제완료 상태인 예약만 필터링
          final paidReservations = reservations.where((r) => r['ts_status'] == '결제완료').toList();
          
          if (paidReservations.isNotEmpty) {
            print('🔍 [디버깅] 정기회원 할인 - 당일 결제완료 예약 ${paidReservations.length}건 발견');
            return 0;
          }
        }
      }
    } catch (e) {
      print('[기간권할인] 중복 체크 예외: $e');
    }
    if (termDiscountSum > 0) {
      return 0;
    } else {
      return totalPassResult;
    }
  }

  /// 기간권 타입, 날짜로 할인 적용 가능 여부 및 타입 반환
  static Future<Map<String, dynamic>> getMembershipInfo(int memberId, String? branchId, String tsDate) async {
    final membershipInfo = await ReservationService.checkMembershipStatusWithDetails(memberId, branchId);
    final String termType = (membershipInfo['termType'] ?? '').toString();
    final bool hasMembership = membershipInfo['hasMembership'] == true;
    DateTime selectedDate = DateTime.parse(tsDate);
    final bool isHoliday = await HolidayService.isHoliday(selectedDate);
    String dayType;
    if (isHoliday) {
      dayType = '공휴일';
    } else if (selectedDate.weekday == DateTime.saturday) {
      dayType = '주말(토요일)';
    } else if (selectedDate.weekday == DateTime.sunday) {
      dayType = '주말(일요일)';
    } else {
      dayType = '평일';
    }
    return {
      'termType': termType,
      'hasMembership': hasMembership,
      'dayType': dayType,
    };
  }
} 