import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/ts_reservation.dart';
import '/services/api_service.dart';
import '../../constants/font_sizes.dart';
import 'crm3_ts_control_time_adjust.dart'; // ReservationStatus enum 사용

/// 타석 이동 관련 기능을 담당하는 서비스 클래스
class TsTsMoveService {
  /// 시간 파싱 헬퍼 (날짜 포함)
  static DateTime _parseTimeWithDate(String timeStr, String dateStr) {
    final date = DateTime.parse(dateStr);
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return date;
  }

  /// 타석 이동 버튼 활성화 여부 체크
  static bool isTsMoveEnabled(TsReservation reservation) {
    // 취소된 예약은 타석 이동 불가
    if (reservation.tsStatus == '예약취소') {
      return false;
    }
    
    final status = TsTimeAdjustService.getReservationStatus(reservation);
    
    // 미래 예약과 진행 중인 예약만 타석 이동 가능 (과거 예약은 불가)
    return status == ReservationStatus.future || status == ReservationStatus.inProgress;
  }

  /// 이동 가능한 타석 목록 조회
  static Future<List<int>> getAvailableTsForMovement(TsReservation reservation) async {
    try {
      final now = DateTime.now();
      final currentStartTime = _parseTimeWithDate(reservation.tsStart ?? '', reservation.tsDate!);
      final currentEndTime = _parseTimeWithDate(reservation.tsEnd ?? '', reservation.tsDate!);
      final currentTsId = reservation.tsId!;
      
      // 미래 예약인지 진행 중 예약인지 판단
      final isFutureReservation = currentStartTime.isAfter(now);
      
      print('\n=== 타석 이동 가능성 체크 ===');
      print('현재 시간: $now');
      print('예약 시간: $currentStartTime ~ $currentEndTime');
      print('예약 유형: ${isFutureReservation ? "미래 예약" : "진행 중 예약"}');
      print('현재 타석 ID: $currentTsId');
      
      // 충돌 체크할 시간 범위 결정
      final checkStartTime = isFutureReservation ? currentStartTime : now;
      final checkEndTime = currentEndTime;
      
      print('충돌 체크 범위: $checkStartTime ~ $checkEndTime');
      
      // 모든 타석 정보 조회
      final allTsInfo = await ApiService.getTsInfoData(
        fields: ['ts_id', 'ts_buffer'],
        where: [
          {
            'field': 'ts_status',
            'operator': '=',
            'value': '예약가능',
          },
        ],
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'},
        ],
      );
      
      List<int> availableList = [];
      
      for (var tsInfo in allTsInfo) {
        final tsId = int.parse(tsInfo['ts_id'].toString());
        if (tsId == currentTsId) continue; // 현재 타석 제외
        
        final bufferMinutes = int.tryParse(tsInfo['ts_buffer']?.toString() ?? '0') ?? 0;
        
        // 해당 타석의 현재 시간 이후 예약들 확인
        final conflictReservations = await ApiService.getTsData(
          fields: ['ts_start', 'ts_end'],
          where: [
            {
              'field': 'ts_id',
              'operator': '=',
              'value': tsId,
            },
            {
              'field': 'ts_date',
              'operator': '=',
              'value': reservation.tsDate!,
            },
            {
              'field': 'ts_status',
              'operator': '=',
              'value': '결제완료',
            },
          ],
        );
        
        bool isAvailable = true;
        
        // 현재 시간부터 원래 예약 종료시간까지의 충돌 체크
        for (var conflictReservation in conflictReservations) {
          final reservationStart = _parseTimeWithDate(conflictReservation['ts_start'] as String, reservation.tsDate!);
          final reservationEnd = _parseTimeWithDate(conflictReservation['ts_end'] as String, reservation.tsDate!);
          
          print('타석 ${tsId}번 체크: ${conflictReservation['ts_start']} ~ ${conflictReservation['ts_end']}');
          print('  정확한 예약 시간: $reservationStart ~ $reservationEnd');
          
          // 이미 종료된 예약은 충돌 체크에서 제외
          if (reservationEnd.isBefore(now)) {
            print('  ✅ 이미 종료된 예약이므로 충돌 체크 제외 (종료: $reservationEnd < 현재: $now)');
            continue;
          }
          
          // 버퍼 시간 고려한 충돌 체크
          final bufferStart = reservationStart.subtract(Duration(minutes: bufferMinutes));
          final bufferEnd = reservationEnd.add(Duration(minutes: bufferMinutes));
          
          print('  버퍼 적용 시간: $bufferStart ~ $bufferEnd (버퍼: ${bufferMinutes}분)');
          print('  충돌 체크: checkEndTime($checkEndTime) <= bufferStart($bufferStart) = ${checkEndTime.isBefore(bufferStart) || checkEndTime.isAtSameMomentAs(bufferStart)}');
          print('  충돌 체크: checkStartTime($checkStartTime) >= bufferEnd($bufferEnd) = ${checkStartTime.isAfter(bufferEnd) || checkStartTime.isAtSameMomentAs(bufferEnd)}');
          
          // 이동할 시간 범위와 기존 예약이 겹치는지 확인
          if (!(checkEndTime.isBefore(bufferStart) || checkEndTime.isAtSameMomentAs(bufferStart) || checkStartTime.isAfter(bufferEnd) || checkStartTime.isAtSameMomentAs(bufferEnd))) {
            print('  ❌ 충돌 발생! 타석 ${tsId}번 이동 불가');
            isAvailable = false;
            break;
          } else {
            print('  ✅ 충돌 없음');
          }
        }
        
        if (isAvailable) {
          availableList.add(tsId);
        }
      }
      
      return availableList;
    } catch (e) {
      print('이동 가능한 타석 조회 오류: $e');
      return [];
    }
  }

  /// 할인 쿠폰 업데이트
  static Future<void> updateDiscountCoupons(String originalReservationId, String newReservationId) async {
    try {
      print('쿠폰 업데이트 시작: $originalReservationId → $newReservationId');
      
      // 1. 이동 전 reservation_id로 사용된 쿠폰 조회
      final usedCoupons = await ApiService.getDiscountCouponsData(
        where: [
          {'field': 'reservation_id_used', 'operator': '=', 'value': originalReservationId},
        ],
      );
      
      // 2. 이동 전 reservation_id로 발급된 쿠폰 조회  
      final issuedCoupons = await ApiService.getDiscountCouponsData(
        where: [
          {'field': 'reservation_id_issued', 'operator': '=', 'value': originalReservationId},
        ],
      );
      
      if (usedCoupons.isEmpty && issuedCoupons.isEmpty) {
        print('쿠폰 없음 - 처리할 쿠폰이 없습니다');
        return;
      }
      
      // 3. 이동 전 reservation_id로 사용된 쿠폰들의 reservation_id_used 업데이트
      for (var coupon in usedCoupons) {
        print('\n📊 [discount_coupons] 사용된 쿠폰 UPDATE:');
        print('  coupon_id: ${coupon['coupon_id']}');
        print('  where: coupon_bill_id = ${coupon['coupon_bill_id']}');
        print('  data: {reservation_id_used: $originalReservationId → $newReservationId}');
        
        await ApiService.updateDiscountCouponsData(
          {'reservation_id_used': newReservationId},
          [
            {'field': 'coupon_id', 'operator': '=', 'value': coupon['coupon_id']},
          ],
        );
        print('✅ 사용된 쿠폰 ${coupon['coupon_id']} 업데이트 완료');
      }
      
      // 4. 이동 전 reservation_id로 발급된 쿠폰들의 reservation_id_issued 업데이트
      for (var coupon in issuedCoupons) {
        print('\n📊 [discount_coupons] 발급된 쿠폰 UPDATE:');
        print('  coupon_id: ${coupon['coupon_id']}');
        print('  where: coupon_id = ${coupon['coupon_id']}');
        print('  data: {reservation_id_issued: $originalReservationId → $newReservationId}');
        
        await ApiService.updateDiscountCouponsData(
          {'reservation_id_issued': newReservationId},
          [
            {'field': 'coupon_id', 'operator': '=', 'value': coupon['coupon_id']},
          ],
        );
        print('✅ 발급된 쿠폰 ${coupon['coupon_id']} 업데이트 완료');
      }
    } catch (e) {
      print('할인 쿠폰 업데이트 오류: $e');
      throw e;
    }
  }
}

