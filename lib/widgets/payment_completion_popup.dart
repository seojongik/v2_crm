import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/salary_form_service.dart';
import '../services/api_service.dart';

class PaymentCompletionPopup extends StatefulWidget {
  final List<Map<String, dynamic>> employeesData;
  final Function()? onSave;

  const PaymentCompletionPopup({
    super.key,
    required this.employeesData,
    this.onSave,
  });

  @override
  State<PaymentCompletionPopup> createState() => _PaymentCompletionPopupState();
}

class _PaymentCompletionPopupState extends State<PaymentCompletionPopup> {
  final Map<String, bool> _checkedEmployees = {};
  bool _isSaving = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChecks();
  }

  void _initializeChecks() {
    for (var employee in widget.employeesData) {
      final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
      // 현재 상태가 '지급완료'인 경우 체크된 상태로 초기화
      _checkedEmployees[employeeKey] = employee['salary_status'] == '지급완료';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 세무검토완료 상태인 직원만 필터링
  List<Map<String, dynamic>> get eligibleEmployees {
    return widget.employeesData.where((employee) => 
      employee['salary_status'] == '세무검토완료' || employee['salary_status'] == '지급완료'
    ).toList();
  }

  Future<void> _confirmAndSave() async {
    // 변경 사항 계산
    int toCompleted = 0;
    int toReview = 0;
    int totalCompletedAmount = 0;
    int totalReviewAmount = 0;
    
    for (var employee in eligibleEmployees) {
      final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
      final isChecked = _checkedEmployees[employeeKey] ?? false;
      final currentStatus = employee['salary_status'];
      final netSalary = (employee['salary_net'] ?? 0) as int;
      
      if (isChecked && currentStatus != '지급완료') {
        toCompleted++;
        totalCompletedAmount += netSalary;
      } else if (!isChecked && currentStatus == '지급완료') {
        toReview++;
        totalReviewAmount += netSalary;
      }
    }
    
    // 변경사항이 없으면 메시지 표시
    if (toCompleted == 0 && toReview == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('변경사항이 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 요약 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.summarize, color: Colors.purple),
              SizedBox(width: 8),
              Text('변경 내역 확인'),
            ],
          ),
          content: Container(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (toCompleted > 0) ...[
                  _buildSummaryItem(
                    '지급완료로 변경',
                    '$toCompleted명',
                    _formatCurrency(totalCompletedAmount),
                    Colors.purple,
                  ),
                ],
                if (toReview > 0) ...[
                  if (toCompleted > 0) SizedBox(height: 12),
                  _buildSummaryItem(
                    '세무검토완료로 되돌림',
                    '$toReview명',
                    _formatCurrency(totalReviewAmount),
                    Colors.blue,
                  ),
                ],
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '이 작업을 진행하시겠습니까?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _savePaymentStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: Text('확인 및 저장'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, String count, String amount, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: color, size: 18),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '대상 인원: $count',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '실수령액 합계: $amount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _savePaymentStatus() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      for (var employee in eligibleEmployees) {
        final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
        final isChecked = _checkedEmployees[employeeKey] ?? false;
        
        // 체크된 경우 '지급완료', 체크 해제된 경우 '세무검토완료'
        final newStatus = isChecked ? '지급완료' : '세무검토완료';
        
        // 현재 상태와 다른 경우에만 업데이트
        if (employee['salary_status'] != newStatus) {
          final String tableName = employee['employee_type'] == '강사' ? 'v2_salary_pro' : 'v2_salary_manager';
          final String idField = employee['employee_type'] == '강사' ? 'pro_id' : 'manager_id';

          await ApiService.updateData(
            table: tableName,
            data: {'salary_status': newStatus},
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': employee['branch_id']},
              {'field': idField, 'operator': '=', 'value': employee['employee_id']},
              {'field': 'year', 'operator': '=', 'value': employee['year']},
              {'field': 'month', 'operator': '=', 'value': employee['month']},
            ],
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('지급 상태가 업데이트되었습니다.'),
          backgroundColor: SalaryFormService.successColor,
        ),
      );

      if (widget.onSave != null) {
        widget.onSave!();
      }

      Navigator.of(context).pop(true);

    } catch (e) {
      print('지급 상태 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('지급 상태 업데이트에 실패했습니다.'),
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
    final eligible = eligibleEmployees;
    
    if (eligible.isEmpty) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 48),
                SizedBox(height: 16),
                Text(
                  '지급 처리 가능한 직원이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '세무검토완료 상태인 직원만 지급완료 처리가 가능합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('확인'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
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
                    _buildInstructions(),
                    SizedBox(height: 20),
                    _buildEmployeeList(),
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
        color: Colors.purple,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '급여 지급완료 처리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '체크박스를 선택하여 지급완료 상태로 변경하세요',
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

  Widget _buildInstructions() {
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
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                '지급완료 처리 안내',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• 체크: 해당 직원을 지급완료 상태로 변경\n• 체크 해제: 세무검토완료 상태로 되돌림\n• 지급완료 상태에서는 공제금액 수정이 불가능합니다',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _buildListHeader(),
          ...eligibleEmployees.map((employee) => _buildEmployeeRow(employee)).toList(),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: SalaryFormService.lightGrayColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('선택', style: _headerTextStyle())),
          Expanded(flex: 2, child: Text('직원정보', style: _headerTextStyle())),
          Expanded(flex: 1, child: Text('현재상태', style: _headerTextStyle())),
          Expanded(flex: 2, child: Text('총급여', style: _headerTextStyle())),
          Expanded(flex: 2, child: Text('공제합계', style: _headerTextStyle())),
          Expanded(flex: 2, child: Text('실수령액', style: _headerTextStyle())),
        ],
      ),
    );
  }

  TextStyle _headerTextStyle() {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> employee) {
    final employeeKey = '${employee['employee_id']}_${employee['employee_type']}';
    final isChecked = _checkedEmployees[employeeKey] ?? false;

    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
        color: isChecked ? Colors.purple[50] : Colors.white,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isChecked,
              onChanged: (value) {
                setState(() {
                  _checkedEmployees[employeeKey] = value ?? false;
                });
              },
              activeColor: Colors.purple,
            ),
          ),
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
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(employee['salary_status'] ?? '').withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(employee['salary_status'] ?? ''),
                  width: 1,
                ),
              ),
              child: Text(
                employee['salary_status'] ?? '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(employee['salary_status'] ?? ''),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(employee['salary_total'] ?? 0),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(employee['deduction_sum'] ?? 0),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(employee['salary_net'] ?? 0),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: SalaryFormService.successColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final checkedCount = _checkedEmployees.values.where((checked) => checked).length;
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                '선택된 직원: ${checkedCount}명',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
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
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirmAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
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
                  : Text('지급 상태 저장'),
              ),
            ),
          ],
        ),
      ],
    );
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

  String _formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }
}