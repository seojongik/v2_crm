import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../services/api_service.dart';
import '/services/supabase_adapter.dart';

// ========================================
// 디폴트 값 상수 정의
// ========================================

// 레슨 예약시간 설정 디폴트값
class LessonTimeDefaults {
  static const int minServiceTime = 15;        // 회당 최소 예약시간 (분)
  static const int serviceTimeUnit = 5;       // 추가 예약단위 (분)
}

// 예약조건 설정 디폴트값
class ReservationDefaults {
  static const int minReservationTerm = 30;    // 예약 가능 시간 (분 전까지)
  static const int reservationAheadDays = 14;   // 최대 예약 기간 (일까지)
}

// 주요계약조건 디폴트값
class ContractDefaults {
  static const String contractType = '프리랜서';
  static const String contractStatus = '활성';
  static const String gender = '남';
  static const String severancePay = '무';
  static const List<String> contractTypeOptions = ['고용(4대보험)', '프리랜서', '레슨장소임대'];
}

// 급여조건 디폴트값
class SalaryDefaults {
  static const int baseSalary = 0;           // 기본급
  static const int hourlySalary = 0;         // 기타 수당
  static const int lessonSalary = 0;         // 일반레슨
  static const int lessonSalaryMin = 0;      // 일반레슨 분당
  static const int eventSalary = 0;          // 이벤트레슨
  static const int eventSalaryMin = 0;       // 이벤트레슨 분당
  static const int promoSalary = 0;          // 직원모션레슨
  static const int promoSalaryMin = 0;       // 직원모션레슨 분당
  static const int noshowSalary = 0;         // 노쇼레슨
  static const int noshowSalaryMin = 0;      // 노쇼레슨 분당
}

// 요일별 운영시간 디폴트값
class WeeklyScheduleDefaults {
  static const String defaultStartTime = '09:00';
  static const String defaultEndTime = '18:00';
  static const bool sundayIsClosed = true;   // 일요일 기본 휴무
  static const bool weekdayIsClosed = false; // 평일 기본 운영
}

// ========================================

class Tab2ManagerContract extends StatefulWidget {
  final bool isNewManagerMode;
  final Map<String, dynamic>? managerData;
  final VoidCallback? onSaved;
  final VoidCallback? onCanceled;
  final bool isRenewal; // 재계약 모드 플래그 추가
  
  const Tab2ManagerContract({
    Key? key,
    required this.isNewManagerMode,
    this.managerData,
    this.onSaved,
    this.onCanceled,
    this.isRenewal = false, // 기본값 false
  }) : super(key: key);

  @override
  _Tab2ManagerContractState createState() => _Tab2ManagerContractState();
}

class _Tab2ManagerContractState extends State<Tab2ManagerContract> {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isNewManagerMode = false;
  Map<String, dynamic>? _selectedManagerData;
  
  // 요일별 운영시간 저장
  Map<String, Map<int, Map<String, dynamic>>> _managerWeeklyHours = {};
  
  // 요일 이름 배열
  final List<String> _weekdayNames = ['일', '월', '화', '수', '목', '금', '토'];
  
  // 새 직원 이름 (임시)
  String _newManagerName = '';
  
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _incentiveController = TextEditingController();
  final TextEditingController _hourlyController = TextEditingController();
  final TextEditingController _mealController = TextEditingController();
  final TextEditingController _mealHoursController = TextEditingController();

  // 기본 정보
  DateTime _contractStartDate = DateTime.now();
  DateTime _contractEndDate = DateTime.now().add(Duration(days: 365));
  DateTime _birthDate = DateTime.now().subtract(Duration(days: 365 * 30));
  String _genderValue = '';
  String _phoneValue = '';
  String _accessIdValue = '';
  String _accessPasswordValue = '';
  String _positionValue = '';
  bool _isAccessIdChecked = false; // 접속ID 중복확인 여부
  bool _isCheckingAccessId = false; // 중복확인 진행 중 여부

  // 계약 조건 - 디폴트 상수 사용
  String _contractType = '';
  String _contractStatus = '';
  
  // 급여 정보 - 디폴트 상수 사용
  int _baseSalary = 0;
  int _hourlySalary = 0;
  int _mealAllowance = 0;
  int _mealMinimumHours = 4; // 식대 지급을 위한 최소 근무시간 (기본값 4시간)
  int _incentive = 0;
  String _severancePay = '';

  // 권한 설정 기본값
  Map<String, String> _permissions = {
    'member_page': '허용',
    'member_registration': '허용',
    'ts_management': '허용',
    'lesson_status': '전체',
    'communication': '허용',
    'locker': '허용',
    'staff_schedule': '전체',
    'pro_schedule': '전체', // 매니저는 전체
    'salary_view': '본인',
    'salary_management': '불가',
    'hr_management': '불가',
    'branch_settings': '불가',
    'branch_operation': '불가',
    'client_app': '허용', // 매니저는 기본적으로 허용
  };

  @override
  void initState() {
    super.initState();
    _isNewManagerMode = widget.isNewManagerMode;
    _selectedManagerData = widget.managerData;
    _initializeControllers();
    _initializeData();
  }

  // 컨트롤러 초기값 설정
  void _initializeControllers() {
    _incentiveController.text = _incentive > 0 ? _formatNumber(_incentive) : '';
    _hourlyController.text = _hourlySalary > 0 ? _formatNumber(_hourlySalary) : '';
    _mealController.text = _mealAllowance > 0 ? _formatNumber(_mealAllowance) : '';
    _mealHoursController.text = _mealMinimumHours.toString();
  }

