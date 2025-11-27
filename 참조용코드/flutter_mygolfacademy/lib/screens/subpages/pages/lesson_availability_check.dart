import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// 레슨 가능 프로(강사) 선택 및 staff_nickname 반환 유틸리티
class LessonAvailabilityCheck {
  /// 시간 문자열(HH:MM:SS)을 분 단위 정수로 변환
  static int toMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 레슨 가능 프로 선택 및 staff_nickname 반환
  static Future<dynamic> selectProAndGetNickname(BuildContext context, int memberId, String scheduledDate, [String? branchId]) async {
    // 1. v2_member_pro_match 테이블에서 relation_status가 '유효'인 프로 목록 조회
    final validPros = await _fetchValidPros(memberId, branchId);
    
    if (validPros.isEmpty) {
      print('⚠️ [경고] 유효한 프로 매칭이 없습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 유효한 프로가 없습니다.')),
      );
      return null;
    }

    print('🔍 [디버깅] 유효한 프로 목록: ${validPros.map((p) => p['pro_name']).toList()}');
    
    // 2. 각 프로별 예약 가능 시간 미리 확인
    Map<String, bool> proAvailability = {};
    Map<String, List<Map<String, int>>> proAvailableBlocks = {};
    Map<String, int> proIds = {};
    
    for (final proData in validPros) {
      final String proName = proData['pro_name'] ?? '';
      final int proId = proData['pro_id'] ?? 0;
      
      if (proName.isEmpty || proId == 0) continue;
      
      // pro_id 저장
      proIds[proName] = proId;
      
      // 해당 프로의 스케줄 및 예약 현황 확인
      final schedule = await fetchStaffSchedule(proId, scheduledDate, branchId: branchId);
      final orders = await fetchProOrders(proId, scheduledDate, memberId, branchId: branchId);
      
      // 스케줄이 없으면 예약 불가능으로 처리
      if (schedule == null) {
        proAvailability[proName] = false;
        print('⚠️ [경고] 프로 $proName(ID: $proId)의 스케줄을 찾을 수 없어 예약 불가로 설정');
        continue;
      }
      
      final workStartStr = schedule['work_start'];
      final workEndStr = schedule['work_end'];
      final breakStartStr = schedule['break_start'];
      final breakEndStr = schedule['break_end'];
      
      // 필수 스케줄 정보가 없으면 예약 불가능으로 처리
      if (workStartStr == null || workEndStr == null) {
        proAvailability[proName] = false;
        print('⚠️ [경고] 프로 $proName(ID: $proId)의 근무시간 정보가 없어 예약 불가로 설정');
        continue;
      }
      
      final workStart = toMinutes(workStartStr);
      final workEnd = toMinutes(workEndStr);
      final breakStart = breakStartStr != null ? toMinutes(breakStartStr) : 0;
      final breakEnd = breakEndStr != null ? toMinutes(breakEndStr) : 0;
      
      // 예약 구간 추출
      List<List<int>> reserved = [];
      for (final order in (orders ?? [])) {
        final startTimeStr = order['LS_start_time'] ?? '';
        final endTimeStr = order['LS_end_time'] ?? '';
        
        if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) {
          final s = toMinutes(startTimeStr);
          final e = toMinutes(endTimeStr);
          
          if (s < e) {
            reserved.add([s, e]);
          }
        }
      }
      
      // 실제 예약 가능 구간 추출
      final availableBlocks = getAvailableBlocks(
        workStart: workStart,
        workEnd: workEnd,
        reserved: reserved,
        breakRange: [breakStart, breakEnd],
      );
      
      // 예약 가능 여부 저장
      proAvailability[proName] = availableBlocks.isNotEmpty;
      // 예약 가능 블록 저장
      proAvailableBlocks[proName] = availableBlocks;
      print('🔍 [디버깅] 프로 $proName(ID: $proId)의 예약 가능 여부: ${availableBlocks.isNotEmpty} (가능 시간대: ${availableBlocks.length}개)');
    }
    
    // 3. 프로 선택 다이얼로그
    final selectedPro = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('프로를 선택하세요', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                '예약 가능한 프로만 선택할 수 있습니다',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 12, 
                    height: 12, 
                    decoration: BoxDecoration(
                      color: Colors.green[100], 
                      borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('예약가능', style: TextStyle(fontSize: 11, color: Colors.green[800])),
                  const SizedBox(width: 12),
                  Container(
                    width: 12, 
                    height: 12, 
                    decoration: BoxDecoration(
                      color: Colors.red[100], 
                      borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('예약불가', style: TextStyle(fontSize: 11, color: Colors.red[800])),
                ],
              ),
              const Divider(height: 16),
            ],
          ),
          children: validPros.map((proData) {
            final String proName = proData['pro_name'] ?? '';
            final isAvailable = proAvailability[proName] ?? false;
            return SimpleDialogOption(
              // 예약 가능한 프로만 선택 가능하도록 설정
              onPressed: isAvailable ? () => Navigator.pop(context, proName) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        proName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.black87 : Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 예약 가능 상태에 따라 다른 상태 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvailable ? '예약가능' : '예약불가',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAvailable ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );

    if (selectedPro == null) return null;

    // 4. 선택한 프로의 정보 활용
    final proId = proIds[selectedPro];
    final availableBlocks = proAvailableBlocks[selectedPro] ?? [];

    // 5. 선택한 날짜와 프로로 예약 시간 선택 다이얼로그 표시
    if (proId != null) {
      // 미리 확인된 데이터를 사용하므로 API 재호출 불필요
      
      // 예약 가능 구간을 시간표 UI에 맞게 변환
      List<Map<String, dynamic>> slotBlocks = availableBlocks.map((b) => {
        'start': b['start'],
        'end': b['end'],
        'isBreak': false,
        'isReserved': false,
        'available': true,
      }).toList();
      // 날짜/요일 라벨 생성
      final date = DateTime.parse(scheduledDate);
      final dateLabel = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(date);
      
      // 사용 가능한 시간 중 가장 빠른 시간으로 초기화 (하드코딩 제거)
      int selectedHour = 0;
      int selectedMinute = 0;
      
      if (availableBlocks.isNotEmpty) {
        selectedHour = availableBlocks.first['start']! ~/ 60;
        selectedMinute = availableBlocks.first['start']! % 60;
      }
      
      try {
        return await showDialog<dynamic>(
          context: context,
          routeSettings: RouteSettings(name: 'lessonTimeSelection'),
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('예약 가능 시간표', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      // 예약 가능 여부에 따라 배지 표시
                      if (availableBlocks.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: const Text(
                            '불가능', 
                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: const Text(
                            '예약가능', 
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (availableBlocks.isNotEmpty)
                    const Text('시간대를 선택하면 타석 시작 시간으로 바로 적용됩니다.', 
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                ],
              ),
              // 스크롤 가능한 영역
              content: SingleChildScrollView(
                child: _buildTimeTableWithSummary(
                  availableBlocks, 
                  context,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('닫기', style: TextStyle(color: Colors.black87)),
                ),
              ],
            );
          },
        );
      } catch (e) {
        debugPrint('⚠️ [경고] 시간표 다이얼로그 표시 중 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('예약 가능 시간을 표시하는 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 3),
          ),
        );
        return null;
      }
    }
    return proId;
  }

  /// v2_member_pro_match 테이블에서 유효한 프로 목록 조회
  static Future<List<Map<String, dynamic>>> _fetchValidPros(int memberId, [String? branchId]) async {
    try {
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'relation_status', 'operator': '=', 'value': '유효'}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_member_pro_match',
          'fields': ['pro_id', 'pro_name', 'member_name', 'registered_at'],
          'where': whereConditions,
          'orderBy': [
            {'field': 'pro_name', 'direction': 'ASC'}
          ]
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        print('🔍 [디버깅] 유효한 프로 매칭 API 응답: $resp');
        
        if (resp['success'] == true && resp['data'] != null) {
          final validPros = List<Map<String, dynamic>>.from(resp['data'] as List);
          
          for (final pro in validPros) {
            print('✅ [정보] 유효한 프로 매칭: ' +
                  'pro_id=${pro['pro_id']}, ' +
                  'pro_name=${pro['pro_name']}, ' +
                  'registered_at=${pro['registered_at']}');
          }
          
          return validPros;
        }
      }
      
      print('⚠️ [경고] 유효한 프로 매칭 API 오류 또는 데이터 없음: ${response.statusCode}');
      return [];
    } catch (e) {
      print('⚠️ [경고] 유효한 프로 매칭 API 예외 발생: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchStaffSchedule(int proId, String scheduledDate, {String? branchId}) async {
    try {
      debugPrint('🔍 [디버깅] 스태프 스케줄 조회 시작 - pro_id: $proId, date: $scheduledDate, branchId: $branchId');
      
      // 1. v2_schedule_adjusted_pro 테이블에서 날짜별 개별 스케줄 확인
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'pro_id', 'operator': '=', 'value': proId},
        {'field': 'scheduled_date', 'operator': '=', 'value': scheduledDate}
      ];
      
      // branch_id 조건 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final requestBody = {
        'operation': 'get',
        'table': 'v2_schedule_adjusted_pro',
        'where': whereConditions
      };
      
      debugPrint('🔍 [디버깅] API 요청 본문: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      debugPrint('🔍 [디버깅] API 응답 상태코드: ${response.statusCode}');
      debugPrint('🔍 [디버깅] API 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true && resp['data'] != null) {
          debugPrint('✅ [성공] 개별 스케줄 API 응답: ${resp['data']}');
          final scheduleList = List<Map<String, dynamic>>.from(resp['data'] as List);
          if (scheduleList.isNotEmpty) {
            debugPrint('✅ [성공] 개별 스케줄 데이터 발견: ${scheduleList.first}');
            return scheduleList.first;
          } else {
            debugPrint('⚠️ [경고] 개별 스케줄 리스트가 비어있음');
          }
        } else {
          debugPrint('❌ [오류] 개별 스케줄 API 응답 실패: ${resp['error'] ?? "success가 false이거나 data가 null"}');
        }
      } else {
        debugPrint('❌ [오류] 개별 스케줄 HTTP 상태코드 오류: ${response.statusCode}');
      }
      
      // 2. 개별 스케줄이 없으면 schedule_weekly_base에서 요일별 기본 스케줄 확인
      debugPrint('🔍 [디버깅] 기본 스케줄 조회 시작');
      
      // 먼저 staff_nickname 조회
      List<Map<String, dynamic>> staffWhereConditions = [
        {'field': 'pro_id', 'operator': '=', 'value': proId}
      ];
      
      // staff 조회에도 branch_id 조건 추가
      if (branchId != null && branchId.isNotEmpty) {
        staffWhereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final staffNicknameResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_staff_pro',
          'fields': ['staff_nickname'],
          'where': staffWhereConditions
        }),
      );
      
      String? staffNickname;
      if (staffNicknameResponse.statusCode == 200) {
        final resp = jsonDecode(staffNicknameResponse.body);
        if (resp['success'] == true && resp['data'] != null && resp['data'].isNotEmpty) {
          staffNickname = resp['data'][0]['staff_nickname'];
          debugPrint('✅ [성공] 스태프 닉네임 조회: $staffNickname');
        }
      }
      
      if (staffNickname != null) {
        final DateTime date = DateTime.parse(scheduledDate);
        final int weekday = date.weekday == 7 ? 0 : date.weekday; // DateTime.weekday: 1(월)~7(일) → DB weekday: 0(일)~6(토)
        
        List<Map<String, dynamic>> weeklyWhereConditions = [
          {'field': 'staff_nickname', 'operator': '=', 'value': staffNickname},
          {'field': 'day_of_week', 'operator': '=', 'value': weekday}
        ];
        
        // 기본 스케줄 조회에도 branch_id 조건 추가
        if (branchId != null && branchId.isNotEmpty) {
          weeklyWhereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
        }
        
        final weeklyRequestBody = {
          'operation': 'get',
          'table': 'schedule_weekly_base',
          'where': weeklyWhereConditions
        };
        
        final weeklyResponse = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(weeklyRequestBody),
        );
        
        if (weeklyResponse.statusCode == 200) {
          final resp = jsonDecode(weeklyResponse.body);
          if (resp['success'] == true && resp['data'] != null) {
            final scheduleList = List<Map<String, dynamic>>.from(resp['data'] as List);
            if (scheduleList.isNotEmpty) {
              debugPrint('✅ [성공] 기본 스케줄 데이터 발견: ${scheduleList.first}');
              return scheduleList.first;
            }
          }
        }
      }
      
      debugPrint('⚠️ [경고] 프로 스케줄을 찾을 수 없음: pro_id=$proId, $scheduledDate');
      return null;
      
    } catch (e) {
      debugPrint('❌ [예외] 프로 스케줄 API 예외 발생: $e');
      return null;
    }
  }

  /// 선택한 프로의 예약 현황(LS_orders) 조회
  static Future<List<dynamic>> fetchProOrders(int proId, String scheduledDate, int memberId, {String? branchId}) async {
    try {
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'pro_id', 'operator': '=', 'value': proId},
        {'field': 'LS_date', 'operator': '=', 'value': scheduledDate}
      ];
      
      // branch_id 조건 추가 (branchId가 제공된 경우)
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'where': whereConditions,
          'orderBy': [
            {'field': 'LS_start_time', 'direction': 'ASC'}
          ]
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true) {
          final orders = resp['data'];
          debugPrint('프로 예약 현황 API 응답: $orders');
          
          if (orders != null && orders is List && orders.isNotEmpty) {
            // 문자열을 숫자로 변환
            return List<Map<String, dynamic>>.from(orders)
              .map((order) {
                // 필요한 숫자 필드들을 int로 변환
                _convertToInt(order, 'LS_order_id');
                _convertToInt(order, 'member_id');
                _convertToInt(order, 'TS_id');
                return order;
              }).toList();
          } else {
            debugPrint('프로 예약 현황이 없음: pro_id=$proId, $scheduledDate');
            return [];
          }
        } else {
          debugPrint('프로 예약 현황 API 오류: ${resp['error'] ?? "알 수 없는 오류"}');
          return [];
        }
      } else {
        debugPrint('프로 예약 현황 API HTTP 오류: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('프로 예약 현황 API 예외 발생: $e');
      return [];
    }
  }

  /// 예약/휴게 구간을 제외한 실제 예약 가능 구간 추출 (예약 구간 사이의 빈 구간만 available로 반환)
  static List<Map<String, int>> getAvailableBlocks({
    required int workStart,
    required int workEnd,
    required List<List<int>> reserved,
    required List<int> breakRange, // [breakStart, breakEnd]
  }) {
    try {
      // 예약 가능 블록 계산 전에 유효성 검사
      if (workStart >= workEnd) {
        debugPrint('⚠️ [경고] 근무 시간 오류: 시작($workStart)이 종료($workEnd)보다 크거나 같습니다.');
        return [];
      }

      List<List<int>> blocks = List.from(reserved);
      
      // 휴식 시간이 유효한 경우만 추가
      if (breakRange.length >= 2 && breakRange[0] < breakRange[1]) {
        blocks.add(breakRange);
        debugPrint('휴식 시간 추가: ${breakRange[0]}분 ~ ${breakRange[1]}분');
      } else {
        debugPrint('휴식 시간 무시: 유효하지 않은 범위');
      }
      
      // 예약 블록 정렬
      blocks.sort((a, b) => a[0].compareTo(b[0]));
      
      List<Map<String, int>> available = [];
      int cursor = workStart;
      
      // 각 블록 사이의 빈 구간 추출
      for (final b in blocks) {
        if (b.length < 2) {
          debugPrint('⚠️ [경고] 유효하지 않은 블록 무시: $b');
          continue;  // 유효하지 않은 블록 무시
        }
        
        if (cursor < b[0]) {
          available.add({'start': cursor, 'end': b[0]});
          debugPrint('가능 구간 추가: $cursor분 ~ ${b[0]}분');
        }
        cursor = b[1] > cursor ? b[1] : cursor;
      }
      
      // 마지막 블록 이후의 시간이 있는 경우
      if (cursor < workEnd) {
        available.add({'start': cursor, 'end': workEnd});
        debugPrint('가능 구간 추가: $cursor분 ~ ${workEnd}분');
      }
      
      // 예약 구간 사이의 빈 구간만 남기고, 예약 구간과 겹치거나 0분짜리 구간은 제외
      final validBlocks = available.where((b) => b['end']! > b['start']!).toList();
      debugPrint('최종 가능 구간 수: ${validBlocks.length}개');
      return validBlocks;
    } catch (e) {
      debugPrint('⚠️ [경고] 예약 가능 구간 계산 중 오류: $e');
      return [];
    }
  }

  /// 예약 가능 시간대 선택 위젯 생성
  static Widget _buildTimeTableWithSummary(List<Map<String, int>> blocks, BuildContext context) {
    // 사용 가능한 시간 블록이 없는 경우 메시지 표시
    if (blocks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.access_time, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            '예약 가능한 시간이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 날짜나 프로를 선택해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        const SizedBox(height: 12),
        const Text('예약 가능 시간', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        // 예약 가능 구간을 시간대별로 정리하여 표시
        Container(
          width: double.infinity,
          child: _buildTimeSlotsByHour(blocks, context),
        ),
      ],
    );
  }

  // 시간대별로 정리된 시간표 형식 생성
  static Widget _buildTimeSlotsByHour(List<Map<String, int>> blocks, BuildContext context) {
    // 블록이 비어있으면 빈 Column 반환
    if (blocks.isEmpty) {
      return const Column(children: []);
    }
    
    // 시간대별로 블록 그룹화
    Map<int, List<Map<String, int>>> hourlyBlocks = {};
    
    // 각 블록을 시간대별로 분류
    for (final block in blocks) {
      final startHour = block['start']! ~/ 60;
      final endHour = block['end']! ~/ 60;
      
      // 블록이 여러 시간대에 걸쳐 있을 수 있음
      for (int hour = startHour; hour <= endHour; hour++) {
        hourlyBlocks[hour] = hourlyBlocks[hour] ?? [];
        
        // 현재 시간대에 맞게 블록 자르기
        int adjustedStart = block['start']!;
        int adjustedEnd = block['end']!;
        
        // 시작 시간이 현재 시간대보다 이전이면 현재 시간대 시작으로 조정
        if (hour > startHour) {
          adjustedStart = hour * 60;
        }
        
        // 종료 시간이 다음 시간대면 현재 시간대 끝으로 조정
        if (hour < endHour) {
          adjustedEnd = (hour + 1) * 60;
        }
        
        // 0분 이상의 유효한 블록만 추가
        if (adjustedEnd > adjustedStart) {
          hourlyBlocks[hour]!.add({
            'start': adjustedStart,
            'end': adjustedEnd
          });
        }
      }
    }
    
    // 시간대별로 정렬된 리스트 생성
    List<int> sortedHours = hourlyBlocks.keys.toList()..sort();
    
    // 정렬된 시간대가 없으면 빈 Column 반환
    if (sortedHours.isEmpty) {
      return const Column(children: []);
    }
    
    return Column(
      children: sortedHours.map((hour) {
        // 해당 시간대의 블록들
        final timeBlocks = hourlyBlocks[hour]!;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시간대 헤더 (왼쪽에 배치)
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '$hour시',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 해당 시간대의 예약 가능 시간들 (오른쪽에 배치)
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeBlocks.map((block) {
                    final startHour = block['start']! ~/ 60;
                    final startMinute = block['start']! % 60;
                    final endHour = block['end']! ~/ 60;
                    final endMinute = block['end']! % 60;
                    
                    return _buildTimeRangeButton(
                      startHour, startMinute,
                      endHour, endMinute,
                      context,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _buildTimeRangeButton(
      int startHour, int startMinute, 
      int endHour, int endMinute, 
      BuildContext context) {
    
    // 시작 시간과 종료 시간 형식화
    String startTimeStr = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    String endTimeStr = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        print('🔍 [디버깅] 레슨 시간 범위 선택: ${startHour}:${startMinute.toString().padLeft(2, '0')}~${endHour}:${endMinute.toString().padLeft(2, '0')}');
        // 시간 선택 즉시 결과 반환하고 모달 닫기
        Navigator.pop(context, {
          'hour': startHour, 
          'minute': startMinute,
          'formatted': startTimeStr
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$startTimeStr ~ $endTimeStr',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
        ),
      ),
    );
  }

  static Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(width: 18, height: 10, decoration: BoxDecoration(color: const Color(0xFF2196F3), borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          const Text('예약 가능', style: TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  // 문자열을 정수로 변환하는 헬퍼 메서드
  static void _convertToInt(Map<String, dynamic> map, String key) {
    if (map.containsKey(key)) {
      var value = map[key];
      if (value is String) {
        map[key] = int.tryParse(value) ?? 0;
      } else if (value is! int) {
        map[key] = 0;
      }
    }
  }
} 