import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '/services/table_design.dart';
import '/services/upper_button_input_design.dart';

class TsUsageRankingPage extends StatefulWidget {
  const TsUsageRankingPage({super.key});

  @override
  State<TsUsageRankingPage> createState() => _TsUsageRankingPageState();
}

class _TsUsageRankingPageState extends State<TsUsageRankingPage> {
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isFullPeriod = false;
  DateTime? _earliestDate;
  
  List<Map<String, dynamic>> _rankingData = [];
  Set<String> _paymentMethods = {};
  Set<String> _selectedPaymentMethods = {};
  bool _isLoading = false;
  bool _isSelectionMode = false;
  Set<int> _selectedMembers = {};
  
  final _eventContentController = TextEditingController();
  final _handicapController = TextEditingController();
  bool _isHandicap = true;
  bool _includeHandicap = true; // 핸디캡 포함 여부
  
  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }
  
  @override
  void dispose() {
    _eventContentController.dispose();
    _handicapController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    
    try {
      // v2_priced_TS에서 결제방법 가져오기
      final response = await ApiService.getTsData(
        fields: ['ts_payment_method'],
        where: [
          {'field': 'ts_payment_method', 'operator': 'IS NOT', 'value': null},
        ],
      );
      
      final methods = <String>{};
      for (var row in response) {
        if (row['ts_payment_method'] != null && row['ts_payment_method'].toString().trim().isNotEmpty) {
          final paymentMethod = row['ts_payment_method'].toString().trim();
          // 핸디캡 관련 결제방법은 제외 (핸디캡 토글로 별도 관리)
          if (!paymentMethod.startsWith('이벤트선정')) {
            methods.add(paymentMethod);
          }
        }
      }
      
      // v2_eventhandicap_TS에서 결제방법을 가져오되 핸디캡 관련은 제외
      try {
        final handicapMethods = await _getHandicapPaymentMethods();
        for (final method in handicapMethods) {
          if (!method.startsWith('이벤트선정')) {
            methods.add(method);
          }
        }
      } catch (e) {
        print('핸디캡 결제방법 조회 오류: $e');
      }
      
      setState(() {
        _paymentMethods = methods;
        _selectedPaymentMethods = Set.from(methods);
      });
      
      // 데이터 로드
      await _loadRankingData();
    } catch (e) {
      print('결제 방법 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결제 방법 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadRankingData() async {
    if (_selectedPaymentMethods.isEmpty) {
      setState(() => _rankingData = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // WHERE 조건 구성
      final where = <Map<String, dynamic>>[
        {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        {'field': 'ts_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
        {'field': 'ts_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
        {'field': 'member_id', 'operator': 'IS NOT', 'value': null},
        {'field': 'ts_min', 'operator': '>', 'value': 0},
      ];
      
      // 선택된 결제방법 필터링
      if (_selectedPaymentMethods.isNotEmpty && _selectedPaymentMethods.length < _paymentMethods.length) {
        where.add({
          'field': 'ts_payment_method',
          'operator': 'IN',
          'value': _selectedPaymentMethods.toList(),
        });
      }
      
      print('조회 조건: $where');
      
      final response = await ApiService.getTsData(
        fields: ['member_id', 'member_name', 'member_phone', 'member_type', 'ts_min'],
        where: where,
      );
      
      // v2_eventhandicap_TS 테이블에서도 데이터 조회 (이벤트선정 핸디캡)
      List<Map<String, dynamic>> handicapResponse = [];
      
      // 핸디캡이 활성화된 경우에만 조회
      if (_includeHandicap) {
        final handicapWhere = <Map<String, dynamic>>[
          {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
          {'field': 'ts_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
          {'field': 'ts_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
          {'field': 'member_id', 'operator': 'IS NOT', 'value': null},
          {'field': 'ts_payment_method', 'operator': 'IN', 'value': ['이벤트선정 차감', '이벤트선정 보너스']},
        ];
        
        handicapResponse = await _getHandicapData(handicapWhere);
      }
      
      print('타석이용 조회 결과: ${response.length}건');
      print('핸디캡 조회 결과: ${handicapResponse.length}건');
      
      // member_id별로 집계 (타석이용 + 핸디캡)
      final Map<int, Map<String, dynamic>> aggregatedData = {};
      
      // 타석이용 데이터 집계
      for (var row in response) {
        if (row['member_id'] == null) continue;
        
        final memberId = row['member_id'] is int 
            ? row['member_id'] as int 
            : int.tryParse(row['member_id'].toString()) ?? 0;
        
        if (memberId == 0) continue;
        
        final tsMin = row['ts_min'] is int 
            ? row['ts_min'] as int
            : int.tryParse(row['ts_min'].toString()) ?? 0;
        
        if (aggregatedData.containsKey(memberId)) {
          aggregatedData[memberId]!['total_minutes'] += tsMin;
          aggregatedData[memberId]!['usage_count'] += 1;
          // total_combined_minutes 업데이트
          aggregatedData[memberId]!['total_combined_minutes'] = 
              aggregatedData[memberId]!['total_minutes'] + (aggregatedData[memberId]!['handicap_minutes'] ?? 0);
        } else {
          aggregatedData[memberId] = {
            'member_id': memberId,
            'member_name': row['member_name'] ?? '',
            'member_phone': row['member_phone'] ?? '',
            'member_type': row['member_type'] ?? '',
            'total_minutes': tsMin,
            'handicap_minutes': 0, // 초기값
            'total_combined_minutes': tsMin, // 처음에는 타석이용 시간만
            'usage_count': 1,
          };
        }
      }
      
      // 핸디캡 데이터를 먼저 member_id별로 합산 (마이너스 값 그대로)
      final Map<int, int> handicapSums = {};
      final Map<int, Map<String, dynamic>> handicapMemberInfo = {};
      
      print('=== 핸디캡 데이터 개별 처리 시작 ===');
      for (var row in handicapResponse) {
        if (row['member_id'] == null) continue;
        
        final memberId = row['member_id'] is int 
            ? row['member_id'] as int 
            : int.tryParse(row['member_id'].toString()) ?? 0;
        
        if (memberId == 0) continue;
        
        final tsMin = row['ts_min'] is int 
            ? row['ts_min'] as int // 마이너스 값 그대로 유지
            : int.tryParse(row['ts_min'].toString()) ?? 0;
        
        print('회원 $memberId: 개별 핸디캡 $tsMin분');
        
        // 0인 값은 제외
        if (tsMin == 0) {
          print('회원 $memberId: 0분 핸디캡은 제외');
          continue;
        }
        
        // 핸디캡 합산 (마이너스 값들이 누적됨)
        final previousSum = handicapSums[memberId] ?? 0;
        handicapSums[memberId] = previousSum + tsMin;
        
        print('회원 $memberId: 누적 핸디캡 $previousSum + $tsMin = ${handicapSums[memberId]}분');
        
        // 회원 정보 저장 (마지막 정보로 업데이트)
        handicapMemberInfo[memberId] = {
          'member_name': row['member_name'] ?? '',
          'member_phone': row['member_phone'] ?? '',
          'member_type': row['member_type'] ?? '',
        };
      }
      
      print('=== 핸디캡 최종 합산 결과 ===');
      for (var entry in handicapSums.entries) {
        print('회원 ${entry.key}: 총 핸디캡 ${entry.value}분');
      }
      
      // 합산된 핸디캡을 원래 값 그대로 사용하여 집계에 반영
      for (var entry in handicapSums.entries) {
        final memberId = entry.key;
        final totalHandicap = entry.value; // 원래 값 그대로 사용 (마이너스면 마이너스)
        final memberInfo = handicapMemberInfo[memberId]!;
        
        if (aggregatedData.containsKey(memberId)) {
          // 기존 회원에게 핸디캡 시간 추가 (이용횟수는 증가시키지 않음)
          aggregatedData[memberId]!['handicap_minutes'] = totalHandicap;
          aggregatedData[memberId]!['total_combined_minutes'] = 
              (aggregatedData[memberId]!['total_minutes'] ?? 0) + totalHandicap;
          print('기존 회원 $memberId에게 핸디캡 ${totalHandicap}분 추가 (이용횟수 제외)');
        } else {
          // 핸디캡만 있는 회원 (타석이용 없음)
          aggregatedData[memberId] = {
            'member_id': memberId,
            'member_name': memberInfo['member_name'],
            'member_phone': memberInfo['member_phone'],
            'member_type': memberInfo['member_type'],
            'total_minutes': 0, // 타석이용 시간은 0
            'handicap_minutes': totalHandicap,
            'total_combined_minutes': totalHandicap, // 합계는 핸디캡만
            'usage_count': 0, // 실제 이용횟수는 0
          };
          print('새 회원 $memberId: 핸디캡만 ${totalHandicap}분 (이용횟수 0)');
        }
      }
      
      // 초기값 설정
      for (var data in aggregatedData.values) {
        data['handicap_minutes'] ??= 0;
        data['total_combined_minutes'] ??= data['total_minutes'] ?? 0;
      }
      
      // 정렬 및 순위 부여 (합계 시간 기준)
      final sortedData = aggregatedData.values.toList()
        ..sort((a, b) => b['total_combined_minutes'].compareTo(a['total_combined_minutes']));
      
      for (int i = 0; i < sortedData.length; i++) {
        sortedData[i]['rank'] = i + 1;
      }
      
      print('집계 결과: ${sortedData.length}명');
      
      setState(() => _rankingData = sortedData);
    } catch (e) {
      print('데이터 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // v2_eventhandicap_TS에서 결제방법 가져오기
  Future<Set<String>> _getHandicapPaymentMethods() async {
    try {
      final response = await SupabaseAdapter.getData(
        table: 'v2_eventhandicap_TS',
        fields: ['ts_payment_method'],
        where: [
          {'field': 'ts_payment_method', 'operator': 'IS NOT', 'value': null},
        ],
      );

      final methods = <String>{};
      for (var row in response) {
        if (row['ts_payment_method'] != null && row['ts_payment_method'].toString().trim().isNotEmpty) {
          methods.add(row['ts_payment_method'].toString().trim());
        }
      }
      return methods;
    } catch (e) {
      print('핸디캡 결제방법 조회 오류: $e');
      return <String>{};
    }
  }
  
  // v2_eventhandicap_TS 데이터 조회
  Future<List<Map<String, dynamic>>> _getHandicapData(List<Map<String, dynamic>> where) async {
    try {
      print('핸디캡 API 요청 데이터: $where');

      final response = await SupabaseAdapter.getData(
        table: 'v2_eventhandicap_TS',
        fields: ['member_id', 'member_name', 'member_phone', 'member_type', 'ts_min'],
        where: where,
      );

      print('핸디캡 데이터 파싱 완료: ${response.length}건');
      return response;
    } catch (e) {
      print('핸디캡 데이터 조회 오류: $e');
      return [];
    }
  }
  
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      useRootNavigator: false,
      builder: (context, child) {
        return Dialog(
          child: SizedBox(
            width: 400,
            height: 500,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF3B82F6),
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _isFullPeriod = false;
      });
      await _loadRankingData();
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      useRootNavigator: false,
      builder: (context, child) {
        return Dialog(
          child: SizedBox(
            width: 400,
            height: 500,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF3B82F6),
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _isFullPeriod = false;
      });
      await _loadRankingData();
    }
  }

  Future<void> _loadEarliestDate() async {
    try {
      // 타석 데이터에서 가장 이른 날짜 찾기
      final response = await ApiService.getTsData(
        fields: ['TS_date'],
        where: [
          {'field': 'TS_date', 'operator': 'IS NOT', 'value': null},
        ],
        orderBy: [{'field': 'TS_date', 'direction': 'ASC'}],
        limit: 1,
      );
      
      if (response.isNotEmpty && response.first['TS_date'] != null) {
        final dateStr = response.first['TS_date'].toString();
        _earliestDate = DateTime.parse(dateStr);
      } else {
        _earliestDate = DateTime.now().subtract(const Duration(days: 365));
      }
    } catch (e) {
      print('가장 이른 날짜 조회 오류: $e');
      _earliestDate = DateTime.now().subtract(const Duration(days: 365));
    }
  }

  void _toggleFullPeriod(bool? value) async {
    if (value == null) return;
    
    setState(() {
      _isFullPeriod = value;
      if (_isFullPeriod) {
        if (_earliestDate == null) {
          _startDate = DateTime.now().subtract(const Duration(days: 365));
        } else {
          _startDate = _earliestDate!;
        }
        _endDate = DateTime.now();
      }
    });
    
    if (_isFullPeriod && _earliestDate == null) {
      await _loadEarliestDate();
      setState(() {
        if (_earliestDate != null) {
          _startDate = _earliestDate!;
        }
      });
    }
    
    await _loadRankingData();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 필터 섹션
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border.all(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 전체기간 체크박스
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isFullPeriod,
                      onChanged: _toggleFullPeriod,
                      activeColor: Color(0xFF06B6D4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '전체기간',
                      style: TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // 시작일
                Text(
                  '시작일',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF1E293B),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 12),
                InkWell(
                  onTap: _isFullPeriod ? null : _selectStartDate,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _isFullPeriod ? Color(0xFFF3F4F6) : Colors.white,
                      border: Border.all(color: Color(0xFFE2E8F0), width: 1.0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: _isFullPeriod ? Color(0xFF9CA3AF) : Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy-MM-dd').format(_startDate),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: _isFullPeriod ? Color(0xFF9CA3AF) : Color(0xFF1E293B),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 종료일
                Text(
                  '종료일',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF1E293B),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 12),
                InkWell(
                  onTap: _isFullPeriod ? null : _selectEndDate,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _isFullPeriod ? Color(0xFFF3F4F6) : Colors.white,
                      border: Border.all(color: Color(0xFFE2E8F0), width: 1.0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: _isFullPeriod ? Color(0xFF9CA3AF) : Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy-MM-dd').format(_endDate),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: _isFullPeriod ? Color(0xFF9CA3AF) : Color(0xFF1E293B),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Spacer(),
                // 핸디캡조정 버튼
                ButtonDesignUpper.buildIconButton(
                  text: _isSelectionMode ? '취소' : '핸디캡조정',
                  icon: _isSelectionMode ? Icons.close : Icons.emoji_events,
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) {
                        _selectedMembers.clear();
                      }
                    });
                  },
                  color: _isSelectionMode ? 'gray' : 'purple',
                  size: 'medium',
                ),
                if (_isSelectionMode && _selectedMembers.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ButtonDesignUpper.buildIconButton(
                    text: '선택완료 (${_selectedMembers.length})',
                    icon: Icons.check_circle,
                    onPressed: _showEventDialog,
                    color: 'cyan',
                    size: 'medium',
                  ),
                ],
              ],
            ),
          ),
          // 필터 칩 섹션
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 결제방법 필터
                ..._paymentMethods.map((method) => FilterChip(
                  label: Text(
                    method,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: _selectedPaymentMethods.contains(method) ? FontWeight.w600 : FontWeight.w500,
                      color: _selectedPaymentMethods.contains(method)
                        ? Colors.white
                        : const Color(0xFF64748B),
                    ),
                  ),
                  selected: _selectedPaymentMethods.contains(method),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPaymentMethods.add(method);
                      } else {
                        _selectedPaymentMethods.remove(method);
                      }
                    });
                    _loadRankingData();
                  },
                  selectedColor: const Color(0xFF0891B2),
                  backgroundColor: const Color(0xFFFAFAFA),
                  side: BorderSide(
                    color: _selectedPaymentMethods.contains(method)
                      ? const Color(0xFF0891B2)
                      : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  checkmarkColor: Colors.white,
                  elevation: _selectedPaymentMethods.contains(method) ? 2 : 0,
                  pressElevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),

                // 핸디캡 토글
                FilterChip(
                  label: Text(
                    '핸디캡',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: _includeHandicap ? FontWeight.w600 : FontWeight.w500,
                      color: _includeHandicap ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                  selected: _includeHandicap,
                  onSelected: (selected) {
                    setState(() {
                      _includeHandicap = selected;
                    });
                    _loadPaymentMethods(); // 데이터 새로고침
                  },
                  selectedColor: const Color(0xFFDC2626),
                  backgroundColor: const Color(0xFFFAFAFA),
                  side: BorderSide(
                    color: _includeHandicap ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  checkmarkColor: Colors.white,
                  elevation: _includeHandicap ? 2 : 0,
                  pressElevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          // 데이터 테이블
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: TableDesign.buildTableContainer(
                child: Column(
                  children: [
                    // 헤더
                    TableDesign.buildTableHeader(
                      children: [
                        if (_isSelectionMode) TableDesign.buildHeaderColumn(text: '선택', width: 60.0),
                        TableDesign.buildHeaderColumn(text: '순위', flex: 1),
                        TableDesign.buildHeaderColumn(text: '회원명', flex: 2),
                        TableDesign.buildHeaderColumn(text: '회원유형', flex: 2),
                        TableDesign.buildHeaderColumn(text: '전화번호', flex: 3),
                        TableDesign.buildHeaderColumn(text: '이용시간(분)', flex: 2),
                        TableDesign.buildHeaderColumn(text: '핸디캡(분)', flex: 2),
                        TableDesign.buildHeaderColumn(text: '종합점수(분)', flex: 2),
                        TableDesign.buildHeaderColumn(text: '이용횟수', flex: 2),
                      ],
                    ),
                    // 본문
                    Expanded(
                      child: TableDesign.buildTableBody(
                        itemCount: _rankingData.length,
                        itemBuilder: (context, index) {
                          final data = _rankingData[index];
                          final isTop3 = data['rank'] <= 3;

                          // 배경색 결정
                          Color? backgroundColor;
                          if (data['rank'] == 1) {
                            backgroundColor = Colors.amber.withValues(alpha: 0.1);
                          } else if (data['rank'] == 2) {
                            backgroundColor = Colors.grey[300]?.withValues(alpha: 0.1);
                          } else if (data['rank'] == 3) {
                            backgroundColor = Colors.orange[200]?.withValues(alpha: 0.1);
                          }

                          return _RankingRowWidget(
                            backgroundColor: backgroundColor,
                            children: [
                              // 선택 체크박스
                              if (_isSelectionMode)
                                Container(
                                  width: 60.0,
                                  alignment: Alignment.center,
                                  child: Checkbox(
                                    value: _selectedMembers.contains(data['member_id']),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value ?? false) {
                                          _selectedMembers.add(data['member_id']);
                                        } else {
                                          _selectedMembers.remove(data['member_id']);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF3B82F6),
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              // 순위
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (data['rank'] == 1) const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                                    if (data['rank'] == 2) const Icon(Icons.emoji_events, color: Colors.grey, size: 20),
                                    if (data['rank'] == 3) Icon(Icons.emoji_events, color: Colors.orange[700], size: 20),
                                    if (isTop3) const SizedBox(width: 4),
                                    Text(
                                      '${data['rank']}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                                        fontSize: isTop3 ? 16 : 14,
                                        color: const Color(0xFF1E293B),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              // 회원명
                              Expanded(
                                flex: 2,
                                child: Text(
                                  data['member_name'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 회원유형
                              Expanded(
                                flex: 2,
                                child: Text(
                                  data['member_type'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 전화번호
                              Expanded(
                                flex: 3,
                                child: Text(
                                  data['member_phone'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 이용시간(분) - 클릭 가능
                              Expanded(
                                flex: 2,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _showTsDetailsDialog(data['member_id'], data['member_name']),
                                    child: Text(
                                      '${data['total_minutes'] ?? 0}',
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF3B82F6),
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              // 핸디캡(분) - 클릭 가능
                              Expanded(
                                flex: 2,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _showHandicapDetailsDialog(data['member_id'], data['member_name']),
                                    child: Text(
                                      '${data['handicap_minutes'] ?? 0}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: (data['handicap_minutes'] ?? 0) != 0
                                          ? ((data['handicap_minutes'] ?? 0) > 0
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFFDC2626))
                                          : const Color(0xFF6B7280),
                                        fontSize: 14,
                                        fontWeight: (data['handicap_minutes'] ?? 0) != 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                        decoration: (data['handicap_minutes'] ?? 0) != 0
                                          ? TextDecoration.underline
                                          : null,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              // 종합점수(분)
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${data['total_combined_minutes'] ?? 0}',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
                                    color: isTop3 ? const Color(0xFF3B82F6) : const Color(0xFF374151),
                                    fontSize: isTop3 ? 16 : 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 이용횟수
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${data['usage_count'] ?? 0}',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        },
                        isLoading: _isLoading,
                        hasError: false,
                        emptyWidget: Center(
                          child: Text(
                            '데이터가 없습니다',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showEventDialog() {
    final selectedMemberData = _rankingData
        .where((data) => _selectedMembers.contains(data['member_id']))
        .toList();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '이벤트 선정 (핸디캡 등록)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 이벤트 선정회원
                const Text(
                  '이벤트 선정회원:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: selectedMemberData.map((member) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${member['member_name']} (${member['member_type']}) - ${member['total_minutes']}분',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                
                // 이벤트 선정내용
                const Text(
                  '이벤트 선정내용:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _eventContentController,
                  style: const TextStyle(color: Color(0xFF1E293B)),
                  decoration: const InputDecoration(
                    hintText: '이벤트 선정 내용을 입력하세요',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                
                // 조정 유형 선택
                const Text(
                  '조정 유형:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isHandicap ? const Color(0xFFFEF2F2) : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(7),
                              bottomLeft: Radius.circular(7),
                            ),
                            border: _isHandicap ? Border.all(color: const Color(0xFFDC2626)) : null,
                          ),
                          child: RadioListTile<bool>(
                            title: const Text(
                              '핸디캡 (차감)',
                              style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                            ),
                            value: true,
                            groupValue: _isHandicap,
                            onChanged: (value) {
                              setDialogState(() {
                                _isHandicap = value ?? true;
                              });
                            },
                            activeColor: const Color(0xFFDC2626),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isHandicap ? const Color(0xFFF0F9FF) : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(7),
                              bottomRight: Radius.circular(7),
                            ),
                            border: !_isHandicap ? Border.all(color: const Color(0xFF3B82F6)) : null,
                          ),
                          child: RadioListTile<bool>(
                            title: const Text(
                              '추가점수 (보너스)',
                              style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                            ),
                            value: false,
                            groupValue: _isHandicap,
                            onChanged: (value) {
                              setDialogState(() {
                                _isHandicap = value ?? true;
                              });
                            },
                            activeColor: const Color(0xFF3B82F6),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 조정 시간(분)
                Text(
                  '${_isHandicap ? "핸디캡" : "추가점수"}(분):',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _handicapController,
                  style: const TextStyle(color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: '${_isHandicap ? "핸디캡" : "추가점수"} 시간(분)을 입력하세요',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixText: '분',
                    suffixStyle: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // 설명
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Text(
                    '이벤트 선정되어 향후 이벤트시 핸디캡이 적용됩니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0C4A6E),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // 유효성 검사
                        if (_eventContentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이벤트 선정내용을 입력해주세요.')),
                          );
                          return;
                        }
                        
                        final inputMinutes = int.tryParse(_handicapController.text.trim());
                        if (inputMinutes == null || inputMinutes <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('올바른 ${_isHandicap ? "핸디캡" : "추가점수"} 시간을 입력해주세요.')),
                          );
                          return;
                        }
                        
                        // 유효성 검사 통과하면 다이얼로그 닫고 저장
                        Navigator.of(context).pop();
                        await _saveEventHandicap();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('확인'),
                    ),
                  ],
                ),
                ],
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Future<void> _saveEventHandicap() async {
    final inputMinutes = int.tryParse(_handicapController.text.trim());
    // 핸디캡은 음수(-), 추가점수는 양수(+)로 처리
    final handicapMinutes = _isHandicap ? -inputMinutes! : inputMinutes!;
    
    try {
      setState(() => _isLoading = true);
      
      final selectedMemberData = _rankingData
          .where((data) => _selectedMembers.contains(data['member_id']))
          .toList();
      
      // 각 선정된 회원에 대해 v2_eventhandicap_TS 테이블에 저장
      for (final member in selectedMemberData) {
        final eventData = {
          'ts_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'ts_payment_method': handicapMinutes < 0 ? '이벤트선정 차감' : '이벤트선정 보너스',
          'ts_status': '결제완료',
          'member_id': member['member_id'],
          'member_type': member['member_type'] ?? '',
          'member_name': member['member_name'] ?? '',
          'member_phone': member['member_phone'] ?? '',
          'ts_min': handicapMinutes,
          'time_stamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          'memo': _eventContentController.text.trim(),
        };
        
        // v2_eventhandicap_TS 테이블에 저장
        await SupabaseAdapter.addData(
          table: 'v2_eventhandicap_TS',
          data: eventData,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedMemberData.length}명의 이벤트 핸디캡이 등록되었습니다.'),
            backgroundColor: const Color(0xFF3B82F6),
          ),
        );
        
        // 선택 모드 해제 및 데이터 새로고침
        setState(() {
          _isSelectionMode = false;
          _selectedMembers.clear();
        });
        
        // 입력 필드 초기화
        _eventContentController.clear();
        _handicapController.clear();
        
        // 결제방법과 데이터 새로고침 (핸디캡이 추가되었으므로)
        await _loadPaymentMethods();
      }
    } catch (e) {
      print('이벤트 핸디캡 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 타석 상세 내역 팝업
  void _showTsDetailsDialog(int memberId, String memberName) async {
    try {
      final where = <Map<String, dynamic>>[
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        {'field': 'ts_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
        {'field': 'ts_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
      ];

      // 결제방법 필터 적용
      if (_selectedPaymentMethods.isNotEmpty && _selectedPaymentMethods.length < _paymentMethods.length) {
        where.add({
          'field': 'ts_payment_method',
          'operator': 'IN',
          'value': _selectedPaymentMethods.toList(),
        });
      }

      final response = await ApiService.getTsData(
        fields: ['ts_date', 'ts_payment_method', 'ts_min'],
        where: where,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$memberName 타석 내역',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('날짜', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('결제방법', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('이용시간(분)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: response.map<DataRow>((data) {
                        return DataRow(cells: [
                          DataCell(Text(data['ts_date'] ?? '')),
                          DataCell(Text(data['ts_payment_method'] ?? '')),
                          DataCell(Text(
                            '${data['ts_min'] ?? 0}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.black),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '총 이용시간: ${response.fold<int>(0, (sum, data) => sum + (data['ts_min'] as int? ?? 0))}분',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('타석 내역 조회 실패: $e')),
      );
    }
  }

  // 핸디캡 상세 내역 팝업
  void _showHandicapDetailsDialog(int memberId, String memberName) async {
    // 핸디캡이 비활성화된 경우 팝업 표시하지 않음
    if (!_includeHandicap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('핸디캡이 비활성화되어 있습니다.')),
      );
      return;
    }
    try {
      final handicapData = await SupabaseAdapter.getData(
        table: 'v2_eventhandicap_TS',
        fields: ['ts_date', 'ts_payment_method', 'ts_min', 'memo'],
        where: _buildHandicapWhereClause(memberId),
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$memberName 핸디캡 내역',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  child: handicapData.isEmpty
                      ? const Center(child: Text('핸디캡 내역이 없습니다.'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 15,
                            columns: const [
                              DataColumn(label: Text('날짜', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('타입', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('조정(분)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('메모', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: handicapData.map<DataRow>((data) {
                              final handicapMin = data['ts_min'] as int? ?? 0;
                              return DataRow(cells: [
                                DataCell(Text(data['ts_date'] ?? '')),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: handicapMin < 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    data['ts_payment_method'] ?? '',
                                    style: TextStyle(
                                      color: handicapMin < 0 ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                                      fontSize: 12,
                                    ),
                                  ),
                                )),
                                DataCell(Text(
                                  '${handicapMin > 0 ? '+' : ''}$handicapMin',
                                  style: TextStyle(
                                    color: handicapMin >= 0 ? const Color(0xFF3B82F6) : const Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                )),
                                DataCell(Text(data['memo'] ?? '')),
                              ]);
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  '총 핸디캡: ${handicapData.fold<int>(0, (sum, data) => sum + (data['ts_min'] as int? ?? 0))}분',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('핸디캡 내역 조회 실패: $e')),
      );
    }
  }

  // 핸디캡 조회를 위한 where 절 구성
  List<Map<String, dynamic>> _buildHandicapWhereClause(int memberId) {
    final where = <Map<String, dynamic>>[
      {'field': 'member_id', 'operator': '=', 'value': memberId},
      {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
      {'field': 'ts_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
      {'field': 'ts_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
    ];

    // 결제방법 필터 적용 (이벤트선정 차감, 이벤트선정 보너스는 항상 포함)
    if (_selectedPaymentMethods.isNotEmpty && _selectedPaymentMethods.length < _paymentMethods.length) {
      final paymentMethodsWithEvents = Set<String>.from(_selectedPaymentMethods);
      // 기존 선택에 이벤트 타입들이 포함되어 있지 않으면 추가
      if (_selectedPaymentMethods.contains('이벤트선정 차감') || _selectedPaymentMethods.contains('이벤트선정 보너스')) {
        paymentMethodsWithEvents.addAll(['이벤트선정 차감', '이벤트선정 보너스']);
      }
      where.add({
        'field': 'ts_payment_method',
        'operator': 'IN',
        'value': paymentMethodsWithEvents.toList(),
      });
    }

    return where;
  }
}

// 커스텀 행 위젯 (배경색 지원)
class _RankingRowWidget extends StatefulWidget {
  final List<Widget> children;
  final Color? backgroundColor;

  const _RankingRowWidget({
    required this.children,
    this.backgroundColor,
  });

  @override
  _RankingRowWidgetState createState() => _RankingRowWidgetState();
}

class _RankingRowWidgetState extends State<_RankingRowWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 60.0),
        decoration: BoxDecoration(
          color: isHovered
              ? Color(0xFFF1F5F9)
              : (widget.backgroundColor ?? Colors.white),
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFF1F5F9),
              width: 1.0,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}