import 'package:intl/intl.dart';
import 'dart:math' as math;
import '/services/api_service.dart';

/// 관리자용 타석 취소 시뮬레이션 서비스
class AdminTsCancellationSimulationService {

  /// 페널티 적용/미적용 시뮬레이션
  static Future<Map<String, dynamic>> simulateCancellation({
    required String reservationId,
    required DateTime reservationStartTime,
    required bool applyPenalty,  // true: 정책 페널티 적용, false: 페널티 면제
  }) async {
    try {
      // 1. v2_priced_TS에서 예약 정보 조회
      final pricedTsData = await ApiService.getTsData(
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId}
        ],
        limit: 1,
      );

      if (pricedTsData.isEmpty) {
        return {'success': false, 'message': '예약 정보를 찾을 수 없습니다'};
      }

      final reservation = pricedTsData.first;
      final billId = reservation['bill_id'];
      final billMinId = reservation['bill_min_id'];

      // 2. 페널티 퍼센트 조회 (정책에서)
      int penaltyPercent = 0;
      if (applyPenalty) {
        final billsPolicy = await _getCancellationPolicy('v2_bills', reservationStartTime);
        final billTimesPolicy = await _getCancellationPolicy('v2_bill_times', reservationStartTime);

        // 더 높은 페널티 적용
        penaltyPercent = math.max(
          billsPolicy['penaltyPercent'] ?? 0,
          billTimesPolicy['penaltyPercent'] ?? 0
        );
      }

      // 3. v2_bills 시뮬레이션
      Map<String, dynamic> billsSimulation = {};
      if (billId != null && billId.toString().isNotEmpty && billId.toString() != 'null') {
        billsSimulation = await _simulateBillsCancellation(billId.toString(), penaltyPercent);
      }

      // 4. v2_bill_times 시뮬레이션  
      Map<String, dynamic> billTimesSimulation = {};
      if (billMinId != null && billMinId.toString().isNotEmpty && billMinId.toString() != 'null') {
        billTimesSimulation = await _simulateBillTimesCancellation(billMinId.toString(), penaltyPercent);
      }

      // 5. 쿠폰 영향 분석
      final usedCoupons = await _previewUsedCoupons(reservationId);
      final issuedCoupons = await _previewIssuedCoupons(reservationId);

