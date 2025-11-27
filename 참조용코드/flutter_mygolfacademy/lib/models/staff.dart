import 'package:flutter/foundation.dart';
import 'dart:convert';

class Staff {
  final String id;
  final String name;
  final String nickname;
  final String staffType;
  final String? phone;
  final String? accessId;
  final String? password;
  final String? status;
  final int? minServiceMin;
  final int? staffSvcTime;
  final int? minReservationTerm;
  final int? reservationAheadDays;
  final double? salaryBase;
  final double? salaryHour;
  final double? salaryPerLesson;
  final double? salaryPerEvent;

  Staff({
    required this.id,
    required this.name,
    required this.nickname,
    required this.staffType,
    this.phone,
    this.accessId,
    this.password,
    this.status,
    this.minServiceMin,
    this.staffSvcTime,
    this.minReservationTerm,
    this.reservationAheadDays,
    this.salaryBase,
    this.salaryHour,
    this.salaryPerLesson,
    this.salaryPerEvent,
  });

  // JSON에서 객체로 변환 (v2_staff_pro 테이블용)
  factory Staff.fromJson(Map<String, dynamic> json) {
    try {
      if (kDebugMode) {
        print('===== Staff.fromJson - 변환 시작 (v2_staff_pro) =====');
        print('원본 JSON 데이터: ${jsonEncode(json)}');
      }
      
      // v2_staff_pro 테이블 필드명에 맞게 변환
      String id = json['pro_id']?.toString() ?? json['staff_id']?.toString() ?? '';
      String name = json['pro_name']?.toString() ?? json['staff_name']?.toString() ?? '';
      String nickname = json['staff_nickname']?.toString() ?? '';
      String staffType = json['staff_type']?.toString() ?? '';
      String? phone = json['pro_phone']?.toString() ?? json['staff_phone']?.toString();
      String? accessId = json['staff_access_id']?.toString();
      String? password = json['staff_password']?.toString();
      String? status = json['staff_status']?.toString();
      
      // 숫자 필드들 안전하게 변환
      int? minServiceMin = _safeToInt(json['min_service_min']);
      int? staffSvcTime = _safeToInt(json['staff_svc_time']);
      int? minReservationTerm = _safeToInt(json['min_reservation_term']);
      int? reservationAheadDays = _safeToInt(json['reservation_ahead_days']);
      
      // 급여 관련 필드들 안전하게 변환
      double? salaryBase = _safeToDouble(json['salary_base']);
      double? salaryHour = _safeToDouble(json['salary_hour']);
      double? salaryPerLesson = _safeToDouble(json['salary_per_lesson']);
      double? salaryPerEvent = _safeToDouble(json['salary_per_event']);
      
      if (kDebugMode) {
        print('기본 필드 변환: id=$id, name=$name, nickname=$nickname, staffType=$staffType, phone=$phone');
        print('추가 필드 변환: minServiceMin=$minServiceMin, staffSvcTime=$staffSvcTime, status=$status');
        print('===== Staff.fromJson - 변환 종료 =====');
      }
      
      return Staff(
        id: id,
        name: name,
        nickname: nickname,
        staffType: staffType,
        phone: phone,
        accessId: accessId,
        password: password,
        status: status,
        minServiceMin: minServiceMin,
        staffSvcTime: staffSvcTime,
        minReservationTerm: minReservationTerm,
        reservationAheadDays: reservationAheadDays,
        salaryBase: salaryBase,
        salaryHour: salaryHour,
        salaryPerLesson: salaryPerLesson,
        salaryPerEvent: salaryPerEvent,
      );
    } catch (e) {
      if (kDebugMode) {
        print('===== Staff.fromJson - 예외 발생 =====');
        print('예외 메시지: $e');
        print('원본 JSON 데이터: ${jsonEncode(json)}');
        print('스택 트레이스: ${StackTrace.current}');
        print('===== Staff.fromJson - 예외 처리 종료 =====');
      }
      rethrow;
    }
  }
  
  // 안전한 int 변환 헬퍼 메서드
  static int? _safeToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }
  
  // 안전한 double 변환 헬퍼 메서드
  static double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
} 