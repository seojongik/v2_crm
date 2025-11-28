import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/ts_reservation.dart';
import '/services/api_service.dart';
import '../../constants/font_sizes.dart';

/// 예약 취소 시뮬레이션 결과 모델
class CancellationSimulation {
  final int refundAmount;
  final int penaltyAmount;
  final int finalRefund;
  final String description;
  final List<Map<String, dynamic>> affectedCoupons;
  final Map<String, dynamic> billChanges;
  final Map<String, dynamic> billTimeChanges;

  CancellationSimulation({
    required this.refundAmount,
    required this.penaltyAmount,
    required this.finalRefund,
    required this.description,
    required this.affectedCoupons,
    required this.billChanges,
    required this.billTimeChanges,
  });
}

/// 취소 정책 시뮬레이션 서비스 클래스
class TsCancellationSimulationService {
  /// 취소 시뮬레이션 실행 (DB 변경 없이 미리보기)
  static Future<CancellationSimulation> simulateCancellation(
    TsReservation reservation, {
    bool applyPenalty = true,
  }) async {
    try {
      // 1. 취소 정책 조회
      final cancellationPolicy = await _getCancellationPolicy(reservation);
      
      // 2. 최종 수수료율 결정
      double finalPenaltyPercent;
      if (applyPenalty) {
        // 정책에 따른 취소: 정책에서 정의된 수수료율 적용
        final penaltyValue = cancellationPolicy['penalty_percent'];
        if (penaltyValue != null) {
          if (penaltyValue is String) {
            finalPenaltyPercent = double.tryParse(penaltyValue) ?? 0.0;
          } else if (penaltyValue is num) {
            finalPenaltyPercent = penaltyValue.toDouble();
          } else {
            finalPenaltyPercent = 0.0;
          }
        } else {
          finalPenaltyPercent = 0.0;
        }
      } else {
        // 관리자 재량 취소: 수수료 면제 (0%)
        finalPenaltyPercent = 0.0;
      }
      
      // 4. 환불/수수료 계산
      final netAmount = reservation.netAmt ?? 0;
      final penaltyAmount = (netAmount * finalPenaltyPercent / 100).round();
      final refundAmount = netAmount - penaltyAmount;
      
      // 5. 영향받는 쿠폰 조회
      final affectedCoupons = await _getAffectedCoupons(reservation.reservationId!);
      
      // 6. Bills 테이블 변경사항 계산
      final billChanges = await _calculateBillChanges(reservation, refundAmount, penaltyAmount);
      
      // 7. Bill times 테이블 변경사항 계산
      final billTimeChanges = await _calculateBillTimeChanges(reservation);
      
      // 7-1. 사용된 쿠폰 조회 (사용취소 대상)
      final usedCoupons = await _getUsedCoupons(reservation.reservationId!);
      
      // 7-2. 발급된 쿠폰 조회 (발급취소 대상)
      final issuedCoupons = await _getIssuedCoupons(reservation.reservationId!);

      // 8. 설명 텍스트 생성
      final description = _generateDescription(
        netAmount, 
        penaltyAmount, 
        refundAmount, 
        finalPenaltyPercent,
        applyPenalty,
        usedCoupons,
        issuedCoupons,
        reservation.tsPaymentMethod,
        reservation.tsMin ?? 0
      );
      
      return CancellationSimulation(
        refundAmount: refundAmount,
        penaltyAmount: penaltyAmount,
        finalRefund: refundAmount,
        description: description,
        affectedCoupons: affectedCoupons,
        billChanges: billChanges,
        billTimeChanges: billTimeChanges,
      );
    } catch (e) {
      print('취소 시뮬레이션 오류: $e');
      rethrow;
    }
  }
  
  /// 취소 정책 조회 (시간 기반 정확한 계산)
  static Future<Map<String, dynamic>> _getCancellationPolicy(TsReservation reservation) async {
    try {
      print('🔍 취소 정책 조회 시작 (v2_bills)');
      
      // 1. 해당 테이블의 취소 정책 조회 (apply_sequence 순으로 정렬)
      final policies = await ApiService.getDataList(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'db_table', 'operator': '=', 'value': 'v2_bills'}
        ],
        orderBy: [
          {'field': 'apply_sequence', 'direction': 'ASC'}
        ],
      );

      if (policies.isEmpty) {
        print('❌ 취소 정책을 찾을 수 없습니다: v2_bills');
        return {'penalty_percent': 0}; // 정책이 없으면 무료 취소
      }

      // 2. 예약 시작 시간 계산
      final reservationDate = DateTime.parse(reservation.tsDate!);
      final startTimeParts = reservation.tsStart!.split(':');
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final reservationStartTime = DateTime(
        reservationDate.year,
        reservationDate.month,
        reservationDate.day,
        startHour,
        startMinute,
      );

      // 3. 현재 시간과 예약 시작 시간의 차이를 분 단위로 계산
      final now = DateTime.now();
      final timeDifferenceInMinutes = reservationStartTime.difference(now).inMinutes;
      
      print('현재 시간: $now');
      print('예약 시작 시간: $reservationStartTime');
      print('시간 차이: ${timeDifferenceInMinutes}분');

      // 4. 현재 시간이 예약 시작 시간을 지났다면 apply_sequence 1번 적용
      if (timeDifferenceInMinutes < 0) {
        print('⚠️ 예약 시작 시간이 지났습니다. apply_sequence 1번 적용');
        final firstPolicy = policies.firstWhere(
          (policy) => int.parse(policy['apply_sequence'].toString()) == 1,
          orElse: () => policies.first,
        );
        final penaltyPercent = int.parse(firstPolicy['penalty_percent'].toString());
        print('✅ 적용할 정책: apply_sequence 1번, ${penaltyPercent}% 페널티');
        return {'penalty_percent': penaltyPercent};
      }