/// 타석 이동 다이얼로그
class TsTsMoveDialog {
  /// 타석 이동 다이얼로그 표시
  static Future<void> show(BuildContext context, TsReservation reservation, VoidCallback? onDataChanged) async {
    // 예약 상태 확인
    if (reservation.tsStatus == '예약취소') {
      _showCancelledReservationDialog(context);
      return;
    }

    final status = TsTimeAdjustService.getReservationStatus(reservation);
    
    // 과거 예약은 타석 이동 불가
    if (status == ReservationStatus.past) {
      _showPastReservationDialog(context);
      return;
    }

    // 이동 가능한 타석 조회
    final availableStations = await TsTsMoveService.getAvailableTsForMovement(reservation);

    if (availableStations.isEmpty) {
      _showNoAvailableStationsDialog(context);
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Container(
              width: 400,
              constraints: BoxConstraints(maxHeight: 500),
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '타석 이동',
                        style: AppTextStyles.titleH3.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  
                  // 현재 타석 정보
                  Text(
                    '현재 타석',
                    style: AppTextStyles.bodyText.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${reservation.tsId}번 타석 (${reservation.tsStart} ~ ${reservation.tsEnd})',
                      style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // 이동 가능한 타석 목록
                  Text(
                    '이동 가능한 타석',
                    style: AppTextStyles.bodyText.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2,
                      ),
                      itemCount: availableStations.length,
                      itemBuilder: (context, index) {
                        final stationId = availableStations[index];
                        return ElevatedButton(
                          onPressed: () async {
                            await _handleTsMovement(context, reservation, stationId, onDataChanged);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '${stationId}번',
                            style: AppTextStyles.button.copyWith(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  /// 타석 이동 처리
  static Future<void> _handleTsMovement(
    BuildContext context,
    TsReservation reservation,
    int newTsId,
    VoidCallback? onDataChanged,
  ) async {
    // 롤백을 위한 상태 추적 변수들
    bool originalReservationUpdated = false;
    bool newReservationCreated = false;
    bool couponsUpdated = false;
    bool billsUpdated = false;
    bool billTimesUpdated = false;
    String? createdReservationId;
    Map<String, dynamic>? originalBillData;
    Map<String, dynamic>? originalBillTimeData;
    Map<String, dynamic>? originalBillForNewRecord; // 새 bill 생성용 원본 데이터
    Map<String, dynamic>? originalBillTimeForNewRecord; // 새 bill_times 생성용 원본 데이터
    
    try {
      print('\n🎯 === 타석 이동 디버깅 시작 ===');
      print('원본 예약 정보:');
      print('  reservation_id: ${reservation.reservationId}');
      print('  ts_id: ${reservation.tsId}');
      print('  ts_date: ${reservation.tsDate}');
      print('  ts_start: ${reservation.tsStart}');
      print('  ts_end: ${reservation.tsEnd}');
      print('  ts_status: ${reservation.tsStatus}');
      print('  bill_id: ${reservation.billId}');
      print('  bill_min_id: ${reservation.billMinId}');
      print('  total_amt: ${reservation.totalAmt}');
      print('  net_amt: ${reservation.netAmt}');
      print('  ts_min: ${reservation.tsMin}');
      print('  새 타석 번호: $newTsId');
      
      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
      final currentTimeForDisplay = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // 예약 날짜를 고려한 정확한 DateTime 생성
      final reservationDate = DateTime.parse(reservation.tsDate!);
      final startTimeParts = reservation.tsStart!.split(':');
      final endTimeParts = reservation.tsEnd!.split(':');
      
      final startTime = DateTime(
        reservationDate.year,
        reservationDate.month,
        reservationDate.day,
        int.parse(startTimeParts[0]),
        int.parse(startTimeParts[1]),
      );
      
      final endTime = DateTime(
        reservationDate.year,
        reservationDate.month,
        reservationDate.day,
        int.parse(endTimeParts[0]),
        int.parse(endTimeParts[1]),
      );
      
      final isFutureReservation = startTime.isAfter(now);
      
      // 시간 비중 계산을 위한 변수
      final totalMinutes = endTime.difference(startTime).inMinutes;
      int originalMinutes = 0;
      int movedMinutes = 0;
      double originalRatio = 0.0;
      double movedRatio = 0.0;
      
      String newReservationId;
      Map<String, dynamic> newReservationData;
      
      if (isFutureReservation) {
        // 미래 예약: 기존 예약 취소하고 새 타석에 동일 시간대로 생성
        
        // 미래 예약은 100% 이동
        originalMinutes = 0;
        movedMinutes = totalMinutes;
        originalRatio = 0.0;
        movedRatio = 1.0;
        
        print('타석 이동 - 미래 예약');
        print('전체 시간: ${totalMinutes}분');
        print('기존 예약 비중: 0% (0분)');
        print('이동 예약 비중: 100% (${movedMinutes}분)');
        
        // 1. 기존 예약을 예약취소로 변경하고 금액/시간을 0으로 설정
        final tsUpdateData = {
          'ts_status': '예약취소',
          // 금액 필드를 0으로 설정 (0% 할당)
          'total_amt': 0,
          'term_discount': 0,
          'coupon_discount': 0,
          'total_discount': 0,
          'net_amt': 0,
          // 시간 필드를 0으로 설정 (0% 할당)
          'discount_min': 0,
          'normal_min': 0,
          'extracharge_min': 0,
          'ts_min': 0,
          'bill_min': 0,
        };
        
        print('\n📊 [v2_priced_TS] 기존 예약 UPDATE 쿼리 (미래 예약):');
        print('  table: v2_priced_TS');
        print('  where: reservation_id = ${reservation.reservationId}');
        print('  data: $tsUpdateData');
        
        await ApiService.updateTsData(
          tsUpdateData,
          [
            {
              'field': 'reservation_id',
              'operator': '=',
              'value': reservation.reservationId!,
            },
          ],
        );
        
        
        // 1-2. v2_bills 업데이트 (미래 예약은 0% 할당)
        if (reservation.billId != null) {
          print('\n=== 기존 예약 v2_bills 업데이트 (0% 할당) ===');
          
          // 기존 bill 조회
          final bills = await ApiService.getBillsData(
            where: [
              {'field': 'bill_id', 'operator': '=', 'value': reservation.billId},
            ],
          );
          
          if (bills.isNotEmpty) {
            final bill = bills[0];
            // 롤백을 위한 원본 데이터 저장
            originalBillData = {
              'bill_netamt': bill['bill_netamt'],
              'bill_balance_after': bill['bill_balance_after'],
              'bill_status': bill['bill_status'],
              'contract_history_id': bill['contract_history_id'],
            };
            
            // 새 bill 생성을 위한 원본 데이터 저장 (업데이트 전)
            originalBillForNewRecord = {
              'bill_totalamt': bill['bill_totalamt'],
              'bill_deduction': bill['bill_deduction'], 
              'bill_netamt': bill['bill_netamt'],
              'bill_balance_before': bill['bill_balance_before'],
              'bill_balance_after': bill['bill_balance_after'],
              'member_id': bill['member_id'],
              'bill_date': bill['bill_date'],
              'bill_type': bill['bill_type'],
              'contract_history_id': bill['contract_history_id'],
              'locker_bill_id': bill['locker_bill_id'],
              'routine_id': bill['routine_id'],
              'contract_credit_expiry_date': bill['contract_credit_expiry_date'],
            };
            
            final contractHistoryId = bill['contract_history_id'];
            final originalBalanceBefore = bill['bill_balance_before'] ?? 0;
            
            // 기존 bill 업데이트: 모든 금액을 0으로 (0% 할당)
            final billUpdateData = {
              'bill_totalamt': 0,   // 0% 할당
              'bill_deduction': 0,  // 0% 할당
              'bill_netamt': 0,     // 0% 할당
              'bill_balance_after': originalBalanceBefore,  // before + 0 = before
              'bill_status': '예약취소',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
            };
            
            print('\n📊 [v2_bills] UPDATE 쿼리:');
            print('  table: v2_bills');
            print('  where: bill_id = ${reservation.billId}');
            print('  data: $billUpdateData');
            
            await ApiService.updateData(
              table: 'v2_bills',
              data: billUpdateData,
              where: [
                {'field': 'bill_id', 'operator': '=', 'value': reservation.billId},
              ],
            );
            
            // 후속 bills 연쇄 잔액 재계산
            await _recalculateSubsequentBills(contractHistoryId, reservation.billId, originalBalanceBefore);
            
            billsUpdated = true;
            print('✅ v2_bills 업데이트 완료');
          }
        }
        
        // 1-3. v2_bill_times 업데이트 (미래 예약은 0% 할당)
        if (reservation.billMinId != null) {
          print('\n=== 기존 예약 v2_bill_times 업데이트 (0% 할당) ===');
          
          // 기존 bill_time 조회
          final billTimes = await ApiService.getBillTimesData(
            where: [
              {'field': 'bill_min_id', 'operator': '=', 'value': reservation.billMinId},
            ],
          );
          
          if (billTimes.isNotEmpty) {
            final billTime = billTimes[0];
            // 롤백을 위한 원본 데이터 저장
            originalBillTimeData = {
              'bill_min': billTime['bill_min'],
              'bill_balance_min_after': billTime['bill_balance_min_after'],
              'bill_status': billTime['bill_status'],
              'contract_history_id': billTime['contract_history_id'],
            };
            
            // 새 bill_times 생성을 위한 원본 데이터 저장 (업데이트 전)
            originalBillTimeForNewRecord = {
              'bill_total_min': billTime['bill_total_min'],
              'bill_discount_min': billTime['bill_discount_min'],
              'bill_min': billTime['bill_min'],
              'bill_balance_min_before': billTime['bill_balance_min_before'],
              'bill_balance_min_after': billTime['bill_balance_min_after'],
              'bill_date': billTime['bill_date'],
              'member_id': billTime['member_id'],
              'bill_type': billTime['bill_type'],
              'contract_history_id': billTime['contract_history_id'],
              'contract_credit_expiry_date': billTime['contract_credit_expiry_date'],
            };
            
            final contractHistoryId = billTime['contract_history_id'];
            final originalBalanceBefore = billTime['bill_balance_min_before'] ?? 0;
            
            // 기존 bill_time 업데이트: 모든 시간 필드를 0으로
            final billTimeUpdateData = {
              'bill_total_min': 0,      // 전체 시간 0으로
              'bill_discount_min': 0,   // 할인 시간 0으로
              'bill_min': 0,            // 사용 시간 0으로 (0% 할당)
              'bill_balance_min_after': originalBalanceBefore,  // before - 0 = before
              'bill_status': '예약취소',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
            };
            
            print('\n📊 [v2_bill_times] UPDATE 쿼리:');
            print('  table: v2_bill_times');
            print('  where: bill_min_id = ${reservation.billMinId}');
            print('  data: $billTimeUpdateData');
            
            await ApiService.updateData(
              table: 'v2_bill_times',
              data: billTimeUpdateData,
              where: [
                {'field': 'bill_min_id', 'operator': '=', 'value': reservation.billMinId},
              ],
            );
            
            // 후속 bill_times 연쇄 시간잔액 재계산
            print('📊 [미래예약] bill_times 재계산 시작: currentBillMinId=${reservation.billMinId}, newBalanceAfter=${originalBalanceBefore}');
            await _recalculateSubsequentBillTimes(contractHistoryId, reservation.billMinId, originalBalanceBefore);
            
            billTimesUpdated = true;
            print('✅ v2_bill_times 업데이트 완료');
          }
        }
        
        // 2. 새로운 reservation_id 생성 (기존 시간 기준)
        final dateStr = reservation.tsDate!.replaceAll('-', '').substring(2); // YYMMDD
        final originalTimeStr = reservation.tsStart!.substring(0, 5).replaceAll(':', ''); // HHMM
        newReservationId = '${dateStr}_${newTsId}_${originalTimeStr}';
        
        // 3. 새로운 예약 레코드 생성 (동일한 시간대)
        newReservationData = {
          'reservation_id': newReservationId,
          'ts_id': newTsId,
          'ts_start': reservation.tsStart, // 기존 시작시간 유지
          'ts_end': reservation.tsEnd,     // 기존 종료시간 유지
          'ts_status': '결제완료',
          'time_stamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now),
        };
        
        // 3-1. 새 bill/bill_times 생성은 맨 마지막에 수행 (balance 재계산 후)
      } else {
        // 진행 중 예약: 기존 예약 종료하고 새 타석에 현재시간부터 생성
        
        // 시간 비중 계산
        originalMinutes = now.difference(startTime).inMinutes;
        movedMinutes = totalMinutes - originalMinutes;  // 전체 시간에서 사용한 시간을 빼서 정확한 계산
        
        // 비율 계산 (0으로 나누기 방지)
        originalRatio = totalMinutes > 0 ? originalMinutes / totalMinutes : 0.0;
        movedRatio = totalMinutes > 0 ? movedMinutes / totalMinutes : 0.0;
        
        final originalPercentage = (originalRatio * 100).toStringAsFixed(1);
        final movedPercentage = (movedRatio * 100).toStringAsFixed(1);
        
        print('타석 이동 - 진행 중 예약');
        print('예약 시간: ${reservation.tsStart} ~ ${reservation.tsEnd}');
        print('현재 시간: $currentTime');
        print('전체 시간: ${totalMinutes}분');
        print('기존 예약: ${originalMinutes}분 (${originalPercentage}%)');
        print('이동 예약: ${movedMinutes}분 (${movedPercentage}%)');
        
        // 금액과 시간을 비율대로 분배
        Map<String, dynamic> originalUpdates = {'ts_end': currentTime};
        Map<String, dynamic> movedUpdates = {};
        
        // 금액 필드 분배 (반올림 오차 방지: 첫 번째는 반올림, 두 번째는 전체에서 차감)
        if (reservation.totalAmt != null) {
          final originalAmt = (reservation.totalAmt! * originalRatio).round();
          originalUpdates['total_amt'] = originalAmt;
          movedUpdates['total_amt'] = reservation.totalAmt! - originalAmt;
        }
        if (reservation.termDiscount != null) {
          final originalDiscount = (reservation.termDiscount! * originalRatio).round();
          originalUpdates['term_discount'] = originalDiscount;
          movedUpdates['term_discount'] = reservation.termDiscount! - originalDiscount;
        }
        if (reservation.couponDiscount != null) {
          final originalCoupon = (reservation.couponDiscount! * originalRatio).round();
          originalUpdates['coupon_discount'] = originalCoupon;
          movedUpdates['coupon_discount'] = reservation.couponDiscount! - originalCoupon;
        }
        if (reservation.totalDiscount != null) {
          final originalTotal = (reservation.totalDiscount! * originalRatio).round();
          originalUpdates['total_discount'] = originalTotal;
          movedUpdates['total_discount'] = reservation.totalDiscount! - originalTotal;
        }
        if (reservation.netAmt != null) {
          final originalNet = (reservation.netAmt! * originalRatio).round();
          originalUpdates['net_amt'] = originalNet;
          movedUpdates['net_amt'] = reservation.netAmt! - originalNet;
        }
        
        // 시간 필드 분배 (반올림 오차 방지: 첫 번째는 반올림, 두 번째는 전체에서 차감)
        if (reservation.discountMin != null) {
          final originalMin = (reservation.discountMin! * originalRatio).round();
          originalUpdates['discount_min'] = originalMin;
          movedUpdates['discount_min'] = reservation.discountMin! - originalMin;
        }
        if (reservation.normalMin != null) {
          final originalNormal = (reservation.normalMin! * originalRatio).round();
          originalUpdates['normal_min'] = originalNormal;
          movedUpdates['normal_min'] = reservation.normalMin! - originalNormal;
        }
        if (reservation.extrachargeMin != null) {
          final originalExtra = (reservation.extrachargeMin! * originalRatio).round();
          originalUpdates['extracharge_min'] = originalExtra;
          movedUpdates['extracharge_min'] = reservation.extrachargeMin! - originalExtra;
        }
        if (reservation.tsMin != null) {
          final originalTs = (reservation.tsMin! * originalRatio).round();
          originalUpdates['ts_min'] = originalTs;
          movedUpdates['ts_min'] = reservation.tsMin! - originalTs;
        }
        if (reservation.billMin != null) {
          final originalBill = (reservation.billMin! * originalRatio).round();
          originalUpdates['bill_min'] = originalBill;
          movedUpdates['bill_min'] = reservation.billMin! - originalBill;
        }
        
        // 1. 기존 예약 업데이트
        print('\n=== 1단계: 기존 예약 업데이트 ===');
        print('\n📊 [v2_priced_TS] 기존 예약 UPDATE 쿼리 (진행 중):');
        print('  table: v2_priced_TS');
        print('  where: reservation_id = ${reservation.reservationId}');
        print('  data: $originalUpdates');
        
        await ApiService.updateTsData(
          originalUpdates,
          [
            {
              'field': 'reservation_id',
              'operator': '=',
              'value': reservation.reservationId!,
            },
          ],
        );
        originalReservationUpdated = true;
        print('✅ 기존 예약 업데이트 완료');
        
        // 1-1. v2_bills: 진행중 예약은 기존 레코드를 사용한 부분만큼 업데이트
        if (reservation.billId != null) {
          print('\n=== 기존 예약 v2_bills 업데이트 (진행중 예약) ===');
          
          // 기존 bill 조회
          final bills = await ApiService.getBillsData(
            where: [
              {'field': 'bill_id', 'operator': '=', 'value': reservation.billId},
            ],
          );
          
          if (bills.isNotEmpty) {
            final bill = bills[0];
            // 롤백을 위한 원본 데이터 저장
            originalBillData = {
              'bill_totalamt': bill['bill_totalamt'],
              'bill_netamt': bill['bill_netamt'],
              'bill_deduction': bill['bill_deduction'],
              'bill_text': bill['bill_text'],
              'bill_balance_after': bill['bill_balance_after'],
            };
            
            final contractHistoryId = bill['contract_history_id'];
            final originalTotalAmt = bill['bill_totalamt'] ?? 0;
            final originalDeduction = bill['bill_deduction'] ?? 0; 
            final originalNetAmt = bill['bill_netamt'] ?? 0;
            final originalBalanceBefore = bill['bill_balance_before'] ?? 0;
            
            // 비율에 따른 금액 계산 (사용한 부분만)
            final usedTotalAmt = (originalTotalAmt * originalRatio).round();
            final usedDeduction = (originalDeduction * originalRatio).round();
            final usedNetAmt = (originalNetAmt * originalRatio).round();
            final newBalanceAfter = originalBalanceBefore + usedNetAmt;
            
            // 기존 bill 업데이트 (사용한 부분만 반영)
            final billUpdateData = {
              'bill_totalamt': usedTotalAmt,
              'bill_deduction': usedDeduction,
              'bill_netamt': usedNetAmt,
              'bill_text': bill['bill_text'] + ' (사용: ${originalMinutes}분)',
              'bill_balance_after': newBalanceAfter,
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
            };
            
            print('\n📊 [v2_bills] UPDATE 쿼리 (진행중):');
            print('  table: v2_bills');
            print('  where: bill_id = ${reservation.billId}');
            print('  data: $billUpdateData');
            
            await ApiService.updateBillsData(
              billUpdateData,
              [
                {'field': 'bill_id', 'operator': '=', 'value': reservation.billId},
              ],
            );
            
            // 후속 bills 연쇄 잔액 재계산
            await _recalculateSubsequentBills(contractHistoryId, reservation.billId, newBalanceAfter);
            
            // 새 레코드 생성을 위한 원본 데이터 저장 (이동할 부분)
            originalBillForNewRecord = {
              ...bill,
              'bill_totalamt': (originalTotalAmt * movedRatio).round(),
              'bill_deduction': (originalDeduction * movedRatio).round(),
              'bill_netamt': (originalNetAmt * movedRatio).round(),
            };
            
            billsUpdated = true;
            print('✅ v2_bills 업데이트 완료');
          }
        }
        
        // 1-2. v2_bill_times: 진행중 예약은 기존 레코드를 사용한 부분만큼 업데이트
        if (reservation.billMinId != null) {
          print('\n=== 기존 예약 v2_bill_times 업데이트 (진행중 예약) ===');
          
          // 기존 bill_time 조회
          final billTimes = await ApiService.getBillTimesData(
            where: [
              {'field': 'bill_min_id', 'operator': '=', 'value': reservation.billMinId},
            ],
          );
          
          if (billTimes.isNotEmpty) {
            final billTime = billTimes[0];
            // 롤백을 위한 원본 데이터 저장
            originalBillTimeData = {
              'bill_total_min': billTime['bill_total_min'],
              'bill_discount_min': billTime['bill_discount_min'],
              'bill_min': billTime['bill_min'],
              'bill_text': billTime['bill_text'],
              'bill_balance_min_after': billTime['bill_balance_min_after'],
            };
            
            final contractHistoryId = billTime['contract_history_id'];
            final originalTotalMin = billTime['bill_total_min'] ?? 0;
            final originalDiscountMin = billTime['bill_discount_min'] ?? 0;
            final originalBillMin = billTime['bill_min'] ?? 0;
            final originalBalanceBefore = billTime['bill_balance_min_before'] ?? 0;
            
            // 비율에 따른 시간 계산 (사용한 부분만)
            final usedTotalMin = (originalTotalMin * originalRatio).round();
            final usedDiscountMin = (originalDiscountMin * originalRatio).round();
            final usedBillMin = (originalBillMin * originalRatio).round();
            final newBalanceAfter = originalBalanceBefore - usedBillMin;  // 시간은 차감!
            
            // 기존 bill_time 업데이트 (사용한 부분만 반영)
            final billTimeUpdateData = {
              'bill_total_min': usedTotalMin,
              'bill_discount_min': usedDiscountMin,
              'bill_min': usedBillMin,
              'bill_text': billTime['bill_text'] + ' (사용: ${originalMinutes}분)',
              'bill_balance_min_after': newBalanceAfter,
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
            };
            
            print('\n📊 [v2_bill_times] UPDATE 쿼리 (진행중):');
            print('  table: v2_bill_times');
            print('  where: bill_min_id = ${reservation.billMinId}');
            print('  data: $billTimeUpdateData');
            
            await ApiService.updateBillTimesData(
              billTimeUpdateData,
              [
                {'field': 'bill_min_id', 'operator': '=', 'value': reservation.billMinId},
              ],
            );
            
            // 후속 bill_times 연쇄 시간잔액 재계산
            await _recalculateSubsequentBillTimes(contractHistoryId, reservation.billMinId, newBalanceAfter);
            
            // 새 레코드 생성을 위한 원본 데이터 저장 (이동할 부분)
            originalBillTimeForNewRecord = {
              ...billTime,
              'bill_total_min': (originalTotalMin * movedRatio).round(),
              'bill_discount_min': (originalDiscountMin * movedRatio).round(),
              'bill_min': (originalBillMin * movedRatio).round(),
            };
            
            billTimesUpdated = true;
            print('✅ v2_bill_times 업데이트 완료');
          }
        }
        
        // 2. 새로운 reservation_id 생성 (현재 시간 기준)
        final dateStr = reservation.tsDate!.replaceAll('-', '').substring(2); // YYMMDD
        final timeStr = currentTime.substring(0, 5).replaceAll(':', ''); // HHMM
        newReservationId = '${dateStr}_${newTsId}_${timeStr}';
        
        // 3. 새로운 예약 레코드 생성 (현재시간부터)
        newReservationData = {
          'reservation_id': newReservationId,
          'ts_id': newTsId,
          'ts_start': currentTime,               // 현재시간부터 시작
          'ts_end': reservation.tsEnd,    // 기존 종료시간 유지
          'ts_status': '결제완료',
          'time_stamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now),
        };
        
        // 분배된 금액과 시간 추가
        newReservationData.addAll(movedUpdates);
      }
      
      // 공통 필드들 추가
      newReservationData.addAll({
        'ts_date': reservation.tsDate,
        'ts_payment_method': reservation.tsPaymentMethod,
        'member_id': reservation.memberId,
        'member_type': reservation.memberType,
        'member_name': reservation.memberName,
        'member_phone': reservation.memberPhone,
        'day_of_week': reservation.dayOfWeek,
        'bill_id': null,      // 새로 생성될 예정
        'bill_min_id': null,  // 새로 생성될 예정
        'bill_game_id': null, // 새로 생성될 예정
        'program_id': reservation.programId,
        'program_name': reservation.programName,
      });
      
      // 미래 예약의 경우에만 원본 금액/시간 정보 추가 (진행 중 예약은 이미 분배된 값이 있음)
      if (isFutureReservation) {
        newReservationData.addAll({
          'total_amt': reservation.totalAmt,
          'term_discount': reservation.termDiscount,
          'coupon_discount': reservation.couponDiscount,
          'total_discount': reservation.totalDiscount,
          'net_amt': reservation.netAmt,        
          'discount_min': reservation.discountMin,
          'normal_min': reservation.normalMin,
          'extracharge_min': reservation.extrachargeMin,
          'ts_min': reservation.tsMin,
          'bill_min': reservation.billMin,
        });
      }
      
      // NULL 값 제거
      newReservationData.removeWhere((key, value) => value == null);
      
      // 새 예약 추가
      print('\n=== 2단계: 새 예약 생성 ===');
      print('\n📊 [v2_priced_TS] 새 예약 INSERT 쿼리:');
      print('  table: v2_priced_TS');
      print('  data: $newReservationData');
      
      await ApiService.addTsData(newReservationData);
      newReservationCreated = true;
      createdReservationId = newReservationId;
      print('✅ 새 예약 생성 완료: $newReservationId');
      
      // 진행 중 예약의 경우 bill 생성은 4단계에서 처리
      
      // 4. 쿠폰 처리
      print('\n=== 3단계: 쿠폰 처리 ===');
      print('\n📊 [discount_coupons] 쿠폰 이전:');
      print('  FROM reservation_id: ${reservation.reservationId}');
      print('  TO reservation_id: $newReservationId');
      
      await TsTsMoveService.updateDiscountCoupons(reservation.reservationId!, newReservationId);
      couponsUpdated = true;
      print('✅ 쿠폰 처리 완료');
      
      // 4. 새 bill/bill_times 레코드 생성 (맨 마지막 - balance 재계산 후)
      print('\n=== 4단계: 새 bill/bill_times 레코드 생성 ===');
      if (originalBillForNewRecord != null) {
        // 미래 예약 & 진행중 예약 모두 동일한 함수 사용
        final newBillId = await _createNewBillRecordFromOriginal(originalBillForNewRecord!, newReservationId, isFutureReservation, originalRatio, movedRatio, originalTsId: reservation.tsId);
        print('새로 생성된 bill_id: $newBillId');
      }
      if (originalBillTimeForNewRecord != null) {
        await _createNewBillTimesRecordFromOriginal(originalBillTimeForNewRecord!, newReservationId, isFutureReservation, originalRatio, movedRatio, originalTsId: reservation.tsId);
      }
      print('✅ 새 bill/bill_times 레코드 생성 완료');
      
      print('\n🎉 타석 이동 처리 완료: ${reservation.tsId}번 → ${newTsId}번');
      
      Navigator.of(context).pop(); // 타석 이동 다이얼로그 닫기
      Navigator.of(context).pop(); // 상세 팝업도 닫기
      
      // 성공 메시지 팝업
      _showSuccessDialog(context, reservation, newTsId, currentTimeForDisplay, onDataChanged);
      
    } catch (e) {
      print('\n❌ 타석 이동 처리 중 오류 발생: $e');
      
      // 롤백 처리
      await _rollbackTsMovement(
        originalReservationId: reservation.reservationId!,
        createdReservationId: createdReservationId,
        originalReservationUpdated: originalReservationUpdated,
        newReservationCreated: newReservationCreated,
        couponsUpdated: couponsUpdated,
        billsUpdated: billsUpdated,
        billTimesUpdated: billTimesUpdated,
        billId: reservation.billId,
        billMinId: reservation.billMinId,
        originalBillData: originalBillData,
        originalBillTimeData: originalBillTimeData,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('타석 이동 중 오류가 발생했습니다'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// 타석 이동 롤백 처리
  static Future<void> _rollbackTsMovement({
    required String originalReservationId,
    String? createdReservationId,
    required bool originalReservationUpdated,
    required bool newReservationCreated,
    required bool couponsUpdated,
    required bool billsUpdated,
    required bool billTimesUpdated,
    String? billId,
    String? billMinId,
    Map<String, dynamic>? originalBillData,
    Map<String, dynamic>? originalBillTimeData,
  }) async {
    print('\n=== 타석 이동 롤백 시작 ===');
    
    try {
      // 역순으로 롤백 처리
      
      // 1. 쿠폰 롤백
      if (couponsUpdated && createdReservationId != null) {
        print('쿠폰 롤백 처리...');
        try {
          await TsTsMoveService.updateDiscountCoupons(createdReservationId, originalReservationId);
          print('✅ 쿠폰 롤백 완료');
        } catch (e) {
          print('❌ 쿠폰 롤백 실패: $e');
        }
      }
      
      // 2. 새 예약 삭제
      if (newReservationCreated && createdReservationId != null) {
        print('새 예약 삭제 처리...');
        try {
          await ApiService.updateTsData(
            {'ts_status': '예약취소'},
            [
              {'field': 'reservation_id', 'operator': '=', 'value': createdReservationId},
            ],
          );
          print('✅ 새 예약 삭제 완료');
        } catch (e) {
          print('❌ 새 예약 삭제 실패: $e');
        }
      }
      
      // 3. bills 롤백
      if (billsUpdated && billId != null && originalBillData != null) {
        print('bills 롤백 처리...');
        try {
          await ApiService.updateData(
            table: 'v2_bills',
            data: {
              'bill_netamt': originalBillData['bill_netamt'],
              'bill_balance_after': originalBillData['bill_balance_after'],
              'bill_status': originalBillData['bill_status'] ?? '결제완료',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [
              {'field': 'bill_id', 'operator': '=', 'value': billId},
            ],
          );
          
          // 연쇄 잔액도 원복
          if (originalBillData['contract_history_id'] != null) {
            await _recalculateSubsequentBills(
              originalBillData['contract_history_id'],
              billId,
              originalBillData['bill_balance_after']
            );
          }
          
          print('✅ bills 롤백 완료');
        } catch (e) {
          print('❌ bills 롤백 실패: $e');
        }
      }
      
      // 4. bill_times 롤백
      if (billTimesUpdated && billMinId != null && originalBillTimeData != null) {
        print('bill_times 롤백 처리...');
        try {
          await ApiService.updateData(
            table: 'v2_bill_times',
            data: {
              'bill_min': originalBillTimeData['bill_min'],
              'bill_balance_min_after': originalBillTimeData['bill_balance_min_after'],
              'bill_status': originalBillTimeData['bill_status'] ?? '결제완료',
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [
              {'field': 'bill_min_id', 'operator': '=', 'value': billMinId},
            ],
          );
          
          // 연쇄 시간잔액도 원복
          if (originalBillTimeData['contract_history_id'] != null) {
            await _recalculateSubsequentBillTimes(
              originalBillTimeData['contract_history_id'],
              billMinId,
              originalBillTimeData['bill_balance_min_after']
            );
          }
          
          print('✅ bill_times 롤백 완료');
        } catch (e) {
          print('❌ bill_times 롤백 실패: $e');
        }
      }
      
      // 5. 기존 예약 복구
      if (originalReservationUpdated) {
        print('기존 예약 복구 처리...');
        try {
          await ApiService.updateTsData(
            {'ts_status': '결제완료'},
            [
              {'field': 'reservation_id', 'operator': '=', 'value': originalReservationId},
            ],
          );
          print('✅ 기존 예약 복구 완료');
        } catch (e) {
          print('❌ 기존 예약 복구 실패: $e');
        }
      }
      
      print('=== 타석 이동 롤백 완료 ===\n');
    } catch (e) {
      print('❌ 롤백 처리 중 오류: $e');
    }
  }

  /// 성공 다이얼로그
  static void _showSuccessDialog(
    BuildContext context,
    TsReservation reservation,
    int newTsId,
    String currentTimeForDisplay,
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
                '${reservation.tsId}번 → ${newTsId}번 타석으로 이동되었습니다',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '이동 시간: $currentTimeForDisplay',
                textAlign: TextAlign.center,
                style: AppTextStyles.formLabel.copyWith(color: Color(0xFF64748B),
                ),
              ),
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

  /// 과거 예약 안내
  static void _showPastReservationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('타석 이동 불가'),
          content: Text('종료된 예약은 타석 이동이 불가능합니다.'),
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

  /// 취소된 예약 안내
  static void _showCancelledReservationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('타석 이동 불가'),
          content: Text('취소된 예약은 타석 이동이 불가능합니다.'),
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

  /// 이동 가능한 타석이 없을 때 안내
  static void _showNoAvailableStationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('타석 이동 불가'),
          content: Text('현재 이동 가능한 타석이 없습니다.'),
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
  
  /// 새 예약에 대한 bill 레코드 생성
  static Future<int?> _createNewBillRecord(
    TsReservation reservation,
    String newReservationId,
    bool isFutureReservation,
    double originalRatio,
    double movedRatio,
  ) async {
    try {
      print('\n=== 새 예약 bill 레코드 생성 ===');
      
      // 기존 bill 레코드 조회
      final existingBills = await ApiService.getBillsData(
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': reservation.billId},
        ],
      );
      
      if (existingBills.isEmpty) {
        print('기존 bill 레코드를 찾을 수 없습니다');
        return null;
      }
      
      final existingBill = existingBills[0];
      
      print('\n📊 [기존 bill 레코드 조회]:');
      print('  bill_id: ${existingBill['bill_id']}');
      print('  bill_totalamt: ${existingBill['bill_totalamt']}');
      print('  bill_deduction: ${existingBill['bill_deduction']}');
      print('  bill_netamt: ${existingBill['bill_netamt']}');
      print('  bill_balance_before: ${existingBill['bill_balance_before']}');
      print('  bill_balance_after: ${existingBill['bill_balance_after']}');
      
      // bill_id는 AUTO INCREMENT PK이므로 데이터베이스에서 자동 생성
      
      Map<String, dynamic> newBillData;
      
      if (isFutureReservation) {
        // 미래 예약: 100% 이전 (bill_id 제외 - AUTO INCREMENT)
        final originalTotalAmt = (existingBill['bill_totalamt'] ?? 0) as int;  // 실제 차감 금액
        final originalBalanceBefore = (existingBill['bill_balance_before'] ?? 0) as int;
        final newBalanceAfter = originalBalanceBefore + originalTotalAmt;
        
        newBillData = {
          // 'bill_id' 제외 - AUTO INCREMENT PK
          'member_id': existingBill['member_id'],
          'bill_date': existingBill['bill_date'],
          'bill_type': existingBill['bill_type'],
          'bill_text': '${reservation.tsId}번 → ${newReservationId.split('_')[1]}번 타석 이동',
          'bill_totalamt': existingBill['bill_totalamt'],        // 100% 이전
          'bill_deduction': existingBill['bill_deduction'],      // 100% 이전
          'bill_netamt': existingBill['bill_totalamt'],          // 실제 차감 금액 (totalamt와 동일)
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_balance_before': originalBalanceBefore,          // 이전 잔액
          'bill_balance_after': newBalanceAfter,                 // 이전 잔액 + netamt
          'reservation_id': newReservationId,
          'bill_status': '결제완료',
          'contract_history_id': existingBill['contract_history_id'],
          'locker_bill_id': existingBill['locker_bill_id'],
          'routine_id': existingBill['routine_id'],
          'contract_credit_expiry_date': existingBill['contract_credit_expiry_date'],
        };
      } else {
        // 진행 중 예약: 남은 비율만 이전 (bill_id 제외 - AUTO INCREMENT)
        final originalBillTotalAmt = existingBill['bill_totalamt'] ?? 0;
        final originalBillDeduction = existingBill['bill_deduction'] ?? 0;
        final originalBillNetAmt = existingBill['bill_netamt'] ?? 0;
        
        newBillData = {
          // 'bill_id' 제외 - AUTO INCREMENT PK
          'member_id': existingBill['member_id'],
          'bill_date': existingBill['bill_date'],
          'bill_type': existingBill['bill_type'],
          'bill_text': '${reservation.tsId}번 → ${newReservationId.split('_')[1]}번 타석 이동 (진행중)',
          'bill_totalamt': originalBillTotalAmt - (originalBillTotalAmt * originalRatio).round(),   // 나머지
          'bill_deduction': originalBillDeduction - (originalBillDeduction * originalRatio).round(), // 나머지
          'bill_netamt': originalBillNetAmt - (originalBillNetAmt * originalRatio).round(),         // 나머지
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_balance_before': existingBill['bill_balance_before'],
          'bill_balance_after': existingBill['bill_balance_after'],
          'reservation_id': newReservationId,
          'bill_status': '결제완료',
          'contract_history_id': existingBill['contract_history_id'],
          'locker_bill_id': existingBill['locker_bill_id'],
          'routine_id': existingBill['routine_id'],
          'contract_credit_expiry_date': existingBill['contract_credit_expiry_date'],
        };
      }
      
      print('\n📊 [v2_bills] 새 레코드 INSERT 쿼리:');
      print('  table: v2_bills');
      print('  data: $newBillData');
      
      // 새 bill 레코드 생성
      final result = await ApiService.addBillsData(newBillData);
      
      // 생성된 bill_id 추출 (String을 int로 변환)
      final rawBillId = result['data']?['bill_id'] ?? result['insertId'];
      final newBillId = rawBillId is String ? int.tryParse(rawBillId) : rawBillId;
      
      if (newBillId != null) {
        // 새 예약의 bill_id 업데이트
        print('\n📊 [v2_priced_TS] bill_id 연결:');
        print('  새 예약 ID: $newReservationId');
        print('  새 bill_id: $newBillId');
        
        print('\n📊 [v2_priced_TS] bill_id UPDATE 쿼리:');
        print('  table: v2_priced_TS');
        print('  where: reservation_id = $newReservationId');
        print('  data: bill_id = $newBillId');
        
        await ApiService.updateTsData(
          {'bill_id': newBillId},
          [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          ],
        );
        
        print('✅ v2_priced_TS bill_id 업데이트 완료');
        
        print('✅ 새 bill 레코드 생성 완료: $newBillId');
        return newBillId;
      } else {
        print('❌ 새 bill_id를 가져올 수 없습니다');
        throw Exception('새 bill_id를 가져올 수 없습니다');
      }
      
    } catch (e) {
      print('새 bill 레코드 생성 오류: $e');
      throw e;
    }
    return null;
  }
  
  /// 원본 데이터로부터 새 예약에 대한 bill 레코드 생성
  static Future<int?> _createNewBillRecordFromOriginal(
    Map<String, dynamic> originalBill,
    String newReservationId,
    bool isFutureReservation,
    double originalRatio,
    double movedRatio, {
    int? originalTsId,
  }) async {
    try {
      print('\n=== 원본 데이터로 새 예약 bill 레코드 생성 ===');
      
      print('\n📊 [원본 bill 데이터]:');
      print('  bill_totalamt: ${originalBill['bill_totalamt']}');
      print('  bill_deduction: ${originalBill['bill_deduction']}');
      print('  bill_netamt: ${originalBill['bill_netamt']}');
      print('  bill_balance_before: ${originalBill['bill_balance_before']}');
      print('  bill_balance_after: ${originalBill['bill_balance_after']}');
      
      Map<String, dynamic> newBillData;
      
      if (isFutureReservation) {
        // 미래 예약: 100% 이전 (bill_id 제외 - AUTO INCREMENT)
        final originalTotalAmt = (originalBill['bill_totalamt'] ?? 0) as int;  // 실제 차감 금액
        
        // 현재 시점의 최신 balance 조회 (재계산 후)
        final contractHistoryId = originalBill['contract_history_id'];
        final latestBills = await ApiService.getBillsData(
          where: [
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
          limit: 1,
        );
        
        final currentBalanceBefore = latestBills.isNotEmpty ? 
          ((latestBills[0]['bill_balance_after'] ?? 0) as int) : 
          ((originalBill['bill_balance_before'] ?? 0) as int);
        final newBalanceAfter = currentBalanceBefore + originalTotalAmt;
        
        newBillData = {
          // 'bill_id' 제외 - AUTO INCREMENT PK
          'member_id': originalBill['member_id'],
          'bill_date': originalBill['bill_date'],
          'bill_type': originalBill['bill_type'],
          'bill_text': '${originalTsId ?? "?"}번 → ${newReservationId.split('_')[1]}번 타석 이동',
          'bill_totalamt': originalBill['bill_totalamt'],        // 100% 이전
          'bill_deduction': originalBill['bill_deduction'],      // 100% 이전
          'bill_netamt': originalBill['bill_totalamt'],          // 실제 차감 금액 (totalamt와 동일)
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_balance_before': currentBalanceBefore,           // 재계산 후 최신 잔액
          'bill_balance_after': newBalanceAfter,                 // 최신 잔액 + netamt
          'reservation_id': newReservationId,
          'bill_status': '결제완료',
          'contract_history_id': originalBill['contract_history_id'],
          'locker_bill_id': originalBill['locker_bill_id'],
          'routine_id': originalBill['routine_id'],
          'contract_credit_expiry_date': originalBill['contract_credit_expiry_date'],
        };
      } else {
        // 진행 중 예약: 이미 비율 계산된 값 사용 (originalBillForNewRecord에 이미 계산되어 있음)
        final movedTotalAmt = originalBill['bill_totalamt'] ?? 0;
        final movedDeduction = originalBill['bill_deduction'] ?? 0;
        final movedNetAmt = originalBill['bill_netamt'] ?? 0;
        
        // 현재 시점의 최신 balance 조회
        final contractHistoryId = originalBill['contract_history_id'];
        final latestBills = await ApiService.getBillsData(
          where: [
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
          limit: 1,
        );
        
        final currentBalanceBefore = latestBills.isNotEmpty ? 
          ((latestBills[0]['bill_balance_after'] ?? 0) as int) : 
          ((originalBill['bill_balance_before'] ?? 0) as int);
        final newBalanceAfter = currentBalanceBefore + movedNetAmt;
        
        newBillData = {
          // 'bill_id' 제외 - AUTO INCREMENT PK
          'member_id': originalBill['member_id'],
          'bill_date': originalBill['bill_date'],
          'bill_type': originalBill['bill_type'],
          'bill_text': '${originalTsId ?? "?"}번 → ${newReservationId.split('_')[1]}번 타석 이동 (진행중)',
          'bill_totalamt': movedTotalAmt,
          'bill_deduction': movedDeduction,
          'bill_netamt': movedNetAmt,
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_balance_before': currentBalanceBefore,           // 최신 잔액 사용
          'bill_balance_after': newBalanceAfter,                 // 최신 잔액 + netamt
          'reservation_id': newReservationId,
          'bill_status': '결제완료',
          'contract_history_id': originalBill['contract_history_id'],
          'locker_bill_id': originalBill['locker_bill_id'],
          'routine_id': originalBill['routine_id'],
          'contract_credit_expiry_date': originalBill['contract_credit_expiry_date'],
        };
      }
      
      print('\n📊 [v2_bills] 새 레코드 INSERT 쿼리:');
      print('  table: v2_bills');
      print('  data: $newBillData');
      
      // 새 bill 레코드 생성
      final result = await ApiService.addBillsData(newBillData);
      
      // 생성된 bill_id 추출 (String을 int로 변환)
      final rawBillId = result['data']?['bill_id'] ?? result['insertId'];
      final newBillId = rawBillId is String ? int.tryParse(rawBillId) : rawBillId;
      
      if (newBillId != null) {
        // 새 예약의 bill_id 업데이트
        print('\n📊 [v2_priced_TS] bill_id 연결:');
        print('  새 예약 ID: $newReservationId');
        print('  새 bill_id: $newBillId');
        
        print('\n📊 [v2_priced_TS] bill_id UPDATE 쿼리:');
        print('  table: v2_priced_TS');
        print('  where: reservation_id = $newReservationId');
        print('  data: bill_id = $newBillId');
        
        await ApiService.updateTsData(
          {'bill_id': newBillId},
          [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          ],
        );
        
        print('✅ v2_priced_TS bill_id 업데이트 완료');
        
        print('✅ 새 bill 레코드 생성 완료: $newBillId');
        return newBillId;
      } else {
        print('❌ 새 bill_id를 가져올 수 없습니다');
        throw Exception('새 bill_id를 가져올 수 없습니다');
      }
      
    } catch (e) {
      print('새 bill 레코드 생성 오류: $e');
      throw e;
    }
    return null;
  }
  
  /// 원본 데이터로부터 새 예약에 대한 bill_times 레코드 생성
  static Future<void> _createNewBillTimesRecordFromOriginal(
    Map<String, dynamic> originalBillTime,
    String newReservationId,
    bool isFutureReservation,
    double originalRatio,
    double movedRatio, {
    int? originalTsId,
  }) async {
    try {
      print('\n=== 원본 데이터로 새 예약 bill_times 레코드 생성 ===');
      
      print('\n📊 [원본 bill_times 데이터]:');
      print('  bill_total_min: ${originalBillTime['bill_total_min']}');
      print('  bill_discount_min: ${originalBillTime['bill_discount_min']}');
      print('  bill_min: ${originalBillTime['bill_min']}');
      print('  bill_balance_min_before: ${originalBillTime['bill_balance_min_before']}');
      print('  bill_balance_min_after: ${originalBillTime['bill_balance_min_after']}');
      
      Map<String, dynamic> newBillTimeData;
      
      if (isFutureReservation) {
        // 미래 예약: 100% 이전 (bill_min_id 제외 - AUTO INCREMENT)
        final originalMin = (originalBillTime['bill_total_min'] ?? 0) as int;  // 실제 차감 시간 (total_min 사용)
        
        // 현재 시점의 최신 balance 조회 (재계산 후)
        final contractHistoryId = originalBillTime['contract_history_id'];
        final latestBillTimes = await ApiService.getBillTimesData(
          where: [
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          ],
          orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
          limit: 1,
        );
        
        final currentBalanceBefore = latestBillTimes.isNotEmpty ? 
          ((latestBillTimes[0]['bill_balance_min_after'] ?? 0) as int) : 
          ((originalBillTime['bill_balance_min_before'] ?? 0) as int);
        final newBalanceAfter = currentBalanceBefore - originalMin;
        
        newBillTimeData = {
          // 'bill_min_id' 제외 - AUTO INCREMENT PK
          'member_id': originalBillTime['member_id'],
          'bill_date': originalBillTime['bill_date'],
          'bill_type': originalBillTime['bill_type'],
          'bill_text': '${originalTsId ?? "?"}번 → ${newReservationId.split('_')[1]}번 타석 이동',
          'bill_total_min': originalBillTime['bill_total_min'],          // 100% 이전
          'bill_discount_min': originalBillTime['bill_discount_min'],    // 100% 이전
          'bill_min': originalBillTime['bill_total_min'],                // 실제 차감 시간 (total_min과 동일)
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_balance_min_before': currentBalanceBefore,               // 재계산 후 최신 잔액
          'bill_balance_min_after': newBalanceAfter,                     // 최신 잔액 + min
          'reservation_id': newReservationId,
          'bill_status': '결제완료',
          'contract_history_id': originalBillTime['contract_history_id'],
          'contract_credit_expiry_date': originalBillTime['contract_credit_expiry_date'],
        };
      } else {
        // 진행 중 예약: 남은 비율만 이전 (bill_min_id 제외 - AUTO INCREMENT)
        final originalTotalMin = originalBillTime['bill_total_min'] ?? 0;
        final originalDiscountMin = originalBillTime['bill_discount_min'] ?? 0;
        final originalMin = originalBillTime['bill_min'] ?? 0;
        
        // 비율에 따른 분배
        final movedTotalMin = (originalTotalMin * movedRatio).round();
        final movedDiscountMin = (originalDiscountMin * movedRatio).round();
        final movedMin = (originalMin * movedRatio).round();
        
        final originalBalanceBefore = (originalBillTime['bill_balance_min_before'] ?? 0) as int;
        final newBalanceAfter = originalBalanceBefore - movedMin;
        
        newBillTimeData = {
          // 'bill_min_id' 제외 - AUTO INCREMENT PK
          'member_id': originalBillTime['member_id'],
          'bill_date': originalBillTime['bill_date'],
          'bill_type': originalBillTime['bill_type'],
          'bill_text': '${originalTsId ?? "?"}번 → ${newReservationId.split('_')[1]}번 타석 이동',
          'bill_total_min': movedTotalMin,
          'bill_discount_min': movedDiscountMin,
          'bill_min': movedMin,
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_balance_min_before': originalBalanceBefore,
          'bill_balance_min_after': newBalanceAfter,
          'reservation_id': newReservationId,
          'bill_status': '결제완료',
          'contract_history_id': originalBillTime['contract_history_id'],
          'contract_credit_expiry_date': originalBillTime['contract_credit_expiry_date'],
        };
      }
      
      print('\n📊 [v2_bill_times] 새 레코드 INSERT 쿼리:');
      print('  table: v2_bill_times');
      print('  data: $newBillTimeData');
      
      // 새 bill_times 레코드 생성
      final result = await ApiService.addBillTimesData(newBillTimeData);
      
      // 생성된 bill_min_id 추출
      final newBillMinId = result['data']?['bill_min_id'] ?? result['insertId'];
      
      if (newBillMinId != null) {
        // 새 예약의 bill_min_id 업데이트
        print('\n📊 [v2_priced_TS] bill_min_id 연결:');
        print('  새 예약 ID: $newReservationId');
        print('  새 bill_min_id: $newBillMinId');
        
        print('\n📊 [v2_priced_TS] bill_min_id UPDATE 쿼리:');
        print('  table: v2_priced_TS');
        print('  where: reservation_id = $newReservationId');
        print('  data: bill_min_id = $newBillMinId');
        
        await ApiService.updateTsData(
          {'bill_min_id': newBillMinId},
          [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          ],
        );
        
        print('✅ v2_priced_TS bill_min_id 업데이트 완료');
        print('✅ 새 bill_times 레코드 생성 완료: $newBillMinId');
      } else {
        print('❌ 새 bill_min_id를 가져올 수 없습니다');
        throw Exception('새 bill_min_id를 가져올 수 없습니다');
      }
      
    } catch (e) {
      print('새 bill_times 레코드 생성 오류: $e');
      throw e;
    }
  }
  
  /// 새 예약에 대한 bill_times 레코드 생성
  static Future<void> _createNewBillTimesRecord(
    TsReservation reservation,
    String newReservationId,
    bool isFutureReservation,
    double originalRatio,
    double movedRatio,
  ) async {
    try {
      print('\n=== 새 예약 bill_times 레코드 생성 ===');
      
      // 기존 bill_time 레코드 조회
      final existingBillTimes = await ApiService.getBillTimesData(
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': reservation.billMinId},
        ],
      );
      
      if (existingBillTimes.isEmpty) {
        print('기존 bill_times 레코드를 찾을 수 없습니다');
        return;
      }
      
      final existingBillTime = existingBillTimes[0];
      
      // bill_min_id는 AUTO INCREMENT PK이므로 데이터베이스에서 자동 생성
      
      Map<String, dynamic> newBillTimeData;
      
      if (isFutureReservation) {
        // 미래 예약: 100% 이전 (bill_min_id 제외 - AUTO INCREMENT)
        newBillTimeData = {
          // 'bill_min_id' 제외 - AUTO INCREMENT PK
          'member_id': existingBillTime['member_id'],
          'bill_date': existingBillTime['bill_date'],
          'bill_text': '${reservation.tsId}번 → ${newReservationId.split('_')[1]}번 타석 이동',
          'bill_type': existingBillTime['bill_type'],
          'reservation_id': newReservationId,
          'bill_total_min': existingBillTime['bill_total_min'],        // 100% 이전
          'bill_discount_min': existingBillTime['bill_discount_min'],  // 100% 이전
          'bill_min': existingBillTime['bill_min'],                    // 100% 이전
          'bill_balance_min_before': existingBillTime['bill_balance_min_before'],
          'bill_balance_min_after': existingBillTime['bill_balance_min_after'],
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_status': '결제완료',
          'contract_history_id': existingBillTime['contract_history_id'],
          'routine_id': existingBillTime['routine_id'],
          'contract_TS_min_expiry_date': existingBillTime['contract_TS_min_expiry_date'],
        };
      } else {
        // 진행 중 예약: 남은 비율만 이전 (bill_min_id 제외 - AUTO INCREMENT)
        final originalBillTotalMin = existingBillTime['bill_total_min'] ?? 0;
        final originalBillDiscountMin = existingBillTime['bill_discount_min'] ?? 0;
        final originalBillMin = existingBillTime['bill_min'] ?? 0;
        
        newBillTimeData = {
          // 'bill_min_id' 제외 - AUTO INCREMENT PK
          'member_id': existingBillTime['member_id'],
          'bill_date': existingBillTime['bill_date'],
          'bill_text': '${reservation.tsId}번 → ${newReservationId.split('_')[1]}번 타석 이동 (진행중)',
          'bill_type': existingBillTime['bill_type'],
          'reservation_id': newReservationId,
          'bill_total_min': originalBillTotalMin - (originalBillTotalMin * originalRatio).round(),   // 나머지
          'bill_discount_min': originalBillDiscountMin - (originalBillDiscountMin * originalRatio).round(), // 나머지  
          'bill_min': originalBillMin - (originalBillMin * originalRatio).round(),                  // 나머지
          'bill_balance_min_before': existingBillTime['bill_balance_min_before'],
          'bill_balance_min_after': existingBillTime['bill_balance_min_after'],
          'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now()),
          'bill_status': '결제완료',
          'contract_history_id': existingBillTime['contract_history_id'],
          'routine_id': existingBillTime['routine_id'],
          'contract_TS_min_expiry_date': existingBillTime['contract_TS_min_expiry_date'],
        };
      }
      
      print('\n📊 [v2_bill_times] 새 레코드 INSERT 쿼리:');
      print('  table: v2_bill_times');
      print('  data: $newBillTimeData');
      
      // 새 bill_times 레코드 생성
      final result = await ApiService.addBillTimesData(newBillTimeData);
      
      // 생성된 bill_min_id 추출
      final newBillMinId = result['data']?['bill_min_id'] ?? result['insertId'];
      
      if (newBillMinId != null) {
        // 새 예약의 bill_min_id 업데이트
        print('\n📊 [v2_priced_TS] bill_min_id 연결:');
        print('  새 예약 ID: $newReservationId');
        print('  새 bill_min_id: $newBillMinId');
        
        await ApiService.updateTsData(
          {'bill_min_id': newBillMinId},
          [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          ],
        );
        
        print('✅ 새 bill_times 레코드 생성 완료: $newBillMinId');
      } else {
        print('❌ 새 bill_min_id를 가져올 수 없습니다');
        throw Exception('새 bill_min_id를 가져올 수 없습니다');
      }
      
    } catch (e) {
      print('새 bill_times 레코드 생성 오류: $e');
      throw e;
    }
  }
  
  /// v2_bills 연쇄 잔액 재계산
  static Future<void> _recalculateSubsequentBills(
    dynamic contractHistoryId,
    dynamic currentBillId,
    int newBalanceAfter,
  ) async {
    try {
      // 후속 레코드들 조회
      print('🔍 재계산 대상 조회: contract_history_id=$contractHistoryId, bill_id > $currentBillId');
      final subsequentBills = await ApiService.getDataList(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>', 'value': currentBillId},
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'ASC'}],
      );
      
      print('🔍 조회된 후속 레코드 bill_id: ${subsequentBills.map((b) => b['bill_id']).toList()}');
      
      if (subsequentBills.isNotEmpty) {
        print('후속 레코드 ${subsequentBills.length}개 발견 - 연쇄 잔액 재계산 시작');
        
        int previousBalanceAfter = newBalanceAfter;
        
        for (var bill in subsequentBills) {
          final netAmt = (bill['bill_netamt'] ?? 0) as int;
          final newBeforeBalance = previousBalanceAfter;
          final newAfterBalance = newBeforeBalance + netAmt;
          
          print('bill_id ${bill['bill_id']}: before ${bill['bill_balance_before']} → ${newBeforeBalance}, after ${bill['bill_balance_after']} → ${newAfterBalance}');
          
          // DB 업데이트
          await ApiService.updateData(
            table: 'v2_bills',
            data: {
              'bill_balance_before': newBeforeBalance,
              'bill_balance_after': newAfterBalance,
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [{'field': 'bill_id', 'operator': '=', 'value': bill['bill_id']}],
          );
          
          previousBalanceAfter = newAfterBalance;
        }
        
        print('✅ 연쇄 잔액 재계산 완료');
      }
    } catch (e) {
      print('연쇄 잔액 재계산 오류: $e');
    }
  }
  
  /// v2_bill_times 연쇄 시간잔액 재계산
  static Future<void> _recalculateSubsequentBillTimes(
    dynamic contractHistoryId,
    dynamic currentBillMinId,
    int newBalanceAfter,
  ) async {
    try {
      // 빈 슬롯 체크
      if (newBalanceAfter == null || newBalanceAfter == 0) {
        print('⚠️ 빈 슬롯 또는 잔액이 0인 레코드 - 연쇄 재계산 불필요');
        return;
      }
      
      // 후속 레코드들 조회
      print('🔍 재계산 대상 조회: contract_history_id=$contractHistoryId, bill_min_id > $currentBillMinId');
      final subsequentBillTimes = await ApiService.getDataList(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '>', 'value': currentBillMinId},
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'ASC'}],
      );
      
      print('🔍 조회된 후속 레코드 bill_min_id: ${subsequentBillTimes.map((bt) => bt['bill_min_id']).toList()}');
      
      if (subsequentBillTimes.isNotEmpty) {
        print('후속 레코드 ${subsequentBillTimes.length}개 발견 - 연쇄 시간잔액 재계산 시작');
        
        int previousBalanceAfter = newBalanceAfter;
        
        for (var billTime in subsequentBillTimes) {
          final billMin = (billTime['bill_min'] ?? 0) as int;
          final newBeforeBalance = previousBalanceAfter;
          final newAfterBalance = newBeforeBalance - billMin;  // 시간은 차감!
          
          print('bill_min_id ${billTime['bill_min_id']}: before ${billTime['bill_balance_min_before']} → ${newBeforeBalance}, after ${billTime['bill_balance_min_after']} → ${newAfterBalance}');
          
          // DB 업데이트
          await ApiService.updateData(
            table: 'v2_bill_times',
            data: {
              'bill_balance_min_before': newBeforeBalance,
              'bill_balance_min_after': newAfterBalance,
              'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            },
            where: [{'field': 'bill_min_id', 'operator': '=', 'value': billTime['bill_min_id']}],
          );
          
          previousBalanceAfter = newAfterBalance;
        }
        
        print('✅ 연쇄 시간잔액 재계산 완료');
      }
    } catch (e) {
      print('연쇄 시간잔액 재계산 오류: $e');
    }
  }
}