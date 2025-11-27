import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/font_sizes.dart';
import 'session_manager.dart';
import 'password_service.dart';
import 'chat_notification_service.dart';
class ApiService {
  // 서버 루트의 dynamic_api.php 사용 - HTTPS로 변경
  static const String baseUrl = 'https://autofms.mycafe24.com/dynamic_api.php';

  // 기본 헤더 (dynamic_api.php는 별도 API 키 불필요)
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // 전역 상태 관리
  static String? _currentBranchId;
  static Map<String, dynamic>? _currentUser;
  static Map<String, dynamic>? _currentBranch;
  static String? _currentStaffAccessId;
  static String? _currentStaffRole; // 'pro' 또는 'manager'
  static Map<String, dynamic>? _currentAccessSettings; // 권한 설정

  // 현재 지점 ID 설정
  static void setCurrentBranch(String branchId, Map<String, dynamic> branchData) {
    _currentBranchId = branchId;
    _currentBranch = branchData;
    print('🏢 지점 설정 완료: $branchId');
    
    // ChatNotificationService에 구독 설정 알림
    try {
      final chatNotificationService = ChatNotificationService();
      chatNotificationService.setupSubscriptions();
      print('🔔 채팅 알림 서비스 구독 시작...');
    } catch (e) {
      print('⚠️ 채팅 알림 서비스 구독 설정 실패: $e');
    }
  }

  // 현재 사용자 설정
  static void setCurrentUser(Map<String, dynamic> userData) {
    _currentUser = userData;
  }

  // 현재 직원 정보 설정
  static void setCurrentStaff(String staffAccessId, String role, Map<String, dynamic> userData) {
    _currentStaffAccessId = staffAccessId;
    _currentStaffRole = role;
    _currentUser = userData;
  }

  // 현재 지점 ID 가져오기
  static String? getCurrentBranchId() {
    return _currentBranchId;
  }

  // 현재 사용자 가져오기
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  // 현재 지점 정보 가져오기
  static Map<String, dynamic>? getCurrentBranch() {
    return _currentBranch;
  }

