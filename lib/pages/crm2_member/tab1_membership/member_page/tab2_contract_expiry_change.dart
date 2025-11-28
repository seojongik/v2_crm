import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';
import 'tab2_contract_popup_design.dart';

class ExpiryChangeDialog extends StatefulWidget {
  final int contractHistoryId;
  final String benefitType; // 'credit', 'time', 'game', 'lesson', 'term'
  final VoidCallback? onSaved;

  const ExpiryChangeDialog({
    Key? key,
    required this.contractHistoryId,
    required this.benefitType,
    this.onSaved,
  }) : super(key: key);

  @override
  State<ExpiryChangeDialog> createState() => _ExpiryChangeDialogState();
}

class _ExpiryChangeDialogState extends State<ExpiryChangeDialog> {
  bool isLoading = true;
  String? errorMessage;
  DateTime? currentExpiryDate;
  DateTime? newExpiryDate;
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentExpiryDate();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentExpiryDate() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // benefitType에 따라 테이블과 필드 결정
      String tableName;
      String primaryKeyField;
      String expiryField;
      
      switch (widget.benefitType) {
        case 'credit':
          tableName = 'v2_bills';
          primaryKeyField = 'bill_id';
          expiryField = 'contract_credit_expiry_date';
          break;
        case 'time':
          tableName = 'v2_bill_times';
          primaryKeyField = 'bill_min_id';
          expiryField = 'contract_TS_min_expiry_date';
          break;
        case 'game':
          tableName = 'v2_bill_games';
          primaryKeyField = 'bill_game_id';
          expiryField = 'contract_games_expiry_date';
          break;
        case 'lesson':
          tableName = 'v3_LS_countings';
          primaryKeyField = 'LS_counting_id';
          expiryField = 'LS_expiry_date';
          break;
        case 'term':
          tableName = 'v2_bill_term';
          primaryKeyField = 'bill_term_id';
          expiryField = 'contract_term_month_expiry_date';
          break;
        default:
          throw Exception('지원하지 않는 benefitType: ${widget.benefitType}');
      }

      final response = await ApiService.getDataList(
        table: tableName,
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
          }
        ],
        orderBy: [
          {
            'field': primaryKeyField,
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      print('=== ${widget.benefitType} 유효기간 조회 디버깅 ===');
      print('contract_history_id: ${widget.contractHistoryId}');
      print('테이블: $tableName');
      print('조회 결과: $response');
      
      if (response.isNotEmpty) {
        final billData = response.first;
        print('billData: $billData');
        final expiryDateStr = billData[expiryField];
        print('expiryDateStr: $expiryDateStr');
        if (expiryDateStr != null) {
          currentExpiryDate = DateTime.parse(expiryDateStr);
          newExpiryDate = currentExpiryDate;
          _dateController.text = DateFormat('yyyy-MM-dd').format(currentExpiryDate!);
        }
      } else {
        errorMessage = '유효기간 정보를 불러올 수 없습니다.';
      }
    } catch (e) {
      errorMessage = '네트워크 오류가 발생했습니다: $e';
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: newExpiryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null) {
      setState(() {
        newExpiryDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveExpiryDate() async {
    if (newExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 유효기간을 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      // benefitType에 따라 테이블과 필드 결정
      String tableName;
      String primaryKeyField;
      String expiryField;
      
      switch (widget.benefitType) {
        case 'credit':
          tableName = 'v2_bills';
          primaryKeyField = 'bill_id';
          expiryField = 'contract_credit_expiry_date';
          break;
        case 'time':
          tableName = 'v2_bill_times';
          primaryKeyField = 'bill_min_id';
          expiryField = 'contract_TS_min_expiry_date';
          break;
        case 'game':
          tableName = 'v2_bill_games';
          primaryKeyField = 'bill_game_id';
          expiryField = 'contract_games_expiry_date';
          break;
        case 'lesson':
          tableName = 'v3_LS_countings';
          primaryKeyField = 'LS_counting_id';
          expiryField = 'LS_expiry_date';
          break;
        case 'term':
          tableName = 'v2_bill_term';
          primaryKeyField = 'bill_term_id';
          expiryField = 'contract_term_month_expiry_date';
          break;
        default:
          throw Exception('지원하지 않는 benefitType: ${widget.benefitType}');
      }

      // 먼저 가장 최근 레코드를 찾기
      final latestBillResponse = await ApiService.getDataList(
        table: tableName,
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
          }
        ],
        orderBy: [
          {
            'field': primaryKeyField,
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (latestBillResponse.isEmpty) {
        throw Exception('해당 계약의 데이터를 찾을 수 없습니다.');
      }

      final latestBill = latestBillResponse.first;
      final latestBillId = latestBill[primaryKeyField];
      
      print('=== ${widget.benefitType} 유효기간 조정 디버깅 ===');
      print('contract_history_id: ${widget.contractHistoryId}');
      print('테이블: $tableName');
      print('latestBill: $latestBill');
      print('latestBillId: $latestBillId');
      print('새 유효기간: ${DateFormat('yyyy-MM-dd').format(newExpiryDate!)}');

      // 해당 레코드의 유효기간만 업데이트
      final response = await ApiService.updateData(
        table: tableName,
        data: {
          expiryField: DateFormat('yyyy-MM-dd').format(newExpiryDate!),
        },
        where: [
          {
            'field': primaryKeyField,
            'operator': '=',
            'value': latestBillId,
          }
        ],
      );

      print('업데이트 응답: $response');

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('유효기간이 성공적으로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onSaved != null) {
          widget.onSaved!();
        }

        Navigator.of(context).pop();
      } else {
        throw Exception('유효기간 변경에 실패했습니다: ${response['message']}');
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
    final theme = BenefitTypeTheme.getTheme(widget.benefitType);
    
    return BaseContractDialog(
      benefitType: widget.benefitType,
      title: '${theme.name} 유효기간 조정',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: theme.primary),
              ),
            )
          else if (errorMessage != null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFDC2626).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 현재 유효기간 정보
            ContractInfoCard(
              title: '현재 유효기간',
              content: currentExpiryDate != null
                  ? ContractUtils.formatDate(currentExpiryDate!)
                  : '정보 없음',
              benefitType: widget.benefitType,
              icon: Icons.schedule,
            ),
            SizedBox(height: 24),

            // 새 유효기간 입력
            ContractInputField(
              label: '새 유효기간',
              hint: '날짜를 선택하세요',
              controller: _dateController,
              isRequired: true,
              enabled: false,
              suffix: IconButton(
                onPressed: _selectDate,
                icon: Icon(Icons.calendar_today, color: theme.primary),
              ),
            ),
          ],
        ],
      ),
      actions: isLoading || errorMessage != null ? null : [
        ContractActionButton(
          text: '취소',
          benefitType: widget.benefitType,
          isSecondary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        ContractActionButton(
          text: '저장',
          benefitType: widget.benefitType,
          isLoading: isLoading,
          onPressed: _saveExpiryDate,
        ),
      ],
    );
  }
}