import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/api_service.dart';
import '/services/supabase_adapter.dart';

// 타임라인 세션 데이터 클래스
class TimelineSession {
  String type; // 'lesson' or 'break'
  int duration;
  
  TimelineSession({required this.type, required this.duration});
}

class ContractProgramDialog extends StatefulWidget {
  final Map<String, dynamic>? existingProgram;
  final String? contractId;
  final String? contractName;
  final bool isNewContract; // 신규 회원권인지 여부
  final Function(Map<String, dynamic>) onProgramSaved;
  
  const ContractProgramDialog({
    super.key,
    this.existingProgram,
    this.contractId,
    this.contractName,
    this.isNewContract = false,
    required this.onProgramSaved,
  });
  
  @override
  State<ContractProgramDialog> createState() => _ContractProgramDialogState();
}

class _ContractProgramDialogState extends State<ContractProgramDialog> {
  final TextEditingController programNameController = TextEditingController();
  final TextEditingController tsMinController = TextEditingController(text: '60');
  final TextEditingController minPlayerController = TextEditingController(text: '1');
  final TextEditingController maxPlayerController = TextEditingController(text: '4');
  final TextEditingController sessionCountController = TextEditingController(text: '10'); // 이용 횟수
  
  // 타임라인 세션 구성
  List<TimelineSession> timeline = [
    TimelineSession(type: 'lesson', duration: 15),
    TimelineSession(type: 'break', duration: 5),
  ];
  
  String newProgramId = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  Future<void> _initializeData() async {
    if (widget.existingProgram != null) {
      // 기존 프로그램 수정 모드
      _loadExistingProgram();
    } else {
      // 신규 프로그램 등록 모드
      newProgramId = await _generateNewProgramId();
    }
  }
  
  void _loadExistingProgram() {
    final program = widget.existingProgram!;
    programNameController.text = program['program_name'] ?? '';
    tsMinController.text = program['ts_min']?.toString() ?? '60';
    minPlayerController.text = program['min_player_no']?.toString() ?? '1';
    maxPlayerController.text = program['max_player_no']?.toString() ?? '4';
    sessionCountController.text = program['session_count']?.toString() ?? '10';
    
    // 타임라인 데이터 로드
    if (program['timeline_sessions'] != null) {
      final sessions = program['timeline_sessions'] as List;
      timeline = sessions.map((s) => TimelineSession(
        type: s['type'],
        duration: s['duration'],
      )).toList();
    }
  }
  
