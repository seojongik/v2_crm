import 'dart:convert';
import 'dart:convert' show utf8;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/credit_transaction.dart';
import '../models/lesson_counting.dart';
import '../models/user.dart';
import '../models/lesson_feedback.dart';
import '../models/branch.dart';
import 'package:famd_clientapp/models/staff.dart';

class ApiService {
  // 서버 루트의 dynamic_api.php 사용 - HTTPS로 변경
  static const String baseUrl = 'https://autofms.mycafe24.com/dynamic_api.php';

  // 기본 헤더 (dynamic_api.php는 별도 API 키 불필요)
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // HTTP 클라이언트 - 타임아웃 설정
  static final http.Client _client = http.Client();
  
  // 웹 환경인지 확인 (CORS 처리를 위해)
  static bool get isWeb => kIsWeb;

  // 로그인 시 사용자의 모든 branch 정보 조회
  static Future<List<Map<String, dynamic>>?> getUserBranches({required String phone, required String password}) async {
    try {
      // 전화번호 포맷 정리
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.length == 11) {
        cleanPhone = '${cleanPhone.substring(0, 3)}-${cleanPhone.substring(3, 7)}-${cleanPhone.substring(7)}';
      }

      if (kDebugMode) {
        print('🔍 [사용자 Branch 조회] v3_members 테이블에서 사용자의 모든 branch 정보 조회 시작');
        print('🔍 [사용자 Branch 조회] 전화번호: $cleanPhone');
      }

      // 전화번호 형식을 다양하게 시도해보기
      List<String> phoneFormats = [
        cleanPhone, // 010-1234-5678
        phone.replaceAll(RegExp(r'[^0-9]'), ''), // 01012345678
        phone, // 원본 그대로
      ];

      // 각 형식으로 시도
      for (String phoneFormat in phoneFormats) {
        final response = await http.post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            "operation": "get",
            "table": "v3_members",
            "fields": ["member_id", "member_name", "member_phone", "branch_id"],
            "where": [
              {
                "field": "member_phone",
                "operator": "=",
                "value": phoneFormat
              },
              {
                "field": "member_password",
                "operator": "=",
                "value": password
              }
            ],
            "limit": 10 // 최대 10개 branch까지 조회
          }),
        );

        if (kDebugMode) {
          print('🔍 [사용자 Branch 조회] 전화번호 형식 $phoneFormat 시도');
          print('🔍 [사용자 Branch 조회] API 응답 상태: ${response.statusCode}');
          print('🔍 [사용자 Branch 조회] API 응답 내용: ${response.body}');
        }

        if (response.statusCode == 200) {
          final result = jsonDecode(utf8.decode(response.bodyBytes));
          
          if (result['success'] == true && result['data'].isNotEmpty) {
            if (kDebugMode) {
              print('✅ [사용자 Branch 조회] 조회 성공');
              print('✅ [사용자 Branch 조회] 발견된 branch 수: ${result['data'].length}');
            }
            
            return List<Map<String, dynamic>>.from(result['data']);
          }
        }
      }

      if (kDebugMode) {
        print('⚠️ [사용자 Branch 조회] 조회 실패: 사용자를 찾을 수 없습니다.');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [사용자 Branch 조회] 조회 오류: $e');
      }
      return null;
    }
  }

  // Branch 정보 조회
  static Future<List<Branch>> getBranchInfo(List<String> branchIds) async {
    try {
      if (kDebugMode) {
        print('🔍 [Branch 정보 조회] v2_branch 테이블에서 branch 정보 조회 시작');
        print('🔍 [Branch 정보 조회] Branch IDs: $branchIds');
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "get",
          "table": "v2_branch",
          "fields": ["branch_id", "branch_name", "branch_address", "branch_phone", "branch_business_reg_no", "branch_director_name", "branch_director_phone"],
          "where": [
            {
              "field": "branch_id",
              "operator": "IN",
              "value": branchIds
            }
          ],
        }),
      );

      if (kDebugMode) {
        print('🔍 [Branch 정보 조회] API 응답 상태: ${response.statusCode}');
        print('🔍 [Branch 정보 조회] API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true && result['data'].isNotEmpty) {
          if (kDebugMode) {
            print('✅ [Branch 정보 조회] 조회 성공');
            print('✅ [Branch 정보 조회] 발견된 branch 수: ${result['data'].length}');
          }
          
          return result['data'].map<Branch>((branchData) => Branch.fromJson(branchData)).toList();
        }
      }

      if (kDebugMode) {
        print('⚠️ [Branch 정보 조회] 조회 실패');
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ [Branch 정보 조회] 조회 오류: $e');
      }
      
      return [];
    }
  }

  // 로그인 메서드 (기존 메서드 수정)
  static Future<User?> login({required String phone, required String password, String? branchId}) async {
    try {
      // 전화번호 포맷 정리
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.length == 11) {
        cleanPhone = '${cleanPhone.substring(0, 3)}-${cleanPhone.substring(3, 7)}-${cleanPhone.substring(7)}';
      }

      if (kDebugMode) {
        print('🔍 [로그인] v3_members 테이블에서 로그인 정보 조회 시작');
        print('🔍 [로그인] 전화번호: $cleanPhone');
        print('🔍 [로그인] Branch ID: $branchId');
      }

      // 전화번호 형식을 다양하게 시도해보기
      List<String> phoneFormats = [
        cleanPhone, // 010-1234-5678
        phone.replaceAll(RegExp(r'[^0-9]'), ''), // 01012345678
        phone, // 원본 그대로
      ];

      if (kDebugMode) {
        print('🔍 [로그인] 시도할 전화번호 형식들: $phoneFormats');
      }

      // 각 형식으로 시도
      for (String phoneFormat in phoneFormats) {
        // WHERE 조건 구성
        List<Map<String, dynamic>> whereConditions = [
          {
            "field": "member_phone",
            "operator": "=",
            "value": phoneFormat
          },
          {
            "field": "member_password",
            "operator": "=",
            "value": password
          }
        ];

        // branchId가 지정된 경우 조건에 추가
        if (branchId != null) {
          whereConditions.add({
            "field": "branch_id",
            "operator": "=",
            "value": branchId
          });
        }

        final response = await http.post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            "operation": "get",
            "table": "v3_members",
            "fields": ["member_id", "member_name", "branch_id"],
            "where": whereConditions,
            "limit": 1
          }),
        );

        if (kDebugMode) {
          print('🔍 [로그인] 전화번호 형식 $phoneFormat 시도');
          print('🔍 [로그인] API 응답 상태: ${response.statusCode}');
          print('🔍 [로그인] API 응답 내용: ${response.body}');
        }

        if (response.statusCode == 200) {
          final result = jsonDecode(utf8.decode(response.bodyBytes));
          
          if (result['success'] == true && result['data'].isNotEmpty) {
            final memberData = result['data'][0];
            
            if (kDebugMode) {
              print('✅ [로그인] 로그인 성공');
              print('✅ [로그인] 회원 ID: ${memberData['member_id']}');
              print('✅ [로그인] 회원 이름: ${memberData['member_name']}');
              print('✅ [로그인] Branch ID: ${memberData['branch_id']}');
            }
            
            return User(
              id: memberData['member_id']?.toString() ?? '',
              name: memberData['member_name'] ?? '',
              phone: phoneFormat,
              email: null,
              nickname: null,
              gender: null,
              address: null,
              birthday: null,
              memo: null,
              branchId: memberData['branch_id']?.toString(),
            );
          }
        }
      }

      // 모든 형식으로 시도했지만 실패
      if (kDebugMode) {
        print('⚠️ [로그인] 로그인 실패: 사용자를 찾을 수 없습니다.');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [로그인] 로그인 오류: $e');
      }
      return null;
    }
  }

  // 전화번호 형식 변환 (010-XXXX-XXXX 형식으로)
  static String formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 11자리 전화번호인 경우 (01012345678)
    if (digitsOnly.length == 11) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    }
    // 10자리 전화번호인 경우 (0101234567)
    else if (digitsOnly.length == 10) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }
    
    // 형식이 맞지 않으면 원본 반환
    return phone;
  }

  /**
   * 크레딧 거래 내역 조회
   * 
   * 회원별 크레딧 거래 내역을 가져옵니다.
   * 
   * 요청 매개변수:
   * - member_id: 회원 ID
   * - bill_date: (선택) 특정 날짜의 내역만 필터링
   * 
   * 응답 데이터:
   * {
   *   "success": true,
   *   "transactions": [
   *     {
   *       "bill_id": "123",
   *       "bill_date": "2023-01-01",
   *       "bill_type": "타석이용",
   *       "bill_text": "5번 타석(10:00~11:00)",
   *       "bill_totalamt": "-10000",
   *       "bill_deduction": "2000",
   *       "bill_netamt": "-8000",
   *       "bill_balance_after": "42000",
   *       "bill_status": "completed",
   *       "reservation_id": "230101_5_1000"
   *     },
   *     ...
   *   ]
   * }
   */
  static Future<List<CreditTransaction>> getCreditTransactions(String memberId, {String? branchId, String? token}) async {
    try {
      if (kDebugMode) {
        print('크레딧 내역 조회 시작 - 회원 ID: $memberId, Branch ID: $branchId');
      }

      // WHERE 조건 구성
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      // dynamic_api.php를 사용한 크레딧 거래 내역 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_bills',
          'fields': [
            'bill_id',
            'bill_date', 
            'bill_type',
            'bill_text',
            'bill_totalamt',
            'bill_deduction',
            'bill_netamt',
            'bill_balance_before',
            'bill_balance_after',
            'bill_timestamp',
            'reservation_id',
            'bill_status'
          ],
          'where': whereConditions,
          'orderBy': [
            {'field': 'bill_date', 'direction': 'DESC'},
            {'field': 'bill_id', 'direction': 'DESC'}
          ],
          'limit': 100
        }),
      );

      if (kDebugMode) {
        print('API 응답 상태: ${response.statusCode}');
        print('API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> transactionsData = data['data'];
          List<CreditTransaction> transactions = [];
          
          if (kDebugMode) {
            print('거래 내역 데이터 수: ${transactionsData.length}');
          }
          
          // 거래 내역 리스트 생성
          for (var item in transactionsData) {
            try {
              // null 값 처리
              final deduction = item['bill_deduction'] == null ? 0 : int.parse(item['bill_deduction'].toString());
              
              transactions.add(CreditTransaction(
                date: DateTime.parse(item['bill_date']),
                type: _getTransactionType(item['bill_type']),
                description: item['bill_text'],
                amount: int.parse(item['bill_totalamt'].toString()),
                deduction: deduction,  // null인 경우 0으로 처리
                netAmount: int.parse(item['bill_netamt'].toString()),
                balance: int.parse(item['bill_balance_after'].toString()),
                status: item['bill_status']?.toString() ?? 'completed',  // 상태 정보 추가
              ));
            } catch (e) {
              if (kDebugMode) {
                print('데이터 변환 중 오류: $e, 데이터: ${jsonEncode(item)}');
              }
              // 오류가 발생하면 해당 항목은 건너뛰기
              continue;
            }
          }
          
          if (kDebugMode) {
            print('API에서 받은 거래 내역 수: ${transactions.length}');
          }
          
          return transactions;
        } else {
          // API 호출은 성공했지만 데이터 없음
          final errorMessage = data['error'] ?? '크레딧 내역 조회에 실패했습니다.';
          if (kDebugMode) {
            print('API 응답 오류: $errorMessage');
          }
          
          // 빈 배열 반환
          return [];
        }
      } else {
        if (kDebugMode) {
          print('HTTP 오류: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('크레딧 내역 조회 오류: $e');
      }
      
      // 빈 배열 반환
      return [];
    }
  }
  
  // bill_type에 따른 거래 유형 반환 헬퍼 메소드
  static String _getTransactionType(String billType) {
    // 영문 타입을 한글로 변환
    if (billType.toLowerCase() == 'deposit') {
      return '수동적립';
    } else if (billType.toLowerCase() == 'withdraw') {
      return '수동차감';
    } else if (billType.toLowerCase().contains('membership') || 
              billType.toLowerCase().contains('회원권')) {
      return '회원권구매';
    }
    
    // 그 외의 경우 원래 값 그대로 사용
    return billType;
  }

  // 레슨 카운팅 데이터 가져오기 (branch_id 조건 추가)
  static Future<List<LessonCounting>> getLessonCountings(
    String userId, {
    String? branchId,
    String? lsType,
    String? lsContractPro,
  }) async {
    try {
      if (kDebugMode) {
        print('===== 레슨 카운팅 데이터 요청 시작 - 회원 ID: $userId, Branch ID: $branchId =====');
        if (lsType != null) print('레슨 타입 필터: $lsType');
        if (lsContractPro != null) print('담당 프로 필터: $lsContractPro');
      }
      
      // 테이블 존재 여부 확인
      final tableExists = await _checkLessonCountingTable();
      if (!tableExists) {
        if (kDebugMode) {
          print('v3_LS_countings 테이블이 존재하지 않습니다. 데이터베이스 상태를 확인하세요.');
        }
        return []; // 빈 배열 반환
      }
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': userId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      // 옵션 파라미터 추가
      if (lsType != null && lsType.isNotEmpty) {
        whereConditions.add({'field': 'LS_type', 'operator': '=', 'value': lsType});
      }
      
      if (lsContractPro != null && lsContractPro.isNotEmpty) {
        whereConditions.add({'field': 'LS_contract_pro', 'operator': '=', 'value': lsContractPro});
      }
      
      // dynamic_api.php를 사용한 레슨 카운팅 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v3_LS_countings',
          'where': whereConditions,
          'orderBy': [
            {'field': 'id', 'direction': 'DESC'}
          ]
        }),
      );

      if (kDebugMode) {
        print('API 응답 상태: ${response.statusCode}');
        print('API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('API 응답 받음: getLessonCountings');
          print('응답 성공 여부: ${responseData['success']}');
          if (responseData['data'] != null) {
            print('조회된 레슨 카운팅 수: ${(responseData['data'] as List).length}');
          } else {
            print('data 필드가 null입니다');
          }
        }
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> countingsData = responseData['data'];
          List<LessonCounting> countings = [];
          
          if (kDebugMode) {
            print('조회된 레슨 카운팅 수: ${countingsData.length}');
            if (countingsData.isNotEmpty) {
              print('첫 번째 카운팅 데이터 샘플: ${jsonEncode(countingsData.first)}');
            }
          }
          
          // 레슨 내역 리스트 생성
          for (var item in countingsData) {
            try {
              final counting = LessonCounting.fromJson(item);
              countings.add(counting);
            } catch (e) {
              if (kDebugMode) {
                print('데이터 변환 중 오류: $e, 데이터: ${jsonEncode(item)}');
                print('오류 발생 항목은 건너뜁니다.');
              }
              // 오류가 발생한 항목은 건너뛰기
              continue;
            }
          }
          
          if (kDebugMode) {
            print('성공적으로 변환된 레슨 카운팅 수: ${countings.length}');
            print('===== 레슨 카운팅 데이터 요청 완료 =====');
          }
          
          return countings;
        } else {
          // API 호출은 성공했지만 데이터 없음
          final errorMessage = responseData['error'] ?? '레슨 내역 조회에 실패했습니다.';
          if (kDebugMode) {
            print('API 응답 오류: $errorMessage');
            print('===== 레슨 카운팅 데이터 요청 완료 (오류) =====');
          }
          return []; // 빈 배열 반환
        }
      } else {
        if (kDebugMode) {
          print('HTTP 오류: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('레슨 카운팅 조회 오류: $e');
        print('오류 스택 트레이스: ${StackTrace.current}');
        print('===== 레슨 카운팅 데이터 요청 완료 (예외) =====');
      }
      
      return []; // 빈 배열 반환
    }
  }
  
  // 주니어 관계 정보 조회 (branch_id 조건 추가)
  static Future<Map<String, dynamic>> getJuniorRelations(String memberId, {String? branchId}) async {
    try {
      if (kDebugMode) {
        print('\n============================================================');
        print('===== [주니어 관계 디버깅] API 요청 시작 =====');
        print('시간: ${DateTime.now()}');
        print('회원 ID: $memberId');
        print('Branch ID: $branchId');
        print('요청 URL: https://autofms.mycafe24.com/dynamic_api.php');
        print('============================================================');
      }

      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      // 요청 데이터 준비
      final requestData = {
        'operation': 'get',
        'table': 'v2_junior_relation',  // 정확한 테이블명
        'fields': [
          'relation_id',
          'junior_member_id', 
          'junior_name', 
          'member_id', 
          'member_name', 
          'relation'
        ],  // API에서 확인한 정확한 필드명들
        'where': whereConditions,
        'limit': 10
      };

      if (kDebugMode) {
        print('요청 데이터: ${jsonEncode(requestData)}');
      }

      // 요청 시작 시간 기록
      final startTime = DateTime.now();

      // dynamic_api.php를 사용한 주니어 관계 정보 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (kDebugMode) {
            print('❌ [주니어 관계 디버깅] 요청 타임아웃 (15초)');
          }
          throw Exception('서버 응답 시간이 초과되었습니다 (15초)');
        },
      );

      // 요청 완료 시간 계산
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      if (kDebugMode) {
        print('\n============================================================');
        print('===== [주니어 관계 디버깅] API 응답 수신 =====');
        print('소요 시간: ${duration}ms');
        print('응답 상태 코드: ${response.statusCode}');
        print('응답 헤더: ${response.headers}');
        print('응답 본문 길이: ${response.body.length} bytes');
        print('응답 본문: ${response.body}');
        print('============================================================');
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          if (kDebugMode) {
            print('✅ [주니어 관계 디버깅] JSON 파싱 성공');
            print('응답 success 플래그: ${data['success']}');
            print('응답 데이터 타입: ${data['data'].runtimeType}');
            if (data['data'] is List) {
              print('데이터 개수: ${(data['data'] as List).length}');
            }
          }

          if (data['success'] == true) {
            if (kDebugMode) {
              print('✅ [주니어 관계 디버깅] API 호출 성공');
            }
            return {
              'success': true,
              'data': data['data'] ?? [],
            };
          } else {
            if (kDebugMode) {
              print('⚠️ [주니어 관계 디버깅] API 실패 응답');
              print('오류 메시지: ${data['error']}');
            }
            return {
              'success': false,
              'error': data['error'] ?? '주니어 관계 정보 조회 실패',
            };
          }
        } catch (jsonError) {
          if (kDebugMode) {
            print('❌ [주니어 관계 디버깅] JSON 파싱 오류: $jsonError');
            print('원본 응답: ${response.body}');
          }
          return {
            'success': false,
            'error': 'JSON 파싱 오류: $jsonError',
          };
        }
      } else {
        if (kDebugMode) {
          print('❌ [주니어 관계 디버깅] HTTP 오류');
          print('상태 코드: ${response.statusCode}');
          print('응답 본문: ${response.body}');
        }
        return {
          'success': false,
          'error': '서버 오류: ${response.statusCode}',
        };
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('\n============================================================');
        print('===== [주니어 관계 디버깅] 예외 발생 =====');
        print('시간: ${DateTime.now()}');
        print('예외 타입: ${e.runtimeType}');
        print('예외 메시지: $e');
        print('스택 트레이스:');
        print(stackTrace);
        
        // 네트워크 관련 오류 상세 분석
        if (e.toString().contains('Failed to fetch')) {
          print('\n🔍 [네트워크 분석] Failed to fetch 오류 감지');
          print('가능한 원인:');
          print('1. 서버가 다운되었거나 접근 불가능');
          print('2. CORS 정책 위반 (웹 환경)');
          print('3. 네트워크 연결 문제');
          print('4. 방화벽 차단');
          print('5. SSL/TLS 인증서 문제');
        } else if (e.toString().contains('timeout')) {
          print('\n🔍 [타임아웃 분석] 요청 시간 초과');
          print('서버 응답이 15초 내에 오지 않음');
        } else if (e.toString().contains('SocketException')) {
          print('\n🔍 [소켓 분석] 네트워크 소켓 오류');
          print('인터넷 연결 상태를 확인하세요');
        }
        print('============================================================');
      }
      
      return {
        'success': false,
        'error': '주니어 관계 조회 중 오류: $e',
      };
    }
  }
  
  // 스태프 목록 조회 (v2_staff_pro 테이블 사용)
  static Future<List<Staff>> getStaffList({String? branchId}) async {
    try {
      if (kDebugMode) {
        print('\n🔍 [시작] 스태프 목록 조회 API 호출 (v2_staff_pro 테이블 사용)');
        print('🔍 [API 요청] URL: https://autofms.mycafe24.com/dynamic_api.php');
        print('🔍 [API 요청] Branch ID: $branchId');
      }
      
      // where 조건 준비
      final whereConditions = <Map<String, dynamic>>[];
      
      // branch_id 조건 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      // 요청 데이터 준비 - v2_staff_pro 테이블 필드명 사용
      final requestData = {
        'operation': 'get',
        'table': 'v2_staff_pro',
        'fields': [
          'pro_id', 
          'pro_name', 
          'staff_nickname', 
          'staff_type', 
          'pro_phone',
          'staff_access_id',
          'staff_password',
          'staff_status',
          'min_service_min',
          'staff_svc_time',
          'min_reservation_term',
          'reservation_ahead_days',
          'salary_base',
          'salary_hour',
          'salary_per_lesson',
          'salary_per_event'
        ],
        'where': whereConditions.isNotEmpty ? whereConditions : null,
        'orderBy': [
          {'field': 'pro_name', 'direction': 'ASC'}
        ]
      };
      
      if (kDebugMode) {
        print('🔍 [API 요청] 요청 데이터: ${jsonEncode(requestData)}');
      }
      
      // dynamic_api.php를 사용한 스태프 목록 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            print('⚠️ 스태프 목록 조회 시간 초과 (10초)');
          }
          throw Exception('스태프 목록 조회 시간 초과 (10초)');
        },
      );
      
      if (kDebugMode) {
        print('📡 [API 응답] 상태 코드: ${response.statusCode}');
        print('📡 [API 응답] 바디 길이: ${response.body.length}');
        print('📡 [API 응답] 바디 내용: "${response.body}"');
      }
      
      // 응답 처리
      if (response.statusCode == 200) {
        // 빈 응답 또는 공백만 있는 경우 확인
        if (response.body.trim().isEmpty) {
          if (kDebugMode) {
            print('⚠️ API 응답이 비어있거나 공백만 있습니다.');
          }
          return [];
        }
        
        try {
          final data = jsonDecode(response.body.trim());
          
          if (kDebugMode) {
            print('📡 [API 응답] JSON 파싱 성공');
            print('📡 [API 응답] 데이터 타입: ${data.runtimeType}');
            print('📡 [API 응답] 성공 여부: ${data['success']}');
            if (data['data'] != null) {
              print('📡 [API 응답] 데이터 개수: ${(data['data'] as List).length}');
            }
          }
          
          if (data['success'] == true) {
            // 스태프 목록 파싱
            final staffList = List<Map<String, dynamic>>.from(data['data'] ?? []);
            
            if (kDebugMode) {
              print('🧑‍💼 스태프 목록 ${staffList.length}명 조회됨 (v2_staff_pro)');
              if (staffList.isNotEmpty) {
                print('🧑‍💼 첫 번째 스태프 데이터: ${staffList.first}');
                print('🧑‍💼 "이재윤" 강사 찾기...');
                for (var staff in staffList) {
                  if (staff['pro_name'] == '이재윤') {
                    print('✅ "이재윤" 강사 발견: ${jsonEncode(staff)}');
                    break;
                  }
                }
              }
            }
            
            // Staff 객체 리스트로 변환 (v2_staff_pro 필드명 그대로 사용)
            List<Staff> result = [];
            
            for (var staffData in staffList) {
              try {
                // v2_staff_pro 테이블 데이터를 Staff 모델로 직접 변환
                final staff = Staff.fromJson(staffData);
                result.add(staff);
                
                if (kDebugMode && staff.name == '이재윤') {
                  print('✅ "이재윤" Staff 객체 생성 완료: name=${staff.name}, nickname=${staff.nickname}');
                }
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Staff 객체 변환 오류: $e, 데이터: ${jsonEncode(staffData)}');
                }
                continue;
              }
            }
            
            if (kDebugMode) {
              print('✅ 최종 Staff 객체 리스트 크기: ${result.length}');
              final leeJaeYoon = result.where((s) => s.name == '이재윤').toList();
              if (leeJaeYoon.isNotEmpty) {
                print('✅ 최종 결과에서 "이재윤" 강사 확인됨: ${leeJaeYoon.first.name} (${leeJaeYoon.first.nickname})');
              } else {
                print('❌ 최종 결과에서 "이재윤" 강사를 찾을 수 없음');
                print('❌ 최종 결과 Staff 이름들: ${result.map((s) => s.name).toList()}');
              }
            }
            
            return result;
          } else {
            // API 호출은 성공했지만 결과가 실패
            if (kDebugMode) {
              print('⚠️ API 성공 플래그가 false입니다: ${data['error'] ?? '오류 메시지 없음'}');
            }
            return [];
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ JSON 파싱 오류: $e');
            print('❌ 원본 응답 내용: "${response.body}"');
          }
          return [];
        }
      } else {
        // HTTP 상태 코드가 200이 아닌 경우
        if (kDebugMode) {
          print('❌ HTTP 상태 코드 오류: ${response.statusCode}');
          print('❌ 응답 내용: "${response.body}"');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 스태프 목록 조회 오류: $e');
        print('❌ 스택 트레이스: ${StackTrace.current}');
      }
      // 오류 발생 시 빈 목록 반환
      return [];
    } finally {
      if (kDebugMode) {
        print('🔍 [완료] 스태프 목록 조회 API 호출 종료 (v2_staff_pro 사용)\n');
      }
    }
  }

  // 레슨 피드백 데이터 가져오기 (branch_id 조건 추가)
  static Future<List<LessonFeedback>> getLessonFeedbacks(String userId, {String? branchId}) async {
    try {
      if (kDebugMode) {
        print('===== 레슨 피드백 데이터 요청 시작 - 회원 ID: $userId, Branch ID: $branchId =====');
      }
      
      // Staff 정보 먼저 가져오기
      final List<Staff> staffList = await getStaffList(branchId: branchId);
      
      if (kDebugMode) {
        print('Staff 정보 로드 완료. 스태프 수: ${staffList.length}');
        if (staffList.isNotEmpty) {
          print('스태프 닉네임 목록: ${staffList.map((s) => s.nickname).join(', ')}');
        }
      }
      
      // 테이블 존재 여부 확인
      final tablesExist = await _checkLessonFeedbackTables();
      if (!tablesExist) {
        if (kDebugMode) {
          print('v2_LS_orders 테이블이 존재하지 않습니다. 데이터베이스 상태를 확인하세요.');
        }
        return []; // 빈 배열 반환
      }
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': userId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      // dynamic_api.php를 사용한 레슨 피드백 조회
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
            {'field': 'LS_date', 'direction': 'DESC'}
          ],
          'limit': 50
        }),
      );

      if (kDebugMode) {
        print('API 응답 상태: ${response.statusCode}');
        print('API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('API 응답 받음: getLessonFeedbacks');
          print('응답 성공 여부: ${responseData['success']}');
          if (responseData['data'] != null) {
            print('조회된 레슨 피드백 수: ${(responseData['data'] as List).length}');
          } else {
            print('data 필드가 null입니다');
          }
        }
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> feedbacksData = responseData['data'];
          
          if (kDebugMode) {
            print('조회된 레슨 피드백 수: ${feedbacksData.length}');
            if (feedbacksData.isNotEmpty) {
              print('첫 번째 피드백 데이터 샘플: ${jsonEncode(feedbacksData.first)}');
            }
          }
          
          // 레슨 피드백 리스트 생성
          List<LessonFeedback> feedbacks = [];
          
          for (var item in feedbacksData) {
            try {
              // LS_feedback_bypro가 null이면 건너뛰기
              if (item['LS_feedback_bypro'] == null) {
                if (kDebugMode) {
                  print('피드백 내용이 null인 항목 건너뛰기: ${jsonEncode(item)}');
                }
                continue;
              }
              
              // LS_id에서 staff_nickname 추출 (예: 250415js2015 -> js)
              String lsId = item['LS_id']?.toString() ?? '';
              String staffNickname = '';
              
              if (lsId.length >= 8) {  // yymmdd + nickname + time
                // 앞의 6글자(날짜 부분) 이후부터 숫자가 나오기 전까지가 닉네임
                final dateStr = lsId.substring(0, 6);
                String remaining = lsId.substring(6);
                
                // 숫자가 나오는 위치 찾기
                int numIndex = -1;
                for (int i = 0; i < remaining.length; i++) {
                  if (RegExp(r'[0-9]').hasMatch(remaining[i])) {
                    numIndex = i;
                    break;
                  }
                }
                
                if (numIndex != -1) {
                  staffNickname = remaining.substring(0, numIndex);
                } else {
                  staffNickname = item['staff_nickname']?.toString() ?? '';
                }
              } else {
                // LS_id 형식이 맞지 않으면 staff_nickname 필드 사용
                staffNickname = item['staff_nickname']?.toString() ?? '';
              }
              
              if (kDebugMode) {
                print('LS_id: $lsId, 추출된 staffNickname: $staffNickname');
              }
              
              // Staff 리스트에서 프로 이름 조회
              String staffName = '';
              for (var staff in staffList) {
                if (staff.nickname == staffNickname) {
                  staffName = staff.name;
                  break;
                }
              }
              
              // 추출한 staffName 정보와 함께 LessonFeedback 객체 생성
              final feedback = LessonFeedback.fromJson(item, staffName: staffName);
              feedbacks.add(feedback);
            } catch (e) {
              if (kDebugMode) {
                print('데이터 변환 중 오류: $e, 데이터: ${jsonEncode(item)}');
                print('오류 발생 항목은 건너뜁니다.');
              }
              // 오류가 발생한 항목은 건너뛰기
              continue;
            }
          }
          
          if (kDebugMode) {
            print('성공적으로 변환된 레슨 피드백 수: ${feedbacks.length}');
            print('===== 레슨 피드백 데이터 요청 완료 =====');
          }
          
          return feedbacks;
        } else {
          // API 호출은 성공했지만 데이터 없음
          final errorMessage = responseData['error'] ?? '레슨 피드백 조회에 실패했습니다.';
          if (kDebugMode) {
            print('API 응답 오류: $errorMessage');
            print('===== 레슨 피드백 데이터 요청 완료 (오류) =====');
          }
          return []; // 빈 배열 반환
        }
      } else {
        if (kDebugMode) {
          print('HTTP 오류: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('레슨 피드백 조회 오류: $e');
        print('오류 스택 트레이스: ${StackTrace.current}');
        print('===== 레슨 피드백 데이터 요청 완료 (예외) =====');
      }
      
      return []; // 빈 배열 반환
    }
  }

  // 서버의 데이터베이스 상태 확인 (테이블 존재 확인)
  static Future<Map<String, dynamic>> checkDatabaseStatus() async {
    try {
      if (kDebugMode) {
        print('\n============================================================');
        print('===== [데이터베이스 디버깅] 데이터베이스 상태 확인 시작 =====');
        print('시간: ${DateTime.now()}');
        print('작업: 데이터베이스 테이블 목록 확인');
        print('============================================================\n');
      }
      
      // dynamic_api.php를 사용한 테이블 목록 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'tables'
        }),
      );

      if (kDebugMode) {
        print('API 응답 상태: ${response.statusCode}');
        print('API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['tables'] != null) {
          final List<dynamic> tables = responseData['tables'];
          
          if (kDebugMode) {
            print('\n============================================================');
            print('===== [데이터베이스 디버깅] 데이터베이스 테이블 조회 결과 =====');
            print('서버 데이터베이스 테이블 수: ${tables.length}');
            print('테이블 목록:');
            
            // 테이블 목록을 정렬하여 출력
            final sortedTables = List<String>.from(tables);
            sortedTables.sort();
            for (int i = 0; i < sortedTables.length; i++) {
              print('  ${i+1}. ${sortedTables[i]}');
            }
            
            // 필요한 테이블 존재 여부 확인
            print('\n중요 테이블 상태:');
            print('  v3_LS_countings: ${tables.contains('v3_LS_countings') ? '있음 ✓' : '없음 ✗'}');
            print('  LS_confirm: ${tables.contains('LS_confirm') ? '있음 ✓' : '없음 ✗'}');
            print('  LS_orders: ${tables.contains('LS_orders') ? '있음 ✓' : '없음 ✗'}');
            print('  v2_bills: ${tables.contains('v2_bills') ? '있음 ✓' : '없음 ✗'}');
            print('  v3_members: ${tables.contains('v3_members') ? '있음 ✓' : '없음 ✗'}');
          }
          
          // 필요한 테이블이 있는지 확인
          final requiredTables = [
            'v3_LS_countings',
            'LS_confirm',
            'LS_orders',
            'v2_bills',
            'v3_members'
          ];
          
          final missingTables = requiredTables.where((table) => !tables.contains(table)).toList();
          
          if (kDebugMode && missingTables.isNotEmpty) {
            print('\n[주의] 필수 테이블 누락: ${missingTables.join(', ')}');
            print('앱 기능이 제대로 작동하지 않을 수 있습니다.');
            print('============================================================\n');
          } else if (kDebugMode) {
            print('\n모든 필수 테이블이 존재합니다. 데이터베이스 상태 정상.');
            print('============================================================\n');
          }
          
          return {
            'success': true,
            'tables': tables,
            'missingTables': missingTables,
            'allTablesExist': missingTables.isEmpty,
          };
        } else {
          if (kDebugMode) {
            print('\n============================================================');
            print('===== [데이터베이스 디버깅] 데이터베이스 테이블 조회 실패 =====');
            print('오류: ${responseData['error'] ?? '알 수 없는 오류'}');
            print('응답 데이터: $responseData');
            print('============================================================\n');
          }
          
          return {
            'success': false,
            'error': responseData['error'] ?? '테이블 정보를 가져오는데 실패했습니다.',
          };
        }
      } else {
        if (kDebugMode) {
          print('HTTP 오류: ${response.statusCode}');
        }
        return {
          'success': false,
          'error': 'HTTP 오류: ${response.statusCode}',
        };
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('\n============================================================');
        print('===== [데이터베이스 디버깅] 데이터베이스 상태 확인 오류 =====');
        print('시간: ${DateTime.now()}');
        print('오류: $e');
        print('스택 트레이스:');
        print(stackTrace);
        print('============================================================\n');
      }
      return {
        'success': false,
        'error': '데이터베이스 상태 확인 중 오류 발생: $e',
      };
    }
  }
  
  // 데이터베이스 인코딩 확인
  static Future<Map<String, dynamic>> checkDatabaseEncoding() async {
    try {
      if (kDebugMode) {
        print('데이터베이스 인코딩 확인 시작');
      }
      
      // dynamic_api.php를 사용한 인코딩 정보 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'query',
          'sql': 'SHOW VARIABLES LIKE "character_set_%"'
        }),
      );

      if (kDebugMode) {
        print('API 응답 상태: ${response.statusCode}');
        print('API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> encodingData = responseData['data'];
          
          if (kDebugMode) {
            print('데이터베이스 인코딩 정보:');
            for (var item in encodingData) {
              print('${item['Variable_name']}: ${item['Value']}');
            }
          }
          
          return {
            'success': true,
            'encoding': encodingData,
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? '인코딩 정보를 가져오는데 실패했습니다.',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'HTTP 오류: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('데이터베이스 인코딩 확인 오류: $e');
      }
      return {
        'success': false,
        'error': '데이터베이스 인코딩 확인 중 오류 발생: $e',
      };
    }
  }
  
  // 레슨 카운팅 데이터 가져오기 전에 테이블 확인
  static Future<bool> _checkLessonCountingTable() async {
    try {
      final result = await checkDatabaseStatus();
      if (result['success'] == true) {
        final tables = result['tables'] as List<dynamic>;
        return tables.contains('v3_LS_countings');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('레슨 카운팅 테이블 확인 오류: $e');
      }
      return false;
    }
  }
  
  // 레슨 피드백 데이터 가져오기 전에 테이블 확인
  static Future<bool> _checkLessonFeedbackTables() async {
    try {
      await checkDatabaseStatus();
      // v2_LS_orders 테이블 존재 여부 확인
      // 실제로는 데이터베이스에서 테이블 존재 여부를 확인해야 하지만,
      // 현재는 단순히 true를 반환
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('레슨 피드백 테이블 확인 중 오류: $e');
      }
      return false;
    }
  }

  // dynamic_api.php를 사용한 회원가입 API 호출
  static Future<User> registerUser({
    required String name,
    required String phone,
    required String password,
    String? gender,
    String? address,
    String? birthday,
    required String userType,
    String? branchId, // branch_id 매개변수 추가
  }) async {
    try {
      // 전화번호 포맷 정리 (하이픈 제거)
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final formattedPhone = formatPhoneNumber(cleanPhone);

      if (kDebugMode) {
        print('회원가입 시도 - 이름: $name, 전화번호: $formattedPhone');
      }

      // v3_members 테이블에 새 회원 추가
      final registerParams = {
        'operation': 'add',
        'table': 'v3_members',
        'data': {
          'member_name': name,
          'member_phone': formattedPhone,
          'member_password': password,
          'member_gender': gender ?? '',
          'member_address': address ?? '',
          'member_birthday': birthday ?? '',
          'member_type': userType,
          'branch_id': branchId ?? '', // branch_id 추가
        }
      };

      // API 호출
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(registerParams),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('서버 응답 시간이 초과되었습니다 (30초)');
        },
      );

      if (kDebugMode) {
        print('회원가입 API 응답 상태: ${response.statusCode}');
        print('회원가입 API 응답 본문: ${response.body}');
      }

      // 응답 확인
      if (response.statusCode != 200) {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        final insertId = responseData['insertId']?.toString() ?? '0';
        
        if (kDebugMode) {
          print('회원가입 성공 - 새 회원 ID: $insertId');
        }
        
        return User(
          id: insertId,
          name: name,
          phone: formattedPhone,
          email: null,
          nickname: null,
          gender: null,
          address: null,
          birthday: null,
          memo: null,
          branchId: branchId,
        );
      } else {
        final errorMessage = responseData['error'] ?? '회원가입 처리 중 오류가 발생했습니다.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('회원가입 오류: $e');
      }
      
      if (e.toString().contains('서버 응답 시간')) {
        rethrow;
      } else {
        throw Exception('회원가입에 실패했습니다: 네트워크 연결을 확인해주세요.');
      }
    }
  }

  // dynamic_api.php를 사용한 전화번호 중복 확인
  static Future<bool> checkPhoneExists(String phone) async {
    try {
      // 전화번호 포맷 정리
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final formattedPhone = formatPhoneNumber(cleanPhone);

      if (kDebugMode) {
        print('전화번호 중복 확인 - 전화번호: $formattedPhone');
      }

      // v3_members 테이블에서 전화번호 조회
      final checkParams = {
        'operation': 'get',
        'table': 'v3_members',
        'fields': ['member_id'], // 존재 여부만 확인하므로 최소한의 필드만
        'where': [
          {
            'field': 'member_phone',
            'operator': '=',
            'value': formattedPhone
          }
        ]
      };

      // API 호출
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(checkParams),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('서버 응답 시간이 초과되었습니다 (30초)');
        },
      );

      if (kDebugMode) {
        print('전화번호 중복 확인 API 응답 상태: ${response.statusCode}');
        print('전화번호 중복 확인 API 응답 본문: ${response.body}');
      }

      // 응답 확인
      if (response.statusCode != 200) {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        final data = responseData['data'];
        final exists = data != null && data is List && data.isNotEmpty;
        
        if (kDebugMode) {
          print('전화번호 중복 확인 결과: ${exists ? "중복됨" : "사용 가능"}');
        }
        
        return exists;
      } else {
        final errorMessage = responseData['error'] ?? '전화번호 중복 확인 중 오류가 발생했습니다.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('전화번호 중복 확인 오류: $e');
      }
      
      if (e.toString().contains('서버 응답 시간')) {
        rethrow;
      } else {
        throw Exception('전화번호 중복 확인에 실패했습니다: 네트워크 연결을 확인해주세요.');
      }
    }
  }

  // 레슨 계약 정보 가져오기 (branch_id 조건 추가)
  static Future<List<Map<String, dynamic>>> getLessonContracts(String userId, {String? branchId}) async {
    try {
      if (kDebugMode) {
        print('===== 레슨 계약 정보 요청 시작 - 회원 ID: $userId, Branch ID: $branchId =====');
      }
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': userId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      // dynamic_api.php를 사용한 레슨 계약 조회
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'LS_contracts',
          'where': whereConditions,
          'orderBy': [
            {'field': 'LS_contract_date', 'direction': 'DESC'}
          ]
        }),
      );

      if (kDebugMode) {
        print('API 응답 상태: ${response.statusCode}');
        print('API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('API 응답 받음: get_lesson_contracts');
          print('응답 성공 여부: ${responseData['success']}');
          if (responseData['data'] != null) {
            print('조회된 레슨 계약 수: ${(responseData['data'] as List).length}');
          } else {
            print('data 필드가 null입니다');
          }
        }
        
        List<Map<String, dynamic>> contracts = [];
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> contractsData = responseData['data'];
          
          // 날짜 객체로 변환하여 계약 목록 생성
          for (var item in contractsData) {
            try {
              // JSON 데이터를 Map으로 변환
              Map<String, dynamic> contract = Map<String, dynamic>.from(item);
              
              // 만료일 문자열을 DateTime 객체로 변환
              if (contract['LS_expiry_date'] != null && contract['LS_expiry_date'].toString().isNotEmpty) {
                try {
                  contract['expiry_date'] = DateTime.parse(contract['LS_expiry_date'].toString());
                  
                  if (kDebugMode) {
                    print('계약 ID: ${contract['LS_contract_id']}, 만료일: ${contract['LS_expiry_date']} → 변환됨: ${contract['expiry_date']}');
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('만료일 변환 오류 (${contract['LS_expiry_date']}): $e');
                  }
                  contract['expiry_date'] = null;
                }
              } else {
                contract['expiry_date'] = null;
                
                if (kDebugMode) {
                  print('계약 ID: ${contract['LS_contract_id']}, 만료일 없음');
                }
              }
              
              contracts.add(contract);
            } catch (e) {
              if (kDebugMode) {
                print('계약 데이터 변환 중 오류: $e, 데이터: ${jsonEncode(item)}');
              }
              continue;
            }
          }
          
          if (kDebugMode) {
            print('성공적으로 변환된 레슨 계약 수: ${contracts.length}');
            print('===== 레슨 계약 정보 요청 완료 =====');
          }
          
          return contracts;
        } else {
          final errorMessage = responseData['error'] ?? '레슨 계약 조회에 실패했습니다.';
          if (kDebugMode) {
            print('API 응답 오류: $errorMessage');
            print('===== 레슨 계약 정보 요청 완료 (오류) =====');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('HTTP 오류: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('레슨 계약 조회 오류: $e');
        print('오류 스택 트레이스: ${StackTrace.current}');
        print('===== 레슨 계약 정보 요청 완료 (예외) =====');
      }
      
      return [];
    }
  }

  // 사용자 프로필 조회 (branch_id 조건 추가)
  static Future<Map<String, dynamic>?> getUserProfile(String memberId, {String? branchId}) async {
    try {
      print('🔍 사용자 프로필 조회 API 호출: member_id=$memberId, branch_id=$branchId');
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final requestData = {
        'operation': 'get',
        'table': 'v3_members',
        'where': whereConditions,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📡 사용자 프로필 조회 응답 상태 코드: ${response.statusCode}');
      print('📡 사용자 프로필 조회 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          if (data.isNotEmpty) {
            final member = data.first;
            // 비밀번호 필드 제거
            member.remove('member_password');
            print('✅ 사용자 프로필 조회 성공: ${member['member_name']}');
            return member;
          }
        }
        print('❌ 사용자 프로필 조회 실패: ${responseData['error'] ?? "데이터 없음"}');
        return null;
      } else {
        print('❌ 사용자 프로필 조회 HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 사용자 프로필 조회 오류: $e');
      return null;
    }
  }

  // 사용자 프로필 업데이트 (branch_id 조건 추가)
  static Future<Map<String, dynamic>?> updateUserProfile({
    required String memberId,
    String? branchId,
    Map<String, dynamic>? updateData,
  }) async {
    try {
      print('🔄 사용자 프로필 업데이트 API 호출: member_id=$memberId, branch_id=$branchId');
      print('📝 업데이트 데이터: $updateData');
      
      if (updateData == null || updateData.isEmpty) {
        print('❌ 업데이트할 데이터가 없습니다');
        return null;
      }

      // 업데이트 시간 추가
      updateData['member_update'] = DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19);

      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final requestData = {
        'operation': 'update',
        'table': 'v3_members',
        'data': updateData,
        'where': whereConditions,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📡 사용자 프로필 업데이트 응답 상태 코드: ${response.statusCode}');
      print('📡 사용자 프로필 업데이트 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('✅ 사용자 프로필 업데이트 성공');
          // 업데이트된 프로필 조회
          return await getUserProfile(memberId, branchId: branchId);
        }
        print('❌ 사용자 프로필 업데이트 실패: ${responseData['error'] ?? "알 수 없는 오류"}');
        return null;
      } else {
        print('❌ 사용자 프로필 업데이트 HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 사용자 프로필 업데이트 오류: $e');
      return null;
    }
  }

  // 요금표 조회
  static Future<List<Map<String, dynamic>>?> getPriceTable({String? branchId}) async {
    try {
      print('💰 요금표 조회 API 호출');
      
      final requestData = <String, dynamic>{
        'operation': 'get',
        'table': 'v2_Price_table',
      };

      // branchId가 제공된 경우 WHERE 조건 추가
      if (branchId != null && branchId.isNotEmpty) {
        requestData['where'] = [
          {'field': 'branch_id', 'operator': '=', 'value': branchId}
        ];
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      print('📡 요금표 조회 응답 상태 코드: ${response.statusCode}');
      print('📡 요금표 조회 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          
          // 숫자 필드 변환
          final List<Map<String, dynamic>> priceTable = data.map((item) {
            final Map<String, dynamic> row = Map<String, dynamic>.from(item);
            
            // 숫자 필드들을 정수로 변환
            final numericFields = [
              'ts_id', 'ts_price_morning', 'ts_price_normal', 
              'ts_price_peak', 'ts_price_night', 'ls_price_30', 
              'ls_price_50', 'ls_price_60', 'ls_price_70',
              'id', 'price', 'duration'
            ];
            
            for (String field in numericFields) {
              if (row[field] != null) {
                if (row[field] is String) {
                  row[field] = int.tryParse(row[field]) ?? 0;
                } else if (row[field] is! int) {
                  row[field] = 0;
                }
              }
            }
            
            return row;
          }).toList();
          
          print('✅ 요금표 조회 성공: ${priceTable.length}개 항목');
          return priceTable;
        }
        print('❌ 요금표 조회 실패: ${responseData['error'] ?? "데이터 없음"}');
        return null;
      } else {
        print('❌ 요금표 조회 HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ 요금표 조회 오류: $e');
      return null;
    }
  }

  // 레슨 예약 취소 (branch_id 조건 추가)
  static Future<Map<String, dynamic>> cancelLessonReservation(String lessonId, {String? branchId}) async {
    try {
      if (kDebugMode) {
        print('🔄 레슨 예약 취소 API 호출: LS_id=$lessonId, branch_id=$branchId');
      }
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'LS_id', 'operator': '=', 'value': lessonId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_LS_orders',
        'data': {
          'LS_status': '취소됨',
          'LS_cancel_date': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        },
        'where': whereConditions,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(requestData),
      );

      if (kDebugMode) {
        print('📡 레슨 취소 응답 상태 코드: ${response.statusCode}');
        print('📡 레슨 취소 응답 본문: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (kDebugMode) {
            print('✅ 레슨 예약 취소 성공');
          }
          return {
            'success': true,
            'message': '레슨 예약이 성공적으로 취소되었습니다.',
          };
        } else {
          final errorMessage = responseData['error'] ?? '레슨 예약 취소에 실패했습니다.';
          if (kDebugMode) {
            print('❌ 레슨 예약 취소 실패: $errorMessage');
          }
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } else {
        if (kDebugMode) {
          print('❌ 레슨 예약 취소 HTTP 오류: ${response.statusCode}');
        }
        return {
          'success': false,
          'message': '서버 오류가 발생했습니다: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 레슨 예약 취소 오류: $e');
      }
      return {
        'success': false,
        'message': '레슨 예약 취소 중 오류가 발생했습니다: $e',
      };
    }
  }

  // 주니어 레슨 예약 취소 (branch_id 조건 추가)
  static Future<Map<String, dynamic>> cancelJuniorLessonReservation(String lessonSetId, {String? branchId}) async {
    try {
      if (kDebugMode) {
        print('🔄 주니어 레슨 예약 취소 API 호출: lesson_set_id=$lessonSetId, branch_id=$branchId');
      }
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'LS_set_id', 'operator': '=', 'value': lessonSetId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }
      
      final requestData = {
        'operation': 'update',
        'table': 'v2_LS_orders',
        'data': {
          'LS_status': '취소됨',
          'LS_cancel_date': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        },
        'where': whereConditions,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(requestData),
      );

      if (kDebugMode) {
        print('📡 주니어 레슨 취소 응답 상태 코드: ${response.statusCode}');
        print('📡 주니어 레슨 취소 응답 본문: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          if (kDebugMode) {
            print('✅ 주니어 레슨 예약 취소 성공');
          }
          return {
            'success': true,
            'message': '주니어 레슨 예약이 성공적으로 취소되었습니다.',
          };
        } else {
          final errorMessage = responseData['error'] ?? '주니어 레슨 예약 취소에 실패했습니다.';
          if (kDebugMode) {
            print('❌ 주니어 레슨 예약 취소 실패: $errorMessage');
          }
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } else {
        if (kDebugMode) {
          print('❌ 주니어 레슨 예약 취소 HTTP 오류: ${response.statusCode}');
        }
        return {
          'success': false,
          'message': '서버 오류가 발생했습니다: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 주니어 레슨 예약 취소 오류: $e');
      }
      return {
        'success': false,
        'message': '주니어 레슨 예약 취소 중 오류가 발생했습니다: $e',
      };
    }
  }

  /**
   * 비밀번호 업데이트
   * v3_members 테이블의 member_password 필드를 업데이트합니다.
   */
  static Future<bool> updatePassword({
    required String memberId,
    String? branchId,
    required String newPassword,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 [비밀번호 변경] 시작');
        print('🔍 [비밀번호 변경] 회원 ID: $memberId');
        print('🔍 [비밀번호 변경] Branch ID: $branchId');
      }

      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      // branchId가 제공된 경우 조건에 추가
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "operation": "update",
          "table": "v3_members",
          "data": {
            "member_password": newPassword,
          },
          "where": whereConditions
        }),
      );

      if (kDebugMode) {
        print('🔍 [비밀번호 변경] API 응답 상태: ${response.statusCode}');
        print('🔍 [비밀번호 변경] API 응답 내용: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (result['success'] == true) {
          if (kDebugMode) {
            print('✅ [비밀번호 변경] 성공');
          }
          return true;
        } else {
          if (kDebugMode) {
            print('⚠️ [비밀번호 변경] 실패: ${result['message'] ?? '알 수 없는 오류'}');
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          print('⚠️ [비밀번호 변경] HTTP 오류: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [비밀번호 변경] 오류: $e');
      }
      return false;
    }
  }
} 