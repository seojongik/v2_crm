import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../../services/routine_analysis_service.dart';
import '../../../services/api_service.dart';

class RoutineMemberScreen extends StatefulWidget {
  final int? memberId;

  const RoutineMemberScreen({Key? key, this.memberId}) : super(key: key);

  @override
  State<RoutineMemberScreen> createState() => _RoutineMemberScreenState();
}

class _RoutineMemberScreenState extends State<RoutineMemberScreen> {
  // 단계 관리를 위한 인덱스
  int _currentStep = 0;
  
  // 선택한 값들을 저장하는 변수
  String? _selectedReservationType; // 예약 종류
  int? _selectedFrequency; // 예약 횟수
  Map<int, Map<String, dynamic>> _selectedTimes = {}; // 요일별 시작/종료 시간 (dynamic으로 변경)
  List<int> _teePreferenceOrder = [1, 2, 3, 4, 5, 6, 7, 8, 9]; // 타석 우선순위
  Set<int> _excludedTees = {}; // 비선호 타석
  
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
  
  // 예약 종류 옵션
  final List<Map<String, dynamic>> _reservationTypes = [
    {'id': 'tee_only', 'title': '타석만 예약', 'icon': Icons.golf_course},
    {'id': 'tee_lesson', 'title': '타석 + 레슨 예약', 'icon': Icons.sports_golf},
  ];
  
