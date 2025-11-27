import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:famd_clientapp/screens/subpages/pages/ts_reservation_history_screen.dart' show ReservationDetailModal;
import 'package:famd_clientapp/services/junior_lesson_cancellation_service.dart';
import 'package:famd_clientapp/services/api_service.dart';

class TodayReservationsWidget extends StatefulWidget {
  const TodayReservationsWidget({Key? key}) : super(key: key);

  @override
  State<TodayReservationsWidget> createState() => _TodayReservationsWidgetState();
}

class _TodayReservationsWidgetState extends State<TodayReservationsWidget> {

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

  // 예약 유형 라벨 변환
  String _typeLabel(String? type) {
    switch (type) {
      case '일반':
        return '일반예약(1회)';
      case '주니어':
        return '주니어(1회)';
      case '일반루틴':
        return '일반예약(루틴)';
      case '주니어루틴':
        return '주니어(루틴)';
      default:
        return type ?? '';
    }
  }

  // 정보 행 위젯
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

  // 모든 예약(일반 예약 + 주니어 예약)을 가져오는 함수
  Future<List<Map<String, dynamic>>> _fetchAllTodayReservations() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final memberId = userProvider.user?.id;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<Map<String, dynamic>> allReservations = [];
    
    try {
      // 1. 일반 예약 가져오기
      final regularResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': [
            {'field': 'ts_date', 'operator': '=', 'value': todayStr},
            {'field': 'ts_status', 'operator': '=', 'value': '결제완료'}
          ]
        }),
      );
      
      if (regularResponse.statusCode == 200) {
        final resp = jsonDecode(regularResponse.body);
        if (resp['success'] == true && resp['data'] != null) {
          final reservations = List<Map<String, dynamic>>.from(resp['data']);
          allReservations.addAll(reservations);
        }
      }
      
      // 2. 레슨 예약 내역 가져오기 (lesson_reservation_history.dart와 동일한 방식)
      final lessonStatusResponse = await _fetchLessonStatusFromAPI(memberId, userProvider.currentBranchId);
      
      if (lessonStatusResponse.containsKey('orders') && lessonStatusResponse['orders'] is List) {
        final orders = lessonStatusResponse['orders'] as List;
        
        if (orders.isNotEmpty) {
          // orders 데이터 처리
          final processedOrders = _processOrders(orders);
          
          // 오늘 날짜에 해당하는 레슨 예약만 필터링
          final todayLessons = processedOrders.where((lesson) => 
            lesson['date'] == todayStr && 
            !(lesson['status']?.toString().contains('취소') ?? false)
          ).toList();
          
          // 레슨 예약임을 표시하고 추가
          allReservations.addAll(todayLessons);
        }
      }
      
      // 3. 주니어 회원 목록 가져오기
      final whereConditionsJunior = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': memberId.toString()
        }
      ];
      
      if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
        whereConditionsJunior.add({
          'field': 'branch_id',
          'operator': '=',
          'value': userProvider.currentBranchId!
        });
      }

      final juniorResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_junior_relation',
          'fields': ['member_id', 'junior_member_id', 'junior_name'],
          'where': whereConditionsJunior,
          'limit': 10
        }),
      );
      
      if (juniorResponse.statusCode == 200) {
        final juniorResp = jsonDecode(juniorResponse.body);
        if (juniorResp['success'] == true && juniorResp['data'] != null) {
          final juniorData = List<Map<String, dynamic>>.from(juniorResp['data']);
          
          // 4. 각 주니어별 예약 가져오기
          for (var junior in juniorData) {
            final juniorMemberId = junior['junior_member_id'];
            final juniorName = junior['junior_name'];
            
            if (juniorMemberId != null) {
              final whereConditionsJuniorLessons = [
                {
                  'field': 'member_id',
                  'operator': '=',
                  'value': juniorMemberId.toString()
                }
              ];
              
              if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
                whereConditionsJuniorLessons.add({
                  'field': 'branch_id',
                  'operator': '=',
                  'value': userProvider.currentBranchId!
                });
              }

              final lessonResponse = await http.post(
                Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
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
                    'LS_net_min'
                  ],
                  'where': whereConditionsJuniorLessons,
                  'limit': 50
                }),
              );
              
              if (lessonResponse.statusCode == 200) {
                final lessonResp = jsonDecode(lessonResponse.body);
                if (lessonResp['success'] == true && lessonResp['data'] != null) {
                  final lessonData = List<Map<String, dynamic>>.from(lessonResp['data']);
                  
                  // 오늘 예약만 필터링
                  final todayLessons = lessonData.where((lesson) => 
                    lesson['LS_date'] == todayStr && 
                    !(lesson['LS_status']?.toString().contains('취소') ?? false)
                  ).toList();
                  
                  // LS_set_id 기준으로 레슨 데이터 그룹화 (junior_reservation_info.dart와 동일한 방식)
                  Map<String, List<Map<String, dynamic>>> lessonGroups = {};
                  
                  // 데이터를 Map<String, dynamic>으로 변환하고 그룹화
                  for (var lesson in todayLessons) {
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
                      for (var lesson in lessons) {
                        lesson['junior_name'] = juniorName;
                        lesson['isJunior'] = true;
                        mergedLessons.add(lesson);
                      }
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
                      mergedLesson['junior_name'] = juniorName;
                      mergedLesson['isJunior'] = true;
                      
                      mergedLessons.add(mergedLesson);
                    }
                  });
                  
                  // 병합된 레슨 데이터 추가
                  allReservations.addAll(mergedLessons);
                }
              }
            }
          }
        }
      }
      
      // 시간순으로 정렬
      allReservations.sort((a, b) {
        String aTime = '';
        String bTime = '';
        
        if (a['isJunior'] == true) {
          aTime = a['LS_start_time'] ?? '';
        } else if (a['isLessonReservation'] == true) {
          aTime = a['start_time'] ?? a['time'] ?? '';
        } else {
          aTime = a['ts_start'] ?? '';
        }
        
        if (b['isJunior'] == true) {
          bTime = b['LS_start_time'] ?? '';
        } else if (b['isLessonReservation'] == true) {
          bTime = b['start_time'] ?? b['time'] ?? '';
        } else {
          bTime = b['ts_start'] ?? '';
        }
        
        return aTime.compareTo(bTime);
      });
      
      return allReservations;
    } catch (e) {
      print('오늘의 예약 조회 오류: $e');
      return [];
    }
  }

  // API를 사용하여 레슨 상태 정보 가져오기 (dynamic_api 사용)
  Future<Map<String, dynamic>> _fetchLessonStatusFromAPI(dynamic memberId, [String? branchId]) async {
    try {
      // 1. 레슨 카운팅 정보 조회 (v3_LS_countings)
      final whereConditionsCountings = [
        {'field': 'member_id', 'operator': '=', 'value': memberId.toString()}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditionsCountings.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final countingsResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v3_LS_countings',
          'where': whereConditionsCountings
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('레슨 카운팅 조회 시간 초과 (30초)');
        },
      );

      // 2. 레슨 예약 정보 조회 (v2_LS_orders)
      final whereConditionsOrders = [
        {'field': 'member_id', 'operator': '=', 'value': memberId.toString()}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditionsOrders.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final ordersResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'where': whereConditionsOrders,
          'orderBy': [
            {'field': 'LS_date', 'direction': 'DESC'},
            {'field': 'LS_start_time', 'direction': 'DESC'}
          ],
          'limit': 100
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('레슨 예약 조회 시간 초과 (30초)');
        },
      );
      
      // 응답 확인 및 데이터 조합
      List<dynamic> countings = [];
      List<dynamic> orders = [];
      
      if (countingsResponse.statusCode == 200) {
        try {
          final countingsData = jsonDecode(countingsResponse.body);
          if (countingsData['success'] == true && countingsData['data'] != null) {
            countings = countingsData['data'];
          }
        } catch (e) {
          print('레슨 카운팅 JSON 파싱 오류: $e');
        }
      }
      
      if (ordersResponse.statusCode == 200) {
        try {
          final ordersData = jsonDecode(ordersResponse.body);
          if (ordersData['success'] == true && ordersData['data'] != null) {
            orders = ordersData['data'];
          }
        } catch (e) {
          print('레슨 예약 JSON 파싱 오류: $e');
        }
      }
      
      // 통합 응답 반환
      return {
        'success': true,
        'countings': countings,
        'orders': orders,
        'data_source': 'dynamic_api'
      };
      
    } catch (e) {
      // 오류가 발생해도 빈 데이터 반환
      return {
        'success': false,
        'error': e.toString(),
        'countings': [],
        'orders': [],
        'data_source': 'dynamic_api_error'
      };
    }
  }

  // LS_orders 데이터 처리 (lesson_reservation_history.dart와 동일한 방식)
  List<Map<String, dynamic>> _processOrders(List<dynamic> orders) {
    final List<Map<String, dynamic>> result = [];
    
    for (var order in orders) {
      if (order is Map<String, dynamic>) {
        try {
          // 필요한 필드 추출
          final id = order['LS_id'] ?? order['id'] ?? '';
          String date = order['LS_date'] ?? order['date'] ?? '';
          
          // 날짜 형식 정규화 (YY-MM-DD 또는 YYYY-MM-DD 형식으로 변환)
          if (date.length == 10 && date.contains('-')) {
            // 이미 YYYY-MM-DD 형식
          } else if (date.length == 8 && date.contains('-')) {
            // YY-MM-DD 형식
            date = '20$date';
          } else if (date.length == 6 && !date.contains('-')) {
            // YYMMDD 형식일 경우 변환
            date = '20${date.substring(0, 2)}-${date.substring(2, 4)}-${date.substring(4, 6)}';
          }
          
          // 시간 관련 필드
          String startTime = order['LS_start_time'] ?? order['start_time'] ?? '';
          String endTime = order['LS_end_time'] ?? order['end_time'] ?? '';
          
          // 시간이 없는 경우 LS_id에서 추출 시도 (예: 250526_es_1950)
          if (startTime.isEmpty && id.toString().contains('_')) {
            final parts = id.toString().split('_');
            if (parts.length >= 3) {
              final timeCode = parts[parts.length - 1];
              if (timeCode.length == 4 && RegExp(r'^\d+$').hasMatch(timeCode)) {
                startTime = '${timeCode.substring(0, 2)}:${timeCode.substring(2, 4)}';
              }
            }
          }
          
          // 시간 형식 처리 (HH:MM:SS -> HH:MM)
          String formattedStartTime = startTime.toString();
          if (formattedStartTime.length >= 5) {
            formattedStartTime = formattedStartTime.substring(0, 5);
          }
          
          // 종료 시간 처리
          String formattedEndTime = endTime.toString();
          if (formattedEndTime.length >= 5) {
            formattedEndTime = formattedEndTime.substring(0, 5);
          } else if (formattedEndTime.isEmpty && formattedStartTime.isNotEmpty) {
            // 종료 시간이 없지만 시작 시간이 있고 duration이 있는 경우 계산
            final duration = order['LS_net_min'] ?? order['duration'] ?? 0;
            final durationMinutes = duration is String ? int.tryParse(duration) ?? 0 : duration;
            
            // 시작 시간 파싱
            if (formattedStartTime.length == 5 && formattedStartTime.contains(':')) {
              final startHour = int.tryParse(formattedStartTime.split(':')[0]) ?? 0;
              final startMinute = int.tryParse(formattedStartTime.split(':')[1]) ?? 0;
              
              // 종료 시간 계산
              final totalMinutes = startHour * 60 + startMinute + durationMinutes;
              final endHour = (totalMinutes ~/ 60) % 24;
              final endMinute = totalMinutes % 60;
              
              formattedEndTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
            }
          }
          
          // 기본값 하드코딩 제거
          final duration = order['LS_net_min'] ?? order['duration'] ?? 0;
          final proName = order['LS_contract_pro'] ?? order['pro_name'] ?? '';
          final status = order['LS_status'] ?? order['status'] ?? '';
          final lessonType = order['LS_type']?.toString() ?? order['lesson_type']?.toString() ?? '';
          final memberId = order['member_id'] ?? '';
          final memberName = order['member_name'] ?? '';
          
          // 예약 데이터 형식으로 변환
          result.add({
            'id': id.toString(),
            'date': date,
            'time': formattedStartTime, // 이전 표시 형식과의 호환성
            'start_time': formattedStartTime,
            'end_time': formattedEndTime,
            'duration': duration is String ? int.tryParse(duration) ?? 0 : duration,
            'pro_name': proName,
            'status': status,
            'lesson_type': lessonType,
            'member_id': memberId,
            'member_name': memberName,
            'is_actual_reservation': true, // 데이터 구분을 위한 플래그
            'raw_data': order, // 디버깅용 원본 데이터 저장
            'data_source': 'v2_LS_orders' // 데이터 소스 표시
          });
        } catch (e) {
          // 오류 처리
          print('레슨 데이터 처리 오류: $e');
        }
      }
    }
    
    return result;
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final memberId = userProvider.user?.id;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllTodayReservations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 예약',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${snapshot.data!.length}건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildReservationItems(snapshot.data!),
          ],
        );
      },
    );
  }
  
  // 예약 항목들을 표시하는 메서드
  Widget _buildReservationItems(List<Map<String, dynamic>> reservations) {
    return Column(
      children: reservations.map((r) {
        // 예약 유형 확인
        final bool isJuniorReservation = r['isJunior'] == true;
        final bool isLessonReservation = r['isLessonReservation'] == true;
        final bool isTSReservation = r['isTSReservation'] == true;
        final String juniorName = r['junior_name'] ?? '';
        
        // 카드 색상 설정
        Color cardColor;
        if (isJuniorReservation) {
          cardColor = Colors.indigo[50]!;
        } else if (isLessonReservation) {
          cardColor = Colors.amber[50]!;
        } else {
          cardColor = Colors.blue[50]!;
        }
        
        // 아이콘 설정
        IconData leadingIcon;
        Color iconColor;
        if (isJuniorReservation) {
          leadingIcon = Icons.child_care;
          iconColor = Colors.indigo;
        } else if (isLessonReservation) {
          leadingIcon = Icons.sports_golf;
          iconColor = Colors.amber[800]!;
        } else {
          leadingIcon = Icons.golf_course;
          iconColor = Colors.green;
        }
        
        // 제목 설정
        String title;
        if (isJuniorReservation) {
          title = '주니어 레슨';
        } else if (isLessonReservation) {
          title = '레슨 예약';
        } else {
          title = '오늘의 예약';
        }
        
        // 시간 정보 설정
        String timeInfo;
        if (isJuniorReservation) {
          timeInfo = '${r['LS_start_time']?.substring(0, 5) ?? ''} ~ ${r['LS_end_time']?.substring(0, 5) ?? ''} (${r['LS_net_min'] ?? ''}분)';
        } else if (isLessonReservation) {
          timeInfo = '${r['start_time'] ?? r['time'] ?? ''} ~ ${r['end_time'] ?? ''} (${r['duration'] ?? ''}분)';
        } else {
          timeInfo = '${r['ts_start']} ~ ${r['ts_end']}  ${r['ts_id']}번 타석';
        }
        
        // 추가 정보 설정
        String additionalInfo;
        if (isJuniorReservation) {
          additionalInfo = '${r['LS_contract_pro'] ?? ''} 프로 · ${r['LS_type'] ?? ''}';
        } else if (isLessonReservation) {
          additionalInfo = '${r['pro_name'] ?? ''} 프로 · ${r['lesson_type'] ?? ''}';
        } else {
          additionalInfo = _typeLabel(r['ts_type']);
        }
        
        return Card(
          color: cardColor,
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Icon(
              leadingIcon,
              color: iconColor,
              size: 32
            ),
            title: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: isJuniorReservation ? Colors.indigo[900] : 
                          isLessonReservation ? Colors.amber[900] : 
                          Colors.blue[900]
                  )
                ),
                if (isJuniorReservation && juniorName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      juniorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900],
                      ),
                    ),
                  ),
                ]
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  timeInfo,
                  style: const TextStyle(fontSize: 15)
                ),
                const SizedBox(height: 2),
                Text(
                  additionalInfo,
                  style: TextStyle(
                    fontSize: 13, 
                    color: isJuniorReservation ? Colors.indigo : 
                          isLessonReservation ? Colors.amber[800] : 
                          Colors.teal
                  )
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isJuniorReservation ? Colors.indigo[900] : 
                    isLessonReservation ? Colors.amber[900] : 
                    Colors.blue[900]
            ),
            onTap: () {
              if (isJuniorReservation) {
                // 주니어 레슨 예약 상세 정보를 팝업으로 표시
                _showJuniorReservationDetail(context, r);
              } else if (isLessonReservation) {
                // 레슨 예약 상세 정보 표시
                _showLessonReservationDetail(context, r);
              } else {
                // 일반 예약 상세 정보 표시
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: ReservationDetailModal(
                        reservation: r,
                        memberId: int.tryParse(Provider.of<UserProvider>(context).user?.id.toString() ?? ''),
                        onCancel: (_, __, ___) {}, // 홈에서는 취소 기능 비활성화
                      ),
                    );
                  },
                );
              }
            },
          ),
        );
      }).toList(),
    );
  }

  // 주니어 레슨 예약 상세 정보 표시 함수
  void _showJuniorReservationDetail(BuildContext context, Map<String, dynamic> reservation) {
    // 시간 정보 표시
    final String startTime = reservation['LS_start_time'] ?? '';
    final String endTime = reservation['LS_end_time'] ?? '';
    final String juniorName = reservation['junior_name'] ?? '';
    
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
      print('날짜 변환 오류: $e');
    }
    
    // 고급스러운 색상 정의
    final Color primaryColor = isCanceled ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
    final Color backgroundColor = Colors.white;
    final Color textColor = const Color(0xFF424242);
    final Color labelColor = const Color(0xFF757575);
    
    // 취소 처리 함수 - 로컬 함수로 정의
    Future<void> performCancel(String lsSetId) async {
      // 확인 다이얼로그 표시
      bool? shouldCancel = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('아니오'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('예, 취소합니다'),
            ),
          ],
        ),
      );
      
      // 취소하지 않기로 선택한 경우
      if (shouldCancel != true) return;
      
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        // 예약 취소 API 호출 (주니어 레슨은 LS_set_id로 세트 취소)
        final result = await ApiService.cancelJuniorLessonReservation(lsSetId);
        
        // 로딩 다이얼로그 닫기
        Navigator.of(context, rootNavigator: true).pop();
        
        // 결과에 따른 메시지 표시
        if (result['success'] == true) {
          // 예약 상세 정보 팝업 닫기
          Navigator.of(context).pop();
          
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // 데이터 새로고침
          setState(() {
            // FutureBuilder를 강제로 다시 실행하기 위해 상태 갱신
          });
          
        } else {
          // 오류 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '예약 취소 중 오류가 발생했습니다'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        // 로딩 다이얼로그 닫기
        Navigator.of(context, rootNavigator: true).pop();
        
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 취소 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
              
              // 오늘 예약 또는 취소된 예약 표시
              if (isTodayReservation || isCanceled) 
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCanceled ? Icons.cancel_outlined : Icons.event_available,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isCanceled ? '취소된 예약입니다' : '오늘 예약입니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 예약 정보 카드
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryColor, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            '주니어 레슨 예약 정보',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 내용
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (juniorName.isNotEmpty)
                            _infoRow('주니어 이름', juniorName, textColor, labelColor),
                          if (reservation['LS_date'] != null)
                            _infoRow('날짜', reservation['LS_date']?.toString() ?? '', textColor, labelColor),
                          if (timeDisplay.isNotEmpty)
                            _infoRow('시간', timeDisplay, textColor, labelColor, 
                              suffix: reservation['LS_net_min'] != null ? 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${reservation['LS_net_min']}분',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ) : null
                            ),
                          if (reservation['LS_contract_pro'] != null)
                            _infoRow('담당 프로', '${reservation['LS_contract_pro']} 프로', textColor, labelColor),
                          if (reservation['LS_type'] != null)
                            _infoRow('레슨 유형', reservation['LS_type']?.toString() ?? '', textColor, labelColor),
                          _infoRow('상태', reservationStatus, textColor, labelColor, 
                            suffix: _buildStatusBadge(reservationStatus)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 예약 취소 버튼 (이미 취소된 예약이 아니고, 과거 예약이 아니며, LS_set_id가 있는 경우에만 표시)
              if (!isCanceled && !isPastReservation && lsSetId.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => performCancel(lsSetId),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('예약 취소하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
              
              // 과거 예약인 경우 취소 불가 메시지 표시
              if (!isCanceled && isPastReservation && lsSetId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '지난 예약은 취소할 수 없습니다.',
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

  // 레슨 예약 상세 정보 표시 함수
  void _showLessonReservationDetail(BuildContext context, Map<String, dynamic> reservation) {
    // 취소 가능 여부 확인 (시작 시간 1시간 전까지만 취소 가능)
    bool canCancel = false;
    String cancelButtonTooltip = '';
    
    final String reservationStatus = reservation['status'] ?? '';
    
    // 레슨 예약 취소 확인 다이얼로그 - 로컬 함수로 정의
    void showCancelConfirmationForLesson(String reservationId) {
      // 로컬 함수로 cancelLessonReservation 함수 선언
      Future<void> cancelLessonReservation(String resId) async {
        try {
          // 로딩 다이얼로그 표시
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          // 예약 취소 API 호출
          final result = await ApiService.cancelLessonReservation(resId);

          // 로딩 다이얼로그 닫기
          Navigator.of(context).pop();

          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'])),
            );

            // 모달 닫기
            Navigator.of(context).pop();
            
            // 데이터 새로고침을 위해 상태 업데이트 (안전하게 setState 호출)
            setState(() {
              // FutureBuilder를 강제로 다시 실행하기 위해 상태 갱신
            });
            
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? '예약 취소 중 오류가 발생했습니다')),
            );
          }
        } catch (e) {
          // 로딩 다이얼로그 닫기
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('예약 취소 중 오류가 발생했습니다: $e')),
          );
        }
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
              onPressed: () {
                Navigator.of(context).pop();
                cancelLessonReservation(reservationId);
              },
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
    
    // 이미 취소된 예약인지 확인
    if (reservationStatus.contains('취소')) {
      cancelButtonTooltip = '이미 취소된 예약입니다';
    } 
    // 확정된 예약인지 확인
    else if (reservationStatus.contains('예약') || reservationStatus.contains('완료')) {
      try {
        final now = DateTime.now();
        final reservationDate = reservation['date'] ?? '';
        final reservationTime = reservation['start_time'] ?? reservation['time'] ?? '';
        
        if (reservationDate.isNotEmpty && reservationTime.isNotEmpty) {
          final DateFormat formatter = DateFormat('yyyy-MM-dd');
          DateTime parsedDate;
          
          // 다양한 날짜 형식 처리
          try {
            parsedDate = formatter.parse(reservationDate);
          } catch (e) {
            // YY년MM월DD일 형식이면 변환
            if (reservationDate.contains('년') && reservationDate.contains('월') && reservationDate.contains('일')) {
              final year = int.tryParse('20${reservationDate.substring(0, 2)}') ?? 2000;
              final month = int.tryParse(reservationDate.substring(3, 5)) ?? 1;
              final day = int.tryParse(reservationDate.substring(6, 8)) ?? 1;
              parsedDate = DateTime(year, month, day);
            } else {
              throw Exception('지원되지 않는 날짜 형식: $reservationDate');
            }
          }
          
          // 시간 파싱
          final timeParts = reservationTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          
          final reservationDateTime = DateTime(
            parsedDate.year, 
            parsedDate.month, 
            parsedDate.day,
            hour,
            minute
          );
          
          final difference = reservationDateTime.difference(now);
          
          if (difference.inHours >= 1) {
            canCancel = true;
            cancelButtonTooltip = '예약을 취소하려면 클릭하세요';
          } else if (difference.isNegative) {
            cancelButtonTooltip = '이미 지난 예약은 취소할 수 없습니다';
          } else {
            cancelButtonTooltip = '예약 시작 1시간 전까지만 취소가 가능합니다';
          }
        } else {
          cancelButtonTooltip = '날짜 또는 시간 정보가 없어 취소할 수 없습니다';
        }
      } catch (e) {
        // 오류 처리
        canCancel = false;
        cancelButtonTooltip = '예약 정보 형식 오류로 취소할 수 없습니다';
      }
    } else {
      cancelButtonTooltip = '취소 가능한 예약 상태가 아닙니다';
    }
    
    // 시간 정보 표시
    final String startTime = reservation['start_time'] ?? reservation['time'] ?? '';
    final String endTime = reservation['end_time'] ?? '';
    
    // 시간 표시 형식
    String timeDisplay = '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeDisplay = '$startTime ~ $endTime';
    } else if (startTime.isNotEmpty) {
      timeDisplay = startTime;
    }
    
    // 예약 날짜 확인
    final String reservationDate = reservation['date'] ?? '';
    bool isPastReservation = false;
    bool isTodayReservation = false;
    
    try {
      if (reservationDate.isNotEmpty) {
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);
        // 날짜 형식에 따라 처리
        DateTime reservationDateTime;
        if (reservationDate.contains('-')) {
          // YYYY-MM-DD 형식
          reservationDateTime = DateTime.parse(reservationDate);
        } else if (reservationDate.contains('년') && reservationDate.contains('월') && reservationDate.contains('일')) {
          // YY년MM월DD일 형식
          final year = int.tryParse('20${reservationDate.substring(0, 2)}') ?? 2000;
          final month = int.tryParse(reservationDate.substring(3, 5)) ?? 1;
          final day = int.tryParse(reservationDate.substring(6, 8)) ?? 1;
          reservationDateTime = DateTime(year, month, day);
        } else {
          throw Exception('지원되지 않는 날짜 형식');
        }
        
        // 오늘 날짜보다 이전인 경우 과거 예약으로 간주
        isPastReservation = reservationDateTime.isBefore(today);
        
        // 오늘 예약인지 확인
        isTodayReservation = reservationDateTime.year == today.year && 
                           reservationDateTime.month == today.month && 
                           reservationDateTime.day == today.day;
      }
    } catch (e) {
      // 날짜 변환 오류 처리
    }
    
    // 색상 정의
    final Color primaryColor = reservationStatus.contains('취소') ? 
        const Color(0xFFE53935) : // 취소는 빨간색
        (isTodayReservation ? 
          const Color(0xFF1E88E5) : // 오늘은 파란색
          const Color(0xFF43A047)); // 그 외는 녹색
    
    final Color backgroundColor = Colors.white;
    final Color textColor = const Color(0xFF424242);
    final Color labelColor = const Color(0xFF757575);
    
    final bool isCanceled = reservationStatus.contains('취소');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
              
              // 상태 표시 (오늘 예약 또는 취소된 예약만)
              if (isTodayReservation || isCanceled) 
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCanceled ? Icons.cancel_outlined : Icons.event_available,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isCanceled ? '취소된 예약입니다' : '오늘 예약입니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 예약 정보 카드
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryColor, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            '예약 정보',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 내용
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reservation['date'] != null)
                            _infoRow('날짜', reservation['date']?.toString() ?? '', textColor, labelColor),
                          if (timeDisplay.isNotEmpty)
                            _infoRow('시간', timeDisplay, textColor, labelColor, 
                              suffix: reservation['duration'] != null ? 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${reservation['duration']}분',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ) : null
                          ),
                          if (reservation['pro_name'] != null)
                            _infoRow('담당 프로', '${reservation['pro_name']} 프로', textColor, labelColor),
                          if (reservation['lesson_type'] != null)
                            _infoRow('레슨 유형', reservation['lesson_type']?.toString() ?? '', textColor, labelColor),
                          _infoRow('상태', reservationStatus, textColor, labelColor, 
                            suffix: _buildStatusBadge(reservationStatus)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 예약 취소 버튼
              if (canCancel)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => showCancelConfirmationForLesson(reservation['id']),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('예약 취소하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              
              // 취소 불가 메시지 (취소 불가인 경우에만 표시)
              if (!canCancel && !isCanceled) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[700]),
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
} 