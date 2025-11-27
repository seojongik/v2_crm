import 'package:flutter/material.dart';

class TsReservation {
  final String? reservationId;
  final int? tsId;
  final String? tsDate;
  final String? tsStart;
  final String? tsEnd;
  final int? tsMin;
  final String? tsType;
  final String? tsPaymentMethod;
  final String? tsStatus;
  final int? memberId;
  final String? memberName;
  final String? memberPhone;
  final int? totalAmt;
  final int? termDiscount;
  final int? memberDiscount;
  final int? juniorDiscount;
  final int? overtimeDiscount;
  final int? revisitDiscount;
  final int? emergencyDiscount;
  final String? emergencyReason;
  final int? totalDiscount;
  final int? netAmt;
  final int? morning;
  final int? normal;
  final int? peak;
  final int? night;
  final String? timeStamp;
  final String? routineId;

  TsReservation({
    this.reservationId,
    this.tsId,
    this.tsDate,
    this.tsStart,
    this.tsEnd,
    this.tsMin,
    this.tsType,
    this.tsPaymentMethod,
    this.tsStatus,
    this.memberId,
    this.memberName,
    this.memberPhone,
    this.totalAmt,
    this.termDiscount,
    this.memberDiscount,
    this.juniorDiscount,
    this.overtimeDiscount,
    this.revisitDiscount,
    this.emergencyDiscount,
    this.emergencyReason,
    this.totalDiscount,
    this.netAmt,
    this.morning,
    this.normal,
    this.peak,
    this.night,
    this.timeStamp,
    this.routineId,
  });

  factory TsReservation.fromJson(Map<String, dynamic> json) {
    return TsReservation(
      reservationId: json['reservation_id']?.toString(),
      tsId: json['ts_id'] != null ? int.tryParse(json['ts_id'].toString()) : null,
      tsDate: json['ts_date']?.toString(),
      tsStart: json['ts_start']?.toString(),
      tsEnd: json['ts_end']?.toString(),
      tsMin: json['ts_min'] != null ? int.tryParse(json['ts_min'].toString()) : null,
      tsType: json['ts_type']?.toString(),
      tsPaymentMethod: json['ts_payment_method']?.toString(),
      tsStatus: json['ts_status']?.toString(),
      memberId: json['member_id'] != null ? int.tryParse(json['member_id'].toString()) : null,
      memberName: json['member_name']?.toString(),
      memberPhone: json['member_phone']?.toString(),
      totalAmt: json['total_amt'] != null ? int.tryParse(json['total_amt'].toString()) : null,
      termDiscount: json['term_discount'] != null ? int.tryParse(json['term_discount'].toString()) : null,
      memberDiscount: json['member_discount'] != null ? int.tryParse(json['member_discount'].toString()) : null,
      juniorDiscount: json['junior_discount'] != null ? int.tryParse(json['junior_discount'].toString()) : null,
      overtimeDiscount: json['overtime_discount'] != null ? int.tryParse(json['overtime_discount'].toString()) : null,
      revisitDiscount: json['revisit_discount'] != null ? int.tryParse(json['revisit_discount'].toString()) : null,
      emergencyDiscount: json['emergency_discount'] != null ? int.tryParse(json['emergency_discount'].toString()) : null,
      emergencyReason: json['emergency_reason']?.toString(),
      totalDiscount: json['total_discount'] != null ? int.tryParse(json['total_discount'].toString()) : null,
      netAmt: json['net_amt'] != null ? int.tryParse(json['net_amt'].toString()) : null,
      morning: json['morning'] != null ? int.tryParse(json['morning'].toString()) : null,
      normal: json['normal'] != null ? int.tryParse(json['normal'].toString()) : null,
      peak: json['peak'] != null ? int.tryParse(json['peak'].toString()) : null,
      night: json['night'] != null ? int.tryParse(json['night'].toString()) : null,
      timeStamp: json['time_stamp']?.toString(),
      routineId: json['routine_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reservation_id': reservationId,
      'ts_id': tsId,
      'ts_date': tsDate,
      'ts_start': tsStart,
      'ts_end': tsEnd,
      'ts_min': tsMin,
      'ts_type': tsType,
      'ts_payment_method': tsPaymentMethod,
      'ts_status': tsStatus,
      'member_id': memberId,
      'member_name': memberName,
      'member_phone': memberPhone,
      'total_amt': totalAmt,
      'term_discount': termDiscount,
      'member_discount': memberDiscount,
      'junior_discount': juniorDiscount,
      'overtime_discount': overtimeDiscount,
      'revisit_discount': revisitDiscount,
      'emergency_discount': emergencyDiscount,
      'emergency_reason': emergencyReason,
      'total_discount': totalDiscount,
      'net_amt': netAmt,
      'morning': morning,
      'normal': normal,
      'peak': peak,
      'night': night,
      'time_stamp': timeStamp,
      'routine_id': routineId,
    };
  }

  // ts_status에 따른 색상 반환
  Color getStatusColor() {
    switch (tsStatus) {
      case '결제완료':
        return Color(0xFFF0FDF4); // 매우 연한 에메랄드
      case '확인대상':
        return Color(0xFFFEF3C7); // 연한 앰버
      case '주니어':
        return Color(0xFFF8FAFF); // 매우 연한 인디고
      default:
        return Color(0xFFF9FAFB); // 매우 연한 그레이
    }
  }

  // 텍스트 색상 반환
  Color getStatusTextColor() {
    switch (tsStatus) {
      case '결제완료':
        return Color(0xFF065F46); // 진한 에메랄드
      case '확인대상':
        return Color(0xFF92400E); // 진한 앰버
      case '주니어':
        return Color(0xFF3730A3); // 진한 인디고
      default:
        return Color(0xFF374151); // 진한 그레이
    }
  }

  // 표시할 회원명
  String get displayMemberName {
    return memberName ?? '미등록';
  }

  // 시간 범위 포맷
  String get formattedTimeRange {
    if (tsStart == null || tsEnd == null) return '';
    
    final start = tsStart!.length >= 8 ? tsStart!.substring(0, 5) : tsStart!;
    final end = tsEnd!.length >= 8 ? tsEnd!.substring(0, 5) : tsEnd!;
    
    return '$start~$end';
  }

  // 상태 표시
  String get displayStatus {
    switch (tsStatus) {
      case '결제완료':
        return ''; // 완료 상태는 표시하지 않음
      case '확인대상':
        return '확인대상';
      case '주니어':
        return '주니어';
      default:
        return tsStatus ?? '';
    }
  }

  // net_amt 포맷 (크레딧 표시)
  String get formattedNetAmt {
    if (netAmt == null || netAmt == 0) return '';
    if (netAmt! < 0) {
      return '${(netAmt! * -1).toString()}c';
    }
    return '${netAmt}c';
  }
} 