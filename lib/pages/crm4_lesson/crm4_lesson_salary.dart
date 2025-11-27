import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/lesson_api_service.dart';
import '../../services/api_service.dart';
import '../../services/salary_form_service.dart';
import 'package:flutter/foundation.dart';

class LessonFeeSettlementDialog extends StatefulWidget {
  final int? proId;
  final String proName;

  const LessonFeeSettlementDialog({
    super.key,
    required this.proId,
    required this.proName,
  });

  @override
  State<LessonFeeSettlementDialog> createState() => _LessonFeeSettlementDialogState();
}

class _LessonFeeSettlementDialogState extends State<LessonFeeSettlementDialog> with SingleTickerProviderStateMixin {
  DateTime selectedMonth = DateTime.now();
  Map<String, dynamic> monthlyStats = {};
  List<Map<String, dynamic>> dailyStats = [];
  Map<String, dynamic>? contractInfo;
  bool isLoading = true;
  
  late TabController _tabController;
  int _selectedTabIndex = 0;
  
  // 세금 입력 컨트롤러
  final TextEditingController _fourInsureController = TextEditingController(text: '0');
  final TextEditingController _incomeTaxController = TextEditingController(text: '0');
  final TextEditingController _businessIncomeTaxController = TextEditingController(text: '0');
  final TextEditingController _localTaxController = TextEditingController(text: '0');
  final TextEditingController _otherDeductionController = TextEditingController(text: '0');
  
