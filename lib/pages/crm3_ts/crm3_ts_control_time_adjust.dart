import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/ts_reservation.dart';
import '/services/api_service.dart';
import '../../constants/font_sizes.dart';
import 'crm3_ts_control_reservation_cancel.dart';

/// 예약 상태 열거형
enum ReservationStatus {
  past,        // 과거 예약 (종료됨)
  inProgress,  // 현재 이용 중
  future,      // 미래 예약
}

/// 시간 조정 관련 기능을 담당하는 서비스 클래스
class TsTimeAdjustService {

  /// 예약 상태 판별
  static ReservationStatus getReservationStatus(TsReservation reservation) {
    final now = DateTime.now();
    final reservationDate = DateTime.parse(reservation.tsDate ?? now.toString().split(' ')[0]);
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(reservationDate.year, reservationDate.month, reservationDate.day);
    
    // 선택된 날짜가 과거인 경우
    if (selectedDate.isBefore(today)) {
      return ReservationStatus.past;
    }
    
    // 선택된 날짜가 미래인 경우
    if (selectedDate.isAfter(today)) {
      return ReservationStatus.future;
    }
    
    // 선택된 날짜가 오늘인 경우, 시간으로 판별
    final startTimeParts = (reservation.tsStart ?? '').split(':');
    final endTimeParts = (reservation.tsEnd ?? '').split(':');
    
    if (startTimeParts.length >= 2 && endTimeParts.length >= 2) {
      final startHour = int.tryParse(startTimeParts[0]) ?? 0;
      final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
      final endHour = int.tryParse(endTimeParts[0]) ?? 0;
      final endMinute = int.tryParse(endTimeParts[1]) ?? 0;
      
      final startDateTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
      final endDateTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
      
      // 예약 종료 시간이 현재 시간보다 이전인 경우 (과거)
      if (endDateTime.isBefore(now)) {
        return ReservationStatus.past;
      }
      
      // 예약 시작 시간이 현재 시간보다 이후인 경우 (미래)
      if (startDateTime.isAfter(now)) {
        return ReservationStatus.future;
      }
      
      // 현재 시간이 예약 시간 범위 내에 있는 경우 (진행 중)
      return ReservationStatus.inProgress;
    }
    
    // 시간 파싱에 실패한 경우 과거로 간주
    return ReservationStatus.past;
  }

  /// 시간 파싱 헬퍼
  static DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
    return now;
  }

  /// 시간 조정 버튼 활성화 여부 체크
  static bool isTimeAdjustmentEnabled(TsReservation reservation) {
    // 취소된 예약은 시간 조정 불가
    if (reservation.tsStatus == '예약취소') {
      return false;
    }
    
    final status = getReservationStatus(reservation);
    
    // 진행 중인 예약과 미래 예약에서 시간 조정 다이얼로그 접근 가능
    return status == ReservationStatus.inProgress || status == ReservationStatus.future;
  }

  /// 시간 증가 가능 여부 체크
  static bool canIncreaseTime(TsReservation reservation, int minutes) {
    if (!isTimeAdjustmentEnabled(reservation)) return false;
    
    final currentEndTime = _parseTime(reservation.tsEnd ?? '');
    
    // 영업 종료 시간 (자정)을 고려한 최대 시간
    final maxEndTime = DateTime(currentEndTime.year, currentEndTime.month, currentEndTime.day, 24, 0);
    
    final newEndTime = currentEndTime.add(Duration(minutes: minutes));
    return newEndTime.isBefore(maxEndTime) || newEndTime.isAtSameMomentAs(maxEndTime);
  }

  /// 시간 감소 가능 여부 체크
  static bool canDecreaseTime(TsReservation reservation, int minutes) {
    if (!isTimeAdjustmentEnabled(reservation)) return false;
    
    final now = DateTime.now();
    final currentEndTime = _parseTime(reservation.tsEnd ?? '');
    
    // 감소된 종료시간이 현재시간보다 이후여야 함
    final newEndTime = currentEndTime.subtract(Duration(minutes: minutes));
    return newEndTime.isAfter(now);
  }

  /// 다음 예약 정보 조회
  static Future<Map<String, dynamic>?> getNextReservationInfo(TsReservation reservation) async {
    try {
      final currentDate = reservation.tsDate;
      final currentEndTime = reservation.tsEnd;
      final tsId = reservation.tsId;

      // 같은 날짜, 같은 타석에서 현재 예약 종료 시간 이후의 예약 조회
      final nextReservations = await ApiService.getTsData(
        fields: ['ts_start', 'ts_end', 'member_name'],
        where: [
          {'field': 'ts_date', 'operator': '=', 'value': currentDate},
          {'field': 'ts_id', 'operator': '=', 'value': tsId},
          {'field': 'ts_start', 'operator': '>', 'value': currentEndTime},
          {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        ],
        orderBy: [{'field': 'ts_start', 'direction': 'ASC'}],
        limit: 1,
      );

      if (nextReservations.isNotEmpty) {
        return nextReservations[0];
      }
      return null;
    } catch (e) {
      print('다음 예약 조회 오류: $e');
      return null;
    }
  }

  /// 시간 조정 처리
  static Future<bool> handleTimeAdjustment({
    required TsReservation reservation,
    required int minutes,
    required bool isIncrease,
  }) async {
    try {
      // 새로운 종료 시간 계산
      String newEndTime;
      
      if (minutes == 0) {
        // 타석 반납의 경우 현재 시간으로 설정
        final now = DateTime.now();
        newEndTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
      } else {
        // 기존 종료 시간에서 조정
        final currentEndTime = _parseTime(reservation.tsEnd ?? '');
        final adjustment = Duration(minutes: isIncrease ? minutes : -minutes);
        final newEndDateTime = currentEndTime.add(adjustment);
        newEndTime = '${newEndDateTime.hour.toString().padLeft(2, '0')}:${newEndDateTime.minute.toString().padLeft(2, '0')}:00';
      }
      
      // API 호출하여 ts_end 업데이트
      final result = await ApiService.updateTsData(
        {'ts_end': newEndTime},
        [
          {
            'field': 'reservation_id',
            'operator': '=',
            'value': reservation.reservationId!,
          },
        ],
      );
      
      return result['success'] == true;
    } catch (e) {
      print('시간 조정 처리 오류: $e');
      return false;
    }
  }
}

