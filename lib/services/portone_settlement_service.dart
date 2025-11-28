import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// 포트원 정산 서비스
/// 
/// 수수료 정책은 포트원 관리자 콘솔 또는 API를 통해 설정됩니다:
/// 1. 계약(Contract) 관리: 중개수수료 설정 (정률/정액)
/// 2. 추가수수료 정책: 추가수수료 정책 생성
/// 3. 할인 분담 정책: 할인 분담률 설정
/// 
/// 정산 내역 조회 시 포트원 API가 자동으로 계산된 수수료를 제공합니다.
class PortoneSettlementService {
  // 포트원 API 베이스 URL
  static const String portoneApiBaseUrl = 'https://api.portone.io';
  
  // 포트원 API Secret (환경변수나 설정에서 가져와야 함)
  // TODO: 실제 운영 환경에서는 환경변수나 보안 저장소에서 가져와야 합니다
  static String? _apiSecret;
  
  /// API Secret 설정
  static void setApiSecret(String secret) {
    _apiSecret = secret;
  }
  
  /// API Secret 가져오기 (없으면 null 반환)
  static String? getApiSecret() {
    return _apiSecret;
  }
  
  /// 지점별 정산 내역 조회 (포트원 API 사용)
  /// 
  /// [branchId] 지점 ID (파트너 ID로 사용)
  /// [from] 조회 시작 날짜
  /// [to] 조회 종료 날짜
  static Future<Map<String, dynamic>> getBranchSettlements({
    required String branchId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int pageSize = 50,
  }) async {
    print('=== PortoneSettlementService.getBranchSettlements 호출 ===');
    print('지점 ID: $branchId');
    print('조회 기간: ${from.toString().split(' ')[0]} ~ ${to.toString().split(' ')[0]}');
    print('페이지: $page, 페이지 크기: $pageSize');
    
    try {
      // API Secret 확인
      print('포트원 API Secret 확인 중...');
      if (_apiSecret == null) {
        print('⚠️ API Secret이 설정되지 않았습니다. DB에서 조회합니다.');
        // API Secret이 없으면 DB에서 조회 (폴백)
        return await _getBranchSettlementsFromDB(
          branchId: branchId,
          from: from,
          to: to,
          page: page,
          pageSize: pageSize,
        );
      }
      print('✅ API Secret이 설정되어 있습니다. 포트원 API를 호출합니다.');
      
      // 포트원 파트너 정산 API 호출
      // 포트원 API는 GET 메서드를 사용하며, requestBody를 query 파라미터로 변환해야 함
      final requestBody = {
        'filter': {
          'partnerIds': [branchId], // 지점 ID를 파트너 ID로 사용
          'settlementDates': _generateDateRange(from, to),
        },
        'page': {
          'number': page,
          'size': pageSize,
        },
        'isForTest': false,
      };
      
      // GET 요청이므로 body를 query 파라미터로 변환
      // 포트원 API는 requestBody를 query string으로 받을 수 있음 (x-portone-query-or-body: enabled)
      // JSON을 URL 인코딩하여 query 파라미터로 전달
      final requestBodyJson = jsonEncode(requestBody);
      final encodedRequestBody = Uri.encodeComponent(requestBodyJson);
      
      final url = Uri.parse('$portoneApiBaseUrl/platform/partner-settlements?requestBody=$encodedRequestBody');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'PortOne $_apiSecret', // 포트원 V2 API는 PortOne 스키마 사용
          'Content-Type': 'application/json',
        },
      );
      
      // 디버깅: API 요청/응답 로그
      print('=== 포트원 정산 내역 API 호출 ===');
      print('요청 URL: ${url.toString()}');
      print('요청 Body (JSON): ${jsonEncode(requestBody)}');
      print('응답 Status Code: ${response.statusCode}');
      print('응답 Body: ${response.body}');
      print('================================');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('파싱된 데이터: ${jsonEncode(data)}');
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        print('정산 내역 건수: ${items.length}');
        
        // 포트원 API 응답을 중심으로 정산 내역 구성
        // 정산 금액, 수수료 등은 포트원 API에서 자동 계산된 값 사용
        final settlementItems = <Map<String, dynamic>>[];
        int totalPaymentAmount = 0;
        int totalPlatformFee = 0;
        int totalPlatformFeeVat = 0;
        int totalBranchAmount = 0;
        int totalVat = 0;
        int totalSupply = 0;
        
