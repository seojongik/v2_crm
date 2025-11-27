import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../constants/font_sizes.dart';
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

  // 현재 지점 ID 설정
  static void setCurrentBranch(String branchId, Map<String, dynamic> branchData) {
    _currentBranchId = branchId;
    _currentBranch = branchData;
  }

  // 현재 사용자 설정
  static void setCurrentUser(Map<String, dynamic> userData) {
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
    bool? isJuniorFilter, // 주니어 필터링 여부
    bool? isRecentFilter, // 최근 등록 필터링 여부
  }) async {
    try {
      Map<String, dynamic> requestData = {
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
      } else if (isJuniorFilter == true) {
        // 주니어 필터
        List<int> juniorFamilyMemberIds = await getJuniorFamilyMemberIds();
        filteredMemberIds = juniorFamilyMemberIds;
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
      if (filteredMemberIds != null) {
        requestData['where'] = [
          {
            'field': 'member_id',
            'operator': 'IN',
            'value': filteredMemberIds
          }
        ];
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
              'member_register'
            ],
            'where': [
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
            ],
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
              'member_register'
            ],
            'where': [
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
            ],
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
          requestData['where'] = [
            {
              'field': 'member_name',
              'operator': 'LIKE',
              'value': '%$searchQuery%'
            }
          ];
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
                'where': [
                  {
                    'field': 'member_phone',
                    'operator': 'LIKE',
                    'value': '%$searchQuery%'
                  }
                ],
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
      
      print('타석 API 요청 데이터: ${json.encode(requestData)}'); // 디버그 로그
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      print('타석 API 응답 상태: ${response.statusCode}'); // 디버그 로그
      print('타석 API 응답 본문: ${response.body}'); // 디버그 로그
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = List<Map<String, dynamic>>.from(responseData['data']);
          print('타석 데이터 파싱 완료: ${data.length}건'); // 디버그 로그
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

  // TS 정보 조회 (v2_ts_info 테이블)
  static Future<List<Map<String, dynamic>>> getTsInfoData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_ts_info',
        'fields': fields ?? ['*'],
      };
      
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_ts_info');
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
  static Future<Map<int, int>> getMemberCredits(List<int> memberIds) async {
    try {
      if (memberIds.isEmpty) return {};
      
      // 모든 회원의 크레딧 정보를 한 번에 조회
      final requestData = {
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['member_id', 'bill_balance_after', 'bill_id'],
        'orderBy': [
          {
            'field': 'member_id',
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
          
          // 각 회원별로 가장 최신 잔액만 추출
          Map<int, int> credits = {};
          for (var bill in billsData) {
            int memberId = bill['member_id'];
            int balance = bill['bill_balance_after'] ?? 0;
            
            // 이미 해당 회원의 크레딧이 없거나, 더 큰 bill_id를 가진 경우에만 업데이트
            if (!credits.containsKey(memberId)) {
              credits[memberId] = balance;
            }
          }
          
          // 요청된 회원 중 크레딧 정보가 없는 회원은 0으로 설정
          for (int memberId in memberIds) {
            if (!credits.containsKey(memberId)) {
              credits[memberId] = 0;
            }
          }
          
          return credits;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('크레딧 조회 오류: $e');
      // 오류 시 모든 회원을 0으로 설정
      Map<int, int> fallbackCredits = {};
      for (int memberId in memberIds) {
        fallbackCredits[memberId] = 0;
      }
      return fallbackCredits;
    }
  }

  // 회원별 레슨권 조회 (v3_LS_countings 테이블에서 LS_type, LS_contract_pro별 최신 잔여 레슨권)
  static Future<Map<int, List<Map<String, dynamic>>>> getMemberLessonTickets(List<int> memberIds) async {
    try {
      if (memberIds.isEmpty) return {};
      
      // 모든 회원의 레슨권 정보를 한 번에 조회
      final requestData = {
        'operation': 'get',
        'table': 'v3_LS_countings',
        'fields': ['member_id', 'LS_type', 'LS_contract_pro', 'LS_balance_min_after', 'LS_counting_id'],
        'orderBy': [
          {
            'field': 'member_id',
            'direction': 'ASC',
          },
          {
            'field': 'LS_type',
            'direction': 'ASC',
          },
          {
            'field': 'LS_contract_pro',
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
          
          // 각 회원별로 LS_type, LS_contract_pro 조합별 최신 잔여 레슨권만 추출
          Map<int, Map<String, Map<String, dynamic>>> tempResult = {};
          
          for (var lesson in lessonData) {
            int memberId = lesson['member_id'];
            String lsType = lesson['LS_type'] ?? '';
            String lsContractPro = lesson['LS_contract_pro'] ?? '';
            int balance = lesson['LS_balance_min_after'] ?? 0;
            
            String combinationKey = '${lsType}_${lsContractPro}';
            
            if (!tempResult.containsKey(memberId)) {
              tempResult[memberId] = {};
            }
            
            // 이미 해당 조합의 레슨권이 없는 경우에만 추가 (가장 큰 LS_counting_id가 먼저 오므로)
            if (!tempResult[memberId]!.containsKey(combinationKey)) {
              tempResult[memberId]![combinationKey] = {
                'LS_type': lsType,
                'LS_contract_pro': lsContractPro,
                'balance': balance,
              };
            }
          }
          
          // 최종 결과 변환
          Map<int, List<Map<String, dynamic>>> result = {};
          for (int memberId in memberIds) {
            if (tempResult.containsKey(memberId)) {
              result[memberId] = tempResult[memberId]!.values.toList();
            } else {
              result[memberId] = [];
            }
          }
          
          return result;
        } else {
          throw Exception('API 오류: ${responseData['error']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('레슨권 조회 오류: $e');
      // 오류 시 모든 회원을 빈 리스트로 설정
      Map<int, List<Map<String, dynamic>>> fallbackTickets = {};
      for (int memberId in memberIds) {
        fallbackTickets[memberId] = [];
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
      final requestData = {
        'operation': 'get',
        'table': 'v2_junior_relation',
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

  // 주니어 관계가 있는 가족 회원 ID 목록 조회
  static Future<List<int>> getJuniorFamilyMemberIds() async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_junior_relation',
        'fields': ['junior_member_id', 'member_id'],
      };
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final relations = List<Map<String, dynamic>>.from(responseData['data']);
          
          // 주니어 회원 ID와 부모 회원 ID를 모두 수집
          Set<int> familyMemberIds = {};
          
          for (var relation in relations) {
            int? juniorMemberId = relation['junior_member_id'];
            int? parentMemberId = relation['member_id'];
            
            if (juniorMemberId != null) {
              familyMemberIds.add(juniorMemberId);
            }
            if (parentMemberId != null) {
              familyMemberIds.add(parentMemberId);
            }
          }
          
          return familyMemberIds.toList();
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

  // 최근 등록된 회원 ID 조회 (최근 10명)
  static Future<List<int>> getRecentMemberIds() async {
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
      
      final response = await http.post(
        Uri.parse(baseUrl),
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
  static Future<bool> updateMember(int memberId, Map<String, dynamic> updateData) async {
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(updateData, 'v3_members');
      
      final requestData = {
        'operation': 'update',
        'table': 'v3_members',
        'data': dataWithBranch,
        'where': [
          {
            'field': 'member_id',
            'operator': '=',
            'value': memberId,
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
    try {
      // branch_id 자동 추가
      final dataWithBranch = _addBranchToData(data, 'v2_bills');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'add',
          'table': 'v2_bills',
          'data': dataWithBranch,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception(responseData['error'] ?? '데이터 추가 실패');
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
      // branch_id 필터링 자동 적용
      final filteredWhere = _addBranchFilter(where, 'v2_contracts');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode({
          'operation': 'get',
          'table': 'v2_contracts',
          'fields': fields,
          'where': filteredWhere.isNotEmpty ? filteredWhere : null,
          'orderBy': orderBy,
          'limit': limit,
          'offset': offset,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        } else {
          throw Exception(responseData['error'] ?? '데이터 조회 실패');
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
      throw Exception('상품 목록 조회 중 오류가 발생했습니다: $e');
    }
  }

  // v2_priced_TS 데이터 조회 (타석이용 내역)
  static Future<List<Map<String, dynamic>>> getPricedTsData({
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

  // v2_discount_coupon 데이터 추가 (할인권 증정)
  static Future<Map<String, dynamic>> addDiscountCoupon(Map<String, dynamic> data) async {
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

  // v2_staff_pro 데이터 조회 (재직중인 프로 목록)
  static Future<List<Map<String, dynamic>>> getActiveStaffPros() async {
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

  // v2_member_pro_match 데이터 조회 (프로별 연결된 유효한 회원 목록)
  static Future<List<int>> getMemberIdsByProId(int proId) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'v2_member_pro_match',
        'fields': ['member_id'],
        'where': [
          {
            'field': 'pro_id',
            'operator': '=',
            'value': proId
          },
          {
            'field': 'relation_status',
            'operator': '=',
            'value': '유효'
          }
        ]
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
          return data.map((item) => item['member_id'] as int).toList();
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

  // 활성 기간권 회원 조회 (만료되지 않은 회원만)
  static Future<List<Map<String, dynamic>>> getActiveTermMembers() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
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
        }),
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
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
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
        }),
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
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
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
        }),
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

  // Staff 로그인 인증
  static Future<Map<String, dynamic>?> authenticateStaff({
    required String staffAccessId,
    required String staffPassword,
  }) async {
    try {
      final requestData = {
        'operation': 'get',
        'table': 'Staff',
        'where': [
          {
            'field': 'staff_access_id',
            'operator': '=',
            'value': staffAccessId,
          },
          {
            'field': 'staff_password',
            'operator': '=',
            'value': staffPassword,
          },
          {
            'field': 'staff_status',
            'operator': '=',
            'value': '재직',
          },
        ],
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'].isNotEmpty) {
          return responseData['data'][0];
        } else {
          return null; // 로그인 실패
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

  // 계약 데이터 조회 (v2_contracts)
  static Future<List<Map<String, dynamic>>> getContractsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      // branch_id 필터 자동 추가
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

  // 계약 이력 추가 (v3_contract_history)
  static Future<Map<String, dynamic>> addContractHistoryData(Map<String, dynamic> data) async {
    try {
      final dataWithBranch = _addBranchToData(data, 'v3_contract_history');
      
      final requestData = {
        'operation': 'add',
        'table': 'v3_contract_history',
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

  // 프로-회원 매칭 조회 (v2_member_pro_match)
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
      throw Exception('프로-회원 매칭 조회 오류: $e');
    }
  }

  // 프로-회원 매칭 추가 (v2_member_pro_match)
  static Future<Map<String, dynamic>> addMemberProMatchData(Map<String, dynamic> data) async {
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
      throw Exception('프로-회원 매칭 추가 오류: $e');
    }
  }

  // 프로-회원 매칭 업데이트 (v2_member_pro_match)
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
      throw Exception('프로-회원 매칭 업데이트 오류: $e');
    }
  }

  // 스태프 프로 조회 (v2_staff_pro)
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
        Uri.parse('$baseUrl/dynamic_api.php'),
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
} 