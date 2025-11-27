import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LessonCancellationService {
  // API 서버 URL
  static const String apiUrl = 'https://autofms.mycafe24.com/dynamic_api.php';

  // 레슨 예약 취소 처리 함수
  static Future<Map<String, dynamic>> cancelLessonReservation(String lsSetId) async {
    try {
      // 1. 먼저 LS_set_id로 v2_LS_orders 테이블에서 LS_id 목록 조회
      final lsIds = await _fetchLsIdsBySetId(lsSetId);
      
      if (lsIds.isEmpty) {
        return {
          'success': false,
          'message': 'LS_id를 찾을 수 없습니다.',
        };
      }
      
      // 2. 각 LS_id에 대해 v3_LS_countings 테이블에서 LS_counting_id와 LS_contract_id 조회
      List<String> lsCountingIds = [];
      List<String> lsContractIds = [];
      
      for (String lsId in lsIds) {
        final countingResult = await _fetchLsCountingsByLsId(lsId);
        if (countingResult['success']) {
          lsCountingIds.add(countingResult['ls_counting_id']);
          lsContractIds.add(countingResult['ls_contract_id']);
        }
      }
      
      if (lsCountingIds.isEmpty || lsContractIds.isEmpty) {
        return {
          'success': false,
          'message': '예약 정보를 찾을 수 없습니다.',
        };
      }
      
      // 3. 최초 조회 대상(LS_counting_ids)의 상태를 '예약취소'로 변경하고 LS_net_min을 0으로 설정
      int successCount = 0;
      int failCount = 0;
      
      // 데이터프레임 대신 Map을 사용하여 데이터 관리
      Map<String, Map<String, dynamic>> allRecords = {};
      
      // 모든 LS_contract_id에 대한 데이터 수집
      for (String contractId in lsContractIds.toSet()) {
        final records = await _fetchAllRecordsByContractId(contractId);
        allRecords.addAll(records);
      }
      
      // 최소 LS_counting_id 찾기
      String? minCountingId;
      for (String countingId in lsCountingIds) {
        if (minCountingId == null || int.parse(countingId) < int.parse(minCountingId)) {
          minCountingId = countingId;
        }
      }
      
      if (minCountingId == null) {
        return {
          'success': false,
          'message': '최소 LS_counting_id를 찾을 수 없습니다.',
        };
      }
      
      // 업데이트할 레코드 목록
      List<Map<String, dynamic>> updatedRows = [];
      
      // 최초 조회 대상 업데이트
      for (String countingId in lsCountingIds) {
        if (allRecords.containsKey(countingId)) {
          final record = allRecords[countingId]!;
          
          // 원래 값 저장
          final originalStatus = record['LS_status'];
          final originalNetMin = _parseToInt(record['LS_net_min']);
          final originalBalanceAfter = _parseToInt(record['LS_balance_min_after']);
          final balanceBefore = _parseToInt(record['LS_balance_min_before']);
          
          // 상태 업데이트
          record['LS_status'] = '예약취소';
          record['LS_net_min'] = 0;
          record['LS_balance_min_after'] = balanceBefore;
          
          updatedRows.add({
            'LS_counting_id': countingId,
            'LS_id': record['LS_id'],
            'original_status': originalStatus,
            'new_status': '예약취소',
            'original_net_min': originalNetMin,
            'new_net_min': 0,
            'original_balance_after': originalBalanceAfter,
            'new_balance_after': balanceBefore,
          });
        }
      }
      
      // 정렬된 LS_counting_id 목록 얻기
      List<String> sortedCountingIds = allRecords.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      
      // 최초 조회 대상 이후의 레코드 처리
      int startIdx = sortedCountingIds.indexOf(minCountingId);
      int? prevBalanceAfter;
      
      for (int i = startIdx; i < sortedCountingIds.length; i++) {
        final countingId = sortedCountingIds[i];
        final record = allRecords[countingId]!;
        
        // 첫 번째 레코드는 LS_balance_min_before 값을 유지
        if (i == startIdx) {
          prevBalanceAfter = _parseToInt(record['LS_balance_min_after']);
          continue;
        }
        
        // 이전 레코드의 LS_balance_min_after 값이 현재 레코드의 LS_balance_min_before 값이 됨
        final originalBefore = _parseToInt(record['LS_balance_min_before']);
        final originalAfter = _parseToInt(record['LS_balance_min_after']);
        final netMin = _parseToInt(record['LS_net_min']);
        
        record['LS_balance_min_before'] = prevBalanceAfter;
        
        // 현재 레코드의 LS_balance_min_after 값 계산 (LS_balance_min_before - LS_net_min)
        record['LS_balance_min_after'] = prevBalanceAfter! - netMin;
        
        // 다음 레코드를 위해 현재 레코드의 LS_balance_min_after 값 저장
        prevBalanceAfter = _parseToInt(record['LS_balance_min_after']);
        
        updatedRows.add({
          'LS_counting_id': countingId,
          'LS_id': record['LS_id'],
          'original_before': originalBefore,
          'new_before': record['LS_balance_min_before'],
          'original_after': originalAfter,
          'new_after': record['LS_balance_min_after'],
        });
      }
      
      // 4. 데이터베이스에 업데이트 반영
      for (var row in updatedRows) {
        bool success = false;
        
        if (row.containsKey('original_status')) {
          // 최초 조회 대상 업데이트
          success = await _updateRecord({
            'LS_status': row['new_status'],
            'LS_net_min': row['new_net_min'],
            'LS_balance_min_after': row['new_balance_after']
          }, [
            ['LS_counting_id', row['LS_counting_id']]
          ]);
        } else {
          // 이후 레코드 업데이트
          success = await _updateRecord({
            'LS_balance_min_before': row['new_before'],
            'LS_balance_min_after': row['new_after']
          }, [
            ['LS_counting_id', row['LS_counting_id']]
          ]);
        }
        
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
      
      // 5. v2_LS_orders 테이블의 LS_status도 '예약취소'로 업데이트
      for (String lsId in lsIds) {
        await _updateLsOrderStatus(lsId, '예약취소');
      }
      
      return {
        'success': true,
        'message': '예약이 취소되었습니다.',
        'details': {
          'success_count': successCount,
          'fail_count': failCount,
          'ls_ids': lsIds,
          'ls_counting_ids': lsCountingIds,
        }
      };
      
    } catch (e) {
      if (kDebugMode) {
        print('레슨 예약 취소 처리 중 오류: $e');
      }
      return {
        'success': false,
        'message': '예약 취소 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  // 안전하게 정수로 변환하는 헬퍼 함수
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        try {
          return double.parse(value).toInt();
        } catch (e) {
          return 0;
        }
      }
    }
    return 0;
  }
  
  // LS_set_id로 LS_id 목록 조회
  static Future<List<String>> _fetchLsIdsBySetId(String lsSetId) async {
    try {
      final Map<String, dynamic> payload = {
        'operation': 'get',
        'table': 'v2_LS_orders',
        'fields': ['LS_id', 'LS_set_id'],
        'where': [
          {
            'field': 'LS_set_id',
            'operator': '=',
            'value': lsSetId
          }
        ],
        'limit': 10
      };
      
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
        
        if (responseData['success'] == true) {
          final data = responseData['data'] as List<dynamic>;
          return data.map((item) => item['LS_id'].toString()).toList();
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('LS_id 조회 중 오류: $e');
      }
      return [];
    }
  }
  
  // LS_id로 LS_counting_id와 LS_contract_id 조회
  static Future<Map<String, dynamic>> _fetchLsCountingsByLsId(String lsId) async {
    try {
      final Map<String, dynamic> payload = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['LS_id', 'LS_counting_id', 'LS_contract_id'],
        'where': [
          {
            'field': 'LS_id',
            'operator': '=',
            'value': lsId
          }
        ],
        'limit': 10
      };
      
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
        
        if (responseData['success'] == true) {
          final data = responseData['data'] as List<dynamic>;
          if (data.isNotEmpty) {
            return {
              'success': true,
              'ls_counting_id': data[0]['LS_counting_id'].toString(),
              'ls_contract_id': data[0]['LS_contract_id'].toString(),
            };
          }
        }
      }
      
      return {'success': false};
    } catch (e) {
      if (kDebugMode) {
        print('LS_counting_id 조회 중 오류: $e');
      }
      return {'success': false};
    }
  }
  
  // LS_contract_id로 모든 레코드 조회
  static Future<Map<String, Map<String, dynamic>>> _fetchAllRecordsByContractId(String contractId) async {
    try {
      final Map<String, dynamic> payload = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': [
          'LS_counting_id', 
          'LS_balance_min_before', 
          'LS_net_min', 
          'LS_balance_min_after', 
          'LS_status', 
          'LS_id'
        ],
        'where': [
          {
            'field': 'LS_contract_id',
            'operator': '=',
            'value': contractId
          }
        ],
        'limit': 100
      };
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode(payload),
      );
      
      Map<String, Map<String, dynamic>> records = {};
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          final data = responseData['data'] as List<dynamic>;
          for (var record in data) {
            records[record['LS_counting_id'].toString()] = Map<String, dynamic>.from(record);
          }
        }
      }
      
      return records;
    } catch (e) {
      if (kDebugMode) {
        print('레코드 조회 중 오류: $e');
      }
      return {};
    }
  }
  
  // 레코드 업데이트
  static Future<bool> _updateRecord(Map<String, dynamic> data, List<List<dynamic>> whereCondition) async {
    try {
      final Map<String, dynamic> payload = {
        'operation': 'update',
        'table': 'v3_LS_countings',
        'data': data,
        'where': _convertWhereCondition(whereCondition),
      };
      
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
        return responseData['success'] == true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('레코드 업데이트 중 오류: $e');
      }
      return false;
    }
  }
  
  // v2_LS_orders 테이블의 상태 업데이트
  static Future<bool> _updateLsOrderStatus(String lsId, String status) async {
    try {
      final Map<String, dynamic> payload = {
        'operation': 'update',
        'table': 'v2_LS_orders',
        'data': {
          'LS_status': status,
        },
        'where': [
          {
            'field': 'LS_id',
            'operator': '=',
            'value': lsId
          }
        ],
      };
      
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
        return responseData['success'] == true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('LS_orders 상태 업데이트 중 오류: $e');
      }
      return false;
    }
  }
  
  // where 조건 변환
  static List<Map<String, dynamic>> _convertWhereCondition(List<List<dynamic>> conditions) {
    List<Map<String, dynamic>> apiWhere = [];
    
    for (var condition in conditions) {
      if (condition.length >= 2) {
        String field = condition[0];
        dynamic value = condition[1];
        String operator = condition.length >= 3 ? condition[2] : "=";
        
        apiWhere.add({
          'field': field,
          'operator': operator,
          'value': value.toString()
        });
      }
    }
    
    return apiWhere;
  }
} 