import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/salary_form_service.dart';
import '../services/api_service.dart';

class DeductionInputPopup extends StatefulWidget {
  final Map<String, dynamic> employeeData;
  final bool isReadOnly;
  final Function(Map<String, dynamic>)? onSave;

  const DeductionInputPopup({
    super.key,
    required this.employeeData,
    this.isReadOnly = false,
    this.onSave,
  });

  @override
  State<DeductionInputPopup> createState() => _DeductionInputPopupState();
}

class _DeductionInputPopupState extends State<DeductionInputPopup> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final data = widget.employeeData;
    
    _controllers['four_insure'] = TextEditingController(
      text: (data['four_insure'] ?? 0).toString()
    );
    _controllers['income_tax'] = TextEditingController(
      text: (data['income_tax'] ?? 0).toString()
    );
    _controllers['business_income_tax'] = TextEditingController(
      text: (data['business_income_tax'] ?? 0).toString()
    );
    _controllers['local_tax'] = TextEditingController(
      text: (data['local_tax'] ?? 0).toString()
    );
    _controllers['other_deduction'] = TextEditingController(
      text: (data['other_deduction'] ?? 0).toString()
    );
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  bool get _isFreelancer => 
    (widget.employeeData['contract_type'] ?? '') == '프리랜서';

  int get _totalDeduction {
    int total = 0;
    if (_isFreelancer) {
      total += int.tryParse(_controllers['business_income_tax']?.text ?? '0') ?? 0;
      total += int.tryParse(_controllers['local_tax']?.text ?? '0') ?? 0;
    } else {
      total += int.tryParse(_controllers['four_insure']?.text ?? '0') ?? 0;
      total += int.tryParse(_controllers['income_tax']?.text ?? '0') ?? 0;
    }
    total += int.tryParse(_controllers['other_deduction']?.text ?? '0') ?? 0;
    return total;
  }

  int get _netSalary {
    final totalSalary = widget.employeeData['salary_total'] ?? 0;
    return totalSalary - _totalDeduction;
  }

  Future<void> _saveDeduction() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final data = widget.employeeData;
      
      final updateData = {
        'four_insure': int.tryParse(_controllers['four_insure']?.text ?? '0') ?? 0,
        'income_tax': int.tryParse(_controllers['income_tax']?.text ?? '0') ?? 0,
        'business_income_tax': int.tryParse(_controllers['business_income_tax']?.text ?? '0') ?? 0,
        'local_tax': int.tryParse(_controllers['local_tax']?.text ?? '0') ?? 0,
        'other_deduction': int.tryParse(_controllers['other_deduction']?.text ?? '0') ?? 0,
        'deduction_sum': _totalDeduction,
        'salary_net': _netSalary,
        'salary_status': '세무검토완료',
      };

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
          content: Text('공제 정보가 저장되었습니다.'),
          backgroundColor: SalaryFormService.successColor,
        ),
      );

      if (widget.onSave != null) {
        widget.onSave!(updateData);
      }

      Navigator.of(context).pop(true);

    } catch (e) {
      print('공제 정보 저장 오류: $e');
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
    final data = widget.employeeData;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildEmployeeInfoCard(),
                    SizedBox(height: 16),
                    _buildSalaryInfoCard(),
                    SizedBox(height: 16),
                    _buildDeductionInputCard(),
                    SizedBox(height: 16),
                    _buildSummaryCard(),
                    if (!widget.isReadOnly) ...[
                      SizedBox(height: 20),
                      _buildActionButtons(),
                    ],
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
          Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.employeeData['employee_name']} 공제금액 ${widget.isReadOnly ? '조회' : '입력'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.employeeData['year']}년 ${widget.employeeData['month']}월',
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

  Widget _buildEmployeeInfoCard() {
    final data = widget.employeeData;
    
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
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
                child: _buildInfoItem('이름', data['employee_name'] ?? ''),
              ),
              Expanded(
                child: _buildInfoItem('구분', data['employee_type'] ?? ''),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildInfoItem('계약형태', data['contract_type'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildSalaryInfoCard() {
    final data = widget.employeeData;
    
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
            '급여 정보',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),
          if ((data['salary_base'] ?? 0) > 0)
            _buildInfoItem('기본급', _formatCurrency(data['salary_base'])),
          if ((data['salary_hour'] ?? 0) > 0)
            _buildInfoItem('시급', _formatCurrency(data['salary_hour'])),
          SizedBox(height: 8),
          Container(height: 1, color: Colors.blue[200]),
          SizedBox(height: 8),
          _buildInfoItem('총급여', _formatCurrency(data['salary_total']), isBold: true),
        ],
      ),
    );
  }

  Widget _buildDeductionInputCard() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '공제 항목 ${widget.isReadOnly ? '' : '입력'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              if (_isFreelancer) ...[
                _buildDeductionField('사업소득세', 'business_income_tax', setState),
                SizedBox(height: 12),
                _buildDeductionField('지방소득세', 'local_tax', setState),
              ] else ...[
                _buildDeductionField('4대보험료', 'four_insure', setState),
                SizedBox(height: 12),
                _buildDeductionField('근로소득세', 'income_tax', setState),
              ],
              SizedBox(height: 12),
              _buildDeductionField('기타공제', 'other_deduction', setState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeductionField(String label, String fieldName, Function setState) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _controllers[fieldName],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            readOnly: widget.isReadOnly,
            style: TextStyle(fontSize: 13, color: Colors.black),
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
              suffixText: '원',
              suffixStyle: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              filled: true,
              fillColor: widget.isReadOnly ? Colors.grey[100] : Colors.white,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              _buildSummaryRow('공제 합계', _formatCurrency(_totalDeduction), Colors.red),
              SizedBox(height: 8),
              Container(height: 1, color: Colors.green[200]),
              SizedBox(height: 8),
              _buildSummaryRow('실수령액', _formatCurrency(_netSalary), SalaryFormService.successColor, isBold: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, Color? color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black,
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
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveDeduction,
            style: ElevatedButton.styleFrom(
              backgroundColor: SalaryFormService.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('저장'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }

  // 외부에서 호출할 수 있는 static 메서드
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, dynamic> employeeData,
    bool isReadOnly = false,
    Function(Map<String, dynamic>)? onSave,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DeductionInputPopup(
          employeeData: employeeData,
          isReadOnly: isReadOnly,
          onSave: onSave,
        );
      },
    );
  }
}