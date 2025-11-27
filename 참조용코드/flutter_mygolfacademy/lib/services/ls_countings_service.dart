import 'package:flutter/foundation.dart';
import 'package:famd_clientapp/models/lesson_counting.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LSCountingsService {
  /// 레슨 유형별 잔여 레슨 수를 계산합니다.
  /// 이 메서드는 계약 ID별로 LS_counting_id가 가장 큰 값의 LS_balance_min_after 값을 찾습니다.
  /// 
  /// [memberId]: 필수 - 회원 ID
  /// [branchId]: 선택 - 지점 ID
  /// 
  /// 반환값: 레슨 유형별 잔여 레슨 정보를 포함한 맵
  /// {
  ///   'lessonTypes': [  // 레슨 유형 목록
  ///     {
  ///       'type': '레슨 유형',
  ///       'pro': '담당 프로',
  ///       'remainingLessons': 잔여 레슨 수,
  ///       'lastRecord': 최신 레코드 객체
  ///     }
  ///   ],
  ///   'totalRemainingLessons': 전체 잔여 레슨 수,
  ///   'lessonCountings': 전체 레슨 카운팅 데이터
  /// }
  static Future<Map<String, dynamic>> getLessonTypeBalances(String memberId, {String? branchId}) async {
    try {
      if (kDebugMode) {
        print('===== 회원 ID: $memberId의 레슨 유형별 잔여 레슨 데이터 요청 (Branch ID: $branchId) =====');
      }
      
      // 레슨 계약 정보 가져오기 - dynamic_api.php 사용
      List<Map<String, dynamic>> contracts = [];
      try {
        final whereConditions = [
          {
            'field': 'member_id',
            'operator': '=',
            'value': memberId
          }
        ];
        
        // branchId가 제공된 경우 조건에 추가
        if (branchId != null && branchId.isNotEmpty) {
          whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
        }
        
        final contractResponse = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'FlutterApp/1.0'
          },
          body: jsonEncode({
            'operation': 'get',
            'table': 'v2_LS_contracts',
            'where': whereConditions
          }),
        );
        
        if (contractResponse.statusCode == 200) {
          final contractData = jsonDecode(contractResponse.body);
          if (contractData['success'] == true && contractData['data'] != null) {
            contracts = List<Map<String, dynamic>>.from(contractData['data']);
            
            // 만료일 파싱 처리 (프론트엔드에서 처리)
            for (var contract in contracts) {
              if (contract['LS_expiry_date'] != null) {
                try {
                  contract['expiry_date'] = DateTime.parse(contract['LS_expiry_date']);
                } catch (e) {
                  if (kDebugMode) {
                    print('만료일 파싱 오류: ${contract['LS_expiry_date']}, 오류: $e');
                  }
                  contract['expiry_date'] = null;
                }
              }
            }
          }
        }
        
        if (kDebugMode) {
          print('레슨 계약 수: ${contracts.length}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('레슨 계약 정보 가져오기 실패: $e');
        }
      }
      
      // 유효한 계약 ID 맵 생성 (만료일 확인)
      Map<String, bool> validContracts = {};
      DateTime now = DateTime.now();
      
      for (var contract in contracts) {
        String contractId = contract['LS_contract_id'].toString();
        DateTime? expiryDate = contract['expiry_date'];
        
        // null 체크 및 현재 날짜와 비교
        bool isValid = (expiryDate == null) || (expiryDate.isAfter(now));
        validContracts[contractId] = isValid;
        
        if (kDebugMode && !isValid) {
          print('계약 ID: $contractId - 만료됨');
        }
      }
      
      // 레슨 카운팅 데이터 가져오기 - dynamic_api.php 사용
      List<LessonCounting> allLessonCountings = [];
      try {
        final whereConditions = [
          {
            'field': 'member_id',
            'operator': '=',
            'value': memberId
          }
        ];
        
        // branchId가 제공된 경우 조건에 추가
        if (branchId != null && branchId.isNotEmpty) {
          whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
        }
        
        final countingResponse = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'FlutterApp/1.0'
          },
          body: jsonEncode({
            'operation': 'get',
            'table': 'v3_LS_countings',
            'where': whereConditions,
            'orderBy': [
              {
                'field': 'LS_counting_id',
                'direction': 'DESC'
              }
            ]
          }),
        );
        
        if (countingResponse.statusCode == 200) {
          final countingData = jsonDecode(countingResponse.body);
          if (countingData['success'] == true && countingData['data'] != null) {
            final countingList = List<Map<String, dynamic>>.from(countingData['data']);
            
            // Map을 LessonCounting 객체로 변환
            for (var countingMap in countingList) {
              try {
                allLessonCountings.add(LessonCounting.fromJson(countingMap));
              } catch (e) {
                if (kDebugMode) {
                  print('레슨 카운팅 데이터 변환 오류: $e, 데이터: $countingMap');
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('레슨 카운팅 데이터 가져오기 실패: $e');
        }
      }
      
      if (kDebugMode) {
        print('전체 레슨 카운팅 데이터 수: ${allLessonCountings.length}');
      }
      
      // 레슨 계약 ID별 그룹화를 위한 맵
      Map<String, List<LessonCounting>> contractGroups = {};
      
      // 레슨 계약 ID로 그룹화
      for (var counting in allLessonCountings) {
        String contractId = counting.lsContractId ?? 'unknown';
        
        if (!contractGroups.containsKey(contractId)) {
          contractGroups[contractId] = [];
        }
        
        contractGroups[contractId]!.add(counting);
      }
      
      if (kDebugMode) {
        print('계약 ID 그룹 수: ${contractGroups.length}');
      }
      
      // 결과 저장을 위한 리스트
      List<Map<String, dynamic>> lessonTypes = [];
      int totalRemainingLessons = 0;
      
      // 각 계약 ID별로 LS_counting_id가 가장 큰 레코드를 찾아 잔여 레슨 계산
      contractGroups.forEach((contractId, countings) {
        // 계약 만료 여부 확인
        bool isValid = true;
        if (contractId != 'unknown') {
          isValid = validContracts[contractId] ?? true;
          
          if (!isValid) {
            return; // 만료된 계약은 처리하지 않음
          }
        }
        
        if (countings.isEmpty) {
          return;
        }
        
        // LS_counting_id 기준으로 정렬 (내림차순)
        countings.sort((a, b) => b.lsCountingId.compareTo(a.lsCountingId));
        
        // 첫 번째(LS_counting_id가 가장 큰) 레코드 가져오기
        LessonCounting latestRecord = countings.first;
        
        if (kDebugMode) {
          print('계약 ID: $contractId - 최신 LS_counting_id: ${latestRecord.lsCountingId}');
        }
        
        // LS_balance_min_after 값 사용 (없으면 lsBalanceAfter)
        int remainingLessons = latestRecord.lsBalanceMinAfter > 0 
            ? latestRecord.lsBalanceMinAfter
            : latestRecord.lsBalanceAfter;
        
        // 잔여 레슨이 있는 경우에만 추가
        if (remainingLessons > 0) {
          // 타입과 프로 정보도 함께 저장
          String type = latestRecord.lsType.isNotEmpty ? latestRecord.lsType : '일반';
          String pro = latestRecord.lsProName ?? '';
          
          lessonTypes.add({
            'contractId': contractId,
            'type': type,
            'pro': pro,
            'remainingLessons': remainingLessons,
            'lastRecord': latestRecord,
            'isValid': isValid,
          });
          
          totalRemainingLessons += remainingLessons;
          
          if (kDebugMode) {
            print('계약 ID: $contractId, 유형: $type, 잔여 레슨: $remainingLessons분 (LS_counting_id: ${latestRecord.lsCountingId})');
          }
        }
      });
      
      if (kDebugMode) {
        print('===== 최종 결과: $totalRemainingLessons분의 잔여 레슨, ${lessonTypes.length}개 계약 =====');
      }
      
      return {
        'lessonTypes': lessonTypes,
        'totalRemainingLessons': totalRemainingLessons,
        'lessonCountings': allLessonCountings,
      };
    } catch (e) {
      if (kDebugMode) {
        print('===== 레슨 유형별 잔여 레슨 데이터 처리 중 오류: $e =====');
      }
      
      return {
        'lessonTypes': <Map<String, dynamic>>[],
        'totalRemainingLessons': 0,
        'lessonCountings': <LessonCounting>[],
        'error': e.toString()
      };
    }
  }
}
