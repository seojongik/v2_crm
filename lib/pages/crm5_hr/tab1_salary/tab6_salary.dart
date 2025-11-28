import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/salary_form_service.dart';
import '/services/api_service.dart';
import '/services/email_service.dart';
import '/widgets/deduction_input_popup.dart';
import '/widgets/bulk_deduction_input_popup.dart';
import '/widgets/payment_completion_popup.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Tab6SalaryWidget extends StatefulWidget {
  const Tab6SalaryWidget({super.key});

  @override
  State<Tab6SalaryWidget> createState() => _Tab6SalaryWidgetState();
}

class _Tab6SalaryWidgetState extends State<Tab6SalaryWidget> {
  DateTime selectedMonth = DateTime.now();
  List<Map<String, dynamic>> allSalaryData = [];
  bool isLoading = false;
  bool isSendingEmail = false;

  final Map<String, TextEditingController> _deductionControllers = {};
  final TextEditingController _taxOfficeController = TextEditingController();
  final TextEditingController _taxOfficeMailController = TextEditingController();

  @override
  void dispose() {
    _deductionControllers.values.forEach((controller) => controller.dispose());
    _taxOfficeController.dispose();
    _taxOfficeMailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    print('🔍 [급여데이터] _loadSalaryData 시작 - ${selectedMonth.year}년 ${selectedMonth.month}월');
    
    setState(() {
      isLoading = true;
    });

    try {
      // 현재 브랜치 ID 가져오기
      final currentBranchId = ApiService.getCurrentBranchId();
      print('🔍 [급여데이터] 현재 브랜치 ID: $currentBranchId');
      
      if (currentBranchId == null) {
        print('❌ [급여데이터] 브랜치 ID가 null입니다.');
        throw Exception('브랜치 정보를 찾을 수 없습니다.');
      }

      // v2_salary_pro 테이블에서 강사 급여 데이터 조회
      print('🔍 [급여데이터] v2_salary_pro 조회 시작 - branch_id: $currentBranchId, year: ${selectedMonth.year}, month: ${selectedMonth.month}');
      final proData = await ApiService.getDataList(
        table: 'v2_salary_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'year', 'operator': '=', 'value': selectedMonth.year},
          {'field': 'month', 'operator': '=', 'value': selectedMonth.month},
        ],
      );
      print('✅ [급여데이터] v2_salary_pro 조회 완료 - ${proData.length}개');
      if (proData.isNotEmpty) {
        print('📋 [급여데이터] v2_salary_pro 첫번째 데이터: ${proData.first}');
      }

      // v2_salary_manager 테이블에서 매니저 급여 데이터 조회
      print('🔍 [급여데이터] v2_salary_manager 조회 시작 - branch_id: $currentBranchId, year: ${selectedMonth.year}, month: ${selectedMonth.month}');
      final managerData = await ApiService.getDataList(
        table: 'v2_salary_manager',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'year', 'operator': '=', 'value': selectedMonth.year},
          {'field': 'month', 'operator': '=', 'value': selectedMonth.month},
        ],
      );
      print('✅ [급여데이터] v2_salary_manager 조회 완료 - ${managerData.length}개');
      if (managerData.isNotEmpty) {
        print('📋 [급여데이터] v2_salary_manager 첫번째 데이터: ${managerData.first}');
      }

      // 데이터 통합 - 강사 데이터에 employee_type 추가
      print('🔍 [급여데이터] 강사 데이터 처리 시작');
      final processedProData = proData.map((item) => {
        ...item,
        'employee_type': '강사',
        'employee_name': item['pro_name'],
        'employee_id': item['pro_id'],
      }).toList();
      print('✅ [급여데이터] 강사 데이터 처리 완료 - ${processedProData.length}개');

      // 데이터 통합 - 매니저 데이터에 employee_type 추가
      print('🔍 [급여데이터] 매니저 데이터 처리 시작');
      final processedManagerData = managerData.map((item) => {
        ...item,
        'employee_type': '매니저',
        'employee_name': item['manager_name'],
        'employee_id': item['manager_id'],
      }).toList();
      print('✅ [급여데이터] 매니저 데이터 처리 완료 - ${processedManagerData.length}개');

      final totalData = [...processedProData, ...processedManagerData];
      print('🔍 [급여데이터] 전체 데이터 통합 완료 - 총 ${totalData.length}개');
      
      setState(() {
        allSalaryData = totalData;
      });
      
      print('✅ [급여데이터] allSalaryData 업데이트 완료 - ${allSalaryData.length}개');
    } catch (e) {
      print('❌ [급여데이터] 로딩 오류: $e');
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
      print('🔍 [급여데이터] _loadSalaryData 완료 - isLoading: false');
    }
  }

  List<Map<String, dynamic>> get currentMonthData {
    print('🔍 [급여데이터] currentMonthData getter 호출');
    print('🔍 [급여데이터] allSalaryData 총 개수: ${allSalaryData.length}');
    print('🔍 [급여데이터] 필터 조건: year=${selectedMonth.year}, month=${selectedMonth.month}');
    
    final filteredData = allSalaryData.where((data) {
      // 데이터 타입 확인 및 변환
      final dataYear = data['year'];
      final dataMonth = data['month'];
      final targetYear = selectedMonth.year;
      final targetMonth = selectedMonth.month;
      
      print('🔍 [급여데이터] 데이터 비교: dataYear=$dataYear (${dataYear.runtimeType}) vs targetYear=$targetYear (${targetYear.runtimeType})');
      print('🔍 [급여데이터] 데이터 비교: dataMonth=$dataMonth (${dataMonth.runtimeType}) vs targetMonth=$targetMonth (${targetMonth.runtimeType})');
      
      // 타입 안전한 비교
      bool yearMatch = false;
      bool monthMatch = false;
      
      if (dataYear is int && targetYear is int) {
        yearMatch = dataYear == targetYear;
      } else if (dataYear is String && targetYear is int) {
        yearMatch = int.tryParse(dataYear.toString()) == targetYear;
      } else {
        yearMatch = dataYear.toString() == targetYear.toString();
      }
      
      if (dataMonth is int && targetMonth is int) {
        monthMatch = dataMonth == targetMonth;
      } else if (dataMonth is String && targetMonth is int) {
        monthMatch = int.tryParse(dataMonth.toString()) == targetMonth;
      } else {
        monthMatch = dataMonth.toString() == targetMonth.toString();
      }
      
      print('🔍 [급여데이터] 매치 결과: yearMatch=$yearMatch, monthMatch=$monthMatch');
      
      return yearMatch && monthMatch;
    }).toList();
    
    print('🔍 [급여데이터] 필터된 데이터 개수: ${filteredData.length}');
    
    if (allSalaryData.isNotEmpty) {
      print('📋 [급여데이터] allSalaryData 샘플:');
      for (int i = 0; i < allSalaryData.length && i < 3; i++) {
        final data = allSalaryData[i];
        print('  - ${i+1}: year=${data['year']} (${data['year'].runtimeType}), month=${data['month']} (${data['month'].runtimeType}), name=${data['employee_name']}');
      }
    }
    
    return filteredData;
  }

  Map<String, dynamic> get monthlySummary {
    final monthData = currentMonthData;
    if (monthData.isEmpty) return {};
    
    int totalSalaryBase = 0;
    int totalSalaryHour = 0; 
    int totalSalaryTotal = 0;
    int totalDeductionSum = 0;
    int totalSalaryNet = 0;
    
    for (var data in monthData) {
      totalSalaryBase += (data['salary_base'] ?? 0) as int;
      totalSalaryHour += (data['salary_hour'] ?? 0) as int;
      totalSalaryTotal += (data['salary_total'] ?? 0) as int;
      totalDeductionSum += (data['deduction_sum'] ?? 0) as int;
      totalSalaryNet += (data['salary_net'] ?? 0) as int;
    }
    
    return {
      'count': monthData.length,
      'total_salary_base': totalSalaryBase,
      'total_salary_hour': totalSalaryHour,
      'total_salary_total': totalSalaryTotal,
      'total_deduction_sum': totalDeductionSum,
      'total_salary_net': totalSalaryNet,
    };
  }

  Future<Map<String, String>> _getPreviousMonthTaxInfo() async {
    DateTime prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    
    try {
      // 현재 브랜치 ID 가져오기
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        return {'tax_office': '', 'tax_office_mail': ''};
      }

      // 직전월 강사 데이터에서 세무사 정보 조회
      final prevProData = await ApiService.getDataList(
        table: 'v2_salary_pro',
        fields: ['tax_office', 'tax_office_mail'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'year', 'operator': '=', 'value': prevMonth.year},
          {'field': 'month', 'operator': '=', 'value': prevMonth.month},
        ],
        limit: 1,
      );

      if (prevProData.isNotEmpty && (prevProData.first['tax_office'] ?? '').isNotEmpty) {
        return {
          'tax_office': prevProData.first['tax_office'] ?? '',
          'tax_office_mail': prevProData.first['tax_office_mail'] ?? '',
        };
      }

      // 강사 데이터에 없으면 매니저 데이터에서 조회
      final prevManagerData = await ApiService.getDataList(
        table: 'v2_salary_manager',
        fields: ['tax_office', 'tax_office_mail'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {'field': 'year', 'operator': '=', 'value': prevMonth.year},
          {'field': 'month', 'operator': '=', 'value': prevMonth.month},
        ],
        limit: 1,
      );

      if (prevManagerData.isNotEmpty) {
        return {
          'tax_office': prevManagerData.first['tax_office'] ?? '',
          'tax_office_mail': prevManagerData.first['tax_office_mail'] ?? '',
        };
      }
    } catch (e) {
      print('이전 월 세무사 정보 로딩 오류: $e');
    }
    
    return {'tax_office': '', 'tax_office_mail': ''};
  }

  void _showTaxAccountantModal() async {
    // 현재 월 데이터가 있으면 그것을, 없으면 직전월 데이터를 기본값으로 사용
    Map<String, String> defaultTaxInfo = await _getPreviousMonthTaxInfo();
    final currentData = currentMonthData.isNotEmpty ? currentMonthData.first : null;
    
    _taxOfficeController.text = currentData?['tax_office'] ?? defaultTaxInfo['tax_office'] ?? '';
    _taxOfficeMailController.text = currentData?['tax_office_mail'] ?? defaultTaxInfo['tax_office_mail'] ?? '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTaxAccountantHeader(),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '세무사 정보',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildTaxInputField('세무사 사무소명', _taxOfficeController),
                      SizedBox(height: 12),
                      _buildTaxInputField('이메일 주소', _taxOfficeMailController),
                      SizedBox(height: 20),
                      Text(
                        '${selectedMonth.year}년 ${selectedMonth.month}월 이후 급여처리 세무사로 등록합니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                '취소',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateTaxAccountantInfo(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SalaryFormService.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('저장'),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildTaxAccountantHeader() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: SalaryFormService.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '세무사 정보 관리',
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

  Widget _buildTaxInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 12, color: Colors.black),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: SalaryFormService.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  void _updateTaxAccountantInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('세무사 정보 업데이트'),
          content: Text(
            '${selectedMonth.year}년 ${selectedMonth.month}월 이후의 모든 급여 레코드에 세무사 정보를 업데이트하시겠습니까?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                _performTaxAccountantUpdate();
                Navigator.of(context).pop(); // 확인 다이얼로그 닫기
                Navigator.of(context).pop(); // 세무사 정보 모달 닫기
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SalaryFormService.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performTaxAccountantUpdate() async {
    try {
      // 현재 브랜치 ID 가져오기
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        throw Exception('브랜치 정보를 찾을 수 없습니다.');
      }

      final updateData = {
        'tax_office': _taxOfficeController.text,
        'tax_office_mail': _taxOfficeMailController.text,
      };

      // v2_salary_pro 테이블 업데이트 - 선택된 월 이후의 모든 레코드
      await ApiService.updateData(
        table: 'v2_salary_pro',
        data: updateData,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {
            'field': 'year',
            'operator': '>=',
            'value': selectedMonth.year,
          },
          {
            'field': 'month', 
            'operator': '>=',
            'value': selectedMonth.month,
          },
        ],
      );
      
      // v2_salary_manager 테이블 업데이트 - 선택된 월 이후의 모든 레코드  
      await ApiService.updateData(
        table: 'v2_salary_manager',
        data: updateData,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          {
            'field': 'year',
            'operator': '>=',
            'value': selectedMonth.year,
          },
          {
            'field': 'month',
            'operator': '>=', 
            'value': selectedMonth.month,
          },
        ],
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('세무사 정보가 업데이트되었습니다.'),
          backgroundColor: SalaryFormService.successColor,
        ),
      );
      
      // 데이터 새로고침
      await _loadSalaryData();
      
    } catch (e) {
      print('세무사 정보 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('세무사 정보 업데이트에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    // 이메일 내용 미리 생성
    final emailContent = await _buildEmailContent(monthData, taxOffice);
    
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '세무사 이메일 발송 확인',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${selectedMonth.year}년 ${selectedMonth.month}월 급여 공제 요청',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        icon: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                // 내용
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 수신자 정보
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: Colors.blue[700], size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '수신자 정보',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Text('세무사: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black)),
                                  Text(taxOffice, style: TextStyle(fontSize: 13, color: Colors.black)),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('이메일: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black)),
                                  Text(taxOfficeEmail, style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        // 이메일 내용 미리보기
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description, color: Colors.grey[700], size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '이메일 내용 미리보기',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                constraints: BoxConstraints(maxHeight: 300),
                                child: SingleChildScrollView(
                                  child: Text(
                                    emailContent,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        // 경고 메시지
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '발송 후 모든 직원의 상태가 "세무사검토"로 변경됩니다.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 버튼
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: Text('취소', style: TextStyle(color: Colors.grey[600])),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          icon: Icon(Icons.send, size: 16),
                          label: Text('발송'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
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
      },
    );

    // 사용자가 취소한 경우
    if (confirmed != true) {
      return;
    }

    setState(() {
      isSendingEmail = true;
    });

    try {
      // 각 직원별 토큰 생성 및 저장, 상태를 "세무사검토"로 변경
      for (var employee in monthData) {
        final token = _generateToken(
          employee['employee_id'].toString(),
          selectedMonth.month.toString(),
          selectedMonth.year.toString(),
        );
        
        // 토큰을 데이터베이스에 저장하고 상태를 "세무사검토"로 변경
        final String tableName = employee['employee_type'] == '강사' ? 'v2_salary_pro' : 'v2_salary_manager';
        final String idField = employee['employee_type'] == '강사' ? 'pro_id' : 'manager_id';
        
        await ApiService.updateData(
          table: tableName,
          data: {
            'tax_token': token,
            'salary_status': '세무사검토',
          },
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': employee['branch_id']},
            {'field': idField, 'operator': '=', 'value': employee['employee_id']},
            {'field': 'year', 'operator': '=', 'value': employee['year']},
            {'field': 'month', 'operator': '=', 'value': employee['month']},
          ],
        );
      }

      // 이메일 내용 생성
      final emailContent = await _buildEmailContent(monthData, taxOffice);
      
      // 이메일 발송 (개발 환경에서는 콘솔에 출력)
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
        isSendingEmail = false;
      });
    }
  }

  Future<String> _buildEmailContent(List<Map<String, dynamic>> monthData, String taxOffice) async {
    final buffer = StringBuffer();
    
    // 현재 지점 정보 조회
    String branchName = '지점명 없음';
    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId != null) {
        final branchData = await ApiService.getDataList(
          table: 'v2_branch',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
          ],
          limit: 1,
        );
        if (branchData.isNotEmpty) {
          branchName = branchData.first['branch_name'] ?? '지점명 없음';
        }
      }
    } catch (e) {
      print('지점 정보 조회 오류: $e');
    }
    
    buffer.writeln('${selectedMonth.year}년 ${selectedMonth.month}월 급여 세금 등 공제 관련 업무를 요청드립니다.\n');
    buffer.writeln('요청 지점: $branchName\n');
    buffer.writeln('아래 링크를 클릭하여 전체 직원의 공제금액을 일괄 입력해 주세요.\n');
    
    // 통합 토큰 생성 (년월 기반)
    final bulkToken = _generateToken(
      'bulk',
      selectedMonth.month.toString(),
      selectedMonth.year.toString(),
    );
    
    buffer.writeln('🔗 세금 등 공제입력 링크: ${_getWebUrl()}?token=$bulkToken');
    buffer.writeln('');
    
    int totalSalary = 0;
    int employeeCount = 0;
    
    buffer.writeln('--- 대상 직원 목록 ---');
    for (var employee in monthData) {
      totalSalary += (employee['salary_total'] ?? 0) as int;
      employeeCount++;
      
      buffer.writeln('${employeeCount}. ${employee['employee_name']} (${employee['employee_type']})');
      buffer.writeln('   - 총급여: ${_formatCurrency(employee['salary_total'] ?? 0)}');
      buffer.writeln('   - 계약형태: ${employee['contract_type'] ?? ''}');
      buffer.writeln('');
    }
    
    buffer.writeln('--- 요약 ---');
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

  Future<void> _updateDeductionInfo(Map<String, dynamic> data, String employeeKey) async {
    try {
      String contractType = data['contract_type'] ?? '고용(4대보험)';
      bool isFreelancer = contractType == '프리랜서';
      
      final updateData = {
        'four_insure': int.tryParse(_deductionControllers['${employeeKey}_four_insure']?.text ?? '0') ?? 0,
        'income_tax': int.tryParse(_deductionControllers['${employeeKey}_income_tax']?.text ?? '0') ?? 0,
        'business_income_tax': int.tryParse(_deductionControllers['${employeeKey}_business_income_tax']?.text ?? '0') ?? 0,
        'local_tax': int.tryParse(_deductionControllers['${employeeKey}_local_tax']?.text ?? '0') ?? 0,
        'other_deduction': int.tryParse(_deductionControllers['${employeeKey}_other_deduction']?.text ?? '0') ?? 0,
      };
      
      // 공제합계 계산
      int deductionSum = 0;
      if (isFreelancer) {
        deductionSum = updateData['business_income_tax']! + updateData['local_tax']! + updateData['other_deduction']!;
      } else {
        deductionSum = updateData['four_insure']! + updateData['income_tax']! + updateData['other_deduction']!;
      }
      updateData['deduction_sum'] = deductionSum;
      updateData['salary_net'] = data['salary_total'] - deductionSum;

      // 강사인지 매니저인지 구분해서 해당 테이블 업데이트
      String tableName = data['employee_type'] == '강사' ? 'v2_salary_pro' : 'v2_salary_manager';
      String idField = data['employee_type'] == '강사' ? 'pro_id' : 'manager_id';

      await ApiService.updateData(
        table: tableName,
        data: updateData,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': data['branch_id']},
          {'field': idField, 'operator': '=', 'value': data['employee_id']},
          {'field': 'year', 'operator': '=', 'value': data['year']},
          {'field': 'month', 'operator': '=', 'value': data['month']},
        ],
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('공제 정보가 업데이트되었습니다.'),
          backgroundColor: SalaryFormService.successColor,
        ),
      );
      
      // 데이터 새로고침
      await _loadSalaryData();
      
    } catch (e) {
      print('공제 정보 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('공제 정보 업데이트에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSalaryDetailModal(Map<String, dynamic> data) {
    // 지급완료 상태인 경우 읽기 전용으로 표시
    final isPaymentCompleted = data['salary_status'] == '지급완료';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DeductionInputPopup(
          employeeData: data,
          isReadOnly: isPaymentCompleted,
          onSave: (updatedData) {
            // 저장 성공시 데이터 새로고침
            _loadSalaryData();
          },
        );
      },
    );
  }

  void _showBulkDeductionModal() {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BulkDeductionInputPopup(
          employeesData: monthData,
          onSave: () {
            // 저장 성공시 데이터 새로고침
            _loadSalaryData();
          },
        );
      },
    );
  }

  void _showPaymentCompletionModal() {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PaymentCompletionPopup(
          employeesData: monthData,
          onSave: () {
            // 저장 성공시 데이터 새로고침
            _loadSalaryData();
          },
        );
      },
    );
  }

  Widget _buildSimpleHeader(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: SalaryFormService.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['employee_name']} 급여 상세',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${data['month']}월 급여 정산 내역',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
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

  Widget _buildDeductionCard(Map<String, dynamic> data, String employeeKey) {
    String contractType = data['contract_type'] ?? '고용(4대보험)';
    bool isFreelancer = contractType == '프리랜서';

    return StatefulBuilder(
      builder: (context, setState) {
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
              Row(
                children: [
                  Icon(Icons.remove_circle_outline, size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    '공제 내역',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (isFreelancer) ...[
                _buildTaxDeductionField('사업소득세', _deductionControllers['${employeeKey}_business_income_tax']!, setState),
                SizedBox(height: 8),
                _buildTaxDeductionField('지방소득세', _deductionControllers['${employeeKey}_local_tax']!, setState),
              ] else ...[
                _buildTaxDeductionField('4대보험료', _deductionControllers['${employeeKey}_four_insure']!, setState),
                SizedBox(height: 8),
                _buildTaxDeductionField('근로소득세', _deductionControllers['${employeeKey}_income_tax']!, setState),
              ],
              SizedBox(height: 8),
              _buildTaxDeductionField('기타급여공제', _deductionControllers['${employeeKey}_other_deduction']!, setState),
              SizedBox(height: 12),
              Container(
                height: 1,
                color: Color(0xFFE5E7EB),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '공제합계',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    _formatCurrency(_calculateTotalDeduction(employeeKey, isFreelancer)),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTaxDeductionField(String label, TextEditingController controller, Function setState) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.black),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: SalaryFormService.primaryColor, width: 2),
              ),
              suffixText: '원',
              suffixStyle: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  int _calculateTotalDeduction(String employeeKey, bool isFreelancer) {
    int total = 0;
    if (isFreelancer) {
      total += int.tryParse(_deductionControllers['${employeeKey}_business_income_tax']?.text ?? '0') ?? 0;
      total += int.tryParse(_deductionControllers['${employeeKey}_local_tax']?.text ?? '0') ?? 0;
    } else {
      total += int.tryParse(_deductionControllers['${employeeKey}_four_insure']?.text ?? '0') ?? 0;
      total += int.tryParse(_deductionControllers['${employeeKey}_income_tax']?.text ?? '0') ?? 0;
    }
    total += int.tryParse(_deductionControllers['${employeeKey}_other_deduction']?.text ?? '0') ?? 0;
    return total;
  }

  Widget _buildSalaryCompositionCard(Map<String, dynamic> data) {
    List<Widget> salaryItems = [];
    
    if ((data['salary_base'] ?? 0) != 0) {
      salaryItems.add(_buildSalaryRow('기본급', _formatCurrency(data['salary_base'] ?? 0)));
    }
    if ((data['salary_hour'] ?? 0) != 0) {
      salaryItems.add(_buildSalaryRow('시급', _formatCurrency(data['salary_hour'] ?? 0)));
    }
    if ((data['severance_pay'] ?? 0) != 0) {
      salaryItems.add(_buildSalaryRow('퇴직금', _formatCurrency(data['severance_pay'] ?? 0)));
    }
    
    // 강사인 경우 추가 항목들
    if (data['employee_type'] == '강사') {
      if ((data['salary_per_lesson'] ?? 0) != 0) {
        salaryItems.add(_buildSalaryRow('일반레슨', _formatCurrency(data['salary_per_lesson'] ?? 0)));
      }
      if ((data['salary_per_event'] ?? 0) != 0) {
        salaryItems.add(_buildSalaryRow('고객증정레슨', _formatCurrency(data['salary_per_event'] ?? 0)));
      }
      if ((data['salary_per_promo'] ?? 0) != 0) {
        salaryItems.add(_buildSalaryRow('신규체험레슨', _formatCurrency(data['salary_per_promo'] ?? 0)));
      }
      if ((data['salalry_per_noshow'] ?? data['salary_per_noshow'] ?? 0) != 0) { // 오타 고려
        salaryItems.add(_buildSalaryRow('노쇼', _formatCurrency(data['salalry_per_noshow'] ?? data['salary_per_noshow'] ?? 0)));
      }
    }

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
          Row(
            children: [
              Icon(Icons.attach_money, size: 16, color: Colors.black),
              SizedBox(width: 6),
              Text(
                '급여 구성',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...salaryItems,
          if (salaryItems.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(height: 1, color: Color(0xFFE5E7EB)),
            SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총급여',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                _formatCurrency(data['salary_total'] ?? 0),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value) {
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
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetPayCard(Map<String, dynamic> data, String employeeKey) {
    String contractType = data['contract_type'] ?? '고용(4대보험)';
    bool isFreelancer = contractType == '프리랜서';
    
    return StatefulBuilder(
      builder: (context, setState) {
        int totalDeduction = _calculateTotalDeduction(employeeKey, isFreelancer);
        int netPay = (data['salary_total'] ?? 0) - totalDeduction;
        
        return Container(
          padding: EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '실수령액',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '총급여 - 공제합계',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Text(
                _formatCurrency(netPay),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  String _formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '제출완료':
        return SalaryFormService.successColor;
      case '세무사검토':
        return Colors.orange;
      case '세무검토완료':
        return Colors.blue;
      case '지급완료':
        return Colors.purple;
      default:
        return SalaryFormService.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthData = currentMonthData;
    final summary = monthlySummary;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(SalaryFormService.largePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀과 버튼들
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '급여 관리',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: SalaryFormService.darkColor,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showTaxAccountantModal,
                    icon: Icon(Icons.account_balance, size: 16),
                    label: Text('세무사 정보'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SalaryFormService.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSendingEmail ? null : _sendEmailToTaxOffice,
                    icon: isSendingEmail 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.email, size: 16),
                    label: Text(isSendingEmail ? '발송 중...' : '세무사 발송'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showBulkDeductionModal,
                    icon: Icon(Icons.table_chart, size: 16),
                    label: Text('세금 등 공제입력'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showPaymentCompletionModal,
                    icon: Icon(Icons.payments, size: 16),
                    label: Text('지급완료'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
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
              _loadSalaryData(); // 월이 변경되면 데이터 새로 로딩
            },
          ),
          SizedBox(height: 16.0),
          
          // 월별 합계 정보
          if (summary.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: SalaryFormService.lightGrayColor,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: SalaryFormService.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('직원 수', '${summary['count']}명'),
                  _buildSummaryItem('기본급 합계', _formatCurrency(summary['total_salary_base'])),
                  _buildSummaryItem('시급 합계', _formatCurrency(summary['total_salary_hour'])),
                  _buildSummaryItem('총급여 합계', _formatCurrency(summary['total_salary_total'])),
                  _buildSummaryItem('공제 합계', _formatCurrency(summary['total_deduction_sum'])),
                  _buildSummaryItem('실수령액 합계', _formatCurrency(summary['total_salary_net'])),
                ],
              ),
            ),
            SizedBox(height: 16.0),
          ],
          
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
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '구분'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '이름'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '상태'),
                              ),
                              Expanded(
                                flex: 2,
                                child: SalaryFormService.buildTableHeaderCell(text: '계약형태'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '기본급'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '시급'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '총급여'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '공제합계'),
                              ),
                              Expanded(
                                flex: 1,
                                child: SalaryFormService.buildTableHeaderCell(text: '실수령액'),
                              ),
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
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: data['employee_name'] ?? '',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        child: Center(
                                          child: SalaryFormService.buildStatusBadge(
                                            status: data['salary_status'] ?? '',
                                            backgroundColor: _getStatusColor(data['salary_status'] ?? ''),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: data['contract_type'] ?? '',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: (data['salary_base'] ?? 0) == 0 
                                            ? '-' 
                                            : SalaryFormService.formatCurrency(data['salary_base'] ?? 0),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: (data['salary_hour'] ?? 0) == 0 
                                            ? '-' 
                                            : SalaryFormService.formatCurrency(data['salary_hour'] ?? 0),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: SalaryFormService.formatCurrency(data['salary_total'] ?? 0),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: SalaryFormService.formatCurrency(data['deduction_sum'] ?? 0),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: SalaryFormService.buildTableDataCell(
                                        text: SalaryFormService.formatCurrency(data['salary_net'] ?? 0),
                                        color: SalaryFormService.successColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      width: 50,
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Tooltip(
                                        message: '공제금액 입력/수정',
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            color: SalaryFormService.primaryColor,
                                            size: 18,
                                          ),
                                          onPressed: () => _showSalaryDetailModal(data),
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

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}