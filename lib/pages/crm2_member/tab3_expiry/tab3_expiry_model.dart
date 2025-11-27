import '/flutter_flow/flutter_flow_util.dart';
import 'tab3_expiry_widget.dart' show Tab3ExpiryWidget;
import 'package:flutter/material.dart';

// 개별 상품 만료 정보 모델
class ExpiryItem {
  final int memberId;
  final String memberName;
  final int contractHistoryId;
  final String productType; // 'credit', 'time', 'game', 'lesson', 'term'
  final String contractName;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final dynamic currentBalance; // int 또는 String (기간권은 "n일")
  final String? proName; // 레슨권만 해당
  final dynamic proId; // 레슨권만 해당

  ExpiryItem({
    required this.memberId,
    required this.memberName,
    required this.contractHistoryId,
    required this.productType,
    required this.contractName,
    required this.purchaseDate,
    this.expiryDate,
    required this.currentBalance,
    this.proName,
    this.proId,
  });

  // 상품 타입별 한글명
  String get productTypeLabel {
    switch (productType) {
      case 'credit':
        return '크레딧';
      case 'time':
        return '시간권';
      case 'game':
        return '게임권';
      case 'lesson':
        return '레슨권';
      case 'term':
        return '기간권';
      default:
        return '기타';
    }
  }

  // 만료까지 남은 일수
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  // 만료 상태 (만료, 임박, 정상)
  String get expiryStatus {
    if (expiryDate == null) return '정보없음';
    final days = daysUntilExpiry!;
    if (days < 0) return '만료';
    if (days <= 7) return '임박';
    if (days <= 30) return '주의';
    return '정상';
  }
}

class Tab3ExpiryModel extends FlutterFlowModel<Tab3ExpiryWidget> {
  // 탭 상태
  int selectedTabIndex = 0; // 0: 크레딧, 1: 시간권, 2: 게임권, 3: 레슨권, 4: 기간권

  // 날짜 필터
  DateTime? startDate;
  DateTime? endDate;

  // 레슨권 프로 필터
  String? selectedProId;
  List<Map<String, dynamic>> availablePros = [];

  // 탭별 데이터 캐시
  Map<int, List<ExpiryItem>> tabDataCache = {};
  Map<int, bool> tabDataLoaded = {};

  // 현재 탭의 필터링된 데이터
  List<ExpiryItem> filteredItems = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState(BuildContext context) {
    // 기본 날짜 설정 (오늘부터 3개월)
    startDate = DateTime.now();
    endDate = DateTime(DateTime.now().year, DateTime.now().month + 3, DateTime.now().day);
  }

  @override
  void dispose() {}

  // 현재 탭의 데이터 가져오기
  List<ExpiryItem> getCurrentTabData() {
    return tabDataCache[selectedTabIndex] ?? [];
  }

  // 필터 적용
  void applyFilters() {
    List<ExpiryItem> items = getCurrentTabData();
    print('>>> applyFilters 시작: ${items.length}개 아이템');

    int noExpiryDateCount = 0;
    int beforeStartDateCount = 0;
    int afterEndDateCount = 0;
    int proFilterCount = 0;

    filteredItems = items.where((item) {
      // 날짜 필터
      if (item.expiryDate == null) {
        noExpiryDateCount++;
        return false;
      }

      if (startDate != null && item.expiryDate!.isBefore(startDate!)) {
        beforeStartDateCount++;
        return false;
      }

      if (endDate != null && item.expiryDate!.isAfter(endDate!.add(Duration(days: 1)))) {
        afterEndDateCount++;
        return false;
      }

      // 레슨권 프로 필터 (탭 인덱스 3)
      if (selectedTabIndex == 3 && selectedProId != null && selectedProId!.isNotEmpty) {
        // ExpiryItem의 proId와 선택된 프로 ID 비교
        if (item.proId?.toString() != selectedProId) {
          proFilterCount++;
          return false;
        }
      }

      return true;
    }).toList();

    print('>>> 필터 결과:');
    print('  - 만료일 없음: $noExpiryDateCount개 제외');
    print('  - 시작일 이전: $beforeStartDateCount개 제외');
    print('  - 종료일 이후: $afterEndDateCount개 제외');
    if (selectedTabIndex == 3 && selectedProId != null) {
      print('  - 프로 필터: $proFilterCount개 제외');
    }
    print('  - 최종 필터된 결과: ${filteredItems.length}개');

    // 만료일 기준 오름차순 정렬
    filteredItems.sort((a, b) {
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
  }

  // 잔액 합계 계산
  int calculateTotalBalance() {
    int total = 0;
    for (var item in filteredItems) {
      if (item.currentBalance is int) {
        total += item.currentBalance as int;
      } else if (item.currentBalance is String) {
        // 기간권의 경우 "n일" 형식
        final match = RegExp(r'(\d+)').firstMatch(item.currentBalance);
        if (match != null) {
          total += int.parse(match.group(1)!);
        }
      }
    }
    return total;
  }

  // 잔액 합계 단위
  String getBalanceUnit() {
    switch (selectedTabIndex) {
      case 0: return '원'; // 크레딧
      case 1: return '분'; // 시간권
      case 2: return '게임'; // 게임권
      case 3: return '분'; // 레슨권
      case 4: return '일'; // 기간권
      default: return '';
    }
  }
}
