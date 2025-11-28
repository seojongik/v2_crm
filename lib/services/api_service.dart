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
import 'supabase_adapter.dart';

class ApiService {
  // 서버 루트의 dynamic_api.php (레거시 - 사용 안 함)
  // static const String baseUrl = 'https://autofms.mycafe24.com/dynamic_api.php';
  static const String baseUrl = ''; // Supabase 전용

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
  
  // 범용 데이터 조회 메서드 (Supabase 전용) - 외부 호출용 (기존 PHP API 형식 호환)
  static Future<Map<String, dynamic>> getData({
    required String table,
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final result = await _getDataRaw(
        table: table,
        fields: fields,
        where: where,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      // 기존 PHP API 응답 형식과 동일하게 반환
      return {'success': true, 'data': result};
    } catch (e) {
      print('❌ [ApiService] getData() 오류: $e');
      return {'success': false, 'data': [], 'error': e.toString()};
    }
  }

  // 범용 데이터 조회 메서드 (Supabase 전용) - List 직접 반환 (변환된 코드용)
  static Future<List<Map<String, dynamic>>> getDataList({
    required String table,
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return _getDataRaw(
      table: table,
      fields: fields,
      where: where,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  // 범용 데이터 조회 메서드 (Supabase 전용) - 내부 호출용 (List 직접 반환)
  static Future<List<Map<String, dynamic>>> _getDataRaw({
    required String table,
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    // API 호출 전 처리
    _beforeApiCall();

    print('📡 [ApiService] _getDataRaw() 호출: $table 테이블');
    final apiStartTime = DateTime.now();
    
    // branch_id 필터링 자동 적용
    final filteredWhere = _addBranchFilter(where, table);
    
    final result = await SupabaseAdapter.getData(
      table: table,
      fields: fields,
      where: filteredWhere.isNotEmpty ? filteredWhere : null,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    
    final apiEndTime = DateTime.now();
    final apiDuration = apiEndTime.difference(apiStartTime);
    print('✅ [ApiService] _getDataRaw() 성공: $table - ${result.length}개 (소요시간: ${apiDuration.inMilliseconds}ms)');
    return result;
  }

  // 범용 데이터 수정 메서드 (Supabase 전용)
  static Future<Map<String, dynamic>> updateData({
    required String table,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> where,
  }) async {
    // API 호출 전 처리
    _beforeApiCall();

    // branch_id 자동 추가 (데이터에)
    final finalData = _addBranchToData(data, table);
    final filteredWhere = _addBranchFilter(where, table);

    try {
      final result = await SupabaseAdapter.updateData(
        table: table,
        data: finalData,
        where: filteredWhere,
      );
      print('✅ [ApiService] updateData() 성공: $table');
      return result;
    } catch (e) {
      print('❌ [ApiService] updateData() 오류: $e');
      throw Exception('데이터 수정 오류: $e');
    }
  }

  // 범용 데이터 추가 메서드 (Supabase 전용)
  static Future<Map<String, dynamic>> addData({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    // API 호출 전 처리
    _beforeApiCall();

    // branch_id 자동 추가
    final finalData = _addBranchToData(data, table);

    try {
      final result = await SupabaseAdapter.addData(
        table: table,
        data: finalData,
      );
      print('✅ [ApiService] addData() 성공: $table');
      return result;
    } catch (e) {
      print('❌ [ApiService] addData() 오류: $e');
      throw Exception('데이터 추가 오류: $e');
    }
  }
  
  // v2_LS_orders 데이터 조회 (레슨 이용내역) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getLSData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(
      table: 'v2_LS_orders',
      fields: fields,
      where: where,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  // Board 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBoardData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(
      table: 'Board',
      fields: fields,
      where: where,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  // Staff 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getStaffData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    // Staff 테이블은 branch_id 필터링 제외
    return await SupabaseAdapter.getData(
      table: 'Staff',
      fields: fields,
      where: where,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  // Member 데이터 조회 (v3_members 테이블) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getMemberData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(
      table: 'v3_members',
      fields: fields,
      where: where,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  // Member 데이터 조회 (v3_members 테이블) - 회원관리 페이지용 간소화된 함수 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getMembers({
    String? searchQuery,
    List<String>? selectedTags,
    List<int>? selectedProIds,
    bool? isTermFilter,
    bool? isBattingFilter,
    bool? isRecentFilter,
    bool? isExpiredFilter,
    bool? isLessonFilter,
  }) async {
    try {
      final fields = [
        'member_id', 'member_no_branch', 'member_name', 'member_phone',
        'member_type', 'member_chn_keyword', 'member_register',
        'member_nickname', 'member_gender', 'chat_bookmark'
      ];
      final orderBy = [{'field': 'member_id', 'direction': 'DESC'}];

      // 필터링된 회원 ID 목록
      List<int>? filteredMemberIds;

      if (isRecentFilter == true) {
        filteredMemberIds = await getRecentMemberIds();
      } else if (isBattingFilter == true) {
        filteredMemberIds = await getBattingMemberIds();
      } else if (isExpiredFilter == true) {
        filteredMemberIds = await getExpiredMemberIds();
      } else if (isLessonFilter == true) {
        filteredMemberIds = await getValidLessonMemberIds();
      } else if (isTermFilter == true) {
        filteredMemberIds = await getAllTermMemberIds();
      } else if (selectedProIds != null && selectedProIds.isNotEmpty) {
        Set<int> allConnectedMemberIds = {};
        for (int proId in selectedProIds) {
          List<int> connectedMemberIds = await getMemberIdsByProId(proId);
          allConnectedMemberIds.addAll(connectedMemberIds);
        }
        filteredMemberIds = allConnectedMemberIds.toList();
      }

      if (filteredMemberIds != null && filteredMemberIds.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> whereConditions = [];
      if (filteredMemberIds != null) {
        whereConditions.add({'field': 'member_id', 'operator': 'IN', 'value': filteredMemberIds});
      }

      // 검색어 처리
      if (searchQuery != null && searchQuery.isNotEmpty) {
        if (filteredMemberIds != null) {
          // 이름으로 검색
          final nameResults = await _getDataRaw(
            table: 'v3_members',
            fields: fields,
            where: [...whereConditions, {'field': 'member_name', 'operator': 'LIKE', 'value': '%$searchQuery%'}],
            orderBy: orderBy,
          );
          
          // 전화번호로 검색
          final phoneResults = await _getDataRaw(
            table: 'v3_members',
            fields: fields,
            where: [...whereConditions, {'field': 'member_phone', 'operator': 'LIKE', 'value': '%$searchQuery%'}],
            orderBy: orderBy,
          );
          
          // 결과 합치기 (중복 제거)
          Set<String> existingIds = nameResults.map((item) => item['member_id'].toString()).toSet();
          for (var phoneResult in phoneResults) {
            if (!existingIds.contains(phoneResult['member_id'].toString())) {
              nameResults.add(phoneResult);
            }
          }
          return nameResults;
        } else {
          // 이름으로 검색
          final nameResults = await _getDataRaw(
            table: 'v3_members',
            fields: fields,
            where: [{'field': 'member_name', 'operator': 'LIKE', 'value': '%$searchQuery%'}],
            orderBy: orderBy,
          );
          
          // 전화번호로 검색
          final phoneResults = await _getDataRaw(
            table: 'v3_members',
            fields: fields,
            where: [{'field': 'member_phone', 'operator': 'LIKE', 'value': '%$searchQuery%'}],
            orderBy: orderBy,
          );
          
          Set<String> existingIds = nameResults.map((item) => item['member_id'].toString()).toSet();
          for (var phoneResult in phoneResults) {
            if (!existingIds.contains(phoneResult['member_id'].toString())) {
              nameResults.add(phoneResult);
            }
          }
          return nameResults;
        }
      }

      return await _getDataRaw(
        table: 'v3_members',
        fields: fields,
        where: whereConditions.isNotEmpty ? whereConditions : null,
        orderBy: orderBy,
      );
    } catch (e) {
      throw Exception('회원 조회 오류: $e');
    }
  }
  
  // Comment 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getCommentData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'Comment', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }
  
  // Board 데이터 추가 - Supabase 전용
  static Future<Map<String, dynamic>> addBoardData(Map<String, dynamic> data) async {
    _beforeApiCall();
    return await addData(table: 'Board', data: data);
  }
  
  // Board 데이터 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateBoardData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    return await updateData(table: 'Board', data: data, where: where);
  }

  // Board 데이터 삭제 - Supabase 전용
  static Future<Map<String, dynamic>> deleteBoardData(List<Map<String, dynamic>> where) async {
    return await deleteData(table: 'Board', where: where);
  }
  
  // Comment 데이터 추가 - Supabase 전용
  static Future<void> addCommentData(Map<String, dynamic> data) async {
    _beforeApiCall();
    await addData(table: 'Comment', data: data);
  }

  // Comment 데이터 삭제 - Supabase 전용
  static Future<Map<String, dynamic>> deleteCommentData(List<Map<String, dynamic>> where) async {
    return await deleteData(table: 'Comment', where: where);
  }

  // v2_priced_TS 데이터 조회 (타석관리용) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_priced_TS', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_priced_TS 데이터 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateTsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    return await updateData(table: 'v2_priced_TS', data: data, where: where);
  }

  // v2_priced_TS 데이터 추가 - Supabase 전용
  static Future<Map<String, dynamic>> addTsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    return await addData(table: 'v2_priced_TS', data: data);
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

  // v2_bill_times 데이터 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateBillTimesData(Map<String, dynamic> data, List<Map<String, dynamic>> where) async {
    return await updateData(table: 'v2_bill_times', data: data, where: where);
  }

  // v2_bill_games 데이터 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateBillGamesData(Map<String, dynamic> data, List<Map<String, dynamic>> where) async {
    return await updateData(table: 'v2_bill_games', data: data, where: where);
  }

  // v2_bills 데이터 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateBillsData(Map<String, dynamic> data, List<Map<String, dynamic>> where) async {
    return await updateData(table: 'v2_bills', data: data, where: where);
  }

  // v2_discount_coupon 데이터 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateDiscountCouponsData(Map<String, dynamic> data, List<Map<String, dynamic>> where) async {
    return await updateData(table: 'v2_discount_coupon', data: data, where: where);
  }

  // TS 정보 조회 (v2_ts_info 테이블) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getTsInfoData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, String>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    final convertedOrderBy = orderBy?.map((o) => <String, dynamic>{...o}).toList();
    return await _getDataRaw(table: 'v2_ts_info', fields: fields, where: where, orderBy: convertedOrderBy, limit: limit, offset: offset);
  }

