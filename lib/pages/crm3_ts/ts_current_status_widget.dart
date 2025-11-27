import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/ts_reservation.dart';
import '../../constants/font_sizes.dart';

class TsCurrentStatusWidget extends StatelessWidget {
  final DateTime selectedDate;
  final List<TsReservation> reservations;
  final List<int> bayNumbers;
  final Function(TsReservation) onReservationTap;
  final String? businessStart; // 영업시간 추가
  final String? businessEnd;   // 영업시간 추가

  const TsCurrentStatusWidget({
    super.key,
    required this.selectedDate,
    required this.reservations,
    required this.bayNumbers,
    required this.onReservationTap,
    this.businessStart,
    this.businessEnd,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
                   selectedDate.month == now.month &&
                   selectedDate.day == now.day;
    
    final businessStatus = _getBusinessStatus(now);

    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '타석 현황',
                    style: AppTextStyles.titleH2.copyWith(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(selectedDate)}${isToday ? ' • ${DateFormat('HH:mm').format(now)} 현재' : ''}',
                    style: AppTextStyles.formLabel.copyWith(
                      color: Color(0xFF64748B),
                    ),
                  ),
                  // 영업시간 상태 표시
                  if (isToday && businessStart != null && businessEnd != null) ...[
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: businessStatus['bgColor'],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: businessStatus['borderColor']),
                      ),
                      child: Text(
                        businessStatus['message'],
                        style: AppTextStyles.cardBody.copyWith(
                          color: businessStatus['textColor'],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: Color(0xFF64748B),
                  size: 24,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          
          // 상태 범례
          _buildStatusLegend(),
          SizedBox(height: 20),
          
          // 타석 타일 그리드
          Expanded(
            child: _buildTsGrid(isToday, now),
          ),
        ],
      ),
    );
  }

  // 상태 범례
  Widget _buildStatusLegend() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('사용 중', Color(0xFF10B981), Color(0xFF065F46)),
          _buildLegendItem('예약 대기', Color(0xFFF59E0B), Color(0xFF92400E)),
          _buildLegendItem('이용 완료', Color(0xFF6B7280), Color(0xFF374151)),
          _buildLegendItem('빈 타석', Color(0xFFF1F5F9), Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color bgColor, Color textColor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // 타석 그리드
  Widget _buildTsGrid(bool isToday, DateTime now) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 한 줄에 3개씩
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: bayNumbers.length,
      itemBuilder: (context, index) {
        final bayNumber = bayNumbers[index];
        return _buildTsTile(bayNumber, isToday, now);
      },
    );
  }

  // 개별 타석 타일
  Widget _buildTsTile(int bayNumber, bool isToday, DateTime now) {
    final currentReservation = _getCurrentReservation(bayNumber, isToday, now);
    final status = _getTsStatus(currentReservation, isToday, now);
    
    return GestureDetector(
      onTap: currentReservation != null 
        ? () => onReservationTap(currentReservation)
        : null,
      child: Container(
        decoration: BoxDecoration(
          color: status['bgColor'],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status['borderColor'],
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 타석 번호
              Text(
                '${bayNumber}번',
                style: AppTextStyles.titleH4.copyWith(
                  fontWeight: FontWeight.bold,
                  color: status['textColor'],
                ),
              ),
              SizedBox(height: 8),
              
              // 상태 표시
              Text(
                status['label'],
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: status['textColor'],
                ),
                textAlign: TextAlign.center,
              ),
              
              // 예약이 있는 경우 추가 정보
              if (currentReservation != null) ...[
                SizedBox(height: 8),
                Text(
                  currentReservation.displayMemberName,
                  style: AppTextStyles.overline.copyWith(
                    fontWeight: FontWeight.w500,
                    color: status['textColor'].withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  currentReservation.formattedTimeRange,
                  style: AppTextStyles.overline.copyWith(
                    color: status['textColor'].withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 현재 시간에 해당하는 예약 찾기
  TsReservation? _getCurrentReservation(int bayNumber, bool isToday, DateTime now) {
    if (!isToday) {
      // 오늘이 아니면 현재 시간 기준이 아닌 가장 최근 예약 반환
      final bayReservations = reservations.where((r) => r.tsId == bayNumber).toList();
      if (bayReservations.isEmpty) return null;
      
      // 시작 시간 기준으로 정렬해서 가장 최근 예약 반환
      bayReservations.sort((a, b) => (a.tsStart ?? '').compareTo(b.tsStart ?? ''));
      return bayReservations.last;
    }

    // 오늘인 경우 현재 시간에 해당하는 예약 찾기
    for (final reservation in reservations) {
      if (reservation.tsId != bayNumber) continue;
      
      final startTime = _parseTime(reservation.tsStart ?? '');
      final endTime = _parseTime(reservation.tsEnd ?? '');
      
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        return reservation; // 현재 진행 중인 예약
      }
    }
    
    // 현재 진행 중인 예약이 없으면 다음 예약 찾기
    TsReservation? nextReservation;
    Duration? shortestDuration;
    
    for (final reservation in reservations) {
      if (reservation.tsId != bayNumber) continue;
      
      final startTime = _parseTime(reservation.tsStart ?? '');
      if (startTime.isAfter(now)) {
        final duration = startTime.difference(now);
        if (shortestDuration == null || duration < shortestDuration) {
          shortestDuration = duration;
          nextReservation = reservation;
        }
      }
    }
    
    return nextReservation;
  }

  // 타석 상태 정보
  Map<String, dynamic> _getTsStatus(TsReservation? reservation, bool isToday, DateTime now) {
    if (reservation == null) {
      return {
        'label': '빈 타석',
        'bgColor': Color(0xFFF1F5F9),
        'borderColor': Color(0xFFE2E8F0),
        'textColor': Color(0xFF64748B),
      };
    }

    if (!isToday) {
      // 오늘이 아닌 경우
      return {
        'label': '예약됨',
        'bgColor': Color(0xFFDCFDF7),
        'borderColor': Color(0xFF10B981),
        'textColor': Color(0xFF065F46),
      };
    }

    final startTime = _parseTime(reservation.tsStart ?? '');
    final endTime = _parseTime(reservation.tsEnd ?? '');
    
    if (now.isAfter(endTime)) {
      // 이용 완료
      return {
        'label': '이용 완료',
        'bgColor': Color(0xFFF3F4F6),
        'borderColor': Color(0xFF6B7280),
        'textColor': Color(0xFF374151),
      };
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      // 사용 중
      return {
        'label': '사용 중',
        'bgColor': Color(0xFFDCFDF7),
        'borderColor': Color(0xFF10B981),
        'textColor': Color(0xFF065F46),
      };
    } else {
      // 예약 대기
      final remainingMinutes = startTime.difference(now).inMinutes;
      return {
        'label': '예약 대기\n(${remainingMinutes}분 후)',
        'bgColor': Color(0xFFFEF3C7),
        'borderColor': Color(0xFFF59E0B),
        'textColor': Color(0xFF92400E),
      };
    }
  }

  // 영업시간 상태 체크
  Map<String, dynamic> _getBusinessStatus(DateTime now) {
    if (businessStart == null || businessEnd == null) {
      return {
        'message': '영업시간 미설정',
        'bgColor': Color(0xFFF3F4F6),
        'borderColor': Color(0xFF9CA3AF),
        'textColor': Color(0xFF6B7280),
      };
    }

    final startHour = _parseBusinessHour(businessStart!);
    final endHour = _parseBusinessHour(businessEnd!);
    final currentHour = now.hour;
    final currentMinute = now.minute;
    final currentTimeInMinutes = currentHour * 60 + currentMinute;
    final startTimeInMinutes = startHour * 60;
    final endTimeInMinutes = endHour * 60;

    bool isWithinBusinessHours;
    if (startHour < endHour) {
      // 일반적인 경우 (예: 09:00 - 22:00)
      isWithinBusinessHours = currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes < endTimeInMinutes;
    } else {
      // 자정을 넘어가는 경우 (예: 22:00 - 02:00)
      isWithinBusinessHours = currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes < endTimeInMinutes;
    }

    if (isWithinBusinessHours) {
      return {
        'message': '영업 중 (${businessStart!.substring(0, 5)} ~ ${businessEnd!.substring(0, 5)})',
        'bgColor': Color(0xFFDCFDF7),
        'borderColor': Color(0xFF10B981),
        'textColor': Color(0xFF065F46),
      };
    } else {
      // 영업시간 전인지 후인지 판단
      bool isBeforeOpen;
      if (startHour < endHour) {
        isBeforeOpen = currentTimeInMinutes < startTimeInMinutes;
      } else {
        // 자정을 넘어가는 경우의 로직
        isBeforeOpen = currentTimeInMinutes < startTimeInMinutes && currentTimeInMinutes >= endTimeInMinutes;
      }

      return {
        'message': isBeforeOpen 
          ? '오픈 전 (${businessStart!.substring(0, 5)} 오픈)'
          : '영업종료 (${businessEnd!.substring(0, 5)} 종료)',
        'bgColor': Color(0xFFFEF3C7),
        'borderColor': Color(0xFFF59E0B),
        'textColor': Color(0xFF92400E),
      };
    }
  }

  // 영업시간 파싱
  int _parseBusinessHour(String timeStr) {
    final parts = timeStr.split(':');
    return int.tryParse(parts[0]) ?? 9;
  }

  // 시간 문자열을 DateTime으로 파싱 (오늘 날짜 기준)
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}