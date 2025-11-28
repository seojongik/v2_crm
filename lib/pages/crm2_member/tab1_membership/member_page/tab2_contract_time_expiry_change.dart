import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';

class TimeExpiryChangeDialog extends StatefulWidget {
  final int contractHistoryId;
  final VoidCallback? onSaved;

  const TimeExpiryChangeDialog({
    Key? key,
    required this.contractHistoryId,
    this.onSaved,
  }) : super(key: key);

  @override
  State<TimeExpiryChangeDialog> createState() => _TimeExpiryChangeDialogState();
}

class _TimeExpiryChangeDialogState extends State<TimeExpiryChangeDialog> {
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

      final response = await ApiService.getDataList(
        table: 'v2_bill_times',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
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

      print('=== 타석시간 유효기간 조회 디버깅 ===');
      print('contract_history_id: ${widget.contractHistoryId}');
      print('조회 결과: $response');
      
      if (response.isNotEmpty) {
        final billData = response.first;
        print('billData: $billData');
        final expiryDateStr = billData['contract_TS_min_expiry_date'];
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

      // 먼저 가장 최근 bill_min_id를 찾기
      final latestBillResponse = await ApiService.getDataList(
        table: 'v2_bill_times',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
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

      if (latestBillResponse.isEmpty) {
        throw Exception('해당 계약의 타석시간 데이터를 찾을 수 없습니다.');
      }

      final latestBill = latestBillResponse.first;
      final latestBillMinId = latestBill['bill_min_id'];
      
      print('=== 타석시간 유효기간 조정 디버깅 ===');
      print('contract_history_id: ${widget.contractHistoryId}');
      print('latestBill: $latestBill');
      print('latestBillMinId: $latestBillMinId');
      print('새 유효기간: ${DateFormat('yyyy-MM-dd').format(newExpiryDate!)}');

      // 해당 bill_min_id의 유효기간만 업데이트
      final response = await ApiService.updateData(
        table: 'v2_bill_times',
        data: {
          'contract_TS_min_expiry_date': DateFormat('yyyy-MM-dd').format(newExpiryDate!),
        },
        where: [
          {
            'field': 'bill_min_id',
            'operator': '=',
            'value': latestBillMinId,
          }
        ],
      );

      print('업데이트 응답: $response');
      
      if (response['affectedRows'] > 0) {
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
        throw Exception('유효기간 변경에 실패했습니다. affectedRows: ${response['affectedRows']}');
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Row(
              children: [
                Icon(
                  Icons.sports_golf,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '타석시간 유효기간 조정',
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: AppTextStyles.bodyText.copyWith(
                          color: Colors.red[600],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // 현재 유효기간
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 유효기간',
                      style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentExpiryDate != null
                          ? DateFormat('yyyy년 MM월 dd일').format(currentExpiryDate!)
                          : '정보 없음',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 18,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 새 유효기간 입력
              Text(
                '새 유효기간',
                style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _selectDate,
                decoration: InputDecoration(
                  hintText: '날짜를 선택하세요',
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF10B981)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 버튼들
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveExpiryDate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              '저장',
                              style: AppTextStyles.button.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}