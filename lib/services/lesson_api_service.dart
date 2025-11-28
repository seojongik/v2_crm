import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'supabase_adapter.dart';

/// 레슨 API 서비스 (Supabase 마이그레이션 완료)
///
/// 기존 cafe24 PHP API에서 Supabase로 마이그레이션됨
class LessonApiService {
  // 프로 목록 조회 (v2_staff_pro 테이블) - 동일 pro_id의 최신 계약만 조회
  static Future<List<Map<String, dynamic>>> getStaffList({
    required String branchId,
    bool includeRetired = false,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [프로 목록 조회] branch_id: $branchId, includeRetired: $includeRetired');
      }

      // WHERE 조건 구성
      List<Map<String, dynamic>> whereConditions = [
        {
          "field": "branch_id",
          "operator": "=",
          "value": branchId
        }
      ];

      // 재직 상태 필터링
      if (!includeRetired) {
        whereConditions.add({
          "field": "staff_status",
          "operator": "=",
          "value": "재직"
        });
      }

      final result = await SupabaseAdapter.getData(
        table: 'v2_staff_pro',
        fields: [
          "pro_id",
          "pro_name",
          "staff_status",
          "pro_phone",
          "staff_type",
          "pro_gender",
          "pro_contract_round",
          "updated_at"
        ],
        where: whereConditions,
        orderBy: [
          {"field": "pro_id", "direction": "ASC"},
          {"field": "pro_contract_round", "direction": "DESC"},
          {"field": "updated_at", "direction": "DESC"}
        ],
      );

      if (kDebugMode) {
        print('✅ [프로 목록 조회] 조회 성공: ${result.length}개');
      }

      // 동일한 pro_id의 최신 계약만 필터링
      Map<int, Map<String, dynamic>> uniqueStaff = {};

      for (var staff in result) {
        int proId = staff['pro_id'];
        if (!uniqueStaff.containsKey(proId)) {
          uniqueStaff[proId] = staff;
        }
      }

      List<Map<String, dynamic>> finalStaffList = uniqueStaff.values.toList();

      // 최종 정렬: 재직 먼저, 그 다음 이름순
      finalStaffList.sort((a, b) {
        if (a['staff_status'] == '재직' && b['staff_status'] != '재직') return -1;
        if (a['staff_status'] != '재직' && b['staff_status'] == '재직') return 1;
        return (a['pro_name'] ?? '').compareTo(b['pro_name'] ?? '');
      });

      if (kDebugMode) {
        print('✅ [프로 목록 조회] 중복 제거 후: ${finalStaffList.length}개');
      }

      return finalStaffList;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [프로 목록 조회] 예외 발생: $e');
      }
      return [];
    }
  }

  // 특정 프로의 특정 날짜 레슨 현황 조회 (v2_LS_orders 테이블)
  static Future<List<Map<String, dynamic>>> getLessonsByProAndDate({
    required String branchId,
    required int proId,
    required String date, // YYYY-MM-DD 형식
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [레슨 현황 조회] branch_id: $branchId, pro_id: $proId, date: $date');
      }

      final result = await SupabaseAdapter.getData(
        table: 'v2_LS_orders',
        fields: [
          "LS_id",
          "LS_date",
          "LS_transaction_type",
          "member_id",
          "member_name",
          "LS_start_time",
          "LS_end_time",
          "LS_net_min",
          "LS_status",
          "LS_request",
          "LS_type",
          "pro_id",
          "pro_name",
          "LS_confirm",
          "LS_feedback_good",
          "LS_feedback_homework",
          "LS_feedback_nextlesson"
        ],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId},
          {"field": "LS_date", "operator": "=", "value": date}
        ],
        orderBy: [
          {"field": "LS_start_time", "direction": "ASC"}
        ],
      );

      if (kDebugMode) {
        print('✅ [레슨 현황 조회] 조회 성공: ${result.length}개');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨 현황 조회] 예외 발생: $e');
      }
      return [];
    }
  }

  // 특정 프로의 특정 기간 레슨 통계 조회
  static Future<Map<String, dynamic>?> getLessonStats({
    required String branchId,
    required int proId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [레슨 통계 조회] branch_id: $branchId, pro_id: $proId, period: $startDate ~ $endDate');
      }

      final result = await SupabaseAdapter.getData(
        table: 'v2_LS_orders',
        fields: ["LS_status", "LS_net_min"],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId},
          {"field": "LS_date", "operator": ">=", "value": startDate},
          {"field": "LS_date", "operator": "<=", "value": endDate}
        ],
      );

      // 클라이언트에서 집계 처리
      Map<String, dynamic> stats = {
        'total_lessons': 0,
        'total_minutes': 0,
        'completed': 0,
        'scheduled': 0,
        'cancelled': 0,
      };

      for (var item in result) {
        stats['total_lessons'] = (stats['total_lessons'] as int) + 1;
        stats['total_minutes'] = (stats['total_minutes'] as int) + (item['LS_net_min'] ?? 0);

        switch (item['LS_status']) {
          case '결제완료':
          case '완료':
            stats['completed'] = (stats['completed'] as int) + 1;
            break;
          case '예약완료':
          case '체크인전':
            stats['scheduled'] = (stats['scheduled'] as int) + 1;
            break;
          default:
            stats['cancelled'] = (stats['cancelled'] as int) + 1;
        }
      }

      if (kDebugMode) {
        print('✅ [레슨 통계 조회] 조회 완료');
      }
      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨 통계 조회] 예외 발생: $e');
      }
      return null;
    }
  }

  // 레슨 피드백 업데이트 (v2_LS_orders 테이블)
  static Future<bool> updateLessonFeedback({
    required String branchId,
    required String lessonId,
    required String confirm,
    required String feedbackGood,
    required String feedbackHomework,
    required String feedbackNextLesson,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [레슨 피드백 업데이트] branch_id: $branchId, LS_id: $lessonId');
      }

      // 업데이트할 데이터 준비
      Map<String, dynamic> updateData = {
        "LS_confirm": confirm,
        "LS_feedback_good": feedbackGood,
        "LS_feedback_homework": feedbackHomework,
        "LS_feedback_nextlesson": feedbackNextLesson,
      };

      // 예약취소(환불)인 경우에만 LS_status를 추가
      if (confirm == "예약취소(환불)") {
        updateData["LS_status"] = "예약취소";
      }

      await SupabaseAdapter.updateData(
        table: 'v2_LS_orders',
        data: updateData,
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "LS_id", "operator": "=", "value": lessonId}
        ],
      );

      if (kDebugMode) {
        print('✅ [레슨 피드백 업데이트] 업데이트 성공');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨 피드백 업데이트] 예외 발생: $e');
      }
      return false;
    }
  }

  // 레슨 환불 처리 (v3_LS_countings 테이블 잔액 재계산)
  static Future<bool> processLessonRefund({
    required String branchId,
    required String lessonId,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [레슨 환불 처리] branch_id: $branchId, LS_id: $lessonId');
      }

      // 1. 해당 레슨의 counting 레코드 조회
      final countingResult = await SupabaseAdapter.getData(
        table: 'v3_LS_countings',
        fields: [
          "LS_counting_id",
          "contract_history_id",
          "LS_balance_min_before",
          "LS_balance_min_after",
          "LS_net_min"
        ],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "LS_id", "operator": "=", "value": lessonId}
        ],
      );

      if (countingResult.isEmpty) {
        if (kDebugMode) {
          print('❌ [레슨 환불 처리] counting 데이터가 비어있음');
        }
        return false;
      }

      final canceledRecord = countingResult[0];
      final canceledCountingId = canceledRecord['LS_counting_id'];
      final contractHistoryId = canceledRecord['contract_history_id'];
      final balanceBeforeCancel = canceledRecord['LS_balance_min_before'];

      if (kDebugMode) {
        print('🔍 [레슨 환불 처리] 취소 대상 레코드:');
        print('   LS_counting_id: $canceledCountingId');
        print('   contract_history_id: $contractHistoryId');
        print('   LS_balance_min_before: $balanceBeforeCancel');
      }

      // 2. 취소된 레슨의 LS_net_min을 0으로, LS_balance_min_after를 before와 동일하게 수정
      await SupabaseAdapter.updateData(
        table: 'v3_LS_countings',
        data: {
          "LS_net_min": 0,
          "LS_balance_min_after": balanceBeforeCancel,
        },
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "LS_counting_id", "operator": "=", "value": canceledCountingId}
        ],
      );

      // 3. 동일 contract_history_id의 후속 레코드들 조회
      final subsequentRecords = await SupabaseAdapter.getData(
        table: 'v3_LS_countings',
        fields: [
          "LS_counting_id",
          "LS_transaction_type",
          "LS_net_min",
          "LS_balance_min_before",
          "LS_balance_min_after"
        ],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "contract_history_id", "operator": "=", "value": contractHistoryId},
          {"field": "LS_counting_id", "operator": ">", "value": canceledCountingId}
        ],
        orderBy: [
          {"field": "LS_counting_id", "direction": "ASC"}
        ],
      );

      // 4. 후속 레코드들의 잔액 재계산
      int currentBalance = balanceBeforeCancel;

      if (kDebugMode) {
        print('🔍 [레슨 환불 처리] 후속 레코드 ${subsequentRecords.length}개 재계산 시작');
        print('   시작 잔액: $currentBalance');
      }

      for (var record in subsequentRecords) {
        int netMin = record['LS_net_min'] ?? 0;
        String transactionType = record['LS_transaction_type'] ?? '';
        int countingId = record['LS_counting_id'];

        int newBalanceBefore = currentBalance;
        int newBalanceAfter;

        if (transactionType == '레슨권 구매') {
          newBalanceAfter = newBalanceBefore + netMin;
        } else {
          newBalanceAfter = newBalanceBefore - netMin;
        }

        if (kDebugMode) {
          print('🔍 [레슨 환불 처리] 레코드 $countingId 재계산:');
          print('   transaction_type: $transactionType');
          print('   net_min: $netMin');
          print('   before: $newBalanceBefore → after: $newBalanceAfter');
        }

        await SupabaseAdapter.updateData(
          table: 'v3_LS_countings',
          data: {
            "LS_balance_min_before": newBalanceBefore,
            "LS_balance_min_after": newBalanceAfter,
          },
          where: [
            {"field": "branch_id", "operator": "=", "value": branchId},
            {"field": "LS_counting_id", "operator": "=", "value": countingId}
          ],
        );

        currentBalance = newBalanceAfter;
      }

      if (kDebugMode) {
        print('✅ [레슨 환불 처리] 환불 및 잔액 재계산 완료');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨 환불 처리] 예외 발생: $e');
      }
      return false;
    }
  }

  // 레슨비 정산 - 월별 집계 (최근 3개월)
  static Future<Map<String, dynamic>?> getLessonFeeMonthlyStats({
    required String branchId,
    required int proId,
    required DateTime targetMonth,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [레슨비 정산 월별 집계] branch_id: $branchId, pro_id: $proId');
      }

      Map<String, dynamic> monthlyStats = {};

      // 최근 3개월 데이터 조회
      for (int i = 0; i < 3; i++) {
        final month = DateTime(targetMonth.year, targetMonth.month - i);
        final startDate = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month, 1));
        final endDate = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month + 1, 0));
        final monthStr = DateFormat('yyyy-MM').format(month);

        final result = await SupabaseAdapter.getData(
          table: 'v2_LS_orders',
          fields: ["LS_confirm", "LS_net_min"],
          where: [
            {"field": "branch_id", "operator": "=", "value": branchId},
            {"field": "pro_id", "operator": "=", "value": proId},
            {"field": "LS_date", "operator": ">=", "value": startDate},
            {"field": "LS_date", "operator": "<=", "value": endDate},
            {"field": "LS_status", "operator": "=", "value": "결제완료"}
          ],
        );

        Map<String, dynamic> monthData = <String, dynamic>{};

        for (var item in result) {
          String confirmType = item['LS_confirm'] ?? '';
          int netMin = (item['LS_net_min'] is String)
              ? int.tryParse(item['LS_net_min']) ?? 0
              : item['LS_net_min'] ?? 0;

          String categoryType = confirmType.isEmpty ? '미확인' : confirmType;
          monthData[categoryType] = (monthData[categoryType] ?? 0) + netMin;
        }

        monthlyStats[monthStr] = monthData;
      }

      if (kDebugMode) {
        print('✅ [레슨비 정산 월별 집계] 조회 완료');
      }

      return monthlyStats;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨비 정산 월별 집계] 예외 발생: $e');
      }
      return null;
    }
  }

  // 레슨비 정산 - 일자별 현황 (선택월)
  static Future<List<Map<String, dynamic>>?> getLessonFeeDailyStats({
    required String branchId,
    required int proId,
    required DateTime targetMonth,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [레슨비 정산 일자별 현황] branch_id: $branchId, pro_id: $proId, month: ${DateFormat('yyyy-MM').format(targetMonth)}');
      }

      final startDate = DateFormat('yyyy-MM-dd').format(DateTime(targetMonth.year, targetMonth.month, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime(targetMonth.year, targetMonth.month + 1, 0));

      final result = await SupabaseAdapter.getData(
        table: 'v2_LS_orders',
        fields: ["LS_date", "LS_confirm", "LS_net_min"],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId},
          {"field": "LS_date", "operator": ">=", "value": startDate},
          {"field": "LS_date", "operator": "<=", "value": endDate},
          {"field": "LS_status", "operator": "=", "value": "결제완료"}
        ],
        orderBy: [
          {"field": "LS_date", "direction": "ASC"}
        ],
      );

      // 일자별로 그룹화
      Map<String, Map<String, dynamic>> dailyData = {};

      for (var item in result) {
        String dateStr = item['LS_date'] ?? '';
        String confirmType = item['LS_confirm'] ?? '';
        int netMin = (item['LS_net_min'] is String)
            ? int.tryParse(item['LS_net_min']) ?? 0
            : item['LS_net_min'] ?? 0;

        if (dateStr.isNotEmpty) {
          if (!dailyData.containsKey(dateStr)) {
            dailyData[dateStr] = <String, dynamic>{};
          }

          String categoryType = confirmType.isEmpty ? '미확인' : confirmType;
          dailyData[dateStr]![categoryType] = (dailyData[dateStr]![categoryType] ?? 0) + netMin;
        }
      }

      // 리스트로 변환
      List<Map<String, dynamic>> dailyStats = [];
      for (var entry in dailyData.entries) {
        Map<String, dynamic> dayData = <String, dynamic>{
          'date': entry.key,
        };
        dayData.addAll(entry.value);
        dailyStats.add(dayData);
      }

      // 날짜순 정렬
      dailyStats.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      if (kDebugMode) {
        print('✅ [레슨비 정산 일자별 현황] 조회 완료: ${dailyStats.length}일');
      }

      return dailyStats;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨비 정산 일자별 현황] 예외 발생: $e');
      }
      return null;
    }
  }

  // 프로 계약 정보 조회 (해당월 말일 기준으로 유효한 계약)
  static Future<Map<String, dynamic>?> getProContractInfo({
    required String branchId,
    required int proId,
    required DateTime targetMonth,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [프로 계약 정보 조회] branch_id: $branchId, pro_id: $proId, month: ${DateFormat('yyyy-MM').format(targetMonth)}');
      }

      // 해당월 말일 계산
      final lastDayOfMonth = DateFormat('yyyy-MM-dd').format(DateTime(targetMonth.year, targetMonth.month + 1, 0));

      final result = await SupabaseAdapter.getData(
        table: 'v2_staff_pro',
        fields: [
          "pro_contract_id",
          "branch_id",
          "pro_id",
          "staff_type",
          "pro_name",
          "pro_phone",
          "staff_access_id",
          "pro_gender",
          "staff_status",
          "pro_license",
          "min_service_min",
          "svc_time_unit",
          "min_reservation_term",
          "reservation_ahead_days",
          "pro_contract_startdate",
          "pro_contract_enddate",
          "contract_type",
          "pro_contract_status",
          "severance_pay",
          "salary_base",
          "salary_hour",
          "salary_per_lesson",
          "salary_per_lesson_min",
          "salary_per_event",
          "salary_per_event_min",
          "salary_per_promo",
          "salary_per_promo_min",
          "salalry_per_noshow",
          "salary_per_noshow_min",
          "pro_contract_round",
          "updated_at",
          "pro_birthday"
        ],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId},
          {"field": "pro_contract_startdate", "operator": "<=", "value": lastDayOfMonth},
          {"field": "pro_contract_enddate", "operator": ">=", "value": lastDayOfMonth}
        ],
        orderBy: [
          {"field": "pro_contract_round", "direction": "DESC"},
          {"field": "updated_at", "direction": "DESC"}
        ],
      );

      if (result.isNotEmpty) {
        if (kDebugMode) {
          print('✅ [프로 계약 정보 조회] 조회 성공');
          print('   min_service_min: ${result[0]['min_service_min']}');
        }
        return result[0];
      } else {
        if (kDebugMode) {
          print('❌ [프로 계약 정보 조회] 해당 기간의 계약을 찾을 수 없음');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [프로 계약 정보 조회] 예외 발생: $e');
      }
      return null;
    }
  }

  // 급여 정보 저장 (v2_salary_pro 테이블) - update 먼저 시도, 실패하면 add
  static Future<bool> saveSalaryInfo({
    required String branchId,
    required int proId,
    required String proName,
    required int year,
    required int month,
    required String salaryStatus,
    required String contractType,
    required int salaryBase,
    required int salaryHour,
    required int salaryPerLesson,
    required int salaryPerEvent,
    required int salaryPerPromo,
    required int salaryPerNoshow,
    required int salaryTotal,
    required int fourInsure,
    required int incomeTax,
    required int businessIncomeTax,
    required int localTax,
    required int otherDeduction,
    required int deductionSum,
    required int salaryNet,
  }) async {
    try {
      if (kDebugMode) {
        print('💰 [급여 정보 저장] pro_id: $proId, year: $year, month: $month');
      }

      final dataMap = {
        "branch_id": branchId,
        "pro_id": proId.toString(),
        "pro_name": proName,
        "year": year.toString(),
        "month": month.toString(),
        "salary_status": salaryStatus,
        "contract_type": contractType,
        "salary_base": salaryBase.toString(),
        "salary_hour": salaryHour.toString(),
        "salary_per_lesson": salaryPerLesson.toString(),
        "salary_per_event": salaryPerEvent.toString(),
        "salary_per_promo": salaryPerPromo.toString(),
        "salalry_per_noshow": salaryPerNoshow.toString(),
        "severance_pay": "0",
        "salary_total": salaryTotal.toString(),
        "four_insure": fourInsure.toString(),
        "income_tax": incomeTax.toString(),
        "business_income_tax": businessIncomeTax.toString(),
        "local_tax": localTax.toString(),
        "other_deduction": otherDeduction.toString(),
        "deduction_sum": deductionSum.toString(),
        "salary_net": salaryNet.toString(),
        "updated_at": DateTime.now().toIso8601String(),
      };

      // 1. 먼저 기존 레코드 있는지 확인
      final existingRecords = await SupabaseAdapter.getData(
        table: 'v2_salary_pro',
        fields: ["pro_id"],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId.toString()},
          {"field": "year", "operator": "=", "value": year.toString()},
          {"field": "month", "operator": "=", "value": month.toString()}
        ],
      );

      if (existingRecords.isNotEmpty) {
        // 2. 기존 레코드 있으면 update
        await SupabaseAdapter.updateData(
          table: 'v2_salary_pro',
          data: dataMap,
          where: [
            {"field": "branch_id", "operator": "=", "value": branchId},
            {"field": "pro_id", "operator": "=", "value": proId.toString()},
            {"field": "year", "operator": "=", "value": year.toString()},
            {"field": "month", "operator": "=", "value": month.toString()}
          ],
        );
        if (kDebugMode) {
          print('✅ [급여 정보 저장] UPDATE 성공');
        }
      } else {
        // 3. 없으면 add
        await SupabaseAdapter.addData(
          table: 'v2_salary_pro',
          data: dataMap,
        );
        if (kDebugMode) {
          print('✅ [급여 정보 저장] ADD 성공');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [급여 정보 저장] 예외 발생: $e');
      }
      return false;
    }
  }

  // 급여 정보 조회 (v2_salary_pro 테이블)
  static Future<Map<String, dynamic>?> getSalaryInfo({
    required String branchId,
    required int proId,
    required int year,
    required int month,
  }) async {
    try {
      if (kDebugMode) {
        print('💰 [급여 정보 조회] pro_id: $proId, year: $year, month: $month');
      }

      final result = await SupabaseAdapter.getData(
        table: 'v2_salary_pro',
        fields: [
          "four_insure",
          "income_tax",
          "business_income_tax",
          "local_tax",
          "other_deduction",
          "deduction_sum",
          "salary_net"
        ],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId.toString()},
          {"field": "year", "operator": "=", "value": year.toString()},
          {"field": "month", "operator": "=", "value": month.toString()}
        ],
      );

      if (result.isNotEmpty) {
        if (kDebugMode) {
          print('✅ [급여 정보 조회] 조회 성공');
        }
        return result[0];
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [급여 정보 조회] 예외 발생: $e');
      }
      return null;
    }
  }

  // 프로 근무시간 조회 (v2_schedule_adjusted_pro 테이블)
  static Future<Map<String, dynamic>?> getProWorkSchedule({
    required String branchId,
    required int proId,
    required String date, // YYYY-MM-DD 형식
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [프로 근무시간 조회] branch_id: $branchId, pro_id: $proId, date: $date');
      }

      final result = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_pro',
        fields: [
          "scheduled_staff_id",
          "pro_id",
          "pro_name",
          "scheduled_date",
          "work_start",
          "work_end",
          "is_day_off"
        ],
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "pro_id", "operator": "=", "value": proId},
          {"field": "scheduled_date", "operator": "=", "value": date}
        ],
      );

      if (result.isNotEmpty) {
        if (kDebugMode) {
          print('✅ [프로 근무시간 조회] 조회 성공');
        }
        return result[0];
      } else {
        if (kDebugMode) {
          print('⚠️ [프로 근무시간 조회] 스케줄 데이터 없음');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [프로 근무시간 조회] 예외 발생: $e');
      }
      return null;
    }
  }

  // 스케줄 등록 (v2_LS_orders 테이블)
  static Future<bool> createSchedule({
    required String branchId,
    required String date, // YYYY-MM-DD 형식
    required int proId,
    required String proName,
    required String staffAccessId, // 등록한 직원 ID
    required String startTime, // HH:mm 형식
    required String endTime, // HH:mm 형식
    required String content,
  }) async {
    try {
      if (kDebugMode) {
        print('📝 [스케줄 등록] branch_id: $branchId, pro_id: $proId, date: $date');
        print('📝 [스케줄 등록] 시간: $startTime ~ $endTime');
        print('📝 [스케줄 등록] 내용: $content');
      }

      // LS_id 생성: {date}_{pro_id}_{시작시간}
      String dateForId = date.replaceAll('-', '');
      String timeForId = startTime.replaceAll(':', '');
      String lessonId = '${dateForId}_${proId}_$timeForId';

      // 시작/종료 시간을 HH:mm:ss 형식으로 변환
      String startTimeWithSeconds = '$startTime:00';
      String endTimeWithSeconds = '$endTime:00';

      // 레슨 시간 계산 (분)
      List<String> startParts = startTime.split(':');
      List<String> endParts = endTime.split(':');
      int startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      int endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      int netMinutes = endMinutes - startMinutes;

      await SupabaseAdapter.addData(
        table: 'v2_LS_orders',
        data: {
          "branch_id": branchId,
          "LS_id": lessonId,
          "LS_transaction_type": "스케줄등록",
          "LS_date": date,
          "member_id": null,
          "LS_status": "예약완료",
          "member_name": staffAccessId,
          "member_type": "일반",
          "LS_type": "일반",
          "pro_id": proId.toString(),
          "pro_name": proName,
          "LS_order_source": "APP",
          "LS_start_time": startTimeWithSeconds,
          "LS_end_time": endTimeWithSeconds,
          "LS_net_min": netMinutes.toString(),
          "LS_request": content,
          "LS_count": "1",
          "updated_at": DateTime.now().toIso8601String(),
        },
      );

      if (kDebugMode) {
        print('✅ [스케줄 등록] 등록 성공');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [스케줄 등록] 예외 발생: $e');
      }
      return false;
    }
  }

  // 스케줄 취소 (v2_LS_orders 테이블의 LS_status를 '예약취소'로 변경)
  static Future<bool> cancelSchedule({
    required String branchId,
    required String lessonId,
  }) async {
    try {
      if (kDebugMode) {
        print('🗑️ [스케줄 취소] branch_id: $branchId, LS_id: $lessonId');
      }

      await SupabaseAdapter.updateData(
        table: 'v2_LS_orders',
        data: {
          "LS_status": "예약취소",
          "updated_at": DateTime.now().toIso8601String(),
        },
        where: [
          {"field": "branch_id", "operator": "=", "value": branchId},
          {"field": "LS_id", "operator": "=", "value": lessonId}
        ],
      );

      if (kDebugMode) {
        print('✅ [스케줄 취소] 취소 성공');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [스케줄 취소] 예외 발생: $e');
      }
      return false;
    }
  }
}
