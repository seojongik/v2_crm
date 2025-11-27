import 'package:flutter/foundation.dart';
import 'dart:convert';

class LessonCounting {
  final String lsId;
  final String memberId;
  final String? lsContractId;
  final String memberName;
  final int lsBalanceBefore;
  final int lsNetQty;
  final int lsBalanceAfter;
  final int lsBalanceMinBefore;
  final int lsNetMin;
  final int lsBalanceMinAfter;
  final String lsCountingSource;
  final DateTime updatedAt;
  final String lsType;
  final String? juniorId;
  final String? lsProName;
  final String? lsDescription;
  final int lsCountingId;
  final String? lsContractPro;
  final String? lsTransactionType;

  LessonCounting({
    required this.lsId,
    required this.memberId,
    this.lsContractId,
    required this.memberName,
    required this.lsBalanceBefore,
    required this.lsNetQty,
    required this.lsBalanceAfter,
    this.lsBalanceMinBefore = 0,
    this.lsNetMin = 0,
    this.lsBalanceMinAfter = 0,
    required this.lsCountingSource,
    required this.updatedAt,
    required this.lsType,
    this.juniorId,
    this.lsProName,
    this.lsDescription,
    this.lsCountingId = 0,
    this.lsContractPro,
    this.lsTransactionType,
  });

