import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';

// 읽기 전용 회원권 상세 뷰어
class ContractViewerDialog extends StatefulWidget {
  final int contractHistoryId;

  const ContractViewerDialog({
    Key? key,
    required this.contractHistoryId,
  }) : super(key: key);

  @override
  State<ContractViewerDialog> createState() => _ContractViewerDialogState();
}

class _ContractViewerDialogState extends State<ContractViewerDialog> {
  Map<String, dynamic>? contractData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContractData();
  }

  Future<void> _loadContractData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 1. contract_history_id로 contract_id 조회
      final historyData = await ApiService.getDataList(
        table: 'v3_contract_history',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': widget.contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        limit: 1,
      );

      if (historyData.isEmpty) {
        throw Exception('계약 이력을 찾을 수 없습니다');
      }

      final contractId = historyData[0]['contract_id'];

      // 2. contract_id로 회원권 상세 정보 조회
      final contracts = await ApiService.getDataList(
        table: 'v2_contracts',
        where: [
          {
            'field': 'contract_id',
            'operator': '=',
            'value': contractId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        limit: 1,
      );

      if (contracts.isEmpty) {
        throw Exception('회원권 정보를 찾을 수 없습니다');
      }

      setState(() {
        contractData = contracts[0];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0원';
    final int priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    final formatted = priceInt.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted원';
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case '패키지':
        return Color(0xFF6366F1);
      case '선불크레딧':
        return Color(0xFF10B981);
      case '레슨권':
        return Color(0xFFF59E0B);
      case '시간권':
        return Color(0xFFEF4444);
      case '기간권':
        return Color(0xFF8B5CF6);
      default:
        return Color(0xFF64748B);
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.cardBody.copyWith(
                color: valueColor ?? Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.cardBody.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.card_membership,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '회원권 상세 정보',
                          style: AppTextStyles.titleH3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (contractData != null)
                          Text(
                            contractData!['contract_name'] ?? '',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 본문
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '회원권 정보를 불러오는 중...',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFFDC2626),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '오류가 발생했습니다',
                                style: AppTextStyles.cardBody.copyWith(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: AppTextStyles.cardMeta.copyWith(
                                  color: Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 기본 정보
                              _buildSection(
                                '기본 정보',
                                [
                                  _buildInfoRow('회원권 ID', contractData!['contract_id'] ?? '-'),
                                  _buildInfoRow(
                                    '회원권 유형',
                                    contractData!['contract_type'] ?? '-',
                                    valueColor: _getTypeColor(contractData!['contract_type']),
                                  ),
                                  _buildInfoRow('회원권 이름', contractData!['contract_name'] ?? '-'),
                                  _buildInfoRow(
                                    '판매 가격',
                                    _formatPrice(contractData!['price']),
                                    valueColor: Color(0xFF059669),
                                  ),
                                  _buildInfoRow(
                                    '상태',
                                    contractData!['contract_status'] ?? '유효',
                                    valueColor: contractData!['contract_status'] == '유효'
                                        ? Color(0xFF059669)
                                        : Color(0xFFDC2626),
                                  ),
                                ],
                              ),

                              // 제공 혜택
                              if (_hasAnyBenefit()) ...[
                                _buildSection(
                                  '제공 혜택',
                                  [
                                    if ((contractData!['contract_credit'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '선불크레딧',
                                        _formatPrice(contractData!['contract_credit']),
                                        valueColor: Color(0xFFFFA500),
                                      ),
                                    if ((contractData!['contract_LS_min'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '레슨권',
                                        '${contractData!['contract_LS_min']}분',
                                        valueColor: Color(0xFF2563EB),
                                      ),
                                    if ((contractData!['contract_games'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '스크린게임',
                                        '${contractData!['contract_games']}회',
                                        valueColor: Color(0xFF8B5CF6),
                                      ),
                                    if ((contractData!['contract_TS_min'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '타석시간',
                                        '${contractData!['contract_TS_min']}분',
                                        valueColor: Color(0xFF10B981),
                                      ),
                                    if ((contractData!['contract_term_month'] ?? 0) > 0)
                                      _buildInfoRow(
                                        '기간권',
                                        '${contractData!['contract_term_month']}개월',
                                        valueColor: Color(0xFF0D9488),
                                      ),
                                  ],
                                ),
                              ],

                              // 유효기간 정보
                              _buildSection(
                                '유효기간 정보',
                                [
                                  _buildInfoRow(
                                    '회원권 유효기간',
                                    contractData!['effect_month'] != null
                                        ? '${contractData!['effect_month']}개월'
                                        : '무제한',
                                  ),
                                  if (contractData!['contract_credit_effect_month'] != null &&
                                      contractData!['contract_credit_effect_month'] > 0)
                                    _buildInfoRow(
                                      '크레딧 유효기간',
                                      '${contractData!['contract_credit_effect_month']}개월',
                                    ),
                                  if (contractData!['contract_LS_min_effect_month'] != null &&
                                      contractData!['contract_LS_min_effect_month'] > 0)
                                    _buildInfoRow(
                                      '레슨 유효기간',
                                      '${contractData!['contract_LS_min_effect_month']}개월',
                                    ),
                                  if (contractData!['contract_games_effect_month'] != null &&
                                      contractData!['contract_games_effect_month'] > 0)
                                    _buildInfoRow(
                                      '게임 유효기간',
                                      '${contractData!['contract_games_effect_month']}개월',
                                    ),
                                  if (contractData!['contract_TS_min_effect_month'] != null &&
                                      contractData!['contract_TS_min_effect_month'] > 0)
                                    _buildInfoRow(
                                      '타석시간 유효기간',
                                      '${contractData!['contract_TS_min_effect_month']}개월',
                                    ),
                                ],
                              ),

                              // 이용 제한
                              _buildSection(
                                '이용 제한',
                                [
                                  _buildInfoRow(
                                    '이용가능 요일',
                                    _formatAvailableDays(contractData!['available_days']),
                                  ),
                                  _buildInfoRow(
                                    '이용가능 시간',
                                    _formatAvailableTime(
                                      contractData!['available_start_time'],
                                      contractData!['available_end_time'],
                                    ),
                                  ),
                                  if (contractData!['available_ts_id'] != null &&
                                      contractData!['available_ts_id'].toString().isNotEmpty)
                                    _buildInfoRow(
                                      '이용가능 타석',
                                      contractData!['available_ts_id'].toString(),
                                    ),
                                ],
                              ),

                              // 기타 설정
                              _buildSection(
                                '기타 설정',
                                [
                                  _buildInfoRow(
                                    '선불크레딧 결제',
                                    (contractData!['sell_by_credit_price'] ?? 0) > 0
                                        ? '허용 (${_formatPrice(contractData!['sell_by_credit_price'])})'
                                        : '불허용',
                                  ),
                                  if (contractData!['program_reservation_availability'] != null &&
                                      contractData!['program_reservation_availability'].toString().isNotEmpty)
                                    _buildInfoRow(
                                      '예약 가능 프로그램',
                                      contractData!['program_reservation_availability'].toString(),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
            ),
            // 하단 버튼
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF64748B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '닫기',
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.w600,
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
  }

  bool _hasAnyBenefit() {
    return (contractData!['contract_credit'] ?? 0) > 0 ||
        (contractData!['contract_LS_min'] ?? 0) > 0 ||
        (contractData!['contract_games'] ?? 0) > 0 ||
        (contractData!['contract_TS_min'] ?? 0) > 0 ||
        (contractData!['contract_term_month'] ?? 0) > 0;
  }

  String _formatAvailableDays(dynamic days) {
    if (days == null || days.toString().isEmpty || days.toString() == '전체') {
      return '전체 요일';
    }
    
    final daysList = days.toString().split(',');
    final weekdays = ['월', '화', '수', '목', '금'];
    final weekends = ['토', '일'];
    
    final hasAllWeekdays = weekdays.every((day) => daysList.contains(day));
    final hasAllWeekends = weekends.every((day) => daysList.contains(day));
    final hasHoliday = daysList.contains('공휴일');
    
    if (hasAllWeekdays && hasAllWeekends && hasHoliday) {
      return '전체 요일';
    } else if (hasAllWeekdays && !hasAllWeekends && !hasHoliday) {
      return '평일';
    } else if (!hasAllWeekdays && hasAllWeekends && !hasHoliday) {
      return '주말';
    } else if (!hasAllWeekdays && hasAllWeekends && hasHoliday) {
      return '주말 및 공휴일';
    }
    
    return days.toString();
  }

  String _formatAvailableTime(dynamic startTime, dynamic endTime) {
    if (startTime == null || endTime == null || 
        startTime.toString().isEmpty || endTime.toString().isEmpty) {
      return '전체 시간';
    }
    
    String start = startTime.toString();
    String end = endTime.toString();
    
    // 초 단위 제거
    if (start.length > 5) start = start.substring(0, 5);
    if (end.length > 5) end = end.substring(0, 5);
    
    if (start == '00:00' && end == '00:00') {
      return '전체 시간';
    }
    
    return '$start ~ $end';
  }
}