import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '/services/table_design.dart';
import '/services/upper_button_input_design.dart';

class LessonUsageRankingPage extends StatefulWidget {
  const LessonUsageRankingPage({super.key});

  @override
  State<LessonUsageRankingPage> createState() => _LessonUsageRankingPageState();
}

class _LessonUsageRankingPageState extends State<LessonUsageRankingPage> {
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isFullPeriod = false;
  DateTime? _earliestDate;
  
  List<Map<String, dynamic>> _rankingData = [];
  Set<String> _lessonTypes = {};
  Set<String> _selectedLessonTypes = {};
  Map<String, String> _proIdToName = {};
  Set<String> _selectedProIds = {};
  bool _isLoading = false;
  bool _isSelectionMode = false;
  Set<int> _selectedMembers = {};
  
  final _eventContentController = TextEditingController();
  final _handicapController = TextEditingController();
  String? _selectedProId;
  String? _selectedProName;
  bool _isHandicap = true; // true: 핸디캡(마이너스), false: 추가점수(플러스)
  bool _includeHandicap = true; // 핸디캡 포함 여부
  
  @override
  void initState() {
    super.initState();
    _loadFilters();
  }
  
  @override
  void dispose() {
    _eventContentController.dispose();
    _handicapController.dispose();
    super.dispose();
  }
  
