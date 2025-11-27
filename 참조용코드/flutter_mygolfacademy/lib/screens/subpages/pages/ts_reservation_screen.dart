import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/holiday_service.dart';
import '../../../services/reservation_service.dart'; // ReservationService import 추가
import 'dart:math';
import '../../../utils/time_slot_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/ts_option.dart'; // ts_option import로 변경
import 'lesson_availability_check.dart';
import 'lesson_reservation_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

// 할인율 변수 정의
class DiscountRates {
  // 등록회원 할인율 (%), ts_option에서 rate 삭제됨 → 하드코딩
  static double memberDiscount = 25.0;
  // 집중연습 할인액 (원), base_option에서 min120 등 삭제됨 → 하드코딩
  static int intensiveDiscount = 2000;
  // 재방문 할인율 (%), base_option에서 rate 삭제됨 → 하드코딩
  static double revisitDiscount = 5.0;
  // 집중연습 할인액 계산 함수
  static int getIntensiveDiscount(int durationMinutes) {
    if (durationMinutes >= 120) {
      return 2000;
    } else if (durationMinutes >= 90) {
      return 1000;
    } else {
      return 0;
    }
  }
}

/*
 * v2_Priced_TS 테이블 구조 (MariaDB):
 * 
 * 컬럼명                | # | Data Type
 * ---------------------|---|-------------
 * reservation_id       | 1 | varchar(50)  - 예약 ID (고유 식별자)
 * ts_id                | 2 | varchar(10)  - 타석 ID
 * ts_date              | 3 | date         - 타석 이용 날짜
 * ts_start             | 4 | time         - 타석 이용 시작 시간
 * ts_end               | 5 | time         - 타석 이용 종료 시간
 * ts_type              | 6 | varchar(20)  - 타석 예약유형(일반/주니어)
 * ts_payment_method    | 7 | varchar(20)  - 결제 방법(크레딧/카드/기업복지멤버십)
 * ts_status            | 7 | varchar(20)  - 타석 예약상태(결제완료/결제취소)
 * member_id            | 7 | int(11)      - 회원 ID
 * member_name          | 8 | varchar(50)  - 회원 이름
 * member_phone         | 9 | varchar(20)  - 회원 전화번호
 * total_amt            | 10| int(11)      - 총 금액 (정상가)
 * term_discount        | 11| int(11)      - 기간권 할인
 * member_discount      | 12| int(11)      - 등록회원 할인
 * junior_discount      | 13| int(11)      - 주니어 학부모 할인
 * routine_discount     | 14| int(11)      - 루틴예약 할인
 * overtime_discount    | 15| int(11)      - 집중연습할인
 * emergency_discount   | 16| int(11)      - 긴급 할인
 * revisit_discount     | 17| int(11)      - 재방문할인
 * emergency_reason     | 18| varchar(100) - 긴급 할인 사유
 * total_discount       | 19| int(11)      - 총 할인 금액
 * net_amt              | 20| int(11)      - 최종 결제 금액
 * morning              | 21| int(11)      - 아침 시간대 이용 여부
 * normal               | 22| int(11)      - 일반 시간대 이용 여부
 * peak                 | 23| int(11)      - 피크 시간대 이용 여부
 * night                | 24| int(11)      - 야간 시간대 이용 여부
 * ts_min               | 25| int(11)      - 이용 시간(분)
 * time_stamp           | 26| datetime     - 등록 시간
 */

class TSReservationScreen extends StatefulWidget {
  final int? memberId; // 회원 ID 파라미터만 남김
  final String? branchId; // 지점 ID 파라미터 추가
  
  const TSReservationScreen({
    Key? key, 
    this.memberId, // 회원 ID 선택적 파라미터로만 유지
    this.branchId, // 지점 ID 선택적 파라미터 추가
  }) : super(key: key);

  @override
  State<TSReservationScreen> createState() => _TSReservationScreenState();
}

class _TSReservationScreenState extends State<TSReservationScreen> {
  // 상태 변수 선언 부분
  bool _loadingData = false;
  List<Map<String, dynamic>> _availableTSs = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedStartTime = TimeOfDay(hour: 13, minute: 0);
  int _durationMinutes = 60;
  List<Map<String, dynamic>> _discounts = [];
  List<String> _selectedDiscounts = [];
  bool _isCalculatingFee = false;
  Map<String, dynamic> _feeDetails = {};
  bool _isPeakTime = false;
  bool _hasMembership = false;
  bool _isCheckingMembership = false;
  String _memberType = 'default'; // 회원 유형 상태 추가
  bool _isProcessingPayment = false; // 결제 처리 중 상태 추가
  
  // 홀드 기간과 만료일자 정보를 저장할 상태 변수 추가
  String _holdStartDate = '';
  String _holdEndDate = '';
  String _expiryDate = '';
  String _termType = ''; // 기간권 타입 정보 추가
  
  // 단계 관리
  int _currentStep = 0; // 처음에 날짜 선택 화면이 나오도록 설정
  
  // 날짜 선택
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  // 시간 선택
  TimeOfDay? _selectedTime;
  
  // 연습 시간 선택 (5분 단위)
  // int _selectedDuration = ts_option["duration"]["min"] as int; // 기본값 ts_option에서
  // final int _minDuration = ts_option["duration"]["min"] as int; // 최소 시간
  // final int _maxDuration = ts_option["duration"]["max"] as int; // 최대 시간
  // final int _dateMinOffset = ts_option["date"]["minOffsetDays"] as int;
  // final int _dateMaxOffset = ts_option["date"]["maxOffsetDays"] as int;
  // final int _timeUnit = ts_option["startTime"]["unitMinutes"] as int;
  // final int _durationUnit = ts_option["duration"]["unit"] as int;
  
  // 공휴일 여부
  bool _isHoliday = false;
  TimeOfDay _businessStartTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _businessEndTime = const TimeOfDay(hour: 24, minute: 0);
  TimeOfDay _lastReservationTime = const TimeOfDay(hour: 23, minute: 30);
  
  // 시간대 정의 - HH:MM 형식의 문자열로 정의
  // 평일 시간대 시작/종료 시간
  final String _ts_weekday_morning_start = '06:00';
  final String _ts_weekday_morning_end = '10:00';
  final String _ts_weekday_peak_start = '17:00';
  final String _ts_weekday_peak_end = '22:00';
  final String _ts_weekday_night_start = '23:00';
  final String _ts_weekday_night_end = '24:00';
  
  // 주말/공휴일 시간대 시작/종료 시간
  final String _ts_holiday_peak_start = '10:00';
  final String _ts_holiday_peak_end = '18:00';
  
  // 시간대 정의 - 분 단위로 저장 (6:00 = 6*60 = 360분)
  // 평일 시간대 설정
  late Map<String, List<List<int>>> _weekdayTimeSlots;
  
  // 주말/공휴일 시간대 설정
  late Map<String, List<List<int>>> _holidayTimeSlots;
  
  // 타석 선택
  int? _selectedTS;
  bool _isLoadingTSs = false; // 타석 정보 로딩 중 여부
  
