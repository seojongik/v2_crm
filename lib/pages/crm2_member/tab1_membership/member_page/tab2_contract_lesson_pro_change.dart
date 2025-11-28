import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';
import 'tab2_contract_popup_design.dart';

class LessonProChangeDialog extends StatefulWidget {
  final Map<String, dynamic> contract;
  final VoidCallback? onSaved;

  const LessonProChangeDialog({
    Key? key,
    required this.contract,
    this.onSaved,
  }) : super(key: key);

  @override
  State<LessonProChangeDialog> createState() => _LessonProChangeDialogState();
}

class _LessonProChangeDialogState extends State<LessonProChangeDialog> {
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  // 현재 프로 정보
  String? currentProId;
  String? currentProName;

  // 프로 목록
  List<Map<String, dynamic>> availablePros = [];
  Map<String, dynamic>? selectedPro;

  // 현재 LS_counting 정보
  Map<String, dynamic>? currentLSCounting;

  @override
  void initState() {
    super.initState();
    _loadCurrentProAndList();
  }

  Future<void> _loadCurrentProAndList() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 1. 현재 레슨 카운팅 정보 가져오기 (가장 최근 레코드)
      final lsCountingResponse = await ApiService.getDataList(
        table: 'v3_LS_countings',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contract['contract_history_id'],
          }
        ],
        orderBy: [
          {
            'field': 'LS_counting_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (lsCountingResponse.isNotEmpty) {
        currentLSCounting = lsCountingResponse.first;
        // 2. 최신 레코드에서 현재 프로 정보 가져오기
        currentProId = currentLSCounting!['pro_id']?.toString();
        currentProName = currentLSCounting!['pro_name']?.toString();
      } else {
        throw Exception('레슨 카운팅 정보를 찾을 수 없습니다.');
      }

      // 3. 재직중인 프로 목록 가져오기
      final prosResponse = await ApiService.getDataList(
        table: 'v2_staff_pro',
        where: [
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직',
          }
        ],
        orderBy: [
          {
            'field': 'pro_name',
            'direction': 'ASC',
          }
        ],
      );

      print('=== 프로변경 다이얼로그 디버깅 ===');
      print('현재 프로: $currentProName ($currentProId)');
      print('재직중인 프로 수: ${prosResponse.length}');
      print('현재 LS_counting: $currentLSCounting');

      // pro_id로 중복 제거 (같은 프로의 여러 계약차수가 있을 수 있음)
      Map<int, Map<String, dynamic>> uniquePros = {};
      for (final pro in prosResponse) {
        final proId = pro['pro_id'];
        if (proId != null) {
          // 동일한 pro_id가 있으면 가장 최근 계약으로 덮어쓰기 (나중에 오는 것이 최신)
          uniquePros[proId] = pro;
        }
      }

      setState(() {
        availablePros = uniquePros.values.toList();

        // 현재 프로와 다른 프로들만 선택 가능하도록 필터링
        if (currentProId != null) {
          availablePros = availablePros.where((pro) {
            final proId = pro['pro_id']?.toString();
            final isCurrentPro = proId == currentProId;
            print('프로 필터링: ${pro['pro_name']} ($proId) - 현재프로($currentProId)와 같은가? $isCurrentPro');
            return !isCurrentPro;
          }).toList();
        }

        // 이름순으로 정렬
        availablePros.sort((a, b) =>
          (a['pro_name'] ?? '').compareTo(b['pro_name'] ?? '')
        );

        print('필터링 후 선택 가능한 프로 수: ${availablePros.length}');
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '데이터 로드 중 오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _saveProChange() async {
    if (selectedPro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 담당 프로를 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (currentLSCounting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 레슨 정보를 불러올 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        isSaving = true;
      });

      final newProId = selectedPro!['pro_id'];
      final newProName = selectedPro!['pro_name'];

      print('=== 프로변경 저장 디버깅 ===');
      print('기존 프로: $currentProName ($currentProId)');
      print('새 프로: $newProName ($newProId)');
      print('contract_history_id: ${widget.contract['contract_history_id']}');
      print('복사할 LS_counting: $currentLSCounting');

      // 1. v3_LS_countings에 새 레코드 추가 (기존 레코드 복사 + 프로 정보만 변경)
      final newLSCountingData = Map<String, dynamic>.from(currentLSCounting!);

      // LS_counting_id는 제거 (AI로 새로 생성됨)
      newLSCountingData.remove('LS_counting_id');

      // 프로 정보만 변경
      newLSCountingData['pro_id'] = newProId;
      newLSCountingData['pro_name'] = newProName;

      // 거래 타입을 프로변경으로 설정
      newLSCountingData['LS_transaction_type'] = '프로변경';
      newLSCountingData['LS_counting_source'] = '프로변경';

      // 프로변경은 레슨 차감/적립이 아니므로 잔액 변동 없음
      final currentBalance = currentLSCounting!['LS_balance_min_after'] ?? 0;
      newLSCountingData['LS_balance_min_before'] = currentBalance;
      newLSCountingData['LS_net_min'] = 0; // 프로변경은 차감/적립 없음
      newLSCountingData['LS_balance_min_after'] = currentBalance; // 잔액 동일

      // 업데이트 시간 갱신
      newLSCountingData['updated_at'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      print('새 LS_counting 데이터: $newLSCountingData');

      final lsCountingResponse = await ApiService.addLSCountingData(newLSCountingData);

      if (lsCountingResponse['success'] != true) {
        throw Exception('레슨 카운팅 데이터 추가 실패: ${lsCountingResponse['message']}');
      }

      // 2. v3_contract_history 테이블의 pro_id, pro_name 업데이트
      final contractUpdateResponse = await ApiService.updateData(
        table: 'v3_contract_history',
        data: {
          'pro_id': newProId,
          'pro_name': newProName,
        },
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contract['contract_history_id'],
          }
        ],
      );

      print('계약 업데이트 응답: $contractUpdateResponse');

      if (contractUpdateResponse['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('담당 프로가 ${currentProName}에서 ${newProName}으로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onSaved != null) {
          widget.onSaved!();
        }

        Navigator.of(context).pop();
      } else {
        throw Exception('계약 정보 업데이트에 실패했습니다: ${contractUpdateResponse['message']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('프로 변경 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseContractDialog(
      benefitType: 'lesson',
      title: '레슨 담당 프로 변경',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
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
            // 현재 담당 프로 정보
            ContractInfoCard(
              title: '현재 담당 프로',
              content: currentProName ?? '정보 없음',
              benefitType: 'lesson',
              icon: Icons.person,
            ),
            SizedBox(height: 24),

            // 새 담당 프로 선택
            Text(
              '새 담당 프로',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),

            if (availablePros.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '변경 가능한 프로가 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: availablePros.asMap().entries.map((entry) {
                    final index = entry.key;
                    final pro = entry.value;
                    final isSelected = selectedPro?['pro_id'] == pro['pro_id'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedPro = pro;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                            ? Color(0xFF3B82F6).withOpacity(0.1)
                            : Colors.transparent,
                          borderRadius: BorderRadius.vertical(
                            top: index == 0 ? Radius.circular(8) : Radius.zero,
                            bottom: index == availablePros.length - 1 ? Radius.circular(8) : Radius.zero,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<Map<String, dynamic>>(
                              value: pro,
                              groupValue: selectedPro,
                              onChanged: (value) {
                                setState(() {
                                  selectedPro = value;
                                });
                              },
                              activeColor: Color(0xFF3B82F6),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.person,
                              size: 20,
                              color: isSelected ? Color(0xFF3B82F6) : Color(0xFF6B7280),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pro['pro_name'] ?? '이름 없음',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Color(0xFF1E293B) : Color(0xFF374151),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (pro['pro_phone'] != null)
                                    Text(
                                      pro['pro_phone'],
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (pro['pro_license'] != null)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  pro['pro_license'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
      actions: isLoading || errorMessage != null ? null : [
        ContractActionButton(
          text: '취소',
          benefitType: 'lesson',
          isSecondary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SizedBox(width: 12),
        ContractActionButton(
          text: '변경',
          benefitType: 'lesson',
          isLoading: isSaving,
          onPressed: availablePros.isEmpty ? null : _saveProChange,
        ),
      ],
    );
  }
}