import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';
import 'tab2_contract_popup_design.dart';

class GameManualDialog extends StatefulWidget {
  final Map<String, dynamic> contract;
  final VoidCallback? onSaved;

  const GameManualDialog({
    Key? key,
    required this.contract,
    this.onSaved,
  }) : super(key: key);

  @override
  State<GameManualDialog> createState() => _GameManualDialogState();
}

class _GameManualDialogState extends State<GameManualDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _gameController = TextEditingController();
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
    _gameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    try {
      // 현재 잔액 조회 (가장 최근 bill_game_id)
      final response = await ApiService.getDataList(
        table: 'v2_bill_games',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contract['contract_history_id'],
          }
        ],
        orderBy: [
          {
            'field': 'bill_game_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (response.isNotEmpty) {
        setState(() {
          currentBalance = int.tryParse(response.first['bill_balance_game_after']?.toString() ?? '0') ?? 0;
          currentExpiryDate = response.first['contract_games_expiry_date']?.toString();
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

      final gameCount = int.parse(_gameController.text);
      final memo = _memoController.text.trim();
      
      int newBalance;
      if (selectedType == '차감') {
        newBalance = currentBalance - gameCount;
      } else {
        newBalance = currentBalance + gameCount;
      }

      // v2_bill_games에 새 레코드 추가
      final response = await ApiService.addBillGamesData({
        'member_id': widget.contract['member_id'],
        'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'bill_text': memo.isNotEmpty ? memo : '수동$selectedType',
        'bill_type': '수동$selectedType',
        'bill_games': gameCount,
        'bill_balance_game_before': currentBalance,
        'bill_balance_game_after': newBalance,
        'bill_timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'bill_status': '결제완료',
        'contract_history_id': widget.contract['contract_history_id'],
        'contract_games_expiry_date': currentExpiryDate, // 기존 유효기간 유지
        'member_name': widget.contract['member_name'] ?? '',
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
      benefitType: 'game',
      title: '스크린게임 수동처리',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재 잔액 표시
            ContractInfoCard(
              title: '현재 잔액',
              content: '${currentBalance}회',
              benefitType: 'game',
              icon: Icons.sports_esports,
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
                    benefitType: 'game',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ContractSelectionButton(
                    text: '적립',
                    isSelected: selectedType == '적립',
                    onTap: () => setState(() => selectedType = '적립'),
                    benefitType: 'game',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 게임 횟수 입력
            ContractInputField(
              label: '게임 횟수',
              hint: '게임 횟수를 입력하세요',
              controller: _gameController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              isRequired: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '게임 횟수를 입력해주세요';
                }
                final gameCount = int.tryParse(value);
                if (gameCount == null || gameCount <= 0) {
                  return '올바른 횟수를 입력해주세요';
                }
                if (selectedType == '차감' && gameCount > currentBalance) {
                  return '현재 잔액보다 큰 횟수는 차감할 수 없습니다';
                }
                return null;
              },
              suffix: Container(
                padding: EdgeInsets.all(12),
                child: Text(
                  '회',
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
          benefitType: 'game',
          isSecondary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        ContractActionButton(
          text: selectedType,
          benefitType: 'game',
          isLoading: isLoading,
          onPressed: _saveManualTransaction,
        ),
      ],
    );
  }
}