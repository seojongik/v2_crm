import 'package:flutter/material.dart';

class CreditTransaction {
  final DateTime date;
  final String type;  // 구분 (사용, 적립 등)
  final String description;  // 내용
  final int amount;  // 총금액
  final int deduction;  // 할인
  final int netAmount;  // 차감액
  final int balance;  // 잔액
  final String status;  // 상태 (completed, 결제완료 등)

  CreditTransaction({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.deduction,
    required this.netAmount,
    required this.balance,
    this.status = 'completed',  // 기본값 설정
  });

  // 거래 타입에 따른 색상 반환
  Color getTypeColor() {
    switch (type) {
      case '사용':
      case '타석이용':
        return Colors.red.shade100;
      case '적립':
      case '회원권구매':
        return Colors.green.shade100;
      case '수동적립':
        return Colors.blue.shade100;
      case '수동차감':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  // 거래 타입에 따른 글자 색상 반환
  Color getTextColor() {
    switch (type) {
      case '사용':
      case '타석이용':
        return Colors.red;
      case '적립':
      case '회원권구매':
        return Colors.green;
      case '수동적립':
        return Colors.blue;
      case '수동차감':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
} 