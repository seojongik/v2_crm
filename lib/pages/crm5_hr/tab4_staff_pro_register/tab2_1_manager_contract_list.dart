import 'package:flutter/material.dart';
import 'dart:math';
import '../../../services/api_service.dart';
import '../../../services/supabase_adapter.dart';
import '/pages/crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract.dart';
import 'package:intl/intl.dart';
import '../../../widgets/scroll_service.dart';

class Tab2ManagerContractListWidget extends StatefulWidget {
  final bool showHeader;
  final Function(VoidCallback)? onToggleFilter;
  final Function(VoidCallback)? onOpenNew;
  
  const Tab2ManagerContractListWidget({
    super.key, 
    this.showHeader = true,
    this.onToggleFilter,
    this.onOpenNew,
  });

  @override
  State<Tab2ManagerContractListWidget> createState() => _Tab2ManagerContractListWidgetState();
}

class _Tab2ManagerContractListWidgetState extends State<Tab2ManagerContractListWidget> {
  // 직원 데이터 (직원별로 그룹화)
  Map<int, List<Map<String, dynamic>>> _managerContractGroups = {};
  bool _isLoading = true;
  bool _showRetiredManagers = false; // 퇴직 직원 포함 여부
  Set<int> _expandedManagerIds = {}; // 펼쳐진 직원들의 ID 집합
  
  @override
  void initState() {
    super.initState();
    _initializeData();
    
    // 콜백 등록
    if (widget.onToggleFilter != null) {
      widget.onToggleFilter!(_toggleRetiredFilter);
    }
    if (widget.onOpenNew != null) {
      widget.onOpenNew!(_openNewManagerContract);
    }
  }

