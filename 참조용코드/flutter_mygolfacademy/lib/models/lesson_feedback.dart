import 'package:flutter/foundation.dart';
import 'dart:convert';

class LessonFeedback {
  final String lsOrderId;
  final String staffNickname;
  final DateTime lsDate;
  final String lsId;
  final String lsConfirm;
  final String staffName;
  final String lsCategory;
  final DateTime confirmedAt;
  final String lsFeedbackBypro;
  final String lsStartTime;
  final String lsEndTime;

  LessonFeedback({
    required this.lsOrderId,
    required this.staffNickname,
    required this.lsDate,
    required this.lsId,
    required this.lsConfirm,
    required this.staffName,
    required this.lsCategory,
    required this.confirmedAt,
    required this.lsFeedbackBypro,
    required this.lsStartTime,
    required this.lsEndTime,
  });

  // JSON에서 객체로 변환
  factory LessonFeedback.fromJson(Map<String, dynamic> json, {String? staffName}) {
    try {
      if (kDebugMode) {
        print('===== LessonFeedback.fromJson - 변환 시작 =====');
        print('원본 JSON 데이터: ${jsonEncode(json)}');
      }
      
      // null 체크 및 안전한 변환
      String lsOrderId = json['LS_order_id']?.toString() ?? '';
      String staffNickname = json['staff_nickname']?.toString() ?? '';
      String lsId = json['LS_id']?.toString() ?? '';
      String lsConfirm = json['LS_confirm']?.toString() ?? '';
      String actualStaffName = staffName ?? json['LS_confirmed_by']?.toString() ?? '';
      String lsCategory = json['LS_category']?.toString() ?? '';
      String lsFeedbackBypro = json['LS_feedback_bypro']?.toString() ?? '';
      String lsStartTime = json['LS_start_time']?.toString() ?? '00:00:00';
      String lsEndTime = json['LS_end_time']?.toString() ?? '00:00:00';
      
      if (kDebugMode) {
        print('기본 문자열 필드 변환: lsOrderId=$lsOrderId, staffNickname=$staffNickname, lsId=$lsId');
        print('시간 필드: lsStartTime=$lsStartTime, lsEndTime=$lsEndTime');
        print('스태프 정보: staffName=$actualStaffName');
      }
      
      // 날짜 변환 시 예외 처리
      DateTime lsDate;
      DateTime confirmedAt;
      
      try {
        if (json['LS_date'] != null && json['LS_date'].toString().isNotEmpty) {
          lsDate = DateTime.parse(json['LS_date'].toString());
        } else {
          if (kDebugMode) {
            print('LS_date 필드가 null이거나 비어 있어 현재 시간으로 대체합니다.');
          }
          lsDate = DateTime.now();
        }
      } catch (e) {
        if (kDebugMode) {
          print('lsDate 변환 오류: $e, 원본 값: ${json['LS_date']}, 타입: ${json['LS_date']?.runtimeType}');
        }
        lsDate = DateTime.now(); // 기본값
      }
      
      try {
        if (json['confirmed_at'] != null && json['confirmed_at'].toString().isNotEmpty) {
          confirmedAt = DateTime.parse(json['confirmed_at'].toString());
        } else {
          if (kDebugMode) {
            print('confirmed_at 필드가 null이거나 비어 있어 현재 시간으로 대체합니다.');
          }
          confirmedAt = DateTime.now();
        }
      } catch (e) {
        if (kDebugMode) {
          print('confirmedAt 변환 오류: $e, 원본 값: ${json['confirmed_at']}, 타입: ${json['confirmed_at']?.runtimeType}');
        }
        confirmedAt = DateTime.now(); // 기본값
      }
      
      if (kDebugMode) {
        print('날짜/시간 필드 변환: lsDate=${lsDate.toIso8601String()}, confirmedAt=${confirmedAt.toIso8601String()}');
        print('LessonFeedback.fromJson - 변환 완료');
        print('===== LessonFeedback.fromJson - 변환 종료 =====');
      }
      
      return LessonFeedback(
        lsOrderId: lsOrderId,
        staffNickname: staffNickname,
        lsDate: lsDate,
        lsId: lsId,
        lsConfirm: lsConfirm,
        staffName: actualStaffName,
        lsCategory: lsCategory,
        confirmedAt: confirmedAt,
        lsFeedbackBypro: lsFeedbackBypro,
        lsStartTime: lsStartTime,
        lsEndTime: lsEndTime,
      );
    } catch (e) {
      if (kDebugMode) {
        print('===== LessonFeedback.fromJson - 예외 발생 =====');
        print('예외 메시지: $e');
        print('원본 JSON 데이터: ${jsonEncode(json)}');
        print('스택 트레이스: ${StackTrace.current}');
        print('===== LessonFeedback.fromJson - 예외 처리 종료 =====');
      }
      rethrow;
    }
  }

  // 피드백 목록 파싱
  List<String> parseFeedback() {
    if (lsFeedbackBypro.startsWith('피드백제외')) {
      return [];
    }
    
    final parts = lsFeedbackBypro.split('/n');
    return parts.where((part) => part.trim().isNotEmpty).toList();
  }

  // 피드백이 있는지 확인
  bool hasFeedback() {
    return !lsFeedbackBypro.startsWith('피드백제외');
  }
} 