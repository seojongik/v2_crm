import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lesson_availability_check.dart';
import '../../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

/// 레슨 예약 화면
/// 타석 예약에서 이어지는 레슨 예약 화면입니다.
class LessonReservationScreen extends StatefulWidget {
  final int? memberId;
  final Map<String, dynamic> tsReservationInfo;
  final String? branchId;

  const LessonReservationScreen({
    Key? key,
    required this.memberId,
    required this.tsReservationInfo,
    required this.branchId,
  }) : super(key: key);

  @override
  State<LessonReservationScreen> createState() => _LessonReservationScreenState();
}

class _LessonReservationScreenState extends State<LessonReservationScreen> {
  // 상태 변수
  bool _isLoading = false;
  List<Map<String, dynamic>> _lessonStatus = [];
  String? _selectedPro;
  String? _selectedProNickname;
  Map<String, dynamic>? _selectedLessonStatus;
  Map<String, dynamic>? _selectedStaffInfo; // 선택된 프로의 상세 정보
  Map<String, dynamic>? _selectedContract; // 선택된 계약 정보 추가
  List<Map<String, dynamic>> _availableTimeBlocks = [];
  Map<String, dynamic>? _selectedTimeBlock;
  int _lessonDuration = 15; // 기본 레슨 시간 15분
  List<Map<String, dynamic>> _selectedTimeBlocks = []; // 다중 레슨 예약을 위한 선택된 블록 목록
  List<Map<String, dynamic>> _staffList = []; // 프로 목록 정보
  List<Map<String, dynamic>> _lessonContracts = []; // 레슨 계약 정보 추가
  
  // 레슨 시작/종료 시간 선택 변수
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  
  // 레슨 간 간격 (기본값 0분)
  final int _lessonGap = 15;

  // 최종 예약 데이터
  Map<String, dynamic> _reservationData = {};

  @override
  void initState() {
    super.initState();
    _loadStaffList();
    _loadLessonStatus();
  }

