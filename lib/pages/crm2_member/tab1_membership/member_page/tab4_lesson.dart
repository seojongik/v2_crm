import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'tab2_contract_validity_check.dart';
import 'tab2_contract_lesson_manual.dart';
import 'tab2_contract_expiry_change.dart';
import 'tab2_contract_lesson_pro_change.dart';

class Tab4LessonWidget extends StatefulWidget {
  const Tab4LessonWidget({
    super.key,
    required this.memberId,
  });

  final int memberId;

  @override
  State<Tab4LessonWidget> createState() => _Tab4LessonWidgetState();
}

class _Tab4LessonWidgetState extends State<Tab4LessonWidget> {
  List<Map<String, dynamic>> lessonHistory = [];
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
      // 1. 해당 회원의 모든 LS_countings 데이터 조회하여 contract_history_id별로 그룹핑
      final allLSData = await ApiService.getLSCountingsData(
        where: [
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'LS_counting_id',
            'direction': 'DESC'
          }
        ]
      );

      // 2. contract_history_id별로 그룹핑하여 최신 잔액 추출
      Map<int?, Map<String, dynamic>> contractGroups = {};
      
      for (final ls in allLSData) {
        final contractHistoryId = ls['contract_history_id'];
        
        // contract_history_id가 null이면 제외
        if (contractHistoryId == null) {
          continue;
        }
        
        // 아직 해당 계약이 없으면 추가 (최신 거래가 먼저 오므로 첫 번째가 최신)
        if (!contractGroups.containsKey(contractHistoryId)) {
          // contract_history_id가 있으면 v3_contract_history에서 실제 계약명 조회
          String contractName = '레슨권 #$contractHistoryId';
          try {
            final contractData = await ApiService.getContractHistoryDataById(contractHistoryId);
            if (contractData != null && contractData['contract_name'] != null) {
              contractName = contractData['contract_name'];
            }
          } catch (e) {
            // 조회 실패 시 기본 이름 사용
          }
          
          contractGroups[contractHistoryId] = {
            'contract_history_id': contractHistoryId,
            'contract_name': contractName,
            'current_balance': int.tryParse(ls['LS_balance_min_after']?.toString() ?? '0') ?? 0,
            'last_transaction': ls,
            'ls_expiry_date': ls['LS_expiry_date'],
            'pro_name': ls['pro_name'],
          };
        }
      }
      
      // 3. 리스트로 변환
      List<Map<String, dynamic>> contractsWithBalanceList = contractGroups.values.toList();
      
      print('=== 레슨 탭 데이터 로드 완료 ===');
      print('로드된 계약 수: ${contractsWithBalanceList.length}');
      for (var contract in contractsWithBalanceList) {
        print('  - ${contract['contract_name']}: balance=${contract['current_balance']}, expiry=${contract['expiry_date']}');
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

  // 필터 적용 (만료 여부 - 레슨권 기준)
  void _applyFilters() {
    print('=== 레슨 탭 필터 적용 시작 ===');
    print('만료 포함: $includeExpired');

    Map<String, List<String>> excludedReasons = {
      '만료': [],
    };
    List<String> included = [];

    filteredContractsWithBalance = contractsWithBalance.where((contract) {
      final contractName = contract['contract_name'] ?? '';
      final currentBalance = ContractValidityChecker.safeParseInt(contract['current_balance']) ?? 0;
      final expiryDateStr = contract['ls_expiry_date']?.toString() ?? '';

      // 유효성 판단: 잔액 > 0 AND 만료일이 미래
      final expiryDate = DateTime.tryParse(expiryDateStr);
      final now = DateTime.now();
      final hasBalance = currentBalance > 0;
      final notExpired = expiryDate?.isAfter(now) ?? false;
      final isValid = hasBalance && notExpired;

      // 만료일이 없으면 만료로 간주
      if (expiryDateStr.isEmpty || expiryDate == null) {
        if (!includeExpired) {
          excludedReasons['만료']!.add('$contractName(잔액${currentBalance}분, 만료일 없음)');
          return false; // 만료된 계약 제외
        }
      }

      if (!includeExpired && !isValid) {
        excludedReasons['만료']!.add('$contractName(잔액${currentBalance}분, 만료일$expiryDateStr)');
        return false; // 만료된 계약 제외
      }

      included.add('$contractName(잔액${currentBalance}분)');
      return true;
    }).toList();

    // 컴팩트 디버그 출력
    print('📊 레슨 탭 필터링 결과:');
    print('  ✅ 포함: ${included.length}건 ${included.isNotEmpty ? '- ${included.join(", ")}' : ''}');
    print('  ⏰ 만료 제외: ${excludedReasons['만료']!.length}건 ${excludedReasons['만료']!.isNotEmpty ? '- ${excludedReasons['만료']!.join(", ")}' : ''}');
    print('  📈 전체: ${contractsWithBalance.length}건 → ${filteredContractsWithBalance.length}건');

    // 첫 번째 계약을 자동 선택 (필터링 후)
    if (filteredContractsWithBalance.isNotEmpty &&
        (selectedContract == null ||
         !filteredContractsWithBalance.any((c) => c['contract_history_id'] == selectedContract!['contract_history_id']))) {
      selectedContract = filteredContractsWithBalance.first;
      _loadLessonHistory(selectedContract!['contract_history_id']);
    } else if (filteredContractsWithBalance.isEmpty) {
      selectedContract = null;
    }
  }

  // 선택된 계약의 레슨 내역 조회
  Future<void> _loadLessonHistory(int? contractHistoryId) async {
    if (contractHistoryId == null) return;
    
    try {
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.memberId,
        },
        {
          'field': 'contract_history_id',
          'operator': '=',
          'value': contractHistoryId,
        }
      ];
      
      final allData = await ApiService.getLSCountingsData(
        where: whereConditions,
        orderBy: [
          {
            'field': 'LS_counting_id',
            'direction': 'DESC'
          }
        ]
      );
      
      // 예약취소 제외 필터링
      final filteredData = allData.where((history) {
        final status = history['LS_status']?.toString() ?? '';
        return status != '예약취소';
      }).toList();
      
      setState(() {
        lessonHistory = filteredData;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
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

  String _formatMinutes(dynamic minutes) {
    if (minutes == null) return '0분';
    try {
      final intMinutes = int.parse(minutes.toString());
      return '${intMinutes}분';
    } catch (e) {
      return '${minutes}분';
    }
  }

  // LS_transaction_type에 따른 표시 텍스트
  String _getTransactionTypeDisplay(String? transactionType) {
    switch (transactionType) {
      case '레슨권 구매':
        return '구매';
      case '레슨차감':
        return '차감';
      case '레슨예약':
        return '예약';
      case '수동적립':
        return '적립';
      case '수동차감':
        return '차감';
      default:
        return transactionType ?? '-';
    }
  }

  // 거래 타입에 따른 색상
  Color _getTransactionColor(String? transactionType) {
    if (transactionType == null) return Colors.black;
    
    if (transactionType.contains('구매') || transactionType.contains('적립')) {
      return Colors.blue;
    } else if (transactionType.contains('차감') || transactionType.contains('예약')) {
      return Colors.red;
    }
    return Colors.black;
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
                            Icons.school,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '레슨권 계약',
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
                              '레슨권이 없습니다',
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
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedContract = contract;
                                _loadLessonHistory(contract['contract_history_id']);
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                  ? Color(0xFF3B82F6).withOpacity(0.1)
                                  : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                    ? Color(0xFF3B82F6)
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
                                        Icons.school,
                                        size: 16,
                                        color: isSelected 
                                          ? Color(0xFF3B82F6)
                                          : Color(0xFF94A3B8),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          contract['contract_name'] ?? '레슨권',
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
                                    _formatMinutes(contract['current_balance']),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w700,
                                      color: isSelected 
                                        ? Color(0xFF3B82F6)
                                        : Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (contract['pro_name'] != null)
                                    Text(
                                      '담당: ${contract['pro_name']}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  if (contract['ls_expiry_date'] != null)
                                    Text(
                                      '유효기간: ${_formatDate(contract['ls_expiry_date'])}',
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
                // 상단 정보 영역
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
                          Icons.school,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                        SizedBox(width: 8),
                        Text(
                          selectedContract?['contract_name'] ?? '레슨권',
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
                            color: Color(0xFFDCEFFD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '잔액: ${_formatMinutes(selectedContract?['current_balance'] ?? 0)}',
                            style: AppTextStyles.bodyTextSmall.copyWith(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                        if (selectedContract?['pro_name'] != null) ...[
                          SizedBox(width: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '담당: ${selectedContract!['pro_name']}',
                              style: AppTextStyles.bodyTextSmall.copyWith(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                        Spacer(),
                        // 액션 버튼들
                        Row(
                          children: [
                            SizedBox(
                              height: 36,
                              child: ElevatedButton.icon(
                                onPressed: _showManualLessonDialog,
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
                                onPressed: _showProChangeDialog,
                                icon: Icon(Icons.person_outline, size: 16),
                                label: Text(
                                  '프로변경',
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
                                onPressed: _showExpiryChangeDialog,
                                icon: Icon(Icons.schedule, size: 16),
                                label: Text(
                                  '유효기간 조정',
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
                                          '레슨권 내역이 없습니다',
                                          style: AppTextStyles.bodyText.copyWith(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : lessonHistory.isEmpty
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
                                              '거래 내역이 없습니다',
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
                                                textAlign: TextAlign.center,
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
                                              flex: 2,
                                              child: Text(
                                                '레슨ID',
                                                style: AppTextStyles.formLabel.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '프로',
                                                style: AppTextStyles.formLabel.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '이전잔액',
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
                                                '사용/적립',
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
                                          itemCount: lessonHistory.length,
                                          itemBuilder: (context, index) {
                                            final item = lessonHistory[index];
                                            final transactionType = item['LS_transaction_type'];
                                            final isDeduction = transactionType?.contains('차감') ?? false;
                                            final beforeMin = int.tryParse(item['LS_balance_min_before']?.toString() ?? '0') ?? 0;
                                            final afterMin = int.tryParse(item['LS_balance_min_after']?.toString() ?? '0') ?? 0;
                                            final deltaMin = afterMin - beforeMin;
                                            
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
                                                      _formatDate(item['LS_date']),
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    textAlign: TextAlign.center,
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
                                                          color: !isDeduction
                                                              ? Color(0xFFDCFDF7)
                                                              : Color(0xFFFEF2F2),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          _getTransactionTypeDisplay(transactionType),
                                                          style: AppTextStyles.caption.copyWith(
                                                            fontFamily: 'Pretendard',
                                                            color: !isDeduction
                                                                ? Color(0xFF059669)
                                                                : Color(0xFFDC2626),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      item['LS_id'] ?? '-',
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      item['pro_name'] ?? '-',
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      _formatMinutes(item['LS_balance_min_before']),
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
                                                      '${deltaMin >= 0 ? '+' : '-'}${_formatMinutes(deltaMin.abs())}',
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: deltaMin >= 0 ? Colors.blue : Colors.red,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      textAlign: TextAlign.right,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      _formatMinutes(item['LS_balance_min_after']),
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

  // 수동차감/적립 다이얼로그 표시
  void _showManualLessonDialog() {
    if (selectedContract == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LessonManualDialog(
          contract: selectedContract!,
          onSaved: () {
            _loadContractsAndBalances();
          },
        );
      },
    );
  }

  // 유효기간 조정 다이얼로그 표시
  void _showExpiryChangeDialog() {
    if (selectedContract == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ExpiryChangeDialog(
          contractHistoryId: selectedContract!['contract_history_id'],
          benefitType: 'lesson',
          onSaved: () {
            _loadContractsAndBalances();
          },
        );
      },
    );
  }

  // 프로변경 다이얼로그 표시
  void _showProChangeDialog() {
    if (selectedContract == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LessonProChangeDialog(
          contract: selectedContract!,
          onSaved: () {
            _loadContractsAndBalances();
          },
        );
      },
    );
  }
}