import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'tab2_contract_popup_design.dart';
import 'tab2_contract_validity_check.dart';

class Tab3CreditWidget extends StatefulWidget {
  const Tab3CreditWidget({
    super.key,
    required this.memberId,
  });

  final int memberId;

  @override
  State<Tab3CreditWidget> createState() => _Tab3CreditWidgetState();
}

class _Tab3CreditWidgetState extends State<Tab3CreditWidget> {
  List<Map<String, dynamic>> creditHistory = [];
  List<Map<String, dynamic>> contractsWithBalance = [];
  List<Map<String, dynamic>> filteredContractsWithBalance = []; // 필터링된 계약 목록
  Map<String, dynamic>? selectedContract;
  bool isLoading = true;
  String? errorMessage;
  bool includeExpired = false; // 만료 포함 여부 (디폴트: 제외)

  @override
  void initState() {
    super.initState();
    _loadContractsAndBalances();
  }

  // 계약별 잔액 조회
  Future<void> _loadContractsAndBalances() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. 해당 회원의 모든 bills 데이터 조회하여 contract_history_id별로 그룹핑
      final allBillsData = await ApiService.getBillsData(
        where: [
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ]
      );

      // 2. contract_history_id별로 그룹핑하여 최신 잔액 추출
      Map<int?, Map<String, dynamic>> contractGroups = {};
      
      for (final bill in allBillsData) {
        final contractHistoryId = bill['contract_history_id'];
        
        // 아직 해당 계약이 없으면 추가 (최신 거래가 먼저 오므로 첫 번째가 최신)
        if (!contractGroups.containsKey(contractHistoryId)) {
          // contract_history_id가 있으면 v3_contract_history에서 실제 계약명 조회
          String contractName = _extractContractName(bill);
          if (contractHistoryId != null) {
            try {
              final contractData = await ApiService.getContractHistoryDataById(contractHistoryId);
              if (contractData != null && contractData['contract_name'] != null) {
                contractName = contractData['contract_name'];
              }
            } catch (e) {
              // 조회 실패 시 기존 이름 사용
            }
          }
          
          contractGroups[contractHistoryId] = {
            'contract_history_id': contractHistoryId,
            'contract_name': contractName,
            'current_balance': int.tryParse(bill['bill_balance_after']?.toString() ?? '0') ?? 0,
            'last_transaction': bill,
            'credit_expiry_date': bill['contract_credit_expiry_date'],
            'is_general': contractHistoryId == null,
          };
        }
      }
      
      // 3. 리스트로 변환
      List<Map<String, dynamic>> contractsWithBalanceList = contractGroups.values.toList();

      print('=== 크레딧 탭 데이터 로드 완료 ===');
      print('로드된 계약 수: ${contractsWithBalanceList.length}');
      for (var contract in contractsWithBalanceList) {
        print('  - ${contract['contract_name']}: contract_credit=${contract['contract_credit']}, current_balance=${contract['current_balance']}');
      }

