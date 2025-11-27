import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'holiday_service.dart';
import 'discount_term_member.dart';
import 'discount_junior_parent.dart';
import '../utils/time_slot_utils.dart';
import 'discount_revisit.dart';
import '../config/ts_option.dart';
import '../services/api_service.dart';

class ReservationService {
  // API 서버 정보
  static const String _apiKey = 'autofms_secure_key_2025';
  static const String _serverHost = 'autofms.mycafe24.com';
  
  // 할인율, 집중연습 할인 등 ts_option에서 읽어오는 헬퍼
  static double get memberDiscountRate => (ts_option["discount"]["member"]["rate"] as num).toDouble();
  static int get intensiveDiscount90 => ts_option["discount"]["intensive"]["min90"] as int;
  static int get intensiveDiscount120 => ts_option["discount"]["intensive"]["min120"] as int;
  static int get intensiveDiscountBelow90 => ts_option["discount"]["intensive"]["below90"] as int;
  static bool get memberDiscountOnlyCredit => ts_option["payment"]["memberDiscountOnlyCredit"] as bool;
  
  /// 타석 이용 가능 여부 확인
  /// 
  /// [date]: 예약할 날짜
  /// [startTime]: 시작 시간
  /// [durationMinutes]: 이용 시간(분)
  /// 
  /// 반환값: 각 타석의 이용 가능 여부 정보가 담긴 리스트
  /// 오류 발생 시 예외를 throw하여 UI에서 처리하도록 함
  static Future<List<Map<String, dynamic>>> getAvailableTSs(
    DateTime date, 
    TimeOfDay startTime, 
    int durationMinutes,
    {String? branchId}
  ) async {
    // 시작 시간과 종료 시간 계산
    final startDateTime = DateTime(
      date.year, date.month, date.day, 
      startTime.hour, startTime.minute
    );
    
    final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
    
    // API 요청 형식에 맞게 날짜/시간 포맷팅
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final formattedStart = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
    final formattedEnd = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}:00';
    
    if (kDebugMode) {
      print('🔍 타석 예약 조회 요청: $formattedDate $formattedStart~$formattedEnd, branchId: $branchId');
      print('🔍 [디버깅] 시간 정보 상세 - 시작 시간(TimeOfDay): ${startTime.hour}시 ${startTime.minute}분');
      print('🔍 [디버깅] 시간 정보 상세 - 시작 시간(변환): $formattedStart');
      print('🔍 [디버깅] 시간 정보 상세 - 종료 시간(변환): $formattedEnd');
      print('🔍 [디버깅] 예약 날짜: ${date.year}년 ${date.month}월 ${date.day}일');
      print('🔍 [디버깅] 연습 시간: $durationMinutes분');
    }
    
