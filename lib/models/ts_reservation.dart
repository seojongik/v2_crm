import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TsReservation {
  final String? branchId;
  final String? reservationId;
  final int? tsId;
  final String? tsDate;
  final String? tsStart;
  final String? tsEnd;
  final String? tsPaymentMethod;
  final String? tsStatus;
  final int? memberId;
  final String? memberType;
  final String? memberName;
  final String? memberPhone;
  final int? totalAmt;
  final int? termDiscount;
  final int? couponDiscount;
  final int? totalDiscount;
  final int? netAmt;
  final int? discountMin;
  final int? normalMin;
  final int? extrachargeMin;
  final int? tsMin;
  final int? billMin;
  final String? timeStamp;
  final String? dayOfWeek;
  final String? billId;
  final String? billMinId;
  final String? billGameId;
  final String? programId;
  final String? programName;
  final String? memo;

  TsReservation({
    this.branchId,
    this.reservationId,
    this.tsId,
    this.tsDate,
    this.tsStart,
    this.tsEnd,
    this.tsPaymentMethod,
    this.tsStatus,
    this.memberId,
    this.memberType,
    this.memberName,
    this.memberPhone,
    this.totalAmt,
    this.termDiscount,
    this.couponDiscount,
    this.totalDiscount,
    this.netAmt,
    this.discountMin,
    this.normalMin,
    this.extrachargeMin,
    this.tsMin,
    this.billMin,
    this.timeStamp,
    this.dayOfWeek,
    this.billId,
    this.billMinId,
    this.billGameId,
    this.programId,
    this.programName,
    this.memo,
  });

  factory TsReservation.fromJson(Map<String, dynamic> json) {
    return TsReservation(
      branchId: json['branch_id']?.toString(),
      reservationId: json['reservation_id']?.toString(),
      tsId: json['ts_id'] != null ? int.tryParse(json['ts_id'].toString()) : null,
      tsDate: json['ts_date']?.toString(),
      tsStart: json['ts_start']?.toString(),
      tsEnd: json['ts_end']?.toString(),
      tsPaymentMethod: json['ts_payment_method']?.toString(),
      tsStatus: json['ts_status']?.toString(),
      memberId: json['member_id'] != null ? int.tryParse(json['member_id'].toString()) : null,
      memberType: json['member_type']?.toString(),
      memberName: json['member_name']?.toString(),
      memberPhone: json['member_phone']?.toString(),
      totalAmt: json['total_amt'] != null ? int.tryParse(json['total_amt'].toString()) : null,
      termDiscount: json['term_discount'] != null ? int.tryParse(json['term_discount'].toString()) : null,
      couponDiscount: json['coupon_discount'] != null ? int.tryParse(json['coupon_discount'].toString()) : null,
      totalDiscount: json['total_discount'] != null ? int.tryParse(json['total_discount'].toString()) : null,
      netAmt: json['net_amt'] != null ? int.tryParse(json['net_amt'].toString()) : null,
      discountMin: json['discount_min'] != null ? int.tryParse(json['discount_min'].toString()) : null,
      normalMin: json['normal_min'] != null ? int.tryParse(json['normal_min'].toString()) : null,
      extrachargeMin: json['extracharge_min'] != null ? int.tryParse(json['extracharge_min'].toString()) : null,
      tsMin: json['ts_min'] != null ? int.tryParse(json['ts_min'].toString()) : null,
      billMin: json['bill_min'] != null ? int.tryParse(json['bill_min'].toString()) : null,
      timeStamp: json['time_stamp']?.toString(),
      dayOfWeek: json['day_of_week']?.toString(),
      billId: json['bill_id']?.toString(),
      billMinId: json['bill_min_id']?.toString(),
      billGameId: json['bill_game_id']?.toString(),
      programId: json['program_id']?.toString(),
      programName: json['program_name']?.toString(),
      memo: json['memo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'reservation_id': reservationId,
      'ts_id': tsId,
      'ts_date': tsDate,
      'ts_start': tsStart,
      'ts_end': tsEnd,
      'ts_payment_method': tsPaymentMethod,
      'ts_status': tsStatus,
      'member_id': memberId,
      'member_type': memberType,
      'member_name': memberName,
      'member_phone': memberPhone,
      'total_amt': totalAmt,
      'term_discount': termDiscount,
      'coupon_discount': couponDiscount,
      'total_discount': totalDiscount,
      'net_amt': netAmt,
      'discount_min': discountMin,
      'normal_min': normalMin,
      'extracharge_min': extrachargeMin,
      'ts_min': tsMin,
      'bill_min': billMin,
      'time_stamp': timeStamp,
      'day_of_week': dayOfWeek,
      'bill_id': billId,
      'bill_min_id': billMinId,
      'bill_game_id': billGameId,
      'program_id': programId,
      'program_name': programName,
      'memo': memo,
    };
  }

  // 센터타석오픈 여부 확인
  bool get isCenterTsOpen {
    return (memberId == null || memberId == 0) && 
           (memberName == null || memberName!.isEmpty) &&
           tsStatus == '결제완료';
  }

  // ts_status에 따른 색상 반환
  Color getStatusColor() {
    // 센터타석오픈인 경우 회색 색상 반환
    if (isCenterTsOpen) {
      return Color(0xFFF3F4F6); // 연한 회색
    }
    
    switch (tsStatus) {
      case '결제완료':
        return Color(0xFFF0FDF4); // 매우 연한 에메랄드
      case '확인대상':
        return Color(0xFFFEF3C7); // 연한 앰버
      case '주니어':
        return Color(0xFFF8FAFF); // 매우 연한 인디고
      case '예약취소':
        return Color(0xFFFEF2F2); // 연한 빨강
      default:
        return Color(0xFFF9FAFB); // 매우 연한 그레이
    }
  }

  // 텍스트 색상 반환
  Color getStatusTextColor() {
    // 센터타석오픈인 경우 회색 텍스트 색상 반환
    if (isCenterTsOpen) {
      return Color(0xFF6B7280); // 중간 회색
    }
    
    switch (tsStatus) {
      case '결제완료':
        return Color(0xFF065F46); // 진한 에메랄드
      case '확인대상':
        return Color(0xFF92400E); // 진한 앰버
      case '주니어':
        return Color(0xFF3730A3); // 진한 인디고
      case '예약취소':
        return Color(0xFF991B1B); // 진한 빨강
      default:
        return Color(0xFF374151); // 진한 그레이
    }
  }

  // 표시할 회원명
  String get displayMemberName {
    // 센터타석오픈인 경우 '센터오픈' 표시
    if (isCenterTsOpen) {
      return '센터오픈';
    }
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
      case '예약취소':
        return '취소';
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

  // 포맷된 날짜
  String get formattedDate {
    if (tsDate == null) return '';
    try {
      final date = DateTime.parse(tsDate!);
      return DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(date);
    } catch (e) {
      return tsDate!;
    }
  }

  // 포맷된 금액
  String get formattedTotalAmt {
    if (totalAmt == null) return '0원';
    return NumberFormat('#,###원').format(totalAmt);
  }

  // 포맷된 할인금액
  String get formattedTotalDiscount {
    if (totalDiscount == null || totalDiscount == 0) return '0원';
    return NumberFormat('#,###원').format(totalDiscount);
  }

  // 포맷된 실결제금액
  String get formattedNetAmtKRW {
    if (netAmt == null) return '0원';
    return NumberFormat('#,###원').format(netAmt);
  }

  // 사용 시간 포맷
  String get formattedDuration {
    if (tsMin == null) return '';
    final hours = tsMin! ~/ 60;
    final minutes = tsMin! % 60;
    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    }
    return '${minutes}분';
  }

  // 결제 방법 아이콘
  IconData getPaymentMethodIcon() {
    switch (tsPaymentMethod) {
      case '선불크레딧':
        return Icons.account_balance_wallet;
      case '시간권':
        return Icons.access_time;
      case '현금':
        return Icons.money;
      case '카드':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
}