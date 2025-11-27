import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class ReservationSelfTsMove {
  static Future<void> handleSelfMove(
    BuildContext context, 
    Map<String, dynamic> reservation, {
    Function(String newReservationId, int newTsId)? onMoveSuccess,
  }) async {
    try {
      // 현재 예약 정보 디버깅
      print('=== 현재 예약 정보 ===');
      print('전체 reservation 객체: $reservation');
      print('');
      print('reservation_id: ${reservation['reservationId']}');
      print('ts_id: ${reservation['station']}');
      print('date: ${reservation['date']}');
      print('startTime: ${reservation['startTime']}');
      print('endTime: ${reservation['endTime']}');
      
      // API 호출하여 해당 날짜의 예약 현황 가져오기
      final branchId = ApiService.getCurrentBranchId();
      final reservationDate = reservation['date'];
      
      final response = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'ts_date', 'operator': '=', 'value': reservationDate},
          {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        ],
        fields: [
          'reservation_id', 'ts_id', 'ts_date', 'ts_start', 'ts_end',
          'member_id', 'member_name', 'member_phone',
          'total_amt', 'term_discount', 'coupon_discount', 'total_discount', 'net_amt',
          'discount_min', 'normal_min', 'extracharge_min', 'ts_min', 'bill_min',
          'ts_payment_method', 'program_id', 'program_name'
        ],
        orderBy: [{'field': 'ts_start', 'direction': 'ASC'}],
      );
      
      Map<String, dynamic> currentReservation = {};
      
      if (response.isNotEmpty) {
        print('\n=== 당일 유효예약 현황 ===');
        for (var slot in response) {
          print('ts_id: ${slot['ts_id']}, ts_date: ${slot['ts_date']}, ts_start: ${slot['ts_start']}, ts_end: ${slot['ts_end']}, reservation_id: ${slot['reservation_id']}');
        }
        
        // 현재 예약 찾기
        currentReservation = response.firstWhere(
          (slot) => slot['reservation_id'] == reservation['reservationId'],
          orElse: () => {},
        );
      } else {
        print('예약 현황을 가져오는데 실패했습니다.');
      }
      
      // v2_ts_info 테이블 조회
      final tsInfoResponse = await ApiService.getData(
        table: 'v2_ts_info',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_id', 'operator': '=', 'value': reservation['station']},
        ],
      );
      
      if (tsInfoResponse.isNotEmpty) {
        final currentTsInfo = tsInfoResponse[0];
        final tsType = currentTsInfo['ts_type'];
        final tsStatus = currentTsInfo['ts_status'];
        final tsUsage = currentTsInfo['ts_usage'];
        
        print('\n=== 현재 타석 정보 ===');
        print('ts_id: ${reservation['station']}, type: $tsType, status: $tsStatus, usage: $tsUsage');
        
        // 같은 조건의 타석들 조회 (현재 타석은 조회 후 필터링)
        final basePrice = currentTsInfo['base_price'];
        final discountPrice = currentTsInfo['discount_price'];
        final extrachargePrice = currentTsInfo['extracharge_price'];
        final tsMinBase = currentTsInfo['ts_min_base'];
        final tsMinMinimum = currentTsInfo['ts_min_minimum'];
        final tsMinMaximum = currentTsInfo['ts_min_maximum'];
        final tsBuffer = currentTsInfo['ts_buffer'];
        final maxPerson = currentTsInfo['max_person'];
        final memberTypeProhibited = currentTsInfo['member_type_prohibited'];
        
        print('\n=== 동일 조건 타석 조회 시작 ===');
        print('조회 조건:');
        print('  branch_id: $branchId');
        print('  ts_type: $tsType');
        print('  ts_status: $tsStatus');
        print('  ts_usage: $tsUsage');
        print('  base_price: $basePrice');
        print('  discount_price: $discountPrice');
        print('  extracharge_price: $extrachargePrice');
        print('  ts_min_base: $tsMinBase');
        print('  ts_min_minimum: $tsMinMinimum');
        print('  ts_min_maximum: $tsMinMaximum');
        print('  ts_buffer: $tsBuffer');
        print('  max_person: $maxPerson');
        print('  member_type_prohibited: $memberTypeProhibited');
        print('  현재 타석 ID: ${reservation['station']} (조회 후 제외)');
        
        List<Map<String, dynamic>> whereConditions = [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_status', 'operator': '=', 'value': tsStatus},
          {'field': 'base_price', 'operator': '=', 'value': basePrice},
          {'field': 'discount_price', 'operator': '=', 'value': discountPrice},
          {'field': 'extracharge_price', 'operator': '=', 'value': extrachargePrice},
          {'field': 'ts_min_base', 'operator': '=', 'value': tsMinBase},
          {'field': 'ts_min_minimum', 'operator': '=', 'value': tsMinMinimum},
          {'field': 'ts_min_maximum', 'operator': '=', 'value': tsMinMaximum},
        ];
        
        // null이 아닌 필드들만 조건에 추가
        if (tsUsage != null && tsUsage != 'null' && tsUsage.toString().isNotEmpty) {
          whereConditions.add({'field': 'ts_usage', 'operator': '=', 'value': tsUsage});
        }
        
        if (tsBuffer != null && tsBuffer != 'null' && tsBuffer.toString().isNotEmpty) {
          whereConditions.add({'field': 'ts_buffer', 'operator': '=', 'value': tsBuffer});
        }
        
        if (maxPerson != null && maxPerson != 'null' && maxPerson.toString().isNotEmpty) {
          whereConditions.add({'field': 'max_person', 'operator': '=', 'value': maxPerson});
        }
        
        if (memberTypeProhibited != null && memberTypeProhibited != 'null' && memberTypeProhibited.toString().isNotEmpty) {
          whereConditions.add({'field': 'member_type_prohibited', 'operator': '=', 'value': memberTypeProhibited});
        }
        
        List<Map<String, dynamic>> allTsResponse = [];
        
        try {
          // 모든 타석을 조회
          allTsResponse = await ApiService.getData(
            table: 'v2_ts_info',
            where: whereConditions,
            orderBy: [{'field': 'ts_id', 'direction': 'ASC'}],
          );
          
          print('조회된 전체 타석 수: ${allTsResponse.length}');
          
          // 현재 타석 제외 필터링
          final currentTsId = reservation['station'].toString();
          final sameTsTypeResponse = allTsResponse.where((ts) {
            final tsId = ts['ts_id'].toString();
            return tsId != currentTsId;
          }).toList();
          
          print('현재 타석($currentTsId) 제외 후: ${sameTsTypeResponse.length}개');
          
          // 필터링된 리스트를 사용
          allTsResponse = sameTsTypeResponse;
          
        } catch (e) {
          print('❌ 동일 조건 타석 조회 실패: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('타석 정보를 불러올 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        final sameTsTypeResponse = allTsResponse;
        
        if (sameTsTypeResponse.isNotEmpty) {
          print('\n=== 동일 조건 타석 목록 ===');
          for (var ts in sameTsTypeResponse) {
            print('ts_id: ${ts['ts_id']}, type: ${ts['ts_type']}, location: ${ts['ts_location'] ?? 'N/A'}');
          }
          
          // 현재 시간
          final now = DateTime.now();
          final reservationStartTime = DateTime.parse('${reservation['date']} ${reservation['startTime']}:00');
          final reservationEndTime = DateTime.parse('${reservation['date']} ${reservation['endTime']}:00');
          
          print('\n=== 타석 이동 가능 여부 확인 ===');
          print('현재 시간: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
          print('예약 시작: ${DateFormat('yyyy-MM-dd HH:mm').format(reservationStartTime)}');
          print('예약 종료: ${DateFormat('yyyy-MM-dd HH:mm').format(reservationEndTime)}');
          
          // 이동 가능한 타석 리스트
          List<Map<String, dynamic>> availableStations = [];
          
          // 각 타석별로 이동 가능 여부 확인
          for (var targetTs in sameTsTypeResponse) {
            final targetTsId = targetTs['ts_id'];
            
            // 현재 타석은 제외
            if (targetTsId.toString() == reservation['station'].toString()) continue;
            
            print('\n타석 ${targetTsId}번 체크:');
            
            // 해당 타석의 당일 예약 현황 확인 (현재 예약은 제외하지 않음 - 모든 예약 체크)
            print('  전체 예약에서 타석 $targetTsId 필터링 중...');
            print('  전체 예약 수: ${response.length}개');
            
            final targetReservations = response
                .where((slot) {
                  final slotTsId = slot['ts_id'].toString();
                  final targetTsIdStr = targetTsId.toString();
                  final matches = slotTsId == targetTsIdStr;
                  print('    slot ts_id: "$slotTsId", target: "$targetTsIdStr", 매칭: $matches (${slot['reservation_id']})');
                  return matches;
                })
                .toList()
              ..sort((a, b) => a['ts_start'].compareTo(b['ts_start']));
            
            print('  해당 타석의 예약 수: ${targetReservations.length}개');
            for (var res in targetReservations) {
              print('    - ${res['ts_start']} ~ ${res['ts_end']} (${res['reservation_id']})');
            }
            
            if (targetReservations.isEmpty) {
              print('  ✅ 예약 없음 - 이동 가능');
              
              // 이동 시 새로운 시작시간과 종료시간 계산
              final newStartTime = now.isAfter(reservationStartTime)
                  ? DateFormat('HH:mm').format(now)
                  : reservation['startTime'];
              final newEndTime = reservation['endTime'];
              
              print('     새로운 이용시간: $newStartTime - $newEndTime');
              
              // 가능한 타석 목록에 추가
              availableStations.add({
                'ts_id': targetTsId,
                'ts_info': targetTs,
                'new_start_time': newStartTime,
                'new_end_time': newEndTime,
              });
            } else {
              // 기존 예약과 시간 충돌 체크
              bool canMove = true;
              String reason = '';
              
              // 이동하려는 시간 범위
              final moveStartTime = now.isAfter(reservationStartTime) ? now : reservationStartTime;
              final moveEndTime = reservationEndTime;
              
              for (var existingReservation in targetReservations) {
                final existingStart = DateTime.parse('${reservation['date']} ${existingReservation['ts_start']}');
                final existingEnd = DateTime.parse('${reservation['date']} ${existingReservation['ts_end']}');
                
                print('    기존 예약과 충돌 체크:');
                print('      이동하려는 시간: ${DateFormat('HH:mm').format(moveStartTime)} ~ ${DateFormat('HH:mm').format(moveEndTime)}');
                print('      기존 예약 시간: ${DateFormat('HH:mm').format(existingStart)} ~ ${DateFormat('HH:mm').format(existingEnd)}');
                
                // 시간 충돌 체크: 1분이라도 겹치면 충돌
                // 충돌 조건: moveStart < existingEnd AND moveEnd > existingStart
                bool isConflict = moveStartTime.isBefore(existingEnd) && moveEndTime.isAfter(existingStart);
                
                if (isConflict) {
                  canMove = false;
                  reason = '시간 충돌 - ${existingReservation['ts_start']} ~ ${existingReservation['ts_end']} (${existingReservation['member_name']})';
                  print('      ❌ 충돌 발생!');
                  break;
                } else {
                  print('      ✅ 충돌 없음');
                }
              }
              
              if (canMove) {
                // 이동 시 새로운 시작시간과 종료시간 계산
                final newStartTime = now.isAfter(DateTime.parse('${reservationDate} ${reservation['startTime']}:00'))
                    ? DateFormat('HH:mm').format(now)
                    : reservation['startTime'];
                final newEndTime = reservation['endTime'];
                
                print('  ✅ 이동 가능');
                print('     새로운 이용시간: $newStartTime - $newEndTime');
                
                // 가능한 타석 목록에 추가
                availableStations.add({
                  'ts_id': targetTsId,
                  'ts_info': targetTs,
                  'new_start_time': newStartTime,
                  'new_end_time': newEndTime,
                });
              } else {
                print('  ❌ 이동 불가: $reason');
              }
            }
          }
          
          // 이동 가능한 타석이 있으면 선택 다이얼로그 표시
          print('\n=== 최종 결과 ===');
          print('이동 가능한 타석 수: ${availableStations.length}개');
          
          if (availableStations.isNotEmpty) {
            print('✅ 타석 선택 다이얼로그 표시');
            showStationMoveDialog(context, availableStations, reservation, onMoveSuccess);
          } else {
            print('⚠️ 이동 가능한 타석이 없어 모달 팝업 표시');
            _showNoAvailableStationsDialog(context);
          }
        } else {
          print('동일 조건 타석: 없음');
          _showNoSameConditionStationsDialog(context);
        }
      }
    } catch (e) {
      print('Error in handleSelfMove: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static void _showNoAvailableStationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                '타석 이동 불가',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          content: Text(
            '현재 이동 가능한 타석이 없습니다.\n다른 시간대를 선택해 주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showMoveSuccessDialog(BuildContext context, int originalTsId, int newTsId, VoidCallback onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 방지
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 성공 아이콘
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 제목
                Text(
                  '타석 이동이 완료되었습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '새 타석으로 이동합니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // 타석 이동 표시 (기존 → 새로운)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 기존 타석
                      Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_golf,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                Text(
                                  '$originalTsId번',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '기존 타석',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      // 화살표
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.green[600],
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                      
                      // 새로운 타석
                      Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_golf,
                                  color: Colors.green[600],
                                  size: 20,
                                ),
                                Text(
                                  '$newTsId번',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '새 타석',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 확인 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // 다이얼로그 닫기
                      onConfirm(); // 콜백 실행
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showNoSameConditionStationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                '이동 가능한 타석 없음',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          content: Text(
            '동일한 조건의 타석이 없습니다.\n다른 타석을 이용해 주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void showStationMoveDialog(
    BuildContext context, 
    List<Map<String, dynamic>> availableStations, 
    Map<String, dynamic> reservation,
    Function(String newReservationId, int newTsId)? onMoveSuccess,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더 아이콘
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 제목
                Text(
                  '이동할 타석 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // 현재 예약 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.sports_golf,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '현재 타석',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${reservation['station']}번 타석',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${reservation['startTime']} - ${reservation['endTime']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 안내 텍스트
                Text(
                  '이동 가능한 타석을 선택해주세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // 타석 목록
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: availableStations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final station = entry.value;
                        final tsId = station['ts_id'].toString();
                        final tsInfo = station['ts_info'];
                        final newStartTime = station['new_start_time'];
                        final newEndTime = station['new_end_time'];
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: index == availableStations.length - 1 ? 0 : 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                _confirmStationMove(context, tsId, newStartTime, newEndTime, reservation, onMoveSuccess);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // 타석 아이콘
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.sports_golf,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          Text(
                                            tsId,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 16),
                                    
                                    // 타석 정보
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${tsId}번 타석',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[900],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  tsInfo['ts_type'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$newStartTime - $newEndTime',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // 화살표 아이콘
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 취소 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _confirmStationMove(
    BuildContext context, 
    String newTsId, 
    String newStartTime, 
    String newEndTime, 
    Map<String, dynamic> reservation,
    Function(String newReservationId, int newTsId)? onMoveSuccess,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 확인 아이콘
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.help_outline,
                    color: Colors.amber[700],
                    size: 40,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 제목
                Text(
                  '타석 이동 확인',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '다음과 같이 이동하시겠습니까?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // 타석 이동 표시 (기존 → 새로운)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 기존 타석
                      Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_golf,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                Text(
                                  '${reservation['station']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '현재 타석',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // 화살표
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.blue,
                        size: 30,
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // 새로운 타석
                      Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_golf,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                Text(
                                  newTsId,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '새 타석',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 시간 정보
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$newStartTime - $newEndTime',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _handleStationMove(context, newTsId, newStartTime, newEndTime, reservation, onMoveSuccess);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '이동하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  static Future<void> _handleStationMove(
    BuildContext context, 
    String newTsId, 
    String newStartTime, 
    String newEndTime, 
    Map<String, dynamic> reservation,
    Function(String newReservationId, int newTsId)? onMoveSuccess,
  ) async {
    print('=== 타석 이동 실행 ===');
    print('예약 ID: ${reservation['reservationId']}');
    print('기존 타석: ${reservation['station']}번');
    print('새 타석: ${newTsId}번');
    print('새 시간: $newStartTime - $newEndTime');
    
    // 비동기 작업 전에 미리 성공 메시지와 콜백 준비
    final originalTsId = int.parse(reservation['station'].toString());
    final newTsIdInt = int.parse(newTsId);
    final originalReservationId = reservation['reservationId'];
    final newReservationId = originalReservationId.replaceFirst('_${originalTsId}_', '_${newTsIdInt}_');
    
    // 먼저 성공 메시지 다이얼로그 표시 (비동기 작업 시작 전)
    if (context.mounted && onMoveSuccess != null) {
      print('🎉 성공 메시지 다이얼로그 표시 (DB 작업 전)');
      _showMoveSuccessDialog(context, originalTsId, newTsIdInt, () {
        print('📞 성공 콜백 호출: newReservationId=$newReservationId, newTsId=$newTsIdInt');
        onMoveSuccess(newReservationId, newTsIdInt);
      });
    }
    
    // 시간 비중 계산 (백그라운드에서 실행)
    print('🔄 _calculateTimeRatio 호출 시작');
    final success = await _calculateTimeRatio(reservation, newStartTime, newEndTime, newTsId);
    print('🔄 _calculateTimeRatio 반환값: $success');
    
    if (!success) {
      print('❌ 타석 이동 실패');
      // 실패 시에만 에러 메시지 (성공 메시지는 이미 위에서 표시됨)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('타석 이동 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      print('✅ DB 작업 완료 (성공 메시지는 이미 표시됨)');
    }
  }

  static Future<bool> _calculateTimeRatio(Map<String, dynamic> reservation, String newStartTime, String newEndTime, String newTsId) async {
    try {
      print('\n=== 시간 비중 계산 ===');
      
      // 원래 예약 시간 계산
      final originalStartTime = reservation['startTime'];
      final originalEndTime = reservation['endTime'];
      final originalStart = DateTime.parse('2000-01-01 $originalStartTime:00');
      final originalEnd = DateTime.parse('2000-01-01 $originalEndTime:00');
      final originalDurationMinutes = originalEnd.difference(originalStart).inMinutes;
      
      // 새로운 예약 시간 계산
      final newStart = DateTime.parse('2000-01-01 $newStartTime:00');
      final newEnd = DateTime.parse('2000-01-01 $newEndTime:00');
      final newDurationMinutes = newEnd.difference(newStart).inMinutes;
      
      // 타석별 비중 계산
      final originalTsId = int.parse(reservation['station'].toString());
      final newTsIdInt = int.parse(newTsId);
      
      // 같은 타석으로의 이동 방지
      if (originalTsId == newTsIdInt) {
        print('⚠️ 경고: 동일한 타석으로는 이동할 수 없습니다.');
        print('원본 타석: $originalTsId, 이동 타석: $newTsIdInt');
        return false;
      }
      
      // 실제 시간 구간별 비중 계산
      final moveTime = DateTime.parse('2000-01-01 $newStartTime:00');
      final originalEndDateTime = DateTime.parse('2000-01-01 $originalEndTime:00');
      final originalStartDateTime = DateTime.parse('2000-01-01 $originalStartTime:00');
      
      int originalTsMinutes;
      int newTsMinutes;
      
      // 완전한 타석 이동인지 확인 (시간이 동일하면 완전한 타석 이동)
      if (originalStartTime == newStartTime && originalEndTime == newEndTime) {
        // 완전한 타석 이동: 전체 시간을 새 타석으로 이동
        originalTsMinutes = 0;
        newTsMinutes = originalDurationMinutes;
      } else {
        // 부분적 타석 이동: 시간 기준으로 분할
        // 기존 타석 사용 시간 (원래 시작 ~ 이동 시작)
        originalTsMinutes = moveTime.difference(originalStartDateTime).inMinutes;
        // 새 타석 사용 시간 (이동 시작 ~ 원래 종료)
        newTsMinutes = originalEndDateTime.difference(moveTime).inMinutes;
      }
      
      // 전체 시간 대비 비중 계산
      double originalTsRatio;
      double newTsRatio;
      
      if (originalDurationMinutes == 0) {
        // 0분인 경우 이미 취소된 예약이므로 처리 불가
        print('⚠️ 기존 예약이 이미 0분 상태입니다. 타석 이동을 할 수 없습니다.');
        return false;
      } else {
        originalTsRatio = (originalTsMinutes / originalDurationMinutes * 100);
        newTsRatio = (newTsMinutes / originalDurationMinutes * 100);
      }
      
      print('원래 예약: $originalStartTime - $originalEndTime (${originalDurationMinutes}분)');
      print('새 예약: $newStartTime - $newEndTime (${newDurationMinutes}분)');
      print('');
      print('시간 비중 계산:');
      print('  ts_id($originalTsId): ${originalTsRatio.toStringAsFixed(1)}% (${originalTsMinutes}분)');
      print('  ts_id($newTsIdInt): ${newTsRatio.toStringAsFixed(1)}% (${newTsMinutes}분)');
      print('');
      
      // 새로운 reservation_id 생성
      final originalReservationId = reservation['reservationId'];
      final newReservationId = originalReservationId.replaceFirst('_${originalTsId}_', '_${newTsIdInt}_');
      
      // 중복 레코드 방지: 활성 상태의 새 reservation_id가 이미 존재하는지 확인
      final existingActiveRecord = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        ],
      );
      
      if (existingActiveRecord.isNotEmpty) {
        print('⚠️ 경고: 이미 활성 상태인 예약이 존재합니다.');
        print('새 reservation_id($newReservationId)가 이미 결제완료 상태로 존재합니다.');
        return false;
      }
      
      // 취소된 예약이 있는지 확인 (있으면 덮어쓰기 예정)
      final existingCancelledRecord = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          {'field': 'ts_status', 'operator': '=', 'value': '예약취소'},
        ],
      );
      
      if (existingCancelledRecord.isNotEmpty) {
        print('✅ 취소된 예약($newReservationId)이 존재하여 덮어쓰기 진행');
      }
      
      // 시간 비중에 따른 가격 재계산
      print('🔄 _calculatePriceByTimeRatio 호출 시작');
      final success = await _calculatePriceByTimeRatio(reservation, originalTsRatio, newTsRatio, originalTsMinutes, newTsMinutes, originalTsId, newTsIdInt, originalReservationId, newReservationId, newStartTime, newEndTime);
      print('🔄 _calculatePriceByTimeRatio 반환값: $success');
      print('=== 시간 비중 계산 완료 ===\n');
      
      return success;
      
    } catch (e) {
      print('시간 비중 계산 오류: $e');
      return false;
    }
  }

  static Future<bool> _calculatePriceByTimeRatio(Map<String, dynamic> reservation, double originalTsRatio, double newTsRatio, int originalTsMinutes, int newTsMinutes, int originalTsId, int newTsIdInt, String originalReservationId, String newReservationId, String newStartTime, String newEndTime) async {
    try {
      print('\n=== 가격 재계산 (시간 비중 기준) ===');
      
      // 원본 예약 데이터를 API에서 조회 - 업데이트 전의 원본 데이터 필요
      final originalDataResponse = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': originalReservationId},
        ],
        orderBy: [{'field': 'time_stamp', 'direction': 'DESC'}], // 최신 데이터 우선
      );
      
      if (originalDataResponse.isEmpty) {
        print('❌ 원본 예약 데이터를 찾을 수 없습니다.');
        print('예약 ID: $originalReservationId');
        return false;
      }
      
      final originalData = originalDataResponse[0];
      print('=== 조회된 원본 데이터 ===');
      print('reservation_id: ${originalData['reservation_id']}');
      print('ts_id: ${originalData['ts_id']}');
      print('ts_status: ${originalData['ts_status']}');
      print('total_amt: ${originalData['total_amt']}원');
      
      // 이미 이동된 예약인지 확인
      if (originalData['ts_id'].toString() != reservation['station'].toString()) {
        print('⚠️ 경고: 이미 다른 타석으로 이동된 예약입니다.');
        print('현재 UI 타석: ${reservation['station']}, DB 타석: ${originalData['ts_id']}');
        return false;
      }
      
      // 금액 계산 - bill_totalamt, bill_deduction, bill_netamt 모두 시간 비중으로 배분
      final originalTotalAmt = originalData['total_amt'] ?? 0;
      final originalTermDiscount = originalData['term_discount'] ?? 0;
      final originalCouponDiscount = originalData['coupon_discount'] ?? 0;
      final originalTotalDiscount = originalData['total_discount'] ?? 0;
      final originalNetAmt = originalData['net_amt'] ?? 0;
      
      // 시간 비중에 따른 배분
      final originalTsAmt = (originalTotalAmt * originalTsRatio / 100).round();
      final newTsAmt = (originalTotalAmt * newTsRatio / 100).round();
      
      final originalTsTermDiscount = (originalTermDiscount * originalTsRatio / 100).round();
      final newTsTermDiscount = (originalTermDiscount * newTsRatio / 100).round();
      
      final originalTsCouponDiscount = (originalCouponDiscount * originalTsRatio / 100).round();
      final newTsCouponDiscount = (originalCouponDiscount * newTsRatio / 100).round();
      
      final originalTsTotalDiscount = (originalTotalDiscount * originalTsRatio / 100).round();
      final newTsTotalDiscount = (originalTotalDiscount * newTsRatio / 100).round();
      
      final originalTsNetAmt = (originalNetAmt * originalTsRatio / 100).round();
      final newTsNetAmt = (originalNetAmt * newTsRatio / 100).round();
      
      print('=== 원본 금액 정보 ===');
      print('total_amt: $originalTotalAmt원');
      print('term_discount: $originalTermDiscount원');
      print('coupon_discount: $originalCouponDiscount원');
      print('total_discount: $originalTotalDiscount원');
      print('net_amt: $originalNetAmt원');
      print('');
      print('=== 시간 비중 배분 결과 ===');
      print('기존 타석($originalTsId): ${originalTsRatio.toStringAsFixed(1)}%');
      print('  total_amt: $originalTsAmt원');
      print('  term_discount: $originalTsTermDiscount원');
      print('  coupon_discount: $originalTsCouponDiscount원');
      print('  total_discount: $originalTsTotalDiscount원');
      print('  net_amt: $originalTsNetAmt원');
      print('');
      print('새 타석($newTsIdInt): ${newTsRatio.toStringAsFixed(1)}%');
      print('  total_amt: $newTsAmt원');
      print('  term_discount: $newTsTermDiscount원');
      print('  coupon_discount: $newTsCouponDiscount원');
      print('  total_discount: $newTsTotalDiscount원');
      print('  net_amt: $newTsNetAmt원');
      print('');
      
      // 쿠폰 조회
      print('=== 쿠폰 조회 ===');
      final coupons = await ApiService.getData(
        table: 'v2_discount_coupon',
        where: [
          {'field': 'reservation_id_used', 'operator': '=', 'value': originalReservationId},
        ],
      );
      
      print('조회된 쿠폰 수: ${coupons.length}');
      int couponDiscount = 0;
      
      if (coupons.isNotEmpty) {
        for (var coupon in coupons) {
          final couponAmt = coupon['discount_amount'] ?? 0;
          couponDiscount += (couponAmt as int);
          print('쿠폰 ID ${coupon['coupon_id']}: $couponAmt원');
        }
      }
      
      // 할인 계산 (새 타석에만 적용)
      int totalDiscount = couponDiscount;
      print('\n총 할인금액: $totalDiscount원');
      print('새 타석 최종금액: ${newTsAmt - totalDiscount}원');
      
      // DB 업데이트 실행
      print('🔄 _executeStationMove 호출 시작');
      final updateSuccess = await _executeStationMove(
        originalData: originalData,
        originalTsRatio: originalTsRatio,
        newTsRatio: newTsRatio,
        originalReservationId: originalReservationId,
        newReservationId: newReservationId,
        newTsIdInt: newTsIdInt,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
        originalTsAmt: originalTsAmt,
        newTsAmt: newTsAmt,
        totalDiscount: totalDiscount,
        couponDiscount: couponDiscount,
        coupons: coupons,
      );
      
      print('🔄 _executeStationMove 반환값: $updateSuccess');
      return updateSuccess;
      
    } catch (e) {
      print('가격 재계산 오류: $e');
      return false;
    }
  }

  static Future<bool> _executeStationMove({
    required Map<String, dynamic> originalData,
    required double originalTsRatio,
    required double newTsRatio,
    required String originalReservationId,
    required String newReservationId,
    required int newTsIdInt,
    required String newStartTime,
    required String newEndTime,
    required int originalTsAmt,
    required int newTsAmt,
    required int totalDiscount,
    required int couponDiscount,
    required List<Map<String, dynamic>> coupons,
  }) async {
    try {
      print('\n=== DB 업데이트 실행 시작 ===');
      
      // 트랜잭션처럼 처리하기 위해 모든 업데이트를 준비
      bool allSuccess = true;
      
      // 1. 기존 v2_priced_TS 업데이트
      print('\n[1/4] 기존 v2_priced_TS 업데이트 중...');
      final originalUpdateData = {
        'ts_end': '${newStartTime}:00', // 종료시간을 시작시간으로 변경
        'total_amt': (originalTsAmt * originalTsRatio / 100).round(),
        'term_discount': 0,
        'coupon_discount': 0,
        'total_discount': 0,
        'net_amt': (originalTsAmt * originalTsRatio / 100).round(),
        'discount_min': originalTsRatio == 0 ? 0 : originalData['discount_min'],
        'normal_min': originalTsRatio == 0 ? 0 : originalData['normal_min'],
        'extracharge_min': originalTsRatio == 0 ? 0 : originalData['extracharge_min'],
        'ts_min': originalTsRatio == 0 ? 0 : originalData['ts_min'],
        'ts_status': originalTsRatio == 0 ? '예약취소' : originalData['ts_status'], // 100% 이동 시 취소
      };
      
      final originalUpdateResult = await ApiService.updateData(
        table: 'v2_priced_TS',
        data: originalUpdateData,
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': originalReservationId},
        ],
      );
      
      if (originalUpdateResult['success'] != true) {
        print('❌ 기존 v2_priced_TS 업데이트 실패: ${originalUpdateResult['error']}');
        allSuccess = false;
      } else {
        print('✅ 기존 v2_priced_TS 업데이트 성공');
      }
      
      // 2. 새 v2_priced_TS 처리 (취소된 레코드가 있으면 업데이트, 없으면 추가)
      print('\n[2/4] 새 v2_priced_TS 처리 중...');
      
      // 취소된 레코드가 있는지 다시 확인
      final existingCancelledRecord = await ApiService.getData(
        table: 'v2_priced_TS',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          {'field': 'ts_status', 'operator': '=', 'value': '예약취소'},
        ],
      );
      
      final newPricedTsData = {
        'branch_id': originalData['branch_id'],
        'reservation_id': newReservationId,
        'ts_id': newTsIdInt,
        'ts_date': originalData['ts_date'],
        'ts_start': '${newStartTime}:00',
        'ts_end': '${newEndTime}:00',
        'ts_payment_method': originalData['ts_payment_method'],
        'ts_status': originalData['ts_status'],
        'member_id': originalData['member_id'],
        'member_type': originalData['member_type'],
        'member_name': originalData['member_name'],
        'member_phone': originalData['member_phone'],
        'total_amt': newTsAmt,
        'term_discount': 0,
        'coupon_discount': couponDiscount,
        'total_discount': totalDiscount,
        'net_amt': newTsAmt - totalDiscount,
        'discount_min': 0,
        'normal_min': (newEndTime != newStartTime) ? 
          DateTime.parse('2000-01-01 $newEndTime:00').difference(DateTime.parse('2000-01-01 $newStartTime:00')).inMinutes : 0,
        'extracharge_min': 0,
        'ts_min': (newEndTime != newStartTime) ? 
          DateTime.parse('2000-01-01 $newEndTime:00').difference(DateTime.parse('2000-01-01 $newStartTime:00')).inMinutes : 0,
        'bill_min': originalData['bill_min'],
        'day_of_week': originalData['day_of_week'],
        'bill_id': null, // v2_bills 생성 후 업데이트 예정
        'time_stamp': DateTime.now().toString(),
        'bill_min_id': originalData['bill_min_id'],
        'bill_game_id': originalData['bill_game_id'],
        'program_id': originalData['program_id'],
        'program_name': originalData['program_name'],
      };
      
      Map<String, dynamic> newProcessResult;
      
      if (existingCancelledRecord.isNotEmpty) {
        // 취소된 레코드 업데이트
        print('✅ 취소된 레코드를 업데이트합니다');
        newProcessResult = await ApiService.updateData(
          table: 'v2_priced_TS',
          data: newPricedTsData,
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId},
          ],
        );
      } else {
        // 새 레코드 추가
        print('✅ 새 레코드를 추가합니다');
        newProcessResult = await ApiService.addData(
          table: 'v2_priced_TS',
          data: newPricedTsData,
        );
      }
      
      if (newProcessResult['success'] != true) {
        print('❌ 새 v2_priced_TS 처리 실패: ${newProcessResult['error']}');
        allSuccess = false;
      } else {
        print('✅ 새 v2_priced_TS 처리 성공');
      }
      
      // 3. v2_discount_coupon 업데이트
      if (coupons.isNotEmpty) {
        print('\n[3/4] v2_discount_coupon 업데이트 중...');
        for (final coupon in coupons) {
          Map<String, dynamic> couponUpdateData = {};
          
          // reservation_id_used 변경이 필요한 경우
          if (coupon['reservation_id_used'] == originalReservationId) {
            couponUpdateData['reservation_id_used'] = newReservationId;
          }
          
          // reservation_id_issued 변경이 필요한 경우
          if (coupon['reservation_id_issued'] == originalReservationId) {
            couponUpdateData['reservation_id_issued'] = newReservationId;
          }
          
          if (couponUpdateData.isNotEmpty) {
            final couponUpdateResult = await ApiService.updateData(
              table: 'v2_discount_coupon',
              data: couponUpdateData,
              where: [
                {'field': 'coupon_id', 'operator': '=', 'value': coupon['coupon_id']},
              ],
            );
            
            if (couponUpdateResult['success'] != true) {
              print('❌ 쿠폰 ID ${coupon['coupon_id']} 업데이트 실패: ${couponUpdateResult['error']}');
              allSuccess = false;
            } else {
              print('✅ 쿠폰 ID ${coupon['coupon_id']} 업데이트 성공');
            }
          }
        }
      } else {
        print('\n[3/4] 업데이트할 쿠폰 없음');
      }
      
      // 4. v2_bills 또는 v2_bill_times 처리
      if (originalData['bill_id'] != null && originalData['bill_id'].toString().isNotEmpty) {
        print('\n[4/4] v2_bills 업데이트 중...');
        await _executeBillsUpdate(originalData, originalTsRatio, newTsRatio, originalReservationId, newReservationId, newTsIdInt, newStartTime, newEndTime, totalDiscount);
      } else if (originalData['bill_min_id'] != null && originalData['bill_min_id'].toString().isNotEmpty) {
        print('\n[4/4] v2_bill_times 업데이트 중...');
        await _executeBillTimesUpdate(originalData, originalTsRatio, newTsRatio, originalReservationId, newReservationId, newTsIdInt, newStartTime, newEndTime);
      } else {
        print('\n[4/4] bills/bill_times 업데이트 없음');
      }
      
      if (allSuccess) {
        print('\n✅ ✅ ✅ 모든 DB 업데이트 성공! ✅ ✅ ✅');
        print('🔄 _executeStationMove 성공 반환');
        return true; // 성공 반환
      } else {
        print('\n⚠️ ⚠️ ⚠️ 일부 업데이트 실패 ⚠️ ⚠️ ⚠️');
        print('❌ _executeStationMove 실패 반환');
        return false; // 실패 반환
      }
      
    } catch (e) {
      print('DB 업데이트 실행 오류: $e');
      rethrow;
    }
  }
  
  static Future<void> _executeBillsUpdate(
    Map<String, dynamic> originalData,
    double originalTsRatio,
    double newTsRatio,
    String originalReservationId,
    String newReservationId,
    int newTsIdInt,
    String newStartTime,
    String newEndTime,
    int totalDiscount,
  ) async {
    try {
      print('\n[4/4] v2_bills 업데이트 중...');
      
      // 디버깅: originalData 확인
      print('=== _executeBillsUpdate 디버깅 ===');
      print('originalData[\'bill_id\']: ${originalData['bill_id']}');
      print('originalReservationId: $originalReservationId');
      
      // 1. 기존 reservation_id에 해당하는 bill 찾기
      final currentBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'reservation_id', 'operator': '=', 'value': originalReservationId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}] // 최신 bill 선택
      );
      
      print('조회된 bills 수: ${currentBills.length}');
      if (currentBills.isNotEmpty) {
        for (int i = 0; i < currentBills.length; i++) {
          print('  bill[$i]: bill_id=${currentBills[i]['bill_id']}, totalamt=${currentBills[i]['bill_totalamt']}');
        }
      }
      
      if (currentBills.isEmpty) {
        print('기존 reservation_id($originalReservationId)에 해당하는 bill을 찾을 수 없어 v2_bills 업데이트를 건너뜁니다.');
        return;
      }
      
      final billId = currentBills[0]['bill_id'];
      print('선택된 bill_id: $billId');
      
      final contractHistoryId = currentBills[0]['contract_history_id'];
      final originalBillTotalAmt = currentBills[0]['bill_totalamt'];
      final originalBillDeduction = currentBills[0]['bill_deduction'];
      final originalBillNetAmt = currentBills[0]['bill_netamt'];
      final originalBillBalanceBefore = currentBills[0]['bill_balance_before'];
      
      print('=== 기존 bill 정보 ===');
      print('bill_totalamt: $originalBillTotalAmt원');
      print('bill_deduction: $originalBillDeduction원');
      print('bill_netamt: $originalBillNetAmt원');
      print('bill_balance_before: $originalBillBalanceBefore원');
      print('');
      
      // 2. 기존 bill 업데이트 (원본 타석의 비중으로 조정)
      final newBillTotalAmt = (originalBillTotalAmt * originalTsRatio / 100).round();
      final newBillDeduction = (originalBillDeduction * originalTsRatio / 100).round();
      final newBillNetAmt = (originalBillNetAmt * originalTsRatio / 100).round();
      
      print('=== 기존 bill 업데이트 계획 ===');
      print('새 bill_totalamt: $newBillTotalAmt원 (${originalTsRatio.toStringAsFixed(1)}%)');
      print('새 bill_deduction: $newBillDeduction원 (${originalTsRatio.toStringAsFixed(1)}%)');
      print('새 bill_netamt: $newBillNetAmt원 (${originalTsRatio.toStringAsFixed(1)}%)');
      print('(balance는 마지막에 일괄 재계산)');
      print('');
      
      await ApiService.updateData(
        table: 'v2_bills',
        data: {
          'bill_totalamt': newBillTotalAmt,
          'bill_deduction': newBillDeduction,
          'bill_netamt': newBillNetAmt,
          'bill_status': originalTsRatio == 0 ? '예약취소' : currentBills[0]['bill_status'], // 100% 이동 시 취소
        },
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ]
      );
      
      print('✅ 기존 bill 업데이트 완료 (bill_id: $billId)');
      
      // 3. 후속 bills 조회 (새 bill 생성 전에 미리 조회)
      final laterBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>', 'value': billId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'ASC'}]
      );
      
      // 4. 새로운 bill 생성 (새 타석의 비중으로)
      final newBillTotalAmtForNew = (originalBillTotalAmt * newTsRatio / 100).round();
      final newBillDeductionForNew = (originalBillDeduction * newTsRatio / 100).round();
      final newBillNetAmtForNew = (originalBillNetAmt * newTsRatio / 100).round();
      
      print('=== 새 bill 생성 계획 ===');
      print('새 bill_totalamt: $newBillTotalAmtForNew원 (${newTsRatio.toStringAsFixed(1)}%)');
      print('새 bill_deduction: $newBillDeductionForNew원 (${newTsRatio.toStringAsFixed(1)}%)');
      print('새 bill_netamt: $newBillNetAmtForNew원 (${newTsRatio.toStringAsFixed(1)}%)');
      print('(balance는 마지막에 일괄 재계산)');
      print('');
      
      // 새 bill 생성
      final newBillResult = await ApiService.addData(
        table: 'v2_bills',
        data: {
          'branch_id': originalData['branch_id'],
          'member_id': originalData['member_id'],
          'bill_date': originalData['ts_date'],
          'bill_type': '타석이용',
          'bill_text': '${newTsIdInt}번 타석($newStartTime ~ $newEndTime)',
          'bill_totalamt': newBillTotalAmtForNew,
          'bill_deduction': newBillDeductionForNew,
          'bill_netamt': newBillNetAmtForNew,
          'bill_timestamp': DateTime.now().toString(),
          'bill_balance_before': 0, // 임시값, 나중에 일괄 재계산
          'bill_balance_after': 0, // 임시값, 나중에 일괄 재계산
          'reservation_id': newReservationId,
          'bill_status': currentBills[0]['bill_status'],
          'contract_history_id': contractHistoryId,
          'contract_credit_expiry_date': currentBills[0]['contract_credit_expiry_date'],
        }
      );
      
      if (newBillResult['success'] != true) {
        print('❌ 새 bill 생성 실패: ${newBillResult['error']}');
        throw Exception('새 bill 생성 실패: ${newBillResult['error']}');
      }
      
      // 새로 생성된 bill_id 추출 (API 응답에서 받아야 함)
      // 임시로 최근 생성된 bill을 조회해서 bill_id 확인
      final recentBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}]
      );
      
      if (recentBills.isNotEmpty) {
        final newBillId = recentBills[0]['bill_id'];
        
        // v2_priced_TS의 bill_id 업데이트
        await ApiService.updateData(
          table: 'v2_priced_TS',
          data: {
            'bill_id': newBillId,
          },
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId}
          ]
        );
        
        print('✅ 새 bill 생성 완료 (bill_id: $newBillId)');
        print('✅ v2_priced_TS bill_id 업데이트 완료');
      } else {
        print('⚠️ 새로 생성된 bill을 찾을 수 없습니다');
      }
      
      // 5. 변경된 bill부터 이후 bills의 잔액 재계산
      print('=== 변경된 bill 이후 잔액 재계산 시작 ===');
      print('기준 bill_id: $billId 부터');
      print('contract_history_id: $contractHistoryId');
      
      // 변경된 bill_id부터 이후 bills를 bill_id 오름차순으로 조회
      final billsToRecalculate = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>=', 'value': billId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'ASC'}]
      );
      
      print('재계산할 bills 수: ${billsToRecalculate.length}');
      
      // 시작점 계산을 위해 이전 bill의 balance_after 조회
      int runningBalance = 0;
      
      // billId 바로 이전 bill 조회
      final previousBills = await ApiService.getData(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '<', 'value': billId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
        limit: 1
      );
      
      if (previousBills.isNotEmpty) {
        runningBalance = (previousBills[0]['bill_balance_after'] ?? 0) as int;
        print('이전 bill의 balance_after: $runningBalance');
      } else {
        print('이전 bill 없음, 0부터 시작');
      }
      
      // 변경된 bill부터 순차적으로 balance 재계산
      for (int i = 0; i < billsToRecalculate.length; i++) {
        final bill = billsToRecalculate[i];
        final currentBillId = bill['bill_id'];
        final currentNetAmt = (bill['bill_netamt'] ?? 0) as int;
        
        // balance_before는 이전 bill의 balance_after
        final newBalanceBefore = runningBalance;
        // balance_after는 balance_before + bill_netamt
        final newBalanceAfter = newBalanceBefore + currentNetAmt;
        
        // DB 업데이트
        final updateResult = await ApiService.updateData(
          table: 'v2_bills',
          data: {
            'bill_balance_before': newBalanceBefore,
            'bill_balance_after': newBalanceAfter,
          },
          where: [
            {'field': 'bill_id', 'operator': '=', 'value': currentBillId}
          ]
        );
        
        if (updateResult['success'] == true) {
          print('✅ bill_id $currentBillId: before=$newBalanceBefore, after=$newBalanceAfter (netamt=$currentNetAmt)');
          runningBalance = newBalanceAfter; // 다음 bill을 위해 업데이트
        } else {
          print('❌ bill_id $currentBillId 업데이트 실패: ${updateResult['error']}');
        }
      }
      
      print('✅ ${billsToRecalculate.length}개 bills 잔액 재계산 완료');
      
      print('✅ v2_bills 업데이트 완료');
      
    } catch (e) {
      print('❌ v2_bills 업데이트 오류: $e');
      rethrow;
    }
  }
  
  static Future<void> _executeBillTimesUpdate(
    Map<String, dynamic> originalData,
    double originalTsRatio,
    double newTsRatio,
    String originalReservationId,
    String newReservationId,
    int newTsIdInt,
    String newStartTime,
    String newEndTime,
  ) async {
    try {
      print('\n[4/4] v2_bill_times 업데이트 중...');
      
      // 디버깅: originalData 확인
      print('=== _executeBillTimesUpdate 디버깅 ===');
      print('originalData[\'bill_min_id\']: ${originalData['bill_min_id']}');
      print('originalReservationId: $originalReservationId');
      
      // 1. 기존 bill_min_id로 bill_times 찾기 (reservation_id가 변경되었을 수 있으므로)
      final currentBillTimes = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': originalData['bill_min_id']}
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}] // 최신 bill 선택
      );
      
      print('조회된 bill_times 수: ${currentBillTimes.length}');
      if (currentBillTimes.isNotEmpty) {
        for (int i = 0; i < currentBillTimes.length; i++) {
          print('  bill_times[$i]: bill_min_id=${currentBillTimes[i]['bill_min_id']}, bill_min=${currentBillTimes[i]['bill_min']}분');
        }
      }
      
      if (currentBillTimes.isEmpty) {
        print('기존 bill_min_id(${originalData['bill_min_id']})에 해당하는 bill_times를 찾을 수 없어 v2_bill_times 업데이트를 건너뜁니다.');
        return;
      }
      
      final billMinId = currentBillTimes[0]['bill_min_id'];
      print('선택된 bill_min_id: $billMinId');
      
      final contractHistoryId = currentBillTimes[0]['contract_history_id'];
      final originalBillMin = currentBillTimes[0]['bill_min'] ?? 0;
      final originalBalanceMinBefore = currentBillTimes[0]['bill_balance_min_before'] ?? 0;
      final originalBalanceMinAfter = currentBillTimes[0]['bill_balance_min_after'] ?? 0;
      
      print('=== 기존 bill_times 정보 ===');
      print('bill_min: ${originalBillMin}분');
      print('bill_balance_min_before: ${originalBalanceMinBefore}분');
      print('bill_balance_min_after: ${originalBalanceMinAfter}분');
      print('');
      
      // 2. 시간 비중 계산
      final originalTsMinutes = (originalBillMin * originalTsRatio / 100).round();
      final newTsMinutes = (originalBillMin * newTsRatio / 100).round();
      
      print('=== 시간 비중 배분 ===');
      print('기존 타석: ${originalTsMinutes}분 (${originalTsRatio.toStringAsFixed(1)}%)');
      print('새 타석: ${newTsMinutes}분 (${newTsRatio.toStringAsFixed(1)}%)');
      print('');
      
      // 3. 기존 bill_times 업데이트
      // 원래 사용한 시간에서 새 타석으로 이동한 시간을 뺀다
      final remainingMinutes = originalTsMinutes;
      // balance_after = balance_before - 실제 사용한 시간
      final newBalanceAfter = originalBalanceMinBefore - remainingMinutes;
      
      print('=== 기존 bill_times 업데이트 계획 ===');
      print('새 bill_min: ${remainingMinutes}분');
      print('새 bill_balance_min_after: ${newBalanceAfter}분');
      print('');
      
      await ApiService.updateData(
        table: 'v2_bill_times',
        data: {
          'bill_min': remainingMinutes,
          'bill_balance_min_after': newBalanceAfter,
          'bill_status': originalTsRatio == 0 ? '예약취소' : currentBillTimes[0]['bill_status'], // 100% 이동 시 취소
        },
        where: [
          {'field': 'bill_min_id', 'operator': '=', 'value': billMinId}
        ]
      );
      
      print('✅ 기존 bill_times 업데이트 완료 (bill_min_id: $billMinId)');
      
      // 4. 새로운 bill_times 생성
      print('=== 새 bill_times 생성 계획 ===');
      print('새 bill_min: ${newTsMinutes}분');
      print('bill_balance_min_before: ${newBalanceAfter}분 (기존 bill의 balance_after)');
      print('bill_balance_min_after: ${newBalanceAfter - newTsMinutes}분');
      print('');
      
      // 새 bill_times 생성
      final newBillResult = await ApiService.addData(
        table: 'v2_bill_times',
        data: {
          'branch_id': originalData['branch_id'],
          'member_id': originalData['member_id'],
          'bill_date': originalData['ts_date'],
          'bill_type': '타석이용',
          'bill_text': '${newTsIdInt}번 타석($newStartTime ~ $newEndTime)',
          'bill_total_min': newTsMinutes,
          'bill_discount_min': 0,
          'bill_min': newTsMinutes,
          'bill_timestamp': DateTime.now().toString(),
          'bill_balance_min_before': newBalanceAfter, // 기존 bill의 balance_after
          'bill_balance_min_after': newBalanceAfter - newTsMinutes,
          'reservation_id': newReservationId,
          'bill_status': currentBillTimes[0]['bill_status'],
          'contract_history_id': contractHistoryId,
          'contract_TS_min_expiry_date': currentBillTimes[0]['contract_TS_min_expiry_date'],
        }
      );
      
      if (newBillResult['success'] != true) {
        print('❌ 새 bill_times 생성 실패: ${newBillResult['error']}');
        throw Exception('새 bill_times 생성 실패: ${newBillResult['error']}');
      }
      
      // 새로 생성된 bill_min_id 추출
      final recentBillTimes = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'reservation_id', 'operator': '=', 'value': newReservationId}
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}]
      );
      
      if (recentBillTimes.isNotEmpty) {
        final newBillMinId = recentBillTimes[0]['bill_min_id'];
        
        // v2_priced_TS의 bill_min_id 업데이트
        await ApiService.updateData(
          table: 'v2_priced_TS',
          data: {
            'bill_min_id': newBillMinId,
          },
          where: [
            {'field': 'reservation_id', 'operator': '=', 'value': newReservationId}
          ]
        );
        
        print('✅ 새 bill_times 생성 완료 (bill_min_id: $newBillMinId)');
        print('✅ v2_priced_TS bill_min_id 업데이트 완료');
      } else {
        print('⚠️ 새로 생성된 bill_times를 찾을 수 없습니다');
      }
      
      // 5. 변경된 bill_times부터 이후 bill_times의 잔액 재계산
      print('=== 변경된 bill_times 이후 잔액 재계산 시작 ===');
      print('기준 bill_min_id: $billMinId 부터');
      print('contract_history_id: $contractHistoryId');
      
      // 변경된 bill_min_id부터 이후 bill_times를 bill_min_id 오름차순으로 조회
      final billTimesToRecalculate = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '>=', 'value': billMinId}
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'ASC'}]
      );
      
      print('재계산할 bill_times 수: ${billTimesToRecalculate.length}');
      
      // 시작점 계산을 위해 이전 bill_times의 balance_min_after 조회
      int runningBalance = 0;
      
      // billMinId 바로 이전 bill_times 조회
      final previousBillTimes = await ApiService.getData(
        table: 'v2_bill_times',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '<', 'value': billMinId}
        ],
        orderBy: [{'field': 'bill_min_id', 'direction': 'DESC'}],
        limit: 1
      );
      
      if (previousBillTimes.isNotEmpty) {
        runningBalance = (previousBillTimes[0]['bill_balance_min_after'] ?? 0) as int;
        print('이전 bill_times의 balance_min_after: ${runningBalance}분');
      } else {
        print('이전 bill_times 없음, 0부터 시작');
      }
      
      // 변경된 bill_times부터 순차적으로 balance 재계산
      for (int i = 0; i < billTimesToRecalculate.length; i++) {
        final billTime = billTimesToRecalculate[i];
        final currentBillMinId = billTime['bill_min_id'];
        final currentBillMin = (billTime['bill_min'] ?? 0) as int;
        
        // balance_min_before는 이전 bill_times의 balance_min_after
        final newBalanceMinBefore = runningBalance;
        // balance_min_after는 balance_min_before - bill_min
        final newBalanceMinAfter = newBalanceMinBefore - currentBillMin;
        
        // DB 업데이트
        final updateResult = await ApiService.updateData(
          table: 'v2_bill_times',
          data: {
            'bill_balance_min_before': newBalanceMinBefore,
            'bill_balance_min_after': newBalanceMinAfter,
          },
          where: [
            {'field': 'bill_min_id', 'operator': '=', 'value': currentBillMinId}
          ]
        );
        
        if (updateResult['success'] == true) {
          print('✅ bill_min_id $currentBillMinId: before=${newBalanceMinBefore}분, after=${newBalanceMinAfter}분 (사용=${currentBillMin}분)');
          runningBalance = newBalanceMinAfter; // 다음 bill_times를 위해 업데이트
        } else {
          print('❌ bill_min_id $currentBillMinId 업데이트 실패: ${updateResult['error']}');
        }
      }
      
      print('✅ ${billTimesToRecalculate.length}개 bill_times 잔액 재계산 완료');
      
      print('✅ v2_bill_times 업데이트 완료');
      
    } catch (e) {
      print('❌ v2_bill_times 업데이트 오류: $e');
      rethrow;
    }
  }
}