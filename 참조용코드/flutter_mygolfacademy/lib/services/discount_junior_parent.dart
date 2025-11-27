import 'dart:async';
import 'package:intl/intl.dart';
import '../utils/time_slot_utils.dart';
import 'holiday_service.dart';

class DiscountJuniorParent {
  /// 주니어 학부모 할인 금액 및 안내 메시지 반환 (겹침, 중복, 안내, 금액 계산 모두 포함)
  ///
  /// [paidReservations]: 결제완료 예약 리스트
  /// [tsNumber]: 타석 번호
  /// [tsDate]: 타석 날짜
  /// [tsStart]: 타석 시작 시간
  /// [tsEnd]: 타석 종료 시간
  /// [priceTable]: 가격 테이블
  ///
  /// 반환값 예시:
  /// {
  ///   'amount': 1530,
  ///   'message': '주니어 학부모할인 금액 : 1530원',
  ///   'duplicateMessage': null,
  ///   'duplicatedReservationIds': [],
  ///   'overlapTimeSlots': {'조조': 0, '일반': 0, '피크': 0, '심야': 0},
  ///   'totalAmount': 1530
  /// }
  static Future<Map<String, dynamic>> calculateJuniorParentDiscount({
    required List<dynamic> paidReservations,
    required int tsNumber,
    required String tsDate,
    required String tsStart,
    required String tsEnd,
    required Map<int, Map<String, int>> priceTable,
  }) async {
    try {
      // 1. 중복 할인 체크 (junior_discount > 0)
      int juniorDiscountSum = 0;
      List<dynamic> juniorDiscountReservationIds = [];
      for (var r in paidReservations) {
        final val = r['junior_discount'];
        if (val is int && val > 0) {
          juniorDiscountSum += val;
          juniorDiscountReservationIds.add(r['reservation_id']);
        } else if (val is String) {
          final parsed = int.tryParse(val) ?? 0;
          if (parsed > 0) {
            juniorDiscountSum += parsed;
            juniorDiscountReservationIds.add(r['reservation_id']);
          }
        }
      }

      // 2. 겹치는 시간 계산 (주니어 예약과 시도 예약이 겹치는지)
      DateTime selStart = DateTime.parse('$tsDate $tsStart');
      DateTime selEnd = DateTime.parse('$tsDate $tsEnd');
      final juniorReservations = paidReservations.where((r) => r['ts_type'] == '주니어').toList();
      int totalAmount = 0;
      Map<String, int> overlapTimeSlots = {
        '조조': 0,
        '일반': 0,
        '피크': 0,
        '심야': 0,
      };
      if (juniorReservations.isNotEmpty) {
        for (var r in juniorReservations) {
          try {
            DateTime resStart = DateTime.parse('$tsDate ${r['ts_start']}');
            DateTime resEnd = DateTime.parse('$tsDate ${r['ts_end']}');
            DateTime overwrapStart = selStart.isAfter(resStart) ? selStart : resStart;
            DateTime overwrapEnd = selEnd.isBefore(resEnd) ? selEnd : resEnd;
            if (overwrapStart.isBefore(overwrapEnd)) {
              final isHoliday = await HolidayService.isHoliday(overwrapStart);
              Map<String, List<List<int>>> timeSlots;
              if (isHoliday) {
                timeSlots = TimeSlotUtils.getHolidayTimeSlots();
              } else {
                timeSlots = TimeSlotUtils.getWeekdayTimeSlots();
              }
              int startMinute = overwrapStart.hour * 60 + overwrapStart.minute;
              int endMinute = overwrapEnd.hour * 60 + overwrapEnd.minute;
              for (int m = startMinute; m < endMinute; m++) {
                String slot = '일반';
                timeSlots.forEach((key, ranges) {
                  for (var range in ranges) {
                    if (m >= range[0] && m < range[1]) slot = key;
                  }
                });
                overlapTimeSlots[slot] = (overlapTimeSlots[slot] ?? 0) + 1;
              }
            }
          } catch (_) {}
        }
      }
      // 3. 요금 시뮬레이션 (겹치는 시간 기준, 내가 예약하려는 타석 단가)
      if (overlapTimeSlots.values.any((v) => v > 0)) {
        final prices = priceTable[tsNumber];
        overlapTimeSlots.forEach((timeSlot, minutes) {
          if (minutes > 0 && prices != null) {
            final int pricePerMinute = prices[timeSlot] ?? prices['일반'] ?? 0;
            totalAmount += (pricePerMinute * minutes).round();
          }
        });
      }
      // 4. 할인 금액 계산
      int amount = (totalAmount * 0.15).round();
      String message = '';
      String? duplicateMessage;
      if (juniorDiscountSum > 0) {
        amount = 0;
        message = '주니어 학부모할인 금액 : 0원';
        duplicateMessage = '주니어 레슨 이력이 있음- 중복할인 불가 (할인 적용 예약: ${juniorDiscountReservationIds})';
      } else {
        message = '주니어 학부모할인 금액 : ${amount}원';
        duplicateMessage = null;
      }
      return {
        'amount': amount,
        'message': message,
        'duplicateMessage': duplicateMessage,
        'duplicatedReservationIds': juniorDiscountReservationIds,
        'overlapTimeSlots': overlapTimeSlots,
        'totalAmount': totalAmount,
      };
    } catch (e) {
      return {
        'amount': 0,
        'message': '주니어 학부모할인 금액 : 0원',
        'duplicateMessage': '할인 계산 중 오류 발생: $e',
        'duplicatedReservationIds': [],
        'overlapTimeSlots': {},
        'totalAmount': 0,
        'error': e.toString(),
      };
    }
  }
}