/// 시간 조정 다이얼로그
class TsTimeAdjustDialog {
  /// 시간 조정 다이얼로그 표시
  static Future<void> show(BuildContext context, TsReservation reservation, VoidCallback? onDataChanged) async {
    // 취소된 예약 체크
    if (reservation.tsStatus == '예약취소') {
      _showCancelledReservationDialog(context);
      return;
    }

    // 다음 예약 정보 조회
    final nextReservation = await TsTimeAdjustService.getNextReservationInfo(reservation);

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
              width: 450,
              constraints: BoxConstraints(maxHeight: 600),
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
                        '시간 조정',
                        style: AppTextStyles.titleH3.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  
                  // 현재 시간 정보
                  Text(
                    '현재 예약 시간',
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
                      '${reservation.tsStart} ~ ${reservation.tsEnd}',
                      style: AppTextStyles.titleH4.copyWith(color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // 예약 상태별 버튼 표시
                  _buildStatusBasedActions(context, reservation, onDataChanged),
                  
                  // 다음 예약 정보 (있는 경우)
                  if (nextReservation != null) ...[
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFF59E0B), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '다음 예약',
                            style: AppTextStyles.cardBody.copyWith(color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${nextReservation['ts_start']} ~ ${nextReservation['ts_end']} (${nextReservation['member_name']})',
                            style: AppTextStyles.formLabel.copyWith(color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }
  }

  /// 예약 상태별 액션 버튼 빌드
  static Widget _buildStatusBasedActions(BuildContext context, TsReservation reservation, VoidCallback? onDataChanged) {
    final status = TsTimeAdjustService.getReservationStatus(reservation);
    
    switch (status) {
      case ReservationStatus.past:
        // 과거 예약 - 모든 버튼 비활성화
        return _buildDisabledSection('종료된 예약');
        
      case ReservationStatus.future:
        // 미래 예약 - 예약 취소 버튼만 표시
        return _buildCancelSection(context, reservation, onDataChanged);
        
      case ReservationStatus.inProgress:
        // 진행 중 예약 - 시간 조정 및 반납 버튼 표시
        return _buildTimeAdjustSection(context, reservation, onDataChanged);
    }
  }

  /// 비활성화 섹션 (과거 예약)
  static Widget _buildDisabledSection(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// 예약 취소 섹션 (미래 예약)
  static Widget _buildCancelSection(BuildContext context, TsReservation reservation, VoidCallback? onDataChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '예약 관리',
          style: AppTextStyles.formLabel.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // 시간 조정 다이얼로그 닫기
              await TsReservationCancelDialog.show(context, reservation, onDataChanged);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '예약 취소',
              style: AppTextStyles.bodyText.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  /// 시간 조정 섹션 (진행 중 예약)
  static Widget _buildTimeAdjustSection(BuildContext context, TsReservation reservation, VoidCallback? onDataChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시간 증가',
          style: AppTextStyles.formLabel.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildTimeAdjustButton(context, reservation, onDataChanged, '+5분', 5, true),
            SizedBox(width: 8),
            _buildTimeAdjustButton(context, reservation, onDataChanged, '+10분', 10, true),
            SizedBox(width: 8),
            _buildTimeAdjustButton(context, reservation, onDataChanged, '+20분', 20, true),
            SizedBox(width: 8),
            _buildTimeAdjustButton(context, reservation, onDataChanged, '+30분', 30, true),
          ],
        ),
        SizedBox(height: 16),
        Text(
          '시간 감소',
          style: AppTextStyles.formLabel.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildTimeAdjustButton(context, reservation, onDataChanged, '-5분', 5, false),
            SizedBox(width: 8),
            _buildTimeAdjustButton(context, reservation, onDataChanged, '-10분', 10, false),
            SizedBox(width: 8),
            _buildTimeAdjustButton(context, reservation, onDataChanged, '-20분', 20, false),
            SizedBox(width: 8),
            _buildTimeAdjustButton(context, reservation, onDataChanged, '-30분', 30, false),
          ],
        ),
        SizedBox(height: 16),
        Text(
          '타석 반납',
          style: AppTextStyles.formLabel.copyWith(color: Color(0xFF374151), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _buildTimeAdjustButton(context, reservation, onDataChanged, '타석 반납', 0, false, isReturn: true),
        ),
      ],
    );
  }

  /// 시간 조정 버튼 빌드
  static Widget _buildTimeAdjustButton(
    BuildContext context,
    TsReservation reservation,
    VoidCallback? onDataChanged,
    String label,
    int minutes,
    bool isIncrease, {
    bool isReturn = false,
  }) {
    bool enabled = true;
    Color buttonColor = Color(0xFF10B981);

    if (isReturn) {
      // 반납 버튼은 항상 활성화 (빨간색)
      buttonColor = Color(0xFFEF4444);
    } else if (isIncrease) {
      enabled = TsTimeAdjustService.canIncreaseTime(reservation, minutes);
      buttonColor = enabled ? Color(0xFF10B981) : Color(0xFFF1F5F9);
    } else {
      enabled = TsTimeAdjustService.canDecreaseTime(reservation, minutes);
      buttonColor = enabled ? Color(0xFFF59E0B) : Color(0xFFF1F5F9);
    }

    final button = ElevatedButton(
      onPressed: enabled ? () async {
        if (isReturn) {
          await _handleTimeAdjustment(context, reservation, onDataChanged, 0, false);
        } else {
          await _handleTimeAdjustment(context, reservation, onDataChanged, minutes, isIncrease);
        }
      } : () => _showDisabledButtonMessage(context, minutes, isIncrease),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: enabled ? Colors.white : Color(0xFF94A3B8),
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyText.copyWith(color: enabled ? Colors.white : Color(0xFF94A3B8), fontWeight: FontWeight.w600),
      ),
    );
    
    // 반납 버튼은 Expanded를 사용하지 않음
    if (isReturn) {
      return button;
    }
    
    return Expanded(child: button);
  }