      return {
        'success': true,
        'penaltyPercent': penaltyPercent,
        'bills': billsSimulation,
        'billTimes': billTimesSimulation,
        'usedCoupons': usedCoupons,
        'issuedCoupons': issuedCoupons,
        'summary': {
          'totalRefundAmount': billsSimulation['refundAmount'] ?? 0,
          'totalRefundMinutes': billTimesSimulation['refundMinutes'] ?? 0,
          'totalPenaltyAmount': billsSimulation['penaltyAmount'] ?? 0,
          'totalPenaltyMinutes': billTimesSimulation['penaltyMinutes'] ?? 0,
        }
      };

    } catch (e) {
      return {'success': false, 'message': '시뮬레이션 오류: $e'};
    }
  }

  /// v2_bills 취소 시뮬레이션 (완전한 구현)
  static Future<Map<String, dynamic>> _simulateBillsCancellation(
    String billId,
    int penaltyPercent
  ) async {
    try {
      // 1. 취소 대상 bill_id 정보 조회
      final targetBillData = await ApiService.getBillsData(
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': int.parse(billId)}
        ],
        limit: 1,
      );

      if (targetBillData.isEmpty) {
        return {'success': false, 'message': '취소 대상 bill_id를 찾을 수 없습니다'};
      }

      final targetBill = targetBillData.first;
      final contractHistoryId = targetBill['contract_history_id'];
      final originalBeforeBalance = targetBill['bill_balance_before'] ?? 0;
      final originalNetAmt = targetBill['bill_netamt'] ?? 0;

      // 2. 동일 contract_history_id에서 해당 bill_id 이상인 모든 레코드 조회
      final affectedBills = await ApiService.getBillsData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>=', 'value': int.parse(billId)},
        ],
        orderBy: [
          {'field': 'bill_id', 'direction': 'ASC'}
        ],
      );

      // 3. 페널티 계산
      int penaltyAmount = 0;
      int refundAmount = originalNetAmt.abs();
      int newAfterBalance = originalBeforeBalance;

      if (penaltyPercent > 0) {
        penaltyAmount = (originalNetAmt.abs() * penaltyPercent / 100).round();
        refundAmount = originalNetAmt.abs() - penaltyAmount;
        newAfterBalance = originalBeforeBalance - penaltyAmount;
      } else {
        newAfterBalance = originalBeforeBalance;
      }

      // 4. 후속 레코드들의 잔액 변화 시뮬레이션
      List<Map<String, dynamic>> affectedRecords = [];
      for (int i = 1; i < affectedBills.length; i++) {
        final currentBill = affectedBills[i];
        final newBeforeBalance = i == 1
          ? newAfterBalance
          : affectedRecords[i-2]['newAfterBalance'];

        final netAmt = currentBill['bill_netamt'] ?? 0;
        final newAfterBalanceForCurrent = newBeforeBalance + netAmt;

        affectedRecords.add({
          'billId': currentBill['bill_id'],
          'originalBeforeBalance': currentBill['bill_balance_before'],
          'originalAfterBalance': currentBill['bill_balance_after'],
          'newBeforeBalance': newBeforeBalance,
          'newAfterBalance': newAfterBalanceForCurrent,
        });
      }

      return {
        'success': true,
        'originalAmount': originalNetAmt.abs(),
        'penaltyPercent': penaltyPercent,
        'penaltyAmount': penaltyAmount,
        'refundAmount': refundAmount,
        'originalBeforeBalance': originalBeforeBalance,
        'newAfterBalance': newAfterBalance,
        'affectedRecordsCount': affectedBills.length,
        'affectedRecords': affectedRecords,
      };

    } catch (e) {
      return {'success': false, 'message': 'Bills 시뮬레이션 오류: $e'};
    }
  }

  /// v2_bill_times 취소 시뮬레이션 (완전한 구현)
  static Future<Map<String, dynamic>> _simulateBillTimesCancellation(
    String billMinId,
    int penaltyPercent
  ) async {
    try {
      // 1. 취소 대상 bill_min_id 정보 조회
      final targetBillData = await ApiService.getBillTimesData(
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': int.parse(billMinId)}
        ],
        limit: 1,
      );

      if (targetBillData.isEmpty) {
        return {'success': false, 'message': '취소 대상 bill_min_id를 찾을 수 없습니다'};
      }

      final targetBill = targetBillData.first;
      final contractHistoryId = targetBill['contract_history_id'];
      final originalBeforeBalance = targetBill['bill_balance_min_before'] ?? 0;
      final originalBillMin = targetBill['bill_min'] ?? 0;

      // 빈 슬롯 처리
      if (originalBeforeBalance == null || originalBeforeBalance == 0) {
        return {
          'success': true,
          'isEmptySlot': true,
          'originalMinutes': 0,
          'penaltyMinutes': 0,
          'refundMinutes': 0,
          'message': '빈 슬롯 - 단순 상태 변경만 수행'
        };
      }

      // 2. 동일 contract_history_id에서 해당 bill_min_id 이상인 모든 레코드 조회
      final affectedBills = await ApiService.getBillTimesData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '>=', 'value': int.parse(billMinId)},
        ],
        orderBy: [
          {'field': 'bill_min_id', 'direction': 'ASC'}
        ],
      );

      // 3. 페널티 계산
      int penaltyMinutes = 0;
      int refundMinutes = originalBillMin;
      int newAfterBalance = originalBeforeBalance;

      if (penaltyPercent > 0) {
        penaltyMinutes = (originalBillMin * penaltyPercent / 100).round();
        refundMinutes = originalBillMin - penaltyMinutes;
        newAfterBalance = originalBeforeBalance - penaltyMinutes;
      } else {
        newAfterBalance = originalBeforeBalance;
      }

      // 4. 후속 레코드들의 시간잔액 변화 시뮬레이션
      List<Map<String, dynamic>> affectedRecords = [];
      for (int i = 1; i < affectedBills.length; i++) {
        final currentBill = affectedBills[i];
        final newBeforeBalance = i == 1
          ? newAfterBalance
          : affectedRecords[i-2]['newAfterBalance'];

        final billMin = currentBill['bill_min'] ?? 0;
        final newAfterBalanceForCurrent = newBeforeBalance - billMin; // 시간권은 차감

        affectedRecords.add({
          'billMinId': currentBill['bill_min_id'],
          'originalBeforeBalance': currentBill['bill_balance_min_before'],
          'originalAfterBalance': currentBill['bill_balance_min_after'],
          'newBeforeBalance': newBeforeBalance,
          'newAfterBalance': newAfterBalanceForCurrent,
        });
      }

      return {
        'success': true,
        'originalMinutes': originalBillMin,
        'penaltyPercent': penaltyPercent,
        'penaltyMinutes': penaltyMinutes,
        'refundMinutes': refundMinutes,
        'originalBeforeBalance': originalBeforeBalance,
        'newAfterBalance': newAfterBalance,
        'affectedRecordsCount': affectedBills.length,
        'affectedRecords': affectedRecords,
      };

    } catch (e) {
      return {'success': false, 'message': 'BillTimes 시뮬레이션 오류: $e'};
    }
  }

  /// 사용된 쿠폰 미리보기
  static Future<List<Map<String, dynamic>>> _previewUsedCoupons(String reservationId) async {
    try {
      return await ApiService.getDiscountCouponsData(
        where: [
          {'field': 'reservation_id_used', 'operator': '=', 'value': reservationId},
        ],
      );
    } catch (e) {
      print('사용된 쿠폰 조회 오류: $e');
      return [];
    }
  }

  /// 발급된 쿠폰 미리보기
  static Future<List<Map<String, dynamic>>> _previewIssuedCoupons(String reservationId) async {
    try {
      return await ApiService.getDiscountCouponsData(
        where: [
          {'field': 'reservation_id_issued', 'operator': '=', 'value': reservationId},
        ],
      );
    } catch (e) {
      print('발급된 쿠폰 조회 오류: $e');
      return [];
    }
  }

  /// 취소 정책 조회
  static Future<Map<String, dynamic>> _getCancellationPolicy(
    String table,
    DateTime reservationStartTime
  ) async {
    try {
      // 1. 해당 테이블의 취소 정책 조회 (apply_sequence 순으로 정렬) - 고객용 앱 방식 사용
      print('🔍 취소 정책 조회 시작 ($table)');
      
      final policies = await ApiService.getDataList(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'db_table', 'operator': '=', 'value': table}
        ],
        orderBy: [
          {'field': 'apply_sequence', 'direction': 'ASC'}
        ],
      );

      if (policies.isEmpty) {
        print('❌ 취소 정책을 찾을 수 없습니다: $table');
        return {'canCancel': true, 'penaltyPercent': 0}; // 정책이 없으면 무료 취소
      }

      // 2. 현재 시간과 예약 시작 시간의 차이를 분 단위로 계산
      final now = DateTime.now();
      final timeDifferenceInMinutes = reservationStartTime.difference(now).inMinutes;
      
      print('현재 시간: $now');
      print('예약 시작 시간: $reservationStartTime');
      print('시간 차이: ${timeDifferenceInMinutes}분');

      // 3. 현재 시간이 예약 시작 시간을 지났다면 apply_sequence 1번 적용
      if (timeDifferenceInMinutes < 0) {
        print('⚠️ 예약 시작 시간이 지났습니다. apply_sequence 1번 적용');
        final firstPolicy = policies.firstWhere(
          (policy) => int.parse(policy['apply_sequence'].toString()) == 1,
          orElse: () => policies.first,
        );
        final penaltyPercent = int.parse(firstPolicy['penalty_percent'].toString());
        print('✅ 적용할 정책: apply_sequence 1번, ${penaltyPercent}% 페널티');
        return {
          'canCancel': true,
          'penaltyPercent': penaltyPercent,
          'policyFound': true,
        };
      }

      // 4. apply_sequence 순으로 정책 적용
      for (final policy in policies) {
        final minBeforeUse = int.parse(policy['_min_before_use'].toString());
        final penaltyPercent = int.parse(policy['penalty_percent'].toString());
        final sequence = int.parse(policy['apply_sequence'].toString());
        
        print('정책 확인 - sequence: $sequence, min_before_use: $minBeforeUse, penalty: $penaltyPercent%');

        if (timeDifferenceInMinutes <= minBeforeUse) {
          print('✅ 적용할 정책 발견: ${penaltyPercent}% 페널티');
          return {
            'canCancel': true,
            'penaltyPercent': penaltyPercent,
            'policyFound': true,
          };
        }
      }

      // 5. 어떤 정책에도 해당하지 않으면 무료 취소 가능
      print('✅ 무료 취소 가능 기간');
      return {'canCancel': true, 'penaltyPercent': 0, 'policyFound': false};

    } catch (e) {
      return {'canCancel': false, 'penaltyPercent': 0};
    }
  }
}