  // JSON에서 객체로 변환
  factory LessonCounting.fromJson(Map<String, dynamic> json) {
    try {
      if (kDebugMode) {
        print('===== LessonCounting.fromJson - 변환 시작 =====');
        print('원본 JSON 데이터: ${jsonEncode(json)}');
      }
      
      // null 체크 및 안전한 변환
      String lsId = json['LS_id']?.toString() ?? '';
      String memberId = json['member_id']?.toString() ?? '';
      String? lsContractId = json['LS_contract_id']?.toString();
      String memberName = json['member_name']?.toString() ?? '';
      
      if (kDebugMode) {
        print('기본 문자열 필드 변환: lsId=$lsId, memberId=$memberId, memberName=$memberName');
      }
      
      // 숫자 변환 시 예외 처리
      int lsBalanceBefore = 0;
      int lsNetQty = 0;
      int lsBalanceAfter = 0;
      int lsBalanceMinBefore = 0;
      int lsNetMin = 0;
      int lsBalanceMinAfter = 0;
      int lsCountingId = 0;
      
      try {
        lsBalanceBefore = json['LS_balance_before'] != null 
            ? int.parse(json['LS_balance_before'].toString()) 
            : 0;
      } catch (e) {
        if (kDebugMode) {
          print('lsBalanceBefore 변환 오류: $e, 원본 값: ${json['LS_balance_before']}, 타입: ${json['LS_balance_before'].runtimeType}');
        }
      }
      
      try {
        lsNetQty = json['LS_net_qty'] != null 
            ? int.parse(json['LS_net_qty'].toString()) 
            : 0;
      } catch (e) {
        if (kDebugMode) {
          print('lsNetQty 변환 오류: $e, 원본 값: ${json['LS_net_qty']}, 타입: ${json['LS_net_qty'].runtimeType}');
        }
      }
      
      try {
        if (json['LS_balance_min_after'] != null) {
          lsBalanceAfter = int.parse(json['LS_balance_min_after'].toString());
        } else if (json['LS_balance_after'] != null) {
          lsBalanceAfter = int.parse(json['LS_balance_after'].toString());
        }
      } catch (e) {
        if (kDebugMode) {
          print('lsBalanceAfter 변환 오류: $e, 원본 값: ${json['LS_balance_after']}, 타입: ${json['LS_balance_after'].runtimeType}');
        }
      }
      
      try {
        lsBalanceMinBefore = json['LS_balance_min_before'] != null 
            ? int.parse(json['LS_balance_min_before'].toString()) 
            : 0;
      } catch (e) {
        if (kDebugMode) {
          print('lsBalanceMinBefore 변환 오류: $e, 원본 값: ${json['LS_balance_min_before']}');
        }
      }
      
      try {
        lsNetMin = json['LS_net_min'] != null 
            ? int.parse(json['LS_net_min'].toString()) 
            : 0;
      } catch (e) {
        if (kDebugMode) {
          print('lsNetMin 변환 오류: $e, 원본 값: ${json['LS_net_min']}');
        }
      }
      
      try {
        lsBalanceMinAfter = json['LS_balance_min_after'] != null 
            ? int.parse(json['LS_balance_min_after'].toString()) 
            : 0;
      } catch (e) {
        if (kDebugMode) {
          print('lsBalanceMinAfter 변환 오류: $e, 원본 값: ${json['LS_balance_min_after']}');
        }
      }
      
      try {
        lsCountingId = json['LS_counting_id'] != null 
            ? int.parse(json['LS_counting_id'].toString()) 
            : 0;
      } catch (e) {
        if (kDebugMode) {
          print('lsCountingId 변환 오류: $e, 원본 값: ${json['LS_counting_id']}');
        }
      }
      
      if (kDebugMode) {
        print('숫자 필드 변환: lsBalanceBefore=$lsBalanceBefore, lsNetQty=$lsNetQty, lsBalanceAfter=$lsBalanceAfter');
        print('추가 숫자 필드: lsBalanceMinBefore=$lsBalanceMinBefore, lsNetMin=$lsNetMin, lsBalanceMinAfter=$lsBalanceMinAfter');
        print('LS_counting_id: $lsCountingId');
      }
      
      String lsCountingSource = json['LS_counting_source']?.toString() ?? '';
      DateTime updatedAt;
      
      try {
        if (json['updated_at'] != null && json['updated_at'].toString().isNotEmpty) {
          updatedAt = DateTime.parse(json['updated_at'].toString());
        } else {
          if (kDebugMode) {
            print('updated_at 필드가 null이거나 비어 있어 현재 시간으로 대체합니다.');
          }
          updatedAt = DateTime.now();
        }
      } catch (e) {
        if (kDebugMode) {
          print('updatedAt 변환 오류: $e, 원본 값: ${json['updated_at']}, 타입: ${json['updated_at']?.runtimeType}');
        }
        updatedAt = DateTime.now(); // 기본값
      }
      
      String lsType = json['LS_type']?.toString() ?? '';
      String? juniorId = json['junior_id']?.toString();
      
      String? lsProName = json['LS_pro_name']?.toString();
      String? lsDescription = json['LS_description']?.toString();
      
      // 추가 필드 변환
      String? lsContractPro = json['LS_contract_pro']?.toString();
      String? lsTransactionType = json['LS_transaction_type']?.toString();
      
      if (kDebugMode) {
        print('날짜/시간 필드 변환: updatedAt=${updatedAt.toIso8601String()}');
        print('새 필드 변환: lsProName=$lsProName, lsDescription=$lsDescription');
        print('담당 프로: lsContractPro=$lsContractPro, 거래 유형: lsTransactionType=$lsTransactionType');
        print('LessonCounting.fromJson - 변환 완료');
        print('===== LessonCounting.fromJson - 변환 종료 =====');
      }
      
      return LessonCounting(
        lsId: lsId,
        memberId: memberId,
        lsContractId: lsContractId,
        memberName: memberName,
        lsBalanceBefore: lsBalanceBefore,
        lsNetQty: lsNetQty,
        lsBalanceAfter: lsBalanceAfter,
        lsBalanceMinBefore: lsBalanceMinBefore,
        lsNetMin: lsNetMin,
        lsBalanceMinAfter: lsBalanceMinAfter,
        lsCountingSource: lsCountingSource,
        updatedAt: updatedAt,
        lsType: lsType,
        juniorId: juniorId,
        lsProName: lsProName,
        lsDescription: lsDescription,
        lsCountingId: lsCountingId,
        lsContractPro: lsContractPro,
        lsTransactionType: lsTransactionType,
      );
    } catch (e) {
      if (kDebugMode) {
        print('===== LessonCounting.fromJson - 예외 발생 =====');
        print('예외 메시지: $e');
        print('원본 JSON 데이터: ${jsonEncode(json)}');
        print('스택 트레이스: ${StackTrace.current}');
        print('===== LessonCounting.fromJson - 예외 처리 종료 =====');
      }
      rethrow;
    }
  }
} 