      setState(() {
        contractsWithBalance = contractsWithBalanceList;
        _applyFilters(); // 필터링 적용
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 필터 적용 (만료 여부 및 크레딧 포함 여부)
  void _applyFilters() {
    print('=== 크레딧 탭 필터 적용 시작 ===');
    print('만료 포함: $includeExpired');

    Map<String, List<String>> excludedReasons = {
      '만료': [],
    };
    List<String> included = [];

    filteredContractsWithBalance = contractsWithBalance.where((contract) {
      final contractName = contract['contract_name'] ?? '';
      final currentBalance = ContractValidityChecker.safeParseInt(contract['current_balance']) ?? 0;
      final creditExpiryDate = contract['credit_expiry_date']?.toString();

      // v2_bills 테이블의 모든 데이터는 크레딧 관련이므로 별도 판별 불필요

      // 만료 필터: 잔액이 0이거나 유효기간이 지났으면 만료
      bool isExpired = false;

      // 1. 잔액이 0이면 일단 만료 후보
      if (currentBalance <= 0) {
        isExpired = true;
      }

      // 2. 유효기간 확인 (있는 경우)
      if (creditExpiryDate != null && creditExpiryDate.isNotEmpty) {
        try {
          final expiryDate = DateTime.parse(creditExpiryDate);
          final today = DateTime.now();
          if (expiryDate.isBefore(today)) {
            // 유효기간이 지났으면 무조건 만료
            isExpired = true;
          } else if (currentBalance > 0) {
            // 잔액이 있고 유효기간이 남아있으면 유효
            isExpired = false;
          }
          // 잔액 0이고 유효기간이 남아있어도 만료로 간주 (크레딧은 잔액 중심)
        } catch (e) {
          // 날짜 파싱 실패시 잔액 기준으로만 판단
        }
      }

      if (!includeExpired && isExpired) {
        excludedReasons['만료']!.add('$contractName(잔액$currentBalance, 만료일$creditExpiryDate)');
        return false; // 만료된 계약 제외
      }

      included.add('$contractName(잔액$currentBalance)');
      return true;
    }).toList();

    // 컴팩트 디버그 출력
    print('📊 크레딧 탭 필터링 결과:');
    print('  ✅ 포함: ${included.length}건 ${included.isNotEmpty ? '- ${included.join(", ")}' : ''}');
    print('  ⏰ 만료 제외: ${excludedReasons['만료']!.length}건 ${excludedReasons['만료']!.isNotEmpty ? '- ${excludedReasons['만료']!.join(", ")}' : ''}');
    print('  📈 전체: ${contractsWithBalance.length}건 → ${filteredContractsWithBalance.length}건');

    // 첫 번째 계약을 자동 선택 (필터링 후)
    if (filteredContractsWithBalance.isNotEmpty &&
        (selectedContract == null ||
         !filteredContractsWithBalance.any((c) => c['contract_history_id'] == selectedContract!['contract_history_id']))) {
      selectedContract = filteredContractsWithBalance.first;
      _loadCreditHistory(selectedContract!['contract_history_id']);
    } else if (filteredContractsWithBalance.isEmpty) {
      selectedContract = null;
    }
  }

  // 선택된 계약의 크레딧 내역 조회
  Future<void> _loadCreditHistory(int? contractHistoryId) async {
    try {
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.memberId,
        }
      ];
      
      if (contractHistoryId != null) {
        whereConditions.add({
          'field': 'contract_history_id',
          'operator': '=',
          'value': contractHistoryId,
        });
      } else {
        whereConditions.add({
          'field': 'contract_history_id',
          'operator': 'is',
          'value': null,
        });
      }
      
      final data = await ApiService.getBillsData(
        where: whereConditions,
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ]
      );
      
      setState(() {
        creditHistory = data;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  // v2_bills 데이터 조회를 위한 별도 함수
  Future<List<Map<String, dynamic>>> _getBillsData() async {
    try {
      // ApiService의 getBillsData 메서드 사용
      final data = await ApiService.getBillsData(
        where: [
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ]
      );
      
      return data;
    } catch (e) {
      throw Exception('크레딧 내역 조회 실패: $e');
    }
  }

  // bill 데이터에서 계약명 추출
  String _extractContractName(Map<String, dynamic> bill) {
    // bill_text에서 계약명 추출 시도
    final billText = bill['bill_text'] ?? '';
    
    // bill_type이 '회원권적립'인 경우 bill_text 사용
    if (bill['bill_type'] == '회원권적립' && billText.isNotEmpty) {
      // "회원권명 (크레딧)" 형태에서 회원권명 추출
      final match = RegExp(r'^(.+?)\s*\(').firstMatch(billText);
      if (match != null) {
        return match.group(1)!.trim();
      }
      return billText;
    }
    
    // contract_history_id가 null이면 일반 크레딧
    if (bill['contract_history_id'] == null) {
      return '일반 크레딧';
    }
    
    // 그 외의 경우 계약 ID 표시
    return '계약 #${bill['contract_history_id']}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0원';
    try {
      final intAmount = int.parse(amount.toString());
      final formatter = NumberFormat('#,###');
      return '${formatter.format(intAmount)}원';
    } catch (e) {
      return '${amount}원';
    }
  }

  String _getBillTypeDisplay(String? billType) {
    switch (billType) {
      case '회원권적립':
        return '적립';
      case 'deposit':
        return '적립';
      case '타석이용':
        return '사용';
      default:
        return billType ?? '-';
    }
  }

  Color _getAmountColor(dynamic netAmount) {
    if (netAmount == null) return Colors.black;
    try {
      final amount = int.parse(netAmount.toString());
      if (amount > 0) {
        return Colors.blue;
      } else if (amount < 0) {
        return Colors.red;
      }
    } catch (e) {
      // ignore
    }
    return Colors.black;
  }

  // 수동차감/적립 다이얼로그 표시
  void _showManualCreditDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ManualCreditDialog(
          memberId: widget.memberId,
          contractHistoryId: selectedContract?['contract_history_id'],
          onSuccess: () {
            // 성공 시 크레딧 내역 새로고침
            _loadContractsAndBalances();
          },
        );
      },
    );
  }

