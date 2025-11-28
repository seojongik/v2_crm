import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '/services/api_service.dart';

class LockerApiService {
  static const String baseUrl = ApiService.baseUrl;
  static const Map<String, String> headers = ApiService.headers;

  // 락커 상태 조회
  static Future<List<Map<String, dynamic>>> getLockerStatus({
    List<Map<String, dynamic>>? where,
    List<Map<String, dynamic>>? orderBy,
  }) async {
    print('🔍 [LockerApiService] getLockerStatus() 호출 시작');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    final whereConditions = <Map<String, dynamic>>[];
    
    // 기존 where 조건 추가
    if (where != null) {
      whereConditions.addAll(where);
    }
    
    // branch_id 조건 추가
    if (branchId != null) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
    }
    
    print('🔍 [LockerApiService] v2_Locker_status 테이블 조회 중...');
    final result = await ApiService.getDataList(
      table: 'v2_Locker_status',
      where: whereConditions.isNotEmpty ? whereConditions : null,
      orderBy: orderBy ?? [{'field': 'locker_id', 'direction': 'ASC'}],
    );
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    print('✅ [LockerApiService] getLockerStatus() 완료: ${result.length}개 (소요시간: ${duration.inMilliseconds}ms)');
    
    return result;
  }

  // 락커 상태 업데이트 (신규 배정 또는 수정)
  static Future<Map<String, dynamic>> updateLocker({
    required int lockerId,
    required Map<String, dynamic> data,
  }) async {
    return ApiService.updateData(
      table: 'v2_Locker_status',
      data: data,
      where: [
        {'field': 'locker_id', 'operator': '=', 'value': lockerId},
      ],
    );
  }

  // 해당 월에 과금 대상인 락커 조회 (배정이력 + 현재 정기결제 락커)
  static Future<List<Map<String, dynamic>>> getMonthlyAssignedLockers(DateTime selectedMonth) async {
    print('🔍 [LockerApiService] getMonthlyAssignedLockers() 호출 시작');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    
    // 선택된 월의 시작일과 끝일
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    
    print('선택된 월 기간: ${monthStart.toString().split(' ')[0]} ~ ${monthEnd.toString().split(' ')[0]}');
    
    final whereConditions = <Map<String, dynamic>>[];
    
    // branch_id 조건
    if (branchId != null) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
    }
    
    final filteredResult = <Map<String, dynamic>>[];
    final addedLockers = <String>{}; // 중복 방지용 (locker_id + member_id 조합)
    
    // 1. v2_Locker_bill에서 해당 월과 겹치는 배정 이력 조회
    print('🔍 [LockerApiService] v2_Locker_bill에서 해당 월 배정이력 조회 중...');
    
    final billResult = await ApiService.getDataList(
      table: 'v2_Locker_bill',
      where: whereConditions,
      orderBy: [{'field': 'locker_id', 'direction': 'ASC'}, {'field': 'locker_bill_start', 'direction': 'ASC'}],
    );
    
    for (var bill in billResult) {
      final billStartStr = bill['locker_bill_start'];
      final billEndStr = bill['locker_bill_end'];
      
      if (billStartStr == null || billEndStr == null) continue;
      
      try {
        final billStart = DateTime.parse(billStartStr);
        final billEnd = DateTime.parse(billEndStr);
        
        // 선택된 월과 배정 기간이 겹치는지 확인
        final overlapStart = billStart.isAfter(monthStart) ? billStart : monthStart;
        final overlapEnd = billEnd.isBefore(monthEnd) ? billEnd : monthEnd;
        
        if (!overlapStart.isAfter(overlapEnd)) {
          // 겹치는 기간이 있으면 포함
          
          // v2_Locker_status에서 현재 락커 상태 정보를 가져와서 병합
          final lockerStatus = await ApiService.getDataList(
            table: 'v2_Locker_status',
            where: [
              {'field': 'locker_id', 'operator': '=', 'value': bill['locker_id']},
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
            ],
          );
          
          // bill 정보와 status 정보 병합
          final mergedData = Map<String, dynamic>.from(bill);
          
          if (lockerStatus.isNotEmpty) {
            final status = lockerStatus.first;
            mergedData['current_payment_frequency'] = status['payment_frequency'];
            mergedData['current_payment_method'] = status['payment_method'];
            mergedData['current_locker_price'] = status['locker_price'];
            mergedData['current_locker_discount_condition'] = status['locker_discount_condition'];
            mergedData['current_locker_discount_condition_min'] = status['locker_discount_condition_min'];
            mergedData['current_locker_discount_ratio'] = status['locker_discount_ratio'];
            mergedData['current_locker_end_date'] = status['locker_end_date'];
          }
          
          final key = '${bill['locker_id']}_${bill['member_id']}';
          if (!addedLockers.contains(key)) {
            filteredResult.add(mergedData);
            addedLockers.add(key);
          }
        }
      } catch (e) {
        print('날짜 파싱 오류: $e');
      }
    }
    
    // 2. v2_Locker_status에서 현재 배정되어 있고 정기결제(월별)인 락커 조회
    print('🔍 [LockerApiService] v2_Locker_status에서 현재 정기결제(월별) 락커 조회 중...');
    
    final statusWhereConditions = <Map<String, dynamic>>[];
    if (branchId != null) {
      statusWhereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
    }
    statusWhereConditions.add({'field': 'member_id', 'operator': 'IS NOT', 'value': null});
    statusWhereConditions.add({'field': 'payment_frequency', 'operator': '=', 'value': '정기결제(월별)'});
    
    final statusResult = await ApiService.getDataList(
      table: 'v2_Locker_status',
      where: statusWhereConditions,
      orderBy: [{'field': 'locker_id', 'direction': 'ASC'}],
    );
    
    for (var status in statusResult) {
      final key = '${status['locker_id']}_${status['member_id']}';
      
      if (!addedLockers.contains(key)) {
        // 현재 배정 정보를 기반으로 가상의 bill 데이터 생성
        final virtualBill = {
          'locker_bill_id': 'virtual_${status['locker_id']}_${status['member_id']}',
          'locker_bill_type': '정기결제',
          'locker_id': status['locker_id'],
          'locker_name': status['locker_name'],
          'member_id': status['member_id'],
          'locker_bill_start': selectedMonth.toString().split(' ')[0].substring(0, 8) + '01', // 해당 월 1일
          'locker_bill_end': DateTime(selectedMonth.year, selectedMonth.month + 1, 0).toString().split(' ')[0], // 해당 월 말일
          'current_payment_frequency': status['payment_frequency'],
          'current_payment_method': status['payment_method'],
          'current_locker_price': status['locker_price'],
          'current_locker_discount_condition': status['locker_discount_condition'],
          'current_locker_discount_condition_min': status['locker_discount_condition_min'],
          'current_locker_discount_ratio': status['locker_discount_ratio'],
          'current_locker_end_date': status['locker_end_date'],
        };
        
        filteredResult.add(virtualBill);
        addedLockers.add(key);
      }
    }
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    print('✅ [LockerApiService] getMonthlyAssignedLockers() 완료: ${filteredResult.length}개 (소요시간: ${duration.inMilliseconds}ms)');
    
    // 디버깅을 위한 상세 정보 출력
    for (var locker in filteredResult) {
      print('=== 해당 월 과금대상 락커 ===');
      print('locker_bill_id: ${locker['locker_bill_id']}');
      print('locker_id: ${locker['locker_id']}');
      print('locker_name: ${locker['locker_name']}');
      print('member_id: ${locker['member_id']}');
      print('배정기간: ${locker['locker_bill_start']} ~ ${locker['locker_bill_end']}');
      print('현재 payment_frequency: ${locker['current_payment_frequency']}');
      print('현재 locker_price: ${locker['current_locker_price']}');
      print('-------------------');
    }
    
    return filteredResult;
  }

  // 회원의 전월 이용시간 조회 (v2_priced_TS 테이블) - 기간권 포함/제외 구분
  static Future<Map<int, Map<String, int>>> getMemberPreviousMonthUsage(DateTime selectedMonth) async {
    print('🔍 [LockerApiService] getMemberPreviousMonthUsage() 호출 시작');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    
    // 전월 계산
    final previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    final previousMonthEnd = DateTime(selectedMonth.year, selectedMonth.month, 0);
    
    print('전월 기간: ${previousMonth.toString().split(' ')[0]} ~ ${previousMonthEnd.toString().split(' ')[0]}');
    
    final whereConditions = <Map<String, dynamic>>[];
    
    // branch_id 조건
    if (branchId != null) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
    }
    
    // 날짜 조건 (전월)
    whereConditions.add({
      'field': 'ts_date',
      'operator': '>=',
      'value': previousMonth.toString().split(' ')[0]
    });
    whereConditions.add({
      'field': 'ts_date',
      'operator': '<=',
      'value': previousMonthEnd.toString().split(' ')[0]
    });
    
    // 결제완료 상태만 조회
    whereConditions.add({'field': 'ts_status', 'operator': '=', 'value': '결제완료'});
    
    print('🔍 [LockerApiService] v2_priced_TS 테이블에서 전월 이용시간 조회 중...');
    
    final result = await ApiService.getDataList(
      table: 'v2_priced_TS',
      where: whereConditions,
    );
    
    // member_id별로 이용시간 합산 (전체, 기간권, 비기간권)
    final Map<int, Map<String, int>> memberUsageMap = {};
    
    for (var record in result) {
      final memberId = record['member_id'];
      if (memberId != null) {
        final tsMin = record['ts_min'] ?? 0;
        final billTermId = record['bill_term_id'];
        
        // 초기화
        if (!memberUsageMap.containsKey(memberId)) {
          memberUsageMap[memberId] = {
            'total': 0,
            'term': 0,      // 기간권 이용시간
            'nonTerm': 0,   // 기간권 제외 이용시간
          };
        }
        
        // 전체 시간 추가
        memberUsageMap[memberId]!['total'] = 
            (memberUsageMap[memberId]!['total'] ?? 0) + (tsMin as int);
        
        // bill_term_id가 있으면 기간권 예약
        if (billTermId != null && billTermId.toString().isNotEmpty) {
          memberUsageMap[memberId]!['term'] = 
              (memberUsageMap[memberId]!['term'] ?? 0) + (tsMin as int);
        } else {
          memberUsageMap[memberId]!['nonTerm'] = 
              (memberUsageMap[memberId]!['nonTerm'] ?? 0) + (tsMin as int);
        }
      }
    }
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    print('✅ [LockerApiService] getMemberPreviousMonthUsage() 완료');
    print('조회된 회원 수: ${memberUsageMap.length}명');
    print('소요시간: ${duration.inMilliseconds}ms');
    
    // 디버깅 출력
    memberUsageMap.forEach((memberId, usage) {
      print('member_id: $memberId');
      print('  - 전체 이용시간: ${usage['total']}분');
      print('  - 기간권 이용시간: ${usage['term']}분');
      print('  - 기간권 제외 이용시간: ${usage['nonTerm']}분');
    });
    
    return memberUsageMap;
  }

  // 해당 월의 락커별 기납부 금액 조회 (v2_Locker_bill 테이블)
  static Future<Map<String, Map<String, dynamic>>> getLockerPreviousPayments(DateTime selectedMonth) async {
    print('🔍 [LockerApiService] getLockerPreviousPayments() 호출 시작');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    
    // 선택된 월의 시작일과 끝일
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    
    print('선택된 월 기간: ${monthStart.toString().split(' ')[0]} ~ ${monthEnd.toString().split(' ')[0]}');
    
    final whereConditions = <Map<String, dynamic>>[];
    
    // branch_id 조건
    if (branchId != null) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
    }
    
    // 결제완료 상태만 조회
    whereConditions.add({'field': 'locker_bill_status', 'operator': '=', 'value': '결제완료'});
    
    print('🔍 [LockerApiService] v2_Locker_bill 테이블에서 기납부 정보 조회 중...');
    
    final result = await ApiService.getDataList(
      table: 'v2_Locker_bill',
      where: whereConditions,
    );
    
    // locker_name + member_id 조합별로 기납부 정보 계산
    final Map<String, Map<String, dynamic>> paymentMap = {};
    
    for (var record in result) {
      final lockerId = record['locker_id'];
      final lockerName = record['locker_name'];
      final memberId = record['member_id'];
      final billStartStr = record['locker_bill_start'];
      final billEndStr = record['locker_bill_end'];
      final netAmount = record['locker_bill_netamt'] ?? 0;
      final paymentMethod = record['payment_method'] ?? '';
      
      if (lockerId == null || memberId == null || billStartStr == null || billEndStr == null) {
        continue;
      }
      
      try {
        final billStart = DateTime.parse(billStartStr);
        final billEnd = DateTime.parse(billEndStr);
        
        // 선택된 월과 겹치는 기간이 있는지 확인
        final overlapStart = billStart.isAfter(monthStart) ? billStart : monthStart;
        final overlapEnd = billEnd.isBefore(monthEnd) ? billEnd : monthEnd;
        
        if (overlapStart.isAfter(overlapEnd)) {
          continue; // 겹치는 기간이 없음
        }
        
        // 비례 계산
        final totalDays = billEnd.difference(billStart).inDays + 1;
        final overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
        final proratedAmount = (netAmount * overlapDays / totalDays).round();
        
        final key = '${lockerId}_$memberId';
        
        if (!paymentMap.containsKey(key)) {
          paymentMap[key] = {
            'locker_id': lockerId,
            'locker_name': lockerName,
            'member_id': memberId,
            'total_amount': 0,
            'payment_methods': <String>{},
          };
        }
        
        paymentMap[key]!['total_amount'] = 
            (paymentMap[key]!['total_amount'] as int) + proratedAmount;
        
        if (paymentMethod.isNotEmpty) {
          (paymentMap[key]!['payment_methods'] as Set<String>).add(paymentMethod);
        }
        
        print('락커 ${lockerId}(${lockerName}) - 회원 ${memberId}: ${proratedAmount}원 (${paymentMethod})');
        print('  결제기간: ${billStartStr} ~ ${billEndStr}');
        print('  겹치는기간: ${overlapStart.toString().split(' ')[0]} ~ ${overlapEnd.toString().split(' ')[0]} (${overlapDays}일/${totalDays}일)');
        
      } catch (e) {
        print('날짜 파싱 오류: $e');
      }
    }
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    print('✅ [LockerApiService] getLockerPreviousPayments() 완료');
    print('기납부 락커 수: ${paymentMap.length}개');
    print('소요시간: ${duration.inMilliseconds}ms');
    
    return paymentMap;
  }

  // 회원 검색 (이름 또는 전화번호)
  static Future<List<Map<String, dynamic>>> searchMembers(String searchText) async {
    print('🔍 [LockerApiService] searchMembers() 호출 시작: "$searchText"');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    final whereConditions = <Map<String, dynamic>>[];
    
    // branch_id 조건
    if (branchId != null) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
    }
    
    // 검색 조건 (member_id, 이름, 전화번호)
    List<Map<String, dynamic>> results = [];
    
    // member_id로 검색 (숫자이고 3자리 이하일 때만)
    if (int.tryParse(searchText) != null && searchText.length <= 3 && !searchText.startsWith('0')) {
      try {
        final memberId = int.parse(searchText);
        print('member_id로 검색: $memberId');
        final idResults = await ApiService.getDataList(
          table: 'v3_members',
          where: [
            ...whereConditions,
            {'field': 'member_id', 'operator': '=', 'value': memberId},
          ],
        );
        results.addAll(idResults);
        print('member_id 검색 결과: ${idResults.length}명');
      } catch (e) {
        print('member_id 검색 오류: $e');
      }
    }
    
    // 이름으로 검색
    try {
      final nameResults = await ApiService.getDataList(
        table: 'v3_members',
        where: [
          ...whereConditions,
          {'field': 'member_name', 'operator': 'LIKE', 'value': '%$searchText%'},
        ],
      );
      for (final member in nameResults) {
        if (!results.any((m) => m['member_id'] == member['member_id'])) {
          results.add(member);
        }
      }
    } catch (e) {
      print('이름 검색 오류: $e');
    }
    
    // 전화번호로 검색
    // 하이픈 제거한 검색어와 원본 모두 시도
    try {
      // 검색어에서 하이픈 제거
      final cleanedSearch = searchText.replaceAll('-', '');
      
      // 원본 검색어로 검색 (하이픈 포함된 경우)
      final phoneResults1 = await ApiService.getDataList(
        table: 'v3_members',
        where: [
          ...whereConditions,
          {'field': 'member_phone', 'operator': 'LIKE', 'value': '%$searchText%'},
        ],
      );
      
      for (final member in phoneResults1) {
        if (!results.any((m) => m['member_id'] == member['member_id'])) {
          results.add(member);
        }
      }
      
      // 하이픈 제거한 검색어로도 검색 (숫자만 입력한 경우를 위해)
      // DB의 전화번호에서도 하이픈을 제거하고 비교해야 하지만, LIKE로는 한계가 있음
      // 따라서 모든 회원을 가져와서 클라이언트에서 필터링
      if (RegExp(r'^\d+$').hasMatch(cleanedSearch)) {
        final allMembers = await ApiService.getDataList(
          table: 'v3_members',
          where: whereConditions,
        );
        
        for (final member in allMembers) {
          final memberPhone = (member['member_phone'] ?? '').toString().replaceAll('-', '');
          if (memberPhone.contains(cleanedSearch)) {
            if (!results.any((m) => m['member_id'] == member['member_id'])) {
              results.add(member);
            }
          }
        }
      }
    } catch (e) {
      print('전화번호 검색 오류: $e');
    }
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    print('✅ [LockerApiService] searchMembers() 완료: ${results.length}명 (소요시간: ${duration.inMilliseconds}ms)');
    
    return results;
  }

  // 특정 member_id 리스트 내에서 회원 검색
  static Future<List<Map<String, dynamic>>> searchMembersInIds({
    required String searchText,
    required List<int> memberIds,
  }) async {
    print('=== searchMembersInIds 시작 ===');
    print('검색어: $searchText');
    print('대상 member_id들: $memberIds');
    
    if (memberIds.isEmpty) {
      print('memberIds가 비어있음');
      return [];
    }
    
    final branchId = ApiService.getCurrentBranchId();
    print('branch_id: $branchId');
    List<Map<String, dynamic>> results = [];
    
    try {
      // member_id 리스트로 회원 정보 조회
      print('API 호출 중...');
      final members = await ApiService.getDataList(
        table: 'v3_members',
        where: [
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': 'IN', 'value': memberIds},
        ],
      );
      print('조회된 회원 수: ${members.length}');
      
      // 검색어로 필터링
      final cleanedSearch = searchText.replaceAll('-', '').toLowerCase();
      print('정제된 검색어: $cleanedSearch');
      
      for (final member in members) {
        // 이름 검색
        final memberName = (member['member_name'] ?? '').toString().toLowerCase();
        final memberPhone = (member['member_phone'] ?? '').toString();
        print('검사 중: ${member['member_id']} - $memberName - $memberPhone');
        
        if (memberName.contains(searchText.toLowerCase())) {
          print('  -> 이름 매칭!');
          results.add(member);
          continue;
        }
        
        // 전화번호 검색 (하이픈 제거 후 비교)
        final memberPhoneClean = memberPhone.replaceAll('-', '');
        if (memberPhoneClean.contains(cleanedSearch) || 
            memberPhone.contains(searchText)) {
          if (!results.any((m) => m['member_id'] == member['member_id'])) {
            print('  -> 전화번호 매칭!');
            results.add(member);
          }
        }
      }
      print('필터링 결과: ${results.length}명');
    } catch (e) {
      print('회원 검색 오류: $e');
      print('오류 상세: ${e.toString()}');
    }
    
    return results;
  }

  // 특정 member_id 리스트의 회원 정보 조회 (캐시용)
  static Future<List<Map<String, dynamic>>> getMembersByIds(List<int> memberIds) async {
    if (memberIds.isEmpty) return [];
    
    print('🔍 [LockerApiService] getMembersByIds() 호출 시작');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    print('  조회할 member_id들: $memberIds');
    print('  branch_id: $branchId');
    
    try {
      final members = await ApiService.getDataList(
        table: 'v3_members',
        where: [
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'member_id', 'operator': 'IN', 'value': memberIds},
        ],
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('✅ [LockerApiService] getMembersByIds() 완료: ${members.length}명 (소요시간: ${duration.inMilliseconds}ms)');
      return members;
    } catch (e) {
      print('❌ [LockerApiService] getMembersByIds() 오류: $e');
      return [];
    }
  }

  // 신규 락커 추가
  static Future<Map<String, dynamic>> addLocker(Map<String, dynamic> data) async {
    try {
      // branch_id 자동 추가
      final branchId = ApiService.getCurrentBranchId();
      final finalData = Map<String, dynamic>.from(data);
      if (branchId != null && !finalData.containsKey('branch_id')) {
        finalData['branch_id'] = branchId;
      }

      final requestData = {
        'operation': 'add',
        'table': 'v2_Locker_status',
        'data': finalData,
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
          throw Exception('락커 추가 실패: ${responseData['error']}');
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
        throw Exception('락커 추가 중 오류 발생: $e');
      }
    }
  }

  // 락커 삭제
  static Future<Map<String, dynamic>> deleteLocker(int lockerId) async {
    try {
      final requestData = {
        'operation': 'delete',
        'table': 'v2_Locker_status',
        'where': [
          {'field': 'locker_id', 'operator': '=', 'value': lockerId},
        ],
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
      throw Exception('락커 삭제 중 오류 발생: $e');
    }
  }

  // 여러 락커 일괄 업데이트 (개별 업데이트로 처리)
  static Future<Map<String, dynamic>> updateMultipleLockers({
    required List<int> lockerIds,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('일괄 업데이트 시작: ${lockerIds.length}개 락커');
      
      int successCount = 0;
      int failCount = 0;
      
      // 각 락커를 개별적으로 업데이트
      for (int lockerId in lockerIds) {
        try {
          print('락커 $lockerId 업데이트 중...');
          await updateLocker(lockerId: lockerId, data: data);
          successCount++;
          print('락커 $lockerId 업데이트 완료');
        } catch (e) {
          failCount++;
          print('락커 $lockerId 업데이트 실패: $e');
        }
      }
      
      print('일괄 업데이트 완료: 성공 $successCount개, 실패 $failCount개');
      
      if (failCount > 0) {
        return {
          'success': false,
          'message': '일부 락커 업데이트 실패 (성공: $successCount, 실패: $failCount)',
        };
      } else {
        return {
          'success': true,
          'message': '모든 락커 업데이트 완료 ($successCount개)',
        };
      }
    } catch (e) {
      throw Exception('일괄 업데이트 중 오류 발생: $e');
    }
  }

  // 락커 자동 채번 (스마트 추가/삭제) - 기존 데이터 재활용
  static Future<void> autoNumberLockers(int totalCount, [List<Map<String, dynamic>>? existingLockers]) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null) {
        throw Exception('지점 ID가 설정되지 않았습니다.');
      }

      print('자동 채번 시작: branchId=$branchId, totalCount=$totalCount');

      // 기존 데이터 재활용하거나 새로 조회
      final lockers = existingLockers ?? await getLockerStatus();
      print('현재 락커 개수: ${lockers.length}개');

      // 락커 번호별로 정리 (중복 체크용)
      final existingNumbers = <String, Map<String, dynamic>>{};
      for (var locker in lockers) {
        final lockerName = locker['locker_name'].toString();
        existingNumbers[lockerName] = locker;
      }

      if (totalCount > lockers.length) {
        // 락커 추가 필요
        print('락커 ${totalCount - lockers.length}개 추가 필요');
        
        for (int i = 1; i <= totalCount; i++) {
          final lockerName = i.toString();
          
          if (!existingNumbers.containsKey(lockerName)) {
            try {
              print('락커 $i 추가 중...');
              final lockerData = {
                'locker_name': lockerName,
                'locker_type': '일반',
                'locker_zone': '미지정',
                'locker_price': 0,
                'branch_id': branchId,
                'registered_at': DateTime.now().toIso8601String(),
              };
              await addLocker(lockerData);
              print('락커 $i 추가 완료');
            } catch (e) {
              print('락커 $i 추가 실패: $e');
            }
          }
        }
      } else if (totalCount < lockers.length) {
        // 락커 삭제 필요 (큰 번호부터)
        print('락커 ${lockers.length - totalCount}개 삭제 필요');
        
        // 삭제 대상 찾기 (totalCount+1번부터)
        final lockersToDelete = <Map<String, dynamic>>[];
        for (var locker in lockers) {
          final lockerNumber = int.tryParse(locker['locker_name'].toString());
          if (lockerNumber != null && lockerNumber > totalCount) {
            lockersToDelete.add(locker);
          }
        }
        
        // 배정된 락커가 있는지 확인
        final assignedLockers = lockersToDelete.where((locker) => locker['member_id'] != null).toList();
        if (assignedLockers.isNotEmpty) {
          final assignedNumbers = assignedLockers.map((l) => l['locker_name']).join(', ');
          throw Exception('삭제 대상 락커에 배정된 회원이 있습니다. (락커 번호: $assignedNumbers)\n반납 처리 후 삭제 가능합니다.');
        }
        
        // 삭제 실행
        for (var locker in lockersToDelete) {
          try {
            print('락커 ${locker["locker_name"]} 삭제 중...');
            await deleteLocker(locker['locker_id']);
            print('락커 ${locker["locker_name"]} 삭제 완료');
          } catch (e) {
            print('락커 ${locker["locker_name"]} 삭제 실패: $e');
          }
        }
      } else {
        print('락커 개수가 동일합니다. 변경 사항 없음');
      }
      
      print('자동 채번 완료');
    } catch (e) {
      print('자동 채번 오류: $e');
      throw Exception('락커 자동 채번 중 오류 발생: $e');
    }
  }


  // 락커 청구서 조회 (정기결제(월별) 결제상태 확인용)
  static Future<List<Map<String, dynamic>>> getLockerBills({
    required int memberId,
    required int lockerId,
  }) async {
    final branchId = ApiService.getCurrentBranchId();
    
    return ApiService.getDataList(
      table: 'v2_Locker_bill',
      where: [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'locker_id', 'operator': '=', 'value': lockerId},
        if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ],
      orderBy: [{'field': 'locker_bill_start', 'direction': 'DESC'}],
    );
  }

  // 모든 락커 청구서 조회 (프론트엔드 계산용)
  static Future<List<Map<String, dynamic>>> getAllLockerBills() async {
    print('🔍 [LockerApiService] getAllLockerBills() 호출 시작');
    final startTime = DateTime.now();
    
    final branchId = ApiService.getCurrentBranchId();
    
    print('🔍 [LockerApiService] v2_Locker_bill 테이블 전체 조회 중...');
    final result = await ApiService.getDataList(
      table: 'v2_Locker_bill',
      where: [
        if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ],
      orderBy: [{'field': 'locker_bill_start', 'direction': 'DESC'}],
    );
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    print('✅ [LockerApiService] getAllLockerBills() 완료: ${result.length}개 (소요시간: ${duration.inMilliseconds}ms)');
    
    return result;
  }

  // 회원의 크레딧 계약 조회 (잔액이 충분한 계약 찾기)
  static Future<Map<String, dynamic>?> findCreditContract({
    required int memberId,
    required int totalPrice,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final today = DateTime.now();
      
      // 해당 회원의 활성 크레딧 계약 조회
      final contracts = await ApiService.getDataList(
        table: 'v3_contract_history',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_status', 'operator': '=', 'value': '활성'},
          {'field': 'contract_credit', 'operator': '>', 'value': 0},
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        orderBy: [
          {'field': 'contract_credit_expiry_date', 'direction': 'ASC'},
          {'field': 'contract_history_id', 'direction': 'DESC'}
        ],
      );

      // 만료되지 않은 계약들 필터링
      final validContracts = contracts.where((contract) {
        final expiryDate = contract['contract_credit_expiry_date'];
        if (expiryDate == null) return false;
        
        try {
          final expiry = DateTime.parse(expiryDate);
          return expiry.isAfter(today);
        } catch (e) {
          return false;
        }
      }).toList();

      // 각 계약의 현재 잔액 계산
      for (var contract in validContracts) {
        final contractHistoryId = contract['contract_history_id'];
        
        // 해당 계약의 가장 최근 bill 조회
        final bills = await ApiService.getDataList(
          table: 'v2_bills',
          where: [
            {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
            if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
          ],
          orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
          limit: 1,
        );

        if (bills.isNotEmpty) {
          contract['current_balance'] = bills.first['bill_balance_after'] ?? 0;
        } else {
          contract['current_balance'] = contract['contract_credit'] ?? 0;
        }
      }

      // 잔액이 충분한 계약들 중에서 만료일이 가장 임박한 것 선택
      final sufficientContracts = validContracts.where((contract) {
        final balance = contract['current_balance'] ?? 0;
        return balance >= totalPrice;
      }).toList();

      if (sufficientContracts.isEmpty) return null;

      // 만료일 기준으로 정렬 후 잔액이 가장 높은 것 선택
      sufficientContracts.sort((a, b) {
        final dateComparison = DateTime.parse(a['contract_credit_expiry_date'])
            .compareTo(DateTime.parse(b['contract_credit_expiry_date']));
        if (dateComparison != 0) return dateComparison;
        
        final balanceA = a['current_balance'] ?? 0;
        final balanceB = b['current_balance'] ?? 0;
        return balanceB.compareTo(balanceA);
      });

      return sufficientContracts.first;
    } catch (e) {
      print('크레딧 계약 조회 실패: $e');
      return null;
    }
  }

  // 회원의 크레딧 잔액 조회
  static Future<Map<String, dynamic>> getMemberCreditInfo(int memberId) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final today = DateTime.now();
      
      // 해당 회원의 활성 크레딧 계약 조회
      final contracts = await ApiService.getDataList(
        table: 'v3_contract_history',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': memberId},
          {'field': 'contract_history_status', 'operator': '=', 'value': '활성'},
          {'field': 'contract_credit', 'operator': '>', 'value': 0},
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );

      if (contracts.isEmpty) {
        return {
          'hasCreditContract': false,
          'totalBalance': 0,
          'message': '사용 가능한 크레딧 계약이 없습니다.'
        };
      }

      // 만료되지 않은 계약들 필터링 및 잔액 계산
      int totalBalance = 0;
      int validContracts = 0;
      
      for (var contract in contracts) {
        final expiryDate = contract['contract_credit_expiry_date'];
        if (expiryDate != null) {
          try {
            final expiry = DateTime.parse(expiryDate);
            if (expiry.isAfter(today)) {
              // 해당 계약의 현재 잔액 계산
              final contractHistoryId = contract['contract_history_id'];
              final bills = await ApiService.getDataList(
                table: 'v2_bills',
                where: [
                  {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
                  if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
                ],
                orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
                limit: 1,
              );

              int currentBalance;
              if (bills.isNotEmpty) {
                currentBalance = bills.first['bill_balance_after'] ?? 0;
              } else {
                currentBalance = contract['contract_credit'] ?? 0;
              }
              
              if (currentBalance > 0) {
                totalBalance += currentBalance;
                validContracts++;
              }
            }
          } catch (e) {
            print('만료일 파싱 오류: $e');
          }
        }
      }

      return {
        'hasCreditContract': validContracts > 0,
        'totalBalance': totalBalance,
        'validContracts': validContracts,
        'message': validContracts > 0 
          ? '사용 가능한 크레딧: ${totalBalance}원 ($validContracts개 계약)'
          : '유효한 크레딧 잔액이 없습니다.'
      };
    } catch (e) {
      print('크레딧 정보 조회 실패: $e');
      return {
        'hasCreditContract': false,
        'totalBalance': 0,
        'message': '크레딧 정보 조회 실패'
      };
    }
  }

  // 크레딧 결제 처리 (v2_bills 테이블 업데이트)
  static Future<int?> processCreditPayment({
    required int memberId,
    required String memberName,
    required String lockerName,
    required String lockerStart,
    required String lockerEnd,
    required String paymentFrequency,
    required int totalPrice,
  }) async {
    try {
      // 충분한 잔액을 가진 크레딧 계약 찾기
      final creditContract = await findCreditContract(
        memberId: memberId,
        totalPrice: totalPrice,
      );

      if (creditContract == null) {
        // 크레딧 계약이 아예 없는지 확인
        final allContracts = await ApiService.getDataList(
          table: 'v3_contract_history',
          where: [
            {'field': 'member_id', 'operator': '=', 'value': memberId},
            {'field': 'contract_history_status', 'operator': '=', 'value': '활성'},
            {'field': 'contract_credit', 'operator': '>', 'value': 0},
            if (ApiService.getCurrentBranchId() != null) 
              {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
          ],
        );
        
        if (allContracts.isEmpty) {
          throw Exception('사용 가능한 크레딧 계약이 없습니다. 먼저 크레딧을 충전해주세요.');
        } else {
          throw Exception('크레딧 잔액이 부족합니다. 필요 금액: ${totalPrice}원');
        }
      }

      final contractHistoryId = creditContract['contract_history_id'];
      final currentBalance = creditContract['current_balance'] ?? 0;
      final branchId = ApiService.getCurrentBranchId();
      final now = DateTime.now();

      // bill_text 생성 (월별결제인 경우 해당 월의 마지막 날짜 사용)
      String billText;
      if (paymentFrequency == '정기결제(월별)') {
        final startDate = DateTime.parse(lockerStart);
        final lastDayOfMonth = DateTime(startDate.year, startDate.month + 1, 0);
        final endDateStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);
        billText = '락커($lockerName)_$lockerStart~$endDateStr';
      } else {
        billText = '락커($lockerName)_$lockerStart~$lockerEnd';
      }

      // v2_bills 테이블에 새 레코드 추가
      final billData = {
        'branch_id': branchId,
        'member_id': memberId,
        'bill_date': now.toIso8601String().split('T')[0],
        'bill_type': '락커결제',
        'bill_text': billText,
        'bill_totalamt': -totalPrice,
        'bill_deduction': 0,
        'bill_netamt': -totalPrice,
        'bill_timestamp': now.toIso8601String(),
        'bill_balance_before': currentBalance,
        'bill_balance_after': currentBalance - totalPrice,
        'bill_status': '결제완료',
        'contract_history_id': contractHistoryId,
        'contract_credit_expiry_date': creditContract['contract_credit_expiry_date'],
      };

      final billResult = await ApiService.addBillsData(billData);
      print('Bills 추가 결과: $billResult');
      
      if (billResult['success'] == true) {
        // 다양한 경로에서 bill_id 추출 시도
        dynamic billIdRaw = billResult['bill_id'] ?? 
                           billResult['data']?['bill_id'] ?? 
                           billResult['insertId'] ?? 
                           billResult['insert_id'];
        
        print('추출된 billIdRaw: $billIdRaw (타입: ${billIdRaw.runtimeType})');
        
        if (billIdRaw == null) {
          print('bill_id를 찾을 수 없음. 전체 응답: $billResult');
          throw Exception('bill_id를 찾을 수 없습니다');
        }
        
        // 문자열인 경우 int로 변환
        int billId;
        if (billIdRaw is String) {
          billId = int.parse(billIdRaw);
        } else if (billIdRaw is int) {
          billId = billIdRaw;
        } else {
          throw Exception('bill_id 형식이 올바르지 않습니다: $billIdRaw');
        }
        
        print('최종 bill_id: $billId');
        return billId;
      } else {
        throw Exception('크레딧 결제 처리 실패: ${billResult['error']}');
      }
    } catch (e) {
      print('크레딧 결제 처리 실패: $e');
      throw Exception('크레딧 결제 처리 중 오류 발생: $e');
    }
  }

  // 락커 청구서 추가 (bill_id 포함 - 월별과금용)
  static Future<Map<String, dynamic>> addLockerBillWithBillId({
    required String billType,
    required int lockerId,
    required String lockerName,
    required int memberId,
    required String lockerStart,
    required String lockerEnd,
    required String paymentMethod,
    required int totalPrice,
    required int deduction,
    required int netAmount,
    required int lastMonthMinutes,
    required double discountRatio,
    required String remark,
    int? billId,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final now = DateTime.now();
      
      // bill_text 생성
      final billText = '락커($lockerName)_$lockerStart~$lockerEnd';
      
      final lockerBillData = {
        'locker_bill_type': billType,
        'locker_id': lockerId,
        'locker_name': lockerName,
        'payment_method': paymentMethod,
        'locker_bill_date': now.toIso8601String().split('T')[0],
        'member_id': memberId,
        'last_month_TS_min': lastMonthMinutes,
        'locker_discount_apply_ratio': discountRatio.toStringAsFixed(2),
        'locker_bill_total_amt': totalPrice,
        'locker_bill_deduction': deduction,
        'locker_bill_netamt': netAmount,
        'locker_remark': remark,
        'locker_bill_remark': remark,
        'branch_id': branchId,
        'locker_bill_start': lockerStart,
        'locker_bill_end': lockerEnd,
        'locker_bill_status': '결제완료',
        'bill_text': billText,
        if (billId != null) 'bill_id': billId,
      };
      
      print('=== v2_Locker_bill 저장 (bill_id 포함) ===');
      print('저장 데이터: $lockerBillData');
      
      // v2_Locker_bill 테이블에 직접 저장
      final response = await http.post(
        Uri.parse(ApiService.baseUrl),
        headers: ApiService.headers,
        body: json.encode({
          'operation': 'add',
          'table': 'v2_Locker_bill',
          'data': lockerBillData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          print('✅ v2_Locker_bill 저장 성공');
          return result;
        } else {
          throw Exception('v2_Locker_bill 저장 실패: ${result['message']}');
        }
      } else {
        throw Exception('v2_Locker_bill 저장 실패: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ v2_Locker_bill 저장 오류: $e');
      rethrow;
    }
  }

  // 락커 청구서 직접 추가 (월별과금용 - 기존 메서드 유지)
  static Future<Map<String, dynamic>> addLockerBillDirect({
    required String billType,
    required int lockerId,
    required String lockerName,
    required int memberId,
    required String lockerStart,
    required String lockerEnd,
    required String paymentMethod,
    required int totalPrice,
    required int deduction,
    required int netAmount,
    required int lastMonthMinutes,
    required double discountRatio,
    required String remark,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final now = DateTime.now();
      
      // bill_text 생성
      final billText = '락커($lockerName)_$lockerStart~$lockerEnd';
      
      final lockerBillData = {
        'locker_bill_type': billType,
        'locker_id': lockerId,
        'locker_name': lockerName,
        'payment_method': paymentMethod,
        'locker_bill_date': now.toIso8601String().split('T')[0],
        'member_id': memberId,
        'last_month_TS_min': lastMonthMinutes,
        'locker_discount_apply_ratio': discountRatio.toStringAsFixed(2),
        'locker_bill_total_amt': totalPrice,
        'locker_bill_deduction': deduction,
        'locker_bill_netamt': netAmount,
        'locker_remark': remark,
        'locker_bill_remark': remark,
        'branch_id': branchId,
        'locker_bill_start': lockerStart,
        'locker_bill_end': lockerEnd,
        'locker_bill_status': '결제완료',
        'bill_text': billText,
      };
      
      print('=== v2_Locker_bill 직접 저장 ===');
      print('저장 데이터: $lockerBillData');
      
      // v2_Locker_bill 테이블에 직접 저장
      final response = await http.post(
        Uri.parse(ApiService.baseUrl),
        headers: ApiService.headers,
        body: json.encode({
          'operation': 'add',
          'table': 'v2_Locker_bill',
          'data': lockerBillData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          print('✅ v2_Locker_bill 저장 성공');
          return result;
        } else {
          throw Exception('v2_Locker_bill 저장 실패: ${result['message']}');
        }
      } else {
        throw Exception('v2_Locker_bill 저장 실패: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ v2_Locker_bill 저장 오류: $e');
      rethrow;
    }
  }

  // 락커 청구서 추가 (v2_Locker_bills)
  static Future<Map<String, dynamic>> addLockerBill({
    required int lockerId,
    required int memberId,
    required String lockerName,
    required String lockerStart,
    required String lockerEnd,
    required String paymentFrequency,
    required String paymentMethod,
    required int totalPrice,
    required double discountRatio,
    required String remark,
    int? billId,
    String billType = '신규배정', // 기본값은 신규배정, 미납결제 시 변경 가능
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final now = DateTime.now();
      
      // 종료일 처리 (월별결제인 경우 해당 월의 마지막 날)
      String actualEndDate = lockerEnd;
      if (paymentFrequency == '정기결제(월별)') {
        final startDate = DateTime.parse(lockerStart);
        final lastDayOfMonth = DateTime(startDate.year, startDate.month + 1, 0);
        actualEndDate = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);
      }
      
      // bill_text 생성
      String billText;
      if (paymentFrequency == '정기결제(월별)') {
        billText = '락커($lockerName)_$lockerStart~$actualEndDate';
      } else {
        billText = '락커($lockerName)_$lockerStart~$lockerEnd';
      }
      
      final lockerBillData = {
        'locker_bill_type': billType,
        'locker_id': lockerId,
        'locker_name': lockerName,  // 락커명 필드 추가
        'payment_method': paymentMethod,  // 결제수단 필드 추가
        'locker_bill_date': now.toIso8601String().split('T')[0],  // 변경: locker_bill_month → locker_bill_date
        'member_id': memberId,
        'last_month_TS_min': 0,
        'locker_discount_apply_ratio': 0,
        'locker_bill_total_amt': totalPrice,
        'locker_bill_deduction': 0,
        'locker_bill_netamt': totalPrice,
        'locker_remark': remark,
        if (remark.isNotEmpty) 'locker_bill_remark': remark,
        'branch_id': branchId,
        'locker_bill_start': lockerStart,
        'locker_bill_end': actualEndDate,
        'locker_bill_status': '결제완료',  // 추가
        'bill_text': billText,  // 추가
        if (billId != null) 'bill_id': billId,
      };

      print('Locker Bill 데이터: $lockerBillData');
      
      // v2_Locker_bill 테이블에 직접 추가 (단수형)
      final requestData = {
        'operation': 'add',
        'table': 'v2_Locker_bill',
        'data': lockerBillData,
      };

      final response = await http.post(
        Uri.parse(ApiService.baseUrl),
        headers: ApiService.headers,
        body: json.encode(requestData),
      ).timeout(Duration(seconds: 15));

      print('HTTP 응답 상태 코드: ${response.statusCode}');
      print('HTTP 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Locker Bill 추가 결과: $responseData');
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw Exception('락커 청구서 추가 실패: ${responseData['error']}');
        }
      } else {
        final errorBody = response.body;
        print('HTTP 오류 응답 본문: $errorBody');
        throw Exception('HTTP 오류: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('락커 청구서 추가 실패: $e');
      throw Exception('락커 청구서 추가 중 오류 발생: $e');
    }
  }

  // 락커 계약 이력 추가
  static Future<Map<String, dynamic>> addLockerContractHistory({
    required int memberId,
    required String memberName,
    required String lockerName,
    required String lockerStart,
    required String lockerEnd,
    required String payMethod,
    required String paymentFrequency,
    required int totalPrice,
    int? billId,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      final now = DateTime.now();
      
      // contract_name 생성 (월별결제인 경우 해당 월의 마지막 날짜 사용)
      String contractName;
      if (paymentFrequency == '정기결제(월별)') {
        final startDate = DateTime.parse(lockerStart);
        final lastDayOfMonth = DateTime(startDate.year, startDate.month + 1, 0);
        final endDateStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);
        contractName = '락커(${lockerName})_${lockerStart}~${endDateStr}';
      } else {
        contractName = '락커(${lockerName})_${lockerStart}~${lockerEnd}';
      }

      final contractData = {
        'branch_id': branchId,
        'member_id': memberId,
        'member_name': memberName,
        'contract_type': paymentFrequency == '일시납부' ? '락커 일괄결제' : '락커 월별결제',
        'contract_id': 'locker_${lockerName.padLeft(3, '0')}',
        'contract_name': contractName,
        'contract_date': now.toIso8601String().split('T')[0],
        'contract_register': now.toIso8601String(),
        'payment_type': payMethod,
        'contract_history_status': '활성',
        'price': totalPrice,
        'contract_credit': 0,
        'contract_LS_min': 0,
        'contract_games': 0,
        'contract_TS_min': 0,
        'contract_term_month': 0,
        if (billId != null) 'bill_id': billId,
      };

      print('Contract History 데이터: $contractData');
      final result = await ApiService.addContractHistoryData(contractData);
      print('Contract History 추가 결과: $result');
      return result;
    } catch (e) {
      print('락커 계약 이력 추가 실패: $e');
      throw Exception('락커 계약 이력 추가 중 오류 발생: $e');
    }
  }

  // 락커 결제 정보 조회 (반납 시 사용)
  static Future<Map<String, dynamic>> getLockerPaymentInfo({
    required int memberId,
    required String lockerName,
    required String returnDate,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      // 반납일자가 포함된 활성 청구서 찾기
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'locker_name', 'operator': '=', 'value': lockerName},
        {'field': 'locker_bill_status', 'operator': '=', 'value': '결제완료'},
        {'field': 'locker_bill_start', 'operator': '<=', 'value': returnDate},
        {'field': 'locker_bill_end', 'operator': '>=', 'value': returnDate},
        if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ];
      
      final bills = await ApiService.getDataList(
        table: 'v2_Locker_bill',
        where: whereConditions,
        orderBy: [{'field': 'locker_bill_id', 'direction': 'DESC'}],
        limit: 1,
      );
      
      if (bills.isEmpty) {
        return {'success': false, 'message': '결제 정보를 찾을 수 없습니다.'};
      }
      
      final bill = bills.first;
      
      // 결제방법별 사용 가능한 환불 옵션 결정
      List<String> availableRefundMethods = [];
      final paymentMethod = bill['payment_method'] ?? '';
      
      if (paymentMethod == '카드결제') {
        availableRefundMethods = ['현금', '카드취소', '환불불가'];
      } else if (paymentMethod == '크레딧 결제') {
        availableRefundMethods = ['현금', '크레딧환불', '환불불가'];
      } else {  // 현금결제
        availableRefundMethods = ['현금', '환불불가'];
      }
      
      return {
        'success': true,
        'bill': bill,
        'payment_method': paymentMethod,
        'available_refund_methods': availableRefundMethods,
        'bill_summary': {
          'locker_name': bill['locker_name'],
          'payment_method': paymentMethod,
          'locker_bill_start': bill['locker_bill_start'],
          'locker_bill_end': bill['locker_bill_end'],
          'locker_bill_total_amt': bill['locker_bill_total_amt'],
          'locker_bill_netamt': bill['locker_bill_netamt'],
          'locker_remark': bill['locker_remark'],
          'bill_id': bill['bill_id'], // 크레딧 환불 처리를 위해 필요
        }
      };
    } catch (e) {
      print('락커 결제 정보 조회 실패: $e');
      return {'success': false, 'message': '결제 정보 조회 중 오류 발생: $e'};
    }
  }

  // 크레딧 환불 처리 (v2_bills 테이블에 환불 레코드 추가)
  static Future<Map<String, dynamic>> processCreditRefund({
    required int billId,
    required String lockerName,
    required double refundAmount,
    required String returnDate,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      print('🔍 [DEBUG] 크레딧 환불 처리 시작');
      print('🔍 [DEBUG] billId: $billId');
      print('🔍 [DEBUG] lockerName: $lockerName');
      print('🔍 [DEBUG] refundAmount: $refundAmount');
      print('🔍 [DEBUG] returnDate: $returnDate');
      
      // 1. 해당 bill_id로 contract_history_id 조회
      final billData = await ApiService.getDataList(
        table: 'v2_bills',
        where: [
          {'field': 'bill_id', 'operator': '=', 'value': billId},
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        limit: 1,
      );
      
      if (billData.isEmpty) {
        return {'success': false, 'message': '원본 청구서를 찾을 수 없습니다.'};
      }
      
      final originalBill = billData.first;
      final contractHistoryId = originalBill['contract_history_id'];
      final memberId = originalBill['member_id'];
      final contractCreditExpiryDate = originalBill['contract_credit_expiry_date'];
      
      print('🔍 [DEBUG] contract_history_id: $contractHistoryId');
      print('🔍 [DEBUG] member_id: $memberId');
      
      // 2. 해당 contract_history_id의 가장 마지막 bill_id의 bill_balance_after 조회
      final latestBills = await ApiService.getDataList(
        table: 'v2_bills',
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
        limit: 1,
      );
      
      if (latestBills.isEmpty) {
        return {'success': false, 'message': '계약 이력을 찾을 수 없습니다.'};
      }
      
      final latestBill = latestBills.first;
      final billBalanceBefore = latestBill['bill_balance_after'] ?? 0;
      final billBalanceAfter = billBalanceBefore + refundAmount;
      
      print('🔍 [DEBUG] bill_balance_before: $billBalanceBefore');
      print('🔍 [DEBUG] bill_balance_after: $billBalanceAfter');
      
      // 3. v2_bills에 환불 레코드 추가
      final refundBillData = {
        'member_id': memberId,
        'bill_date': returnDate,
        'bill_type': '락커환불',
        'bill_text': '락커($lockerName)취소_$returnDate',
        'bill_totalamt': refundAmount,
        'bill_deduction': 0,
        'bill_netamt': refundAmount,
        'bill_balance_before': billBalanceBefore,
        'bill_balance_after': billBalanceAfter,
        'bill_status': '결제완료',
        'contract_history_id': contractHistoryId,
        'contract_credit_expiry_date': contractCreditExpiryDate,
        if (branchId != null) 'branch_id': branchId,
      };
      
      print('🔍 [DEBUG] 환불 레코드 데이터: $refundBillData');
      
      final result = await ApiService.addBillsData(refundBillData);
      
      print('🔍 [DEBUG] 환불 레코드 추가 결과: $result');
      
      if (result['success'] == true) {
        return {
          'success': true,
          'message': '크레딧 환불이 완료되었습니다.',
          'refund_bill_id': result['insertId'],
          'new_balance': billBalanceAfter,
        };
      } else {
        return {'success': false, 'message': '환불 레코드 추가 실패: ${result['message']}'};
      }
      
    } catch (e) {
      print('크레딧 환불 처리 실패: $e');
      return {'success': false, 'message': '크레딧 환불 처리 중 오류 발생: $e'};
    }
  }

  // 락커 청구서 반납 업데이트 (반납 시)
  static Future<Map<String, dynamic>> updateLockerBillForReturn({
    required int memberId,
    required String lockerName,
    required String returnDate,  // 반납일자
    required String refundType,
    required double refundAmount,
  }) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      print('🔍 [DEBUG] 락커 청구서 반납 업데이트 시작');
      print('🔍 [DEBUG] memberId: $memberId');
      print('🔍 [DEBUG] lockerName: $lockerName');
      print('🔍 [DEBUG] returnDate: $returnDate');
      print('🔍 [DEBUG] refundType: $refundType');
      print('🔍 [DEBUG] refundAmount: $refundAmount');
      print('🔍 [DEBUG] branchId: $branchId');
      
      // 반납일자가 포함된 청구서 찾기 (locker_bill_start <= returnDate <= locker_bill_end)
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId},
        {'field': 'locker_name', 'operator': '=', 'value': lockerName},  // locker_id 대신 locker_name으로 검색
        {'field': 'locker_bill_status', 'operator': '=', 'value': '결제완료'},
        {'field': 'locker_bill_start', 'operator': '<=', 'value': returnDate},
        {'field': 'locker_bill_end', 'operator': '>=', 'value': returnDate},
        if (branchId != null) {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ];
      
      print('🔍 [DEBUG] 검색 조건: $whereConditions');
      
      final bills = await ApiService.getDataList(
        table: 'v2_Locker_bill',
        where: whereConditions,
        orderBy: [{'field': 'locker_bill_id', 'direction': 'DESC'}],
        limit: 1,
      );
      
      print('🔍 [DEBUG] 검색된 청구서 개수: ${bills.length}');
      if (bills.isNotEmpty) {
        print('🔍 [DEBUG] 찾은 청구서: ${bills.first}');
      }

      if (bills.isNotEmpty) {
        final billId = bills.first['locker_bill_id'];
        
        final updateData = {
          'locker_cancel_date': returnDate,
          'locker_refund_type': refundType,
          'locker_refund_amt': refundAmount,
          'locker_bill_end': returnDate,      // 종료일을 반납일로 변경
          'locker_bill_status': '반납완료',    // 상태를 반납완료로 변경
        };
        
        final updateWhere = [
          {'field': 'locker_bill_id', 'operator': '=', 'value': billId},
        ];
        
        print('🔍 [DEBUG] 업데이트할 billId: $billId');
        print('🔍 [DEBUG] 업데이트 데이터: $updateData');
        print('🔍 [DEBUG] 업데이트 조건: $updateWhere');
        
        final result = await ApiService.updateData(
          table: 'v2_Locker_bill',
          data: updateData,
          where: updateWhere,
        );
        
        print('🔍 [DEBUG] 업데이트 결과: $result');
        return result;
      } else {
        print('❌ [DEBUG] 해당 반납일자($returnDate)가 포함된 청구서를 찾을 수 없음');
        return {'success': false, 'message': '해당 반납일자가 포함된 청구서를 찾을 수 없습니다'};
      }
    } catch (e) {
      print('❌ [DEBUG] 락커 청구서 반납 업데이트 실패: $e');
      print('❌ [DEBUG] Stack trace: ${StackTrace.current}');
      return {'success': false, 'message': '락커 청구서 반납 업데이트 중 오류 발생: $e'};
    }
  }
}