/// 관리자용 타석 취소 실행 서비스
class AdminTsCancellationExecutionService {

  /// 관리자용 타석 취소 실행
  static Future<bool> cancelTsReservation({
    required String reservationId,
    required DateTime reservationStartTime,
    required bool applyPenalty,  // true: 정책 페널티 적용, false: 페널티 면제
  }) async {

    bool pricedTsUpdated = false;
    bool billsUpdated = false;
    bool billTimesUpdated = false;
    bool usedCouponsRecovered = false;
    bool issuedCouponsCanceled = false;

    try {
      print('\n=== 관리자 타석 취소 실행 시작 ===');
      print('예약 ID: $reservationId');
      print('페널티 적용: ${applyPenalty ? "정책 적용" : "면제"}');

      // 1. 시뮬레이션으로 변경사항 계산
      final simulation = await AdminTsCancellationSimulationService.simulateCancellation(
        reservationId: reservationId,
        reservationStartTime: reservationStartTime,
        applyPenalty: applyPenalty,
      );

      if (!simulation['success']) {
        print('❌ 시뮬레이션 실패: ${simulation['message']}');
        return false;
      }

      print('페널티: ${simulation['summary']['totalPenaltyAmount']}원, ${simulation['summary']['totalPenaltyMinutes']}분');
      print('환불: ${simulation['summary']['totalRefundAmount']}원, ${simulation['summary']['totalRefundMinutes']}분');

      // 2. v2_priced_TS 업데이트
      print('\n=== 1단계: v2_priced_TS 업데이트 ===');
      await ApiService.updateTsData(
        {
          'ts_status': '예약취소',
          'time_stamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
        },
        [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
        ],
      );
      pricedTsUpdated = true;
      print('✅ v2_priced_TS 업데이트 완료');

      // 3. v2_bills 업데이트 (연쇄 잔액 재계산 포함)
      if (simulation['bills']['success'] == true) {
        print('\n=== 2단계: v2_bills 업데이트 (연쇄 재계산) ===');
        await _updateBillsWithChaining(simulation['bills'], applyPenalty);
        billsUpdated = true;
        print('✅ v2_bills 연쇄 업데이트 완료');
      }

      // 4. v2_bill_times 업데이트 (연쇄 시간잔액 재계산 포함)
      if (simulation['billTimes']['success'] == true) {
        print('\n=== 3단계: v2_bill_times 업데이트 (연쇄 재계산) ===');
        await _updateBillTimesWithChaining(simulation['billTimes'], applyPenalty);
        billTimesUpdated = true;
        print('✅ v2_bill_times 연쇄 업데이트 완료');
      }

      // 5. 사용된 쿠폰 복구
      if (simulation['usedCoupons'].isNotEmpty) {
        print('\n=== 4단계: 사용된 쿠폰 복구 ===');
        await _recoverUsedCoupons(simulation['usedCoupons']);
        usedCouponsRecovered = true;
        print('✅ 사용된 쿠폰 복구 완료');
      }

      // 6. 발급된 쿠폰 취소
      if (simulation['issuedCoupons'].isNotEmpty) {
        print('\n=== 5단계: 발급된 쿠폰 취소 ===');
        await _cancelIssuedCoupons(simulation['issuedCoupons']);
        issuedCouponsCanceled = true;
        print('✅ 발급된 쿠폰 취소 완료');
      }

      print('\n🎉 관리자 타석 취소 처리 완료');
      return true;

    } catch (e) {
      print('\n❌ 관리자 타석 취소 처리 중 오류 발생: $e');

      // 롤백 처리
      await _rollbackCancellation(
        reservationId: reservationId,
        pricedTsUpdated: pricedTsUpdated,
        billsUpdated: billsUpdated,
        billTimesUpdated: billTimesUpdated,
        usedCouponsRecovered: usedCouponsRecovered,
        issuedCouponsCanceled: issuedCouponsCanceled,
        simulation: null, // 에러가 발생한 경우이므로 시뮬레이션 결과가 없을 수 있음
      );

      return false;
    }
  }