  /// 시간 조정 처리
  static Future<void> _handleTimeAdjustment(
    BuildContext context,
    TsReservation reservation,
    VoidCallback? onDataChanged,
    int minutes,
    bool isIncrease,
  ) async {
    final success = await TsTimeAdjustService.handleTimeAdjustment(
      reservation: reservation,
      minutes: minutes,
      isIncrease: isIncrease,
    );

    if (success) {
      Navigator.of(context).pop(); // 다이얼로그 닫기
      Navigator.of(context).pop(); // 상세 팝업도 닫기
      
      // 성공 메시지 팝업 표시
      _showSuccessDialog(context, reservation, minutes, isIncrease, onDataChanged);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간 조정 중 오류가 발생했습니다'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  /// 성공 다이얼로그
  static void _showSuccessDialog(
    BuildContext context,
    TsReservation reservation,
    int minutes,
    bool isIncrease,
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
                minutes == 0 ? '${reservation.tsId}번 타석이 반납되었습니다' : 
                '${reservation.tsId}번 타석 시간이 ${isIncrease ? "증가" : "감소"}되었습니다',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
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

  /// 비활성화된 버튼 메시지
  static void _showDisabledButtonMessage(BuildContext context, int minutes, bool isIncrease) {
    String message = isIncrease 
        ? '영업시간을 초과하여 시간을 증가할 수 없습니다'
        : '현재 시간보다 이전으로 시간을 감소할 수 없습니다';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
  }

  /// 오늘이 아닌 예약 안내
  static void _showNotTodayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('시간 조정 불가'),
          content: Text('당일 예약만 시간 조정이 가능합니다.'),
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
          title: Text('시간 조정 불가'),
          content: Text('취소된 예약은 시간 조정이 불가능합니다.'),
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