  static const double COL_WIDTH_DATE = 110;
  static const double COL_WIDTH_UNCONFIRMED = 75;
  static const double COL_WIDTH_LESSON = 75;
  static const double COL_WIDTH_EVENT = 75;
  static const double COL_WIDTH_PROMO = 75;
  static const double COL_WIDTH_NOSHOW = 75;
  static const double COL_WIDTH_REFUND = 75;
  static const double COL_WIDTH_TOTAL = 80;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettlementData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _fourInsureController.dispose();
    _incomeTaxController.dispose();
    _businessIncomeTaxController.dispose();
    _localTaxController.dispose();
    _otherDeductionController.dispose();
    super.dispose();
  }

  Future<void> _loadSettlementData() async {
    if (widget.proId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) return;

      final monthlyData = await LessonApiService.getLessonFeeMonthlyStats(
        branchId: currentBranchId,
        proId: widget.proId!,
        targetMonth: selectedMonth,
      );

      final dailyData = await LessonApiService.getLessonFeeDailyStats(
        branchId: currentBranchId,
        proId: widget.proId!,
        targetMonth: selectedMonth,
      );

      final contractData = await LessonApiService.getProContractInfo(
        branchId: currentBranchId,
        proId: widget.proId!,
        targetMonth: selectedMonth,
      );

      // 저장된 급여 정보 불러오기
      final salaryData = await LessonApiService.getSalaryInfo(
        branchId: currentBranchId,
        proId: widget.proId!,
        year: selectedMonth.year,
        month: selectedMonth.month,
      );

      setState(() {
        monthlyStats = monthlyData ?? {};
        dailyStats = dailyData ?? [];
        contractInfo = contractData;
        
        // 저장된 데이터가 있으면 컨트롤러에 설정
        if (salaryData != null) {
          _fourInsureController.text = (salaryData['four_insure'] ?? 0).toString();
          _incomeTaxController.text = (salaryData['income_tax'] ?? 0).toString();
          _businessIncomeTaxController.text = (salaryData['business_income_tax'] ?? 0).toString();
          _localTaxController.text = (salaryData['local_tax'] ?? 0).toString();
          _otherDeductionController.text = (salaryData['other_deduction'] ?? 0).toString();
        }
        
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 통일된 다이얼로그 크기 사용
    const double dialogWidth = 900;
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
            // 헤더 - SalaryFormService 사용
            SalaryFormService.buildDialogHeader(
              title: '레슨비 정산',
              subtitle: '${widget.proName} 프로 (${SalaryFormService.formatDate(selectedMonth, format: 'yyyy년 M월')})',
              onClose: () => Navigator.of(context).pop(),
              isLoading: isLoading,
            ),

            // 월 네비게이션 - SalaryFormService 사용
            SalaryFormService.buildMonthNavigation(
              selectedMonth: selectedMonth,
              onMonthChanged: (newMonth) {
                setState(() {
                  selectedMonth = newMonth;
                  _loadSettlementData();
                });
              },
            ),

            // 탭바 - SalaryFormService 사용
            SalaryFormService.buildTabBar(
              tabController: _tabController,
              tabs: [
                TabItem(label: '월별 집계', icon: Icons.calendar_view_month),
                TabItem(label: '일자별 현황', icon: Icons.calendar_today),
                TabItem(label: '레슨비 정산', icon: Icons.calculate),
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
              child: isLoading
                  ? SalaryFormService.buildLoadingIndicator(message: '데이터를 불러오는 중...')
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMonthlyStatsSection(),
                        _buildDailyStatsSection(),
                        _buildSalarySection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatsSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: COL_WIDTH_DATE,
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child: Text(
                              '월',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_UNCONFIRMED,
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child: Text(
                              '미확인',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2,
                          child: Column(
                            children: [
                              Container(
                                height: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '레슨진행',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: COL_WIDTH_LESSON,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                                      ),
                                      child: _buildTableCell('일반', isHeader: true),
                                    ),
                                    Container(
                                      width: COL_WIDTH_EVENT,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                                      ),
                                      child: _buildTableCell('고객증정', isHeader: true),
                                    ),
                                    Container(
                                      width: COL_WIDTH_PROMO,
                                      child: _buildTableCell('신규체험', isHeader: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1,
                          child: Column(
                            children: [
                              Container(
                                height: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '레슨미진행',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: COL_WIDTH_NOSHOW,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                                      ),
                                      child: _buildTableCell('노쇼', isHeader: true),
                                    ),
                                    Container(
                                      width: COL_WIDTH_REFUND,
                                      child: _buildTableCell('환불', isHeader: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_TOTAL,
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child: Text(
                              '합계',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                ],
              ),
              for (int i = 0; i < 12; i++)
                _buildMonthlyStatsRowNew(i),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider({bool isThick = false, double? height}) {
    return Container(
      width: isThick ? 2 : 1,
      height: height ?? 40,
      decoration: BoxDecoration(
        color: isThick ? Color(0xFF6B7280) : Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildMonthlyStatsRowNew(int monthOffset) {
    final month = DateTime(selectedMonth.year, selectedMonth.month - monthOffset);
    final monthStr = DateFormat('yyyy-MM').format(month);
    final statsData = monthlyStats[monthStr];
    final stats = statsData != null ? Map<String, dynamic>.from(statsData) : <String, dynamic>{};

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          SizedBox(width: COL_WIDTH_DATE, child: _buildTableCell(DateFormat('yyyy.MM').format(month))),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_UNCONFIRMED, child: _buildTableCell(_formatMinutesWithSession(stats['미확인'] ?? 0))),
          _buildVerticalDivider(),
          // 레슨진행 그룹 (3개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2, // 내부 경계선 2개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_LESSON,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(stats['일반레슨'] ?? 0)),
                ),
                Container(
                  width: COL_WIDTH_EVENT,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(stats['고객증정레슨'] ?? 0)),
                ),
                Container(
                  width: COL_WIDTH_PROMO,
                  child: _buildTableCell(_formatMinutesWithSession(stats['신규체험레슨'] ?? 0)),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          // 레슨미진행 그룹 (2개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1, // 내부 경계선 1개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_NOSHOW,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(stats['노쇼'] ?? 0)),
                ),
                Container(
                  width: COL_WIDTH_REFUND,
                  child: _buildTableCell(_formatMinutesWithSession(stats['예약취소(환불)'] ?? 0)),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_TOTAL, child: _buildTableCell(_formatMinutesWithSession(_getTotalMinutes(stats)), isBold: true)),
        ],
      ),
    );
  }

  Widget _buildDailyStatsSection() {
    return SingleChildScrollView(
      child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF9FAFB),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: COL_WIDTH_DATE,
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child: Text(
                              '일자',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_UNCONFIRMED,
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child: Text(
                              '미확인',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2,
                          child: Column(
                            children: [
                              Container(
                                height: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '레슨진행',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: COL_WIDTH_LESSON,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                                      ),
                                      child: _buildTableCell('일반', isHeader: true),
                                    ),
                                    Container(
                                      width: COL_WIDTH_EVENT,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                                      ),
                                      child: _buildTableCell('고객증정', isHeader: true),
                                    ),
                                    Container(
                                      width: COL_WIDTH_PROMO,
                                      child: _buildTableCell('신규체험', isHeader: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1,
                          child: Column(
                            children: [
                              Container(
                                height: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '레슨미진행',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: COL_WIDTH_NOSHOW,
                                      decoration: BoxDecoration(
                                        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                                      ),
                                      child: _buildTableCell('노쇼', isHeader: true),
                                    ),
                                    Container(
                                      width: COL_WIDTH_REFUND,
                                      child: _buildTableCell('환불', isHeader: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildVerticalDivider(height: 80),
                        SizedBox(
                          width: COL_WIDTH_TOTAL,
                          child: Container(
                            height: 80,
                            alignment: Alignment.center,
                            child: Text(
                              '합계',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                ],
              ),
              for (var dailyStat in dailyStats)
                _buildDailyStatsRowNew(dailyStat),
              _buildDailyTotalRowNew(),
              _buildSalaryPerMinRowNew(),
              _buildTotalSalaryRowNew(),
            ],
          ),
        ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, bool isDivider = false, bool isEmpty = false, bool isGroupHeader = false}) {
    if (isDivider || isEmpty) {
      return Container(height: 40);
    }

    bool hasSession = text.contains('분/') && text.contains('회');
    
    if (hasSession) {
      List<String> parts = text.split('/');
      String minutes = parts[0];
      String sessions = parts[1];
      
      return Container(
        height: 40,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              minutes,
              style: TextStyle(
                fontSize: isHeader ? 11 : 12,
                fontWeight: isHeader ? FontWeight.w600 : (isBold ? FontWeight.bold : FontWeight.normal),
                color: isHeader ? Color(0xFF374151) : Color(0xFF1F2937),
              ),
            ),
            Text(
              sessions,
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader ? FontWeight.w600 : (isBold ? FontWeight.bold : FontWeight.normal),
          color: isHeader ? Color(0xFF374151) : Color(0xFF1F2937),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDailyStatsRowNew(Map<String, dynamic> dailyStat) {
    // 날짜 문자열을 DateTime으로 파싱
    String dateStr = dailyStat['date'] ?? '';
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (e) {
      // 파싱 실패시 기본값
      date = null;
    }
    
    // 날짜와 요일 포맷팅
    String formattedDate = '';
    if (date != null) {
      String dayOfWeek = _getKoreanDayOfWeek(date);
      formattedDate = '${date.month}/${date.day}($dayOfWeek)';
    } else {
      formattedDate = dateStr;
    }
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: COL_WIDTH_DATE, 
            child: date != null 
              ? _buildDateCellWithColor(formattedDate, _getDayOfWeekColor(date))
              : _buildTableCell(formattedDate)
          ),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_UNCONFIRMED, child: _buildTableCell(_formatMinutesWithSession(dailyStat['미확인'] ?? 0))),
          _buildVerticalDivider(),
          // 레슨진행 그룹 (3개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2, // 내부 경계선 2개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_LESSON,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(dailyStat['일반레슨'] ?? 0)),
                ),
                Container(
                  width: COL_WIDTH_EVENT,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(dailyStat['고객증정레슨'] ?? 0)),
                ),
                Container(
                  width: COL_WIDTH_PROMO,
                  child: _buildTableCell(_formatMinutesWithSession(dailyStat['신규체험레슨'] ?? 0)),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          // 레슨미진행 그룹 (2개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1, // 내부 경계선 1개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_NOSHOW,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(dailyStat['노쇼'] ?? 0)),
                ),
                Container(
                  width: COL_WIDTH_REFUND,
                  child: _buildTableCell(_formatMinutesWithSession(dailyStat['예약취소(환불)'] ?? 0)),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_TOTAL, child: _buildTableCell(_formatMinutesWithSession(_getTotalMinutes(dailyStat)), isBold: true)),
        ],
      ),
    );
  }

  int _getTotalMinutes(Map<String, dynamic> stats) {
    int total = 0;
    ['미확인', '일반레슨', '고객증정레슨', '신규체험레슨', '노쇼', '예약취소(환불)'].forEach((key) {
      total += (stats[key] as int?) ?? 0;
    });
    return total;
  }

  Widget _buildDailyTotalRowNew() {
    Map<String, int> totalStats = {};
    for (var dailyStat in dailyStats) {
      ['미확인', '일반레슨', '고객증정레슨', '신규체험레슨', '노쇼', '예약취소(환불)'].forEach((key) {
        totalStats[key] = (totalStats[key] ?? 0) + ((dailyStat[key] as int?) ?? 0);
      });
    }
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          SizedBox(width: COL_WIDTH_DATE, child: _buildTableCell('합계', isBold: true)),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_UNCONFIRMED, child: _buildTableCell(_formatMinutesWithSession(totalStats['미확인'] ?? 0), isBold: true)),
          _buildVerticalDivider(),
          // 레슨진행 그룹 (3개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2, // 내부 경계선 2개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_LESSON,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(totalStats['일반레슨'] ?? 0), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_EVENT,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(totalStats['고객증정레슨'] ?? 0), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_PROMO,
                  child: _buildTableCell(_formatMinutesWithSession(totalStats['신규체험레슨'] ?? 0), isBold: true),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          // 레슨미진행 그룹 (2개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1, // 내부 경계선 1개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_NOSHOW,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatMinutesWithSession(totalStats['노쇼'] ?? 0), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_REFUND,
                  child: _buildTableCell(_formatMinutesWithSession(totalStats['예약취소(환불)'] ?? 0), isBold: true),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_TOTAL, child: _buildTableCell(_formatMinutesWithSession(_getTotalMinutes(totalStats)), isBold: true)),
        ],
      ),
    );
  }

  Widget _buildSalaryPerMinRowNew() {
    if (contractInfo == null) {
      return Container();
    }

    int salaryPerLessonMin = (contractInfo!['salary_per_lesson_min'] as int?) ?? 0;
    int salaryPerEventMin = (contractInfo!['salary_per_event_min'] as int?) ?? 0;
    int salaryPerPromoMin = (contractInfo!['salary_per_promo_min'] as int?) ?? 0;
    int salaryPerNoshowMin = (contractInfo!['salary_per_noshow_min'] as int?) ?? 0;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          SizedBox(width: COL_WIDTH_DATE, child: _buildTableCell('분당 레슨비', isBold: true)),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_UNCONFIRMED, child: _buildTableCell('-')),
          _buildVerticalDivider(),
          // 레슨진행 그룹 (3개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2, // 내부 경계선 2개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_LESSON,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatCurrencyWithDash(salaryPerLessonMin), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_EVENT,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatCurrencyWithDash(salaryPerEventMin), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_PROMO,
                  child: _buildTableCell(_formatCurrencyWithDash(salaryPerPromoMin), isBold: true),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          // 레슨미진행 그룹 (2개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1, // 내부 경계선 1개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_NOSHOW,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatCurrencyWithDash(salaryPerNoshowMin), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_REFUND,
                  child: _buildTableCell('-'),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_TOTAL, child: _buildTableCell('-')),
        ],
      ),
    );
  }

  Widget _buildTotalSalaryRowNew() {
    if (contractInfo == null) {
      return Container();
    }

    Map<String, int> totalStats = {};
    for (var dailyStat in dailyStats) {
      ['미확인', '일반레슨', '고객증정레슨', '신규체험레슨', '노쇼', '예약취소(환불)'].forEach((key) {
        totalStats[key] = (totalStats[key] ?? 0) + ((dailyStat[key] as int?) ?? 0);
      });
    }

    int salaryPerLessonMin = (contractInfo!['salary_per_lesson_min'] as int?) ?? 0;
    int salaryPerEventMin = (contractInfo!['salary_per_event_min'] as int?) ?? 0;
    int salaryPerPromoMin = (contractInfo!['salary_per_promo_min'] as int?) ?? 0;
    int salaryPerNoshowMin = (contractInfo!['salary_per_noshow_min'] as int?) ?? 0;

    int totalLessonSalary = (totalStats['일반레슨'] ?? 0) * salaryPerLessonMin;
    int totalEventSalary = (totalStats['고객증정레슨'] ?? 0) * salaryPerEventMin;
    int totalPromoSalary = (totalStats['신규체험레슨'] ?? 0) * salaryPerPromoMin;
    int totalNoshowSalary = (totalStats['노쇼'] ?? 0) * salaryPerNoshowMin;
    int grandTotal = totalLessonSalary + totalEventSalary + totalPromoSalary + totalNoshowSalary;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Color(0xFFEDE9FE),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          SizedBox(width: COL_WIDTH_DATE, child: _buildTableCell('총 레슨비(인센티브)', isBold: true)),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_UNCONFIRMED, child: _buildTableCell('-')),
          _buildVerticalDivider(),
          // 레슨진행 그룹 (3개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_LESSON + COL_WIDTH_EVENT + COL_WIDTH_PROMO + 2, // 내부 경계선 2개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_LESSON,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatCurrencyWithDash(totalLessonSalary), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_EVENT,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatCurrencyWithDash(totalEventSalary), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_PROMO,
                  child: _buildTableCell(_formatCurrencyWithDash(totalPromoSalary), isBold: true),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          // 레슨미진행 그룹 (2개 컬럼을 하나로 묶어서 헤더와 맞춤)
          SizedBox(
            width: COL_WIDTH_NOSHOW + COL_WIDTH_REFUND + 1, // 내부 경계선 1개 포함
            child: Row(
              children: [
                Container(
                  width: COL_WIDTH_NOSHOW,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                  ),
                  child: _buildTableCell(_formatCurrencyWithDash(totalNoshowSalary), isBold: true),
                ),
                Container(
                  width: COL_WIDTH_REFUND,
                  child: _buildTableCell('-'),
                ),
              ],
            ),
          ),
          _buildVerticalDivider(),
          SizedBox(width: COL_WIDTH_TOTAL, child: _buildTableCell(_formatCurrencyWithDash(grandTotal), isBold: true)),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return formatter.format(amount);
  }
  
  // 요일 한글 변환
  String _getKoreanDayOfWeek(DateTime date) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[date.weekday - 1];
  }
  
  // 요일별 색상 반환
  Color _getDayOfWeekColor(DateTime date) {
    switch (date.weekday) {
      case 6: // 토요일
        return Color(0xFF2563EB); // 파란색
      case 7: // 일요일
        return Color(0xFFDC2626); // 빨간색
      default: // 평일
        return Color(0xFF1F2937); // 기본 검은색
    }
  }
  
  // 색상이 적용된 날짜 셀 빌더
  Widget _buildDateCellWithColor(String text, Color color) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  // 급여 정보 섹션
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
  
  String _formatCurrencyWithDash(int amount) {
    if (amount == 0) {
      return '-';
    }
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount)}원';
  }

  String _formatMinutesWithSession(int minutes) {
    if (minutes == 0) {
      return '-';
    }
    
    if (contractInfo == null || contractInfo!['min_service_min'] == null) {
      return '${_formatCurrency(minutes)}분';
    }
    
    int minServiceMin = (contractInfo!['min_service_min'] as int?) ?? 1;
    if (minServiceMin == 0) minServiceMin = 1;
    
    double sessions = minutes / minServiceMin;
    return '${_formatCurrency(minutes)}분/${sessions.toStringAsFixed(1)}회';
  }
  
  // 급여 정산 섹션
  Widget _buildSalarySection() {
    if (contractInfo == null) {
      return Center(
        child: Text(
          '계약 정보를 불러올 수 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    // 총 레슨비 계산
    Map<String, int> totalStats = {};
    for (var dailyStat in dailyStats) {
      ['미확인', '일반레슨', '고객증정레슨', '신규체험레슨', '노쇼', '예약취소(환불)'].forEach((key) {
        totalStats[key] = (totalStats[key] ?? 0) + ((dailyStat[key] as int?) ?? 0);
      });
    }

    int salaryPerLessonMin = (contractInfo!['salary_per_lesson_min'] as int?) ?? 0;
    int salaryPerEventMin = (contractInfo!['salary_per_event_min'] as int?) ?? 0;
    int salaryPerPromoMin = (contractInfo!['salary_per_promo_min'] as int?) ?? 0;
    int salaryPerNoshowMin = (contractInfo!['salary_per_noshow_min'] as int?) ?? 0;

    int totalLessonSalary = (totalStats['일반레슨'] ?? 0) * salaryPerLessonMin +
                           (totalStats['고객증정레슨'] ?? 0) * salaryPerEventMin +
                           (totalStats['신규체험레슨'] ?? 0) * salaryPerPromoMin +
                           (totalStats['노쇼'] ?? 0) * salaryPerNoshowMin;
    
    int salaryBase = (contractInfo!['salary_base'] as int?) ?? 0;
    int totalSalary = salaryBase + totalLessonSalary;

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
              _formatCurrencyWithDash(salaryBase),
              Color(0xFF374151),
            ),
            SizedBox(height: 16),
            
            // 레슨비(인센티브)
            _buildSalaryInfoRow(
              '레슨비(인센티브)',
              _formatCurrencyWithDash(totalLessonSalary),
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
              _formatCurrencyWithDash(totalSalary),
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
                    color: (contractInfo?['contract_type'] ?? '정규') == '프리랜서' ? Color(0xFFFEF3C7) : Color(0xFFDDD6FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '계약 타입: ${contractInfo?['contract_type'] ?? '정규'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (contractInfo?['contract_type'] ?? '정규') == '프리랜서' ? Color(0xFF92400E) : Color(0xFF5B21B6),
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
              _formatCurrencyWithDash(_calculateTotalDeduction()),
              Color(0xFFEF4444),
              isBold: true,
            ),
            SizedBox(height: 16),
            
            // 실지급액
            _buildSalaryInfoRow(
              '실지급액',
              _formatCurrencyWithDash(totalSalary - _calculateTotalDeduction()),
              Color(0xFF10B981),
              isBold: true,
              fontSize: 16,
            ),
            
            SizedBox(height: 16),
            
            // 확정 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmSalary(totalLessonSalary, salaryBase, totalSalary, _calculateTotalDeduction(), totalSalary - _calculateTotalDeduction()),
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
  
  // 세금 입력 필드 빌더
  Widget _buildTaxInputFields() {
    String contractType = contractInfo?['contract_type'] ?? '정규';
    bool isFreelancer = contractType == '프리랜서';
    
    return Column(
      children: [
        // 계약 타입별 세금 필드
        // 계약 타입 표시
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isFreelancer ? Color(0xFFFEF3C7) : Color(0xFFDDD6FE),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '계약 타입: ${contractType}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFreelancer ? Color(0xFF92400E) : Color(0xFF5B21B6),
            ),
          ),
        ),
        if (isFreelancer) ...[
          // 프리랜서: 사업소득세, 지방소득세
          _buildTaxInputField('사업소득세', _businessIncomeTaxController),
          SizedBox(height: 10),
          _buildTaxInputField('지방소득세', _localTaxController),
        ] else ...[
          // 고용(4대보험): 근로소득세, 4대보험료
          _buildTaxInputField('근로소득세', _incomeTaxController),
          SizedBox(height: 10),
          _buildTaxInputField('4대보험료', _fourInsureController),
        ],
        SizedBox(height: 10),
        // 공통: 기타급여공제
        _buildTaxInputField('기타급여공제', _otherDeductionController),
      ],
    );
  }
  
  // 계약 타입 표시 없는 세금 입력 필드 빌더
  Widget _buildTaxInputFieldsWithoutTypeDisplay() {
    String contractType = contractInfo?['contract_type'] ?? '정규';
    bool isFreelancer = contractType == '프리랜서';
    
    return Column(
      children: [
        if (isFreelancer) ...[
          // 프리랜서: 사업소득세, 지방소득세
          _buildTaxInputField('사업소득세', _businessIncomeTaxController),
          SizedBox(height: 10),
          _buildTaxInputField('지방소득세', _localTaxController),
        ] else ...[
          // 고용(4대보험): 근로소득세, 4대보험료
          _buildTaxInputField('근로소득세', _incomeTaxController),
          SizedBox(height: 10),
          _buildTaxInputField('4대보험료', _fourInsureController),
        ],
        SizedBox(height: 10),
        // 공통: 기타급여공제
        _buildTaxInputField('기타급여공제', _otherDeductionController),
      ],
    );
  }
  
  // 개별 세금 입력 필드
  Widget _buildTaxInputField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2),
              ),
              suffixText: '원',
              suffixStyle: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            onChanged: (value) {
              setState(() {
                // 입력값 변경 시 화면 갱신
              });
            },
          ),
        ),
      ],
    );
  }
  
  // 총 공제액 계산
  int _calculateTotalDeduction() {
    String contractType = contractInfo?['contract_type'] ?? '정규';
    bool isFreelancer = contractType == '프리랜서';
    
    int totalDeduction = 0;
    
    if (isFreelancer) {
      // 프리랜서: 사업소득세 + 지방소득세 + 기타공제
      totalDeduction += int.tryParse(_businessIncomeTaxController.text) ?? 0;
      totalDeduction += int.tryParse(_localTaxController.text) ?? 0;
    } else {
      // 고용: 근로소득세 + 4대보험료 + 기타공제
      totalDeduction += int.tryParse(_incomeTaxController.text) ?? 0;
      totalDeduction += int.tryParse(_fourInsureController.text) ?? 0;
    }
    
    // 공통: 기타급여공제
    totalDeduction += int.tryParse(_otherDeductionController.text) ?? 0;
    
    return totalDeduction;
  }
  
  // 급여 제출 처리
  Future<void> _confirmSalary(int totalLessonSalary, int salaryBase, int totalSalary, int totalDeduction, int netSalary) async {
    if (widget.proId == null || contractInfo == null) {
      _showErrorDialog('프로 정보 또는 계약 정보를 찾을 수 없습니다.');
      return;
    }

    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        _showErrorDialog('지점 정보를 찾을 수 없습니다.');
        return;
      }

      // 현재 급여 상태 확인
      final existingStatus = await _checkExistingSalaryStatus(currentBranchId);
      if (existingStatus == "확정") {
        _showErrorDialog('이미 확정된 급여는 수정할 수 없습니다.');
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('급여 상태 확인 오류: $e');
      }
    }

    // 확인 다이얼로그
    bool confirmed = await _showConfirmDialog(
      '급여 정산을 제출하시겠습니까?',
      '제출 후 관리자가 검토합니다.',
    );
    
    if (!confirmed) return;

    try {
      // 각 레슨 유형별 레슨비 합계 계산
      Map<String, int> totalStats = {};
      for (var dailyStat in dailyStats) {
        ['미확인', '일반레슨', '고객증정레슨', '신규체험레슨', '노쇼', '예약취소(환불)'].forEach((key) {
          totalStats[key] = (totalStats[key] ?? 0) + ((dailyStat[key] as int?) ?? 0);
        });
      }

      int salaryPerLessonMin = (contractInfo!['salary_per_lesson_min'] as int?) ?? 0;
      int salaryPerEventMin = (contractInfo!['salary_per_event_min'] as int?) ?? 0;
      int salaryPerPromoMin = (contractInfo!['salary_per_promo_min'] as int?) ?? 0;
      int salaryPerNoshowMin = (contractInfo!['salary_per_noshow_min'] as int?) ?? 0;

      // 각 유형별 레슨비 합계
      int lessonSalaryTotal = (totalStats['일반레슨'] ?? 0) * salaryPerLessonMin;
      int eventSalaryTotal = (totalStats['고객증정레슨'] ?? 0) * salaryPerEventMin;
      int promoSalaryTotal = (totalStats['신규체험레슨'] ?? 0) * salaryPerPromoMin;
      int noshowSalaryTotal = (totalStats['노쇼'] ?? 0) * salaryPerNoshowMin;

      // 계약 타입 확인
      String contractType = contractInfo!['contract_type'] ?? '정규';
      bool isFreelancer = contractType == '프리랜서';
      
      // 세금 정보 가져오기
      int fourInsure = isFreelancer ? 0 : (int.tryParse(_fourInsureController.text) ?? 0);
      int incomeTax = isFreelancer ? 0 : (int.tryParse(_incomeTaxController.text) ?? 0);
      int businessIncomeTax = isFreelancer ? (int.tryParse(_businessIncomeTaxController.text) ?? 0) : 0;
      int localTax = isFreelancer ? (int.tryParse(_localTaxController.text) ?? 0) : 0;
      int otherDeduction = int.tryParse(_otherDeductionController.text) ?? 0;
      
      // 현재 지점 ID 가져오기 (상태 확인에서 가져온 값 사용)
      final currentBranchId = ApiService.getCurrentBranchId()!;
      
      // 급여 정보 저장
      bool success = await LessonApiService.saveSalaryInfo(
        branchId: currentBranchId,
        proId: widget.proId!,
        proName: widget.proName,
        year: selectedMonth.year,
        month: selectedMonth.month,
        salaryStatus: '제출완료',
        contractType: contractType,
        salaryBase: salaryBase,
        salaryHour: 0, // 시급제가 아니므로 0
        salaryPerLesson: lessonSalaryTotal, // 일반레슨 레슨비 합계
        salaryPerEvent: eventSalaryTotal, // 고객증정레슨 레슨비 합계
        salaryPerPromo: promoSalaryTotal, // 신규체험레슨 레슨비 합계
        salaryPerNoshow: noshowSalaryTotal, // 노쇼 레슨비 합계
        salaryTotal: totalSalary,
        fourInsure: fourInsure,
        incomeTax: incomeTax,
        businessIncomeTax: businessIncomeTax,
        localTax: localTax,
        otherDeduction: otherDeduction,
        deductionSum: totalDeduction,
        salaryNet: netSalary,
      );

      if (success) {
        _showSuccessDialog('급여 정산이 성공적으로 제출되었습니다.');
      } else {
        _showErrorDialog('급여 정산 저장에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('급여 확정 오류: $e');
      }
      _showErrorDialog('급여 정산 중 오류가 발생했습니다.');
    }
  }
  
  // 확인 다이얼로그
  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: Text('제출'),
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  // 성공 다이얼로그
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('성공'),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // 급여 정산 다이얼로그도 닫기
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }
  
  // 에러 다이얼로그
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('오류'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 기존 급여 상태 확인 메서드
  Future<String?> _checkExistingSalaryStatus(String branchId) async {
    try {
      final queryRequestBody = {
        "operation": "select",
        "table": "v2_salary_pro",
        "columns": ["salary_status"],
        "where": [
          {
            "field": "branch_id",
            "operator": "=",
            "value": branchId
          },
          {
            "field": "pro_id",
            "operator": "=",  
            "value": widget.proId.toString()
          },
          {
            "field": "year",
            "operator": "=",
            "value": selectedMonth.year.toString()
          },
          {
            "field": "month",
            "operator": "=",
            "value": selectedMonth.month.toString()
          }
        ]
      };

      final response = await http.post(
        Uri.parse(ApiService.baseUrl),
        headers: ApiService.headers,
        body: jsonEncode(queryRequestBody),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        if (result['success'] == true && result['data'] != null && result['data'].isNotEmpty) {
          return result['data'][0]['salary_status'];
        }
      }
      
      return null; // 기존 데이터가 없음
    } catch (e) {
      if (kDebugMode) {
        print('❌ [급여 상태 확인 오류]: $e');
      }
      return null;
    }
  }
}

void showLessonFeeSettlementDialog(BuildContext context, int? proId, String proName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return LessonFeeSettlementDialog(
        proId: proId,
        proName: proName,
      );
    },
  );
}