  // 타석 정보 추가 - Supabase 전용
  static Future<Map<String, dynamic>> addTsInfoData(Map<String, dynamic> tsData) async {
    _beforeApiCall();
    return await addData(table: 'v2_ts_info', data: tsData);
  }

  // 타석 정보 수정 - Supabase 전용
  static Future<Map<String, dynamic>> updateTsInfoData(Map<String, dynamic> tsData, List<Map<String, dynamic>> where) async {
    return await updateData(table: 'v2_ts_info', data: tsData, where: where);
  }

  // 타석 정보 삭제 - Supabase 전용
  static Future<Map<String, dynamic>> deleteTsInfoData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    return await deleteData(table: 'v2_ts_info', where: where);
  }

  // 타석 예약 데이터 조회 (v2_priced_TS 테이블) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getPricedTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_priced_TS', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // FMS_TS 데이터 조회 (타석 예약 데이터) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getFmsTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'FMS_TS', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
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
      // Supabase 전용 - 범용 getData 사용
      List<Map<String, dynamic>> billsData = await _getDataRaw(
        table: 'v2_bills',
        fields: ['member_id', 'bill_balance_after', 'bill_id', 'contract_history_id', 'contract_credit_expiry_date'],
        where: filteredWhere,
        orderBy: [
          {'field': 'member_id', 'direction': 'ASC'},
          {'field': 'contract_history_id', 'direction': 'ASC'},
          {'field': 'bill_id', 'direction': 'DESC'},
        ],
      );

      // 각 회원별로 contract_history_id별 최신 정보 추출
      Map<int, Map<String, dynamic>> memberCreditsInfo = {};
      Map<int, Map<int, Map<String, dynamic>>> memberContractData = {};

      DateTime now = DateTime.now();

      for (var bill in billsData) {
        int memberId = bill['member_id'];
        int contractHistoryId = bill['contract_history_id'] ?? 0;
        int balance = bill['bill_balance_after'] ?? 0;
        String? expiryDateStr = bill['contract_credit_expiry_date'];

        if (!memberContractData.containsKey(memberId)) {
          memberContractData[memberId] = {};
        }

        if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
            bill['bill_id'] > memberContractData[memberId]![contractHistoryId]!['bill_id']) {
          memberContractData[memberId]![contractHistoryId] = {
            'bill_id': bill['bill_id'],
            'balance': balance,
            'expiry_date': expiryDateStr,
          };
        }
      }

      for (var entry in memberContractData.entries) {
        int memberId = entry.key;
        Map<int, Map<String, dynamic>> contracts = entry.value;
        int totalBalance = 0;
        int validContractCount = 0;
        DateTime? nearestExpiryDate;

        for (var contractData in contracts.values) {
          int balance = contractData['balance'] ?? 0;
          String? expiryDateStr = contractData['expiry_date'];

          if (balance > 0) {
            bool isValid = true;
            if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
              try {
                DateTime expiryDate = DateTime.parse(expiryDateStr);
                if (expiryDate.isBefore(now)) {
                  isValid = false;
                } else {
                  if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                    nearestExpiryDate = expiryDate;
                  }
                }
              } catch (e) {}
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

      // Supabase 전용 - 범용 getData 사용
      List<Map<String, dynamic>> termData = await _getDataRaw(
        table: 'v2_bill_term',
        fields: ['member_id', 'bill_text', 'bill_term_id', 'contract_history_id', 'contract_term_month_expiry_date'],
        where: filteredWhere,
        orderBy: [
          {'field': 'member_id', 'direction': 'ASC'},
          {'field': 'contract_history_id', 'direction': 'ASC'},
          {'field': 'bill_term_id', 'direction': 'DESC'},
        ],
      );

      Map<int, Map<String, dynamic>> memberTermInfo = {};
      Map<int, Map<int, Map<String, dynamic>>> memberContractData = {};
      DateTime now = DateTime.now();

      for (var termRecord in termData) {
        int memberId = termRecord['member_id'];
        int contractHistoryId = termRecord['contract_history_id'] ?? 0;
        String billText = termRecord['bill_text'] ?? '';
        String? expiryDateStr = termRecord['contract_term_month_expiry_date'];

        if (!memberContractData.containsKey(memberId)) {
          memberContractData[memberId] = {};
        }

        if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
            termRecord['bill_term_id'] > memberContractData[memberId]![contractHistoryId]!['bill_term_id']) {
          memberContractData[memberId]![contractHistoryId] = {
            'bill_term_id': termRecord['bill_term_id'],
            'bill_text': billText,
            'expiry_date': expiryDateStr,
          };
        }
      }

      for (var entry in memberContractData.entries) {
        int memberId = entry.key;
        Map<int, Map<String, dynamic>> contracts = entry.value;
        int validContractCount = 0;
        DateTime? nearestExpiryDate;
        List<Map<String, dynamic>> validTermTypes = [];

        for (var contractData in contracts.values) {
          String? expiryDateStr = contractData['expiry_date'];
          String billText = contractData['bill_text'] ?? '';
          bool isValid = true;
          int remainingDays = 0;

          if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
            try {
              DateTime expiryDate = DateTime.parse(expiryDateStr);
              DateTime nowDate = DateTime(now.year, now.month, now.day);
              DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              remainingDays = expiryDateOnly.difference(nowDate).inDays;

              if (remainingDays < 0) {
                isValid = false;
              } else {
                if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                  nearestExpiryDate = expiryDate;
                }
              }
            } catch (e) {
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

      // Supabase 전용 - 범용 getData 사용
      List<Map<String, dynamic>> timeData = await _getDataRaw(
        table: 'v2_bill_times',
        fields: ['member_id', 'bill_balance_min_after', 'bill_min_id', 'contract_history_id', 'contract_TS_min_expiry_date'],
        where: filteredWhere,
        orderBy: [
          {'field': 'member_id', 'direction': 'ASC'},
          {'field': 'contract_history_id', 'direction': 'ASC'},
          {'field': 'bill_min_id', 'direction': 'DESC'},
        ],
      );

      Map<int, Map<String, dynamic>> memberTimeInfo = {};
      Map<int, Map<int, Map<String, dynamic>>> memberContractData = {};
      DateTime now = DateTime.now();

      for (var timeRecord in timeData) {
        int memberId = timeRecord['member_id'];
        int contractHistoryId = timeRecord['contract_history_id'] ?? 0;
        int balance = timeRecord['bill_balance_min_after'] ?? 0;
        String? expiryDateStr = timeRecord['contract_TS_min_expiry_date'];

        if (!memberContractData.containsKey(memberId)) {
          memberContractData[memberId] = {};
        }

        if (!memberContractData[memberId]!.containsKey(contractHistoryId) ||
            timeRecord['bill_min_id'] > memberContractData[memberId]![contractHistoryId]!['bill_min_id']) {
          memberContractData[memberId]![contractHistoryId] = {
            'bill_min_id': timeRecord['bill_min_id'],
            'balance': balance,
            'expiry_date': expiryDateStr,
          };
        }
      }

      for (var entry in memberContractData.entries) {
        int memberId = entry.key;
        Map<int, Map<String, dynamic>> contracts = entry.value;
        int totalBalance = 0;
        int validContractCount = 0;
        DateTime? nearestExpiryDate;

        for (var contractData in contracts.values) {
          int balance = contractData['balance'] ?? 0;
          String? expiryDateStr = contractData['expiry_date'];

          if (balance > 0) {
            bool isValid = true;
            if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
              try {
                DateTime expiryDate = DateTime.parse(expiryDateStr);
                if (expiryDate.isBefore(now)) {
                  isValid = false;
                } else {
                  if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                    nearestExpiryDate = expiryDate;
                  }
                }
              } catch (e) {}
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

      // Supabase 전용 - 범용 getData 사용
      List<Map<String, dynamic>> lessonData = await _getDataRaw(
        table: 'v3_LS_countings',
        fields: ['member_id', 'LS_type', 'pro_name', 'LS_balance_min_after', 'LS_counting_id', 'contract_history_id', 'LS_expiry_date'],
        where: filteredWhere,
        orderBy: [
          {'field': 'member_id', 'direction': 'ASC'},
          {'field': 'contract_history_id', 'direction': 'ASC'},
          {'field': 'LS_counting_id', 'direction': 'DESC'},
        ],
      );

      Map<int, Map<String, dynamic>> memberLessonInfo = {};
      Map<int, Map<int, Map<String, dynamic>>> memberContractData = {};
      DateTime now = DateTime.now();

      for (var lesson in lessonData) {
        int memberId = lesson['member_id'];
        int contractHistoryId = lesson['contract_history_id'] ?? 0;
        String lsType = lesson['LS_type'] ?? '';
        String lsContractPro = lesson['pro_name'] ?? '';
        int balance = lesson['LS_balance_min_after'] ?? 0;
        String? expiryDateStr = lesson['LS_expiry_date'];

        if (!memberContractData.containsKey(memberId)) {
          memberContractData[memberId] = {};
        }

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

      for (var entry in memberContractData.entries) {
        int memberId = entry.key;
        Map<int, Map<String, dynamic>> contracts = entry.value;
        int totalBalance = 0;
        int validContractCount = 0;
        DateTime? nearestExpiryDate;
        List<Map<String, dynamic>> validLessonTypes = [];
        Set<String> validProNames = {};

        for (var contractData in contracts.values) {
          int balance = contractData['balance'] ?? 0;
          String? expiryDateStr = contractData['expiry_date'];
          String lsType = contractData['LS_type'] ?? '';
          String lsContractPro = contractData['pro_name'] ?? '';

          if (balance > 0) {
            bool isValid = true;
            if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
              try {
                DateTime expiryDate = DateTime.parse(expiryDateStr);
                if (expiryDate.isBefore(now)) {
                  isValid = false;
                } else {
                  if (nearestExpiryDate == null || expiryDate.isBefore(nearestExpiryDate)) {
                    nearestExpiryDate = expiryDate;
                  }
                }
              } catch (e) {}
            }
            if (isValid) {
              totalBalance += balance;
              validContractCount++;
              validLessonTypes.add({'LS_type': lsType, 'pro_name': lsContractPro, 'balance': balance});
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
          'pro_names': validProNames.toList(),
        };
      }

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
  // v2_junior_relation 주니어 관계 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getJuniorRelations({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_junior_relation', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // 관계가 있는 회원 ID 목록 조회 - Supabase 전용
  static Future<List<int>> getJuniorFamilyMemberIds() async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter([], 'v2_group');
      final relations = await _getDataRaw(
        table: 'v2_group',
        where: filteredWhere,
      );
      
      // 관계가 있는 모든 회원 ID를 수집
      Set<int> familyMemberIds = {};
      for (var relation in relations) {
        int? memberId = relation['member_id'];
        int? relatedMemberId = relation['related_member_id'];
        if (memberId != null) familyMemberIds.add(memberId);
        if (relatedMemberId != null) familyMemberIds.add(relatedMemberId);
      }
      return familyMemberIds.toList();
    } catch (e) {
      print('관계 회원 조회 오류: $e');
      return [];
    }
  }

  // 최근 등록된 회원 ID 조회 (최근 10명) - Supabase 전용
  static Future<List<int>> getRecentMemberIds() async {
    _beforeApiCall();
    try {
      final data = await _getDataRaw(
        table: 'v3_members',
        fields: ['member_id'],
        orderBy: [{'field': 'member_id', 'direction': 'DESC'}],
        limit: 10,
      );
      
      return data.map((item) => item['member_id'] as int).toList();
    } catch (e) {
      print('최근 회원 조회 오류: $e');
      return [];
    }
  }

  // 특정 회원 정보 조회 - Supabase 전용
  static Future<Map<String, dynamic>?> getMemberById(int memberId) async {
    _beforeApiCall();
    try {
      final whereConditions = [{'field': 'member_id', 'operator': '=', 'value': memberId}];
      final filteredWhere = _addBranchFilter(whereConditions, 'v3_members');
      
      final data = await _getDataRaw(
        table: 'v3_members',
        where: filteredWhere,
        limit: 1,
      );
      return data.isNotEmpty ? data.first : null;
    } catch (e) {
      throw Exception('회원 조회 오류: $e');
    }
  }

  // 회원 정보 업데이트
  // 회원 즐겨찾기 업데이트
  static Future<bool> updateMemberBookmark(int memberId, String bookmarkStatus) async {
    return updateMember(memberId, {
      'chat_bookmark': bookmarkStatus,
    });
  }

  // 회원 정보 업데이트 - Supabase 전용
  static Future<bool> updateMember(int memberId, Map<String, dynamic> updateData) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(updateData, 'v3_members');
      final whereConditions = [{'field': 'member_id', 'operator': '=', 'value': memberId}];
      final filteredWhere = _addBranchFilter(whereConditions, 'v3_members');
      
      final result = await ApiService.updateData(
        table: 'v3_members',
        data: dataWithBranch,
        where: filteredWhere ?? [],
      );
      return result['success'] == true;
    } catch (e) {
      throw Exception('회원 정보 업데이트 오류: $e');
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

  // 월별 매출 집계 데이터 조회 - Supabase 전용
  static Future<Map<String, dynamic>> getMonthlySalesReport({
    required int year,
    required int month,
  }) async {
    _beforeApiCall();
    try {
      final lastDay = DateTime(year, month + 1, 0);
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final where = [
        {'field': 'contract_date', 'operator': '>=', 'value': startDate},
        {'field': 'contract_date', 'operator': '<=', 'value': endDate},
      ];
      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');

      final data = await _getDataRaw(
        table: 'v3_contract_history',
        fields: ['contract_date', 'contract_history_status', 'member_name', 'contract_name', 'payment_type', 'price', 'contract_credit', 'contract_LS_min', 'contract_games', 'contract_TS_min', 'contract_term_month'],
        where: filteredWhere,
      );

      // 집계 계산
      double totalPrice = 0;
      double totalCredit = 0;
      int totalLSMin = 0;
      int totalGames = 0;
      int totalTSMin = 0;
      int totalTermMonth = 0;
      int validRecordCount = 0;

      for (var record in data) {
        final status = record['contract_history_status']?.toString() ?? '';
        final paymentType = record['payment_type']?.toString() ?? '';
        if (status == '삭제' || paymentType == '데이터 이전' || paymentType == '크레딧결제') continue;

        validRecordCount++;
        totalPrice += double.tryParse(record['price']?.toString() ?? '0') ?? 0;
        totalCredit += double.tryParse(record['contract_credit']?.toString() ?? '0') ?? 0;
        totalLSMin += int.tryParse(record['contract_LS_min']?.toString() ?? '0') ?? 0;
        totalGames += int.tryParse(record['contract_games']?.toString() ?? '0') ?? 0;
        totalTSMin += int.tryParse(record['contract_TS_min']?.toString() ?? '0') ?? 0;
        totalTermMonth += int.tryParse(record['contract_term_month']?.toString() ?? '0') ?? 0;
      }

      return {
        'year': year, 'month': month, 'recordCount': validRecordCount,
        'totalPrice': totalPrice, 'totalCredit': totalCredit, 'totalLSMin': totalLSMin,
        'totalGames': totalGames, 'totalTSMin': totalTSMin, 'totalTermMonth': totalTermMonth,
        'rawData': data,
      };
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

  // 월별 청구 데이터 조회 - Supabase 전용
  static Future<Map<String, dynamic>> getMonthlyBillsReport({
    required int year,
    required int month,
  }) async {
    _beforeApiCall();
    try {
      final lastDay = DateTime(year, month + 1, 0);
      final startDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endDate = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final where = [
        {'field': 'bill_date', 'operator': '>=', 'value': startDate},
        {'field': 'bill_date', 'operator': '<=', 'value': endDate},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_bills');

      final rawData = await _getDataRaw(
        table: 'v2_bills',
        fields: ['bill_netamt', 'bill_date', 'bill_type', 'bill_status'],
        where: filteredWhere,
      );

      double totalBills = 0;
      int validRecordCount = 0;

      for (var record in rawData) {
        final billType = record['bill_type']?.toString() ?? '';
        final billStatus = record['bill_status']?.toString() ?? '';
        if (billType == '데이터 이관' || billType == '회원권 구매') continue;
        if (billStatus != '결제완료') continue;

        if (record['bill_netamt'] != null) {
          final billAmount = double.tryParse(record['bill_netamt'].toString()) ?? 0;
          if (billAmount < 0) {
            totalBills += billAmount.abs();
            validRecordCount++;
          }
        }
      }
      return {'year': year, 'month': month, 'totalBills': totalBills, 'recordCount': validRecordCount};
    } catch (e) {
      print('월별 청구 데이터 조회 오류: $e');
      return {'year': year, 'month': month, 'totalBills': 0, 'recordCount': 0};
    }
  }

  // v3_contract_history 데이터 조회 (계약 이력)
  // v3_contract_history 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getContractHistoryData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v3_contract_history', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v3_members 테이블에 신규 회원 추가 - Supabase 전용
  static Future<Map<String, dynamic>> addMember(Map<String, dynamic> memberData) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(memberData, 'v3_members');
      final result = await addData(table: 'v3_members', data: dataWithBranch);
      return {
        'success': result['success'] ?? true,
        'member_id': result['insertId'],
        'message': '회원이 성공적으로 등록되었습니다.'
      };
    } catch (e) {
      throw Exception('회원 등록 오류: $e');
    }
  }

  // v3_LS_countings 데이터 조회 (레슨권 내역)
  // 레슨 카운팅 데이터 조회 (v3_LS_countings) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getLSCountingsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v3_LS_countings');
      return await _getDataRaw(
        table: 'v3_LS_countings',
        fields: fields,
        where: filteredWhere,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('레슨 카운팅 데이터 조회 오류: $e');
    }
  }

  // v2_bills 데이터 조회 (크레딧 내역) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBillsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_bills', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_bills 데이터 추가 (크레딧 수동차감/적립) - Supabase 전용
  static Future<Map<String, dynamic>> addBillsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('=== addBillsData (Supabase) 시작 ===');
    return await addData(table: 'v2_bills', data: data);
  }

  // v2_bill_term 데이터 조회 (기간권 조회)
  // v2_bill_term 데이터 조회 (기간권 조회) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBillTermData({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_bill_term', where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_bill_term_hold 데이터 추가 (홀드 등록) - Supabase 전용
  static Future<Map<String, dynamic>> addBillTermHoldData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_bill_term_hold');
      return await addData(table: 'v2_bill_term_hold', data: dataWithBranch);
    } catch (e) {
      throw Exception('Bill Term Hold 데이터 추가 오류: $e');
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

  // v2_bill_term 테이블의 contract_term_month_expiry_date 업데이트 - Supabase 전용
  static Future<Map<String, dynamic>> updateBillTermExpiryDate(
    int billTermId, 
    String newExpiryDate,
    String newEndDate,
  ) async {
    _beforeApiCall();
    try {
      return await ApiService.updateData(
        table: 'v2_bill_term',
        data: {'contract_term_month_expiry_date': newExpiryDate, 'term_enddate': newEndDate},
        where: [{'field': 'bill_term_id', 'operator': '=', 'value': billTermId}],
      );
    } catch (e) {
      print('updateBillTermExpiryDate 오류: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // v2_bill_term 데이터 추가 (기간권 관리) - Supabase 전용
  static Future<Map<String, dynamic>> addBillTermData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_bill_term');
      return await addData(table: 'v2_bill_term', data: dataWithBranch);
    } catch (e) {
      throw Exception('Bill Term 데이터 추가 오류: $e');
    }
  }

  // v2_bill_times 데이터 추가 (시간 크레딧 관리) - Supabase 전용
  static Future<Map<String, dynamic>> addBillTimesData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_bill_times');
      return await addData(table: 'v2_bill_times', data: dataWithBranch);
    } catch (e) {
      throw Exception('Bill Times 데이터 추가 오류: $e');
    }
  }

  // v2_bill_games 데이터 추가 (게임 크레딧 관리) - Supabase 전용
  static Future<Map<String, dynamic>> addBillGamesData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_bill_games');
      return await addData(table: 'v2_bill_games', data: dataWithBranch);
    } catch (e) {
      throw Exception('Bill Games 데이터 추가 오류: $e');
    }
  }

  // v2_contracts 데이터 조회 (상품 목록) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getContractsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_contracts', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_base_option_setting 데이터 조회 (옵션 설정) - Supabase 전용
  static Future<List<String>> getBaseOptionSettings({
    required String category,
    required String tableName,
    required String fieldName,
  }) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': category},
        {'field': 'table_name', 'operator': '=', 'value': tableName},
        {'field': 'field_name', 'operator': '=', 'value': fieldName},
        {'field': 'setting_status', 'operator': '=', 'value': '유효'},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      
      final data = await _getDataRaw(
        table: 'v2_base_option_setting',
        fields: ['option_value'],
        where: filteredWhere,
        orderBy: [{'field': 'option_value', 'direction': 'ASC'}],
      );
      return data.map((item) => item['option_value'].toString()).toList();
    } catch (e) {
      throw Exception('옵션 설정 조회 오류: $e');
    }
  }

  // v2_base_option_setting 데이터 조회 (범용) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBaseOptionSettingData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      return await _getDataRaw(
        table: 'v2_base_option_setting',
        fields: fields,
        where: filteredWhere,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('옵션 설정 데이터 조회 오류: $e');
    }
  }

  // v2_bill_times 데이터 조회
  // v2_bill_times 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBillTimesData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _getDataRaw(table: 'v2_bill_times', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_cancellation_policy 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getCancellationPolicyData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    return await _getDataRaw(table: 'v2_cancellation_policy', fields: fields, where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_discount_coupon 데이터 추가 (할인권 증정) - Supabase 전용
  static Future<Map<String, dynamic>> addDiscountCoupon(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_discount_coupon');
      return await addData(table: 'v2_discount_coupon', data: dataWithBranch);
    } catch (e) {
      throw Exception('할인권 증정 오류: $e');
    }
  }

  // v2_discount_coupon 데이터 조회 (할인권 내역) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getDiscountCouponsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_discount_coupon');
      return await _getDataRaw(table: 'v2_discount_coupon', fields: fields, where: filteredWhere, orderBy: orderBy, limit: limit, offset: offset);
    } catch (e) {
      throw Exception('할인권 조회 오류: $e');
    }
  }

  // 유효한 회원권 조회 (통합예약 상품 설정용) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getActiveMembershipContracts() async {
    _beforeApiCall();
    try {
      final branchId = getCurrentBranchId();
      if (branchId == null) throw Exception('지점 정보가 없습니다.');

      return await _getDataRaw(
        table: 'v2_contracts',
        fields: ['contract_id', 'contract_type', 'contract_name', 'contract_LS_min', 'contract_TS_min'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'contract_category', 'operator': '=', 'value': '회원권'},
          {'field': 'contract_status', 'operator': '=', 'value': '유효'},
        ],
        orderBy: [
          {'field': 'contract_type', 'direction': 'ASC'},
          {'field': 'contract_name', 'direction': 'ASC'},
        ],
      );
    } catch (e) {
      throw Exception('회원권 조회 오류: $e');
    }
  }

  // v2_staff_pro 데이터 조회 (재직중인 프로 목록) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getActiveStaffPros() async {
    _beforeApiCall();
    return await _getDataRaw(
      table: 'v2_staff_pro',
      fields: ['pro_id', 'pro_name', 'staff_status'],
      where: [{'field': 'staff_status', 'operator': '=', 'value': '재직'}],
      orderBy: [{'field': 'pro_name', 'direction': 'ASC'}],
    );
  }

  // 유효한 레슨권을 가진 모든 회원 ID 목록 조회 - Supabase 전용
  static Future<List<int>> getValidLessonMemberIds() async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      DateTime nowDate = DateTime(now.year, now.month, now.day);
      
      List<Map<String, dynamic>> data = await _getDataRaw(
        table: 'v3_LS_countings',
        fields: ['member_id', 'LS_expiry_date', 'LS_balance_min_after'],
      );
      
      // 유효한 레슨권이 있는 회원만 필터링
      Set<int> validMemberIds = {};
      for (var item in data) {
        int? balance = item['LS_balance_min_after'] ?? item['ls_balance_min_after'];
        String? expiryDateStr = item['LS_expiry_date'] ?? item['ls_expiry_date'];
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
            int? memberId = item['member_id'];
            if (memberId != null) {
              validMemberIds.add(memberId);
            }
          }
        }
      }
      return validMemberIds.toList();
    } catch (e) {
      throw Exception('유효한 레슨회원 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 프로별 유효한 레슨권이 있는 회원 목록 조회 (v3_LS_countings 기준) - Supabase 전용
  static Future<List<int>> getMemberIdsByProId(int proId) async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      DateTime nowDate = DateTime(now.year, now.month, now.day);

      final whereConditions = [{'field': 'pro_id', 'operator': '=', 'value': proId}];
      final filteredWhere = _addBranchFilter(whereConditions, 'v3_LS_countings');

      final data = await _getDataRaw(
        table: 'v3_LS_countings',
        fields: ['member_id', 'LS_expiry_date', 'LS_balance_min_after'],
        where: filteredWhere,
      );

      Set<int> validMemberIds = {};
      for (var item in data) {
        int? balance = item['LS_balance_min_after'] ?? item['ls_balance_min_after'];
        String? expiryDateStr = item['LS_expiry_date'] ?? item['ls_expiry_date'];
        if (balance != null && balance > 0) {
          bool isValid = true;
          if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
            try {
              DateTime expiryDate = DateTime.parse(expiryDateStr);
              if (DateTime(expiryDate.year, expiryDate.month, expiryDate.day).difference(nowDate).inDays < 0) {
                isValid = false;
              }
            } catch (e) {}
          }
          if (isValid) {
            int? memberId = item['member_id'];
            if (memberId != null) validMemberIds.add(memberId);
          }
        }
      }
      return validMemberIds.toList();
    } catch (e) {
      throw Exception('프로별 레슨회원 조회 오류: $e');
    }
  }

  // 타석 회원 ID 조회 (유효한 레슨권이 없는 회원) - Supabase 전용
  static Future<List<int>> getBattingMemberIds() async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      DateTime nowDate = DateTime(now.year, now.month, now.day);

      // 모든 회원 조회
      List<Map<String, dynamic>> allMembers = await _getDataRaw(
        table: 'v3_members',
        fields: ['member_id'],
      );
      List<int> allMemberIds = allMembers.map((m) => m['member_id'] as int).toList();
      
      if (allMemberIds.isEmpty) return [];

      // 레슨권 조회
      List<Map<String, dynamic>> lessonData = await _getDataRaw(
        table: 'v3_LS_countings',
        fields: ['member_id', 'LS_balance_min_after', 'LS_expiry_date'],
        where: [{'field': 'member_id', 'operator': 'IN', 'value': allMemberIds}],
      );

      Set<int> validLessonMemberIds = {};
      for (var lesson in lessonData) {
        int? balance = lesson['LS_balance_min_after'] ?? lesson['ls_balance_min_after'];
        String? expiryDateStr = lesson['LS_expiry_date'] ?? lesson['ls_expiry_date'];

        if (balance != null && balance > 0) {
          bool isValid = true;
          if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
            try {
              DateTime expiryDate = DateTime.parse(expiryDateStr);
              DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              if (expiryDateOnly.difference(nowDate).inDays < 0) {
                isValid = false;
              }
            } catch (e) {}
          }
          if (isValid) {
            int? memberId = lesson['member_id'];
            if (memberId != null) {
              validLessonMemberIds.add(memberId);
            }
          }
        }
      }

      return allMemberIds.where((id) => !validLessonMemberIds.contains(id)).toList();
    } catch (e) {
      throw Exception('타석 회원 조회 오류: $e');
    }
  }

  // 만료회원 ID 목록 조회 (유효한 회원권이 아무것도 없는 회원) - Supabase 전용
  static Future<List<int>> getExpiredMemberIds() async {
    _beforeApiCall();
    try {
      DateTime now = DateTime.now();
      DateTime nowDate = DateTime(now.year, now.month, now.day);

      // 모든 회원 조회
      List<Map<String, dynamic>> allMembers = await _getDataRaw(
        table: 'v3_members',
        fields: ['member_id'],
      );
      List<int> allMemberIds = allMembers.map((m) => m['member_id'] as int).toList();
      if (allMemberIds.isEmpty) return [];

      Set<int> validMemberIds = {};

      // 헬퍼 함수: 유효한 회원 ID 추가
      void addValidMembers(List<Map<String, dynamic>> data, String balanceField, String? expiryField) {
        for (var item in data) {
          int? balance = item[balanceField] ?? item[balanceField.toLowerCase()];
          String? expiryDateStr = expiryField != null ? (item[expiryField] ?? item[expiryField.toLowerCase()]) : null;
          
          bool isValid = true;
          if (balanceField.isNotEmpty && (balance == null || balance <= 0)) {
            isValid = false;
          }
          if (isValid && expiryDateStr != null && expiryDateStr.isNotEmpty) {
            try {
              DateTime expiryDate = DateTime.parse(expiryDateStr);
              if (DateTime(expiryDate.year, expiryDate.month, expiryDate.day).difference(nowDate).inDays < 0) {
                isValid = false;
              }
            } catch (e) {}
          }
          if (isValid) {
            int? memberId = item['member_id'];
            if (memberId != null) validMemberIds.add(memberId);
          }
        }
      }

      // 1. 크레딧
      List<Map<String, dynamic>> creditData = await _getDataRaw(
        table: 'v2_bills',
        fields: ['member_id', 'bill_balance_after', 'contract_credit_expiry_date'],
        where: [{'field': 'member_id', 'operator': 'IN', 'value': allMemberIds}],
      );
      addValidMembers(creditData, 'bill_balance_after', 'contract_credit_expiry_date');

      // 2. 레슨권
      List<Map<String, dynamic>> lessonData = await _getDataRaw(
        table: 'v3_LS_countings',
        fields: ['member_id', 'LS_balance_min_after', 'LS_expiry_date'],
        where: [{'field': 'member_id', 'operator': 'IN', 'value': allMemberIds}],
      );
      addValidMembers(lessonData, 'LS_balance_min_after', 'LS_expiry_date');

      // 3. 시간권
      List<Map<String, dynamic>> timeData = await _getDataRaw(
        table: 'v2_bill_times',
        fields: ['member_id', 'bill_balance_min_after', 'contract_TS_min_expiry_date'],
        where: [{'field': 'member_id', 'operator': 'IN', 'value': allMemberIds}],
      );
      addValidMembers(timeData, 'bill_balance_min_after', 'contract_TS_min_expiry_date');

      // 4. 기간권
      List<Map<String, dynamic>> termData = await _getDataRaw(
        table: 'v2_bill_term',
        fields: ['member_id', 'contract_term_month_expiry_date'],
        where: [{'field': 'member_id', 'operator': 'IN', 'value': allMemberIds}],
      );
      for (var term in termData) {
        String? expiryDateStr = term['contract_term_month_expiry_date'];
        if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
          try {
            DateTime expiryDate = DateTime.parse(expiryDateStr);
            if (DateTime(expiryDate.year, expiryDate.month, expiryDate.day).difference(nowDate).inDays >= 0) {
              int? memberId = term['member_id'];
              if (memberId != null) validMemberIds.add(memberId);
            }
          } catch (e) {}
        }
      }

      return allMemberIds.where((id) => !validMemberIds.contains(id)).toList();
    } catch (e) {
      throw Exception('만료회원 조회 오류: $e');
    }
  }

  // 활성 기간권 회원 조회 (만료되지 않은 회원만) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getActiveTermMembers() async {
    _beforeApiCall();
    return await _getDataRaw(
      table: 'v2_Term_member',
      where: [
        {
          'field': 'term_expirydate',
          'operator': '>=',
          'value': DateTime.now().toIso8601String().split('T')[0],
        }
      ],
      orderBy: [{'field': 'term_type', 'direction': 'ASC'}],
    );
  }

  // 특정 기간권 타입의 회원 ID 목록 조회 - Supabase 전용
  static Future<List<int>> getMemberIdsByTermType(String termType) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'term_type', 'operator': '=', 'value': termType},
        {'field': 'term_expirydate', 'operator': '>=', 'value': DateTime.now().toIso8601String().split('T')[0]},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_Term_member');

      final results = await _getDataRaw(
        table: 'v2_Term_member',
        fields: ['member_id'],
        where: filteredWhere,
      );
      return results
          .map((item) => item['member_id'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toSet()
          .toList();
    } catch (e) {
      throw Exception('기간권 회원 ID 조회 오류: $e');
    }
  }

  // 모든 유효한 기간권 회원 ID 목록 조회 (타입 구분 없이) - Supabase 전용
  static Future<List<int>> getAllTermMemberIds() async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'term_expirydate', 'operator': '>=', 'value': DateTime.now().toIso8601String().split('T')[0]},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_Term_member');

      final results = await _getDataRaw(
        table: 'v2_Term_member',
        fields: ['member_id'],
        where: filteredWhere,
      );
      return results
          .map((item) => item['member_id'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toSet()
          .toList();
    } catch (e) {
      throw Exception('기간권 회원 ID 조회 오류: $e');
    }
  }

  // Staff 로그인 인증 (v2_staff_pro, v2_staff_manager 테이블 사용) - Supabase 전용
  static Future<Map<String, dynamic>?> authenticateStaff({
    required String staffAccessId,
    required String staffPassword,
  }) async {
    print('=== authenticateStaff 메서드 시작 (Supabase) ===');
    print('입력 받은 값:');
    print('  - staffAccessId: $staffAccessId');
    print('  - staffPassword: (보안상 표시 안함)');

    try {
      // 1. v2_staff_pro 테이블에서 사용자 조회
      print('1단계: v2_staff_pro 테이블 조회 시작');
      final proData = await SupabaseAdapter.getData(
        table: 'v2_staff_pro',
        where: [
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
      );

      print('Pro 응답: ${proData.length}개');

      if (proData.isNotEmpty) {
        // 같은 staff_access_id로 여러 계약이 있을 수 있으므로 모두 순회
        for (var userData in proData) {
          final storedPassword = userData['staff_access_password'] ?? '';

          // PasswordService로 비밀번호 검증
          print('🔐 Pro 비밀번호 검증 시작 (branch: ${userData['branch_id']})...');
          if (PasswordService.verifyPassword(staffPassword, storedPassword)) {
            userData['role'] = 'pro';
            print('✅ Pro로 인증 성공!');
            print('  - pro_name: ${userData['pro_name']}');
            print('  - branch_id: ${userData['branch_id']}');
            return userData;
          } else {
            print('❌ Pro 비밀번호 불일치 (branch: ${userData['branch_id']})');
          }
        }
        print('Pro 테이블에서 비밀번호가 일치하는 계약을 찾을 수 없음');
      } else {
        print('Pro 테이블에서 사용자를 찾을 수 없음');
      }

      // 2. v2_staff_manager 테이블에서 사용자 조회
      print('2단계: v2_staff_manager 테이블 조회 시작');
      final managerData = await SupabaseAdapter.getData(
        table: 'v2_staff_manager',
        where: [
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
      );

      print('Manager 응답: ${managerData.length}개');

      if (managerData.isNotEmpty) {
        // 같은 staff_access_id로 여러 계약이 있을 수 있으므로 모두 순회
        for (var userData in managerData) {
          final storedPassword = userData['staff_access_password'] ?? '';

          // PasswordService로 비밀번호 검증
          print('🔐 Manager 비밀번호 검증 시작 (branch: ${userData['branch_id']})...');
          if (PasswordService.verifyPassword(staffPassword, storedPassword)) {
            userData['role'] = 'manager';
            print('✅ Manager로 인증 성공!');
            print('  - manager_name: ${userData['manager_name']}');
            print('  - branch_id: ${userData['branch_id']}');
            return userData;
          } else {
            print('❌ Manager 비밀번호 불일치 (branch: ${userData['branch_id']})');
          }
        }
        print('Manager 테이블에서 비밀번호가 일치하는 계약을 찾을 수 없음');
      } else {
        print('Manager 테이블에서도 사용자를 찾을 수 없음');
      }

      print('❌❌❌ 인증 실패: Pro와 Manager 모두에서 사용자를 찾을 수 없거나 비밀번호 불일치');
      return null;

    } catch (e) {
      print('❌❌❌ 예외 발생: $e');
      throw Exception('로그인 오류: $e');
    }
  }

  // 지점 정보 조회 (Supabase 전용)
  static Future<List<Map<String, dynamic>>> getBranchData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    // v2_branch는 branch_id 필터링 제외하므로 getData의 자동 필터링을 우회
    try {
      return await SupabaseAdapter.getData(
        table: 'v2_branch',
        fields: fields,
        where: where,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('지점 정보 조회 오류: $e');
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

  // 개발용 직원 목록 조회 (특정 지점의 v2_staff_pro, v2_staff_manager 테이블) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getDevStaffListByBranch(String branchId) async {
    print('=== getDevStaffListByBranch 메서드 시작 (지점: $branchId, Supabase) ===');
    
    try {
      List<Map<String, dynamic>> allStaff = [];
      
      // 1. v2_staff_pro 테이블에서 해당 지점의 재직 프로 직원 조회
      print('1단계: v2_staff_pro 테이블 조회 시작 (지점: $branchId)');
      final proData = await SupabaseAdapter.getData(
        table: 'v2_staff_pro',
        fields: [
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
        where: [
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
        orderBy: [
          {
            'field': 'pro_name',
            'direction': 'ASC',
          }
        ],
      );

      if (proData.isNotEmpty) {
        for (var staff in proData) {
          staff['role'] = 'pro';
          staff['staff_name'] = staff['pro_name']; // 통일된 이름 필드
          allStaff.add(staff);
        }
        print('✅ Pro 직원 ${proData.length}명 조회 성공 (지점: $branchId)');
      }

      // 2. v2_staff_manager 테이블에서 해당 지점의 재직 매니저 직원 조회
      print('2단계: v2_staff_manager 테이블 조회 시작 (지점: $branchId)');
      final managerData = await SupabaseAdapter.getData(
        table: 'v2_staff_manager',
        fields: [
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
        where: [
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
        orderBy: [
          {
            'field': 'manager_name',
            'direction': 'ASC',
          }
        ],
      );

      if (managerData.isNotEmpty) {
        for (var staff in managerData) {
          staff['role'] = 'manager';
          staff['staff_name'] = staff['manager_name']; // 통일된 이름 필드
          allStaff.add(staff);
        }
        print('✅ Manager 직원 ${managerData.length}명 조회 성공 (지점: $branchId)');
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

  // Delete data from table (Supabase 전용)
  static Future<Map<String, dynamic>> deleteData({
    required String table,
    required List<Map<String, dynamic>> where,
  }) async {
    try {
      final result = await SupabaseAdapter.deleteData(
        table: table,
        where: where,
      );
      print('✅ [ApiService] deleteData() 성공: $table');
      return result;
    } catch (e) {
      print('❌ [ApiService] deleteData() 오류: $e');
      throw Exception('데이터 삭제 오류: $e');
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
      
      final result = await addData(
        table: 'v3_contract_history',
        data: dataWithBranch,
      );
      
      print('계약 이력 추가 성공: $result');
      return result;
    } catch (e) {
      print('계약 이력 추가 예외 발생: $e');
      throw Exception('계약 이력 추가 오류: $e');
    }
  }

  // 계약 이력 업데이트 (v3_contract_history) - Supabase 전용
  static Future<bool> updateContractHistoryData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v3_contract_history');
      final filteredWhere = _addBranchFilter(where, 'v3_contract_history');
      
      final result = await updateData(
        table: 'v3_contract_history',
        data: dataWithBranch,
        where: filteredWhere ?? [],
      );
      
      return result['success'] == true;
    } catch (e) {
      throw Exception('계약 이력 업데이트 오류: $e');
    }
  }

  // 레슨 계약 추가 (v2_LS_contracts) - 더 이상 사용하지 않음
  // v2_LS_contracts 테이블은 마이그레이션에서 제외됨
  static Future<Map<String, dynamic>> addLSContractData(Map<String, dynamic> data) async {
    throw Exception('v2_LS_contracts 테이블은 더 이상 사용하지 않습니다.');
  }

  // 레슨 카운팅 추가 (v3_LS_countings) - Supabase 전용
  static Future<Map<String, dynamic>> addLSCountingData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v3_LS_countings');
      return await addData(table: 'v3_LS_countings', data: dataWithBranch);
    } catch (e) {
      throw Exception('레슨 카운팅 추가 오류: $e');
    }
  }

  // 레슨 카운팅 조회 (v3_LS_countings) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getLSCountingData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v3_LS_countings');
      return await _getDataRaw(
        table: 'v3_LS_countings',
        fields: fields,
        where: filteredWhere,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
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

      // getMemberProPurchaseCount는 특수 작업이라 일단 빈 결과 반환
      // TODO: Supabase에서 v3_LS_countings 테이블에서 직접 계산하도록 변경 필요
      print('⚠️ getMemberProPurchaseCount: 아직 Supabase로 마이그레이션되지 않음');
      
      // v3_LS_countings에서 프로별 구매 횟수 계산
      final result = await _getDataRaw(
        table: 'v3_LS_countings',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'LS_transaction_type', 'operator': '=', 'value': '레슨권 구매'},
        ],
      );
      
      // result는 List<Map<String, dynamic>> 타입
      // 프로별로 그룹화
      Map<String, int> proCounts = {};
      for (var item in result) {
        final proName = item['pro_name']?.toString() ?? '미지정';
        proCounts[proName] = (proCounts[proName] ?? 0) + 1;
      }
      
      return {
        'success': true,
        'data': proCounts.entries.map((e) => {'pro_name': e.key, 'count': e.value}).toList(),
        'total_count': result.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': '프로 구매횟수 조회 오류: $e',
      };
    }
  }

  // 회원-프로 매칭 조회 (v2_member_pro_match) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getMemberProMatchData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_member_pro_match');
      return await _getDataRaw(table: 'v2_member_pro_match', fields: fields, where: filteredWhere, orderBy: orderBy, limit: limit, offset: offset);
    } catch (e) {
      throw Exception('회원-프로 매칭 조회 오류: $e');
    }
  }

  // 회원-프로 매칭 추가 (v2_member_pro_match) - Supabase 전용
  static Future<Map<String, dynamic>> addMemberProMatchData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_member_pro_match');
      return await addData(table: 'v2_member_pro_match', data: dataWithBranch);
    } catch (e) {
      throw Exception('회원-프로 매칭 추가 오류: $e');
    }
  }

  // 회원-프로 매칭 업데이트 (v2_member_pro_match) - Supabase 전용
  static Future<bool> updateMemberProMatchData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_member_pro_match');
      final filteredWhere = _addBranchFilter(where, 'v2_member_pro_match');
      final result = await ApiService.updateData(table: 'v2_member_pro_match', data: dataWithBranch, where: filteredWhere ?? []);
      return result['success'] == true;
    } catch (e) {
      throw Exception('회원-프로 매칭 업데이트 오류: $e');
    }
  }

  // 스태프 프로 데이터 조회 (v2_staff_pro) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getStaffProData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_staff_pro');
      
      return await _getDataRaw(
        table: 'v2_staff_pro',
        fields: fields,
        where: filteredWhere,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('스태프 프로 조회 오류: $e');
    }
  }

  // ========== 타석유형 관리 (v2_base_option_setting) ==========
  
  // 타석유형 목록 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getTsTypeOptions() async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '타석종류'},
        {'field': 'table_name', 'operator': '=', 'value': 'v2_ts_info'},
        {'field': 'field_name', 'operator': '=', 'value': 'ts_type'},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      return await _getDataRaw(
        table: 'v2_base_option_setting',
        fields: ['option_value'],
        where: filteredWhere,
        orderBy: [{'field': 'option_value', 'direction': 'ASC'}],
      );
    } catch (e) {
      throw Exception('타석유형 조회 오류: $e');
    }
  }

  // 회원유형 목록 조회 (유효/만료 모두) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getMemberTypeOptions() async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      return await _getDataRaw(
        table: 'v2_base_option_setting',
        fields: ['option_value', 'setting_status', 'option_sequence'],
        where: filteredWhere,
        orderBy: [
          {'field': 'setting_status', 'direction': 'DESC'},
          {'field': 'option_sequence', 'direction': 'ASC'},
        ],
      );
    } catch (e) {
      throw Exception('회원유형 조회 오류: $e');
    }
  }

  // 회원유형 추가 - Supabase 전용
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
      final dataWithBranch = _addBranchToData(data, 'v2_base_option_setting');
      await addData(table: 'v2_base_option_setting', data: dataWithBranch);
    } catch (e) {
      throw Exception('회원유형 추가 오류: $e');
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

  // 회원유형 만료 처리 (삭제 대신 setting_status를 '만료'로 변경) - Supabase 전용
  static Future<void> deleteMemberTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      await ApiService.updateData(table: 'v2_base_option_setting', data: {'setting_status': '만료'}, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('회원유형 만료 처리 오류: $e');
    }
  }

  // 회원유형 되살리기 (setting_status를 '유효'로 변경) - Supabase 전용
  static Future<void> restoreMemberTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      await ApiService.updateData(table: 'v2_base_option_setting', data: {'setting_status': '유효'}, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('회원유형 되살리기 오류: $e');
    }
  }

  // 회원유형 순서 업데이트 - Supabase 전용
  static Future<void> updateMemberTypeSequence(List<Map<String, String>> sequenceUpdates) async {
    _beforeApiCall();
    try {
      for (var update in sequenceUpdates) {
        final where = [
          {'field': 'category', 'operator': '=', 'value': '유형설정'},
          {'field': 'table_name', 'operator': '=', 'value': '회원유형'},
          {'field': 'option_value', 'operator': '=', 'value': update['option_value']!},
        ];
        final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
        await ApiService.updateData(
          table: 'v2_base_option_setting',
          data: {'option_sequence': int.parse(update['sequence']!)},
          where: filteredWhere ?? [],
        );
      }
    } catch (e) {
      throw Exception('회원유형 순서 업데이트 오류: $e');
    }
  }

  // 회원권 유형 목록 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getMembershipTypeOptions() async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      return await _getDataRaw(
        table: 'v2_base_option_setting',
        fields: ['option_value', 'setting_status', 'option_sequence'],
        where: filteredWhere,
        orderBy: [
          {'field': 'setting_status', 'direction': 'DESC'},
          {'field': 'option_sequence', 'direction': 'ASC'},
        ],
      );
    } catch (e) {
      throw Exception('회원권 유형 조회 오류: $e');
    }
  }

  // 회원권 유형 추가 - Supabase 전용
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
      final dataWithBranch = _addBranchToData(data, 'v2_base_option_setting');
      await addData(table: 'v2_base_option_setting', data: dataWithBranch);
    } catch (e) {
      throw Exception('회원권 유형 추가 오류: $e');
    }
  }

  // 회원권 유형 만료 처리 (setting_status를 '만료'로 변경) - Supabase 전용
  static Future<void> deleteMembershipTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      await ApiService.updateData(table: 'v2_base_option_setting', data: {'setting_status': '만료'}, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('회원권 유형 만료 처리 오류: $e');
    }
  }

  // 회원권 유형 순서 업데이트 - Supabase 전용
  static Future<void> updateMembershipTypeSequence(List<Map<String, String>> sequenceUpdates) async {
    _beforeApiCall();
    try {
      for (var update in sequenceUpdates) {
        final where = [
          {'field': 'category', 'operator': '=', 'value': '유형설정'},
          {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
          {'field': 'option_value', 'operator': '=', 'value': update['option_value']!},
        ];
        final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
        await ApiService.updateData(
          table: 'v2_base_option_setting',
          data: {'option_sequence': int.parse(update['sequence']!)},
          where: filteredWhere ?? [],
        );
      }
    } catch (e) {
      throw Exception('회원권 유형 순서 업데이트 오류: $e');
    }
  }

  // 회원권 유형 되살리기 (setting_status를 '유효'로 변경) - Supabase 전용
  static Future<void> restoreMembershipTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '유형설정'},
        {'field': 'table_name', 'operator': '=', 'value': '회원권유형'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      await ApiService.updateData(table: 'v2_base_option_setting', data: {'setting_status': '유효'}, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('회원권 유형 되살리기 오류: $e');
    }
  }

  // 타석유형 추가 - Supabase 전용
  static Future<void> addTsTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final data = {
        'category': '타석종류',
        'table_name': 'v2_ts_info',
        'field_name': 'ts_type',
        'option_value': optionValue,
      };
      final dataWithBranch = _addBranchToData(data, 'v2_base_option_setting');
      await addData(table: 'v2_base_option_setting', data: dataWithBranch);
    } catch (e) {
      throw Exception('타석유형 추가 오류: $e');
    }
  }

  // 타석유형 수정 - Supabase 전용
  static Future<void> updateTsTypeOption(String oldValue, String newValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '타석종류'},
        {'field': 'table_name', 'operator': '=', 'value': 'v2_ts_info'},
        {'field': 'field_name', 'operator': '=', 'value': 'ts_type'},
        {'field': 'option_value', 'operator': '=', 'value': oldValue},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      await ApiService.updateData(table: 'v2_base_option_setting', data: {'option_value': newValue}, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('타석유형 수정 오류: $e');
    }
  }

  // 타석유형 삭제 - Supabase 전용
  static Future<void> deleteTsTypeOption(String optionValue) async {
    _beforeApiCall();
    try {
      final where = [
        {'field': 'category', 'operator': '=', 'value': '타석종류'},
        {'field': 'table_name', 'operator': '=', 'value': 'v2_ts_info'},
        {'field': 'field_name', 'operator': '=', 'value': 'ts_type'},
        {'field': 'option_value', 'operator': '=', 'value': optionValue},
      ];
      final filteredWhere = _addBranchFilter(where, 'v2_base_option_setting');
      await deleteData(table: 'v2_base_option_setting', where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('타석유형 삭제 오류: $e');
    }
  }

  // ========== v2_contracts 테이블 관련 메서드들 ==========
  
  // v2_contracts 데이터 추가 (회원권 추가) - Supabase 전용
  static Future<Map<String, dynamic>> addContractsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_contracts');
      return await addData(table: 'v2_contracts', data: dataWithBranch);
    } catch (e) {
      throw Exception('회원권 추가 오류: $e');
    }
  }

  // v2_contracts 데이터 수정 (회원권 수정) - Supabase 전용
  static Future<Map<String, dynamic>> updateContractsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_contracts');
      final filteredWhere = _addBranchFilter(where, 'v2_contracts');
      return await ApiService.updateData(table: 'v2_contracts', data: dataWithBranch, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('회원권 수정 오류: $e');
    }
  }

  // v2_contracts 데이터 삭제 (회원권 삭제) - Supabase 전용
  static Future<Map<String, dynamic>> deleteContractsData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_contracts');
      return await deleteData(table: 'v2_contracts', where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('회원권 삭제 오류: $e');
    }
  }

  // v2_ts_pricing_policy 데이터 조회 (과금정책 조회) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getPricingPolicyData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_ts_pricing_policy');
      return await _getDataRaw(table: 'v2_ts_pricing_policy', fields: fields, where: filteredWhere, orderBy: orderBy, limit: limit, offset: offset);
    } catch (e) {
      throw Exception('과금정책 조회 오류: $e');
    }
  }

  // v2_ts_pricing_policy 데이터 추가 (과금정책 추가) - Supabase 전용
  static Future<Map<String, dynamic>> addPricingPolicyData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_ts_pricing_policy');
      return await addData(table: 'v2_ts_pricing_policy', data: dataWithBranch);
    } catch (e) {
      throw Exception('과금정책 추가 오류: $e');
    }
  }

  // v2_ts_pricing_policy 데이터 삭제 (과금정책 삭제) - Supabase 전용
  static Future<Map<String, dynamic>> deletePricingPolicyData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_ts_pricing_policy');
      return await deleteData(table: 'v2_ts_pricing_policy', where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('과금정책 삭제 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 조회 (일별 조정된 스케줄 조회) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getScheduleAdjustedTsData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_schedule_adjusted_ts');
      return await _getDataRaw(table: 'v2_schedule_adjusted_ts', fields: fields, where: filteredWhere, orderBy: orderBy, limit: limit, offset: offset);
    } catch (e) {
      throw Exception('일별 조정 스케줄 조회 오류: $e');
    }
  }

  // 타석 요금 정책 데이터 조회 - Supabase 전용
  static Future<List<Map<String, dynamic>>> getTsPricingPolicyData({
    List<String>? fields,
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_ts_pricing_policy');
      return await _getDataRaw(table: 'v2_ts_pricing_policy', fields: fields, where: filteredWhere, orderBy: orderBy, limit: limit, offset: offset);
    } catch (e) {
      throw Exception('타석 요금 정책 조회 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 추가 (일별 조정된 스케줄 추가) - Supabase 전용
  static Future<Map<String, dynamic>> addScheduleAdjustedTsData(Map<String, dynamic> data) async {
    _beforeApiCall();
    try {
      final dataWithBranch = _addBranchToData(data, 'v2_schedule_adjusted_ts');
      return await addData(table: 'v2_schedule_adjusted_ts', data: dataWithBranch);
    } catch (e) {
      throw Exception('일별 스케줄 추가 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 수정 (일별 조정된 스케줄 수정) - Supabase 전용
  static Future<Map<String, dynamic>> updateScheduleAdjustedTsData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_schedule_adjusted_ts');
      return await ApiService.updateData(table: 'v2_schedule_adjusted_ts', data: data, where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('일별 스케줄 수정 오류: $e');
    }
  }

  // v2_schedule_adjusted_ts 데이터 삭제 (일별 조정된 스케줄 삭제) - Supabase 전용
  static Future<Map<String, dynamic>> deleteScheduleAdjustedTsData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    try {
      final filteredWhere = _addBranchFilter(where, 'v2_schedule_adjusted_ts');
      return await deleteData(table: 'v2_schedule_adjusted_ts', where: filteredWhere ?? []);
    } catch (e) {
      throw Exception('일별 스케줄 삭제 오류: $e');
    }
  }

  // ========== 게시판 관련 메소드들 ==========

  // v2_board 데이터 조회 (게시판 목록) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBoardByMemberData({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    print('🔍 [DEBUG] getBoardByMemberData (Supabase) 시작');
    return await _getDataRaw(table: 'v2_board', where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_board 데이터 추가 (새 게시글 작성) - Supabase 전용
  static Future<Map<String, dynamic>> addBoardByMemberData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('🔍 [DEBUG] addBoardByMemberData (Supabase) 시작');
    return await addData(table: 'v2_board', data: data);
  }

  // v2_board 데이터 수정 - Supabase 전용
  static Future<Map<String, dynamic>> updateBoardByMemberData(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> where,
  ) async {
    return await updateData(table: 'v2_board', data: data, where: where);
  }

  // v2_board 데이터 삭제 - Supabase 전용
  static Future<Map<String, dynamic>> deleteBoardByMemberData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    return await deleteData(table: 'v2_board', where: where);
  }

  // v2_board_comment 데이터 조회 (댓글 목록) - Supabase 전용
  static Future<List<Map<String, dynamic>>> getBoardRepliesData({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
    int? limit,
    int? offset,
  }) async {
    print('🔍 [DEBUG] getBoardRepliesData (Supabase) 시작');
    return await _getDataRaw(table: 'v2_board_comment', where: where, orderBy: orderBy, limit: limit, offset: offset);
  }

  // v2_board_comment 데이터 추가 (새 댓글 작성) - Supabase 전용
  static Future<Map<String, dynamic>> addBoardReplyData(Map<String, dynamic> data) async {
    _beforeApiCall();
    print('🔍 [DEBUG] addBoardReplyData (Supabase) 시작');
    return await addData(table: 'v2_board_comment', data: data);
  }

  // v2_board_comment 데이터 삭제 - Supabase 전용
  static Future<Map<String, dynamic>> deleteBoardReplyData(List<Map<String, dynamic>> where) async {
    _beforeApiCall();
    return await deleteData(table: 'v2_board_comment', where: where);
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

      final responseData = await _getDataRaw(
        table: 'v2_LS_orders',
        fields: ['LS_net_min', 'LS_date', 'LS_status', 'pro_name'],
        where: filteredWhere,
      );

      // responseData는 List<Map<String, dynamic>> 타입
      if (responseData.isNotEmpty) {
        int totalUsageMin = 0;
        int validRecordCount = 0; // 실제 집계에 포함된 건수
        Map<String, int> proUsageMap = {}; // 프로별 사용 시간

        print('=== 서버 응답 데이터 확인 ===');
        print('전체 응답 건수: ${responseData.length}건');

        for (var record in responseData) {
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
      }
      
      // 데이터가 없는 경우
      return {
        'year': year,
        'month': month,
        'totalLessonUsage': 0,
        'recordCount': 0,
        'proUsageBreakdown': {},
      };
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

      final responseData = await _getDataRaw(
        table: 'v3_contract_history',
        fields: ['contract_LS_min', 'contract_date', 'contract_history_status', 'payment_type', 'contract_type', 'pro_name'],
        where: filteredWhere,
      );

      // responseData는 List<Map<String, dynamic>> 타입
      if (responseData.isNotEmpty) {
        Map<String, int> proSalesMap = {}; // 프로별 판매 시간
        int validRecordCount = 0;

        print('=== 서버 응답 데이터 확인 ===');
        print('전체 응답 건수: ${responseData.length}건');

        for (var record in responseData) {
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
      }
      
      // 데이터가 없는 경우
      return {
        'year': year,
        'month': month,
        'proSalesBreakdown': {},
        'recordCount': 0,
      };
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

      final responseData = await _getDataRaw(
        table: 'v3_contract_history',
        fields: ['price', 'contract_date', 'contract_history_status', 'payment_type', 'contract_type'],
        where: filteredWhere,
      );

      // responseData는 List<Map<String, dynamic>> 타입
      if (responseData.isNotEmpty) {
        Map<String, double> contractTypeMap = {}; // 계약 타입별 매출

        for (var record in responseData) {
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
