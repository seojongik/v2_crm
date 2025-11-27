import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/table_design.dart';
import 'tab5_sales_graphs.dart';

class Tab5SalesWidget extends StatefulWidget {
  const Tab5SalesWidget({super.key});

  @override
  State<Tab5SalesWidget> createState() => _Tab5SalesWidgetState();
}

class _Tab5SalesWidgetState extends State<Tab5SalesWidget> {
  bool _isLoading = false;
  Map<String, dynamic> _salesData = {};
  DateTime _selectedDate = DateTime.now();
  final NumberFormat _numberFormat = NumberFormat('#,###');
  bool _showCancelledRefunds = false;
  bool _showCreditPayments = false;

  // 차트 관련 상태
  List<Map<String, dynamic>> _trendData = [];
  bool _isLoadingChart = false;

  // 차트 연도 설정
  int _chartYear = DateTime.now().year;

  // 선택된 차트 항목 (단일 선택)
  String _selectedChartItem = 'totalPrice';

  @override
  void initState() {
    super.initState();
    _loadMonthlySalesData();
    _loadTrendData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMonthlySalesData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final salesReport = await ApiService.getMonthlySalesReport(
        year: _selectedDate.year,
        month: _selectedDate.month,
      );

      if (salesReport.isNotEmpty) {
        print('=== 월별 매출 집계 결과 ===');
        print('년도: ${salesReport['year']}');
        print('월: ${salesReport['month']}');
        print('총 계약 건수: ${salesReport['recordCount']}건');
        print('총 매출액(price): ${salesReport['totalPrice'].toStringAsFixed(0)}원');
        print('총 크레딧(contract_credit): ${salesReport['totalCredit'].toStringAsFixed(0)}');
        print('총 레슨 시간(contract_LS_min): ${salesReport['totalLSMin']}분');
        print('총 게임 수(contract_games): ${salesReport['totalGames']}');
        print('총 TS 시간(contract_TS_min): ${salesReport['totalTSMin']}분');
        print('총 계약 기간(contract_term_month): ${salesReport['totalTermMonth']}개월');
        print('========================');

        setState(() {
          _salesData = salesReport;
        });
      } else {
        print('월별 매출 데이터가 없습니다.');
      }
    } catch (e) {
      print('매출 데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매출 관리',
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF1E293B),
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.0),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽 영역: 계약 내역 테이블 (50%)
                Expanded(
                  flex: 5,
                  child: _buildContractHistoryTable(),
                ),
                SizedBox(width: 16.0),
                // 오른쪽 영역: 매출 트렌드 차트 (50%)
                Expanded(
                  flex: 5,
                  child: _isLoadingChart
                      ? Center(child: CircularProgressIndicator())
                      : SalesTrendChart(
                          trendData: _trendData,
                          selectedChartItem: _selectedChartItem,
                          chartYear: _chartYear,
                          numberFormat: _numberFormat,
                          onChartItemChanged: (String item) {
                            setState(() {
                              _selectedChartItem = item;
                            });
                            if (item == 'totalCredit' || item == 'totalLSMin') {
                              _loadTrendData();
                            }
                          },
                          onYearChanged: (int year) {
                            setState(() {
                              _chartYear = year;
                            });
                            _loadTrendData();
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalAmount(List<dynamic> data) {
    double total = 0;
    for (var record in data) {
      final price = double.tryParse(record['price']?.toString() ?? '0') ?? 0;
      total += price;
    }
    return total;
  }

  Widget _buildContractHistoryTable() {
    final rawData = _salesData['rawData'] as List<dynamic>? ?? [];
    final validData = rawData.where((record) {
      final status = record['contract_history_status']?.toString() ?? '';
      final paymentType = record['payment_type']?.toString() ?? '';

      // 데이터 이전은 항상 제외
      if (paymentType == '데이터 이전') {
        return false;
      }

      // 토글 상태에 따라 필터링
      if (_showCancelledRefunds) {
        // 취소환불 내역만 보기
        return status == '삭제';
      } else if (_showCreditPayments) {
        // 크레딧 관련 내역만 보기 (contract_type이 '크레딧'이거나 payment_type이 '크레딧결제')
        final contractType = record['contract_type']?.toString() ?? '';
        return status != '삭제' && (contractType == '크레딧' || paymentType == '크레딧결제');
      } else {
        // 정상 내역만 보기 (삭제 상태가 아니고 크레딧결제가 아닌 것)
        return status != '삭제' && paymentType != '크레딧결제';
      }
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
            ),
            child: Column(
              children: [
                // 월 선택 네비게이션을 계약 내역 구획 안으로 이동
                _buildMonthNavigation(),
                SizedBox(height: 12.0),
                // 계약 내역 제목과 토글
                Row(
                  children: [
                    Text(
                      '계약 내역',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: Color(0xFF1E293B),
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 16.0),
                    Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: _showCancelledRefunds ? Color(0xFFEF4444) : Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showCancelledRefunds = !_showCancelledRefunds;
                        if (_showCancelledRefunds) {
                          _showCreditPayments = false; // 취소환불을 보면 크레딧 결제는 끔
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showCancelledRefunds ? Icons.visibility : Icons.visibility_off,
                          size: 16.0,
                          color: _showCancelledRefunds ? Colors.white : Color(0xFF64748B),
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          '취소환불 내역',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: _showCancelledRefunds ? Colors.white : Color(0xFF64748B),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    SizedBox(width: 8.0),
                    Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: _showCreditPayments ? Color(0xFF8B5CF6) : Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showCreditPayments = !_showCreditPayments;
                        if (_showCreditPayments) {
                          _showCancelledRefunds = false; // 크레딧 결제를 보면 취소환불은 끔
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showCreditPayments ? Icons.visibility : Icons.visibility_off,
                          size: 16.0,
                          color: _showCreditPayments ? Colors.white : Color(0xFF64748B),
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          '크레딧 결제',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: _showCreditPayments ? Colors.white : Color(0xFF64748B),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    Spacer(),
                    Text(
                      _showCancelledRefunds
                        ? '취소환불 ${validData.length}건 (합계 ${_numberFormat.format(_calculateTotalAmount(validData))}원)'
                        : _showCreditPayments
                        ? '크레딧결제 ${validData.length}건 (합계 ${_numberFormat.format(_calculateTotalAmount(validData))}원)'
                        : '정상 ${validData.length}건 (합계 ${_numberFormat.format(_calculateTotalAmount(validData))}원)',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: _showCancelledRefunds
                          ? Color(0xFFEF4444)
                          : _showCreditPayments
                          ? Color(0xFF8B5CF6)
                          : Color(0xFF64748B),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TableDesign.buildTableContainer(
              child: Column(
                children: [
                  TableDesign.buildTableHeader(
                    children: [
                      TableDesign.buildHeaderColumn(text: '계약일', flex: 2),
                      TableDesign.buildHeaderColumn(text: '계약자', flex: 2),
                      TableDesign.buildHeaderColumn(text: '상품명', flex: 3),
                      TableDesign.buildHeaderColumn(text: '결제방식', flex: 2),
                      TableDesign.buildHeaderColumn(text: '금액', flex: 2, textAlign: TextAlign.right),
                    ],
                  ),
                  Expanded(
                    child: TableDesign.buildTableBody(
                      itemCount: validData.length,
                      itemBuilder: (context, index) {
                        final record = validData[index];
                        return TableDesign.buildTableRow(
                          children: [
                            TableDesign.buildRowColumn(
                              text: record['contract_date']?.toString() ?? '',
                              flex: 2,
                              fontSize: 13.0,
                            ),
                            TableDesign.buildRowColumn(
                              text: record['member_name']?.toString() ?? '',
                              flex: 2,
                              fontSize: 13.0,
                            ),
                            TableDesign.buildRowColumn(
                              text: record['contract_name']?.toString() ?? '',
                              flex: 3,
                              fontSize: 13.0,
                            ),
                            TableDesign.buildRowColumn(
                              text: record['payment_type']?.toString() ?? '',
                              flex: 2,
                              fontSize: 13.0,
                            ),
                            TableDesign.buildRowColumn(
                              text: '${_numberFormat.format(double.tryParse(record['price']?.toString() ?? '0') ?? 0)}원',
                              flex: 2,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              textAlign: TextAlign.right,
                            ),
                          ],
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

  Widget _buildMonthlySummary() {
    // 취소환불 내역을 보고 있을 때는 집계를 다르게 표시
    final rawData = _salesData['rawData'] as List<dynamic>? ?? [];

    Map<String, dynamic> displayData;
    String titleSuffix;

    if (_showCancelledRefunds) {
      // 취소환불 내역 집계
      titleSuffix = ' (취소환불)';
      displayData = _calculateCancelledRefundsSummary(rawData);
    } else if (_showCreditPayments) {
      // 크레딧 결제 내역 집계
      titleSuffix = ' (크레딧결제)';
      displayData = _calculateCreditPaymentsSummary(rawData);
    } else {
      // 정상 매출 집계 (기존 데이터 사용)
      titleSuffix = '';
      displayData = _salesData;
    }

    return Container(
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${displayData['year'] ?? 2025}년 ${displayData['month'] ?? 9}월 매출 집계$titleSuffix',
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: _showCancelledRefunds
                ? Color(0xFFEF4444)
                : _showCreditPayments
                ? Color(0xFF8B5CF6)
                : Color(0xFF1E293B),
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.0),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
              childAspectRatio: 2.5,
              children: [
                _buildSummaryCard(
                  _showCancelledRefunds
                    ? '취소환불 건수'
                    : _showCreditPayments
                    ? '크레딧결제 건수'
                    : '총 계약 건수',
                  '${_numberFormat.format(displayData['recordCount'] ?? 0)}건',
                  _showCancelledRefunds
                    ? Color(0xFFEF4444)
                    : _showCreditPayments
                    ? Color(0xFF8B5CF6)
                    : Color(0xFF3B82F6),
                ),
                _buildSummaryCard(
                  _showCancelledRefunds
                    ? '취소환불액'
                    : _showCreditPayments
                    ? '크레딧결제액'
                    : '총 매출액',
                  '${_numberFormat.format(displayData['totalPrice'] ?? 0)}원',
                  _showCancelledRefunds
                    ? Color(0xFFEF4444)
                    : _showCreditPayments
                    ? Color(0xFF8B5CF6)
                    : Color(0xFF10B981),
                ),
                _buildSummaryCard(
                  _showCancelledRefunds
                    ? '취소 크레딧'
                    : _showCreditPayments
                    ? '크레딧결제 크레딧'
                    : '총 크레딧',
                  '${_numberFormat.format(displayData['totalCredit'] ?? 0)}',
                  _showCancelledRefunds
                    ? Color(0xFFEF4444)
                    : _showCreditPayments
                    ? Color(0xFF8B5CF6)
                    : Color(0xFF8B5CF6),
                ),
                _buildSummaryCard(
                  _showCancelledRefunds
                    ? '취소 레슨시간'
                    : _showCreditPayments
                    ? '크레딧결제 레슨시간'
                    : '총 레슨시간',
                  '${_numberFormat.format(displayData['totalLSMin'] ?? 0)}분',
                  _showCancelledRefunds
                    ? Color(0xFFEF4444)
                    : _showCreditPayments
                    ? Color(0xFF8B5CF6)
                    : Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateCancelledRefundsSummary(List<dynamic> rawData) {
    final cancelledData = rawData.where((record) {
      final status = record['contract_history_status']?.toString() ?? '';
      final paymentType = record['payment_type']?.toString() ?? '';
      return status == '삭제' && paymentType != '데이터 이전';
    }).toList();

    double totalPrice = 0;
    double totalCredit = 0;
    int totalLSMin = 0;
    int totalGames = 0;
    int totalTSMin = 0;
    int totalTermMonth = 0;

    for (var record in cancelledData) {
      if (record['price'] != null && record['price'] != '') {
        totalPrice += double.tryParse(record['price'].toString()) ?? 0;
      }
      if (record['contract_credit'] != null && record['contract_credit'] != '') {
        totalCredit += double.tryParse(record['contract_credit'].toString()) ?? 0;
      }
      if (record['contract_LS_min'] != null && record['contract_LS_min'] != '') {
        totalLSMin += int.tryParse(record['contract_LS_min'].toString()) ?? 0;
      }
      if (record['contract_games'] != null && record['contract_games'] != '') {
        totalGames += int.tryParse(record['contract_games'].toString()) ?? 0;
      }
      if (record['contract_TS_min'] != null && record['contract_TS_min'] != '') {
        totalTSMin += int.tryParse(record['contract_TS_min'].toString()) ?? 0;
      }
      if (record['contract_term_month'] != null && record['contract_term_month'] != '') {
        totalTermMonth += int.tryParse(record['contract_term_month'].toString()) ?? 0;
      }
    }

    return {
      'year': _selectedDate.year,
      'month': _selectedDate.month,
      'recordCount': cancelledData.length,
      'totalPrice': totalPrice,
      'totalCredit': totalCredit,
      'totalLSMin': totalLSMin,
      'totalGames': totalGames,
      'totalTSMin': totalTSMin,
      'totalTermMonth': totalTermMonth,
    };
  }

  Map<String, dynamic> _calculateCreditPaymentsSummary(List<dynamic> rawData) {
    final creditData = rawData.where((record) {
      final status = record['contract_history_status']?.toString() ?? '';
      final paymentType = record['payment_type']?.toString() ?? '';
      final contractType = record['contract_type']?.toString() ?? '';
      return status != '삭제' && paymentType != '데이터 이전' && (contractType == '크레딧' || paymentType == '크레딧결제');
    }).toList();

    double totalPrice = 0;
    double totalCredit = 0;
    int totalLSMin = 0;
    int totalGames = 0;
    int totalTSMin = 0;
    int totalTermMonth = 0;

    for (var record in creditData) {
      if (record['price'] != null && record['price'] != '') {
        totalPrice += double.tryParse(record['price'].toString()) ?? 0;
      }
      if (record['contract_credit'] != null && record['contract_credit'] != '') {
        totalCredit += double.tryParse(record['contract_credit'].toString()) ?? 0;
      }
      if (record['contract_LS_min'] != null && record['contract_LS_min'] != '') {
        totalLSMin += int.tryParse(record['contract_LS_min'].toString()) ?? 0;
      }
      if (record['contract_games'] != null && record['contract_games'] != '') {
        totalGames += int.tryParse(record['contract_games'].toString()) ?? 0;
      }
      if (record['contract_TS_min'] != null && record['contract_TS_min'] != '') {
        totalTSMin += int.tryParse(record['contract_TS_min'].toString()) ?? 0;
      }
      if (record['contract_term_month'] != null && record['contract_term_month'] != '') {
        totalTermMonth += int.tryParse(record['contract_term_month'].toString()) ?? 0;
      }
    }

    return {
      'year': _selectedDate.year,
      'month': _selectedDate.month,
      'recordCount': creditData.length,
      'totalPrice': totalPrice,
      'totalCredit': totalCredit,
      'totalLSMin': totalLSMin,
      'totalGames': totalGames,
      'totalTSMin': totalTSMin,
      'totalTermMonth': totalTermMonth,
    };
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF64748B),
              fontSize: 12.0,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 4.0),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: color,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMonthNavigation() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _isLoading ? null : () => _changeMonth(-1),
            icon: Icon(
              Icons.chevron_left,
              color: _isLoading ? Color(0xFFCBD5E1) : Color(0xFF475569),
            ),
          ),
          SizedBox(width: 16.0),
          Text(
            '${_selectedDate.year}년 ${_selectedDate.month}월',
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF1E293B),
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 16.0),
          IconButton(
            onPressed: _isLoading ? null : () => _changeMonth(1),
            icon: Icon(
              Icons.chevron_right,
              color: _isLoading ? Color(0xFFCBD5E1) : Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
    });
    _loadMonthlySalesData();
  }

  Future<void> _loadTrendData() async {
    setState(() {
      _isLoadingChart = true;
    });

    try {
      // 크레딧 선택 시에만 bills 데이터 포함
      final includeBills = _selectedChartItem == 'totalCredit';
      // 레슨권 선택 시에만 lesson usage 데이터 포함
      final includeLessonUsage = _selectedChartItem == 'totalLSMin';
      final trendData = await ApiService.getMonthlySalesTrend(
        year: _chartYear,
        includeBills: includeBills,
        includeLessonUsage: includeLessonUsage,
      );
      setState(() {
        _trendData = trendData;
      });
    } catch (e) {
      print('트렌드 데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

}
