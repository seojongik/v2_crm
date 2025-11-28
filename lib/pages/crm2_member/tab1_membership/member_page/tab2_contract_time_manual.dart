import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';
import 'tab2_contract_popup_design.dart';

class TimeManualDialog extends StatefulWidget {
  final Map<String, dynamic> contract;
  final VoidCallback? onSaved;

  const TimeManualDialog({
    Key? key,
    required this.contract,
    this.onSaved,
  }) : super(key: key);

  @override
  State<TimeManualDialog> createState() => _TimeManualDialogState();
}

class _TimeManualDialogState extends State<TimeManualDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  
  bool isLoading = false;
  String selectedType = '차감'; // '차감' 또는 '적립'
  int currentBalance = 0;
  String? currentExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    try {
      // 현재 잔액 조회 (가장 최근 bill_min_id)
      final response = await ApiService.getDataList(
        table: 'v2_bill_times',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contract['contract_history_id'],
          }
        ],
        orderBy: [
          {
            'field': 'bill_min_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (response.isNotEmpty) {
        setState(() {
          currentBalance = int.tryParse(response.first['bill_balance_min_after']?.toString() ?? '0') ?? 0;
          currentExpiryDate = response.first['contract_TS_min_expiry_date']?.toString();
        });
      }
    } catch (e) {
      print('잔액 조회 오류: $e');
    }
  }

  Future<void> _saveManualTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        isLoading = true;
      });

      final timeMinutes = int.parse(_timeController.text);
      final memo = _memoController.text.trim();
      
      int newBalance;
      if (selectedType == '차감') {
        newBalance = currentBalance - timeMinutes;
      } else {
        newBalance = currentBalance + timeMinutes;
      }

      // v2_bill_times에 새 레코드 추가
      final response = await ApiService.addBillTimesData({
        'member_id': widget.contract['member_id'],
        'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'bill_text': memo.isNotEmpty ? memo : '수동$selectedType',
        'bill_type': '수동$selectedType',
        'bill_total_min': timeMinutes,
        'bill_discount_min': 0,
        'bill_min': timeMinutes,
        'bill_balance_min_before': currentBalance,
        'bill_balance_min_after': newBalance,
        'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'bill_status': '결제완료',
        'contract_history_id': widget.contract['contract_history_id'],
        'contract_TS_min_expiry_date': currentExpiryDate, // 기존 유효기간 유지
      });

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedType}이 성공적으로 처리되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (widget.onSaved != null) {
          widget.onSaved!();
        }
        
        Navigator.of(context).pop();
      } else {
        throw Exception(response['message'] ?? '처리에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseContractDialog(
      benefitType: 'time',
      title: '타석시간 수동처리',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재 잔액 표시
            ContractInfoCard(
              title: '현재 잔액',
              content: '${NumberFormat('#,###').format(currentBalance)}분',
              benefitType: 'time',
              icon: Icons.access_time,
            ),
            SizedBox(height: 24),

            // 처리 유형 선택
            Text(
              '처리 유형',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ContractSelectionButton(
                    text: '차감',
                    isSelected: selectedType == '차감',
                    onTap: () => setState(() => selectedType = '차감'),
                    benefitType: 'time',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ContractSelectionButton(
                    text: '적립',
                    isSelected: selectedType == '적립',
                    onTap: () => setState(() => selectedType = '적립'),
                    benefitType: 'time',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 시간 입력
            ContractInputField(
              label: '시간 (분)',
              hint: '시간을 분 단위로 입력하세요',
              controller: _timeController,
              keyboardType: TextInputType.number,
              isRequired: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '시간을 입력해주세요';
                }
                final timeMinutes = int.tryParse(value);
                if (timeMinutes == null || timeMinutes <= 0) {
                  return '올바른 시간을 입력해주세요';
                }
                if (selectedType == '차감' && timeMinutes > currentBalance) {
                  return '현재 잔액보다 큰 금액은 차감할 수 없습니다';
                }
                return null;
              },
              suffix: Container(
                padding: EdgeInsets.all(12),
                child: Text(
                  '분',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),

            // 메모 입력
            ContractInputField(
              label: '메모',
              hint: '처리 사유를 입력하세요',
              controller: _memoController,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        ContractActionButton(
          text: '취소',
          benefitType: 'time',
          isSecondary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        ContractActionButton(
          text: selectedType,
          benefitType: 'time',
          isLoading: isLoading,
          onPressed: _saveManualTransaction,
        ),
      ],
    );
  }
}