  // 스태프 목록 로드
  Future<void> _loadStaffList() async {
    try {
      final currentBranchId = Provider.of<UserProvider>(context, listen: false).currentBranchId;
      
      final whereConditions = <Map<String, dynamic>>[];
      
      // branch_id 조건 추가
      if (currentBranchId != null && currentBranchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': currentBranchId});
      }
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_staff_pro',
          'fields': ['pro_name', 'staff_nickname'],
          'where': whereConditions.isNotEmpty ? whereConditions : null,
          'orderBy': [
            {'field': 'pro_name', 'direction': 'ASC'}
          ]
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true && resp['data'] != null) {
          setState(() {
            _staffList = List<Map<String, dynamic>>.from(resp['data'] as List);
          });
          
          // 스태프 정보 디버깅
          print('🔍 [디버깅] 스태프 목록 불러옴: ${_staffList.length}명 (v2_staff_pro 테이블 사용)');
          if (_staffList.isNotEmpty) {
            print('🔍 [디버깅] 첫번째 스태프 필드: ${_staffList.first.keys.join(', ')}');
            print('🔍 [디버깅] 첫번째 스태프 정보: ${_staffList.first}');
          }
        }
      }
    } catch (e) {
      print('❌ 스태프 목록 로드 중 오류: $e');
    }
  }

  // 레슨 상태 정보 로드
  Future<void> _loadLessonStatus() async {
    if (widget.memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 정보가 필요합니다. 로그인 후 이용해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 계약 정보 먼저 조회 - 순서 변경
      await _fetchLessonContracts(widget.memberId!, widget.branchId);
      
      // LessonAvailabilityCheck 클래스에서 레슨 상태 조회 메서드 활용
      final lessonStatus = await _fetchLessonStatus(widget.memberId!, widget.branchId);
      
      if (mounted) {
        setState(() {
          _lessonStatus = lessonStatus;
          _isLoading = false;
        });
      }

      // 디버깅
      print('🔍 [디버깅] 레슨 상태 정보: $lessonStatus');
      
      // 사용 가능한 계약이 없으면 알림
      if (_lessonContracts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약 가능한 레슨 계약이 없습니다.')),
        );
      }
    } catch (e) {
      print('❌ 레슨 상태 정보 로드 중 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('레슨 정보를 가져오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 레슨 계약 정보 가져오기
  Future<void> _fetchLessonContracts(int memberId, String? branchId) async {
    try {
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_contracts',
          'where': whereConditions
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        print('🔍 [디버깅] 레슨 계약 API 응답: ${resp}');
        
        if (resp['success'] == true && resp['data'] != null) {
          final contracts = List<Map<String, dynamic>>.from(resp['data'] as List);
          
          // 각 계약에 만료일 정보를 DateTime 객체로 변환하여 추가하고 유효성 확인
          final today = DateTime.now();
          for (var contract in contracts) {
            // 만료일 문자열을 DateTime 객체로 변환
            if (contract['LS_expiry_date'] != null && contract['LS_expiry_date'].toString().isNotEmpty) {
              try {
                final expiryDate = DateTime.parse(contract['LS_expiry_date'].toString());
                contract['expiry_date'] = expiryDate;
                // 만료 여부 확인 (현재 날짜와 비교)
                contract['is_valid'] = expiryDate.isAfter(today);
              } catch (e) {
                print('⚠️ 만료일 변환 오류 (${contract['LS_expiry_date']}): $e');
                contract['expiry_date'] = null;
                contract['is_valid'] = true; // 만료일을 파싱할 수 없는 경우 기본적으로 유효하다고 간주
              }
            } else {
              contract['expiry_date'] = null;
              contract['is_valid'] = true; // 만료일이 없는 경우 기본적으로 유효하다고 간주
            }
          }
          
          _lessonContracts = contracts;
          
          // 디버깅 정보 출력 - 상세 정보
          print('============================================================');
          print('===== [디버깅] 회원 ID $memberId의 레슨 계약 정보 =====');
          print('계약 개수: ${contracts.length}');
          
          if (contracts.isNotEmpty) {
            print('\n계약 목록:');
            for (int i = 0; i < contracts.length; i++) {
              final contract = contracts[i];
              print('\n[$i] 계약 정보:');
              print('계약 ID: ${contract['LS_contract_id']}');
              print('계약명: ${contract['contract_name']}');
              print('유형: ${contract['LS_type']}');
              print('담당 프로: ${contract['LS_contract_pro']}');
              print('계약일: ${contract['LS_contract_date']}');
              print('만료일: ${contract['LS_expiry_date']}');
              print('만료 여부: ${contract['is_valid'] ? '유효함' : '만료됨'}');
              print('수량: ${contract['contract_qty']}');
              print('회당 시간: ${contract['LS_min_per_qty']}');
            }
          } else {
            print('계약 정보가 없습니다.');
          }
          
          print('\n[디버깅] getLessonCounting과 v2_LS_contracts 비교:');
          print('레슨 계약 수: ${_lessonContracts.length}');
          print('레슨 카운팅 수: ${_lessonStatus.length}');
          
          // 두 데이터 간 비교
          for (final status in _lessonStatus) {
            final proName = status['LS_contract_pro'] ?? '';
            print('\n프로: $proName');
            print('카운팅 잔여 시간: ${status['LS_balance_min_after'] ?? 0}분');
            
            // 해당 프로의 계약 찾기
            final matchingContracts = _lessonContracts.where(
              (contract) => contract['LS_contract_pro'] == proName
            ).toList();
            
            print('관련 계약 수: ${matchingContracts.length}개');
            for (final contract in matchingContracts) {
              print('- 계약명: ${contract['contract_name']}, 유형: ${contract['LS_type']}, 유효성: ${contract['is_valid'] ? '유효' : '만료'}');
            }
          }
          
          print('============================================================');
        } else {
          print('❌ 레슨 계약 조회 실패: ${resp['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        print('❌ 레슨 계약 API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ 레슨 계약 정보 조회 중 예외 발생: $e');
    }
  }

  // 레슨 상태 정보 가져오기 (LessonAvailabilityCheck 클래스 코드 재사용)
  Future<List<Map<String, dynamic>>> _fetchLessonStatus(int memberId, String? branchId) async {
    try {
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': memberId}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v3_LS_countings',
          'where': whereConditions
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true && resp['data'] != null) {
          final countings = resp['data'] as List;
          
          // 첫 번째 항목의 모든 필드 출력
          if (countings.isNotEmpty) {
            print('첫 번째 레슨 항목의 모든 필드: ${countings.first.keys.toList()}');
            print('첫 번째 레슨 항목 값: ${countings.first}');
          }
          
          print('레슨 상태 API 응답: ${resp['data']}');
          
          // 모든 항목 정수 변환 처리
          final List<Map<String, dynamic>> processedCountings = List<Map<String, dynamic>>.from(countings)
            .map((counting) {
              // ID 필드 변환 (LS_counting_id 또는 LC_counting_id)
              if (counting.containsKey('LS_counting_id')) {
                _convertToInt(counting, 'LS_counting_id');
              } else if (counting.containsKey('LC_counting_id')) {
                _convertToInt(counting, 'LC_counting_id');
                // 필드명 오타 수정 (오타가 수정되기 전 데이터도 처리하기 위함)
                counting['LS_counting_id'] = counting['LC_counting_id'];
              }
              
              // 계약 ID 필드 변환
              _convertToInt(counting, 'LS_contract_id');
              
              // 잔여 시간 관련 필드 변환
              _convertToInt(counting, 'LS_balance_min');
              _convertToInt(counting, 'LS_balance_min_after');
              
              return counting;
            })
            .toList();
          
          // 중요 필드 디버깅 출력
          print('\n🔍 [디버깅] LS_countings 테이블 데이터 처리 결과:');
          for (final counting in processedCountings) {
            print('- 카운팅 ID: ${counting['LS_counting_id']}, 계약 ID: ${counting['LS_contract_id']}, 프로: ${counting['LS_contract_pro']}, 잔여 시간: ${counting['LS_balance_min_after']}분');
          }
            
          return processedCountings;
        }
      }
      
      print('레슨 상태 API 오류 또는 데이터 없음: ${response.statusCode}');
      return [];
    } catch (e) {
      print('레슨 상태 API 예외 발생: $e');
      return [];
    }
  }

  // 문자열을 정수로 변환하는 헬퍼 메서드
  void _convertToInt(Map<String, dynamic> map, String key) {
    if (map.containsKey(key)) {
      var value = map[key];
      if (value is String) {
        map[key] = int.tryParse(value) ?? 0;
      } else if (value is! int) {
        map[key] = 0;
      }
    }
  }

  // 프로 선택 후 해당 프로의 닉네임 조회
  Future<String?> _fetchStaffNickname(String staffName) async {
    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'Staff',
          'fields': ['staff_name', 'staff_nickname'],
          'where': [
            {'field': 'staff_name', 'operator': '=', 'value': staffName}
          ]
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true && resp['data'] != null) {
          print('스태프 목록 API 응답: ${resp['data']}');
          
          final staffList = List<Map<String, dynamic>>.from(resp['data'] as List);
          
          if (staffList.isNotEmpty) {
            return staffList.first['staff_nickname'];
          }
        }
      }
      
      print('스태프 닉네임을 찾을 수 없음: $staffName');
      return null;
    } catch (e) {
      print('스태프 목록 API 예외 발생: $e');
      return null;
    }
  }

  // 계약 선택 및 사용 가능한 시간 블록 조회 (기존 _selectProAndGetAvailableTimes 대체)
  Future<void> _selectContractAndGetAvailableTimes() async {
    if (_selectedContract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('레슨 계약을 먼저 선택해주세요.')),
      );
      return;
    }

    // 선택된 계약에서 담당 프로 이름 추출
    final proName = _selectedContract!['LS_contract_pro'] as String? ?? '';
    if (proName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 계약에 담당 프로 정보가 없습니다.')),
      );
      return;
    }
    
    // 계약 ID 가져오기
    final contractId = _selectedContract!['LS_contract_id'];
    if (contractId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 계약에 계약 ID가 없습니다.')),
      );
      return;
    }

    // 프로 이름 설정
    _selectedPro = proName;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 선택된 프로의 설정 정보 불러오기
      _selectedStaffInfo = _staffList.firstWhere(
        (staff) => staff['pro_name'] == _selectedPro,
        orElse: () => {},
      );
      
      // 디버깅
      if (_selectedStaffInfo != null && _selectedStaffInfo!.isNotEmpty) {
        print('🔍 [디버깅] 선택된 프로 정보: $_selectedStaffInfo');
        print('🔍 [디버깅] 최소 예약 시간: ${_getMinServiceTime()}분');
        print('🔍 [디버깅] 추가 시간 단위: ${_getServiceTimeUnit()}분');
        print('🔍 [디버깅] 최소 예약 가능 시간: ${_getMinReservationTerm()}분');
      }

      // 2. 프로 닉네임 조회
      final staffNickname = _selectedStaffInfo?['staff_nickname'] ?? await _fetchStaffNickname(_selectedPro!);
      
      if (staffNickname == null) {
        throw Exception('해당 프로의 닉네임을 찾을 수 없습니다.');
      }

      _selectedProNickname = staffNickname;

      // 3. 잔여 시간 정보 조회 (계약 ID로 카운팅 정보 찾기)
      _selectedLessonStatus = _findLessonStatusByContractId(contractId);
      
      if (_selectedLessonStatus == null) {
        // 카운팅 정보가 없는 경우 API에서 다시 조회 시도
        await _refreshLessonStatus();
        
        // 다시 찾기
        _selectedLessonStatus = _findLessonStatusByContractId(contractId);
        
        // 여전히 없으면 오류
        if (_selectedLessonStatus == null) {
          throw Exception('선택한 계약의 레슨 잔여 시간 정보를 찾을 수 없습니다.');
        }
      }

      // 4. 타석 예약 날짜 가져오기 (정렬된 문자열)
      final selectedDate = widget.tsReservationInfo['formattedDate'] as String;
      
      // 5. 프로의 스케줄 조회
      final proId = _selectedStaffInfo?['pro_id'];
      if (proId == null) {
        throw Exception('프로 ID를 찾을 수 없습니다.');
      }
      
      final schedule = await LessonAvailabilityCheck.fetchStaffSchedule(proId, selectedDate, branchId: widget.branchId);
      
      // 6. 프로의 예약 현황 조회 (서버에는 staff_name으로 전송됨)
      final orders = await _fetchProOrders(_selectedPro!, selectedDate);
      
      // 7. 사용 가능한 시간 블록 계산
      final availableTimeBlocks = _calculateAvailableTimeBlocks(schedule, orders);
      
      // 8. 타석 예약 시간과 겹치는 시간 블록만 필터링
      final filteredTimeBlocks = _filterTimeBlocksByTSReservation(availableTimeBlocks);
      
      if (mounted) {
        setState(() {
          _availableTimeBlocks = filteredTimeBlocks;
          _isLoading = false;
          
          // 초기 레슨 시간 설정
          _lessonDuration = _getMinServiceTime();
        });
      }

      // 사용 가능한 시간 블록이 없으면 알림
      if (filteredTimeBlocks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('타석 예약 시간과 겹치는 레슨 가능 시간이 없습니다.')),
        );
      }
    } catch (e) {
      print('❌ 프로 일정 정보 로드 중 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로 일정 정보를 가져오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
  
  // 프로 이름으로 레슨 카운팅 정보 찾기 (새로 추가)
  Map<String, dynamic>? _findLessonStatusByProName(String proName) {
    for (final status in _lessonStatus) {
      if ((status['LS_contract_pro'] ?? '') == proName) {
        return status;
      }
    }
    return null;
  }
  
  // 계약 ID로 레슨 카운팅 정보 찾기 (새로 추가)
  Map<String, dynamic>? _findLessonStatusByContractId(dynamic contractId) {
    // contractId가 null인 경우 처리
    if (contractId == null) return null;
    
    // 계약 ID가 문자열 또는 숫자로 저장되어 있을 수 있으므로 모두 문자열로 변환하여 비교
    final contractIdStr = contractId.toString();
    
    // 해당 계약 ID를 가진 모든 레코드 찾기
    final matchingRecords = <Map<String, dynamic>>[];
    
    for (final status in _lessonStatus) {
      // LS_contract_id가 없는 경우 처리
      if (!status.containsKey('LS_contract_id')) continue;
      
      // 동일한 문자열로 비교
      final statusContractId = status['LS_contract_id'];
      if (statusContractId != null && statusContractId.toString() == contractIdStr) {
        matchingRecords.add(status);
      }
    }
    
    if (matchingRecords.isEmpty) {
      print('❌ 계약 ID($contractId)에 해당하는 카운팅 정보를 찾을 수 없음');
      
      // 찾지 못한 경우 디버깅 정보 출력
      print('🔍 [디버깅] 현재 카운팅 정보 목록:');
      for (final status in _lessonStatus) {
        print('- 카운팅 ID: ${status['LS_counting_id']}, 계약 ID: ${status['LS_contract_id']}, 프로: ${status['LS_contract_pro']}, 잔여시간: ${status['LS_balance_min_after']}분');
      }
      
      return null;
    }
    
    // LS_counting_id 기준으로 정렬 (가장 큰 값이 가장 최신)
    matchingRecords.sort((a, b) {
      final aId = a['LS_counting_id'] is int ? a['LS_counting_id'] : int.tryParse(a['LS_counting_id']?.toString() ?? '0') ?? 0;
      final bId = b['LS_counting_id'] is int ? b['LS_counting_id'] : int.tryParse(b['LS_counting_id']?.toString() ?? '0') ?? 0;
      return bId.compareTo(aId); // 내림차순 정렬 (가장 큰 값이 먼저)
    });
    
    // 가장 최신 레코드 반환
    final latestRecord = matchingRecords.first;
    print('🔍 [디버깅] 계약 ID($contractId)에 대한 최신 카운팅 정보: LS_counting_id=${latestRecord['LS_counting_id']}, 잔여시간=${latestRecord['LS_balance_min_after']}분');
    
    return latestRecord;
  }
  
  // 레슨 상태 정보 갱신 (새로 추가)
  Future<void> _refreshLessonStatus() async {
    try {
      final lessonStatus = await _fetchLessonStatus(widget.memberId!, widget.branchId);
      
      setState(() {
        _lessonStatus = lessonStatus;
      });
      
      print('🔍 [디버깅] 레슨 상태 정보 갱신: $_lessonStatus');
    } catch (e) {
      print('❌ 레슨 상태 정보 갱신 중 오류: $e');
      throw Exception('레슨 상태 정보 갱신 중 오류: $e');
    }
  }

  // 최소 서비스 시간 (최소 예약 시간)
  int _getMinServiceTime() {
    if (_selectedStaffInfo != null && _selectedStaffInfo!.isNotEmpty) {
      // min_service_min 필드가 있는지 확인
      if (_selectedStaffInfo!.containsKey('min_service_min')) {
        final minServiceMin = _selectedStaffInfo!['min_service_min'];
        if (minServiceMin != null) {
          // 문자열이면 정수로 변환
          if (minServiceMin is String) {
            return int.tryParse(minServiceMin) ?? 15;
          } else if (minServiceMin is int) {
            return minServiceMin;
          }
        }
      }
    }
    return 15; // 기본값 15분
  }
  
  // 서비스 시간 단위 (추가 시간 단위)
  int _getServiceTimeUnit() {
    if (_selectedStaffInfo != null && _selectedStaffInfo!.isNotEmpty) {
      // staff_svc_time 필드가 있는지 확인
      if (_selectedStaffInfo!.containsKey('staff_svc_time')) {
        final staffSvcTime = _selectedStaffInfo!['staff_svc_time'];
        if (staffSvcTime != null) {
          // 문자열이면 정수로 변환
          if (staffSvcTime is String) {
            return int.tryParse(staffSvcTime) ?? 10;
          } else if (staffSvcTime is int) {
            return staffSvcTime;
          }
        }
      }
    }
    return 10; // 기본값 10분
  }
  
  // 최소 예약 가능 시간 (현재로부터 몇 분 후부터 예약 가능한지)
  int _getMinReservationTerm() {
    if (_selectedStaffInfo != null && _selectedStaffInfo!.isNotEmpty) {
      // min_reservation_term 필드가 있는지 확인
      if (_selectedStaffInfo!.containsKey('min_reservation_term')) {
        final minReservationTerm = _selectedStaffInfo!['min_reservation_term'];
        if (minReservationTerm != null) {
          // 문자열이면 정수로 변환
          if (minReservationTerm is String) {
            return int.tryParse(minReservationTerm) ?? 30;
          } else if (minReservationTerm is int) {
            return minReservationTerm;
          }
        }
      }
    }
    return 30; // 기본값 30분
  }

  // 사용 가능한 시간 블록 계산
  List<Map<String, dynamic>> _calculateAvailableTimeBlocks(
      Map<String, dynamic>? schedule, List<dynamic> orders) {
    
    // API에서 schedule 데이터가 없는 경우 에러 처리
    if (schedule == null || schedule.isEmpty) {
      print('오류: API에서 스케줄 정보를 가져오지 못했습니다.');
      return []; // 빈 배열 반환
    }
    
    // schedule에서 값을 추출
    final workStartStr = schedule['work_start'] ?? '';
    final workEndStr = schedule['work_end'] ?? '';
    final breakStartStr = schedule['break_start'] ?? '';
    final breakEndStr = schedule['break_end'] ?? '';
    
    // 값이 비어있는 경우 오류 처리
    if (workStartStr.isEmpty || workEndStr.isEmpty || 
        breakStartStr.isEmpty || breakEndStr.isEmpty) {
      print('오류: 스케줄 정보가 불완전합니다.');
      return []; // 빈 배열 반환
    }
    
    // 시간 문자열을 분으로 변환
    int toMinutes(String t) {
      final parts = t.split(':');
      if (parts.length < 2) return 0;
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    
    final workStart = toMinutes(workStartStr);
    final workEnd = toMinutes(workEndStr);
    final breakStart = toMinutes(breakStartStr);
    final breakEnd = toMinutes(breakEndStr);
    
    // 예약 구간 추출
    List<List<int>> reserved = [];
    for (final order in orders) {
      final startTimeStr = order['LS_start_time'] ?? '';
      final endTimeStr = order['LS_end_time'] ?? '';
      
      if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) {
        final s = toMinutes(startTimeStr);
        final e = toMinutes(endTimeStr);
        
        if (s < e) {
          reserved.add([s, e]);
        }
      }
    }
    
    // 실제 예약 가능 구간 추출
    final availableBlocks = LessonAvailabilityCheck.getAvailableBlocks(
      workStart: workStart,
      workEnd: workEnd,
      reserved: reserved,
      breakRange: [breakStart, breakEnd],
    );
    
    // 각 블록을 시간 형식으로 변환하여 반환
    return availableBlocks.map((block) {
      final startMin = block['start']!;
      final endMin = block['end']!;
      final startHour = startMin ~/ 60;
      final startMinute = startMin % 60;
      final endHour = endMin ~/ 60;
      final endMinute = endMin % 60;
      
      return {
        'startMin': startMin,
        'endMin': endMin,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'startFormatted': '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}',
        'endFormatted': '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
      };
    }).toList();
  }

  // 타석 예약 시간과 겹치는 시간 블록만 필터링
  List<Map<String, dynamic>> _filterTimeBlocksByTSReservation(List<Map<String, dynamic>> timeBlocks) {
    // 타석 예약 시간 정보 가져오기
    final startTime = widget.tsReservationInfo['startTime'] as TimeOfDay;
    final endTime = widget.tsReservationInfo['endTime'] as TimeOfDay;
    
    // 타석 시작 및 종료 시간을 분으로 변환
    final tsStartMin = startTime.hour * 60 + startTime.minute;
    final tsEndMin = endTime.hour * 60 + endTime.minute;
    
    // 예약 날짜와 현재 날짜 비교
    final reservationDate = DateFormat('yyyy-MM-dd').parse(widget.tsReservationInfo['formattedDate'] as String);
    final today = DateTime.now();
    final isToday = reservationDate.year == today.year && 
                   reservationDate.month == today.month && 
                   reservationDate.day == today.day;
    
    // 현재 시간 기준 최소 예약 가능 시간 계산 (당일 예약인 경우에만)
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    // 당일 예약인 경우에만 최소 예약 가능 시간 적용, 미래 날짜는 0으로 설정(제약 없음)
    final minReservableMin = isToday ? (currentMin + _getMinReservationTerm()) : 0;
    
    // 디버깅
    print('🔍 [디버깅] 예약 날짜: ${widget.tsReservationInfo['formattedDate']}');
    print('🔍 [디버깅] 오늘 날짜: ${DateFormat('yyyy-MM-dd').format(today)}');
    print('🔍 [디버깅] 당일 예약 여부: $isToday');
    print('🔍 [디버깅] 타석 예약 시간: $tsStartMin분 ~ $tsEndMin분');
    print('🔍 [디버깅] 현재 시간: $currentMin분');
    print('🔍 [디버깅] 최소 예약 가능 시간: ${_getMinReservationTerm()}분');
    print('🔍 [디버깅] 최소 예약 가능 시간점: $minReservableMin분');
    print('🔍 [디버깅] 레슨 가능 시간 블록 수: ${timeBlocks.length}');
    
    // 타석 예약 시간과 겹치는 시간 블록만 필터링 + 당일 예약인 경우 최소 예약 가능 시간 이후만 가능
    final filteredBlocks = timeBlocks.where((block) {
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      // 블록 시작 시간이 현재 시간 + 최소 예약 가능 시간 이후인지 확인 (당일 예약만 적용)
      final isAfterMinReservable = isToday ? (blockStartMin >= minReservableMin) : true;
      
      // 겹침 여부 계산: 어느 한쪽이 다른쪽을 완전히 포함하거나, 부분적으로 겹치는 경우
      final isOverlapping = 
        // 시간 블록이 타석 시간을 포함하는 경우
        (blockStartMin <= tsStartMin && blockEndMin >= tsEndMin) ||
        // 타석 시간이 시간 블록을 포함하는 경우
        (tsStartMin <= blockStartMin && tsEndMin >= blockEndMin) ||
        // 시간 블록의 시작이 타석 시간 내에 있는 경우
        (blockStartMin >= tsStartMin && blockStartMin < tsEndMin) ||
        // 시간 블록의 종료가 타석 시간 내에 있는 경우
        (blockEndMin > tsStartMin && blockEndMin <= tsEndMin);
      
      // 두 조건 모두 만족해야 예약 가능
      final isAvailable = isOverlapping && isAfterMinReservable;
      
      // 디버깅
      if (isAvailable) {
        print('✅ 예약 가능한 시간 블록: ${block['startFormatted']} ~ ${block['endFormatted']}');
      } else if (isOverlapping && !isAfterMinReservable && isToday) {
        print('❌ ${_getMinReservationTerm()}분 이내 예약 불가 시간 블록: ${block['startFormatted']} ~ ${block['endFormatted']}');
      }
      
      return isAvailable;
    }).toList();
    
    // 각 블록을 타석 예약 시간과의 교집합으로 조정
    return filteredBlocks.map((block) {
      // 원본 블록 복사
      final adjustedBlock = Map<String, dynamic>.from(block);
      
      // 겹치는 부분만 계산
      final overlapStartMin = block['startMin'] < tsStartMin ? tsStartMin : block['startMin'];
      final overlapEndMin = block['endMin'] > tsEndMin ? tsEndMin : block['endMin'];
      
      // 조정된 시간 설정
      adjustedBlock['startMin'] = overlapStartMin;
      adjustedBlock['endMin'] = overlapEndMin;
      
      // 시간 형식 업데이트
      final startHour = overlapStartMin ~/ 60;
      final startMinute = overlapStartMin % 60;
      final endHour = overlapEndMin ~/ 60;
      final endMinute = overlapEndMin % 60;
      
      adjustedBlock['startHour'] = startHour;
      adjustedBlock['startMinute'] = startMinute;
      adjustedBlock['endHour'] = endHour;
      adjustedBlock['endMinute'] = endMinute;
      adjustedBlock['startFormatted'] = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
      adjustedBlock['endFormatted'] = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
      
      // 디버깅
      print('🔍 [디버깅] 조정된 시간 블록: ${adjustedBlock['startFormatted']} ~ ${adjustedBlock['endFormatted']}');
      
      return adjustedBlock;
    }).toList();
  }
  
  // 레슨 예약 완료 처리
  Future<void> _finishReservation() async {
    if (_selectedPro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로를 선택해주세요')),
      );
      return;
    }
    
    if (_selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 시간을 선택해주세요')),
      );
      return;
    }
    
    if (_selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간을 선택해주세요')),
      );
      return;
    }
    
    if (_selectedLessonStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('레슨 정보를 찾을 수 없습니다')),
      );
      return;
    }

    if (_selectedContract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 계약 정보가 없습니다')),
      );
      return;
    }
    
    // 계약 만료 여부 확인
    final isValid = _selectedContract!['is_valid'] ?? true;
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('만료된 계약으로는 레슨을 예약할 수 없습니다')),
      );
      return;
    }
    
    // 계약 ID 확인
    final contractId = _selectedContract!['LS_contract_id'];
    if (contractId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 계약에 계약 ID가 없습니다')),
      );
      return;
    }
    
    // 시작 및 종료 시간을 분으로 변환
    final startMin = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
    final endMin = _selectedEndTime!.hour * 60 + _selectedEndTime!.minute;
    
    // 레슨 시간 계산
    final lessonDuration = endMin - startMin;
    
    // 레슨 시간이 최소 예약 시간 이상인지 확인
    final minServiceTime = _getMinServiceTime();
    if (lessonDuration < minServiceTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 시간은 최소 $minServiceTime분 이상이어야 합니다')),
      );
      return;
    }
    
    // 레슨 시간이 추가 시간 단위의 배수인지 확인
    final serviceTimeUnit = _getServiceTimeUnit();
    if (lessonDuration % serviceTimeUnit != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 시간은 $serviceTimeUnit분 단위로 선택해야 합니다')),
      );
      return;
    }
    
    // 레슨 시간이 잔여 시간을 초과하는지 확인
    final balanceMin = _selectedLessonStatus!['LS_balance_min_after'] ?? 0;
    if (lessonDuration > balanceMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('선택한 레슨 시간($lessonDuration분)이 잔여 시간($balanceMin분)을 초과합니다')),
      );
      return;
    }
    
    // 선택한 시작/종료 시간이 타석 예약 시간 내인지 확인
    final tsStartTime = widget.tsReservationInfo['startTime'] as TimeOfDay;
    final tsEndTime = widget.tsReservationInfo['endTime'] as TimeOfDay;
    final tsStartMin = tsStartTime.hour * 60 + tsStartTime.minute;
    final tsEndMin = tsEndTime.hour * 60 + tsEndTime.minute;
    
    if (startMin < tsStartMin || endMin > tsEndMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 레슨 시간이 타석 예약 시간을 벗어납니다')),
      );
      return;
    }

    // 이미 예약된 시간과 겹치는지 확인
    if (_isOverlappingWithExisting(startMin, endMin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 시간이 이미 예약된 레슨 시간과 겹칩니다')),
      );
      return;
    }
    
    // 레슨 간 간격 확인 (새로 추가)
    if (_hasTooCloseLesson(startMin, endMin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 간 최소 $_lessonGap분의 간격이 필요합니다')),
      );
      return;
    }
    
    // 예약 정보에 맞는 시간 블록으로 포맷
    final startFormatted = '${_selectedStartTime!.hour.toString().padLeft(2, '0')}:${_selectedStartTime!.minute.toString().padLeft(2, '0')}';
    final endFormatted = '${_selectedEndTime!.hour.toString().padLeft(2, '0')}:${_selectedEndTime!.minute.toString().padLeft(2, '0')}';
    
    // 1. 회원 정보 조회
    String memberName = '';
    String memberPhone = '';
    try {
      final member = await ApiService.getUserProfile(widget.memberId.toString());
      if (member != null) {
        memberName = member['member_name'] ?? '';
        memberPhone = member['member_phone'] ?? '';
      }
    } catch (e) {
      // 조회 실패 시 빈값 유지
      if (kDebugMode) {
        print('회원 정보 조회 오류: $e');
      }
    }
    
    // 예약 ID 생성
    final formattedDate = widget.tsReservationInfo['formattedDate'] as String;
    final reservationId = "${widget.memberId}_${_selectedPro?.replaceAll(' ', '_')}_${formattedDate.replaceAll('-', '')}_${startFormatted.replaceAll(':', '')}";
    
    // 예약 데이터 생성
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final reservationData = {
      "LS_contract_id": contractId,
      "member_id": widget.memberId,
      "member_name": memberName,
      "member_phone": memberPhone,
      "staff_name": _selectedPro,  // pro_name → staff_name으로 변경됨
      "LS_start_time": "$startFormatted:00",
      "LS_end_time": "$endFormatted:00",
      "LS_date": formattedDate,
      "LS_type": "일반",
      "LS_status": "예약완료",
      "LS_min": lessonDuration,
      "LS_net_min": lessonDuration,
      "LS_ts_id": widget.tsReservationInfo['tsNumber'],
      "LS_ts_start": widget.tsReservationInfo['formattedStartTime'],
      "LS_ts_end": widget.tsReservationInfo['formattedEndTime'],
      "LS_counting_id": _selectedLessonStatus!['LS_counting_id'] ?? 0,
      "branch_id": userProvider.currentBranchId, // branch_id 추가
    };
    
    // 디버깅
    print('🔍 [디버깅] 레슨 예약 데이터: ${jsonEncode(reservationData)}');
    
    // API 호출
    setState(() {
      _isLoading = true;
    });
    
    try {
      // dynamic_api.php 사용으로 변경
      final url = 'https://autofms.mycafe24.com/dynamic_api.php';
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };
      
      print('🔍 [디버깅] API 요청 URL: $url');
      print('🔍 [디버깅] API 요청 메소드: POST');
      print('🔍 [디버깅] API 요청 헤더: $headers');
      
      // dynamic_api.php 요청 구조로 변경
      final apiRequestData = {
        "operation": "add",
        "table": "v2_LS_orders",
        "data": reservationData
      };
      
      final jsonBody = jsonEncode(apiRequestData);
      print('🔍 [디버깅] dynamic_api.php 요청 JSON 데이터: $jsonBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonBody,
      );
      
      // 응답 본문 로깅
      print('🔍 [디버깅] API 응답 상태 코드: ${response.statusCode}');
      print('🔍 [디버깅] API 응답 헤더: ${response.headers}');
      print('🔍 [디버깅] API 응답 본문: ${response.body}');
      
      if (response.statusCode == 200) {
        // 빈 응답인 경우 처리
        if (response.body.isEmpty) {
          print('❌ 서버에서 빈 응답을 반환했습니다.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서버에서 빈 응답을 반환했습니다. 관리자에게 문의하세요.')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        // JSON 파싱 시 예외 처리
        dynamic resp;
        try {
          resp = jsonDecode(response.body);
        } catch (e) {
          print('❌ JSON 파싱 오류: $e');
          print('❌ JSON 파싱 실패한 응답 본문: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버 응답을 처리할 수 없습니다: $e')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        if (resp['success'] == true) {
          // 예약된 레슨 정보 생성
          final lessonInfo = {
            'startMin': startMin,
            'endMin': endMin,
            'startFormatted': startFormatted,
            'endFormatted': endFormatted,
            'lessonDuration': lessonDuration,
            'pro': _selectedPro,
            'lessonStatusId': _selectedLessonStatus!['LS_counting_id'],
            'contractId': contractId, // _selectedLessonStatus!['LS_contract_id'] 대신 선택된 계약의 ID 사용
          };
          
          // 예약했던 블록 목록에 추가
          _selectedTimeBlocks.add(lessonInfo);
          
          // 예약한 시간을 가용 목록에서 제외 처리
          _updateAvailableTimeBlocksForDirectTime(startMin, endMin);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('레슨 예약이 완료되었습니다')),
          );
          
          // 남은 시간 블록이 있는지, 잔여 레슨 시간이 있는지 확인
          final updatedBalanceMin = balanceMin - lessonDuration;
          setState(() {
            // 선택 초기화
            _selectedStartTime = null;
            _selectedEndTime = null;
            _selectedTimeBlock = null;
            _lessonDuration = _getMinServiceTime(); // 프로별 최소 예약 시간으로 리셋
            
            // 잔여 시간 업데이트
            if (_selectedLessonStatus != null) {
              _selectedLessonStatus!['LS_balance_min_after'] = updatedBalanceMin;
            }
          });
          
          // 시간 블록을 다시 평가해서 초기 시간 설정
          if (_availableTimeBlocks.isNotEmpty && updatedBalanceMin >= _getMinServiceTime()) {
            print('🔍 [디버깅] 추가 레슨 가능: 잔여 시간 $updatedBalanceMin분, 가용 블록 ${_availableTimeBlocks.length}개');
            // 추가 레슨 등록 가능
          } else {
            // 추가 레슨 예약이 불가능한 경우
            if (_availableTimeBlocks.isEmpty) {
              _showReservationCompleteDialog('가용 시간 블록이 없어 더 이상 레슨을 예약할 수 없습니다.');
            } else if (updatedBalanceMin < _getMinServiceTime()) {
              _showReservationCompleteDialog('잔여 레슨 시간이 ${_getMinServiceTime()}분 미만이라 더 이상 레슨을 예약할 수 없습니다.');
            }
          }
        } else {
          print('❌ 레슨 예약 저장 실패: ${resp['error'] ?? '알 수 없는 오류'}');
          if (resp.containsKey('debug_info')) {
            print('❌ 디버그 정보: ${resp['debug_info']}');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('레슨 예약 저장 실패: ${resp['error'] ?? '알 수 없는 오류'}')),
          );
        }
      } else {
        print('❌ 서버 오류 ${response.statusCode}: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('❌ 레슨 예약 저장 중 오류: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 예약 저장 중 오류: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 이미 예약된 시간과 겹치는지 확인
  bool _isOverlappingWithExisting(int startMin, int endMin) {
    for (final block in _selectedTimeBlocks) {
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      // 겹치는 경우: 
      // 1. 새로운 시작 시간이 기존 블록 내에 있는 경우 (간격 고려)
      // 2. 새로운 종료 시간이 기존 블록 내에 있는 경우 (간격 고려)
      // 3. 새로운 블록이 기존 블록을 완전히 포함하는 경우 (간격 고려)
      // 4. 새로운 시작 시간이 기존 블록 종료 시간과 너무 가까운 경우
      // 5. 새로운 종료 시간이 기존 블록 시작 시간과 너무 가까운 경우
      if ((startMin >= blockStartMin - _lessonGap && startMin < blockEndMin + _lessonGap) ||
          (endMin > blockStartMin - _lessonGap && endMin <= blockEndMin + _lessonGap) ||
          (startMin <= blockStartMin - _lessonGap && endMin >= blockEndMin + _lessonGap)) {
        return true;
      }
    }
    return false;
  }
  
  // 레슨 간 간격이 너무 가까운지 확인하는 새로운 메서드
  bool _hasTooCloseLesson(int startMin, int endMin) {
    // _lessonGap이 0이면 간격 제한 없음 (연속 예약 가능)
    if (_lessonGap <= 0) return false;
    
    for (final block in _selectedTimeBlocks) {
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      // 기존 레슨 종료 시간과 새 레슨 시작 시간의 간격이 너무 가까운 경우
      if (blockEndMin <= startMin && startMin - blockEndMin < _lessonGap) {
        print('🔍 [디버깅] 레슨 간격 부족: 이전 레슨 종료(${blockEndMin ~/ 60}:${blockEndMin % 60})와 새 레슨 시작(${startMin ~/ 60}:${startMin % 60}) 사이 간격 ${startMin - blockEndMin}분 < 최소 간격 $_lessonGap분');
        return true;
      }
      
      // 새 레슨 종료 시간과 기존 레슨 시작 시간의 간격이 너무 가까운 경우
      if (endMin <= blockStartMin && blockStartMin - endMin < _lessonGap) {
        print('🔍 [디버깅] 레슨 간격 부족: 새 레슨 종료(${endMin ~/ 60}:${endMin % 60})와 다음 레슨 시작(${blockStartMin ~/ 60}:${blockStartMin % 60}) 사이 간격 ${blockStartMin - endMin}분 < 최소 간격 $_lessonGap분');
        return true;
      }
    }
    
    return false;
  }
  
  // 선택한 시작/종료 시간으로 가용 시간 블록 업데이트
  void _updateAvailableTimeBlocksForDirectTime(int startMin, int endMin) {
    print('🔍 [디버깅] 가용 시간 블록 업데이트 시작: $startMin ~ $endMin');
    print('🔍 [디버깅] 업데이트 전 가용 블록 수: ${_availableTimeBlocks.length}');
    
    // 선택한 시간 범위를 포함하는 모든 블록 찾기
    List<int> blockIndicesToUpdate = [];
    
    for (int i = 0; i < _availableTimeBlocks.length; i++) {
      final block = _availableTimeBlocks[i];
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      // 선택한 시간 범위가 이 블록에 영향을 미치는지 확인
      if (!(endMin <= blockStartMin || startMin >= blockEndMin)) {
        blockIndicesToUpdate.add(i);
        print('🔍 [디버깅] 업데이트할 블록 발견: $blockStartMin ~ $blockEndMin');
      }
    }
    
    // 뒤에서부터 처리하여 인덱스 변화 방지
    blockIndicesToUpdate.sort((a, b) => b.compareTo(a));
    
    for (final index in blockIndicesToUpdate) {
      final block = _availableTimeBlocks[index];
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      // 기존 블록 삭제
      _availableTimeBlocks.removeAt(index);
      
      // 선택한 시간 이전에 15분 이상 남은 경우, 새 블록 추가
      if (startMin - blockStartMin >= 15) {
        final newBlock = _createTimeBlock(blockStartMin, startMin);
        _availableTimeBlocks.add(newBlock);
        print('🔍 [디버깅] 이전 시간 블록 추가: ${newBlock['startFormatted']} ~ ${newBlock['endFormatted']}');
      }
      
      // 선택한 시간 이후에 15분 이상 남은 경우, 새 블록 추가
      if (blockEndMin - endMin >= 15) {
        final newBlock = _createTimeBlock(endMin, blockEndMin);
        _availableTimeBlocks.add(newBlock);
        print('🔍 [디버깅] 이후 시간 블록 추가: ${newBlock['startFormatted']} ~ ${newBlock['endFormatted']}');
      }
    }
    
    // 시간순 정렬
    _availableTimeBlocks.sort((a, b) => (a['startMin'] as int).compareTo(b['startMin'] as int));
    
    print('🔍 [디버깅] 업데이트 후 가용 블록 수: ${_availableTimeBlocks.length}');
    for (final block in _availableTimeBlocks) {
      print('🔍 [디버깅] 가용 블록: ${block['startFormatted']} ~ ${block['endFormatted']}');
    }
  }
  
  // 예약 완료 알림 다이얼로그
  void _showReservationCompleteDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('레슨 예약 알림'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  // 예약 완료된 시간을 제외하고 가용 시간 블록 업데이트
  void _updateAvailableTimeBlocks() {
    if (_selectedTimeBlock == null) return;
    
    final selectedStart = _selectedTimeBlock!['startMin'] as int;
    final selectedEnd = selectedStart + _lessonDuration;
    
    // 예약한 시간이 포함된 블록 찾기
    final blockIndex = _availableTimeBlocks.indexWhere((block) => 
      block['startMin'] == _selectedTimeBlock!['startMin'] && 
      block['endMin'] == _selectedTimeBlock!['endMin']
    );
    
    if (blockIndex != -1) {
      final block = _availableTimeBlocks[blockIndex];
      final blockStart = block['startMin'] as int;
      final blockEnd = block['endMin'] as int;
      
      // 기존 블록 삭제
      _availableTimeBlocks.removeAt(blockIndex);
      
      // 블록 분할(예약된 이전/이후 시간이 15분 이상이면 새로운 블록으로 추가)
      if (selectedStart - blockStart >= 15) {
        // 이전 시간 블록 추가
        _availableTimeBlocks.add(_createTimeBlock(blockStart, selectedStart));
      }
      
      if (blockEnd - selectedEnd >= 15) {
        // 이후 시간 블록 추가
        _availableTimeBlocks.add(_createTimeBlock(selectedEnd, blockEnd));
      }
      
      // 시간순 정렬
      _availableTimeBlocks.sort((a, b) => (a['startMin'] as int).compareTo(b['startMin'] as int));
    }
  }
  
  // 시간 블록 생성 헬퍼 메서드
  Map<String, dynamic> _createTimeBlock(int startMin, int endMin) {
    final startHour = startMin ~/ 60;
    final startMinute = startMin % 60;
    final endHour = endMin ~/ 60;
    final endMinute = endMin % 60;
    
    return {
      'startMin': startMin,
      'endMin': endMin,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'startFormatted': '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}',
      'endFormatted': '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레슨 예약'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                // 메인 스크롤 영역
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 타석 예약 정보 요약
                      _buildTSReservationSummary(),
                      const SizedBox(height: 24),
                      
                      // 계약 선택 섹션 (기존 프로 선택 대체)
                      _buildContractSelectionSection(),
                      const SizedBox(height: 24),
                      
                      // 선택된 계약이 있을 때만 시간 선택 섹션 표시
                      if (_selectedContract != null && _selectedPro != null) ...[
                        // 시간 선택 섹션
                        _buildTimeSelectionSection(),
                        const SizedBox(height: 24),
                      ],
                      
                      // 장바구니 아래 고정을 위한 여백
                      if (_selectedTimeBlocks.isNotEmpty)
                        const SizedBox(height: 120),
                    ],
                  ),
                ),
                
                // 장바구니 표시 (화면 하단에 고정)
                if (_selectedTimeBlocks.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildCartSummary(),
                  ),
              ],
            ),
    );
  }
  
  // 장바구니 요약 위젯 (하단 고정 표시용)
  Widget _buildCartSummary() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 장바구니 요약 정보
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 장바구니 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          '레슨 장바구니',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        _showCartDetailBottomSheet();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Text(
                              '${_selectedTimeBlocks.length}개 항목',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_less, size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 예약 버튼
                ElevatedButton.icon(
                  onPressed: _selectedTimeBlocks.isNotEmpty ? _registerAllLessons : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    '${_selectedTimeBlocks.length}개 레슨 예약하기 (총 ${_calculateTotalLessonDuration()}분)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 장바구니 상세 내용 표시
  void _showCartDetailBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '레슨 장바구니 상세',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '총 ${_calculateTotalLessonDuration()}분',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // 장바구니 아이템 목록
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _selectedTimeBlocks.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final block = _selectedTimeBlocks[index];
                  final startFormatted = block['startFormatted'];
                  final endFormatted = block['endFormatted'];
                  final lessonDuration = block['lessonDuration'] as int;
                  final proName = block['pro'] as String? ?? _selectedPro ?? '프로 정보 없음';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽 컨텐츠
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$lessonDuration분',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '레슨 ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildReservationInfoItem(
                                icon: Icons.access_time,
                                label: '시간',
                                value: '$startFormatted - $endFormatted',
                              ),
                              const SizedBox(height: 4),
                              _buildReservationInfoItem(
                                icon: Icons.person,
                                label: '프로',
                                value: proName,
                              ),
                            ],
                          ),
                        ),
                        
                        // 삭제 버튼
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _removeFromLessonCart(index);
                          },
                          tooltip: '레슨 삭제',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // 닫기 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 타석 예약 정보 요약 위젯
  Widget _buildTSReservationSummary() {
    // 타석 예약 정보
    final date = widget.tsReservationInfo['date'] as DateTime;
    final startTime = widget.tsReservationInfo['startTime'] as TimeOfDay;
    final endTime = widget.tsReservationInfo['endTime'] as TimeOfDay;
    final duration = widget.tsReservationInfo['duration'] as int;
    final tsNumber = widget.tsReservationInfo['tsNumber'] as int;
    final tsType = widget.tsReservationInfo['tsType'] as String;
    
    // 날짜 및 시간 포맷
    final dateFormat = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR');
    final formattedDate = dateFormat.format(date);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  '타석 예약 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('날짜', formattedDate),
            _buildInfoRow('시간', '${startTime.format(context)} - ${endTime.format(context)}'),
            _buildInfoRow('이용 시간', '$duration분'),
            _buildInfoRow('타석', '$tsNumber번 ($tsType)'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '위 타석 예약 시간 내에서 레슨을 예약합니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  // 계약 선택 섹션 위젯 (기존 _buildProSelectionSection 대체)
  Widget _buildContractSelectionSection() {
    // 계약 정보가 로딩 중이거나 아직 로드하지 않은 경우
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // 유효한 계약 정보만 필터링
    final validContracts = _lessonContracts.where((contract) => contract['is_valid'] == true).toList();
    
    // 계약 정보가 없는 경우
    if (validContracts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '유효한 레슨 계약 정보가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '예약 가능한 계약이 없거나 모든 계약이 만료되었습니다.\n관리자에게 문의하세요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '레슨 계약 선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '유효한 계약 ${validContracts.length}개',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 유효한 계약만 선택 리스트에 표시
        ...List.generate(validContracts.length, (index) {
          final contract = validContracts[index];
          final contractName = contract['contract_name'] ?? '이름 없음';
          final proName = contract['LS_contract_pro'] ?? '담당 프로 없음';
          final lessonType = contract['LS_type'] ?? '유형 정보 없음';
          final contractId = contract['LS_contract_id'];
          final isSelected = _selectedContract == contract;
          
          // 만료일 정보 표시 준비
          String expiryInfo = '만료일 정보 없음';
          if (contract['LS_expiry_date'] != null && contract['LS_expiry_date'].toString().isNotEmpty) {
            try {
              DateTime expiryDate = contract['expiry_date'] ?? DateTime.parse(contract['LS_expiry_date'].toString());
              final daysRemaining = expiryDate.difference(DateTime.now()).inDays;
              expiryInfo = '만료일: ${contract['LS_expiry_date']} (${daysRemaining}일 남음)';
            } catch (e) {
              expiryInfo = '만료일: ${contract['LS_expiry_date']}';
            }
          }
          
          // 회당 시간 정보 처리 (문자열이나 정수 모두 처리)
          String minPerQtyText = '회당 시간 정보 없음';
          final minPerQtyRaw = contract['LS_min_per_qty'];
          
          if (minPerQtyRaw != null) {
            int minPerQty = 0;
            
            if (minPerQtyRaw is int) {
              minPerQty = minPerQtyRaw;
              minPerQtyText = '$minPerQty분/회';
            } else if (minPerQtyRaw is String) {
              minPerQty = int.tryParse(minPerQtyRaw) ?? 0;
              if (minPerQty > 0) {
                minPerQtyText = '$minPerQty분/회';
              } else {
                minPerQtyText = '회당 시간 정보 없음';
              }
            }
          }
          
          // 해당 계약의 잔여 시간 찾기 (계약 ID 기준)
          String balanceInfo = '잔여 시간 정보 없음';
          
          if (contractId != null) {
            final status = _findLessonStatusByContractId(contractId);
            if (status != null) {
              final balanceMin = status['LS_balance_min_after'] ?? 0;
              balanceInfo = '잔여 시간: $balanceMin분';
            }
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedContract = contract;
                  _selectedTimeBlock = null; // 계약 변경 시 시간 초기화
                  _availableTimeBlocks = []; // 계약 변경 시 시간 블록 초기화
                });
                
                // 계약 선택 시 가능한 시간 로드
                _selectContractAndGetAvailableTimes();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.assignment,
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contractName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '담당 프로: $proName',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.8) : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '유형: $lessonType',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.8) : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            balanceInfo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.8) : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expiryInfo,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.8) : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            minPerQtyText,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.8) : Colors.grey.shade700,
                            ),
                          ),
                          if (contractId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '계약 ID: $contractId',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
  
  // 시간 선택 섹션 위젯
  Widget _buildTimeSelectionSection() {
    // 시간 블록이 로딩 중이거나 아직 로드하지 않은 경우
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // 가능한 시간 블록이 없는 경우
    if (_availableTimeBlocks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.access_time, size: 32, color: Colors.orange.shade700),
            const SizedBox(height: 8),
            const Text(
              '가능한 시간이 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '타석 예약 시간과 겹치는 레슨 가능 시간이 없습니다.\n다른 프로를 선택하거나 다른 시간대에 예약해주세요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // 타석 예약 시간 정보 가져오기
    final startTime = widget.tsReservationInfo['startTime'] as TimeOfDay;
    final endTime = widget.tsReservationInfo['endTime'] as TimeOfDay;
    
    // 타석 시작 및 종료 시간을 분으로 변환
    final tsStartMin = startTime.hour * 60 + startTime.minute;
    final tsEndMin = endTime.hour * 60 + endTime.minute;
    
    // 시간 선택 초기값 설정 (첫 번째 가능한 시간 블록으로 설정)
    if (_selectedStartTime == null && _availableTimeBlocks.isNotEmpty) {
      try {
        final firstBlock = _availableTimeBlocks.first;
        final startHour = firstBlock['startHour'] as int;
        final startMinute = firstBlock['startMinute'] as int;
        _selectedStartTime = TimeOfDay(hour: startHour, minute: startMinute);
        
        // 기본 레슨 시간은 최소 서비스 시간으로 설정
        final startMin = startHour * 60 + startMinute;
        final endMin = startMin + _getMinServiceTime();
        
        // 종료 시간이 타석 종료 시간 또는 블록 종료 시간을 초과하지 않도록 조정
        final blockEndMin = firstBlock['endMin'] as int;
        final adjustedEndMin = endMin < blockEndMin ? endMin : blockEndMin;
        final adjustedEndMin2 = adjustedEndMin < tsEndMin ? adjustedEndMin : tsEndMin;
        
        _selectedEndTime = TimeOfDay(hour: adjustedEndMin2 ~/ 60, minute: adjustedEndMin2 % 60);
        
        // 선택된 시간 블록 업데이트
        _selectedTimeBlock = firstBlock;
        
        // 레슨 시간 계산 업데이트
        _lessonDuration = (_selectedEndTime!.hour * 60 + _selectedEndTime!.minute) - 
                          (_selectedStartTime!.hour * 60 + _selectedStartTime!.minute);
                          
        // 디버깅
        print('🔍 [디버깅] 초기 시간 설정: 시작=${_selectedStartTime!.format(context)}, 종료=${_selectedEndTime!.format(context)}, 시간=${_lessonDuration}분');
      } catch (e) {
        print('❌ 초기 시간 설정 중 오류: $e');
        // 초기 시간 설정 실패 시 기본값 설정하지 않음
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '레슨 시간 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_selectedPro} 프로의 가능한 시간 범위',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        
        // 가능한 시간 범위 표시
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _availableTimeBlocks.map((block) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${block['startFormatted']} - ${block['endFormatted']}',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 시작 시간 선택
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '시작 시간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectStartTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedStartTime != null
                                ? _selectedStartTime!.format(context)
                                : '시작 시간 선택',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedStartTime != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '종료 시간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectEndTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedEndTime != null
                                ? _selectedEndTime!.format(context)
                                : '종료 시간 선택',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedEndTime != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 레슨 시간 정보
        if (_selectedStartTime != null && _selectedEndTime != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '레슨 예약 정보',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '시간: ${_selectedStartTime!.format(context)} - ${_selectedEndTime!.format(context)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  '레슨 시간: ${_calculateLessonDuration()}분',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (_selectedLessonStatus != null)
                  Text(
                    '잔여 시간: ${_selectedLessonStatus!['LS_balance_min_after']}분 → ${(_selectedLessonStatus!['LS_balance_min_after'] as int) - _calculateLessonDuration()}분',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _addToLessonCart();
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('레슨 담기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  // 시작 시간 선택 다이얼로그
  Future<void> _selectStartTime(BuildContext context) async {
    // 가능한 시간 목록 생성
    final availableTimes = <TimeOfDay>[];
    
    for (final block in _availableTimeBlocks) {
      final startHour = block['startHour'] as int;
      final startMinute = block['startMinute'] as int;
      final endHour = block['endHour'] as int;
      final endMinute = block['endMinute'] as int;
      
      // 시작 시간부터 서비스 시간 단위로 종료 시간-최소 서비스 시간까지의 시간 추가
      int currentMin = startHour * 60 + startMinute;
      final endMin = endHour * 60 + endMinute;
      final minServiceTime = _getMinServiceTime();
      
      while (currentMin <= endMin - minServiceTime) { // 최소 서비스 시간만큼 레슨 시간 확보
        // 기존 예약된 레슨 이후 최소 간격을 확인
        bool isValidStartTime = true;
        
        // _lessonGap이 0보다 큰 경우에만 검사
        if (_lessonGap > 0 && _selectedTimeBlocks.isNotEmpty) {
          for (final block in _selectedTimeBlocks) {
            final blockEndMin = block['endMin'] as int;
            
            // 기존 레슨 종료 이후 최소 간격 내에 있는 시간은 제외
            if (currentMin < blockEndMin + _lessonGap && currentMin >= blockEndMin) {
              isValidStartTime = false;
              break;
            }
            
            // 기존 레슨 시작 전 최소 간격 내에 시작해서 기존 레슨에 간섭하는 경우 제외
            final blockStartMin = block['startMin'] as int;
            if (currentMin + minServiceTime > blockStartMin - _lessonGap && currentMin <= blockStartMin) {
              isValidStartTime = false;
              break;
            }
          }
        }
        
        if (isValidStartTime) {
          availableTimes.add(TimeOfDay(hour: currentMin ~/ 60, minute: currentMin % 60));
        }
        currentMin += _getServiceTimeUnit(); // 서비스 시간 단위로 증가
      }
    }
    
    // 이미 선택된 시간 블록이 있으면 해당 블록 내의 시간만 표시
    final filteredTimes = _selectedTimeBlock != null
        ? availableTimes.where((time) {
            final timeInMin = time.hour * 60 + time.minute;
            final blockStartMin = _selectedTimeBlock!['startMin'] as int;
            final blockEndMin = _selectedTimeBlock!['endMin'] as int;
            final minServiceTime = _getMinServiceTime();
            return timeInMin >= blockStartMin && timeInMin <= blockEndMin - minServiceTime;
          }).toList()
        : availableTimes;
    
    // 필터링된 시간이 없는 경우 처리
    if (filteredTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택 가능한 시작 시간이 없습니다.')),
      );
      return;
    }
    
    // UI에 표시할 높이 계산 (최대 5개까지만 한 번에 표시)
    final dialogHeight = filteredTimes.length > 5 ? 300.0 : filteredTimes.length * 56.0 + 112.0;
    
    // 팝업 다이얼로그로 시간 선택 UI 표시
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시작 시간 선택'),
        content: SizedBox(
          width: 300,
          height: dialogHeight,
          child: ListView.builder(
            itemCount: filteredTimes.length,
            itemBuilder: (context, index) {
              final time = filteredTimes[index];
              final isSelected = _selectedStartTime != null &&
                  _selectedStartTime!.hour == time.hour &&
                  _selectedStartTime!.minute == time.minute;
              
              return ListTile(
                title: Text(time.format(context)),
                tileColor: isSelected ? Colors.blue.shade50 : null,
                onTap: () {
                  Navigator.pop(context, time);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    
    if (selectedTime != null) {
      setState(() {
        _selectedStartTime = selectedTime;
        
        // 선택된 시작 시간에 해당하는 시간 블록 찾기
        _selectedTimeBlock = _findTimeBlockForTime(selectedTime);
        
        // 종료 시간 재설정 (최소 15분 이상)
        final startMin = selectedTime.hour * 60 + selectedTime.minute;
        final endMin = startMin + _getMinServiceTime(); // 최소 서비스 시간으로 변경
        
        // 종료 시간이 블록의 종료 시간을 초과하지 않도록 조정
        if (_selectedTimeBlock != null) {
          final blockEndMin = _selectedTimeBlock!['endMin'] as int;
          final adjustedEndMin = endMin < blockEndMin ? endMin : blockEndMin;
          
          _selectedEndTime = TimeOfDay(hour: adjustedEndMin ~/ 60, minute: adjustedEndMin % 60);
        } else {
          _selectedEndTime = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);
        }
        
        // 레슨 시간 업데이트
        _lessonDuration = _calculateLessonDuration();
      });
    }
  }
  
  // 종료 시간 선택 다이얼로그
  Future<void> _selectEndTime(BuildContext context) async {
    if (_selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 시작 시간을 선택해주세요.')),
      );
      return;
    }
    
    if (_selectedTimeBlock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 시간 블록이 선택되지 않았습니다.')),
      );
      return;
    }
    
    // 시작 시간을 분으로 변환
    final startTimeMin = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
    final minServiceTime = _getMinServiceTime();
    final serviceTimeUnit = _getServiceTimeUnit();
    
    // 시작 시간 이후부터 블록 종료 시간까지 서비스 시간 단위로 시간 목록 생성
    final availableTimes = <TimeOfDay>[];
    final blockEndMin = _selectedTimeBlock!['endMin'] as int;
    
    // 시작 시간 + 최소 서비스 시간부터 서비스 시간 단위로 블록 끝까지
    int currentMin = startTimeMin + minServiceTime;
    while (currentMin <= blockEndMin) {
      // 시작 시간부터의 차이가 서비스 시간 단위의 배수인 경우만 추가
      if ((currentMin - startTimeMin) % serviceTimeUnit == 0) {
        availableTimes.add(TimeOfDay(hour: currentMin ~/ 60, minute: currentMin % 60));
      }
      currentMin += serviceTimeUnit;  // 서비스 시간 단위로 증가
    }
    
    // 마지막 시간이 정확히 블록 끝이 아니면 블록 끝 시간 추가
    final lastTimeMin = availableTimes.isEmpty ? -1 : availableTimes.last.hour * 60 + availableTimes.last.minute;
    if (blockEndMin > lastTimeMin && 
        (blockEndMin - startTimeMin) >= minServiceTime && 
        (blockEndMin - startTimeMin) % serviceTimeUnit == 0) {
      availableTimes.add(TimeOfDay(hour: blockEndMin ~/ 60, minute: blockEndMin % 60));
    }
    
    // 사용 가능한 시간이 없는 경우 처리
    if (availableTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('선택 가능한 종료 시간이 없습니다. (시작 시간에서 최소 $minServiceTime분, $serviceTimeUnit분 단위 필요)')),
      );
      return;
    }
    
    // 남은 레슨 시간 확인
    final balanceMin = _selectedLessonStatus?['LS_balance_min_after'] ?? 0;
    
    // 남은 레슨 시간을 초과하지 않는 시간만 필터링
    final filteredTimes = availableTimes.where((time) {
      final timeInMin = time.hour * 60 + time.minute;
      final duration = timeInMin - startTimeMin;
      return duration <= balanceMin; // 잔여 시간 이하인 경우만 허용
    }).toList();
    
    // 필터링된 시간이 없는 경우 처리
    if (filteredTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('잔여 레슨 시간 내에 선택 가능한 종료 시간이 없습니다.')),
      );
      return;
    }
    
    // UI에 표시할 높이 계산 (최대 5개까지만 한 번에 표시)
    final dialogHeight = filteredTimes.length > 5 ? 300.0 : filteredTimes.length * 56.0 + 112.0;
    
    // 팝업 다이얼로그로 시간 선택 UI 표시
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('종료 시간 선택'),
        content: SizedBox(
          width: 300,
          height: dialogHeight,
          child: ListView.builder(
            itemCount: filteredTimes.length,
            itemBuilder: (context, index) {
              final time = filteredTimes[index];
              final isSelected = _selectedEndTime != null &&
                  _selectedEndTime!.hour == time.hour &&
                  _selectedEndTime!.minute == time.minute;
              
              // 해당 종료 시간 선택 시 레슨 시간 계산하여 표시
              final timeInMin = time.hour * 60 + time.minute;
              final duration = timeInMin - startTimeMin;
              
              return ListTile(
                title: Text('${time.format(context)} (${duration}분)'),
                tileColor: isSelected ? Colors.blue.shade50 : null,
                onTap: () {
                  Navigator.pop(context, time);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    
    if (selectedTime != null) {
      setState(() {
        _selectedEndTime = selectedTime;
        
        // 레슨 시간 업데이트
        _lessonDuration = _calculateLessonDuration();
      });
    }
  }
  
  // 선택된 시간에 해당하는 시간 블록 찾기
  Map<String, dynamic>? _findTimeBlockForTime(TimeOfDay time) {
    final timeInMin = time.hour * 60 + time.minute;
    
    for (final block in _availableTimeBlocks) {
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      if (timeInMin >= blockStartMin && timeInMin < blockEndMin) {
        return block;
      }
    }
    
    return null;
  }
  
  // 레슨 시간 계산
  int _calculateLessonDuration() {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      return 0;
    }
    
    final startMin = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
    final endMin = _selectedEndTime!.hour * 60 + _selectedEndTime!.minute;
    
    return endMin - startMin;
  }
  
  // 선택된 레슨 목록 섹션 위젯
  Widget _buildSelectedLessonsSection() {
    if (_selectedTimeBlocks.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '레슨 장바구니',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '총 ${_calculateTotalLessonDuration()}분',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_selectedTimeBlocks.length, (index) {
          final block = _selectedTimeBlocks[index];
          final startFormatted = block['startFormatted'];
          final endFormatted = block['endFormatted'];
          final lessonDuration = block['lessonDuration'] as int;
          final proName = block['pro'] as String? ?? _selectedPro ?? '프로 정보 없음';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '레슨 ${index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$lessonDuration분',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeFromLessonCart(index),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(left: 8),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildReservationInfoItem(
                    icon: Icons.access_time,
                    label: '시간',
                    value: '$startFormatted - $endFormatted',
                  ),
                  const SizedBox(height: 4),
                  _buildReservationInfoItem(
                    icon: Icons.person,
                    label: '프로',
                    value: proName,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _selectedTimeBlocks.isNotEmpty ? _registerAllLessons : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('모든 레슨 예약하기'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  // 장바구니에서 레슨 제거
  void _removeFromLessonCart(int index) {
    if (index < 0 || index >= _selectedTimeBlocks.length) return;
    
    final block = _selectedTimeBlocks[index];
    final startMin = block['startMin'] as int;
    final endMin = block['endMin'] as int;
    final lessonDuration = block['lessonDuration'] as int;
    
    // 해당 프로의 레슨 상태 찾기
    final proName = block['pro'] as String;
    final lessonStatus = _lessonStatus.firstWhere(
      (status) => status['LS_contract_pro'] == proName,
      orElse: () => {},
    );
    
    setState(() {
      // 장바구니에서 제거
      _selectedTimeBlocks.removeAt(index);
      
      // 가용 시간 목록에 다시 추가
      _addBackToAvailableTimeBlocks(startMin, endMin);
      
      // 잔여 시간 업데이트
      if (lessonStatus.isNotEmpty) {
        final currentBalance = lessonStatus['LS_balance_min_after'] ?? 0;
        lessonStatus['LS_balance_min_after'] = currentBalance + lessonDuration;
        
        // 현재 선택된 프로가 같으면 선택된 레슨 상태도 업데이트
        if (_selectedPro == proName && _selectedLessonStatus != null) {
          _selectedLessonStatus!['LS_balance_min_after'] = currentBalance + lessonDuration;
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('레슨이 장바구니에서 제거되었습니다')),
    );
  }
  
  // 가용 시간 목록에 다시 추가
  void _addBackToAvailableTimeBlocks(int startMin, int endMin) {
    // 시간 블록 생성
    final newBlock = _createTimeBlock(startMin, endMin);
    
    // 기존 블록과 병합 가능한지 확인
    bool merged = false;
    
    // 병합 가능한 블록 찾기
    for (int i = 0; i < _availableTimeBlocks.length; i++) {
      final block = _availableTimeBlocks[i];
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      
      // 블록이 인접한 경우 병합
      if (blockEndMin == startMin) {
        // 현재 블록 끝과 새 블록 시작이 인접
        _availableTimeBlocks[i] = _createTimeBlock(blockStartMin, endMin);
        merged = true;
        break;
      } else if (blockStartMin == endMin) {
        // 새 블록 끝과 현재 블록 시작이 인접
        _availableTimeBlocks[i] = _createTimeBlock(startMin, blockEndMin);
        merged = true;
        break;
      }
    }
    
    // 병합되지 않았으면 새 블록으로 추가
    if (!merged) {
      _availableTimeBlocks.add(newBlock);
      
      // 블록을 시간순으로 정렬
      _availableTimeBlocks.sort((a, b) => (a['startMin'] as int).compareTo(b['startMin'] as int));
    }
    
    // 인접한 블록들 병합 시도
    _mergeAdjacentBlocks();
    
    print('🔍 [디버깅] 시간 블록 반환 후: ${_availableTimeBlocks.length}개 블록');
    for (final block in _availableTimeBlocks) {
      print('🔍 [디버깅] 가용 블록: ${block['startFormatted']} ~ ${block['endFormatted']}');
    }
  }
  
  // 인접한 블록들 병합
  void _mergeAdjacentBlocks() {
    if (_availableTimeBlocks.length <= 1) return;
    
    // 인접한 블록 병합
    bool mergeOccurred;
    do {
      mergeOccurred = false;
      
      for (int i = 0; i < _availableTimeBlocks.length - 1; i++) {
        final currentBlock = _availableTimeBlocks[i];
        final nextBlock = _availableTimeBlocks[i + 1];
        
        final currentEndMin = currentBlock['endMin'] as int;
        final nextStartMin = nextBlock['startMin'] as int;
        
        // 블록이 인접하면 병합
        if (currentEndMin == nextStartMin) {
          final mergedBlock = _createTimeBlock(
            currentBlock['startMin'] as int,
            nextBlock['endMin'] as int,
          );
          
          // 두 블록을 제거하고 병합된 블록 추가
          _availableTimeBlocks.removeAt(i + 1);
          _availableTimeBlocks[i] = mergedBlock;
          
          mergeOccurred = true;
          break;
        }
      }
    } while (mergeOccurred);
  }
  
  // 장바구니에 있는 모든 레슨 등록
  Future<void> _registerAllLessons() async {
    if (_selectedTimeBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장바구니에 레슨이 없습니다')),
      );
      return;
    }
    
    // 계약별 레슨 시간 합계 계산 및 회당 시간 검증
    if (_selectedContract != null) {
      final contractId = _selectedContract!['LS_contract_id'];
      final minPerQtyRaw = _selectedContract!['LS_min_per_qty'];
      
      // 유효성 검사 - 만료된 계약인지 확인
      final isValid = _selectedContract!['is_valid'] ?? true;
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('만료된 계약으로는 레슨을 예약할 수 없습니다.')),
        );
        return;
      }
      
      if (contractId != null && minPerQtyRaw != null) {
        // minPerQty가 문자열일 경우 숫자로 변환
        int minPerQty = 0;
        if (minPerQtyRaw is int) {
          minPerQty = minPerQtyRaw;
        } else if (minPerQtyRaw is String) {
          minPerQty = int.tryParse(minPerQtyRaw) ?? 0;
        }
        
        // 회당 시간이 0보다 큰 경우에만 검증
        if (minPerQty > 0) {
          // 현재 장바구니에 있는 동일 계약의 레슨 시간 합계 계산
          int totalCartDuration = 0;
          for (final item in _selectedTimeBlocks) {
            if (item['contractId'] == contractId) {
              totalCartDuration += item['lessonDuration'] as int;
            }
          }
          
          // 디버깅
          print('🔍 [디버깅] 최종 회당 시간 검증: 회당 시간=$minPerQty분, 총 예약 시간=$totalCartDuration분');
          
          // 총 시간이 회당 시간보다 작은 경우 알림
          if (totalCartDuration < minPerQty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('총 레슨 시간은 회당 시간($minPerQty분) 이상이어야 합니다. 현재 총 시간: $totalCartDuration분')),
            );
            return;
          }
        }
      }
    }
    
    // 장바구니 아이템 중 만료된 계약이 있는지 확인
    List<Map<String, dynamic>> expiredItems = [];
    for (final item in _selectedTimeBlocks) {
      // 아이템에 연결된 계약ID로 원본 계약 찾기
      final contractId = item['contractId'];
      if (contractId != null) {
        final contract = _lessonContracts.firstWhere(
          (c) => c['LS_contract_id'] == contractId,
          orElse: () => {'is_valid': true}, // 찾지 못할 경우 기본적으로 유효하다고 간주
        );
        
        // 만료된 계약인 경우 목록에 추가
        if (contract['is_valid'] == false) {
          expiredItems.add(item);
        }
      }
    }
    
    // 만료된 계약이 있는 경우 처리
    if (expiredItems.isNotEmpty) {
      final expiredCount = expiredItems.length;
      final totalCount = _selectedTimeBlocks.length;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$expiredCount개의 레슨이 만료된 계약에 연결되어 있습니다. 장바구니에서 제거 후 다시 시도해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    // 성공 및 실패 카운트
    int successCount = 0;
    int failCount = 0;
    String errorMessage = '';
    
    // 1. 회원 정보 조회
    String memberName = '';
    String memberPhone = '';
    try {
      final member = await ApiService.getUserProfile(widget.memberId.toString());
      if (member != null) {
        memberName = member['member_name'] ?? '';
        memberPhone = member['member_phone'] ?? '';
      }
    } catch (e) {
      // 조회 실패 시 빈값 유지
      if (kDebugMode) {
        print('회원 정보 조회 오류: $e');
      }
    }
    
    // 모든 레슨 예약 처리
    for (int i = 0; i < _selectedTimeBlocks.length; i++) {
      final block = _selectedTimeBlocks[i];
      
      // 예약 정보 생성
      final startFormatted = block['startFormatted'] as String;
      final endFormatted = block['endFormatted'] as String;
      final lessonDuration = block['lessonDuration'] as int;
      final proName = block['pro'] as String;
      final lessonStatusId = block['lessonStatusId'];
      final contractId = block['contractId']; // String에서 dynamic으로 변경
      
      // 예약 ID 생성
      final formattedDate = widget.tsReservationInfo['formattedDate'] as String;
      final reservationId = "${widget.memberId}_${proName.replaceAll(' ', '_')}_${formattedDate.replaceAll('-', '')}_${startFormatted.replaceAll(':', '')}";
      
      // 예약 데이터 생성
      final reservationData = {
        "LS_contract_id": contractId,
        "member_id": widget.memberId,
        "member_name": memberName,
        "member_phone": memberPhone,
        "staff_name": proName,  // pro_name → staff_name으로 변경됨
        "LS_start_time": "$startFormatted:00",
        "LS_end_time": "$endFormatted:00",
        "LS_date": formattedDate,
        "LS_type": "일반",
        "LS_status": "예약완료",
        "LS_min": lessonDuration,
        "LS_net_min": lessonDuration,
        "LS_ts_id": widget.tsReservationInfo['tsNumber'],
        "LS_ts_start": widget.tsReservationInfo['formattedStartTime'],
        "LS_ts_end": widget.tsReservationInfo['formattedEndTime'],
        "LS_counting_id": lessonStatusId,
      };
      
      try {
        // dynamic_api.php 사용으로 변경
        final url = 'https://autofms.mycafe24.com/dynamic_api.php';
        final headers = {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        };
        
        print('🔍 [디버깅] API 요청 URL: $url');
        print('🔍 [디버깅] API 요청 메소드: POST');
        print('🔍 [디버깅] API 요청 헤더: $headers');
        
        // dynamic_api.php 요청 구조로 변경
        final apiRequestData = {
          "operation": "add",
          "table": "v2_LS_orders",
          "data": reservationData
        };
        
        final jsonBody = jsonEncode(apiRequestData);
        print('🔍 [디버깅] dynamic_api.php 요청 JSON 데이터: $jsonBody');
        
        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonBody,
        );
        
        // 응답 본문 로깅
        print('🔍 [디버깅] API 응답 상태 코드: ${response.statusCode}');
        print('🔍 [디버깅] API 응답 헤더: ${response.headers}');
        print('🔍 [디버깅] API 응답 본문: ${response.body}');
        
        if (response.statusCode == 200) {
          // 빈 응답인 경우 처리
          if (response.body.isEmpty) {
            failCount++;
            errorMessage += '${proName} $startFormatted-$endFormatted 예약 실패: 서버에서 빈 응답을 반환했습니다.\n';
            continue;
          }
          
          // JSON 파싱 시 예외 처리
          dynamic resp;
          try {
            resp = jsonDecode(response.body);
          } catch (e) {
            failCount++;
            errorMessage += '${proName} $startFormatted-$endFormatted 예약 실패: JSON 파싱 오류 - $e\n';
            continue;
          }
          
          if (resp['success'] == true) {
            successCount++;
          } else {
            failCount++;
            errorMessage += '${proName} $startFormatted-$endFormatted 예약 실패: ${resp['error'] ?? '알 수 없는 오류'}\n';
            if (resp.containsKey('debug_info')) {
              errorMessage += '상세 정보: ${resp['debug_info']}\n';
            }
          }
        } else {
          failCount++;
          errorMessage += '${proName} $startFormatted-$endFormatted 예약 실패: 서버 오류(${response.statusCode}) - ${response.body}\n';
        }
      } catch (e) {
        failCount++;
        errorMessage += '${proName} $startFormatted-$endFormatted 예약 실패: $e\n';
      }
    }
    
    setState(() {
      _isLoading = false;
    });
    
    // 결과 안내
    if (successCount > 0 && failCount == 0) {
      // 모두 성공
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successCount개 레슨 예약이 모두 완료되었습니다')),
      );
      
      // 예약 완료 다이얼로그
      _showReservationCompleteDialog('$successCount개 레슨 예약이 모두 완료되었습니다.');
      
      // 예약 목록 초기화
      setState(() {
        _selectedTimeBlocks = [];
      });
    } else if (successCount > 0 && failCount > 0) {
      // 일부 성공, 일부 실패
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successCount개 성공, $failCount개 실패')),
      );
      
      // 실패한 항목 안내 다이얼로그
      _showErrorDialog('일부 레슨 예약 실패', '$successCount개 레슨은 예약되었으나, $failCount개 레슨 예약에 실패했습니다.\n\n$errorMessage');
    } else {
      // 모두 실패
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 레슨 예약에 실패했습니다')),
      );
      
      // 실패 안내 다이얼로그
      _showErrorDialog('레슨 예약 실패', errorMessage);
    }
  }
  
  // 에러 다이얼로그
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  // 총 레슨 시간 계산
  int _calculateTotalLessonDuration() {
    int total = 0;
    for (final block in _selectedTimeBlocks) {
      total += block['lessonDuration'] as int;
    }
    return total;
  }

  // 예약 정보 항목 위젯
  Widget _buildReservationInfoItem({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value ?? '정보 없음',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 장바구니에 레슨 추가
  void _addToLessonCart() {
    if (_selectedPro == null || _selectedStartTime == null || _selectedEndTime == null || _selectedLessonStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 레슨 정보를 선택해주세요')),
      );
      return;
    }
    
    if (_selectedContract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 계약 정보가 없습니다')),
      );
      return;
    }
    
    // 계약 만료 여부 확인
    final isValid = _selectedContract!['is_valid'] ?? true;
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('만료된 계약으로는 레슨을 예약할 수 없습니다')),
      );
      return;
    }
    
    // 계약 ID 확인
    final contractId = _selectedContract!['LS_contract_id'];
    if (contractId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 계약에 계약 ID가 없습니다')),
      );
      return;
    }
    
    // 시작 및 종료 시간을 분으로 변환
    final startMin = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
    final endMin = _selectedEndTime!.hour * 60 + _selectedEndTime!.minute;
    
    // 레슨 시간 계산
    final lessonDuration = endMin - startMin;
    
    // 레슨 시간이 최소 예약 시간 이상인지 확인
    final minServiceTime = _getMinServiceTime();
    if (lessonDuration < minServiceTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 시간은 최소 $minServiceTime분 이상이어야 합니다')),
      );
      return;
    }
    
    // 레슨 시간이 추가 시간 단위의 배수인지 확인
    final serviceTimeUnit = _getServiceTimeUnit();
    if (lessonDuration % serviceTimeUnit != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 시간은 $serviceTimeUnit분 단위로 선택해야 합니다')),
      );
      return;
    }
    
    // 레슨 시간이 잔여 시간을 초과하는지 확인
    final balanceMin = _selectedLessonStatus!['LS_balance_min_after'] ?? 0;
    if (lessonDuration > balanceMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('선택한 레슨 시간($lessonDuration분)이 잔여 시간($balanceMin분)을 초과합니다')),
      );
      return;
    }
    
    // 선택한 시작/종료 시간이 타석 예약 시간 내인지 확인
    final tsStartTime = widget.tsReservationInfo['startTime'] as TimeOfDay;
    final tsEndTime = widget.tsReservationInfo['endTime'] as TimeOfDay;
    final tsStartMin = tsStartTime.hour * 60 + tsStartTime.minute;
    final tsEndMin = tsEndTime.hour * 60 + tsEndTime.minute;
    
    if (startMin < tsStartMin || endMin > tsEndMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 레슨 시간이 타석 예약 시간을 벗어납니다')),
      );
      return;
    }

    // 이미 예약된 시간과 겹치는지 확인
    if (_isOverlappingWithExisting(startMin, endMin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 시간이 이미 추가한 레슨 시간과 겹칩니다')),
      );
      return;
    }
    
    // 레슨 간 간격 확인 (새로 추가)
    if (_hasTooCloseLesson(startMin, endMin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 간 최소 $_lessonGap분의 간격이 필요합니다')),
      );
      return;
    }
    
    // 예약 정보에 맞는 시간 블록으로 포맷
    final startFormatted = '${_selectedStartTime!.hour.toString().padLeft(2, '0')}:${_selectedStartTime!.minute.toString().padLeft(2, '0')}';
    final endFormatted = '${_selectedEndTime!.hour.toString().padLeft(2, '0')}:${_selectedEndTime!.minute.toString().padLeft(2, '0')}';
    
    // 예약된 레슨 정보 생성
    final lessonCartItem = {
      'startMin': startMin,
      'endMin': endMin,
      'startFormatted': startFormatted,
      'endFormatted': endFormatted,
      'lessonDuration': lessonDuration,
      'pro': _selectedPro,
      'lessonStatusId': _selectedLessonStatus!['LS_counting_id'],
      'contractId': contractId, // 선택된 계약의 ID 직접 사용
    };
    
    setState(() {
      // 장바구니에 레슨 추가
      _selectedTimeBlocks.add(lessonCartItem);
      
      // 예약한 시간을 가용 목록에서 제외 처리
      _updateAvailableTimeBlocksForDirectTime(startMin, endMin);
      
      // 잔여 시간 업데이트
      final updatedBalanceMin = balanceMin - lessonDuration;
      if (_selectedLessonStatus != null) {
        _selectedLessonStatus!['LS_balance_min_after'] = updatedBalanceMin;
      }
      
      // 선택 초기화
      _selectedStartTime = null;
      _selectedEndTime = null;
      _selectedTimeBlock = null;
      _lessonDuration = _getMinServiceTime(); // 프로별 최소 예약 시간으로 리셋
    });
    
    // 자동으로 다음 가능한 시간 선택 추가
    _updateInitialTimeSelectionAfterCart();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('레슨이 장바구니에 추가되었습니다')),
    );
  }

  // 이미 예약된 레슨 이후 첫 번째 유효한 시간 자동 설정
  void _updateInitialTimeSelectionAfterCart() {
    // 시간 블록이 없거나 레슨 간격이 0인 경우 처리하지 않음
    if (_availableTimeBlocks.isEmpty || _lessonGap <= 0 || _selectedTimeBlocks.isEmpty) {
      return;
    }
    
    // 가장 마지막 예약된 레슨 블록 찾기
    int lastEndMin = 0;
    for (final block in _selectedTimeBlocks) {
      final blockEndMin = block['endMin'] as int;
      if (blockEndMin > lastEndMin) {
        lastEndMin = blockEndMin;
      }
    }
    
    // 최소 간격 이후의 첫 번째 가능한 시간 찾기
    final earliestValidStartMin = lastEndMin + _lessonGap;
    
    // 가능한 첫 번째 시간 블록 찾기
    Map<String, dynamic>? validBlock;
    int? validStartMin;
    
    for (final block in _availableTimeBlocks) {
      final blockStartMin = block['startMin'] as int;
      final blockEndMin = block['endMin'] as int;
      final minServiceTime = _getMinServiceTime();
      
      // 블록이 늦은 시작 시간을 수용할 수 있는지 확인
      if (earliestValidStartMin <= blockEndMin - minServiceTime) {
        // 블록 내에서 첫 번째 가능한 시간 계산
        final serviceTimeUnit = _getServiceTimeUnit();
        
        // 블록 시작 시간과 최소 유효 시간 중 더 늦은 시간 사용
        int firstValidMin = blockStartMin > earliestValidStartMin ? blockStartMin : earliestValidStartMin;
        
        // 서비스 시간 단위로 나눠떨어지는 시간으로 조정
        final remainder = firstValidMin % serviceTimeUnit;
        if (remainder > 0) {
          firstValidMin = firstValidMin + (serviceTimeUnit - remainder);
        }
        
        // 이 시간이 블록 내에 있고 최소 서비스 시간을 확보할 수 있는지 확인
        if (firstValidMin <= blockEndMin - minServiceTime) {
          validBlock = block;
          validStartMin = firstValidMin;
          break;
        }
      }
    }
    
    // 유효한 시간이 발견되면 자동 설정
    if (validBlock != null && validStartMin != null) {
      final startHour = validStartMin ~/ 60;
      final startMinute = validStartMin % 60;
      final startTime = TimeOfDay(hour: startHour, minute: startMinute);
      
      // 여기서 non-null 타입으로 안전하게 사용 가능
      final nonNullValidBlock = validBlock;
      final nonNullValidStartMin = validStartMin;
      
      setState(() {
        _selectedStartTime = startTime;
        _selectedTimeBlock = nonNullValidBlock;
        
        // 종료 시간도 자동 설정
        final endMin = nonNullValidStartMin + _getMinServiceTime();
        final blockEndMin = nonNullValidBlock['endMin'] as int;
        final adjustedEndMin = endMin < blockEndMin ? endMin : blockEndMin;
        
        _selectedEndTime = TimeOfDay(
          hour: (adjustedEndMin ~/ 60), 
          minute: (adjustedEndMin % 60)
        );
        
        // 레슨 시간 업데이트
        _lessonDuration = _calculateLessonDuration();
      });
      
      print('🔍 [디버깅] 자동 시간 설정: 시작=${_selectedStartTime!.format(context)}, 종료=${_selectedEndTime!.format(context)}, 시간=${_lessonDuration}분');
    } else {
      // 유효한 시간이 없으면 선택 초기화
      setState(() {
        _selectedStartTime = null;
        _selectedEndTime = null;
        _selectedTimeBlock = null;
        _lessonDuration = _getMinServiceTime();
      });
      
      print('⚠️ [주의] 이전 레슨 이후 $_lessonGap분 뒤 유효한 시간을 찾을 수 없음');
    }
  }

  // 특정 프로의 특정 날짜 예약 현황 조회
  Future<List<Map<String, dynamic>>> _fetchProOrders(String proName, String scheduledDate) async {
    try {
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'pro_name', 'operator': '=', 'value': proName},
        {'field': 'scheduled_date', 'operator': '=', 'value': scheduledDate}
      ];
      
      // branch_id 조건 추가
      if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
          Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
        });
      }
      
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'where': whereConditions
        }),
      );
      
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true && resp['data'] != null) {
          final orders = resp['data'] as List;
          print('프로 예약 현황 API 응답: $orders');
          
          if (orders.isNotEmpty) {
            final List<Map<String, dynamic>> processedOrders = 
                List<Map<String, dynamic>>.from(orders).map((order) {
              // 숫자 필드 변환
              _convertToInt(order, 'LS_order_id');
              _convertToInt(order, 'member_id');
              _convertToInt(order, 'TS_id');
              return order;
            }).toList();
            
            return processedOrders;
          }
        }
      }
      
      print('프로 예약 현황 API 오류 또는 데이터 없음: ${response.statusCode}');
      return [];
    } catch (e) {
      print('프로 예약 현황 API 예외 발생: $e');
      return [];
    }
  }
} 