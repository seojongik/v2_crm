import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../../services/routine_analysis_service.dart';

class RoutineJuniorScreen extends StatefulWidget {
  final int? memberId;

  const RoutineJuniorScreen({Key? key, this.memberId}) : super(key: key);

  @override
  State<RoutineJuniorScreen> createState() => _RoutineJuniorScreenState();
}

class _RoutineJuniorScreenState extends State<RoutineJuniorScreen> {
  // 주니어 회원 ID (실제 예약에 사용될 ID)
  int? _juniorMemberId;
  String? _juniorName;
  bool _isLoadingJuniorInfo = true;
  String? _juniorLoadError;
  
  // 단계 관리를 위한 인덱스
  int _currentStep = 0;
  
  // 선택한 값들을 저장하는 변수
  String? _selectedReservationType; // 예약 종류
  int? _selectedFrequency; // 예약 횟수
  Map<int, Map<String, dynamic>> _selectedTimes = {}; // 요일별 시작/종료 시간 (lessons 배열 추가)
  List<int> _teePreferenceOrder = [7, 8, 9]; // 단독타석 우선순위
  Set<int> _excludedTees = {1, 2, 3, 4, 5, 6}; // 오픈타석 제외
  
  // 예약 분석 결과 저장 변수들
  Map<String, dynamic>? _analysisResult;
  bool _isAnalyzing = false;
  String? _analysisError;
  List<Map<String, dynamic>> _selectedReservations = []; // 사용자가 선택한 예약들
  
  // 프로 선택 관련 변수들
  String? _selectedPro; // 선택된 프로
  List<Map<String, dynamic>> _availablePros = []; // 사용 가능한 프로 목록
  bool _isLoadingPros = false;
  Map<String, dynamic>? _lessonBalance; // 레슨 잔여시간 정보
  Map<String, Map<String, dynamic>> _proWeeklySchedule = {}; // 프로의 주간 스케줄 정보
  
  // 예약 종류 옵션 (주니어는 타석+레슨만)
  final List<Map<String, dynamic>> _reservationTypes = [
    {'id': 'tee_lesson', 'title': '타석 + 레슨 예약', 'icon': Icons.sports_golf},
  ];
  
  // 예약 횟수 옵션 (수정됨)
  final List<Map<String, dynamic>> _frequencyOptions = [
    {'count': 4, 'description': '4회'},
    {'count': 7, 'description': '7회'},
    {'count': 10, 'description': '10회'},
  ];
  
  // 타석 정보
  final List<Map<String, dynamic>> _teeInfo = [
    {'number': 1, 'type': '오픈타석', 'color': Colors.blue},
    {'number': 2, 'type': '오픈타석', 'color': Colors.blue},
    {'number': 3, 'type': '오픈타석', 'color': Colors.blue},
    {'number': 4, 'type': '오픈타석', 'color': Colors.blue},
    {'number': 5, 'type': '오픈타석', 'color': Colors.blue},
    {'number': 6, 'type': '오픈타석', 'color': Colors.blue},
    {'number': 7, 'type': '단독타석', 'color': Colors.green},
    {'number': 8, 'type': '단독타석', 'color': Colors.green},
    {'number': 9, 'type': '단독타석', 'color': Colors.green},
  ];
  
  // 요일 옵션
  final List<Map<String, dynamic>> _weekdays = [
    {'id': 0, 'name': '일', 'fullName': '매주 일요일'},
    {'id': 1, 'name': '월', 'fullName': '매주 월요일'},
    {'id': 2, 'name': '화', 'fullName': '매주 화요일'},
    {'id': 3, 'name': '수', 'fullName': '매주 수요일'},
    {'id': 4, 'name': '목', 'fullName': '매주 목요일'},
    {'id': 5, 'name': '금', 'fullName': '매주 금요일'},
    {'id': 6, 'name': '토', 'fullName': '매주 토요일'},
  ];