  // 결제 정보
  String? _selectedPaymentMethod;
  String? _selectedWelfareCompany;
  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'credit', 'name': '크레딧결제', 'icon': Icons.account_balance_wallet},
    {'id': 'card', 'name': '카드결제', 'icon': Icons.credit_card},
    {'id': 'welfare', 'name': '기업복지멤버십', 'icon': Icons.business},
  ];
  final List<String> _welfareCompanies = ['웰빙클럽', '아이코젠', '리프레쉬'];
  
  // 최종 예약 정보
  Map<String, dynamic> _reservationData = {};
  
  // TextEditingController for custom duration input
  final TextEditingController _durationController = TextEditingController(text: '30');
  
  // 시간 선택을 위한 변수들
  List<int> _hours = [];  // 초기화는 initState에서 진행
  List<int> _minutes = []; // 초기화는 initState에서 진행
  
  // 요금 관련 변수 추가
  Map<String, dynamic>? _feeInfo;
  
  // ts_option 값 추출
  // final int _dateMinOffset = ts_option["date"]["minOffsetDays"] as int;
  // final int _dateMaxOffset = ts_option["date"]["maxOffsetDays"] as int;
  // final int _timeUnit = ts_option["startTime"]["unitMinutes"] as int;
  // final int _durationUnit = ts_option["duration"]["unit"] as int;
  
  // ts_option에서 옵션 추출 함수
  dynamic getTsOption(String key) {
    // member_type이 없거나 잘못된 경우 default로 fallback
    final typeOption = ts_option[_memberType] as Map<String, dynamic>? ?? {};
    dynamic value = typeOption.containsKey(key) ? typeOption[key] : ts_option["default"][key];
    // value가 null이거나 Map/num/bool/String이 아니면 default[key]로 fallback
    if (value == null || (value is! Map && value is! bool && value is! num && value is! String)) {
      value = ts_option["default"][key];
    }
    return value;
  }

  // 연습 시간 선택 (5분 단위)
  int get _selectedDuration => _durationController.text.isNotEmpty ? int.tryParse(_durationController.text) ?? _minDuration : _minDuration;
  set _selectedDuration(int value) {
    _durationController.text = value.toString();
  }
  int get _minDuration {
    final duration = getTsOption("duration");
    if (duration is Map && duration.containsKey("min")) {
      return duration["min"] as int;
    }
    return 60; // fallback
  }
  int get _maxDuration {
    final duration = getTsOption("duration");
    if (duration is Map && duration.containsKey("max")) {
      return duration["max"] as int;
    }
    return 60; // fallback
  }
  int get _durationUnit {
    final duration = getTsOption("duration");
    if (duration is Map && duration.containsKey("unit")) {
      return duration["unit"] as int;
    }
    return 60; // fallback
  }
  int get _dateMinOffset {
    final date = getTsOption("date");
    if (date is Map && date.containsKey("minOffsetDays")) {
      return date["minOffsetDays"] as int;
    }
    return 0; // fallback
  }
  int get _dateMaxOffset {
    final date = getTsOption("date");
    if (date is Map && date.containsKey("maxOffsetDays")) {
      return date["maxOffsetDays"] as int;
    }
    return 10; // fallback
  }
  int get _timeUnit {
    final startTime = getTsOption("startTime");
    if (startTime is Map && startTime.containsKey("unitMinutes")) {
      return startTime["unitMinutes"] as int;
    }
    return 10; // fallback
  }

  // 시간 피커용 스크롤 컨트롤러 추가
  FixedExtentScrollController? _hourScrollController;
  FixedExtentScrollController? _minuteScrollController;

  // 1. 비활성화 날짜 Set 추가
  Set<String> _disabledDates = {};

  @override
  void initState() {
    // branchId는 필수이므로 null이면 에러 처리
    assert(widget.branchId != null, 'branchId는 필수입니다.');
    if (widget.branchId == null) {
      // branchId가 없으면 예약화면 진입 자체를 막음
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('지점 정보가 없습니다. 예약을 진행할 수 없습니다.')),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    super.initState();
    _fetchMemberType();
    _loadingData = true;
    _selectedDiscounts = [];
    _isPeakTime = false;
    _hasMembership = false;
    
    // 홀드 기간과 만료일자 정보를 저장할 상태 변수 초기화
    _holdStartDate = '';
    _holdEndDate = '';
    _expiryDate = '';
    
    // 디버깅: 회원 ID 확인
    print('🔍 [디버깅] TSReservationScreen.initState - 회원 ID: ${widget.memberId}, 타입: ${widget.memberId?.runtimeType}');
    
    // 할인 정보 초기화
    _discounts = [
      {'id': 'member', 'name': '등록회원 할인', 'amount': DiscountRates.memberDiscount, 'percentage': true, 'isActive': true},
      {'id': 'membership', 'name': '기간권 할인', 'amount': 0, 'percentage': false, 'isActive': false},
      {'id': 'junior_parent', 'name': '주니어 학부모 할인', 'amount': 0, 'percentage': false, 'isActive': true},
      {'id': 'intensive', 'name': '집중연습할인', 'amount': DiscountRates.intensiveDiscount, 'percentage': false, 'isActive': true},
      {'id': 'revisit', 'name': '재방문할인', 'amount': 0, 'percentage': false, 'isActive': true},
    ];
    
    // 시간대 설정 초기화
    _weekdayTimeSlots = TimeSlotUtils.getWeekdayTimeSlots(
      morningStart: _ts_weekday_morning_start,
      morningEnd: _ts_weekday_morning_end,
      peakStart: _ts_weekday_peak_start,
      peakEnd: _ts_weekday_peak_end,
      nightStart: _ts_weekday_night_start,
      nightEnd: _ts_weekday_night_end,
    );
    _holidayTimeSlots = TimeSlotUtils.getHolidayTimeSlots(
      peakStart: _ts_holiday_peak_start,
      peakEnd: _ts_holiday_peak_end,
    );
    
    // 기본 시간/분 목록 초기화
    _hours = TimeSlotUtils.generateHours(6, 24);
    _minutes = List.generate(60 ~/ _timeUnit, (index) => index * _timeUnit);
    
    _durationController.addListener(() {
      if (_durationController.text.isNotEmpty) {
        final newValue = int.tryParse(_durationController.text);
        if (newValue != null && newValue >= _minDuration && newValue <= _maxDuration) {
          setState(() {
            _selectedDuration = newValue;
            _updateIntensiveDiscount(); // 집중연습할인 자동 갱신
          });
          // 연습 시간이 변경되면 타석 정보 갱신만 수행
          _loadAvailableTSs();
          // 자동 요금 계산 호출 제거
        }
      }
    });
    
    // 강제로 날짜 선택 화면이 첫 번째로 표시되도록 합니다
    _currentStep = 0;
    
    // 영업 시간 초기화 및 시간 관련 변수 설정
    _initializeBusinessHours();
    
    // 기본 결제 방법을 크레딧 결제로 설정
    _selectedPaymentMethod = 'credit';
    
    // 기본적으로 등록회원 할인 선택
    _selectedDiscounts.add('member');
    
    // 회원 ID 유효성 확인 및 디버깅 정보 출력
    final int? memberId = widget.memberId;
    if (memberId == null) {
      print('❌ [디버깅] 회원 ID가 null입니다. 로그인 상태를 확인해주세요.');
    } else if (memberId <= 0) {
      print('❌ [디버깅] 회원 ID가 0 이하입니다: $memberId. 유효하지 않은 회원 ID입니다.');
    } else {
      print('✅ [디버깅] 유효한 회원 ID: $memberId');
    }
    
    // 기간권 보유 여부 확인 - 회원 ID가 있는 경우만 호출
    if (memberId != null && memberId > 0) {
      print('🔍 [디버깅] 기간권 확인 호출 직전 - 회원 ID: $memberId');
      _loadMembershipStatus(memberId);
    } else {
      print('🔍 [디버깅] 기간권 확인 불가 - 회원 ID가 유효하지 않습니다: $memberId');
      
      // 회원 ID가 없는 경우 기간권 할인 비활성화
      for (var discount in _discounts) {
        if (discount['id'] == 'membership') {
          discount['isActive'] = false;
          print('🏷️ [디버깅] 기간권 할인 비활성화 (유효한 회원 ID 없음)');
          break;
        }
      }
    }
    
    // 화면이 렌더링된 직후에도 _currentStep을 0으로 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentStep = 0;
        });
      }
    });

    // 2. 비활성화 날짜 불러오기 함수
    _fetchDisabledDates();
  }
  
  Future<void> _fetchMemberType() async {
    if (widget.memberId != null) {
      try {
        final response = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'FlutterApp/1.0'
          },
          body: jsonEncode({
            'operation': 'get',
            'table': 'v3_members',
            'fields': ['member_type'],
            'where': [
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId.toString()
              },
              if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                  Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
                {
                  'field': 'branch_id',
                  'operator': '=',
                  'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
                }
            ]
          }),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
            final memberType = data['data'][0]['member_type'];
            setState(() {
              _memberType = memberType ?? 'default';
            });
          }
        }
      } catch (e) {
        print('회원 타입 조회 오류: $e');
        setState(() {
          _memberType = 'default';
        });
      }
    }
  }
  
  // 연습 시간(_selectedDuration) 변경 시 집중연습할인 금액 자동 갱신 함수
  void _updateIntensiveDiscount() {
    final int discount = DiscountRates.getIntensiveDiscount(_selectedDuration);
    for (var d in _discounts) {
      if (d['id'] == 'intensive') {
        d['amount'] = discount;
      }
    }
  }
  
  // 기간권 보유 여부 확인 메소드 추가
  Future<void> _loadMembershipStatus(int? memberId) async {
    // memberId가 null이거나 0 이하인 경우 API 호출 없이 즉시 반환
    if (memberId == null || memberId <= 0) {
      print('❌ [디버깅] _loadMembershipStatus - 유효하지 않은 회원 ID: $memberId');
      
      if (mounted) {
        setState(() {
          _hasMembership = false;
          _isCheckingMembership = false;
          _holdStartDate = '';
          _holdEndDate = '';
          _expiryDate = '';
          
          // 기간권 할인 비활성화
          for (var discount in _discounts) {
            if (discount['id'] == 'membership') {
              discount['isActive'] = false;
              break;
            }
          }
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _isCheckingMembership = true;
      });
    }
    
    // 디버깅: 회원 ID 출력
    print('🔍 [디버깅] _loadMembershipStatus 호출됨 - 회원 ID: $memberId, 타입: ${memberId.runtimeType}');
    
    try {
      // 디버깅: API 요청 직전
      print('🔍 [디버깅] 기간권 상태 조회 시작 - 회원 ID: $memberId');
      
      // 1. 기간권 정보 조회 - dynamic_api.php 사용
      bool hasMembership = false;
      String holdStartDate = '';
      String holdEndDate = '';
      String expiryDate = '';
      String termType = '';
      
      // v2_Term_member 테이블에서 최신 기간권 정보 조회
      final termResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_Term_member',
          'fields': ['term_type', 'term_expirydate', 'term_id'],
          'where': [
            {
              'field': 'member_id',
              'operator': '=',
              'value': memberId.toString()
            },
            if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
              {
                'field': 'branch_id',
                'operator': '=',
                'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
              }
          ],
          'orderBy': [
            {
              'field': 'term_id',
              'direction': 'DESC'
            }
          ],
          'limit': 1
        }),
      );
      
      if (termResponse.statusCode == 200) {
        final termData = jsonDecode(termResponse.body);
        if (termData['success'] == true && termData['data'] != null && termData['data'].isNotEmpty) {
          final termInfo = termData['data'][0];
          termType = termInfo['term_type'] ?? '';
          expiryDate = termInfo['term_expirydate'] ?? '';
          final termId = termInfo['term_id'];
          
          // 만료일 확인
          if (expiryDate.isNotEmpty) {
            try {
              final expiry = DateTime.parse(expiryDate);
              final now = DateTime.now();
              
              if (expiry.isAfter(now)) {
                // 만료되지 않은 기간권이 있음
                
                // 2. 홀드 상태 확인 - dynamic_api.php 사용
                final holdResponse = await http.post(
                  Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
                  headers: {
                    'Content-Type': 'application/json',
                    'User-Agent': 'FlutterApp/1.0'
                  },
                  body: jsonEncode({
                    'operation': 'get',
                    'table': 'v2_Term_hold',
                    'where': [
                      {
                        'field': 'term_id',
                        'operator': '=',
                        'value': termId.toString()
                      },
                      {
                        'field': 'term_hold_start',
                        'operator': '<=',
                        'value': DateFormat('yyyy-MM-dd').format(now)
                      },
                      {
                        'field': 'term_hold_end',
                        'operator': '>=',
                        'value': DateFormat('yyyy-MM-dd').format(now)
                      }
                    ]
                  }),
                );
                
                if (holdResponse.statusCode == 200) {
                  final holdData = jsonDecode(holdResponse.body);
                  if (holdData['success'] == true && holdData['data'] != null && holdData['data'].isNotEmpty) {
                    // 현재 홀드 중
                    final holdInfo = holdData['data'][0];
                    holdStartDate = holdInfo['term_hold_start'] ?? '';
                    holdEndDate = holdInfo['term_hold_end'] ?? '';
                    hasMembership = false; // 홀드 중이므로 사용 불가
                  } else {
                    // 홀드 중이 아님 - 유효한 기간권
                    hasMembership = true;
                  }
                } else {
                  // 홀드 조회 실패 시 기간권 유효로 처리
                  hasMembership = true;
                }
              }
            } catch (e) {
              print('만료일 파싱 오류: $e');
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isCheckingMembership = false;
          _hasMembership = hasMembership;
          _holdStartDate = holdStartDate;
          _holdEndDate = holdEndDate;
          _expiryDate = expiryDate;
          _termType = termType;
          
          // 기간권 할인 활성화 여부 설정
          for (var discount in _discounts) {
            if (discount['id'] == 'membership') {
              discount['isActive'] = _hasMembership;
              break;
            }
          }
        });
      }
      
      // 디버깅 출력
      print('🔍 [디버깅] 기간권 상태: $_hasMembership');
      if (_hasMembership) {
        print('🔍 [디버깅] 기간권 타입: $_termType, 만료일: $_expiryDate');
      } else if (_holdStartDate.isNotEmpty && _holdEndDate.isNotEmpty) {
        print('🔍 [디버깅] 홀드 기간: $_holdStartDate ~ $_holdEndDate');
      }
      
    } catch (e) {
      print('❌ 기간권 확인 중 오류 발생: $e');
      print('❌ [디버깅] 오류 상세 스택트레이스: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _hasMembership = false;
          // 기간권 할인 비활성화
          for (var discount in _discounts) {
            if (discount['id'] == 'membership') {
              discount['isActive'] = false;
              break;
            }
          }
          _isCheckingMembership = false;
        });
      }
    }
  }
  
  // 시간 문자열을 분으로 변환하는 함수 (예: "06:30" -> 390분)
  // => TimeSlotUtils.convertTimeToMinutes로 대체
  // int _convertTimeToMinutes(String timeString) { ... }  // 삭제
  
  // 시간대 설정 초기화
  // void _initializeTimeSlots() { ... }  // 삭제
  
  // 특정 시간에 대해 유효한 분 목록 가져오기
  // => TimeSlotUtils.getValidMinutesForHour로 대체
  // List<int> _getValidMinutesForHour(int hour) { ... }  // 삭제
  
  // 기본 시간 설정 - 현재 시간 또는 영업 시작 시간 기준
  // => TimeSlotUtils.getDefaultTime로 대체
  // void _setDefaultTime() { ... }  // 삭제
  
  // 두 날짜가 같은 날인지 확인
  // => TimeSlotUtils.isSameDay로 대체
  // bool _isSameDay(DateTime a, DateTime b) { ... }  // 삭제
  
  // 영업 시간 초기화 및 적용
  Future<void> _initializeBusinessHours() async {
    try {
      print('🔍 [디버깅] _initializeBusinessHours 시작 - 현재 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
      final TimeOfDay? previousTime = _selectedTime; // 이전 선택 시간 저장
      bool isLessonTime = false;
      if (previousTime != null) {
        if (previousTime.minute == 0 || previousTime.minute == 30) {
          print('🔍 [디버깅] 이전 시간이 정각 또는 30분 단위로 선택된 것 같습니다 (가능한 레슨 시간)');
          isLessonTime = true;
        }
      }
      // 현재 선택된 날짜가 공휴일인지 확인
      _isHoliday = await HolidayService.isHoliday(_selectedDate);
      // 영업 시간 정보 가져오기 (branchId 추가)
      _businessStartTime = await HolidayService.getBusinessStartTime(_selectedDate, widget.branchId!);
      _businessEndTime = await HolidayService.getBusinessEndTime(_selectedDate, widget.branchId!);
      _selectedDuration = _selectedDuration > 0 ? _selectedDuration : _minDuration;
      _updateTimeSelectionRange();
      if (previousTime != null) {
        final int previousMinutes = previousTime.hour * 60 + previousTime.minute;
        final int businessStartMinutes = _businessStartTime.hour * 60 + _businessStartTime.minute;
        final int lastReservationMinutes = _lastReservationTime.hour * 60 + _lastReservationTime.minute;
        if (isLessonTime) {
          print('🔍 [디버깅] 레슨 시간으로 판단됨 (\\${previousTime.format(context)})');
          if (previousMinutes >= businessStartMinutes - 240 && previousMinutes <= lastReservationMinutes + 240) {
            print('🔍 [디버깅] 레슨 시간 강제 유지 (영업 시간 확장 범위 내): \\${previousTime.format(context)}');
            _selectedTime = previousTime;
          } else {
            if (previousMinutes >= businessStartMinutes && previousMinutes <= lastReservationMinutes) {
              print('🔍 [디버깅] 레슨 시간 유지 (영업 시간 내): \\${previousTime.format(context)}');
              _selectedTime = previousTime;
            } else {
              if (_selectedTime == null) {
                _setDefaultTime();
              }
              print('🔍 [디버깅] 레슨 시간이지만 영업 시간 외여서 기본 시간 설정: \\${_selectedTime!.format(context)}');
            }
          }
        } else {
          if (previousMinutes >= businessStartMinutes && previousMinutes <= lastReservationMinutes) {
            _selectedTime = previousTime;
            print('🔍 [디버깅] 일반 시간 유지 (영업 시간 내): \\${_selectedTime!.format(context)}');
          } else {
            if (_selectedTime == null) {
              _setDefaultTime();
            }
            print('🔍 [디버깅] 이전 시간이 영업 시간 외여서 기본 시간 설정: \\${_selectedTime!.format(context)}');
          }
        }
      } else {
        if (_selectedTime == null) {
          _setDefaultTime();
          print('🔍 [디버깅] 이전 시간 없음, 기본 시간 설정: \\${_selectedTime!.format(context)}');
        }
      }
      print('🔍 [디버깅] _initializeBusinessHours 종료 - 최종 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('영업 시간 초기화 오류: $e');
      _businessStartTime = const TimeOfDay(hour: 6, minute: 0);
      _businessEndTime = const TimeOfDay(hour: 24, minute: 0);
      _hours = List.generate(16, (index) => index + 6);
      _minutes = List.generate(12, (index) => index * 5);
      _lastReservationTime = TimeOfDay(hour: 24 - (_selectedDuration ~/ 60) - 1, 
                                      minute: 60 - (_selectedDuration % 60));
      if (_selectedTime == null) {
        _setDefaultTime();
      }
    }
  }
  
  // 날짜 변경 시 영업 시간 업데이트
  void _updateBusinessHoursForDate(DateTime date) async {
    final TimeOfDay? previousSelectedTime = _selectedTime;
    print('🔍 [디버깅] 날짜 변경 전 _selectedTime: \\${previousSelectedTime?.format(context) ?? "null"}');
    bool isLessonTime = false;
    if (previousSelectedTime != null) {
      if (previousSelectedTime.minute == 0 || previousSelectedTime.minute == 30) {
        isLessonTime = true;
        print('🔍 [디버깅] 선택된 시간(\\${previousSelectedTime.format(context)})이 레슨 시간으로 추정됩니다.');
      }
    }
    final TimeOfDay? savedSelectedTime = previousSelectedTime != null ? 
      TimeOfDay(hour: previousSelectedTime.hour, minute: previousSelectedTime.minute) : null;
    _selectedDate = date;
    await _initializeBusinessHours();
    print('🔍 [디버깅] _initializeBusinessHours 후 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
    if (savedSelectedTime != null) {
      final int selectedMinutes = savedSelectedTime.hour * 60 + savedSelectedTime.minute;
      final int businessStartMinutes = _businessStartTime.hour * 60 + _businessStartTime.minute;
      final int lastReservationMinutes = _lastReservationTime.hour * 60 + _lastReservationTime.minute;
      if (isLessonTime) {
        final int extendedStartMinutes = businessStartMinutes - 120;
        final int extendedEndMinutes = lastReservationMinutes + 120;
        if (selectedMinutes >= extendedStartMinutes && selectedMinutes <= extendedEndMinutes) {
          setState(() {
            print('🔍 [디버깅] 레슨 시간 강제 복원 (확장 영업시간 내): \\${savedSelectedTime.format(context)}');
            _selectedTime = savedSelectedTime;
            print('🔍 [디버깅] 레슨 시간으로 복원된 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
          });
        } else {
          print('🔍 [디버깅] 레슨 시간이지만 확장 영업시간 외 (${extendedStartMinutes}~${extendedEndMinutes}분)라서 복원 불가');
        }
      }
      else if (selectedMinutes >= businessStartMinutes && selectedMinutes <= lastReservationMinutes) {
        setState(() {
          print('🔍 [디버깅] 일반 시간 복원: \\${savedSelectedTime.format(context)}');
          _selectedTime = savedSelectedTime;
          print('🔍 [디버깅] 일반 시간으로 복원된 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
        });
      } else {
        print('🔍 [디버깅] 시간 복원 불가: 이전 시간(\\${savedSelectedTime.format(context)})이 영업 시간 외($businessStartMinutes~$lastReservationMinutes 분)');
      }
    }
    if (_selectedTime != null) {
      print('🔍 [디버깅] 날짜 변경 후 최종 시간 확인 및 타석 정보 갱신 - 시간: \\${_selectedTime?.format(context) ?? "null"}');
      _loadAvailableTSs();
    }
  }
  
  // 이용 가능한 타석 정보 로드
  Future<void> _loadAvailableTSs() async {
    // 필요한 데이터 확인
    if (_selectedTime == null) {
      return;
    }
    
    setState(() {
      _isLoadingTSs = true; // 로딩 시작
    });
    
    try {
      // 요청 직전의 시간 값 디버깅
      print('🔍 [디버깅] API 요청 직전 _selectedTime: ${_selectedTime?.format(context) ?? "null"}, 시: ${_selectedTime?.hour}, 분: ${_selectedTime?.minute}');
      
      // 이 시점에서 선택된 시간 복사본 저장
      final TimeOfDay requestTime = TimeOfDay(hour: _selectedTime!.hour, minute: _selectedTime!.minute);
      
      // 안전한 시간 값을 지역 변수에 저장 (값 객체이므로 변경될 수 없음)
      final int safeHour = requestTime.hour;
      final int safeMinute = requestTime.minute;
      
      // ReservationService를 통해 타석 정보 가져오기
      final availableTSs = await ReservationService.getAvailableTSs(
        _selectedDate,
        requestTime,  // 복사본 사용하여 시간 변경 방지
        _selectedDuration,
        branchId: widget.branchId
      );
      
      // 요청 후 시간이 변경되었는지 확인
      if (_selectedTime!.hour != safeHour || _selectedTime!.minute != safeMinute) {
        print('⚠️ [경고] API 요청 중 시간이 변경됨: ${safeHour}:${safeMinute.toString().padLeft(2, '0')} -> ${_selectedTime!.format(context)}');
        print('🔄 [복구] 원래 선택한 시간으로 복원 중...');
        
        // 안전한 값을 이용해 새 TimeOfDay 객체 생성 (원래 객체가 변경됐을 수 있으므로)
        _selectedTime = TimeOfDay(hour: safeHour, minute: safeMinute);
        
        // 추가 디버깅 로그
        print('🔍 [디버깅] 복원 후 _selectedTime: ${_selectedTime?.format(context) ?? "null"}');
      }
      
      setState(() {
        _availableTSs = availableTSs;
        _isLoadingTSs = false; // 로딩 완료
        
        // 시간 복원 확인
        final currentHour = _selectedTime!.hour;
        final currentMinute = _selectedTime!.minute;
        
        if (currentHour != safeHour || currentMinute != safeMinute) {
          print('⚠️ [경고] setState 중 시간이 다시 변경됨, 다시 복원 중...');
          _selectedTime = TimeOfDay(hour: safeHour, minute: safeMinute);
        }
        
        // 선택된 타석이 이용 불가능하게 되었다면 선택 해제
        if (_selectedTS != null) {
          final selectedTSInfo = _availableTSs.firstWhere(
            (ts) => ts['number'] == _selectedTS,
            orElse: () => {'isAvailable': false}
          );
          
          if (selectedTSInfo.isEmpty || !selectedTSInfo['isAvailable']) {
            _selectedTS = null;
            _feeInfo = null; // 타석이 해제되면 요금 정보도 초기화
          }
        }
      });
      
      // API 응답 로그 출력
      print('타석 조회 결과: ${availableTSs.length}개 타석 정보 수신');
      
      // 최종 시간 확인
      print('🔍 [디버깅] 타석 로드 완료 후 _selectedTime: ${_selectedTime?.format(context) ?? "null"}');
      
    } catch (e) {
      print('타석 정보 로드 중 오류 발생: $e');
      
      setState(() {
        // 에러 발생 시 기본 타석 정보 설정 (1~9번 타석, 모두 사용 가능으로)
        _availableTSs = [
          for (int i = 1; i <= 9; i++) {
            'number': i,
            'isAvailable': true,
            'type': i <= 6 ? '오픈타석' : '단독타석'
          }
        ];
        _isLoadingTSs = false; // 로딩 완료
      });
      
      // 사용자에게 오류 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('타석 정보를 가져오는 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '재시도',
            textColor: Colors.white,
            onPressed: _loadAvailableTSs,
          ),
        ),
      );
    }
  }
  
  // 요금 계산 함수
  Future<void> _calculateFee() async {
    if (_selectedTS != null) {
      // 시간대별 이용 시간 계산
      final timeSlots = _calculateTimeSlots();
      try {
        // 시작 시간 문자열 생성
        final startTimeStr = _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00'
            : '00:00:00';
        // 종료 시간 계산
        final endMinutes = (_selectedTime?.hour ?? 0) * 60 + (_selectedTime?.minute ?? 0) + _selectedDuration;
        final endHour = (endMinutes ~/ 60) % 24;
        final endMinute = endMinutes % 60;
        final endTimeStr = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}:00';
        // 요금 계산 서비스 호출 (async 함수)
        _feeInfo = await ReservationService.calculateFee(
          _selectedTS!,
          timeSlots,
          startTimeHours: _selectedTime?.hour,
          startTimeMinutes: _selectedTime?.minute,
          durationMinutes: _selectedDuration,
          membershipStatus: _hasMembership, // 최신 상태에서 직접 전달
          membershipType: _termType,        // 최신 상태에서 직접 전달
          memberId: widget.memberId ?? 0,   // 필수 파라미터 추가
          tsDate: DateFormat('yyyy-MM-dd').format(_selectedDate), // 필수 파라미터 추가
          tsStart: startTimeStr,
          tsEnd: endTimeStr,
          discounts: _selectedDiscounts, // 할인 체크박스 상태를 서비스에 전달
          branchId: widget.branchId, // branchId 파라미터 추가
        );
        // 예약 데이터에 요금 정보 추가
        _reservationData['feeInfo'] = _feeInfo;
        // 재방문 할인액을 _discounts 리스트에 동적으로 반영
        int revisitDiscount = _feeInfo?['revisitDiscount'] as int? ?? 0;
        for (var discount in _discounts) {
          if (discount['id'] == 'revisit') {
            discount['amount'] = revisitDiscount;
          }
        }
        // UI 갱신
        if (mounted) {
          setState(() {});
        }
        if (_feeInfo != null) {
          _feeInfo!['overtimeDiscount'] = DiscountRates.getIntensiveDiscount(_selectedDuration);
        }
      } catch (e) {
        // 오류 발생 시 사용자에게 알림
        if (mounted) {
          _feeInfo = null; // 이전 요금 정보 초기화
          setState(() {});
          // 스낵바 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('요금 정보를 가져오는 중 오류가 발생했습니다: ${e.toString()}'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: _calculateFee,
              ),
            ),
          );
        }
      }
    } else {
      _feeInfo = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // 할인 선택 시 금액만 재계산하는 함수 (API 호출 없음)
  void _recalculateDiscountedFee() {
    if (_feeInfo != null && mounted) {
      print('💰 [할인 재계산] API 호출 없이 금액만 재계산');
      setState(() {
        // UI만 업데이트 - 기존 _feeInfo 데이터 유지
      });
    }
  }
  
  // 선택 가능한 시간 범위 업데이트
  void _updateTimeSelectionRange() {
    print('🔍 [디버깅] _updateTimeSelectionRange 시작');
    print('🔍 [디버깅] 영업시간: ${_businessStartTime.format(context)} - ${_businessEndTime.format(context)}');
    print('🔍 [디버깅] 선택된 날짜: ${_selectedDate.toString()}');
    print('🔍 [디버깅] _timeUnit: $_timeUnit');
    
    try {
      // 마지막 예약 가능 시간 계산 (영업 종료 30분 전)
      int endTimeInMinutes = _businessEndTime.hour * 60 + _businessEndTime.minute;
      int lastReservationMinutes = endTimeInMinutes - 30;
      int lastReservationHour = lastReservationMinutes ~/ 60;
      int lastReservationMinute = lastReservationMinutes % 60;
      _lastReservationTime = TimeOfDay(hour: lastReservationHour, minute: lastReservationMinute);
      
      print('🔍 [디버깅] 마지막 예약 가능 시간: ${_lastReservationTime.format(context)}');
      
      // 영업 시작 시간
      int startTimeInMinutes = _businessStartTime.hour * 60 + _businessStartTime.minute;
      
      // 오늘인 경우 현재 시간 고려
      final now = TimeOfDay.now();
      int nowInMinutes = now.hour * 60 + now.minute;
      bool isToday = _selectedDate.year == DateTime.now().year && 
                    _selectedDate.month == DateTime.now().month && 
                    _selectedDate.day == DateTime.now().day;
      
      int effectiveStartTimeInMinutes = (isToday && nowInMinutes > startTimeInMinutes) 
          ? nowInMinutes 
          : startTimeInMinutes;
      
      // 5분 단위로 올림 처리
      int effectiveStartHour = effectiveStartTimeInMinutes ~/ 60;
      int effectiveStartMinute = effectiveStartTimeInMinutes % 60;
      effectiveStartMinute = ((effectiveStartMinute + 4) ~/ 5) * 5;
      if (effectiveStartMinute >= 60) {
        effectiveStartHour += 1;
        effectiveStartMinute = 0;
      }
      
      print('🔍 [디버깅] 유효 시작 시간: ${effectiveStartHour}:${effectiveStartMinute.toString().padLeft(2, '0')}');
      
      // 시간 목록 생성 (간단하게)
      List<int> availableHours = [];
      for (int hour = effectiveStartHour; hour <= _lastReservationTime.hour; hour++) {
        availableHours.add(hour);
      }
      
      // 분 목록 생성 (5분 단위)
      int timeUnit = _timeUnit > 0 ? _timeUnit : 5; // fallback to 5 minutes
      List<int> availableMinutes = [];
      for (int minute = 0; minute < 60; minute += timeUnit) {
        availableMinutes.add(minute);
      }
      
      print('🔍 [디버깅] 생성된 시간 목록: $availableHours');
      print('🔍 [디버깅] 생성된 분 목록: $availableMinutes');
      
      // 빈 목록 방지
      if (availableHours.isEmpty) {
        availableHours.add(_businessStartTime.hour);
        print('🔍 [디버깅] 빈 시간 목록 방지 - 영업 시작 시간 추가: ${_businessStartTime.hour}');
      }
      
      if (availableMinutes.isEmpty) {
        availableMinutes.add(0);
        print('🔍 [디버깅] 빈 분 목록 방지 - 0분 추가');
      }
      
      // 현재 선택된 시간이 유효하지 않으면 조정
      if (_selectedTime != null) {
        int selectedTimeInMinutes = _selectedTime!.hour * 60 + _selectedTime!.minute;
        if (selectedTimeInMinutes < effectiveStartTimeInMinutes || 
            selectedTimeInMinutes > lastReservationMinutes) {
          print('🔍 [디버깅] 선택된 시간이 유효하지 않음 - 조정 필요');
          if (selectedTimeInMinutes < effectiveStartTimeInMinutes) {
            _selectedTime = TimeOfDay(hour: effectiveStartHour, minute: effectiveStartMinute);
          } else {
            _selectedTime = _lastReservationTime;
          }
          print('🔍 [디버깅] 시간 조정됨: ${_selectedTime!.format(context)}');
        }
      }
      
      // 선택된 시간이 없거나 유효하지 않으면 기본값 설정
      if (_selectedTime == null || !availableHours.contains(_selectedTime!.hour)) {
        _selectedTime = TimeOfDay(hour: availableHours.first, minute: availableMinutes.first);
        print('🔍 [디버깅] 기본 시간 설정: ${_selectedTime!.format(context)}');
      }
      
      setState(() {
        _hours = availableHours;
        _minutes = availableMinutes;
      });
      
      print('🔍 [디버깅] 최종 시간 목록: $_hours');
      print('🔍 [디버깅] 최종 분 목록: $_minutes');
      print('🔍 [디버깅] 최종 선택된 시간: ${_selectedTime?.format(context) ?? "null"}');
      
    } catch (e) {
      print('❌ [오류] 시간 선택 범위 업데이트 실패: $e');
      
      // 오류 발생 시 기본값 설정
      setState(() {
        _hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23];
        _minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
        if (_selectedTime == null) {
          _selectedTime = TimeOfDay(hour: 13, minute: 0);
        }
        _lastReservationTime = TimeOfDay(hour: 23, minute: 30);
      });
      
      print('🔍 [디버깅] 오류 복구 - 기본값 설정 완료');
    }
  }
  
  // 선택된 시간과 지속 시간으로 종료 시간 계산
  TimeOfDay _getEndTime() {
    // _selectedTime이 null인 경우 현재 시간 반환
    if (_selectedTime == null) {
      return TimeOfDay.now();
    }
    
    final int totalMinutes = _selectedTime!.hour * 60 + _selectedTime!.minute + _selectedDuration;
    final int endHour = totalMinutes ~/ 60;
    final int endMinute = totalMinutes % 60;
    return TimeOfDay(hour: endHour % 24, minute: endMinute);
  }
  
  // 기본 시간 설정 - 현재 시간 또는 영업 시작 시간 기준
  // => TimeSlotUtils.getDefaultTime로 대체
  void _setDefaultTime() {
    print('🔍 [디버깅] _setDefaultTime 시작 - 현재 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
    
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    // 5분 단위로 올림 처리
    final roundedMinutes = ((currentMinutes + 4) ~/ 5) * 5;
    final roundedHour = (roundedMinutes ~/ 60) % 24;
    final roundedMinute = roundedMinutes % 60;
    
    // 마지막 예약 가능 시간(분)
    final lastReservationMinutes = _lastReservationTime.hour * 60 + _lastReservationTime.minute;
    // 영업 시작 시간(분)
    final businessStartMinutes = _businessStartTime.hour * 60 + _businessStartTime.minute;
    
    TimeOfDay newSelectedTime;
    
    // 현재 날짜가 오늘이고, 현재 시간이 영업 시간 내에 있는 경우
    if (TimeSlotUtils.isSameDay(_selectedDate, DateTime.now())) {
      if (roundedMinutes >= businessStartMinutes && roundedMinutes <= lastReservationMinutes) {
        // 현재 시간이 영업 시간 내에 있으면 현재 시간 사용
        newSelectedTime = TimeOfDay(hour: roundedHour, minute: roundedMinute);
        print('🔍 [디버깅] 현재 시간 사용: ${newSelectedTime.format(context)}');
      } else if (roundedMinutes < businessStartMinutes) {
        // 현재 시간이 영업 시작 전이면 영업 시작 시간 사용
        newSelectedTime = _businessStartTime;
        print('🔍 [디버깅] 영업 시작 시간 사용: ${newSelectedTime.format(context)}');
      } else if (roundedMinutes > lastReservationMinutes) {
        // 현재 시간이 마지막 예약 가능 시간 이후면 마지막 예약 가능 시간 설정
        newSelectedTime = _lastReservationTime;
        print('🔍 [디버깅] 마지막 예약 시간 사용: ${newSelectedTime.format(context)}');
      } else {
        // 기본값으로 영업 시작 시간 사용
        newSelectedTime = _businessStartTime;
        print('🔍 [디버깅] 기본 시간 사용: ${newSelectedTime.format(context)}');
      }
    } else {
      // 다른 날짜의 경우 영업 시작 시간 사용
      newSelectedTime = _businessStartTime;
      print('🔍 [디버깅] 다른 날짜 기본 시간 사용: ${newSelectedTime.format(context)}');
    }
    
    // 선택된 시간이 마지막 예약 가능 시간을 초과하지 않도록 확인
    final selectedMinutes = newSelectedTime.hour * 60 + newSelectedTime.minute;
    if (selectedMinutes > lastReservationMinutes) {
      newSelectedTime = _lastReservationTime;
      print('🔍 [디버깅] 선택 시간 조정 (최대값 초과): ${newSelectedTime.format(context)}');
    }
    
    _selectedTime = newSelectedTime;
    print('🔍 [디버깅] _setDefaultTime 종료 - 설정된 _selectedTime: \\${_selectedTime?.format(context) ?? "null"}');
  }
  
  // 두 날짜가 같은 날인지 확인
  // => TimeSlotUtils.isSameDay로 대체
  bool _isSameDay(DateTime a, DateTime b) {
    return TimeSlotUtils.isSameDay(a, b);
  }
  
  @override
  void dispose() {
    _durationController.dispose();
    _hourScrollController?.dispose();
    _minuteScrollController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('타석예약'),
      ),
      body: SingleChildScrollView(
        child: Stepper(
          type: StepperType.vertical,
          physics: const ClampingScrollPhysics(),
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            final isFirstStep = _currentStep == 0;
            final isLastStep = _currentStep == 4; // 결제 스텝 추가로 인해 4로 변경
            
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  // 첫 단계가 아니면 이전 버튼을 표시
                  if (!isFirstStep) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('이전'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  // 다음 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessingPayment ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessingPayment && isLastStep
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('처리중...'),
                              ],
                            )
                          : Text(isLastStep ? '결제하기' : '다음'),
                    ),
                  ),
                ],
              ),
            );
          },
          currentStep: _currentStep,
          onStepTapped: (step) {
            // 단계 제목을 탭했을 때 해당 단계로 이동
            setState(() {
              _currentStep = step;
              
              // 시간 선택 스텝으로 이동했을 때 시간 선택 범위 업데이트
              if (step == 1 && _selectedDuration > 0) {
                _updateTimeSelectionRange();
              }
              
              // 타석 선택 단계로 이동할 때 타석 정보 갱신
              if (step == 3 && _selectedTime != null) {
                _loadAvailableTSs();
              }
            });
          },
          onStepContinue: () async {
            if (_currentStep < 4) { // 결제 스텝 추가로 인해 4로 변경
              // 다음 단계로 이동하기 전에 현재 단계의 데이터 유효성 검사
              bool canContinue = true;
              
              switch (_currentStep) {
                case 0: // 날짜 선택
                  // 항상 날짜가 선택되어 있으므로 추가 검사 필요 없음
                  _reservationData['date'] = _selectedDate;
                  // 1단계에서 다음 누를 때 최소 이용시간 기반 마지막 예약 가능 시간 갱신
                  await _updateLastReservationTimeByMinTsMin();
                  break;
                case 1: // 시작 시간 선택
                  if (_selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('시작 시간을 선택해주세요')),
                    );
                    canContinue = false;
                  } else {
                    _reservationData['startTime'] = _selectedTime;
                  }
                  break;
                case 2: // 연습 시간 선택
                  // 시간이 선택되었는지 확인
                  if (_selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('시작 시간을 선택해주세요')),
                    );
                    setState(() {
                      _currentStep = 1; // 시간 선택 단계로 되돌아가기
                    });
                    canContinue = false;
                  } else {
                    _reservationData['duration'] = _selectedDuration;
                  }
                  break;
                case 3: // 타석 선택
                  if (_selectedTS == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('타석을 선택해주세요')),
                    );
                    canContinue = false;
                  } else if (_selectedTime == null) {
                    // 시간이 선택되었는지 확인
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('시작 시간이 설정되어 있지 않습니다')),
                    );
                    setState(() {
                      _currentStep = 1; // 시간 선택 단계로 되돌아가기
                    });
                    canContinue = false;
                  } else {
                    _reservationData['tsNumber'] = _selectedTS;
                    var ts = _availableTSs.firstWhere(
                      (ts) => ts['number'] == _selectedTS,
                      orElse: () => {'type': '오픈타석'} // 기본값 제공
                    );
                    _reservationData['tsType'] = ts['type'];
                    // 타석 선택 후 다음 단계로 넘어갈 때만 요금 계산 (비동기 1회만)
                    await _calculateFee();
                  }
                  break;
              }
              
              if (canContinue) {
                // 요금 계산이 끝난 후에만 다음 단계로 이동
                if (mounted) {
                  setState(() {
                    _currentStep += 1;
                    // 타석 선택 단계로 이동할 때 타석 정보 갱신
                    if (_currentStep == 3 && _selectedTime != null) {
                      _loadAvailableTSs();
                    }
                  });
                }
              }
            } else {
              // 마지막 스텝(결제)일 때 예약 확정 함수 호출
              await _finishReservation();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              // Future.microtask를 사용하여 UI 갱신 후 상태 변경
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    _currentStep -= 1;
                    
                    // 연습 시간 선택에서 시간 선택으로 돌아갔을 때 시간 선택 범위 업데이트
                    if (_currentStep == 1 && _selectedDuration > 0) {
                      _updateTimeSelectionRange();
                    }
                  });
                }
              });
            }
          },
          steps: [
            Step(
              title: const Text('날짜 선택'),
              content: _buildDateSelection(),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('시작 시간 선택'),
              content: _buildTimeSelection(),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('연습 시간 선택'),
              content: _buildDurationSelection(),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('타석 선택'),
              content: _buildTSSelection(),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('결제'),
              content: _buildPaymentSelection(),
              isActive: _currentStep >= 4,
            ),
          ],
        ),
      ),
    );
  }
  
  // 날짜 선택 위젯
  Widget _buildDateSelection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                firstDay: DateTime.now().add(Duration(days: _dateMinOffset)),
                lastDay: DateTime.now().add(Duration(days: _dateMaxOffset)),
                focusedDay: _selectedDate,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: '달력',
                },
                selectedDayPredicate: (day) {
                  return TimeSlotUtils.isSameDay(_selectedDate, day);
                },
                // 3. 비활성화 날짜 적용
                enabledDayPredicate: (day) {
                  if (_disabledDates.isEmpty) return true;
                  final dayStr = DateFormat('yyyy-MM-dd').format(day);
                  return !_disabledDates.contains(dayStr);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                    // 날짜가 변경되면 해당 날짜의 영업 시간 업데이트
                    _updateBusinessHoursForDate(selectedDay);
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false, // 포맷 버튼 숨기기
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 날짜',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 시간 선택 위젯 (쿠퍼티노 스타일로 변경)
  Widget _buildTimeSelection() {
    print('🔍 [디버깅] _buildTimeSelection 시작');
    print('🔍 [디버깅] _hours: $_hours');
    print('🔍 [디버깅] _minutes: $_minutes');
    print('🔍 [디버깅] _selectedTime: ${_selectedTime?.format(context) ?? "null"}');
    
    // 시간 목록이 비어있는 경우 처리
    if (_hours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              '현재 선택 가능한 시간이 없습니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '다른 날짜를 선택하거나 연습 시간을 줄여주세요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 간단한 필터링 로직
    final now = TimeOfDay.now();
    final nowDate = DateTime.now();
    bool isToday = _selectedDate.year == nowDate.year && 
                   _selectedDate.month == nowDate.month && 
                   _selectedDate.day == nowDate.day;
    
    // 시간 목록 필터링 (더 간단하게)
    List<int> filteredHours = List.from(_hours);
    List<int> filteredMinutes = List.from(_minutes);
    
    // 레슨 시간이 선택된 경우에는 필터링을 적용하지 않음
    // (레슨 시간은 영업시간 외에도 가능할 수 있음)
    bool isLessonTimeSelected = _selectedTime != null && 
        (_selectedTime!.minute == 0 || _selectedTime!.minute == 30);
    
    // 오늘인 경우에만 현재 시간 이후로 제한 (단, 레슨 시간이 아닌 경우에만)
    if (isToday && !isLessonTimeSelected) {
      int currentMinutes = now.hour * 60 + now.minute;
      
      // 현재 시간 이후의 시간만 허용
      filteredHours = _hours.where((hour) {
        // 현재 시간보다 이후의 시간이거나, 현재 시간과 같은 시간이면서 선택 가능한 분이 있는 경우
        if (hour > now.hour) return true;
        if (hour == now.hour) {
          return _minutes.any((minute) => hour * 60 + minute > currentMinutes);
        }
        return false;
      }).toList();
    }
    
    print('🔍 [디버깅] 레슨 시간 선택 여부: $isLessonTimeSelected');
    print('🔍 [디버깅] 필터링된 시간: $filteredHours');
    print('🔍 [디버깅] 필터링된 분: $filteredMinutes');
    
    // 빈 목록 방지
    if (filteredHours.isEmpty) {
      filteredHours = List.from(_hours);
      print('🔍 [디버깅] 빈 시간 목록 방지 - 전체 시간 사용');
    }
    
    if (filteredMinutes.isEmpty) {
      filteredMinutes = List.from(_minutes);
      print('🔍 [디버깅] 빈 분 목록 방지 - 전체 분 사용');
    }

    // 선택된 시간이 없거나 유효하지 않으면 기본값 설정
    if (_selectedTime == null || !filteredHours.contains(_selectedTime!.hour)) {
      _selectedTime = TimeOfDay(hour: filteredHours.first, minute: filteredMinutes.first);
      print('🔍 [디버깅] 기본 시간 설정: ${_selectedTime!.format(context)}');
    }
    
    // 현재 선택된 시간에 대한 유효한 분 목록
    List<int> currentValidMinutes = List.from(filteredMinutes);
    if (isToday && _selectedTime!.hour == now.hour) {
      // 오늘이고 현재 시간과 같은 시간이면 현재 분 이후만 허용
      currentValidMinutes = filteredMinutes.where((minute) => minute > now.minute).toList();
      if (currentValidMinutes.isEmpty) {
        currentValidMinutes = List.from(filteredMinutes);
      }
    }

    // 선택된 시간이 피커에 표시되도록 초기 인덱스 설정
    int initialHourIndex = filteredHours.contains(_selectedTime!.hour) 
        ? filteredHours.indexOf(_selectedTime!.hour) 
        : 0;
    
    int initialMinuteIndex = currentValidMinutes.contains(_selectedTime!.minute) 
        ? currentValidMinutes.indexOf(_selectedTime!.minute) 
        : 0;
    
    print('🔍 [디버깅] 초기 시간 인덱스: $initialHourIndex (${filteredHours.isNotEmpty ? filteredHours[initialHourIndex] : "없음"}시)');
    print('🔍 [디버깅] 초기 분 인덱스: $initialMinuteIndex (${currentValidMinutes.isNotEmpty ? currentValidMinutes[initialMinuteIndex] : "없음"}분)');
    
    // 스크롤 컨트롤러 생성 (클래스 멤버 변수 사용)
    _hourScrollController ??= FixedExtentScrollController(initialItem: initialHourIndex);
    _minuteScrollController ??= FixedExtentScrollController(initialItem: initialMinuteIndex);
    
    // 스크롤 컨트롤러 위치 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hourScrollController!.hasClients && initialHourIndex != _hourScrollController!.selectedItem) {
        _hourScrollController!.animateToItem(
          initialHourIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (_minuteScrollController!.hasClients && initialMinuteIndex != _minuteScrollController!.selectedItem) {
        _minuteScrollController!.animateToItem(
          initialMinuteIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    // 상단에 표시되는 시간 문자열
    String selectedTimeText = _selectedTime != null 
        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : '시간을 선택해주세요';
    
    print('🔍 [디버깅] 시간 선택 UI - 현재 선택된 시간: $selectedTimeText');
    print('🔍 [디버깅] 시간 선택 UI - 필터링된 시간: $filteredHours');
    print('🔍 [디버깅] 시간 선택 UI - 선택된 시간의 유효한 분: $currentValidMinutes');
    print('🔍 [디버깅] 시간 선택 UI - 초기 시간 인덱스: $initialHourIndex ${filteredHours.isNotEmpty ? "(${filteredHours[initialHourIndex]}시)" : "(시간 없음)"}');
    print('🔍 [디버깅] 시간 선택 UI - 초기 분 인덱스: $initialMinuteIndex ${currentValidMinutes.isNotEmpty && initialMinuteIndex < currentValidMinutes.length ? "(${currentValidMinutes[initialMinuteIndex]}분)" : "(분 없음)"}');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 공휴일 여부 및 영업 시간 표시
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHoliday ? Colors.amber.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isHoliday ? Colors.amber.shade200 : Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  _isHoliday ? Icons.event : Icons.business,
                  color: _isHoliday ? Colors.amber.shade700 : Colors.blue.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isHoliday
                        ? '공휴일 - 영업시간: ${_businessStartTime.format(context)}~${_businessEndTime.format(context)}'
                        : '평일 - 영업시간: ${_businessStartTime.format(context)}~${_businessEndTime.format(context)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isHoliday ? Colors.amber.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '시작 시간 선택',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Column(
                children: [
                  // 현재 선택된 시간 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      selectedTimeText,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _selectedTime != null 
                            ? Theme.of(context).primaryColor 
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 쿠퍼티노 스타일 시간 선택기
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 시간 선택 피커
                        Expanded(
                          flex: 2,
                          child: Container(
                            color: Colors.transparent, // 투명 배경으로 변경
                            child: CupertinoPicker(
                              backgroundColor: Colors.transparent, // 투명 배경으로 변경
                              itemExtent: 40,
                              diameterRatio: 1.2, 
                              magnification: 1.1, 
                              squeeze: 1.0, 
                              useMagnifier: true, 
                              looping: false,
                              onSelectedItemChanged: (index) {
                                if (filteredHours.isEmpty || index >= filteredHours.length) return;

                                final selectedHour = filteredHours[index];
                                
                                // 새로운 시간에 맞는 분 목록 계산 (간단하게)
                                List<int> newValidMinutes = List.from(filteredMinutes);
                                if (isToday && selectedHour == now.hour) {
                                  // 오늘이고 현재 시간과 같으면 현재 분 이후만 허용
                                  newValidMinutes = filteredMinutes.where((minute) => minute > now.minute).toList();
                                  if (newValidMinutes.isEmpty) {
                                    newValidMinutes = List.from(filteredMinutes);
                                  }
                                }
                                
                                int adjustedMinute = newValidMinutes.isNotEmpty ? newValidMinutes.first : 0;
                                if (_selectedTime != null && newValidMinutes.contains(_selectedTime!.minute)) {
                                  adjustedMinute = _selectedTime!.minute;
                                }
                                
                                setState(() {
                                  _selectedTime = TimeOfDay(
                                    hour: selectedHour,
                                    minute: adjustedMinute,
                                  );
                                  
                                  // 분 스크롤 컨트롤러 업데이트
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_minuteScrollController!.hasClients) {
                                      final newIndex = newValidMinutes.indexOf(adjustedMinute);
                                      if (newIndex >= 0) {
                                        _minuteScrollController!.animateToItem(
                                          newIndex,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    }
                                  });
                                });
                                _loadAvailableTSs();
                                if (_selectedTS != null) {
                                  _calculateFee();
                                }
                              },
                              children: filteredHours.map((hour) {
                                return Center(
                                  child: Text(
                                    hour.toString().padLeft(2, '0'),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                              scrollController: _hourScrollController,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: const Text('시', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        // 분 선택 피커
                        Expanded(
                          flex: 2,
                          child: Container(
                            color: Colors.transparent, // 투명 배경으로 변경
                            child: CupertinoPicker(
                              backgroundColor: Colors.transparent, // 투명 배경으로 변경
                              itemExtent: 40,
                              diameterRatio: 1.2, 
                              magnification: 1.1, 
                              squeeze: 1.0, 
                              useMagnifier: true, 
                              looping: false,
                              onSelectedItemChanged: (index) {
                                if (currentValidMinutes.isEmpty || index >= currentValidMinutes.length) return;
                                final selectedHour = _selectedTime?.hour ?? (filteredHours.isNotEmpty ? filteredHours.first : 0);
                                final selectedMinute = currentValidMinutes[index];
                                setState(() {
                                  _selectedTime = TimeOfDay(
                                    hour: selectedHour,
                                    minute: selectedMinute,
                                  );
                                });
                                _loadAvailableTSs();
                                if (_selectedTS != null) {
                                  _calculateFee();
                                }
                              },
                              children: currentValidMinutes.map((minute) {
                                return Center(
                                  child: Text(
                                    minute.toString().padLeft(2, '0'),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                              scrollController: _minuteScrollController,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: const Text('분', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (widget.memberId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그인 후 이용 가능합니다.')),
                );
                return;
              }
              
              // 현재 화면 컨텍스트를 사용합니다 (Navigator.push 등으로 바꾸지 않도록)
              final BuildContext currentContext = context;
              
              final result = await LessonAvailabilityCheck.selectProAndGetNickname(
                currentContext,
                widget.memberId!,
                DateFormat('yyyy-MM-dd').format(_selectedDate),
                widget.branchId,
              );
              
              // 화면이 여전히 활성 상태인지 확인 (화면 이동 방지)
              if (!mounted) return;
              
              print('DEBUG: result 타입은 ${result.runtimeType}, 값: $result');
              
              if (result is Map<String, dynamic> && result.containsKey('hour') && result.containsKey('minute')) {
                // Map 형태로 시간 정보가 전달된 경우
                final int hour = result['hour'];
                final int minute = result['minute'];
                print('🔍 [디버깅] 타석예약 - 레슨 선택 시간: ${hour}시 ${minute}분');
                
                // 업데이트 전 현재 시간 로깅
                print('🔍 [디버깅] 업데이트 전 _selectedTime: ${_selectedTime?.format(context) ?? "null"}');
                
                // 1. 레슨 선택 시간 내부 변수에 저장 (API 호출에 사용하기 위함)
                final TimeOfDay lessonSelectedTime = TimeOfDay(hour: hour, minute: minute);
                
                // 2. 즉시 상태 변수에 설정
                _selectedTime = lessonSelectedTime;
                
                // 3. 상태 변수 업데이트 (UI 갱신)
                setState(() {
                  // _selectedTime은 이미 설정됨
                  
                  // 피커의 스크롤 위치 업데이트를 위한 변수 준비
                  if (_hours.contains(hour)) {
                    final hourIndex = _hours.indexOf(hour);
                    // 시간 피커 스크롤 위치 업데이트
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_hourScrollController!.hasClients) {
                        _hourScrollController!.animateToItem(
                          hourIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    });
                    
                    // 해당 시간에 대한 유효한 분 목록 업데이트
                    List<int> newValidMinutes = List.from(_minutes);
                    
                    // 선택된 분이 유효한 목록에 있는지 확인하고 인덱스 구하기
                    if (newValidMinutes.contains(minute)) {
                      final minuteIndex = newValidMinutes.indexOf(minute);
                      // 분 피커 스크롤 위치 업데이트
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_minuteScrollController!.hasClients) {
                          _minuteScrollController!.animateToItem(
                            minuteIndex,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    }
                  }
                });
                
                // 설정 직후 값 로깅
                print('🔍 [디버깅] 업데이트 직후 _selectedTime: ${_selectedTime?.format(context) ?? "null"}');
                
                // 4. 레슨 선택 시간을 안전하게 다른 API 호출에 사용
                if (mounted) {
                  // 타석 정보 로딩 시작
                  setState(() {
                    _isLoadingTSs = true;
                  });
                  
                  try {
                    // ReservationService를 통해 타석 정보 가져오기 (선택된 레슨 시간 사용)
                    final availableTSs = await ReservationService.getAvailableTSs(
                      _selectedDate,
                      lessonSelectedTime,
                      _selectedDuration,
                      branchId: widget.branchId
                    );
                    
                    // 상태 적용 전에 _selectedTime이 변경되었는지 확인
                    if (_selectedTime!.hour != lessonSelectedTime.hour || _selectedTime!.minute != lessonSelectedTime.minute) {
                      print('⚠️ [경고] 레슨 시간이 변경됨: ${lessonSelectedTime.format(context)} -> ${_selectedTime!.format(context)}');
                      print('🔄 [복구] 레슨 선택 시간으로 복원');
                      _selectedTime = lessonSelectedTime; // 원래 시간으로 복원
                    }
                    
                    if (mounted) {
                      setState(() {
                        _availableTSs = availableTSs;
                        _isLoadingTSs = false;
                        
                        // 타석 선택 초기화
                        _selectedTS = null;
                        _feeInfo = null;
                      });
                    }
                    
                    print('타석 조회 결과: ${availableTSs.length}개 타석 정보 수신');
                  } catch (e) {
                    print('타석 정보 로드 중 오류 발생: $e');
                    
                    if (mounted) {
                      setState(() {
                        _availableTSs = [
                          for (int i = 1; i <= 9; i++) {
                            'number': i,
                            'isAvailable': true,
                            'type': i <= 6 ? '오픈타석' : '단독타석'
                          }
                        ];
                        _isLoadingTSs = false;
                      });
                    }
                  }
                }
                
                print('🔍 [디버깅] 타석예약 - 시간 설정됨: ${_selectedTime!.hour}시 ${_selectedTime!.minute}분');
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('선택한 시간대가 타석 시작 시간에 반영되었습니다.')),
                );
              } else if (result is int) {
                // 기존 방식으로 분 값이 전달된 경우 (이전 버전 호환성 유지)
                final int hour = result ~/ 60;
                final int minute = result % 60;
                print('🔍 [디버깅] 타석예약 - 레슨 선택 시간(변환 전): ${hour}시 ${minute}분 (총 ${result}분)');
                
                // 안전한 레슨 선택 시간 저장
                final TimeOfDay lessonSelectedTime = TimeOfDay(hour: hour, minute: minute);
                _selectedTime = lessonSelectedTime;
                
                setState(() {
                  // 필터링된 시간/분 업데이트 (간단하게)
                  List<int> availableHours = List.from(_hours);
                  
                  // 피커 위치 업데이트
                  if (availableHours.contains(hour)) {
                    final hourIndex = availableHours.indexOf(hour);
                    // 시간 피커 업데이트
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_hourScrollController!.hasClients) {
                        _hourScrollController!.animateToItem(
                          hourIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    });
                    
                    // 분 피커 업데이트
                    List<int> validMinutes = List.from(_minutes);
                    if (validMinutes.contains(minute)) {
                      final minuteIndex = validMinutes.indexOf(minute);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_minuteScrollController!.hasClients) {
                          _minuteScrollController!.animateToItem(
                            minuteIndex,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    }
                  }
                });
                
                // 타석 정보 로딩
                if (mounted) {
                  setState(() {
                    _isLoadingTSs = true;
                  });
                  
                  try {
                    final availableTSs = await ReservationService.getAvailableTSs(
                      _selectedDate,
                      lessonSelectedTime,
                      _selectedDuration, branchId: widget.branchId
                    );
                    
                    if (mounted) {
                      setState(() {
                        _availableTSs = availableTSs;
                        _isLoadingTSs = false;
                        _selectedTS = null;
                        _feeInfo = null;
                      });
                    }
                  } catch (e) {
                    print('타석 정보 로드 오류: $e');
                    
                    if (mounted) {
                      setState(() {
                        _isLoadingTSs = false;
                        _availableTSs = [
                          for (int i = 1; i <= 9; i++) {
                            'number': i,
                            'isAvailable': true,
                            'type': i <= 6 ? '오픈타석' : '단독타석'
                          }
                        ];
                      });
                    }
                  }
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('선택한 시간대가 타석 시작 시간에 반영되었습니다.')),
                );
              } else if (result is String) {
                debugPrint('선택한 프로의 닉네임: $result');
              }
            },
            child: const Text('레슨 가능시간 확인'),
          ),
        ],
      ),
    );
  }
  
  // 연습 시간 선택 위젯
  Widget _buildDurationSelection() {
    // _selectedTime이 null인 경우 처리
    if (_selectedTime == null) {
      // 스낵바를 즉시 표시하고 간단한 메시지 위젯 반환
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('시작 시간을 먼저 선택해주세요')),
          );
        }
      });
      
      // 임시 위젯 반환
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              '시작 시간을 선택해주세요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '이전 단계로 이동하여 시작 시간을 선택해주세요',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // 선택된 시작 시간에 따라 최대 연습 시간 계산
    int calculateMaxDuration() {
      int endTimeInMinutes = _businessEndTime.hour * 60 + _businessEndTime.minute;
      int startTimeInMinutes = _selectedTime!.hour * 60 + _selectedTime!.minute;
      int availableMinutes = endTimeInMinutes - startTimeInMinutes;
      availableMinutes = (availableMinutes ~/ _durationUnit) * _durationUnit;
      return min(availableMinutes, _maxDuration);
    }
    int maxDuration = calculateMaxDuration();

    // 예약 불가 상황: maxDuration이 0 이하이거나 min > max
    if (maxDuration <= 0 || _minDuration > maxDuration) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              '해당 시간에는 예약이 불가합니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '다른 시작 시간을 선택하거나 날짜를 변경해 주세요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // min == max일 때는 고정값만 보여주기
    if (_minDuration == maxDuration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_selectedDuration != _minDuration) {
            setState(() {
              _selectedDuration = _minDuration;
              _durationController.text = _minDuration.toString();
              _updateIntensiveDiscount();
            });
            _loadAvailableTSs();
            if (_selectedTS != null) {
              _calculateFee();
            }
          }
        }
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '시작 시간: \\${_selectedTime!.format(context)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '연습 시간',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_minDuration}분 (고정)',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '종료 시간: \\${_getEndTime().format(context)}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // 위젯이 처음 표시될 때 디폴트 연습 시간을 min(60, 영업종료시간 - 시작시간의 분 값)으로 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 연습 시간이 아직 초기값(30분)이거나 이전에 계산된 최대값보다 크다면 재설정
        // 즉, 이 화면에 방금 들어온 경우에만 초기값 설정
        if (_selectedDuration == 30 || _selectedDuration > maxDuration) {
          // 기본값을 60분과 최대 가능 시간 중 작은 값으로 설정
          final defaultDuration = min(60, maxDuration);
          setState(() {
            _selectedDuration = defaultDuration;
            _durationController.text = _selectedDuration.toString();
          });
        }
      }
    });
    
    String getFormattedDuration(int minutes) {
      if (minutes < 60) {
        return '$minutes분';
      } else {
        int hours = minutes ~/ 60;
        int remainingMinutes = minutes % 60;
        return remainingMinutes > 0 
            ? '$hours시간 $remainingMinutes분' 
            : '$hours시간';
      }
    }

    // 현재 선택된 연습 시간이 최대값을 초과하는 경우 조정
    if (_selectedDuration > maxDuration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDuration = maxDuration;
            _durationController.text = _selectedDuration.toString();
          });
          
          // 사용자에게 알림
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('선택한 시간에 가능한 최대 연습 시간은 ${maxDuration}분입니다')),
          );
        }
      });
    }
    
    // 선택된 시작 시간 + 선택된 연습 시간으로 종료 시간 계산
    TimeOfDay calculateEndTime() {
      final int totalMinutes = _selectedTime!.hour * 60 + _selectedTime!.minute + _selectedDuration;
      final int endHour = totalMinutes ~/ 60;
      final int endMinute = totalMinutes % 60;
      return TimeOfDay(hour: endHour % 24, minute: endMinute);
    }
    
    TimeOfDay endTime = calculateEndTime();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '시작 시간: ${_selectedTime!.format(context)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '연습 시간 선택',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              getFormattedDuration(_selectedDuration),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '종료 시간: ${endTime.format(context)}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 슬라이더 - 5분 단위 선택 가능하도록 수정
                  Row(
                    children: [
                      Text('${_minDuration}분'),
                      Expanded(
                        child: Slider(
                          value: _selectedDuration.toDouble(),
                          min: _minDuration.toDouble(),
                          max: maxDuration.toDouble(),
                          divisions: ((maxDuration - _minDuration) ~/ _durationUnit) > 0
                              ? ((maxDuration - _minDuration) ~/ _durationUnit)
                              : 1, // ts_option 단위로 선택 가능하도록
                          label: getFormattedDuration(_selectedDuration),
                          onChanged: (double value) {
                            // ts_option 단위로 값 조정
                            int roundedValue = (value / _durationUnit).round() * _durationUnit;
                            if (roundedValue < _minDuration) roundedValue = _minDuration;
                            if (roundedValue > maxDuration) roundedValue = maxDuration;
                            setState(() {
                              _selectedDuration = roundedValue;
                              _durationController.text = _selectedDuration.toString();
                              _updateIntensiveDiscount(); // 집중연습할인 자동 갱신
                            });
                            
                            // 연습 시간이 변경되면 타석 정보 갱신
                            _loadAvailableTSs();
                            
                            // 선택된 타석이 있으면 요금 재계산
                            if (_selectedTS != null) {
                              _calculateFee();
                            }
                          },
                        ),
                      ),
                      Text('${maxDuration >= 180 ? "3시간" : getFormattedDuration(maxDuration)}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 직접 입력
                  TextField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: '연습 시간 (분)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixText: '분',
                      hintText: '${_minDuration} ~ $maxDuration 사이의 값을 입력하세요 ($_durationUnit분 단위)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        int? newValue = int.tryParse(value);
                        if (newValue != null) {
                          // ts_option 단위로 범위 제한
                          if (newValue < _minDuration) newValue = _minDuration;
                          if (newValue > maxDuration) newValue = maxDuration;
                          // 단위 맞추기
                          newValue = (newValue / _durationUnit).round() * _durationUnit;
                          setState(() {
                            _selectedDuration = newValue!;
                            _updateIntensiveDiscount(); // 집중연습할인 자동 갱신
                          });
                          
                          // 직접 입력으로 연습 시간이 변경되면 타석 정보 갱신
                          _loadAvailableTSs();
                          
                          // 선택된 타석이 있으면 요금 재계산
                          if (_selectedTS != null) {
                            _calculateFee();
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 타석 선택 위젯
  Widget _buildTSSelection() {
    final tsOption = getTsOption("ts");
    final allowedSlots = (tsOption is Map && tsOption.containsKey("allowedSlots"))
        ? tsOption["allowedSlots"] as Map<String, dynamic>
        : <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '시간: ${_selectedTime?.format(context) ?? "선택 필요"} - ${_getEndTime().format(context)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '연습 시간: $_selectedDuration분',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '타석 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // 타석 정보 로딩 중일 때 로딩 인디케이터 표시
        if (_isLoadingTSs)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('타석 정보를 불러오는 중입니다...'),
                ],
              ),
            ),
          )
        else if (_availableTSs.isEmpty)
          // 타석 정보가 없을 때 메시지 표시
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    '타석 정보를 불러올 수 없습니다.\n다시 시도해주세요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAvailableTSs,
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            ),
          )
        else
          // 타석 그리드 표시
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _availableTSs.length,
            itemBuilder: (context, index) {
              final ts = _availableTSs[index];
              final int tsNumber = ts['number'] as int;
              final bool isAvailable = ts['isAvailable'] as bool;
              final String tsType = ts['type'] as String;
              final bool isSelected = _selectedTS == tsNumber;
              // ts_option의 allowedSlots 적용
              final bool isAllowed = !allowedSlots.containsKey(tsNumber.toString()) || allowedSlots[tsNumber.toString()] == true;
              final bool canSelect = isAllowed && isAvailable;
              return InkWell(
                onTap: canSelect ? () {
                  if (_selectedTS != tsNumber) {
                    HapticFeedback.lightImpact(); // 햅틱 피드백 추가
                    setState(() {
                      _selectedTS = tsNumber;
                      // 타석 선택 시 로그 출력 추가
                      print('✅ 타석 선택됨: $tsNumber번 ($tsType)');
                    });
                    // _calculateFee() 호출 제거
                  }
                } : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.8)
                        : (canSelect ? Colors.white : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tsNumber.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (canSelect ? Colors.black : Colors.grey.shade500),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tsType,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : (canSelect ? Colors.grey.shade700 : Colors.grey.shade500),
                        ),
                      ),
                      if (!canSelect) ...[
                        const SizedBox(height: 6),
                        Text(
                          allowedSlots.containsKey(tsNumber.toString()) && allowedSlots[tsNumber.toString()] == false
                            ? '선택불가(설정)' : '이용 불가',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        // 결제 정보 표시
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '시간대 분류 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 시간대 분류 정보 표시
              if (_selectedTime != null) ...[
                const SizedBox(height: 4),
                ..._buildTimeSlotInfo(),
              ],
              

            ],
          ),
        ),
      ],
    );
  }
  
  // 시간대 분류 정보 위젯 리스트 생성
  List<Widget> _buildTimeSlotInfo() {
    if (_selectedTime == null) return [];
    
    final Map<String, int> timeSlots = _calculateTimeSlots();
    final List<Widget> widgets = [];
    
    // 시간대별 색상 설정
    final Map<String, Color> slotColors = {
      '조조': Colors.amber.shade700,
      '일반': Colors.blue.shade700,
      '피크': Colors.red.shade700,
      '심야': Colors.purple.shade700,
    };
    
    timeSlots.forEach((slot, minutes) {
      if (minutes > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: slotColors[slot] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$slot: $minutes분',
                  style: TextStyle(
                    fontSize: 13,
                    color: slotColors[slot] ?? Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
    
    return widgets;
  }
  
  // 요금 정보 위젯 리스트 생성
  List<Widget> _buildFeeInfo() {
    if (_feeInfo == null) return [];
    
    final List<Widget> widgets = [];
    final numberFormat = NumberFormat('#,###');
    
    // 시간대별 요금 정보
    final List<dynamic> detailsRaw = _feeInfo!['details'] ?? [];
    final List<Map<String, dynamic>> details = detailsRaw
        .whereType<Map<String, dynamic>>()
        .toList();
    
    // 세부 요금 정보
    for (var detail in details) {
      final String timeSlot = detail['timeSlot'] as String? ?? '알 수 없음';
      final int minutes = detail['minutes'] as int? ?? 0;
      final int pricePerMinute = detail['pricePerMinute'] as int? ?? 0;
      final int amount = detail['amount'] as int? ?? 0;
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$timeSlot (${minutes}분)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '${numberFormat.format(pricePerMinute)}원/분',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                '${numberFormat.format(amount)}원',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 구분선
    widgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Divider(color: Colors.grey.shade300, height: 1),
      ),
    );
    
    // 총 금액
    final int totalAmount = _feeInfo!['totalAmount'] as int? ?? 0;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '총 금액',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${numberFormat.format(totalAmount)}원',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
    
    // 등록회원 할인 표시 (선택된 경우에만)
    int memberDiscountAmount = 0;
    if (_selectedDiscounts.contains('member')) {
      // 서비스에서 내려주는 값이 있으면 사용, 없으면 25%로 계산
      if (_feeInfo!.containsKey('memberDiscount')) {
        memberDiscountAmount = _feeInfo!['memberDiscount'] as int? ?? 0;
      } else {
        memberDiscountAmount = (totalAmount * (DiscountRates.memberDiscount / 100)).round();
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                '등록회원 할인 (${DiscountRates.memberDiscount}%): ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '-${NumberFormat('#,###').format(memberDiscountAmount)}원',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
      );
    }
    // 기간권 할인 표시 (선택된 경우에만)
    if (_selectedDiscounts.contains('membership')) {
      int membershipDiscountTarget = _feeInfo!['membershipDiscountTarget'] as int? ?? 0;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                '기간권 할인 (적용대상): ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '-${NumberFormat('#,###').format(membershipDiscountTarget)}원',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
      );
    }
    // 집중연습 할인(오버타임 할인) 표시
    int overtimeDiscount = _feeInfo!['overtimeDiscount'] as int? ?? 0;
    if (_selectedDiscounts.contains('intensive') && overtimeDiscount > 0) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                '집중연습 할인 (90분: 1,000c | 120분: 2,000c): ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '-${NumberFormat('#,###').format(overtimeDiscount)}원',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
      );
    }
    // 재방문 할인(직전 1주일 이용횟수 기준) 표시
    int revisitDiscount = _feeInfo!['revisitDiscount'] as int? ?? 0;
    if (_selectedDiscounts.contains('revisit') && revisitDiscount > 0) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                '재방문 할인 (직전 1주일간 환산 이용횟수 기준): ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '-${NumberFormat('#,###').format(revisitDiscount)}원',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
      );
    }
    
    return widgets;
  }
  
  // 시간대 분류 계산 함수
  Map<String, int> _calculateTimeSlots() {
    if (_selectedTime == null) {
      return {'조조': 0, '일반': 0, '피크': 0, '심야': 0};
    }
    
    // 시작 시간과 종료 시간 계산
    final startTime = _selectedTime!;
    final endTime = _getEndTime();
    
    // 시간대별 분류 결과
    final Map<String, int> result = {
      '조조': 0,
      '일반': 0,
      '피크': 0,
      '심야': 0,
    };
    
    // 시작 및 종료 시간을 분으로 변환
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    
    // 종료 시간이 다음 날로 넘어가는 경우 처리
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // 24시간 추가
    }
    
    // 영업 시간 내 총 이용 시간 (분)
    int totalMinutes = endMinutes - startMinutes;
    
    // 공휴일 여부 판단 (토요일, 일요일도 공휴일로 처리)
    bool isWeekendOrHoliday = _isHoliday || 
                           _selectedDate.weekday == DateTime.saturday || 
                           _selectedDate.weekday == DateTime.sunday;
    
    // 해당 요일에 맞는 시간대 정의 사용
    final Map<String, List<List<int>>> timeSlots = isWeekendOrHoliday 
                                             ? _holidayTimeSlots 
                                             : _weekdayTimeSlots;
    
    // 각 시간대별 사용 시간 계산
    int coveredMinutes = 0; // 특별 시간대로 분류된 시간의 총합

    // 시간대별 사용 시간 계산 (조조, 피크, 심야)
    timeSlots.forEach((slot, ranges) {
      for (final range in ranges) {
        final rangeStart = range[0];
        final rangeEnd = range[1];
        
        // 겹치는 시간 계산
        if (startMinutes < rangeEnd && endMinutes > rangeStart) {
          final overlapStart = startMinutes > rangeStart ? startMinutes : rangeStart;
          final overlapEnd = endMinutes < rangeEnd ? endMinutes : rangeEnd;
          
          if (overlapEnd > overlapStart) {
            final slotMinutes = overlapEnd - overlapStart;
            result[slot] = (result[slot] ?? 0) + slotMinutes;
            coveredMinutes += slotMinutes;
          }
        }
      }
    });
    
    // 남은 시간은 모두 일반 시간대로 처리
    result['일반'] = totalMinutes - coveredMinutes;
    
    return result;
  }
  
  // 결제 방법 선택 위젯
  Widget _buildPaymentSelection() {
    final paymentOption = getTsOption("payment");
    final paymentMethodsOption = (paymentOption is Map && paymentOption.containsKey("methods"))
        ? paymentOption["methods"] as Map<String, dynamic>
        : <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선택한 예약 정보 요약
        Card(
          margin: EdgeInsets.zero,
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
                const Text(
                  '예약 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('날짜', DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate)),
                _buildInfoRow('시간', '${_selectedTime?.format(context) ?? "선택 필요"} - ${_getEndTime().format(context)}'),
                _buildInfoRow('연습 시간', '$_selectedDuration분'),
                _buildInfoRow('타석', '$_selectedTS번 (${_availableTSs.firstWhere((ts) => ts['number'] == _selectedTS, orElse: () => {'type': '알 수 없음'})['type']})'),
                const Divider(height: 24),
                // 금액 정보 위젯
                _buildPriceInfoWidget(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '결제 방법 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // 결제 방법 선택 리스트
        ...List.generate(_paymentMethods.length, (index) {
          final method = _paymentMethods[index];
          final String id = method['id'] as String;
          final String name = method['name'] as String;
          final IconData icon = method['icon'] as IconData;
          final bool isSelected = _selectedPaymentMethod == id;
          final bool isAllowed = paymentMethodsOption[id] == true;
          if (!isAllowed) return const SizedBox.shrink(); // false면 아예 안보이게
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: isAllowed
                  ? () {
                      setState(() {
                        _selectedPaymentMethod = id;
                        // 등록회원 할인은 크레딧 결제에서만 사용 가능
                        if (id == 'credit') {
                          if (!_selectedDiscounts.contains('member')) {
                            _selectedDiscounts.add('member');
                            print('🏷️ 등록회원 할인 자동 선택됨: 30%');
                          }
                        } else {
                          if (_selectedDiscounts.contains('member')) {
                            _selectedDiscounts.remove('member');
                            print('🏷️ 등록회원 할인 자동 해제됨: 크레딧 결제가 아님');
                          }
                        }
                        print('💰 결제 방법 선택됨: $name');
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      icon,
                      size: 24,
                      color: isAllowed
                          ? (isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isAllowed
                            ? (isSelected ? Theme.of(context).primaryColor : Colors.black87)
                            : Colors.grey.shade400,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected && isAllowed)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    if (!isAllowed)
                      Icon(
                        Icons.block,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
    
        
        const SizedBox(height: 24),
        const Text(
          '할인 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // 할인 옵션 선택 리스트
        ...List.generate(_discounts.length, (index) {
          final discount = _discounts[index];
          final String id = discount['id'] as String;
          final discountOption = getTsOption("discount");
          final discountEnabled = (discountOption is Map && discountOption.containsKey(id)) ? discountOption[id] : null;
          if (discountEnabled != null && discountEnabled == false) return const SizedBox.shrink(); // false면 아예 안보이게
          final String name = discount['name'] as String;
          num amount = discount['amount'] as num;
          final bool percentage = discount['percentage'] as bool;
          bool isActive = discount['isActive'] as bool;
          final bool isSelected = _selectedDiscounts.contains(id);

          // 등록회원 할인은 크레딧 결제에서만 활성화
          if (id == 'member' && _selectedPaymentMethod != 'credit') {
            isActive = false;
          }

          // 할인 금액 계산 (서비스 값 우선, 없으면 fallback)
          int discountAmount = 0;
          if (_feeInfo != null) {
            if (id == 'member') {
              if (_feeInfo!.containsKey('memberDiscount')) {
                discountAmount = _feeInfo!['memberDiscount'] as int? ?? 0;
              } else {
                int totalAmount = _feeInfo!['originalAmount'] != null ? (_feeInfo!['originalAmount'] as int) : (_feeInfo!['totalAmount'] as int);
                discountAmount = (totalAmount * (DiscountRates.memberDiscount / 100)).round();
              }
            } else if (id == 'membership') {
              discountAmount = _feeInfo!['membershipDiscountTarget'] as int? ?? 0;
            } else if (id == 'junior_parent') {
              discountAmount = _feeInfo!['juniorParentDiscount'] as int? ?? 0;
              amount = discountAmount; // UI에 표시되는 amount도 동적으로 반영
            } else if (percentage) {
              int totalAmount = _feeInfo!['originalAmount'] != null ? (_feeInfo!['originalAmount'] as int) : (_feeInfo!['totalAmount'] as int);
              discountAmount = (totalAmount * (amount / 100)).round();
            } else {
              discountAmount = amount.toInt();
            }
          } else {
            if (percentage) {
              discountAmount = 0; // 정보 없으면 0
            } else {
              discountAmount = amount.toInt();
            }
          }

          // 기간권 할인만 infoText와 금액만 한 줄로 표시
          if (id == 'membership') {
            String passType = _termType.isNotEmpty ? _termType : '기간권';
            String expireText = _expiryDate.isNotEmpty ? _formatDate(_expiryDate) : '';
            String mainText = '보유 $passType 사용';
            String expireLine = expireText.isNotEmpty ? '(만료 : $expireText)' : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDiscounts.remove(id);
                    } else {
                      _selectedDiscounts.add(id);
                    }
                  });
                  _recalculateDiscountedFee(); // 할인 선택 시 금액만 재계산 (API 호출 없음)
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green.shade500 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 24,
                        color: isSelected ? Colors.green.shade500 : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mainText,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.green.shade700 : Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  '-${NumberFormat('#,###').format(discountAmount)}원',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (expireLine.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  expireLine,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: isSelected ? Colors.green.shade700 : Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // 모든 일반 할인 항목도 동일한 스타일로 통일
          if (isActive) {
            String subText = '';
            if (id == 'member') {
              subText = '25% 할인';
            } else if (id == 'junior_parent') {
              // 실제 할인 금액을 동적으로 표시
              int dynamicAmount = 0;
              if (_feeInfo != null && _feeInfo!.containsKey('juniorParentDiscount')) {
                dynamicAmount = _feeInfo!['juniorParentDiscount'] as int? ?? 0;
              }
              subText = '${NumberFormat('#,###').format(dynamicAmount)}원 할인';
            } else if (id == 'intensive') {
              subText = '90분: 1,000c | 120분: 2,000c';
            } else if (id == 'revisit') {
              // 환산이용 횟수 동적 표시
              double hours = 0.0;
              if (_feeInfo != null && _feeInfo!.containsKey('revisitHours')) {
                hours = (_feeInfo!['revisitHours'] as num?)?.toDouble() ?? 0.0;
              }
              String hoursText = hours.toStringAsFixed(1);
              subText = '직전 1주간 환산이용 횟수: $hoursText회 (60분=1회 기준)';
            } else if (percentage) {
              subText = '${amount}% 할인';
            } else {
              subText = '${NumberFormat('#,###').format(amount)}원 할인';
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDiscounts.remove(id);
                    } else {
                      _selectedDiscounts.add(id);
                    }
                  });
                  _recalculateDiscountedFee(); // 할인 선택 시 금액만 재계산 (API 호출 없음)
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green.shade500 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 24,
                        color: isSelected ? Colors.green.shade500 : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.green.shade700 : Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  '-${NumberFormat('#,###').format(discountAmount)}원',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                subText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: isSelected ? Colors.green.shade700 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (!isActive) {
            // 등록회원 할인인 경우에는 비활성화 상태로 표시 (다른 할인은 숨김)
            if (id == 'member') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_outline_blank,
                        size: 24,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    percentage ? '$amount% 할인' : '${NumberFormat('#,###').format(amount)}원 할인',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '-${NumberFormat('#,###').format(discountAmount)}원',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            // 기간권 할인인 경우 상태에 따른 메시지 표시
            else if (id == 'membership') {
              // 안내문구 생성
              String passType = _termType.isNotEmpty ? _termType : '기간권';
              String expireText = _expiryDate.isNotEmpty ? _formatDate(_expiryDate) : '';
              String infoText = expireText.isNotEmpty
                  ? '$passType 보유(만료 : $expireText)'
                  : '$passType 보유';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDiscounts.remove(id);
                        print('🏷️ 기간권 할인 해제됨');
                      } else {
                        _selectedDiscounts.add(id);
                        print('🏷️ 기간권 할인 선택됨');
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.green.shade500 : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 24,
                          color: isSelected ? Colors.green.shade500 : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            infoText,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.green.shade700 : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '-${NumberFormat('#,###').format(discountAmount)}원',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink(); // 다른 비활성화된 할인은 표시하지 않음
          }

          // 기간권 할인인 경우 특별 UI (활성화된 경우)
          if (id == 'membership') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDiscounts.remove(id);
                      print('🏷️ 기간권 할인 해제됨');
                    } else {
                      _selectedDiscounts.add(id);
                      print('🏷️ 기간권 할인 선택됨: $amount%');
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green.shade500 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 24,
                            color: isSelected ? Colors.green.shade500 : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.green.shade700 : Colors.black87,
                                  ),
                                ),
                                if (_feeInfo != null)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$amount% 할인',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '-${NumberFormat('#,###').format(discountAmount)}원',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    percentage ? '$amount% 할인' : '${NumberFormat('#,###').format(amount)}원 할인',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 두 개의 중복된 컨테이너를 하나로 합치고 만료일자 포함된 버전만 유지
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _expiryDate.isNotEmpty 
                            ? '유효한 기간권이 확인되었습니다. (만료일자: ${_formatDate(_expiryDate)})'
                            : '유효한 기간권이 확인되었습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDiscounts.remove(id);
                    // 할인 해제 로그 출력
                    print('🏷️ 할인 해제됨: $name');
                  } else {
                    _selectedDiscounts.add(id);
                    // 할인 선택 로그 출력
                    print('🏷️ 할인 선택됨: $name ${percentage ? "$amount%" : "${NumberFormat('#,###').format(amount)}원"}');
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.green.shade500 : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 24,
                      color: isSelected ? Colors.green.shade500 : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.green.shade700 : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  percentage ? '$amount% 할인' : '${NumberFormat('#,###').format(amount)}원 할인',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Text(
                                '-${NumberFormat('#,###').format(discountAmount)}원',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
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
  
  // 예약 정보 행 위젯 (결제 화면에서 사용)
  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isHighlighted ? 16 : 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? (isHighlighted ? Theme.of(context).primaryColor : Colors.black87),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // 금액 정보 위젯 (결제 화면에서 사용)
  Widget _buildPriceInfoWidget() {
    // 요금 정보가 있는 경우
    if (_feeInfo != null) {
      int originalAmount = _feeInfo!['originalAmount'] != null 
          ? _feeInfo!['originalAmount'] as int 
          : _feeInfo!['totalAmount'] as int;
      int memberDiscountAmount = _selectedDiscounts.contains('member') 
          ? (originalAmount * (DiscountRates.memberDiscount / 100)).round() 
          : 0;
      int membershipDiscountAmount = _selectedDiscounts.contains('membership')
          ? (_feeInfo!['membershipDiscountTarget'] as int? ?? 0)
          : 0;
      // 주니어 학부모 할인
      int juniorParentDiscount = _selectedDiscounts.contains('junior_parent')
          ? (_feeInfo!['juniorParentDiscount'] as int? ?? 0)
          : 0;
      // 집중연습 할인(오버타임 할인)
      int intensiveDiscountAmount = _selectedDiscounts.contains('intensive')
          ? (_feeInfo!['overtimeDiscount'] as int? ?? 0)
          : 0;
      int revisitDiscount = _selectedDiscounts.contains('revisit')
          ? (_feeInfo!['revisitDiscount'] as int? ?? 0)
          : 0;

      int totalDiscountAmount = memberDiscountAmount + membershipDiscountAmount + juniorParentDiscount + intensiveDiscountAmount + revisitDiscount;
      int finalAmount = originalAmount - totalDiscountAmount;
      if (finalAmount < 0) finalAmount = 0;

      List<Widget> priceInfoWidgets = [];
      priceInfoWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                '총 금액: ',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${NumberFormat('#,###').format(originalAmount)}원',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        )
      );
      if (_selectedDiscounts.contains('member')) {
        priceInfoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '등록회원 할인 (${DiscountRates.memberDiscount}%): ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${NumberFormat('#,###').format(memberDiscountAmount)}원',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        );
      }
      if (_selectedDiscounts.contains('membership')) {
        priceInfoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '기간권 할인 (적용대상): ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${NumberFormat('#,###').format(membershipDiscountAmount)}원',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        );
      }
      // 주니어 학부모 할인 표시 (선택된 경우에만)
      if (_selectedDiscounts.contains('junior_parent') && juniorParentDiscount > 0) {
        priceInfoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '주니어 학부모 할인: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${NumberFormat('#,###').format(juniorParentDiscount)}원',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        );
      }
      // 집중연습 할인(오버타임 할인) 표시
      if (_selectedDiscounts.contains('intensive') && intensiveDiscountAmount > 0) {
        priceInfoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '집중연습 할인 (90분: 1,000c | 120분: 2,000c): ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${NumberFormat('#,###').format(intensiveDiscountAmount)}원',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        );
      }
      // 재방문 할인(직전 1주일 이용횟수 기준) 표시
      if (_selectedDiscounts.contains('revisit') && revisitDiscount > 0) {
        priceInfoWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '재방문 할인 (직전 1주일간 환산 이용횟수 기준): ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${NumberFormat('#,###').format(revisitDiscount)}원',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        );
      }
      priceInfoWidgets.add(const Divider(height: 16));
      priceInfoWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(
                '결제 금액: ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${NumberFormat('#,###').format(finalAmount)}원',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        )
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: priceInfoWidgets,
      );
    } 
    // 타석은 선택되었으나 요금 정보 계산 중인 경우
    else if (_selectedTS != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16, 
              height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2)
            ),
            const SizedBox(width: 8),
            const Text('금액 정보를 계산 중입니다...'),
          ],
        ),
      );
    }
    // 타석도 선택되지 않은 경우
    else {
      return const SizedBox.shrink(); // 빈 위젯 반환
    }
  }
  
  // 예약 완료 처리
  Future<void> _finishReservation() async {
    // 이미 처리 중이면 중복 실행 방지
    if (_isProcessingPayment) {
      print('🔍 [디버깅] 이미 결제 처리 중입니다. 중복 실행 방지됨');
      return;
    }

    // 햅틱 피드백 추가
    HapticFeedback.mediumImpact();

    // 처리 시작 - 로딩 상태 활성화
    setState(() {
      _isProcessingPayment = true;
    });

    print('🔍 [디버깅] ===== 결제하기 버튼 클릭됨 =====');
    print('🔍 [디버깅] 현재 단계: $_currentStep');
    print('🔍 [디버깅] member_id: ${widget.memberId}');

    try {
      // _selectedTime이 null인지 다시 확인
      if (_selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시작 시간이 설정되어 있지 않습니다')),
        );
        setState(() {
          _currentStep = 1; // 시간 선택 단계로 되돌아가기
        });
        return;
      }
      // _selectedTS가 null인지 확인
      if (_selectedTS == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('타석을 선택해주세요')),
        );
        setState(() {
          _currentStep = 3; // 타석 선택 단계로 되돌아가기
        });
        return;
      }

      // 1. 회원 정보 조회
      String memberName = '';
      String memberPhone = '';
      try {
        final response = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'FlutterApp/1.0'
          },
          body: jsonEncode({
            'operation': 'get',
            'table': 'v3_members',
            'fields': ['member_name', 'member_phone'],
            'where': [
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId.toString()
              },
              if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                  Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
                {
                  'field': 'branch_id',
                  'operator': '=',
                  'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
                }
            ]
          }),
        );
        
        if (response.statusCode == 200) {
          final resp = jsonDecode(response.body);
          if (resp['success'] == true && resp['data'] != null && resp['data'].isNotEmpty) {
            memberName = resp['data'][0]['member_name'] ?? '';
            memberPhone = resp['data'][0]['member_phone'] ?? '';
          }
        }
      } catch (e) {
        // 조회 실패 시 빈값 유지
        print('회원 정보 조회 실패: $e');
      }

      // 종료 시간 계산
      final endTime = _getEndTime();
      final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final String startTimeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      final String endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
      
      // 할인 및 금액 계산 함수
      int _calcMemberDiscount() {
        if (_selectedDiscounts.contains('member')) {
          if (_feeInfo != null && _feeInfo!.containsKey('memberDiscount')) {
            return _feeInfo!['memberDiscount'] as int? ?? 0;
          } else {
            int totalAmount = _feeInfo?['totalAmount'] ?? 0;
            return (totalAmount * (DiscountRates.memberDiscount / 100)).round();
          }
        }
        return 0;
      }
      
      int _calcTotalDiscount() {
        int sum = 0;
        sum += _calcMemberDiscount();
        sum += _feeInfo?['membershipDiscountTarget'] as int? ?? 0;
        sum += _selectedDiscounts.contains('junior_parent') ? (_feeInfo?['juniorParentDiscount'] as int? ?? 0) : 0;
        sum += _selectedDiscounts.contains('intensive') ? (_feeInfo?['overtimeDiscount'] as int? ?? 0) : 0;
        sum += _selectedDiscounts.contains('overtime') ? (_feeInfo?['overtimeDiscount'] as int? ?? 0) : 0;
        sum += _selectedDiscounts.contains('revisit') ? (_feeInfo?['revisitDiscount'] as int? ?? 0) : 0;
        sum += _selectedDiscounts.contains('emergency') ? (_feeInfo?['emergencyDiscount'] as int? ?? 0) : 0;
        return sum;
      }
      int _calcNetAmount() {
        int total = _feeInfo?['totalAmount'] ?? 0;
        int discount = _calcTotalDiscount();
        return (total - discount) < 0 ? 0 : (total - discount);
      }
      Map<String, int> timeSlots = _calculateTimeSlots();
      // 예약 데이터 생성
      final reservationId = "${DateFormat('yyMMdd').format(_selectedDate)}_${_selectedTS}_${_selectedTime!.hour.toString().padLeft(2, '0')}${_selectedTime!.minute.toString().padLeft(2, '0')}";
      
      // 디버깅을 위한 로그
      print('🔍 [디버깅] 예약 ID: $reservationId');
      print('🔍 [디버깅] ts_id: ${_selectedTS.toString()}');
      
      final reservationData = {
        "reservation_id": reservationId,
        "ts_id": _selectedTS.toString(),
        "ts_date": formattedDate,
        "ts_start": startTimeStr,
        "ts_end": endTimeStr,
        "ts_min": _selectedDuration,
        "ts_type": "일반",
        "ts_payment_method": _selectedPaymentMethod ?? "credit",
        "ts_status": "결제완료",
        "member_id": widget.memberId,
        "member_name": memberName,
        "member_phone": memberPhone,
        "total_amt": _feeInfo?['totalAmount'] ?? 0,
        "term_discount": _selectedDiscounts.contains('term') ? (_feeInfo?['termDiscount'] ?? 0) : 0,
        "member_discount": _selectedDiscounts.contains('member') ? (_calcMemberDiscount()) : 0,
        "junior_discount": _selectedDiscounts.contains('junior_parent') ? (_feeInfo?['juniorParentDiscount'] ?? 0) : 0,
        "overtime_discount": _selectedDiscounts.contains('intensive') ? (_feeInfo?['overtimeDiscount'] ?? 0) : 0,
        "revisit_discount": _selectedDiscounts.contains('revisit') ? (_feeInfo?['revisitDiscount'] ?? 0) : 0,
        "emergency_discount": _selectedDiscounts.contains('emergency') ? (_feeInfo?['emergencyDiscount'] ?? 0) : 0,
        "emergency_reason": _selectedDiscounts.contains('emergency') ? "" : "",
        "total_discount": _calcTotalDiscount(),
        "net_amt": _calcNetAmount(),
        "morning": timeSlots['조조'] ?? 0,
        "normal": timeSlots['일반'] ?? 0,
        "peak": timeSlots['피크'] ?? 0,
        "night": timeSlots['심야'] ?? 0,
        "time_stamp": DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        "branch_id": Provider.of<UserProvider>(context, listen: false).currentBranchId,
      };
      
      // 디버그 로그 추가: 전체 예약 데이터
      print('🔍 [디버깅] 예약 데이터: ${jsonEncode(reservationData)}');
      
      // API 호출 - v2_priced_TS 테이블에 예약 정보 저장
      try {
        final response = await http.post(
          Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'FlutterApp/1.0'
          },
          body: jsonEncode({
            'operation': 'add',
            'table': 'v2_priced_TS',
            'data': reservationData
          }),
        );
        
        // 응답 본문 로깅
        print('🔍 [디버깅] API 응답 상태 코드: ${response.statusCode}');
        print('🔍 [디버깅] API 응답 본문: ${response.body}');
        
        if (response.statusCode == 200) {
          final resp = jsonDecode(response.body);
          if (resp['success'] == true) {
            // v2_priced_TS 저장 성공 후 v2_bills 테이블 업데이트
            await _updateBillsTable(reservationId, memberName, formattedDate, startTimeStr, endTimeStr, reservationData);
            
            // 예약 성공 메시지
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('타석 예약이 완료되었습니다')),
            );
            
            // 예약 정보를 담은 맵 생성
            final tsReservationInfo = {
              'date': _selectedDate,
              'startTime': _selectedTime!,
              'endTime': endTime,
              'duration': _selectedDuration,
              'tsNumber': _selectedTS,
              'tsType': _availableTSs.firstWhere((ts) => ts['number'] == _selectedTS, orElse: () => {'type': '오픈타석'})['type'],
              'formattedDate': formattedDate,
              'formattedStartTime': startTimeStr,
              'formattedEndTime': endTimeStr,
            };
            
            // 레슨 예약 여부를 묻는 다이얼로그 표시
            _showLessonReservationPrompt(tsReservationInfo);
          } else {
            print('❌ 예약 저장 실패: ${resp['error'] ?? '알 수 없는 오류'}');
            if (resp.containsKey('debug_info')) {
              print('❌ 디버그 정보: ${resp['debug_info']}');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('예약 저장 실패: ${resp['error'] ?? '알 수 없는 오류'}')),
            );
          }
        } else {
          print('❌ 서버 오류 ${response.statusCode}: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('서버 오류: ${response.statusCode}')),
          );
        }
      } catch (e) {
        print('❌ 예약 저장 중 오류: $e');
        print('❌ 스택 트레이스: ${StackTrace.current}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예약 저장 중 오류: $e')),
        );
      } finally {
        // 처리 완료 - 로딩 상태 해제
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
        }
        print('🔍 [디버깅] 결제 처리 완료 - 로딩 상태 해제됨');
      }
    } catch (e) {
      print('❌ 예약 저장 중 오류: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('예약 저장 중 오류: $e')),
      );
    }
  }

  // v2_bills 테이블 업데이트 함수
  Future<void> _updateBillsTable(String reservationId, String memberName, String formattedDate, String startTimeStr, String endTimeStr, Map<String, dynamic> reservationData) async {
    try {
      // 1. 현재 잔액 조회 (가장 큰 bill_id의 bill_balance_after)
      int currentBalance = 0;
      
      final balanceResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_bills',
          'fields': ['bill_balance_after'],
          'where': [
            {
              'field': 'member_id',
              'operator': '=',
              'value': widget.memberId.toString()
            },
            if (Provider.of<UserProvider>(context, listen: false).currentBranchId != null && 
                Provider.of<UserProvider>(context, listen: false).currentBranchId!.isNotEmpty)
              {
                'field': 'branch_id',
                'operator': '=',
                'value': Provider.of<UserProvider>(context, listen: false).currentBranchId!
              }
          ],
          'orderBy': [
            {
              'field': 'bill_id',
              'direction': 'DESC'
            }
          ],
          'limit': 1
        }),
      );
      
      if (balanceResponse.statusCode == 200) {
        final balanceResp = jsonDecode(balanceResponse.body);
        if (balanceResp['success'] == true && balanceResp['data'] != null && balanceResp['data'].isNotEmpty) {
          currentBalance = balanceResp['data'][0]['bill_balance_after'] ?? 0;
          print('🔍 [디버깅] 현재 잔액: $currentBalance');
        } else {
          print('🔍 [디버깅] 기존 bills 데이터 없음, 잔액 0으로 시작');
        }
      }
      
      // 2. v2_bills 테이블에 새 레코드 추가
      final totalAmt = reservationData['total_amt'] as int;
      final totalDiscount = reservationData['total_discount'] as int;
      final netAmt = reservationData['net_amt'] as int;
      
      // 타석 정보 생성
      final tsInfo = '${_selectedTS}번 타석($startTimeStr ~ $endTimeStr)';
      
      final billData = {
        'member_id': widget.memberId,
        'bill_date': formattedDate,
        'bill_type': '타석이용',
        'bill_text': tsInfo,
        'bill_totalamt': -totalAmt, // 마이너스로 저장
        'bill_deduction': totalDiscount, // 플러스로 저장
        'bill_netamt': -netAmt, // 마이너스로 저장 (크레딧 차감)
        'bill_timestamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        'bill_balance_before': currentBalance,
        'bill_balance_after': currentBalance - netAmt, // 현재 잔액에서 net_amt 차감
        'reservation_id': reservationId,
        'bill_status': '결제완료',
        'contract_history_id': null,
        'locker_bill_id': null,
        'routine_id': null,
        'branch_id': Provider.of<UserProvider>(context, listen: false).currentBranchId,
      };
      
      print('🔍 [디버깅] Bills 데이터: ${jsonEncode(billData)}');
      
      final billResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'add',
          'table': 'v2_bills',
          'data': billData
        }),
      );
      
      if (billResponse.statusCode == 200) {
        final billResp = jsonDecode(billResponse.body);
        if (billResp['success'] == true) {
          print('✅ [디버깅] v2_bills 테이블 업데이트 성공: bill_id=${billResp['insertId']}');
        } else {
          print('❌ [디버깅] v2_bills 테이블 업데이트 실패: ${billResp['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        print('❌ [디버깅] v2_bills API 호출 실패: ${billResponse.statusCode}');
      }
      
    } catch (e) {
      print('❌ [디버깅] v2_bills 테이블 업데이트 중 오류: $e');
      // Bills 업데이트 실패는 로그만 남기고 계속 진행 (예약은 이미 성공했으므로)
    }
  }

  // 레슨 예약 여부를 묻는 다이얼로그
  void _showLessonReservationPrompt(Map<String, dynamic> tsReservationInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('레슨 예약'),
        content: const Text('방금 예약한 타석에 이어서 레슨 예약을 진행하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 타석 예약 화면 종료
            },
            child: const Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 현재 화면 종료 후 레슨 예약 화면으로 이동
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LessonReservationScreen(
                    memberId: widget.memberId,
                    branchId: null, // 현재 사용자의 branchId를 전달하거나 null로 설정
                    tsReservationInfo: tsReservationInfo,
                  ),
                ),
              );
            },
            child: const Text('예'),
          ),
        ],
      ),
    );
  }

  String _getMembershipStatusMessage() {
    // 로그인 상태(memberId) 확인
    if (widget.memberId == null) {
      return '로그인 후 이용 가능합니다 [비로그인 상태]';
    } else if (widget.memberId! <= 0) {  // null이 아님을 보장하기 위해 ! 연산자 사용
      return '로그인 후 이용 가능합니다 [회원 ID: ${widget.memberId}]';
    } else if (_hasMembership) {
      // 유효한 기간권이 있는 경우, 만료일자 포함
      final formattedExpiryDate = _formatDate(_expiryDate);
      final termTypeText = _termType.isNotEmpty ? '$_termType ' : '';
      return '유효한 ${termTypeText}기간권이 확인되었습니다. (만료일자: $formattedExpiryDate)';
    } else if (_holdStartDate.isNotEmpty && _holdEndDate.isNotEmpty) {
      // 홀드 중인 경우, 홀드 기간 포함
      final formattedHoldStart = _formatDate(_holdStartDate);
      final formattedHoldEnd = _formatDate(_holdEndDate);
      final termTypeText = _termType.isNotEmpty ? '$_termType ' : '';
      return '${termTypeText}기간권이 홀드 중입니다. ($formattedHoldStart ~ $formattedHoldEnd)';
    } else {
      // 로그인은 했지만 유효한 기간권이 없는 경우
      return '유효한 기간권이 없습니다 [회원 ID: ${widget.memberId}]';
    }
  }

  // 아래에 _buildMembershipUI 및 날짜 포맷 메서드를 추가합니다
  // 기간권 상태 UI 위젯
  Widget _buildMembershipUI() {
    // 로그인 상태 확인 (비로그인 또는 유효하지 않은 회원 ID)
    if (widget.memberId == null || widget.memberId! <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          widget.memberId == null ? '로그인 후 이용 가능합니다.' : '로그인 후 이용 가능합니다. [회원 ID: ${widget.memberId}]',
          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
        ),
      );
    }
    
    // 기간권 확인 중인 경우
    if (_isCheckingMembership) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('기간권 확인 중...'),
          ],
        ),
      );
    }
    
    // 상태에 따른 색상 설정
    Color textColor;
    if (_hasMembership) {
      textColor = Colors.green[700]!;
    } else if (_holdStartDate.isNotEmpty && _holdEndDate.isNotEmpty) {
      textColor = Colors.orange[700]!;
    } else {
      textColor = Colors.red[700]!;
    }
    
    // 상태 메시지 가져오기 (_getMembershipStatusMessage 활용)
    final message = _getMembershipStatusMessage();
    
    // UI 반환
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        message,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 날짜 형식 변환 헬퍼 메서드
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[0].substring(2)}년${parts[1]}월${parts[2]}일';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  // 2. 비활성화 날짜 불러오기 함수
  Future<void> _fetchDisabledDates() async {
    if (widget.branchId == null) return;
    try {
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_schedule_adjusted_ts',
          'fields': ['ts_date'],
          'where': [
            {'field': 'branch_id', 'operator': '=', 'value': widget.branchId},
            {'field': 'is_holiday', 'operator': '=', 'value': 'close'}
          ]
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        setState(() {
          _disabledDates = {
            for (var row in data['data']) row['ts_date'] as String
          };
        });
      }
    } catch (e) {
      // 네트워크 오류 등은 무시 (fallback: 모두 선택 가능)
      print('비활성화 날짜 조회 오류: $e');
    }
  }

  // 1단계에서 '다음'을 누를 때 호출되는 함수 추가
  Future<void> _updateLastReservationTimeByMinTsMin() async {
    try {
      // 1. v2_ts_info에서 예약가능 타석의 최소 이용시간 구하기
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_ts_info',
          'fields': ['ts_min_minimum'],
          'where': [
            {'field': 'branch_id', 'operator': '=', 'value': widget.branchId!},
            {'field': 'ts_status', 'operator': '=', 'value': '예약가능'}
          ]
        }),
      );
      final data = jsonDecode(response.body);
      int minTsMin = 30; // fallback
      if (data['success'] == true && data['data'] != null && data['data'].isNotEmpty) {
        final mins = data['data']
            .map<int>((row) => int.tryParse(row['ts_min_minimum'].toString()) ?? 0)
            .where((v) => v > 0)
            .toList();
        if (mins.isNotEmpty) {
          minTsMin = mins.reduce((a, b) => a < b ? a : b);
        }
      }
      // 2. 영업 종료 시간 구하기
      final businessEnd = await HolidayService.getBusinessEndTime(_selectedDate, widget.branchId!);
      final lastStartMinutes = businessEnd.hour * 60 + businessEnd.minute - minTsMin;
      final lastStartHour = lastStartMinutes ~/ 60;
      final lastStartMinute = lastStartMinutes % 60;
      setState(() {
        _lastReservationTime = TimeOfDay(hour: lastStartHour, minute: lastStartMinute);
      });
    } catch (e) {
      print('최소 이용시간 기반 마지막 예약 가능 시간 계산 오류: $e');
      // fallback: 23:30
      setState(() {
        _lastReservationTime = TimeOfDay(hour: 23, minute: 30);
      });
    }
  }
}
