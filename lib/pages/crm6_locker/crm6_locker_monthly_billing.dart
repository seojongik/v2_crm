import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'locker_api_service.dart';
import '/services/api_service.dart';

class LockerMonthlyBillingDialog extends StatefulWidget {
  const LockerMonthlyBillingDialog({super.key});

  @override
  State<LockerMonthlyBillingDialog> createState() => _LockerMonthlyBillingDialogState();
}

class _LockerMonthlyBillingDialogState extends State<LockerMonthlyBillingDialog> {
  DateTime selectedMonth = DateTime.now();
  List<Map<String, dynamic>> monthlyLockers = [];
  Map<int, Map<String, int>> memberUsageMap = {};
  Map<int, Map<String, dynamic>> memberInfoMap = {};
  Map<String, Map<String, dynamic>> previousPaymentsMap = {};
  Map<int, int> memberCreditBalanceMap = {}; // 회원별 크레딧 잔액
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyBillingData();
  }

  Future<void> _loadMonthlyBillingData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 해당 월에 배정 이력이 있는 락커 조회 (v2_Locker_bill 기준)
      final lockers = await LockerApiService.getMonthlyAssignedLockers(selectedMonth);
      
      // 전월 이용시간 조회
      final usageData = await LockerApiService.getMemberPreviousMonthUsage(selectedMonth);
      
      // 기납부 정보 조회
      final paymentsData = await LockerApiService.getLockerPreviousPayments(selectedMonth);
      
      // 회원 정보 조회 (이름 표시용)
      final memberIds = lockers
          .where((locker) => locker['member_id'] != null)
          .map((locker) => locker['member_id'] as int)
          .toSet()
          .toList();
      
      final memberInfoData = <int, Map<String, dynamic>>{};
      final creditBalanceData = <int, int>{};
      
      for (var memberId in memberIds) {
        final memberData = await ApiService.getDataList(
          table: 'v3_members',
          where: [
            {'field': 'member_id', 'operator': '=', 'value': memberId},
            {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
          ],
        );
        if (memberData.isNotEmpty) {
          memberInfoData[memberId] = memberData.first;
        }
        
        // 크레딧 잔액 조회
        try {
          final creditInfo = await LockerApiService.getMemberCreditInfo(memberId);
          creditBalanceData[memberId] = creditInfo['totalBalance'] ?? 0;
        } catch (e) {
          print('크레딧 잔액 조회 실패 (member_id: $memberId): $e');
          creditBalanceData[memberId] = 0;
        }
      }

      setState(() {
        monthlyLockers = lockers;
        memberUsageMap = usageData;
        memberInfoMap = memberInfoData;
        previousPaymentsMap = paymentsData;
        memberCreditBalanceMap = creditBalanceData;
        isLoading = false;
      });
    } catch (e) {
      print('월별과금 데이터 로드 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 할인 금액 계산 (정기결제(월별)만 적용)
  int _calculateDiscountAmount(Map<String, dynamic> locker, Map<String, int>? usage) {
    final paymentFrequency = locker['current_payment_frequency'] ?? '';
    
    // 정기결제(월별)이 아니면 할인 적용 안함
    if (paymentFrequency != '정기결제(월별)') {
      return 0;
    }
    
    if (usage == null) return 0;
    
    final basePrice = (locker['current_locker_price'] ?? 0) as int;
    final discountCondition = locker['current_locker_discount_condition'] ?? '';
    final discountConditionMin = (locker['current_locker_discount_condition_min'] ?? 0) as int;
    final discountRatio = double.tryParse(locker['current_locker_discount_ratio']?.toString() ?? '0') ?? 0.0;

    int relevantMinutes = 0;
    
    // 할인 조건에 따라 적용할 이용시간 결정
    if (discountCondition == '기간권 이용포함') {
      // 전체 이용시간 사용
      relevantMinutes = usage['total'] ?? 0;
    } else if (discountCondition == '기간권 이용제외') {
      // 기간권 제외 이용시간만 사용
      relevantMinutes = usage['nonTerm'] ?? 0;
    }
    
    // 할인 조건 충족 시 할인 적용
    if (relevantMinutes >= discountConditionMin) {
      return (basePrice * discountRatio / 100).round();
    }
    
    return 0;
  }

  // 청구금액 계산 (현재 시점 기준)
  dynamic _calculateBillAmount(Map<String, dynamic> locker, DateTime selectedMonth) {
    final basePrice = (locker['current_locker_price'] ?? 0) as int;
    final paymentFrequency = locker['current_payment_frequency'] ?? '';
    
    // 일시납부의 경우 v2_Locker_bill의 종료일 사용
    final lockerEndDateStr = paymentFrequency == '일시납부' 
        ? locker['locker_bill_end'] 
        : locker['current_locker_end_date'];
    
    print('청구금액 계산: locker_id=${locker['locker_id']}, member_id=${locker['member_id']}');
    print('  현재 납부방법: $paymentFrequency');
    print('  현재 기본가격: ${basePrice}원');
    print('  기준 종료일: $lockerEndDateStr (${paymentFrequency == '일시납부' ? 'bill' : 'status'}에서)');
    
    // 정기결제(월별)는 기본가격 그대로
    if (paymentFrequency == '정기결제(월별)') {
      print('  정기결제(월별) - 청구금액: ${basePrice}원');
      return basePrice;
    }
    
    // 일시납부의 경우 bill 종료일 기준으로 계산
    if (paymentFrequency == '일시납부' && lockerEndDateStr != null) {
      try {
        final today = DateTime.now();
        final lockerEndDate = DateTime.parse(lockerEndDateStr);
        
        print('  일시납부 계산: 오늘=${today.toString().split(' ')[0]}, bill종료일=${lockerEndDateStr}');
        
        // 오늘이 bill 종료일을 넘지 않았으면 결제완료 상태 ("-" 표시)
        if (!today.isAfter(lockerEndDate)) {
          print('  결제완료 상태 (bill 기간 내) - 청구금액: "-"');
          return "-";
        }
        
        // 오늘이 bill 종료일을 넘었으면 선택된 월에 연체 기간이 있는지 확인
        final selectedMonthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
        final selectedMonthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
        
        // 연체 시작일 (bill 종료일 다음날)
        final overduePeriodStart = lockerEndDate.add(Duration(days: 1));
        
        // 선택된 월과 연체 기간의 겹치는 부분 계산
        final overlapStart = overduePeriodStart.isAfter(selectedMonthStart) ? overduePeriodStart : selectedMonthStart;
        final overlapEnd = today.isBefore(selectedMonthEnd) ? today : selectedMonthEnd;
        
        // 겹치는 기간이 없으면 해당 월에는 청구할 금액 없음
        if (overlapStart.isAfter(overlapEnd)) {
          print('  선택된 월에 연체 기간 없음 - 청구금액: 0원');
          return 0;
        }
        
        // 겹치는 기간이 있으면 비례 계산
        final overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
        final totalOverdueDays = today.difference(overduePeriodStart).inDays + 1;
        
        final proratedAmount = (basePrice * overlapDays / totalOverdueDays).round();
        
        print('  연체 비례 계산:');
        print('    전체 연체일수: ${totalOverdueDays}일');
        print('    선택된 월 겹치는 일수: ${overlapDays}일');
        print('    비례 청구금액: ${proratedAmount}원');
        
        return proratedAmount;
        
      } catch (e) {
        print('  일시납부 청구금액 계산 오류: $e');
        return "-";  // 오류 시 결제완료로 처리
      }
    }
    
    // 일시납부인데 종료일이 없으면 결제완료로 처리
    if (paymentFrequency == '일시납부') {
      print('  일시납부 but 종료일 없음 - 청구금액: "-"');
      return "-";
    }
    
    // 기타 경우는 기본가격
    print('  기타 - 청구금액: ${basePrice}원');
    return basePrice;
  }

  // 미납 청구서가 있는지 확인
  bool _hasUnpaidBills() {
    return monthlyLockers.any((locker) {
      final memberId = locker['member_id'];
      final lockerId = locker['locker_id'];
      final usage = memberUsageMap[memberId];
      final billAmount = _calculateBillAmount(locker, selectedMonth);
      final discountAmount = _calculateDiscountAmount(locker, usage);
      final paymentFrequency = locker['current_payment_frequency'] ?? '';
      
      // 기납부 정보
      final paymentKey = '${lockerId}_$memberId';
      final previousPayment = previousPaymentsMap[paymentKey];
      final paidAmount = previousPayment?['total_amount'] ?? 0;
      
      // 청구금액이 0보다 큰 경우 미납으로 간주
      if (billAmount == "-") {
        return false;
      } else if (paymentFrequency == '정기결제(월별)' && paidAmount > 0) {
        return false;
      } else {
        final billAmountInt = billAmount as int;
        final finalAmount = billAmountInt - discountAmount;
        return finalAmount > 0;
      }
    });
  }

  // 크레딧 결제 다이얼로그 표시
  void _showCreditPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreditPaymentDialog(
        selectedMonth: selectedMonth,
        monthlyLockers: monthlyLockers,
        memberUsageMap: memberUsageMap,
        memberInfoMap: memberInfoMap,
        previousPaymentsMap: previousPaymentsMap,
        calculateBillAmount: _calculateBillAmount,
        calculateDiscountAmount: _calculateDiscountAmount,
        memberCreditBalanceMap: memberCreditBalanceMap,
        onPaymentComplete: () {
          _loadMonthlyBillingData(); // 결제 완료 후 데이터 새로고침
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    final previousMonthStr = DateFormat('yyyy년 MM월').format(previousMonth);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF10B981),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calculate, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '락커 월별과금',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '정기결제(월별) 락커 관리',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // 월 선택
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
                      });
                      _loadMonthlyBillingData();
                    },
                    icon: Icon(Icons.chevron_left, color: Color(0xFF10B981)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF10B981)),
                    ),
                    child: Text(
                      DateFormat('yyyy년 MM월').format(selectedMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
                      });
                      _loadMonthlyBillingData();
                    },
                    icon: Icon(Icons.chevron_right, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),

            // 전월 표시
            Container(
              padding: EdgeInsets.all(12),
              color: Color(0xFFFEF3C7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text(
                    '전월($previousMonthStr) 이용시간 기준으로 할인이 적용됩니다',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 테이블
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : monthlyLockers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                '정기결제(월별) 락커가 없습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(20),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DataTable(
                                columnSpacing: 24,
                                headingRowColor: MaterialStateProperty.all(Color(0xFFF9FAFB)),
                                columns: [
                                  DataColumn(label: Center(child: Text('락커번호', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Center(child: Text('회원ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Center(child: Text('회원명', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Center(child: Text('납부방법', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Center(child: Text('결제방법', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('기본가격', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Center(child: Text('할인조건', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('할인기준', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('할인율', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('전월\n전체이용', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('전월\n기간권제외', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('할인금액', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('청구금액', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('기납부', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('크레딧잔액', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                  DataColumn(label: Center(child: Text('비고', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                                ],
                              rows: monthlyLockers.map((locker) {
                                final memberId = locker['member_id'];
                                final lockerId = locker['locker_id'];
                                final memberInfo = memberInfoMap[memberId];
                                final memberName = memberInfo?['member_name'] ?? '-';
                                final usage = memberUsageMap[memberId];
                                final totalMinutes = usage?['total'] ?? 0;
                                final nonTermMinutes = usage?['nonTerm'] ?? 0;
                                final paymentFrequency = locker['current_payment_frequency'] ?? '';
                                final currentPrice = (locker['current_locker_price'] ?? 0) as int;
                                
                                // 청구금액 계산 (현재 시점 기준)
                                final billAmount = _calculateBillAmount(locker, selectedMonth);
                                final discountAmount = _calculateDiscountAmount(locker, usage);
                                
                                // 기납부 정보 조회
                                final paymentKey = '${lockerId}_$memberId';
                                final previousPayment = previousPaymentsMap[paymentKey];
                                final paidAmount = previousPayment?['total_amount'] ?? 0;
                                final paymentMethods = previousPayment?['payment_methods'] as Set<String>? ?? <String>{};
                                final paymentMethodsStr = paymentMethods.join(', ');
                                
                                // 청구금액 계산 
                                final dynamic finalPrice;
                                if (billAmount == "-") {
                                  finalPrice = "-";
                                } else if (paymentFrequency == '정기결제(월별)' && paidAmount > 0) {
                                  // 정기결제(월별)에서 기납부가 있으면 첫달로 간주하여 결제완료 처리
                                  finalPrice = 0;
                                } else {
                                  final billAmountInt = billAmount as int;
                                  finalPrice = billAmountInt - discountAmount;
                                }
                                
                                // 크레딧 잔액 및 부족 여부 확인
                                final creditBalance = memberCreditBalanceMap[memberId] ?? 0;
                                final bool isInsufficientCredit = finalPrice != "-" && 
                                    finalPrice is int && 
                                    finalPrice > 0 && 
                                    creditBalance < finalPrice;
                                
                                return DataRow(
                                  cells: [
                                    // 락커번호 - 가운데 정렬
                                    DataCell(Center(child: Text(locker['locker_name']?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.black)))),
                                    // 회원ID - 가운데 정렬
                                    DataCell(Center(child: Text(memberId?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.black)))),
                                    // 회원명 - 가운데 정렬 (볼드)
                                    DataCell(Center(child: Text(memberName, style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)))),
                                    DataCell(
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isInsufficientCredit && paymentFrequency == '정기결제(월별)'
                                              ? Color(0xFFFEE2E2) // 크레딧 부족 시 분홍 배경
                                              : paymentFrequency == '정기결제(월별)' 
                                                  ? Color(0xFFDCFCE7) 
                                                  : Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          paymentFrequency.isEmpty ? '-' : paymentFrequency,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isInsufficientCredit && paymentFrequency == '정기결제(월별)'
                                                ? Color(0xFFDC2626) // 크레딧 부족 시 빨간 글씨
                                                : paymentFrequency == '정기결제(월별)' 
                                                    ? Color(0xFF16A34A)
                                                    : Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 결제방법 - 가운데 정렬
                                    DataCell(
                                      Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Text(
                                            locker['current_payment_method']?.toString() ?? '-',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 기본가격 - 오른쪽 정렬 (볼드)
                                    DataCell(Align(alignment: Alignment.centerRight, child: Text(
                                      currentPrice > 0 ? '${NumberFormat('#,###').format(currentPrice)}원' : '-',
                                      style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)
                                    ))),
                                    // 할인조건 - 가운데 정렬
                                    DataCell(
                                      Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Text(
                                            locker['current_locker_discount_condition']?.toString() ?? '-',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 할인기준 - 오른쪽 정렬
                                    DataCell(Align(alignment: Alignment.centerRight, child: Text(
                                      (locker['current_locker_discount_condition_min'] ?? 0) > 0 
                                        ? '${locker['current_locker_discount_condition_min']}분' 
                                        : '-',
                                      style: TextStyle(fontSize: 12, color: Colors.black)
                                    ))),
                                    // 할인율 - 오른쪽 정렬
                                    DataCell(Align(alignment: Alignment.centerRight, child: Text(
                                      (double.tryParse(locker['current_locker_discount_ratio']?.toString() ?? '0') ?? 0.0) > 0 
                                        ? '${locker['current_locker_discount_ratio']}%' 
                                        : '-',
                                      style: TextStyle(fontSize: 12, color: Colors.black)
                                    ))),
                                    // 전월 전체이용 - 오른쪽 정렬
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          totalMinutes > 0 ? '${totalMinutes}분' : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 전월 기간권제외 - 오른쪽 정렬
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          nonTermMinutes > 0 ? '${nonTermMinutes}분' : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 할인금액 - 오른쪽 정렬
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          discountAmount > 0 ? '-${NumberFormat('#,###').format(discountAmount)}원' : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 청구금액 - 오른쪽 정렬
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          finalPrice == "-" ? "-" : 
                                            finalPrice == 0 ? "-" : 
                                            '${NumberFormat('#,###').format(finalPrice)}원',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 기납부 - 오른쪽 정렬 (볼드)
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Text(
                                            paidAmount > 0 
                                                ? '${NumberFormat('#,###').format(paidAmount)}원${paymentMethodsStr.isNotEmpty ? ' ($paymentMethodsStr)' : ''}'
                                                : '-',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: paidAmount > 0 ? Color(0xFF059669) : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 크레딧 잔액 - 오른쪽 정렬
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          creditBalance > 0 ? '${NumberFormat('#,###').format(creditBalance)}원' : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: creditBalance == 0 ? Colors.black : 
                                                   isInsufficientCredit ? Color(0xFFDC2626) : Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 비고 - 가운데 정렬
                                    DataCell(
                                      Center(
                                        child: isInsufficientCredit
                                            ? Text(
                                                '크레딧 부족',
                                                style: TextStyle(
                                                  color: Color(0xFFDC2626),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              )
                                            : Text(''),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                              ),
                            ),
                          ),
                        ),
            ),

            // 하단 요약 및 결제 버튼
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '총 ${monthlyLockers.length}개 락커',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '총 청구금액: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '${NumberFormat('#,###').format(
                              monthlyLockers.fold<int>(0, (sum, locker) {
                                final memberId = locker['member_id'];
                                final lockerId = locker['locker_id'];
                                final usage = memberUsageMap[memberId];
                                final billAmount = _calculateBillAmount(locker, selectedMonth);
                                final discountAmount = _calculateDiscountAmount(locker, usage);
                                
                                // 기납부 정보
                                final paymentKey = '${lockerId}_$memberId';
                                final previousPayment = previousPaymentsMap[paymentKey];
                                final paidAmount = previousPayment?['total_amount'] ?? 0;
                                final paymentFrequency = locker['current_payment_frequency'] ?? '';
                                
                                // 청구금액 계산
                                if (billAmount == "-") {
                                  return sum;
                                } else if (paymentFrequency == '정기결제(월별)' && paidAmount > 0) {
                                  // 정기결제(월별)에서 기납부가 있으면 첫달로 간주하여 결제완료 처리
                                  return sum;
                                } else {
                                  final billAmountInt = billAmount as int;
                                  final finalAmount = billAmountInt - discountAmount;
                                  return sum + finalAmount;
                                }
                              })
                            )}원',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // 크레딧 결제 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _hasUnpaidBills() ? _showCreditPaymentDialog : null,
                      icon: Icon(Icons.credit_card, color: Colors.white),
                      label: Text(
                        '청구금액 결제(크레딧)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasUnpaidBills() ? Color(0xFF3B82F6) : Color(0xFFD1D5DB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 크레딧 결제 다이얼로그
class CreditPaymentDialog extends StatefulWidget {
  final DateTime selectedMonth;
  final List<Map<String, dynamic>> monthlyLockers;
  final Map<int, Map<String, int>> memberUsageMap;
  final Map<int, Map<String, dynamic>> memberInfoMap;
  final Map<String, Map<String, dynamic>> previousPaymentsMap;
  final Map<int, int> memberCreditBalanceMap;
  final Function(Map<String, dynamic>, DateTime) calculateBillAmount;
  final Function(Map<String, dynamic>, Map<String, int>?) calculateDiscountAmount;
  final VoidCallback onPaymentComplete;

  const CreditPaymentDialog({
    super.key,
    required this.selectedMonth,
    required this.monthlyLockers,
    required this.memberUsageMap,
    required this.memberInfoMap,
    required this.previousPaymentsMap,
    required this.memberCreditBalanceMap,
    required this.calculateBillAmount,
    required this.calculateDiscountAmount,
    required this.onPaymentComplete,
  });

  @override
  State<CreditPaymentDialog> createState() => _CreditPaymentDialogState();
}

class _CreditPaymentDialogState extends State<CreditPaymentDialog> {
  bool includeMonthly = false; // 정기결제(월별) 포함 여부
  bool includeLumpSum = false; // 일시납부 포함 여부
  bool isProcessing = false;

  // 정기결제(월별) 청구 금액 계산
  int _calculateMonthlyTotal() {
    return widget.monthlyLockers.where((locker) {
      return locker['current_payment_frequency'] == '정기결제(월별)';
    }).fold<int>(0, (sum, locker) {
      final memberId = locker['member_id'];
      final lockerId = locker['locker_id'];
      final usage = widget.memberUsageMap[memberId];
      final billAmount = widget.calculateBillAmount(locker, widget.selectedMonth);
      final discountAmount = widget.calculateDiscountAmount(locker, usage);
      
      // 기납부 정보
      final paymentKey = '${lockerId}_$memberId';
      final previousPayment = widget.previousPaymentsMap[paymentKey];
      final paidAmount = previousPayment?['total_amount'] ?? 0;
      
      if (billAmount == "-" || (paidAmount > 0)) {
        return sum;
      } else {
        final billAmountInt = billAmount as int;
        final finalAmount = billAmountInt - discountAmount;
        return sum + finalAmount as int;
      }
    });
  }

  // 일시납부 청구 금액 계산
  int _calculateLumpSumTotal() {
    return widget.monthlyLockers.where((locker) {
      return locker['current_payment_frequency'] == '일시납부';
    }).fold<int>(0, (sum, locker) {
      final memberId = locker['member_id'];
      final lockerId = locker['locker_id'];
      final billAmount = widget.calculateBillAmount(locker, widget.selectedMonth);
      
      if (billAmount == "-") {
        // 일시납부 기간 내 락커도 크레딧으로 연장 결제 가능
        // 마지막 청구 종료일부터 당일까지 일할 계산
        final billEndStr = locker['locker_bill_end'];
        if (billEndStr != null) {
          try {
            final billEndDate = DateTime.parse(billEndStr);
            final today = DateTime.now();
            final todayOnly = DateTime(today.year, today.month, today.day); // 시간 제거
            
            // 종료일 다음날부터 당일까지
            final extendStart = billEndDate.add(Duration(days: 1));
            final extendEnd = todayOnly;
            
            if (extendStart.isBefore(extendEnd) || extendStart.isAtSameMomentAs(extendEnd)) {
              final extendDays = extendEnd.difference(extendStart).inDays + 1;
              final monthDays = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
              final basePrice = (locker['current_locker_price'] ?? 0) as int;
              final proratedAmount = (basePrice * extendDays / monthDays).round();
              return sum + proratedAmount;
            }
          } catch (e) {
            print('일시납부 연장 계산 오류: $e');
          }
        }
        return sum;
      } else {
        // 이미 연체된 경우
        final billAmountInt = billAmount as int;
        return sum + billAmountInt;
      }
    });
  }

  // 결제 처리
  Future<void> _processPayment() async {
    print('=== 크레딧 결제 시작 ===');
    print('정기결제(월별) 선택: $includeMonthly');
    print('일시납부 선택: $includeLumpSum');
    
    if (!includeMonthly && !includeLumpSum) {
      print('선택된 결제 방법이 없음');
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final branchId = ApiService.getCurrentBranchId();
      final today = DateTime.now();
      final monthStart = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
      final monthEnd = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
      
      print('Branch ID: $branchId');
      print('오늘 날짜: ${today.toString().split(' ')[0]}');
      print('청구 기간: ${monthStart.toString().split(' ')[0]} ~ ${monthEnd.toString().split(' ')[0]}');

      // 정기결제(월별) 처리
      if (includeMonthly) {
        print('\n=== 정기결제(월별) 처리 시작 ===');
        for (var locker in widget.monthlyLockers) {
          if (locker['current_payment_frequency'] != '정기결제(월별)') continue;
          
          final memberId = locker['member_id'];
          final lockerId = locker['locker_id'];
          final lockerName = locker['locker_name'];
          
          print('\n락커 처리: ID=$lockerId, Name=$lockerName, Member=$memberId');
          
          final usage = widget.memberUsageMap[memberId];
          final billAmount = widget.calculateBillAmount(locker, widget.selectedMonth);
          final discountAmount = widget.calculateDiscountAmount(locker, usage);
          
          print('청구금액: $billAmount, 할인금액: $discountAmount');
          
          // 기납부 확인
          final paymentKey = '${lockerId}_$memberId';
          final previousPayment = widget.previousPaymentsMap[paymentKey];
          final paidAmount = previousPayment?['total_amount'] ?? 0;
          
          print('기납부 금액: $paidAmount');
          
          if (billAmount != "-" && paidAmount == 0) {
            final billAmountInt = billAmount as int;
            final finalAmount = billAmountInt - discountAmount;
            
            print('최종 청구금액: $finalAmount');
            
            if (finalAmount > 0) {
              final usage = widget.memberUsageMap[memberId];
              final totalMinutes = usage?['total'] ?? 0;
              final discountRatio = discountAmount > 0 ? (discountAmount / billAmountInt * 100) : 0.0;
              
              print('크레딧 결제 처리 시작...');
              try {
                // 1. 먼저 크레딧 차감 (v2_bills 업데이트)
                final billId = await LockerApiService.processCreditPayment(
                  memberId: memberId,
                  memberName: widget.memberInfoMap[memberId]?['member_name'] ?? '',
                  lockerName: lockerName.toString(),
                  lockerStart: monthStart.toString().split(' ')[0],
                  lockerEnd: monthEnd.toString().split(' ')[0],
                  paymentFrequency: '정기결제(월별)',
                  totalPrice: finalAmount as int,
                );
                
                print('✅ 크레딧 차감 성공 - bill_id: $billId');
                
                // 2. v2_Locker_bill에 레코드 추가 (bill_id 포함)
                final result = await LockerApiService.addLockerBillWithBillId(
                  billType: '정기결제',
                  lockerId: lockerId,
                  lockerName: lockerName.toString(),
                  memberId: memberId,
                  lockerStart: monthStart.toString().split(' ')[0],
                  lockerEnd: monthEnd.toString().split(' ')[0],
                  paymentMethod: '크레딧 결제',
                  totalPrice: billAmountInt,
                  deduction: discountAmount,
                  netAmount: finalAmount as int,
                  lastMonthMinutes: totalMinutes,
                  discountRatio: discountRatio,
                  remark: '',
                  billId: billId,
                );
                print('✅ v2_Locker_bill 저장 성공: $result');
              } catch (e) {
                print('❌ 크레딧 결제 처리 실패: $e');
                rethrow;
              }
            }
          }
        }
      }

      // 일시납부 처리
      if (includeLumpSum) {
        for (var locker in widget.monthlyLockers) {
          if (locker['current_payment_frequency'] != '일시납부') continue;
          
          final memberId = locker['member_id'];
          final lockerId = locker['locker_id'];
          final billAmount = widget.calculateBillAmount(locker, widget.selectedMonth);
          
          int finalAmount = 0;
          String billStart = '';
          String billEnd = '';
          
          if (billAmount == "-") {
            // 기간 내 락커 - 연장 결제 (당일까지)
            final billEndStr = locker['locker_bill_end'];
            if (billEndStr != null) {
              try {
                final billEndDate = DateTime.parse(billEndStr);
                final todayOnly = DateTime(today.year, today.month, today.day); // 시간 제거
                final extendStart = billEndDate.add(Duration(days: 1));
                final extendEnd = todayOnly;
                
                if (extendStart.isBefore(extendEnd) || extendStart.isAtSameMomentAs(extendEnd)) {
                  final extendDays = extendEnd.difference(extendStart).inDays + 1;
                  final monthDays = monthEnd.day;
                  final basePrice = (locker['current_locker_price'] ?? 0) as int;
                  finalAmount = (basePrice * extendDays / monthDays).round();
                  billStart = extendStart.toString().split(' ')[0];
                  billEnd = extendEnd.toString().split(' ')[0];
                }
              } catch (e) {
                print('일시납부 연장 계산 오류: $e');
                continue;
              }
            }
          } else {
            // 연체 락커
            finalAmount = billAmount as int;
            billStart = monthStart.toString().split(' ')[0];
            billEnd = monthEnd.toString().split(' ')[0];
          }
          
          if (finalAmount > 0) {
            print('크레딧 결제 처리 시작 (일시납부)...');
            try {
              // 1. 먼저 크레딧 차감 (v2_bills 업데이트)
              final memberInfo = widget.memberInfoMap[memberId];
              final memberName = memberInfo?['member_name'] ?? '';
              
              final billId = await LockerApiService.processCreditPayment(
                memberId: memberId,
                memberName: memberName,
                lockerName: locker['locker_name'].toString(),
                lockerStart: billStart,
                lockerEnd: billEnd,
                paymentFrequency: '일시납부',
                totalPrice: finalAmount,
              );
              
              print('✅ 크레딧 차감 성공 (일시납부) - bill_id: $billId');
              
              // 2. v2_Locker_bill에 레코드 추가 (bill_id 포함)
              final result = await LockerApiService.addLockerBillWithBillId(
                billType: '일시납부',
                lockerId: lockerId,
                lockerName: locker['locker_name'].toString(),
                memberId: memberId,
                lockerStart: billStart,
                lockerEnd: billEnd,
                paymentMethod: '크레딧 결제',
                totalPrice: finalAmount,
                deduction: 0,
                netAmount: finalAmount,
                lastMonthMinutes: 0,
                discountRatio: 0.0,
                remark: '',
                billId: billId,
              );
              print('✅ v2_Locker_bill 저장 성공 (일시납부): $result');
            } catch (e) {
              print('❌ 크레딧 결제 처리 실패 (일시납부): $e');
              rethrow;
            }
          }
        }
      }

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('크레딧 결제가 완료되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        widget.onPaymentComplete();
      }
    } catch (e) {
      print('결제 처리 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('결제 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthlyTotal = _calculateMonthlyTotal();
    final lumpSumTotal = _calculateLumpSumTotal();
    final selectedTotal = (includeMonthly ? monthlyTotal : 0) + (includeLumpSum ? lumpSumTotal : 0);

    return Dialog(
      child: Container(
        width: 500,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.credit_card, color: Color(0xFF3B82F6), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '크레딧 결제',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            SizedBox(height: 24),

            // 납부방법 선택
            Text(
              '납부방법 선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 12),

            // 정기결제(월별) 옵션
            CheckboxListTile(
              value: includeMonthly,
              onChanged: monthlyTotal > 0 ? (value) {
                setState(() {
                  includeMonthly = value ?? false;
                });
              } : null,
              title: Text('정기결제(월별)'),
              subtitle: Text(
                monthlyTotal > 0 
                    ? '${NumberFormat('#,###').format(monthlyTotal)}원'
                    : '청구 대상 없음',
                style: TextStyle(
                  color: monthlyTotal > 0 ? Color(0xFF059669) : Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            // 일시납부 옵션
            CheckboxListTile(
              value: includeLumpSum,
              onChanged: lumpSumTotal > 0 ? (value) {
                setState(() {
                  includeLumpSum = value ?? false;
                });
              } : null,
              title: Text('일시납부'),
              subtitle: Text(
                lumpSumTotal > 0 
                    ? '${NumberFormat('#,###').format(lumpSumTotal)}원 (연체/연장)'
                    : '청구 대상 없음',
                style: TextStyle(
                  color: lumpSumTotal > 0 ? Color(0xFF059669) : Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            SizedBox(height: 24),

            // 총 결제금액
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '총 결제금액',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(selectedTotal)}원',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 결제 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('취소'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedTotal > 0 && !isProcessing ? _processPayment : null,
                    child: isProcessing 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '결제하기',
                            style: TextStyle(color: Colors.white),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}