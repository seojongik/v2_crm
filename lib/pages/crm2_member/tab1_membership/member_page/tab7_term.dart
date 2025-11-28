import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/constants/font_sizes.dart';
import '/services/api_service.dart';

class Tab7TermWidget extends StatefulWidget {
  const Tab7TermWidget({
    super.key,
    required this.memberId,
  });

  final int memberId;

  @override
  State<Tab7TermWidget> createState() => _Tab7TermWidgetState();
}

class _Tab7TermWidgetState extends State<Tab7TermWidget> {
  List<Map<String, dynamic>> termContracts = [];
  List<Map<String, dynamic>> filteredTermContracts = []; // 필터링된 계약 목록
  List<Map<String, dynamic>> termDetails = [];
  bool isLoading = true;
  bool isLoadingDetails = false;
  int? selectedContractHistoryId;
  bool includeExpired = false; // 만료 포함 여부 (디폴트: 제외)

  @override
  void initState() {
    super.initState();
    _loadTermContracts();
  }

  // 홀드 이력 조회
  Future<Map<String, dynamic>> _getHoldHistory(int contractHistoryId) async {
    try {
      print('=== 홀드 이력 조회 시작: contract_history_id = $contractHistoryId ===');

      final data = await ApiService.getDataList(
        table: 'v2_bill_term_hold',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
      );

      print('홀드 조회 결과: ${data.length}개');
      for (var hold in data) {
        print('  홀드: ${hold['term_hold_start']} ~ ${hold['term_hold_end']}, 일수: ${hold['term_add_dates']}');
      }

      int holdCount = data.length;
      int totalHoldDays = 0;

      for (var hold in data) {
        final addDays = (hold['term_add_dates'] as int?) ?? 0;
        totalHoldDays += addDays;
        print('  추가된 일수: $addDays, 누적 총 일수: $totalHoldDays');
      }

      print('최종 홀드 결과: ${holdCount}회 ${totalHoldDays}일');

      return {
        'holdCount': holdCount,
        'totalHoldDays': totalHoldDays,
      };
    } catch (e) {
      print('홀드 이력 조회 오류: $e');
      return {
        'holdCount': 0,
        'totalHoldDays': 0,
      };
    }
  }

  // 기간권 계약 목록 조회 (contract_history_id별로 그룹핑)
  Future<void> _loadTermContracts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // v2_bill_term에서 해당 멤버의 기간권 데이터 조회
      final data = await ApiService.getBillTermData(
        where: [
          {'field': 'member_id', 'operator': '=', 'value': widget.memberId}
        ],
        orderBy: [
          {'field': 'contract_history_id', 'direction': 'DESC'},
          {'field': 'bill_term_id', 'direction': 'DESC'}
        ],
      );

      // contract_history_id별로 그룹핑하고 최신 레코드만 유지
      final Map<int, Map<String, dynamic>> groupedData = {};
      
      for (final item in data) {
        final contractHistoryId = item['contract_history_id'];
        if (contractHistoryId != null && !groupedData.containsKey(contractHistoryId)) {
          groupedData[contractHistoryId] = item;
        }
      }

      print('=== 기간권 탭 데이터 로드 완료 ===');
      print('로드된 계약 수: ${groupedData.values.length}');
      for (var contract in groupedData.values) {
        print('  - ${contract['contract_name'] ?? '기간권'}: 만료일=${contract['contract_term_month_expiry_date']}');
      }