  Future<void> _loadFilters() async {
    setState(() => _isLoading = true);
    
    try {
      print('=== v2_LS_orders 테이블 접근 시도 ===');
      
      // v2_LS_orders에서 LS_type과 pro_id/pro_name 가져오기
      final response = await ApiService.getLSData(
        fields: ['LS_type', 'pro_id', 'pro_name'],
        where: [
          {'field': 'LS_type', 'operator': 'IS NOT', 'value': null},
          {'field': 'pro_id', 'operator': 'IS NOT', 'value': null},
        ],
      );
      
      print('v2_LS_orders 조회 성공: ${response.length}건');
      if (response.isNotEmpty) {
        print('v2_LS_orders 첫 번째 레코드: ${response.first}');
        print('사용 가능한 필드들: ${response.first.keys.toList()}');
      }
      
      final types = <String>{};
      final proMap = <String, String>{};
      
      for (var row in response) {
        // LS_type 수집 (핸디캡 관련 타입 제외)
        if (row['LS_type'] != null && row['LS_type'].toString().trim().isNotEmpty) {
          final lessonType = row['LS_type'].toString().trim();
          if (!lessonType.startsWith('이벤트선정')) {
            types.add(lessonType);
          }
        }
        
        // pro_id와 pro_name 수집
        if (row['pro_id'] != null && row['pro_name'] != null && 
            row['pro_id'].toString().trim().isNotEmpty && row['pro_name'].toString().trim().isNotEmpty) {
          proMap[row['pro_id'].toString().trim()] = row['pro_name'].toString().trim();
        }
      }
      
      // 핸디캡 필터는 별도 토글로 처리하므로 일반 필터에서 제외
      
      setState(() {
        _lessonTypes = types;
        _selectedLessonTypes = Set.from(types);
        _proIdToName = proMap;
        _selectedProIds = Set.from(proMap.keys);
      });
      
      // 데이터 로드
      await _loadRankingData();
    } catch (e) {
      print('필터 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('필터 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadRankingData() async {
    if (_selectedLessonTypes.isEmpty || _selectedProIds.isEmpty) {
      setState(() => _rankingData = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // WHERE 조건 구성 (예약취소를 제외한 다른 상태들을 명시적으로 포함)
      final where = <Map<String, dynamic>>[
        {'field': 'LS_status', 'operator': 'IN', 'value': ['예약완료', '결제완료', '레슨완료', '진행중', '확정']},
        {'field': 'LS_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
        {'field': 'LS_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
        {'field': 'member_id', 'operator': 'IS NOT', 'value': null},
        {'field': 'LS_net_min', 'operator': '>', 'value': 0},
      ];
      
      // 선택된 레슨타입 필터링
      if (_selectedLessonTypes.isNotEmpty && _selectedLessonTypes.length < _lessonTypes.length) {
        where.add({
          'field': 'LS_type',
          'operator': 'IN',
          'value': _selectedLessonTypes.toList(),
        });
      }
      
      // 선택된 강사 필터링
      if (_selectedProIds.isNotEmpty && _selectedProIds.length < _proIdToName.length) {
        where.add({
          'field': 'pro_id',
          'operator': 'IN',
          'value': _selectedProIds.toList(),
        });
      }
      
      print('조회 조건: $where');
      
      final response = await ApiService.getLSData(
        fields: ['member_id', 'member_name', 'member_type', 'LS_net_min'],
        where: where,
      );
      
      // v2_eventhandicap_LS 테이블에서도 데이터 조회 (이벤트선정 핸디캡)
      List<Map<String, dynamic>> handicapResponse = [];
      
      // 핸디캡이 활성화된 경우에만 조회
      if (_includeHandicap) {
        try {
        final handicapWhere = <Map<String, dynamic>>[
          {'field': 'LS_status', 'operator': 'IN', 'value': ['예약완료', '결제완료', '레슨완료', '진행중', '확정']},
          {'field': 'LS_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
          {'field': 'LS_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
          {'field': 'member_id', 'operator': 'IS NOT', 'value': null},
        ];
        
        // 레슨타입 필터 적용 (이벤트선정 차감, 이벤트선정 보너스는 항상 포함)
        if (_selectedLessonTypes.isNotEmpty && _selectedLessonTypes.length < _lessonTypes.length) {
          final lessonTypesWithEvents = Set<String>.from(_selectedLessonTypes)
            ..addAll(['이벤트선정 차감', '이벤트선정 보너스']);
          handicapWhere.add({
            'field': 'LS_type',
            'operator': 'IN',
            'value': lessonTypesWithEvents.toList(),
          });
        }
        
        // 선택된 강사 필터링 적용
        if (_selectedProIds.isNotEmpty && _selectedProIds.length < _proIdToName.length) {
          handicapWhere.add({
            'field': 'pro_id',
            'operator': 'IN',
            'value': _selectedProIds.toList(),
          });
        }
        
          handicapResponse = await _getHandicapData(handicapWhere);
        } catch (e) {
          print('핸디캡 데이터 조회 중 오류: $e');
        }
      }
      
      print('레슨이용 조회 결과: ${response.length}건');
      print('핸디캡 조회 결과: ${handicapResponse.length}건');
      
      // member_id별로 집계 (레슨이용 + 핸디캡)
      final Map<int, Map<String, dynamic>> aggregatedData = {};
      
      // 레슨이용 데이터 집계
      for (var row in response) {
        if (row['member_id'] == null) continue;
        
        final memberId = row['member_id'] is int 
            ? row['member_id'] as int 
            : int.tryParse(row['member_id'].toString()) ?? 0;
        
        if (memberId == 0) continue;
        
        final lsNetMin = row['LS_net_min'] is int 
            ? row['LS_net_min'] as int
            : int.tryParse(row['LS_net_min'].toString()) ?? 0;
        
        if (aggregatedData.containsKey(memberId)) {
          aggregatedData[memberId]!['total_minutes'] += lsNetMin;
          aggregatedData[memberId]!['usage_count'] += 1;
          // total_combined_minutes 업데이트
          aggregatedData[memberId]!['total_combined_minutes'] = 
              aggregatedData[memberId]!['total_minutes'] + (aggregatedData[memberId]!['handicap_minutes'] ?? 0);
        } else {
          aggregatedData[memberId] = {
            'member_id': memberId,
            'member_name': row['member_name'] ?? '',
            'member_phone': '', // v2_LS_orders에는 phone 필드 없음
            'member_type': row['member_type'] ?? '',
            'total_minutes': lsNetMin,
            'handicap_minutes': 0,
            'total_combined_minutes': lsNetMin,
            'usage_count': 1,
          };
        }
      }
      
      // 핸디캡 데이터를 먼저 member_id별로 합산 (마이너스 값 그대로)
      final Map<int, int> handicapSums = {};
      final Map<int, Map<String, dynamic>> handicapMemberInfo = {};
      
      print('=== 레슨 핸디캡 데이터 개별 처리 시작 ===');
      for (var row in handicapResponse) {
        if (row['member_id'] == null) continue;
        
        final memberId = row['member_id'] is int 
            ? row['member_id'] as int 
            : int.tryParse(row['member_id'].toString()) ?? 0;
        
        if (memberId == 0) continue;
        
        final lsNetMin = row['LS_net_min'] is int 
            ? row['LS_net_min'] as int
            : int.tryParse(row['LS_net_min'].toString()) ?? 0;
        
        print('회원 $memberId: 개별 핸디캡 ${lsNetMin}분');
        
        if (lsNetMin == 0) {
          print('회원 $memberId: 0분 핸디캡은 제외');
          continue;
        }
        
        final previousSum = handicapSums[memberId] ?? 0;
        handicapSums[memberId] = previousSum + lsNetMin;
        
        print('회원 $memberId: 누적 핸디캡 $previousSum + $lsNetMin = ${handicapSums[memberId]}분');
        
        handicapMemberInfo[memberId] = {
          'member_name': row['member_name'] ?? '',
          'member_phone': '', // 핸디캡 테이블에도 phone 필드 없음
          'member_type': row['member_type'] ?? '',
        };
      }
      
      print('=== 레슨 핸디캡 최종 합산 결과 ===');
      for (var entry in handicapSums.entries) {
        print('회원 ${entry.key}: 총 핸디캡 ${entry.value}분');
      }
      
      // 합산된 핸디캡을 원래 값 그대로 사용하여 집계에 반영
      for (var entry in handicapSums.entries) {
        final memberId = entry.key;
        final totalHandicap = entry.value;
        final memberInfo = handicapMemberInfo[memberId]!;
        
        if (aggregatedData.containsKey(memberId)) {
          aggregatedData[memberId]!['handicap_minutes'] = totalHandicap;
          aggregatedData[memberId]!['total_combined_minutes'] = 
              (aggregatedData[memberId]!['total_minutes'] ?? 0) + totalHandicap;
          print('기존 회원 $memberId에게 핸디캡 ${totalHandicap}분 추가 (이용횟수 제외)');
        } else {
          aggregatedData[memberId] = {
            'member_id': memberId,
            'member_name': memberInfo['member_name'],
            'member_phone': '', // phone 필드 없음
            'member_type': memberInfo['member_type'],
            'total_minutes': 0,
            'handicap_minutes': totalHandicap,
            'total_combined_minutes': totalHandicap,
            'usage_count': 0,
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
  
  // v2_eventhandicap_LS에서 필터 데이터 가져오기
  Future<Map<String, dynamic>> _getHandicapFilters() async {
    try {
      final response = await SupabaseAdapter.getData(
        table: 'v2_eventhandicap_LS',
        fields: ['LS_type', 'pro_id', 'pro_name'],
        where: [
          {'field': 'LS_type', 'operator': 'IS NOT', 'value': null},
          {'field': 'pro_id', 'operator': 'IS NOT', 'value': null},
        ],
      );

      final types = <String>{};
      final proMap = <String, String>{};

      for (var row in response) {
        if (row['LS_type'] != null && row['LS_type'].toString().trim().isNotEmpty) {
          types.add(row['LS_type'].toString().trim());
        }
        if (row['pro_id'] != null && row['pro_name'] != null &&
            row['pro_id'].toString().trim().isNotEmpty && row['pro_name'].toString().trim().isNotEmpty) {
          proMap[row['pro_id'].toString().trim()] = row['pro_name'].toString().trim();
        }
      }

      return {'types': types, 'proMap': proMap};
    } catch (e) {
      print('핸디캡 필터 조회 오류: $e');
      return {'types': <String>{}, 'proMap': <String, String>{}};
    }
  }
  
  // v2_eventhandicap_LS 데이터 조회
  Future<List<Map<String, dynamic>>> _getHandicapData(List<Map<String, dynamic>> where) async {
    try {
      print('레슨 핸디캡 API 요청 데이터: $where');

      final response = await SupabaseAdapter.getData(
        table: 'v2_eventhandicap_LS',
        fields: ['member_id', 'member_name', 'member_type', 'LS_net_min'],
        where: where,
      );

      print('레슨 핸디캡 데이터 파싱 완료: ${response.length}건');
      return response;
    } catch (e) {
      print('레슨 핸디캡 데이터 조회 오류: $e');
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
                  primary: Color(0xFF10B981),
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
                  primary: Color(0xFF10B981),
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
      // 레슨 데이터에서 가장 이른 날짜 찾기
      final response = await ApiService.getLSData(
        fields: ['LS_date'],
        where: [
          {'field': 'LS_date', 'operator': 'IS NOT', 'value': null},
        ],
        orderBy: [{'field': 'LS_date', 'direction': 'ASC'}],
        limit: 1,
      );
      
      if (response.isNotEmpty && response.first['LS_date'] != null) {
        final dateStr = response.first['LS_date'].toString();
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
                      activeColor: Color(0xFF10B981),
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
                    color: 'green',
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
                // 레슨타입 필터
                ..._lessonTypes.map((type) => FilterChip(
                  label: Text(
                    type,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: _selectedLessonTypes.contains(type) ? FontWeight.w600 : FontWeight.w500,
                      color: _selectedLessonTypes.contains(type)
                        ? Colors.white
                        : const Color(0xFF64748B),
                    ),
                  ),
                  selected: _selectedLessonTypes.contains(type),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLessonTypes.add(type);
                      } else {
                        _selectedLessonTypes.remove(type);
                      }
                    });
                    _loadRankingData();
                  },
                  selectedColor: const Color(0xFF059669),
                  backgroundColor: const Color(0xFFFAFAFA),
                  side: BorderSide(
                    color: _selectedLessonTypes.contains(type)
                      ? const Color(0xFF059669)
                      : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  checkmarkColor: Colors.white,
                  elevation: _selectedLessonTypes.contains(type) ? 2 : 0,
                  pressElevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
                // 강사 필터
                ..._proIdToName.entries.map((entry) => FilterChip(
                  label: Text(
                    entry.value,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: _selectedProIds.contains(entry.key) ? FontWeight.w600 : FontWeight.w500,
                      color: _selectedProIds.contains(entry.key)
                        ? Colors.white
                        : const Color(0xFF64748B),
                    ),
                  ),
                  selected: _selectedProIds.contains(entry.key),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedProIds.add(entry.key);
                      } else {
                        _selectedProIds.remove(entry.key);
                      }
                    });
                    _loadRankingData();
                  },
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFFFAFAFA),
                  side: BorderSide(
                    color: _selectedProIds.contains(entry.key)
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  checkmarkColor: Colors.white,
                  elevation: _selectedProIds.contains(entry.key) ? 2 : 0,
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
                    _loadRankingData();
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
                        TableDesign.buildHeaderColumn(text: '레슨시간(분)', flex: 2),
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
                                    activeColor: const Color(0xFF10B981),
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
                              // 레슨시간(분) - 클릭 가능
                              Expanded(
                                flex: 2,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _showLessonDetailsDialog(data['member_id'], data['member_name']),
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
                                              ? const Color(0xFF10B981)
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
                                    color: isTop3 ? const Color(0xFF10B981) : const Color(0xFF374151),
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
                      borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                
                // 강사 선택
                const Text(
                  '강사 선택:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                Autocomplete<MapEntry<String, String>>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return _proIdToName.entries;
                    }
                    return _proIdToName.entries.where((entry) {
                      return entry.value.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                             entry.key.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  displayStringForOption: (MapEntry<String, String> option) => option.value,
                  onSelected: (MapEntry<String, String> selection) {
                    setState(() {
                      _selectedProId = selection.key;
                      _selectedProName = selection.value;
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    // 초기값 설정
                    if (_selectedProName != null && controller.text.isEmpty) {
                      controller.text = _selectedProName!;
                    }
                    
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '강사를 선택하거나 입력하세요',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 400,
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: options.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.value,
                                          style: const TextStyle(
                                            color: Color(0xFF1E293B),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '(${option.key})',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
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
                            border: !_isHandicap ? Border.all(color: const Color(0xFF10B981)) : null,
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
                            activeColor: const Color(0xFF10B981),
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
                      borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
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
                        
                        if (_selectedProId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('강사를 선택해주세요.')),
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
                        backgroundColor: const Color(0xFF10B981),
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
  
  // 강사-회원 매칭 검증 로직
  Future<Map<String, dynamic>> _validateInstructorMemberMatch() async {
    final selectedMemberData = _rankingData
        .where((data) => _selectedMembers.contains(data['member_id']))
        .toList();
    
    final selectedMemberIds = selectedMemberData.map((data) => data['member_id']).toList();
    
    try {
      // 선택된 회원들과 선택된 강사 간의 레슨 이력 조회
      final response = await ApiService.getLSData(
        fields: ['member_id', 'member_name'],
        where: [
          {'field': 'member_id', 'operator': 'IN', 'value': selectedMemberIds},
          {'field': 'pro_id', 'operator': '=', 'value': int.tryParse(_selectedProId ?? '') ?? 0},
          {'field': 'LS_status', 'operator': 'IN', 'value': ['예약완료', '결제완료', '레슨완료', '진행중', '확정']},
        ],
      );
      
      final membersWithHistory = <int>{};
      for (var record in response) {
        if (record['member_id'] != null) {
          final memberId = record['member_id'] is int 
              ? record['member_id'] as int
              : int.tryParse(record['member_id'].toString()) ?? 0;
          if (memberId > 0) {
            membersWithHistory.add(memberId);
          }
        }
      }
      
      final membersWithoutHistory = <Map<String, dynamic>>[];
      final membersWithHistoryData = <Map<String, dynamic>>[];
      
      for (var member in selectedMemberData) {
        if (membersWithHistory.contains(member['member_id'])) {
          membersWithHistoryData.add(member);
        } else {
          membersWithoutHistory.add(member);
        }
      }
      
      return {
        'hasIssues': membersWithoutHistory.isNotEmpty,
        'membersWithHistory': membersWithHistoryData,
        'membersWithoutHistory': membersWithoutHistory,
      };
      
    } catch (e) {
      print('강사-회원 매칭 검증 오류: $e');
      // 오류 발생시에도 계속 진행
      return {
        'hasIssues': false,
        'membersWithHistory': selectedMemberData,
        'membersWithoutHistory': <Map<String, dynamic>>[],
      };
    }
  }
  
  Future<void> _saveEventHandicap() async {
    final inputMinutes = int.tryParse(_handicapController.text.trim());
    // 핸디캡은 음수(-), 추가점수는 양수(+)로 처리
    final handicapMinutes = _isHandicap ? -inputMinutes! : inputMinutes!;
    
    // 강사-회원 매칭 검증 실행
    final validationResult = await _validateInstructorMemberMatch();
    
    if (validationResult['hasIssues'] == true) {
      // 검증 이슈가 있으면 확인 팝업 표시
      _showValidationConfirmDialog(validationResult, handicapMinutes);
      return;
    }
    
    // 검증 이슈가 없으면 바로 저장 진행
    await _performSave(handicapMinutes);
  }
  
  Future<void> _performSave(int handicapMinutes) async {
    try {
      setState(() => _isLoading = true);
      
      final selectedMemberData = _rankingData
          .where((data) => _selectedMembers.contains(data['member_id']))
          .toList();
      
      // 각 선정된 회원에 대해 v2_eventhandicap_LS 테이블에 저장
      for (final member in selectedMemberData) {
        final eventData = {
          'LS_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'LS_type': handicapMinutes < 0 ? '이벤트선정 차감' : '이벤트선정 보너스',
          'LS_status': '결제완료',
          'pro_id': int.tryParse(_selectedProId ?? '') ?? 0,
          'pro_name': _selectedProName ?? '',
          'member_id': member['member_id'],
          'member_type': member['member_type'] ?? '',
          'member_name': member['member_name'] ?? '',
          'LS_net_min': handicapMinutes,
          'time_stamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          'memo': _eventContentController.text.trim(),
        };
        
        print('=== 레슨 핸디캡 저장 요청 ===');
        print('요청 데이터: $eventData');

        // v2_eventhandicap_LS 테이블에 저장
        await SupabaseAdapter.addData(
          table: 'v2_eventhandicap_LS',
          data: eventData,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedMemberData.length}명의 이벤트 핸디캡이 등록되었습니다.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        
        setState(() {
          _isSelectionMode = false;
          _selectedMembers.clear();
        });
        
        _eventContentController.clear();
        _handicapController.clear();
        _selectedProId = null;
        _selectedProName = null;
        
        await _loadFilters();
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
  
  void _showValidationConfirmDialog(Map<String, dynamic> validationResult, int handicapMinutes) {
    final membersWithHistory = validationResult['membersWithHistory'] as List<Map<String, dynamic>>;
    final membersWithoutHistory = validationResult['membersWithoutHistory'] as List<Map<String, dynamic>>;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            width: 600,
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
                      '강사-회원 매칭 검증 결과',
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
                
                if (membersWithHistory.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '선택된 강사와 레슨 이력이 있는 회원 (${membersWithHistory.length}명):',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: membersWithHistory.map((member) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${member['member_name']} (${member['member_type']})',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF166534)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                if (membersWithoutHistory.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '선택된 강사와 레슨 이력이 없는 회원 (${membersWithoutHistory.length}명):',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: membersWithoutHistory.map((member) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${member['member_name']} (${member['member_type']})',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF92400E)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      '일부 회원은 선택된 강사와 레슨 이력이 없습니다. 그래도 진행하시겠습니까?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop(); // 검증 다이얼로그 닫기
                        await _performSave(handicapMinutes); // 저장 실행
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('무시하고 진행'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 레슨 상세 내역 팝업
  void _showLessonDetailsDialog(int memberId, String memberName) async {
    try {
      final where = <Map<String, dynamic>>[
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'LS_status', 'operator': 'IN', 'value': ['예약완료', '결제완료', '레슨완료', '진행중', '확정']},
        {'field': 'LS_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
        {'field': 'LS_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
      ];

      // 레슨타입 필터 적용
      if (_selectedLessonTypes.isNotEmpty && _selectedLessonTypes.length < _lessonTypes.length) {
        where.add({
          'field': 'LS_type',
          'operator': 'IN',
          'value': _selectedLessonTypes.toList(),
        });
      }

      // 강사 필터 적용
      if (_selectedProIds.isNotEmpty && _selectedProIds.length < _proIdToName.length) {
        where.add({
          'field': 'pro_id',
          'operator': 'IN',
          'value': _selectedProIds.toList(),
        });
      }

      final response = await ApiService.getLSData(
        fields: ['LS_date', 'LS_type', 'pro_name', 'LS_net_min'],
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
                      '$memberName 레슨 내역',
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
                        DataColumn(label: Text('레슨타입', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('강사', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('시간(분)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: response.map<DataRow>((data) {
                        return DataRow(cells: [
                          DataCell(Text(data['LS_date'] ?? '')),
                          DataCell(Text(data['LS_type'] ?? '')),
                          DataCell(Text(data['pro_name'] ?? '')),
                          DataCell(Text(
                            '${data['LS_net_min'] ?? 0}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: (data['LS_net_min'] ?? 0) >= 0 ? Colors.black : const Color(0xFFDC2626),
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '총 레슨시간: ${response.fold<int>(0, (sum, data) => sum + (data['LS_net_min'] as int? ?? 0))}분',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 내역 조회 실패: $e')),
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
        table: 'v2_eventhandicap_LS',
        fields: ['LS_date', 'LS_type', 'pro_name', 'LS_net_min', 'memo'],
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
                              DataColumn(label: Text('강사', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('조정(분)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('메모', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: handicapData.map<DataRow>((data) {
                              final handicapMin = data['LS_net_min'] as int? ?? 0;
                              return DataRow(cells: [
                                DataCell(Text(data['LS_date'] ?? '')),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: handicapMin < 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    data['LS_type'] ?? '',
                                    style: TextStyle(
                                      color: handicapMin < 0 ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                                      fontSize: 12,
                                    ),
                                  ),
                                )),
                                DataCell(Text(data['pro_name'] ?? '')),
                                DataCell(Text(
                                  '${handicapMin > 0 ? '+' : ''}$handicapMin',
                                  style: TextStyle(
                                    color: handicapMin >= 0 ? const Color(0xFF10B981) : const Color(0xFFDC2626),
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
                  '총 핸디캡: ${handicapData.fold<int>(0, (sum, data) => sum + (data['LS_net_min'] as int? ?? 0))}분',
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
      {'field': 'LS_status', 'operator': 'IN', 'value': ['예약완료', '결제완료', '레슨완료', '진행중', '확정']},
      {'field': 'LS_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(_startDate)},
      {'field': 'LS_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(_endDate)},
    ];

    // 레슨타입 필터 적용 (이벤트선정 차감, 이벤트선정 보너스는 항상 포함)
    if (_selectedLessonTypes.isNotEmpty && _selectedLessonTypes.length < _lessonTypes.length) {
      final lessonTypesWithEvents = Set<String>.from(_selectedLessonTypes)
        ..addAll(['이벤트선정 차감', '이벤트선정 보너스']);
      where.add({
        'field': 'LS_type',
        'operator': 'IN',
        'value': lessonTypesWithEvents.toList(),
      });
    }

    // 강사 필터 적용
    if (_selectedProIds.isNotEmpty && _selectedProIds.length < _proIdToName.length) {
      where.add({
        'field': 'pro_id',
        'operator': 'IN',
        'value': _selectedProIds.toList(),
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