  // 상품구매 다이얼로그 표시
  void _showProductPurchaseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductPurchaseDialog(
          memberId: widget.memberId,
          contractHistoryId: selectedContract?['contract_history_id'],
          onSuccess: () {
            // 성공 시 크레딧 내역 새로고침
            _loadContractsAndBalances();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Color(0xFFF8FAFC),
      child: Row(
        children: [
          // 왼쪽 사이드바 - 계약 목록
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 왼쪽: 제목
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '계약목록',
                            style: AppTextStyles.bodyText.copyWith(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      // 오른쪽: 만료 포함 체크박스
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: includeExpired,
                              onChanged: (value) {
                                setState(() {
                                  includeExpired = value ?? false;
                                });
                                _applyFilters();
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '만료 포함',
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'Pretendard',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 계약 리스트
                Expanded(
                  child: filteredContractsWithBalance.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 40,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 12),
                            Text(
                              '크레딧 계약이 없습니다',
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredContractsWithBalance.length,
                        itemBuilder: (context, index) {
                          final contract = filteredContractsWithBalance[index];
                          final isSelected = selectedContract?['contract_history_id'] == contract['contract_history_id'];
                          final isGeneral = contract['is_general'] ?? false;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedContract = contract;
                                _loadCreditHistory(contract['contract_history_id']);
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                  ? (isGeneral ? Color(0xFF6B7280) : Color(0xFFF59E0B)).withOpacity(0.1)
                                  : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                    ? (isGeneral ? Color(0xFF6B7280) : Color(0xFFF59E0B))
                                    : Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isGeneral ? Icons.account_balance_wallet : Icons.credit_card,
                                        size: 16,
                                        color: isSelected 
                                          ? (isGeneral ? Color(0xFF6B7280) : Color(0xFFF59E0B))
                                          : Color(0xFF94A3B8),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          contract['contract_name'] ?? '일반 크레딧',
                                          style: AppTextStyles.bodyTextSmall.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected 
                                              ? Color(0xFF1E293B)
                                              : Color(0xFF475569),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _formatAmount(contract['current_balance']),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w700,
                                      color: isSelected 
                                        ? (isGeneral ? Color(0xFF6B7280) : Color(0xFFF59E0B))
                                        : Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (contract['credit_expiry_date'] != null)
                                    Text(
                                      '유효기간: ${_formatDate(contract['credit_expiry_date'])}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
          
          // 오른쪽 메인 영역
          Expanded(
            child: Column(
              children: [
                // 상단 버튼 영역
                if (selectedContract != null)
                  Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 선택된 계약 정보
                        Icon(
                          (selectedContract?['is_general'] ?? false) 
                            ? Icons.account_balance_wallet 
                            : Icons.credit_card,
                          size: 20,
                          color: (selectedContract?['is_general'] ?? false)
                            ? Color(0xFF6B7280)
                            : Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 8),
                        Text(
                          selectedContract?['contract_name'] ?? '일반 크레딧',
                          style: AppTextStyles.h4.copyWith(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '잔액: ${_formatAmount(selectedContract?['current_balance'] ?? 0)}',
                            style: AppTextStyles.bodyTextSmall.copyWith(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        Spacer(),
                        // 버튼들
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: _showManualCreditDialog,
                            icon: Icon(Icons.edit, size: 16),
                            label: Text(
                              '수동차감/적립',
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6B7280),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: _showProductPurchaseDialog,
                            icon: Icon(Icons.shopping_cart, size: 16),
                            label: Text(
                              '상품구매',
                              style: AppTextStyles.caption.copyWith(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6B7280),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // 테이블 영역
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '오류 발생',
                                style: AppTextStyles.h4.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: AppTextStyles.bodyTextSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF64748B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : filteredContractsWithBalance.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '크레딧 내역이 없습니다',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : creditHistory.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 48,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        '선택된 계약의 거래 내역이 없습니다',
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                          : Column(
                              children: [
                                // 테이블 헤더
                                Container(
                                  padding: EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8.0),
                                      topRight: Radius.circular(8.0),
                                    ),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '날짜',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '구분',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '내용',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '총금액',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '할인',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '차감액',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '잔액',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // 테이블 내용
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: creditHistory.length,
                                    itemBuilder: (context, index) {
                                      final item = creditHistory[index];
                                      return Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                        decoration: BoxDecoration(
                                          color: index % 2 == 0 ? Colors.white : Color(0xFFFAFAFA),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE2E8F0),
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatDate(item['bill_date']),
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Center(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getBillTypeDisplay(item['bill_type']) == '적립'
                                                        ? Color(0xFFDCFDF7)
                                                        : Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    _getBillTypeDisplay(item['bill_type']),
                                                    style: AppTextStyles.caption.copyWith(
                                                      fontFamily: 'Pretendard',
                                                      color: _getBillTypeDisplay(item['bill_type']) == '적립'
                                                          ? Color(0xFF059669)
                                                          : Color(0xFFDC2626),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                item['bill_text'] ?? '-',
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatAmount(item['bill_totalamt']),
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                _formatAmount(item['bill_deduction']),
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatAmount(item['bill_netamt']),
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: _getAmountColor(item['bill_netamt']),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatAmount(item['bill_balance_after']),
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF1E293B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                
                                // 하단 요약 정보
                                if (creditHistory.isNotEmpty)
                                  Container(
                                    padding: EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(8.0),
                                        bottomRight: Radius.circular(8.0),
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                '총적립액',
                                                style: AppTextStyles.caption.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '${_formatAmount(creditHistory.where((item) => (int.tryParse(item['bill_netamt']?.toString() ?? '0') ?? 0) > 0).fold(0, (sum, item) => sum + (int.tryParse(item['bill_netamt']?.toString() ?? '0') ?? 0)))}',
                                                style: AppTextStyles.bodyTextSmall.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF059669),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                '총차감액',
                                                style: AppTextStyles.caption.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '${_formatAmount(creditHistory.where((item) => (int.tryParse(item['bill_netamt']?.toString() ?? '0') ?? 0) < 0).fold(0, (sum, item) => sum + (int.tryParse(item['bill_netamt']?.toString() ?? '0') ?? 0).abs()))}',
                                                style: AppTextStyles.bodyTextSmall.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                '현재잔액',
                                                style: AppTextStyles.caption.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '${creditHistory.isNotEmpty ? _formatAmount(creditHistory.first['bill_balance_after']) : '0원'}',
                                                style: AppTextStyles.bodyTextSmall.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 수동차감/적립 다이얼로그 위젯
class ManualCreditDialog extends StatefulWidget {
  final int memberId;
  final int? contractHistoryId;
  final VoidCallback onSuccess;

  const ManualCreditDialog({
    Key? key,
    required this.memberId,
    this.contractHistoryId,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<ManualCreditDialog> createState() => _ManualCreditDialogState();
}

class _ManualCreditDialogState extends State<ManualCreditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedType = '적립'; // 기본값: 적립
  bool _isLoading = false;

  // 추가 변수들
  int selectedAmount = 0;
  String description = '';
  bool get isDeduction => _selectedType == '차감';

  @override
  void initState() {
    super.initState();
    
    // 컨트롤러 리스너 추가
    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      selectedAmount = int.tryParse(text) ?? 0;
    });
    
    _descriptionController.addListener(() {
      description = _descriptionController.text;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 현재 잔액 조회 (선택된 계약의 잔액)
  Future<int> _getCurrentBalance() async {
    try {
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.memberId,
        }
      ];
      
      // 특정 계약의 잔액 조회
      if (widget.contractHistoryId != null) {
        whereConditions.add({
          'field': 'contract_history_id',
          'operator': '=',
          'value': widget.contractHistoryId,
        });
      } else {
        // 일반 크레딧 (contract_history_id가 null인 경우)
        whereConditions.add({
          'field': 'contract_history_id',
          'operator': 'is',
          'value': null,
        });
      }
      
      final data = await ApiService.getBillsData(
        where: whereConditions,
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ],
        limit: 1,
      );
      
      if (data.isNotEmpty) {
        return int.tryParse(data.first['bill_balance_after']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // 계약의 크레딧 만료일 조회
  Future<String?> _getContractCreditExpiryDate() async {
    if (widget.contractHistoryId == null) return null;
    
    try {
      final data = await ApiService.getBillsData(
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ],
        limit: 1,
      );
      
      if (data.isNotEmpty) {
        return data.first['contract_credit_expiry_date']?.toString();
      }
      return null;
    } catch (e) {
      print('크레딧 만료일 조회 오류: $e');
      return null;
    }
  }

  // 수동차감/적립 처리
  Future<void> _processManualCredit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 잔액 조회
      final currentBalance = await _getCurrentBalance();
      
      // 크레딧 만료일 조회
      final creditExpiryDate = await _getContractCreditExpiryDate();
      
      // 입력된 금액
      final amount = int.parse(_amountController.text.replaceAll(',', ''));
      
      // 차감/적립에 따른 금액 계산
      final billTotalAmt = _selectedType == '적립' ? amount : -amount; // 차감 시 마이너스
      final netAmount = billTotalAmt;
      final newBalance = currentBalance + netAmount;
      
      // 현재 날짜와 타임스탬프
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timestampStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      // v2_bills 테이블에 데이터 추가
      final billData = {
        'member_id': widget.memberId,
        'branch_id': ApiService.getCurrentBranchId(),
        'bill_date': dateStr,
        'bill_type': _selectedType == '적립' ? '수동적립' : '수동차감',
        'bill_text': _descriptionController.text,
        'bill_totalamt': billTotalAmt, // 차감 시 마이너스
        'bill_deduction': 0,
        'bill_netamt': netAmount,
        'bill_balance_before': currentBalance,
        'bill_balance_after': newBalance,
        'bill_timestamp': timestampStr,
        'bill_status': '결제완료',
        'contract_history_id': widget.contractHistoryId,
      };
      
      // 크레딧 만료일이 있으면 추가
      if (creditExpiryDate != null) {
        billData['contract_credit_expiry_date'] = creditExpiryDate;
      }
      
      await ApiService.addBillsData(billData);

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('${_selectedType}이 성공적으로 처리되었습니다.'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
        
        // 다이얼로그 닫기 및 콜백 호출
        Navigator.of(context).pop(true);
        widget.onSuccess();
      }
    } catch (e) {
      // 오류 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('처리 중 오류가 발생했습니다: $e')),
              ],
            ),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 금액 포맷팅
  String _formatAmount(String value) {
    if (value.isEmpty) return '';
    
    final number = int.tryParse(value.replaceAll(',', ''));
    if (number == null) return value;
    
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return BaseContractDialog(
      benefitType: 'credit',
      title: '크레딧 수동처리',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 처리 유형 선택
            Text(
              '처리 유형',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ContractSelectionButton(
                    text: '차감',
                    isSelected: _selectedType == '차감',
                    onTap: () => setState(() => _selectedType = '차감'),
                    benefitType: 'credit',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ContractSelectionButton(
                    text: '적립',
                    isSelected: _selectedType == '적립',
                    onTap: () => setState(() => _selectedType = '적립'),
                    benefitType: 'credit',
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // 금액 입력
            ContractInputField(
              label: '금액',
              hint: '금액을 입력하세요',
              controller: _amountController,
              keyboardType: TextInputType.number,
              isRequired: true,
              onChanged: (value) {
                final formatted = _formatAmount(value);
                if (formatted != value) {
                  _amountController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '금액을 입력해주세요';
                }
                final amount = int.tryParse(value.replaceAll(',', ''));
                if (amount == null || amount <= 0) {
                  return '올바른 금액을 입력해주세요';
                }
                return null;
              },
              suffix: Container(
                padding: EdgeInsets.all(12),
                child: Text(
                  '원',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // 적요 입력
            ContractInputField(
              label: '적요',
              hint: '내용을 입력하세요',
              controller: _descriptionController,
              maxLines: 3,
              isRequired: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '적요를 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        ContractActionButton(
          text: '취소',
          benefitType: 'credit',
          isSecondary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        ContractActionButton(
          text: '확인',
          benefitType: 'credit',
          isLoading: _isLoading,
          onPressed: _processManualCredit,
        ),
      ],
    );
  }
}

// 상품구매 다이얼로그 위젯
class ProductPurchaseDialog extends StatefulWidget {
  final int memberId;
  final int? contractHistoryId;
  final VoidCallback onSuccess;

  const ProductPurchaseDialog({
    Key? key,
    required this.memberId,
    this.contractHistoryId,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<ProductPurchaseDialog> createState() => _ProductPurchaseDialogState();
}

class _ProductPurchaseDialogState extends State<ProductPurchaseDialog> {
  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> categorizedProducts = {};
  String selectedCategory = '';
  Map<String, dynamic>? selectedProduct;
  bool isLoading = true;
  bool isPurchasing = false;
  String? errorMessage;

  // 카테고리 정보 - contract_type 기준으로 3개 카테고리
  final Map<String, Map<String, dynamic>> categoryInfo = {
    '서비스': {
      'name': '서비스',
      'icon': Icons.room_service,
      'color': Color(0xFF8B5CF6),
      'description': '각종 서비스'
    },
    '상품': {
      'name': '상품',
      'icon': Icons.shopping_bag,
      'color': Color(0xFF06B6D4),
      'description': '골프용품 및 기타상품'
    },
    '식음료': {
      'name': '식음료',
      'icon': Icons.local_cafe,
      'color': Color(0xFFEF4444),
      'description': '음료 및 식품'
    },
  };

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // 상품 목록 로드
  Future<void> _loadProducts() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final data = await ApiService.getContractsData(
        where: [
          {
            'field': 'contract_category',
            'operator': '<>',
            'value': '회원권',
          },
          {
            'field': 'contract_status',
            'operator': '=',
            'value': '유효',
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        orderBy: [
          {
            'field': 'contract_type',
            'direction': 'ASC'
          },
          {
            'field': 'contract_name',
            'direction': 'ASC'
          }
        ]
      );

      // contract_type별로 상품 분류
      final Map<String, List<Map<String, dynamic>>> categorized = {};
      for (final product in data) {
        final category = product['contract_type'] ?? '기타';
        if (!categorized.containsKey(category)) {
          categorized[category] = [];
        }
        categorized[category]!.add(product);
      }

      setState(() {
        products = data;
        categorizedProducts = categorized;
        selectedCategory = categorized.keys.isNotEmpty ? categorized.keys.first : '';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 현재 잔액 조회 (선택된 계약의 잔액)
  Future<int> _getCurrentBalance() async {
    try {
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.memberId,
        }
      ];
      
      // 특정 계약의 잔액 조회
      if (widget.contractHistoryId != null) {
        whereConditions.add({
          'field': 'contract_history_id',
          'operator': '=',
          'value': widget.contractHistoryId,
        });
      } else {
        // 일반 크레딧 (contract_history_id가 null인 경우)
        whereConditions.add({
          'field': 'contract_history_id',
          'operator': 'is',
          'value': null,
        });
      }
      
      final data = await ApiService.getBillsData(
        where: whereConditions,
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ],
        limit: 1,
      );
      
      if (data.isNotEmpty) {
        return int.tryParse(data.first['bill_balance_after']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // 계약의 크레딧 만료일 조회
  Future<String?> _getContractCreditExpiryDate() async {
    if (widget.contractHistoryId == null) return null;
    
    try {
      final data = await ApiService.getBillsData(
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC'
          }
        ],
        limit: 1,
      );
      
      if (data.isNotEmpty) {
        return data.first['contract_credit_expiry_date']?.toString();
      }
      return null;
    } catch (e) {
      print('크레딧 만료일 조회 오류: $e');
      return null;
    }
  }

  // 상품 구매 처리
  Future<void> _processPurchase() async {
    if (selectedProduct == null) return;

    setState(() {
      isPurchasing = true;
    });

    try {
      // 현재 잔액 조회
      final currentBalance = await _getCurrentBalance();
      
      // 크레딧 만료일 조회
      final creditExpiryDate = await _getContractCreditExpiryDate();
      
      // 상품 가격 (sell_by_credit_price가 있으면 그것을, 없으면 price 사용)
      final productPrice = int.tryParse(selectedProduct!['sell_by_credit_price']?.toString() ?? '0') ?? 
                          int.tryParse(selectedProduct!['price']?.toString() ?? '0') ?? 0;
      
      // 0원 상품도 허용하되, 음수는 불허
      if (productPrice < 0) {
        throw Exception('상품 가격 정보가 올바르지 않습니다.');
      }

      // 0원이 아닌 경우에만 잔액 확인
      if (productPrice > 0 && currentBalance < productPrice) {
        throw Exception('잔액이 부족합니다. (현재 잔액: ${_formatAmount(currentBalance)}, 필요 금액: ${_formatAmount(productPrice)})');
      }
      
      // 차감 금액 (상품구매는 항상 마이너스)
      final billTotalAmt = -productPrice;
      final netAmount = billTotalAmt;
      final newBalance = currentBalance + netAmount;
      
      // 현재 날짜와 타임스탬프
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timestampStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      // v2_bills 테이블에 데이터 추가
      final billData = {
        'member_id': widget.memberId,
        'branch_id': ApiService.getCurrentBranchId(),
        'bill_date': dateStr,
        'bill_type': '상품구매',
        'bill_text': selectedProduct!['contract_name'] ?? '상품구매',
        'bill_totalamt': billTotalAmt, // 상품구매는 마이너스
        'bill_deduction': 0,
        'bill_netamt': netAmount,
        'bill_balance_before': currentBalance,
        'bill_balance_after': newBalance,
        'bill_timestamp': timestampStr,
        'bill_status': '결제완료',
        'contract_history_id': widget.contractHistoryId,
      };
      
      // 크레딧 만료일이 있으면 추가
      if (creditExpiryDate != null) {
        billData['contract_credit_expiry_date'] = creditExpiryDate;
      }
      
      await ApiService.addBillsData(billData);

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('${selectedProduct!['contract_name']} 구매가 완료되었습니다.'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
        
        // 다이얼로그 닫기 및 콜백 호출
        Navigator.of(context).pop(true);
        widget.onSuccess();
      }
    } catch (e) {
      // 오류 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('구매 중 오류가 발생했습니다: $e')),
              ],
            ),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isPurchasing = false;
        });
      }
    }
  }

  // 금액 포맷팅
  String _formatAmount(dynamic amount) {
    if (amount == null) return '0원';
    try {
      final intAmount = int.parse(amount.toString());
      final formatter = NumberFormat('#,###');
      return '${formatter.format(intAmount)}원';
    } catch (e) {
      return '${amount}원';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseContractDialog(
      benefitType: 'credit',
      title: '상품 구매',
      child: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '상품 목록을 불러오는 중...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '오류 발생',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 현재 잔액 정보
                    FutureBuilder<int>(
                      future: _getCurrentBalance(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ContractInfoCard(
                            title: '현재 크레딧 잔액',
                            content: _formatAmount(snapshot.data!),
                            benefitType: 'credit',
                            icon: Icons.account_balance_wallet,
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                    SizedBox(height: 24),
                    
                    // 카테고리 선택
                    if (categorizedProducts.isNotEmpty) ...[
                      Text(
                        '카테고리',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categorizedProducts.keys.map((category) {
                          final info = categoryInfo[category] ?? {
                            'name': category,
                            'icon': Icons.category,
                            'color': Color(0xFF64748B),
                            'description': category
                          };
                          final isSelected = selectedCategory == category;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategory = category;
                                selectedProduct = null;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFFF59E0B) : Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Color(0xFFF59E0B) : Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    info['icon'],
                                    size: 16,
                                    color: isSelected ? Colors.white : info['color'],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${info['name']} (${categorizedProducts[category]?.length ?? 0})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24),
                    ],
                    
                    // 상품 선택
                    if (selectedCategory.isNotEmpty && categorizedProducts[selectedCategory] != null) ...[
                      Text(
                        '상품 선택',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.all(8),
                          itemCount: categorizedProducts[selectedCategory]!.length,
                          separatorBuilder: (context, index) => SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final product = categorizedProducts[selectedCategory]![index];
                            final isSelected = selectedProduct?['contract_id'] == product['contract_id'];
                            final price = int.tryParse(product['sell_by_credit_price']?.toString() ?? '0') ?? 
                                         int.tryParse(product['price']?.toString() ?? '0') ?? 0;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedProduct = product;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Color(0xFFFFFBEB) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Color(0xFFF59E0B) : Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Color(0xFFF59E0B) : Color(0xFFD1D5DB),
                                          width: 2,
                                        ),
                                        color: isSelected ? Color(0xFFF59E0B) : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 10,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['contract_name'] ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (product['contract_category'] != null)
                                            Text(
                                              product['contract_category'],
                                              style: TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatAmount(price),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFF59E0B),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '카테고리를 선택해주세요',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    // 선택된 상품 정보
                    if (selectedProduct != null) ...[
                      SizedBox(height: 24),
                      ContractInfoCard(
                        title: '선택된 상품',
                        content: selectedProduct!['contract_name'] ?? '',
                        benefitType: 'credit',
                        icon: Icons.shopping_bag,
                      ),
                    ],
                  ],
                ),
      actions: [
        ContractActionButton(
          text: '취소',
          benefitType: 'credit',
          isSecondary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        ContractActionButton(
          text: selectedProduct != null 
              ? '구매하기 (${_formatAmount(int.tryParse(selectedProduct!['sell_by_credit_price']?.toString() ?? '0') ?? int.tryParse(selectedProduct!['price']?.toString() ?? '0') ?? 0)})'
              : '상품을 선택하세요',
          benefitType: 'credit',
          isLoading: isPurchasing,
          onPressed: (selectedProduct == null) ? null : _processPurchase,
        ),
      ],
    );
  }
} 