  // 데이터 초기화
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadManagerContractList();
    } catch (e) {
      print('❌ 직원 계약 데이터 로드 실패: $e');
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 직원 계약 리스트 로드 (직원별로 그룹화) - Supabase
  Future<void> _loadManagerContractList() async {
    try {
      // 조회 조건 설정
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        {'field': 'staff_type', 'operator': '=', 'value': '직원'},
      ];

      // 퇴직 직원 포함하지 않는 경우에만 재직 조건 추가
      if (!_showRetiredManagers) {
        whereConditions.add({'field': 'staff_status', 'operator': '=', 'value': '재직'});
      }

      final contractList = await SupabaseAdapter.getData(
        table: 'v2_staff_manager',
        where: whereConditions,
        orderBy: [
          {'field': 'staff_status', 'direction': 'ASC'}, // 재직을 먼저 표시
          {'field': 'manager_id', 'direction': 'ASC'},
          {'field': 'manager_contract_round', 'direction': 'ASC'}
        ],
      );

      // 직원별로 그룹화
      Map<int, List<Map<String, dynamic>>> groupedData = {};
      for (var contract in contractList) {
        final managerId = contract['manager_id'] ?? 0;
        if (managerId > 0) {
          if (!groupedData.containsKey(managerId)) {
            groupedData[managerId] = [];
          }
          groupedData[managerId]!.add(contract);
        }
      }

      setState(() {
        _managerContractGroups = groupedData;
      });

      final statusText = _showRetiredManagers ? '(퇴직 포함)' : '(재직만)';
      print('✅ 직원 계약 리스트 로드 완료 $statusText: ${_managerContractGroups.length}개 직원, 총 ${contractList.length}개 계약');
    } catch (e) {
      print('❌ 직원 계약 리스트 로드 오류: $e');
      setState(() {
        _managerContractGroups = {};
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // 직원 계약 상세 팝업 열기
  void _openManagerContractPopup({Map<String, dynamic>? contractData, bool isNewContract = false, int? managerId, bool isRenewal = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // 화면 크기에 따라 동적으로 조절되지만 최대값을 제한
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final dialogWidth = screenWidth < 1400 ? screenWidth * 0.9 : 1400.0;
        final dialogHeight = screenHeight < 900 ? screenHeight * 0.9 : 900.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            child: Tab2ManagerContract(
              managerData: contractData,
              isNewManagerMode: isNewContract,
              isRenewal: isRenewal,
              onSaved: () {
                Navigator.of(context).pop();
                _loadManagerContractList(); // 목록 새로고침
                
                // 상황에 맞는 성공 메시지 표시
                String successMessage;
                if (isRenewal) {
                  successMessage = '재계약이 등록되었습니다.';
                } else if (isNewContract) {
                  successMessage = '새 직원가 등록되었습니다.';
                } else {
                  successMessage = '계약정보가 저장되었습니다.';
                }
                
                _showSuccessSnackBar(successMessage);
              },
              onCanceled: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  // 재계약 팝업 열기
  void _openRenewManagerContractPopup(int managerId, List<Map<String, dynamic>> contracts) {
    final latestContract = contracts.last; // 가장 최근 계약
    final newContract = Map<String, dynamic>.from(latestContract);
    
    // 기존 계약 종료일 파싱
    DateTime contractStartDate;
    try {
      final existingEndDate = DateTime.parse(latestContract['manager_contract_enddate'] ?? '');
      contractStartDate = existingEndDate.add(Duration(days: 1)); // 기존 계약 종료일 다음날
    } catch (e) {
      contractStartDate = DateTime.now(); // 파싱 실패 시 현재 날짜
    }
    
    // 계약 종료일: 시작일로부터 1년 - 1일 후
    final contractEndDate = contractStartDate.add(Duration(days: 364)); // 365일 - 1일 = 364일
    
    // 새 계약을 위한 설정 (계약기간과 상태만 변경, 나머지는 직전 계약 값 유지)
    newContract['manager_contract_round'] = (latestContract['manager_contract_round'] ?? 0) + 1;
    newContract['manager_contract_startdate'] = DateFormat('yyyy-MM-dd').format(contractStartDate);
    newContract['manager_contract_enddate'] = DateFormat('yyyy-MM-dd').format(contractEndDate);
    newContract['manager_contract_status'] = '활성';
    
    // ID 관련 필드는 새로 생성되도록 제거
    newContract.remove('manager_contract_id');
    newContract.remove('created_at');
    newContract.remove('updated_at');
    
    print('✅ 재계약 데이터 준비 완료: ${newContract['manager_name']} ${newContract['manager_contract_round']}차');
    print('📅 계약기간: ${newContract['manager_contract_startdate']} ~ ${newContract['manager_contract_enddate']}');
    print('📋 복사된 급여설정: 기본급 ${newContract['salary_base']}, 시간급 ${newContract['salary_hour']}, 식대 ${newContract['salary_meal']}');
    
    // 재계약은 기존 직원의 새 계약이므로 isNewContract를 false로 설정하고 isRenewal을 true로 설정
    _openManagerContractPopup(contractData: newContract, isNewContract: false, managerId: managerId, isRenewal: true);
  }

  // 퇴직 등록 다이얼로그
  void _showRetirementDialog(int managerId, List<Map<String, dynamic>> contracts) {
    final managerName = contracts.first['manager_name'] ?? '';
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_off,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '퇴직 등록',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          '$managerName 직원',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '퇴직 등록 시 해당 직원의 모든 계약이 종료 처리됩니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    Text(
                      '퇴직일자',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Color(0xFF6B7280),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Color(0xFF6B7280),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              DateFormat('yyyy년 MM월 dd일').format(selectedDate),
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _processRetirement(managerId, contracts, selectedDate);
                  },
                  child: Text(
                    '퇴직 등록',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEF4444),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 퇴직 처리 - Supabase
  Future<void> _processRetirement(int managerId, List<Map<String, dynamic>> contracts, DateTime retirementDate) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final retirementDateStr = DateFormat('yyyy-MM-dd').format(retirementDate);

      // 해당 직원의 모든 계약을 퇴직 상태로 업데이트
      for (var contract in contracts) {
        final contractId = contract['manager_contract_id'];

        await SupabaseAdapter.updateData(
          table: 'v2_staff_manager',
          where: [
            {'field': 'manager_contract_id', 'operator': '=', 'value': contractId}
          ],
          data: {
            'staff_status': '퇴직',
            'manager_contract_status': '만료',
            'manager_contract_enddate': retirementDateStr,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      // 목록 새로고침
      await _loadManagerContractList();

      _showSuccessSnackBar('퇴직 등록이 완료되었습니다.');

    } catch (e) {
      print('❌ 퇴직 처리 오류: $e');
      _showErrorSnackBar('퇴직 등록에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 가격 포맷팅
  String _formatPrice(int price) {
    final formatter = NumberFormat('#,###');
    return formatter.format(price);
  }

  // 날짜 포맷팅
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // 직원별 계약 테이블 위젯
  Widget _buildManagerContractTable(int managerId, List<Map<String, dynamic>> contracts) {
    final firstContract = contracts.first;
    final managerName = firstContract['manager_name'] ?? '';
    final proPhone = firstContract['manager_phone'] ?? '';
    final proGender = firstContract['manager_gender'] ?? '';
    final staffStatus = firstContract['staff_status'] ?? '재직';
    final isRetired = staffStatus != '재직';
    
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 직원 헤더 정보 - 더 모던한 디자인
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: isRetired 
                  ? LinearGradient(
                      colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Color(0xFF6B7280).withOpacity(0.05), Color(0xFF6B7280).withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: isRetired 
                        ? LinearGradient(
                            colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isRetired ? Color(0xFF9CA3AF) : Color(0xFF3B82F6)).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isRetired ? Icons.person_off_outlined : Icons.person_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            managerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isRetired ? Color(0xFF6B7280) : Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 버튼들
                Row(
                  children: [
                    if (!isRetired && _expandedManagerIds.contains(managerId)) ...[
                      ElevatedButton.icon(
                        onPressed: () => _openRenewManagerContractPopup(managerId, contracts),
                        icon: Icon(Icons.add, size: 12),
                        label: Text(
                          '재계약',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: Size(0, 32),
                        ),
                      ),
                      SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRetirementDialog(managerId, contracts),
                        icon: Icon(Icons.person_remove, size: 12),
                        label: Text(
                          '퇴직등록',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF1F2937),
                          side: BorderSide(color: Color(0xFFEF4444)),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: Size(0, 32),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _toggleManagerExpansion(managerId),
                      icon: Icon(
                        _expandedManagerIds.contains(managerId) 
                            ? Icons.keyboard_arrow_up 
                            : Icons.keyboard_arrow_down, 
                        size: 12
                      ),
                      label: Text(
                        _expandedManagerIds.contains(managerId) ? '접기' : '펼치기',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF1F2937),
                        side: BorderSide(color: Color(0xFF3B82F6)),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 계약 테이블 - ScrollService 사용
          if (_expandedManagerIds.contains(managerId))
            Container(
              margin: EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: LayoutBuilder(
              builder: (context, constraints) {
                // 실제 테이블 컨텐츠에 필요한 최소 너비 계산
                const minColumnWidths = [
                  80.0,   // 차수
                  120.0,  // 시작일
                  120.0,  // 종료일
                  120.0,  // 기본급
                  120.0,  // 시간급
                  120.0,  // 식대
                  100.0,  // 관리
                ];
                final tableWidth = ScrollServiceUtils.calculateTableWidth(minColumnWidths);
                final needsScroll = ScrollServiceUtils.needsScroll(constraints.maxWidth, tableWidth);

                // 디버깅 로그
                ScrollServiceUtils.debugLog('직원 계약', constraints.maxWidth, tableWidth, needsScroll);

                // 테이블 위젯 생성
                final tableWidget = Table(
                  columnWidths: {
                    0: FixedColumnWidth(minColumnWidths[0]),   // 차수
                    1: FixedColumnWidth(minColumnWidths[1]),   // 시작일
                    2: FixedColumnWidth(minColumnWidths[2]),   // 종료일
                    3: FixedColumnWidth(minColumnWidths[3]),   // 기본급
                    4: FixedColumnWidth(minColumnWidths[4]),   // 시간급
                    5: FixedColumnWidth(minColumnWidths[5]),   // 식대
                    6: FixedColumnWidth(minColumnWidths[6]),   // 관리
                  },
                  children: [
                    // 테이블 헤더 - 더 모던한 스타일
                    TableRow(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2),
                        ),
                      ),
                      children: [
                        _buildTableHeaderCell('차수'),
                        _buildTableHeaderCell('시작일'),
                        _buildTableHeaderCell('종료일'),
                        _buildTableHeaderCell('기본급'),
                        _buildTableHeaderCell('시간급'),
                        _buildTableHeaderCell('식대'),
                        _buildTableHeaderCell('관리'),
                      ],
                    ),
                    // 계약 데이터 행들
                    ...contracts.map((contract) => _buildContractRow(contract, isRetired)).toList(),
                  ],
                );

                // ScrollService 적용 여부에 따라 반환
                if (needsScroll) {
                  return Container(
                    height: 300, // 고정 높이 제공
                    child: ScrollService(
                      child: Container(
                        width: tableWidth,
                        child: tableWidget,
                      ),
                      contentWidth: tableWidth,
                      enableScrollbar: true,
                      scrollbarHeight: 8.0,
                      trackColor: Color(0xFFE5E7EB),
                      thumbColor: Color(0xFF6B7280),
                      scrollbarMargin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      sensitivity: 2.0,
                    ),
                  );
                } else {
                  return Container(
                    child: tableWidget,
                  );
                }
              },
              ),
            ),
        ],
      ),
    );
  }

  // 테이블 헤더 셀
  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // 계약 행 생성
  TableRow _buildContractRow(Map<String, dynamic> contract, [bool isRetired = false]) {
    final contractRound = contract['manager_contract_round'] ?? 1;
    final contractType = contract['contract_type'] ?? '';
    final contractStatus = contract['manager_contract_status'] ?? '';
    final startDate = _formatDate(contract['manager_contract_startdate']);
    final endDate = _formatDate(contract['manager_contract_enddate']);
    final baseSalary = contract['salary_base'] ?? 0;
    final hourlyRate = contract['salary_hour'] ?? 0;
    final mealAllowance = contract['salary_meal'] ?? 0;
    
    return TableRow(
      decoration: BoxDecoration(
        color: isRetired ? Color(0xFFFAFAFA) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      children: [
        _buildTableDataCell('${contractRound}차', isRetired: isRetired, isBold: true),
        _buildTableDataCell(startDate, isRetired: isRetired),
        _buildTableDataCell(endDate, isRetired: isRetired),
        _buildTableDataCell(baseSalary > 0 ? '${_formatPrice(baseSalary)}원' : '-', isRetired: isRetired, isPrice: true),
        _buildTableDataCell(hourlyRate > 0 ? '${_formatPrice(hourlyRate)}원' : '-', isRetired: isRetired, isPrice: true),
        _buildTableDataCell(mealAllowance > 0 ? '${_formatPrice(mealAllowance)}원' : '-', isRetired: isRetired, isPrice: true),
        _buildTableActionCell(contract, isRetired),
      ],
    );
  }

  // 테이블 데이터 셀
  Widget _buildTableDataCell(String text, {bool isRetired = false, bool isBold = false, bool isPrice = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          color: isRetired 
              ? Color(0xFF9CA3AF) 
              : isPrice && text != '-'
                  ? Color(0xFF059669)
                  : Color(0xFF374151),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // 상태 셀
  Widget _buildTableStatusCell(String status) {
    Color statusColor;
    Color backgroundColor;
    
    switch (status) {
      case '활성':
        statusColor = Color(0xFF6B7280);
        backgroundColor = Color(0xFFF0FDF4);
        break;
      case '만료':
        statusColor = Color(0xFF6B7280);
        backgroundColor = Color(0xFFFEF2F2);
        break;
      case '중단':
        statusColor = Color(0xFFEA580C);
        backgroundColor = Color(0xFFFFF7ED);
        break;
      default:
        statusColor = Color(0xFF6B7280);
        backgroundColor = Color(0xFFF9FAFB);
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // 액션 셀 (수정 버튼)
  Widget _buildTableActionCell(Map<String, dynamic> contract, [bool isRetired = false]) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: ElevatedButton(
          onPressed: isRetired ? null : () => _openManagerContractPopup(contractData: contract),
          child: Icon(
            Icons.edit_outlined,
            color: isRetired ? Color(0xFF9CA3AF) : Color(0xFFEF4444),
            size: 16,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRetired
                ? Color(0xFFF3F4F6)
                : Colors.white,
            disabledBackgroundColor: Color(0xFFF3F4F6),
            side: BorderSide(
              color: isRetired ? Colors.transparent : Color(0xFFE5E7EB),
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size(60, 36),
            elevation: 0,
            shadowColor: isRetired ? null : Color(0x1A000000),
          ),
        ),
      ),
    );
  }

  // 외부에서 호출할 수 있는 메서드들
  void _toggleRetiredFilter() async {
    setState(() {
      _showRetiredManagers = !_showRetiredManagers;
    });
    await _loadManagerContractList();
  }

  void _openNewManagerContract() {
    _openManagerContractPopup(isNewContract: true);
  }
  
  void _toggleManagerExpansion(int managerId) {
    setState(() {
      if (_expandedManagerIds.contains(managerId)) {
        _expandedManagerIds.remove(managerId);
      } else {
        _expandedManagerIds.add(managerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B7280)),
              ),
              SizedBox(height: 16),
              Text(
                '직원 계약 정보를 불러오는 중...',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget content = Column(
      children: [
        // 헤더 - 모던한 그라데이션 디자인 (조건부 표시)
        if (widget.showHeader)
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6B7280), Color(0xFF6B7280)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF6B7280).withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '직원 계약 관리',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                
                // 필터 토글 버튼
                Container(
                  margin: EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _showRetiredManagers = !_showRetiredManagers;
                      });
                      await _loadManagerContractList();
                    },
                    icon: Icon(
                      _showRetiredManagers ? Icons.visibility : Icons.visibility_off,
                      color: Color(0xFF1F2937),
                      size: 16,
                    ),
                    label: Text(
                      _showRetiredManagers ? '퇴직포함' : '재직만',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Color(0xFF3B82F6)),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // 새 직원 등록 버튼
                ElevatedButton.icon(
                  onPressed: () => _openManagerContractPopup(isNewContract: true),
                  icon: Icon(Icons.person_add_outlined, color: Colors.white, size: 16),
                  label: Text(
                    '새 직원 등록',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        
        // 직원 계약 목록
        Expanded(
          child: _managerContractGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Color(0xFF6B7280).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 64,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        '등록된 직원이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: widget.showHeader ? BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF000000).withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ) : null,
                  margin: widget.showHeader ? EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.zero,
                  child: ListView(
                    padding: widget.showHeader ? EdgeInsets.all(16) : EdgeInsets.zero,
                    children: _managerContractGroups.entries.map((entry) {
                      final managerId = entry.key;
                      final contracts = entry.value;
                      return _buildManagerContractTable(managerId, contracts);
                    }).toList(),
                  ),
                ),
        ),
      ],
    );

    return widget.showHeader 
        ? Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: content,
          )
        : content;
  }
} 