  // 새로운 program_id 생성
  Future<String> _generateNewProgramId() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) {
        throw Exception('지점 정보가 없습니다.');
      }

      final data = await SupabaseAdapter.getData(
        table: 'v2_base_option_setting',
        fields: ['option_value'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
          {'field': 'field_name', 'operator': '=', 'value': 'program_id'},
        ],
      );

      final existingIds = data.map((item) => item['option_value'].toString()).toList();

      // 기존 ID에서 숫자 부분 추출하여 최대값 찾기
      int maxNumber = 0;
      for (String id in existingIds) {
        if (id.startsWith('${branchId}_')) {
          final numberPart = id.substring('${branchId}_'.length);
          final number = int.tryParse(numberPart) ?? 0;
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }

      // 다음 번호로 새 ID 생성
      return '${branchId}_${(maxNumber + 1).toString().padLeft(3, '0')}';
      
      // 첫 번째 프로그램인 경우
      return '${branchId}_001';
    } catch (e) {
      print('❌ program_id 생성 오류: $e');
      final branchId = ApiService.getCurrentBranchId() ?? 'unknown';
      return '${branchId}_001';
    }
  }
  
  void _showErrorSnackBar(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.error, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 8),
              Text(
                '오류',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '확인',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  Future<void> _saveProgram() async {
    if (programNameController.text.trim().isEmpty) {
      _showErrorSnackBar('프로그램명을 입력해주세요.');
      return;
    }
    
    // 총시간과 프로그램 시간이 일치하는지 검증
    int totalSessionTime = timeline.fold<int>(0, (a, b) => a + b.duration);
    int programTime = int.tryParse(tsMinController.text) ?? 0;
    
    if (totalSessionTime != programTime) {
      _showErrorSnackBar('세션 총시간(${totalSessionTime}분)과 프로그램 시간(${programTime}분)이 일치하지 않습니다.');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final int sessionCount = int.tryParse(sessionCountController.text) ?? 10;
      final int totalTsMin = (int.tryParse(tsMinController.text) ?? 60);
      final int totalLessonMin = timeline.where((s) => s.type == 'lesson').fold<int>(0, (a, b) => a + b.duration);
      
      final programData = {
        'program_id': widget.existingProgram?['program_id'] ?? newProgramId,
        'program_name': programNameController.text.trim(),
        'ts_min': totalTsMin,
        'min_player_no': int.tryParse(minPlayerController.text) ?? 1,
        'max_player_no': int.tryParse(maxPlayerController.text) ?? 4,
        'session_count': sessionCount,
        'timeline_sessions': timeline.map((s) => {
          'type': s.type,
          'duration': s.duration,
        }).toList(),
        'contract_id': widget.contractId,
        'is_temporary': widget.existingProgram == null, // 신규 프로그램인 경우 임시 저장
        // 제공 서비스 계산값
        'calculated_ls_min': totalLessonMin * sessionCount, // 레슨권 = 레슨시간 × 횟수
        'calculated_ts_min': totalTsMin * sessionCount,     // 타석시간 = 총시간 × 횟수
      };
      
      // 부모 위젯에 데이터 전달
      print('📤 ContractProgramDialog에서 onProgramSaved 호출: $programData');
      widget.onProgramSaved(programData);
      Navigator.of(context).pop();
      
      // DB 저장은 회원권 저장/수정 시에만 수행
      // 모든 프로그램 등록은 임시 데이터로 처리
      
    } catch (e) {
      print('❌ 프로그램 저장 오류: $e');
      _showErrorSnackBar('프로그램 저장에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveProgramToDatabase(Map<String, dynamic> programData) async {
    final branchId = ApiService.getCurrentBranchId();
    final programName = programData['program_name'];
    final programId = programData['program_id'];
    
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
    }
    
    _showSuccessSnackBar('프로그램이 등록되었습니다.');
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingProgram != null;
    
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        isEdit ? '프로그램 수정' : '신규 프로그램 등록',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
      content: Container(
        width: 800,
        height: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로그램명
              _buildCompactTextField('프로그램명', programNameController, ''),
              
              SizedBox(height: 16),
              
              // 기본 정보 첫 번째 줄
              Row(
                children: [
                  Expanded(
                    child: _buildCompactTextField('프로그램 시간', tsMinController, '분'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactTextField('이용 횟수', sessionCountController, '회'),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // 기본 정보 두 번째 줄
              Row(
                children: [
                  Expanded(
                    child: _buildCompactTextField('최소인원', minPlayerController, '명'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactTextField('최대인원', maxPlayerController, '명'),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // 연결된 회원권 정보 (읽기 전용)
              if (widget.contractName != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFFFD700)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_membership, 
                           color: Color(0xFFD97706), size: 18),
                      SizedBox(width: 8),
                      Text(
                        '연결된 회원권: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        widget.contractName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              
              SizedBox(height: 16),
              
              // 계산된 제공 서비스 정보
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF0EA5E9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '제공 서비스 계산 (자동 적용)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C4A6E),
                      ),
                    ),
                    SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setCalculationState) {
                        // 입력값 변경 시 계산값 업데이트를 위한 리스너 설정
                        tsMinController.addListener(() => setCalculationState(() {}));
                        sessionCountController.addListener(() => setCalculationState(() {}));
                        
                        return Row(
                          children: [
                            Expanded(
                              child: _buildServiceCalculation(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // 타임라인 미리보기
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '타임라인 미리보기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildTimelinePreview(timeline),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCompactSummaryChip('레슨', '${timeline.where((s) => s.type == 'lesson').fold<int>(0, (a, b) => a + b.duration)}분', Color(0xFF3B82F6)),
                        SizedBox(width: 6),
                        _buildCompactSummaryChip('자체연습', '${timeline.where((s) => s.type == 'break').fold<int>(0, (a, b) => a + b.duration)}분', Color(0xFF9CA3AF)),
                        SizedBox(width: 6),
                        _buildCompactSummaryChip('총시간', '${timeline.fold<int>(0, (a, b) => a + b.duration)}분', Color(0xFF6366F1)),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // 세션 편집 리스트
              Container(
                height: 200,
                child: ReorderableListView(
                  shrinkWrap: true,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = timeline.removeAt(oldIndex);
                      timeline.insert(newIndex, item);
                    });
                  },
                  children: timeline.asMap().entries.map((entry) {
                    final index = entry.key;
                    final session = entry.value;
                    return _buildDraggableTimelineSessionCard(
                      index, 
                      session, 
                      timeline,
                      int.tryParse(tsMinController.text) ?? 0,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProgram,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isEdit ? '수정' : '등록'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  // UI Helper 위젯들
  Widget _buildCompactTextField(String label, TextEditingController controller, String suffix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: suffix.isNotEmpty ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            isDense: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimelinePreview(List<TimelineSession> timeline) {
    if (timeline.isEmpty) return Container();
    
    int totalDuration = timeline.fold<int>(0, (a, b) => a + b.duration);
    
    return Container(
      height: 44, // 높이 증가
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 전체 사용 가능한 폭에서 마진 제외
          final availableWidth = constraints.maxWidth - (timeline.length - 1) * 2; // 마진 2px씩
          
          return Row(
            children: timeline.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              final isLast = index == timeline.length - 1;
              
              // 상대적 비율로 전체 폭 활용 (절대적 시간이 아닌 비율)
              final width = (session.duration / totalDuration) * availableWidth;
              
              return Container(
                width: width,
                height: 44,
                margin: EdgeInsets.only(right: isLast ? 0 : 2),
                decoration: BoxDecoration(
                  color: session.type == 'lesson' ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      width < 50 ? '${session.duration}' : '${session.duration}분',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13, // 폰트 크기 증가
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
    );
  }
  
  Widget _buildCompactSummaryChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildDraggableTimelineSessionCard(int index, TimelineSession session, List<TimelineSession> timeline, int maxTsMin) {
    final TextEditingController durationController = TextEditingController(text: session.duration.toString());
    
    return Container(
      key: ValueKey('session_$index'),
      margin: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: session.type == 'lesson' ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 세션 타입 아이콘
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: session.type == 'lesson' ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                session.type == 'lesson' ? Icons.school : Icons.self_improvement,
                color: Colors.white,
                size: 18,
              ),
            ),
            
            SizedBox(width: 16),
            
            // 세션 타입 텍스트
            Container(
              width: 70,
              child: Text(
                session.type == 'lesson' ? '레슨' : '자체연습',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            
            SizedBox(width: 20),
            
            // 세션 추가 버튼들
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _addSessionAfter(index, 'lesson', timeline, maxTsMin),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Color(0xFF3B82F6).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '레슨추가',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                InkWell(
                  onTap: () => _addSessionAfter(index, 'break', timeline, maxTsMin),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF9CA3AF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Color(0xFF9CA3AF).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '연습추가',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            Spacer(),
            
            // 시간 컨트롤러
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 시간 감소 버튼
                InkWell(
                  onTap: () {
                    if (session.duration > 5) {
                      setState(() {
                        session.duration -= 5;
                        durationController.text = session.duration.toString();
                      });
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.remove,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // 시간 표시
                Container(
                  width: 80,
                  height: 32,
                  child: TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      height: 1.2,
                    ),
                    decoration: InputDecoration(
                      suffixText: '분',
                      suffixStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Color(0xFF6366F1)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      int newDuration = int.tryParse(value) ?? 0;
                      int currentTotal = timeline.fold<int>(0, (a, b) => a + b.duration);
                      int otherSessionsTotal = currentTotal - session.duration;
                      
                      if (otherSessionsTotal + newDuration <= maxTsMin) {
                        setState(() {
                          session.duration = newDuration;
                        });
                      } else {
                        int maxAllowed = maxTsMin - otherSessionsTotal;
                        if (maxAllowed > 0) {
                          setState(() {
                            session.duration = maxAllowed;
                            durationController.text = maxAllowed.toString();
                          });
                        }
                        _showErrorSnackBar('총 세션 시간이 프로그램 시간을 초과할 수 없습니다.');
                      }
                    },
                  ),
                ),
                
                SizedBox(width: 8),
                
                // 시간 증가 버튼
                InkWell(
                  onTap: () {
                    int currentTotal = timeline.fold<int>(0, (a, b) => a + b.duration);
                    int otherSessionsTotal = currentTotal - session.duration;
                    int newDuration = session.duration + 5;
                    
                    if (otherSessionsTotal + newDuration <= maxTsMin) {
                      setState(() {
                        session.duration = newDuration;
                        durationController.text = newDuration.toString();
                      });
                    } else {
                      _showErrorSnackBar('총 세션 시간이 프로그램 시간을 초과할 수 없습니다.');
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(width: 24),
            
            // 삭제 버튼
            InkWell(
              onTap: timeline.length > 1 ? () {
                setState(() {
                  timeline.removeAt(index);
                });
              } : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: timeline.length > 1 
                    ? Color(0xFFEF4444).withOpacity(0.1)
                    : Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: timeline.length > 1 ? Color(0xFFEF4444) : Color(0xFF9CA3AF),
                  size: 18,
                ),
              ),
            ),
            
            SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
  
  // 특정 위치 이후에 세션 추가
  void _addSessionAfter(int afterIndex, String sessionType, List<TimelineSession> timeline, int maxTsMin) {
    int currentTotal = timeline.fold<int>(0, (a, b) => a + b.duration);
    int defaultDuration = sessionType == 'lesson' ? 15 : 5;
    
    if (currentTotal + defaultDuration <= maxTsMin) {
      setState(() {
        timeline.insert(afterIndex + 1, TimelineSession(type: sessionType, duration: defaultDuration));
      });
    } else {
      int remainingTime = maxTsMin - currentTotal;
      if (remainingTime > 0) {
        setState(() {
          timeline.insert(afterIndex + 1, TimelineSession(type: sessionType, duration: remainingTime));
        });
      } else {
        _showErrorSnackBar('총 세션 시간이 프로그램 시간을 초과할 수 없습니다.');
      }
    }
  }
  
  // 제공 서비스 계산 위젯
  Widget _buildServiceCalculation() {
    final int sessionCount = int.tryParse(sessionCountController.text) ?? 10;
    final int totalTsMin = int.tryParse(tsMinController.text) ?? 60;
    final int totalLessonMin = timeline.where((s) => s.type == 'lesson').fold<int>(0, (a, b) => a + b.duration);
    
    final int calculatedLsMin = totalLessonMin * sessionCount;
    final int calculatedTsMin = totalTsMin * sessionCount;
    
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.school, color: Color(0xFF3B82F6), size: 16),
            SizedBox(width: 6),
            Text(
              '레슨권: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              '${totalLessonMin}분 × ${sessionCount}회 = ${calculatedLsMin}분',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.golf_course, color: Color(0xFF059669), size: 16),
            SizedBox(width: 6),
            Text(
              '타석시간: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              '${totalTsMin}분 × ${sessionCount}회 = ${calculatedTsMin}분',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ],
        ),
      ],
    );
  }
}