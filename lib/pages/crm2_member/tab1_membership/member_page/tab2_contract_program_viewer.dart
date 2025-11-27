import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 타임라인 세션 데이터 클래스
class TimelineSession {
  String type; // 'lesson' or 'break'
  int duration;
  
  TimelineSession({required this.type, required this.duration});
}

class ProgramViewerDialog extends StatefulWidget {
  final String programId;
  final String programName;

  const ProgramViewerDialog({
    Key? key,
    required this.programId,
    required this.programName,
  }) : super(key: key);

  @override
  State<ProgramViewerDialog> createState() => _ProgramViewerDialogState();
}

class _ProgramViewerDialogState extends State<ProgramViewerDialog> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? programData;

  @override
  void initState() {
    super.initState();
    _loadProgramData();
  }

  // 프로그램 데이터 로드
  Future<void> _loadProgramData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'operation': 'get',
          'table': 'v2_base_option_setting',
          'where': [
            {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
            {'field': 'category', 'operator': '=', 'value': '특수타석예약'},
            {'field': 'table_name', 'operator': '=', 'value': widget.programName},
          ],
          'orderBy': [
            {'field': 'field_name', 'direction': 'ASC'}
          ],
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final data = result['data'] as List;
          final settings = data.cast<Map<String, dynamic>>();
          
          // 프로그램 데이터 분석
          final analyzedData = _analyzeProgramData(settings);
          
          setState(() {
            programData = analyzedData;
            isLoading = false;
          });
        } else {
          throw Exception('프로그램 정보 조회 실패: ${result['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('프로그램 정보 조회 HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 프로그램 데이터 분석
  Map<String, dynamic> _analyzeProgramData(List<Map<String, dynamic>> settings) {
    int tsMin = 0;
    List<Map<String, dynamic>> timelineSessions = [];
    int minPlayerNo = 0;
    int maxPlayerNo = 0;
    String status = '유효';
    
    for (var setting in settings) {
      final fieldName = setting['field_name'] ?? '';
      final optionValue = setting['option_value'] ?? '';
      final settingStatus = setting['setting_status'] ?? '';
      
      if (settingStatus != '유효') {
        status = settingStatus;
      }
      
      switch (fieldName) {
        case 'ts_min':
          tsMin = int.tryParse(optionValue) ?? 0;
          break;
        case 'min_player_no':
          minPlayerNo = int.tryParse(optionValue) ?? 0;
          break;
        case 'max_player_no':
          maxPlayerNo = int.tryParse(optionValue) ?? 0;
          break;
        default:
          // ls_min(1), ls_break_min(2) 형식의 필드명 처리
          RegExp regExp = RegExp(r'^(ls_min|ls_break_min)\((\d+)\)$');
          Match? match = regExp.firstMatch(fieldName);
          if (match != null) {
            String sessionType = match.group(1)!;
            int order = int.tryParse(match.group(2)!) ?? 0;
            int duration = int.tryParse(optionValue) ?? 0;
            
            timelineSessions.add({
              'type': sessionType == 'ls_min' ? 'lesson' : 'break',
              'duration': duration,
              'order': order,
            });
          }
          break;
      }
    }
    
    // 순서대로 정렬
    timelineSessions.sort((a, b) => a['order'].compareTo(b['order']));
    
    // TimelineSession 객체 리스트로 변환
    List<TimelineSession> timeline = timelineSessions.map((session) => 
      TimelineSession(
        type: session['type'],
        duration: session['duration'],
      )
    ).toList();
    
    return {
      'ts_min': tsMin,
      'timeline': timeline,
      'total_lesson_time': timeline.where((s) => s.type == 'lesson').fold<int>(0, (a, b) => a + b.duration),
      'total_break_time': timeline.where((s) => s.type == 'break').fold<int>(0, (a, b) => a + b.duration),
      'lesson_count': timeline.where((s) => s.type == 'lesson').length,
      'min_player_no': minPlayerNo,
      'max_player_no': maxPlayerNo,
      'status': status,
    };
  }

  // 타임라인 미리보기 위젯
  Widget _buildTimelinePreview(List<TimelineSession> timeline) {
    if (timeline.isEmpty) return Container();
    
    int totalDuration = timeline.fold<int>(0, (a, b) => a + b.duration);
    
    return Container(
      height: 40,
      child: Row(
        children: timeline.map((session) {
          double width = (session.duration / totalDuration) * 400; // 최대 400px
          return Container(
            width: width < 40 ? 40 : width, // 최소 너비 40px
            height: 40,
            margin: EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: session.type == 'lesson' ? Color(0xFF3B82F6) : Color(0xFF9CA3AF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${session.duration}분',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 요약 칩 위젯
  Widget _buildSummaryChip(String label, String value, Color color) {
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

  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
                      Icons.schedule,
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
                          '프로그램 상세 정보',
                          style: AppTextStyles.titleH3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.programName,
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
                            color: Color(0xFF6366F1),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '프로그램 정보를 불러오는 중...',
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
                              Container(
                                margin: EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '기본 정보',
                                          style: AppTextStyles.cardBody.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    _buildInfoRow('프로그램 ID', widget.programId),
                                    _buildInfoRow('프로그램시간', '${programData!['ts_min']}분'),
                                    _buildInfoRow('최소인원', '${programData!['min_player_no']}명'),
                                    _buildInfoRow('최대인원', '${programData!['max_player_no']}명'),
                                    _buildInfoRow(
                                      '상태',
                                      programData!['status'],
                                      valueColor: programData!['status'] == '유효'
                                          ? Color(0xFF059669)
                                          : Color(0xFFDC2626),
                                    ),
                                  ],
                                ),
                              ),

                              // 타임라인 미리보기
                              if (programData!['timeline'].isNotEmpty) ...[
                                Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.timeline,
                                            size: 18,
                                            color: Color(0xFF64748B),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '타임라인 미리보기',
                                            style: AppTextStyles.cardBody.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      _buildTimelinePreview(programData!['timeline']),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildSummaryChip('레슨', '${programData!['total_lesson_time']}분', Color(0xFF3B82F6)),
                                          SizedBox(width: 6),
                                          _buildSummaryChip('자체연습', '${programData!['total_break_time']}분', Color(0xFF9CA3AF)),
                                          SizedBox(width: 6),
                                          _buildSummaryChip('총시간', '${programData!['ts_min']}분', Color(0xFF6366F1)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
}