import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '/services/salary_form_service.dart';

class ManagerSalaryDialog extends StatefulWidget {
  final DateTime selectedMonth;
  final String managerName;
  final int managerId;

  const ManagerSalaryDialog({
    Key? key,
    required this.selectedMonth,
    required this.managerName,
    required this.managerId,
  }) : super(key: key);

  @override
  State<ManagerSalaryDialog> createState() => _ManagerSalaryDialogState();
}

class _ManagerSalaryDialogState extends State<ManagerSalaryDialog> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _salaryData = [];
  Map<String, dynamic> _contractInfo = {};
  List<Map<String, dynamic>> _monthlySalaryData = []; // 월별 급여 데이터
  
  late TabController _tabController;
  int _selectedTabIndex = 0;
  
  // 합계 데이터
  double _totalWorkHours = 0.0;
  int _totalMealAllowance = 0;
  int _totalHourlySalary = 0; // 시간급 합계
  int _baseSalary = 0; // 기본급
  
  // 인센티브/기타 컨트롤러
  final TextEditingController _incentiveController = TextEditingController();
  int _incentiveAmount = 0;
  
  // 공제 관련 컨트롤러들
  final TextEditingController _tax1Controller = TextEditingController(); // 소득세 (사업소득세 또는 근로소득세)
  final TextEditingController _tax2Controller = TextEditingController(); // 지방소득세 또는 4대보험료
  final TextEditingController _otherDeductionController = TextEditingController(); // 기타급여공제
  
  int _tax1Amount = 0;
  int _tax2Amount = 0;
  int _otherDeductionAmount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSalaryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _incentiveController.dispose();
    _tax1Controller.dispose();
    _tax2Controller.dispose();
    _otherDeductionController.dispose();
    super.dispose();
  }

  // 급여 데이터 로드
  Future<void> _loadSalaryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadContractInfo();
      await _loadWorkScheduleData();
      await _loadMonthlySalaryData();
      _calculateSalary();
    } catch (e) {
      print('❌ 급여 데이터 로드 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 계약 정보 로드 - Supabase
  Future<void> _loadContractInfo() async {
    final branchId = ApiService.getCurrentBranchId();

    final contractData = await SupabaseAdapter.getData(
      table: 'v2_staff_manager',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'manager_id', 'operator': '=', 'value': widget.managerId.toString()},
        {'field': 'staff_status', 'operator': '=', 'value': '재직'},
      ],
      orderBy: [
        {'field': 'manager_contract_round', 'direction': 'DESC'}
      ],
    );

    if (contractData.isNotEmpty) {
      _contractInfo = contractData.first; // 최신 계약 (가장 큰 manager_contract_round)
      print('✅ 계약 정보 로드 완료: ${_contractInfo['manager_name']}');
    }
  }

  // 월별 급여 데이터 로드 (최근 6개월) - Supabase
  Future<void> _loadMonthlySalaryData() async {
    final branchId = ApiService.getCurrentBranchId();
    _monthlySalaryData.clear();

    // 선택된 월을 기준으로 최근 6개월 데이터 가져오기
    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month - i, 1);
      final year = targetDate.year;
      final month = targetDate.month;

      try {
        final salaryData = await SupabaseAdapter.getData(
          table: 'v2_salary_manager',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'manager_id', 'operator': '=', 'value': widget.managerId.toString()},
            {'field': 'year', 'operator': '=', 'value': year.toString()},
            {'field': 'month', 'operator': '=', 'value': month.toString()},
          ],
        );

        if (salaryData.isNotEmpty) {
          final salaryRecord = salaryData[0];
          _monthlySalaryData.add({
            'year': year,
            'month': month,
            'salary_base': int.tryParse(salaryRecord['salary_base']?.toString() ?? '0') ?? 0,
            'salary_hour': int.tryParse(salaryRecord['salary_hour']?.toString() ?? '0') ?? 0,
            'salary_total': int.tryParse(salaryRecord['salary_total']?.toString() ?? '0') ?? 0,
            'deduction_sum': int.tryParse(salaryRecord['deduction_sum']?.toString() ?? '0') ?? 0,
            'salary_net': int.tryParse(salaryRecord['salary_net']?.toString() ?? '0') ?? 0,
            'salary_status': salaryRecord['salary_status'] ?? '',
            'business_income_tax': int.tryParse(salaryRecord['business_income_tax']?.toString() ?? '0') ?? 0,
            'local_tax': int.tryParse(salaryRecord['local_tax']?.toString() ?? '0') ?? 0,
            'income_tax': int.tryParse(salaryRecord['income_tax']?.toString() ?? '0') ?? 0,
            'four_insure': int.tryParse(salaryRecord['four_insure']?.toString() ?? '0') ?? 0,
            'other_deduction': int.tryParse(salaryRecord['other_deduction']?.toString() ?? '0') ?? 0,
          });
        } else {
          // 데이터가 없는 경우 빈 레코드 추가 (해당 월에 급여 정산이 없음을 표시)
          _monthlySalaryData.add({
            'year': year,
            'month': month,
            'salary_base': 0,
            'salary_hour': 0,
            'salary_total': 0,
            'deduction_sum': 0,
            'salary_net': 0,
            'salary_status': '미정산',
            'business_income_tax': 0,
            'local_tax': 0,
            'income_tax': 0,
            'four_insure': 0,
            'other_deduction': 0,
          });
        }
      } catch (e) {
        print('❌ ${year}년 ${month}월 급여 데이터 로드 실패: $e');
        // 오류가 발생한 경우에도 빈 레코드 추가
        _monthlySalaryData.add({
          'year': year,
          'month': month,
          'salary_base': 0,
          'salary_hour': 0,
          'salary_total': 0,
          'deduction_sum': 0,
          'salary_net': 0,
          'salary_status': '오류',
          'business_income_tax': 0,
          'local_tax': 0,
          'income_tax': 0,
          'four_insure': 0,
          'other_deduction': 0,
        });
      }
    }

    print('✅ 월별 급여 데이터 로드 완료 - ${_monthlySalaryData.length}개월');
  }

  // 근무 스케줄 데이터 로드 - Supabase
  Future<void> _loadWorkScheduleData() async {
    final branchId = ApiService.getCurrentBranchId();
    final firstDay = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    final lastDay = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);

    final firstDateStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final lastDateStr = DateFormat('yyyy-MM-dd').format(lastDay);

    final scheduleData = await SupabaseAdapter.getData(
      table: 'v2_schedule_adjusted_manager',
      where: [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'manager_name', 'operator': '=', 'value': widget.managerName},
        {'field': 'scheduled_date', 'operator': '>=', 'value': firstDateStr},
        {'field': 'scheduled_date', 'operator': '<=', 'value': lastDateStr},
      ],
      orderBy: [
        {'field': 'scheduled_date', 'direction': 'ASC'}
      ],
    );

    _salaryData.clear();

    for (var schedule in scheduleData) {
      final dateStr = schedule['scheduled_date'];
      final isDayOff = schedule['is_day_off'] == '휴무';

      if (!isDayOff) {
        final workStart = schedule['work_start'] ?? '';
        final workEnd = schedule['work_end'] ?? '';

        if (workStart.isNotEmpty && workEnd.isNotEmpty) {
          final workHours = _calculateWorkHours(workStart, workEnd);

          _salaryData.add({
            'date': dateStr,
            'workStart': workStart,
            'workEnd': workEnd,
            'workHours': workHours,
          });
        }
      }
    }

    print('✅ 근무 스케줄 데이터 로드 완료 - ${_salaryData.length}일 근무');
  }

  // 근무시간 계산 (시간 단위로 반환)
  double _calculateWorkHours(String startTime, String endTime) {
    try {
      final start = TimeOfDay(
        hour: int.parse(startTime.split(':')[0]),
        minute: int.parse(startTime.split(':')[1]),
      );
      final end = TimeOfDay(
        hour: int.parse(endTime.split(':')[0]),
        minute: int.parse(endTime.split(':')[1]),
      );
      
      int startMinutes = start.hour * 60 + start.minute;
      int endMinutes = end.hour * 60 + end.minute;
      
      // 다음날로 넘어가는 경우 처리
      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }
      
      int workMinutes = endMinutes - startMinutes;
      return workMinutes / 60.0; // 시간 단위로 반환
    } catch (e) {
      print('❌ 근무시간 계산 오류: $e');
      return 0.0;
    }
  }

  // 급여 계산
  void _calculateSalary() {
    _totalWorkHours = 0.0;
    _totalMealAllowance = 0;
    _totalHourlySalary = 0;

    final salaryHour = int.tryParse(_contractInfo['salary_hour']?.toString() ?? '0') ?? 0;
    final salaryMeal = int.tryParse(_contractInfo['salary_meal']?.toString() ?? '0') ?? 0;
    final mealMinimumHours = double.tryParse(_contractInfo['salary_meal_minimum_hours']?.toString() ?? '0') ?? 0.0;
    
    // 기본급 설정
    _baseSalary = int.tryParse(_contractInfo['salary_base']?.toString() ?? '0') ?? 0;

    for (var dayData in _salaryData) {
      final workHours = dayData['workHours'] as double;
      _totalWorkHours += workHours;
      
      // 식대 계산 (최소 근무시간 이상인 경우)
      if (workHours >= mealMinimumHours) {
        _totalMealAllowance += salaryMeal;
        dayData['mealAllowance'] = salaryMeal;
      } else {
        dayData['mealAllowance'] = 0;
      }
      
      // 일별 시간급 계산
      final dailySalary = (workHours * salaryHour).round();
      dayData['salary'] = dailySalary;
      _totalHourlySalary += dailySalary;
    }
    
    print('✅ 급여 계산 완료 - 총 근무시간: ${_totalWorkHours.toStringAsFixed(1)}시간, 시간급+식대: ${NumberFormat('#,###').format(_totalHourlySalary + _totalMealAllowance)}원, 기본급: ${NumberFormat('#,###').format(_baseSalary)}원');
  }
  
  // 총 급여 계산
  int get _totalSalary {
    return _totalHourlySalary + _totalMealAllowance + _baseSalary + _incentiveAmount;
  }
  
  // 인센티브 변경 처리
  void _onIncentiveChanged(String value) {
    setState(() {
      _incentiveAmount = int.tryParse(value.replaceAll(',', '')) ?? 0;
    });
  }
  
  // 공제 항목 변경 처리
  void _onTax1Changed(String value) {
    setState(() {
      _tax1Amount = int.tryParse(value.replaceAll(',', '')) ?? 0;
    });
  }
  
  void _onTax2Changed(String value) {
    setState(() {
      _tax2Amount = int.tryParse(value.replaceAll(',', '')) ?? 0;
    });
  }
  
  void _onOtherDeductionChanged(String value) {
    setState(() {
      _otherDeductionAmount = int.tryParse(value.replaceAll(',', '')) ?? 0;
    });
  }
  
  // 총 공제액 계산
  int get _totalDeduction {
    return _tax1Amount + _tax2Amount + _otherDeductionAmount;
  }
  
  // 실 지급액 계산
  int get _netSalary {
    return _totalSalary - _totalDeduction;
  }
  
  // 계약 타입 확인
  bool get _isFreelancer {
    final contractType = _contractInfo['contract_type']?.toString() ?? '';
    return contractType.contains('프리랜서');
  }
  
  // 공제 항목 라벨 가져오기
  String get _tax1Label {
    return _isFreelancer ? '사업소득세' : '근로소득세';
  }
  
  String get _tax2Label {
    return _isFreelancer ? '지방소득세' : '4대보험료';
  }

  @override
  Widget build(BuildContext context) {
    // 레슨 급여와 동일한 다이얼로그 크기 설정
    const double dialogWidth = 900; // 레슨 급여와 동일한 고정 너비
    final double dialogHeight = MediaQuery.of(context).size.height * 0.85;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SalaryFormService.largeRadius),
        ),
        child: Column(
          children: [
            // 헤더
            SalaryFormService.buildDialogHeader(
              title: '급여 정산',
              subtitle: '${widget.managerName} 매니저 (${SalaryFormService.formatDate(widget.selectedMonth, format: 'yyyy년 M월')})',
              onClose: () => Navigator.of(context).pop(),
              isLoading: _isLoading,
            ),

            // 월 네비게이션
            SalaryFormService.buildMonthNavigation(
              selectedMonth: widget.selectedMonth,
              onMonthChanged: (newMonth) {
                // 월 변경 로직 추후 구현
              },
            ),

            // 탭바
            SalaryFormService.buildTabBar(
              tabController: _tabController,
              tabs: [
                TabItem(label: '월별 집계', icon: Icons.calendar_view_month),
                TabItem(label: '일자별 현황', icon: Icons.calendar_today),
                TabItem(label: '급여 정산', icon: Icons.calculate),
              ],
              onTabChanged: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
            ),

            SizedBox(height: 16),
            
            // 탭뷰 콘텐츠 영역
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 월별 집계 탭
                  _buildMonthlySummaryTab(),
                  // 일자별 현황 탭  
                  _buildDailyDetailsTab(),
                  // 급여 정산 탭
                  _buildSalarySettlementTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 월별 집계 탭 빌드
  Widget _buildMonthlySummaryTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
            SizedBox(height: 16),
            Text(
              '급여 데이터를 불러오는 중...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_monthlySalaryData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '월별 급여 데이터가 없습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // 월별 급여 집계 테이블
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // 테이블 헤더
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '월',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '기본급',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '시간급',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '총급여',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '공제액',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '실지급액',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '상태',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 테이블 데이터
                  Expanded(
                    child: ListView.builder(
                      itemCount: _monthlySalaryData.length,
                      itemBuilder: (context, index) {
                        final monthlyData = _monthlySalaryData[index];
                        final isCurrentMonth = monthlyData['year'] == widget.selectedMonth.year && 
                                               monthlyData['month'] == widget.selectedMonth.month;
                        
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == _monthlySalaryData.length - 1 
                                    ? Colors.transparent 
                                    : Color(0xFFE5E7EB), 
                                width: 1
                              ),
                            ),
                            color: isCurrentMonth 
                                ? Color(0xFFEEF2FF) 
                                : (index % 2 == 0 ? Colors.white : Color(0xFFFAFAFA)),
                          ),
                          child: Row(
                            children: [
                              // 월
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${monthlyData['year']}.${monthlyData['month'].toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrentMonth ? Color(0xFF3B82F6) : Color(0xFF374151),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 기본급
                              Expanded(
                                flex: 2,
                                child: Text(
                                  monthlyData['salary_base'] > 0 
                                      ? '${NumberFormat('#,###').format(monthlyData['salary_base'])}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF374151),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 시간급
                              Expanded(
                                flex: 2,
                                child: Text(
                                  monthlyData['salary_hour'] > 0 
                                      ? '${NumberFormat('#,###').format(monthlyData['salary_hour'])}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF10B981),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 총급여
                              Expanded(
                                flex: 2,
                                child: Text(
                                  monthlyData['salary_total'] > 0 
                                      ? '${NumberFormat('#,###').format(monthlyData['salary_total'])}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 공제액
                              Expanded(
                                flex: 2,
                                child: Text(
                                  monthlyData['deduction_sum'] > 0 
                                      ? '${NumberFormat('#,###').format(monthlyData['deduction_sum'])}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFEF4444),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 실지급액
                              Expanded(
                                flex: 2,
                                child: Text(
                                  monthlyData['salary_net'] > 0 
                                      ? '${NumberFormat('#,###').format(monthlyData['salary_net'])}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E40AF),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 상태
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(monthlyData['salary_status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(monthlyData['salary_status']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
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
          
          SizedBox(height: 20),
          
          // 집계 요약
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFBAE6FD)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '총 집계 개월',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_monthlySalaryData.where((data) => data['salary_status'] != '미정산' && data['salary_status'] != '오류').length}개월',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Color(0xFFBAE6FD),
                ),
                Column(
                  children: [
                    Text(
                      '평균 실지급액',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,###').format(_getAverageNetSalary())}원',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Color(0xFFBAE6FD),
                ),
                Column(
                  children: [
                    Text(
                      '총 누적 급여',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,###').format(_getTotalSalary())}원',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 요약 테이블 행 빌더
  Widget _buildSummaryRow(String label, int amount, Color color, {bool isBold = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${NumberFormat('#,###').format(amount)}원',
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // 급여 상태별 색상 반환
  Color _getStatusColor(String status) {
    switch (status) {
      case '제출완료':
        return Color(0xFF10B981); // 초록색
      case '확정':
        return Color(0xFF3B82F6); // 파랑색
      case '미정산':
        return Color(0xFF6B7280); // 회색
      case '오류':
        return Color(0xFFEF4444); // 빨간색
      default:
        return Color(0xFF6B7280); // 기본 회색
    }
  }

  // 급여 상태별 표시 텍스트 반환
  String _getStatusText(String status) {
    switch (status) {
      case '제출완료':
        return '제출';
      case '확정':
        return '확정';
      case '미정산':
        return '미정산';
      case '오류':
        return '오류';
      default:
        return status.isEmpty ? '미정산' : status;
    }
  }

  // 평균 실지급액 계산
  int _getAverageNetSalary() {
    final validData = _monthlySalaryData.where(
      (data) => data['salary_status'] != '미정산' && 
               data['salary_status'] != '오류' && 
               data['salary_net'] > 0
    ).toList();
    
    if (validData.isEmpty) return 0;
    
    final total = validData.fold<int>(0, (sum, data) => sum + (data['salary_net'] as int));
    return (total / validData.length).round();
  }

  // 총 누적 급여 계산
  int _getTotalSalary() {
    return _monthlySalaryData.fold<int>(0, (sum, data) {
      if (data['salary_status'] != '미정산' && data['salary_status'] != '오류') {
        return sum + (data['salary_net'] as int);
      }
      return sum;
    });
  }

  // 일자별 현황 탭 빌드  
  Widget _buildDailyDetailsTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
            SizedBox(height: 16),
            Text(
              '급여 데이터를 불러오는 중...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_salaryData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '해당 월에 근무 기록이 없습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // 일자별 상세 테이블 (월별 집계와 동일한 구조)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // 테이블 헤더
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '일자',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '근무시간',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '시급',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '식대',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '일급여',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 테이블 데이터 (합계 행 제외)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _salaryData.length,
                      itemBuilder: (context, index) {
                        final dayData = _salaryData[index];
                        final salaryHour = int.tryParse(_contractInfo['salary_hour']?.toString() ?? '0') ?? 0;
                        final workHours = dayData['workHours'] as double;
                        final mealAllowance = dayData['mealAllowance'] as int;
                        final dailySalary = (workHours * salaryHour).toInt() + mealAllowance;
                        
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index == _salaryData.length - 1
                                    ? Colors.transparent
                                    : Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  dayData['date'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${workHours.toStringAsFixed(1)}시간',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${NumberFormat('#,###').format((workHours * salaryHour).toInt())}원',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${NumberFormat('#,###').format(mealAllowance)}원',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${NumberFormat('#,###').format(dailySalary)}원',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1F2937),
                                    fontWeight: FontWeight.bold,
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
    );
  }

  // 급여 정산 탭 빌드 (레슨비 정산과 완전히 동일한 스타일)
  Widget _buildSalarySettlementTab() {
    if (_isLoading) {
      return SalaryFormService.buildLoadingIndicator(message: '급여 데이터를 불러오는 중...');
    }

    if (_salaryData.isEmpty) {
      return SalaryFormService.buildEmptyState(message: '해당 월에 근무 기록이 없습니다.');
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withOpacity(0.05),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀
            Row(
              children: [
                Icon(Icons.account_balance_wallet, 
                     color: Color(0xFF8B5CF6), size: 20),
                SizedBox(width: 8),
                Text(
                  '급여 정산 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // 기본급
            _buildSalaryInfoRow(
              '기본급',
              _baseSalary == 0 ? '-' : '${NumberFormat('#,###').format(_baseSalary)}원',
              Color(0xFF374151),
            ),
            SizedBox(height: 16),
            
            // 레슨비(인센티브)
            _buildSalaryInfoRow(
              '레슨비(인센티브)',
              _totalHourlySalary + _totalMealAllowance == 0 ? '-' : '${NumberFormat('#,###').format(_totalHourlySalary + _totalMealAllowance)}원',
              Color(0xFF059669),
            ),
            
            SizedBox(height: 16),
            Container(
              height: 1,
              color: Color(0xFFE5E7EB),
            ),
            SizedBox(height: 16),
            
            // 총 급여
            _buildSalaryInfoRow(
              '총 급여',
              '${NumberFormat('#,###').format(_totalSalary)}원',
              Color(0xFF8B5CF6),
              isBold: true,
              fontSize: 16,
            ),
            
            SizedBox(height: 16),
            Container(
              height: 1,
              color: Color(0xFFE5E7EB),
            ),
            SizedBox(height: 16),
            
            // 공제 항목 타이틀과 계약 타입
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '공제 항목',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFreelancer ? Color(0xFFFEF3C7) : Color(0xFFDDD6FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '계약 타입: ${_isFreelancer ? '프리랜서' : '고용(4대보험)'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isFreelancer ? Color(0xFF92400E) : Color(0xFF5B21B6),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // 계약 타입별 세금 입력 필드
            _buildTaxInputFieldsWithoutTypeDisplay(),
            
            SizedBox(height: 16),
            Container(
              height: 1,
              color: Color(0xFFE5E7EB),
            ),
            SizedBox(height: 16),
            
            // 총 공제액
            _buildSalaryInfoRow(
              '총 공제액',
              '${NumberFormat('#,###').format(_totalDeduction)}원',
              Color(0xFFEF4444),
              isBold: true,
            ),
            SizedBox(height: 16),
            
            // 실지급액
            _buildSalaryInfoRow(
              '실지급액',
              '${NumberFormat('#,###').format(_netSalary)}원',
              Color(0xFF10B981),
              isBold: true,
              fontSize: 16,
            ),
            
            SizedBox(height: 16),
            
            // 확정 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmSalary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '급여 정산 제출',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 급여 정보 섹션 (레슨비 정산과 동일)
  Widget _buildSalaryInfoRow(
    String label, 
    String value, 
    Color valueColor, 
    {bool isBold = false, double fontSize = 14}
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label :',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  // 계약 타입 표시 없는 세금 입력 필드 빌더 (레슨비 정산과 동일)
  Widget _buildTaxInputFieldsWithoutTypeDisplay() {
    bool isFreelancer = _isFreelancer;
    
    return Column(
      children: [
        if (isFreelancer) ...[
          // 프리랜서: 사업소득세, 지방소득세
          _buildTaxInputField('사업소득세', _tax1Controller),
          SizedBox(height: 10),
          _buildTaxInputField('지방소득세', _tax2Controller),
        ] else ...[
          // 고용(4대보험): 근로소득세, 4대보험료
          _buildTaxInputField('근로소득세', _tax1Controller),
          SizedBox(height: 10),
          _buildTaxInputField('4대보험료', _tax2Controller),
        ],
        SizedBox(height: 10),
        // 공통: 기타급여공제
        _buildTaxInputField('기타급여공제', _otherDeductionController),
      ],
    );
  }
  
  // 개별 세금 입력 필드 (레슨비 정산과 동일)
  Widget _buildTaxInputField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2),
                ),
                suffixText: '원',
                suffixStyle: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              onChanged: (value) {
                if (controller == _tax1Controller) {
                  _onTax1Changed(value);
                } else if (controller == _tax2Controller) {
                  _onTax2Changed(value);
                } else if (controller == _otherDeductionController) {
                  _onOtherDeductionChanged(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // 흰색 텍스트 라벨 행 빌더 (보라색 카드 내부용) - 사용 안함, 호환성을 위해 유지
  Widget _buildWhiteLabelRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }


  // 급여정산확정 메서드
  Future<void> _confirmSalary() async {
    try {
      final salaryData = {
        'manager_id': widget.managerId.toString(),
        'manager_name': widget.managerName,
        'year': widget.selectedMonth.year.toString(),
        'month': widget.selectedMonth.month.toString(),
        'salary_status': '제출완료',
        'salary_base': _baseSalary.toString(),
        'salary_hour': (_totalHourlySalary + _totalMealAllowance).toString(),
        'salary_total': _totalSalary.toString(),
        'business_income_tax': _isFreelancer ? _tax1Amount.toString() : '0',
        'local_tax': _isFreelancer ? _tax2Amount.toString() : '0',
        'income_tax': _isFreelancer ? '0' : _tax1Amount.toString(),
        'four_insure': _isFreelancer ? '0' : _tax2Amount.toString(),
        'other_deduction': _otherDeductionAmount.toString(),
        'deduction_sum': _totalDeduction.toString(),
        'salary_net': _netSalary.toString(),
      };

      final whereClause = [
        {'field': 'manager_id', 'operator': '=', 'value': widget.managerId.toString()},
        {'field': 'year', 'operator': '=', 'value': widget.selectedMonth.year.toString()},
        {'field': 'month', 'operator': '=', 'value': widget.selectedMonth.month.toString()},
      ];

      // 기존 데이터 확인
      final existing = await SupabaseAdapter.getData(
        table: 'v2_salary_manager',
        where: whereClause,
      );

      if (existing.isNotEmpty) {
        // 기존 데이터가 있으면 업데이트
        await SupabaseAdapter.updateData(
          table: 'v2_salary_manager',
          data: salaryData,
          where: whereClause,
        );
      } else {
        // 기존 데이터가 없으면 추가
        await SupabaseAdapter.addData(
          table: 'v2_salary_manager',
          data: salaryData,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('급여 정산이 성공적으로 제출되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      print('급여 정산 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('급여 정산 중 오류가 발생했습니다.')),
      );
    }
  }
}

// 급여조회 기능을 위한 헬퍼 클래스
class SalaryHelper {
  // 급여조회 다이얼로그 표시
  static Future<void> showSalaryDialog(BuildContext context, {
    required DateTime selectedMonth,
    required String managerName,
    required int managerId,
  }) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ManagerSalaryDialog(
          selectedMonth: selectedMonth,
          managerName: managerName,
          managerId: managerId,
        );
      },
    );
  }
}
