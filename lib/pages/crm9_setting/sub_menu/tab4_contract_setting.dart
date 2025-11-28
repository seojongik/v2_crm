import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/api_service.dart';
import '../../../services/table_design.dart';
import '../../../services/upper_button_input_design.dart';
import '../../../constants/font_sizes.dart';
import 'tab4_contract_setting_program.dart';
import 'tab4_contract_setting_terms.dart' as terms;
import '/services/supabase_adapter.dart';

// 1,000단위 콤마 자동 입력 포맷터
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(',', '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    int value = int.tryParse(newText) ?? 0;
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class Tab4ContractSettingWidget extends StatefulWidget {
  const Tab4ContractSettingWidget({super.key});

  @override
  State<Tab4ContractSettingWidget> createState() => _Tab4ContractSettingWidgetState();
}

class _Tab4ContractSettingWidgetState extends State<Tab4ContractSettingWidget> {
  List<Map<String, dynamic>> contractsList = [];
  bool isLoading = false;
  bool showExpiredContracts = false; // 만료된 회원권 표시 여부
  
  // 유형별 색상 정의 (보기 좋은 색상들)
  final List<Map<String, dynamic>> typeColors = [
    {'bg': Color(0xFF6366F1).withOpacity(0.1), 'text': Color(0xFF6366F1)}, // 보라
    {'bg': Color(0xFF10B981).withOpacity(0.1), 'text': Color(0xFF10B981)}, // 초록
    {'bg': Color(0xFFF59E0B).withOpacity(0.1), 'text': Color(0xFFF59E0B)}, // 주황
    {'bg': Color(0xFFEF4444).withOpacity(0.1), 'text': Color(0xFFEF4444)}, // 빨강
    {'bg': Color(0xFF8B5CF6).withOpacity(0.1), 'text': Color(0xFF8B5CF6)}, // 자주
    {'bg': Color(0xFF06B6D4).withOpacity(0.1), 'text': Color(0xFF06B6D4)}, // 청록
    {'bg': Color(0xFFEC4899).withOpacity(0.1), 'text': Color(0xFFEC4899)}, // 핑크
    {'bg': Color(0xFF84CC16).withOpacity(0.1), 'text': Color(0xFF84CC16)}, // 라임
  ];
  
  Map<String, Map<String, dynamic>> typeColorMap = {};

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  // 유형별 색상 할당
  Map<String, dynamic> _getTypeColor(String contractType) {
    if (typeColorMap.containsKey(contractType)) {
      return typeColorMap[contractType]!;
    }
    
    // 새로운 유형이면 색상 할당
    final colorIndex = typeColorMap.length % typeColors.length;
    typeColorMap[contractType] = typeColors[colorIndex];
    return typeColors[colorIndex];
  }

  Future<void> _loadContracts() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('회원권 데이터 조회 시작...');
      
      // 필터 조건 설정
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'contract_category', 'operator': '=', 'value': '회원권'}
      ];
      
      // 만료된 회원권을 포함하지 않는 경우에만 유효 조건 추가
      if (!showExpiredContracts) {
        whereConditions.add({'field': 'contract_status', 'operator': '=', 'value': '유효'});
      }
      
      final data = await ApiService.getContractsData(
        where: whereConditions,
        orderBy: [
          {'field': 'contract_status', 'direction': 'ASC'}, // 유효한 것을 먼저 표시 (ASC로 변경하여 '유효'가 먼저 오도록)
          {'field': 'contract_type', 'direction': 'ASC'},
          {'field': 'contract_id', 'direction': 'ASC'}
        ],
      );
      print('회원권 데이터 조회 성공: ${data.length}개');
      
      // 클라이언트 사이드에서 추가 정렬 (만료된 것을 맨 뒤로)
      data.sort((a, b) {
        final aExpired = (a['contract_status'] ?? '유효') != '유효';
        final bExpired = (b['contract_status'] ?? '유효') != '유효';
        
        if (aExpired && !bExpired) return 1; // a가 만료, b가 유효 -> a를 뒤로
        if (!aExpired && bExpired) return -1; // a가 유효, b가 만료 -> a를 앞으로
        
        // 둘 다 같은 상태면 유형별, ID별 정렬
        final typeCompare = (a['contract_type'] ?? '').compareTo(b['contract_type'] ?? '');
        if (typeCompare != 0) return typeCompare;
        
        return (a['contract_id'] ?? '').compareTo(b['contract_id'] ?? '');
      });
      
      setState(() {
        contractsList = data;
      });
    } catch (e) {
      print('회원권 데이터 조회 실패: $e');
      _showErrorSnackBar('회원권 정보 조회 실패: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> _getNextContractIdFromServer() async {
    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null || currentBranchId.isEmpty) {
        throw Exception('브랜치 정보가 없습니다');
      }
      
      // 서버에서 현재 브랜치의 회원권 contract_id 조회
      final allContracts = await ApiService.getContractsData(
        fields: ['contract_id'],
        where: [
          {'field': 'contract_category', 'operator': '=', 'value': '회원권'}
        ],
      );
      
      // 현재 브랜치의 membership ID 패턴 찾기 - 더 짧은 형식 사용
      final branchPrefix = '${currentBranchId}_m'; // _membership_을 _m으로 단축
      int maxNum = 0;
      
      for (var contract in allContracts) {
        final contractId = contract['contract_id'].toString();
        
        // 현재 브랜치의 membership ID인지 확인
        if (contractId.startsWith(branchPrefix)) {
          final numPart = contractId.substring(branchPrefix.length);
          final num = int.tryParse(numPart) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }
      
      // 다음 번호 생성 (3자리 패딩으로 단축)
      final nextNum = maxNum + 1;
      final nextId = '${branchPrefix}${nextNum.toString().padLeft(3, '0')}';
      
      print('브랜치 ID: $currentBranchId');
      print('생성된 다음 Contract ID: $nextId (길이: ${nextId.length})');
      print('기존 최대 번호: $maxNum');
      
      return nextId;
    } catch (e) {
      print('서버에서 Contract ID 조회 실패: $e');
      // 서버 조회 실패 시 기본값 반환
      final currentBranchId = ApiService.getCurrentBranchId() ?? 'unknown';
      return '${currentBranchId}_m001';
    }
  }

  String _getNextContractId() {
    final currentBranchId = ApiService.getCurrentBranchId() ?? 'unknown';
    final branchPrefix = '${currentBranchId}_m'; // _membership_을 _m으로 단축
    
    if (contractsList.isEmpty) {
      // 데이터가 없으면 001부터 시작
      return '${branchPrefix}001';
    }
    
    // 현재 브랜치의 membership ID 패턴에서 최대값 찾기
    int maxNum = 0;
    
    for (var contract in contractsList) {
      final contractId = contract['contract_id'].toString();
      
      // 현재 브랜치의 membership ID인지 확인
      if (contractId.startsWith(branchPrefix)) {
        final numPart = contractId.substring(branchPrefix.length);
        final num = int.tryParse(numPart) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    
    // 다음 번호 생성 (3자리 패딩으로 단축)
    final nextNum = maxNum + 1;
    final nextId = '${branchPrefix}${nextNum.toString().padLeft(3, '0')}';
    
    print('로컬에서 생성된 다음 Contract ID: $nextId (길이: ${nextId.length})');
    print('기존 최대 번호: $maxNum');
    
    return nextId;
  }

  void _showContractDialog({Map<String, dynamic>? contract}) async{
    final isEditing = contract != null;
    
    // 새 계약 추가 시 서버에서 다음 ID 조회
    String nextId = '';
    if (!isEditing) {
      nextId = await _getNextContractIdFromServer();
    }
    
    showDialog(
      context: context,
      builder: (context) => ContractDialog(
        contract: contract,
        nextContractId: isEditing ? null : nextId,
        onSave: (contractData) async {
          // 수정인 경우 확인 다이얼로그 먼저 표시
          if (isEditing) {
            final shouldProceed = await _showEditConfirmationDialog(contract!, contractData);
            if (!shouldProceed) return;
          }
          
          await _saveContract(contractData, isEditing);
        },
      ),
    );
  }

  Future<bool> _showEditConfirmationDialog(Map<String, dynamic> originalContract, Map<String, dynamic> newContract) async {
    // 변경된 필드들을 찾기 - 개선된 비교 로직
    List<String> changedFields = [];
    
    // 안전한 비교를 위한 헬퍼 함수들
    String normalizeString(dynamic value) {
      return (value?.toString() ?? '').trim();
    }
    
    int normalizeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }
    
    // 이용가능 요일 정규화 함수 추가
    String normalizeAvailableDays(dynamic value) {
      final str = (value?.toString() ?? '').trim();
      // 빈 값이나 null은 '전체'로 처리
      if (str.isEmpty || str == 'null') {
        return '전체';
      }
      return str;
    }
    
    // 문자열 필드 비교
    if (normalizeString(originalContract['contract_type']) != normalizeString(newContract['contract_type'])) {
      changedFields.add('contract_type');
    }
    if (normalizeString(originalContract['contract_name']) != normalizeString(newContract['contract_name'])) {
      changedFields.add('contract_name');
    }
    if (normalizeString(originalContract['contract_status']) != normalizeString(newContract['contract_status'])) {
      changedFields.add('contract_status');
    }
    // 이용가능 요일은 특별 처리
    if (normalizeAvailableDays(originalContract['available_days']) != normalizeAvailableDays(newContract['available_days'])) {
      changedFields.add('available_days');
    }
    if (normalizeString(originalContract['available_start_time']) != normalizeString(newContract['available_start_time'])) {
      changedFields.add('available_start_time');
    }
    if (normalizeString(originalContract['available_end_time']) != normalizeString(newContract['available_end_time'])) {
      changedFields.add('available_end_time');
    }
    
    // 숫자 필드 비교
    if (normalizeInt(originalContract['price']) != normalizeInt(newContract['price'])) {
      changedFields.add('price');
    }
    if (normalizeInt(originalContract['contract_credit']) != normalizeInt(newContract['contract_credit'])) {
      changedFields.add('contract_credit');
    }
    if (normalizeInt(originalContract['contract_LS_min']) != normalizeInt(newContract['contract_LS_min'])) {
      changedFields.add('contract_LS_min');
    }
    if (normalizeInt(originalContract['contract_TS_min']) != normalizeInt(newContract['contract_TS_min'])) {
      changedFields.add('contract_TS_min');
    }
    if (normalizeInt(originalContract['contract_games']) != normalizeInt(newContract['contract_games'])) {
      changedFields.add('contract_games');
    }
    if (normalizeInt(originalContract['contract_term_month']) != normalizeInt(newContract['contract_term_month'])) {
      changedFields.add('contract_term_month');
    }
    if (normalizeInt(originalContract['sell_by_credit_price']) != normalizeInt(newContract['sell_by_credit_price'])) {
      changedFields.add('sell_by_credit_price');
    }
    
    // effect_month는 null이 의미가 있으므로 별도 처리
    final originalEffectMonth = originalContract['effect_month'];
    final newEffectMonth = newContract['effect_month'];
    if ((originalEffectMonth == null && newEffectMonth != null) ||
        (originalEffectMonth != null && newEffectMonth == null) ||
        (originalEffectMonth != null && newEffectMonth != null && normalizeInt(originalEffectMonth) != normalizeInt(newEffectMonth))) {
      changedFields.add('effect_month');
    }
    
    // 새로 추가된 필드들 비교
    // 타석 예약제한
    if (normalizeInt(originalContract['max_min_reservation_ahead']) != normalizeInt(newContract['max_min_reservation_ahead'])) {
      changedFields.add('max_min_reservation_ahead');
    }
    
    // 쿠폰 발급/사용 가능 여부
    if (normalizeString(originalContract['coupon_issue_available']) != normalizeString(newContract['coupon_issue_available'])) {
      changedFields.add('coupon_issue_available');
    }
    if (normalizeString(originalContract['coupon_use_available']) != normalizeString(newContract['coupon_use_available'])) {
      changedFields.add('coupon_use_available');
    }
    
    // 일회 최대이용(타석)
    if (normalizeInt(originalContract['max_ts_use_min']) != normalizeInt(newContract['max_ts_use_min'])) {
      changedFields.add('max_ts_use_min');
    }

    // 일일 최대이용(타석)
    if (normalizeInt(originalContract['max_use_per_day']) != normalizeInt(newContract['max_use_per_day'])) {
      changedFields.add('max_use_per_day');
    }

    // 일회 최대이용(레슨)
    if (normalizeInt(originalContract['max_ls_min_session']) != normalizeInt(newContract['max_ls_min_session'])) {
      changedFields.add('max_ls_min_session');
    }

    // 일일 최대이용(레슨)
    if (normalizeInt(originalContract['max_ls_per_day']) != normalizeInt(newContract['max_ls_per_day'])) {
      changedFields.add('max_ls_per_day');
    }

    // 프로그램 예약설정 비교
    if (normalizeString(originalContract['program_reservation_availability']) != normalizeString(newContract['program_reservation_availability'])) {
      changedFields.add('program_reservation_availability');
    }
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F2937).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_note, color: Color(0xFF1F2937), size: 24),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '회원권 수정 확인',
                      style: AppTextStyles.modalTitle.copyWith(
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '${changedFields.length}개 항목이 변경됩니다',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          content: Container(
            width: 600,
            constraints: BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (changedFields.isEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 20),
                          SizedBox(width: 8),
                          Text(
                            '변경된 내용이 없습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 표 형태로 변경된 항목들 표시
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Table(
                        columnWidths: {
                          0: FlexColumnWidth(2.5),  // 항목명
                          1: FlexColumnWidth(3),    // 변경 전
                          2: FlexColumnWidth(1.5),  // 차이 (새로 추가)
                          3: FlexColumnWidth(3),    // 변경 후
                        },
                        children: [
                          // 헤더 행
                          TableRow(
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  '변경 항목',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  '변경 전',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  '차이',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  '변경 후',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          // 데이터 행들
                          ...changedFields.map((field) {
                            String label = '';
                            String originalValue = '';
                            String newValue = '';
                            
                            switch (field) {
                              case 'contract_type':
                                label = '회원권 유형';
                                originalValue = originalContract['contract_type']?.toString() ?? '';
                                newValue = newContract['contract_type']?.toString() ?? '';
                                break;
                              case 'contract_name':
                                label = '회원권 이름';
                                originalValue = originalContract['contract_name']?.toString() ?? '';
                                newValue = newContract['contract_name']?.toString() ?? '';
                                break;
                              case 'price':
                                label = '판매 가격';
                                originalValue = _formatPrice(originalContract['price']);
                                newValue = _formatPrice(newContract['price']);
                                break;
                              case 'contract_credit':
                                label = '선불크레딧 제공량';
                                originalValue = '${originalContract['contract_credit'] ?? 0}원';
                                newValue = '${newContract['contract_credit'] ?? 0}원';
                                break;
                              case 'contract_LS_min':
                                label = '레슨권 제공량';
                                originalValue = '${originalContract['contract_LS_min'] ?? 0}분';
                                newValue = '${newContract['contract_LS_min'] ?? 0}분';
                                break;
                              case 'contract_TS_min':
                                label = '타석시간 제공량';
                                originalValue = '${originalContract['contract_TS_min'] ?? 0}분';
                                newValue = '${newContract['contract_TS_min'] ?? 0}분';
                                break;
                              case 'contract_games':
                                label = '스크린게임 제공량';
                                originalValue = '${originalContract['contract_games'] ?? 0}회';
                                newValue = '${newContract['contract_games'] ?? 0}회';
                                break;
                              case 'contract_term_month':
                                label = '기간권 제공량';
                                originalValue = '${originalContract['contract_term_month'] ?? 0}개월';
                                newValue = '${newContract['contract_term_month'] ?? 0}개월';
                                break;
                              case 'effect_month':
                                label = '회원권 유효기간';
                                originalValue = originalContract['effect_month'] != null ? '${originalContract['effect_month']}개월' : '무제한';
                                newValue = newContract['effect_month'] != null ? '${newContract['effect_month']}개월' : '무제한';
                                break;
                              case 'contract_status':
                                label = '회원권 상태';
                                originalValue = originalContract['contract_status']?.toString() ?? '유효';
                                newValue = newContract['contract_status']?.toString() ?? '유효';
                                break;
                              case 'sell_by_credit_price':
                                label = '선불크레딧 결제 허용';
                                final originalCredit = originalContract['sell_by_credit_price'] ?? 0;
                                final newCredit = newContract['sell_by_credit_price'] ?? 0;
                                originalValue = originalCredit > 0 ? '허용 (${_formatPrice(originalCredit)})' : '불허용';
                                newValue = newCredit > 0 ? '허용 (${_formatPrice(newCredit)})' : '불허용';
                                break;
                              case 'available_days':
                                label = '이용가능 요일';
                                originalValue = _formatAvailableDays(originalContract['available_days']?.toString() ?? '');
                                newValue = _formatAvailableDays(newContract['available_days']?.toString() ?? '');
                                break;
                              case 'available_start_time':
                              case 'available_end_time':
                                label = '이용가능 시간';
                                final originalStart = originalContract['available_start_time']?.toString() ?? '';
                                final originalEnd = originalContract['available_end_time']?.toString() ?? '';
                                final newStart = newContract['available_start_time']?.toString() ?? '';
                                final newEnd = newContract['available_end_time']?.toString() ?? '';
                                originalValue = _formatAvailableTime(originalStart, originalEnd);
                                newValue = _formatAvailableTime(newStart, newEnd);
                                // 시작시간과 종료시간이 모두 변경된 경우 중복 표시 방지
                                if (field == 'available_end_time' && changedFields.contains('available_start_time')) {
                                  return TableRow(children: [Container(), Container(), Container(), Container()]); // 빈 행 반환
                                }
                                break;
                              case 'max_min_reservation_ahead':
                                label = '타석 예약제한';
                                final originalMin = originalContract['max_min_reservation_ahead'];
                                final newMin = newContract['max_min_reservation_ahead'];
                                originalValue = originalMin != null ? '${originalMin}분 이내 임박 예약만 가능' : '타석설정 적용';
                                newValue = newMin != null ? '${newMin}분 이내 임박 예약만 가능' : '타석설정 적용';
                                break;
                              case 'coupon_issue_available':
                                label = '쿠폰 발급';
                                originalValue = originalContract['coupon_issue_available']?.toString() ?? '가능';
                                newValue = newContract['coupon_issue_available']?.toString() ?? '가능';
                                break;
                              case 'coupon_use_available':
                                label = '쿠폰 사용';
                                originalValue = originalContract['coupon_use_available']?.toString() ?? '가능';
                                newValue = newContract['coupon_use_available']?.toString() ?? '가능';
                                break;
                              case 'max_ts_use_min':
                                label = '일회 최대이용(타석)';
                                final originalMax = originalContract['max_ts_use_min'];
                                final newMax = newContract['max_ts_use_min'];
                                originalValue = originalMax != null ? '최대 ${originalMax}분' : '제한없음';
                                newValue = newMax != null ? '최대 ${newMax}분' : '제한없음';
                                break;
                              case 'max_use_per_day':
                                label = '일일 최대이용(타석)';
                                final originalMaxPerDay = originalContract['max_use_per_day'];
                                final newMaxPerDay = newContract['max_use_per_day'];
                                originalValue = originalMaxPerDay != null ? '최대 ${originalMaxPerDay}분' : '제한없음';
                                newValue = newMaxPerDay != null ? '최대 ${newMaxPerDay}분' : '제한없음';
                                break;
                              case 'max_ls_min_session':
                                label = '일회 최대이용(레슨)';
                                final originalMaxLs = originalContract['max_ls_min_session'];
                                final newMaxLs = newContract['max_ls_min_session'];
                                originalValue = originalMaxLs != null ? '최대 ${originalMaxLs}분' : '제한없음';
                                newValue = newMaxLs != null ? '최대 ${newMaxLs}분' : '제한없음';
                                break;
                              case 'max_ls_per_day':
                                label = '일일 최대이용(레슨)';
                                final originalMaxLsPerDay = originalContract['max_ls_per_day'];
                                final newMaxLsPerDay = newContract['max_ls_per_day'];
                                originalValue = originalMaxLsPerDay != null ? '최대 ${originalMaxLsPerDay}분' : '제한없음';
                                newValue = newMaxLsPerDay != null ? '최대 ${newMaxLsPerDay}분' : '제한없음';
                                break;
                              case 'program_reservation_availability':
                                label = '프로그램 예약설정';
                                final originalProgram = originalContract['program_reservation_availability']?.toString() ?? '';
                                final newProgram = newContract['program_reservation_availability']?.toString() ?? '';
                                originalValue = originalProgram.isEmpty ? '연결 안됨' : originalProgram;
                                newValue = newProgram.isEmpty ? '연결 안됨' : newProgram;
                                break;
                            }
                            
                            return TableRow(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Color(0xFFFECACA)),
                                    ),
                                    child: Text(
                                      originalValue,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF374151),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                // 차이 컬럼 (새로 추가)
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: _isNumericField(field) 
                                        ? _buildDifferenceIndicatorWithValue(field, originalContract, newContract)
                                        : Text(
                                            '→',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Color(0xFFBBF7D0)),
                                    ),
                                    child: Text(
                                      newValue,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF374151),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '기존 계약 및 예약은 변경되지 않습니다.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: changedFields.isEmpty ? null : () => Navigator.of(context).pop(true),
              child: Text(
                '수정하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: changedFields.isEmpty ? Color(0xFF9CA3AF) : Color(0xFF6366F1),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  String _formatAvailableDays(String availableDays) {
    if (availableDays.isEmpty || availableDays == '전체') {
      return '전체 요일';
    }
    
    final selectedDays = availableDays.split(',');
    
    // 평일 체크 (월~금)
    final weekdays = ['월', '화', '수', '목', '금'];
    final hasAllWeekdays = weekdays.every((day) => selectedDays.contains(day));
    
    // 주말 체크 (토, 일)
    final weekends = ['토', '일'];
    final hasAllWeekends = weekends.every((day) => selectedDays.contains(day));
    
    // 공휴일 체크
    final hasHoliday = selectedDays.contains('공휴일');
    
    if (hasAllWeekdays && hasAllWeekends && hasHoliday) {
      return '전체 요일';
    } else if (hasAllWeekdays && !hasAllWeekends && !hasHoliday) {
      return '평일 (월~금)';
    } else if (!hasAllWeekdays && hasAllWeekends && !hasHoliday) {
      return '주말 (토, 일)';
    } else if (!hasAllWeekdays && hasAllWeekends && hasHoliday) {
      return '주말 및 공휴일';
    } else {
      return selectedDays.join(', ');
    }
  }

  String _formatAvailableTime(String startTime, String endTime) {
    if (startTime.isEmpty && endTime.isEmpty) {
      return '전체 시간';
    }
    
    // 초 단위 제거 (hh:mm:ss -> hh:mm)
    final startTimeFormatted = startTime.length > 5 ? startTime.substring(0, 5) : startTime;
    final endTimeFormatted = endTime.length > 5 ? endTime.substring(0, 5) : endTime;
    
    if (startTimeFormatted == '00:00' && endTimeFormatted == '00:00') {
      return '전체 시간';
    } else if (startTimeFormatted.isNotEmpty && endTimeFormatted.isNotEmpty) {
      return '$startTimeFormatted ~ $endTimeFormatted';
    } else {
      return '전체 시간';
    }
  }

  // 수치 항목인지 판별하는 함수
  bool _isNumericField(String field) {
    return [
      'price',
      'contract_credit',
      'contract_LS_min',
      'contract_TS_min',
      'contract_games',
      'contract_term_month',
      'effect_month',
      'sell_by_credit_price'
    ].contains(field);
  }

  // 증감량 표시 위젯 생성 함수
  Widget _buildDifferenceIndicator(String field, Map<String, dynamic> originalContract, Map<String, dynamic> newContract) {
    int originalValue = 0;
    int newValue = 0;
    
    switch (field) {
      case 'price':
        originalValue = originalContract['price'] ?? 0;
        newValue = newContract['price'] ?? 0;
        break;
      case 'contract_credit':
        originalValue = originalContract['contract_credit'] ?? 0;
        newValue = newContract['contract_credit'] ?? 0;
        break;
      case 'contract_LS_min':
        originalValue = originalContract['contract_LS_min'] ?? 0;
        newValue = newContract['contract_LS_min'] ?? 0;
        break;
      case 'contract_TS_min':
        originalValue = originalContract['contract_TS_min'] ?? 0;
        newValue = newContract['contract_TS_min'] ?? 0;
        break;
      case 'contract_games':
        originalValue = originalContract['contract_games'] ?? 0;
        newValue = newContract['contract_games'] ?? 0;
        break;
      case 'contract_term_month':
        originalValue = originalContract['contract_term_month'] ?? 0;
        newValue = newContract['contract_term_month'] ?? 0;
        break;
      case 'effect_month':
        originalValue = originalContract['effect_month'] ?? 0;
        newValue = newContract['effect_month'] ?? 0;
        break;
      case 'sell_by_credit_price':
        originalValue = originalContract['sell_by_credit_price'] ?? 0;
        newValue = newContract['sell_by_credit_price'] ?? 0;
        break;
    }
    
    final difference = newValue - originalValue;
    if (difference == 0) return Container();
    
    final isIncrease = difference > 0;
    final emoji = isIncrease ? '🔺' : '🔻';
    
    return Text(
      emoji,
      style: TextStyle(fontSize: 16),
    );
  }

  // 차이를 값과 함께 표시하는 새로운 함수
  Widget _buildDifferenceIndicatorWithValue(String field, Map<String, dynamic> originalContract, Map<String, dynamic> newContract) {
    int originalValue = 0;
    int newValue = 0;
    
    switch (field) {
      case 'price':
        originalValue = originalContract['price'] ?? 0;
        newValue = newContract['price'] ?? 0;
        break;
      case 'contract_credit':
        originalValue = originalContract['contract_credit'] ?? 0;
        newValue = newContract['contract_credit'] ?? 0;
        break;
      case 'contract_LS_min':
        originalValue = originalContract['contract_LS_min'] ?? 0;
        newValue = newContract['contract_LS_min'] ?? 0;
        break;
      case 'contract_TS_min':
        originalValue = originalContract['contract_TS_min'] ?? 0;
        newValue = newContract['contract_TS_min'] ?? 0;
        break;
      case 'contract_games':
        originalValue = originalContract['contract_games'] ?? 0;
        newValue = newContract['contract_games'] ?? 0;
        break;
      case 'contract_term_month':
        originalValue = originalContract['contract_term_month'] ?? 0;
        newValue = newContract['contract_term_month'] ?? 0;
        break;
      case 'effect_month':
        originalValue = originalContract['effect_month'] ?? 0;
        newValue = newContract['effect_month'] ?? 0;
        break;
      case 'sell_by_credit_price':
        originalValue = originalContract['sell_by_credit_price'] ?? 0;
        newValue = newContract['sell_by_credit_price'] ?? 0;
        break;
    }
    
    final difference = newValue - originalValue;
    if (difference == 0) return Container();
    
    final isIncrease = difference > 0;
    
    // 천 단위 콤마 추가
    String formatNumber(int number) {
      return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
        (Match m) => '${m[1]},'
      );
    }
    
    final formattedDifference = formatNumber(difference.abs());
    
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: isIncrease ? '▲' : '▼',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isIncrease ? Color(0xFFDC2626) : Color(0xFF2563EB), // 화살표도 색상 구분
            ),
          ),
          TextSpan(
            text: formattedDifference,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isIncrease ? Color(0xFFDC2626) : Color(0xFF2563EB), // 증가: 빨간색, 감소: 파란색
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveContract(Map<String, dynamic> contractData, bool isEditing) async {
    try {
      print('회원권 저장 시작 - ${isEditing ? '수정' : '추가'}');
      print('저장할 데이터: $contractData');
      print('program_reservation_availability: ${contractData['program_reservation_availability']}');
      
      if (isEditing) {
        await ApiService.updateContractsData(
          contractData,
          [{'field': 'contract_id', 'operator': '=', 'value': contractData['contract_id']}],
        );
        print('회원권 수정 성공');
        
        // 임시 프로그램 데이터가 있는 경우 실제 저장
        if (contractData['temporary_program_data'] != null) {
          await _saveProgramToDatabase(contractData['temporary_program_data']);
        }
        
        _showSuccessSnackBar('회원권 정보가 수정되었습니다');
      } else {
        await ApiService.addContractsData(contractData);
        print('회원권 추가 성공');
        
        // 신규 회원권에 임시 프로그램 데이터가 있는 경우 실제 저장
        if (contractData['temporary_program_data'] != null) {
          await _saveProgramToDatabase(contractData['temporary_program_data']);
        }
        
        _showSuccessSnackBar('새로운 회원권이 추가되었습니다');
      }

      // 다이얼로그 닫기
      Navigator.of(context).pop();
      
      // 데이터 새로고침
      _loadContracts();
    } catch (e) {
      print('회원권 저장 실패: $e');
      _showErrorSnackBar('저장 실패: ${e.toString()}');
    }
  }

  Future<void> _saveProgramToDatabase(Map<String, dynamic> programData) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final programName = programData['program_name'];
      final programId = programData['program_id'];
      
      print('프로그램 데이터베이스 저장 시작: $programId ($programName)');
      
      // 새 설정 추가
      final newSettings = [
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': programName,
          'field_name': 'program_id',
          'option_value': programId,
          'setting_status': '유효',
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': programName,
          'field_name': 'ts_min',
          'option_value': programData['ts_min'].toString(),
          'setting_status': '유효',
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': programName,
          'field_name': 'min_player_no',
          'option_value': programData['min_player_no'].toString(),
          'setting_status': '유효',
        },
        {
          'branch_id': branchId,
          'category': '특수타석예약',
          'table_name': programName,
          'field_name': 'max_player_no',
          'option_value': programData['max_player_no'].toString(),
          'setting_status': '유효',
        },
      ];
      
      // 타임라인 기반 세션 추가
      final timelineSessions = programData['timeline_sessions'] as List;
      for (int i = 0; i < timelineSessions.length; i++) {
        final session = timelineSessions[i];
        if (session['duration'] > 0) {
          String fieldName = session['type'] == 'lesson' 
            ? 'ls_min(${i + 1})' 
            : 'ls_break_min(${i + 1})';
          
          newSettings.add({
            'branch_id': branchId,
            'category': '특수타석예약',
            'table_name': programName,
            'field_name': fieldName,
            'option_value': session['duration'].toString(),
            'setting_status': '유효',
          });
        }
      }
      
      // 각 설정 저장
      for (var setting in newSettings) {
        await SupabaseAdapter.addData(
          table: 'v2_base_option_setting',
          data: setting,
        );

        print('설정 저장 완료: ${setting['field_name']} = ${setting['option_value']}');
      }
      
      print('프로그램 데이터베이스 저장 완료: $programId');
    } catch (e) {
      print('❌ 프로그램 데이터베이스 저장 오류: $e');
      throw e;
    }
  }

  Future<void> _deleteContract(String contractId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 8),
              Text('회원권 삭제'),
            ],
          ),
          content: Text('이 회원권을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('삭제', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteContractsData([
          {'field': 'contract_id', 'operator': '=', 'value': contractId}
        ]);
        _showSuccessSnackBar('회원권이 삭제되었습니다');
        _loadContracts();
      } catch (e) {
        _showErrorSnackBar('삭제 실패: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return priceInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 왼쪽: 버튼 그룹
              Row(
                children: [
                  // 회원권 추가 버튼
                  ButtonDesignUpper.buildIconButton(
                    text: '회원권 추가',
                    icon: Icons.card_membership,
                    onPressed: () => _showContractDialog(),
                    color: 'cyan',
                    size: 'large',
                  ),
                  SizedBox(width: 12),
                  // 온라인 회원권 판매약관 버튼
                  ButtonDesignUpper.buildIconButton(
                    text: '온라인 판매약관',
                    icon: Icons.description,
                    onPressed: () => terms.showTermsDialog(context),
                    color: 'purple',
                    size: 'large',
                  ),
                ],
              ),
              // 오른쪽: 필터 토글 버튼
              ButtonDesignUpper.buildIconButton(
                text: showExpiredContracts ? '만료포함' : '유효회원권',
                icon: showExpiredContracts ? Icons.visibility : Icons.visibility_off,
                onPressed: () {
                  setState(() {
                    showExpiredContracts = !showExpiredContracts;
                  });
                  _loadContracts();
                },
                color: showExpiredContracts ? 'orange' : 'cyan',
                size: 'large',
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 컨텐츠 - 테이블 영역
        Expanded(
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '회원권 정보를 불러오는 중...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : contractsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
          Container(
                            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
                              color: Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.card_membership,
                              size: 64,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            '등록된 회원권이 없습니다',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '새로운 회원권을 추가해보세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TableDesign.buildTableContainer(
                      child: Column(
                        children: [
                          // 헤더
                          TableDesign.buildTableHeader(
                            children: [
                              TableDesign.buildHeaderColumn(text: 'ID', flex: 1),
                              TableDesign.buildHeaderColumn(text: '유형', flex: 1),
                              TableDesign.buildHeaderColumn(text: '이름', flex: 2),
                              TableDesign.buildHeaderColumn(text: '제공서비스', flex: 3),
                              TableDesign.buildHeaderColumn(text: '가격(원)', flex: 1),
                              TableDesign.buildHeaderColumn(text: '이용가능요일', flex: 2),
                              TableDesign.buildHeaderColumn(text: '이용가능시간', flex: 2),
                              TableDesign.buildHeaderColumn(text: '관리', flex: 1),
                            ],
                          ),
                          // 본문
                          Expanded(
                            child: TableDesign.buildTableBody(
                              itemCount: contractsList.length,
                              itemBuilder: (context, index) {
                                final contract = contractsList[index];
                              final contractId = contract['contract_id'].toString();
                              final isExpired = (contract['contract_status'] ?? '유효') != '유효';
                              
                              // 제공서비스 정보를 조합
                              List<String> services = [];
                              final credit = contract['contract_credit'] ?? 0;
                              final lesson = contract['contract_LS_min'] ?? 0;
                              final driving = contract['contract_TS_min'] ?? 0;
                              final period = contract['contract_term_month'] ?? 0;
                              final games = contract['contract_games'] ?? 0;
                              
                              if (credit > 0) services.add('크레딧 ${credit}원');
                              if (lesson > 0) services.add('레슨 ${lesson}분');
                              if (driving > 0) services.add('타석 ${driving}분');
                              if (games > 0) services.add('게임 ${games}회');
                              if (period > 0) services.add('기간 ${period}개월');
                              
                              final serviceText = services.isEmpty ? '-' : services.join(', ');
                              
                              // 이용가능요일 정보 구성
                              final availableDays = contract['available_days']?.toString() ?? '';
                              String dayText = '';
                              
                              if (availableDays.isEmpty || availableDays == '전체') {
                                dayText = '전체요일';
                              } else {
                                final selectedDays = availableDays.split(',');
                                
                                // 평일 체크 (월~금)
                                final weekdays = ['월', '화', '수', '목', '금'];
                                final hasAllWeekdays = weekdays.every((day) => selectedDays.contains(day));
                                
                                // 주말 체크 (토, 일)
                                final weekends = ['토', '일'];
                                final hasAllWeekends = weekends.every((day) => selectedDays.contains(day));
                                
                                // 공휴일 체크
                                final hasHoliday = selectedDays.contains('공휴일');
                                
                                if (hasAllWeekdays && hasAllWeekends && hasHoliday) {
                                  dayText = '전체요일';
                                } else if (hasAllWeekdays && !hasAllWeekends && !hasHoliday) {
                                  dayText = '평일';
                                } else if (!hasAllWeekdays && hasAllWeekends && !hasHoliday) {
                                  dayText = '주말';
                                } else if (!hasAllWeekdays && hasAllWeekends && hasHoliday) {
                                  dayText = '주말 및 공휴일';
                                } else {
                                  // 그 외의 경우 실제 선택된 요일들을 표시
                                  dayText = selectedDays.join(', ');
                                }
                              }
                              
                              // 이용가능시간 정보 구성
                              final startTime = contract['available_start_time']?.toString() ?? '';
                              final endTime = contract['available_end_time']?.toString() ?? '';
                              String timeText = '';
                              
                              if (startTime.isNotEmpty && endTime.isNotEmpty) {
                                // 초 단위 제거 (hh:mm:ss -> hh:mm)
                                final startTimeFormatted = startTime.length > 5 ? startTime.substring(0, 5) : startTime;
                                final endTimeFormatted = endTime.length > 5 ? endTime.substring(0, 5) : endTime;
                                
                                if (startTimeFormatted == '00:00' && endTimeFormatted == '00:00') {
                                  timeText = '전체시간';
                                } else {
                                  timeText = '$startTimeFormatted~$endTimeFormatted';
                                }
                              } else {
                                // 시간 정보가 없으면 전체시간으로 간주
                                timeText = '전체시간';
                              }
                              
                                return TableDesign.buildTableRow(
                                  children: [
                                    // ID
                                    TableDesign.buildRowColumn(
                                      text: contractId,
                                      flex: 1,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                      color: isExpired ? Colors.grey.shade500 : TableDesign.textColorPrimary,
                                    ),
                                    // 유형 (배지)
                                    TableDesign.buildColumn(
                                      flex: 1,
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isExpired
                                                ? Colors.grey.shade300
                                                : _getTypeColor(contract['contract_type'] ?? '')['bg'],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            contract['contract_type'] ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Pretendard',
                                              color: isExpired
                                                  ? Colors.grey.shade600
                                                  : _getTypeColor(contract['contract_type'] ?? '')['text'],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 이름
                                    TableDesign.buildRowColumn(
                                      text: contract['contract_name'] ?? '',
                                      flex: 2,
                                      fontSize: 14.0,
                                      color: isExpired ? Colors.grey.shade500 : TableDesign.textColorPrimary,
                                    ),
                                    // 제공서비스
                                    TableDesign.buildRowColumn(
                                      text: serviceText,
                                      flex: 3,
                                      fontSize: 13.0,
                                      color: isExpired ? Colors.grey.shade500 : TableDesign.textColorPrimary,
                                    ),
                                    // 가격
                                    TableDesign.buildRowColumn(
                                      text: _formatPrice(contract['price']),
                                      flex: 1,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                      color: isExpired ? Colors.grey.shade500 : Color(0xFFF59E0B),
                                    ),
                                    // 이용가능요일
                                    TableDesign.buildRowColumn(
                                      text: dayText,
                                      flex: 2,
                                      fontSize: 13.0,
                                      color: isExpired ? Colors.grey.shade500 : TableDesign.textColorPrimary,
                                    ),
                                    // 이용가능시간
                                    TableDesign.buildRowColumn(
                                      text: timeText,
                                      flex: 2,
                                      fontSize: 13.0,
                                      color: isExpired ? Colors.grey.shade500 : TableDesign.textColorPrimary,
                                    ),
                                    // 관리 (버튼)
                                    TableDesign.buildColumn(
                                      flex: 1,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: '수정',
                                            child: InkWell(
                                              onTap: () => _showContractDialog(contract: contract),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.edit,
                                                  size: 18,
                                                  color: isExpired ? Colors.grey.shade400 : Color(0xFF6366F1)
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Tooltip(
                                            message: '삭제',
                                            child: InkWell(
                                              onTap: () => _deleteContract(contractId),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.delete,
                                                  size: 18,
                                                  color: isExpired ? Colors.grey.shade400 : Color(0xFFEF4444)
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                              isLoading: false,
                              hasError: false,
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

// 회원권 추가/수정 다이얼로그
class ContractDialog extends StatefulWidget {
  final Map<String, dynamic>? contract;
  final String? nextContractId;
  final Function(Map<String, dynamic>) onSave;

  const ContractDialog({
    super.key,
    this.contract,
    this.nextContractId,
    required this.onSave,
  });

  @override
  State<ContractDialog> createState() => _ContractDialogState();
}

class _ContractDialogState extends State<ContractDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // 컨트롤러들
  late TextEditingController _contractIdController;
  late TextEditingController _contractNameController;
  late TextEditingController _contractCreditController;
  late TextEditingController _contractLSController;
  late TextEditingController _priceController;
  late TextEditingController _effectMonthController;
  late TextEditingController _sellByCreditPriceController;
  late TextEditingController _contractTSMinController;
  late TextEditingController _contractTermMonthController;
  late TextEditingController _contractGamesController; // 스크린게임 컨트롤러 (contract_games)
  late TextEditingController _contractCreditEffectMonthController;
  late TextEditingController _contractLSMinEffectMonthController;
  late TextEditingController _contractTSMinEffectMonthController;
  late TextEditingController _contractGamesEffectMonthController;
  late TextEditingController _contractTermMonthEffectMonthController;
  // 추가: 이용가능시간 컨트롤러
  late TextEditingController _availableStartTimeController;
  late TextEditingController _availableEndTimeController;
  // 타석 예약제한 관련
  late TextEditingController _maxMinReservationAheadController;
  bool _useDefaultReservationLimit = true;
  // 쿠폰 발급/사용 제한 관련
  bool _useDefaultCouponSettings = true;
  bool _couponIssueAvailable = true;
  bool _couponUseAvailable = true;
  // 일회 최대이용(타석) 관련
  late TextEditingController _maxTsUseMinController;
  bool _useDefaultMaxTsUseSetting = true;
  // 일일 최대이용(타석) 관련
  late TextEditingController _maxUsePerDayController;
  bool _useDefaultMaxUsePerDay = true;
  // 일회 최대이용(레슨) 관련
  late TextEditingController _maxLsMinSessionController;
  bool _useDefaultMaxLsMinSession = true;
  // 일일 최대이용(레슨) 관련
  late TextEditingController _maxLsPerDayController;
  bool _useDefaultMaxLsPerDay = true;

  // 프로그램 예약설정 관련
  String _selectedProgramId = '';
  String _selectedProgramName = '';
  List<Map<String, dynamic>> _availablePrograms = [];
  Map<String, dynamic>? _temporaryProgramData; // 신규 회원권의 임시 프로그램 데이터
  
  // 드롭다운 선택값들
  String _selectedContractType = '';
  String _selectedContractStatus = '유효';
  String _selectedLsType = '';
  
  // 결제방법 체크박스 상태 - 선불크레딧만 비활성화로 변경
  bool _isCardPayment = true;
  bool _isCashPayment = true;
  bool _isPrepaidCredit = false; // true에서 false로 변경
  bool _isAppPayment = true;
  
  // 이용가능요일 체크박스 상태 - 모두 선택된 상태로 초기화
  bool _isMonday = true;
  bool _isTuesday = true;
  bool _isWednesday = true;
  bool _isThursday = true;
  bool _isFriday = true;
  bool _isSaturday = true;
  bool _isSunday = true;
  bool _isHoliday = true;
  
  // 드롭다운 옵션들 - 동적으로 로드
  List<String> contractTypeOptions = [];
  List<String> contractStatusOptions = ['유효', '비활성'];

  bool _isLoadingOptions = true;

  // 레슨권만 있는 경우 (타석 관련 서비스가 하나도 없음)
  // 선불크레딧, 타석시간, 스크린게임, 기간권은 모두 타석권에 해당
  bool get _isLessonOnlyContract {
    final lessonMin = int.tryParse(_contractLSController.text.replaceAll(',', '')) ?? 0;
    final credit = int.tryParse(_contractCreditController.text.replaceAll(',', '')) ?? 0;
    final drivingMin = int.tryParse(_contractTSMinController.text.replaceAll(',', '')) ?? 0;
    final games = int.tryParse(_contractGamesController.text.replaceAll(',', '')) ?? 0;
    final termMonth = int.tryParse(_contractTermMonthController.text.replaceAll(',', '')) ?? 0;

    return lessonMin > 0 && credit == 0 && drivingMin == 0 && games == 0 && termMonth == 0;
  }

  // 레슨권이 없는 경우
  bool get _isNoLessonContract {
    final lessonMin = int.tryParse(_contractLSController.text.replaceAll(',', '')) ?? 0;
    return lessonMin == 0;
  }

  // 제공서비스 변경 시 자동으로 비활성화된 설정을 제한없음으로 리셋
  void _resetDisabledSettings() {
    // 레슨권이 없으면 레슨 설정을 제한없음으로 리셋
    if (_isNoLessonContract) {
      _useDefaultMaxLsMinSession = true;
      _useDefaultMaxLsPerDay = true;
    }

    // 레슨권만 있으면 타석 설정을 제한없음으로 리셋
    if (_isLessonOnlyContract) {
      _useDefaultMaxTsUseSetting = true;
      _useDefaultMaxUsePerDay = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadContractTypeOptions();
    _loadAvailablePrograms();
  }

  // 프로그램 데이터 로드
  Future<void> _loadAvailablePrograms() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) return;
      
      final programs = await SupabaseAdapter.getData(
        table: 'v2_base_option_setting',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'field_name', 'operator': '=', 'value': 'program_id'},
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ],
      );

      print('API에서 반환된 원시 데이터: ${programs}');
      setState(() {
        _availablePrograms = programs.map((p) => {
          'program_id': p['option_value'],
          'program_name': p['table_name'],
        }).toList();

        // 임시 프로그램 데이터가 있으면 목록에 추가
        if (_temporaryProgramData != null) {
          final tempProgramId = _temporaryProgramData!['program_id'];
          final tempProgramName = _temporaryProgramData!['program_name'];

          // 이미 존재하는지 확인
          final exists = _availablePrograms.any((p) => p['program_id'] == tempProgramId);
          if (!exists) {
            _availablePrograms.insert(0, {
              'program_id': tempProgramId,
              'program_name': tempProgramName,
            });
            print('✨ 임시 프로그램을 목록에 추가: $tempProgramName ($tempProgramId)');
          }
        }

        print('변환된 프로그램 목록: ${_availablePrograms}');
        print('로드된 프로그램 목록: ${_availablePrograms}');
        print('현재 선택된 프로그램 ID: ${_selectedProgramId}');

        // 선택된 프로그램 이름 설정 - 임시 데이터 우선 확인
        if (_selectedProgramId.isNotEmpty) {
          // 먼저 임시 프로그램 데이터 확인 (신규 프로그램인 경우)
          if (_temporaryProgramData != null && _temporaryProgramData!['program_id'] == _selectedProgramId) {
            _selectedProgramName = _temporaryProgramData!['program_name'] ?? '';
            print('임시 프로그램 데이터에서 매칭: ${_temporaryProgramData!['program_name']}');
          } else {
            // API에서 로드된 프로그램 목록에서 찾기
            final selectedProgram = _availablePrograms.firstWhere(
              (p) => p['program_id'] == _selectedProgramId,
              orElse: () => {},
            );
            if (selectedProgram.isNotEmpty) {
              _selectedProgramName = selectedProgram['program_name'] ?? '';
              print('API 데이터에서 매칭: ${selectedProgram}');
              print('설정된 프로그램 이름: ${_selectedProgramName}');
            } else {
              print('⚠️ 프로그램 ID ${_selectedProgramId}에 매칭되는 프로그램을 찾을 수 없습니다.');
              _selectedProgramName = '프로그램 정보 불일치 (ID: ${_selectedProgramId})';
            }
          }
        }
      });
    } catch (e) {
      print('❌ 프로그램 로드 오류: $e');
    }
  }
  
  // 기존 프로그램의 타임라인 데이터 로드
  Future<Map<String, dynamic>?> _loadExistingProgramData(String programId) async {
    try {
      print('🔍 _loadExistingProgramData 호출: programId=$programId');
      print('🔍 _temporaryProgramData 상태: ${_temporaryProgramData != null ? _temporaryProgramData!['program_id'] : 'null'}');
      
      // 임시 프로그램 데이터가 있고, 요청한 programId와 일치하면 우선 반환
      if (_temporaryProgramData != null && _temporaryProgramData!['program_id'] == programId) {
        print('✨ 임시 프로그램 데이터 사용: ${_temporaryProgramData!['program_name']} ($programId)');
        return Map<String, dynamic>.from(_temporaryProgramData!);
      }
      
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) return null;
      
      // 먼저 프로그램 이름을 찾기
      final programName = _availablePrograms
          .firstWhere((p) => p['program_id'] == programId, orElse: () => {})['program_name'];
      
      if (programName == null || programName.isEmpty) {
        print('❌ 프로그램 ID $programId에 해당하는 프로그램명을 찾을 수 없습니다.');
        return null;
      }
      
      print('🔍 프로그램 타임라인 로드 시작: $programId ($programName)');
      
      // 해당 프로그램의 모든 설정 데이터 가져오기 (table_name으로 검색)
      final settings = await SupabaseAdapter.getData(
        table: 'v2_base_option_setting',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'table_name', 'operator': '=', 'value': programName},
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ],
      );

      print('📊 로드된 설정 개수: ${settings.length}');

      if (settings.isNotEmpty) {
        Map<String, dynamic> programData = {'program_id': programId, 'program_name': programName};
        List<Map<String, dynamic>> timelineSessions = [];

        for (var setting in settings) {
          print('⚙️ 처리 중인 설정: ${setting}');
          final fieldName = setting['field_name'];
          final optionValue = setting['option_value'];

          switch (fieldName) {
            case 'ts_min':
              programData['ts_min'] = int.tryParse(optionValue) ?? 0;
              break;
            case 'min_player_no':
              programData['min_player_no'] = int.tryParse(optionValue) ?? 1;
              break;
            case 'max_player_no':
              programData['max_player_no'] = int.tryParse(optionValue) ?? 4;
              break;
            default:
              // 레슨 시간 패턴: ls_min(1), ls_min(2), etc.
              RegExp lessonPattern = RegExp(r'ls_min\((\d+)\)');
              Match? lessonMatch = lessonPattern.firstMatch(fieldName);
              if (lessonMatch != null) {
                int index = int.parse(lessonMatch.group(1)!) - 1;
                while (timelineSessions.length <= index) {
                  timelineSessions.add({'type': 'lesson', 'duration': 0});
                }
                timelineSessions[index] = {
                  'type': 'lesson',
                  'duration': int.tryParse(optionValue) ?? 0
                };
              }

              // 브레이크 시간 패턴: ls_break_min(1), ls_break_min(2), etc.
              RegExp breakPattern = RegExp(r'ls_break_min\((\d+)\)');
              Match? breakMatch = breakPattern.firstMatch(fieldName);
              if (breakMatch != null) {
                int index = int.parse(breakMatch.group(1)!) - 1;
                while (timelineSessions.length <= index) {
                  timelineSessions.add({'type': 'break', 'duration': 0});
                }
                timelineSessions[index] = {
                  'type': 'break',
                  'duration': int.tryParse(optionValue) ?? 0
                };
              }
              break;
          }
        }

        // 0분인 세션 제거
        timelineSessions = timelineSessions.where((session) => session['duration'] > 0).toList();
        programData['timeline_sessions'] = timelineSessions;

        print('🎯 최종 프로그램 데이터: $programData');
        print('⏰ 타임라인 세션 개수: ${timelineSessions.length}');

        return programData;
      }
    } catch (e) {
      print('❌ 프로그램 타임라인 로드 오류: $e');
    }
    
    return null;
  }
  
  Future<void> _loadContractTypeOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      // DB에서 유효한 회원권 유형을 option_sequence 순으로 로드
      final data = await ApiService.getMembershipTypeOptions();
      
      // 유효한 회원권 유형만 필터링하고 option_value 추출
      final validTypes = data
          .where((item) => item['setting_status'] == '유효')
          .map((item) => item['option_value'].toString())
          .toList();

      if (!mounted) return;

      setState(() {
        contractTypeOptions = validTypes;
        _isLoadingOptions = false;

        // 기존 선택값이 유효한지 확인 (수정 모드)
        final contract = widget.contract;
        if (contract != null) {
          final contractType = contract['contract_type']?.toString() ?? '';
          if (contractType.isNotEmpty) {
            // 기존 값이 옵션에 없으면 옵션에 추가 (만료된 유형이어도 표시)
            if (!contractTypeOptions.contains(contractType)) {
              contractTypeOptions.add(contractType);
            }
            _selectedContractType = contractType;
          }
        }

        print('회원권 유형 옵션 설정 완료: $contractTypeOptions');
        print('선택된 회원권 유형: $_selectedContractType');
      });
    } catch (e) {
      print('회원권 유형 로드 실패: $e');
      if (!mounted) return;
      
      // 오류 발생 시 기본값 사용
      setState(() {
        contractTypeOptions = ['크레딧', '레슨권', '패키지', '기간권', '주니어'];
        _isLoadingOptions = false;

        // 기존 선택값이 유효한지 확인 (수정 모드)
        final contract = widget.contract;
        if (contract != null) {
          final contractType = contract['contract_type']?.toString() ?? '';
          if (contractType.isNotEmpty) {
            if (!contractTypeOptions.contains(contractType)) {
              contractTypeOptions.add(contractType);
            }
            _selectedContractType = contractType;
          }
        }
      });
    }
  }

  void _initializeControllers() {
    final contract = widget.contract;
    final isEdit = contract != null;
    
    _contractIdController = TextEditingController(
      text: isEdit ? contract['contract_id'].toString() : (widget.nextContractId ?? '')
    );
    _contractNameController = TextEditingController(
      text: isEdit ? (contract['contract_name']?.toString() ?? '') : ''
    );
    _contractCreditController = TextEditingController(
      text: isEdit ? (contract['contract_credit']?.toString() ?? '0') : '0'
    );
    _contractLSController = TextEditingController(
      text: isEdit ? (contract['contract_LS_min']?.toString() ?? '0') : '0'
    );
    _priceController = TextEditingController(
      text: isEdit ? (contract['price']?.toString() ?? '0') : '0'
    );
    _effectMonthController = TextEditingController(
      text: isEdit ? (contract['effect_month']?.toString() ?? '0') : '0'
    );
    _sellByCreditPriceController = TextEditingController(
      text: isEdit ? (contract['sell_by_credit_price']?.toString() ?? '0') : '0'
    );
    _contractTSMinController = TextEditingController(
      text: isEdit ? (contract['contract_TS_min']?.toString() ?? '0') : '0'
    );
    _contractTermMonthController = TextEditingController(
      text: isEdit ? (contract['contract_term_month']?.toString() ?? '0') : '0'
    );
    _contractGamesController = TextEditingController(
      text: isEdit ? (contract['contract_games']?.toString() ?? '0') : '0'
    );
    
    _contractCreditEffectMonthController = TextEditingController(
      text: isEdit ? (contract['contract_credit_effect_month']?.toString() ?? '0') : '0',
    );
    _contractLSMinEffectMonthController = TextEditingController(
      text: isEdit ? (contract['contract_LS_min_effect_month']?.toString() ?? '0') : '0',
    );
    _contractTSMinEffectMonthController = TextEditingController(
      text: isEdit ? (contract['contract_TS_min_effect_month']?.toString() ?? '0') : '0',
    );
    _contractGamesEffectMonthController = TextEditingController(
      text: isEdit ? (contract['contract_games_effect_month']?.toString() ?? '0') : '0',
    );
    _contractTermMonthEffectMonthController = TextEditingController(
      text: isEdit ? (contract['contract_term_month_effect_month']?.toString() ?? '0') : '0',
    );
    
    // 드롭다운 초기값 설정
    if (isEdit) {
      final contractType = contract['contract_type']?.toString() ?? '';
      final contractStatus = contract['contract_status']?.toString() ?? '유효';
      
      _selectedContractType = contractType;
      _selectedContractStatus = contractStatus;
      _selectedLsType = contract['LS_type']?.toString() ?? '';
      
      // 기존 상태가 옵션에 없으면 추가
      if (contractStatus.isNotEmpty && !contractStatusOptions.contains(contractStatus)) {
        contractStatusOptions.add(contractStatus);
      }
      
      print('수정 모드 초기화:');
      print('- 계약 유형: $contractType');
      print('- 계약 상태: $contractStatus');
      print('- 상태 옵션: $contractStatusOptions');
      print('- 전체 계약 데이터: $contract');
      
      // 결제방법 초기화 - 기존 데이터에서 sell_by_credit_price가 0보다 크면 선불크레딧 체크
      final sellByCreditPrice = contract['sell_by_credit_price'] ?? 0;
      _isPrepaidCredit = sellByCreditPrice > 0;
      
      // 다른 결제방법들은 기본적으로 체크 (실제 데이터가 있다면 해당 필드에서 가져와야 함)
      _isCardPayment = true;
      _isCashPayment = true;
      _isAppPayment = true;
      
      // 이용가능요일 초기화 - available_days 필드에서 파싱
      final availableDays = contract['available_days']?.toString() ?? '';
      if (availableDays.isEmpty || availableDays == '전체') {
        // 전체 또는 빈 값인 경우 모든 요일 선택
        _isMonday = true;
        _isTuesday = true;
        _isWednesday = true;
        _isThursday = true;
        _isFriday = true;
        _isSaturday = true;
        _isSunday = true;
        _isHoliday = true;
      } else {
        // 특정 요일들이 지정된 경우 해당 요일만 선택
        final selectedDays = availableDays.split(',');
        _isMonday = selectedDays.contains('월');
        _isTuesday = selectedDays.contains('화');
        _isWednesday = selectedDays.contains('수');
        _isThursday = selectedDays.contains('목');
        _isFriday = selectedDays.contains('금');
        _isSaturday = selectedDays.contains('토');
        _isSunday = selectedDays.contains('일');
        _isHoliday = selectedDays.contains('공휴일');
      }
    } else {
      // 새로 추가할 때는 빈 값으로 초기화
      _selectedContractType = '';
      _selectedContractStatus = '유효';
      print('새 추가 모드 초기화');
    }
    // 추가: 이용가능시간 컨트롤러 초기화
    _availableStartTimeController = TextEditingController(
      text: isEdit ? (contract['available_start_time']?.toString() ?? '') : ''
    );
    _availableEndTimeController = TextEditingController(
      text: isEdit ? (contract['available_end_time']?.toString() ?? '') : ''
    );
    // 타석 예약제한 컨트롤러 초기화
    _maxMinReservationAheadController = TextEditingController(
      text: isEdit ? (contract['max_min_reservation_ahead']?.toString() ?? '30') : '30'
    );
    if (isEdit) {
      final maxMinValue = contract['max_min_reservation_ahead']?.toString() ?? '';
      _useDefaultReservationLimit = maxMinValue.isEmpty;
      // 쿠폰 설정 초기화
      final couponIssue = contract['coupon_issue_available']?.toString() ?? '';
      final couponUse = contract['coupon_use_available']?.toString() ?? '';
      if (couponIssue.isNotEmpty && couponIssue != '가능') {
        _useDefaultCouponSettings = false;
        _couponIssueAvailable = couponIssue == '가능';
        _couponUseAvailable = couponUse == '가능';
      }
      // 일회 최대이용(타석) 초기화
      final maxTsUse = contract['max_ts_use_min']?.toString() ?? '';
      _useDefaultMaxTsUseSetting = maxTsUse.isEmpty;
      // 일일 최대이용(타석) 초기화
      final maxUsePerDay = contract['max_use_per_day']?.toString() ?? '';
      _useDefaultMaxUsePerDay = maxUsePerDay.isEmpty;
      // 일회 최대이용(레슨) 초기화
      final maxLsMinSession = contract['max_ls_min_session']?.toString() ?? '';
      _useDefaultMaxLsMinSession = maxLsMinSession.isEmpty;
      // 일일 최대이용(레슨) 초기화
      final maxLsPerDay = contract['max_ls_per_day']?.toString() ?? '';
      _useDefaultMaxLsPerDay = maxLsPerDay.isEmpty;
    }
    // 일회 최대이용(타석) 컨트롤러 초기화
    _maxTsUseMinController = TextEditingController(
      text: isEdit ? (contract['max_ts_use_min']?.toString() ?? '120') : '120'
    );
    // 일일 최대이용(타석) 컨트롤러 초기화
    _maxUsePerDayController = TextEditingController(
      text: isEdit ? (contract['max_use_per_day']?.toString() ?? '') : ''
    );
    // 일회 최대이용(레슨) 컨트롤러 초기화
    _maxLsMinSessionController = TextEditingController(
      text: isEdit ? (contract['max_ls_min_session']?.toString() ?? '120') : '120'
    );
    // 일일 최대이용(레슨) 컨트롤러 초기화
    _maxLsPerDayController = TextEditingController(
      text: isEdit ? (contract['max_ls_per_day']?.toString() ?? '') : ''
    );

    // 프로그램 예약설정 초기화
    if (isEdit) {
      _selectedProgramId = contract['program_reservation_availability']?.toString() ?? '';
      print('회원권 데이터에서 프로그램 ID: ${_selectedProgramId}');
      print('회원권 전체 데이터: ${contract}');
    }
  }

  @override
  void dispose() {
    _contractIdController.dispose();
    _contractNameController.dispose();
    _contractCreditController.dispose();
    _contractLSController.dispose();
    _priceController.dispose();
    _effectMonthController.dispose();
    _sellByCreditPriceController.dispose();
    _contractTSMinController.dispose();
    _contractTermMonthController.dispose();
    _contractGamesController.dispose();
    _contractCreditEffectMonthController.dispose();
    _contractLSMinEffectMonthController.dispose();
    _contractTSMinEffectMonthController.dispose();
    _contractGamesEffectMonthController.dispose();
    _contractTermMonthEffectMonthController.dispose();
    _availableStartTimeController.dispose();
    _availableEndTimeController.dispose();
    _maxMinReservationAheadController.dispose();
    _maxTsUseMinController.dispose();
    _maxUsePerDayController.dispose();
    _maxLsMinSessionController.dispose();
    _maxLsPerDayController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    print('🔵 _handleSave() 함수 호출됨!');
    print('🔵 폼 검증 시작...');

    if (!_formKey.currentState!.validate()) {
      print('❌ 폼 검증 실패!');
      return;
    }
    print('✅ 폼 검증 성공!');

    // 회원권 유형은 선택사항이므로 체크하지 않음
    print('ℹ️ 회원권 유형: ${_selectedContractType.isEmpty ? "선택 안함" : _selectedContractType}');

    // 로딩 시작
    print('🔄 로딩 상태 시작...');
    setState(() {
      _isLoading = true;
    });

    // 선불크레딧 체크 상태에 따라 크레딧 판매가 설정
    final sellByCreditPrice = _isPrepaidCredit 
        ? (int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0)
        : 0;

    // 선택된 요일들을 문자열로 조합
    List<String> selectedDays = [];
    if (_isMonday) selectedDays.add('월');
    if (_isTuesday) selectedDays.add('화');
    if (_isWednesday) selectedDays.add('수');
    if (_isThursday) selectedDays.add('목');
    if (_isFriday) selectedDays.add('금');
    if (_isSaturday) selectedDays.add('토');
    if (_isSunday) selectedDays.add('일');
    if (_isHoliday) selectedDays.add('공휴일');
    
    // 모든 요일이 선택되었거나 아무것도 선택되지 않은 경우 전체로 처리
    String availableDays = '';
    if (selectedDays.length == 8 || selectedDays.isEmpty) {
      availableDays = '전체';
    } else {
      availableDays = selectedDays.join(',');
    }

    final data = {
      'contract_id': _contractIdController.text,
      'contract_type': _selectedContractType,
      'contract_name': _contractNameController.text,
      'contract_credit': int.tryParse(_contractCreditController.text.replaceAll(',', '')) ?? 0,
      'contract_LS_min': int.tryParse(_contractLSController.text.replaceAll(',', '')) ?? 0,
      'contract_TS_min': int.tryParse(_contractTSMinController.text.replaceAll(',', '')) ?? 0,
      'contract_term_month': int.tryParse(_contractTermMonthController.text.replaceAll(',', '')) ?? 0,
      'contract_games': int.tryParse(_contractGamesController.text.replaceAll(',', '')) ?? 0,
      'contract_status': _selectedContractStatus,
      'price': int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
      'sell_by_credit_price': sellByCreditPrice,
      'contract_category': '회원권',
      'LS_type': '',
      'branch_id': ApiService.getCurrentBranchId() ?? 'famd',
      'available_days': availableDays,
      'available_start_time': _availableStartTimeController.text.isEmpty ? null : _availableStartTimeController.text,
      'available_end_time': _availableEndTimeController.text.isEmpty ? null : _availableEndTimeController.text,
      'max_min_reservation_ahead': _useDefaultReservationLimit ? null : (int.tryParse(_maxMinReservationAheadController.text) ?? 30),
      'coupon_issue_available': _useDefaultCouponSettings ? '가능' : (_couponIssueAvailable ? '가능' : '불가능'),
      'coupon_use_available': _useDefaultCouponSettings ? '가능' : (_couponUseAvailable ? '가능' : '불가능'),
      // 레슨권 전용인 경우 타석 설정은 항상 null (제한없음)
      'max_ts_use_min': (_isLessonOnlyContract || _useDefaultMaxTsUseSetting) ? null : (int.tryParse(_maxTsUseMinController.text) ?? 120),
      'max_use_per_day': (_isLessonOnlyContract || _useDefaultMaxUsePerDay) ? null : (int.tryParse(_maxUsePerDayController.text) ?? null),
      // 타석권 전용인 경우 레슨 설정은 항상 null (제한없음)
      'max_ls_min_session': (_isNoLessonContract || _useDefaultMaxLsMinSession) ? null : (int.tryParse(_maxLsMinSessionController.text) ?? 120),
      'max_ls_per_day': (_isNoLessonContract || _useDefaultMaxLsPerDay) ? null : (int.tryParse(_maxLsPerDayController.text) ?? null),
      'contract_credit_effect_month': int.tryParse(_contractCreditEffectMonthController.text.replaceAll(',', '')) ?? 0,
      'contract_LS_min_effect_month': int.tryParse(_contractLSMinEffectMonthController.text.replaceAll(',', '')) ?? 0,
      'contract_TS_min_effect_month': int.tryParse(_contractTSMinEffectMonthController.text.replaceAll(',', '')) ?? 0,
      'contract_games_effect_month': int.tryParse(_contractGamesEffectMonthController.text.replaceAll(',', '')) ?? 0,
      'contract_term_month_effect_month': int.tryParse(_contractTermMonthEffectMonthController.text.replaceAll(',', '')) ?? 0,
      'program_reservation_availability': _selectedProgramId.isNotEmpty ? _selectedProgramId : null,
      'temporary_program_data': _temporaryProgramData, // 신규 회원권의 임시 프로그램 데이터
    };

    print('📦 저장할 데이터 준비 완료:');
    print('  - contract_id: ${data['contract_id']}');
    print('  - contract_type: ${data['contract_type']}');
    print('  - contract_name: ${data['contract_name']}');
    print('  - price: ${data['price']}');

    try {
      print('🚀 widget.onSave(data) 호출 시작...');
      await widget.onSave(data);
      print('✅ widget.onSave(data) 완료!');
      // 팝업 닫기는 _saveContract에서 처리됨
    } catch (e) {
      print('❌ 저장 중 오류 발생: $e');
      print('❌ 오류 스택: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 로딩 종료
      print('🔄 로딩 상태 종료...');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('✅ 로딩 상태 종료 완료!');
      }
    }
  }

  // 기존 프로그램 수정 다이얼로그
  void _showEditProgramDialog() async {
    if (_selectedProgramId.isEmpty || _selectedProgramName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('수정할 프로그램 정보를 찾을 수 없습니다.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    
    try {
      // 기존 프로그램 데이터 로드
      final programData = await _loadExistingProgramData(_selectedProgramId);
      
      final contractName = _contractNameController.text.trim().isEmpty
          ? '기존 회원권'
          : _contractNameController.text.trim();
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ContractProgramDialog(
            existingProgram: programData,
            contractId: widget.contract?['contract_id'],
            contractName: contractName,
            isNewContract: widget.contract == null,
            onProgramSaved: (updatedProgramData) {
              print('🚀 onProgramSaved 콜백 호출됨 (기존 프로그램 수정): $updatedProgramData');
              setState(() {
                // 기존 프로그램 수정도 임시 저장으로 처리
                _temporaryProgramData = updatedProgramData;
                _selectedProgramName = updatedProgramData['program_name'];
                
                // 계산된 제공 서비스 값을 회원권 컨트롤러에 반영
                if (updatedProgramData['calculated_ls_min'] != null) {
                  _contractLSController.text = updatedProgramData['calculated_ls_min'].toString();
                  print('🔄 레슨권 업데이트: ${updatedProgramData['calculated_ls_min']}분');
                }
                if (updatedProgramData['calculated_ts_min'] != null) {
                  _contractTSMinController.text = updatedProgramData['calculated_ts_min'].toString();
                  print('🔄 타석시간 업데이트: ${updatedProgramData['calculated_ts_min']}분');
                }
                
                // 프로그램 목록 다시 로드
                _loadAvailablePrograms();
              });
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('프로그램 데이터를 불러올 수 없습니다: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
  
  
  // 프로그램 연결 해제 확인 다이얼로그
  void _showDeleteProgramConfirm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 8),
              Text('프로그램 연결 해제'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음 프로그램과의 연결을 해제하시겠습니까?'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.golf_course, color: Color(0xFF3B82F6), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedProgramName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedProgramId,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // 프로그램 setting_status를 '만료'로 업데이트
                  await _disableProgramSettings(_selectedProgramId, _selectedProgramName);
                  
                  setState(() {
                    _selectedProgramId = '';
                    _selectedProgramName = '';
                    _temporaryProgramData = null;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('프로그램 연결이 해제되었습니다.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('연결 해제 중 오류가 발생했습니다: $e'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
              },
              child: Text('연결 해제', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEF4444),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // 신규 프로그램 등록 다이얼로그
  void _showAddProgramDialog() {
    final contractName = _contractNameController.text.trim().isEmpty
        ? '새 회원권'
        : _contractNameController.text.trim();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ContractProgramDialog(
          existingProgram: null, // 신규 프로그램 등록
          contractId: widget.contract?['contract_id'],
          contractName: contractName,
          isNewContract: widget.contract == null,
          onProgramSaved: (programData) {
            print('🚀 onProgramSaved 콜백 호출됨: $programData');
            print('🚀 widget.contract == null: ${widget.contract == null}');
            setState(() {
              // 신규 프로그램인 경우 항상 임시 저장 (신규 회원권이든 기존 회원권이든)
              if (programData['is_temporary'] == true || widget.contract == null) {
                print('🆕 신규 프로그램 - 임시 저장 처리');
                _temporaryProgramData = programData;
                _selectedProgramId = programData['program_id'];
                _selectedProgramName = programData['program_name'];
                
                // 계산된 제공 서비스 값을 회원권 컨트롤러에 반영
                if (programData['calculated_ls_min'] != null) {
                  _contractLSController.text = programData['calculated_ls_min'].toString();
                  print('📊 레슨권 자동 설정: ${programData['calculated_ls_min']}분');
                }
                if (programData['calculated_ts_min'] != null) {
                  _contractTSMinController.text = programData['calculated_ts_min'].toString();
                  print('📊 타석시간 자동 설정: ${programData['calculated_ts_min']}분');
                }
                
                print('✅ 신규 프로그램 임시 저장 완료: ${programData['program_name']} (${programData['program_id']})');
                print('✅ _temporaryProgramData 설정됨: $_temporaryProgramData');
              } else {
                print('📝 기존 프로그램 수정 - 임시 저장 처리');
                
                // 기존 프로그램 수정도 임시 데이터로 관리
                _temporaryProgramData = programData;
                _selectedProgramId = programData['program_id'];
                _selectedProgramName = programData['program_name'];
                
                // 계산된 제공 서비스 값을 화면에 임시 반영
                if (programData['calculated_ls_min'] != null) {
                  _contractLSController.text = programData['calculated_ls_min'].toString();
                  print('📊 레슨권 임시 반영 (화면만): ${programData['calculated_ls_min']}분');
                }
                if (programData['calculated_ts_min'] != null) {
                  _contractTSMinController.text = programData['calculated_ts_min'].toString();
                  print('📊 타석시간 임시 반영 (화면만): ${programData['calculated_ts_min']}분');
                }
                
                print('✅ 기존 프로그램 수정사항 임시 저장 완료');
                print('✅ _temporaryProgramData 업데이트됨: ${_temporaryProgramData!['program_name']} (횟수: ${_temporaryProgramData!['session_count']})');
                print('ℹ️ "수정하기" 버튼 클릭 시 프로그램과 제공서비스가 함께 저장됩니다.');
              }
              // 프로그램 목록 다시 로드
              _loadAvailablePrograms();
            });
          },
        );
      },
    );
  }
  
  // 프로그램 설정들을 '만료'로 업데이트
  Future<void> _disableProgramSettings(String programId, String programName) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) throw Exception('지점 정보가 없습니다.');
      
      print('프로그램 비활성화 시작: $programId ($programName)');
      
      // 해당 프로그램의 모든 설정 조회
      final settings = await SupabaseAdapter.getData(
        table: 'v2_base_option_setting',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'table_name', 'operator': '=', 'value': programName},
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ],
      );

      print('비활성화할 설정 개수: ${settings.length}');

      if (settings.isNotEmpty) {
        // 각 설정의 setting_status를 '만료'로 업데이트
        for (var setting in settings) {
          await SupabaseAdapter.updateData(
            table: 'v2_base_option_setting',
            data: {
              'setting_status': '만료',
            },
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': setting['branch_id']},
              {'field': 'category', 'operator': '=', 'value': setting['category']},
              {'field': 'table_name', 'operator': '=', 'value': setting['table_name']},
              {'field': 'field_name', 'operator': '=', 'value': setting['field_name']},
              {'field': 'option_value', 'operator': '=', 'value': setting['option_value']},
            ],
          );

          print('비활성화 완료: ${setting['field_name']} = ${setting['option_value']}');
        }

        print('프로그램 비활성화 완료: $programId');
      } else {
        print('해당 프로그램의 설정을 찾을 수 없습니다.');
      }
      
      // v2_contracts 테이블에서 program_reservation_availability 필드도 클리어
      await _clearContractProgramMapping(programId);
      
    } catch (e) {
      print('❌ 프로그램 비활성화 오류: $e');
      rethrow;
    }
  }

  Future<void> _clearContractProgramMapping(String programId) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) return;
      
      print('회원권 테이블에서 프로그램 매핑 클리어 시작: $programId');
      
      // 해당 프로그램 ID를 사용하는 회원권 조회
      final contracts = await SupabaseAdapter.getData(
        table: 'v2_contracts',
        fields: ['contract_id', 'program_reservation_availability'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'program_reservation_availability', 'operator': '=', 'value': programId},
        ],
      );

      print('프로그램 매핑을 클리어할 회원권 개수: ${contracts.length}');

      if (contracts.isNotEmpty) {
        // 각 회원권의 program_reservation_availability 필드를 null로 업데이트
        for (var contract in contracts) {
          await SupabaseAdapter.updateData(
            table: 'v2_contracts',
            data: {
              'program_reservation_availability': null,
            },
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'contract_id', 'operator': '=', 'value': contract['contract_id']},
            ],
          );

          print('회원권 프로그램 매핑 클리어 완료: ${contract['contract_id']}');
        }
      } else {
        print('해당 프로그램을 사용하는 회원권을 찾을 수 없습니다.');
      }
    } catch (e) {
      print('❌ 회원권 프로그램 매핑 클리어 오류: $e');
      // 이 오류는 rethrow하지 않음 (주요 기능이 아니므로)
    }
  }

  
  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool required = false,
    bool enabled = true,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            required ? '$label *' : label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required String label,
    required Function(String?) onChanged,
    bool required = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            required ? '$label *' : label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value.isNotEmpty ? value : null,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: options.isEmpty && label == '회원권 유형' && _isLoadingOptions
                ? null
                : options.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
            onChanged: options.isEmpty && label == '회원권 유형' && _isLoadingOptions
                ? null
                : onChanged,
            validator: required ? (value) {
              if (value == null || value.isEmpty) {
                return '$label을(를) 선택해주세요';
              }
              return null;
            } : null,
            hint: options.isEmpty && label == '회원권 유형' && _isLoadingOptions
                ? Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '옵션 로딩 중...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '$label을(를) 선택하세요',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String day, bool isSelected, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6366F1) : Colors.white,
              border: Border.all(
            color: Color(0xFF6366F1),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  void _showTimePicker({
    required TextEditingController controller,
    required String title,
  }) {
    DateTime initialTime = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        final parts = controller.text.split(':');
        if (parts.length == 2) {
          initialTime = DateTime(2023, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        }
      } catch (e) {
        // 파싱 실패 시 현재 시간 사용
      }
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Colors.white,
            child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text('취소'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    child: Text('확인'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: initialTime,
                use24hFormat: true,
                onDateTimeChanged: (DateTime newTime) {
                  final hour = newTime.hour.toString().padLeft(2, '0');
                  final minute = newTime.minute.toString().padLeft(2, '0');
                  controller.text = '$hour:$minute';
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contract != null;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 900,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
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
                      isEdit ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEdit ? '회원권 수정' : '회원권 추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // 수정 모드일 때 상태 변경 드롭다운 추가
                  if (isEdit) ...[
                    SizedBox(width: 20),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedContractStatus,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          dropdownColor: Color(0xFF6366F1),
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                          items: contractStatusOptions.map((String status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedContractStatus = newValue;
                                print('상태 변경: $newValue');
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
            
            // 내용
            Flexible(
              child: Container(
                color: Color(0xFFF8FAFC),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
            child: Column(
                      children: [
                        // 기본 정보 - 제목 제거하고 바로 입력창들만 표시
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                // 라벨 행
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '회원권 유형',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        '회원권 이름 *',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // 입력창 행
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedContractType.isNotEmpty && contractTypeOptions.contains(_selectedContractType)
                                            ? _selectedContractType
                                            : null,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        dropdownColor: Colors.white,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        items: contractTypeOptions.isEmpty && _isLoadingOptions
                                            ? null
                                            : contractTypeOptions.map((String option) {
                                                return DropdownMenuItem<String>(
                                                  value: option,
                                                  child: Text(
                                                    option,
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                        onChanged: contractTypeOptions.isEmpty && _isLoadingOptions
                                            ? null
                                            : (value) {
                                                print('📝 회원권 유형 선택됨: value=$value');
                                                print('📝 현재 _selectedContractType: $_selectedContractType');
                                                setState(() {
                                                  _selectedContractType = value ?? '';
                                                });
                                                print('📝 업데이트 후 _selectedContractType: $_selectedContractType');
                                              },
                                        validator: (value) {
                                          // 회원권 유형은 선택사항으로 변경 - validator 제거
                                          print('✅ 회원권 유형 validator 통과 (선택사항): _selectedContractType=$_selectedContractType');
                                          return null;
                                        },
                                        hint: contractTypeOptions.isEmpty && _isLoadingOptions
                                            ? Row(
                                                children: [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                Text(
                                                    '옵션 로딩 중...',
                  style: TextStyle(
                                                      color: Color(0xFF6B7280),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                '선택하세요',
                                                style: TextStyle(
                                                  color: Color(0xFF6B7280),
                                                  fontSize: 14,
                                                ),
                                              ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      flex: 5,
                                      child: TextFormField(
                                        controller: _contractNameController,
                                        style: TextStyle(
                                          color: Color(0xFF1F2937),
                                          fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            print('❌ 회원권 이름 validator 실패: value=$value');
                                            return '회원권 이름을 입력해주세요';
                                          }
                                          print('✅ 회원권 이름 validator 성공: value=$value');
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 6), // 8에서 6으로 줄임
                        
                        // 크레딧 및 레슨 정보와 가격 및 기간 정보를 좌우로 배치
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제공서비스 (더 넓게)
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 제공서비스 타이틀(카드 외부)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF3F4FD),
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                                    ),
                                    child: Text(
                                      '제공서비스',
                                      style: AppTextStyles.modalTitle.copyWith(
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                  // 제공서비스 카드(내부 타이틀/배경색 Container 완전 제거, 흰색 배경)
                                  Card(
                                    margin: EdgeInsets.only(bottom: 4),
                                    color: Colors.white,
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          // 표 제목
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text('구분', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text('내용', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text('유효기간(개월)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          // 선불크레딧
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text('선불크레딧', style: TextStyle(color: Colors.black)),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractCreditController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _resetDisabledSettings(); // 비활성화된 설정 자동 리셋
                                                      });
                                                    },
                                                    decoration: InputDecoration(
                                                      suffixText: '원',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractCreditEffectMonthController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    decoration: InputDecoration(
                                                      suffixText: '개월',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 레슨권
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text('레슨권', style: TextStyle(color: Colors.black)),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractLSController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _resetDisabledSettings(); // 비활성화된 설정 자동 리셋
                                                      });
                                                    },
                                                    decoration: InputDecoration(
                                                      suffixText: '분',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractLSMinEffectMonthController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    decoration: InputDecoration(
                                                      suffixText: '개월',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 타석시간
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text('타석시간', style: TextStyle(color: Colors.black)),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractTSMinController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _resetDisabledSettings(); // 비활성화된 설정 자동 리셋
                                                      });
                                                    },
                                                    decoration: InputDecoration(
                                                      suffixText: '분',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractTSMinEffectMonthController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    decoration: InputDecoration(
                                                      suffixText: '개월',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 스크린게임
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text('스크린게임', style: TextStyle(color: Colors.black)),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractGamesController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _resetDisabledSettings(); // 비활성화된 설정 자동 리셋
                                                      });
                                                    },
                                                    decoration: InputDecoration(
                                                      suffixText: '회',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractGamesEffectMonthController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    decoration: InputDecoration(
                                                      suffixText: '개월',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 기간권
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text('기간권', style: TextStyle(color: Colors.black)),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractTermMonthController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _resetDisabledSettings(); // 비활성화된 설정 자동 리셋
                                                      });
                                                    },
                                                    decoration: InputDecoration(
                                                      suffixText: '개월',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _contractTermMonthEffectMonthController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                                    textAlign: TextAlign.right,
                                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                                    decoration: InputDecoration(
                                                      suffixText: '개월',
                                                      suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            // 판매조건 (더 좁게)
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 판매조건 타이틀(카드 외부)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF3F4FD),
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                                    ),
                                    child: Text(
                                      '판매조건',
                                      style: AppTextStyles.modalTitle.copyWith(
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                  // 판매조건 카드(여백 최소화, 내부 타이틀/배경색 제거, 흰색 배경)
                                  Card(
                                    margin: EdgeInsets.only(bottom: 4),
                                    color: Colors.white,
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 가격 입력창(가로 전체)
                                          Text('가격', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
                                          SizedBox(height: 12),
                                          SizedBox(
                                            height: 40,
                                            child: TextFormField(
                                              controller: _priceController,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                                              textAlign: TextAlign.right,
                                              inputFormatters: [ThousandsSeparatorInputFormatter()],
                                              validator: (value) {
                                                print('🔍 판매가격 validator 호출: value=$value');
                                                if (value == null || value.isEmpty) {
                                                  print('❌ 판매가격 validator 실패: 빈 값');
                                                  return '판매가격을 입력해주세요';
                                                }
                                                final price = int.tryParse(value.replaceAll(',', ''));
                                                if (price == null || price < 0) {
                                                  print('❌ 판매가격 validator 실패: 잘못된 값 price=$price');
                                                  return '올바른 가격을 입력해주세요';
                                                }
                                                print('✅ 판매가격 validator 성공: price=$price');
                                                return null;
                                              },
                                              decoration: InputDecoration(
                                                suffixText: '원',
                                                suffixStyle: TextStyle(color: Color(0xFF6B7280)),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                            ),
                                          ),
                                          // 높이차이만큼 띄우기
                                          SizedBox(height: 36),
                                          // 결제방법 1열 세로 나열
                                          Text('결제방법', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                                          SizedBox(height: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [Checkbox(value: _isCardPayment, onChanged: (value) { setState(() { _isCardPayment = value ?? false; }); }, activeColor: Color(0xFF6366F1), checkColor: Colors.white, side: BorderSide(color: Color(0xFF6366F1), width: 2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), Text('카드결제', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600)),]),
                                              SizedBox(height: 12),
                                              Row(children: [Checkbox(value: _isCashPayment, onChanged: (value) { setState(() { _isCashPayment = value ?? false; }); }, activeColor: Color(0xFF6366F1), checkColor: Colors.white, side: BorderSide(color: Color(0xFF6366F1), width: 2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), Text('현금결제', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600)),]),
                                              SizedBox(height: 12),
                                              Row(children: [Checkbox(value: _isPrepaidCredit, onChanged: (value) { setState(() { _isPrepaidCredit = value ?? false; }); }, activeColor: Color(0xFF6366F1), checkColor: Colors.white, side: BorderSide(color: Color(0xFF6366F1), width: 2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), Text('선불크레딧', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600)),]),
                                              SizedBox(height: 12),
                                              Row(children: [Checkbox(value: _isAppPayment, onChanged: (value) { setState(() { _isAppPayment = value ?? false; }); }, activeColor: Color(0xFF6366F1), checkColor: Colors.white, side: BorderSide(color: Color(0xFF6366F1), width: 2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), Text('앱결제', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600)),]),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 6), // 8에서 6으로 줄임
                        
                        // 이용상 제약 섹션 - 제목 제거하고 바로 카드만 표시
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 이용가능요일 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '이용가능요일',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _buildDayChip('월', _isMonday, (value) => setState(() => _isMonday = value)),
                                          _buildDayChip('화', _isTuesday, (value) => setState(() => _isTuesday = value)),
                                          _buildDayChip('수', _isWednesday, (value) => setState(() => _isWednesday = value)),
                                          _buildDayChip('목', _isThursday, (value) => setState(() => _isThursday = value)),
                                          _buildDayChip('금', _isFriday, (value) => setState(() => _isFriday = value)),
                                          _buildDayChip('토', _isSaturday, (value) => setState(() => _isSaturday = value)),
                                          _buildDayChip('일', _isSunday, (value) => setState(() => _isSunday = value)),
                                          _buildDayChip('공휴일', _isHoliday, (value) => setState(() => _isHoliday = value)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10), // 12에서 10으로 줄임
                                // 이용가능시간 섹션 - 한 줄로 배치, 입력 방식으로 변경
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '이용가능시간',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _availableStartTimeController,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '00:00',
                                          hintStyle: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 14,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '~',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _availableEndTimeController,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '00:00',
                                          hintStyle: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 14,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _availableStartTimeController.text = '00:00';
                                            _availableEndTimeController.text = '00:00';
                                          });
                                        },
                                        child: Text(
                                          '전체시간',
                                          style: TextStyle(
                                            fontSize: 13, // 11에서 13으로 증가
                                            color: Color(0xFF6366F1),
                                            fontWeight: FontWeight.w600, // 볼드 처리 추가
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          side: BorderSide(color: Color(0xFF6366F1)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 구분선
                                Divider(color: Colors.grey.shade300, thickness: 1),
                                SizedBox(height: 16),
                                // 타석 예약제한 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '타석 예약제한',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // 타석설정 적용 라디오
                                          Radio<bool>(
                                            value: true,
                                            groupValue: _useDefaultReservationLimit,
                                            onChanged: (value) {
                                              setState(() {
                                                _useDefaultReservationLimit = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '타석설정 적용',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // 수정 라디오
                                          Radio<bool>(
                                            value: false,
                                            groupValue: _useDefaultReservationLimit,
                                            onChanged: (value) {
                                              setState(() {
                                                _useDefaultReservationLimit = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '수정',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          // 입력 필드
                                          Expanded(
                                            child: TextFormField(
                                              controller: _maxMinReservationAheadController,
                                              enabled: !_useDefaultReservationLimit,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(
                                                color: _useDefaultReservationLimit ? Colors.grey : Colors.black87,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              decoration: InputDecoration(
                                                suffixText: '분 이내 임박예약만',
                                                suffixStyle: TextStyle(
                                                  color: _useDefaultReservationLimit ? Colors.grey.shade400 : Color(0xFF6B7280),
                                                  fontSize: 12,
                                                ),
                                                filled: true,
                                                fillColor: _useDefaultReservationLimit ? Colors.grey.shade50 : Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1).withOpacity(0.3), width: 1),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 쿠폰발급/사용제한 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '쿠폰발급/사용제한',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // 쿠폰설정 적용 라디오
                                          Radio<bool>(
                                            value: true,
                                            groupValue: _useDefaultCouponSettings,
                                            onChanged: (value) {
                                              setState(() {
                                                _useDefaultCouponSettings = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '쿠폰설정 적용',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // 개별 설정 라디오
                                          Radio<bool>(
                                            value: false,
                                            groupValue: _useDefaultCouponSettings,
                                            onChanged: (value) {
                                              setState(() {
                                                _useDefaultCouponSettings = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '개별 설정',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          // 개별 설정 체크박스들
                                          if (!_useDefaultCouponSettings) ...[
                                            SizedBox(width: 16),
                                            Checkbox(
                                              value: !_couponIssueAvailable,
                                              onChanged: (value) {
                                                setState(() {
                                                  _couponIssueAvailable = !value!;
                                                });
                                              },
                                              activeColor: Color(0xFF6366F1),
                                              checkColor: Colors.white,
                                              side: BorderSide(color: Color(0xFF6366F1), width: 2),
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            Text(
                                              '발급금지',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Checkbox(
                                              value: !_couponUseAvailable,
                                              onChanged: (value) {
                                                setState(() {
                                                  _couponUseAvailable = !value!;
                                                });
                                              },
                                              activeColor: Color(0xFF6366F1),
                                              checkColor: Colors.white,
                                              side: BorderSide(color: Color(0xFF6366F1), width: 2),
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            Text(
                                              '사용금지',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 일회 최대이용(타석) 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '일회 최대이용(타석)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _isLessonOnlyContract ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // 제한없음 라디오
                                          Radio<bool>(
                                            value: true,
                                            groupValue: _isLessonOnlyContract ? true : _useDefaultMaxTsUseSetting,
                                            onChanged: _isLessonOnlyContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxTsUseSetting = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '제한없음',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isLessonOnlyContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // 수정 라디오
                                          Radio<bool>(
                                            value: false,
                                            groupValue: _isLessonOnlyContract ? true : _useDefaultMaxTsUseSetting,
                                            onChanged: _isLessonOnlyContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxTsUseSetting = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '최대',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isLessonOnlyContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          // 입력 필드
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller: _maxTsUseMinController,
                                              enabled: !_isLessonOnlyContract && !_useDefaultMaxTsUseSetting,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(
                                                color: (_isLessonOnlyContract || _useDefaultMaxTsUseSetting) ? Colors.grey : Colors.black87,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: (_isLessonOnlyContract || _useDefaultMaxTsUseSetting) ? Colors.grey.shade50 : Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1).withOpacity(0.3), width: 1),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '분으로 설정',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: (_isLessonOnlyContract || _useDefaultMaxTsUseSetting) ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 일일 최대이용(타석) 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '일일 최대이용(타석)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _isLessonOnlyContract ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // 제한없음 라디오
                                          Radio<bool>(
                                            value: true,
                                            groupValue: _isLessonOnlyContract ? true : _useDefaultMaxUsePerDay,
                                            onChanged: _isLessonOnlyContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxUsePerDay = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '제한없음',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isLessonOnlyContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // 수정 라디오
                                          Radio<bool>(
                                            value: false,
                                            groupValue: _isLessonOnlyContract ? true : _useDefaultMaxUsePerDay,
                                            onChanged: _isLessonOnlyContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxUsePerDay = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '최대',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isLessonOnlyContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              controller: _maxUsePerDayController,
                                              enabled: !_isLessonOnlyContract && !_useDefaultMaxUsePerDay,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: (_isLessonOnlyContract || _useDefaultMaxUsePerDay) ? Colors.grey : Colors.black87,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '240',
                                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1).withOpacity(0.3), width: 1),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '분으로 설정',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: (_isLessonOnlyContract || _useDefaultMaxUsePerDay) ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 일회 최대이용(레슨) 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '일회 최대이용(레슨)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _isNoLessonContract ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // 제한없음 라디오
                                          Radio<bool>(
                                            value: true,
                                            groupValue: _isNoLessonContract ? true : _useDefaultMaxLsMinSession,
                                            onChanged: _isNoLessonContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxLsMinSession = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '제한없음',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isNoLessonContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // 수정 라디오
                                          Radio<bool>(
                                            value: false,
                                            groupValue: _isNoLessonContract ? true : _useDefaultMaxLsMinSession,
                                            onChanged: _isNoLessonContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxLsMinSession = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '최대',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isNoLessonContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          // 입력 필드
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller: _maxLsMinSessionController,
                                              enabled: !_isNoLessonContract && !_useDefaultMaxLsMinSession,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(
                                                color: (_isNoLessonContract || _useDefaultMaxLsMinSession) ? Colors.grey : Colors.black87,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: (_isNoLessonContract || _useDefaultMaxLsMinSession) ? Colors.grey.shade50 : Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1).withOpacity(0.3), width: 1),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '분으로 설정',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: (_isNoLessonContract || _useDefaultMaxLsMinSession) ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 일일 최대이용(레슨) 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '일일 최대이용(레슨)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _isNoLessonContract ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // 제한없음 라디오
                                          Radio<bool>(
                                            value: true,
                                            groupValue: _isNoLessonContract ? true : _useDefaultMaxLsPerDay,
                                            onChanged: _isNoLessonContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxLsPerDay = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '제한없음',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isNoLessonContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // 수정 라디오
                                          Radio<bool>(
                                            value: false,
                                            groupValue: _isNoLessonContract ? true : _useDefaultMaxLsPerDay,
                                            onChanged: _isNoLessonContract ? null : (value) {
                                              setState(() {
                                                _useDefaultMaxLsPerDay = value!;
                                              });
                                            },
                                            activeColor: Color(0xFF6366F1),
                                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                                if (states.contains(MaterialState.selected)) {
                                                  return Color(0xFF6366F1);
                                                }
                                                return Color(0xFF6366F1).withOpacity(0.3);
                                              },
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            '최대',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isNoLessonContract ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              controller: _maxLsPerDayController,
                                              enabled: !_isNoLessonContract && !_useDefaultMaxLsPerDay,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: (_isNoLessonContract || _useDefaultMaxLsPerDay) ? Colors.grey : Colors.black87,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '240',
                                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
                                                ),
                                                disabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1).withOpacity(0.3), width: 1),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '분으로 설정',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: (_isNoLessonContract || _useDefaultMaxLsPerDay) ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // 구분선
                                Divider(color: Colors.grey.shade300, thickness: 1),
                                SizedBox(height: 16),
                                // 프로그램 예약설정 섹션
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        '프로그램 예약설정',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF0F9FF),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Color(0xFF3B82F6).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // 첫 번째 줄: 프로그램 정보 + 액션 버튼
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.golf_course,
                                                  color: Color(0xFF3B82F6),
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _selectedProgramName.isNotEmpty
                                                        ? _selectedProgramName
                                                        : '타석(시간권)+레슨 통합예약을 위한 프로그램화된 상품으로 설정합니다.',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: _selectedProgramName.isNotEmpty
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      color: _selectedProgramName.isNotEmpty
                                                          ? Color(0xFF1F2937)
                                                          : Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ),
                                                // 액션 버튼들 (아이콘으로 컴팩트하게)
                                                _selectedProgramId.isEmpty
                                                    ? IconButton(
                                                        onPressed: _showAddProgramDialog,
                                                        icon: Icon(Icons.add, color: Color(0xFF10B981), size: 18),
                                                        tooltip: '프로그램 등록',
                                                        constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                                                      )
                                                    : Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            onPressed: _showEditProgramDialog,
                                                            icon: Icon(Icons.edit, color: Color(0xFF6366F1), size: 16),
                                                            tooltip: '프로그램 수정',
                                                            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                                          ),
                                                          SizedBox(width: 6),
                                                          IconButton(
                                                            onPressed: _showDeleteProgramConfirm,
                                                            icon: Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                                            tooltip: '연결 해제',
                                                            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                                          ),
                                                        ],
                                                      ),
                                              ],
                                            ),
                                            // 두 번째 줄: 타임라인 미리보기 (연결된 경우만)
                                            if (_selectedProgramId.isNotEmpty) ...[
                                              SizedBox(height: 8),
                                              _buildCompactTimelinePreview(),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // 버튼
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        '취소',
                  style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        print('🟢 저장 버튼이 눌렸습니다!');
                        print('🟢 _isLoading 상태: $_isLoading');
                        _handleSave();
                      },
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isEdit ? '수정하기' : '추가하기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6366F1),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
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
  
  // 컴팩트한 타임라인 미리보기 위젯
  Widget _buildCompactTimelinePreview() {
    if (_selectedProgramId.isEmpty) return Container();
    
    // 임시 프로그램 데이터가 있으면 사용
    if (_temporaryProgramData != null && _temporaryProgramData!['program_id'] == _selectedProgramId) {
      List<Map<String, dynamic>> timelineSessions = _temporaryProgramData!['timeline_sessions'] != null 
          ? List<Map<String, dynamic>>.from(_temporaryProgramData!['timeline_sessions'])
          : [];
      int totalMinutes = _temporaryProgramData!['ts_min'] ?? 0;
      
      return _buildTimelineWidget(timelineSessions, totalMinutes);
    } else {
      // 기존 프로그램의 경우 실제 데이터 로드
      return FutureBuilder<Map<String, dynamic>?>(
        future: _loadExistingProgramData(_selectedProgramId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B7280)),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '타임라인 정보 로딩 중...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 6),
                  Text(
                    '타임라인 정보를 로드할 수 없습니다',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          
          final programData = snapshot.data!;
          final timelineSessions = programData['timeline_sessions'] as List<Map<String, dynamic>>? ?? [];
          final totalMinutes = programData['ts_min'] as int? ?? 0;
          
          return _buildTimelineWidget(timelineSessions, totalMinutes);
        },
      );
    }
  }
  
  // 타임라인 위젯 생성
  Widget _buildTimelineWidget(List<Map<String, dynamic>> timelineSessions, int totalMinutes) {
    if (timelineSessions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF9CA3AF), size: 16),
            SizedBox(width: 6),
            Text(
              '타임라인 정보가 없습니다',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // 타임라인 바 (동적 크기 조정)
          Expanded(
            flex: 17, // 17/20 공간 사용 (85%)
            child: Container(
              height: 28, // 높이 더 증가
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth - (timelineSessions.length - 1); // 마진 제외
                  
                  return Row(
                    children: timelineSessions.map((session) {
                      final duration = session['duration'] as int;
                      final type = session['type'] as String;
                      final width = totalMinutes > 0 ? (duration / totalMinutes) * availableWidth : 0.0;
                      
                      return Container(
                        width: width,
                        height: 28,
                        margin: EdgeInsets.only(right: session != timelineSessions.last ? 1 : 0),
                        decoration: BoxDecoration(
                          color: type == 'lesson' ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _getTimelineText(width, duration, type),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12, // 폰트 크기 더 증가
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 8), // 간격 줄임
          // 요약 정보 (오른쪽) - 더 컴팩트하게
          Flexible(
            flex: 3, // 3/20 공간 사용 (15%)
            child: _buildCompactSummary(timelineSessions, totalMinutes),
          ),
        ],
      ),
    );
  }
  
  // 타임라인 바 너비에 따른 동적 텍스트 생성
  String _getTimelineText(double width, int duration, String type) {
    if (width < 30) {
      // 너비가 30px 미만: 숫자만
      return '${duration}';
    } else if (width < 60) {
      // 너비가 60px 미만: 숫자 + 단위
      return '${duration}분';
    } else {
      // 너비가 60px 이상: 타입 + 숫자 + 단위
      final typeLabel = type == 'lesson' ? '레슨' : '연습';
      return '${typeLabel} ${duration}분';
    }
  }
  
  Widget _buildTimelineChip(String label, int minutes, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        minutes > 0 ? '$label ${minutes}분' : label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  // 컴팩트한 요약 정보 (총 50분 (레슨 30분, 연습 20분) 형태)
  Widget _buildCompactSummary(List<Map<String, dynamic>> timelineSessions, int totalMinutes) {
    return Container(
      child: Text(
        '총 ${totalMinutes}분',
        style: TextStyle(
          fontSize: 14, // 폰트 크기 증가
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }
} 