        // 모든 결제 ID를 수집하여 한 번에 DB 조회 (성능 개선)
        final paymentIds = <String>[];
        for (var settlement in items) {
          final payment = settlement['payment'] as Map<String, dynamic>? ?? {};
          final paymentId = payment['id'] as String? ?? '';
          if (paymentId.isNotEmpty) {
            paymentIds.add(paymentId);
          }
        }
        
        // DB에서 결제 상세 정보 일괄 조회 (API 응답에 없는 비즈니스 정보만)
        print('DB 조회할 paymentIds: $paymentIds');
        final paymentDetailsMap = await _getPaymentDetailsBatch(paymentIds);
        print('DB에서 조회된 결제 정보 건수: ${paymentDetailsMap.length}');
        
        for (var settlement in items) {
          final amount = settlement['amount'] as Map<String, dynamic>? ?? {};
          final payment = settlement['payment'] as Map<String, dynamic>? ?? {};
          final paymentId = payment['id'] as String? ?? '';
          
          // 디버깅: 각 정산 항목 상세 정보
          print('--- 정산 항목 #${settlementItems.length + 1} ---');
          print('정산 ID: ${settlement['id']}');
          print('결제 ID: $paymentId');
          print('정산 타입: ${settlement['type']}');
          print('정산 상태: ${settlement['status']}');
          print('정산일: ${settlement['settlementDate']}');
          print('금액 정보: ${jsonEncode(amount)}');
          print('결제 정보: ${jsonEncode(payment)}');
          
          // 포트원 API에서 제공하는 정산 정보 (신뢰할 수 있는 소스)
          final paymentAmount = amount['payment'] as int? ?? 0;
          final platformFee = amount['platformFee'] as int? ?? 0;
          final platformFeeVat = amount['platformFeeVat'] as int? ?? 0;
          final settlementAmount = amount['settlement'] as int? ?? 0;
          final paymentVat = amount['paymentVat'] as int? ?? 0;
          final paymentSupply = amount['paymentSupply'] as int? ?? 0;
          
          // DB에서 가져온 보완 정보 (API 응답에 없는 비즈니스 정보)
          final paymentDetail = paymentDetailsMap[paymentId] ?? <String, dynamic>{};
          print('DB 보완 정보: ${jsonEncode(paymentDetail)}');
          
          totalPaymentAmount += paymentAmount;
          totalPlatformFee += platformFee;
          totalPlatformFeeVat += platformFeeVat;
          totalBranchAmount += settlementAmount;
          totalVat += paymentVat;
          totalSupply += paymentSupply;
          
          // 포트원 API 응답을 중심으로 데이터 구성
          settlementItems.add({
            'settlementId': settlement['id'],
            'paymentId': paymentId,
            'txId': payment['txId'] ?? paymentDetail['txId'], // API 우선, 없으면 DB
            'orderName': payment['orderName'] ?? paymentDetail['orderName'] ?? '',
            // 정산 금액 정보는 포트원 API에서 제공 (신뢰할 수 있는 소스)
            'paymentAmount': paymentAmount,
            'paymentSupply': paymentSupply,
            'paymentVat': paymentVat,
            'platformFee': platformFee,
            'platformFeeVat': platformFeeVat,
            'branchAmount': settlementAmount,
            // 정산 일자 및 상태는 포트원 API에서 관리
            'settlementDate': settlement['settlementDate'],
            'settlementStatus': settlement['status'],
            'paymentDate': payment['paidAt'] ?? paymentDetail['paymentDate'],
            'paymentMethod': payment['method']?['type'] ?? paymentDetail['paymentMethod'] ?? '',
            'paymentProvider': payment['method']?['provider'] ?? paymentDetail['paymentProvider'] ?? '',
            // 비즈니스 정보는 DB에서 보완
            'memberId': paymentDetail['memberId'],
            'contractHistoryId': paymentDetail['contractHistoryId'],
            'isCancelled': settlement['type'] == 'ORDER_CANCEL',
            'settlementType': settlement['type'],
          });
        }
        
        final pageInfo = data['page'] as Map<String, dynamic>? ?? {};
        final totalCount = pageInfo['totalElements'] as int? ?? 0;
        
