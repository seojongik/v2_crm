import 'package:flutter/material.dart';
import 'dart:html' as html;
import '/services/api_service.dart';
import '/widgets/deduction_input_popup.dart';
import '/services/salary_form_service.dart';

class TaxDeductionPage extends StatefulWidget {
  final String? token;
  
  const TaxDeductionPage({super.key, this.token});

  @override
  State<TaxDeductionPage> createState() => _TaxDeductionPageState();
}

class _TaxDeductionPageState extends State<TaxDeductionPage> {
  Map<String, dynamic>? employeeData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEmployeeDataByToken();
  }

  Future<void> _loadEmployeeDataByToken() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = '유효하지 않은 접근입니다.';
      });
      return;
    }

    try {
      // 토큰으로 강사 데이터 조회
      final proData = await ApiService.getDataList(
        table: 'v2_salary_pro',
        where: [
          {'field': 'tax_token', 'operator': '=', 'value': widget.token},
        ],
        limit: 1,
      );

      if (proData.isNotEmpty) {
        final data = proData.first;
        setState(() {
          employeeData = {
            ...data,
            'employee_type': '강사',
            'employee_name': data['pro_name'],
            'employee_id': data['pro_id'],
          };
          isLoading = false;
        });
        return;
      }

      // 강사 데이터가 없으면 매니저 데이터 조회
      final managerData = await ApiService.getDataList(
        table: 'v2_salary_manager',
        where: [
          {'field': 'tax_token', 'operator': '=', 'value': widget.token},
        ],
        limit: 1,
      );

      if (managerData.isNotEmpty) {
        final data = managerData.first;
        setState(() {
          employeeData = {
            ...data,
            'employee_type': '매니저',
            'employee_name': data['manager_name'],
            'employee_id': data['manager_id'],
          };
          isLoading = false;
        });
        return;
      }

      // 데이터를 찾을 수 없는 경우
      setState(() {
        isLoading = false;
        errorMessage = '해당하는 급여 데이터를 찾을 수 없습니다.';
      });

    } catch (e) {
      print('직원 데이터 로딩 오류: $e');
      setState(() {
        isLoading = false;
        errorMessage = '데이터를 불러오는데 실패했습니다.';
      });
    }
  }

  void _openDeductionPopup() {
    if (employeeData == null) return;

    // 지급완료 상태인 경우 읽기 전용으로 표시
    final isPaymentCompleted = employeeData!['salary_status'] == '지급완료';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DeductionInputPopup(
          employeeData: employeeData!,
          isReadOnly: isPaymentCompleted,
          onSave: (updatedData) {
            // 저장 후 페이지 새로고침 또는 성공 메시지 표시
            setState(() {
              // 업데이트된 데이터를 반영
              employeeData = {...employeeData!, ...updatedData};
            });
          },
        );
      },
    ).then((saved) {
      if (saved == true) {
        // 저장 성공시 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공제 정보가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('급여 공제 정보 입력'),
        backgroundColor: SalaryFormService.primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: isLoading
        ? Center(child: CircularProgressIndicator())
        : errorMessage != null
          ? _buildErrorView()
          : _buildMainContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        margin: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            SizedBox(height: 16),
            Text(
              '오류',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (employeeData == null) return SizedBox();

    final data = employeeData!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWelcomeCard(),
              SizedBox(height: 24),
              _buildEmployeeInfoCard(),
              SizedBox(height: 24),
              _buildActionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance,
            size: 48,
            color: SalaryFormService.primaryColor,
          ),
          SizedBox(height: 16),
          Text(
            '급여 공제 정보 입력',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '세무사님께서 해당 직원의 급여 공제금액을 입력하실 수 있습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard() {
    final data = employeeData!;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '직원 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16),
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
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('계약형태', data['contract_type'] ?? ''),
              ),
              Expanded(
                child: _buildInfoItem('처리월', '${data['year']}년 ${data['month']}월'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(height: 1, color: Colors.grey[300]),
          SizedBox(height: 16),
          _buildInfoItem('총 급여', '${(data['salary_total'] ?? 0):,}원', isBold: true),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.edit_outlined,
            size: 32,
            color: SalaryFormService.primaryColor,
          ),
          SizedBox(height: 16),
          Text(
            '공제 정보 입력',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '아래 버튼을 클릭하여 해당 직원의 세금 및 공제 정보를 입력해 주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openDeductionPopup,
              style: ElevatedButton.styleFrom(
                backgroundColor: SalaryFormService.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '공제 정보 입력하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // URL에서 토큰을 추출하는 헬퍼 메서드 (웹에서 사용)
  static String? getTokenFromUrl() {
    if (html.window.location.search.isNotEmpty) {
      final uri = Uri.parse(html.window.location.href);
      return uri.queryParameters['token'];
    }
    return null;
  }
}