      // 5. apply_sequence 순으로 정책 적용
      for (final policy in policies) {
        final minBeforeUse = int.parse(policy['_min_before_use'].toString());
        final penaltyPercent = int.parse(policy['penalty_percent'].toString());
        final sequence = int.parse(policy['apply_sequence'].toString());
        
        print('정책 확인 - sequence: $sequence, min_before_use: $minBeforeUse, penalty: $penaltyPercent%');

        if (timeDifferenceInMinutes <= minBeforeUse) {
          print('✅ 적용할 정책 발견: ${penaltyPercent}% 페널티');
          return {'penalty_percent': penaltyPercent};
        }
      }

      // 6. 어떤 정책에도 해당하지 않으면 무료 취소 가능
      print('✅ 무료 취소 가능 기간');
      return {'penalty_percent': 0};
      
    } catch (e) {
      print('취소 정책 조회 오류: $e');
      return {'penalty_percent': 0};
    }
  }
  
  /// 사용된 쿠폰 조회 (사용취소 대상)
  static Future<List<Map<String, dynamic>>> _getUsedCoupons(String reservationId) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      print('🔍 사용된 쿠폰 조회 시작');
      print('  - reservationId: $reservationId');
      print('  - branchId: $branchId');
      
      if (branchId == null) {
        print('❌ 현재 branch_id가 null입니다. 쿠폰 조회를 생략합니다.');
        return [];
      }
      
      final whereConditions = [
        {'field': 'reservation_id_used', 'operator': '=', 'value': reservationId},
        {'field': 'coupon_status', 'operator': '=', 'value': '사용'},
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ];
      
      print('  - where 조건: $whereConditions');
      
      final result = await ApiService.getDataList(
        table: 'v2_discount_coupon',
        where: whereConditions,
      );
      
      print('✅ 사용된 쿠폰 조회 완료: ${result.length}건');
      for (var coupon in result) {
        // ID 필드명 확인 (coupon_id가 실제 필드명)
        final couponId = coupon['coupon_id'] ?? 'unknown';
        print('  - 사용된 쿠폰 ID: $couponId, 상태: ${coupon['coupon_status']}');
        print('    전체 데이터: $coupon');
      }
      return result;
    } catch (e) {
      print('❌ 사용된 쿠폰 조회 오류: $e');
      return [];
    }
  }
  
  /// 발급된 쿠폰 조회 (발급취소 대상)
  static Future<List<Map<String, dynamic>>> _getIssuedCoupons(String reservationId) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      print('🔍 발급된 쿠폰 조회 시작');
      print('  - reservationId: $reservationId');
      print('  - branchId: $branchId');
      
      if (branchId == null) {
        print('❌ 현재 branch_id가 null입니다. 쿠폰 조회를 생략합니다.');
        return [];
      }
      
      final whereConditions = [
        {'field': 'reservation_id_issued', 'operator': '=', 'value': reservationId},
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ];
      
      print('  - where 조건: $whereConditions');
      
      final result = await ApiService.getDataList(
        table: 'v2_discount_coupon',
        where: whereConditions,
      );
      
      // 중요: 사용된 쿠폰은 제외 (reservation_id_used가 같은 예약ID인 경우 제외)
      // 발급만 된 쿠폰만 취소 대상
      final filteredResult = result.where((coupon) {
        final status = coupon['coupon_status']?.toString() ?? '';
        final usedReservationId = coupon['reservation_id_used']?.toString() ?? '';
        
        // 이미 취소된 쿠폰 제외
        if (status == '취소') return false;
        
        // 같은 예약에서 사용된 쿠폰은 제외 (발급된 것이지만 이미 사용됨)
        if (usedReservationId == reservationId) {
          print('  - 제외: 쿠폰 ID ${coupon['coupon_bill_id']} (같은 예약에서 사용됨)');
          return false;
        }
        
        return true;
      }).toList();
      
      print('✅ 발급된 쿠폰 조회 완료: ${result.length}건 (필터링 후: ${filteredResult.length}건)');
      for (var coupon in filteredResult) {
        // ID 필드명 확인 (coupon_id가 실제 필드명)
        final couponId = coupon['coupon_id'] ?? 'unknown';
        print('  - 발급된 쿠폰 ID: $couponId, 상태: ${coupon['coupon_status']}');
      }
      return filteredResult;
    } catch (e) {
      print('❌ 발급된 쿠폰 조회 오류: $e');
      return [];
    }
  }

  /// 영향받는 쿠폰 조회 (기존 호환성 유지)
  static Future<List<Map<String, dynamic>>> _getAffectedCoupons(String reservationId) async {
    return await _getUsedCoupons(reservationId);
  }
  
  /// Bills 테이블 변경사항 계산
  static Future<Map<String, dynamic>> _calculateBillChanges(
    TsReservation reservation, 
    int refundAmount, 
    int penaltyAmount
  ) async {
    try {
      // 기존 bill 레코드 조회
      final bills = await ApiService.getBillsData(
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': reservation.reservationId},
        ],
      );
      
      if (bills.isEmpty) {
        return {};
      }
      
      final bill = bills[0];
      // v2_bills 테이블의 실제 필드명 사용
      final currentBalanceAfter = bill['bill_balance_after'] ?? 0;
      
      return {
        'bill_id': bill['bill_id'],
        'current_balance': currentBalanceAfter,
        'refund_amount': refundAmount,
        'penalty_amount': penaltyAmount,
        'new_balance': currentBalanceAfter + refundAmount, // 환불시 잔액 증가
        'status_change': '예약취소',
      };
    } catch (e) {
      print('Bills 변경사항 계산 오류: $e');
      return {};
    }
  }
  
  /// Bill times 테이블 변경사항 계산
  static Future<Map<String, dynamic>> _calculateBillTimeChanges(TsReservation reservation) async {
    try {
      // 해당 예약의 bill_min_id 조회
      final billTimes = await ApiService.getBillTimesData(
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': reservation.reservationId},
        ],
      );
      
      if (billTimes.isEmpty) {
        return {};
      }
      
      final billTime = billTimes[0];
      
      return {
        'bill_min_id': billTime['bill_min_id'],
        'current_remaining_time': billTime['remaining_time'] ?? 0,
        'refund_time': reservation.tsMin ?? 0,
        'new_remaining_time': (billTime['remaining_time'] ?? 0) + (reservation.tsMin ?? 0),
        'status_change': '예약취소',
      };
    } catch (e) {
      print('Bill times 변경사항 계산 오류: $e');
      return {};
    }
  }
  
  /// 설명 텍스트 생성
  static String _generateDescription(
    int netAmount, 
    int penaltyAmount, 
    int refundAmount, 
    double penaltyPercent,
    bool applyPenalty,
    List<Map<String, dynamic>> usedCoupons,
    List<Map<String, dynamic>> issuedCoupons,
    String? paymentMethod,
    int tsMin
  ) {
    final formatter = NumberFormat('#,###');
    String description = '';
    final isTimePayment = paymentMethod == '시간권';
    
    if (applyPenalty) {
      if (penaltyPercent == 0.0) {
        // 무료 취소 가능 시간
        if (isTimePayment) {
          description = '''무료 취소 가능시간
결제액: ${tsMin}분 (전액환불)''';
        } else {
          description = '''무료 취소 가능시간
결제액: ${formatter.format(netAmount)}원 (전액환불)''';
        }
      } else {
        // 취소 패널티 적용
        if (isTimePayment) {
          final penaltyTime = (tsMin * penaltyPercent / 100).round();
          final refundTime = tsMin - penaltyTime;
          description = '''취소패널티 적용 부분환불
결제액: ${refundTime}분 (${(100 - penaltyPercent).toStringAsFixed(0)}% 환불)''';
        } else {
          description = '''취소패널티 적용 부분환불
결제액: ${formatter.format(refundAmount)}원 (${(100 - penaltyPercent).toStringAsFixed(0)}% 환불)''';
        }
      }
    } else {
      // 관리자 재량 전액 환불
      if (isTimePayment) {
        description = '''관리자 재량 전액 환불
결제액: ${tsMin}분 (전액환불)''';
      } else {
        description = '''관리자 재량 전액 환불
결제액: ${formatter.format(netAmount)}원 (전액환불)''';
      }
    }
    
    return description;
  }
}

