import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/salary_form_service.dart';
import '/services/api_service.dart';
import '/services/email_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Tab6SalaryBackupWidget extends StatefulWidget {
  const Tab6SalaryBackupWidget({super.key});

  @override
  State<Tab6SalaryBackupWidget> createState() => _Tab6SalaryBackupWidgetState();
}

class _Tab6SalaryBackupWidgetState extends State<Tab6SalaryBackupWidget> {
  DateTime selectedMonth = DateTime.now();
  List<Map<String, dynamic>> allSalaryData = [];
  bool isLoading = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        throw Exception('브랜치 정보를 찾을 수 없습니다.');
      }

      // v2_salary_pro 테이블에서 강사 급여 데이터 조회
      final proData = await ApiService.getDataList(
        table: 'v2_salary_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'year', 'operator': '=', 'value': selectedMonth.year},
          {'field': 'month', 'operator': '=', 'value': selectedMonth.month},
        ],
      );

      // v2_salary_manager 테이블에서 매니저 급여 데이터 조회
      final managerData = await ApiService.getDataList(
        table: 'v2_salary_manager',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'year', 'operator': '=', 'value': selectedMonth.year},
          {'field': 'month', 'operator': '=', 'value': selectedMonth.month},
        ],
      );

      // 데이터 통합 - 강사 데이터
      final processedProData = proData.map((item) => {
        ...item,
        'employee_type': '강사',
        'employee_name': item['pro_name'],
        'employee_id': item['pro_id'],
      }).toList();

      // 데이터 통합 - 매니저 데이터
      final processedManagerData = managerData.map((item) => {
        ...item,
        'employee_type': '매니저',
        'employee_name': item['manager_name'],
        'employee_id': item['manager_id'],
      }).toList();

      final totalData = [...processedProData, ...processedManagerData];
      
      setState(() {
        allSalaryData = totalData;
      });
      
    } catch (e) {
      print('급여 데이터 로딩 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('급여 데이터를 불러오는데 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get currentMonthData {
    return allSalaryData.where((data) {
      final dataYear = data['year'];
      final dataMonth = data['month'];
      final targetYear = selectedMonth.year;
      final targetMonth = selectedMonth.month;
      
      bool yearMatch = false;
      bool monthMatch = false;
      
      if (dataYear is int && targetYear is int) {
        yearMatch = dataYear == targetYear;
      } else {
        yearMatch = dataYear.toString() == targetYear.toString();
      }
      
      if (dataMonth is int && targetMonth is int) {
        monthMatch = dataMonth == targetMonth;
      } else {
        monthMatch = dataMonth.toString() == targetMonth.toString();
      }
      
      return yearMatch && monthMatch;
    }).toList();
  }

  String _generateToken(String employeeId, String month, String year) {
    final input = '$employeeId$month$year${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  Future<void> _sendEmailToTaxOffice() async {
    final monthData = currentMonthData;
    if (monthData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('해당 월의 급여 데이터가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 세무사 이메일 확인
    final taxOffice = monthData.first['tax_office'] ?? '';
    final taxOfficeEmail = monthData.first['tax_office_mail'] ?? '';
    
    if (taxOfficeEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('세무사 이메일이 설정되지 않았습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      // 각 직원별 토큰 생성 및 저장
      for (var employee in monthData) {
        final token = _generateToken(
          employee['employee_id'].toString(),
          selectedMonth.month.toString(),
          selectedMonth.year.toString(),
        );
        
        // 토큰을 데이터베이스에 저장 (임시 테이블 또는 기존 테이블에 필드 추가)
        final String tableName = employee['employee_type'] == '강사' ? 'v2_salary_pro' : 'v2_salary_manager';
        final String idField = employee['employee_type'] == '강사' ? 'pro_id' : 'manager_id';
        
        await ApiService.updateData(
          table: tableName,
          data: {'tax_token': token},
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': employee['branch_id']},
            {'field': idField, 'operator': '=', 'value': employee['employee_id']},
            {'field': 'year', 'operator': '=', 'value': employee['year']},
            {'field': 'month', 'operator': '=', 'value': employee['month']},
          ],
        );
      }

      // 이메일 내용 생성
      final emailContent = _buildEmailContent(monthData, taxOffice);
      
      // 이메일 발송
      await EmailService.sendSalaryEmail(
        to: taxOfficeEmail,
        subject: '${selectedMonth.year}년 ${selectedMonth.month}월 급여 공제 요청',
        content: emailContent,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('세무사에게 이메일이 발송되었습니다.'),
          backgroundColor: SalaryFormService.successColor,
        ),
      );

    } catch (e) {
      print('이메일 발송 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일 발송에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  String _buildEmailContent(List<Map<String, dynamic>> monthData, String taxOffice) {
    final buffer = StringBuffer();
    
    buffer.writeln('$taxOffice 세무사님께,\n');
    buffer.writeln('${selectedMonth.year}년 ${selectedMonth.month}월 급여 공제 관련 업무를 요청드립니다.\n');
    buffer.writeln('아래 링크를 클릭하여 각 직원의 공제금액을 입력해 주세요.\n');
    
    int totalSalary = 0;
    int employeeCount = 0;
    
    for (var employee in monthData) {
      totalSalary += (employee['salary_total'] ?? 0) as int;
      employeeCount++;
      
      final token = _generateToken(
        employee['employee_id'].toString(),
        selectedMonth.month.toString(),
        selectedMonth.year.toString(),
      );
      
      buffer.writeln('${employee['employee_name']} (${employee['employee_type']})');
      buffer.writeln('- 총급여: ${_formatCurrency(employee['salary_total'] ?? 0)}');
      buffer.writeln('- 계약형태: ${employee['contract_type'] ?? ''}');
      buffer.writeln('- 공제입력 링크: ${_getWebUrl()}?token=$token');
      buffer.writeln('');
    }
    
    buffer.writeln('\n--- 요약 ---');
    buffer.writeln('총 직원 수: ${employeeCount}명');
    buffer.writeln('총 급여합계: ${_formatCurrency(totalSalary)}');
    buffer.writeln('\n공제금액 입력 후 저장하시면 자동으로 급여시스템에 반영됩니다.');
    buffer.writeln('\n감사합니다.');
    
    return buffer.toString();
  }

  String _getWebUrl() {
    // 실제 웹 호스팅 URL로 변경 필요
    return 'https://your-domain.com/tax-deduction';
  }

  String _formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }

  void _showEmployeeDetailModal(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailHeader(data),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildEmployeeInfoCard(data),
                      SizedBox(height: 12),
                      _buildSalaryBreakdownCard(data),
                      SizedBox(height: 12),
                      _buildDeductionInfoCard(data),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailHeader(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: SalaryFormService.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '${data['employee_name']} 급여 상세',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '직원 정보',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('이름', data['employee_name'] ?? ''),
              ),
              Expanded(
                child: _buildInfoRow('구분', data['employee_type'] ?? ''),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildInfoRow('계약형태', data['contract_type'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildSalaryBreakdownCard(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '급여 구성',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          if ((data['salary_base'] ?? 0) != 0)
            _buildInfoRow('기본급', _formatCurrency(data['salary_base'] ?? 0)),
          if ((data['salary_hour'] ?? 0) != 0)
            _buildInfoRow('시급', _formatCurrency(data['salary_hour'] ?? 0)),
          SizedBox(height: 8),
          Container(height: 1, color: Color(0xFFE5E7EB)),
          SizedBox(height: 8),
          _buildInfoRow('총급여', _formatCurrency(data['salary_total'] ?? 0), isBold: true),
        ],
      ),
    );
  }

  Widget _buildDeductionInfoCard(Map<String, dynamic> data) {
    String contractType = data['contract_type'] ?? '고용(4대보험)';
    bool isFreelancer = contractType == '프리랜서';

    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 공제 내역',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          if (isFreelancer) ...[
            _buildInfoRow('사업소득세', _formatCurrency(data['business_income_tax'] ?? 0)),
            _buildInfoRow('지방소득세', _formatCurrency(data['local_tax'] ?? 0)),
          ] else ...[
            _buildInfoRow('4대보험료', _formatCurrency(data['four_insure'] ?? 0)),
            _buildInfoRow('근로소득세', _formatCurrency(data['income_tax'] ?? 0)),
          ],
          _buildInfoRow('기타공제', _formatCurrency(data['other_deduction'] ?? 0)),
          SizedBox(height: 8),
          Container(height: 1, color: Color(0xFFE5E7EB)),
          SizedBox(height: 8),
          _buildInfoRow('공제합계', _formatCurrency(data['deduction_sum'] ?? 0), isBold: true),
          _buildInfoRow('실수령액', _formatCurrency(data['salary_net'] ?? 0), isBold: true, color: SalaryFormService.successColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthData = currentMonthData;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(SalaryFormService.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀과 세무사 발송 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '급여관리 (백업)',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SalaryFormService.darkColor,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ElevatedButton.icon(
                onPressed: isSending ? null : _sendEmailToTaxOffice,
                icon: isSending 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.email, size: 16),
                label: Text(isSending ? '발송 중...' : '세무사에게 발송'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SalaryFormService.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          
          // 월 네비게이션
          SalaryFormService.buildMonthNavigation(
            selectedMonth: selectedMonth,
            onMonthChanged: (newMonth) {
              setState(() {
                selectedMonth = newMonth;
              });
              _loadSalaryData();
            },
          ),
          SizedBox(height: 16.0),
          
          Expanded(
            child: isLoading 
              ? Center(child: CircularProgressIndicator())
              : monthData.isEmpty 
                ? Center(
                    child: Text(
                      '${selectedMonth.year}년 ${selectedMonth.month}월 급여 데이터가 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(SalaryFormService.defaultRadius),
                      border: Border.all(color: SalaryFormService.borderColor),
                    ),
                    child: Column(
                      children: [
                        // 테이블 헤더
                        Container(
                          decoration: BoxDecoration(
                            color: SalaryFormService.lightGrayColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(SalaryFormService.defaultRadius),
                              topRight: Radius.circular(SalaryFormService.defaultRadius),
                            ),
                            border: Border(
                              bottom: BorderSide(color: SalaryFormService.borderColor),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: SalaryFormService.buildTableHeaderCell(text: '구분')),
                              Expanded(flex: 2, child: SalaryFormService.buildTableHeaderCell(text: '이름')),
                              Expanded(flex: 2, child: SalaryFormService.buildTableHeaderCell(text: '계약형태')),
                              Expanded(flex: 2, child: SalaryFormService.buildTableHeaderCell(text: '총급여')),
                              Expanded(flex: 2, child: SalaryFormService.buildTableHeaderCell(text: '공제합계')),
                              Expanded(flex: 2, child: SalaryFormService.buildTableHeaderCell(text: '실수령액')),
                              SizedBox(width: 50),
                            ],
                          ),
                        ),
                        // 테이블 데이터
                        Expanded(
                          child: ListView.builder(
                            itemCount: monthData.length,
                            itemBuilder: (context, index) {
                              final data = monthData[index];
                              
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: SalaryFormService.borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: data['employee_type'] ?? '',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: data['employee_name'] ?? '',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: data['contract_type'] ?? '',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: SalaryFormService.formatCurrency(data['salary_total'] ?? 0),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: SalaryFormService.formatCurrency(data['deduction_sum'] ?? 0),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: SalaryFormService.formatCurrency(data['salary_net'] ?? 0),
                                        color: SalaryFormService.successColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      width: 50,
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.visibility,
                                          color: SalaryFormService.primaryColor,
                                          size: 18,
                                        ),
                                        onPressed: () => _showEmployeeDetailModal(data),
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
}