        final result = {
          'success': true,
          'data': {
            'items': settlementItems,
            'summary': {
              'totalCount': totalCount,
              'totalPaymentAmount': totalPaymentAmount,
              'totalPaymentSupply': totalSupply,
              'totalPaymentVat': totalVat,
              'totalPlatformFee': totalPlatformFee,
              'totalPlatformFeeVat': totalPlatformFeeVat,
              'totalBranchAmount': totalBranchAmount,
            },
            'pagination': {
              'page': page,
              'pageSize': pageSize,
              'totalCount': totalCount,
              'totalPages': pageInfo['totalPages'] as int? ?? 1,
            },
          },
        };
        
        // 디버깅: 최종 결과 요약
        print('=== 정산 내역 처리 완료 ===');
        print('총 건수: $totalCount');
        print('처리된 항목 수: ${settlementItems.length}');
        print('총 결제 금액: $totalPaymentAmount원');
        print('총 플랫폼 수수료: $totalPlatformFee원');
        print('총 지점 정산 금액: $totalBranchAmount원');
        print('========================');
        
        return result;
      } else {
        // API 호출 실패 시 오류 타입 확인
        print('❌ 포트원 API 호출 실패');
        print('Status Code: ${response.statusCode}');
        print('응답 Body: ${response.body}');
        
        try {
          final errorData = jsonDecode(response.body);
          final errorType = errorData['type'] as String?;
          
          // 플랫폼 미활성화 오류인 경우 특별 처리
          if (response.statusCode == 403 && errorType == 'PLATFORM_NOT_ENABLED') {
            print('⚠️ 파트너 정산 자동화 기능이 활성화되지 않았습니다.');
            return {
              'success': false,
              'error': '파트너 정산 자동화 기능이 활성화되지 않았습니다.',
              'errorType': 'PLATFORM_NOT_ENABLED',
            };
          }
        } catch (e) {
          print('오류 응답 파싱 실패: $e');
        }
        
        // 다른 오류인 경우 DB에서 조회 (폴백)
        print('DB에서 조회합니다.');
        return await _getBranchSettlementsFromDB(
          branchId: branchId,
          from: from,
          to: to,
          page: page,
          pageSize: pageSize,
        );
      }
    } catch (e) {
      print('지점별 정산 내역 조회 오류: $e');
      // 오류 발생 시 DB에서 조회 (폴백)
      return await _getBranchSettlementsFromDB(
        branchId: branchId,
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      );
    }
  }
  
  /// DB에서 정산 내역 조회 (폴백)
  /// 
  /// 주의: 수수료 정책은 포트원에서 관리되므로, 정확한 정산 내역은 포트원 API를 통해 조회해야 합니다.
  /// DB에는 결제 정보만 저장되어 있으므로, 정산 금액은 대략적인 추정치입니다.
  /// 포트원 API Secret이 설정되지 않은 경우에만 사용됩니다.
  static Future<Map<String, dynamic>> _getBranchSettlementsFromDB({
    required String branchId,
    required DateTime from,
    required DateTime to,
    int page = 0,
    int pageSize = 50,
  }) async {
    print('=== DB에서 정산 내역 조회 (폴백) ===');
    print('지점 ID: $branchId');
    print('조회 기간: ${from.toString().split(' ')[0]} ~ ${to.toString().split(' ')[0]}');
    
    try {
      print('DB 조회 시작...');
      final payments = await ApiService.getDataList(
        table: 'v2_portone_payments',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'payment_status', 'operator': '=', 'value': 'PAID'},
          {
            'field': 'payment_paid_at',
            'operator': '>=',
            'value': from.toIso8601String(),
          },
          {
            'field': 'payment_paid_at',
            'operator': '<=',
            'value': to.toIso8601String(),
          },
        ],
        orderBy: [
          {'field': 'payment_paid_at', 'direction': 'DESC'},
        ],
        limit: pageSize,
        offset: page * pageSize,
      );
      
      print('DB에서 조회된 결제 건수: ${payments.length}');
      
      int totalPaymentAmount = 0;
      
      final settlementItems = <Map<String, dynamic>>[];
      
      for (var payment in payments) {
        print('결제 정보: paymentId=${payment['portone_payment_uid']}, 금액=${payment['payment_amount']}원');
        final paymentAmount = payment['payment_amount'] as int? ?? 0;
        
        totalPaymentAmount += paymentAmount;
        
        // 수수료 정책은 포트원에서 관리되므로, DB에는 정확한 수수료 정보가 없습니다.
        // 포트원 API를 통해 정산 내역을 조회해야 정확한 수수료와 정산 금액을 확인할 수 있습니다.
        settlementItems.add({
          'paymentId': payment['portone_payment_uid'],
          'txId': payment['portone_tx_id'],
          'orderName': payment['order_name'],
          'paymentAmount': paymentAmount,
          'paymentSupply': (paymentAmount / 1.1).round(),
          'paymentVat': paymentAmount - (paymentAmount / 1.1).round(),
          'platformFee': null, // 포트원 API에서만 제공
          'platformFeeVat': null, // 포트원 API에서만 제공
          'branchAmount': null, // 포트원 API에서만 제공 (정확한 수수료 정책 필요)
          'settlementDate': null, // 포트원 API에서만 제공
          'settlementStatus': 'UNKNOWN', // 포트원 API에서만 제공
          'paymentDate': payment['payment_paid_at'],
          'paymentMethod': payment['payment_method'],
          'paymentProvider': payment['payment_provider'],
          'memberId': payment['member_id'],
          'contractHistoryId': payment['contract_history_id'],
          'isCancelled': false,
          'settlementType': 'ORDER',
        });
      }
      
      final totalCount = await ApiService.getDataList(
        table: 'v2_portone_payments',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'payment_status', 'operator': '=', 'value': 'PAID'},
          {
            'field': 'payment_paid_at',
            'operator': '>=',
            'value': from.toIso8601String(),
          },
          {
            'field': 'payment_paid_at',
            'operator': '<=',
            'value': to.toIso8601String(),
          },
        ],
      );
      
      print('DB 조회 완료: 총 ${totalCount.length}건, 처리된 ${settlementItems.length}건');
      print('총 결제 금액: $totalPaymentAmount원');
      
      return {
        'success': true,
        'data': {
          'items': settlementItems,
          'summary': {
            'totalCount': totalCount.length,
            'totalPaymentAmount': totalPaymentAmount,
            'totalPaymentSupply': (totalPaymentAmount / 1.1).round(),
            'totalPaymentVat': totalPaymentAmount - (totalPaymentAmount / 1.1).round(),
            'totalPlatformFee': null, // 포트원 API에서만 제공
            'totalPlatformFeeVat': null, // 포트원 API에서만 제공
            'totalBranchAmount': null, // 포트원 API에서만 제공
          },
          'pagination': {
            'page': page,
            'pageSize': pageSize,
            'totalCount': totalCount.length,
            'totalPages': (totalCount.length / pageSize).ceil(),
          },
        },
        'warning': '포트원 API Secret이 설정되지 않아 DB에서 조회했습니다. 정확한 수수료 및 정산 금액은 포트원 API를 통해 확인하세요.',
      };
    } catch (e, stackTrace) {
      print('❌ DB 조회 오류: $e');
      print('스택 트레이스: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 결제 상세 정보 일괄 조회 (DB에서) - 성능 개선
  /// API 응답에 없는 비즈니스 정보(memberId, contractHistoryId 등)만 보완용으로 사용
  static Future<Map<String, Map<String, dynamic>>> _getPaymentDetailsBatch(List<String> paymentIds) async {
    if (paymentIds.isEmpty) {
      return {};
    }
    
    try {
      final payments = await ApiService.getDataList(
        table: 'v2_portone_payments',
        where: [
          {'field': 'portone_payment_uid', 'operator': 'IN', 'value': paymentIds},
        ],
      );
      
      final Map<String, Map<String, dynamic>> result = {};
      for (var payment in payments) {
        final paymentId = payment['portone_payment_uid'] as String? ?? '';
        if (paymentId.isNotEmpty) {
          result[paymentId] = {
            'txId': payment['portone_tx_id'],
            'orderName': payment['order_name'],
            'paymentDate': payment['payment_paid_at'],
            'paymentMethod': payment['payment_method'],
            'paymentProvider': payment['payment_provider'],
            'memberId': payment['member_id'],
            'contractHistoryId': payment['contract_history_id'],
          };
        }
      }
      
      return result;
    } catch (e) {
      print('결제 상세 정보 일괄 조회 오류: $e');
      return {};
    }
  }
  
  /// 날짜 범위 생성
  static List<String> _generateDateRange(DateTime from, DateTime to) {
    final dates = <String>[];
    var current = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    
    while (!current.isAfter(end)) {
      dates.add('${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}');
      current = current.add(Duration(days: 1));
    }
    
    return dates;
  }
  
  /// 전체 지점 정산 요약 조회
  /// 
  /// 주의: 수수료 정책은 포트원에서 관리되므로, 포트원 API를 통해 조회하는 것을 권장합니다.
  /// 
  /// [from] 조회 시작 날짜
  /// [to] 조회 종료 날짜
  static Future<Map<String, dynamic>> getAllBranchesSettlementSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // 포트원 API를 통해 정산 내역을 조회하는 것을 권장합니다.
      // 수수료 정책은 포트원에서 관리되므로, 정확한 정산 금액은 포트원 API에서만 제공됩니다.
      
      // 모든 지점의 결제 내역 조회 (대략적인 정보만 제공)
      final payments = await ApiService.getDataList(
        table: 'v2_portone_payments',
        where: [
          {'field': 'payment_status', 'operator': '=', 'value': 'PAID'},
          {
            'field': 'payment_paid_at',
            'operator': '>=',
            'value': from.toIso8601String(),
          },
          {
            'field': 'payment_paid_at',
            'operator': '<=',
            'value': to.toIso8601String(),
          },
        ],
      );
      
      // 지점별 집계 (결제 금액만 집계, 수수료는 포트원 API에서만 제공)
      final branchSummary = <String, Map<String, dynamic>>{};
      int totalPaymentAmount = 0;
      
      for (var payment in payments) {
        final branchId = payment['branch_id'] as String? ?? 'unknown';
        final paymentAmount = payment['payment_amount'] as int? ?? 0;
        
        if (!branchSummary.containsKey(branchId)) {
          branchSummary[branchId] = {
            'branchId': branchId,
            'paymentCount': 0,
            'totalPaymentAmount': 0,
          };
        }
        
        branchSummary[branchId]!['paymentCount'] = 
            (branchSummary[branchId]!['paymentCount'] as int) + 1;
        branchSummary[branchId]!['totalPaymentAmount'] = 
            (branchSummary[branchId]!['totalPaymentAmount'] as int) + paymentAmount;
        
        totalPaymentAmount += paymentAmount;
      }
      
      return {
        'success': true,
        'data': {
          'branchSummary': branchSummary.values.toList(),
          'totalSummary': {
            'totalPaymentAmount': totalPaymentAmount,
            'totalPaymentCount': payments.length,
          },
        },
        'warning': '수수료 및 정산 금액은 포트원 API를 통해 조회하세요. 수수료 정책은 포트원에서 관리됩니다.',
      };
    } catch (e) {
      print('전체 지점 정산 요약 조회 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 결제 취소 요청
  /// 
  /// [paymentId] 결제 ID
  /// [cancelReason] 취소 사유
  /// [cancelAmount] 취소 금액 (null이면 전체 취소)
  static Future<Map<String, dynamic>> cancelPayment({
    required String paymentId,
    required String cancelReason,
    int? cancelAmount,
  }) async {
    try {
      if (_apiSecret == null) {
        return {
          'success': false,
          'error': '포트원 API Secret이 설정되지 않았습니다.',
        };
      }
      
      final requestBody = {
        'reason': cancelReason,
        if (cancelAmount != null) 'amount': cancelAmount, // 포트원 API는 'amount' 필드 사용
      };
      
      // 디버깅: 결제 취소 API 호출 로그
      print('=== 포트원 결제 취소 API 호출 ===');
      print('요청 URL: $portoneApiBaseUrl/payments/$paymentId/cancel');
      print('요청 Body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$portoneApiBaseUrl/payments/$paymentId/cancel'), // v2 제거
        headers: {
          'Authorization': 'Bearer $_apiSecret', // Bearer 토큰 형식 사용
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('응답 Status Code: ${response.statusCode}');
      print('응답 Body: ${response.body}');
      print('================================');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        print('✅ 결제 취소 성공: ${jsonEncode(data)}');
        return {
          'success': true,
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ 결제 취소 실패: ${errorData['message'] ?? '알 수 없는 오류'}');
        return {
          'success': false,
          'error': errorData['message'] ?? '결제 취소 실패',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