/// 예약 취소 관련 기능을 담당하는 서비스 클래스
class TsReservationCancelService {
  /// 예약 취소 가능 여부 확인
  static bool canCancelReservation(TsReservation reservation) {
    final now = DateTime.now();
    final reservationDate = DateTime.parse(reservation.tsDate ?? now.toString().split(' ')[0]);
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(reservationDate.year, reservationDate.month, reservationDate.day);
    
    // 이미 취소된 예약은 취소 불가
    if (reservation.tsStatus == '예약취소') {
      return false;
    }
    
    // 선택된 날짜가 오늘 이후인 경우 (미래 예약)
    if (selectedDate.isAfter(today)) {
      return true;
    }
    
    // 선택된 날짜가 오늘인 경우, 예약 시작 시간이 현재 시간 이후인지 확인
    if (selectedDate.isAtSameMomentAs(today)) {
      final startTimeParts = (reservation.tsStart ?? '').split(':');
      if (startTimeParts.length >= 2) {
        final startHour = int.tryParse(startTimeParts[0]) ?? 0;
        final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
        final startDateTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
        
        // 예약 시작 시간이 현재 시간 이후인 경우 (미래 예약)
        return startDateTime.isAfter(now);
      }
    }
    
    // 과거 예약 또는 진행 중인 예약은 취소 불가
    return false;
  }

  /// 예약 취소 처리 (단순 버전 - 기존 호환성 유지)
  static Future<bool> cancelReservation(TsReservation reservation) async {
    return await adminCancelTsReservation(reservation, applyPenalty: false);
  }
  