  // 잔액 정보 변수
  int? _billBalanceAfter; // v2_bills 테이블에서 가져온 bill_balance_after 값

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🚀 [디버깅] RoutineJuniorScreen 초기화 시작');
      print('🚀 [디버깅] 디버그 모드 활성화됨');
    }
    _debugMemberId();
    
    // 주니어 골프스쿨용 고정 타석 설정 (단독타석만 사용)
    _teePreferenceOrder = [7, 8, 9]; // 단독타석 우선순위
    _excludedTees = {1, 2, 3, 4, 5, 6}; // 오픈타석 제외
    
    _loadJuniorMemberInfo(); // 주니어 회원 정보 로드
  }

  // 디버깅을 위해 memberId를 콘솔에 출력
  void _debugMemberId() {
    if (kDebugMode) {
      print('🔍 [디버깅] ===== 회원 ID 정보 =====');
      print('🔍 [디버깅] RoutineJuniorScreen - 부모 memberId: ${widget.memberId}');
      
      // Provider에서 회원 ID 직접 가져와서 비교 출력
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final String? userIdStr = userProvider.user?.id;
      final int? providerMemberId = userIdStr != null ? int.tryParse(userIdStr) : null;
      
      print('🔍 [디버깅] Provider에서 가져온 부모 memberId: $providerMemberId (원본: $userIdStr)');
      print('🔍 [디버깅] ========================');
    }
  }

  // 주니어 회원 정보 로드
  Future<void> _loadJuniorMemberInfo() async {
    if (widget.memberId == null) {
      setState(() {
        _juniorLoadError = '부모 회원 ID가 없습니다.';
        _isLoadingJuniorInfo = false;
      });
      return;
    }

    try {
      if (kDebugMode) {
        print('🔍 [주니어 정보] v2_junior_relation 테이블에서 주니어 정보 조회 시작');
        print('🔍 [주니어 정보] 부모 member_id: ${widget.memberId}');
      }

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "get",
          "table": "v2_junior_relation",
          "fields": ["junior_member_id", "junior_name"],
          "where": [
            {
              "field": "member_id",
              "operator": "=",
              "value": widget.memberId.toString()
            },
            if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
            {
              "field": "branch_id",
              "operator": "=",
              "value": Provider.of<UserProvider>(context, listen: false).currentBranchId!
            }
          ],
          "limit": 1
        }),
      );

      if (kDebugMode) {
        print('🔍 [주니어 정보] API 응답 상태: ${response.statusCode}');
        print('🔍 [주니어 정보] API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          final juniorData = result['data'][0];
          
          setState(() {
            _juniorMemberId = int.tryParse(juniorData['junior_member_id'].toString());
            _juniorName = juniorData['junior_name'];
            _isLoadingJuniorInfo = false;
          });
          
          if (kDebugMode) {
            print('✅ [주니어 정보] 주니어 정보 로드 성공');
            print('✅ [주니어 정보] 주니어 member_id: $_juniorMemberId');
            print('✅ [주니어 정보] 주니어 이름: $_juniorName');
          }
          
          // 주니어 정보 로드 성공 후 프로 목록 자동 로드
          await _loadAvailablePros();
        } else {
          setState(() {
            _juniorLoadError = '연결된 주니어 회원이 없습니다.';
            _isLoadingJuniorInfo = false;
          });
          
          if (kDebugMode) {
            print('⚠️ [주니어 정보] 주니어 회원 없음');
          }
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _juniorLoadError = '주니어 정보 로드 실패: $e';
        _isLoadingJuniorInfo = false;
      });
      
      if (kDebugMode) {
        print('❌ [주니어 정보] 로드 오류: $e');
      }
    }
  }
  
  // 디버깅 함수 - 현재 선택 사항 출력
  void _debugCurrentSelections() {
    if (kDebugMode) {
      // 타석 예약 정보 출력
      print('\n===== [디버깅] 타석 예약 선택 내역 =====');
      print('🔍 부모 memberId: ${widget.memberId}');
      print('🔍 주니어 memberId: $_juniorMemberId');
      print('🔍 주니어 이름: $_juniorName');
      print('🔍 테이블: v2_priced_TS');
      print('🔍 타석 예약 횟수: ${_selectedFrequency != null ? '$_selectedFrequency회' : '선택되지 않음'}');
      
      // 타석 우선순위 정보 출력
      List<int> preferredTees = _teePreferenceOrder.where((tee) => !_excludedTees.contains(tee)).toList();
      if (preferredTees.isNotEmpty) {
        print('🔍 타석 우선순위: ${preferredTees.join(',')}');
      } else {
        print('🔍 타석 우선순위: 모든 타석이 제외됨');
      }
      
      // 제외된 타석 정보 출력
      if (_excludedTees.isNotEmpty) {
        print('🔍 제외된 타석: ${_excludedTees.join(',')}');
      } else {
        print('🔍 제외된 타석: 없음');
      }
      
      if (_selectedTimes.isNotEmpty) {
        print('🔍 선택한 요일/시간:');
        _selectedTimes.forEach((dayId, times) {
          final dayName = _weekdays.firstWhere((day) => day['id'] == dayId)['fullName'];
          final startTime = times['start'] as TimeOfDay;
          final endTime = times['end'] as TimeOfDay;
          
          final timeRange = '${_formatTimeOfDay(startTime)} ~ ${_formatTimeOfDay(endTime)}';
          print('  - $dayName: $timeRange');
        });
      } else {
        print('🔍 선택한 요일/시간: 없음');
      }
      print('=============================');
      
      // 레슨 예약이 있는 경우만 출력
      if (_selectedReservationType == 'tee_lesson') {
        print('\n===== [디버깅] 레슨 예약 선택 내역 =====');
        print('🔍 주니어 memberId: $_juniorMemberId');
        print('🔍 테이블: v2_LS_orders, v3_LS_countings');
        print('🔍 레슨 예약 횟수: ${_selectedFrequency != null ? '$_selectedFrequency회' : '선택되지 않음'}');
        
        if (_selectedTimes.isNotEmpty) {
          print('🔍 선택한 요일/시간:');
          _selectedTimes.forEach((dayId, times) {
            final dayName = _weekdays.firstWhere((day) => day['id'] == dayId)['fullName'];
            
            List<Map<String, TimeOfDay>> lessons = List.from(times['lessons'] ?? []);
            if (lessons.isNotEmpty) {
              for (int i = 0; i < lessons.length; i++) {
                final lessonStart = lessons[i]['start']!;
                final lessonEnd = lessons[i]['end']!;
                
                final timeRange = '${_formatTimeOfDay(lessonStart)} ~ ${_formatTimeOfDay(lessonEnd)}';
                print('  - $dayName 레슨${i + 1}: $timeRange');
              }
            }
          });
        } else {
          print('🔍 선택한 요일/시간: 없음');
        }
        print('=============================');
      }
      
      print(''); // 빈 줄 추가
    }
  }

  // TimeOfDay를 문자열로 변환
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // 다음 단계로 이동
  void _nextStep() async {
    if (_currentStep == 0 && (_selectedPro == null || _selectedFrequency == null)) {
      _showSelectionRequiredDialog('담당 프로와 예약 횟수를 모두 선택해주세요');
      return;
    }
    
    // 0단계에서 1단계로 넘어갈 때 프로의 주간 스케줄 정보 로드
    if (_currentStep == 0) {
      if (kDebugMode) {
        print('📅 [단계 이동] 0단계 → 1단계: 프로 주간 스케줄 로드 시작');
      }
      
      // 프로의 주간 스케줄 정보 로드
      final weeklySchedule = await _loadProWeeklySchedule();
      
      setState(() {
        _proWeeklySchedule = weeklySchedule;
      });
      
      if (kDebugMode) {
        print('📅 [단계 이동] 프로 주간 스케줄 로드 완료: ${weeklySchedule.length}개 요일');
      }
    }
    
    if (_currentStep == 1 && _selectedTimes.isEmpty) {
      _showSelectionRequiredDialog('요일과 시간을 선택해주세요');
      return;
    }
    
    // 1단계에서 2단계로 넘어갈 때 예약 분석 API 호출
    if (_currentStep == 1) {
      await _analyzeReservations();
      if (_analysisError != null) {
        return; // 오류가 있으면 다음 단계로 넘어가지 않음
      }
    }
    
    // 2단계에서 결제하기 버튼 클릭 시 (내역확인에서 결제하기)
    if (_currentStep == 2) {
      if (_selectedReservations.isEmpty) {
        _showSelectionRequiredDialog('예약할 날짜를 선택해주세요');
        return;
      }
    }
    
    // 3단계에서 결제완료 버튼 클릭 시 (결제에서 결제완료)
    if (_currentStep == 3) {
      await _completePayment();
      return; // 결제 완료 후에는 다음 단계로 이동하지 않음
    }
    
    setState(() {
      _currentStep++;
    });
    
    // 디버깅 - 현재 선택 사항 출력
    _debugCurrentSelections();
  }
  
  // 이전 단계로 이동
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }
  
  // 선택 필요 다이얼로그 표시
  void _showSelectionRequiredDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('선택 필요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  // 예약 분석 API 호출
  Future<void> _analyzeReservations() async {
    if (_selectedTimes.isEmpty) {
      _showSelectionRequiredDialog('요일과 시간을 선택해주세요');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
      _analysisResult = null;
    });

    try {
      final params = _buildAnalysisParams();
      final result = await _sendAnalysisRequest(params);
      
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
        _selectedReservations.clear(); // 기존 선택 초기화
      });
    } catch (e) {
      setState(() {
        _analysisError = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  // 분석 요청 파라미터 생성
  Map<String, dynamic> _buildAnalysisParams() {
    final now = DateTime.now();
    final baseDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    // 선호 타석 리스트 (제외된 타석 제외)
    final preferredTees = _teePreferenceOrder.where((tee) => !_excludedTees.contains(tee)).toList();
    final nonPreferredTees = _teePreferenceOrder.where((tee) => _excludedTees.contains(tee)).toList();
    
    // 요일별 시간 정보를 API 형식으로 변환
    final targetWeekdays = <List<String>>[];
    final targetLessonWeekdays = <List<String>>[];
    
    _selectedTimes.forEach((dayId, times) {
      final weekdayName = _getWeekdayName(dayId);
      final startTime = _formatTimeOfDay(times['start']);
      final endTime = _formatTimeOfDay(times['end']);
      
      // 타석 시간 추가
      targetWeekdays.add([weekdayName, startTime, endTime]);
      
      // 레슨 시간 추가 (레슨 예약인 경우)
      if (_selectedReservationType == 'tee_lesson') {
        List<Map<String, TimeOfDay>> lessons = List.from(times['lessons'] ?? []);
        
        // 각 레슨 시간을 개별적으로 추가
        for (var lesson in lessons) {
          final lessonStartTime = _formatTimeOfDay(lesson['start']!);
          final lessonEndTime = _formatTimeOfDay(lesson['end']!);
          targetLessonWeekdays.add([weekdayName, lessonStartTime, lessonEndTime]);
        }
      }
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final params = {
      "base_date": baseDate,
      "member_id": _safeToInt(_juniorMemberId), // 주니어 member_id 사용
      "selected_dates": _selectedFrequency ?? 5,
      "search_dates": (_selectedFrequency ?? 5) + 3,
      "preferred_ts_ids": preferredTees,
      "non_preferred_ts_ids": nonPreferredTees,
      "target_weekdays": targetWeekdays,
      "target_lesson_weekdays": targetLessonWeekdays,
      "branch_id": userProvider.currentBranchId, // branch_id 추가
    };

    // 레슨 예약인 경우 선택된 프로 정보 추가
    if (_selectedReservationType == 'tee_lesson' && _selectedPro != null) {
      params["ls_contract_pro"] = _selectedPro!;
    }

    return params;
  }

  // 요일 ID를 한글 요일명으로 변환
  String _getWeekdayName(int dayId) {
    const weekdayNames = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
    return weekdayNames[dayId];
  }

  // 레슨 시간 계산 (분 단위)
  int _calculateLessonDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return 0;
    
    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      
      return endMinutes - startMinutes;
    } catch (e) {
      return 0;
    }
  }

  // API 요청 전송
  Future<Map<String, dynamic>> _sendAnalysisRequest(Map<String, dynamic> params) async {
    if (kDebugMode) {
      print('🔍 [루틴 분석] 요청 시작');
      print('📋 [루틴 분석] 파라미터: ${jsonEncode(params)}');
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      // 새로운 RoutineAnalysisService 사용
      final result = await RoutineAnalysisService.analyzeReservation(params);

      if (result['success'] == true) {
        setState(() {
          _analysisResult = result['data'];
          _isAnalyzing = false;
        });

        if (kDebugMode) {
          print('✅ [루틴 분석] 분석 완료');
          print('📊 [루틴 분석] 결과: ${jsonEncode(result['data'])}');
        }
        
        return result;
      } else {
        throw Exception(result['error'] ?? '분석 실패');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [루틴 분석] 오류: $e');
      }
      
      setState(() {
        _isAnalyzing = false;
        _analysisResult = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('분석 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  // 프로 목록 조회
  Future<void> _loadAvailablePros() async {
    if (_isLoadingPros) return;
    
    setState(() {
      _isLoadingPros = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "get",
          "table": "v2_LS_contracts",
          "fields": ["LS_contract_pro", "LS_expiry_date"],
          "where": [
            {
              "field": "member_id",
              "operator": "=",
              "value": _juniorMemberId.toString() // 주니어 member_id 사용
            },
            {
              "field": "LS_expiry_date",
              "operator": ">",
              "value": DateTime.now().toIso8601String().split('T')[0]
            },
            if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
            {
              "field": "branch_id",
              "operator": "=",
              "value": Provider.of<UserProvider>(context, listen: false).currentBranchId!
            }
          ],
          "limit": 100
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true) {
          final data = result['data'] as List<dynamic>;
          
          // 중복 제거하여 프로 목록 생성
          final Set<String> uniquePros = {};
          for (var contract in data) {
            uniquePros.add(contract['LS_contract_pro']);
          }
          
          setState(() {
            _availablePros = uniquePros.map((pro) => {
              'name': pro,
              'display_name': pro,
            }).toList();
            _isLoadingPros = false;
          });
          
          if (kDebugMode) {
            print('📚 사용 가능한 프로 목록: ${_availablePros.length}명');
            for (var pro in _availablePros) {
              print('  - ${pro['name']}');
            }
          }
        } else {
          throw Exception(result['error'] ?? '프로 목록 조회 실패');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoadingPros = false;
      });
      
      if (kDebugMode) {
        print('❌ 프로 목록 조회 오류: $e');
      }
      
      // 오류 발생 시 빈 프로 목록 설정
      setState(() {
        _availablePros = [];
      });
    }
  }

  // 레슨 잔여시간 조회
  Future<void> _loadLessonBalance() async {
    if (_selectedPro == null) return;

    try {
      // 직접 LS_countings 테이블에서 조회
      // member_id가 일치하고, LS_type이 '주니어레슨'이고, LS_contract_pro가 선택된 프로인 것들 중에서
      // 가장 큰 LS_counting_id의 LS_balance_min_after를 조회
      final balanceResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "get",
          "table": "v3_LS_countings",
          "fields": ["LS_counting_id", "LS_balance_min_after", "LS_contract_id"],
          "where": [
            {
              "field": "member_id",
              "operator": "=",
              "value": _juniorMemberId.toString() // 주니어 member_id 사용
            },
            {
              "field": "LS_type",
              "operator": "=",
              "value": "주니어레슨" // 일반레슨 -> 주니어레슨으로 변경
            },
            {
              "field": "LS_contract_pro",
              "operator": "=",
              "value": _selectedPro
            },
            if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
            {
              "field": "branch_id",
              "operator": "=",
              "value": Provider.of<UserProvider>(context, listen: false).currentBranchId!
            }
          ],
          "orderBy": [
            {
              "field": "LS_counting_id",
              "direction": "DESC"
            }
          ],
          "limit": 1
        }),
      );

      if (balanceResponse.statusCode == 200) {
        final balanceResult = jsonDecode(utf8.decode(balanceResponse.bodyBytes));
        
        if (balanceResult['success'] == true && balanceResult['data'].isNotEmpty) {
          final data = balanceResult['data'][0];
          final balanceMinutes = int.tryParse(data['LS_balance_min_after'].toString()) ?? 0;
          final countingId = data['LS_counting_id'];
          final contractId = data['LS_contract_id'];
          
          setState(() {
            _lessonBalance = {
              'contract_id': contractId,
              'balance_minutes': balanceMinutes,
              'balance_hours': (balanceMinutes / 60).floor(),
              'remaining_minutes': balanceMinutes % 60,
            };
          });
          
          if (kDebugMode) {
            print('📚 레슨 잔여시간: ${balanceMinutes}분 (${_lessonBalance!['balance_hours']}시간 ${_lessonBalance!['remaining_minutes']}분)');
            print('📚 조회 기준: member_id=$_juniorMemberId, LS_type=주니어레슨, LS_contract_pro=$_selectedPro');
            print('📚 최신 기록: LS_counting_id=$countingId, LS_contract_id=$contractId');
          }
        } else {
          setState(() {
            _lessonBalance = {
              'contract_id': null,
              'balance_minutes': 0,
              'balance_hours': 0,
              'remaining_minutes': 0,
            };
          });
          
          if (kDebugMode) {
            print('📚 레슨 잔여시간: 0분 (해당 프로의 주니어레슨 기록 없음)');
            print('📚 조회 기준: member_id=$_juniorMemberId, LS_type=주니어레슨, LS_contract_pro=$_selectedPro');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 레슨 잔여시간 조회 오류: $e');
      }
    }
  }

  // 선택된 프로의 주간 스케줄 정보 조회
  Future<Map<String, Map<String, dynamic>>> _loadProWeeklySchedule() async {
    if (_selectedPro == null) return {};

    try {
      // 먼저 v2_staff_pro 테이블에서 staff_nickname 조회
      final whereConditions = [
        {
          "field": "pro_name",
          "operator": "=",
          "value": _selectedPro
        }
      ];
      
      // branch_id 조건 추가
      if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
          Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty) {
        whereConditions.add({
          "field": "branch_id",
          "operator": "=",
          "value": Provider.of<UserProvider>(context, listen: false).currentBranchId!
        });
      }
      
      final staffResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "get",
          "table": "v2_staff_pro",
          "fields": ["staff_nickname"],
          "where": whereConditions,
          "limit": 1
        }),
      );

      String staffNickname = _selectedPro!; // 기본값으로 pro_name 사용
      
      if (staffResponse.statusCode == 200) {
        final staffResult = jsonDecode(utf8.decode(staffResponse.bodyBytes));
        
        if (staffResult['success'] == true && staffResult['data'].isNotEmpty) {
          staffNickname = staffResult['data'][0]['staff_nickname'] ?? _selectedPro!;
        }
      }

      if (kDebugMode) {
        print('📅 [프로 스케줄] 프로명: $_selectedPro, 닉네임: $staffNickname');
      }

      // schedule_weekly_base 테이블에서 해당 프로의 주간 스케줄 조회
      final scheduleResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "get",
          "table": "schedule_weekly_base",
          "fields": ["day_of_week", "work_or_break", "schedule_base_status", "staff_nickname", "is_day_off", "start_time", "end_time"],
          "where": [
            {
              "field": "staff_nickname",
              "operator": "=",
              "value": staffNickname
            },
            {
              "field": "schedule_base_status",
              "operator": "=",
              "value": "유효"
            }
          ]
        }),
      );

      if (scheduleResponse.statusCode == 200) {
        final scheduleResult = jsonDecode(utf8.decode(scheduleResponse.bodyBytes));
        
        if (scheduleResult['success'] == true) {
          final scheduleData = scheduleResult['data'] as List<dynamic>;
          Map<String, Map<String, dynamic>> weeklySchedule = {};
          
          for (var schedule in scheduleData) {
            final dayOfWeek = schedule['day_of_week'];
            weeklySchedule[dayOfWeek] = {
              'work_or_break': schedule['work_or_break'],
              'schedule_base_status': schedule['schedule_base_status'],
              'staff_nickname': schedule['staff_nickname'],
              'is_day_off': schedule['is_day_off'],
              'start_time': schedule['start_time'],
              'end_time': schedule['end_time'],
            };
          }
          
          if (kDebugMode) {
            print('📅 [프로 스케줄] 주간 스케줄 조회 성공: ${weeklySchedule.length}개 요일');
            weeklySchedule.forEach((day, info) {
              print('📅 [프로 스케줄] $day: ${info['is_day_off']} (${info['start_time']} ~ ${info['end_time']})');
            });
          }
          
          return weeklySchedule;
        }
      }
      
      if (kDebugMode) {
        print('⚠️ [프로 스케줄] 스케줄 정보 조회 실패 또는 데이터 없음');
      }
      
      return {};
    } catch (e) {
      if (kDebugMode) {
        print('❌ [프로 스케줄] 조회 오류: $e');
      }
      return {};
    }
  }

  // v2_bills 테이블에서 가장 큰 bill_id의 bill_balance_after 조회
  Future<void> _getBillBalanceAfter() async {
    if (kDebugMode) {
      print('🔍 [디버깅] ===== 결제하기 버튼 클릭됨 =====');
      print('🔍 [디버깅] 현재 단계: $_currentStep');
      print('🔍 [디버깅] 주니어 member_id: $_juniorMemberId');
      print('🔍 [디버깅] 선택된 예약 종류: $_selectedReservationType');
      print('🔍 [디버깅] 선택된 프로: $_selectedPro');
      
      // 레슨 잔여시간 정보 출력
      if (_lessonBalance != null) {
        print('🔍 [디버깅] 레슨 잔여시간 정보:');
        print('🔍 [디버깅]   - contract_id: ${_lessonBalance!['contract_id']}');
        print('🔍 [디버깅]   - balance_minutes: ${_lessonBalance!['balance_minutes']}분');
        print('🔍 [디버깅]   - balance_hours: ${_lessonBalance!['balance_hours']}시간');
        print('🔍 [디버깅]   - remaining_minutes: ${_lessonBalance!['remaining_minutes']}분');
      } else {
        print('🔍 [디버깅] 레슨 잔여시간 정보: 없음');
      }
    }

    if (_juniorMemberId == null) {
      if (kDebugMode) {
        print('❌ [디버깅] 주니어 member_id가 null입니다.');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔍 [디버깅] v2_bills 테이블에서 bill_balance_after 조회 시작');
      }

      final requestBody = {
        "operation": "get",
        "table": "v2_bills",
        "fields": ["bill_id", "bill_balance_after", "bill_date", "bill_text"],
        "where": [
          {
            "field": "member_id",
            "operator": "=",
            "value": _juniorMemberId.toString() // 주니어 member_id 사용
          },
          if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
              Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
          {
            "field": "branch_id",
            "operator": "=",
            "value": Provider.of<UserProvider>(context, listen: false).currentBranchId!
          }
        ],
        "orderBy": [
          {
            "field": "bill_id",
            "direction": "DESC"
          }
        ],
        "limit": 1
      };

      if (kDebugMode) {
        print('🔍 [디버깅] API 요청 데이터: ${jsonEncode(requestBody)}');
      }

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        print('🔍 [디버깅] API 응답 상태 코드: ${response.statusCode}');
        print('🔍 [디버깅] API 응답 본문: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (kDebugMode) {
          print('🔍 [디버깅] 파싱된 응답: ${jsonEncode(result)}');
        }
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          final billData = result['data'][0];
          final billId = billData['bill_id'];
          final billBalanceAfter = billData['bill_balance_after'];
          final billDate = billData['bill_date'];
          final billText = billData['bill_text'];
          
          // _billBalanceAfter 변수에 값 저장
          setState(() {
            _billBalanceAfter = billBalanceAfter;
          });
          
          if (kDebugMode) {
            print('🔍 [디버깅] ===== v2_bills 조회 결과 =====');
            print('🔍 [디버깅] 가장 큰 bill_id: $billId');
            print('🔍 [디버깅] bill_balance_after: $billBalanceAfter');
            print('🔍 [디버깅] bill_date: $billDate');
            print('🔍 [디버깅] bill_text: $billText');
            print('🔍 [디버깅] ================================');
          }
        } else {
          if (kDebugMode) {
            print('🔍 [디버깅] v2_bills 테이블에서 해당 member_id의 데이터를 찾을 수 없습니다.');
            print('🔍 [디버깅] result[success]: ${result['success']}');
            print('🔍 [디버깅] result[data]: ${result['data']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ [디버깅] HTTP 오류: ${response.statusCode}');
          print('❌ [디버깅] 응답 본문: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [디버깅] v2_bills 조회 오류: $e');
        print('❌ [디버깅] 스택 트레이스: ${StackTrace.current}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 주니어 테마 색상 정의 (갈색 계열이지만 조금 다른 톤)
    final Color primaryColor = const Color(0xFF795548); // 주니어용 갈색 테마
    final Color secondaryColor = const Color(0xFF8D6E63); // 밝은 갈색
    final Color backgroundColor = const Color(0xFFF5F5F5); // 배경색
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '주니어 골프스쿨 루틴예약${_juniorName != null ? ' ($_juniorName)' : ''}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoadingJuniorInfo
            ? _buildLoadingScreen()
            : _juniorLoadError != null
                ? _buildErrorScreen()
                : Column(
                    children: [
                      // 단계 표시
                      _buildStepIndicator(),
                      
                      // 단계별 내용
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                      
                      // 하단 버튼
                      _buildBottomButtons(primaryColor),
                    ],
                  ),
      ),
    );
  }

  // 로딩 화면
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF795548),
          ),
          const SizedBox(height: 16),
          Text(
            '주니어 회원 정보를 불러오는 중...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 오류 화면
  Widget _buildErrorScreen() {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              '주니어 회원 정보 로드 실패',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
              Container(
              padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                  color: Colors.grey.shade200,
                    width: 1,
                ),
              ),
              child: Text(
                _juniorLoadError ?? '알 수 없는 오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadJuniorMemberInfo(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF795548),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('이전 화면'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 단계 표시기
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepCircle(0, '예약 설정'),
          _buildStepLine(0),
          _buildStepCircle(1, '요일/시간'),
          _buildStepLine(1),
          _buildStepCircle(2, '내역 확인'),
          _buildStepLine(2),
          _buildStepCircle(3, '결제'),
        ],
      ),
    );
  }
  
  // 단계 원형 표시기
  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    final Color primaryColor = const Color(0xFF795548);
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // 이미 완료한 단계나 현재 단계+1까지만 이동 가능
          if (step <= _currentStep || step == _currentStep + 1) {
            setState(() {
              _currentStep = step;
            });
          }
        },
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive 
                    ? primaryColor 
                    : isCompleted 
                        ? Colors.green 
                        : Colors.grey.shade300,
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        (step + 1).toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? primaryColor : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // 단계 연결선
  Widget _buildStepLine(int step) {
    final isCompleted = _currentStep > step;
    
    return Container(
      width: 10,
      height: 2,
      color: isCompleted ? Colors.green : Colors.grey.shade300,
    );
  }
  
  // 현재 단계에 따른 내용 표시
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildReservationSettings();
      case 1:
        return _buildTimeSelection();
      case 2:
        return _buildSummary();
      case 3:
        return _buildPayment();
      default:
        return Container();
    }
  }
  
  // 1단계: 예약 설정 (예약 종류 + 예약 횟수)
  Widget _buildReservationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주니어 루틴 예약 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '담당 프로와 예약 횟수를 선택해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        
        // 주니어 골프스쿨 타석 안내
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '주니어 골프스쿨은 단독타석(7, 8, 9번)만 사용합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // 담당 프로 선택 섹션
        Text(
          '담당 프로 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        
        // 프로 목록 로딩 중
        if (_isLoadingPros)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF795548),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '프로 목록을 불러오는 중...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        // 프로 목록 타일 표시
        else if (_availablePros.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _availablePros.length,
            itemBuilder: (context, index) {
              final pro = _availablePros[index];
              final isSelected = _selectedPro == pro['name'];
              final Color primaryColor = const Color(0xFF795548);
              
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    _selectedPro = pro['name'];
                    _selectedReservationType = 'tee_lesson'; // 자동으로 타석+레슨 선택
                    _lessonBalance = null; // 기존 잔여시간 정보 초기화
                  });
                  
                  if (pro['name'] != null) {
                    await _loadLessonBalance();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              size: 24,
                              color: isSelected ? primaryColor : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pro['display_name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? primaryColor : Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        // 프로 목록이 없는 경우
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '유효한 레슨 계약이 없습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 잔여시간 정보 표시 (프로 선택 후)
        if (_selectedPro != null && _lessonBalance != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '레슨 잔여시간',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_lessonBalance!['balance_minutes'] / 30).floor()}회 (총 ${_lessonBalance!['balance_minutes']}분)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // 잔여시간 상태 아이콘
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _lessonBalance!['balance_minutes'] > 0 
                        ? Colors.green.shade100 
                        : Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _lessonBalance!['balance_minutes'] > 0 
                        ? Icons.check 
                        : Icons.warning,
                    size: 16,
                    color: _lessonBalance!['balance_minutes'] > 0 
                        ? Colors.green.shade700 
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 32),
        
        // 예약 횟수 섹션
        Text(
          '예약 횟수',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '원하는 예약 횟수를 선택해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        
        // 예약 횟수 그리드
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _frequencyOptions.length,
          itemBuilder: (context, index) {
            final option = _frequencyOptions[index];
            final isSelected = _selectedFrequency == option['count'];
            final Color primaryColor = const Color(0xFF795548);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFrequency = option['count'];
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    Center(
                      child: Text(
                        option['description'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? primaryColor : Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  // 2단계: 시간 선택 (기존 3단계에서 2단계로 변경)
  Widget _buildTimeSelection() {
    final Color primaryColor = const Color(0xFF795548);
    final bool isLessonIncluded = _selectedReservationType == 'tee_lesson';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주니어 루틴 예약 요일과 시간을 선택해주세요',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '매주 반복될 요일과 시간을 선택하세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        
        // 주니어 골프스쿨 타석 안내
        if (isLessonIncluded)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade800,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '타석은 정각 또는 30분에 시작하며, 55분간 이용됩니다. 레슨 1, 2는 자동으로 설정됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 요일 선택 리스트 (컴팩트한 디자인)
        ...List.generate(_weekdays.length, (index) {
          final day = _weekdays[index];
          final dayId = day['id'] as int;
          final dayName = day['name'] as String;
          final fullDayName = day['fullName'] as String;
          
          // 프로 스케줄 정보 확인
          final proSchedule = _proWeeklySchedule[dayName];
          final bool isProDayOff = proSchedule?['is_day_off'] == '휴무';
          final String? workStartTime = proSchedule?['start_time'];
          final String? workEndTime = proSchedule?['end_time'];
          
          Map<String, dynamic> times = _selectedTimes[dayId] ?? {};
          
          // 해당 요일이 선택되지 않았다면 빈 시간 정보로 초기화
          if (times.isEmpty) {
            // 프로 근무시간이 있으면 그 시간으로 초기화, 없으면 기본값
            TimeOfDay defaultStart = TimeOfDay(hour: 9, minute: 0);
            TimeOfDay defaultEnd = TimeOfDay(hour: 9, minute: 55);
            
            if (!isProDayOff && workStartTime != null && workEndTime != null) {
              try {
                final startParts = workStartTime.split(':');
                final endParts = workEndTime.split(':');
                defaultStart = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
                
                // 종료시간에서 55분 빼서 타석 종료시간 계산
                int endHour = int.parse(endParts[0]);
                int endMinute = int.parse(endParts[1]) - 5; // 5분 여유
                if (endMinute < 0) {
                  endHour = (endHour - 1) % 24;
                  endMinute += 60;
                }
                defaultEnd = TimeOfDay(hour: endHour, minute: endMinute);
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ [프로 스케줄] 시간 파싱 오류: $e');
                }
              }
            }
            
            times = {
              'start': defaultStart,
              'end': defaultEnd,
            };
            
            if (isLessonIncluded) {
              times['lessons'] = [
                {
                  'start': defaultStart,
                  'end': TimeOfDay(hour: defaultStart.hour, minute: defaultStart.minute + 15),
                },
                {
                  'start': TimeOfDay(hour: defaultStart.hour, minute: defaultStart.minute + 15),
                  'end': TimeOfDay(hour: defaultStart.hour, minute: defaultStart.minute + 30),
                }
              ];
            }
          } else if (isLessonIncluded && times['lessons'] == null) {
            // 타석+레슨인데 레슨 시간이 없는 경우 추가
            final TimeOfDay teeStart = times['start'] ?? TimeOfDay(hour: 9, minute: 0);
            
            times['lessons'] = [
              {
                'start': teeStart,
                'end': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute + 15),
              },
              {
                'start': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute + 15),
                'end': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute + 30),
              }
            ];
          }
          
          final bool isSelected = _selectedTimes.containsKey(dayId);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? primaryColor.withOpacity(0.5) : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ] : null,
            ),
            child: Column(
              children: [
                // 요일 헤더 및 선택 토글 (더 컴팩트하게)
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dayId == 0 || dayId == 6
                            ? dayId == 0 
                                ? Colors.red.shade100
                                : Colors.blue.shade100
                            : isProDayOff
                                ? Colors.grey.shade200
                                : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dayId == 0
                                ? Colors.red
                                : dayId == 6
                                    ? Colors.blue
                                    : isProDayOff
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullDayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isProDayOff ? Colors.grey.shade600 : null,
                            ),
                          ),
                          // 프로 스케줄 정보 표시
                          if (proSchedule != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              isProDayOff 
                                  ? '프로 휴무일' 
                                  : '근무: ${workStartTime?.substring(0, 5)} ~ ${workEndTime?.substring(0, 5)}',
                              style: TextStyle(
                                fontSize: 13, // 11 -> 13으로 증가
                                color: isProDayOff ? Colors.red.shade600 : Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 선택 토글 스위치 (더 작게)
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isSelected,
                        onChanged: isProDayOff ? null : (value) { // 프로 휴무일이면 비활성화
                          setState(() {
                            if (value) {
                              // 새로운 요일 추가 시 기본 시간 설정
                              final TimeOfDay teeStart = times['start']!;
                              final TimeOfDay teeEnd = times['end']!;
                              
                              // 시간 정보 설정 (고정 레슨 2개)
                              _selectedTimes[dayId] = {
                                'start': teeStart,
                                'end': teeEnd,
                                'lessons': [
                                  {
                                    'start': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute),
                                    'end': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute + 15),
                                  },
                                  {
                                    'start': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute + 15),
                                    'end': TimeOfDay(hour: teeStart.hour, minute: teeStart.minute + 30),
                                  }
                                ],
                              };
                              
                              if (kDebugMode) {
                                print('⏰ [요일 활성화] $fullDayName - 주니어 골프스쿨 고정 레슨 2개');
                              }
                            } else {
                              _selectedTimes.remove(dayId);
                            }
                          });
                          
                          // 요일 선택/해제 시 디버깅 정보 출력
                          _debugCurrentSelections();
                        },
                        activeColor: primaryColor,
                      ),
                    ),
                  ],
                ),
                
                // 시간 선택 섹션 (선택된 요일만 표시)
                if (isSelected) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  // 타석 시작시간 선택 타일들
                  _buildTimeSelectionTiles(dayId, proSchedule, primaryColor),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // 시간 선택 타일들 빌드 함수
  Widget _buildTimeSelectionTiles(int dayId, Map<String, dynamic>? proSchedule, Color primaryColor) {
    // 프로 스케줄 기반으로 시간 옵션 생성
    List<TimeOfDay> timeOptions = [];
    
    if (proSchedule != null && proSchedule['is_day_off'] != '휴무') {
      try {
        final workStartTime = proSchedule['start_time'] as String;
        final workEndTime = proSchedule['end_time'] as String;
        
        // 근무 시작/종료 시간 파싱
        final startParts = workStartTime.split(':');
        final endParts = workEndTime.split(':');
        final workStartHour = int.parse(startParts[0]);
        final workStartMinute = int.parse(startParts[1]);
        final workEndHour = int.parse(endParts[0]);
        final workEndMinute = int.parse(endParts[1]);
        
        // 근무 종료시간에서 1시간(60분) 빼기
        int maxHour = workEndHour;
        int maxMinute = workEndMinute - 60;
        if (maxMinute < 0) {
          maxHour = (maxHour - 1) % 24;
          maxMinute += 60;
        }
        
        // 근무시간 내에서 정각 또는 30분 시간 옵션 생성
        for (int hour = workStartHour; hour <= maxHour; hour++) {
          for (int minute in [0, 30]) {
            // 시작 시간 체크
            if (hour == workStartHour && minute < workStartMinute) {
              continue; // 근무 시작시간 이전은 제외
            }
            
            // 종료 시간 체크 (1시간 전까지)
            if (hour == maxHour && minute > maxMinute) {
              break; // 근무 종료시간 1시간 전 이후는 제외
            }
            
            // 24시간을 넘지 않도록 체크
            if (hour >= 24) break;
            
            timeOptions.add(TimeOfDay(hour: hour, minute: minute));
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [시간 타일] 프로 스케줄 파싱 오류: $e');
        }
        // 오류 시 기본 시간 옵션 사용
        for (int hour = 6; hour <= 22; hour++) {
          timeOptions.add(TimeOfDay(hour: hour, minute: 0));
          timeOptions.add(TimeOfDay(hour: hour, minute: 30));
        }
      }
    } else {
      // 프로 스케줄이 없거나 휴무일인 경우 기본 시간 옵션
      for (int hour = 6; hour <= 22; hour++) {
        timeOptions.add(TimeOfDay(hour: hour, minute: 0));
        timeOptions.add(TimeOfDay(hour: hour, minute: 30));
      }
    }
    
    // 시간 옵션이 없는 경우 처리
    if (timeOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700, size: 16),
            const SizedBox(width: 8),
            Text(
              '해당 요일에는 예약 가능한 시간이 없습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    }
    
    final currentSelectedTime = _selectedTimes[dayId]?['start'];
    
    // 시간 타일들을 그리드로 표시
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 한 줄에 4개씩
        childAspectRatio: 1.5, // 비율 조정
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: timeOptions.length,
      itemBuilder: (context, index) {
        final time = timeOptions[index];
        final isSelected = currentSelectedTime != null && 
                           time.hour == currentSelectedTime.hour && 
                           time.minute == currentSelectedTime.minute;
        
        // 종료 시간 계산 (시작시간 + 55분)
        int endHour = time.hour;
        int endMinute = time.minute + 55;
        if (endMinute >= 60) {
          endHour = (endHour + 1) % 24;
          endMinute -= 60;
        }
        final endTime = TimeOfDay(hour: endHour, minute: endMinute);
        
        return GestureDetector(
          onTap: () => _selectTeeStartTime(dayId, time),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_formatTimeOfDay(time)}',
                      style: TextStyle(
                        fontSize: 15, // 13 -> 15로 증가
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '~${_formatTimeOfDay(endTime)}',
                      style: TextStyle(
                        fontSize: 15, // 13 -> 15로 증가
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 타석 시작시간 선택 함수
  void _selectTeeStartTime(int dayId, TimeOfDay selectedTime) {
    setState(() {
      Map<String, dynamic> times = _selectedTimes[dayId] ?? {};
      
      // 타석 시작시간 업데이트
      times['start'] = selectedTime;
      
      // 타석 종료시간을 시작시간 + 55분으로 자동 설정
      int endHour = selectedTime.hour;
      int endMinute = selectedTime.minute + 55;
      if (endMinute >= 60) {
        endHour = (endHour + 1) % 24;
        endMinute -= 60;
      }
      times['end'] = TimeOfDay(hour: endHour, minute: endMinute);
      
      // 레슨 시간도 자동 조정 (레슨 예약인 경우)
      if (_selectedReservationType == 'tee_lesson') {
        // 레슨 1: 타석 시작시간과 동일하게 시작, 15분간
        // 레슨 2: 타석 시작시간 + 15분에 시작, 15분간
        times['lessons'] = [
          {
            'start': selectedTime,
            'end': TimeOfDay(
              hour: selectedTime.hour,
              minute: selectedTime.minute + 15 >= 60 
                  ? selectedTime.minute + 15 - 60 
                  : selectedTime.minute + 15,
            ),
          },
          {
            'start': TimeOfDay(
              hour: selectedTime.minute + 15 >= 60 
                  ? (selectedTime.hour + 1) % 24 
                  : selectedTime.hour,
              minute: selectedTime.minute + 15 >= 60 
                  ? selectedTime.minute + 15 - 60 
                  : selectedTime.minute + 15,
            ),
            'end': TimeOfDay(
              hour: selectedTime.minute + 30 >= 60 
                  ? (selectedTime.hour + 1) % 24 
                  : selectedTime.hour,
              minute: selectedTime.minute + 30 >= 60 
                  ? selectedTime.minute + 30 - 60 
                  : selectedTime.minute + 30,
            ),
          }
        ];
      }
      
      _selectedTimes[dayId] = times;
    });
    
    // 디버깅 - 현재 선택 사항 출력
    _debugCurrentSelections();
  }
  
  // 4단계: 예약 내역 확인
  Widget _buildSummary() {
    final Color primaryColor = const Color(0xFF795548);
    
    if (_isAnalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text(
              '예약 가능한 날짜를 분석하고 있습니다...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_analysisError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '분석 중 오류가 발생했습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _analysisError!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _analyzeReservations,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    
    if (_analysisResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '예약 분석을 시작해주세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _analyzeReservations,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('분석 시작'),
            ),
          ],
        ),
      );
    }
    
    // 분석 결과가 있는 경우
    final success = _analysisResult!['success'] as bool? ?? false;
    if (!success) {
      final error = _analysisResult!['error'] as String? ?? '알 수 없는 오류';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 64,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '예약 분석 실패',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    final data = _analysisResult!;
    final teeAnalysis = data['tee_analysis'] as List<dynamic>? ?? [];
    final lessonAnalysis = data['lesson_analysis'] as List<dynamic>? ?? [];
    
    // 기존 UI와 호환되도록 details 형식으로 변환
    final details = <Map<String, dynamic>>[];
    
    for (var teeResult in teeAnalysis) {
      final teeMap = teeResult as Map<String, dynamic>;
      final date = teeMap['date'];
      
      // 해당 날짜의 레슨 정보 찾기
      Map<String, dynamic>? lessonResult;
      for (var lesson in lessonAnalysis) {
        final lessonMap = lesson as Map<String, dynamic>;
        if (lessonMap['date'] == date) {
          lessonResult = lessonMap;
          break;
        }
      }
      
      // 상태 텍스트 생성
      String statusText = '';
      bool teeAvailable = teeMap['status'] == '배정완료';
      bool lessonAvailable = lessonResult?['available'] == true;
      
      if (teeAvailable && lessonAvailable) {
        statusText = '예약가능';
      } else if (teeAvailable && !lessonAvailable) {
        statusText = '타석만가능';
      } else {
        statusText = '예약불가';
      }
      
      // 기존 형식으로 변환
      details.add({
        'date': date,
        'weekday': teeMap['weekday'],
        'status_text': statusText,
        'tee_info': {
          'assigned': teeMap['status'] == '배정완료',
          'assigned_ts_id': teeMap['assigned_ts_id'],
          'start_time': teeMap['start_time'],
          'end_time': teeMap['end_time'],
          'cost_info': teeMap['cost_info'],
          'status': teeMap['status'],
          'is_holiday': teeMap['is_holiday'],
          'holiday_name': teeMap['holiday_name'],
        },
        'lesson_info': lessonResult != null ? {
          'available': lessonResult['available'],
          'reason': lessonResult['reason'],
          'start_time': lessonResult['start_time'],
          'end_time': lessonResult['end_time'],
          'duration': _calculateLessonDuration(lessonResult['start_time'], lessonResult['end_time']),
        } : {
          'available': false,
          'reason': '레슨 없음',
          'duration': 0,
        },
        'holiday_info': {
          'is_holiday': teeMap['is_holiday'] ?? false,
          'holiday_name': teeMap['holiday_name'] ?? '',
        }
      });
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Expanded(
              child: Text(
                '예약가능 현황을 확인 후 날짜를 선택해주세요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            // 전체선택 버튼
            ElevatedButton(
              onPressed: () => _selectAllAvailableReservations(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size(0, 0),
              ),
              child: Text(
                '전체선택',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 예약 현황 표
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 표 헤더
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(color: primaryColor.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      child: Text(
                        '선택',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '날짜',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '시간',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '타석',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '상태',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 표 내용
              ...details.asMap().entries.map((entry) {
                final index = entry.key;
                final detail = entry.value as Map<String, dynamic>;
                return _buildTableRow(detail, index, primaryColor);
              }).toList(),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // 선택된 예약 요약 (간소화) - 제거됨 (중복 정보)
        /*
        if (_selectedReservations.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Icon(Icons.check_circle, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '선택된 예약: ${_selectedReservations.length}개',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 간소화된 표 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        child: Text(
                          '순번',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '날짜',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '시간',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '타석',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                
                // 간소화된 표 내용
                ...(_selectedReservations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reservation = entry.value;
                  final detail = reservation['detail'] as Map<String, dynamic>;
                  final teeInfo = detail['tee_info'] as Map<String, dynamic>;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 순번
                        Container(
                          width: 30,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        // 날짜 정보
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${reservation['date']} (${reservation['weekday']})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        // 시간 정보
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${teeInfo['start_time']}-${teeInfo['end_time']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        // 타석 정보
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${teeInfo['ts_id']}번',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
        ],
        */
      ],
    );
  }
  
  // 표 행 위젯
  Widget _buildTableRow(Map<String, dynamic> detail, int index, Color primaryColor) {
    final date = detail['date'] as String;
    final weekday = detail['weekday'] as String;
    final statusText = detail['status_text'] as String;
    final teeInfo = detail['tee_info'] as Map<String, dynamic>;
    final holidayInfo = detail['holiday_info'] as Map<String, dynamic>;
    
    final bool isAvailable = statusText.contains('예약가능');
    final bool isSelected = _selectedReservations.any((r) => r['date'] == date);
    final bool canSelect = isAvailable;
    
    Color statusColor;
    String displayStatusText;
    
    if (isAvailable) {
      statusColor = Colors.green;
      displayStatusText = '예약가능';
    } else {
      statusColor = Colors.red;
      displayStatusText = '예약불가';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 체크박스
          Container(
            width: 40,
            child: Center(
              child: Checkbox(
                value: isSelected,
                onChanged: canSelect ? (bool? value) {
                  if (value != null) {
                    _toggleReservationSelection(detail);
                  }
                } : null,
                activeColor: primaryColor,
                checkColor: Colors.white,
                side: BorderSide(
                  color: canSelect 
                      ? Colors.grey.shade400
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
            ),
          ),
          
          // 날짜
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  '$date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '($weekday)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (holidayInfo['is_holiday'] == true)
                  Text(
                    '🎌',
                    style: TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          
          // 시간
          Expanded(
            flex: 2,
            child: Text(
              canSelect && teeInfo['assigned'] == true
                  ? '${teeInfo['start_time']}-${teeInfo['end_time']}'
                  : '-',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // 타석
          Expanded(
            flex: 1,
            child: Text(
              canSelect && teeInfo['assigned'] == true
                  ? '${teeInfo['assigned_ts_id']}번'
                  : '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: canSelect ? Colors.blue.shade700 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // 상태
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                displayStatusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 컴팩트한 비용 정보 위젯
  Widget _buildCompactCostInfo(Map<String, dynamic> costInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기본 금액 - 주니어는 0원
        Text(
          '기본: 0원',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        // 등록회원 할인 - 주니어는 0원
        Text(
          '등록회원할인: -0원',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        // 집중연습할인 - 주니어는 표시하지 않음 (항상 0원이므로)
        // 기간권 할인 - 주니어는 표시하지 않음 (항상 0원이므로)
        const SizedBox(height: 2),
        // 최종 결제 금액 - 주니어는 0원
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '결제: 0원',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }
  
  // 통화 포맷팅
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0원';
    final int value = amount is int ? amount : int.tryParse(amount.toString()) ?? 0;
    return '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }
  
  // 예약 선택/해제 토글
  void _toggleReservationSelection(Map<String, dynamic> detail) {
    final date = detail['date'] as String;
    final existingIndex = _selectedReservations.indexWhere((r) => r['date'] == date);
    
    setState(() {
      if (existingIndex >= 0) {
        // 이미 선택된 경우 제거
        _selectedReservations.removeAt(existingIndex);
      } else {
        // 선택되지 않은 경우 추가 (최대 개수 제한 제거)
        _selectedReservations.add({
          'date': detail['date'],
          'weekday': detail['weekday'],
          'detail': detail,
        });
      }
    });
  }
  
  // 5단계: 결제 (구현 예정)
  Widget _buildPayment() {
    final Color primaryColor = const Color(0xFF795548);
    
    // 현재 레슨 잔여시간과 횟수 계산
    final currentLessonMinutes = _lessonBalance?['balance_minutes'] ?? 0;
    final currentLessonCount = (currentLessonMinutes / 30).floor();
    
    // 이번 예약으로 사용될 레슨 횟수 (선택된 예약 개수)
    final usedLessonCount = _selectedReservations.length;
    
    // 예약 후 잔여 레슨 횟수
    final afterLessonCount = currentLessonCount - usedLessonCount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 레슨 횟수 변화 정보
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '레슨권 현황',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 횟수 변화 표시
              Row(
                children: [
                  // 현재 보유 횟수
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inventory, color: Colors.blue.shade700, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '변경전',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currentLessonCount}회',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 화살표
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                  ),
                  
                  // 금회 예약 횟수
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.remove_circle, color: Colors.orange.shade700, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '금회 예약',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '-${usedLessonCount}회',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 화살표
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                  ),
                  
                  // 변경 후 잔여 횟수
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: afterLessonCount >= 0 
                              ? Colors.green.shade200 
                              : Colors.red.shade200
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            afterLessonCount >= 0 ? Icons.check_circle : Icons.warning,
                            color: afterLessonCount >= 0 
                                ? Colors.green.shade700 
                                : Colors.red.shade700,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '변경 후',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: afterLessonCount >= 0 
                                  ? Colors.green.shade700 
                                  : Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${afterLessonCount}회',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: afterLessonCount >= 0 
                                  ? Colors.green.shade800 
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // 주의사항 (레슨 횟수 부족 시)
              if (afterLessonCount < 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '레슨 횟수가 부족합니다. 레슨 충전 후 이용해주세요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // 예약 상세 정보
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '예약 상세 정보',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('담당 프로:', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        Text(_selectedPro ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('예약 횟수:', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        Text('${_selectedReservations.length}회', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '예약내역:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: _selectedReservations.map((reservation) {
                              final detail = reservation['detail'] as Map<String, dynamic>;
                              final teeInfo = detail['tee_info'] as Map<String, dynamic>;
                              final date = reservation['date'] as String;
                              final weekday = reservation['weekday'] as String;
                              
                              final startTime = teeInfo['start_time'] ?? '';
                              final endTime = teeInfo['end_time'] ?? '';
                              
                              // 요일 한글 변환
                              String koreanWeekday = '';
                              switch (weekday) {
                                case '일요일':
                                  koreanWeekday = '일';
                                  break;
                                case '월요일':
                                  koreanWeekday = '월';
                                  break;
                                case '화요일':
                                  koreanWeekday = '화';
                                  break;
                                case '수요일':
                                  koreanWeekday = '수';
                                  break;
                                case '목요일':
                                  koreanWeekday = '목';
                                  break;
                                case '금요일':
                                  koreanWeekday = '금';
                                  break;
                                case '토요일':
                                  koreanWeekday = '토';
                                  break;
                                default:
                                  koreanWeekday = weekday;
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• $date($koreanWeekday) $startTime~$endTime',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 하단 버튼
  Widget _buildBottomButtons(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 이전 버튼
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '이전',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          
          // 간격
          if (_currentStep > 0)
            const SizedBox(width: 16),
          
          // 다음 버튼
          Expanded(
            child: ElevatedButton(
              onPressed: _getNextButtonEnabled() ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: _getNextButtonEnabled() ? primaryColor : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _getNextButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return '다음';
      case 1:
        return '다음';
      case 2:
        return '결제하기';
      case 3:
        return '결제하기';
      default:
        return '';
    }
  }

  bool _getNextButtonEnabled() {
    switch (_currentStep) {
      case 0:
        return _selectedPro != null && _selectedFrequency != null;
      case 1:
        return _selectedTimes.isNotEmpty;
      case 2:
        return _selectedReservations.isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  // 전체선택 함수
  void _selectAllAvailableReservations() {
    if (_analysisResult == null) return;
    
    final details = _analysisResult!['data']['details'] as List<dynamic>;
    
    setState(() {
      _selectedReservations.clear();
      
      // 선택 가능한 모든 예약을 추가 (예약가능만 선택)
      for (var detail in details) {
        final statusText = detail['status_text'] as String;
        final bool isAvailable = statusText.contains('예약가능');
        
        if (isAvailable) {
          _selectedReservations.add({
            'date': detail['date'],
            'weekday': detail['weekday'],
            'detail': detail,
          });
        }
      }
    });
  }
  
  // 잔액 정보 섹션 위젯
  Widget _buildBalanceInfoSection(Color primaryColor) {
    // 총 결제 금액 계산
    int totalCost = 0;
    int totalLessonTime = 0;
    
    for (var reservation in _selectedReservations) {
      final detail = reservation['detail'] as Map<String, dynamic>;
      final teeInfo = detail['tee_info'] as Map<String, dynamic>;
      final lessonInfo = detail['lesson_info'] as Map<String, dynamic>;
      
      // 결제 금액 합계
      if (teeInfo['assigned'] == true && teeInfo['cost_info'] != null) {
        final costInfo = teeInfo['cost_info'] as Map<String, dynamic>;
        totalCost += (costInfo['final_cost'] ?? 0) as int;
      }
      
      // 레슨 시간 합계
      if (_selectedReservationType == 'tee_lesson') {
        totalLessonTime += (lessonInfo['duration'] ?? 0) as int;
      }
    }
    
    // 예약 횟수에 따른 할인 적용
    int discount = 0;
    if (_selectedFrequency != null) {
      final frequencyOption = _frequencyOptions.firstWhere(
        (option) => option['count'] == _selectedFrequency,
        orElse: () => {'discount': 0},
      );
      discount = frequencyOption['discount'] ?? 0;
    }
    
    // 할인 적용된 최종 결제 금액
    final finalTotalCost = totalCost - discount;
    
    // 현재 잔액 정보 (디버깅에서 가져온 값들 사용)
    final currentBalance = _billBalanceAfter ?? 0; // v2_bills에서 가져온 잔액
    final currentLessonMinutes = _lessonBalance?['balance_minutes'] ?? 0; // 레슨 잔여시간
    
    // 결제 후 예상 잔액 계산 (할인 적용된 금액으로)
    final afterPaymentBalance = currentBalance - finalTotalCost;
    final afterLessonMinutes = currentLessonMinutes - totalLessonTime;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.indigo.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
                      borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade600, Colors.indigo.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '결제 전/후 잔액 현황',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    Text(
                      '타석 잔액과 레슨 잔여시간을 확인하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade600,
                ),
              ),
            ],
          ),
        ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 타석 잔액 정보
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_golf, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '타석 잔액',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceItem(
                        '결제 전',
                        _formatCurrency(currentBalance),
                        currentBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        Icons.account_balance,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, color: Colors.grey.shade500, size: 12),
                    ),
                    Expanded(
                      child: _buildBalanceItem(
                        '원금액',
                        '-${_formatCurrency(totalCost)}',
                        Colors.orange.shade700,
                        Icons.payment,
                      ),
                    ),
                    if (discount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward, color: Colors.grey.shade500, size: 12),
                      ),
                      Expanded(
                        child: _buildBalanceItem(
                          '할인',
                          '+${_formatCurrency(discount)}',
                          Colors.purple.shade700,
                          Icons.discount,
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward, color: Colors.grey.shade500, size: 12),
                    ),
                    Expanded(
                      child: _buildBalanceItem(
                        '결제 후',
                        _formatCurrency(afterPaymentBalance),
                        afterPaymentBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        Icons.account_balance_wallet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 할인 상세 정보 (할인이 있는 경우만)
          if (discount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.discount, color: Colors.purple.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedFrequency}회 예약 할인 혜택',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        Text(
                          '원금액 ${_formatCurrency(totalCost)} → 최종금액 ${_formatCurrency(finalTotalCost)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-${_formatCurrency(discount)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 레슨 잔여시간 정보 (레슨 예약인 경우만)
          if (_selectedReservationType == 'tee_lesson') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '레슨 잔여시간',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBalanceItem(
                          '사용 전',
                          '${currentLessonMinutes}분',
                          currentLessonMinutes > 0 ? Colors.green.shade700 : Colors.red.shade700,
                          Icons.timer,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: Colors.grey.shade500, size: 16),
                      ),
                      Expanded(
                        child: _buildBalanceItem(
                          '사용 예정',
                          '-${totalLessonTime}분',
                          Colors.orange.shade700,
                          Icons.schedule,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: Colors.grey.shade500, size: 16),
                      ),
                      Expanded(
                        child: _buildBalanceItem(
                          '사용 후',
                          '${afterLessonMinutes}분',
                          afterLessonMinutes >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          Icons.timer_off,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // 주의사항
          if (afterPaymentBalance < 0 || (_selectedReservationType == 'tee_lesson' && afterLessonMinutes < 0)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      afterPaymentBalance < 0 
                          ? '잔액이 부족합니다. 충전 후 이용해주세요.'
                          : '레슨 잔여시간이 부족합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
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
    );
  }
  
  // 잔액 아이템 위젯
  Widget _buildBalanceItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 결제 완료 처리 함수
  Future<void> _completePayment() async {
    if (kDebugMode) {
      print('💳 [주니어 결제 완료] 시작');
    }

    try {
      // 주니어 회원 정보 조회
      String memberName = _juniorName ?? '';
      String memberPhone = '';
      
      try {
        final memberResponse = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'operation': 'get',
            'table': 'v3_members',
            'fields': ['member_name', 'member_phone'],
            'where': [
              {
                'field': 'member_id',
                'operator': '=',
                'value': _juniorMemberId.toString() // 주니어 member_id 사용
              },
              if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                  Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
              {
                'field': 'branch_id',
                'operator': '=',
                'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
              }
            ],
            'limit': 1
          }),
        );

        if (memberResponse.statusCode == 200) {
          final memberResult = jsonDecode(utf8.decode(memberResponse.bodyBytes));
          
          if (memberResult['success'] == true && memberResult['data'].isNotEmpty) {
            final memberData = memberResult['data'][0];
            memberName = memberData['member_name'] ?? _juniorName ?? '';
            memberPhone = memberData['member_phone'] ?? '';
            
            if (kDebugMode) {
              print('✅ [주니어 결제 완료] 주니어 회원 정보 조회 성공 - 이름: $memberName, 전화번호: $memberPhone');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [주니어 결제 완료] 주니어 회원 정보 조회 실패: $e');
        }
        // 회원 정보 조회 실패해도 계속 진행
      }

      // 각 날짜별로 v2_priced_TS 테이블에 타석 예약 정보 등록
      List<String> failedReservations = [];
      int successCount = 0;

      for (var reservation in _selectedReservations) {
        try {
          final detail = reservation['detail'] as Map<String, dynamic>;
          final teeInfo = detail['tee_info'] as Map<String, dynamic>;
          
          if (teeInfo['assigned'] != true || teeInfo['cost_info'] == null) {
            if (kDebugMode) {
              print('⚠️ [주니어 결제 완료] 타석 배정되지 않은 날짜 건너뛰기: ${reservation['date']}');
            }
            continue;
          }

          final costInfo = teeInfo['cost_info'] as Map<String, dynamic>;
          final tsId = _safeToInt(teeInfo['ts_id']);
          final startTime = teeInfo['start_time'];
          final endTime = teeInfo['end_time'];
          final date = reservation['date'];

          // reservation_id 생성 (yymmdd_ts_id_hhmm)
          final dateParts = date.split('-');
          final year = dateParts[0].substring(2); // yy
          final month = dateParts[1]; // mm
          final day = dateParts[2]; // dd
          final timeParts = startTime.split(':');
          final hour = timeParts[0]; // hh
          final minute = timeParts[1]; // mm
          final reservationId = '${year}${month}${day}_${tsId}_${hour}${minute}';

          // 시간대별 분 계산
          final timeClassification = detail['time_classification'];
          int morningMinutes = 0;
          int normalMinutes = 0;
          int peakMinutes = 0;
          int nightMinutes = 0;

          if (timeClassification is Map) {
            morningMinutes = timeClassification['조조'] ?? 0;
            normalMinutes = timeClassification['일반'] ?? 0;
            peakMinutes = timeClassification['피크'] ?? 0;
            nightMinutes = timeClassification['심야'] ?? 0;
          } else if (timeClassification is String) {
            // 단일 시간대인 경우 60분으로 설정
            switch (timeClassification) {
              case '조조':
                morningMinutes = 60;
                break;
              case '일반':
                normalMinutes = 60;
                break;
              case '피크':
                peakMinutes = 60;
                break;
              case '심야':
                nightMinutes = 60;
                break;
            }
          }

          final totalMinutes = morningMinutes + normalMinutes + peakMinutes + nightMinutes;

          // ts_min 계산 (시작 시간과 종료 시간의 차이를 분으로)
          final startTimeParts = startTime.split(':');
          final endTimeParts = endTime.split(':');
          final startMinutes = int.parse(startTimeParts[0]) * 60 + int.parse(startTimeParts[1]);
          final endMinutes = int.parse(endTimeParts[0]) * 60 + int.parse(endTimeParts[1]);
          final tsMinutes = endMinutes - startMinutes;

          // 타석 예약 데이터 생성
          final teeReservationData = {
            'reservation_id': reservationId,
            'ts_id': tsId,
            'ts_date': date,
            'ts_start': startTime,
            'ts_end': endTime,
            'ts_min': tsMinutes,
            'ts_type': '주니어(루틴)', // 일반(루틴) -> 주니어(루틴)으로 변경
            'ts_payment_method': 'credit',
            'ts_status': '결제완료',
            'member_id': _safeToInt(_juniorMemberId), // 주니어 member_id 사용
            'member_name': memberName,
            'member_phone': memberPhone,
            'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId,
            'total_amt': 0, // 주니어 골프스쿨은 무료이므로 0
            'term_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'member_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'junior_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'routine_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'overtime_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'revisit_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'emergency_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'emergency_reason': '',
            'total_discount': 0, // 주니어 골프스쿨은 무료이므로 0
            'net_amt': 0, // 주니어 골프스쿨은 무료이므로 0
            'morning': morningMinutes,
            'normal': normalMinutes,
            'peak': peakMinutes,
            'night': nightMinutes,
            'time_stamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
          };

          if (kDebugMode) {
            print('💳 [주니어 결제 완료] 타석 예약 데이터 (${reservation['date']}): ${jsonEncode(teeReservationData)}');
          }

          // 타석 예약 등록 API 호출
          final teeResponse = await http.post(
            Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'operation': 'add',
              'table': 'v2_priced_TS',
              'data': teeReservationData,
            }),
          );

          if (kDebugMode) {
            print('💳 [주니어 결제 완료] 타석 예약 API 응답 상태 (${reservation['date']}): ${teeResponse.statusCode}');
            print('💳 [주니어 결제 완료] 타석 예약 API 응답 내용 (${reservation['date']}): ${teeResponse.body}');
          }

          if (teeResponse.statusCode == 200) {
            final teeResult = jsonDecode(utf8.decode(teeResponse.bodyBytes));
            
            if (teeResult['success'] == true) {
              successCount++;
              if (kDebugMode) {
                print('✅ [주니어 결제 완료] 타석 예약 성공 (${reservation['date']}): reservation_id=${reservationId}');
              }
              
              // 레슨 예약인 경우 v2_LS_orders 테이블에도 레슨 데이터 추가
              if (_selectedReservationType == 'tee_lesson') {
                await _addLessonReservation(reservation, memberName);
              }
              
            } else {
              failedReservations.add('${reservation['date']}: ${teeResult['error'] ?? '알 수 없는 오류'}');
              if (kDebugMode) {
                print('❌ [주니어 결제 완료] 타석 예약 실패 (${reservation['date']}): ${teeResult['error']}');
              }
            }
          } else {
            failedReservations.add('${reservation['date']}: HTTP 오류 ${teeResponse.statusCode}');
            if (kDebugMode) {
              print('❌ [주니어 결제 완료] 타석 예약 HTTP 오류 (${reservation['date']}): ${teeResponse.statusCode}');
            }
          }

        } catch (e) {
          failedReservations.add('${reservation['date']}: $e');
          if (kDebugMode) {
            print('❌ [주니어 결제 완료] 타석 예약 예외 오류 (${reservation['date']}): $e');
          }
        }
      }

      // 결과 다이얼로그 표시
      if (failedReservations.isEmpty) {
        // 모든 예약 성공
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text('결제 완료'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('주니어 루틴 예약이 성공적으로 등록되었습니다.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• 주니어 이름: $memberName'),
                      Text('• 예약 종류: ${_selectedReservationType == 'tee_lesson' ? '타석 + 레슨' : '타석만'}'),
                      Text('• 성공한 예약: ${successCount}회'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  Navigator.of(context).pop(); // 루틴예약 화면 닫기
                },
                child: Text('확인'),
              ),
            ],
          ),
        );
      } else {
        // 일부 실패
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text('부분 성공'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('일부 타석 예약에 실패했습니다.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• 주니어 이름: $memberName'),
                      Text('• 성공한 예약: ${successCount}회'),
                      Text('• 실패한 예약: ${failedReservations.length}회'),
                      const SizedBox(height: 8),
                      Text('실패 내역:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...failedReservations.take(3).map((failure) => Text('  - $failure', style: TextStyle(fontSize: 12))),
                      if (failedReservations.length > 3)
                        Text('  ... 외 ${failedReservations.length - 3}건', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  Navigator.of(context).pop(); // 루틴예약 화면 닫기
                },
                child: Text('확인'),
              ),
            ],
          ),
        );
      }

      if (kDebugMode) {
        print('✅ [주니어 결제 완료] 전체 처리 완료 - 성공: ${successCount}건, 실패: ${failedReservations.length}건');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [주니어 결제 완료] 전체 처리 오류: $e');
      }

      // 오류 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text('결제 실패'),
            ],
          ),
          content: Text('주니어 결제 처리 중 오류가 발생했습니다.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  // 레슨 예약 추가 함수
  Future<void> _addLessonReservation(Map<String, dynamic> reservation, String memberName) async {
    try {
      final detail = reservation['detail'] as Map<String, dynamic>;
      final lessonInfo = detail['lesson_info'] as Map<String, dynamic>;
      final date = reservation['date'];
      
      // 레슨이 가능한 경우만 처리
      if (lessonInfo['available'] != true) {
        if (kDebugMode) {
          print('⚠️ [주니어 레슨 예약] 레슨 불가능한 날짜 건너뛰기: $date');
        }
        return;
      }

      // 강사 닉네임 조회 (Staff 테이블에서)
      String staffNickname = await _getStaffNickname(_selectedPro ?? '');
      
      // _selectedTimes에서 해당 날짜의 레슨 시간 찾기
      final weekdayMap = {
        '일요일': 0, '월요일': 1, '화요일': 2, '수요일': 3, 
        '목요일': 4, '금요일': 5, '토요일': 6
      };
      
      final weekday = reservation['weekday'];
      final dayId = weekdayMap[weekday];
      
      if (dayId == null || !_selectedTimes.containsKey(dayId)) {
        if (kDebugMode) {
          print('⚠️ [주니어 레슨 예약] 해당 요일의 시간 정보 없음: $weekday');
        }
        return;
      }

      final times = _selectedTimes[dayId]!;
      List<Map<String, TimeOfDay>> lessons = List.from(times['lessons'] ?? []);
      
      if (lessons.isEmpty) {
        if (kDebugMode) {
          print('⚠️ [주니어 레슨 예약] 레슨 시간 정보 없음: $date');
        }
        return;
      }

      // 각 레슨 시간에 대해 개별적으로 예약 생성
      for (int lessonIndex = 0; lessonIndex < lessons.length; lessonIndex++) {
        final lesson = lessons[lessonIndex];
        final lessonStart = lesson['start']!;
        final lessonEnd = lesson['end']!;
        
        final lessonStartTime = '${_formatTimeOfDay(lessonStart)}:00';
        final lessonEndTime = '${_formatTimeOfDay(lessonEnd)}:00';
        
        // 레슨 시간 계산 (분 단위)
        final startMinutes = lessonStart.hour * 60 + lessonStart.minute;
        final endMinutes = lessonEnd.hour * 60 + lessonEnd.minute;
        final lessonDuration = endMinutes - startMinutes;

        // LS_id 생성 (yymmdd_staff_nickname_hhmm) - 인덱스 제거
        final dateParts = date.split('-');
        final year = dateParts[0].substring(2);
        final month = dateParts[1];
        final day = dateParts[2];
        final timeParts = lessonStartTime.split(':');
        final hour = timeParts[0];
        final minute = timeParts[1];
        final lessonId = '${year}${month}${day}_${staffNickname}_${hour}${minute}';

        // LS_set_id 생성 (첫 번째 레슨의 시작시간 기준으로 일자별 묶음)
        final firstLessonStart = lessons[0]['start']!;
        final firstLessonHour = firstLessonStart.hour.toString().padLeft(2, '0');
        final firstLessonMinute = firstLessonStart.minute.toString().padLeft(2, '0');
        final setId = '${year}${month}${day}_${staffNickname}_${firstLessonHour}${firstLessonMinute}_set';

        // 레슨 예약 데이터 생성
        final lessonReservationData = {
          'LS_id': lessonId,
          'LS_transaction_type': '레슨예약',
          'LS_date': date,
          'member_id': _safeToInt(_juniorMemberId), // 주니어 member_id 사용
          'LS_status': '결제완료',
          'member_name': memberName,
          'member_type': '주니어', // 일반 -> 주니어로 변경
          'LS_type': '주니어(루틴)', // 일반(루틴) -> 주니어(루틴)으로 변경
          'LS_contract_pro': _selectedPro ?? '',
          'LS_order_source': 'web-app',
          'LS_start_time': lessonStartTime,
          'LS_end_time': lessonEndTime,
          'LS_net_min': lessonDuration,
          'updated_at': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
          'TS_id': _safeToInt(detail['tee_info']['ts_id']),
          'LS_set_id': setId, // LS_set_id 추가
          'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
        };

        if (kDebugMode) {
          print('💳 [주니어 레슨 예약] 레슨 ${lessonIndex + 1} 예약 데이터 ($date): ${jsonEncode(lessonReservationData)}');
        }

        // 레슨 예약 등록 API 호출
        final lessonResponse = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'operation': 'add',
            'table': 'v2_LS_orders',
            'data': lessonReservationData,
          }),
        );

        if (kDebugMode) {
          print('💳 [주니어 레슨 예약] 레슨 ${lessonIndex + 1} 예약 API 응답 상태 ($date): ${lessonResponse.statusCode}');
          print('💳 [주니어 레슨 예약] 레슨 ${lessonIndex + 1} 예약 API 응답 내용 ($date): ${lessonResponse.body}');
        }

        if (lessonResponse.statusCode == 200) {
          final lessonResult = jsonDecode(utf8.decode(lessonResponse.bodyBytes));
          
          if (lessonResult['success'] == true) {
            if (kDebugMode) {
              print('✅ [주니어 레슨 예약] 레슨 ${lessonIndex + 1} 예약 성공 ($date): LS_id=${lessonId}, LS_set_id=${setId}');
            }
            
            // 레슨 예약 성공 후 v3_LS_countings 테이블에 레슨 사용 기록 추가
            await _addLessonCounting(date, lessonId, lessonDuration, memberName, setId);
            
          } else {
            if (kDebugMode) {
              print('❌ [주니어 레슨 예약] 레슨 ${lessonIndex + 1} 예약 실패 ($date): ${lessonResult['error']}');
            }
          }
        } else {
          if (kDebugMode) {
            print('❌ [주니어 레슨 예약] 레슨 ${lessonIndex + 1} 예약 HTTP 오류 ($date): ${lessonResponse.statusCode}');
          }
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [주니어 레슨 예약] 레슨 예약 예외 오류 (${reservation['date']}): $e');
      }
    }
  }

  // 강사 닉네임 조회 함수
  Future<String> _getStaffNickname(String staffName) async {
    try {
      final whereConditions = [
        {
          'field': 'pro_name',
          'operator': '=',
          'value': staffName
        }
      ];
      
      // branch_id 조건 추가
      if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
          Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
        });
      }
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_staff_pro',
          'fields': ['staff_nickname'],
          'where': whereConditions,
          'limit': 1
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          return result['data'][0]['staff_nickname'] ?? staffName;
        }
      }
      
      // 닉네임을 찾지 못한 경우 원본 이름 반환
      return staffName;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [강사 닉네임 조회] 오류: $e');
      }
      return staffName; // 오류 시 원본 이름 반환
    }
  }

  // 프로별 레슨 시간 설정 정보 조회 함수
  Future<Map<String, int>> _getStaffServiceSettings(String staffName) async {
    try {
      final whereConditions = [
        {
          'field': 'pro_name',
          'operator': '=',
          'value': staffName
        }
      ];
      
      // branch_id 조건 추가
      if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
          Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
        });
      }
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_staff_pro',
          'fields': ['min_service_min', 'staff_svc_time'],
          'where': whereConditions,
          'limit': 1
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          final data = result['data'][0];
          final minServiceMin = _safeToInt(data['min_service_min']);
          final staffSvcTime = _safeToInt(data['staff_svc_time']);
          
          if (kDebugMode) {
            print('📋 [프로 설정] $staffName - 최소시간: ${minServiceMin}분, 선택단위: ${staffSvcTime}분');
          }
          
          return {
            'min_service_min': minServiceMin > 0 ? minServiceMin : 15, // 기본값 15분
            'staff_svc_time': staffSvcTime > 0 ? staffSvcTime : 5,     // 기본값 5분
          };
        }
      }
      
      // 조회 실패 시 기본값 반환
      if (kDebugMode) {
        print('⚠️ [프로 설정] $staffName 조회 실패, 기본값 사용');
      }
      return {
        'min_service_min': 15, // 기본 최소시간
        'staff_svc_time': 5,   // 기본 선택단위
      };
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [프로 설정 조회] 오류: $e');
      }
      return {
        'min_service_min': 15,
        'staff_svc_time': 5,
      };
    }
  }

  // 레슨 사용 기록 추가 함수 (v3_LS_countings)
  Future<void> _addLessonCounting(String date, String lessonId, int lessonDuration, String memberName, String setId) async {
    try {
      if (kDebugMode) {
        print('📊 [주니어 레슨 카운팅] 시작 - 날짜: $date, LS_id: $lessonId, 사용시간: ${lessonDuration}분, LS_set_id: $setId');
      }

      // 1. 해당 주니어 회원의 해당 프로에 대한 최신 잔여시간 조회
      int balanceMinBefore = await _getLatestLessonBalance();
      
      if (kDebugMode) {
        print('📊 [주니어 레슨 카운팅] 사용 전 잔여시간: ${balanceMinBefore}분');
      }

      // 2. 사용 후 잔여시간 계산
      int balanceMinAfter = balanceMinBefore - lessonDuration;
      
      if (kDebugMode) {
        print('📊 [주니어 레슨 카운팅] 사용 후 잔여시간: ${balanceMinAfter}분');
      }

      // 3. v3_LS_countings 데이터 생성
      final countingData = {
        'LS_transaction_type': '주니어루틴', // '레슨예약(주니어루틴)' -> '주니어루틴'으로 단축
        'LS_date': date,
        'member_id': _safeToInt(_juniorMemberId), // 주니어 member_id 사용
        'member_name': memberName,
        'member_type': '주니어', // 일반 -> 주니어로 변경
        'LS_status': '결제완료',
        'LS_type': '주니어레슨', // 일반레슨 -> 주니어레슨으로 변경
        'LS_id': lessonId,
        'LS_contract_pro': _selectedPro ?? '',
        'LS_balance_min_before': balanceMinBefore,
        'LS_net_min': lessonDuration,
        'LS_balance_min_after': balanceMinAfter,
        'LS_counting_source': 'v2_LS_orders',
        'updated_at': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        'LS_set_id': setId, // LS_set_id 추가
        'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
      };

      if (kDebugMode) {
        print('📊 [주니어 레슨 카운팅] 카운팅 데이터: ${jsonEncode(countingData)}');
      }

      // 4. API 호출
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'add',
          'table': 'v3_LS_countings',
          'data': countingData,
        }),
      );

      if (kDebugMode) {
        print('📊 [주니어 레슨 카운팅] API 응답 상태: ${response.statusCode}');
        print('📊 [주니어 레슨 카운팅] API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true) {
          if (kDebugMode) {
            print('✅ [주니어 레슨 카운팅] 레슨 사용 기록 성공: LS_counting_id=${result['insertId']}, LS_set_id=$setId');
          }
        } else {
          if (kDebugMode) {
            print('❌ [주니어 레슨 카운팅] 레슨 사용 기록 실패: ${result['error']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ [주니어 레슨 카운팅] HTTP 오류: ${response.statusCode}');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [주니어 레슨 카운팅] 예외 오류: $e');
      }
    }
  }

  // 최신 레슨 잔여시간 조회 함수
  Future<int> _getLatestLessonBalance() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranchId;
      
      final whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': _juniorMemberId.toString() // 주니어 member_id 사용
        },
        {
          'field': 'LS_contract_pro',
          'operator': '=',
          'value': _selectedPro ?? ''
        },
        {
          'field': 'LS_type',
          'operator': '=',
          'value': '주니어레슨' // 일반레슨 -> 주니어레슨으로 변경
        }
      ];
      
      // branch_id 조건 추가
      if (branchId != null) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': branchId
        });
      }
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v3_LS_countings',
          'fields': ['LS_balance_min_after'],
          'where': whereConditions,
          'orderBy': [
            {
              'field': 'LS_counting_id',
              'direction': 'DESC'
            }
          ],
          'limit': 1
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          return _safeToInt(result['data'][0]['LS_balance_min_after']);
        }
      }
      
      // 기록이 없는 경우 0 반환
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [주니어 최신 레슨 잔여시간 조회] 오류: $e');
      }
      return 0;
    }
  }

  // 안전한 int 변환 헬퍼 함수
  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // 레슨 시간 추가 함수
  void _addLessonTime(int dayId) {
    setState(() {
      Map<String, dynamic> times = _selectedTimes[dayId] ?? {};
      List<Map<String, TimeOfDay>> lessons = List.from(times['lessons'] ?? []);
      
      // 타석 시간 내에서 기본 레슨 시간 설정
      TimeOfDay teeStart = times['start'] ?? TimeOfDay(hour: 9, minute: 0);
      TimeOfDay newLessonStart = teeStart;
      
      // 주니어 골프스쿨 고정 설정 (15분)
      const int minServiceMin = 15;
      
      TimeOfDay newLessonEnd = TimeOfDay(
        hour: newLessonStart.hour,
        minute: newLessonStart.minute + minServiceMin,
      );
      
      // 60분 초과 시 시간 조정
      if (newLessonEnd.minute >= 60) {
        newLessonEnd = TimeOfDay(
          hour: (newLessonEnd.hour + 1) % 24,
          minute: newLessonEnd.minute - 60,
        );
      }
      
      lessons.add({
        'start': newLessonStart,
        'end': newLessonEnd,
      });
      times['lessons'] = lessons;
      _selectedTimes[dayId] = times;
    });
  }
  
  // 레슨 시간 삭제 함수
  void _removeLessonTime(int dayId, int lessonIndex) {
    setState(() {
      Map<String, dynamic> times = _selectedTimes[dayId] ?? {};
      List<Map<String, TimeOfDay>> lessons = List.from(times['lessons'] ?? []);
      
      if (lessonIndex < lessons.length) {
        lessons.removeAt(lessonIndex);
        times['lessons'] = lessons;
        _selectedTimes[dayId] = times;
      }
    });
  }
} 