  // 데이터 초기화
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_isNewManagerMode) {
        // 새 직원 모드일 때 초기화
        _initializeNewManagerData();
      } else if (_selectedManagerData != null) {
        // 기존 직원 데이터 로드
        await _loadExistingManagerData();
      }
    } catch (e) {
      print('❌ 데이터 초기화 실패: $e');
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 새 직원 데이터 초기화
  void _initializeNewManagerData() {
    print('🆕 새 직원 데이터 초기화');
    
    // 새 직원 모드에서만 디폴트 값 설정
    _genderValue = ContractDefaults.gender;
    _phoneValue = '';
    _accessIdValue = '';
    _accessPasswordValue = ''; // 최초 등록 시 핸드폰 번호 뒷 4자리로 자동 설정
    _positionValue = '매니저';
    
    // 계약 조건 디폴트 값
    _contractType = ContractDefaults.contractType;
    _contractStatus = ContractDefaults.contractStatus;
    
    // 급여 정보 디폴트 값
    _baseSalary = SalaryDefaults.baseSalary;
    _hourlySalary = SalaryDefaults.hourlySalary;
    _mealAllowance = 0;
    _mealMinimumHours = 4;
    _incentive = 0;
    _severancePay = ContractDefaults.severancePay;
    
    // 새 직원용 주간 스케줄 초기화
    const String newManagerKey = "NEW_MANAGER";
    _managerWeeklyHours[newManagerKey] = {};
    
    // 일요일부터 토요일까지 (0~6)
    for (int i = 0; i < 7; i++) {
      if (i == 0) { // 일요일은 기본 휴무
        _managerWeeklyHours[newManagerKey]![i] = {
          'isClosed': WeeklyScheduleDefaults.sundayIsClosed,
          'startTime': WeeklyScheduleDefaults.defaultStartTime,
          'endTime': WeeklyScheduleDefaults.defaultEndTime,
        };
      } else { // 월~토요일은 기본 운영
        _managerWeeklyHours[newManagerKey]![i] = {
          'isClosed': WeeklyScheduleDefaults.weekdayIsClosed,
          'startTime': WeeklyScheduleDefaults.defaultStartTime,
          'endTime': WeeklyScheduleDefaults.defaultEndTime,
        };
      }
    }
  }

  // 기존 직원 데이터 로드
  Future<void> _loadExistingManagerData() async {
    if (_selectedManagerData == null) return;

    final managerId = _selectedManagerData!['manager_id']?.toString() ?? '';
    _managerNameController.text = _selectedManagerData!['manager_name'] ?? '';

    // 기존 직원의 계약 정보 로드
    _loadManagerContractData();

    // 기존 직원의 스케줄 로드
    await _loadManagerSchedule(managerId);

    // 기존 직원의 권한 설정 로드
    await _loadAccessSettings();
  }

  // 직원 계약 데이터 로드
  void _loadManagerContractData() {
    if (_selectedManagerData == null) return;
    
    print('📋 기존 직원 계약 데이터 로드 시작');
    
    // 기본 정보 - 실제 DB 값만 사용
    _genderValue = _selectedManagerData!['manager_gender']?.toString() ?? '';
    _phoneValue = _selectedManagerData!['manager_phone'] ?? '';
    _accessIdValue = _selectedManagerData!['staff_access_id']?.toString() ?? '';
    _accessPasswordValue = _selectedManagerData!['staff_access_password']?.toString() ?? '';
    _positionValue = _selectedManagerData!['manager_position']?.toString() ?? '';
    
    // 생년월일 파싱
    final birthdayStr = _selectedManagerData!['manager_birthday']?.toString() ?? '';
    if (birthdayStr.isNotEmpty) {
      try {
        _birthDate = DateTime.parse(birthdayStr);
      } catch (e) {
        print('생년월일 파싱 오류: $e');
        _birthDate = DateTime.now().subtract(Duration(days: 365 * 30));
      }
    }
    
    // 계약 조건 - 실제 DB 값만 사용 (디폴트 값 제거)
    _contractType = _selectedManagerData!['contract_type']?.toString() ?? '';
    _contractStatus = _selectedManagerData!['manager_contract_status']?.toString() ?? '';
    
    // 계약 기간 파싱
    final startDateStr = _selectedManagerData!['manager_contract_startdate']?.toString() ?? '';
    final endDateStr = _selectedManagerData!['manager_contract_enddate']?.toString() ?? '';
    
    if (startDateStr.isNotEmpty) {
      try {
        _contractStartDate = DateTime.parse(startDateStr);
      } catch (e) {
        print('계약시작일 파싱 오류: $e');
        _contractStartDate = DateTime.now();
      }
    }
    
    if (endDateStr.isNotEmpty) {
      try {
        _contractEndDate = DateTime.parse(endDateStr);
      } catch (e) {
        print('계약종료일 파싱 오류: $e');
        _contractEndDate = DateTime.now().add(Duration(days: 365));
      }
    }
    
    // 급여 정보 - 실제 DB 값만 사용 (디폴트 값 제거)
    _baseSalary = _selectedManagerData!['salary_base'] != null ? 
        int.tryParse(_selectedManagerData!['salary_base'].toString()) ?? 0 : 0;
    _hourlySalary = _selectedManagerData!['salary_hour'] != null ? 
        int.tryParse(_selectedManagerData!['salary_hour'].toString()) ?? 0 : 0;
    _mealAllowance = _selectedManagerData!['salary_meal'] != null ? 
        int.tryParse(_selectedManagerData!['salary_meal'].toString()) ?? 0 : 0;
    _mealMinimumHours = _selectedManagerData!['salary_meal_minimum_hours'] != null ? 
        int.tryParse(_selectedManagerData!['salary_meal_minimum_hours'].toString()) ?? 4 : 4;
    _incentive = _selectedManagerData!['salary_incentive'] != null ? 
        int.tryParse(_selectedManagerData!['salary_incentive'].toString()) ?? 0 : 0;
    _severancePay = _selectedManagerData!['severance_pay']?.toString() ?? '';
    
    // 컨트롤러들 업데이트 (인센티브 금액 UI 반영)
    _initializeControllers();
    
    print('✅ 기존 직원 계약 데이터 로드 완료');
    print('📊 로드된 데이터: 이름=${_selectedManagerData!['manager_name']}, 성별=$_genderValue, 전화=$_phoneValue');
    print('💰 급여 데이터: 기본급=$_baseSalary, 시간급=$_hourlySalary, 식대=$_mealAllowance(${_mealMinimumHours}시간 이상), 인센티브=$_incentive');
  }

  // 특정 날짜의 운영시간 가져오기
  String _getOperatingHours(DateTime date) {
    // 테이블에 없으면 미설정
    return '미설정';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // 지점 ID 가져오기 헬퍼 함수
  Future<String?> _getBranchId() async {
    try {
      return ApiService.getCurrentBranchId();
    } catch (e) {
      print('지점 ID 가져오기 실패: $e');
      return null;
    }
  }

  // v2_staff_pro 업데이트 데이터 디버깅 출력
  void _debugStaffProData() {
    print('\n=== 📋 v2_staff_pro 테이블 업데이트 데이터 디버깅 ===');
    
    try {
      final branchId = ApiService.getCurrentBranchId();
      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      print('🏢 branch_id: $branchId');
      print('🆔 staff_type: "직원"');
      print('📊 staff_status: "재직"');
      print('🕒 updated_at: $currentTime');
      
      if (_isNewManagerMode) {
        print('\n🆕 === 새 직원 등록 모드 ===');
        print('👤 manager_name: "$_newManagerName"');
        print('🆔 manager_id: [최대값+1로 자동 채번 예정]');
        print('🔢 manager_contract_round: 1');
        print('📝 manager_contract_id: [AUTO_INCREMENT]');
        
        // 기본 정보 섹션
        print('\n📋 === 기본 정보 섹션 ===');
        print('👤 manager_name: "$_newManagerName"');
        print('⚧ manager_gender: "$_genderValue"');
        print('🎂 manager_birthday: "${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}"');
        print('📞 manager_phone: "$_phoneValue"');
        print('🔑 staff_access_id: "$_accessIdValue"');
        print('📜 manager_position: "$_positionValue"');
        
        // 계약 조건 섹션
        print('\n📋 === 계약 조건 섹션 ===');
        print('📅 manager_contract_startdate: "${_contractStartDate.year}-${_contractStartDate.month.toString().padLeft(2, '0')}-${_contractStartDate.day.toString().padLeft(2, '0')}"');
        print('📅 manager_contract_enddate: "${_contractEndDate.year}-${_contractEndDate.month.toString().padLeft(2, '0')}-${_contractEndDate.day.toString().padLeft(2, '0')}"');
        print('📋 contract_type: "$_contractType"');
        print('📊 manager_contract_status: "$_contractStatus"');
        
        // 급여 정보 섹션
        print('\n💰 === 급여 정보 섹션 ===');
        print('💵 salary_base: $_baseSalary');
        print('⏰ salary_hour: $_hourlySalary');
        print('🍽 salary_meal: $_mealAllowance');
        print('⏱ salary_meal_minimum_hours: $_mealMinimumHours');
        print('💰 salary_incentive: $_incentive');
        print('💰 severance_pay: $_severancePay');
        
      } else {
        print('\n✏️ === 기존 직원 수정 모드 ===');
        print('👤 manager_name: "${_selectedManagerData?['manager_name'] ?? ''}"');
        print('🆔 manager_id: ${_selectedManagerData?['manager_id'] ?? ''}');
        print('🔢 manager_contract_round: ${(_selectedManagerData?['manager_contract_round'] ?? 1) + 1}'); // 기존 + 1
        
        // 기존 직원 수정 시에도 동일한 필드들 출력
        print('\n📋 === 수정 가능한 필드들 ===');
        print('📞 manager_phone: "$_phoneValue" (현재: ${_selectedManagerData?['manager_phone'] ?? ''})');
        print('🔑 staff_access_id: "$_accessIdValue" (현재: ${_selectedManagerData?['staff_access_id'] ?? ''})');
        print('📜 manager_position: "$_positionValue" (현재: ${_selectedManagerData?['manager_position'] ?? ''})');
        print('⚧ manager_gender: "$_genderValue" (현재: ${_selectedManagerData?['manager_gender'] ?? ''})');
        print('🎂 manager_birthday: "${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}" (현재: ${_selectedManagerData?['manager_birthday'] ?? ''})');
        
        // 계약 조건
        print('\n📋 === 계약 조건 수정 ===');
        print('📅 manager_contract_startdate: "${_contractStartDate.year}-${_contractStartDate.month.toString().padLeft(2, '0')}-${_contractStartDate.day.toString().padLeft(2, '0')}" (현재: ${_selectedManagerData?['manager_contract_startdate'] ?? ''})');
        print('📅 manager_contract_enddate: "${_contractEndDate.year}-${_contractEndDate.month.toString().padLeft(2, '0')}-${_contractEndDate.day.toString().padLeft(2, '0')}" (현재: ${_selectedManagerData?['manager_contract_enddate'] ?? ''})');
        print('📋 contract_type: "$_contractType" (현재: ${_selectedManagerData?['contract_type'] ?? ''})');
        print('📊 manager_contract_status: "$_contractStatus" (현재: ${_selectedManagerData?['manager_contract_status'] ?? ''})');
        
        // 급여 정보
        print('\n💰 === 급여 정보 수정 ===');
        print('💵 salary_base: $_baseSalary (현재: ${_selectedManagerData?['salary_base'] ?? ''})');
        print('⏰ salary_hour: $_hourlySalary (현재: ${_selectedManagerData?['salary_hour'] ?? ''})');
        print('🍽 salary_meal: $_mealAllowance (현재: ${_selectedManagerData?['salary_meal'] ?? ''})');
        print('⏱ salary_meal_minimum_hours: $_mealMinimumHours (현재: ${_selectedManagerData?['salary_meal_minimum_hours'] ?? ''})');
        print('💰 salary_incentive: $_incentive (현재: ${_selectedManagerData?['salary_incentive'] ?? ''})');
        print('💰 severance_pay: $_severancePay (현재: ${_selectedManagerData?['severance_pay'] ?? ''})');
      }
      
      print('\n🔧 === 다음 단계 ===');
      print('1. 필요한 입력 필드 변수들 추가');
      print('2. UI에서 실제 값 수집');
      print('3. dynamic_api.php로 실제 DB 업데이트');
      print('=== 📋 v2_staff_pro 디버깅 완료 ===\n');
      
    } catch (e) {
      print('❌ v2_staff_pro 디버깅 출력 실패: $e');
    }
  }

  // 레슨 운영시간 저장
  Future<void> _saveLessonHours() async {
    print('🔘 _saveLessonHours 메서드 시작');
    print('🔍 _isNewManagerMode: $_isNewManagerMode');
    print('🔍 _selectedManagerData: $_selectedManagerData');
    print('🔍 _managerWeeklyHours 키들: ${_managerWeeklyHours.keys.toList()}');
    
    if (!_isNewManagerMode && _selectedManagerData == null) {
      print('❌ 기존 직원 모드인데 선택된 직원 데이터가 없음');
      _showErrorSnackBar('직원 정보를 찾을 수 없습니다');
      return;
    }

    // 새 직원 등록 시 필수 입력 필드 검증
    if (_isNewManagerMode) {
      if (_newManagerName.trim().isEmpty) {
        _showErrorSnackBar('직원 이름을 입력해주세요');
        return;
      }
      if (_phoneValue.trim().isEmpty) {
        _showErrorSnackBar('휴대폰 번호를 입력해주세요');
        return;
      }
    }

    // v2_staff_pro 업데이터 데이터 디버깅 출력
    _debugStaffProData();

    // 저장할 데이터가 있는지 확인
    String currentKey = _isNewManagerMode ? "NEW_MANAGER" : (_selectedManagerData?['manager_id']?.toString() ?? '');
    print('🔍 currentKey: $currentKey');
    print('🔍 _managerWeeklyHours.containsKey($currentKey): ${_managerWeeklyHours.containsKey(currentKey)}');
    if (_managerWeeklyHours.containsKey(currentKey)) {
      print('🔍 _managerWeeklyHours[$currentKey]: ${_managerWeeklyHours[currentKey]}');
      print('🔍 _managerWeeklyHours[$currentKey].isEmpty: ${_managerWeeklyHours[currentKey]!.isEmpty}');
    }
    
    if (!_managerWeeklyHours.containsKey(currentKey) || _managerWeeklyHours[currentKey]!.isEmpty) {
      print('❌ 저장할 레슨 운영시간 데이터가 없음');
      _showErrorSnackBar('저장할 레슨 운영시간 데이터가 없습니다');
      return;
    }

    print('✅ 데이터 검증 완료 - 저장 직원세스 시작');

    setState(() {
      _isSaving = true;
    });

    try {
      // 현재 직원 이름 결정
      final managerName = _isNewManagerMode ? _newManagerName : (_selectedManagerData?['manager_name'] ?? '');
      
      print('🏢 레슨 운영시간 저장 - 직원: $managerName');
      
      final branchId = ApiService.getCurrentBranchId();
      print('🔍 현재 branchId: $branchId');
      
      if (branchId == null || branchId.isEmpty) {
        throw Exception('지점 정보를 찾을 수 없습니다. 다시 로그인해주세요.');
      }

      // 새 직원 등록 시 먼저 v2_staff_pro에 등록하고 manager_id를 받아옴
      String managerId;
      String currentKey;
      
      if (_isNewManagerMode) {
        managerId = await _createNewManager(branchId, managerName);
        print('🆕 새 직원 등록 완료 - managerId: $managerId');
        
        // NEW_MANAGER 키를 실제 managerId로 변경
        if (_managerWeeklyHours.containsKey('NEW_MANAGER')) {
          _managerWeeklyHours[managerId] = _managerWeeklyHours['NEW_MANAGER']!;
          _managerWeeklyHours.remove('NEW_MANAGER');
          print('🔄 _managerWeeklyHours 키 변경: NEW_MANAGER -> $managerId');
        }
        currentKey = managerId;
      } else {
        managerId = _selectedManagerData!['manager_id'].toString();
        currentKey = managerId;  // ← manager_id 사용
      }
      
      print('🔍 managerId: $managerId, managerName: $managerName');
      
      // 요일별로 데이터 저장 - 실제 데이터가 있는 요일만 처리
      final proHours = _managerWeeklyHours[currentKey]!;
      
      // 재계약인 경우 v2_staff_pro 테이블에 새 레코드 추가
      if (!_isNewManagerMode) {
        // 재계약 여부 판단: 계약기간이 변경되었거나 계약 회차가 증가하는 경우
        final isRenewal = _isContractRenewal();
        
        if (isRenewal) {
          await _updateExistingManagerContract(branchId, managerId, managerName);
        } else {
          // 단순 수정인 경우 기존 레코드 업데이트
          await _updateExistingManagerInfo(branchId, managerId, managerName);
        }
      }
      
      for (int weekdayIndex in proHours.keys) {
        try {
          final daySchedule = proHours[weekdayIndex]!;
          final dayOfWeek = _weekdayNames[weekdayIndex];
          
          // 휴무 여부에 따른 시간 설정
          String startTime, endTime, isDayOff;
          if (daySchedule['isClosed']) {
            startTime = '00:00:00';
            endTime = '00:00:00';
            isDayOff = '휴무';
          } else {
            startTime = '${daySchedule['startTime']}:00';
            endTime = '${daySchedule['endTime']}:00';
            isDayOff = '출근';
          }
          
          print('🔍 $dayOfWeek - isDayOff: $isDayOff, startTime: $startTime, endTime: $endTime');
          
          // 현재 시간을 더 간단한 형식으로
          final now = DateTime.now();
          final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          
          // 기존 데이터 확인 후 업데이트 또는 추가
          final whereConditions = [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'manager_id', 'operator': '=', 'value': managerId},
            {'field': 'day_of_week', 'operator': '=', 'value': dayOfWeek},
          ];

          final checkResponse = await SupabaseAdapter.getData(
            table: 'v2_weekly_schedule_manager',
            where: whereConditions,
          );

          print('🔍 $dayOfWeek 기존 데이터 확인: ${checkResponse.length}건');

          Map<String, dynamic> result;
          if (checkResponse.isNotEmpty) {
            // 기존 데이터가 있으면 업데이트
            final updateData = {
              'is_day_off': isDayOff,
              'start_time': startTime,
              'end_time': endTime,
              'updated_at': currentTime,
            };

            print('🔍 $dayOfWeek 업데이트 데이터: $updateData');

            result = await SupabaseAdapter.updateData(
              table: 'v2_weekly_schedule_manager',
              data: updateData,
              where: whereConditions,
            );

            if (result['success'] != true) {
              throw Exception('$dayOfWeek 업데이트 실패: ${result['message'] ?? '알 수 없는 오류'}');
            }

            print('✅ $dayOfWeek 업데이트 성공');
          } else {
            // 기존 데이터가 없으면 새로 추가
            final insertData = {
              'branch_id': branchId,
              'manager_id': managerId,
              'manager_name': managerName,
              'day_of_week': dayOfWeek,
              'is_day_off': isDayOff,
              'start_time': startTime,
              'end_time': endTime,
              'updated_at': currentTime,
            };

            print('🔍 $dayOfWeek 추가 데이터: $insertData');

            result = await SupabaseAdapter.addData(
              table: 'v2_weekly_schedule_manager',
              data: insertData,
            );

            if (result['success'] != true) {
              throw Exception('$dayOfWeek 추가 실패: ${result['message'] ?? '알 수 없는 오류'}');
            }

            print('✅ $dayOfWeek 추가 성공');
          }
        } catch (e) {
          print('❌ ${_weekdayNames[weekdayIndex]} 처리 중 오류: $e');
          throw e; // 에러를 다시 던져서 전체 직원세스 중단
        }
      }
      
      _showSuccessSnackBar('$managerName 레슨 운영시간이 저장되었습니다');
      print('✅ 레슨 운영시간 저장 완료 - 총 ${proHours.length}개 요일 처리됨');
      
      // v2_schedule_adjusted_pro 테이블에 월별 스케줄 저장
      await _saveMonthlySchedule(branchId, managerId, managerName);
      
      // 저장 성공 후 콜백 호출
      if (widget.onSaved != null) {
        widget.onSaved!();
      }
      
    } catch (e) {
      print('❌ 레슨 운영시간 저장 실패: $e');
      _showErrorSnackBar('저장 실패: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // 월별 스케줄을 v2_schedule_adjusted_manager에 저장
  Future<void> _saveMonthlySchedule(String branchId, String managerId, String managerName) async {
    try {
      print('📅 계약기간 스케줄 저장 시작 - ${_contractStartDate.year}-${_contractStartDate.month}-${_contractStartDate.day} ~ ${_contractEndDate.year}-${_contractEndDate.month}-${_contractEndDate.day}');

      // 시작일 결정: 오늘이 계약시작일보다 늦으면 오늘부터, 아니면 계약시작일부터
      final today = DateTime.now();
      final startDate = today.isAfter(_contractStartDate) ? today : _contractStartDate;
      final endDate = _contractEndDate;

      print('📅 실제 처리 기간: ${startDate.year}-${startDate.month}-${startDate.day} ~ ${endDate.year}-${endDate.month}-${endDate.day}');

      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // 통계 변수
      int processedDays = 0;
      int successCount = 0;
      int errorCount = 0;
      List<String> errorDates = [];
      Map<String, int> errorTypes = {};

      // 시작일부터 종료일까지 모든 날짜에 대해 처리
      DateTime currentDate = startDate;

      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        final dateString = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        final weekdayIndex = currentDate.weekday % 7; // 일요일=0, 월요일=1, ..., 토요일=6

        try {
          // 해당 요일의 기본 스케줄 가져오기 - managerId를 사용
          final daySchedule = _managerWeeklyHours[managerId]![weekdayIndex]!;

          // 휴무 여부에 따른 시간 설정
          String workStart, workEnd, isDayOff;
          if (daySchedule['isClosed']) {
            workStart = '00:00:00';
            workEnd = '00:00:00';
            isDayOff = '휴무';
          } else {
            workStart = '${daySchedule['startTime']}:00';
            workEnd = '${daySchedule['endTime']}:00';
            isDayOff = '출근';
          }

          final whereConditions = [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'manager_id', 'operator': '=', 'value': managerId},
            {'field': 'scheduled_date', 'operator': '=', 'value': dateString},
          ];

          // 기존 데이터 확인
          final checkResponse = await SupabaseAdapter.getData(
            table: 'v2_schedule_adjusted_manager',
            where: whereConditions,
          );

          Map<String, dynamic> result;
          if (checkResponse.isNotEmpty) {
            // 기존 데이터가 있으면 업데이트
            final updateData = {
              'work_start': workStart,
              'work_end': workEnd,
              'is_day_off': isDayOff,
              'updated_at': currentTime,
              'is_manually_set': '자동',
            };

            result = await SupabaseAdapter.updateData(
              table: 'v2_schedule_adjusted_manager',
              data: updateData,
              where: whereConditions,
            );

            if (result['success'] == true) {
              successCount++;
            } else {
              errorCount++;
              errorDates.add(dateString);
              final errorType = 'UPDATE_FAILED';
              errorTypes[errorType] = (errorTypes[errorType] ?? 0) + 1;
            }

          } else {
            // 기존 데이터가 없으면 새로 추가
            final insertData = {
              'branch_id': branchId,
              'manager_id': managerId,
              'manager_name': managerName,
              'scheduled_date': dateString,
              'work_start': workStart,
              'work_end': workEnd,
              'is_day_off': isDayOff,
              'updated_at': currentTime,
              'is_manually_set': '자동',
            };

            result = await SupabaseAdapter.addData(
              table: 'v2_schedule_adjusted_manager',
              data: insertData,
            );

            if (result['success'] == true) {
              successCount++;
            } else {
              errorCount++;
              errorDates.add(dateString);
              final errorType = 'INSERT_FAILED';
              errorTypes[errorType] = (errorTypes[errorType] ?? 0) + 1;
            }
          }

        } catch (e) {
          errorCount++;
          errorDates.add(dateString);
          final errorType = 'EXCEPTION';
          errorTypes[errorType] = (errorTypes[errorType] ?? 0) + 1;
        }

        // 다음 날로 이동
        currentDate = currentDate.add(Duration(days: 1));
        processedDays++;
      }

      // 요약 출력
      print('📊 계약기간 스케줄 저장 완료');
      print('   - 처리된 날짜: ${processedDays}일');
      print('   - 성공: ${successCount}개');
      print('   - 오류: ${errorCount}개');

      if (errorCount > 0) {
        print('   - 오류 유형별 통계:');
        errorTypes.forEach((type, count) {
          print('     * $type: ${count}개');
        });
        print('   - 오류 발생 날짜: ${errorDates.take(5).join(', ')}${errorDates.length > 5 ? ' 외 ${errorDates.length - 5}개' : ''}');
      }

    } catch (e) {
      print('❌ 계약기간 스케줄 저장 실패: $e');
      // 스케줄 저장 실패해도 전체 직원세스는 성공으로 처리
    }
  }

  // 직원별 레슨 운영시간 로드
  // 접속ID 중복 확인
  Future<void> _checkAccessIdDuplicate() async {
    if (_accessIdValue.isEmpty) {
      _showErrorSnackBar('접속ID를 입력해주세요');
      return;
    }

    setState(() {
      _isCheckingAccessId = true;
    });

    try {
      // v2_staff_manager 테이블에서 중복 확인
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'staff_access_id', 'operator': '=', 'value': _accessIdValue},
      ];
      // 현재 편집 중인 직원은 제외 (수정 모드일 때)
      if (!_isNewManagerMode && _selectedManagerData != null) {
        whereConditions.add({'field': 'manager_id', 'operator': '!=', 'value': _selectedManagerData!['manager_id']});
      }

      final managerResponse = await SupabaseAdapter.getData(
        table: 'v2_staff_manager',
        where: whereConditions,
        limit: 1,
      );

      final proResponse = await SupabaseAdapter.getData(
        table: 'v2_staff_pro',
        where: [
          {'field': 'staff_access_id', 'operator': '=', 'value': _accessIdValue},
        ],
        limit: 1,
      );

      bool isDuplicated = false;
      String duplicatedInfo = '';

      if (managerResponse.isNotEmpty) {
        isDuplicated = true;
        duplicatedInfo = '직원(${managerResponse[0]['manager_name']})';
      }

      if (proResponse.isNotEmpty) {
        isDuplicated = true;
        if (duplicatedInfo.isNotEmpty) {
          duplicatedInfo += ' 및 ';
        }
        duplicatedInfo += '프로(${proResponse[0]['pro_name']})';
      }

      if (isDuplicated) {
        setState(() {
          _isAccessIdChecked = false;
        });
        // 중복 알림 다이얼로그
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Color(0xFFEF4444), size: 24),
                  SizedBox(width: 8),
                  Text('중복 확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text('이미 사용 중인 접속ID입니다.\n[$duplicatedInfo]'),
              actions: [
                TextButton(
                  child: Text('확인'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      } else {
        setState(() {
          _isAccessIdChecked = true;
        });
        // 사용 가능 알림 다이얼로그
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 8),
                  Text('중복 확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text('사용 가능한 접속ID입니다.'),
              actions: [
                TextButton(
                  child: Text('확인'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('❌ 접속ID 중복 확인 실패: $e');
      _showErrorSnackBar('중복 확인 중 오류가 발생했습니다');
    } finally {
      setState(() {
        _isCheckingAccessId = false;
      });
    }
  }

  Future<void> _loadManagerSchedule(String managerId) async {
    await _loadManagerWeeklySchedule(managerId);
  }

  Future<void> _loadManagerWeeklySchedule(String managerId) async {
    try {
      print('📅 전문가 주간 스케줄 로드 시작: $managerId');
      
      final branchId = await _getBranchId();
      if (branchId == null) {
        throw Exception('지점 ID를 가져올 수 없습니다');
      }

      final response = await SupabaseAdapter.getData(
        table: 'v2_weekly_schedule_manager',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'manager_id', 'operator': '=', 'value': managerId},
        ],
      );

      if (response.isNotEmpty) {
        print('✅ 주간 스케줄 데이터 로드 성공');

        // 기존 데이터 초기화
        _managerWeeklyHours[managerId] = {};

        // 요일 매핑: 한글 요일명을 숫자로 변환
        final dayMapping = {
          '일': 0, '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6
        };

        for (var scheduleData in response) {
          final dayOfWeek = scheduleData['day_of_week']?.toString() ?? '';
          final weekdayIndex = dayMapping[dayOfWeek];

          if (weekdayIndex != null) {
            _managerWeeklyHours[managerId]![weekdayIndex] = {
              'isClosed': scheduleData['is_day_off'] == '휴무',
              'startTime': _formatTime(scheduleData['start_time'] ?? '09:00:00'),
              'endTime': _formatTime(scheduleData['end_time'] ?? '18:00:00'),
            };
          }
        }

        print('📊 로드된 주간 스케줄: ${_managerWeeklyHours[managerId]}');
      } else {
        print('⚠️ 주간 스케줄 데이터가 없습니다. 기본값으로 초기화합니다.');
        _initializeDefaultWeeklySchedule(managerId);
      }
    } catch (e) {
      print('❌ 주간 스케줄 로드 실패: $e');
      _initializeDefaultWeeklySchedule(managerId);
    }
  }

  void _initializeDefaultWeeklySchedule(String managerId) {
    _managerWeeklyHours[managerId] = {};
    // 일요일부터 토요일까지 (0~6)
    for (int i = 0; i < 7; i++) {
      if (i == 0) { // 일요일은 기본 휴무
        _managerWeeklyHours[managerId]![i] = {
          'isClosed': WeeklyScheduleDefaults.sundayIsClosed,
          'startTime': WeeklyScheduleDefaults.defaultStartTime,
          'endTime': WeeklyScheduleDefaults.defaultEndTime,
        };
      } else { // 월~토요일은 기본 운영
        _managerWeeklyHours[managerId]![i] = {
          'isClosed': WeeklyScheduleDefaults.weekdayIsClosed,
          'startTime': WeeklyScheduleDefaults.defaultStartTime,
          'endTime': WeeklyScheduleDefaults.defaultEndTime,
        };
      }
    }
  }

  // 권한설정 위젯
  Widget _buildPermissionSettings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 10),
                Text(
                  '권한설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),

          // 권한 목록
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // 1파트: 기본 허용/불가 권한들
                _buildPermissionRowPair(
                  '회원관리', 'member_page', ['허용', '불가'],
                  '회원등록', 'member_registration', ['허용', '불가'],
                ),
                _buildPermissionRowPair(
                  '타석관리', 'ts_management', ['허용', '불가'],
                  '커뮤니케이션', 'communication', ['허용', '불가'],
                ),
                _buildPermissionRowPair(
                  '락커관리', 'locker', ['허용', '불가'],
                  '고객용 앱', 'client_app', ['허용', '불가']
                ),
                SizedBox(height: 6), // 1파트와 2파트 사이 간격
                // 2파트: 본인/전체 옵션을 가진 항목들 (구분선으로 감싸기)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _buildPermissionRowPair(
                          '레슨현황', 'lesson_status', ['본인', '전체'],
                          '급여조회', 'salary_view', ['본인', '전체'],
                        ),
                        _buildPermissionRowPair(
                          '근무시간표', 'staff_schedule', ['본인', '전체'],
                          '레슨시간표', 'pro_schedule', ['본인', '전체'],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6), // 2파트와 3파트 사이 간격
                // 3파트: 관리 관련 허용/불가 권한들
                _buildPermissionRowPair(
                  '급여관리', 'salary_management', ['허용', '불가'],
                  '직원등록', 'hr_management', ['허용', '불가'],
                ),
                _buildPermissionRowPair(
                  '매장설정', 'branch_settings', ['허용', '불가'],
                  '매장운영', 'branch_operation', ['허용', '불가'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 버튼 색상 결정 함수
  Color _getButtonColor(String option) {
    switch (option) {
      case '불가':
        return Color(0xFFEF4444); // 빨간색
      case '전체':
        return Color(0xFF10B981); // 초록색
      default:
        return Color(0xFF3B82F6); // 기본 파란색
    }
  }

  // 2개 권한을 한 줄에 배치
  Widget _buildPermissionRowPair(String title1, String fieldName1, List<String> options1, String title2, String fieldName2, List<String> options2) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // 첫 번째 권한
          Expanded(
            flex: 1,
            child: _buildSinglePermissionItem(title1, fieldName1, options1),
          ),
          SizedBox(width: 20),
          // 두 번째 권한
          Expanded(
            flex: 1,
            child: _buildSinglePermissionItem(title2, fieldName2, options2),
          ),
        ],
      ),
    );
  }

  // 개별 권한 설정 아이템
  Widget _buildSinglePermissionItem(String title, String fieldName, List<String> options) {
    // 중요 메뉴 확인
    bool isImportantMenu = ['salary_view', 'salary_management', 'hr_management', 'branch_settings', 'branch_operation'].contains(fieldName);

    // 메뉴별 아이콘 선택
    IconData? menuIcon;
    Color iconColor = Color(0xFF6B7280);

    switch (fieldName) {
      case 'staff_schedule':
      case 'pro_schedule':
        menuIcon = Icons.access_time;
        iconColor = Color(0xFF10B981);
        break;
      case 'member_page':
      case 'member_registration':
        menuIcon = Icons.person;
        iconColor = Color(0xFF3B82F6);
        break;
      case 'ts_management':
      case 'lesson_status':
        menuIcon = Icons.sports_golf;
        iconColor = Color(0xFF059669);
        break;
      case 'communication':
        menuIcon = Icons.mail;
        iconColor = Color(0xFF8B5CF6);
        break;
      case 'locker':
        menuIcon = Icons.lock;
        iconColor = Color(0xFFEF4444);
        break;
      case 'client_app':
        menuIcon = Icons.phone_android;
        iconColor = Color(0xFF6366F1);
        break;
    }

    return Row(
      children: [
        // 항목명
        Expanded(
          flex: 3,
          child: Row(
            children: [
              if (menuIcon != null) ...[
                Icon(
                  menuIcon,
                  size: 14,
                  color: iconColor,
                ),
                SizedBox(width: 4),
              ],
              if (isImportantMenu) ...[
                Icon(
                  Icons.workspace_premium,
                  size: 14,
                  color: Color(0xFFEAB308),
                ),
                SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 버튼들
        Expanded(
          flex: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: options.map((option) {
              bool isSelected = _permissions[fieldName] == option;
              return Padding(
                padding: EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _permissions[fieldName] = option;
                    });
                    print('$fieldName: $option 선택');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _getButtonColor(option) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? _getButtonColor(option) : Color(0xFFD1D5DB),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 개별 권한 설정 행 (홀수 개일 때 사용)
  Widget _buildPermissionRow(String title, String fieldName, List<String> options) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: _buildSinglePermissionItem(title, fieldName, options),
    );
  }

  // 모드 변경 처리

  // 직원별 운영시간 설정 위젯
  Widget _buildWeeklySettings() {
    String currentKey = _isNewManagerMode ? 'NEW_MANAGER' : (_selectedManagerData?['manager_id']?.toString() ?? '');
    
    if (currentKey.isEmpty || !_managerWeeklyHours.containsKey(currentKey)) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _isNewManagerMode ? '새 직원 정보를 입력해주세요' : '직원 데이터를 로드 중입니다...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    Map<int, Map<String, dynamic>> proHours = _managerWeeklyHours[currentKey]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 10),
                Text(
                  '요일별 기본설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          // 테이블 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  child: Text(
                    '요일',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 70,
                  child: Text(
                    '시작',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  width: 70,
                  child: Text(
                    '종료',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '휴무',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          // 요일별 설정 리스트
          Column(
            children: List.generate(_weekdayNames.length, (index) {
              String weekdayName = _weekdayNames[index];
              int weekdayNumber = index; // 0(일)~6(토)로 통일
              
              // 데이터베이스에서 로드된 데이터가 있는지 확인
              Map<String, dynamic>? dayInfo = proHours[weekdayNumber];
              bool hasData = dayInfo != null;
              
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.white : Color(0xFFFAFAFA),
                  border: Border(
                    bottom: index < _weekdayNames.length - 1 
                      ? BorderSide(color: Color(0xFFE5E7EB), width: 1)
                      : BorderSide.none,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 요일명
                    Container(
                      width: 60,
                      child: Text(
                        weekdayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: index == 5 ? Color(0xFF2563EB) : // 토요일은 파란색
                                 index == 6 ? Color(0xFFEF4444) : // 일요일은 빨간색
                                 Color(0xFF374151), // 평일은 기본색
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // 시작시간 또는 미설정 표시
                    Container(
                      width: 70,
                      height: 34,
                      child: hasData ? TextFormField(
                        key: ValueKey('start_${weekdayNumber}_${dayInfo['isClosed']}'),
                        initialValue: !dayInfo['isClosed'] ? dayInfo['startTime'] : '',
                        enabled: !dayInfo['isClosed'],
                        style: TextStyle(
                          fontSize: 13,
                          color: dayInfo['isClosed'] ? Color(0xFF9CA3AF) : Color(0xFF374151),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '07:00',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          filled: true,
                          fillColor: dayInfo['isClosed'] ? Color(0xFFF3F4F6) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        ),
                        onChanged: (value) {
                          if (_isValidTime(value)) {
                            setState(() {
                              _managerWeeklyHours[currentKey]![weekdayNumber]!['startTime'] = _formatTime(value);
                            });
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                      ) : Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: Center(
                          child: Text(
                            '미설정',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // 종료시간 또는 미설정 표시
                    Container(
                      width: 70,
                      height: 34,
                      child: hasData ? TextFormField(
                        key: ValueKey('end_${weekdayNumber}_${dayInfo['isClosed']}'),
                        initialValue: !dayInfo['isClosed'] ? dayInfo['endTime'] : '',
                        enabled: !dayInfo['isClosed'],
                        style: TextStyle(
                          fontSize: 13,
                          color: dayInfo['isClosed'] ? Color(0xFF9CA3AF) : Color(0xFF374151),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '23:00',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          filled: true,
                          fillColor: dayInfo['isClosed'] ? Color(0xFFF3F4F6) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        ),
                        onChanged: (value) {
                          if (_isValidTime(value)) {
                            setState(() {
                              _managerWeeklyHours[currentKey]![weekdayNumber]!['endTime'] = _formatTime(value);
                            });
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                      ) : Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: Center(
                          child: Text(
                            '미설정',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // 휴무 체크박스
                    Transform.scale(
                      scale: 0.9,
                      child: Checkbox(
                        value: hasData ? dayInfo['isClosed'] : false,
                        onChanged: hasData ? (bool? value) {
                          setState(() {
                            _managerWeeklyHours[currentKey]![weekdayNumber]!['isClosed'] = value ?? false;
                          });
                        } : null,
                        activeColor: Color(0xFFEF4444),
                        checkColor: Colors.white,
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return Color(0xFFEF4444);
                          }
                          return Colors.white;
                        }),
                        side: BorderSide(color: Color(0xFF374151), width: 2),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 계약 기본 설정 위젯 (계약기간 + 계약형태를 한 줄로 배치)
  Widget _buildContractBasicSettings() {
    return Row(
      children: [
        // 계약기간 타일
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
              children: [
                    Icon(Icons.date_range, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 10),
                Text(
                      '계약기간',
                    style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
              children: [
                    Expanded(
                      child: _buildInlineDateField('계약 시작일', _contractStartDate, (date) {
                        setState(() {
                          _contractStartDate = date;
                        });
                      }),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineDateField('계약 종료일', _contractEndDate, (date) {
                        setState(() {
                          _contractEndDate = date;
                        });
                      }),
                    ),
                  ],
          ),
        ],
      ),
          ),
        ),
        SizedBox(width: 16),
        // 주요계약조건 타일
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
                      color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Row(
              children: [
                    Icon(Icons.assignment, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 10),
                Text(
                      '주요계약조건',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineDropdownField('계약형태', ContractDefaults.contractTypeOptions, 
                        selectedValue: _contractType.isNotEmpty ? _contractType : (_isNewManagerMode ? ContractDefaults.contractType : ''), 
                        onChanged: (value) {
                          setState(() {
                            _contractType = value ?? (_isNewManagerMode ? ContractDefaults.contractType : '');
                          });
                        }),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineDropdownField('퇴직금유무', ['유', '무'], 
                        selectedValue: _severancePay.isNotEmpty ? _severancePay : (_isNewManagerMode ? ContractDefaults.severancePay : ''), 
                        onChanged: (value) {
                          setState(() {
                            _severancePay = value ?? (_isNewManagerMode ? ContractDefaults.severancePay : '');
                          });
                        }),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ],
    );
  }

  // 계약조건 입력 위젯 (레슨 보수 설정만)
  Widget _buildContractConditions() {
    // 새 직원 모드이거나 기존 직원가 선택된 경우 표시
    if (!_isNewManagerMode && _selectedManagerData == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF000000).withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '직원를 선택해주세요',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 10),
                Text(
                  '급여조건',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          // 테이블 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
                        border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
            child: Row(
                  children: [
                Container(
                  width: 120,
                        child: Text(
                    '구분',
                          style: TextStyle(
                      fontSize: 13,
                            fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                          ),
                        ),
                      ),
                SizedBox(width: 8),
            Expanded(
                  child: Text(
                    '금액',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 8),
            Expanded(
                  child: Text(
                    '비고',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // 테이블 내용
          Column(
            children: [
              // 고정급 카테고리
              _buildCategoryHeader('고정급'),
              _buildBaseSalaryRow(),
              _buildIncentiveSalaryTableRowWithCallback('  (2) 시간급', _hourlyController, remark: '시간당 급여', onChanged: (value) {
                if (value.isNotEmpty) {
                  try {
                    final cleanValue = value.replaceAll(',', '');
                    final amount = int.parse(cleanValue);
                    setState(() {
                      _hourlySalary = amount;
                    });
                  } catch (e) {
                    // 잘못된 입력 시 기본값 유지
                  }
                } else {
                  setState(() {
                    _hourlySalary = 0;
                  });
                }
              }),
              _buildMealAllowanceRow(),
              
              // 인센티브 카테고리
              _buildCategoryHeader('인센티브'),
              _buildIncentiveSalaryTableRowWithCallback('인센티브', _incentiveController, onChanged: (value) {
                if (value.isNotEmpty) {
                  try {
                    final cleanValue = value.replaceAll(',', '');
                    final amount = int.parse(cleanValue);
                    setState(() {
                      _incentive = amount;
                    });
                  } catch (e) {
                    // 잘못된 입력 시 기본값 유지
                  }
                } else {
                  setState(() {
                    _incentive = 0;
                  });
                }
              }),
              // 빈 칸 추가 (높이 맞춤용)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: SizedBox(height: 60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 인센티브 급여 테이블 행 위젯 (콜백 기능 포함)
  Widget _buildIncentiveSalaryTableRowWithCallback(String category, TextEditingController controller, {bool enabled = true, bool isLast = false, String? remark, Function(String)? onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 구분명
          Container(
            width: 120,
            child: Text(
              category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          SizedBox(width: 8),
          // 금액 입력 필드 + "/ 분 기준"
          Expanded(
            child: Row(
              children: [
                // 금액 입력 필드 (축소)
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 34,
                    child: TextFormField(
                      controller: controller,
                      enabled: enabled,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled ? Color(0xFF374151) : Color(0xFF9CA3AF),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right, // 오른쪽 정렬
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        suffixText: '원',
                        suffixStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ThousandsSeparatorInputFormatter(), // 천 단위 콤마 추가
                      ],
                      onChanged: (value) {
                        setState(() {}); // 분당 단가 실시간 업데이트
                        if (onChanged != null) onChanged(value);
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
          SizedBox(width: 8),
          // 비고
          Expanded(
            child: Text(
              remark ?? '',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 숫자 포맷팅 함수 (천 단위 콤마)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // 기본정보 위젯 (한 줄로 배치)
  Widget _buildBasicInfo() {
    return Container(
      padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF000000).withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            '기본 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInlineInputFieldForName(
                  '직원이름', 
                  _isNewManagerMode ? '' : (_selectedManagerData?['manager_name'] ?? ''), 
                  enabled: _isNewManagerMode,
                  onChanged: _isNewManagerMode ? (value) {
                    setState(() {
                      _newManagerName = value;
                    });
                  } : null,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildInlineDropdownField('성별', ['남', '여'], selectedValue: _genderValue.isEmpty ? '남' : _genderValue, onChanged: (value) {
                  setState(() {
                    _genderValue = value ?? '남';
                  });
                }),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildInlineDateField('생년월일', _birthDate, (date) {
                  setState(() {
                    _birthDate = date;
                  });
                }),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildInlineInputFieldForText('전화번호', _phoneValue, onChanged: (value) {
                  setState(() {
                    _phoneValue = value;
                  });
                }),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 78), // 중복확인 버튼 영역 예약
                      child: _buildInlineInputFieldForText('접속ID', _accessIdValue, onChanged: (value) {
                        setState(() {
                          _accessIdValue = value;
                          _isAccessIdChecked = false;
                        });
                      }),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _isCheckingAccessId ? null : () async {
                            await _checkAccessIdDuplicate();
                          },
                          child: _isCheckingAccessId
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text('중복확인', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isAccessIdChecked ? Color(0xFF10B981) : Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            minimumSize: Size(70, 34),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildInlineDropdownField('직급', ['관리자', '실장', '매니저', '사원', '기타'],
                  selectedValue: _positionValue.isNotEmpty ? _positionValue : (_isNewManagerMode ? '매니저' : ''),
                  onChanged: (value) {
                    setState(() {
                      _positionValue = value ?? (_isNewManagerMode ? '매니저' : '');
                    });
                  }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 직원이름용 인라인 입력 필드 (한글 입력 가능)
  Widget _buildInlineInputFieldForName(String label, String initialValue, {bool enabled = true, String? prefix, String? suffix, Function(String)? onChanged}) {
    // 기존 직원 모드로 전환될 때 컨트롤러 업데이트
    if (!_isNewManagerMode && _managerNameController.text != initialValue) {
      _managerNameController.text = initialValue;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
                          style: TextStyle(
                            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 4),
        Container(
          height: 34,
          child: TextFormField(
            controller: _managerNameController,
            enabled: enabled,
            style: TextStyle(
              fontSize: 14,
              color: enabled ? Color(0xFF2563EB) : Color(0xFF9CA3AF),
                            fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: prefix,
              suffixText: suffix,
              prefixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              suffixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            // 한글 입력 가능하도록 inputFormatters 제거
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 일반 텍스트용 인라인 입력 필드 (한글/영문 모두 가능)
  Widget _buildInlineInputFieldForText(String label, String initialValue, {bool enabled = true, String? prefix, String? suffix, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 4),
        Container(
          height: 34,
          child: TextFormField(
            initialValue: initialValue,
            enabled: enabled,
            style: TextStyle(
              fontSize: 14,
              color: enabled ? Color(0xFF2563EB) : Color(0xFF9CA3AF),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: prefix,
              suffixText: suffix,
              prefixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              suffixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            // 한글/영문 모두 입력 가능하도록 inputFormatters 제거
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 1행 인라인 입력 필드 (prefix, suffix 지원)
  Widget _buildInlineInputField(String label, String initialValue, {bool enabled = true, String? prefix, String? suffix}) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
            ),
            SizedBox(height: 4),
        Container(
          height: 34,
          child: TextFormField(
            initialValue: initialValue,
            enabled: enabled,
                  style: TextStyle(
                    fontSize: 14,
              color: enabled ? Color(0xFF2563EB) : Color(0xFF9CA3AF),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: prefix,
              suffixText: suffix,
              prefixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              suffixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
              filled: true,
              fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ),
      ],
    );
  }

  // 1행 인라인 입력 필드 (콜백 기능 포함)
  Widget _buildInlineInputFieldWithCallback(String label, String initialValue, {bool enabled = true, String? prefix, String? suffix, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
          label,
                    style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
            ),
            SizedBox(height: 4),
        Container(
          height: 34,
          child: TextFormField(
            initialValue: initialValue,
            enabled: enabled,
                  style: TextStyle(
                    fontSize: 14,
              color: enabled ? Color(0xFF2563EB) : Color(0xFF9CA3AF),
                      fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: prefix,
              suffixText: suffix,
              prefixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              suffixStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 1행 인라인 드롭다운 필드
  Widget _buildInlineDropdownField(String label, List<String> options, {String? selectedValue, Function(String?)? onChanged}) {
    // selectedValue가 options에 없으면 null로 설정
    String? safeSelectedValue = selectedValue;
    if (selectedValue != null && !options.contains(selectedValue)) {
      safeSelectedValue = null;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 4),
        Container(
          height: 34,
          child: DropdownButtonFormField<String>(
            value: safeSelectedValue,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
            ),
            dropdownColor: Colors.white,
            icon: Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF6B7280),
            ),
            items: options.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 일반 입력 필드 행 위젯
  Widget _buildInputRow(String label, String initialValue, {String? suffix, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                        Text(
          label,
                          style: TextStyle(
                              fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
        SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          enabled: enabled,
                            style: TextStyle(
                              fontSize: 14,
            color: enabled ? Color(0xFF374151) : Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
                              filled: true,
            fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                              ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
        ),
      ],
    );
  }

  // 드롭다운 행 위젯
  Widget _buildDropdownRow(String label, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
                            style: TextStyle(
                              fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
                            ),
        ),
        SizedBox(height: 6),
        DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              filled: true,
            fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF6B7280),
          ),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            // TODO: 드롭다운 값 변경 처리
          },
        ),
      ],
    );
  }

  // 급여 테이블 행 위젯 (콜백 기능 포함)
  Widget _buildSalaryTableRowWithCallback(String category, String amount, String note, {bool enabled = true, bool isLast = false, Function(String)? onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 구분명
          Container(
            width: 120,
            child: Text(
              category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          SizedBox(width: 8),
          // 금액 입력 필드
          Expanded(
            child: Container(
              height: 34,
              child: TextFormField(
                initialValue: amount == '0' ? '' : amount,
                enabled: enabled,
                style: TextStyle(
                  fontSize: 14,
                  color: enabled ? Color(0xFF374151) : Color(0xFF9CA3AF),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right, // 오른쪽 정렬
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  suffixText: '원',
                  suffixStyle: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: enabled ? Colors.white : Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandsSeparatorInputFormatter(), // 천 단위 콤마 추가
                ],
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(width: 8),
          // 비고
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 섹션 제목 위젯
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
                    style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
      ),
    );
  }

  // 시간 포맷팅 함수
  String _formatTime(String time) {
    if (time.isEmpty) return '00:00';
    
    // 초(seconds) 제거 - HH:MM:SS에서 HH:MM으로 변환
    if (time.contains(':')) {
      final parts = time.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
    }
    
    // HHMM 형식인 경우 HH:MM으로 변환
    if (time.length == 4 && !time.contains(':')) {
      return '${time.substring(0, 2)}:${time.substring(2, 4)}';
    }
    
    return time;
  }

  // 시간 형식 유효성 검사
  bool _isValidTime(String time) {
    if (time.isEmpty) return false;
    
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  // 레슨시간 및 예약 설정 위젯 (한 줄로 배치) - 직원용은 제거
  Widget _buildLessonTimeAndReservationSettings() {
    return SizedBox.shrink(); // 직원 계약에서는 표시하지 않음
  }

  // 카테고리 헤더 위젯
  Widget _buildCategoryHeader(String categoryName) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  // 1행 인라인 날짜 입력 필드 (데이트피커 포함)
  Widget _buildInlineDateField(String label, DateTime initialDate, [Function(DateTime)? onDateChanged]) {
    final controller = TextEditingController(
      text: '${initialDate.year}-${initialDate.month.toString().padLeft(2, '0')}-${initialDate.day.toString().padLeft(2, '0')}'
    );
    
    // 생년월일과 계약일자에 따라 다른 날짜 범위 설정
    DateTime firstDate;
    DateTime lastDate;
    
    if (label == '생년월일') {
      firstDate = DateTime(1950);  // 생년월일: 1950년부터
      lastDate = DateTime.now();   // 현재까지
    } else {
      firstDate = DateTime(2020);  // 계약일자: 2020년부터
      lastDate = DateTime(2030);   // 2030년까지
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 4),
        Container(
          height: 34,
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixIcon: Icon(
                Icons.calendar_today,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: firstDate,
                lastDate: lastDate,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Color(0xFF10B981), // 선택된 날짜 배경색
                        onPrimary: Colors.white, // 선택된 날짜 텍스트 색
                        surface: Colors.white, // 달력 배경색
                        onSurface: Color(0xFF374151), // 기본 텍스트 색
                        onSurfaceVariant: Color(0xFF6B7280), // 비활성 텍스트 색 (연도 선택기 포함)
                      ),
                      textTheme: Theme.of(context).textTheme.copyWith(
                        headlineSmall: TextStyle(
                          color: Color(0xFF374151), // 헤더 텍스트 색
                          fontWeight: FontWeight.bold,
                        ),
                        titleMedium: TextStyle(
                          color: Color(0xFF374151), // 연도/월 텍스트 색
                          fontWeight: FontWeight.w600,
                        ),
                        bodyLarge: TextStyle(
                          color: Color(0xFF374151), // 날짜 텍스트 색
                        ),
                        bodyMedium: TextStyle(
                          color: Color(0xFF6B7280), // 비활성 날짜 텍스트 색
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && onDateChanged != null) {
                onDateChanged(picked);
                controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF10B981),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 팝업 헤더
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isNewManagerMode ? Icons.person_add : Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isNewManagerMode ? '새 직원 등록' : '직원 계약 수정',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isNewManagerMode 
                          ? '새로운 직원의 계약 조건을 설정하세요'
                          : '${_selectedManagerData?['manager_name'] ?? ''}님의 계약 조건을 수정하세요',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                // 닫기 버튼
                IconButton(
                  onPressed: widget.onCanceled,
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          
          // 스크롤 가능한 컨텐츠
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 기본정보
                    _buildBasicInfo(),
                    
                    SizedBox(height: 20),
                    
                    // 레슨시간 및 예약 설정 (한 줄로 배치)
                    _buildLessonTimeAndReservationSettings(),
                    
                    SizedBox(height: 20),
                    
                    // 계약 기본 설정 (한 줄로 배치)
                    _buildContractBasicSettings(),
                    
                    SizedBox(height: 20),
                    
                    // 메인 콘텐츠 (좌중우 분할: 요일별 기본설정 + 급여조건 + 권한설정)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽+중앙 영역 (요일별 기본설정 + 급여조건) - 65%
                        Expanded(
                          flex: 65,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 왼쪽 영역 (요일별 기본설정)
                              Expanded(
                                flex: 4,
                                child: _buildWeeklySettings(),
                              ),
                              SizedBox(width: 20),

                              // 중앙 영역 (급여조건)
                              Expanded(
                                flex: 6,
                                child: _buildContractConditions(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 20),

                        // 오른쪽 영역 (권한설정) - 35%
                        Expanded(
                          flex: 35,
                          child: _buildPermissionSettings(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 하단 버튼들
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF000000).withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 취소 버튼
                TextButton(
                  onPressed: _isSaving ? null : widget.onCanceled,
                  child: Text(
                    '취소',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                
                // 저장 버튼
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () {
                    print('🔘 계약 정보 저장 버튼 클릭됨');
                    _saveLessonHours();
                  },
                  icon: _isSaving 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.save, color: Colors.white, size: 18),
                  label: Text(
                    _isSaving ? '저장 중...' : '저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 기본급 행 위젯 (다른 필드들과 통일)
  Widget _buildBaseSalaryRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 구분명
          Container(
            width: 120,
            child: Text(
              '  (1) 기본급',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          SizedBox(width: 8),
          // 금액 입력 필드
          Expanded(
            child: Row(
              children: [
                // 금액 입력 필드
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 34,
                    child: TextFormField(
                      initialValue: _baseSalary > 0 ? _formatNumber(_baseSalary) : '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        suffixText: '원',
                        suffixStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          String newText = newValue.text.replaceAll(',', '');
                          if (newText.isEmpty) return newValue;
                          
                          try {
                            int value = int.parse(newText);
                            String formatted = _formatNumber(value);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          } catch (e) {
                            return oldValue;
                          }
                        }),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          try {
                            final cleanValue = value.replaceAll(',', '');
                            final amount = int.parse(cleanValue);
                            setState(() {
                              _baseSalary = amount;
                            });
                          } catch (e) {
                            // 잘못된 입력 시 기본값 유지
                          }
                        } else {
                          setState(() {
                            _baseSalary = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // 비고 (빈 공간)
          Expanded(
            child: Text(
              '',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 식대 지급 조건 행 위젯
  Widget _buildMealAllowanceRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 구분명
          Container(
            width: 120,
            child: Text(
              '  (3) 식대',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          SizedBox(width: 8),
          // 금액 + 시간 입력 필드
          Expanded(
            child: Row(
              children: [
                // 금액 입력 필드
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 34,
                    child: TextFormField(
                      controller: _mealController,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        suffixText: '원',
                        suffixStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          String newText = newValue.text.replaceAll(',', '');
                          if (newText.isEmpty) return newValue;
                          
                          try {
                            int value = int.parse(newText);
                            String formatted = _formatNumber(value);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          } catch (e) {
                            return oldValue;
                          }
                        }),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          try {
                            final cleanValue = value.replaceAll(',', '');
                            final amount = int.parse(cleanValue);
                            setState(() {
                              _mealAllowance = amount;
                            });
                          } catch (e) {
                            // 잘못된 입력 시 기본값 유지
                          }
                        } else {
                          setState(() {
                            _mealAllowance = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(width: 4),
                // 최소 근무시간 입력 필드
                Container(
                  width: 50,
                  height: 34,
                  child: TextFormField(
                    controller: _mealHoursController,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '4',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      suffixText: 'h',
                      suffixStyle: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        try {
                          setState(() {
                            _mealMinimumHours = int.parse(value);
                          });
                        } catch (e) {
                          // 잘못된 입력 시 기본값 유지
                        }
                      } else {
                        setState(() {
                          _mealMinimumHours = 4;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // 비고
          Expanded(
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                return Text(
                  '${_mealMinimumHours}시간 이상 근무일 적용',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _incentiveController.dispose();
    _hourlyController.dispose();
    _mealController.dispose();
    _mealHoursController.dispose();
    super.dispose();
  }

  // 새 직원를 v2_staff_pro 테이블에 등록하고 생성된 manager_id 반환
  Future<String> _createNewManager(String branchId, String managerName) async {
    try {
      print('🆕 새 직원 등록 시작: $managerName');
      
      // DB에서 최대 manager_id 조회하여 새 ID 생성
      final newManagerId = await _getNextManagerId(branchId);
      print('🔍 새 manager_id 생성: $newManagerId');
      
      // 현재 시간
      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      // 3. v2_staff_pro 테이블에 새 직원 등록
      final insertData = {
        'branch_id': branchId,
        'manager_id': newManagerId,
        'staff_type': '직원',
        'manager_name': managerName,
        'manager_gender': _genderValue,
        'manager_phone': _phoneValue,
        'staff_access_id': _accessIdValue,
        'staff_access_password': _phoneValue.length >= 4 ? _phoneValue.substring(_phoneValue.length - 4) : _phoneValue, // 핸드폰 번호 뒷 4자리
        'staff_status': '재직',
        'manager_position': _positionValue,
        'manager_birthday': '${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}',
        'manager_contract_startdate': '${_contractStartDate.year}-${_contractStartDate.month.toString().padLeft(2, '0')}-${_contractStartDate.day.toString().padLeft(2, '0')}',
        'manager_contract_enddate': '${_contractEndDate.year}-${_contractEndDate.month.toString().padLeft(2, '0')}-${_contractEndDate.day.toString().padLeft(2, '0')}',
        'contract_type': _contractType,
        'manager_contract_status': _contractStatus,
        'manager_contract_round': 1,
        'salary_base': _baseSalary,
        'salary_hour': _hourlySalary,
        'salary_meal': _mealAllowance,
        'salary_meal_minimum_hours': _mealMinimumHours,
        'salary_incentive': _incentive,
        'severance_pay': _severancePay,
        'created_at': currentTime,
        'updated_at': currentTime,
      };
      
      print('🔍 새 직원 등록 데이터: $insertData');

      final result = await SupabaseAdapter.addData(
        table: 'v2_staff_manager',
        data: insertData,
      );

      print('🔍 새 직원 등록 응답: $result');

      if (result['success'] != true) {
        throw Exception('새 직원 등록 실패: ${result['message'] ?? '알 수 없는 오류'}');
      }
      
      print('✅ 새 직원 등록 성공 - managerId: $newManagerId');

      // v2_staff_access_setting 테이블에 권한 설정 저장
      await _saveAccessSettings(branchId, _accessIdValue, managerName, 'manager');

      return newManagerId.toString();
      
    } catch (e) {
      print('❌ 새 직원 등록 실패: $e');
      throw Exception('새 직원 등록 실패: $e');
    }
  }

  // 기존 직원의 계약 정보를 v2_staff_pro 테이블에서 업데이트
  Future<void> _updateExistingManagerContract(String branchId, String managerId, String managerName) async {
    try {
      print('🔄 기존 직원 새 계약 레코드 추가 시작: $managerName (ID: $managerId)');
      
      // 현재 시간
      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      // DB에서 해당 manager_id의 최대 계약 회차 조회
      print('🔍 [DEBUG] 계약 회차 계산 시작 - branchId: $branchId, managerId: $managerId');
      final maxRound = await _getMaxContractRound(branchId, managerId);
      final newRound = maxRound + 1;
      
      print('🔍 [DEBUG] 계약 회차 계산 결과:');
      print('   - DB 최대 회차: $maxRound (타입: ${maxRound.runtimeType})');
      print('   - 새 계약 회차: $newRound (타입: ${newRound.runtimeType})');
      
      // 새로운 계약 레코드 데이터 (기존 직원 정보 + 새 계약 정보)
      final insertData = {
        'branch_id': branchId,
        'manager_id': int.parse(managerId), // 동일한 manager_id 사용
        'staff_type': '직원',
        'manager_name': managerName,
        'manager_gender': _selectedManagerData?['manager_gender'] ?? '',
        'manager_phone': _selectedManagerData?['manager_phone'] ?? '',
        'staff_access_id': _selectedManagerData?['staff_access_id'] ?? '',
        'staff_access_password': _selectedManagerData?['staff_access_password'] ?? '', // 재계약 시 기존 비밀번호 유지
        'staff_status': '재직',
        'manager_position': _selectedManagerData?['manager_position'] ?? '',
        'manager_birthday': _selectedManagerData?['manager_birthday'] ?? '',
        'manager_contract_startdate': '${_contractStartDate.year}-${_contractStartDate.month.toString().padLeft(2, '0')}-${_contractStartDate.day.toString().padLeft(2, '0')}',
        'manager_contract_enddate': '${_contractEndDate.year}-${_contractEndDate.month.toString().padLeft(2, '0')}-${_contractEndDate.day.toString().padLeft(2, '0')}',
        'contract_type': _contractType,
        'manager_contract_status': _contractStatus,
        'manager_contract_round': newRound, // 새로운 계약 회차
        'salary_base': _baseSalary,
        'salary_hour': _hourlySalary,
        'salary_meal': _mealAllowance,
        'salary_meal_minimum_hours': _mealMinimumHours,
        'salary_incentive': _incentive,
        'severance_pay': _severancePay,
        'created_at': currentTime,
        'updated_at': currentTime,
      };
      
      print('🔍 [DEBUG] insertData의 manager_contract_round 값: ${insertData['manager_contract_round']} (타입: ${insertData['manager_contract_round'].runtimeType})');
      print('🔍 새 계약 레코드 추가 데이터: $insertData');
      
      print('🔍 [DEBUG] 새 계약 레코드 추가 데이터: ${json.encode(insertData)}');

      final result = await SupabaseAdapter.addData(
        table: 'v2_staff_manager',
        data: insertData,
      );

      print('🔍 [DEBUG] 새 계약 레코드 추가 응답: $result');

      if (result['success'] != true) {
        throw Exception('새 계약 레코드 추가 실패: ${result['message'] ?? '알 수 없는 오류'}');
      }
      
      print('✅ 새 계약 레코드 추가 성공 - manager_id: $managerId, 계약 회차: $newRound');

      // v2_staff_access_setting 테이블에 권한 설정 저장
      await _saveAccessSettings(branchId, _accessIdValue, managerName, 'manager');

    } catch (e) {
      print('❌ 새 계약 레코드 추가 실패: $e');
      throw Exception('새 계약 레코드 추가 실패: $e');
    }
  }

  // DB에서 해당 manager_id의 최대 계약 회차 조회
  Future<int> _getMaxContractRound(String branchId, String managerId) async {
    print('🔍 [DEBUG] 계약 회차 계산 시작 - branchId: $branchId, managerId: $managerId');
    
    try {
      print('🔍 [DEBUG] 최대 계약 회차 조회 시작');
      print('   - branchId: $branchId (타입: ${branchId.runtimeType})');
      print('   - managerId: $managerId (타입: ${managerId.runtimeType})');
      
      final whereConditions = [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
        {'field': 'manager_id', 'operator': '=', 'value': int.parse(managerId)},
      ];

      print('🔍 [DEBUG] 최대 계약 회차 조회 조건: $whereConditions');

      final contracts = await SupabaseAdapter.getData(
        table: 'v2_staff_manager',
        where: whereConditions,
      );

      print('🔍 [DEBUG] 계약 회차 조회 결과: ${contracts.length}건');

      if (contracts.isNotEmpty) {
        // 모든 계약 회차를 가져와서 최대값 계산
        int maxRound = 0;

        for (var contract in contracts) {
          if (contract['manager_contract_round'] != null) {
            int round = int.tryParse(contract['manager_contract_round'].toString()) ?? 0;
            if (round > maxRound) {
              maxRound = round;
            }
          }
        }
          
        print('🔍 [DEBUG] 조회된 계약 데이터: ${contracts.length}개');
        print('🔍 [DEBUG] 계산된 최대 회차: $maxRound');
        return maxRound;
      }

      print('⚠️ [DEBUG] 계약 데이터 없음, 기본값 0 반환');
      return 0;
    } catch (e) {
      print('❌ [DEBUG] 예외 발생: $e');
      return 0;
    }
  }

  // 재계약 여부 판단 메서드
  bool _isContractRenewal() {
    if (_selectedManagerData == null) return false;
    
    // 1. 재계약 모드 플래그가 true면 무조건 재계약
    if (widget.isRenewal) {
      print('🔍 재계약 여부 판단: 재계약 버튼으로 진입 → 재계약 모드');
      return true;
    }
    
    // 2. 계약 기간 변경 확인 (재계약은 계약기간 변경시에만)
    final existingStartDate = _selectedManagerData!['manager_contract_startdate']?.toString() ?? '';
    final existingEndDate = _selectedManagerData!['manager_contract_enddate']?.toString() ?? '';
    
    final newStartDate = '${_contractStartDate.year}-${_contractStartDate.month.toString().padLeft(2, '0')}-${_contractStartDate.day.toString().padLeft(2, '0')}';
    final newEndDate = '${_contractEndDate.year}-${_contractEndDate.month.toString().padLeft(2, '0')}-${_contractEndDate.day.toString().padLeft(2, '0')}';
    
    final isDateChanged = (existingStartDate != newStartDate) || (existingEndDate != newEndDate);
    
    // 급여나 기타 정보 변경은 재계약이 아닌 단순 수정으로 처리
    final isSalaryChanged = 
      (_baseSalary != (_selectedManagerData?['salary_base'] ?? 0)) ||
      (_hourlySalary != (_selectedManagerData?['salary_hour'] ?? 0)) ||
      (_mealAllowance != (_selectedManagerData?['salary_meal'] ?? 0)) ||
      (_mealMinimumHours != (_selectedManagerData?['salary_meal_minimum_hours'] ?? 4)) ||
      (_incentive != (_selectedManagerData?['salary_incentive'] ?? 0));
    
    final isContractConditionChanged = 
      (_contractType != (_selectedManagerData?['contract_type'] ?? ''));
    
    // 재계약은 오직 계약기간이 변경되거나 재계약 버튼으로 진입한 경우에만
    final isRenewal = isDateChanged;
    
    print('🔍 재계약 여부 판단:');
    print('   재계약 버튼 모드: ${widget.isRenewal}');
    print('   기존 계약기간: $existingStartDate ~ $existingEndDate');
    print('   새 계약기간: $newStartDate ~ $newEndDate');
    print('   계약기간 변경: $isDateChanged');
    print('   급여 정보 변경: $isSalaryChanged (단순 수정으로 처리)');
    print('   계약 조건 변경: $isContractConditionChanged (단순 수정으로 처리)');
    print('   📋 최종 판단 - 재계약: $isRenewal');
    
    return isRenewal;
  }

  // 기존 직원 정보 업데이트 (재계약이 아닌 단순 수정)
  Future<void> _updateExistingManagerInfo(String branchId, String managerId, String managerName) async {
    try {
      print('🔄 기존 직원 정보 업데이트 시작: $managerName (ID: $managerId)');
      
      // 현재 시간
      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      // 업데이트할 데이터 (계약기간은 변경하지 않고 다른 정보만 업데이트)
      final updateData = {
        'manager_phone': _phoneValue,
        'staff_access_id': _accessIdValue,
        // 수정 시에는 비밀번호 변경 불가 (개별 직원이 변경)
        'manager_position': _positionValue,
        'manager_gender': _genderValue,
        'manager_birthday': '${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}',
        'contract_type': _contractType,
        'manager_contract_status': _contractStatus,
        'salary_base': _baseSalary,
        'salary_hour': _hourlySalary,
        'salary_meal': _mealAllowance,
        'salary_meal_minimum_hours': _mealMinimumHours,
        'salary_incentive': _incentive,
        'severance_pay': _severancePay,
        'updated_at': currentTime,
      };
      
      print('🔍 기존 직원 정보 업데이트 데이터: $updateData');

      final whereConditions = [
        {'field': 'manager_id', 'operator': '=', 'value': int.parse(managerId)},
        {'field': 'manager_contract_round', 'operator': '=', 'value': _selectedManagerData?['manager_contract_round'] ?? 1},
      ];

      final result = await SupabaseAdapter.updateData(
        table: 'v2_staff_manager',
        data: updateData,
        where: whereConditions,
      );

      print('🔍 기존 직원 정보 업데이트 응답: $result');

      if (result['success'] != true) {
        throw Exception('기존 직원 정보 업데이트 실패: ${result['message'] ?? '알 수 없는 오류'}');
      }
      
      print('✅ 기존 직원 정보 업데이트 성공 - manager_id: $managerId');

      // v2_staff_access_setting 테이블에 권한 설정 업데이트
      await _saveAccessSettings(branchId, _accessIdValue, managerName, 'manager');

    } catch (e) {
      print('❌ 기존 직원 정보 업데이트 실패: $e');
      throw Exception('기존 직원 정보 업데이트 실패: $e');
    }
  }

  // v2_staff_access_setting 테이블에 권한 설정 저장
  Future<void> _saveAccessSettings(String branchId, String accessId, String staffName, String staffType) async {
    try {
      print('🔐 권한 설정 저장 시작 - accessId: $accessId');

      // 먼저 기존 레코드 확인
      final checkResponse = await SupabaseAdapter.getData(
        table: 'v2_staff_access_setting',
        where: [
          {'field': 'staff_access_id', 'operator': '=', 'value': accessId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        limit: 1,
      );

      bool recordExists = checkResponse.isNotEmpty;

      // 권한 설정 데이터 준비
      final accessData = {
        'staff_access_id': accessId,
        'branch_id': branchId,
        'member_page': _permissions['member_page'],
        'member_registration': _permissions['member_registration'],
        'ts_management': _permissions['ts_management'],
        'lesson_status': _permissions['lesson_status'],
        'communication': _permissions['communication'],
        'locker': _permissions['locker'],
        'staff_schedule': _permissions['staff_schedule'],
        'pro_schedule': _permissions['pro_schedule'],
        'salary_view': _permissions['salary_view'],
        'salary_management': _permissions['salary_management'],
        'hr_management': _permissions['hr_management'],
        'branch_settings': _permissions['branch_settings'],
        'branch_operation': _permissions['branch_operation'],
        'client_app': _permissions['client_app'],
      };

      // staffType에 따라 staff_name 또는 pro_name 설정
      if (staffType == 'pro') {
        accessData['pro_name'] = staffName;
      } else {
        accessData['staff_name'] = staffName;
      }

      print('🔍 권한 설정 데이터: $accessData');

      // 레코드가 존재하면 update, 없으면 insert
      final operation = recordExists ? 'update' : 'add';
      Map<String, dynamic> result;

      if (recordExists) {
        final whereConditions = [
          {'field': 'staff_access_id', 'operator': '=', 'value': accessId},
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ];
        result = await SupabaseAdapter.updateData(
          table: 'v2_staff_access_setting',
          data: accessData,
          where: whereConditions,
        );
      } else {
        result = await SupabaseAdapter.addData(
          table: 'v2_staff_access_setting',
          data: accessData,
        );
      }

      print('🔍 권한 설정 저장 응답: $result');

      if (result['success'] != true) {
        throw Exception('권한 설정 저장 실패: ${result['message'] ?? '알 수 없는 오류'}');
      }

      print('✅ 권한 설정 저장 성공 - $operation 작업 완료');

    } catch (e) {
      print('❌ 권한 설정 저장 실패: $e');
      // 권한 설정 저장 실패는 전체 프로세스를 실패시키지 않도록 함
    }
  }

  // v2_staff_access_setting 테이블에서 권한 설정 로드
  Future<void> _loadAccessSettings() async {
    if (_accessIdValue.isEmpty) return;

    try {
      print('🔐 권한 설정 로드 시작 - accessId: $_accessIdValue');

      final response = await SupabaseAdapter.getData(
        table: 'v2_staff_access_setting',
        where: [
          {'field': 'staff_access_id', 'operator': '=', 'value': _accessIdValue},
        ],
        limit: 1,
      );

      print('🔍 권한 설정 로드 응답: ${response.length}건');

      if (response.isNotEmpty) {
        final accessData = response[0];

        // 저장된 권한 설정을 _permissions 맵에 적용
        setState(() {
          _permissions['member_page'] = accessData['member_page']?.toString() ?? '허용';
          _permissions['member_registration'] = accessData['member_registration']?.toString() ?? '허용';
          _permissions['ts_management'] = accessData['ts_management']?.toString() ?? '허용';
          _permissions['lesson_status'] = accessData['lesson_status']?.toString() ?? '전체';
          _permissions['communication'] = accessData['communication']?.toString() ?? '허용';
          _permissions['locker'] = accessData['locker']?.toString() ?? '허용';
          _permissions['staff_schedule'] = accessData['staff_schedule']?.toString() ?? '전체';
          _permissions['pro_schedule'] = accessData['pro_schedule']?.toString() ?? '전체';
          _permissions['salary_view'] = accessData['salary_view']?.toString() ?? '허용';
          _permissions['salary_management'] = accessData['salary_management']?.toString() ?? '불가';
          _permissions['hr_management'] = accessData['hr_management']?.toString() ?? '허용';
          _permissions['branch_settings'] = accessData['branch_settings']?.toString() ?? '허용';
          _permissions['branch_operation'] = accessData['branch_operation']?.toString() ?? '허용';
          _permissions['client_app'] = accessData['client_app']?.toString() ?? '허용'; // 매니저는 기본값이 허용
        });

        print('✅ 권한 설정 로드 성공');
        print('🔍 로드된 권한 설정: $_permissions');
      } else {
        print('ℹ️ 기존 권한 설정 없음 - 기본값 사용');
      }

    } catch (e) {
      print('❌ 권한 설정 로드 실패: $e');
      // 로드 실패 시 기본값 유지
    }
  }

  // DB에서 다음 manager_id 생성 (최대값 + 1)
  Future<int> _getNextManagerId(String branchId) async {
    try {
      print('🔍 다음 manager_id 조회 시작 - branch_id: $branchId');
      
      final response = await SupabaseAdapter.getData(
        table: 'v2_staff_manager',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        fields: ['manager_id'],
        orderBy: [{'field': 'manager_id', 'direction': 'DESC'}],
        limit: 1,
      );

      print('🔍 다음 manager_id 조회 응답: ${response.length}건');

      if (response.isNotEmpty) {
        final maxManagerId = response[0]['manager_id'];
        final nextManagerId = (maxManagerId is int ? maxManagerId : int.tryParse(maxManagerId.toString()) ?? 0) + 1;
        print('🔍 DB 최대 manager_id: $maxManagerId → 다음 manager_id: $nextManagerId');
        return nextManagerId;
      } else {
        print('🔍 기존 데이터 없음, 첫 번째 manager_id: 1');
        return 1;
      }
      
    } catch (e) {
      print('❌ 다음 manager_id 조회 실패: $e');
      print('⚠️ 기본값 1 사용');
      return 1;
    }
  }
}

// 별도의 StatefulWidget으로 인센티브 행 구현
class _IncentiveSalaryTableRow extends StatefulWidget {
  final String category;
  final String initialAmount;
  final int minReservationTime;
  final bool isLast;

  const _IncentiveSalaryTableRow({
    required this.category,
    required this.initialAmount,
    required this.minReservationTime,
    this.isLast = false,
  });

  @override
  _IncentiveSalaryTableRowState createState() => _IncentiveSalaryTableRowState();
}

class _IncentiveSalaryTableRowState extends State<_IncentiveSalaryTableRow> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount);
  }

  @override
  void didUpdateWidget(_IncentiveSalaryTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 초기값이 변경되었을 때만 컨트롤러 업데이트
    if (oldWidget.initialAmount != widget.initialAmount && _amountController.text.isEmpty) {
      _amountController.text = widget.initialAmount;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: widget.isLast ? BorderSide.none : BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
          child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          // 구분명
              Container(
            width: 120,
            child: Text(
              widget.category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          SizedBox(width: 8),
          // 금액과 시간 입력 필드 - 확대
              Expanded(
            flex: 4,
            child: Row(
              children: [
                // 금액 입력
                Expanded(
                  child: Container(
                    height: 34,
                    child: TextFormField(
                      controller: _amountController,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right, // 오른쪽 정렬
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        suffixText: '원',
                        suffixStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ThousandsSeparatorInputFormatter(), // 천 단위 콤마 추가
                      ],
                      onChanged: (value) {
                        setState(() {}); // 분당 환산 금액 업데이트를 위해
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // 시간 텍스트 표시
                Text(
                  '/${widget.minReservationTime}분',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
          ),
        ),
      ],
            ),
          ),
          SizedBox(width: 8),
          // 비고 (분당 환산 금액) - 축소
          Expanded(
            flex: 1,
            child: Builder(
              builder: (context) {
                String perMinuteAmount = '';
                if (_amountController.text.isNotEmpty) {
                  try {
                    // 콤마 제거 후 숫자 파싱
                    final cleanAmount = _amountController.text.replaceAll(',', '');
                    final amountValue = double.parse(cleanAmount);
                    if (widget.minReservationTime > 0) {
                      final perMinute = amountValue / widget.minReservationTime;
                      perMinuteAmount = '분당 ${_formatNumber(perMinute.round())}원';
                    }
                  } catch (e) {
                    perMinuteAmount = '';
                  }
                }
                
                return Text(
                  perMinuteAmount,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 숫자 포맷팅 함수 (천 단위 콤마)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

// 천 단위 콤마 입력 포맷터
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 숫자만 추출
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return TextEditingValue.empty;
    }

    // 천 단위 콤마 추가
    String formatted = _addThousandsSeparator(digitsOnly);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _addThousandsSeparator(String value) {
    if (value.isEmpty) return value;
    
    // 뒤에서부터 3자리씩 콤마 추가
    String result = '';
    for (int i = value.length - 1; i >= 0; i--) {
      result = value[i] + result;
      if ((value.length - i) % 3 == 0 && i != 0) {
        result = ',' + result;
      }
    }
    return result;
  }
} 