  /// 관리자용 예약 취소 처리 (비즈니스 로직 포함)
  static Future<bool> adminCancelTsReservation(
    TsReservation reservation, {
    bool applyPenalty = true,
  }) async {
    bool pricedTsUpdated = false;
    bool billsUpdated = false;
    bool billTimesUpdated = false;
    bool couponsUpdated = false;
    
    try {
      print('\n=== 관리자 예약 취소 시작 ===');
      print('예약 ID: ${reservation.reservationId}');
      print('수수료 적용: ${applyPenalty ? "정책 적용" : "면제"}');
      
      // 디버깅: 모든 관련 쿠폰 조회
      final branchId = ApiService.getCurrentBranchId();
      if (branchId != null) {
        print('\n=== 디버깅: 모든 관련 쿠폰 조회 ===');
        final allCoupons = await ApiService.getDataList(
          table: 'v2_discount_coupon',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
          ],
        );
        
        final relatedCoupons = allCoupons.where((coupon) {
          final usedReservationId = coupon['reservation_id_used']?.toString() ?? '';
          final issuedReservationId = coupon['reservation_id_issued']?.toString() ?? '';
          return usedReservationId == reservation.reservationId || 
                 issuedReservationId == reservation.reservationId;
        }).toList();
        
        print('관련 쿠폰 총 ${relatedCoupons.length}개 발견:');
        for (var coupon in relatedCoupons) {
          print('  - 쿠폰 ID: ${coupon['coupon_bill_id']}');
          print('    상태: ${coupon['coupon_status']}');
          print('    reservation_id_used: ${coupon['reservation_id_used']}');
          print('    reservation_id_issued: ${coupon['reservation_id_issued']}');
        }
      }
      
      // 1. 시뮬레이션 실행하여 변경사항 계산
      final simulation = await TsCancellationSimulationService.simulateCancellation(
        reservation,
        applyPenalty: applyPenalty,
      );
      
      print('환불 금액: ${simulation.refundAmount}원');
      print('수수료: ${simulation.penaltyAmount}원');
      
      // 2. v2_priced_TS 테이블 업데이트
      print('\n=== 1단계: v2_priced_TS 업데이트 ===');
      await ApiService.updateTsData(
        {'ts_status': '예약취소'},
        [
          {
            'field': 'reservation_id',
            'operator': '=',
            'value': reservation.reservationId!,
          },
        ],
      );
      pricedTsUpdated = true;
      print('✅ v2_priced_TS 업데이트 완료');
      
      // 3. v2_bills 테이블 업데이트 및 연쇄 잔액 재계산
      if (simulation.billChanges.isNotEmpty) {
        print('\n=== 2단계: v2_bills 업데이트 및 연쇄 잔액 재계산 ===');
        
        final billId = simulation.billChanges['bill_id'];
        final refundAmount = simulation.refundAmount;
        final penaltyAmount = simulation.penaltyAmount;
        
        // 3-1. 취소 대상 bill 조회
        final targetBills = await ApiService.getBillsData(
          where: [
            {'field': 'bill_id', 'operator': '=', 'value': billId},
          ],
        );
        
        if (targetBills.isNotEmpty) {
          final targetBill = targetBills[0];
          final contractHistoryId = targetBill['contract_history_id'];
          final originalNetAmt = targetBill['bill_netamt'] ?? 0;
          final originalBalanceBefore = targetBill['bill_balance_before'] ?? 0;
          
          // 3-2. 페널티 적용한 새로운 금액 계산
          final newNetAmt = applyPenalty ? -penaltyAmount : 0; // 페널티만 차감
          final newBalanceAfter = originalBalanceBefore + newNetAmt;
          
          print('원래 사용금액: ${originalNetAmt}');
          print('페널티: ${penaltyAmount}');
          print('환불금액: ${refundAmount}');
          print('새로운 netamt: ${newNetAmt}');
          print('새로운 balance_after: ${newBalanceAfter}');
          
          // 3-3. 취소 대상 레코드 업데이트
          await ApiService.updateData(
            table: 'v2_bills',
            data: {
              'bill_netamt': newNetAmt,
              'bill_balance_after': newBalanceAfter,
              'bill_status': '예약취소',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [
              {'field': 'bill_id', 'operator': '=', 'value': billId},
            ],
          );
          
          // 3-4. 동일 계약의 후속 레코드들 조회
          final subsequentBills = await ApiService.getDataList(
            table: 'v2_bills',
            where: [
              {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
              {'field': 'bill_id', 'operator': '>', 'value': billId},
            ],
            orderBy: [{'field': 'bill_id', 'direction': 'ASC'}],
          );
          
          if (subsequentBills.isNotEmpty) {
            print('후속 레코드 ${subsequentBills.length}개 발견 - 연쇄 잔액 재계산 시작');
            
            // 3-5. 모든 레코드를 메모리에 로드 (취소 대상 포함)
            final allBills = [
              {
                ...targetBill,
                'bill_balance_after': newBalanceAfter, // 업데이트된 값
              },
              ...subsequentBills,
            ];
            
            // 3-6. 연쇄 잔액 재계산
            for (int i = 1; i < allBills.length; i++) {
              final currentBill = allBills[i];
              final prevBalanceAfter = allBills[i - 1]['bill_balance_after'];
              final currentNetAmt = currentBill['bill_netamt'] ?? 0;
              final newBeforeBalance = prevBalanceAfter;
              final newAfterBalance = newBeforeBalance + currentNetAmt;
              
              print('bill_id ${currentBill['bill_id']}: before ${currentBill['bill_balance_before']} → ${newBeforeBalance}, after ${currentBill['bill_balance_after']} → ${newAfterBalance}');
              
              // DB 업데이트
              await ApiService.updateData(
                table: 'v2_bills',
                where: [
                  {'field': 'bill_id', 'operator': '=', 'value': currentBill['bill_id']},
                ],
                data: {
                  'bill_balance_before': newBeforeBalance,
                  'bill_balance_after': newAfterBalance,
                  'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                },
              );
              
              // 메모리상 데이터도 업데이트 (다음 반복을 위해)
              allBills[i]['bill_balance_after'] = newAfterBalance;
            }
            
            print('✅ 연쇄 잔액 재계산 완료');
          }
          
          billsUpdated = true;
          print('✅ v2_bills 업데이트 완료 (상태: 결제완료 → 예약취소)');
        }
      }
      
      // 4. v2_bill_times 테이블 업데이트 및 연쇄 시간잔액 재계산
      if (simulation.billTimeChanges.isNotEmpty) {
        print('\n=== 3단계: v2_bill_times 업데이트 및 연쇄 시간잔액 재계산 ===');
        
        final billMinId = simulation.billTimeChanges['bill_min_id'];
        final refundTime = reservation.tsMin ?? 0;
        
        // 4-1. 취소 대상 bill_time 조회
        final targetBillTimes = await ApiService.getBillTimesData(
          where: [
            {'field': 'bill_min_id', 'operator': '=', 'value': billMinId},
          ],
        );
        
        if (targetBillTimes.isNotEmpty) {
          final targetBillTime = targetBillTimes[0];
          final contractHistoryId = targetBillTime['contract_history_id'];
          final originalBillMin = targetBillTime['bill_min'] ?? 0;
          final originalBalanceBefore = targetBillTime['bill_balance_min_before'];
          final billStatus = targetBillTime['bill_status'];
          
          // 4-2. 빈 슬롯 체크
          if (originalBalanceBefore == null || originalBalanceBefore == 0) {
            print('⚠️ 빈 슬롯 또는 잔액이 0인 레코드 - 단순 상태 변경만 수행');
            
            await ApiService.updateData(
              table: 'v2_bill_times',
              where: [
                {'field': 'bill_min_id', 'operator': '=', 'value': billMinId},
              ],
              data: {
                'bill_status': '예약취소',
                'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
              },
            );
            
            billTimesUpdated = true;
            print('✅ v2_bill_times 상태 업데이트 완료');
            return true; // 빈 슬롯은 여기서 종료
          }
          
          // 4-3. 페널티 적용한 새로운 시간 계산
          final penaltyPercent = applyPenalty ? (simulation.penaltyAmount.toDouble() / simulation.refundAmount.toDouble()) : 0.0;
          final penaltyTime = (originalBillMin * penaltyPercent).round();
          final newBillMin = applyPenalty ? penaltyTime : 0; // 페널티만 차감
          final newBalanceAfter = originalBalanceBefore - newBillMin; // 시간은 차감!
          
          print('원래 사용시간: ${originalBillMin}분');
          print('페널티율: ${(penaltyPercent * 100).toStringAsFixed(0)}%');
          print('페널티 시간: ${penaltyTime}분');
          print('환불시간: ${originalBillMin - penaltyTime}분');
          print('새로운 bill_min: ${newBillMin}분');
          print('새로운 balance_after: ${newBalanceAfter}분');
          
          // 4-4. 취소 대상 레코드 업데이트
          await ApiService.updateData(
            table: 'v2_bill_times',
            data: {
              'bill_min': newBillMin,
              'bill_balance_min_after': newBalanceAfter,
              'bill_status': '예약취소',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [
              {'field': 'bill_min_id', 'operator': '=', 'value': billMinId},
            ],
          );
          
          // 4-5. 동일 계약의 후속 레코드들 조회
          final subsequentBillTimes = await ApiService.getDataList(
            table: 'v2_bill_times',
            where: [
              {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
              {'field': 'bill_min_id', 'operator': '>', 'value': billMinId},
            ],
            orderBy: [{'field': 'bill_min_id', 'direction': 'ASC'}],
          );
          
          if (subsequentBillTimes.isNotEmpty) {
            print('후속 레코드 ${subsequentBillTimes.length}개 발견 - 연쇄 시간잔액 재계산 시작');
            
            // 4-6. 모든 레코드를 메모리에 로드 (취소 대상 포함)
            final allBillTimes = [
              {
                ...targetBillTime,
                'bill_balance_min_after': newBalanceAfter, // 업데이트된 값
              },
              ...subsequentBillTimes,
            ];
            
            // 4-7. 연쇄 시간잔액 재계산
            for (int i = 1; i < allBillTimes.length; i++) {
              final currentBillTime = allBillTimes[i];
              final prevBalanceAfter = allBillTimes[i - 1]['bill_balance_min_after'];
              final currentBillMin = currentBillTime['bill_min'] ?? 0;
              final newBeforeBalance = prevBalanceAfter;
              final newAfterBalance = newBeforeBalance - currentBillMin; // 시간은 차감!
              
              print('bill_min_id ${currentBillTime['bill_min_id']}: before ${currentBillTime['bill_balance_min_before']} → ${newBeforeBalance}, after ${currentBillTime['bill_balance_min_after']} → ${newAfterBalance}');
              
              // DB 업데이트
              await ApiService.updateData(
                table: 'v2_bill_times',
                where: [
                  {'field': 'bill_min_id', 'operator': '=', 'value': currentBillTime['bill_min_id']},
                ],
                data: {
                  'bill_balance_min_before': newBeforeBalance,
                  'bill_balance_min_after': newAfterBalance,
                  'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                },
              );
              
              // 메모리상 데이터도 업데이트 (다음 반복을 위해)
              allBillTimes[i]['bill_balance_min_after'] = newAfterBalance;
            }
            
            print('✅ 연쇄 시간잔액 재계산 완료');
          }
          
          billTimesUpdated = true;
          print('✅ v2_bill_times 업데이트 완료');
        }
      }
      
      // 5. 사용된 쿠폰 복구 (미사용 상태로 변경)
      final usedCoupons = await TsCancellationSimulationService._getUsedCoupons(reservation.reservationId!);
      if (usedCoupons.isNotEmpty) {
        print('\n=== 4단계: 사용된 쿠폰 복구 ===');
        print('복구할 사용된 쿠폰 수: ${usedCoupons.length}개');
        for (var coupon in usedCoupons) {
          // coupon_id가 실제 DB 필드명
          final couponId = coupon['coupon_id'];
          final idFieldName = 'coupon_id';
          
          print('📝 사용된 쿠폰 복구 처리: ID $couponId');
          print('  - 현재 상태: ${coupon['coupon_status']}');
          print('  - reservation_id_used: ${coupon['reservation_id_used']}');
          print('  - 변경할 상태: 미사용');
          print('  - ID 필드명: $idFieldName');
          
          await ApiService.updateData(
            table: 'v2_discount_coupon',
            data: {
              'coupon_status': '미사용',
              'reservation_id_used': null,
              'used_at': null,
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [
              {'field': idFieldName, 'operator': '=', 'value': couponId},
            ],
          );
          print('✅ 사용된 쿠폰 $couponId 복구 완료 (사용 → 미사용)');
        }
        couponsUpdated = true;
      } else {
        print('\n=== 4단계: 사용된 쿠폰 없음 ===');
      }

      // 6. 발급된 쿠폰 취소 (취소 상태로 변경)
      final issuedCoupons = await TsCancellationSimulationService._getIssuedCoupons(reservation.reservationId!);
      if (issuedCoupons.isNotEmpty) {
        print('\n=== 5단계: 발급된 쿠폰 취소 ===');
        print('취소할 발급된 쿠폰 수: ${issuedCoupons.length}개');
        for (var coupon in issuedCoupons) {
          // coupon_id가 실제 DB 필드명
          final couponId = coupon['coupon_id'];
          final idFieldName = 'coupon_id';
          
          print('📝 발급된 쿠폰 취소 처리: ID $couponId');
          print('  - 현재 상태: ${coupon['coupon_status']}');
          print('  - reservation_id_issued: ${coupon['reservation_id_issued']}');
          print('  - 변경할 상태: 취소');
          print('  - ID 필드명: $idFieldName');
          
          await ApiService.updateData(
            table: 'v2_discount_coupon',
            data: {
              'coupon_status': '취소',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [
              {'field': idFieldName, 'operator': '=', 'value': couponId},
            ],
          );
          print('✅ 발급된 쿠폰 $couponId 취소 완료 (${coupon['coupon_status']} → 취소)');
        }
      } else {
        print('\n=== 5단계: 발급된 쿠폰 없음 ===');
      }
      
      print('\n🎉 관리자 예약 취소 처리 완료');
      return true;
      
    } catch (e) {
      print('\n❌ 관리자 예약 취소 처리 중 오류 발생: $e');
      
      // 롤백 처리 - 시뮬레이션이 실패한 경우 빈 맵으로 처리
      await _rollbackCancellation(
        reservationId: reservation.reservationId!,
        pricedTsUpdated: pricedTsUpdated,
        billsUpdated: billsUpdated,
        billTimesUpdated: billTimesUpdated,
        couponsUpdated: couponsUpdated,
        originalBillChanges: {},
        originalBillTimeChanges: {},
        affectedCoupons: [],
      );
      
      return false;
    }
  }
  
  /// 취소 처리 롤백
  static Future<void> _rollbackCancellation({
    required String reservationId,
    required bool pricedTsUpdated,
    required bool billsUpdated,
    required bool billTimesUpdated,
    required bool couponsUpdated,
    Map<String, dynamic>? originalBillChanges,
    Map<String, dynamic>? originalBillTimeChanges,
    required List<Map<String, dynamic>> affectedCoupons,
  }) async {
    print('\n=== 예약 취소 롤백 시작 ===');
    
    try {
      // 역순으로 롤백 처리
      
      // 1. 쿠폰 롤백
      if (couponsUpdated) {
        print('쿠폰 롤백 처리...');
        for (var coupon in affectedCoupons) {
          try {
            await ApiService.updateData(
              table: 'v2_discount_coupon',
              data: {
                'coupon_status': '사용됨',
                'reservation_id_used': reservationId,
                'used_at': coupon['used_at'],
              },
              where: [
                {'field': 'coupon_id', 'operator': '=', 'value': coupon['coupon_id']},
              ],
            );
            print('✅ 쿠폰 ${coupon['coupon_id']} 롤백 완료');
          } catch (e) {
            print('❌ 쿠폰 ${coupon['coupon_id']} 롤백 실패: $e');
          }
        }
      }
      
      // 2. bill_times 롤백
      if (billTimesUpdated && originalBillTimeChanges != null) {
        print('bill_times 롤백 처리...');
        try {
          await ApiService.updateBillTimesData(
            {'remaining_time': originalBillTimeChanges['current_remaining_time']},
            [
              {'field': 'bill_min_id', 'operator': '=', 'value': originalBillTimeChanges['bill_min_id']},
            ],
          );
          print('✅ bill_times 롤백 완료');
        } catch (e) {
          print('❌ bill_times 롤백 실패: $e');
        }
      }
      
      // 3. bills 롤백 (단순히 상태만 원복 - 연쇄 재계산은 너무 복잡)
      if (billsUpdated && originalBillChanges != null) {
        print('bills 롤백 처리...');
        try {
          await ApiService.updateBillsData(
            {'bill_status': '결제완료'},
            [
              {'field': 'bill_id', 'operator': '=', 'value': originalBillChanges['bill_id']},
            ],
          );
          print('✅ bills 롤백 완료 (상태만 원복)');
        } catch (e) {
          print('❌ bills 롤백 실패: $e');
        }
      }
      
      // 4. priced_TS 롤백
      if (pricedTsUpdated) {
        print('priced_TS 롤백 처리...');
        try {
          await ApiService.updateTsData(
            {'ts_status': '결제완료'},
            [
              {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
            ],
          );
          print('✅ priced_TS 롤백 완료');
        } catch (e) {
          print('❌ priced_TS 롤백 실패: $e');
        }
      }
      
      print('=== 예약 취소 롤백 완료 ===\n');
    } catch (e) {
      print('❌ 롤백 처리 중 오류: $e');
    }
  }
}

/// 관리자용 예약 취소 다이얼로그
class TsReservationCancelDialog {
  /// 관리자용 예약 취소 다이얼로그 표시 (패널티 적용/면제 옵션)
  static Future<void> show(BuildContext context, TsReservation reservation, VoidCallback? onDataChanged) async {
    print('🎯 다이얼로그 show 시작');
    
    if (!context.mounted) {
      print('❌ 초기 context가 mounted되지 않음');
      return;
    }
    
    if (!TsReservationCancelService.canCancelReservation(reservation)) {
      _showCannotCancelDialog(context);
      return;
    }

    // 즉시 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false, // 로딩 중에는 닫기 방지
      builder: (BuildContext dialogContext) {
        return _CancellationLoadingDialog(
          reservation: reservation,
          onDataChanged: onDataChanged,
        );
      },
    );
  }
  
  /// 예약 정보 섹션
  static Widget _buildReservationInfo(TsReservation reservation, List<Map<String, dynamic>> usedCoupons, List<Map<String, dynamic>> issuedCoupons) {
    final formatter = NumberFormat('#,###');
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '예약 정보',
            style: AppTextStyles.h4.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('타석', style: _labelStyle()),
                    Text('${reservation.tsId}번', style: _valueStyle()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('일시', style: _labelStyle()),
                    Text('${reservation.tsDate}', style: _valueStyle()),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('시간', style: _labelStyle()),
                    Text('${reservation.tsStart} ~ ${reservation.tsEnd}', style: _valueStyle()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('결제액', style: _labelStyle()),
                    Text(
                      reservation.tsPaymentMethod == '시간권' 
                        ? '${reservation.tsMin ?? 0}분'
                        : '${formatter.format(reservation.netAmt ?? 0)}원', 
                      style: _valueStyle()
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 쿠폰 정보 (있는 경우만 표시)
          if (usedCoupons.isNotEmpty || issuedCoupons.isNotEmpty) ...[
            SizedBox(height: 16),
            Divider(color: Color(0xFFE2E8F0)),
            SizedBox(height: 8),
            Text(
              '영향받는 쿠폰',
              style: AppTextStyles.bodyText.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            
            if (usedCoupons.isNotEmpty) ...[
              Text(
                '• 사용취소 대상: ${usedCoupons.length}개 (미사용 상태로 복구)',
                style: AppTextStyles.formLabel.copyWith(color: Color(0xFF059669)),
              ),
              for (final coupon in usedCoupons.take(2))
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 2),
                  child: Text(
                    '- ${coupon['coupon_description'] ?? coupon['coupon_type'] ?? '할인쿠폰'}',
                    style: AppTextStyles.caption.copyWith(color: Color(0xFF64748B)),
                  ),
                ),
              if (usedCoupons.length > 2)
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 2),
                  child: Text(
                    '외 ${usedCoupons.length - 2}개',
                    style: AppTextStyles.caption.copyWith(color: Color(0xFF64748B)),
                  ),
                ),
            ],
            
            if (issuedCoupons.isNotEmpty) ...[
              if (usedCoupons.isNotEmpty) SizedBox(height: 4),
              Text(
                '• 발급취소 대상: ${issuedCoupons.length}개 (쿠폰 취소)',
                style: AppTextStyles.formLabel.copyWith(color: Color(0xFFDC2626)),
              ),
              for (final coupon in issuedCoupons.take(2))
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 2),
                  child: Text(
                    '- ${coupon['coupon_description'] ?? coupon['coupon_type'] ?? '할인쿠폰'}',
                    style: AppTextStyles.caption.copyWith(color: Color(0xFF64748B)),
                  ),
                ),
              if (issuedCoupons.length > 2)
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 2),
                  child: Text(
                    '외 ${issuedCoupons.length - 2}개',
                    style: AppTextStyles.caption.copyWith(color: Color(0xFF64748B)),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
  
  /// 취소 옵션 섹션
  static Widget _buildCancellationOptions(
    BuildContext context, 
    TsReservation reservation, 
    CancellationSimulation policySimulation,
    CancellationSimulation exemptSimulation,
    VoidCallback? onDataChanged
  ) {
    // 무료 취소 가능시간인지 확인 (패널티 0%)
    final isFreeCancel = policySimulation.penaltyAmount == 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '취소 정책 선택',
          style: AppTextStyles.titleH4.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        
        if (isFreeCancel) ...[
          // 무료 취소 가능시간: 전액환불 옵션만 표시
          _buildCancelOption(
            context,
            '전액환불',
            '무료취소 가능시간\n결제금액: ${NumberFormat('#,###').format(reservation.netAmt ?? 0)}원 (전액환불)',
            Color(0xFF3B82F6),
            () => _showAdminDiscretionDialog(context, reservation, onDataChanged),
          ),
        ] else ...[
          // 패널티가 있는 경우: 두 옵션 모두 표시
          _buildCancelOption(
            context,
            '취소패널티 적용',
            policySimulation.description,
            Color(0xFF10B981),
            () => _showPolicyConfirmDialog(context, reservation, onDataChanged),
          ),
          SizedBox(height: 12),
          
          _buildCancelOption(
            context,
            '전액 환불',
            exemptSimulation.description,
            Color(0xFF3B82F6),
            () => _showAdminDiscretionDialog(context, reservation, onDataChanged),
          ),
        ],
        
        SizedBox(height: 12),
      ],
    );
  }
  
  /// 취소 옵션 버튼
  static Widget _buildCancelOption(
    BuildContext context,
    String title,
    String description,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyText.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 관리자 재량 취소 확인 다이얼로그
  static Future<void> _showAdminDiscretionDialog(
    BuildContext context, 
    TsReservation reservation, 
    VoidCallback? onDataChanged
  ) async {
    Navigator.of(context).pop(); // 옵션 다이얼로그 닫기
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            '전액 환불',
            style: AppTextStyles.modalTitle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '수수료 없이 전액 환불로 예약을 취소하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
            style: AppTextStyles.bodyText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소', style: AppTextStyles.modalButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B82F6)),
              child: Text('확인', style: AppTextStyles.modalButton.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      await _handleCancellationWithPolicy(context, reservation, false, onDataChanged);
    }
  }
  
  
  
  static TextStyle _labelStyle() {
    return AppTextStyles.formLabel.copyWith(color: Color(0xFF64748B));
  }
  
  static TextStyle _valueStyle() {
    return AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600);
  }

  /// 시뮬레이션 오류 다이얼로그
  static void _showSimulationErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('오류'),
          content: Text('취소 시뮬레이션 중 오류가 발생했습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }
  
  /// 정책 적용 취소 확인 다이얼로그
  static Future<void> _showPolicyConfirmDialog(
    BuildContext context, 
    TsReservation reservation, 
    VoidCallback? onDataChanged
  ) async {
    Navigator.of(context).pop(); // 옵션 다이얼로그 닫기
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            '취소패널티 적용',
            style: AppTextStyles.modalTitle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '취소패널티가 적용되어 수수료가 차감됩니다.\n\n예약을 취소하시겠습니까?',
            style: AppTextStyles.bodyText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소', style: AppTextStyles.modalButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF10B981)),
              child: Text('확인', style: AppTextStyles.modalButton.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      await _handleCancellationWithPolicy(context, reservation, true, onDataChanged);
    }
  }

  /// 정책 적용/면제에 따른 취소 처리
  static Future<void> _handleCancellationWithPolicy(
    BuildContext context,
    TsReservation reservation,
    bool applyPenalty,
    VoidCallback? onDataChanged,
  ) async {
    final success = await TsReservationCancelService.adminCancelTsReservation(
      reservation,
      applyPenalty: applyPenalty,
    );

    if (success) {
      if (context.mounted) {
        Navigator.of(context).pop(); // 상세 팝업 닫기
        _showSuccessDialog(context, reservation, applyPenalty, onDataChanged);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 취소 중 오류가 발생했습니다'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// 성공 다이얼로그
  static void _showSuccessDialog(
    BuildContext context,
    TsReservation reservation,
    bool appliedPenalty,
    VoidCallback? onDataChanged,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF10B981),
                size: 48.0,
              ),
              SizedBox(height: 16),
              Text(
                '예약이 취소되었습니다',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '${reservation.tsId}번 타석 예약이 성공적으로 취소되었습니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.formLabel.copyWith(color: Color(0xFF64748B)),
              ),
              if (appliedPenalty) ...[
                SizedBox(height: 8),
                Text(
                  '취소패널티가 적용되었습니다',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardBody.copyWith(color: Color(0xFF64748B)),
                ),
              ] else ...[
                SizedBox(height: 8),
                Text(
                  '전액 환불로 처리되었습니다',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardBody.copyWith(color: Color(0xFF10B981)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDataChanged?.call();
              },
              child: Text(
                '확인',
                style: AppTextStyles.modalButton.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 취소 불가 안내 다이얼로그
  static void _showCannotCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('예약 취소 불가'),
          content: Text('진행 중이거나 종료된 예약은 취소할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

/// 로딩 상태 다이얼로그
class _CancellationLoadingDialog extends StatefulWidget {
  final TsReservation reservation;
  final VoidCallback? onDataChanged;

  const _CancellationLoadingDialog({
    required this.reservation,
    this.onDataChanged,
  });

  @override
  State<_CancellationLoadingDialog> createState() => _CancellationLoadingDialogState();
}

class _CancellationLoadingDialogState extends State<_CancellationLoadingDialog> {
  bool _isLoading = true;
  CancellationSimulation? _policySimulation;
  CancellationSimulation? _exemptSimulation;
  List<Map<String, dynamic>> _usedCoupons = [];
  List<Map<String, dynamic>> _issuedCoupons = [];

  @override
  void initState() {
    super.initState();
    _loadSimulations();
  }

  Future<void> _loadSimulations() async {
    try {
      print('🎯 다이얼로그 내부 시뮬레이션 시작');
      
      // 쿠폰 정보를 한 번만 조회
      _usedCoupons = await TsCancellationSimulationService._getUsedCoupons(widget.reservation.reservationId!);
      _issuedCoupons = await TsCancellationSimulationService._getIssuedCoupons(widget.reservation.reservationId!);
      
      // 두 시뮬레이션을 병렬로 실행
      final futures = await Future.wait([
        TsCancellationSimulationService.simulateCancellation(widget.reservation, applyPenalty: true),
        TsCancellationSimulationService.simulateCancellation(widget.reservation, applyPenalty: false),
      ]);
      
      _policySimulation = futures[0];
      _exemptSimulation = futures[1];
      
      print('🎯 시뮬레이션 완료. UI 업데이트 중...');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 시뮬레이션 실패: $e');
      if (mounted) {
        Navigator.of(context).pop();
        TsReservationCancelDialog._showSimulationErrorDialog(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: 700),
        padding: EdgeInsets.all(24.0),
        child: _isLoading ? _buildLoadingContent() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '관리자 예약 취소',
              style: AppTextStyles.modalTitle.copyWith(
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        SizedBox(height: 40),
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
        SizedBox(height: 20),
        Text(
          '취소 정책을 확인하고 있습니다...',
          style: AppTextStyles.bodyText.copyWith(color: Color(0xFF64748B)),
        ),
        SizedBox(height: 40),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '관리자 예약 취소',
              style: AppTextStyles.modalTitle.copyWith(
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: Color(0xFF64748B)),
            ),
          ],
        ),
        SizedBox(height: 20),
        
        // 예약 정보 (쿠폰 정보 포함)
        TsReservationCancelDialog._buildReservationInfo(widget.reservation, _usedCoupons, _issuedCoupons),
        SizedBox(height: 20),
        
        // 취소 옵션
        TsReservationCancelDialog._buildCancellationOptions(context, widget.reservation, _policySimulation!, _exemptSimulation!, widget.onDataChanged),
      ],
    );
  }
}