  // 예약 횟수 옵션 (수정됨)
  final List<Map<String, dynamic>> _frequencyOptions = [
    {'count': 5, 'discount': 5000, 'description': '5회\n(할인: 5,000c)'},
    {'count': 10, 'discount': 10000, 'description': '10회\n(할인: 10,000c)'},
    {'count': 15, 'discount': 20000, 'description': '15회\n(할인: 20,000c)'},
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
      print('🚀 [디버깅] RoutineMemberScreen 초기화 시작');
      print('🚀 [디버깅] 디버그 모드 활성화됨');
    }
    _debugMemberId();
  }

  // 디버깅을 위해 memberId를 콘솔에 출력
  void _debugMemberId() {
    if (kDebugMode) {
      print('🔍 [디버깅] ===== 회원 ID 정보 =====');
      print('🔍 [디버깅] RoutineMemberScreen - memberId: ${widget.memberId}');
      
      // Provider에서 회원 ID 직접 가져와서 비교 출력
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final String? userIdStr = userProvider.user?.id;
      final int? providerMemberId = userIdStr != null ? int.tryParse(userIdStr) : null;
      
      print('🔍 [디버깅] Provider에서 가져온 memberId: $providerMemberId (원본: $userIdStr)');
      print('🔍 [디버깅] ========================');
    }
  }
  
  // 디버깅 함수 - 현재 선택 사항 출력
  void _debugCurrentSelections() {
    if (kDebugMode) {
      // 타석 예약 정보 출력
      print('\n===== [디버깅] 타석 예약 선택 내역 =====');
      print('🔍 memberId: ${widget.memberId}');
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
        print('🔍 memberId: ${widget.memberId}');
        print('🔍 테이블: v2_LS_orders, v3_LS_countings');
        print('🔍 레슨 예약 횟수: ${_selectedFrequency != null ? '$_selectedFrequency회' : '선택되지 않음'}');
        
        if (_selectedTimes.isNotEmpty) {
          print('🔍 선택한 요일/시간:');
          _selectedTimes.forEach((dayId, times) {
            final dayName = _weekdays.firstWhere((day) => day['id'] == dayId)['fullName'];
            
            if (times['lesson_start'] != null && times['lesson_end'] != null) {
              final lessonStart = times['lesson_start'] as TimeOfDay;
              final lessonEnd = times['lesson_end'] as TimeOfDay;
              
              final timeRange = '${_formatTimeOfDay(lessonStart)} ~ ${_formatTimeOfDay(lessonEnd)}';
              print('  - $dayName: $timeRange');
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
    if (_currentStep == 0 && (_selectedReservationType == null || _selectedFrequency == null)) {
      _showSelectionRequiredDialog('예약 종류와 예약 횟수를 모두 선택해주세요');
      return;
    }
    
    // 레슨 예약인 경우 프로 선택 검증
    if (_currentStep == 0 && _selectedReservationType == 'tee_lesson' && _selectedPro == null) {
      _showSelectionRequiredDialog('담당 프로를 선택해주세요');
      return;
    }
    
    if (_currentStep == 2 && _selectedTimes.isEmpty) {
      _showSelectionRequiredDialog('요일과 시간을 선택해주세요');
      return;
    }
    
    // 3단계에서 4단계로 넘어갈 때 예약 분석 API 호출
    if (_currentStep == 2) {
      await _analyzeReservations();
      if (_analysisError != null) {
        return; // 오류가 있으면 다음 단계로 넘어가지 않음
      }
    }
    
    // 3단계에서 결제하기 버튼 클릭 시 (내역확인에서 결제하기)
    if (_currentStep == 3) {
      if (_selectedReservations.isEmpty) {
        _showSelectionRequiredDialog('예약할 날짜를 선택해주세요');
        return;
      }
      
      // 최소 개수 검증 (선택한 예약 종류의 횟수만큼)
      final minRequired = _selectedFrequency ?? 5;
      if (_selectedReservations.length < minRequired) {
        _showSelectionRequiredDialog('최소 ${minRequired}개 이상의 날짜를 선택해주세요');
        return;
      }
      
      // 결제하기 버튼 클릭 시 v2_bills 테이블에서 bill_balance_after 조회
      await _getBillBalanceAfter();
    }
    
    // 4단계에서 결제완료 버튼 클릭 시 (결제에서 결제완료)
    if (_currentStep == 4) {
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
      if (_selectedReservationType == 'tee_lesson' && 
          times['lesson_start'] != null && times['lesson_end'] != null) {
        final lessonStartTime = _formatTimeOfDay(times['lesson_start']);
        final lessonEndTime = _formatTimeOfDay(times['lesson_end']);
        targetLessonWeekdays.add([weekdayName, lessonStartTime, lessonEndTime]);
      }
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final params = {
      "base_date": baseDate,
      "member_id": _safeToInt(widget.memberId),
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
      // ApiService.getStaffList()를 사용하여 프로 목록 조회
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final staffList = await ApiService.getStaffList(branchId: userProvider.currentBranchId);
      
      if (staffList.isNotEmpty) {
        setState(() {
          _availablePros = staffList.map((staff) => {
            'name': staff.name,
            'display_name': staff.name,
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
        throw Exception('프로 목록이 비어있습니다');
      }
    } catch (e) {
      setState(() {
        _isLoadingPros = false;
      });
      
      if (kDebugMode) {
        print('❌ 프로 목록 조회 오류: $e');
      }
      
      // 오류 발생 시 빈 목록 유지 (기본값 설정하지 않음)
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
      // member_id가 일치하고, LS_type이 '일반레슨'이고, LS_contract_pro가 선택된 프로인 것들 중에서
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
              "field": "branch_id",
              "operator": "=",
              "value": Provider.of<UserProvider>(context, listen: false).currentBranchId
            },
            {
              "field": "member_id",
              "operator": "=",
              "value": widget.memberId.toString()
            },
            {
              "field": "LS_type",
              "operator": "=",
              "value": "일반레슨"
            },
            {
              "field": "LS_contract_pro",
              "operator": "=",
              "value": _selectedPro
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
            print('📚 조회 기준: member_id=${widget.memberId}, LS_type=일반레슨, LS_contract_pro=$_selectedPro');
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
            print('📚 레슨 잔여시간: 0분 (해당 프로의 일반레슨 기록 없음)');
            print('📚 조회 기준: member_id=${widget.memberId}, LS_type=일반레슨, LS_contract_pro=$_selectedPro');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 레슨 잔여시간 조회 오류: $e');
      }
    }
  }

  // v2_bills 테이블에서 가장 큰 bill_id의 bill_balance_after 조회
  Future<void> _getBillBalanceAfter() async {
    if (kDebugMode) {
      print('🔍 [디버깅] ===== 결제하기 버튼 클릭됨 =====');
      print('🔍 [디버깅] 현재 단계: $_currentStep');
      print('🔍 [디버깅] member_id: ${widget.memberId}');
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

    if (widget.memberId == null) {
      if (kDebugMode) {
        print('❌ [디버깅] member_id가 null입니다.');
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
            "value": widget.memberId.toString()
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
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    final Color secondaryColor = const Color(0xFF8D6E63); // 밝은 갈색
    final Color backgroundColor = const Color(0xFFF5F5F5); // 배경색 변경 (덜 노란색)
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '일반회원 루틴예약',
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
      backgroundColor: backgroundColor, // 배경색 적용
      body: SafeArea(
        child: Column(
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
          _buildStepCircle(1, '타석 선택'),
          _buildStepLine(1),
          _buildStepCircle(2, '요일/시간'),
          _buildStepLine(2),
          _buildStepCircle(3, '내역 확인'),
          _buildStepLine(3),
          _buildStepCircle(4, '결제'),
        ],
      ),
    );
  }
  
  // 단계 원형 표시기
  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    final Color primaryColor = const Color(0xFF5D4037);
    
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
        return _buildTeeSelection();
      case 2:
        return _buildTimeSelection();
      case 3:
        return _buildSummary();
      case 4:
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
          '루틴 예약 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '예약 종류와 횟수를 선택해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        
        // 예약 종류 섹션
        Text(
          '예약 종류',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        
        // 예약 종류 선택 카드들
        ..._reservationTypes.map((type) => _buildReservationTypeCard(type)).toList(),
        
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
          '자주 이용할수록 더 많은 할인 혜택을 받을 수 있습니다.',
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
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _frequencyOptions.length,
          itemBuilder: (context, index) {
            final option = _frequencyOptions[index];
            final isSelected = _selectedFrequency == option['count'];
            final Color primaryColor = const Color(0xFF5D4037);
            
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${option['count']}회',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? primaryColor : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '할인: ${option['discount'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}c',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? primaryColor : Colors.grey.shade700,
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
          },
        ),
      ],
    );
  }
  
  // 예약 종류 선택 카드
  Widget _buildReservationTypeCard(Map<String, dynamic> type) {
    final Color primaryColor = const Color(0xFF5D4037);
    final bool isSelected = _selectedReservationType == type['id'];
    final bool isLessonType = type['id'] == 'tee_lesson';
    
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedReservationType = type['id'];
          // 레슨 예약이 아닌 경우 프로 선택 초기화
          if (!isLessonType) {
            _selectedPro = null;
            _lessonBalance = null;
          }
        });
        
        // 레슨 예약 선택 시 프로 목록 로드
        if (isLessonType) {
          await _loadAvailablePros();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 기본 예약 종류 정보
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    type['icon'],
                    color: isSelected ? primaryColor : Colors.grey.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    type['title'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : Colors.grey.shade800,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            
            // 레슨 예약 선택 시 프로 선택 섹션
            if (isSelected && isLessonType) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // 프로 선택 헤더
              Row(
                children: [
                  Icon(Icons.person, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '담당 프로 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
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
                          color: primaryColor,
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
              // 프로 목록 표시
              else if (_availablePros.isNotEmpty)
                Column(
                  children: [
                    // 프로 선택 드롭다운
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPro,
                          hint: Text(
                            '프로를 선택해주세요',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          isExpanded: true,
                          items: _availablePros.map((pro) {
                            return DropdownMenuItem<String>(
                              value: pro['name'],
                              child: Text(
                                pro['display_name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) async {
                            setState(() {
                              _selectedPro = newValue;
                              _lessonBalance = null; // 기존 잔여시간 정보 초기화
                            });
                            
                            if (newValue != null) {
                              await _loadLessonBalance();
                            }
                          },
                        ),
                      ),
                    ),
                    
                    // 잔여시간 정보 표시
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
                                    '${_lessonBalance!['balance_hours']}시간 ${_lessonBalance!['remaining_minutes']}분 (총 ${_lessonBalance!['balance_minutes']}분)',
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
                  ],
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
            ],
          ],
        ),
      ),
    );
  }
  
  // 2단계: 타석 선택
  Widget _buildTeeSelection() {
    final Color primaryColor = const Color(0xFF5D4037);
    
    // 선호 타석과 비선호 타석 분리
    List<int> preferredTees = _teePreferenceOrder.where((tee) => !_excludedTees.contains(tee)).toList();
    List<int> excludedTees = _teePreferenceOrder.where((tee) => _excludedTees.contains(tee)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선호 타석 섹션
        if (preferredTees.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade600, Colors.blue.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              spreadRadius: 0,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.reorder,
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
                              '선호 타석 우선순위',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '가운데 타석 카드를 드래그하여 순서 변경',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 3분할 구조
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1열: 순위 표시 (고정)
                    Container(
                      width: 50,
                      child: Column(
                        children: [
                          ...List.generate(preferredTees.length, (index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.3),
                                        spreadRadius: 0,
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 2열: 드래그 가능한 타석 카드
                    Expanded(
                      child: Column(
                        children: [
                          // 드래그 가능한 타석 리스트
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final int item = preferredTees.removeAt(oldIndex);
                                preferredTees.insert(newIndex, item);
                                
                                // 전체 우선순위 리스트 업데이트
                                _teePreferenceOrder = [...preferredTees, ...excludedTees];
                              });
                            },
                            children: List.generate(preferredTees.length, (index) {
                              final teeNumber = preferredTees[index];
                              final teeInfo = _teeInfo.firstWhere((tee) => tee['number'] == teeNumber);
                              
                              return Container(
                                key: ValueKey('tee_$teeNumber'),
                                margin: const EdgeInsets.only(bottom: 8),
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.grey.shade50],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade300, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.15),
                                      spreadRadius: 0,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      children: [
                                        // 타석 정보
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: teeInfo['color'],
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: teeInfo['color'].withOpacity(0.4),
                                                spreadRadius: 0,
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$teeNumber번',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: teeInfo['color'].withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: teeInfo['color'].withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            teeInfo['type'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: teeInfo['color'],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 3열: 비선호 체크박스 (고정)
                    Container(
                      width: 60,
                      child: Column(
                        children: [
                          ...List.generate(preferredTees.length, (index) {
                            final teeNumber = preferredTees[index];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setState(() {
                                      _excludedTees.add(teeNumber);
                                    });
                                  },
                                  child: Center(
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.red.shade50, Colors.red.shade100],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: Colors.red.shade300,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.2),
                                            spreadRadius: 0,
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.red.shade600,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        
        // 비선호 타석 섹션
        if (excludedTees.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.block,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '제외된 타석',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '예약에서 제외되는 타석들',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                ...excludedTees.map((teeNumber) {
                  final teeInfo = _teeInfo.firstWhere((tee) => tee['number'] == teeNumber);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 제외 표시
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                          ),
                          child: Text(
                            '제외됨',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // 타석 정보
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: teeInfo['color'],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: teeInfo['color'].withOpacity(0.4),
                                spreadRadius: 0,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$teeNumber번',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: teeInfo['color'].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: teeInfo['color'].withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            teeInfo['type'],
                            style: TextStyle(
                              fontSize: 10,
                              color: teeInfo['color'],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // 선호로 되돌리기 버튼
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _excludedTees.remove(teeNumber);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade500, Colors.green.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    spreadRadius: 0,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.restore,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '복원',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  // 3단계: 시간 선택
  Widget _buildTimeSelection() {
    final Color primaryColor = const Color(0xFF5D4037);
    final bool isLessonIncluded = _selectedReservationType == 'tee_lesson';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '루틴 예약 요일과 시간을 선택해주세요',
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
        
        // 타석+레슨 선택 시 안내 메시지 (더 컴팩트하게)
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
                    '타석 + 레슨 옵션을 선택하셨습니다.',
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
          Map<String, dynamic> times = _selectedTimes[dayId] ?? {};
          
          // 해당 요일이 선택되지 않았다면 빈 시간 정보로 초기화
          if (times.isEmpty) {
            times = {
              'start': TimeOfDay(hour: 9, minute: 0),
              'end': TimeOfDay(hour: 10, minute: 0),
            };
            
            if (isLessonIncluded) {
              times['lesson_start'] = TimeOfDay(hour: 9, minute: 0); // 타석 시작 시간과 동일하게 변경
              times['lesson_end'] = TimeOfDay(hour: 9, minute: 15); // 레슨 시작 시간 + 15분으로 변경
            }
          } else if (isLessonIncluded && times['lesson_start'] == null) {
            // 타석+레슨인데 레슨 시간이 없는 경우 추가
            final TimeOfDay teeStart = times['start'] ?? TimeOfDay(hour: 9, minute: 0);
            times['lesson_start'] = teeStart; // 타석 시작 시간과 동일하게 설정
            
            // 레슨 종료 시간은 레슨 시작 시간 + 15분
            int lessonEndMinute = teeStart.minute + 15;
            int lessonEndHour = teeStart.hour;
            if (lessonEndMinute >= 60) {
              lessonEndHour = (lessonEndHour + 1) % 24;
              lessonEndMinute -= 60;
            }
            times['lesson_end'] = TimeOfDay(hour: lessonEndHour, minute: lessonEndMinute);
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
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          day['name'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dayId == 0
                                ? Colors.red
                                : dayId == 6
                                    ? Colors.blue
                                    : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      day['fullName'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // 선택 토글 스위치 (더 작게)
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              // 새로운 요일 추가 시 기본 시간 설정
                              final TimeOfDay teeStart = TimeOfDay(hour: 9, minute: 0);
                              final TimeOfDay teeEnd = TimeOfDay(hour: 10, minute: 0);
                              
                              // 레슨 시작 시간은 타석 시작 시간과 동일하게 설정
                              final TimeOfDay lessonStart = teeStart;
                              
                              // 레슨 종료 시간은 시작 시간 + 프로별 최소예약시간으로 설정
                              int lessonEndMinute = lessonStart.minute;
                              int lessonEndHour = lessonStart.hour;
                              
                              // 프로별 최소예약시간 적용 (비동기 처리)
                              if (_selectedReservationType == 'tee_lesson' && _selectedPro != null) {
                                _getStaffServiceSettings(_selectedPro!).then((staffSettings) {
                                  final int minServiceMin = staffSettings['min_service_min']!;
                                  
                                  lessonEndMinute = lessonStart.minute + minServiceMin;
                                  lessonEndHour = lessonStart.hour;
                                  if (lessonEndMinute >= 60) {
                                    lessonEndHour = (lessonEndHour + 1) % 24;
                                    lessonEndMinute -= 60;
                                  }
                                  
                                  final TimeOfDay lessonEnd = TimeOfDay(hour: lessonEndHour, minute: lessonEndMinute);
                                  
                                  // 시간 정보 업데이트
                                  setState(() {
                                    _selectedTimes[dayId] = {
                                      'start': teeStart,
                                      'end': teeEnd,
                                      'lesson_start': lessonStart,
                                      'lesson_end': lessonEnd,
                                    };
                                  });
                                  
                                  if (kDebugMode) {
                                    print('⏰ [요일 활성화] ${day['fullName']} - 프로: $_selectedPro, 최소시간: ${minServiceMin}분');
                                    print('⏰ [요일 활성화] 레슨시간: ${_formatTimeOfDay(lessonStart)} ~ ${_formatTimeOfDay(lessonEnd)}');
                                  }
                                });
                              } else {
                                // 기본값 15분 적용 (프로가 선택되지 않은 경우)
                                lessonEndMinute = lessonStart.minute + 15;
                                if (lessonEndMinute >= 60) {
                                  lessonEndHour = (lessonEndHour + 1) % 24;
                                  lessonEndMinute -= 60;
                                }
                                final TimeOfDay lessonEnd = TimeOfDay(hour: lessonEndHour, minute: lessonEndMinute);
                                
                                // 시간 정보 설정
                                _selectedTimes[dayId] = {
                                  'start': teeStart,
                                  'end': teeEnd,
                                  'lesson_start': lessonStart,
                                  'lesson_end': lessonEnd,
                                };
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
                
                // 시간 선택 섹션 (선택된 요일만 표시, 더 컴팩트하게)
                if (isSelected) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  
                  // 타석 시간과 레슨 시간을 한 줄에 표시
                  if (isLessonIncluded) ...[
                    // 타석 + 레슨 시간을 세로로 배치하되 더 컴팩트하게
                    _buildCompactTimeSection(
                      icon: Icons.golf_course,
                      label: '타석',
                      color: primaryColor,
                      startTime: times['start'],
                      endTime: times['end'],
                      onStartTap: () => _showTimePickerForDay(dayId, isStart: true, isLesson: false),
                      onEndTap: () => _showTimePickerForDay(dayId, isStart: false, isLesson: false),
                    ),
                    const SizedBox(height: 6),
                    _buildCompactTimeSection(
                      icon: Icons.sports_golf,
                      label: '레슨',
                      color: Colors.green.shade700,
                      startTime: times['lesson_start'],
                      endTime: times['lesson_end'],
                      onStartTap: () => _showTimePickerForDay(dayId, isStart: true, isLesson: true),
                      onEndTap: () => _showTimePickerForDay(dayId, isStart: false, isLesson: true),
                    ),
                  ] else ...[
                    // 타석만 선택한 경우
                    _buildCompactTimeSection(
                      icon: Icons.golf_course,
                      label: '타석',
                      color: primaryColor,
                      startTime: times['start'],
                      endTime: times['end'],
                      onStartTap: () => _showTimePickerForDay(dayId, isStart: true, isLesson: false),
                      onEndTap: () => _showTimePickerForDay(dayId, isStart: false, isLesson: false),
                    ),
                  ],
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
  
  // 컴팩트한 시간 섹션 위젯
  Widget _buildCompactTimeSection({
    required IconData icon,
    required String label,
    required Color color,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required VoidCallback onStartTap,
    required VoidCallback onEndTap,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onStartTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatTimeOfDay(startTime),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '~',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: onEndTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatTimeOfDay(endTime),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 요일별 시간 선택 다이얼로그 - minuteInterval 변경
  void _showTimePickerForDay(
    int dayId, {
    bool isStart = true,
    bool isLesson = false,
  }) async {
    // 프로별 레슨 시간 설정 조회 (레슨 시간 선택인 경우만)
    Map<String, int> staffSettings = {'min_service_min': 15, 'staff_svc_time': 5};
    if (isLesson && _selectedPro != null) {
      staffSettings = await _getStaffServiceSettings(_selectedPro!);
    }
    
    final int minServiceMin = staffSettings['min_service_min']!;
    final int staffSvcTime = staffSettings['staff_svc_time']!;
    
    if (kDebugMode && isLesson) {
      print('⏰ [시간 선택] 프로: $_selectedPro, 최소시간: ${minServiceMin}분, 선택단위: ${staffSvcTime}분');
    }
    
    // 현재 설정값 가져오기
    final Map<String, dynamic> times = _selectedTimes[dayId] ?? {};
    
    // 타석 또는 레슨 시간의 필드명 결정
    final String fieldName = isLesson
        ? (isStart ? 'lesson_start' : 'lesson_end')
        : (isStart ? 'start' : 'end');
    
    // 관련된 다른 필드명도 결정
    final String relatedFieldName = isLesson
        ? (isStart ? 'lesson_end' : 'lesson_start')
        : (isStart ? 'end' : 'start');
    
    // 기존 시간값 가져오기
    final existingTime = times[fieldName];
    final relatedTime = times[relatedFieldName];
    
    // 타석 시간 범위 가져오기 (레슨 시간 선택 시 필요)
    final TimeOfDay? teeStart = times['start'];
    final TimeOfDay? teeEnd = times['end'];
    
    // 기본값 설정
    var initialTime = existingTime ?? (
      isLesson
          ? (isStart ? teeStart ?? TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: 9, minute: minServiceMin))
          : (isStart ? TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: 10, minute: 0))
    );
    
    // 레슨 시간 최소, 최대 설정 (타석 시간 내로 제한)
    DateTime? minimumDate;
    DateTime? maximumDate;
    
    if (isLesson && teeStart != null && teeEnd != null) {
      // 레슨 시작 시간 선택 시: 타석 시작 시간 ~ (타석 종료 시간 - 최소레슨시간)
      // 레슨 종료 시간 선택 시: (레슨 시작 시간 + 최소레슨시간) ~ 타석 종료 시간
      if (isStart) {
        minimumDate = DateTime(2022, 1, 1, teeStart.hour, teeStart.minute);
        
        // 타석 종료 시간 - 최소레슨시간
        int maxHour = teeEnd.hour;
        int maxMinute = teeEnd.minute - minServiceMin;
        if (maxMinute < 0) {
          maxHour = (maxHour - 1) % 24;
          maxMinute += 60;
        }
        maximumDate = DateTime(2022, 1, 1, maxHour, maxMinute);
      } else {
        final lessonStart = times['lesson_start'] as TimeOfDay;
        
        // 레슨 시작 시간 + 최소레슨시간
        int minHour = lessonStart.hour;
        int minMinute = lessonStart.minute + minServiceMin;
        if (minMinute >= 60) {
          minHour = (minHour + 1) % 24;
          minMinute -= 60;
        }
        minimumDate = DateTime(2022, 1, 1, minHour, minMinute);
        
        maximumDate = DateTime(2022, 1, 1, teeEnd.hour, teeEnd.minute);
      }
      
      // 최소/최대 날짜가 역전되는 경우 처리 (타석 시간이 최소레슨시간 이하인 극단적인 경우)
      if (minimumDate.isAfter(maximumDate)) {
        minimumDate = maximumDate;
      }
      
      // 초기값이 범위를 벗어나는 경우 조정
      final initialDateTime = DateTime(2022, 1, 1, initialTime.hour, initialTime.minute);
      if (initialDateTime.isBefore(minimumDate)) {
        initialTime = TimeOfDay(hour: minimumDate.hour, minute: minimumDate.minute);
      } else if (initialDateTime.isAfter(maximumDate)) {
        initialTime = TimeOfDay(hour: maximumDate.hour, minute: maximumDate.minute);
      }
    }
    
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('취소'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('확인'),
                      onPressed: () {
                        Navigator.of(context).pop(initialTime);
                      },
                    ),
                  ],
                ),
                const Divider(height: 0),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(
                      2022, 1, 1, 
                      initialTime.hour, 
                      initialTime.minute,
                    ),
                    onDateTimeChanged: (DateTime newDateTime) {
                      initialTime = TimeOfDay(
                        hour: newDateTime.hour,
                        minute: newDateTime.minute,
                      );
                    },
                    minimumDate: minimumDate,
                    maximumDate: maximumDate,
                    minuteInterval: isLesson ? staffSvcTime : 5, // 레슨인 경우 프로별 설정, 타석은 5분
                    use24hFormat: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      if (value != null && value is TimeOfDay) {
        setState(() {
          // 현재 요일의 시간 정보 가져오기 (없으면 새로 생성)
          Map<String, dynamic> updatedTimes = {...(times)};
          
          // 선택한 시간 업데이트
          updatedTimes[fieldName] = value;
          
          // 시작/종료 시간 자동 조정 로직
          if (!isLesson) {
            // 타석 시간이 변경된 경우
            if (isStart) {
              // 타석 시작 시간이 변경된 경우
              // 1) 타석 종료 시간 자동 조정 (1시간 후)
              final int endHour = (value.hour + 1) % 24;
              updatedTimes['end'] = TimeOfDay(hour: endHour, minute: value.minute);
              
              // 2) 레슨 시작 시간을 타석 시작 시간으로 자동 설정
              if (_selectedReservationType == 'tee_lesson') {
                updatedTimes['lesson_start'] = value;
                
                // 3) 레슨 종료 시간 조정 (레슨 시작 시간 + 최소레슨시간, 단 타석 종료 시간을 넘지 않도록)
                int lessonEndMinute = value.minute + minServiceMin;
                int lessonEndHour = value.hour;
                if (lessonEndMinute >= 60) {
                  lessonEndHour = (lessonEndHour + 1) % 24;
                  lessonEndMinute -= 60;
                }
                
                final TimeOfDay newTeeEnd = TimeOfDay(hour: endHour, minute: value.minute);
                final TimeOfDay calculatedLessonEnd = TimeOfDay(hour: lessonEndHour, minute: lessonEndMinute);
                
                // 레슨 종료 시간이 타석 종료 시간을 넘지 않도록 조정
                if (calculatedLessonEnd.hour > newTeeEnd.hour || 
                    (calculatedLessonEnd.hour == newTeeEnd.hour && calculatedLessonEnd.minute > newTeeEnd.minute)) {
                  updatedTimes['lesson_end'] = newTeeEnd;
                } else {
                  updatedTimes['lesson_end'] = calculatedLessonEnd;
                }
              }
            } else {
              // 타석 종료 시간이 변경된 경우
              final TimeOfDay startTime = updatedTimes['start'];
              
              // 타석 종료 시간이 시작 시간보다 이전이면 경고 및 조정
              if (value.hour < startTime.hour || 
                  (value.hour == startTime.hour && value.minute < startTime.minute)) {
                // 종료 시간을 시작 시간 + 1시간으로 조정
                final int endHour = (startTime.hour + 1) % 24;
                updatedTimes['end'] = TimeOfDay(hour: endHour, minute: startTime.minute);
                
                // 실제 적용할 종료 시간
                value = TimeOfDay(hour: endHour, minute: startTime.minute);
              }
              
              // 레슨 종료 시간이 새로운 타석 종료 시간을 넘지 않도록 조정
              if (_selectedReservationType == 'tee_lesson') {
                final TimeOfDay? lessonEnd = updatedTimes['lesson_end'];
                if (lessonEnd != null) {
                  if (lessonEnd.hour > value.hour || 
                      (lessonEnd.hour == value.hour && lessonEnd.minute > value.minute)) {
                    updatedTimes['lesson_end'] = value;
                  }
                }
              }
            }
          } else {
            // 레슨 시간이 변경된 경우 (사용자가 직접 선택)
            if (isStart) {
              // 레슨 시작 시간이 변경된 경우
              
              // 레슨 종료 시간 확인 (시작 시간 + 최소레슨시간 이후인지)
              final TimeOfDay? lessonEnd = updatedTimes['lesson_end'];
              
              if (lessonEnd != null) {
                int minEndMinute = value.minute + minServiceMin;
                int minEndHour = value.hour;
                if (minEndMinute >= 60) {
                  minEndHour = (minEndHour + 1) % 24;
                  minEndMinute -= 60;
                }
                
                bool isEndBeforeMin = 
                    lessonEnd.hour < minEndHour || 
                    (lessonEnd.hour == minEndHour && lessonEnd.minute < minEndMinute);
                
                if (isEndBeforeMin) {
                  // 레슨 종료 시간 조정 (시작 시간 + 최소레슨시간)
                  updatedTimes['lesson_end'] = TimeOfDay(hour: minEndHour, minute: minEndMinute);
                }
              }
            }
          }
          
          // 전체 맵 업데이트
          _selectedTimes[dayId] = updatedTimes;
        });
        
        // 디버깅 - 현재 선택 사항 출력
        _debugCurrentSelections();
      }
    });
  }
  
  // 4단계: 예약 내역 확인
  Widget _buildSummary() {
    final Color primaryColor = const Color(0xFF5D4037);
    
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
    
    final data = _analysisResult!['data'] as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
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
        
        // 날짜 목록
        ...details.asMap().entries.map((entry) {
          final index = entry.key;
          final detail = entry.value as Map<String, dynamic>;
          return _buildDateCard(detail, index, primaryColor);
        }).toList(),
        
        const SizedBox(height: 20),
        
        // 선택된 예약 요약
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
                
                // 표 헤더
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
                      Container(
                        width: 80,
                        child: Text(
                          '결제금액',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      if (_selectedReservationType == 'tee_lesson') ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 60,
                          child: Text(
                            '레슨시간',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                
                // 표 내용
                ...(_selectedReservations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reservation = entry.value;
                  final detail = reservation['detail'] as Map<String, dynamic>;
                  final teeInfo = detail['tee_info'] as Map<String, dynamic>;
                  final lessonInfo = detail['lesson_info'] as Map<String, dynamic>;
                  
                  // 최종 결제 금액 추출
                  int finalCost = 0;
                  if (teeInfo['assigned'] == true && teeInfo['cost_info'] != null) {
                    final costInfo = teeInfo['cost_info'] as Map<String, dynamic>;
                    finalCost = costInfo['final_cost'] ?? 0;
                  }
                  
                  // 레슨 시간 추출
                  int lessonDuration = 0;
                  if (_selectedReservationType == 'tee_lesson') {
                    lessonDuration = lessonInfo['duration'] ?? 0;
                  }
                  
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
                          child: Text(
                            '${reservation['date']} (${reservation['weekday']})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        // 결제 금액
                        Container(
                          width: 80,
                          child: Text(
                            '${_formatCurrency(finalCost)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        
                        // 레슨 시간 (레슨 예약인 경우만)
                        if (_selectedReservationType == 'tee_lesson') ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 60,
                            child: Text(
                              '${lessonDuration}분',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList()),
                
                // 합계 행
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    border: Border(
                      top: BorderSide(
                        color: primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 순번 자리
                      Container(
                        width: 30,
                        child: Icon(
                          Icons.calculate,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                      
                      // 합계 라벨
                      Expanded(
                        child: Text(
                          '합계',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // 총 결제 금액
                      Container(
                        width: 80,
                        child: Builder(
                          builder: (context) {
                            int totalCost = 0;
                            for (var reservation in _selectedReservations) {
                              final detail = reservation['detail'] as Map<String, dynamic>;
                              final teeInfo = detail['tee_info'] as Map<String, dynamic>;
                              if (teeInfo['assigned'] == true && teeInfo['cost_info'] != null) {
                                final costInfo = teeInfo['cost_info'] as Map<String, dynamic>;
                                totalCost += (costInfo['final_cost'] ?? 0) as int;
                              }
                            }
                            return Text(
                              '${_formatCurrency(totalCost)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                              textAlign: TextAlign.right,
                            );
                          },
                        ),
                      ),
                      
                      // 총 레슨 시간 (레슨 예약인 경우만)
                      if (_selectedReservationType == 'tee_lesson') ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 60,
                          child: Builder(
                            builder: (context) {
                              int totalLessonTime = 0;
                              for (var reservation in _selectedReservations) {
                                final detail = reservation['detail'] as Map<String, dynamic>;
                                final lessonInfo = detail['lesson_info'] as Map<String, dynamic>;
                                totalLessonTime += (lessonInfo['duration'] ?? 0) as int;
                              }
                              return Text(
                                '${totalLessonTime}분',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                                textAlign: TextAlign.right,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  // 선택된 예약 합계 정보 위젯
  Widget _buildSelectedReservationsSummary(Color primaryColor) {
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
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // 합계 라벨
          Icon(Icons.calculate, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            '합계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          
          const Spacer(),
          
          // 총 결제 금액
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatCurrency(totalCost)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              Text(
                '총 결제금액',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          // 총 레슨 시간 (레슨 예약인 경우만)
          if (_selectedReservationType == 'tee_lesson') ...[
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${totalLessonTime}분',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  '총 레슨시간',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  // 요약 아이템 위젯
  Widget _buildSummaryItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  // 날짜 카드 위젯
  Widget _buildDateCard(Map<String, dynamic> detail, int index, Color primaryColor) {
    final date = detail['date']?.toString() ?? '';
    final weekday = detail['weekday']?.toString() ?? '';
    final statusText = detail['status_text']?.toString() ?? '';
    final teeInfo = detail['tee_info'] as Map<String, dynamic>? ?? {};
    final lessonInfo = detail['lesson_info'] as Map<String, dynamic>? ?? {};
    final holidayInfo = detail['holiday_info'] as Map<String, dynamic>? ?? {};
    
    final bool isAvailable = statusText.contains('예약가능');
    final bool isTeeOnly = statusText.contains('타석만가능');
    final bool isSelected = _selectedReservations.any((r) => r['date'] == date);
    
    // 선택 가능한지 확인 (예약가능 또는 타석만가능)
    final bool canSelect = isAvailable || isTeeOnly;
    
    Color statusColor;
    IconData statusIcon;
    String displayStatusText;
    
    if (isAvailable) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      displayStatusText = '타석+레슨 가능';
    } else if (isTeeOnly) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      displayStatusText = '타석만 가능';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      displayStatusText = '예약 불가';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canSelect ? () => _toggleReservationSelection(detail) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 (날짜, 요일, 상태)
                Row(
                  children: [
                    // 순번
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 날짜 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$date ($weekday)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (holidayInfo['is_holiday'] == true)
                            Text(
                              '🎌 공휴일',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // 상태 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            displayStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 선택 체크박스
                    if (canSelect) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                  ],
                ),
                
                // 타석 정보
                if (teeInfo['assigned'] == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1열: 타석 정보
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.golf_course, size: 14, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '타석',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${teeInfo['assigned_ts_id']}번',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                '${teeInfo['start_time']}-${teeInfo['end_time']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 2열: 금액 정보
                        if (teeInfo['cost_info'] != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.attach_money, size: 14, color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      '금액',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildCompactCostInfo(teeInfo['cost_info']),
                              ],
                            ),
                          ),
                        ],
                        
                        // 3열: 레슨 정보
                        if (_selectedReservationType == 'tee_lesson') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.sports_golf, size: 14, color: Colors.orange.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      '레슨',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lessonInfo['duration'] > 0
                                      ? '${lessonInfo['duration']}분'
                                      : '불가',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: lessonInfo['duration'] > 0 
                                        ? Colors.orange.shade700 
                                        : Colors.red.shade600,
                                  ),
                                ),
                                if (lessonInfo['duration'] <= 0)
                                  Text(
                                    lessonInfo['reason'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // 타석 배정 불가인 경우
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '타석 배정 불가',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
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
      ),
    );
  }
  
  // 컴팩트한 비용 정보 위젯
  Widget _buildCompactCostInfo(Map<String, dynamic> costInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기본 금액
        Text(
          '기본: ${_formatCurrency(costInfo['base_cost'])}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        // 등록회원 할인
        Text(
          '등록회원할인: -${_formatCurrency(costInfo['member_discount'])}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        // 집중연습할인 (있는 경우만)
        if (costInfo['time_discount'] != null && costInfo['time_discount'] > 0)
          Text(
            '집중연습할인: -${_formatCurrency(costInfo['time_discount'])}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        // 기간권 할인 (있는 경우만)
        if (costInfo['term_discount'] != null && costInfo['term_discount'] > 0)
          Text(
            '기간권할인: -${_formatCurrency(costInfo['term_discount'])}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 2),
        // 최종 결제 금액
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '결제: ${_formatCurrency(costInfo['final_cost'])}',
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
    final Color primaryColor = const Color(0xFF5D4037);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '결제 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '결제 전후 잔액 현황을 확인하고 결제를 진행해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        
        // 잔액 정보 섹션
        if (_selectedReservations.isNotEmpty) ...[
          _buildBalanceInfoSection(primaryColor),
          const SizedBox(height: 20),
        ],
        
        // 결제 방법 선택 (추후 구현)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '결제 방법',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '결제 방법 선택 기능은 추후 구현 예정입니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
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
        return '다음';
      case 3:
        return '결제하기';
      case 4:
        return '결제하기';
      default:
        return '';
    }
  }

  bool _getNextButtonEnabled() {
    switch (_currentStep) {
      case 0:
        // 기본 조건: 예약 종류와 횟수 선택
        bool basicCondition = _selectedReservationType != null && _selectedFrequency != null;
        
        // 레슨 예약인 경우 프로 선택도 필요
        if (_selectedReservationType == 'tee_lesson') {
          return basicCondition && _selectedPro != null;
        }
        
        return basicCondition;
      case 1:
        return _selectedReservationType != null && _selectedFrequency != null;
      case 2:
        return _selectedTimes.isNotEmpty;
      case 3:
        return _selectedReservations.isNotEmpty;
      case 4:
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
      
      // 선택 가능한 모든 예약을 추가 (예약가능 또는 타석만가능)
      for (var detail in details) {
        final statusText = detail['status_text'] as String;
        final bool isAvailable = statusText.contains('예약가능');
        final bool isTeeOnly = statusText.contains('타석만가능');
        final bool canSelect = isAvailable || isTeeOnly;
        
        if (canSelect) {
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
      print('💳 [결제 완료] 시작');
    }

    try {
      // 할인 금액 계산
      int discount = 0;
      if (_selectedFrequency != null) {
        final frequencyOption = _frequencyOptions.firstWhere(
          (option) => option['count'] == _selectedFrequency,
          orElse: () => {'discount': 0},
        );
        discount = frequencyOption['discount'] ?? 0;
      }

      // 루틴 타입 결정
      String routineType = _selectedReservationType == 'tee_lesson' ? 'TS+LS' : 'TS';

      // 시작일과 종료일 계산
      _selectedReservations.sort((a, b) => a['date'].compareTo(b['date']));
      String startDate = _selectedReservations.first['date'];
      String endDate = _selectedReservations.last['date'];

      // 현재 날짜
      String registerDate = DateTime.now().toIso8601String().split('T')[0];

      // v2_routine_discount 테이블에 추가할 데이터
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final routineData = {
        'member_id': _safeToInt(widget.memberId),
        'routine_discount': discount,
        'routine_reservation_status': '예약완료',
        'routine_type': routineType,
        'routine_register_date': registerDate,
        'routine_start_date': startDate,
        'routine_end_date': endDate,
        'routine_reservation_days': _selectedReservations.length,
        'timestamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        'branch_id': userProvider.currentBranchId, // branch_id 추가
      };

      if (kDebugMode) {
        print('💳 [결제 완료] v2_routine_discount 추가 데이터: ${jsonEncode(routineData)}');
      }

      // 1단계: v2_routine_discount 테이블에 루틴 정보 등록
      final routineResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'add',
          'table': 'v2_routine_discount',
          'data': routineData,
        }),
      );

      if (kDebugMode) {
        print('💳 [결제 완료] 루틴 등록 API 응답 상태: ${routineResponse.statusCode}');
        print('💳 [결제 완료] 루틴 등록 API 응답 내용: ${routineResponse.body}');
      }

      if (routineResponse.statusCode != 200) {
        throw Exception('루틴 등록 서버 오류: ${routineResponse.statusCode}');
      }

      final routineResult = jsonDecode(utf8.decode(routineResponse.bodyBytes));
      
      if (routineResult['success'] != true) {
        throw Exception(routineResult['error'] ?? '루틴 등록 실패');
      }

      final routineId = _safeToInt(routineResult['insertId']);
      
      if (kDebugMode) {
        print('✅ [결제 완료] 루틴 등록 성공 - routine_id: $routineId');
      }

      // 회원 정보 조회
      String memberName = '';
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
                'value': widget.memberId.toString()
              }
            ],
            'limit': 1
          }),
        );

        if (memberResponse.statusCode == 200) {
          final memberResult = jsonDecode(utf8.decode(memberResponse.bodyBytes));
          
          if (memberResult['success'] == true && memberResult['data'].isNotEmpty) {
            final memberData = memberResult['data'][0];
            memberName = memberData['member_name'] ?? '';
            memberPhone = memberData['member_phone'] ?? '';
            
            if (kDebugMode) {
              print('✅ [결제 완료] 회원 정보 조회 성공 - 이름: $memberName, 전화번호: $memberPhone');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [결제 완료] 회원 정보 조회 실패: $e');
        }
        // 회원 정보 조회 실패해도 계속 진행
      }

      // 2단계: 각 날짜별로 v2_priced_TS 테이블에 타석 예약 정보 등록
      List<String> failedReservations = [];
      int successCount = 0;

      for (var reservation in _selectedReservations) {
        try {
          final detail = reservation['detail'] as Map<String, dynamic>;
          final teeInfo = detail['tee_info'] as Map<String, dynamic>;
          
          if (teeInfo['assigned'] != true || teeInfo['cost_info'] == null) {
            if (kDebugMode) {
              print('⚠️ [결제 완료] 타석 배정되지 않은 날짜 건너뛰기: ${reservation['date']}');
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

          // 중복 예약 확인
          final duplicateCheckResponse = await http.post(
            Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'operation': 'get',
              'table': 'v2_priced_TS',
              'fields': ['reservation_id'],
              'where': [
                {
                  'field': 'reservation_id',
                  'operator': '=',
                  'value': reservationId
                }
              ],
              'limit': 1
            }),
          );

          if (duplicateCheckResponse.statusCode == 200) {
            final duplicateResult = jsonDecode(utf8.decode(duplicateCheckResponse.bodyBytes));
            
            if (duplicateResult['success'] == true && duplicateResult['data'] != null && duplicateResult['data'].isNotEmpty) {
              // 이미 존재하는 예약 ID
              if (kDebugMode) {
                print('⚠️ [결제 완료] 중복 예약 ID 발견, 건너뛰기 (${reservation['date']}): $reservationId');
              }
              continue; // 다음 예약으로 넘어감
            }
          }

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
            'ts_type': '일반(루틴)',
            'ts_payment_method': 'credit',
            'ts_status': '결제완료',
            'member_id': _safeToInt(widget.memberId),
            'member_name': memberName,
            'member_phone': memberPhone,
            'total_amt': _safeToInt(costInfo['base_cost']),
            'term_discount': _safeToInt(costInfo['term_discount']),
            'member_discount': _safeToInt(costInfo['member_discount']),
            'junior_discount': 0,
            'routine_discount': 0, // 개별 예약에는 0, 루틴 할인은 v2_routine_discount에서 관리
            'overtime_discount': _safeToInt(costInfo['time_discount']), // 집중연습할인
            'revisit_discount': 0,
            'emergency_discount': 0,
            'emergency_reason': '',
            'total_discount': _safeToInt(costInfo['member_discount']) + _safeToInt(costInfo['term_discount']) + _safeToInt(costInfo['time_discount']),
            'net_amt': _safeToInt(costInfo['final_cost']),
            'morning': morningMinutes,
            'normal': normalMinutes,
            'peak': peakMinutes,
            'night': nightMinutes,
            'time_stamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
            'routine_id': routineId,
            'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
          };

          if (kDebugMode) {
            print('💳 [결제 완료] 타석 예약 데이터 (${reservation['date']}): ${jsonEncode(teeReservationData)}');
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
            print('💳 [결제 완료] 타석 예약 API 응답 상태 (${reservation['date']}): ${teeResponse.statusCode}');
            print('💳 [결제 완료] 타석 예약 API 응답 내용 (${reservation['date']}): ${teeResponse.body}');
          }

          if (teeResponse.statusCode == 200) {
            final teeResult = jsonDecode(utf8.decode(teeResponse.bodyBytes));
            
            if (teeResult['success'] == true) {
              successCount++;
              if (kDebugMode) {
                print('✅ [결제 완료] 타석 예약 성공 (${reservation['date']}): reservation_id=${reservationId}');
              }
              
              // 레슨 예약인 경우 v2_LS_orders 테이블에도 레슨 데이터 추가
              if (_selectedReservationType == 'tee_lesson') {
                await _addLessonReservation(reservation, routineId, memberName);
              }
              
            } else {
              failedReservations.add('${reservation['date']}: ${teeResult['error'] ?? '알 수 없는 오류'}');
              if (kDebugMode) {
                print('❌ [결제 완료] 타석 예약 실패 (${reservation['date']}): ${teeResult['error']}');
              }
            }
          } else {
            failedReservations.add('${reservation['date']}: HTTP 오류 ${teeResponse.statusCode}');
            if (kDebugMode) {
              print('❌ [결제 완료] 타석 예약 HTTP 오류 (${reservation['date']}): ${teeResponse.statusCode}');
            }
          }

        } catch (e) {
          failedReservations.add('${reservation['date']}: $e');
          if (kDebugMode) {
            print('❌ [결제 완료] 타석 예약 예외 오류 (${reservation['date']}): $e');
          }
        }
      }

      // 결과 다이얼로그 표시
      if (failedReservations.isEmpty) {
        // 모든 예약 성공 - v2_bills 테이블 업데이트 진행
        await _updateBillsTable(routineId, successCount, discount);
        
        // 성공 다이얼로그 표시
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
                Text('루틴 예약이 성공적으로 등록되었습니다.'),
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
                      Text('• 예약 종류: ${_selectedReservationType == 'tee_lesson' ? '타석 + 레슨' : '타석만'}'),
                      Text('• 성공한 예약: ${successCount}회'),
                      Text('• 루틴 할인: ${_formatCurrency(discount)}'),
                      Text('• 기간: $startDate ~ $endDate'),
                      Text('• 루틴 ID: $routineId'),
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
        // 일부 실패 - 성공한 예약에 대해서만 v2_bills 테이블 업데이트
        if (successCount > 0) {
          await _updateBillsTable(routineId, successCount, discount);
        }
        
        // 부분 성공 다이얼로그 표시
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
                Text('루틴 등록은 완료되었으나 일부 타석 예약에 실패했습니다.'),
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
                      Text('• 성공한 예약: ${successCount}회'),
                      Text('• 실패한 예약: ${failedReservations.length}회'),
                      Text('• 루틴 ID: $routineId'),
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
        print('✅ [결제 완료] 전체 처리 완료 - 성공: ${successCount}건, 실패: ${failedReservations.length}건');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [결제 완료] 전체 처리 오류: $e');
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
          content: Text('결제 처리 중 오류가 발생했습니다.\n\n$e'),
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

  // v2_bills 테이블 업데이트 함수
  Future<void> _updateBillsTable(int routineId, int successCount, int routineDiscount) async {
    if (kDebugMode) {
      print('💰 [Bills 업데이트] 시작 - routineId: $routineId, 성공 예약: ${successCount}개, 루틴할인: $routineDiscount');
    }

    try {
      // 1. 현재 회원의 최신 잔액 조회
      int currentBalance = await _getCurrentBalance();
      
      if (kDebugMode) {
        print('💰 [Bills 업데이트] 현재 잔액: $currentBalance');
      }

      // 2. 성공한 예약들을 날짜순으로 정렬
      List<Map<String, dynamic>> successfulReservations = [];
      for (var reservation in _selectedReservations) {
        final detail = reservation['detail'] as Map<String, dynamic>;
        final teeInfo = detail['tee_info'] as Map<String, dynamic>;
        
        if (teeInfo['assigned'] == true && teeInfo['cost_info'] != null) {
          successfulReservations.add(reservation);
        }
      }
      
      successfulReservations.sort((a, b) => a['date'].compareTo(b['date']));

      // 3. 각 날짜별 타석이용 기록 추가
      int runningBalance = currentBalance;
      
      for (var reservation in successfulReservations) {
        final detail = reservation['detail'] as Map<String, dynamic>;
        final teeInfo = detail['tee_info'] as Map<String, dynamic>;
        final costInfo = teeInfo['cost_info'] as Map<String, dynamic>;
        
        final date = reservation['date'];
        final tsId = _safeToInt(teeInfo['ts_id']);
        final startTime = teeInfo['start_time'];
        final endTime = teeInfo['end_time'];
        
        // reservation_id 생성
        final dateParts = date.split('-');
        final year = dateParts[0].substring(2);
        final month = dateParts[1];
        final day = dateParts[2];
        final timeParts = startTime.split(':');
        final hour = timeParts[0];
        final minute = timeParts[1];
        final reservationId = '${year}${month}${day}_${tsId}_${hour}${minute}';

        // 금액 계산
        final totalAmt = -_safeToInt(costInfo['base_cost']); // 음수
        final deduction = _safeToInt(costInfo['member_discount']) + _safeToInt(costInfo['term_discount']) + _safeToInt(costInfo['time_discount']); // 양수
        final netAmt = -_safeToInt(costInfo['final_cost']); // 음수
        
        final billBalanceBefore = runningBalance;
        final billBalanceAfter = runningBalance + netAmt; // netAmt가 음수이므로 잔액 감소
        runningBalance = billBalanceAfter;

        // bill_text 생성
        final billText = '${tsId}번 타석(${startTime.substring(0, 5)} ~ ${endTime.substring(0, 5)})';

        final billData = {
          'member_id': _safeToInt(widget.memberId),
          'bill_date': date,
          'bill_type': '타석이용',
          'bill_text': billText,
          'bill_totalamt': totalAmt,
          'bill_deduction': deduction,
          'bill_netamt': netAmt,
          'bill_timestamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
          'bill_balance_before': billBalanceBefore,
          'bill_balance_after': billBalanceAfter,
          'reservation_id': reservationId,
          'bill_status': '결제완료',
          'routine_id': routineId,
          'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
        };

        if (kDebugMode) {
          print('💰 [Bills 업데이트] 타석이용 기록 ($date): ${jsonEncode(billData)}');
        }

        // API 호출
        final response = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'operation': 'add',
            'table': 'v2_bills',
            'data': billData,
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('타석이용 기록 등록 실패 ($date): HTTP ${response.statusCode}');
        }

        final result = jsonDecode(utf8.decode(response.bodyBytes));
        if (result['success'] != true) {
          throw Exception('타석이용 기록 등록 실패 ($date): ${result['error']}');
        }

        if (kDebugMode) {
          print('✅ [Bills 업데이트] 타석이용 기록 성공 ($date): bill_id=${result['insertId']}');
        }
      }

      // 4. 루틴할인 기록 추가 (할인이 있는 경우만)
      if (routineDiscount > 0) {
        final registerDate = DateTime.now().toIso8601String().split('T')[0];
        
        final billBalanceBefore = runningBalance;
        final billBalanceAfter = runningBalance + routineDiscount; // 할인은 크레딧 증가
        
        final routineDiscountBillData = {
          'member_id': _safeToInt(widget.memberId),
          'bill_date': registerDate,
          'bill_type': '루틴할인',
          'bill_text': '루틴할인(${successCount}회)',
          'bill_totalamt': 0,
          'bill_deduction': 0,
          'bill_netamt': routineDiscount, // 양수 (크레딧 증가)
          'bill_timestamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
          'bill_balance_before': billBalanceBefore,
          'bill_balance_after': billBalanceAfter,
          'reservation_id': '',
          'bill_status': '결제완료',
          'routine_id': routineId,
          'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
        };

        if (kDebugMode) {
          print('💰 [Bills 업데이트] 루틴할인 기록: ${jsonEncode(routineDiscountBillData)}');
        }

        // API 호출
        final response = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'operation': 'add',
            'table': 'v2_bills',
            'data': routineDiscountBillData,
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('루틴할인 기록 등록 실패: HTTP ${response.statusCode}');
        }

        final result = jsonDecode(utf8.decode(response.bodyBytes));
        if (result['success'] != true) {
          throw Exception('루틴할인 기록 등록 실패: ${result['error']}');
        }

        if (kDebugMode) {
          print('✅ [Bills 업데이트] 루틴할인 기록 성공: bill_id=${result['insertId']}');
        }
      }

      if (kDebugMode) {
        print('✅ [Bills 업데이트] 전체 완료 - 최종 잔액: ${runningBalance}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [Bills 업데이트] 오류: $e');
      }
      // Bills 업데이트 실패는 로그만 남기고 계속 진행
    }
  }

  // 현재 회원의 최신 잔액 조회
  Future<int> _getCurrentBalance() async {
    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_bills',
          'fields': ['bill_balance_after'],
          'where': [
            {
              'field': 'member_id',
              'operator': '=',
              'value': widget.memberId.toString()
            }
          ],
          'orderBy': [
            {
              'field': 'bill_id',
              'direction': 'DESC'
            }
          ],
          'limit': 1
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          return _safeToInt(result['data'][0]['bill_balance_after']);
        }
      }
      
      return 0; // 기본값
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [getCurrentBalance] 오류: $e');
      }
      return 0; // 오류 시 기본값
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

  // 레슨 예약 추가 함수
  Future<void> _addLessonReservation(Map<String, dynamic> reservation, int routineId, String memberName) async {
    try {
      final detail = reservation['detail'] as Map<String, dynamic>;
      final lessonInfo = detail['lesson_info'] as Map<String, dynamic>;
      final date = reservation['date'];
      
      // 레슨이 가능한 경우만 처리
      if (lessonInfo['available'] != true) {
        if (kDebugMode) {
          print('⚠️ [레슨 예약] 레슨 불가능한 날짜 건너뛰기: $date');
        }
        return;
      }

      // 강사 닉네임 조회 (Staff 테이블에서)
      String staffNickname = await _getStaffNickname(_selectedPro ?? '');
      
      // 레슨 시간 정보 가져오기
      String lessonStartTime = '';
      String lessonEndTime = '';
      int lessonDuration = lessonInfo['duration'] ?? 0;
      
      // _selectedTimes에서 해당 날짜의 레슨 시간 찾기
      final weekdayMap = {
        '일요일': 0, '월요일': 1, '화요일': 2, '수요일': 3, 
        '목요일': 4, '금요일': 5, '토요일': 6
      };
      
      final weekday = reservation['weekday'];
      final dayId = weekdayMap[weekday];
      
      if (dayId != null && _selectedTimes.containsKey(dayId)) {
        final times = _selectedTimes[dayId]!;
        if (times['lesson_start'] != null && times['lesson_end'] != null) {
          lessonStartTime = '${_formatTimeOfDay(times['lesson_start'])}:00';
          lessonEndTime = '${_formatTimeOfDay(times['lesson_end'])}:00';
        }
      }

      // LS_id 생성 (yymmdd_staff_nickname_hhmm)
      final dateParts = date.split('-');
      final year = dateParts[0].substring(2);
      final month = dateParts[1];
      final day = dateParts[2];
      final timeParts = lessonStartTime.split(':');
      final hour = timeParts[0];
      final minute = timeParts[1];
      final lessonId = '${year}${month}${day}_${staffNickname}_${hour}${minute}';

      // 레슨 예약 데이터 생성
      final lessonReservationData = {
        'LS_id': lessonId,
        'LS_transaction_type': '레슨예약',
        'LS_date': date,
        'member_id': _safeToInt(widget.memberId),
        'LS_status': '결제완료',
        'member_name': memberName,
        'member_type': '일반',
        'LS_type': '일반(루틴)',
        'LS_contract_pro': _selectedPro ?? '',
        'LS_order_source': 'web-app',
        'LS_start_time': lessonStartTime,
        'LS_end_time': lessonEndTime,
        'LS_net_min': lessonDuration,
        'updated_at': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
        'TS_id': _safeToInt(detail['tee_info']['ts_id']),
        'routine_id': routineId,
      };

      if (kDebugMode) {
        print('💳 [레슨 예약] 레슨 예약 데이터 ($date): ${jsonEncode(lessonReservationData)}');
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
        print('💳 [레슨 예약] 레슨 예약 API 응답 상태 ($date): ${lessonResponse.statusCode}');
        print('💳 [레슨 예약] 레슨 예약 API 응답 내용 ($date): ${lessonResponse.body}');
      }

      if (lessonResponse.statusCode == 200) {
        final lessonResult = jsonDecode(utf8.decode(lessonResponse.bodyBytes));
        
        if (lessonResult['success'] == true) {
          if (kDebugMode) {
            print('✅ [레슨 예약] 레슨 예약 성공 ($date): LS_id=${lessonId}');
          }
          
          // 레슨 예약 성공 후 v3_LS_countings 테이블에 레슨 사용 기록 추가
          await _addLessonCounting(date, lessonId, lessonDuration, memberName);
          
        } else {
          if (kDebugMode) {
            print('❌ [레슨 예약] 레슨 예약 실패 ($date): ${lessonResult['error']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ [레슨 예약] 레슨 예약 HTTP 오류 ($date): ${lessonResponse.statusCode}');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨 예약] 레슨 예약 예외 오류 (${reservation['date']}): $e');
      }
    }
  }

  // 강사 닉네임 조회 함수
  Future<String> _getStaffNickname(String staffName) async {
    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_staff_pro',
          'fields': ['staff_nickname'],
          'where': [
            {
              'field': 'pro_name',
              'operator': '=',
              'value': staffName
            }
          ],
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
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final whereConditions = [
        {
          'field': 'pro_name',
          'operator': '=',
          'value': staffName
        }
      ];
      
      // branch_id 조건 추가
      if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': userProvider.currentBranchId!
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
  Future<void> _addLessonCounting(String date, String lessonId, int lessonDuration, String memberName) async {
    try {
      if (kDebugMode) {
        print('📊 [레슨 카운팅] 시작 - 날짜: $date, LS_id: $lessonId, 사용시간: ${lessonDuration}분');
      }

      // 1. 해당 회원의 해당 프로에 대한 최신 잔여시간 조회
      int balanceMinBefore = await _getLatestLessonBalance();
      
      if (kDebugMode) {
        print('📊 [레슨 카운팅] 사용 전 잔여시간: ${balanceMinBefore}분');
      }

      // 2. 사용 후 잔여시간 계산
      int balanceMinAfter = balanceMinBefore - lessonDuration;
      
      if (kDebugMode) {
        print('📊 [레슨 카운팅] 사용 후 잔여시간: ${balanceMinAfter}분');
      }

      // 3. v3_LS_countings 데이터 생성
      final countingData = {
        'LS_transaction_type': '레슨예약(루틴)',
        'LS_date': date,
        'member_id': _safeToInt(widget.memberId),
        'member_name': memberName,
        'member_type': '일반',
        'LS_status': '결제완료',
        'LS_type': '일반레슨',
        'LS_id': lessonId,
        'LS_contract_pro': _selectedPro ?? '',
        'LS_balance_min_before': balanceMinBefore,
        'LS_net_min': lessonDuration,
        'LS_balance_min_after': balanceMinAfter,
        'LS_counting_source': 'v2_LS_orders',
        'updated_at': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId, // branch_id 추가
      };

      if (kDebugMode) {
        print('📊 [레슨 카운팅] 카운팅 데이터: ${jsonEncode(countingData)}');
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
        print('📊 [레슨 카운팅] API 응답 상태: ${response.statusCode}');
        print('📊 [레슨 카운팅] API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true) {
          if (kDebugMode) {
            print('✅ [레슨 카운팅] 레슨 사용 기록 성공: LS_counting_id=${result['insertId']}');
          }
        } else {
          if (kDebugMode) {
            print('❌ [레슨 카운팅] 레슨 사용 기록 실패: ${result['error']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ [레슨 카운팅] HTTP 오류: ${response.statusCode}');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ [레슨 카운팅] 예외 오류: $e');
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
          'value': widget.memberId.toString()
        },
        {
          'field': 'LS_contract_pro',
          'operator': '=',
          'value': _selectedPro ?? ''
        },
        {
          'field': 'LS_type',
          'operator': '=',
          'value': '일반레슨'
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
        print('⚠️ [최신 레슨 잔여시간 조회] 오류: $e');
      }
      return 0;
    }
  }
} 