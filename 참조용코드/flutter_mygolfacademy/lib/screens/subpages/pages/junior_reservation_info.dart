import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../../../services/junior_lesson_cancellation_service.dart'; // 주니어 레슨 취소 서비스 import

class JuniorReservationInfoScreen extends StatefulWidget {
  final int? memberId;
  
  const JuniorReservationInfoScreen({Key? key, this.memberId}) : super(key: key);

  @override
  State<JuniorReservationInfoScreen> createState() => _JuniorReservationInfoScreenState();
}

class _JuniorReservationInfoScreenState extends State<JuniorReservationInfoScreen> {
  List<dynamic> _juniorData = [];
  List<dynamic> _lessonData = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showPastReservations = false; // 과거 예약 표시 여부

  @override
  void initState() {
    super.initState();
    _fetchJuniorData();
  }

  // v2_junior_relation 테이블에서 주니어 회원 정보 가져오기
  Future<void> _fetchJuniorData() async {
    if (widget.memberId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인 정보가 없습니다';
      });
      return;
    }

    try {
      // API 서버 URL
      const String apiUrl = 'https://autofms.mycafe24.com/dynamic_api.php';
      
      // 요청 데이터 구성
      final Map<String, dynamic> payload = {
        'operation': 'get',
        'table': 'v2_junior_relation',
        'fields': ['member_id', 'junior_member_id', 'junior_name'],
        'where': [
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId.toString()
          }
        ],
        'limit': 10
      };

      if (kDebugMode) {
        print('주니어 정보 API 요청 데이터: ${jsonEncode(payload)}');
      }

      // HTTP POST 요청 보내기
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('주니어 정보 API 응답: ${response.body}');
        }

        if (responseData['success'] == true) {
          setState(() {
            _juniorData = responseData['data'] ?? [];
          });
          
          // 주니어 회원 정보가 있으면 각 주니어 회원 ID로 레슨 예약 정보 조회
          if (_juniorData.isNotEmpty) {
            for (var junior in _juniorData) {
              await _fetchLessonData(junior['junior_member_id']);
            }
          }
          
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = responseData['error'] ?? '데이터를 가져오는데 실패했습니다';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '서버 응답 오류: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '데이터 요청 중 오류 발생: $e';
      });
      if (kDebugMode) {
        print('주니어 정보 조회 오류: $e');
      }
    }
  }
  
  // 주니어 회원 ID를 이용하여 v2_LS_orders 테이블에서 레슨 예약 정보 가져오기
  Future<void> _fetchLessonData(dynamic juniorMemberId) async {
    if (juniorMemberId == null) return;
    
    try {
      // API 서버 URL
      const String apiUrl = 'https://autofms.mycafe24.com/dynamic_api.php';
      
      // 요청 데이터 구성 (junior_member_id를 member_id로 사용)
      final Map<String, dynamic> payload = {
        'operation': 'get',
        'table': 'v2_LS_orders',
        'fields': [
          'member_id',
          'LS_id',
          'LS_set_id',
          'LS_type',
          'LS_date',
          'LS_contract_pro',
          'LS_start_time',
          'LS_end_time',
          'LS_status',
          'LS_net_min',
          'TS_id'
        ],
        'where': [
          {
            'field': 'member_id',
            'operator': '=',
            'value': juniorMemberId.toString()
          }
        ],
        'limit': 50
      };

      if (kDebugMode) {
        print('레슨 예약 API 요청 데이터: ${jsonEncode(payload)}');
      }

      // HTTP POST 요청 보내기
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('레슨 예약 API 응답: ${response.body}');
        }

        if (responseData['success'] == true) {
          final lessonData = responseData['data'] ?? [];
          
          // 주니어 이름 추가
          final juniorName = _juniorData.firstWhere(
            (junior) => junior['junior_member_id'].toString() == juniorMemberId.toString(),
            orElse: () => {}
          )['junior_name'] ?? '';
          
          // 각 레슨 데이터에 주니어 이름 추가
          for (var lesson in lessonData) {
            lesson['junior_name'] = juniorName;
          }
          
          setState(() {
            // 기존 데이터에 추가
            _lessonData.addAll(lessonData);
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('레슨 예약 정보 조회 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // 매우 연한 회색 배경
      appBar: AppBar(
        title: const Text(
          '주니어 레슨 예약 내역',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _lessonData = [];
                _juniorData = [];
                _errorMessage = null;
              });
              _fetchJuniorData();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '데이터를 불러오는 중입니다',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _juniorData.isEmpty
                  ? _buildEmptyJuniorView()
                  : _lessonData.isEmpty
                      ? _buildEmptyLessonView()
                      : _buildLessonList(),
    );
  }

  Widget _buildErrorView() {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.red.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '데이터를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _errorMessage ?? '알 수 없는 오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _lessonData = [];
                    _juniorData = [];
                    _errorMessage = null;
                  });
                  _fetchJuniorData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyJuniorView() {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.person_search,
                size: 80,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '주니어 회원 정보가 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
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
                '등록된 주니어 회원이 없습니다. 주니어 회원을 등록해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLessonView() {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.history_edu,
                size: 80,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '레슨 예약 내역이 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
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
                '주니어 회원의 레슨 예약 내역이 없습니다. 레슨을 예약하고 골프 실력을 향상시켜보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList() {
    // LS_set_id 기준으로 레슨 데이터 그룹화
    Map<String, List<Map<String, dynamic>>> lessonGroups = {};
    
    // 데이터를 Map<String, dynamic>으로 변환하고 그룹화
    for (var lesson in _lessonData) {
      final Map<String, dynamic> lessonMap = Map<String, dynamic>.from(lesson);
      final String setId = lessonMap['LS_set_id'] != null ? lessonMap['LS_set_id'].toString() : lessonMap['LS_id'].toString();
      
      if (lessonGroups.containsKey(setId)) {
        lessonGroups[setId]!.add(lessonMap);
      } else {
        lessonGroups[setId] = [lessonMap];
      }
    }
    
    // 그룹화된 레슨 데이터를 합치기
    List<Map<String, dynamic>> mergedLessons = [];
    
    lessonGroups.forEach((setId, lessons) {
      if (lessons.length == 1 || setId == 'null') {
        // 단일 레슨 또는 세트 ID가 없는 경우 그대로 추가
        mergedLessons.addAll(lessons);
      } else {
        // 여러 레슨이 같은 세트 ID를 가진 경우 병합
        Map<String, dynamic> mergedLesson = Map<String, dynamic>.from(lessons.first);
        
        // 가장 빠른 시작 시간과 가장 늦은 종료 시간 찾기
        String earliestStartTime = lessons.first['LS_start_time'];
        String latestEndTime = lessons.first['LS_end_time'];
        
        for (var lesson in lessons) {
          String startTime = lesson['LS_start_time'];
          String endTime = lesson['LS_end_time'];
          
          if (startTime.compareTo(earliestStartTime) < 0) {
            earliestStartTime = startTime;
          }
          
          if (endTime.compareTo(latestEndTime) > 0) {
            latestEndTime = endTime;
          }
        }
        
        // 마지막 종료 시간에 10분 추가
        String adjustedEndTime = _addMinutesToTime(latestEndTime, 10);
        
        // 총 시간 계산 (시작 시간부터 조정된 종료 시간까지)
        int totalMinutes = _calculateMinutesBetween(earliestStartTime, adjustedEndTime);
        
        mergedLesson['LS_start_time'] = earliestStartTime;
        mergedLesson['LS_end_time'] = adjustedEndTime;
        mergedLesson['LS_net_min'] = totalMinutes;
        mergedLesson['lesson_count'] = lessons.length;
        
        mergedLessons.add(mergedLesson);
      }
    });
    
    // 날짜와 시간으로 정렬
    mergedLessons.sort((a, b) {
      final aDate = a['LS_date'] ?? '';
      final bDate = b['LS_date'] ?? '';
      
      if (aDate == bDate) {
        final aTime = a['LS_start_time'] ?? '';
        final bTime = b['LS_start_time'] ?? '';
        return aTime.compareTo(bTime);
      }
      
      return aDate.compareTo(bDate);
    });
    
    // 오늘 날짜 구하기
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    // 오늘/미래/과거 예약 분류
    final todayReservations = mergedLessons.where((r) => r['LS_date'] == todayStr).toList();
    final futureReservations = mergedLessons.where((r) => r['LS_date'].compareTo(todayStr) > 0).toList();
    final pastReservations = mergedLessons.where((r) => r['LS_date'].compareTo(todayStr) < 0).toList();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 주니어 회원 목록 헤더
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12, top: 8),
          child: Text(
            '주니어 회원',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF3F51B5),
            ),
          ),
        ),
        // 주니어 회원 목록 (가로 스크롤을 세로 레이아웃으로 변경)
        ...List.generate(_juniorData.length, (index) {
          final junior = _juniorData[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF1E88E5),
                    child: Text(
                      junior['junior_name']?.substring(0, 1) ?? '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          junior['junior_name'] ?? '이름 없음',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '주니어 회원',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        
        const Divider(height: 32),
        
        // 오늘 예약
        if (todayReservations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
            child: Text(
              '오늘',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF3F51B5),
              ),
            ),
          ),
          ...todayReservations.map((r) => _buildReservationCard(r, color: Colors.blue[50], isToday: true)),
        ],
        
        // 미래 예약
        if (futureReservations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
            child: Text(
              '예정',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
          ...futureReservations.map((r) => _buildReservationCard(r, color: Colors.green[50], isToday: false)),
        ],
        
        // 과거 예약 더보기 버튼
        if (pastReservations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showPastReservations = !_showPastReservations;
                });
              },
              icon: Icon(_showPastReservations ? Icons.expand_less : Icons.expand_more),
              label: Text(_showPastReservations ? '접기' : '더 보기 (${pastReservations.length}개)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ),
          
          // 과거 예약 표시
          if (_showPastReservations)
            ...pastReservations.map((r) => _buildReservationCard(r, color: Colors.grey[100], isToday: false)),
        ],
      ],
    );
  }
  
  // 시간 문자열에 분 추가하는 함수
  String _addMinutesToTime(String timeStr, int minutes) {
    try {
      // 시간 형식 (HH:MM:SS)에서 시간, 분, 초 추출
      List<String> parts = timeStr.split(':');
      if (parts.length < 3) {
        // 형식이 맞지 않으면 원본 반환
        return timeStr;
      }
      
      int hours = int.parse(parts[0]);
      int mins = int.parse(parts[1]);
      int secs = int.parse(parts[2]);
      
      // 분 추가
      mins += minutes;
      
      // 60분 넘어가면 시간 조정
      if (mins >= 60) {
        hours += mins ~/ 60;
        mins = mins % 60;
      }
      
      // 24시간 넘어가면 조정
      if (hours >= 24) {
        hours = hours % 24;
      }
      
      // 형식에 맞게 반환 (HH:MM:SS)
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } catch (e) {
      // 오류 발생 시 원본 반환
      return timeStr;
    }
  }
  
  // 두 시간 사이의 분 차이 계산 함수
  int _calculateMinutesBetween(String startTimeStr, String endTimeStr) {
    try {
      // 시간 형식 (HH:MM:SS)에서 시간, 분 추출
      List<String> startParts = startTimeStr.split(':');
      List<String> endParts = endTimeStr.split(':');
      
      if (startParts.length < 2 || endParts.length < 2) {
        return 0;
      }
      
      int startHour = int.parse(startParts[0]);
      int startMin = int.parse(startParts[1]);
      
      int endHour = int.parse(endParts[0]);
      int endMin = int.parse(endParts[1]);
      
      // 총 분 계산
      int startTotalMins = startHour * 60 + startMin;
      int endTotalMins = endHour * 60 + endMin;
      
      // 날짜를 넘어가는 경우 (예: 23:30 ~ 00:30)
      if (endTotalMins < startTotalMins) {
        endTotalMins += 24 * 60; // 24시간 추가
      }
      
      return endTotalMins - startTotalMins;
    } catch (e) {
      return 0;
    }
  }
  
  // 예약 카드 위젯
  Widget _buildReservationCard(Map<String, dynamic> reservation, {Color? color, bool isToday = false}) {
    // 상태에 따른 색상 설정
    final String reservationStatus = reservation['LS_status'] ?? '';
    final bool isCanceled = reservationStatus.contains('취소');
    
    // 카드 배경색
    final cardColor = isCanceled ? Colors.grey[200]! : (color ?? Colors.white);
    
    // 아이콘 색상
    final iconColor = isCanceled ? Colors.grey : (color == Colors.blue[50] ? Colors.blue : color == Colors.green[50] ? Colors.green : Colors.grey);
    
    // 시간 정보 표시
    final String startTime = reservation['LS_start_time'] ?? '';
    final String endTime = reservation['LS_end_time'] ?? '';
    
    // 시간 표시 형식
    String timeDisplay = '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      // 시간 형식 정리 (HH:MM:SS -> HH:MM)
      String formattedStartTime = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
      String formattedEndTime = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
      timeDisplay = '$formattedStartTime ~ $formattedEndTime';
    } else if (startTime.isNotEmpty) {
      String formattedStartTime = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
      timeDisplay = formattedStartTime;
    }
    
    final dynamic duration = reservation['LS_net_min'] ?? '';
    final durationDisplay = duration.toString().isNotEmpty ? '(${duration}분)' : '';
    
    // 여러 레슨이 묶인 경우 표시 (숨김)
    final lessonCount = reservation['lesson_count'] ?? 1;
    final lessonCountDisplay = ''; // 레슨 개수 표시 제거
    
    // 날짜 포맷 (YYYY-MM-DD -> YY년MM월DD일)
    String formattedDate = reservation['LS_date'] ?? '';
    if (formattedDate.length >= 10 && formattedDate.contains('-')) {
      try {
        formattedDate = '${formattedDate.substring(2,4)}년${formattedDate.substring(5,7)}월${formattedDate.substring(8,10)}일';
      } catch (e) {
        // 날짜 형식이 예상과 다른 경우 원본 반환
      }
    }
    
    return Card(
      color: cardColor,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 오늘 레슨 배지
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 12, bottom: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isCanceled ? Colors.grey[400] : Colors.blue[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCanceled ? '취소된 예약' : '오늘예약',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            leading: Icon(
              isCanceled ? Icons.cancel_outlined : (lessonCount > 1 ? Icons.playlist_add_check : Icons.golf_course),
              color: iconColor, 
              size: 32
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '$formattedDate  $timeDisplay $durationDisplay$lessonCountDisplay', 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(reservationStatus),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      reservation['LS_contract_pro'] != null ? '${reservation['LS_contract_pro']} 프로' : '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (reservation['LS_type'] != null && reservation['LS_type'].toString().isNotEmpty)
                      Expanded(
                        child: Text(
                          reservation['LS_type'].toString(), 
                          style: const TextStyle(fontSize: 13, color: Colors.teal),
                        ),
                      ),
                    if (reservation['junior_name'] != null)
                      Text(
                        '${reservation['junior_name']}', 
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReservationDetail(context, reservation),
          ),
        ],
      ),
    );
  }
  
  // 상태 배지 위젯
  Widget _buildStatusBadge(String status) {
    Color color;
    String text = status;
    IconData? icon;
    
    // 상태별 색상 및 아이콘 동적 지정
    if (status.contains('예약취소') || status.contains('취소')) {
      color = Colors.red;
      text = '취소됨';
      icon = Icons.cancel_outlined;
    } else if (status.contains('완료')) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (status.contains('예약') || status.contains('확정')) {
      color = Colors.blue;
      text = '예약완료';
      icon = Icons.event_available;
    } else if (status.contains('처리중')) {
      color = Colors.purple;
      icon = Icons.pending_outlined;
    } else if (status.contains('대기')) {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else {
      color = Colors.grey;
      icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text, 
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.bold, 
              fontSize: 13
            ),
          ),
        ],
      ),
    );
  }
  
  // 예약 상세 정보 모달
  void _showReservationDetail(BuildContext context, Map<String, dynamic> reservation) {
    // 시간 정보 표시
    final String startTime = reservation['LS_start_time'] ?? '';
    final String endTime = reservation['LS_end_time'] ?? '';
    
    // 시간 표시 형식
    String formattedStartTime = '';
    String formattedEndTime = '';
    
    if (startTime.isNotEmpty) {
      // 시간 형식 정리 (HH:MM:SS -> HH:MM)
      formattedStartTime = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
    }
    
    if (endTime.isNotEmpty) {
      formattedEndTime = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
    }
    
    // 예약 상태
    final String reservationStatus = reservation['LS_status'] ?? '';
    final bool isCanceled = reservationStatus.contains('취소');
    
    // LS_set_id 가져오기
    final String lsSetId = reservation['LS_set_id'] ?? '';
    
    // 예약 날짜 확인
    final String reservationDate = reservation['LS_date'] ?? '';
    bool isPastReservation = false;
    bool isTodayReservation = false;
    
    try {
      if (reservationDate.isNotEmpty) {
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime reservationDateTime = DateTime.parse(reservationDate);
        
        // 오늘 날짜보다 이전인 경우 과거 예약으로 간주
        isPastReservation = reservationDateTime.isBefore(today);
        
        // 오늘 예약인지 확인
        isTodayReservation = reservationDateTime.year == today.year && 
                            reservationDateTime.month == today.month && 
                            reservationDateTime.day == today.day;
      }
    } catch (e) {
      if (kDebugMode) {
        print('날짜 변환 오류: $e');
      }
    }
    
    // 취소 가능 여부 확인
    bool canCancel = !isCanceled && !isPastReservation && lsSetId.isNotEmpty;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // 상태 표시 헤더
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isCanceled ? Colors.red[50] :
                      isPastReservation ? Colors.grey[100] :
                      isTodayReservation ? Colors.blue[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCanceled ? Icons.cancel_outlined :
                      isPastReservation ? Icons.history :
                      isTodayReservation ? Icons.today : Icons.event_available,
                      color: isCanceled ? Colors.red :
                          isPastReservation ? Colors.grey[600] :
                          isTodayReservation ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isCanceled ? '취소된 예약입니다' :
                        isPastReservation ? '지난 예약입니다' :
                        isTodayReservation ? '오늘의 예약입니다' : '예약이 확정되었습니다',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCanceled ? Colors.red :
                              isPastReservation ? Colors.grey[700] :
                              isTodayReservation ? Colors.blue : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 시간 및 주요 정보
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 시간 정보
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          '레슨 시간',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // 시작-종료 시간
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (formattedStartTime.isNotEmpty)
                          Text(
                            formattedStartTime,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          
                        if (formattedStartTime.isNotEmpty && formattedEndTime.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '~',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                        if (formattedEndTime.isNotEmpty)
                          Text(
                            formattedEndTime,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                      ],
                    ),
                    
                    // 총 시간
                    if (reservation['LS_net_min'] != null && reservation['LS_net_min'].toString().isNotEmpty)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '총 ${reservation['LS_net_min']}분',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 예약 상세 정보
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reservation['LS_date'] != null)
                      _infoRow('날짜', reservation['LS_date']?.toString() ?? '', Colors.black, Colors.grey),
                    if (reservation['LS_contract_pro'] != null)
                      _infoRow('담당 프로', '${reservation['LS_contract_pro']} 프로', Colors.black, Colors.grey),
                    if (reservation['LS_type'] != null)
                      _infoRow('레슨 유형', reservation['LS_type']?.toString() ?? '', Colors.black, Colors.grey),
                    if (reservation['junior_name'] != null)
                      _infoRow('주니어 이름', reservation['junior_name']?.toString() ?? '', Colors.black, Colors.grey),
                    _infoRow('상태', reservationStatus, Colors.black, Colors.grey,
                      suffix: _buildStatusBadge(reservationStatus)
                    ),
                  ],
                ),
              ),
              
              // 예약 취소 버튼
              if (canCancel)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCancellationConfirmDialog(context, reservation),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('예약 취소하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              
              // 취소 불가 메시지
              if (!canCancel && !isCanceled) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isPastReservation ? 
                            '지난 예약은 취소할 수 없습니다.' : 
                            '예약 시작 1시간 전까지만 취소가 가능합니다.',
                          style: TextStyle(
                            color: Colors.grey[700],
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
    );
  }
  
  // 정보 행 위젯 (고급스러운 디자인)
  Widget _infoRow(String label, String value, Color textColor, Color labelColor, {Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: textColor,
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }
  
  // 예약 취소 확인 다이얼로그
  void _showCancellationConfirmDialog(BuildContext context, Map<String, dynamic> reservation) {
    final String lsSetId = reservation['LS_set_id'] ?? '';
    
    if (lsSetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('예약 정보가 올바르지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약 취소 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말 이 레슨 예약을 취소하시겠습니까?'),
            const SizedBox(height: 16),
            Text(
              '취소 후에는 복구할 수 없으며, 잔여 시간이 재계산됩니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () => _cancelReservation(context, lsSetId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('예, 취소합니다'),
          ),
        ],
      ),
    );
  }
  
  // 예약 취소 처리
  Future<void> _cancelReservation(BuildContext context, String lsSetId) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('예약을 취소하는 중입니다...'),
          ],
        ),
      ),
    );
    
    try {
      // 예약 취소 서비스 호출
      final result = await JuniorLessonCancellationService.cancelJuniorLessonReservation(lsSetId);
      
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      
      // 상세 정보 모달 닫기
      Navigator.of(context).pop();
      
      // 결과에 따른 메시지 표시
      if (result['success']) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        
        // 데이터 새로고침
        setState(() {
          _isLoading = true;
          _lessonData = [];
          _juniorData = [];
          _errorMessage = null;
        });
        _fetchJuniorData();
      } else {
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예약 취소 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // min 함수 구현
  int min(int a, int b) {
    return a < b ? a : b;
  }
} 