  // 다음 회원번호(member_no_branch) 가져오기
  static Future<int> getNextMemberNoBranch() async {
    try {
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        throw Exception('현재 지점 정보가 없습니다.');
      }

      // 해당 지점의 최대 member_no_branch 조회
      final result = await getMemberData(
        fields: ['member_no_branch'],
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          }
        ],
        orderBy: [
          {
            'field': 'member_no_branch',
            'direction': 'DESC'
          }
        ],
        limit: 1,
      );

      if (result.isEmpty) {
        // 첫 번째 회원이면 1 반환
        return 1;
      }

      final maxMemberNo = result[0]['member_no_branch'];
      if (maxMemberNo == null) {
        return 1;
      }

      // 최대값 + 1 반환
      return (maxMemberNo is int) ? maxMemberNo + 1 : int.parse(maxMemberNo.toString()) + 1;
    } catch (e) {
      print('getNextMemberNoBranch 오류: $e');
      throw Exception('회원번호 채번 중 오류가 발생했습니다: $e');
    }
  }

  // 현재 직원 Access ID 가져오기
  static String? getCurrentStaffAccessId() {
    return _currentStaffAccessId;
  }

  // 현재 직원 역할 가져오기 ('pro' 또는 'manager')
  static String? getCurrentStaffRole() {
    return _currentStaffRole;
  }

  // 현재 권한 설정 저장
  static void setCurrentAccessSettings(Map<String, dynamic> accessSettings) {
    _currentAccessSettings = accessSettings;
  }

  // 현재 권한 설정 가져오기
  static Map<String, dynamic>? getCurrentAccessSettings() {
    return _currentAccessSettings;
  }

  // 특정 권한 확인
  static bool hasPermission(String permission) {
    if (_currentAccessSettings == null) return true; // 권한 설정이 없으면 모든 권한 허용
    final value = _currentAccessSettings![permission];
    return value != null && value.toString() != '불가';
  }

  // 로그아웃 - 모든 전역 상태 초기화
  static void logout() {
    _currentBranchId = null;
    _currentUser = null;
    _currentBranch = null;
    _currentStaffAccessId = null;
    _currentStaffRole = null;
    _currentAccessSettings = null;
  }

  // API 호출 전 공통 처리 (세션 갱신)
  static void _beforeApiCall() {
    SessionManager.instance.updateActivity();
  }

  // WHERE 조건에 branch_id 자동 추가 (Staff, v2_branch 테이블 제외)
  static List<Map<String, dynamic>> _addBranchFilter(List<Map<String, dynamic>>? where, String tableName) {
    // Staff와 v2_branch 테이블은 branch_id 필터링 제외
    if (tableName == 'Staff' || tableName == 'v2_branch') {
      return where ?? [];
    }

    final branchId = getCurrentBranchId();
    if (branchId == null) {
      return where ?? [];
    }

    final branchCondition = {
      'field': 'branch_id',
      'operator': '=',
      'value': branchId,
    };

    if (where == null || where.isEmpty) {
      return [branchCondition];
    }

    // 이미 branch_id 조건이 있는지 확인
    bool hasBranchCondition = where.any((condition) => condition['field'] == 'branch_id');
    
    if (hasBranchCondition) {
      return where;
    }

    return [...where, branchCondition];
  }

  // 데이터 추가 시 branch_id 자동 추가 (Staff, v2_branch 테이블 제외)
  static Map<String, dynamic> _addBranchToData(Map<String, dynamic> data, String tableName) {
    // Staff와 v2_branch 테이블은 branch_id 자동 추가 제외
    if (tableName == 'Staff' || tableName == 'v2_branch') {
      return data;
    }

    final branchId = getCurrentBranchId();
    if (branchId == null) {
      return data;
    }

    // 이미 branch_id가 있으면 덮어쓰지 않음
    if (data.containsKey('branch_id')) {
      return data;
    }

    return {
      ...data,
      'branch_id': branchId,
    };
  }
  
  // 범용 데이터 조회 메서드 (고객용 앱과 동일)
  static Future<List<Map<String, dynamic>>> getData({
    required String table,
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    // API 호출 전 처리
    _beforeApiCall();

    print('📡 [ApiService] getData() 호출: $table 테이블');
    final apiStartTime = DateTime.now();
    
    try {
      final requestData = {
        'operation': 'get',
        'table': table,
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, table);
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      print('📡 [ApiService] HTTP POST 요청 전송 중...');
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      final apiEndTime = DateTime.now();
      final apiDuration = apiEndTime.difference(apiStartTime);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final dataList = List<Map<String, dynamic>>.from(responseData['data']);
          print('✅ [ApiService] getData() 성공: $table - ${dataList.length}개 (소요시간: ${apiDuration.inMilliseconds}ms)');
          return dataList;
        } else {
          print('❌ [ApiService] getData() 실패: $table - ${responseData['error']}');
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('getData 예외 발생: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 범용 데이터 수정 메서드 (고객용 앱과 동일)
  static Future<Map<String, dynamic>> updateData({
    required String table,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> where,
  }) async {
    // API 호출 전 처리
    _beforeApiCall();

    try {
      // branch_id 자동 추가 (데이터에)
      final finalData = _addBranchToData(data, table);
      
      final requestData = {
        'operation': 'update',
        'table': table,
        'data': finalData,
        'where': _addBranchFilter(where, table),
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('updateData 예외 발생: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // v2_LS_orders 데이터 조회 (레슨 이용내역)
  static Future<List<Map<String, dynamic>>> getLSData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_LS_orders',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_LS_orders');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      print('v2_LS_orders API 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('v2_LS_orders API 응답 상태: ${response.statusCode}');
      print('v2_LS_orders API 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Board 데이터 조회
  static Future<List<Map<String, dynamic>>> getBoardData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'Board',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'Board');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Staff 데이터 조회
  static Future<List<Map<String, dynamic>>> getStaffData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'Staff',
        'fields': fields ?? ['*'],
      };
      
      if (where != null && where.isNotEmpty) {
        requestData['where'] = where;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Member 데이터 조회 (v3_members 테이블) - 기존 호환성을 위한 함수
  static Future<List<Map<String, dynamic>>> getMemberData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v3_members');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Member 데이터 조회 (v3_members 테이블) - 회원관리 페이지용 간소화된 함수
  static Future<List<Map<String, dynamic>>> getMembers({
    String? searchQuery,
    List<String>? selectedTags,
    List<int>? selectedProIds,
    bool? isTermFilter, // 기간권 필터링 여부 (단순화)
    bool? isBattingFilter, // 타석 필터링 여부 (유효한 레슨권이 없는 회원)
    bool? isRecentFilter, // 최근 등록 필터링 여부
    bool? isExpiredFilter, // 만료회원 필터링 여부 (유효한 회원권이 없는 회원)
    bool? isLessonFilter, // 레슨회원 필터링 여부 (유효한 레슨권을 가진 회원)
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': [
          'member_id',
          'member_no_branch',
          'member_name',
          'member_phone',
          'member_type',
          'member_chn_keyword',
          'member_register',
          'member_nickname',
          'member_gender',
          'chat_bookmark'
        ],
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'DESC'
          }
        ]
      };

      // 필터링된 회원 ID 목록
      List<int>? filteredMemberIds;

      // 태그는 배타적으로 선택되므로 각각 독립적으로 처리
      if (isRecentFilter == true) {
        // 최근등록 필터
        List<int> recentMemberIds = await getRecentMemberIds();
        filteredMemberIds = recentMemberIds;
      } else if (isBattingFilter == true) {
        // 타석 필터
        List<int> battingMemberIds = await getBattingMemberIds();
        filteredMemberIds = battingMemberIds;
      } else if (isExpiredFilter == true) {
        // 만료회원 필터
        List<int> expiredMemberIds = await getExpiredMemberIds();
        filteredMemberIds = expiredMemberIds;
      } else if (isLessonFilter == true) {
        // 레슨회원 필터
        List<int> lessonMemberIds = await getValidLessonMemberIds();
        filteredMemberIds = lessonMemberIds;
      } else if (isTermFilter == true) {
        // 기간권 필터
        List<int> termMemberIds = await getAllTermMemberIds();
        filteredMemberIds = termMemberIds;
      } else if (selectedProIds != null && selectedProIds.isNotEmpty) {
        // 프로 필터
        Set<int> allConnectedMemberIds = {};
        for (int proId in selectedProIds) {
          List<int> connectedMemberIds = await getMemberIdsByProId(proId);
          allConnectedMemberIds.addAll(connectedMemberIds);
        }
        filteredMemberIds = allConnectedMemberIds.toList();
      }
      // else: 전체 선택 시 filteredMemberIds는 null로 유지 (모든 회원 조회)
      
      // 필터링된 회원이 없으면 빈 결과 반환
      if (filteredMemberIds != null && filteredMemberIds.isEmpty) {
        return [];
      }
      
      // 필터링된 회원 ID가 있는 경우 WHERE 조건 추가
      List<Map<String, dynamic>> whereConditions = [];
      
      if (filteredMemberIds != null) {
        whereConditions.add({
          'field': 'member_id',
          'operator': 'IN',
          'value': filteredMemberIds
        });
      }
      
      // branch_id 필터링 자동 추가
      whereConditions = _addBranchFilter(whereConditions, 'v3_members');
      
      if (whereConditions.isNotEmpty) {
        requestData['where'] = whereConditions;
      }

      // 검색 조건 추가 - 이름 또는 전화번호로 검색
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // 필터링이 있는 경우 AND 조건으로 추가
        if (filteredMemberIds != null) {
          // 이름 검색과 필터링을 동시에 적용하기 위해 별도 처리
          List<Map<String, dynamic>> nameResults = [];
          List<Map<String, dynamic>> phoneResults = [];
          
          // 이름으로 검색
          Map<String, dynamic> nameRequestData = {
            'operation': 'get',
            'table': 'v3_members',
            'fields': [
              'member_id',
              'member_name', 
              'member_phone',
              'member_type',
              'member_chn_keyword',
              'member_register',
              'member_nickname',
              'member_gender',
              'chat_bookmark'
            ],
            'where': _addBranchFilter([
              {
                'field': 'member_id',
                'operator': 'IN',
                'value': filteredMemberIds
              },
              {
                'field': 'member_name',
                'operator': 'LIKE',
                'value': '%$searchQuery%'
              }
            ], 'v3_members'),
            'orderBy': [
              {
                'field': 'member_id',
                'direction': 'DESC'
              }
            ]
          };
          
          final nameResponse = await http.post(
            Uri.parse(baseUrl),
            headers: headers,
            body: json.encode(nameRequestData),
          ).timeout(Duration(seconds: 15));
          
          if (nameResponse.statusCode == 200) {
            final nameResponseData = json.decode(nameResponse.body);
            if (nameResponseData['success'] == true) {
              nameResults = List<Map<String, dynamic>>.from(nameResponseData['data']);
            }
          }
          
          // 전화번호로 검색
          Map<String, dynamic> phoneRequestData = {
            'operation': 'get',
            'table': 'v3_members',
            'fields': [
              'member_id',
              'member_name', 
              'member_phone',
              'member_type',
              'member_chn_keyword',
              'member_register',
              'member_nickname',
              'member_gender',
              'chat_bookmark'
            ],
            'where': _addBranchFilter([
              {
                'field': 'member_id',
                'operator': 'IN',
                'value': filteredMemberIds
              },
              {
                'field': 'member_phone',
                'operator': 'LIKE',
                'value': '%$searchQuery%'
              }
            ], 'v3_members'),
            'orderBy': [
              {
                'field': 'member_id',
                'direction': 'DESC'
              }
            ]
          };
          
          final phoneResponse = await http.post(
            Uri.parse(baseUrl),
            headers: headers,
            body: json.encode(phoneRequestData),
          ).timeout(Duration(seconds: 15));
          
          if (phoneResponse.statusCode == 200) {
            final phoneResponseData = json.decode(phoneResponse.body);
            if (phoneResponseData['success'] == true) {
              phoneResults = List<Map<String, dynamic>>.from(phoneResponseData['data']);
            }
          }
          
          // 결과 합치기 (중복 제거)
          Set<String> existingIds = nameResults.map((item) => item['member_id'].toString()).toSet();
          for (var phoneResult in phoneResults) {
            if (!existingIds.contains(phoneResult['member_id'].toString())) {
              nameResults.add(phoneResult);
            }
          }
          
          return nameResults;
        } else {
          // 필터링이 없는 경우 기존 로직 사용
          requestData['where'] = _addBranchFilter([
            {
              'field': 'member_name',
              'operator': 'LIKE',
              'value': '%$searchQuery%'
            }
          ], 'v3_members');
        }
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(responseData['data']);
          
          // 전화번호로도 검색하여 결과 추가 (프로 필터링이 없고 검색어가 있는 경우만)
          if (searchQuery != null && searchQuery.isNotEmpty && filteredMemberIds == null) {
            try {
              Map<String, dynamic> phoneRequestData = {
                'operation': 'get',
                'table': 'v3_members',
                'fields': [
                  'member_id',
                  'member_name', 
                  'member_phone',
                  'member_type',
                  'member_chn_keyword',
                  'member_register'
                ],
                'where': _addBranchFilter([
                  {
                    'field': 'member_phone',
                    'operator': 'LIKE',
                    'value': '%$searchQuery%'
                  }
                ], 'v3_members'),
                'orderBy': [
                  {
                    'field': 'member_id',
                    'direction': 'DESC'
                  }
                ]
              };
              
              final phoneResponse = await http.post(
                Uri.parse(baseUrl),
                headers: headers,
                body: json.encode(phoneRequestData),
              ).timeout(Duration(seconds: 15));
              
              if (phoneResponse.statusCode == 200) {
                final phoneResponseData = json.decode(phoneResponse.body);
                if (phoneResponseData['success'] == true) {
                  List<Map<String, dynamic>> phoneResults = List<Map<String, dynamic>>.from(phoneResponseData['data']);
                  
                  // 중복 제거하면서 결과 합치기
                  Set<String> existingIds = results.map((item) => item['member_id'].toString()).toSet();
                  for (var phoneResult in phoneResults) {
                    if (!existingIds.contains(phoneResult['member_id'].toString())) {
                      results.add(phoneResult);
                    }
                  }
                }
              }
            } catch (e) {
              // 전화번호 검색 실패해도 이름 검색 결과는 반환
              print('전화번호 검색 오류: $e');
            }
          }
          
          return results;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Comment 데이터 조회
  static Future<List<Map<String, dynamic>>> getCommentData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'Comment',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'Comment');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Board 데이터 추가
  static Future<Map<String, dynamic>> addBoardData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'Board');
      
      final requestData = {
        'operation': 'add',
        'table': 'Board',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Board 데이터 업데이트
  static Future<Map<String, dynamic>> updateBoardData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      // WHERE 조건에 branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'Board');
      
      final requestData = {
        'operation': 'update',
        'table': 'Board',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Board 데이터 삭제
  static Future<Map<String, dynamic>> deleteBoardData(
    List<Map<String, dynamic>> where,
  ) async {
    try {
      // WHERE 조건에 branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'Board');
      
      final requestData = {
        'operation': 'delete',
        'table': 'Board',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }
  
  // Comment 데이터 추가
  static Future<void> addCommentData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'Comment');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'add',
          'table': 'Comment',
          'data': dataWithBranch,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('댓글 추가 실패: ${responseData['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('접근 권한이 없습니다.');
      } else if (response.statusCode == 404) {
        throw Exception('API 엔드포인트를 찾을 수 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('네트워크 연결 오류: $e');
      }
      rethrow;
    }
  }

  // Comment 데이터 삭제
  static Future<Map<String, dynamic>> deleteCommentData(
    List<Map<String, dynamic>> where,
  ) async {
    try {
      // WHERE 조건에 branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'Comment');
      
      final requestData = {
        'operation': 'delete',
        'table': 'Comment',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_priced_TS 데이터 조회 (타석관리용)
  static Future<List<Map<String, dynamic>>> getTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_priced_TS',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_priced_TS');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      // print('타석 API 요청 데이터: ${json.encode(requestData)}'); // 디버그 로그
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      // print('타석 API 응답 상태: ${response.statusCode}'); // 디버그 로그
      // print('타석 API 응답 본문: ${response.body}'); // 디버그 로그
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data']);
          // print('타석 데이터 파싱 완료: ${data.length}건'); // 디버그 로그
          return data;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          print('타석 API 오류: $errorMsg'); // 디버그 로그
          throw Exception('API 오류: $errorMsg');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else if (response.statusCode == 500) {
        print('서버 500 오류 응답: ${response.body}'); // 디버그 로그
        throw Exception('서버 내부 오류 (500): 서버 설정을 확인해주세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('타석 API 호출 예외: $e'); // 디버그 로그
      
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        rethrow; // 이미 처리된 예외는 그대로 전달
      }
    }
  }

  // v2_priced_TS 데이터 업데이트
  static Future<Map<String, dynamic>> updateTsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_priced_TS');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_priced_TS',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          throw Exception('타석 데이터 업데이트 실패: $errorMsg');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('타석 데이터 업데이트 오류: $e');
      rethrow;
    }
  }

  // v2_priced_TS 데이터 추가
  static Future<Map<String, dynamic>> addTsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_priced_TS');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_priced_TS',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          throw Exception('타석 데이터 추가 실패: $errorMsg');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('타석 데이터 추가 오류: $e');
      rethrow;
    }
  }

  // 타석 요금 정책 조회
  static Future<List<Map<String, dynamic>>> getTsPricingPolicy({
    required DateTime date,
  }) async {
    try {
      // 한글 요일명으로 변환 (1=월요일, 2=화요일, ..., 7=일요일)
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final dayOfWeek = weekdays[date.weekday - 1];
      
      final fields = [
        'policy_category', 'policy_start_time', 'policy_end_time', 'day_of_week',
        'policy_apply', 'branch_id'
      ];
      
      final where = [
        {
          'field': 'day_of_week',
          'operator': '=',
          'value': dayOfWeek,
        }
      ];
      
      final data = await getTsPricingPolicyData(
        fields: fields,
        where: where,
        orderBy: [
          {'field': 'policy_category', 'direction': 'ASC'},
          {'field': 'policy_start_time', 'direction': 'ASC'},
        ],
      );
      
      return data;
    } catch (e) {
      print('요금 정책 조회 오류: $e');
      return [];
    }
  }
  
  // 시간대별 요금 분석
  static Map<String, int> analyzePricingByTimeRange({
    required String startTime,
    required String endTime,
    required List<Map<String, dynamic>> pricingPolicies,
  }) {
    Map<String, int> timeAnalysis = {
      'discount_price': 0,
      'base_price': 0,
      'extracharge_price': 0,
    };
    
    try {
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = _timeToMinutes(endTime);
      
      // 5분 단위로 시간을 나누어 각 구간이 어떤 요금 정책에 속하는지 확인
      for (int minute = startMinutes; minute < endMinutes; minute += 5) {
        final currentTimeStr = _minutesToTime(minute);
        final policyType = _getPolicyTypeForTime(currentTimeStr, pricingPolicies);
        
        // 5분씩 해당 정책에 추가
        timeAnalysis[policyType] = (timeAnalysis[policyType] ?? 0) + 5;
      }
      
      // 나머지 시간 처리
      final remainingMinutes = (endMinutes - startMinutes) % 5;
      if (remainingMinutes > 0) {
        final lastTimeStr = _minutesToTime(endMinutes - remainingMinutes);
        final policyType = _getPolicyTypeForTime(lastTimeStr, pricingPolicies);
        timeAnalysis[policyType] = (timeAnalysis[policyType] ?? 0) + remainingMinutes;
      }
      
    } catch (e) {
      print('시간대별 요금 분석 오류: $e');
      // 오류 시 전체 시간을 일반 요금으로 처리
      final totalMinutes = _timeToMinutes(endTime) - _timeToMinutes(startTime);
      timeAnalysis['base_price'] = totalMinutes;
    }
    
    return timeAnalysis;
  }
  
  // 특정 시간의 요금 정책 타입 반환
  static String _getPolicyTypeForTime(String timeStr, List<Map<String, dynamic>> pricingPolicies) {
    final timeMinutes = _timeToMinutes(timeStr);
    
    for (final policy in pricingPolicies) {
      final policyStart = policy['policy_start_time'];
      final policyEnd = policy['policy_end_time'];
      final policyApply = policy['policy_apply'];
      
      if (policyStart != null && policyEnd != null && policyApply != null) {
        final startMinutes = _timeToMinutes(policyStart);
        final endMinutes = _timeToMinutes(policyEnd);
        
        if (timeMinutes >= startMinutes && timeMinutes < endMinutes) {
          return policyApply; // 'base_price', 'discount_price', 'extracharge_price'
        }
      }
    }
    
    // 기본적으로 일반 요금
    return 'base_price';
  }
  
  // 시간 문자열을 분으로 변환
  static int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
  
  // 분을 시간 문자열로 변환
  static String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // v2_bill_times 데이터 업데이트
  static Future<Map<String, dynamic>> updateBillTimesData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_bill_times');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_bill_times',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          throw Exception('v2_bill_times 업데이트 실패: $errorMsg');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('v2_bill_times 업데이트 오류: $e');
      rethrow;
    }
  }

  // v2_bill_games 데이터 업데이트
  static Future<Map<String, dynamic>> updateBillGamesData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_bill_games');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_bill_games',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          throw Exception('v2_bill_games 업데이트 실패: $errorMsg');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('v2_bill_games 업데이트 오류: $e');
      rethrow;
    }
  }

  // v2_bills 데이터 업데이트
  static Future<Map<String, dynamic>> updateBillsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_bills');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_bills',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          throw Exception('v2_bills 업데이트 실패: $errorMsg');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('v2_bills 업데이트 오류: $e');
      rethrow;
    }
  }

  // v2_discount_coupon 데이터 업데이트
  static Future<Map<String, dynamic>> updateDiscountCouponsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_discount_coupon');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_discount_coupon',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          final errorMsg = responseData['error'] ?? responseData['message'] ?? '알 수 없는 오류';
          throw Exception('v2_discount_coupon 업데이트 실패: $errorMsg');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('v2_discount_coupon 업데이트 오류: $e');
      rethrow;
    }
  }

  // TS 정보 조회 (v2_ts_info 테이블)
  static Future<List<Map<String, dynamic>>> getTsInfoData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, String>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'operation': 'get',
        'table': 'v2_ts_info',
        'fields': fields ?? ['*'],
      };
      
      // WHERE 조건에 branch_id 필터링 자동 추가
      List<Map<String, dynamic>> conditions = where ?? [];
      conditions = _addBranchFilter(conditions, 'v2_ts_info');
      if (conditions.isNotEmpty) {
        requestData['where'] = conditions;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      if (offset != null) {
        requestData['offset'] = offset;
        }
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('타석 정보 조회 실패: ${data['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('타석 정보 조회 오류: $e');
      throw Exception('타석 정보 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 타석 정보 추가
  static Future<Map<String, dynamic>> addTsInfoData(Map<String, dynamic> tsData) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final branchId = getCurrentBranchId();
      if (branchId != null) {
        tsData['branch_id'] = branchId;
      }

      Map<String, dynamic> requestData = {
        'operation': 'add',
        'table': 'v2_ts_info',
        'data': tsData,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
      } else {
          throw Exception('타석 정보 추가 실패: ${data['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석 정보 추가 오류: $e');
      }
    }
  }

  // 타석 정보 수정
  static Future<Map<String, dynamic>> updateTsInfoData(
    Map<String, dynamic> tsData,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      // WHERE 조건에 branch_id 필터링 자동 추가
      List<Map<String, dynamic>> conditions = _addBranchFilter(where, 'v2_ts_info');

      Map<String, dynamic> requestData = {
        'operation': 'update',
        'table': 'v2_ts_info',
        'data': tsData,
        'where': conditions,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception('타석 정보 수정 실패: ${data['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석 정보 수정 오류: $e');
      }
    }
  }

  // 타석 정보 삭제
  static Future<Map<String, dynamic>> deleteTsInfoData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      // WHERE 조건에 branch_id 필터링 자동 추가
      List<Map<String, dynamic>> conditions = _addBranchFilter(where, 'v2_ts_info');

      Map<String, dynamic> requestData = {
        'operation': 'delete',
        'table': 'v2_ts_info',
        'where': conditions,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception('타석 정보 삭제 실패: ${data['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석 정보 삭제 오류: $e');
      }
    }
  }

  // 타석 예약 데이터 조회 (v2_priced_TS 테이블)
  static Future<List<Map<String, dynamic>>> getPricedTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        'operation': 'get',
        'table': 'v2_priced_TS',
        'fields': fields ?? ['*'],
      };
      
      // WHERE 조건에 branch_id 필터링 자동 추가
      List<Map<String, dynamic>> conditions = where ?? [];
      conditions = _addBranchFilter(conditions, 'v2_priced_TS');
      if (conditions.isNotEmpty) {
        requestData['where'] = conditions;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('타석 예약 데이터 조회 실패: ${data['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('타석 예약 데이터 조회 오류: $e');
      throw Exception('타석 예약 데이터 조회 중 오류가 발생했습니다: $e');
    }
  }

  // FMS_TS 데이터 조회 (타석 예약 데이터)
  static Future<List<Map<String, dynamic>>> getFmsTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'FMS_TS',
        'fields': fields ?? ['*'],
      };
      
      if (where != null && where.isNotEmpty) {
        requestData['where'] = where;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 날짜 포맷 함수
  static String formatDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '-';
    
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  // 전화번호 포맷 함수
  static String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    return phone;
  }

  // 회원 타입에 따른 배지 색상
  static Map<String, dynamic> getMemberTypeBadge(String? memberType) {
    switch (memberType) {
      case '남성':
        return {
          'color': Color(0xFF3B82F6),
          'backgroundColor': Color(0xFFDBEAFE),
          'text': '남성'
        };
      case '여성':
        return {
          'color': Color(0xFFEC4899),
          'backgroundColor': Color(0xFFFCE7F3),
          'text': '여성'
        };
      default:
        return {
          'color': Color(0xFF64748B),
          'backgroundColor': Color(0xFFF1F5F9),
          'text': memberType ?? '-'
        };
    }
  }

  // 회원별 크레딧 조회 (v2_bills 테이블에서 가장 최신 잔액) - 최적화된 버전
  static Future<Map<int, Map<String, dynamic>>> getMemberCredits(List<int> memberIds) async {
    _beforeApiCall();
    try {
      if (memberIds.isEmpty) return {};

      // branch_id 필터링을 위한 where 조건 생성
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': 'IN',
          'value': memberIds,
        }
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(whereConditions, 'v2_bills');

      // 모든 회원의 크레딧 정보를 한 번에 조회 (contract_history_id, contract_credit_expiry_date 포함)
      final requestData = {
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['member_id', 'bill_balance_after', 'bill_id', 'contract_history_id', 'contract_credit_expiry_date'],
        'where': filteredWhere,
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'ASC',
          },
          {
            'field': 'contract_history_id',
            'direction': 'ASC',
          },
          {
            'field': 'bill_id',
            'direction': 'DESC',
          }
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> billsData = List<Map<String, dynamic>>.from(responseData['data']);

          // 각 회원별로 contract_history_id별 최신 정보 추출
          Map<int, Map<String, dynamic>> memberCreditsInfo = {};
          Map<int, Map<int, Map<String, dynamic>>> memberContractData = {}; // member_id -> contract_history_id -> data

          // 현재 날짜
          DateTime now = DateTime.now();

          for (var bill in billsData) {
            int memberId = bill['member_id'];
            int contractHistoryId = bill['contract_history_id'] ?? 0;
            int balance = bill['bill_balance_after'] ?? 0;
            String? expiryDateStr = bill['contract_credit_expiry_date'];

            // 회원별 계약 데이터 구조 초기화
            if (!memberContractData.containsKey(memberId)) {
              memberContractData[memberId] = {};
            }

            // contract_history_id별로 최신 bill_id의 데이터만 저장
            if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
                bill['bill_id'] > memberContractData[memberId]![contractHistoryId]!['bill_id']) {
              memberContractData[memberId]![contractHistoryId] = {
                'bill_id': bill['bill_id'],
                'balance': balance,
                'expiry_date': expiryDateStr,
              };
            }
          }

          // 각 회원별로 유효한 계약들의 잔액 합산 및 유효기간 계산
          for (var entry in memberContractData.entries) {
            int memberId = entry.key;
            Map<int, Map<String, dynamic>> contracts = entry.value;

            int totalBalance = 0;
            int validContractCount = 0;
            DateTime? nearestExpiryDate;

            for (var contractData in contracts.values) {
              int balance = contractData['balance'] ?? 0;
              String? expiryDateStr = contractData['expiry_date'];

              // 잔액이 0보다 크고 유효기간이 현재보다 미래인 계약만 합산
              if (balance > 0) {
                bool isValid = true;

                if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                  try {
                    DateTime expiryDate = DateTime.parse(expiryDateStr);
                    if (expiryDate.isBefore(now)) {
                      isValid = false; // 만료된 계약
                    } else {
                      // 가장 가까운 유효기간 추적
                      if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                        nearestExpiryDate = expiryDate;
                      }
                    }
                  } catch (e) {
                    // 날짜 파싱 실패 시 유효한 것으로 간주
                  }
                }

                if (isValid) {
                  totalBalance += balance;
                  validContractCount++;
                }
              }
            }

            memberCreditsInfo[memberId] = {
              'total_balance': totalBalance,
              'contract_count': validContractCount,
              'nearest_expiry_date': nearestExpiryDate?.toIso8601String(),
            };
          }

          // 요청된 회원 중 크레딧 정보가 없는 회원은 기본값으로 설정
          for (int memberId in memberIds) {
            if (!memberCreditsInfo.containsKey(memberId)) {
              memberCreditsInfo[memberId] = {
                'total_balance': 0,
                'contract_count': 0,
                'nearest_expiry_date': null,
              };
            }
          }

          return memberCreditsInfo;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('크레딧 조회 오류: $e');
      // 오류 시 모든 회원을 기본값으로 설정
      Map<int, Map<String, dynamic>> fallbackCredits = {};
      for (int memberId in memberIds) {
        fallbackCredits[memberId] = {
          'total_balance': 0,
          'contract_count': 0,
          'nearest_expiry_date': null,
        };
      }
      return fallbackCredits;
    }
  }

  // 회원별 기간권 조회 (v2_bill_term 테이블에서 contract_history_id별 집계)
  static Future<Map<int, Map<String, dynamic>>> getMemberTermTickets(List<int> memberIds) async {
    _beforeApiCall();
    try {
      if (memberIds.isEmpty) return {};

      // branch_id 필터링을 위한 where 조건 생성
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': 'IN',
          'value': memberIds,
        }
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(whereConditions, 'v2_bill_term');

      // 모든 회원의 기간권 정보를 한 번에 조회
      final requestData = {
        'operation': 'get',
        'table': 'v2_bill_term',
        'fields': ['member_id', 'bill_text', 'bill_term_id', 'contract_history_id', 'contract_term_month_expiry_date'],
        'where': filteredWhere,
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'ASC',
          },
          {
            'field': 'contract_history_id',
            'direction': 'ASC',
          },
          {
            'field': 'bill_term_id',
            'direction': 'DESC',
          }
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> termData = List<Map<String, dynamic>>.from(responseData['data']);

          // 각 회원별로 contract_history_id별 최신 정보 추출
          Map<int, Map<String, dynamic>> memberTermInfo = {};
          Map<int, Map<int, Map<String, dynamic>>> memberContractData = {}; // member_id -> contract_history_id -> data

          // 현재 날짜
          DateTime now = DateTime.now();

          for (var termRecord in termData) {
            int memberId = termRecord['member_id'];
            int contractHistoryId = termRecord['contract_history_id'] ?? 0;
            String billText = termRecord['bill_text'] ?? '';
            String? expiryDateStr = termRecord['contract_term_month_expiry_date'];

            // 회원별 계약 데이터 구조 초기화
            if (!memberContractData.containsKey(memberId)) {
              memberContractData[memberId] = {};
            }

            // contract_history_id별로 최신 bill_term_id의 데이터만 저장
            if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
                termRecord['bill_term_id'] > memberContractData[memberId]![contractHistoryId]!['bill_term_id']) {
              memberContractData[memberId]![contractHistoryId] = {
                'bill_term_id': termRecord['bill_term_id'],
                'bill_text': billText,
                'expiry_date': expiryDateStr,
              };
            }
          }

          // 각 회원별로 유효한 계약들의 기간권 합산 및 유효기간 계산
          for (var entry in memberContractData.entries) {
            int memberId = entry.key;
            Map<int, Map<String, dynamic>> contracts = entry.value;

            int validContractCount = 0;
            DateTime? nearestExpiryDate;
            List<Map<String, dynamic>> validTermTypes = [];

            for (var contractData in contracts.values) {
              String? expiryDateStr = contractData['expiry_date'];
              String billText = contractData['bill_text'] ?? '';

              // 유효기간이 현재보다 미래인 계약만 포함
              bool isValid = true;
              int remainingDays = 0;

              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime nowDate = DateTime(now.year, now.month, now.day); // 시간 제거
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day); // 시간 제거
                  remainingDays = expiryDateOnly.difference(nowDate).inDays;

                  if (remainingDays < 0) {
                    isValid = false; // 만료된 계약
                  } else {
                    // 가장 가까운 유효기간 추적
                    if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                      nearestExpiryDate = expiryDate;
                    }
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                  isValid = true;
                }
              }

              if (isValid) {
                validContractCount++;
                validTermTypes.add({
                  'bill_text': billText,
                  'remaining_days': remainingDays,
                  'expiry_date': expiryDateStr,
                });
              }
            }

            memberTermInfo[memberId] = {
              'contract_count': validContractCount,
              'nearest_expiry_date': nearestExpiryDate?.toIso8601String(),
              'term_types': validTermTypes,
            };
          }

          // 요청된 회원 중 기간권 정보가 없는 회원은 기본값으로 설정
          for (int memberId in memberIds) {
            if (!memberTermInfo.containsKey(memberId)) {
              memberTermInfo[memberId] = {
                'contract_count': 0,
                'nearest_expiry_date': null,
                'term_types': [],
              };
            }
          }

          return memberTermInfo;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('기간권 조회 오류: $e');
      // 오류 시 모든 회원을 기본값으로 설정
      Map<int, Map<String, dynamic>> fallbackTickets = {};
      for (int memberId in memberIds) {
        fallbackTickets[memberId] = {
          'contract_count': 0,
          'nearest_expiry_date': null,
          'term_types': [],
        };
      }
      return fallbackTickets;
    }
  }

  // 회원별 시간권 조회 (v2_bill_times 테이블에서 contract_history_id별 집계)
  static Future<Map<int, Map<String, dynamic>>> getMemberTimeTickets(List<int> memberIds) async {
    _beforeApiCall();
    try {
      if (memberIds.isEmpty) return {};

      // branch_id 필터링을 위한 where 조건 생성
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': 'IN',
          'value': memberIds,
        }
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(whereConditions, 'v2_bill_times');

      // 모든 회원의 시간권 정보를 한 번에 조회 (contract_history_id, contract_TS_min_expiry_date 포함)
      final requestData = {
        'operation': 'get',
        'table': 'v2_bill_times',
        'fields': ['member_id', 'bill_balance_min_after', 'bill_min_id', 'contract_history_id', 'contract_TS_min_expiry_date'],
        'where': filteredWhere,
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'ASC',
          },
          {
            'field': 'contract_history_id',
            'direction': 'ASC',
          },
          {
            'field': 'bill_min_id',
            'direction': 'DESC',
          }
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> timeData = List<Map<String, dynamic>>.from(responseData['data']);

          // 각 회원별로 contract_history_id별 최신 정보 추출
          Map<int, Map<String, dynamic>> memberTimeInfo = {};
          Map<int, Map<int, Map<String, dynamic>>> memberContractData = {}; // member_id -> contract_history_id -> data

          // 현재 날짜
          DateTime now = DateTime.now();

          for (var timeRecord in timeData) {
            int memberId = timeRecord['member_id'];
            int contractHistoryId = timeRecord['contract_history_id'] ?? 0;
            int balance = timeRecord['bill_balance_min_after'] ?? 0;
            String? expiryDateStr = timeRecord['contract_TS_min_expiry_date'];

            // 회원별 계약 데이터 구조 초기화
            if (!memberContractData.containsKey(memberId)) {
              memberContractData[memberId] = {};
            }

            // contract_history_id별로 최신 bill_min_id의 데이터만 저장
            if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
                timeRecord['bill_min_id'] > memberContractData[memberId]![contractHistoryId]!['bill_min_id']) {
              memberContractData[memberId]![contractHistoryId] = {
                'bill_min_id': timeRecord['bill_min_id'],
                'balance': balance,
                'expiry_date': expiryDateStr,
              };
            }
          }

          // 각 회원별로 유효한 계약들의 시간권 합산 및 유효기간 계산
          for (var entry in memberContractData.entries) {
            int memberId = entry.key;
            Map<int, Map<String, dynamic>> contracts = entry.value;

            int totalBalance = 0;
            int validContractCount = 0;
            DateTime? nearestExpiryDate;

            for (var contractData in contracts.values) {
              int balance = contractData['balance'] ?? 0;
              String? expiryDateStr = contractData['expiry_date'];

              // 잔액이 0보다 크고 유효기간이 현재보다 미래인 계약만 합산
              if (balance > 0) {
                bool isValid = true;

                if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                  try {
                    DateTime expiryDate = DateTime.parse(expiryDateStr);
                    if (expiryDate.isBefore(now)) {
                      isValid = false; // 만료된 계약
                    } else {
                      // 가장 가까운 유효기간 추적
                      if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                        nearestExpiryDate = expiryDate;
                      }
                    }
                  } catch (e) {
                    // 날짜 파싱 실패 시 유효한 것으로 간주
                  }
                }

                if (isValid) {
                  totalBalance += balance;
                  validContractCount++;
                }
              }
            }

            memberTimeInfo[memberId] = {
              'total_balance': totalBalance,
              'contract_count': validContractCount,
              'nearest_expiry_date': nearestExpiryDate?.toIso8601String(),
            };
          }

          // 요청된 회원 중 시간권 정보가 없는 회원은 기본값으로 설정
          for (int memberId in memberIds) {
            if (!memberTimeInfo.containsKey(memberId)) {
              memberTimeInfo[memberId] = {
                'total_balance': 0,
                'contract_count': 0,
                'nearest_expiry_date': null,
              };
            }
          }

          return memberTimeInfo;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('시간권 조회 오류: $e');
      // 오류 시 모든 회원을 기본값으로 설정
      Map<int, Map<String, dynamic>> fallbackTickets = {};
      for (int memberId in memberIds) {
        fallbackTickets[memberId] = {
          'total_balance': 0,
          'contract_count': 0,
          'nearest_expiry_date': null,
        };
      }
      return fallbackTickets;
    }
  }

  // 회원별 레슨권 조회 (v3_LS_countings 테이블에서 contract_history_id별 집계)
  static Future<Map<int, Map<String, dynamic>>> getMemberLessonTickets(List<int> memberIds) async {
    _beforeApiCall();
    try {
      if (memberIds.isEmpty) return {};

      // branch_id 필터링을 위한 where 조건 생성
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': 'IN',
          'value': memberIds,
        }
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(whereConditions, 'v3_LS_countings');

      // 모든 회원의 레슨권 정보를 한 번에 조회 (contract_history_id, LS_expiry_date 포함)
      final requestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['member_id', 'LS_type', 'pro_name', 'LS_balance_min_after', 'LS_counting_id', 'contract_history_id', 'LS_expiry_date'],
        'where': filteredWhere,
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'ASC',
          },
          {
            'field': 'contract_history_id',
            'direction': 'ASC',
          },
          {
            'field': 'LS_counting_id',
            'direction': 'DESC',
          }
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> lessonData = List<Map<String, dynamic>>.from(responseData['data']);

          // 각 회원별로 contract_history_id별 최신 정보 추출
          Map<int, Map<String, dynamic>> memberLessonInfo = {};
          Map<int, Map<int, Map<String, dynamic>>> memberContractData = {}; // member_id -> contract_history_id -> data

          // 현재 날짜
          DateTime now = DateTime.now();

          for (var lesson in lessonData) {
            int memberId = lesson['member_id'];
            int contractHistoryId = lesson['contract_history_id'] ?? 0;
            String lsType = lesson['LS_type'] ?? '';
            String lsContractPro = lesson['pro_name'] ?? '';
            int balance = lesson['LS_balance_min_after'] ?? 0;
            String? expiryDateStr = lesson['LS_expiry_date'];

            // 회원별 계약 데이터 구조 초기화
            if (!memberContractData.containsKey(memberId)) {
              memberContractData[memberId] = {};
            }

            // contract_history_id별로 최신 LS_counting_id의 데이터만 저장
            if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
                lesson['LS_counting_id'] > memberContractData[memberId]![contractHistoryId]!['LS_counting_id']) {
              memberContractData[memberId]![contractHistoryId] = {
                'LS_counting_id': lesson['LS_counting_id'],
                'LS_type': lsType,
                'pro_name': lsContractPro,
                'balance': balance,
                'expiry_date': expiryDateStr,
              };
            }
          }

          // 각 회원별로 유효한 계약들의 레슨권 합산 및 유효기간 계산
          for (var entry in memberContractData.entries) {
            int memberId = entry.key;
            Map<int, Map<String, dynamic>> contracts = entry.value;

            int totalBalance = 0;
            int validContractCount = 0;
            DateTime? nearestExpiryDate;
            List<Map<String, dynamic>> validLessonTypes = [];
            Set<String> validProNames = {}; // 유효한 계약의 프로명 수집

            for (var contractData in contracts.values) {
              int balance = contractData['balance'] ?? 0;
              String? expiryDateStr = contractData['expiry_date'];
              String lsType = contractData['LS_type'] ?? '';
              String lsContractPro = contractData['pro_name'] ?? '';

              // 잔액이 0보다 크고 유효기간이 현재보다 미래인 계약만 합산
              if (balance > 0) {
                bool isValid = true;

                if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                  try {
                    DateTime expiryDate = DateTime.parse(expiryDateStr);
                    if (expiryDate.isBefore(now)) {
                      isValid = false; // 만료된 계약
                    } else {
                      // 가장 가까운 유효기간 추적
                      if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                        nearestExpiryDate = expiryDate;
                      }
                    }
                  } catch (e) {
                    // 날짜 파싱 실패 시 유효한 것으로 간주
                  }
                }

                if (isValid) {
                  totalBalance += balance;
                  validContractCount++;
                  validLessonTypes.add({
                    'LS_type': lsType,
                    'pro_name': lsContractPro,
                    'balance': balance,
                  });

                  // 유효한 프로명 수집 (빈 문자열이 아닌 경우만)
                  if (lsContractPro.isNotEmpty) {
                    validProNames.add(lsContractPro);
                  }
                }
              }
            }

            memberLessonInfo[memberId] = {
              'total_balance': totalBalance,
              'contract_count': validContractCount,
              'nearest_expiry_date': nearestExpiryDate?.toIso8601String(),
              'lesson_types': validLessonTypes,
              'pro_names': validProNames.toList(), // 유효한 프로명 리스트
            };
          }

          // 요청된 회원 중 레슨권 정보가 없는 회원은 기본값으로 설정
          for (int memberId in memberIds) {
            if (!memberLessonInfo.containsKey(memberId)) {
              memberLessonInfo[memberId] = {
                'total_balance': 0,
                'contract_count': 0,
                'nearest_expiry_date': null,
                'lesson_types': [],
                'pro_names': [],
              };
            }
          }

          return memberLessonInfo;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('레슨권 조회 오류: $e');
      // 오류 시 모든 회원을 기본값으로 설정
      Map<int, Map<String, dynamic>> fallbackTickets = {};
      for (int memberId in memberIds) {
        fallbackTickets[memberId] = {
          'total_balance': 0,
          'contract_count': 0,
          'nearest_expiry_date': null,
          'lesson_types': [],
          'pro_names': [],
        };
      }
      return fallbackTickets;
    }
  }

  // 주니어 관계 데이터 조회
  static Future<List<Map<String, dynamic>>> getJuniorRelations({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_junior_relation');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_junior_relation',
        'fields': fields ?? ['*'],
      };
      
      if (filteredWhere != null && filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/dynamic_api.php'),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 관계가 있는 회원 ID 목록 조회
  static Future<List<int>> getJuniorFamilyMemberIds() async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_group',
        'fields': ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter([], 'v2_group');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      print('관계 회원 API 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('관계 회원 API 응답 상태: ${response.statusCode}');
      print('관계 회원 API 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final relations = List<Map<String, dynamic>>.from(responseData['data']);
          
          // 관계가 있는 모든 회원 ID를 수집
          Set<int> familyMemberIds = {};
          
          for (var relation in relations) {
            int? memberId = relation['member_id'];
            int? relatedMemberId = relation['related_member_id'];
            
            if (memberId != null) {
              familyMemberIds.add(memberId);
            }
            if (relatedMemberId != null) {
              familyMemberIds.add(relatedMemberId);
            }
          }
          
          return familyMemberIds.toList();
        } else {
          print('관계 회원 API 실패: ${responseData['error']}');
          // 테이블이 존재하지 않거나 데이터가 없으면 빈 리스트 반환
          return [];
        }
      } else if (response.statusCode == 400) {
        print('관계 회원 API 400 오류: v2_group 테이블이 존재하지 않거나 필드명이 잘못되었습니다.');
        // 400 오류 시 빈 리스트 반환 (테이블이 없거나 필드명이 잘못된 경우)
        return [];
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        print('관계 회원 조회 오류: $e');
        // 오류 발생 시 빈 리스트 반환
        return [];
      }
    }
  }

  // 최근 등록된 회원 ID 조회 (최근 10명)
  static Future<List<int>> getRecentMemberIds() async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': ['member_id'],
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'DESC'
          }
        ],
        'limit': 10,
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter([], 'v3_members');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data']);
          List<int> recentMemberIds = [];
          
          for (var item in data) {
            if (item['member_id'] != null) {
              recentMemberIds.add(item['member_id']);
            }
          }
          
          return recentMemberIds;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 특정 회원 정보 조회
  static Future<Map<String, dynamic>?> getMemberById(int memberId) async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': ['*'],
        'where': [
          {
            'field': 'member_id',
            'operator': '=',
            'value': memberId,
          }
        ],
        'limit': 1,
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v3_members');
      requestData['where'] = filteredWhere;
      
      final response = await http.post(
        Uri.parse('$baseUrl/dynamic_api.php'),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data']);
          return data.isNotEmpty ? data.first : null;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 회원 정보 업데이트
  // 회원 즐겨찾기 업데이트
  static Future<bool> updateMemberBookmark(int memberId, String bookmarkStatus) async {
    return updateMember(memberId, {
      'chat_bookmark': bookmarkStatus,
    });
  }

  static Future<bool> updateMember(int memberId, Map<String, dynamic> updateData) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(updateData, 'v3_members');
      
      // WHERE 조건에도 branch_id 필터링 적용
      final whereConditions = [
          {
            'field': 'member_id',
            'operator': '=',
            'value': memberId,
          }
      ];
      final filteredWhere = _addBranchFilter(whereConditions, 'v3_members');
      
      final requestData = {
        'operation': 'update',
        'table': 'v3_members',
        'data': dataWithBranch,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 특정 contract_history_id로 계약 정보 조회
  static Future<Map<String, dynamic>?> getContractHistoryDataById(int contractHistoryId) async {
    _beforeApiCall();
    try {
      final data = await getContractHistoryData(
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          }
        ],
        limit: 1,
      );
      
      return data.isNotEmpty ? data.first : null;
    } catch (e) {
      print('계약 정보 조회 오류: $e');
      return null;
    }
  }

  // 월별 매출 집계 데이터 조회
  static Future<Map<String, dynamic>> getMonthlySalesReport({
    required int year,
    required int month,
  }) async {
    try {
      // 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);

      // 날짜 포맷팅 (YYYY-MM-DD)
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      print('월별 매출 조회 시작 - 년: $year, 월: $month');
      print('날짜 범위: $startDate ~ $endDate');

      final requestData = {
        'operation': 'get',
        'table': 'v3_contract_history',
        'fields': [
          'contract_date',
          'contract_history_status',
          'member_name',
          'contract_name',
          'payment_type',
          'price',
          'contract_credit',
          'contract_LS_min',
          'contract_games',
          'contract_TS_min',
          'contract_term_month',
        ],
      };

      // WHERE 조건: branch_id 필터 + 해당 월 (상태와 payment_type은 클라이언트에서 필터링)
      final where = [
        {
          'field': 'contract_date',
          'operator': '>=',
          'value': startDate,
        },
        {
          'field': 'contract_date',
          'operator': '<=',
          'value': endDate,
        },
      ];

      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('요청 데이터: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data']);

          // 집계 계산
          double totalPrice = 0;
          double totalCredit = 0;
          int totalLSMin = 0;
          int totalGames = 0;
          int totalTSMin = 0;
          int totalTermMonth = 0;
          int validRecordCount = 0; // 실제 집계에 포함된 건수

          for (var record in data) {
            // '삭제' 상태가 아니고 크레딧 관련이 아닌 것만 집계
            final status = record['contract_history_status']?.toString() ?? '';
            final paymentType = record['payment_type']?.toString() ?? '';
            final contractType = record['contract_type']?.toString() ?? '';

            if (status == '삭제' || paymentType == '데이터 이전' || paymentType == '크레딧결제') {
              continue;
            }

            // 유효한 레코드 카운트 증가
            validRecordCount++;

            // price 집계
            if (record['price'] != null && record['price'] != '') {
              totalPrice += double.tryParse(record['price'].toString()) ?? 0;
            }

            // contract_credit 집계
            if (record['contract_credit'] != null && record['contract_credit'] != '') {
              totalCredit += double.tryParse(record['contract_credit'].toString()) ?? 0;
            }

            // contract_LS_min 집계
            if (record['contract_LS_min'] != null && record['contract_LS_min'] != '') {
              totalLSMin += int.tryParse(record['contract_LS_min'].toString()) ?? 0;
            }

            // contract_games 집계
            if (record['contract_games'] != null && record['contract_games'] != '') {
              totalGames += int.tryParse(record['contract_games'].toString()) ?? 0;
            }

            // contract_TS_min 집계
            if (record['contract_TS_min'] != null && record['contract_TS_min'] != '') {
              totalTSMin += int.tryParse(record['contract_TS_min'].toString()) ?? 0;
            }

            // contract_term_month 집계
            if (record['contract_term_month'] != null && record['contract_term_month'] != '') {
              totalTermMonth += int.tryParse(record['contract_term_month'].toString()) ?? 0;
            }
          }

          return {
            'year': year,
            'month': month,
            'recordCount': validRecordCount, // 실제 집계된 건수만 포함
            'totalPrice': totalPrice,
            'totalCredit': totalCredit,
            'totalLSMin': totalLSMin,
            'totalGames': totalGames,
            'totalTSMin': totalTSMin,
            'totalTermMonth': totalTermMonth,
            'rawData': data, // 원본 데이터도 포함
          };
        } else {
          print('월별 매출 조회 실패: ${responseData['message']}');
          return {};
        }
      } else {
        print('월별 매출 조회 HTTP 오류: ${response.statusCode}');
        print('응답 내용: ${response.body}');
        return {};
      }
    } catch (e) {
      print('월별 매출 조회 오류: $e');
      return {};
    }
  }

  // 월별 트렌드 데이터 조회 (연도별 12개월)
  static Future<List<Map<String, dynamic>>> getMonthlySalesTrend({
    int? year,
    int? monthsBack,
    bool? includeBills,
    bool? includeLessonUsage,
  }) async {
    try {
      final List<Map<String, dynamic>> trendData = [];

      if (year != null) {
        // 특정 연도의 12개월 데이터 조회
        for (int month = 1; month <= 12; month++) {
          final salesReport = await getMonthlySalesReport(
            year: year,
            month: month,
          );

          // contract_type별 매출 집계 추가
          final contractTypeReport = await getMonthlyContractTypeBreakdown(
            year: year,
            month: month,
          );

          Map<String, dynamic> monthData = {
            'year': year,
            'month': month,
            'monthLabel': '$year-${month.toString().padLeft(2, '0')}',
            'recordCount': salesReport['recordCount'] ?? 0,
            'totalPrice': salesReport['totalPrice'] ?? 0,
            'totalCredit': salesReport['totalCredit'] ?? 0,
            'totalLSMin': salesReport['totalLSMin'] ?? 0,
            'totalGames': salesReport['totalGames'] ?? 0,
            'totalTSMin': salesReport['totalTSMin'] ?? 0,
            'totalTermMonth': salesReport['totalTermMonth'] ?? 0,
            'contractTypeBreakdown': contractTypeReport['contractTypeBreakdown'] ?? {},
          };

          // includeBills가 true일 때만 bills 데이터 조회
          if (includeBills == true) {
            final billsReport = await getMonthlyBillsReport(
              year: year,
              month: month,
            );
            monthData['totalBills'] = billsReport['totalBills'] ?? 0;
          } else {
            monthData['totalBills'] = 0;
          }

          // includeLessonUsage가 true일 때만 레슨 사용 데이터 조회 + 레슨권 판매 프로별 집계
          if (includeLessonUsage == true) {
            final lessonUsageReport = await getMonthlyLessonUsageReport(
              year: year,
              month: month,
            );
            final lessonSalesProReport = await getMonthlyLessonSalesProBreakdown(
              year: year,
              month: month,
            );
            monthData['totalLessonUsage'] = lessonUsageReport['totalLessonUsage'] ?? 0;
            monthData['proUsageBreakdown'] = lessonUsageReport['proUsageBreakdown'] ?? {};
            monthData['proSalesBreakdown'] = lessonSalesProReport['proSalesBreakdown'] ?? {};
          } else {
            monthData['totalLessonUsage'] = 0;
            monthData['proUsageBreakdown'] = {};
            monthData['proSalesBreakdown'] = {};
          }

          trendData.add(monthData);
        }
      } else {
        // 기존 로직 (최근 N개월)
        final now = DateTime.now();
        final months = monthsBack ?? 12;
        for (int i = months - 1; i >= 0; i--) {
          final targetDate = DateTime(now.year, now.month - i, 1);
          final salesReport = await getMonthlySalesReport(
            year: targetDate.year,
            month: targetDate.month,
          );

          if (salesReport.isNotEmpty) {
            // contract_type별 매출 집계 추가
            final contractTypeReport = await getMonthlyContractTypeBreakdown(
              year: targetDate.year,
              month: targetDate.month,
            );

            Map<String, dynamic> monthData = {
              'year': targetDate.year,
              'month': targetDate.month,
              'monthLabel': '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}',
              'recordCount': salesReport['recordCount'] ?? 0,
              'totalPrice': salesReport['totalPrice'] ?? 0,
              'totalCredit': salesReport['totalCredit'] ?? 0,
              'totalLSMin': salesReport['totalLSMin'] ?? 0,
              'totalGames': salesReport['totalGames'] ?? 0,
              'totalTSMin': salesReport['totalTSMin'] ?? 0,
              'totalTermMonth': salesReport['totalTermMonth'] ?? 0,
              'contractTypeBreakdown': contractTypeReport['contractTypeBreakdown'] ?? {},
            };

            // includeBills가 true일 때만 bills 데이터 조회
            if (includeBills == true) {
              final billsReport = await getMonthlyBillsReport(
                year: targetDate.year,
                month: targetDate.month,
              );
              monthData['totalBills'] = billsReport['totalBills'] ?? 0;
            } else {
              monthData['totalBills'] = 0;
            }

            // includeLessonUsage가 true일 때만 레슨 사용 데이터 조회 + 레슨권 판매 프로별 집계
            if (includeLessonUsage == true) {
              final lessonUsageReport = await getMonthlyLessonUsageReport(
                year: targetDate.year,
                month: targetDate.month,
              );
              final lessonSalesProReport = await getMonthlyLessonSalesProBreakdown(
                year: targetDate.year,
                month: targetDate.month,
              );
              monthData['totalLessonUsage'] = lessonUsageReport['totalLessonUsage'] ?? 0;
              monthData['proUsageBreakdown'] = lessonUsageReport['proUsageBreakdown'] ?? {};
              monthData['proSalesBreakdown'] = lessonSalesProReport['proSalesBreakdown'] ?? {};
            } else {
              monthData['totalLessonUsage'] = 0;
              monthData['proUsageBreakdown'] = {};
              monthData['proSalesBreakdown'] = {};
            }

            trendData.add(monthData);
          }
        }
      }

      print('월별 트렌드 데이터 조회 완료: ${trendData.length}개월');
      return trendData;
    } catch (e) {
      print('월별 트렌드 데이터 조회 오류: $e');
      return [];
    }
  }

  // 월별 청구 데이터 조회
  static Future<Map<String, dynamic>> getMonthlyBillsReport({
    required int year,
    required int month,
  }) async {
    try {
      // 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);

      // 날짜 포맷팅 (YYYY-MM-DD)
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final requestData = {
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['bill_netamt', 'bill_date', 'bill_type', 'bill_status'],
      };

      // WHERE 조건: branch_id 필터 + 해당 월 (bill_type과 bill_status는 클라이언트에서 필터링)
      final where = [
        {
          'field': 'bill_date',
          'operator': '>=',
          'value': startDate,
        },
        {
          'field': 'bill_date',
          'operator': '<=',
          'value': endDate,
        },
      ];

      final filteredWhere = _addBranchFilter(where, 'v2_bills');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('=== v2_bills 쿼리 요청 ===');
      print('년: $year, 월: $month');
      print('날짜 범위: $startDate ~ $endDate');
      print('요청 데이터: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> rawData = responseData['data'];

        double totalBills = 0;
        int validRecordCount = 0; // 실제 집계에 포함된 건수

        print('=== 서버 응답 데이터 확인 ===');
        print('전체 응답 건수: ${rawData.length}건');

        for (var record in rawData) {
          // 클라이언트 사이드 필터링: '데이터 이관', '회원권 구매' 제외, '결제완료'만 포함
          final billType = record['bill_type']?.toString() ?? '';
          final billStatus = record['bill_status']?.toString() ?? '';

          if (billType == '데이터 이관' || billType == '회원권 구매') {
            continue; // 데이터 이관, 회원권 구매 제외
          }

          if (billStatus != '결제완료') {
            continue; // 결제완료가 아닌 것 제외
          }

          if (record['bill_netamt'] != null && record['bill_netamt'] != '') {
            final billAmount = double.tryParse(record['bill_netamt'].toString()) ?? 0;

            // 크레딧 사용은 마이너스 값으로 저장되므로, 마이너스 값만 필터링하여 절대값으로 합산
            if (billAmount < 0) {
              totalBills += billAmount.abs();
              validRecordCount++; // 유효한 레코드 카운트 증가
            }
          }
        }

        print('=== 월별 청구 데이터 조회 완료 ===');
        print('년: $year, 월: $month');
        print('크레딧 사용 건수: ${validRecordCount}건');
        print('총 크레딧 사용 금액: ${totalBills.toStringAsFixed(0)}원');
        print('=============================');

        return {
          'year': year,
          'month': month,
          'totalBills': totalBills,
          'recordCount': validRecordCount,
        };
      } else {
        print('월별 청구 데이터 조회 실패: ${responseData['message'] ?? 'Unknown error'}');
        return {
          'year': year,
          'month': month,
          'totalBills': 0,
          'recordCount': 0,
        };
      }
    } catch (e) {
      print('월별 청구 데이터 조회 오류: $e');
      return {
        'year': year,
        'month': month,
        'totalBills': 0,
        'recordCount': 0,
      };
    }
  }

  // v3_contract_history 데이터 조회 (계약 이력)
  static Future<List<Map<String, dynamic>>> getContractHistoryData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v3_contract_history',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v3_members 테이블에 신규 회원 추가
  static Future<Map<String, dynamic>> addMember(Map<String, dynamic> memberData) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(memberData, 'v3_members');
      
      final requestData = {
        'operation': 'add',
        'table': 'v3_members',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'member_id': responseData['insertId'],
            'message': '회원이 성공적으로 등록되었습니다.'
          };
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v3_LS_countings 데이터 조회 (레슨권 내역)
  static Future<List<Map<String, dynamic>>> getLSCountingsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v3_LS_countings');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_bills 데이터 조회 (크레딧 내역)
  static Future<List<Map<String, dynamic>>> getBillsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_bills',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_bills');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_bills 데이터 추가 (크레딧 수동차감/적립)
  static Future<Map<String, dynamic>> addBillsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addBillsData 시작 ===');
    print('입력 데이터: $data');
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_bills');
      print('branch_id 추가 후 데이터: $dataWithBranch');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_bills',
        'data': dataWithBranch,
      };
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('Bills 데이터 추가 성공: $responseData');
          return responseData;
        } else {
          print('API 오류 발생: ${responseData['error']}');
          throw Exception(responseData['error'] ?? '데이터 추가 실패');
        }
      } else if (response.statusCode == 403) {
        print('서버 접근 권한 오류');
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        print('HTTP 오류 발생: ${response.statusCode}');
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      print('요청 시간 초과');
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      print('네트워크 연결 오류');
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('Bills 데이터 추가 예외 발생: $e');
      throw Exception('데이터 추가 중 오류가 발생했습니다: $e');
    }
  }

  // v2_bill_term 데이터 조회 (기간권 조회)
  static Future<List<Map<String, dynamic>>> getBillTermData({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = <String, dynamic>{
        'operation': 'get',
        'table': 'v2_bill_term',
      };

      if (where != null && where.isNotEmpty) {
        // branch_id 조건 자동 추가
        final whereWithBranch = List<Map<String, dynamic>>.from(where);
        final currentBranchId = getCurrentBranchId();
        if (currentBranchId != null) {
          whereWithBranch.add({
            'field': 'branch_id',
            'operator': '=',
            'value': currentBranchId
          });
        }
        requestData['where'] = whereWithBranch;
      } else {
        // where 조건이 없으면 branch_id만 추가
        final currentBranchId = getCurrentBranchId();
        if (currentBranchId != null) {
          requestData['where'] = [
            {'field': 'branch_id', 'operator': '=', 'value': currentBranchId}
          ];
        }
      }

      if (orderBy != null) {
        requestData['orderBy'] = orderBy;
      }

      if (limit != null) {
        requestData['limit'] = limit;
      }

      if (offset != null) {
        requestData['offset'] = offset;
      }

      print('getBillTermData 요청: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        } else {
          throw Exception(data['error'] ?? '데이터 조회 실패');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('getBillTermData 오류: $e');
      throw Exception('기간권 데이터 조회 중 오류가 발생했습니다: $e');
    }
  }

  // v2_bill_term_hold 데이터 추가 (홀드 등록)
  static Future<Map<String, dynamic>> addBillTermHoldData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addBillTermHoldData 시작 ===');
    print('입력 데이터: $data');
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_bill_term_hold');
      print('branch_id 추가 후 데이터: $dataWithBranch');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_bill_term_hold',
        'data': dataWithBranch,
      };
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('addBillTermHoldData 파싱된 응답: $responseData');
        
        if (responseData['success'] == true) {
          return {
            'success': true,
            'insertId': responseData['insertId'],
            'data': responseData['data']
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? '데이터 추가 실패'
          };
        }
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } on TimeoutException {
      print('요청 시간 초과');
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      print('네트워크 연결 오류');
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('Bill Term Hold 데이터 추가 예외 발생: $e');
      throw Exception('데이터 추가 중 오류가 발생했습니다: $e');
    }
  }

  // v2_bill_term 테이블에서 특정 contract_history_id의 최신 레코드 조회
  static Future<Map<String, dynamic>?> getLatestBillTermByContractHistoryId(int contractHistoryId) async {
    _beforeApiCall();
    try {
      final data = await getBillTermData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
        ],
        orderBy: [
          {'field': 'bill_term_id', 'direction': 'DESC'}
        ],
        limit: 1,
      );
      
      return data.isNotEmpty ? data.first : null;
    } catch (e) {
      print('getLatestBillTermByContractHistoryId 오류: $e');
      return null;
    }
  }

  // v2_bill_term 테이블의 contract_term_month_expiry_date 업데이트
  static Future<Map<String, dynamic>> updateBillTermExpiryDate(
    int billTermId, 
    String newExpiryDate,
    String newEndDate,
  ) async {
    try {
      final requestData = {
        'operation': 'update',
        'table': 'v2_bill_term',
        'data': {
          'contract_term_month_expiry_date': newExpiryDate,
          'term_enddate': newEndDate,
        },
        'where': [
          {'field': 'bill_term_id', 'operator': '=', 'value': billTermId}
        ]
      };
      
      print('updateBillTermExpiryDate 요청: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      print('updateBillTermExpiryDate 오류: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // v2_bill_term 데이터 추가 (기간권 관리)
  static Future<Map<String, dynamic>> addBillTermData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addBillTermData 시작 ===');
    print('입력 데이터: $data');
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_bill_term');
      print('branch_id 추가 후 데이터: $dataWithBranch');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_bill_term',
        'data': dataWithBranch,
      };
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('addBillTermData 파싱된 응답: $responseData');
        
        if (responseData['success'] == true) {
          return {
            'success': true,
            'insertId': responseData['insertId'],
            'data': responseData['data']
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? '데이터 추가 실패'
          };
        }
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } on TimeoutException {
      print('요청 시간 초과');
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      print('네트워크 연결 오류');
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('Bill Term 데이터 추가 예외 발생: $e');
      throw Exception('데이터 추가 중 오류가 발생했습니다: $e');
    }
  }

  // v2_bill_times 데이터 추가 (시간 크레딧 관리)
  static Future<Map<String, dynamic>> addBillTimesData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addBillTimesData 시작 ===');
    print('입력 데이터: $data');
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_bill_times');
      print('branch_id 추가 후 데이터: $dataWithBranch');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_bill_times',
        'data': dataWithBranch,
      };
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('Bill Times 데이터 추가 성공: $responseData');
          return responseData;
        } else {
          print('API 오류 발생: ${responseData['error']}');
          throw Exception(responseData['error'] ?? '데이터 추가 실패');
        }
      } else if (response.statusCode == 403) {
        print('서버 접근 권한 오류');
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        print('HTTP 오류 발생: ${response.statusCode}');
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      print('요청 시간 초과');
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      print('네트워크 연결 오류');
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('Bill Times 데이터 추가 예외 발생: $e');
      throw Exception('데이터 추가 중 오류가 발생했습니다: $e');
    }
  }

  // v2_bill_games 데이터 추가 (게임 크레딧 관리)
  static Future<Map<String, dynamic>> addBillGamesData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addBillGamesData 시작 ===');
    print('입력 데이터: $data');
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_bill_games');
      print('branch_id 추가 후 데이터: $dataWithBranch');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_bill_games',
        'data': dataWithBranch,
      };
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('Bill Games 데이터 추가 성공: $responseData');
          return responseData;
        } else {
          print('API 오류 발생: ${responseData['error']}');
          throw Exception(responseData['error'] ?? '데이터 추가 실패');
        }
      } else if (response.statusCode == 403) {
        print('서버 접근 권한 오류');
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        print('HTTP 오류 발생: ${response.statusCode}');
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      print('요청 시간 초과');
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      print('네트워크 연결 오류');
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('Bill Games 데이터 추가 예외 발생: $e');
      throw Exception('데이터 추가 중 오류가 발생했습니다: $e');
    }
  }

  // v2_contracts 데이터 조회 (상품 목록)
  static Future<List<Map<String, dynamic>>> getContractsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_contracts');
      
      final requestData = {
          'operation': 'get',
          'table': 'v2_contracts',
        'fields': fields ?? ['*'],
      };
      
      if (filteredWhere != null && filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('계약 데이터 조회 오류: $e');
    }
  }

  // v2_base_option_setting 데이터 조회 (옵션 설정)
  static Future<List<String>> getBaseOptionSettings({
    required String category,
    required String tableName,
    required String fieldName,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_base_option_setting',
        'fields': ['option_value'],
        'where': [
          {
            'field': 'category',
            'operator': '=',
            'value': category
          },
          {
            'field': 'table_name',
            'operator': '=',
            'value': tableName
          },
          {
            'field': 'field_name',
            'operator': '=',
            'value': fieldName
          },
          {
            'field': 'setting_status',
            'operator': '=',
            'value': '유효'
          }
        ],
        'orderBy': [
          {
            'field': 'option_value',
            'direction': 'ASC'
          }
        ]
      };
      
      // branch_id 필터링 자동 적용
      print('🔍 getBaseOptionSettings - 현재 branch_id: ${getCurrentBranchId()}');
      print('🔍 getBaseOptionSettings - 요청 카테고리: $category');
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_base_option_setting');
      requestData['where'] = filteredWhere;
      print('🔍 getBaseOptionSettings - 최종 WHERE 조건: $filteredWhere');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data']);
          return data.map((item) => item['option_value'].toString()).toList();
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('서버 응답 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('옵션 설정 조회 오류: $e');
    }
  }

  // v2_base_option_setting 데이터 조회 (범용)
  static Future<List<Map<String, dynamic>>> getBaseOptionSettingData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      print('getBaseOptionSettingData 호출됨');
      print('현재 branch_id: ${getCurrentBranchId()}');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_base_option_setting',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      print('필터링된 WHERE 조건: $filteredWhere');
      
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('getBaseOptionSettingData 예외 발생: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_bill_times 데이터 조회
  static Future<List<Map<String, dynamic>>> getBillTimesData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'get',
          'table': 'v2_bill_times',
          'fields': fields,
          'where': where,
          'orderBy': orderBy,
          'limit': limit,
          'offset': offset,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data'] ?? []);
        } else {
          throw Exception(responseData['error'] ?? '빌 타임 조회 실패');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('getBillTimesData 예외 발생: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_cancellation_policy 데이터 조회
  static Future<List<Map<String, dynamic>>> getCancellationPolicyData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'get',
          'table': 'v2_cancellation_policy',
          'fields': fields,
          'where': where,
          'orderBy': orderBy,
          'limit': limit,
          'offset': offset,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data'] ?? []);
        } else {
          throw Exception(responseData['error'] ?? '취소 정책 조회 실패');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('getCancellationPolicyData 예외 발생: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_discount_coupon 데이터 추가 (할인권 증정)
  static Future<Map<String, dynamic>> addDiscountCoupon(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_discount_coupon');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'add',
          'table': 'v2_discount_coupon',
          'data': dataWithBranch,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception(responseData['error'] ?? '할인권 증정 실패');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('할인권 증정 중 오류가 발생했습니다: $e');
    }
  }

  // v2_discount_coupon 데이터 조회 (할인권 내역)
  static Future<List<Map<String, dynamic>>> getDiscountCouponsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_discount_coupon',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_discount_coupon');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 유효한 회원권 조회 (통합예약 상품 설정용)
  static Future<List<Map<String, dynamic>>> getActiveMembershipContracts() async {
    _beforeApiCall();
    try {
      final branchId = getCurrentBranchId();
      if (branchId == null) {
        throw Exception('지점 정보가 없습니다.');
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'get',
          'table': 'v2_contracts',
          'fields': ['contract_id', 'contract_type', 'contract_name', 'contract_LS_min', 'contract_TS_min'],
          'where': [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'contract_category', 'operator': '=', 'value': '회원권'},
            {'field': 'contract_status', 'operator': '=', 'value': '유효'},
          ],
          'orderBy': [
            {'field': 'contract_type', 'direction': 'ASC'},
            {'field': 'contract_name', 'direction': 'ASC'},
          ],
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          return List<Map<String, dynamic>>.from(result['data']);
        } else {
          throw Exception('회원권 조회 실패: ${result['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('회원권 조회 HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원권 조회 중 오류 발생: $e');
      }
    }
  }

  // v2_staff_pro 데이터 조회 (재직중인 프로 목록)
  static Future<List<Map<String, dynamic>>> getActiveStaffPros() async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_staff_pro',
        'fields': ['pro_id', 'pro_name', 'staff_status'],
        'where': [
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직'
          }
        ],
        'orderBy': [
          {
            'field': 'pro_name',
            'direction': 'ASC'
          }
        ]
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_staff_pro');
      requestData['where'] = filteredWhere;
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 유효한 레슨권을 가진 모든 회원 ID 목록 조회
  static Future<List<int>> getValidLessonMemberIds() async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      // branch_id 필터링만 적용 (pro_id 조건 없음)
      final filteredWhere = _addBranchFilter([], 'v3_LS_countings');
      final requestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['member_id', 'LS_expiry_date', 'LS_balance_min_after'],
        'where': filteredWhere,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(responseData['data']);
          // 유효한 레슨권이 있는 회원만 필터링
          Set<int> validMemberIds = {};
          DateTime nowDate = DateTime(now.year, now.month, now.day);
          for (var item in data) {
            int? balance = item['LS_balance_min_after'];
            String? expiryDateStr = item['LS_expiry_date'];
            // 잔액이 0보다 크고 유효기간이 남은 경우만 포함
            if (balance != null && balance > 0) {
              bool isValid = true;
              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                  int remainingDays = expiryDateOnly.difference(nowDate).inDays;
                  if (remainingDays < 0) {
                    isValid = false; // 만료된 레슨권
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                }
              }
              if (isValid) {
                validMemberIds.add(item['member_id'] as int);
              }
            }
          }
          return validMemberIds.toList();
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('유효한 레슨회원 조회 중 오류가 발생했습니다: $e');
      }
    }
  }

  // 프로별 유효한 레슨권이 있는 회원 목록 조회 (v3_LS_countings 기준)
  static Future<List<int>> getMemberIdsByProId(int proId) async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();

      final whereConditions = [
          {
            'field': 'pro_id',
            'operator': '=',
            'value': proId
          }
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(whereConditions, 'v3_LS_countings');

      final requestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['member_id', 'LS_expiry_date', 'LS_balance_min_after'],
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(responseData['data']);

          // 유효한 레슨권이 있는 회원만 필터링
          Set<int> validMemberIds = {};
          DateTime nowDate = DateTime(now.year, now.month, now.day);

          for (var item in data) {
            int? balance = item['LS_balance_min_after'];
            String? expiryDateStr = item['LS_expiry_date'];

            // 잔액이 0보다 크고 유효기간이 남은 경우만 포함
            if (balance != null && balance > 0) {
              bool isValid = true;

              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                  int remainingDays = expiryDateOnly.difference(nowDate).inDays;

                  if (remainingDays < 0) {
                    isValid = false; // 만료된 레슨권
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                }
              }

              if (isValid) {
                validMemberIds.add(item['member_id'] as int);
              }
            }
          }

          return validMemberIds.toList();
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 타석 회원 ID 조회 (유효한 레슨권이 없는 회원)
  static Future<List<int>> getBattingMemberIds() async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      DateTime nowDate = DateTime(now.year, now.month, now.day);

      // 모든 회원 조회
      final allMembersData = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': ['member_id'],
      };

      final allMembersResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(_addBranchFilter([], 'v3_members').isEmpty
          ? allMembersData
          : {...allMembersData, 'where': _addBranchFilter([], 'v3_members')}),
      ).timeout(Duration(seconds: 15));

      if (allMembersResponse.statusCode != 200) {
        throw Exception('HTTP 오류: ${allMembersResponse.statusCode}');
      }

      final allMembersResponseData = json.decode(allMembersResponse.body);
      if (allMembersResponseData['success'] != true) {
        throw Exception('API 오류: ${allMembersResponseData['error']}');
      }

      List<Map<String, dynamic>> allMembers = List<Map<String, dynamic>>.from(allMembersResponseData['data']);
      List<int> allMemberIds = allMembers.map((member) => member['member_id'] as int).toList();

      // 유효한 레슨권이 있는 회원 조회
      final lessonRequestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['member_id', 'LS_balance_min_after', 'LS_expiry_date'],
        'where': _addBranchFilter([
          {
            'field': 'member_id',
            'operator': 'IN',
            'value': allMemberIds,
          }
        ], 'v3_LS_countings'),
      };

      final lessonResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(lessonRequestData),
      ).timeout(Duration(seconds: 15));

      Set<int> validLessonMemberIds = {};

      if (lessonResponse.statusCode == 200) {
        final lessonResponseData = json.decode(lessonResponse.body);
        if (lessonResponseData['success'] == true) {
          List<Map<String, dynamic>> lessonData = List<Map<String, dynamic>>.from(lessonResponseData['data']);

          for (var lesson in lessonData) {
            int? balance = lesson['LS_balance_min_after'];
            String? expiryDateStr = lesson['LS_expiry_date'];

            // 잔액이 0보다 크고 유효기간이 남은 경우
            if (balance != null && balance > 0) {
              bool isValid = true;

              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                  int remainingDays = expiryDateOnly.difference(nowDate).inDays;

                  if (remainingDays < 0) {
                    isValid = false;
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                }
              }

              if (isValid) {
                validLessonMemberIds.add(lesson['member_id'] as int);
              }
            }
          }
        }
      }

      // 유효한 레슨권이 없는 회원 반환 (타석회원)
      List<int> battingMemberIds = allMemberIds.where((memberId) => !validLessonMemberIds.contains(memberId)).toList();

      return battingMemberIds;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 만료회원 ID 목록 조회 (유효한 회원권이 아무것도 없는 회원)
  static Future<List<int>> getExpiredMemberIds() async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      DateTime nowDate = DateTime(now.year, now.month, now.day);

      // 모든 회원 조회
      final allMembersData = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': ['member_id'],
      };

      final allMembersResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(_addBranchFilter([], 'v3_members').isEmpty
          ? allMembersData
          : {...allMembersData, 'where': _addBranchFilter([], 'v3_members')}),
      ).timeout(Duration(seconds: 15));

      if (allMembersResponse.statusCode != 200) {
        throw Exception('HTTP 오류: ${allMembersResponse.statusCode}');
      }

      final allMembersResponseData = json.decode(allMembersResponse.body);
      if (allMembersResponseData['success'] != true) {
        throw Exception('API 오류: ${allMembersResponseData['error']}');
      }

      List<Map<String, dynamic>> allMembers = List<Map<String, dynamic>>.from(allMembersResponseData['data']);
      List<int> allMemberIds = allMembers.map((member) => member['member_id'] as int).toList();

      Set<int> validMemberIds = {};

      // 1. 유효한 크레딧이 있는 회원 조회
      final creditRequestData = {
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['member_id', 'bill_balance_after', 'contract_credit_expiry_date'],
        'where': _addBranchFilter([
          {
            'field': 'member_id',
            'operator': 'IN',
            'value': allMemberIds,
          }
        ], 'v2_bills'),
      };

      final creditResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(creditRequestData),
      ).timeout(Duration(seconds: 15));

      if (creditResponse.statusCode == 200) {
        final creditResponseData = json.decode(creditResponse.body);
        if (creditResponseData['success'] == true) {
          List<Map<String, dynamic>> creditData = List<Map<String, dynamic>>.from(creditResponseData['data']);

          for (var credit in creditData) {
            int? balance = credit['bill_balance_after'];
            String? expiryDateStr = credit['contract_credit_expiry_date'];

            if (balance != null && balance > 0) {
              bool isValid = true;

              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                  int remainingDays = expiryDateOnly.difference(nowDate).inDays;

                  if (remainingDays < 0) {
                    isValid = false;
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                }
              }

              if (isValid) {
                validMemberIds.add(credit['member_id'] as int);
              }
            }
          }
        }
      }

      // 2. 유효한 레슨권이 있는 회원 조회
      final lessonRequestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['member_id', 'LS_balance_min_after', 'LS_expiry_date'],
        'where': _addBranchFilter([
          {
            'field': 'member_id',
            'operator': 'IN',
            'value': allMemberIds,
          }
        ], 'v3_LS_countings'),
      };

      final lessonResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(lessonRequestData),
      ).timeout(Duration(seconds: 15));

      if (lessonResponse.statusCode == 200) {
        final lessonResponseData = json.decode(lessonResponse.body);
        if (lessonResponseData['success'] == true) {
          List<Map<String, dynamic>> lessonData = List<Map<String, dynamic>>.from(lessonResponseData['data']);

          for (var lesson in lessonData) {
            int? balance = lesson['LS_balance_min_after'];
            String? expiryDateStr = lesson['LS_expiry_date'];

            if (balance != null && balance > 0) {
              bool isValid = true;

              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                  int remainingDays = expiryDateOnly.difference(nowDate).inDays;

                  if (remainingDays < 0) {
                    isValid = false;
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                }
              }

              if (isValid) {
                validMemberIds.add(lesson['member_id'] as int);
              }
            }
          }
        }
      }

      // 3. 유효한 시간권이 있는 회원 조회
      final timeRequestData = {
        'operation': 'get',
        'table': 'v2_bill_times',
        'fields': ['member_id', 'bill_balance_min_after', 'contract_TS_min_expiry_date'],
        'where': _addBranchFilter([
          {
            'field': 'member_id',
            'operator': 'IN',
            'value': allMemberIds,
          }
        ], 'v2_bill_times'),
      };

      final timeResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(timeRequestData),
      ).timeout(Duration(seconds: 15));

      if (timeResponse.statusCode == 200) {
        final timeResponseData = json.decode(timeResponse.body);
        if (timeResponseData['success'] == true) {
          List<Map<String, dynamic>> timeData = List<Map<String, dynamic>>.from(timeResponseData['data']);

          for (var time in timeData) {
            int? balance = time['bill_balance_min_after'];
            String? expiryDateStr = time['contract_TS_min_expiry_date'];

            if (balance != null && balance > 0) {
              bool isValid = true;

              if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
                try {
                  DateTime expiryDate = DateTime.parse(expiryDateStr);
                  DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                  int remainingDays = expiryDateOnly.difference(nowDate).inDays;

                  if (remainingDays < 0) {
                    isValid = false;
                  }
                } catch (e) {
                  // 날짜 파싱 실패 시 유효한 것으로 간주
                }
              }

              if (isValid) {
                validMemberIds.add(time['member_id'] as int);
              }
            }
          }
        }
      }

      // 4. 유효한 기간권이 있는 회원 조회
      final termRequestData = {
        'operation': 'get',
        'table': 'v2_bill_term',
        'fields': ['member_id', 'contract_term_month_expiry_date'],
        'where': _addBranchFilter([
          {
            'field': 'member_id',
            'operator': 'IN',
            'value': allMemberIds,
          }
        ], 'v2_bill_term'),
      };

      final termResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(termRequestData),
      ).timeout(Duration(seconds: 15));

      if (termResponse.statusCode == 200) {
        final termResponseData = json.decode(termResponse.body);
        if (termResponseData['success'] == true) {
          List<Map<String, dynamic>> termData = List<Map<String, dynamic>>.from(termResponseData['data']);

          for (var term in termData) {
            String? expiryDateStr = term['contract_term_month_expiry_date'];

            bool isValid = true;

            if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
              try {
                DateTime expiryDate = DateTime.parse(expiryDateStr);
                DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                int remainingDays = expiryDateOnly.difference(nowDate).inDays;

                if (remainingDays < 0) {
                  isValid = false;
                }
              } catch (e) {
                // 날짜 파싱 실패 시 유효한 것으로 간주
              }
            }

            if (isValid) {
              validMemberIds.add(term['member_id'] as int);
            }
          }
        }
      }

      // 유효한 회원권이 없는 회원 반환 (만료회원)
      List<int> expiredMemberIds = allMemberIds.where((memberId) => !validMemberIds.contains(memberId)).toList();

      return expiredMemberIds;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 활성 기간권 회원 조회 (만료되지 않은 회원만)
  static Future<List<Map<String, dynamic>>> getActiveTermMembers() async {
    _beforeApiCall();
    try {
      final requestData = {
          'operation': 'get',
          'table': 'v2_Term_member',
          'where': [
            {
              'field': 'term_expirydate',
              'operator': '>=',
              'value': DateTime.now().toIso8601String().split('T')[0], // 오늘 날짜
            }
          ],
          'orderBy': [
            {
              'field': 'term_type',
              'direction': 'ASC'
            }
          ]
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_Term_member');
      requestData['where'] = filteredWhere;

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('서버 오류: ${data['error'] ?? '알 수 없는 오류'}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('기간권 회원 조회 오류: $e');
    }
  }

  // 특정 기간권 타입의 회원 ID 목록 조회
  static Future<List<int>> getMemberIdsByTermType(String termType) async {
    _beforeApiCall();
    try {
      final requestData = {
          'operation': 'get',
          'table': 'v2_Term_member',
          'fields': ['member_id'],
          'where': [
            {
              'field': 'term_type',
              'operator': '=',
              'value': termType,
            },
            {
              'field': 'term_expirydate',
              'operator': '>=',
              'value': DateTime.now().toIso8601String().split('T')[0], // 오늘 날짜
            }
          ]
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_Term_member');
      requestData['where'] = filteredWhere;

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data['data']);
          return results
              .map((item) => item['member_id'] as int?)
              .where((id) => id != null)
              .cast<int>()
              .toSet() // 중복 제거
              .toList();
        } else {
          throw Exception('서버 오류: ${data['error'] ?? '알 수 없는 오류'}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('기간권 회원 ID 조회 오류: $e');
    }
  }

  // 모든 유효한 기간권 회원 ID 목록 조회 (타입 구분 없이)
  static Future<List<int>> getAllTermMemberIds() async {
    _beforeApiCall();
    try {
      final requestData = {
          'operation': 'get',
          'table': 'v2_Term_member',
          'fields': ['member_id'],
          'where': [
            {
              'field': 'term_expirydate',
              'operator': '>=',
              'value': DateTime.now().toIso8601String().split('T')[0], // 오늘 날짜
            }
          ]
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_Term_member');
      requestData['where'] = filteredWhere;

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data['data']);
          return results
              .map((item) => item['member_id'] as int?)
              .where((id) => id != null)
              .cast<int>()
              .toSet() // 중복 제거
              .toList();
        } else {
          throw Exception('서버 오류: ${data['error'] ?? '알 수 없는 오류'}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('기간권 회원 ID 조회 오류: $e');
    }
  }

  // Staff 로그인 인증 (v2_staff_pro, v2_staff_manager 테이블 사용)
  static Future<Map<String, dynamic>?> authenticateStaff({
    required String staffAccessId,
    required String staffPassword,
  }) async {
    print('=== authenticateStaff 메서드 시작 ===');
    print('입력 받은 값:');
    print('  - staffAccessId: $staffAccessId');
    print('  - staffPassword: (보안상 표시 안함)');

    try {
      // 1. v2_staff_pro 테이블에서 사용자 조회 (비밀번호 검증 없이)
      print('1단계: v2_staff_pro 테이블 조회 시작');
      final proRequestData = {
        'operation': 'get',
        'table': 'v2_staff_pro',
        'where': [
          {
            'field': 'staff_access_id',
            'operator': '=',
            'value': staffAccessId,
          },
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직',
          },
        ],
      };

      print('Pro 테이블 요청 데이터:');
      print(json.encode(proRequestData));
      print('API URL: $baseUrl');

      final proResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(proRequestData),
      ).timeout(Duration(seconds: 15));

      print('Pro 응답 상태 코드: ${proResponse.statusCode}');

      if (proResponse.statusCode == 200) {
        final proResponseData = json.decode(proResponse.body);
        print('Pro 응답 파싱 성공:');
        print('  - success: ${proResponseData['success']}');
        print('  - data 길이: ${proResponseData['data']?.length ?? 0}');

        if (proResponseData['success'] == true && proResponseData['data'].isNotEmpty) {
          // 같은 staff_access_id로 여러 계약이 있을 수 있으므로 모두 순회
          for (var userData in proResponseData['data']) {
            final storedPassword = userData['staff_access_password'] ?? '';

            // PasswordService로 비밀번호 검증
            print('🔐 Pro 비밀번호 검증 시작 (branch: ${userData['branch_id']})...');
            if (PasswordService.verifyPassword(staffPassword, storedPassword)) {
              userData['role'] = 'pro';
              print('✅ Pro로 인증 성공!');
              print('  - pro_name: ${userData['pro_name']}');
              print('  - branch_id: ${userData['branch_id']}');
              print('  - 전체 필드: ${userData.keys.toList()}');
              return userData;
            } else {
              print('❌ Pro 비밀번호 불일치 (branch: ${userData['branch_id']})');
            }
          }
          print('Pro 테이블에서 비밀번호가 일치하는 계약을 찾을 수 없음');
        } else {
          print('Pro 테이블에서 사용자를 찾을 수 없음');
        }
      } else {
        print('❌ Pro API 호출 실패: ${proResponse.statusCode}');
      }

      // 2. v2_staff_manager 테이블에서 사용자 조회 (비밀번호 검증 없이)
      print('2단계: v2_staff_manager 테이블 조회 시작');
      final managerRequestData = {
        'operation': 'get',
        'table': 'v2_staff_manager',
        'where': [
          {
            'field': 'staff_access_id',
            'operator': '=',
            'value': staffAccessId,
          },
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직',
          },
        ],
      };

      print('Manager 테이블 요청 데이터:');
      print(json.encode(managerRequestData));

      final managerResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(managerRequestData),
      ).timeout(Duration(seconds: 15));

      print('Manager 응답 상태 코드: ${managerResponse.statusCode}');

      if (managerResponse.statusCode == 200) {
        final managerResponseData = json.decode(managerResponse.body);
        print('Manager 응답 파싱 성공:');
        print('  - success: ${managerResponseData['success']}');
        print('  - data 길이: ${managerResponseData['data']?.length ?? 0}');

        if (managerResponseData['success'] == true && managerResponseData['data'].isNotEmpty) {
          // 같은 staff_access_id로 여러 계약이 있을 수 있으므로 모두 순회
          for (var userData in managerResponseData['data']) {
            final storedPassword = userData['staff_access_password'] ?? '';

            // PasswordService로 비밀번호 검증
            print('🔐 Manager 비밀번호 검증 시작 (branch: ${userData['branch_id']})...');
            if (PasswordService.verifyPassword(staffPassword, storedPassword)) {
              userData['role'] = 'manager';
              print('✅ Manager로 인증 성공!');
              print('  - manager_name: ${userData['manager_name']}');
              print('  - branch_id: ${userData['branch_id']}');
              print('  - 전체 필드: ${userData.keys.toList()}');
              return userData;
            } else {
              print('❌ Manager 비밀번호 불일치 (branch: ${userData['branch_id']})');
            }
          }
          print('Manager 테이블에서 비밀번호가 일치하는 계약을 찾을 수 없음');
        } else {
          print('Manager 테이블에서도 사용자를 찾을 수 없음');
        }
      } else {
        print('❌ Manager API 호출 실패: ${managerResponse.statusCode}');
      }

      print('❌❌❌ 인증 실패: Pro와 Manager 모두에서 사용자를 찾을 수 없거나 비밀번호 불일치');
      return null;

    } catch (e) {
      print('❌❌❌ 예외 발생: $e');
      print('에러 타입: ${e.runtimeType}');
      if (e.toString().contains('TimeoutException')) {
        print('타임아웃 발생');
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        print('네트워크 연결 문제');
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        print('기타 오류');
        throw Exception('로그인 오류: $e');
      }
    }
  }

  // 지점 정보 조회
  static Future<List<Map<String, dynamic>>> getBranchData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_branch',
        'fields': fields ?? ['*'],
      };
      
      if (where != null && where.isNotEmpty) {
        requestData['where'] = where;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('지점 정보 조회 오류: $e');
      }
    }
  }

  // 특정 지점 ID로 지점 정보 조회
  static Future<Map<String, dynamic>?> getBranchById(String branchId) async {
    _beforeApiCall();
    try {
      final branches = await getBranchData(
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          }
        ],
      );
      
      return branches.isNotEmpty ? branches.first : null;
    } catch (e) {
      throw Exception('지점 정보 조회 오류: $e');
    }
  }

  // 개발용 직원 목록 조회 (특정 지점의 v2_staff_pro, v2_staff_manager 테이블)
  static Future<List<Map<String, dynamic>>> getDevStaffListByBranch(String branchId) async {
    print('=== getDevStaffListByBranch 메서드 시작 (지점: $branchId) ===');
    
    try {
      List<Map<String, dynamic>> allStaff = [];
      
      // 1. v2_staff_pro 테이블에서 해당 지점의 재직 프로 직원 조회
      print('1단계: v2_staff_pro 테이블 조회 시작 (지점: $branchId)');
      final proRequestData = {
        'operation': 'get',
        'table': 'v2_staff_pro',
        'fields': [
          'pro_id',
          'pro_name',
          'staff_access_id',
          'staff_access_password',
          'staff_status',
          'branch_id',
          'pro_phone',
          'pro_gender',
          'pro_contract_status'
        ],
        'where': [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          },
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직',
          },
        ],
        'orderBy': [
          {
            'field': 'pro_name',
            'direction': 'ASC',
          }
        ],
      };

      final proResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(proRequestData),
      ).timeout(Duration(seconds: 15));

      if (proResponse.statusCode == 200) {
        final proResponseData = json.decode(proResponse.body);
        if (proResponseData['success'] == true && proResponseData['data'].isNotEmpty) {
          for (var staff in proResponseData['data']) {
            staff['role'] = 'pro';
            staff['staff_name'] = staff['pro_name']; // 통일된 이름 필드
            allStaff.add(staff);
          }
          print('✅ Pro 직원 ${proResponseData['data'].length}명 조회 성공 (지점: $branchId)');
        }
      }

      // 2. v2_staff_manager 테이블에서 해당 지점의 재직 매니저 직원 조회
      print('2단계: v2_staff_manager 테이블 조회 시작 (지점: $branchId)');
      final managerRequestData = {
        'operation': 'get',
        'table': 'v2_staff_manager',
        'fields': [
          'manager_id',
          'manager_name',
          'staff_access_id',
          'staff_access_password',
          'staff_status',
          'branch_id',
          'manager_phone',
          'manager_gender',
          'manager_contract_status'
        ],
        'where': [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          },
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직',
          },
        ],
        'orderBy': [
          {
            'field': 'manager_name',
            'direction': 'ASC',
          }
        ],
      };

      final managerResponse = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(managerRequestData),
      ).timeout(Duration(seconds: 15));

      if (managerResponse.statusCode == 200) {
        final managerResponseData = json.decode(managerResponse.body);
        if (managerResponseData['success'] == true && managerResponseData['data'].isNotEmpty) {
          for (var staff in managerResponseData['data']) {
            staff['role'] = 'manager';
            staff['staff_name'] = staff['manager_name']; // 통일된 이름 필드
            allStaff.add(staff);
          }
          print('✅ Manager 직원 ${managerResponseData['data'].length}명 조회 성공 (지점: $branchId)');
        }
      }

      // 전체 직원을 이름순으로 정렬
      allStaff.sort((a, b) => (a['staff_name'] ?? '').compareTo(b['staff_name'] ?? ''));
      
      print('✅ 지점별 직원 목록 조회 완료: ${allStaff.length}명 (지점: $branchId)');
      return allStaff;

    } catch (e) {
      print('❌ 지점별 직원 목록 조회 오류: $e');
      throw Exception('지점별 직원 목록 조회 오류: $e');
    }
  }

  // Delete data from table
  static Future<Map<String, dynamic>> deleteData(
    String table,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final requestData = {
        'operation': 'delete',
        'table': table,
        'where': where,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Delete data error: $e');
    }
  }

  // 계약 이력 추가 (v3_contract_history)
  static Future<Map<String, dynamic>> addContractHistoryData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addContractHistoryData 시작 ===');
    print('입력 데이터: $data');
    try {
      final dataWithBranch = _addBranchToData(data, 'v3_contract_history');
      print('branch_id 추가 후 데이터: $dataWithBranch');
      
      final requestData = {
        'operation': 'add',
        'table': 'v3_contract_history',
        'data': dataWithBranch,
      };
      print('최종 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('계약 이력 추가 성공: $responseData');
          return responseData;
        } else {
          print('API 오류 발생: ${responseData['error']}');
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        print('HTTP 오류 발생: ${response.statusCode}');
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('계약 이력 추가 예외 발생: $e');
      throw Exception('계약 이력 추가 오류: $e');
    }
  }

  // 계약 이력 업데이트 (v3_contract_history)
  static Future<bool> updateContractHistoryData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final dataWithBranch = _addBranchToData(data, 'v3_contract_history');
      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');
      
      final requestData = {
        'operation': 'update',
        'table': 'v3_contract_history',
        'data': dataWithBranch,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('계약 이력 업데이트 오류: $e');
    }
  }

  // 레슨 계약 추가 (v2_LS_contracts)
  static Future<Map<String, dynamic>> addLSContractData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_LS_contracts');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_LS_contracts',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('레슨 계약 추가 오류: $e');
    }
  }

  // 레슨 카운팅 추가 (v3_LS_countings)
  static Future<Map<String, dynamic>> addLSCountingData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v3_LS_countings');
      
      final requestData = {
        'operation': 'add',
        'table': 'v3_LS_countings',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('레슨 카운팅 추가 오류: $e');
    }
  }

  // 레슨 카운팅 조회 (v3_LS_countings)
  static Future<List<Map<String, dynamic>>> getLSCountingData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v3_LS_countings');
      
      final requestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': fields ?? ['*'],
      };
      
      if (filteredWhere != null && filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('레슨 카운팅 조회 오류: $e');
    }
  }

  // 회원별 프로 구매횟수 조회 (dynamic_api.php 사용)
  static Future<Map<String, dynamic>> getMemberProPurchaseCount({
    required int memberId,
    int? branchId,
  }) async {
    try {
      final currentBranchId = branchId ?? getCurrentBranchId();
      if (currentBranchId == null) {
        throw Exception('지점 정보를 찾을 수 없습니다.');
      }

      final requestData = {
        'action': 'getMemberProPurchaseCount',
        'member_id': memberId,
        'branch_id': currentBranchId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/../dynamic_api.php'),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? [],
            'total_count': responseData['total_count'] ?? 0,
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Unknown error',
          };
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'message': '프로 구매횟수 조회 오류: $e',
      };
    }
  }

  // 회원-프로 매칭 조회 (v2_member_pro_match)
  static Future<List<Map<String, dynamic>>> getMemberProMatchData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_member_pro_match');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_member_pro_match',
        'fields': fields ?? ['*'],
      };
      
      if (filteredWhere != null && filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('회원-프로 매칭 조회 오류: $e');
    }
  }

  // 회원-프로 매칭 추가 (v2_member_pro_match)
  static Future<Map<String, dynamic>> addMemberProMatchData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_member_pro_match');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_member_pro_match',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('회원-프로 매칭 추가 오류: $e');
    }
  }

  // 회원-프로 매칭 업데이트 (v2_member_pro_match)
  static Future<bool> updateMemberProMatchData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_member_pro_match');
      final filteredWhere = _addBranchFilter(where, 'v2_member_pro_match');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_member_pro_match',
        'data': dataWithBranch,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('회원-프로 매칭 업데이트 오류: $e');
    }
  }

  // 스태프 프로 데이터 조회 (v2_staff_pro)
  static Future<List<Map<String, dynamic>>> getStaffProData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_staff_pro');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_staff_pro',
        'fields': fields ?? ['*'],
      };
      
      if (filteredWhere != null && filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('스태프 프로 조회 오류: $e');
    }
  }

  // ========== 타석유형 관리 (v2_base_option_setting) ==========
  
  // 타석유형 목록 조회
  static Future<List<Map<String, dynamic>>> getTsTypeOptions() async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_base_option_setting',
        'fields': ['option_value'],
        'where': [
          {'field': 'category', 'operator': '=', 'value': '타석종류'},
          {'field': 'table_name', 'operator': '=', 'value': 'v2_ts_info'},
          {'field': 'field_name', 'operator': '=', 'value': 'ts_type'},
        ],
        'orderBy': [
          {'field': 'option_value', 'direction': 'ASC'}
        ],
      };

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_base_option_setting');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('타석유형 조회 요청 데이터: ${json.encode(requestData)}'); // 디버깅용
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('타석유형 조회 응답 상태: ${response.statusCode}'); // 디버깅용
      print('타석유형 조회 응답 본문: ${response.body}'); // 디버깅용
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data'] ?? []);
        } else {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('타석유형 조회 예외: $e'); // 디버깅용
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석유형 조회 오류: $e');
      }
    }
  }

  // 회원유형 목록 조회 (유효/만료 모두)
  static Future<List<Map<String, dynamic>>> getMemberTypeOptions() async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_base_option_setting',
        'fields': ['option_value', 'setting_status', 'option_sequence'],
        'where': [
          {'field': 'category', 'operator': '=', 'value': '유형설정'},
          {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
        ],
        'orderBy': [
          {'field': 'setting_status', 'direction': 'DESC'}, // 유효한 것이 먼저
          {'field': 'option_sequence', 'direction': 'ASC'} // 등록 순서대로
        ],
      };

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_base_option_setting');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('회원유형 조회 요청 데이터: ${json.encode(requestData)}'); // 디버깅용
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('회원유형 조회 응답 상태: ${response.statusCode}'); // 디버깅용
      print('회원유형 조회 응답 본문: ${response.body}'); // 디버깅용
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('회원유형 조회 파싱된 응답: $responseData'); // 추가 디버깅
        if (responseData['success'] == true) {
          final dataList = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          print('회원유형 옵션 데이터 리스트: $dataList'); // 추가 디버깅
          return dataList;
        } else {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('회원유형 조회 예외: $e'); // 디버깅용
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원유형 조회 오류: $e');
      }
    }
  }

  // 회원유형 추가
  static Future<void> addMemberTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final data = {
        'category': '유형설정',
        'table_name': '회원유형',
        'field_name': 'member_type',
        'option_value': optionValue,
        'setting_status': '유효',
      };

      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_base_option_setting');

      final requestData = {
        'operation': 'add',
        'table': 'v2_base_option_setting',
        'data': dataWithBranch,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원유형 추가 오류: $e');
      }
    }
  }

  // 회원유형 수정 (사용 중지 - option_value는 변경 불가, 만료 후 재등록 필요)
  // static Future<void> updateMemberTypeOption(String oldValue, String newValue) async {
  //   _beforeApiCall();
  //   try {
  //     final where = [
  //       {'field': 'category', 'operator': '=', 'value': '회원유형'},
  //       {'field': 'field_name', 'operator': '=', 'value': 'member_type'},
  //       {'field': 'option_value', 'operator': '=', 'value': oldValue},
  //     ];
  //
  //     // branch_id 필터링 자동 적용
  //     final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
  //
  //     final requestData = {
  //       'operation': 'update',
  //       'table': 'v2_base_option_setting',
  //       'data': {
  //         'option_value': newValue,
  //       },
  //       'where': filteredWhere,
  //     };
  //
  //     final response = await http.post(
  //       Uri.parse(baseUrl),
  //       headers: headers,
  //       body: json.encode(requestData),
  //     ).timeout(Duration(seconds: 15));
  //
  //     if (response.statusCode == 200) {
  //       final responseData = json.decode(response.body);
  //       if (responseData['success'] != true) {
  //         throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
  //       }
  //     } else {
  //       throw Exception('HTTP 오류: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     if (e.toString().contains('TimeoutException')) {
  //       throw Exception('서버 응답 시간이 초과되었습니다.');
  //     } else if (e.toString().contains('SocketException')) {
  //       throw Exception('네트워크 연결을 확인해주세요.');
  //     } else {
  //       throw Exception('회원유형 수정 오류: $e');
  //     }
  //   }
  // }

  // 회원유형 만료 처리 (삭제 대신 setting_status를 '만료'로 변경)
  static Future<void> deleteMemberTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

      final requestData = {
        'operation': 'update',
        'table': 'v2_base_option_setting',
        'data': {
          'setting_status': '만료',
        },
        'where': filteredWhere,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원유형 만료 처리 오류: $e');
      }
    }
  }

  // 회원유형 되살리기 (setting_status를 '유효'로 변경)
  static Future<void> restoreMemberTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

      final requestData = {
        'operation': 'update',
        'table': 'v2_base_option_setting',
        'data': {
          'setting_status': '유효',
        },
        'where': filteredWhere,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원유형 되살리기 오류: $e');
      }
    }
  }

  // 회원유형 순서 업데이트
  static Future<void> updateMemberTypeSequence(List<Map<String, String>> sequenceUpdates) async {
    _beforeApiCall();
    try {
      // 각 항목의 option_sequence를 업데이트
      for (var update in sequenceUpdates) {
        final where = [
          {'field': 'category', 'operator': '=', 'value': '유형설정'},
          {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
          {'field': 'option_value', 'operator': '=', 'value': update['option_value']!},
        ];

        // branch_id 필터링 자동 적용
        final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

        final requestData = {
          'operation': 'update',
          'table': 'v2_base_option_setting',
          'data': {
            'option_sequence': int.parse(update['sequence']!),
          },
          'where': filteredWhere,
        };

        final response = await http.post(
          Uri.parse(baseUrl),
          headers: headers,
          body: json.encode(requestData),
        ).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] != true) {
            throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
          }
        } else {
          throw Exception('HTTP 오류: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원유형 순서 업데이트 오류: $e');
      }
    }
  }

  // 회원권 유형 목록 조회
  static Future<List<Map<String, dynamic>>> getMembershipTypeOptions() async {
    _beforeApiCall();
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_base_option_setting',
        'fields': ['option_value', 'setting_status', 'option_sequence'],
        'where': [
          {'field': 'category', 'operator': '=', 'value': '유형설정'},
          {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
        ],
        'orderBy': [
          {'field': 'setting_status', 'direction': 'DESC'}, // 유효한 것이 먼저
          {'field': 'option_sequence', 'direction': 'ASC'} // 등록 순서대로
        ],
      };

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(requestData['where'] as List<Map<String, dynamic>>, 'v2_base_option_setting');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('회원권 유형 조회 요청 데이터: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('회원권 유형 조회 응답 상태: ${response.statusCode}');
      print('회원권 유형 조회 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('회원권 유형 조회 파싱된 응답: $responseData');
        if (responseData['success'] == true) {
          final dataList = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          print('회원권 유형 옵션 데이터 리스트: $dataList');
          return dataList;
        } else {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('회원권 유형 조회 예외: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원권 유형 조회 오류: $e');
      }
    }
  }

  // 회원권 유형 추가
  static Future<void> addMembershipTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final data = {
        'category': '유형설정',
        'table_name': '회원권유형',
        'field_name': 'contract_type',
        'option_value': optionValue,
        'setting_status': '유효',
      };

      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_base_option_setting');

      final requestData = {
        'operation': 'add',
        'table': 'v2_base_option_setting',
        'data': dataWithBranch,
      };

      print('회원권 유형 추가 요청 데이터: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('회원권 유형 추가 응답 상태: ${response.statusCode}');
      print('회원권 유형 추가 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원권 유형 추가 오류: $e');
      }
    }
  }

  // 회원권 유형 만료 처리 (setting_status를 '만료'로 변경)
  static Future<void> deleteMembershipTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

      final requestData = {
        'operation': 'update',
        'table': 'v2_base_option_setting',
        'data': {
          'setting_status': '만료',
        },
        'where': filteredWhere,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원권 유형 만료 처리 오류: $e');
      }
    }
  }

  // 회원권 유형 순서 업데이트
  static Future<void> updateMembershipTypeSequence(List<Map<String, String>> sequenceUpdates) async {
    _beforeApiCall();
    try {
      // 각 항목의 option_sequence를 업데이트
      for (var update in sequenceUpdates) {
        final where = [
          {'field': 'category', 'operator': '=', 'value': '유형설정'},
          {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
          {'field': 'option_value', 'operator': '=', 'value': update['option_value']!},
        ];

        // branch_id 필터링 자동 적용
        final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

        final requestData = {
          'operation': 'update',
          'table': 'v2_base_option_setting',
          'data': {
            'option_sequence': int.parse(update['sequence']!),
          },
          'where': filteredWhere,
        };

        final response = await http.post(
          Uri.parse(baseUrl),
          headers: headers,
          body: json.encode(requestData),
        ).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] != true) {
            throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
          }
        } else {
          throw Exception('HTTP 오류: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원권 유형 순서 업데이트 오류: $e');
      }
    }
  }

  // 회원권 유형 되살리기 (setting_status를 '유효'로 변경)
  static Future<void> restoreMembershipTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

      final requestData = {
        'operation': 'update',
        'table': 'v2_base_option_setting',
        'data': {
          'setting_status': '유효',
        },
        'where': filteredWhere,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('회원권 유형 되살리기 오류: $e');
      }
    }
  }

  // 타석유형 추가
  static Future<void> addTsTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final data = {
        'category': '타석종류',
        'table_name': 'v2_ts_info',
        'field_name': 'ts_type',
        'option_value': optionValue,
      };

      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_base_option_setting');

      final requestData = {
        'operation': 'add',
        'table': 'v2_base_option_setting',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석유형 추가 오류: $e');
      }
    }
  }

  // 타석유형 수정
  static Future<void> updateTsTypeOption(String oldValue, String newValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '타석종류'},
        {'field': 'table_name', 'operator': '=', 'value': 'v2_ts_info'},
        {'field': 'field_name', 'operator': '=', 'value': 'ts_type'},
        {'field': 'option_value', 'operator': '=', 'value': oldValue},
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

      final requestData = {
        'operation': 'update',
        'table': 'v2_base_option_setting',
        'data': {
          'option_value': newValue,
        },
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석유형 수정 오류: $e');
      }
    }
  }

  // 타석유형 삭제
  static Future<void> deleteTsTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '타석종류'},
        {'field': 'table_name', 'operator': '=', 'value': 'v2_ts_info'},
        {'field': 'field_name', 'operator': '=', 'value': 'ts_type'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];

      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');

      final requestData = {
        'operation': 'delete',
        'table': 'v2_base_option_setting',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] != true) {
          throw Exception('API 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('타석유형 삭제 오류: $e');
      }
    }
  }

  // ========== v2_contracts 테이블 관련 메서드들 ==========
  
  // v2_contracts 데이터 추가 (회원권 추가)
  static Future<Map<String, dynamic>> addContractsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_contracts');
      
      final requestBody = {
        'operation': 'add',
        'table': 'v2_contracts',
        'data': dataWithBranch,
      };
      
      print('=== API 요청 상세 정보 ===');
      print('URL: $baseUrl');
      print('Headers: $headers');
      print('Request Body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 15));

      print('=== API 응답 상세 정보 ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception(responseData['error'] ?? '회원권 추가 실패');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      print('=== API 에러 상세 정보 ===');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      throw Exception('회원권 추가 중 오류가 발생했습니다: $e');
    }
  }

  // v2_contracts 데이터 수정 (회원권 수정)
  static Future<Map<String, dynamic>> updateContractsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_contracts');
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_contracts');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'update',
          'table': 'v2_contracts',
          'data': dataWithBranch,
          'where': filteredWhere,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception(responseData['error'] ?? '회원권 수정 실패');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('회원권 수정 중 오류가 발생했습니다: $e');
    }
  }

  // v2_contracts 데이터 삭제 (회원권 삭제)
  static Future<Map<String, dynamic>> deleteContractsData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_contracts');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'delete',
          'table': 'v2_contracts',
          'where': filteredWhere,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception(responseData['error'] ?? '회원권 삭제 실패');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('요청 시간이 초과되었습니다.');
    } on SocketException {
      throw Exception('네트워크 연결을 확인해주세요.');
    } catch (e) {
      throw Exception('회원권 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // v2_ts_pricing_policy 데이터 조회 (과금정책 조회)
  static Future<List<Map<String, dynamic>>> getPricingPolicyData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_ts_pricing_policy');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_ts_pricing_policy',
        'fields': fields ?? ['*'],
      };
      
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('과금정책 조회 오류: $e');
      }
    }
  }

  // v2_ts_pricing_policy 데이터 추가 (과금정책 추가)
  static Future<Map<String, dynamic>> addPricingPolicyData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_ts_pricing_policy');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_ts_pricing_policy',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('과금정책 추가 오류: $e');
    }
  }

  // v2_ts_pricing_policy 데이터 삭제 (과금정책 삭제)
  static Future<Map<String, dynamic>> deletePricingPolicyData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_ts_pricing_policy');
      
      final requestData = {
        'operation': 'delete',
        'table': 'v2_ts_pricing_policy',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('과금정책 삭제 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 조회 (일별 조정된 스케줄 조회)
  static Future<List<Map<String, dynamic>>> getScheduleAdjustedTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_schedule_adjusted_ts',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_schedule_adjusted_ts');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // 타석 요금 정책 데이터 조회
  static Future<List<Map<String, dynamic>>> getTsPricingPolicyData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_ts_pricing_policy', // 올바른 테이블명
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_ts_pricing_policy');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }
      
      if (orderBy != null && orderBy.isNotEmpty) {
        requestData['orderBy'] = orderBy;
      }
      
      if (limit != null) {
        requestData['limit'] = limit;
      }
      
      if (offset != null) {
        requestData['offset'] = offset;
      }
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else if (response.statusCode == 403) {
        throw Exception('서버 접근 권한이 없습니다. 관리자에게 문의하세요.');
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답 시간이 초과되었습니다.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('네트워크 연결을 확인해주세요.');
      } else {
        throw Exception('네트워크 오류: $e');
      }
    }
  }

  // v2_schedule_adjusted_ts 데이터 추가 (일별 조정된 스케줄 추가)
  static Future<Map<String, dynamic>> addScheduleAdjustedTsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_schedule_adjusted_ts');
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_schedule_adjusted_ts',
        'data': dataWithBranch,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('일별 스케줄 추가 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 수정 (일별 조정된 스케줄 수정)
  static Future<Map<String, dynamic>> updateScheduleAdjustedTsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_schedule_adjusted_ts');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_schedule_adjusted_ts',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('일별 스케줄 수정 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 삭제 (일별 조정된 스케줄 삭제)
  static Future<Map<String, dynamic>> deleteScheduleAdjustedTsData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_schedule_adjusted_ts');
      
      final requestData = {
        'operation': 'delete',
        'table': 'v2_schedule_adjusted_ts',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('일별 스케줄 삭제 오류: $e');
    }
  }

  // ========== 게시판 관련 메소드들 ==========

  // v2_board 데이터 조회 (게시판 목록)
  static Future<List<Map<String, dynamic>>> getBoardByMemberData({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where ?? [], 'v2_board');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_board',
        'where': filteredWhere,
        if (orderBy != null) 'orderBy': orderBy,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      };
      
      print('🔍 [DEBUG] getBoardByMemberData 요청 데이터:');
      print('📋 Request: ${json.encode(requestData)}');
      print('🌐 URL: $baseUrl');
      print('📦 Headers: $headers');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('📡 [DEBUG] 응답 상태코드: ${response.statusCode}');
      print('📄 [DEBUG] 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ [DEBUG] 파싱된 응답: $responseData');
        
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          print('📊 [DEBUG] 조회된 데이터 개수: ${data.length}');
          return data;
        } else {
          print('❌ [DEBUG] API 오류: ${responseData['error']}');
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        print('🚨 [DEBUG] HTTP 오류 - 상태코드: ${response.statusCode}, 응답: ${response.body}');
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('💥 [DEBUG] 예외 발생: $e');
      print('📍 [DEBUG] 스택 트레이스: ${StackTrace.current}');
      throw Exception('게시판 데이터 조회 오류: $e');
    }
  }

  // v2_board 데이터 추가 (새 게시글 작성)
  static Future<Map<String, dynamic>> addBoardByMemberData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      print('🔍 [DEBUG] addBoardByMemberData 시작');
      print('📥 [DEBUG] 입력 데이터: $data');
      print('🏢 [DEBUG] 현재 branch_id: $_currentBranchId');
      
      // 현재 branch_id 추가
      if (_currentBranchId != null) {
        data['branch_id'] = _currentBranchId;
        print('✅ [DEBUG] branch_id 추가됨: $_currentBranchId');
      } else {
        print('⚠️  [DEBUG] branch_id가 null입니다!');
      }
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_board',
        'data': data,
      };
      
      print('📋 [DEBUG] 최종 요청 데이터: ${json.encode(requestData)}');
      print('🌐 [DEBUG] URL: $baseUrl');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('📡 [DEBUG] 응답 상태코드: ${response.statusCode}');
      print('📄 [DEBUG] 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ [DEBUG] 파싱된 응답: $responseData');
        
        if (responseData['success'] == true) {
          print('🎉 [DEBUG] 게시글 작성 성공!');
          return responseData;
        } else {
          print('❌ [DEBUG] API 오류: ${responseData['error']}');
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        print('🚨 [DEBUG] HTTP 오류 - 상태코드: ${response.statusCode}, 응답: ${response.body}');
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('💥 [DEBUG] 예외 발생: $e');
      print('📍 [DEBUG] 스택 트레이스: ${StackTrace.current}');
      throw Exception('게시글 작성 오류: $e');
    }
  }

  // v2_board 데이터 수정
  static Future<Map<String, dynamic>> updateBoardByMemberData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_board');
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_board',
        'data': data,
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('게시글 수정 오류: $e');
    }
  }

  // v2_board 데이터 삭제
  static Future<Map<String, dynamic>> deleteBoardByMemberData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_board');
      
      final requestData = {
        'operation': 'delete',
        'table': 'v2_board',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('게시글 삭제 오류: $e');
    }
  }

  // v2_board_comment 데이터 조회 (댓글 목록)
  static Future<List<Map<String, dynamic>>> getBoardRepliesData({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final filteredWhere = _addBranchFilter(where ?? [], 'v2_board_comment');
      
      final requestData = {
        'operation': 'get',
        'table': 'v2_board_comment',
        'where': filteredWhere,
        if (orderBy != null) 'orderBy': orderBy,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      };
      
      print('🔍 [DEBUG] getBoardRepliesData 요청:');
      print('📋 Request: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('📡 [DEBUG] 댓글 조회 응답: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data'] ?? []);
          print('📊 [DEBUG] 조회된 댓글 개수: ${data.length}');
          return data;
        } else {
          print('❌ [DEBUG] 댓글 조회 API 오류: ${responseData['error']}');
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        print('🚨 [DEBUG] 댓글 조회 HTTP 오류: ${response.statusCode} - ${response.body}');
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('💥 [DEBUG] 댓글 조회 예외: $e');
      throw Exception('댓글 데이터 조회 오류: $e');
    }
  }

  // v2_board_comment 데이터 추가 (새 댓글 작성)
  static Future<Map<String, dynamic>> addBoardReplyData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      print('🔍 [DEBUG] addBoardReplyData 시작');
      print('📥 [DEBUG] 댓글 입력 데이터: $data');
      
      // 현재 branch_id 추가
      if (_currentBranchId != null) {
        data['branch_id'] = _currentBranchId;
        print('✅ [DEBUG] 댓글에 branch_id 추가됨: $_currentBranchId');
      } else {
        print('⚠️  [DEBUG] 댓글 작성 시 branch_id가 null입니다!');
      }
      
      final requestData = {
        'operation': 'add',
        'table': 'v2_board_comment',
        'data': data,
      };
      
      print('📋 [DEBUG] 댓글 작성 요청: ${json.encode(requestData)}');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('📡 [DEBUG] 댓글 작성 응답: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('🎉 [DEBUG] 댓글 작성 성공!');
          return responseData;
        } else {
          print('❌ [DEBUG] 댓글 작성 API 오류: ${responseData['error']}');
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        print('🚨 [DEBUG] 댓글 작성 HTTP 오류: ${response.statusCode} - ${response.body}');
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('💥 [DEBUG] 댓글 작성 예외: $e');
      throw Exception('댓글 작성 오류: $e');
    }
  }

  // v2_board_comment 데이터 삭제
  static Future<Map<String, dynamic>> deleteBoardReplyData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_board_comment');
      
      final requestData = {
        'operation': 'delete',
        'table': 'v2_board_comment',
        'where': filteredWhere,
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('댓글 삭제 오류: $e');
    }
  }

  // 월별 레슨 사용 데이터 조회 (v2_LS_orders)
  static Future<Map<String, dynamic>> getMonthlyLessonUsageReport({
    required int year,
    required int month,
  }) async {
    try {
      // 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);

      // 날짜 포맷팅 (YYYY-MM-DD)
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final requestData = {
        'operation': 'get',
        'table': 'v2_LS_orders',
        'fields': ['LS_net_min', 'LS_date', 'LS_status', 'pro_name'],
      };

      // WHERE 조건: branch_id 필터 + 해당 월 (LS_status는 클라이언트에서 필터링)
      final where = [
        {
          'field': 'LS_date',
          'operator': '>=',
          'value': startDate,
        },
        {
          'field': 'LS_date',
          'operator': '<=',
          'value': endDate,
        },
      ];

      final filteredWhere = _addBranchFilter(where, 'v2_LS_orders');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('=== v2_LS_orders 쿼리 요청 ===');
      print('년: $year, 월: $month');
      print('날짜 범위: $startDate ~ $endDate');
      print('요청 데이터: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> rawData = responseData['data'];

        int totalUsageMin = 0;
        int validRecordCount = 0; // 실제 집계에 포함된 건수
        Map<String, int> proUsageMap = {}; // 프로별 사용 시간

        print('=== 서버 응답 데이터 확인 ===');
        print('전체 응답 건수: ${rawData.length}건');

        for (var record in rawData) {
          // 클라이언트 사이드 필터링: '예약완료'만 포함
          final lsStatus = record['LS_status']?.toString() ?? '';

          if (lsStatus != '예약완료') {
            continue; // 예약완료가 아닌 것 제외
          }

          // 유효한 레코드 카운트 증가
          validRecordCount++;

          if (record['LS_net_min'] != null && record['LS_net_min'] != '') {
            final netMin = int.tryParse(record['LS_net_min'].toString()) ?? 0;
            totalUsageMin += netMin;

            // 프로별 집계
            final proName = record['pro_name']?.toString() ?? '미지정';
            proUsageMap[proName] = (proUsageMap[proName] ?? 0) + netMin;
          }
        }

        print('=== 월별 레슨 사용 데이터 조회 완료 ===');
        print('년: $year, 월: $month');
        print('필터링 후 레슨 건수: ${validRecordCount}건');
        print('총 사용 시간: ${totalUsageMin}분');
        print('프로별 사용 시간: ${proUsageMap}');
        print('=============================');

        return {
          'year': year,
          'month': month,
          'totalLessonUsage': totalUsageMin,
          'recordCount': validRecordCount,
          'proUsageBreakdown': proUsageMap,
        };
      } else {
        print('월별 레슨 사용 데이터 조회 실패: ${responseData['message'] ?? 'Unknown error'}');
        return {
          'year': year,
          'month': month,
          'totalLessonUsage': 0,
          'recordCount': 0,
          'proUsageBreakdown': {},
        };
      }
    } catch (e) {
      print('월별 레슨 사용 데이터 조회 오류: $e');
      return {
        'year': year,
        'month': month,
        'totalLessonUsage': 0,
        'recordCount': 0,
        'proUsageBreakdown': {},
      };
    }
  }

  // 월별 레슨권 판매 프로별 집계 조회
  static Future<Map<String, dynamic>> getMonthlyLessonSalesProBreakdown({
    required int year,
    required int month,
  }) async {
    try {
      // 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);

      // 날짜 포맷팅 (YYYY-MM-DD)
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final requestData = {
        'operation': 'get',
        'table': 'v3_contract_history',
        'fields': ['contract_LS_min', 'contract_date', 'contract_history_status', 'payment_type', 'contract_type', 'pro_name'],
      };

      // WHERE 조건: branch_id 필터 + 해당 월
      final where = [
        {
          'field': 'contract_date',
          'operator': '>=',
          'value': startDate,
        },
        {
          'field': 'contract_date',
          'operator': '<=',
          'value': endDate,
        },
      ];

      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      print('=== v3_contract_history 레슨권 판매 프로별 집계 요청 ===');
      print('년: $year, 월: $month');
      print('날짜 범위: $startDate ~ $endDate');
      print('요청 데이터: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> rawData = responseData['data'];

        Map<String, int> proSalesMap = {}; // 프로별 판매 시간
        int validRecordCount = 0;

        print('=== 서버 응답 데이터 확인 ===');
        print('전체 응답 건수: ${rawData.length}건');

        for (var record in rawData) {
          // 클라이언트 사이드 필터링: 정상 계약만 포함
          final status = record['contract_history_status']?.toString() ?? '';
          final paymentType = record['payment_type']?.toString() ?? '';
          final contractType = record['contract_type']?.toString() ?? '';

          if (status == '삭제' || paymentType == '데이터 이전' || paymentType == '크레딧결제') {
            continue; // 삭제된 것이나 크레딧결제는 제외
          }

          // contract_LS_min이 있는 경우만 집계
          if (record['contract_LS_min'] != null && record['contract_LS_min'] != '') {
            final lsMin = int.tryParse(record['contract_LS_min'].toString()) ?? 0;

            if (lsMin > 0) {
              validRecordCount++;

              // 프로별 집계
              final proName = record['pro_name']?.toString() ?? '미지정';
              proSalesMap[proName] = (proSalesMap[proName] ?? 0) + lsMin;
            }
          }
        }

        print('=== 월별 레슨권 판매 프로별 집계 완료 ===');
        print('년: $year, 월: $month');
        print('필터링 후 레슨권 판매 건수: ${validRecordCount}건');
        print('프로별 판매 시간: ${proSalesMap}');
        print('=============================');

        return {
          'year': year,
          'month': month,
          'proSalesBreakdown': proSalesMap,
          'recordCount': validRecordCount,
        };
      } else {
        print('월별 레슨권 판매 프로별 집계 실패: ${responseData['message'] ?? 'Unknown error'}');
        return {
          'year': year,
          'month': month,
          'proSalesBreakdown': {},
          'recordCount': 0,
        };
      }
    } catch (e) {
      print('월별 레슨권 판매 프로별 집계 오류: $e');
      return {
        'year': year,
        'month': month,
        'proSalesBreakdown': {},
        'recordCount': 0,
      };
    }
  }

  // 월별 계약 타입별 매출 집계 조회
  static Future<Map<String, dynamic>> getMonthlyContractTypeBreakdown({
    required int year,
    required int month,
  }) async {
    try {
      // 월의 첫날과 마지막날 계산
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);

      // 날짜 포맷팅 (YYYY-MM-DD)
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final requestData = {
        'operation': 'get',
        'table': 'v3_contract_history',
        'fields': ['price', 'contract_date', 'contract_history_status', 'payment_type', 'contract_type'],
      };

      // WHERE 조건: branch_id 필터 + 해당 월
      final where = [
        {
          'field': 'contract_date',
          'operator': '>=',
          'value': startDate,
        },
        {
          'field': 'contract_date',
          'operator': '<=',
          'value': endDate,
        },
      ];

      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');
      if (filteredWhere.isNotEmpty) {
        requestData['where'] = filteredWhere;
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      final responseData = json.decode(response.body);

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> rawData = responseData['data'];

        Map<String, double> contractTypeMap = {}; // 계약 타입별 매출

        for (var record in rawData) {
          // 클라이언트 사이드 필터링: 정상 계약만 포함
          final status = record['contract_history_status']?.toString() ?? '';
          final paymentType = record['payment_type']?.toString() ?? '';
          final contractType = record['contract_type']?.toString() ?? '';

          if (status == '삭제' || paymentType == '데이터 이전' || paymentType == '크레딧결제') {
            continue; // 삭제된 것이나 크레딧결제는 제외
          }

          // price가 있는 경우만 집계
          if (record['price'] != null && record['price'] != '') {
            final price = double.tryParse(record['price'].toString()) ?? 0;

            if (price > 0) {
              // 계약 타입별 집계
              final typeKey = contractType.isEmpty ? '기타' : contractType;
              contractTypeMap[typeKey] = (contractTypeMap[typeKey] ?? 0) + price;
            }
          }
        }

        return {
          'year': year,
          'month': month,
          'contractTypeBreakdown': contractTypeMap,
        };
      } else {
        return {
          'year': year,
          'month': month,
          'contractTypeBreakdown': {},
        };
      }
    } catch (e) {
      print('월별 계약 타입별 매출 집계 오류: $e');
      return {
        'year': year,
        'month': month,
        'contractTypeBreakdown': {},
      };
    }
  }
}