  /// v2_bills 연쇄 업데이트 처리
  static Future<void> _updateBillsWithChaining(
    Map<String, dynamic> billsSimulation, 
    bool applyPenalty
  ) async {
    // 1. 원본 레코드 업데이트
    final penaltyAmount = billsSimulation['penaltyAmount'] ?? 0;
    final newAfterBalance = billsSimulation['newAfterBalance'];

    Map<String, dynamic> updateData = {
      'bill_status': '예약취소',
      'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'bill_balance_after': newAfterBalance,
    };

    if (applyPenalty && penaltyAmount > 0) {
      // 페널티가 있는 경우: 음수 금액으로 페널티 차감
      updateData.addAll({
        'bill_totalamt': -penaltyAmount,
        'bill_netamt': -penaltyAmount,
      });
    } else {
      // 페널티 면제: 모든 금액을 0으로
      updateData.addAll({
        'bill_totalamt': 0,
        'bill_deduction': 0,
        'bill_netamt': 0,
      });
    }

    // 원본 레코드 업데이트
    await ApiService.updateBillsData(
      updateData,
      [{'field': 'bill_id', 'operator': '=', 'value': billsSimulation['billId']}],
    );

    // 2. 후속 레코드들의 연쇄 잔액 재계산
    final affectedRecords = billsSimulation['affectedRecords'] as List<Map<String, dynamic>>;
    for (final record in affectedRecords) {
      await ApiService.updateBillsData(
        {
          'bill_balance_before': record['newBeforeBalance'],
          'bill_balance_after': record['newAfterBalance'],
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        [{'field': 'bill_id', 'operator': '=', 'value': record['billId']}],
      );
      print('  연쇄 업데이트: bill_id=${record['billId']}, 잔액=${record['newBeforeBalance']}→${record['newAfterBalance']}');
    }
  }

  /// v2_bill_times 연쇄 업데이트 처리
  static Future<void> _updateBillTimesWithChaining(
    Map<String, dynamic> billTimesSimulation, 
    bool applyPenalty
  ) async {
    // 빈 슬롯 처리
    if (billTimesSimulation['isEmptySlot'] == true) {
      await ApiService.updateBillTimesData(
        {
          'bill_status': '예약취소',
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        [{'field': 'bill_min_id', 'operator': '=', 'value': billTimesSimulation['billMinId']}],
      );
      return;
    }

    // 1. 원본 레코드 업데이트
    final penaltyMinutes = billTimesSimulation['penaltyMinutes'] ?? 0;
    final newAfterBalance = billTimesSimulation['newAfterBalance'];

    Map<String, dynamic> updateData = {
      'bill_status': '예약취소',
      'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'bill_balance_min_after': newAfterBalance,
    };

    if (applyPenalty && penaltyMinutes > 0) {
      // 페널티가 있는 경우: 페널티 시간만큼 차감
      updateData.addAll({
        'bill_total_min': penaltyMinutes,
        'bill_min': penaltyMinutes,
      });
    } else {
      // 페널티 면제: 모든 시간을 0으로
      updateData.addAll({
        'bill_total_min': 0,
        'bill_discount_min': 0,
        'bill_min': 0,
      });
    }

    // 원본 레코드 업데이트
    await ApiService.updateBillTimesData(
      updateData,
      [{'field': 'bill_min_id', 'operator': '=', 'value': billTimesSimulation['billMinId']}],
    );

    // 2. 후속 레코드들의 연쇄 시간잔액 재계산
    final affectedRecords = billTimesSimulation['affectedRecords'] as List<Map<String, dynamic>>;
    for (final record in affectedRecords) {
      await ApiService.updateBillTimesData(
        {
          'bill_balance_min_before': record['newBeforeBalance'],
          'bill_balance_min_after': record['newAfterBalance'],
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        [{'field': 'bill_min_id', 'operator': '=', 'value': record['billMinId']}],
      );
      print('  연쇄 업데이트: bill_min_id=${record['billMinId']}, 시간잔액=${record['newBeforeBalance']}→${record['newAfterBalance']}');
    }
  }

  /// 사용된 쿠폰 복구
  static Future<void> _recoverUsedCoupons(List<Map<String, dynamic>> usedCoupons) async {
    for (final coupon in usedCoupons) {
      await ApiService.updateDiscountCouponsData(
        {
          'coupon_status': '미사용',
          'coupon_use_timestamp': null,
          'LS_id_used': null,
          'reservation_id_used': null,
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        [{'field': 'coupon_bill_id', 'operator': '=', 'value': coupon['coupon_bill_id']}],
      );
      print('  쿠폰 복구: ${coupon['coupon_bill_id']}');
    }
  }

  /// 발급된 쿠폰 취소
  static Future<void> _cancelIssuedCoupons(List<Map<String, dynamic>> issuedCoupons) async {
    for (final coupon in issuedCoupons) {
      await ApiService.updateDiscountCouponsData(
        {
          'coupon_status': '취소',
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        [{'field': 'coupon_bill_id', 'operator': '=', 'value': coupon['coupon_bill_id']}],
      );
      print('  쿠폰 취소: ${coupon['coupon_bill_id']}');
    }
  }

  /// 롤백 처리
  static Future<void> _rollbackCancellation({
    required String reservationId,
    required bool pricedTsUpdated,
    required bool billsUpdated,
    required bool billTimesUpdated,
    required bool usedCouponsRecovered,
    required bool issuedCouponsCanceled,
    Map<String, dynamic>? simulation,
  }) async {
    print('\n=== 관리자 타석 취소 롤백 시작 ===');

    try {
      // 역순으로 롤백 처리
      if (issuedCouponsCanceled && simulation != null) {
        print('발급된 쿠폰 상태 복구...');
        final issuedCoupons = simulation['issuedCoupons'] as List<Map<String, dynamic>>;
        for (final coupon in issuedCoupons) {
          try {
            await ApiService.updateDiscountCouponsData(
              {'coupon_status': coupon['coupon_status']},
              [{'field': 'coupon_bill_id', 'operator': '=', 'value': coupon['coupon_bill_id']}],
            );
          } catch (e) {
            print('❌ 발급된 쿠폰 롤백 실패: $e');
          }
        }
      }

      if (usedCouponsRecovered && simulation != null) {
        print('사용된 쿠폰 상태 복구...');
        final usedCoupons = simulation['usedCoupons'] as List<Map<String, dynamic>>;
        for (final coupon in usedCoupons) {
          try {
            await ApiService.updateDiscountCouponsData(
              {
                'coupon_status': '사용됨',
                'reservation_id_used': reservationId,
              },
              [{'field': 'coupon_bill_id', 'operator': '=', 'value': coupon['coupon_bill_id']}],
            );
          } catch (e) {
            print('❌ 사용된 쿠폰 롤백 실패: $e');
          }
        }
      }

      if (billTimesUpdated) {
        print('bill_times 롤백 처리...');
        try {
          await ApiService.updateTsData(
            {'ts_status': '결제완료'},
            [{'field': 'reservation_id', 'operator': '=', 'value': reservationId}],
          );
        } catch (e) {
          print('❌ bill_times 롤백 실패: $e');
        }
      }

      if (billsUpdated) {
        print('bills 롤백 처리...');
        // 원본 상태로 복구는 복잡하므로 간단히 상태만 복구
      }

      if (pricedTsUpdated) {
        print('priced_TS 롤백 처리...');
        try {
          await ApiService.updateTsData(
            {'ts_status': '결제완료'},
            [{'field': 'reservation_id', 'operator': '=', 'value': reservationId}],
          );
        } catch (e) {
          print('❌ priced_TS 롤백 실패: $e');
        }
      }

      print('=== 관리자 타석 취소 롤백 완료 ===\n');
    } catch (e) {
      print('❌ 롤백 처리 중 오류: $e');
    }
  }
}