      setState(() {
        termContracts = groupedData.values.toList();
        _applyFilters(); // 필터링 적용
        isLoading = false;
      });
    } catch (e) {
      print('기간권 계약 조회 오류: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('기간권 데이터를 불러오는데 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 필터링 적용
  void _applyFilters() {
    print('=== 기간권 필터링 시작 ===');
    print('includeExpired: $includeExpired');
    print('전체 계약 수: ${termContracts.length}');

    if (includeExpired) {
      filteredTermContracts = termContracts;
      print('만료 포함: 모든 계약 표시 (${filteredTermContracts.length}개)');
    } else {
      filteredTermContracts = termContracts.where((contract) {
        final expiryDateStr = contract['contract_term_month_expiry_date'];

        if (expiryDateStr == null || expiryDateStr.toString().isEmpty) {
          print('  - ${contract['bill_text'] ?? '기간권'}: 만료일 없음 -> 활성');
          return true; // 만료일이 없으면 활성으로 간주
        }

        try {
          final expiryDate = DateTime.parse(expiryDateStr.toString());
          final today = DateTime.now();
          final isExpired = expiryDate.isBefore(today);

          print('  - ${contract['bill_text'] ?? '기간권'}: 만료일=$expiryDateStr -> ${isExpired ? '만료' : '활성'}');

          return !isExpired; // 만료되지 않은 계약만 표시
        } catch (e) {
          print('  - ${contract['bill_text'] ?? '기간권'}: 날짜 파싱 오류 -> 활성');
          return true; // 파싱 오류시 활성으로 간주
        }
      }).toList();

      print('만료 제외: ${filteredTermContracts.length}개 표시');
    }

    print('=== 기간권 필터링 완료 ===');

    // 첫 번째 계약을 자동 선택 (필터링 후)
    if (filteredTermContracts.isNotEmpty &&
        (selectedContractHistoryId == null ||
         !filteredTermContracts.any((c) => c['contract_history_id'] == selectedContractHistoryId))) {
      selectedContractHistoryId = filteredTermContracts.first['contract_history_id'];
      _loadTermDetails(selectedContractHistoryId!);
      print('첫 번째 계약 자동 선택: ${filteredTermContracts.first['bill_text']}');
    } else if (filteredTermContracts.isEmpty) {
      selectedContractHistoryId = null;
      print('필터링된 계약이 없어 선택 초기화');
    }
  }

  // 특정 계약의 상세 기록 조회
  Future<void> _loadTermDetails(int contractHistoryId) async {
    setState(() {
      isLoadingDetails = true;
      selectedContractHistoryId = contractHistoryId;
    });

    try {
      final data = await ApiService.getBillTermData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
        orderBy: [
          {'field': 'bill_term_id', 'direction': 'DESC'}
        ],
      );

      setState(() {
        termDetails = data;
        isLoadingDetails = false;
      });
    } catch (e) {
      print('기간권 상세 조회 오류: $e');
      setState(() {
        isLoadingDetails = false;
      });
    }
  }

  // 홀드 등록 다이얼로그
  Future<void> _showHoldDialog(Map<String, dynamic> contract) async {
    print('=== 홀드 다이얼로그 시작 ===');
    DateTime? holdStartDate;
    DateTime? holdEndDate;
    String holdReason = '';
    int holdDays = 0;
    
    // 기간권 종료일 파싱
    final contractEndDateStr = contract['contract_term_month_expiry_date'];
    DateTime contractEndDate;
    
    try {
      if (contractEndDateStr != null && contractEndDateStr.toString().isNotEmpty) {
        contractEndDate = DateTime.parse(contractEndDateStr.toString());
      } else {
        contractEndDate = DateTime.now().add(Duration(days: 365));
      }
    } catch (e) {
      print('날짜 파싱 오류: $e, 입력값: $contractEndDateStr');
      contractEndDate = DateTime.now().add(Duration(days: 365));
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            print('=== StatefulBuilder 빌드됨 ===');
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                '홀드 등록',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              content: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '계약명: ${contract['bill_text'] ?? ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '기간권 만료일: ${contract['contract_term_month_expiry_date'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 간단한 테스트 버튼
                    ElevatedButton(
                      onPressed: () {
                        print('=== 테스트 버튼 클릭 성공! ===');
                        setDialogState(() {
                          // 상태 변경 테스트
                        });
                      },
                      child: Text('클릭 테스트'),
                    ),
                    SizedBox(height: 16),
                    
                    // 홀드 시작일
                    Text(
                      '홀드 시작일 *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        print('=== 홀드 시작일 버튼 클릭 감지됨 ===');
                        final now = DateTime.now();
                        final maxDate = contractEndDate.isAfter(now) ? contractEndDate : now.add(Duration(days: 365));
                        
                        print('현재 날짜: $now');
                        print('계약 종료일: $contractEndDate');
                        print('최대 날짜: $maxDate');
                        
                        DateTime? picked;
                        try {
                          picked = await showDatePicker(
                            context: context,
                            initialDate: holdStartDate ?? (now.isBefore(maxDate) ? now : maxDate.subtract(Duration(days: 1))),
                            firstDate: now,
                            lastDate: maxDate,
                          );
                          
                          print('선택된 날짜: $picked');
                        } catch (e) {
                          print('날짜 선택 오류: $e');
                        }
                        
                        if (picked != null) {
                          setDialogState(() {
                            holdStartDate = picked!;
                            // 홀드 종료일이 시작일보다 이전이면 초기화
                            if (holdEndDate != null && holdEndDate!.isBefore(picked!)) {
                              holdEndDate = null;
                              holdDays = 0;
                            } else if (holdEndDate != null) {
                              holdDays = holdEndDate!.difference(holdStartDate!).inDays + 1;
                            }
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF0F9FF),
                        foregroundColor: Color(0xFF6B7280),
                        side: BorderSide(color: Color(0xFF3B82F6), width: 2),
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          holdStartDate != null 
                            ? DateFormat('yyyy.MM.dd').format(holdStartDate!)
                            : '날짜 선택 (클릭)',
                          style: TextStyle(
                            fontSize: 14,
                            color: holdStartDate != null ? Color(0xFF6B7280) : Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 홀드 종료일
                    Text(
                      '홀드 종료일 *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: holdStartDate != null ? () async {
                        print('=== 홀드 종료일 버튼 클릭 감지됨 ===');
                        final maxDate = contractEndDate.isAfter(holdStartDate!) ? contractEndDate : holdStartDate!.add(Duration(days: 365));
                        
                        print('시작일: $holdStartDate');
                        print('최대 날짜: $maxDate');
                        
                        DateTime? picked;
                        try {
                          picked = await showDatePicker(
                            context: context,
                            initialDate: holdEndDate ?? holdStartDate!,
                            firstDate: holdStartDate!,
                            lastDate: maxDate,
                          );
                          
                          print('선택된 종료일: $picked');
                        } catch (e) {
                          print('종료일 선택 오류: $e');
                        }
                        if (picked != null) {
                          setDialogState(() {
                            holdEndDate = picked!;
                            holdDays = picked!.difference(holdStartDate!).inDays + 1;
                          });
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: holdStartDate != null ? Colors.white : Color(0xFFF9FAFB),
                        foregroundColor: Color(0xFF6B7280),
                        side: BorderSide(color: holdStartDate != null ? Color(0xFFE2E8F0) : Color(0xFFE5E7EB)),
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          holdEndDate != null 
                            ? DateFormat('yyyy.MM.dd').format(holdEndDate!)
                            : holdStartDate != null ? '날짜 선택 (클릭)' : '시작일을 먼저 선택하세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: holdEndDate != null 
                              ? Color(0xFF6B7280) 
                              : holdStartDate != null 
                                ? Color(0xFF9CA3AF) 
                                : Color(0xFFD1D5DB),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 홀드 일수 표시
                    if (holdDays > 0) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF0369A1).withOpacity(0.3)),
                        ),
                        child: Text(
                          '홀드 기간: $holdDays일',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                    
                    // 홀드 사유
                    Text(
                      '홀드 사유',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      onChanged: (value) {
                        holdReason = value;
                      },
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '홀드 사유를 입력하세요',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: (holdStartDate != null && holdEndDate != null && holdDays > 0)
                    ? () => Navigator.of(context).pop(true)
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    '홀드 등록',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && holdStartDate != null && holdEndDate != null) {
      await _processHoldRegistration(
        contract, 
        holdStartDate!, 
        holdEndDate!, 
        holdReason, 
        holdDays
      );
    }
  }

  // 홀드 등록 처리
  Future<void> _processHoldRegistration(
    Map<String, dynamic> contract, 
    DateTime holdStart, 
    DateTime holdEnd, 
    String reason, 
    int addDays
  ) async {
    try {
      final contractHistoryId = contract['contract_history_id'];
      
      // 1. v2_bill_term_hold 테이블에 홀드 정보 추가
      final holdData = {
        'contract_history_id': contractHistoryId,
        'term_hold_start': DateFormat('yyyy-MM-dd').format(holdStart),
        'term_hold_end': DateFormat('yyyy-MM-dd').format(holdEnd),
        'term_hold_reason': reason,
        'term_add_dates': addDays,
        'staff_id': 1, // 임시로 1 설정
        'term_hold_timestamp': DateTime.now().toIso8601String(),
      };

      final holdResponse = await ApiService.addBillTermHoldData(holdData);
      
      if (holdResponse['success'] == true) {
        // 2. v2_bill_term에 홀드등록 레코드 추가
        final latestTerm = await ApiService.getLatestBillTermByContractHistoryId(contractHistoryId);
        if (latestTerm != null) {
          final originalEndDate = DateTime.parse(latestTerm['contract_term_month_expiry_date']);
          final newEndDate = originalEndDate.add(Duration(days: addDays));
          
          final newTermData = {
            'member_id': contract['member_id'],
            'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'bill_type': '홀드등록',
            'bill_text': contract['bill_text'],
            'bill_term_min': null,
            'bill_timestamp': DateTime.now().toIso8601String(),
            'reservation_id': null,
            'bill_status': '결제완료',
            'contract_history_id': contractHistoryId,
            'contract_term_month_expiry_date': DateFormat('yyyy-MM-dd').format(newEndDate),
            'term_startdate': latestTerm['term_startdate'],
            'term_enddate': DateFormat('yyyy-MM-dd').format(newEndDate),
          };

          final termResponse = await ApiService.addBillTermData(newTermData);
          
          if (termResponse['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('홀드가 등록되었습니다.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
              // 데이터 새로고침
              _loadTermContracts();
              if (selectedContractHistoryId != null) {
                _loadTermDetails(selectedContractHistoryId!);
              }
            }
          }
        }
      }
    } catch (e) {
      print('홀드 등록 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('홀드 등록 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Color(0xFFF8FAFC),
      child: isLoading
        ? Center(child: CircularProgressIndicator())
        : Row(
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
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 20,
                                color: Color(0xFF6B7280),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '기간권 계약',
                                style: AppTextStyles.bodyText.copyWith(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '만료 포함',
                                style: AppTextStyles.caption.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF6B7280),
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(width: 4),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: Checkbox(
                                  value: includeExpired,
                                  onChanged: (value) {
                                    setState(() {
                                      includeExpired = value ?? false;
                                      _applyFilters(); // 필터링 재적용
                                    });
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 계약 리스트
                    Expanded(
                      child: filteredTermContracts.isEmpty
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
                                  termContracts.isEmpty
                                    ? '기간권이 없습니다'
                                    : '표시할 기간권이 없습니다',
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
                            itemCount: filteredTermContracts.length,
                            itemBuilder: (context, index) {
                              final contract = filteredTermContracts[index];
                              final isSelected = selectedContractHistoryId == contract['contract_history_id'];
                              
                              return GestureDetector(
                                onTap: () {
                                  _loadTermDetails(contract['contract_history_id']);
                                },
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                      ? Color(0xFFF59E0B).withOpacity(0.1)
                                      : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected 
                                        ? Color(0xFFF59E0B)
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
                                            Icons.calendar_month,
                                            size: 16,
                                            color: isSelected 
                                              ? Color(0xFFF59E0B)
                                              : Color(0xFF94A3B8),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              contract['bill_text'] ?? '기간권',
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
                                        '기간: ${contract['term_startdate']} ~ ${contract['term_enddate']}',
                                        style: AppTextStyles.caption.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF374151),
                                          fontSize: 11,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      // 홀드 이력 표시를 위한 FutureBuilder
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: _getHoldHistory(contract['contract_history_id']),
                                        builder: (context, snapshot) {
                                          final holdData = snapshot.data ?? {'holdCount': 0, 'totalHoldDays': 0};
                                          final holdCount = holdData['holdCount'] as int;
                                          final totalHoldDays = holdData['totalHoldDays'] as int;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // 홀드 이력 (0이 아닐 때만 표시)
                                              if (holdCount > 0 || totalHoldDays > 0) ...[
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF8B5CF6).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '홀드 ${holdCount}회 ${totalHoldDays}일',
                                                    style: AppTextStyles.caption.copyWith(
                                                      fontFamily: 'Pretendard',
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF8B5CF6),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                              ],
                                              // 만료일 (항상 표시)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFF59E0B).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Color(0xFFF59E0B).withOpacity(0.4),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  '만료일: ${contract['contract_term_month_expiry_date']}',
                                                  style: AppTextStyles.caption.copyWith(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFFF59E0B),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
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
                    if (selectedContractHistoryId != null && termContracts.isNotEmpty)
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
                              Icons.calendar_month,
                              size: 20,
                              color: Color(0xFFF59E0B),
                            ),
                            SizedBox(width: 8),
                            Text(
                              termContracts.firstWhere((c) => c['contract_history_id'] == selectedContractHistoryId, orElse: () => {})['bill_text'] ?? '기간권',
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
                                color: Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '만료일: ${termContracts.firstWhere((c) => c['contract_history_id'] == selectedContractHistoryId, orElse: () => {})['contract_term_month_expiry_date'] ?? ''}',
                                style: AppTextStyles.bodyTextSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            Spacer(),
                            if (termDetails.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final latestContract = termDetails.first;
                                  _showHoldDialog(latestContract);
                                },
                                icon: Icon(Icons.pause_circle, size: 16),
                                label: Text('홀드 등록'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  textStyle: AppTextStyles.bodyTextSmall.copyWith(
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w600,
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
                        child: isLoadingDetails
                          ? Center(child: CircularProgressIndicator())
                          : selectedContractHistoryId == null
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
                                      '계약을 선택하세요',
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : termDetails.isEmpty
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
                                            flex: 3,
                                            child: Text(
                                              '내용',
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
                                              '기간',
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
                                              '만료일',
                                              style: AppTextStyles.formLabel.copyWith(
                                                fontFamily: 'Pretendard',
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF6B7280),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // 테이블 내용
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: termDetails.length,
                                        itemBuilder: (context, index) {
                                          final detail = termDetails[index];
                                          final isHold = detail['bill_type'] == '홀드등록';
                                          
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
                                                  child: Center(
                                                    child: Text(
                                                      detail['bill_date'] ?? '',
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                      ),
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
                                                        color: isHold
                                                            ? Color(0xFFFFF7ED)
                                                            : Color(0xFFDCFDF7),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        detail['bill_type'] ?? '',
                                                        style: AppTextStyles.caption.copyWith(
                                                          fontFamily: 'Pretendard',
                                                          color: isHold
                                                              ? Color(0xFFF59E0B)
                                                              : Color(0xFF059669),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Center(
                                                    child: Text(
                                                      detail['bill_text'] ?? '',
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Center(
                                                    child: Text(
                                                      '${detail['term_startdate']} ~ ${detail['term_enddate']}',
                                                      style: AppTextStyles.cardSubtitle.copyWith(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Center(
                                                    child: Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFFF59E0B).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        detail['contract_term_month_expiry_date'] ?? '',
                                                        style: AppTextStyles.caption.copyWith(
                                                          fontFamily: 'Pretendard',
                                                          color: Color(0xFFF59E0B),
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
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
} 