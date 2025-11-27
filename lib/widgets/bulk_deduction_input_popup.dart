import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/salary_form_service.dart';
import '../services/api_service.dart';

class BulkDeductionInputPopup extends StatefulWidget {
  final List<Map<String, dynamic>> employeesData;
  final Function()? onSave;

  const BulkDeductionInputPopup({
    super.key,
    required this.employeesData,
    this.onSave,
  });

  @override
  State<BulkDeductionInputPopup> createState() => _BulkDeductionInputPopupState();
}

class _BulkDeductionInputPopupState extends State<BulkDeductionInputPopup> {
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  bool _isSaving = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (var employee in editableEmployees) {
      final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
      
      _controllers[employeeKey] = {
        'four_insure': TextEditingController(
          text: (employee['four_insure'] ?? 0).toString()
        ),
        'income_tax': TextEditingController(
          text: (employee['income_tax'] ?? 0).toString()
        ),
        'business_income_tax': TextEditingController(
          text: (employee['business_income_tax'] ?? 0).toString()
        ),
        'local_tax': TextEditingController(
          text: (employee['local_tax'] ?? 0).toString()
        ),
        'other_deduction': TextEditingController(
          text: (employee['other_deduction'] ?? 0).toString()
        ),
      };
    }
  }

  @override
  void dispose() {
    _controllers.forEach((employeeKey, controllers) {
      controllers.forEach((field, controller) {
        controller.dispose();
      });
    });
    _scrollController.dispose();
    super.dispose();
  }

  bool _isFreelancer(Map<String, dynamic> employee) => 
    (employee['contract_type'] ?? '') == '프리랜서';

  // 지급완료 상태가 아닌 편집 가능한 직원들만 필터링
  List<Map<String, dynamic>> get editableEmployees {
    return widget.employeesData.where((employee) => 
      employee['salary_status'] != '지급완료'
    ).toList();
  }

  int _getTotalDeduction(String employeeKey, bool isFreelancer) {
    final controllers = _controllers[employeeKey]!;
    int total = 0;
    
    if (isFreelancer) {
      total += int.tryParse(controllers['business_income_tax']?.text ?? '0') ?? 0;
      total += int.tryParse(controllers['local_tax']?.text ?? '0') ?? 0;
    } else {
      total += int.tryParse(controllers['four_insure']?.text ?? '0') ?? 0;
      total += int.tryParse(controllers['income_tax']?.text ?? '0') ?? 0;
    }
    total += int.tryParse(controllers['other_deduction']?.text ?? '0') ?? 0;
    return total;
  }

  int _getNetSalary(Map<String, dynamic> employee, int totalDeduction) {
    final totalSalary = employee['salary_total'] ?? 0;
    return totalSalary - totalDeduction;
  }

  Future<void> _saveAllDeductions() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      for (var employee in editableEmployees) {
        final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
        final controllers = _controllers[employeeKey]!;
        final isFreelancer = _isFreelancer(employee);
        final totalDeduction = _getTotalDeduction(employeeKey, isFreelancer);
        
        final updateData = {
          'four_insure': int.tryParse(controllers['four_insure']?.text ?? '0') ?? 0,
          'income_tax': int.tryParse(controllers['income_tax']?.text ?? '0') ?? 0,
          'business_income_tax': int.tryParse(controllers['business_income_tax']?.text ?? '0') ?? 0,
          'local_tax': int.tryParse(controllers['local_tax']?.text ?? '0') ?? 0,
          'other_deduction': int.tryParse(controllers['other_deduction']?.text ?? '0') ?? 0,
          'deduction_sum': totalDeduction,
          'salary_net': _getNetSalary(employee, totalDeduction),
          'salary_status': '세무검토완료',
        };

        // 강사인지 매니저인지 구분해서 해당 테이블 업데이트
        String tableName = employee['employee_type'] == '강사' ? 'v2_salary_pro' : 'v2_salary_manager';
        String idField = employee['employee_type'] == '강사' ? 'pro_id' : 'manager_id';

        await ApiService.updateData(
          table: tableName,
          data: updateData,
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': employee['branch_id']},
            {'field': idField, 'operator': '=', 'value': employee['employee_id']},
            {'field': 'year', 'operator': '=', 'value': employee['year']},
            {'field': 'month', 'operator': '=', 'value': employee['month']},
          ],
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모든 직원의 공제 정보가 저장되었습니다.'),
          backgroundColor: SalaryFormService.successColor,
        ),
      );

      if (widget.onSave != null) {
        widget.onSave!();
      }

      Navigator.of(context).pop(true);

    } catch (e) {
      print('일괄 공제 정보 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('공제 정보 저장에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildSummaryCard(),
                    SizedBox(height: 20),
                    _buildEmployeeTable(),
                    SizedBox(height: 20),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: SalaryFormService.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 직원 공제금액 일괄 입력',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${editableEmployees.length}명의 편집 가능한 직원 (지급완료 제외)',
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

  Widget _buildSummaryCard() {
    final editable = editableEmployees;
    int totalEmployees = editable.length;
    int totalSalary = editable.fold(0, (sum, emp) => sum + (emp['salary_total'] ?? 0) as int);
    int totalCurrentDeductions = 0;
    int totalNewDeductions = 0;
    
    for (var employee in editable) {
      final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
      totalCurrentDeductions += (employee['deduction_sum'] ?? 0) as int;
      totalNewDeductions += _getTotalDeduction(employeeKey, _isFreelancer(employee));
    }

    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '급여 요약',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('총 직원 수', '${totalEmployees}명')),
              Expanded(child: _buildSummaryItem('총 급여', _formatCurrency(totalSalary))),
              Expanded(child: _buildSummaryItem('현재 공제합계', _formatCurrency(totalCurrentDeductions))),
              Expanded(child: _buildSummaryItem('예상 공제합계', _formatCurrency(totalNewDeductions))),
            ],
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
            color: Colors.black.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmployeeTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          ...editableEmployees.map((employee) => _buildEmployeeRow(employee)).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: SalaryFormService.lightGrayColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildHeaderCell('직원정보')),
          Expanded(flex: 2, child: _buildHeaderCell('총급여')),
          Expanded(flex: 3, child: _buildHeaderCell('공제항목')),
          Expanded(flex: 2, child: _buildHeaderCell('공제합계')),
          Expanded(flex: 2, child: _buildHeaderCell('실수령액')),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> employee) {
    final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
    final isFreelancer = _isFreelancer(employee);
    final controllers = _controllers[employeeKey]!;

    return StatefulBuilder(
      builder: (context, setState) {
        final totalDeduction = _getTotalDeduction(employeeKey, isFreelancer);
        final netSalary = _getNetSalary(employee, totalDeduction);

        return Container(
          padding: EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 직원정보
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee['employee_name'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '${employee['employee_type']} (${employee['contract_type']})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // 총급여
              Expanded(
                flex: 2,
                child: Text(
                  _formatCurrency(employee['salary_total'] ?? 0),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 공제항목
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    if (isFreelancer) ...[
                      _buildSmallDeductionField('사업소득세', controllers['business_income_tax']!, setState),
                      SizedBox(height: 4),
                      _buildSmallDeductionField('지방소득세', controllers['local_tax']!, setState),
                    ] else ...[
                      _buildSmallDeductionField('4대보험료', controllers['four_insure']!, setState),
                      SizedBox(height: 4),
                      _buildSmallDeductionField('근로소득세', controllers['income_tax']!, setState),
                    ],
                    SizedBox(height: 4),
                    _buildSmallDeductionField('기타공제', controllers['other_deduction']!, setState),
                  ],
                ),
              ),
              // 공제합계
              Expanded(
                flex: 2,
                child: Text(
                  _formatCurrency(totalDeduction),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 실수령액
              Expanded(
                flex: 2,
                child: Text(
                  _formatCurrency(netSalary),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: SalaryFormService.successColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmallDeductionField(String label, TextEditingController controller, Function setState) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.black),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: SalaryFormService.primaryColor, width: 1),
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

  Widget _buildActionButtons() {
    return Row(
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
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAllDeductions,
            style: ElevatedButton.styleFrom(
              backgroundColor: SalaryFormService.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('전체 저장'),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }
}