    try {
      // where 조건 구성
      final List<Map<String, dynamic>> whereConditions = [
        {'field': 'ts_date', 'operator': '=', 'value': formattedDate},
        {'field': 'ts_status', 'operator': '=', 'value': '결제완료'}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse('https://$_serverHost/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'fields': ['ts_id', 'ts_start', 'ts_end', 'ts_status'],
          'where': whereConditions
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('서버 응답 시간이 초과되었습니다.');
        },
      );
      
      if (kDebugMode) {
        print('📡 API 응답 상태 코드: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          print('📡 API 응답 본문 프리뷰: ${response.body.substring(0, min(200, response.body.length))}');
        }
      }
      
      // 모든 타석에 대한 기본 정보 생성 (1~9번)
      final List<Map<String, dynamic>> allTeeSlots = List.generate(9, (index) {
        final slotNumber = index + 1;
        return {
          'number': slotNumber,
          'isAvailable': true, // 기본적으로 사용 가능으로 설정
          'type': slotNumber <= 6 ? '오픈타석' : '단독타석',
        };
      });
      
      // 응답 검증 및 처리
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> reservations = responseData['data'];
          
          // 예약된 타석들을 확인하여 사용 불가능으로 표시
          for (var reservation in reservations) {
            final int tsId = int.tryParse(reservation['ts_id'].toString()) ?? 0;
            final String reservedStart = reservation['ts_start'] ?? '';
            final String reservedEnd = reservation['ts_end'] ?? '';
            
            // 시간 겹침 확인
            if (tsId >= 1 && tsId <= 9 && _isTimeOverlap(formattedStart, formattedEnd, reservedStart, reservedEnd)) {
              allTeeSlots[tsId - 1]['isAvailable'] = false;
            }
          }
          
          if (kDebugMode && allTeeSlots.isNotEmpty) {
            print('🔢 첫 번째 타석 정보: ${allTeeSlots.first}');
            print('타석 조회 결과: ${reservations.length}개 예약 확인, 총 ${allTeeSlots.length}개 타석 표시');
          }
          
          return allTeeSlots;
        } else {
          if (kDebugMode) {
            print('❌ API 오류 응답: ${responseData['error'] ?? "알 수 없는 오류"}');
          }
          throw Exception('API 오류 응답: ${responseData['error'] ?? "알 수 없는 오류"}');
        }
      } else {
        if (kDebugMode) {
          print('❌ HTTP 상태 코드 오류: ${response.statusCode}');
          print('❌ 응답 본문: ${response.body}');
        }
        throw Exception('HTTP 오류 응답 [${response.statusCode}]');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 타석 정보 조회 오류: $e');
        print('❌ 스택 트레이스: ${StackTrace.current}');
      }
      // 오류 발생 시, 기본 타석 정보 반환
      return List.generate(9, (index) {
        final slotNumber = index + 1;
        return {
          'number': slotNumber,
          'isAvailable': true,
          'type': slotNumber <= 6 ? '오픈타석' : '단독타석',
        };
      });
    }
  }
  
  // 시간 겹침 확인 헬퍼 함수
  static bool _isTimeOverlap(String start1, String end1, String start2, String end2) {
    try {
      final DateTime startTime1 = DateTime.parse('2000-01-01 $start1');
      final DateTime endTime1 = DateTime.parse('2000-01-01 $end1');
      final DateTime startTime2 = DateTime.parse('2000-01-01 $start2');
      final DateTime endTime2 = DateTime.parse('2000-01-01 $end2');
      
      return startTime1.isBefore(endTime2) && endTime1.isAfter(startTime2);
    } catch (e) {
      if (kDebugMode) {
        print('시간 겹침 확인 오류: $e');
      }
      return false;
    }
  }
  
  /// 타석 요금표 조회
  /// 
  /// 반환값: Map<int, Map<String, int>> 형태의 요금표
  /// 오류 발생 시 예외를 throw
  static Future<Map<int, Map<String, int>>> getPriceTable({String? branchId}) async {
    try {
      if (kDebugMode) {
        print('🌐 타석 요금표 조회 요청');
      }
      
      // ApiService의 새로운 getPriceTable 함수 사용
      final priceData = await ApiService.getPriceTable(branchId: branchId);
      
      if (priceData == null || priceData.isEmpty) {
        throw Exception('요금표 데이터를 가져올 수 없습니다.');
      }
      
      final Map<int, Map<String, int>> priceTable = {};
      
      // API 응답 데이터를 파싱하여 요금표 생성
      for (var item in priceData) {
        try {
          // 문자열이나 다른 타입으로 들어오는 경우 int로 변환
          final int tsId = item['ts_id'] is int 
            ? item['ts_id'] 
            : int.parse(item['ts_id'].toString());
          
          // 각 가격 필드도 int로 변환
          final morningPrice = item['ts_price_morning'] is int 
            ? item['ts_price_morning'] 
            : int.parse(item['ts_price_morning'].toString());
            
          final normalPrice = item['ts_price_normal'] is int 
            ? item['ts_price_normal'] 
            : int.parse(item['ts_price_normal'].toString());
            
          final peakPrice = item['ts_price_peak'] is int 
            ? item['ts_price_peak'] 
            : int.parse(item['ts_price_peak'].toString());
            
          final nightPrice = item['ts_price_night'] is int 
            ? item['ts_price_night'] 
            : int.parse(item['ts_price_night'].toString());
          
          priceTable[tsId] = {
            '조조': morningPrice,
            '일반': normalPrice,
            '피크': peakPrice,
            '심야': nightPrice,
          };
          
          if (kDebugMode) {
            print('🔢 타석 ID $tsId의 요금 정보: 조조=$morningPrice, 일반=$normalPrice, 피크=$peakPrice, 심야=$nightPrice');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 요금표 변환 오류: $e, 데이터: ${jsonEncode(item)}');
          }
          // 오류가 발생한 타석은 건너뛰기
          continue;
        }
      }
      
      if (kDebugMode) {
        print('💰 요금표 로드 완료: ${priceTable.length}개 타석 요금 정보');
      }
      
      return priceTable;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 요금표 조회 오류: $e');
        print('❌ 스택 트레이스: ${StackTrace.current}');
      }
      throw Exception('요금표를 가져오는 중 오류가 발생했습니다: $e');
    }
  }
  
  /// 타석 요금 계산
  /// 
  /// [tsNumber]: 타석 번호
  /// [timeSlots]: 시간대별 이용 시간(분) 맵 {'조조': 30, '일반': 20, '피크': 10, '심야': 0}
  /// [startTimeHours]: 시작 시간 (시, 선택적)
  /// [startTimeMinutes]: 시작 시간 (분, 선택적)
  /// [durationMinutes]: 이용 시간(분, 선택적)
  /// 
  /// 반환값: 요금 정보 맵
  /// {
  ///   'totalAmount': 총 요금(원),
  ///   'details': [
  ///     {'timeSlot': '조조', 'minutes': 30, 'price': 280, 'amount': 140},
  ///     {'timeSlot': '일반', 'minutes': 20, 'price': 350, 'amount': 117},
  ///     ...
  ///   ]
  /// }
  static Future<Map<String, dynamic>> calculateFee(
    int tsNumber, 
    Map<String, int> timeSlots, 
    {
    int? startTimeHours,
    int? startTimeMinutes,
    int? durationMinutes,
    bool? membershipStatus,
    String? membershipType,
    required int memberId,
    required String tsDate,
    required String tsStart,
    required String tsEnd,
    List<dynamic>? discounts,
    String? branchId,
  }) async {
    try {
      // membershipDiscountTarget 변수를 함수 try 블록 시작 직후에 선언
      int membershipDiscountTarget = 0;
      int juniorParentDiscount = 0;
      // DB에서 요금표 가져오기
      final priceTable = await getPriceTable(branchId: branchId);
      
      // 해당 타석의 요금표 가져오기 (없으면 예외 발생)
      final prices = priceTable[tsNumber];
      if (prices == null) {
        throw Exception('$tsNumber번 타석의 요금 정보를 찾을 수 없습니다.');
      }
      if (kDebugMode) {
        print('🧮 요금 계산 시작 - 타석: $tsNumber');
        print('⏱️ 시간대 분류: $timeSlots');
        if (startTimeHours != null) {
          final startTimeStr = '${startTimeHours.toString().padLeft(2, '0')}:${(startTimeMinutes ?? 0).toString().padLeft(2, '0')}';
          print('⏰ 시작 시간: $startTimeStr, 이용 시간: ${durationMinutes ?? 0}분');
        }
        // 초기 요금 계산에 사용된 시간대 분류를 표시
        print('🔍 초기 요금 계산에 사용된 시간대 분류:');
        for (var entry in timeSlots.entries) {
          if (entry.value > 0) {
            print('   ${entry.key}: ${entry.value}분, 분당 ${prices[entry.key]}원');
          }
        }
      }
      
      // 요금 계산
      int totalAmount = 0;
      List<Map<String, dynamic>> details = [];
      
      timeSlots.forEach((timeSlot, minutes) {
        if (minutes > 0) {
          // 시간대 요금 가져오기 (없으면 일반 요금 기본값)
          final int pricePerMinute = prices[timeSlot] ?? prices['일반'] ?? 0;
          if (pricePerMinute == 0) {
            throw Exception('$timeSlot 시간대의 요금 정보가 올바르지 않습니다.');
          }
          
          // 분당 요금에 이용 시간(분)을 곱하여 계산
          final amount = (pricePerMinute * minutes).round();
          
          totalAmount += amount;
          details.add({
            'timeSlot': timeSlot,
            'minutes': minutes,
            'pricePerMinute': pricePerMinute,
            'pricePerHour': pricePerMinute * 60, // 시간당 요금 추가
            'amount': amount
          });
        }
      });
      
      // 재방문 할인(직전 1주일 일반예약 횟수 기반) 계산
      int revisitDiscount = 0;
      Map<String, dynamic> revisitResult = {'discount': 0, 'hours': 0.0};
      try {
        revisitResult = await DiscountRevisit.calculateRevisitDiscountAmount(
          memberId: memberId,
          branchId: branchId,
          baseDate: tsDate,
        );
        revisitDiscount = revisitResult['discount'] ?? 0;
        if (kDebugMode) {
          print('🟢 [재방문 할인] 직전 1주일 환산횟수 ${revisitResult['hours']?.toStringAsFixed(2) ?? '0.00'}회, 할인액: ${revisitDiscount}원');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ [재방문 할인 계산 오류] $e');
        }
        revisitDiscount = 0;
        revisitResult = {'discount': 0, 'hours': 0.0};
      }
      
      if (kDebugMode) {
        print('💲 요금 계산 결과: $tsNumber번 타석, 총액: $totalAmount원');
        for (var detail in details) {
          print('   - ${detail['timeSlot']}: ${detail['minutes']}분, 분당 ${detail['pricePerMinute']}원 (시간당 ${detail['pricePerHour']}원) = ${detail['amount']}원');
        }
        
        // ====== [기간권 할인 계산 - 분리된 로직 호출] ======
        try {
          final membershipInfo = await DiscountTermMember.getMembershipInfo(memberId, branchId, tsDate);
          final String dayType = (membershipInfo['dayType'] ?? '').toString();
          final String termType = (membershipInfo['termType'] ?? '').toString();
          print('[기간권할인-DEBUG] calculateTermDiscountTarget 호출 직전');
          print('  timeSlots: ' + timeSlots.toString());
          print('  durationMinutes: ' + (durationMinutes?.toString() ?? 'null'));
          print('  memberId: ' + memberId.toString());
          print('  tsDate: ' + tsDate);
          print('  dayType: ' + dayType);
          print('  termType: ' + termType);
          membershipDiscountTarget = await DiscountTermMember.calculateTermDiscountTarget(
            memberId: memberId,
            tsDate: tsDate,
            timeSlots: timeSlots,
            startTimeHours: startTimeHours ?? 0,
            startTimeMinutes: startTimeMinutes ?? 0,
            durationMinutes: durationMinutes ?? 0,
            dayType: dayType,
            termType: termType,
            branchId: branchId,
          );
          if (kDebugMode) {
            print('🟢 [calculateFee] 기간권 할인 대상 금액: '
                '\u001b[32m$membershipDiscountTarget\u001b[0m');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ [calculateFee] 기간권 할인 계산 오류: $e');
          }
          membershipDiscountTarget = 0;
        }
        // ====== [기간권 할인 계산 끝] ======

        // ====== [회원 당일 예약 현황 조회] ======
        try {
          final url = 'https://$_serverHost/dynamic_api.php';
          
          // WHERE 조건 구성
          final whereConditions = [
            {'field': 'member_id', 'operator': '=', 'value': memberId}
          ];
          
          // branchId가 제공된 경우 조건에 추가
          if (branchId != null && branchId.isNotEmpty) {
            whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
          }
          
          final params = {
            'operation': 'get',
            'table': 'v2_priced_TS',
            'where': whereConditions
          };
          
          Map<String, String> headers = {
            'X-API-Key': _apiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };
          final response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(params),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('서버 응답 시간이 초과되었습니다.');
            },
          );
          if (kDebugMode) {
            print('\n[회원 당일 예약 현황 조회]');
            print('API 요청 파라미터: $params');
            print('응답 상태 코드: \u001b[32m\u001b[1m${response.statusCode}\u001b[0m');
            if (response.body.isNotEmpty) {
              final responseData = jsonDecode(response.body);
              if (responseData['success'] == true) {
                final reservations = responseData['data'] as List<dynamic>;
                // 결제완료 상태만 필터링
                final paidReservations = reservations.where((r) => r['ts_status'] == '결제완료').toList();
                print('결제완료 예약 건수: \u001b[32m${paidReservations.length}\u001b[0m');
                for (var r in paidReservations) {
                  print(' - 예약: $r');
                }

                // ====== [주니어 학부모 할인 계산 및 안내 메시지 출력] ======
                final priceTable = await getPriceTable(branchId: branchId);
                final discountResult = await DiscountJuniorParent.calculateJuniorParentDiscount(
                  paidReservations: paidReservations,
                  tsNumber: tsNumber,
                  tsDate: tsDate,
                  tsStart: tsStart,
                  tsEnd: tsEnd,
                  priceTable: priceTable,
                );
                print('   > ${discountResult['message']}');
                if (discountResult['duplicateMessage'] != null) {
                  print('   > ${discountResult['duplicateMessage']}');
                }
                // 실제 할인 금액을 반환값에 포함
                if (discountResult['amount'] != null) {
                  juniorParentDiscount = discountResult['amount'] as int? ?? 0;
                }
                // ====== [주니어 학부모 할인 안내 끝] ======
              } else {
                print('예약 조회 실패: ${responseData['error']}');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 회원 당일 예약 현황 조회 오류: $e');
          }
        }
        // ====== [회원 당일 예약 현황 조회 끝] ======

        // 반환값에 membershipDiscountTarget, juniorParentDiscount, revisitDiscount 추가
        Map<String, dynamic> returnValue = {
          'totalAmount': totalAmount,
          'details': details,
          'membershipDiscountTarget': membershipDiscountTarget,
          'juniorParentDiscount': juniorParentDiscount,
          'revisitDiscount': revisitDiscount,
          'revisitHours': revisitResult['hours'] ?? 0.0,
        };
        return returnValue;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 요금 계산 중 오류 발생: $e');
      }
      // 함수 마지막에 도달할 경우(논리적 실수 방지용) 기본값 반환
      return {
        'totalAmount': 0,
        'details': [],
        'membershipDiscountTarget': 0,
        'juniorParentDiscount': 0,
        'revisitDiscount': 0,
        'revisitHours': 0.0,
        'error': e.toString(),
      };
    }
    // 모든 경로에서 return이 보장되도록 안전 return 추가
    return {
      'totalAmount': 0,
      'details': [],
      'membershipDiscountTarget': 0,
      'juniorParentDiscount': 0,
      'revisitDiscount': 0,
      'revisitHours': 0.0,
      'error': 'Unreachable code fallback',
    };
  }
  
  /// 시뮬레이션 전용 요금 계산 (DB/API 접근 없이 단순 계산만)
  static Future<Map<String, dynamic>> calculateFeeSimulation(
    int tsNumber,
    Map<String, int> timeSlots,
    {
    required Map<int, Map<String, int>> priceTable,
  }) async {
    int totalAmount = 0;
    List<Map<String, dynamic>> details = [];
    final prices = priceTable[tsNumber];
    if (prices == null) {
      throw Exception('$tsNumber번 타석의 요금 정보를 찾을 수 없습니다.');
    }
    timeSlots.forEach((timeSlot, minutes) {
      if (minutes > 0) {
        final int pricePerMinute = prices[timeSlot] ?? prices['일반'] ?? 0;
        if (pricePerMinute == 0) {
          throw Exception('$timeSlot 시간대의 요금 정보가 올바르지 않습니다.');
        }
        final amount = (pricePerMinute * minutes).round();
        totalAmount += amount;
        details.add({
          'timeSlot': timeSlot,
          'minutes': minutes,
          'pricePerMinute': pricePerMinute,
          'pricePerHour': pricePerMinute * 60,
          'amount': amount
        });
      }
    });
    return {
      'totalAmount': totalAmount,
      'details': details,
    };
  }
  
  /// 회원의 기간권 보유 상태 확인 (상세 정보 포함)
  /// 
  /// [memberId]: 회원 ID
  /// [branchId]: 지점 ID
  /// 
  /// 반환값: 기간권 정보를 포함한 Map
  /// {
  ///   'hasMembership': true/false,  // 유효한 기간권 보유 여부
  ///   'holdStartDate': 홀드 시작일 (있는 경우),
  ///   'holdEndDate': 홀드 종료일 (있는 경우),
  ///   'expiryDate': 만료일 (유효한 기간권이 있는 경우),
  ///   'termType': 기간권 타입
  /// }
  static Future<Map<String, dynamic>> checkMembershipStatusWithDetails(int? memberId, [String? branchId]) async {
    if (kDebugMode) {
      print('🔍 기간권 상세 정보 확인 - 회원 ID: $memberId, 지점 ID: $branchId');
      print('🔍 [디버깅] checkMembershipStatusWithDetails 호출됨 - memberId 타입: ${memberId?.runtimeType}, 값: $memberId');
    }
    
    // 결과 맵 초기화
    Map<String, dynamic> result = {
      'hasMembership': false,
      'holdStartDate': '',
      'holdEndDate': '',
      'expiryDate': '',
      'termType': '',  // term_type 저장 필드 추가
    };
    
    // memberId가 null이거나 0 이하인 경우 API 호출 없이 즉시 결과 반환
    if (memberId == null || memberId <= 0) {
      if (kDebugMode) {
        print('❌ [디버깅] 회원 ID가 유효하지 않음 (null 또는 <= 0): $memberId');
      }
      return result;
    }
    
    try {
      // API 요청 데이터 준비
      final Map<String, dynamic> params = {
        'member_id': memberId,
      };
      
      // branchId가 제공된 경우 추가
      if (branchId != null && branchId.isNotEmpty) {
        params['branch_id'] = branchId;
      }
      
      // 디버깅: 요청 파라미터 확인
      if (kDebugMode) {
        print('🔍 [디버깅] API 요청 파라미터: $params');
        print('🔍 [디버깅] API 요청 파라미터 타입 - member_id: ${params['member_id'].runtimeType}');
      }
      
      // API 요청 URL 생성
      final url = 'https://$_serverHost/dynamic_api.php';
      
      if (kDebugMode) {
        print('🌐 API 요청 URL: $url');
        print('🌐 API 요청 파라미터: ${jsonEncode(params)}');
      }
      
      // HTTP 헤더 설정
      Map<String, String> headers = {
        'X-API-Key': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // API 요청 실행
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(params),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            print('🔍 [디버깅] API 요청 타임아웃');
          }
          throw Exception('서버 응답 시간이 초과되었습니다.');
        },
      );
      
      // 404 오류 처리 (API 엔드포인트가 없는 경우)
      if (response.statusCode == 404) {
        if (kDebugMode) {
          print('⚠️ [디버깅] API 엔드포인트를 찾을 수 없음 (404): getTermMember');
        }
        return result;
      }
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['terms'] != null) {
          final List<dynamic> terms = responseData['terms'];
          
          // 현재 날짜
          final now = DateTime.now();
          final nowFormatted = DateFormat('yyyy-MM-dd').format(now);
          
          if (kDebugMode) {
            print('🔍 [디버깅] 현재 날짜: $nowFormatted');
          }
          
          // 회원 상태 변수
          bool hasValidPeriod = false;  // 유효한 기간 내 기간권이 있는지
          bool isInHoldPeriodAny = false;  // 하나라도 홀드 기간 내에 있는지
          String validExpiryDate = '';  // 유효한 기간권의 만료일
          String validTermType = '';  // 유효한 기간권의 타입
          String currentHoldStartDate = '';  // 현재 홀드 기간 시작일
          String currentHoldEndDate = '';  // 현재 홀드 기간 종료일
          String holdTermType = '';  // 홀드 중인 기간권의 타입
          
          // 모든 기간권을 검사하여 상태 확인
          for (var term in terms) {
            // 필수 필드 존재 여부 확인
            if (!term.containsKey('term_startdate') || !term.containsKey('term_expirydate')) {
              continue; // 필수 필드가 없으면 다음 항목으로
            }
            
            // 시작일과 만료일 확인
            String startDateRaw = term['term_startdate'] as String;
            String expiryDateRaw = term['term_expirydate'] as String;
            final String startDate = startDateRaw.length >= 10 ? startDateRaw.substring(0, 10) : startDateRaw;
            final String expiryDate = expiryDateRaw.length >= 10 ? expiryDateRaw.substring(0, 10) : expiryDateRaw;
            final String termType = term['term_type'] as String? ?? '알 수 없음';  // term_type 가져오기
            
            // 홀드 기간 확인
            final String? holdStartDate = term['term_holdstart'] as String?;
            final String? holdEndDate = term['term_holdend'] as String?;
            
            // 현재 날짜가 시작일과 만료일 사이에 있는지 확인
            bool isWithinValidPeriod = startDate.compareTo(nowFormatted) <= 0 && expiryDate.compareTo(nowFormatted) >= 0;
            
            if (isWithinValidPeriod) {
              hasValidPeriod = true;  // 유효한 기간 내 기간권 있음
              
              // 만료일이 더 나중인 경우 업데이트 (가장 나중에 만료되는 기간권 정보 저장)
              if (validExpiryDate.isEmpty || expiryDate.compareTo(validExpiryDate) > 0) {
                validExpiryDate = expiryDate;
                validTermType = termType;  // 해당 기간권의 타입도 함께 저장
              }
            }
            
            // 홀드 기간 내에 있는지 확인
            if (holdStartDate != null && holdStartDate.isNotEmpty && 
                holdEndDate != null && holdEndDate.isNotEmpty) {
              bool isThisTermInHold = holdStartDate.compareTo(nowFormatted) <= 0 && holdEndDate.compareTo(nowFormatted) >= 0;
              
              // 하나라도 홀드 기간 내에 있으면 홀드 상태로 간주
              if (isThisTermInHold) {
                isInHoldPeriodAny = true;
                
                // 홀드 정보 저장 (가장 나중에 종료되는 홀드 정보 저장)
                if (currentHoldEndDate.isEmpty || holdEndDate.compareTo(currentHoldEndDate) > 0) {
                  currentHoldStartDate = holdStartDate;
                  currentHoldEndDate = holdEndDate;
                  holdTermType = termType; // 홀드 중인 기간권의 타입 저장
                }
              }
            }
          }
          
          // 결과 맵 업데이트
          result['hasMembership'] = hasValidPeriod && !isInHoldPeriodAny;
          
          if (hasValidPeriod) {
            result['expiryDate'] = validExpiryDate;
            result['termType'] = validTermType;  // 기간권 타입 저장
          }
          
          if (isInHoldPeriodAny) {
            result['holdStartDate'] = currentHoldStartDate;
            result['holdEndDate'] = currentHoldEndDate;
            result['termType'] = holdTermType; // 홀드 중인 경우에도 기간권 타입 정보 저장
          }
          
          if (kDebugMode) {
            if (hasValidPeriod && !isInHoldPeriodAny) {
              print('✅ 유효한 기간권 있음 - 홀드 상태 아님 - 타입: $validTermType, 만료일: $validExpiryDate');
            } else if (hasValidPeriod && isInHoldPeriodAny) {
              print('❌ 홀드 기간 중이므로 기간권 사용 불가 - 타입: $holdTermType, 홀드 기간: $currentHoldStartDate ~ $currentHoldEndDate');
            } else {
              print('❌ 유효한 기간권이 없음');
            }
          }
        }
      }
      
      return result;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 기간권 정보 조회 오류: $e');
      }
      return result;
    }
  }
  
  /// 회원의 기간권 보유 상태 확인 (하위 호환성 유지)
  /// 
  /// [memberId]: 회원 ID
  /// [branchId]: 지점 ID
  /// 
  /// 반환값: 유효한 기간권 보유 여부를 나타내는 불리언 값
  static Future<bool> checkMembershipStatus(int? memberId, [String? branchId]) async {
    final result = await checkMembershipStatusWithDetails(memberId, branchId);
    return result['hasMembership'];
  }
  
  // 문자열 길이 제한 헬퍼 함수
  static int min(int a, int b) {
    return (a < b) ? a : b;
  }

  static Future<String?> getMemberType(int memberId, [String? branchId]) async {
    try {
      final member = await ApiService.getUserProfile(memberId.toString(), branchId: branchId);
      if (member != null) {
        return member['member_type'] ?? 'default';
      }
    } catch (e) {
      // 에러 무시하고 default 반환
      if (kDebugMode) {
        print('회원 타입 조회 오류: $e');
      }
    }
    return 'default';
  }

  static Future<List<Map<String, dynamic>>> getTSReservationsByMember(int memberId, [String? branchId]) async {
    try {
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse('https://$_serverHost/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': whereConditions
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching TS reservations: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getTermMember(int memberId, {String? branchId}) async {
    try {
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final response = await http.post(
        Uri.parse('https://$_serverHost/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v3_members',
          'where': whereConditions
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
          return Map<String, dynamic>.from(data['data'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching term member: $e');
      return null;
    }
  }
} 