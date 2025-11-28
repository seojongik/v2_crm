import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '/services/holiday_service.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '/services/tab_design_upper.dart';

class Tab11LessonHoursWidget extends StatefulWidget {
  const Tab11LessonHoursWidget({super.key});

  @override
  State<Tab11LessonHoursWidget> createState() => _Tab11LessonHoursWidgetState();
}

class _Tab11LessonHoursWidgetState extends State<Tab11LessonHoursWidget> with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Supabase로 마이그레이션됨 (cafe24 제거)

  // 공휴일 데이터
  List<String> _holidays = [];
  bool _isLoadingHolidays = false;

  // 프로 데이터
  List<Map<String, dynamic>> _proList = [];
  bool _isLoadingPros = false;
  String _selectedMode = ''; // 현재 선택된 프로명
  Map<String, dynamic>? _selectedProData; // 선택된 프로 데이터

  // TabController
  late TabController _tabController;
  
  // 프로별 운영시간 데이터 (프로명을 키로 사용)
  Map<String, Map<int, Map<String, dynamic>>> _proWeeklyHours = {};
  
  // 일별 스케줄 데이터 (날짜별 운영시간)
  Map<String, Map<String, dynamic>> _dailySchedule = {};

  // 월별 스케줄 데이터 (v2_schedule_adjusted_pro에서 조회한 데이터)
  Map<String, Map<String, dynamic>> _monthlySchedule = {};

  final List<String> _weekdayNames = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  // 저장 중 상태
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    if (_proList.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_proList.isNotEmpty && _tabController.index < _proList.length) {
      final selectedPro = _proList[_tabController.index];
      final proName = selectedPro['pro_name'] ?? '';
      if (proName != _selectedMode) {
        _onModeChanged(proName);
      }
    }
  }

  // 데이터 초기화
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadHolidays(_focusedDay.year);
      await _loadProList();
    } catch (e) {
      print('❌ 레슨 데이터 로드 실패: $e');
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 공휴일 데이터 로드
  Future<void> _loadHolidays(int year) async {
    setState(() {
      _isLoadingHolidays = true;
    });
    
    try {
      final holidays = await HolidayService.getHolidays(year);
      setState(() {
        _holidays = holidays;
        _isLoadingHolidays = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHolidays = false;
      });
    }
  }

  // 프로 리스트 로드
  Future<void> _loadProList() async {
    setState(() {
      _isLoadingPros = true;
    });

    try {
      // pro_schedule 권한 체크
      final proSchedulePermission = ApiService.getCurrentAccessSettings()?['pro_schedule'] ?? '전체';
      final currentUser = ApiService.getCurrentUser();
      final currentRole = ApiService.getCurrentStaffRole();

      if (proSchedulePermission == '본인' && currentRole == 'pro' && currentUser != null) {
        // 본인 권한인 경우 현재 로그인한 프로의 정보만 표시
        final newProList = [currentUser];

        // TabController 초기화
        _tabController = TabController(length: newProList.length, vsync: this);
        _tabController.addListener(_handleTabSelection);

        setState(() {
          _proList = newProList;
          _isLoadingPros = false;
        });

        // 자동으로 본인 선택
        if (_proList.isNotEmpty) {
          _onModeChanged(_proList[0]['pro_name'] ?? '');
        }

        print('🔒 pro_schedule 본인 권한: ${currentUser['pro_name']} 프로만 표시');
        return;
      }

      // 전체 권한인 경우 모든 프로 조회 (Supabase)
      final data = await SupabaseAdapter.getData(
        table: 'v2_staff_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
          {'field': 'staff_status', 'operator': '=', 'value': '재직'},
          {'field': 'staff_type', 'operator': '=', 'value': '프로'},
        ],
        orderBy: [
          {'field': 'pro_name', 'direction': 'ASC'}
        ],
      );

      // 중복 제거 로직
      final Map<String, Map<String, dynamic>> uniqueProList = {};
      for (var item in data) {
        final proId = item['pro_id'].toString();
        final currentRound = item['pro_contract_round'] ?? 0;
        if (!uniqueProList.containsKey(proId) ||
            (uniqueProList[proId]!['pro_contract_round'] ?? 0) < currentRound) {
          uniqueProList[proId] = item;
        }
      }

      final newProList = uniqueProList.values.toList();

      // TabController 초기화
      _tabController = TabController(length: newProList.length, vsync: this);
      _tabController.addListener(_handleTabSelection);

      setState(() {
        _proList = newProList;
      });
      print('✅ 프로 리스트 로드 완료: ${_proList.length}개');
    } catch (e) {
      print('❌ 프로 리스트 로드 오류: $e');
      setState(() {
        _proList = [];
      });
    }

    setState(() {
      _isLoadingPros = false;
    });

    // 첫 번째 프로를 기본 선택
    if (_proList.isNotEmpty && _selectedMode.isEmpty) {
      _onModeChanged(_proList.first['pro_name'] ?? '');
    }
  }

  // 특정 날짜가 공휴일인지 확인
  bool _isHoliday(DateTime date) {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _holidays.contains(dateStr);
  }

  // 특정 날짜의 공휴일 이름 가져오기
  String? _getHolidayName(DateTime date) {
    return HolidayService.getHolidayName(date);
  }

  // 날짜의 요일 번호 가져오기 (일요일=0, 월요일=1, ... 토요일=6)
  int _getWeekdayNumber(DateTime date) {
    return date.weekday % 7;
  }

  // 특정 날짜의 운영시간 가져오기
  String _getOperatingHours(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    
    // 1. 월별 스케줄에서 먼저 확인 (v2_schedule_adjusted_pro 테이블 데이터)
    if (_monthlySchedule.containsKey(dateString)) {
      final monthSchedule = _monthlySchedule[dateString]!;
      if (monthSchedule['isClosed']) {
        return '휴무';
      } else {
        final startTime = _formatTime(monthSchedule['startTime']);
        final endTime = _formatTime(monthSchedule['endTime']);
        return '$startTime-$endTime';
      }
    }
    
    // 2. 일별 스케줄에서 확인 (수동 설정된 데이터)
    if (_dailySchedule.containsKey(dateString)) {
      final daySchedule = _dailySchedule[dateString]!;
      if (daySchedule['isClosed']) {
        return '휴무';
      } else {
        final startTime = _formatTime(daySchedule['startTime']);
        final endTime = _formatTime(daySchedule['endTime']);
        return '$startTime-$endTime';
      }
    }
    
    // 테이블에 없으면 미설정
    return '미설정';
  }

  // 시간 형식 유효성 검사
  bool _isValidTime(String time) {
    if (time.isEmpty) return false;
    
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
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

  // 레슨 운영시간 저장
  Future<void> _saveLessonHours() async {
    if (_selectedMode.isEmpty) {
      _showErrorSnackBar('프로를 선택해주세요');
      return;
    }

    if (_selectedProData == null) {
      _showErrorSnackBar('프로 정보를 찾을 수 없습니다');
      return;
    }

    // 저장할 데이터가 있는지 확인
    if (!_proWeeklyHours.containsKey(_selectedMode) || _proWeeklyHours[_selectedMode]!.isEmpty) {
      _showErrorSnackBar('저장할 레슨 운영시간 데이터가 없습니다');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      print('🏢 레슨 운영시간 저장 - 프로: $_selectedMode');
      
      final branchId = ApiService.getCurrentBranchId();
      print('🔍 현재 branchId: $branchId');
      
      if (branchId == null || branchId.isEmpty) {
        throw Exception('지점 정보를 찾을 수 없습니다. 다시 로그인해주세요.');
      }
      
      final proId = _selectedProData!['pro_id'].toString(); // 문자열로 변환
      final proName = _selectedProData!['pro_name'].toString();
      
      print('🔍 proId: $proId, proName: $proName');
      
      // 요일별로 데이터 저장 - 실제 데이터가 있는 요일만 처리
      final weekdayKorean = ['일', '월', '화', '수', '목', '금', '토'];
      final proHours = _proWeeklyHours[_selectedMode]!;
      
      for (int weekdayIndex in proHours.keys) {
        try {
          final daySchedule = proHours[weekdayIndex]!;
          final dayOfWeek = weekdayKorean[weekdayIndex];
          
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
          final checkData = await SupabaseAdapter.getData(
            table: 'v2_weekly_schedule_pro',
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'pro_id', 'operator': '=', 'value': proId},
              {'field': 'day_of_week', 'operator': '=', 'value': dayOfWeek},
            ],
          );

          if (checkData.isNotEmpty) {
              // 기존 데이터가 있으면 업데이트
              final updateData = {
                'is_day_off': isDayOff,
                'start_time': startTime,
                'end_time': endTime,
                'updated_at': currentTime,
              };

              print('🔍 $dayOfWeek 업데이트 데이터: $updateData');

              final updateResult = await SupabaseAdapter.updateData(
                table: 'v2_weekly_schedule_pro',
                data: updateData,
                where: [
                  {'field': 'branch_id', 'operator': '=', 'value': branchId},
                  {'field': 'pro_id', 'operator': '=', 'value': proId},
                  {'field': 'day_of_week', 'operator': '=', 'value': dayOfWeek},
                ],
              );

              if (updateResult['success'] != true) {
                throw Exception('$dayOfWeek 업데이트 실패: ${updateResult['message'] ?? '알 수 없는 오류'}');
              }

              print('✅ $dayOfWeek 업데이트 성공');
              
            } else {
              // 기존 데이터가 없으면 새로 추가
              final insertData = {
                'branch_id': branchId,
                'pro_id': proId,
                'pro_name': proName,
                'day_of_week': dayOfWeek,
                'is_day_off': isDayOff,
                'start_time': startTime,
                'end_time': endTime,
                'updated_at': currentTime,
              };

              print('🔍 $dayOfWeek 추가 데이터: $insertData');

              final insertResult = await SupabaseAdapter.addData(
                table: 'v2_weekly_schedule_pro',
                data: insertData,
              );

              print('🔍 $dayOfWeek 추가 결과: ${insertResult['success']}');

              if (insertResult['success'] != true) {
                print('❌ $dayOfWeek 추가 상세 오류: ${insertResult['message']}');
                throw Exception('$dayOfWeek 추가 실패: ${insertResult['message'] ?? '알 수 없는 오류'}');
              }

              print('✅ $dayOfWeek 추가 성공');
            }
        } catch (e) {
          print('❌ ${weekdayKorean[weekdayIndex]} 처리 중 오류: $e');
          throw e; // 에러를 다시 던져서 전체 프로세스 중단
        }
      }
      
      _showSuccessSnackBar('$_selectedMode 레슨 운영시간이 저장되었습니다');
      print('✅ 레슨 운영시간 저장 완료 - 총 ${proHours.length}개 요일 처리됨');
      
      // v2_schedule_adjusted_pro 테이블에 월별 스케줄 저장
      await _saveMonthlySchedule(branchId, proId, proName);
      
    } catch (e) {
      print('❌ 레슨 운영시간 저장 실패: $e');
      _showErrorSnackBar('저장 실패: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // 월별 스케줄을 v2_schedule_adjusted_pro에 저장
  Future<void> _saveMonthlySchedule(String branchId, String proId, String proName) async {
    try {
      print('📅 월별 스케줄 저장 시작 - ${_selectedDay.year}년 ${_selectedDay.month}월');
      
      // 선택된 월의 첫날과 마지막날 계산
      final firstDay = DateTime(_selectedDay.year, _selectedDay.month, 1);
      final lastDay = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
      
      final weekdayKorean = ['일', '월', '화', '수', '목', '금', '토'];
      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      // 해당 월의 모든 날짜에 대해 처리
      for (int day = 1; day <= lastDay.day; day++) {
        final currentDate = DateTime(_selectedDay.year, _selectedDay.month, day);
        final dateString = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        final weekdayIndex = currentDate.weekday % 7; // 일요일=0, 월요일=1, ..., 토요일=6
        
        // 해당 요일의 기본 스케줄 가져오기
        final daySchedule = _proWeeklyHours[_selectedMode]![weekdayIndex]!;
        
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
        
        print('🔍 $dateString 처리 중 - 요일: ${weekdayIndex}, isDayOff: $isDayOff, workStart: $workStart, workEnd: $workEnd');

        // 기존 데이터 확인
        final checkData = await SupabaseAdapter.getData(
          table: 'v2_schedule_adjusted_pro',
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'pro_id', 'operator': '=', 'value': proId},
            {'field': 'scheduled_date', 'operator': '=', 'value': dateString},
          ],
        );

        print('🔍 $dateString 기존 데이터 확인 결과: ${checkData.length}개');

        if (checkData.isNotEmpty) {
            // 기존 데이터가 있으면 업데이트
            final updateData = {
              'work_start': workStart,
              'work_end': workEnd,
              'is_day_off': isDayOff,
              'updated_at': currentTime,
              'is_manually_set': '자동',
            };

            print('🔍 $dateString 업데이트 데이터: $updateData');

            final updateResult = await SupabaseAdapter.updateData(
              table: 'v2_schedule_adjusted_pro',
              data: updateData,
              where: [
                {'field': 'branch_id', 'operator': '=', 'value': branchId},
                {'field': 'pro_id', 'operator': '=', 'value': proId},
                {'field': 'scheduled_date', 'operator': '=', 'value': dateString},
              ],
            );

            print('🔍 $dateString 업데이트 결과: ${updateResult['success']}');

            if (updateResult['success'] == true) {
              print('✅ $dateString 스케줄 업데이트 성공');
            } else {
              print('❌ $dateString 스케줄 업데이트 실패: ${updateResult['message']}');
            }
            
          } else {
            // 기존 데이터가 없으면 새로 추가
            final insertData = {
              'branch_id': branchId,
              'pro_id': proId,
              'pro_name': proName,
              'scheduled_date': dateString,
              'work_start': workStart,
              'work_end': workEnd,
              'is_day_off': isDayOff,
              'updated_at': currentTime,
              'is_manually_set': '자동',
            };

            print('🔍 $dateString 추가 데이터: $insertData');

            final insertResult = await SupabaseAdapter.addData(
              table: 'v2_schedule_adjusted_pro',
              data: insertData,
            );

            print('🔍 $dateString 추가 결과: ${insertResult['success']}');

            if (insertResult['success'] == true) {
              print('✅ $dateString 스케줄 추가 성공');
            } else {
              print('❌ $dateString 스케줄 추가 실패: ${insertResult['message']}');
            }
          }
      }
      
      print('✅ 월별 스케줄 저장 완료 - ${lastDay.day}일 처리됨');
      
    } catch (e) {
      print('❌ 월별 스케줄 저장 실패: $e');
      // 월별 스케줄 저장 실패해도 전체 프로세스는 성공으로 처리
    }
  }

  // 프로별 레슨 운영시간 로드
  Future<void> _loadProSchedule(String proName) async {
    if (_selectedProData == null) return;

    try {
      final branchId = ApiService.getCurrentBranchId();
      final proId = _selectedProData!['pro_id'];

      final scheduleData = await SupabaseAdapter.getData(
        table: 'v2_weekly_schedule_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'pro_id', 'operator': '=', 'value': proId},
        ],
      );

      // 프로별 운영시간 데이터 초기화
      _proWeeklyHours[proName] = {};

      if (scheduleData.isNotEmpty) {
        // 데이터베이스에서 불러온 데이터로 설정
        final weekdayKorean = ['일', '월', '화', '수', '목', '금', '토'];

        // 데이터베이스 값으로 설정
        for (var schedule in scheduleData) {
          final dayOfWeek = schedule['day_of_week'];
          final weekdayIndex = weekdayKorean.indexOf(dayOfWeek);

          if (weekdayIndex >= 0) {
            final isDayOff = schedule['is_day_off'] == '휴무';
            final startTime = _formatTime(schedule['start_time'] ?? '07:00:00');
            final endTime = _formatTime(schedule['end_time'] ?? '23:00:00');

            _proWeeklyHours[proName]![weekdayIndex] = {
              'startTime': startTime,
              'endTime': endTime,
              'isClosed': isDayOff,
            };
          }
        }

        print('✅ $proName 레슨 운영시간 로드 완료');
      } else {
        print('ℹ️ $proName 레슨 운영시간 데이터 없음');
      }
    } catch (e) {
      print('❌ $proName 레슨 운영시간 로드 실패: $e');
      // 실패 시 빈 맵 유지
      _proWeeklyHours[proName] = {};
    }
  }

  // 월별 스케줄 데이터 로드
  Future<void> _loadMonthlySchedule() async {
    if (_selectedMode.isEmpty || _selectedProData == null) return;

    try {
      final branchId = ApiService.getCurrentBranchId();
      final proId = _selectedProData!['pro_id'];

      // 해당 월의 첫날과 마지막날 계산
      final firstDay = DateTime(_selectedDay.year, _selectedDay.month, 1);
      final lastDay = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);

      final firstDateStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDateStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      print('📅 월별 스케줄 조회 - ${_selectedDay.year}년 ${_selectedDay.month}월 ($firstDateStr ~ $lastDateStr)');

      final scheduleData = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'scheduled_date', 'operator': '>=', 'value': firstDateStr},
          {'field': 'scheduled_date', 'operator': '<=', 'value': lastDateStr},
        ],
        orderBy: [
          {'field': 'scheduled_date', 'direction': 'ASC'}
        ],
      );

      if (scheduleData.isNotEmpty) {
        // 기존 월별 스케줄 데이터 초기화
        _monthlySchedule.clear();

        // 조회된 데이터를 맵에 저장
        for (var schedule in scheduleData) {
          final dateStr = schedule['scheduled_date'];
          final isDayOff = schedule['is_day_off'] == '휴무';
          final workStart = _formatTime(schedule['work_start'] ?? '07:00:00');
          final workEnd = _formatTime(schedule['work_end'] ?? '23:00:00');

          _monthlySchedule[dateStr] = {
            'isClosed': isDayOff,
            'startTime': workStart,
            'endTime': workEnd,
          };
        }

        print('✅ 월별 스케줄 로드 완료 - ${scheduleData.length}개 날짜');
      } else {
        print('ℹ️ 월별 스케줄 데이터 없음');
        _monthlySchedule.clear();
      }
    } catch (e) {
      print('❌ 월별 스케줄 로드 실패: $e');
      _monthlySchedule.clear();
    }
  }

  // 모드 변경 처리
  void _onModeChanged(String mode) async {
    setState(() {
      _selectedMode = mode;
      // 프로 데이터 설정
      _selectedProData = _proList.firstWhere(
        (pro) => pro['pro_name'] == mode,
        orElse: () => {},
      );
    });

    // 데이터베이스에서 기존 스케줄 로드
    await _loadProSchedule(mode);
    // 월별 스케줄 로드
    await _loadMonthlySchedule();
    setState(() {}); // UI 업데이트
  }

  // 프로별 운영시간 설정 위젯
  Widget _buildProWeeklySettings() {
    if (_selectedMode.isEmpty || !_proWeeklyHours.containsKey(_selectedMode)) {
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
            '프로를 선택해주세요',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    Map<int, Map<String, dynamic>> proHours = _proWeeklyHours[_selectedMode]!;

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
                Icon(Icons.settings, color: Color(0xFF10B981), size: 20),
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
                      fontSize: 14,
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
                      fontSize: 14,
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
                      fontSize: 14,
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
                    fontSize: 14,
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
              // 새로운 순서에 맞게 weekdayNumber 매핑
              int weekdayNumber;
              if (index == 6) { // 일요일
                weekdayNumber = 0;
              } else { // 월~토요일
                weekdayNumber = index + 1;
              }
              
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
                          fontSize: 14,
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
                              _proWeeklyHours[_selectedMode]![weekdayNumber]!['startTime'] = _formatTime(value);
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
                          fontSize: 14,
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
                              _proWeeklyHours[_selectedMode]![weekdayNumber]!['endTime'] = _formatTime(value);
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
                            _proWeeklyHours[_selectedMode]![weekdayNumber]!['isClosed'] = value ?? false;
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
          // 저장 버튼
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () {
                    print('🔘 레슨 운영시간 저장 버튼 클릭됨');
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
                    : Icon(Icons.save, color: Colors.white, size: 16),
                  label: Text(
                    _isSaving ? '저장 중...' : '레슨시간 저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  // 달력 위젯
  Widget _buildCalendar() {
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
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                SizedBox(width: 8),
                Text(
                  '근무일정표',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Spacer(),
                // 월 네비게이션
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        final previousYear = _selectedDay.year;
                        setState(() {
                          _selectedDay = DateTime(_selectedDay.year, _selectedDay.month - 1);
                        });
                        // 연도가 바뀌면 공휴일 데이터 새로 로드
                        if (_selectedDay.year != previousYear) {
                          await _loadHolidays(_selectedDay.year);
                        }
                        // 월별 스케줄 다시 로드
                        await _loadMonthlySchedule();
                        setState(() {});
                      },
                      icon: Icon(Icons.chevron_left, color: Color(0xFF10B981)),
                      iconSize: 20,
                    ),
                    Text(
                      '${_selectedDay.year}년 ${_selectedDay.month}월',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final previousYear = _selectedDay.year;
                        setState(() {
                          _selectedDay = DateTime(_selectedDay.year, _selectedDay.month + 1);
                        });
                        // 연도가 바뀌면 공휴일 데이터 새로 로드
                        if (_selectedDay.year != previousYear) {
                          await _loadHolidays(_selectedDay.year);
                        }
                        // 월별 스케줄 다시 로드
                        await _loadMonthlySchedule();
                        setState(() {});
                      },
                      icon: Icon(Icons.chevron_right, color: Color(0xFF10B981)),
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 달력 테이블
          Expanded(
            child: _buildCalendarTable(),
          ),
        ],
      ),
    );
  }

  // 달력 테이블 생성
  Widget _buildCalendarTable() {
    DateTime firstDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    DateTime lastDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
    
    // 첫 번째 주의 시작 요일 (일요일=0, 월요일=1, ... 토요일=6)
    int firstWeekday = firstDayOfMonth.weekday % 7;

    // 전체 셀 데이터 생성
    List<List<DateTime?>> weeks = [];
    List<DateTime?> currentWeek = [];
    
    // 이전 달의 빈 셀들
    for (int i = 0; i < firstWeekday; i++) {
      currentWeek.add(null);
    }

    // 현재 달의 날짜들
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
      currentWeek.add(DateTime(_selectedDay.year, _selectedDay.month, day));
    }
    
    // 마지막 주 완성
    while (currentWeek.length < 7) {
      currentWeek.add(null);
    }
    weeks.add(currentWeek);
    
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFE5E7EB), width: 1),
        ),
        child: Column(
          children: [
            // 요일 헤더
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: day != '토' ? BorderSide(color: Color(0xFFE5E7EB), width: 1) : BorderSide.none,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: day == '일' 
                                ? Color(0xFFEF4444) 
                                : day == '토'
                                  ? Color(0xFF2563EB)
                                  : Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // 날짜 행들
            Expanded(
              child: Column(
                children: weeks.map((week) => Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                    ),
                    child: Row(
                      children: week.asMap().entries.map((entry) {
                        int dayIndex = entry.key;
                        DateTime? date = entry.value;
                        
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: dayIndex < 6 ? BorderSide(color: Color(0xFFE5E7EB), width: 1) : BorderSide.none,
                              ),
                              color: date != null ? _getCellColor(date) : Colors.transparent,
                            ),
                            child: date != null ? _buildDateContent(date) : Container(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 셀 배경색 결정
  Color _getCellColor(DateTime date) {
    bool isToday = DateTime.now().day == date.day && 
                   DateTime.now().month == date.month && 
                   DateTime.now().year == date.year;
    bool isSelected = _selectedDay.day == date.day && 
                      _selectedDay.month == date.month && 
                      _selectedDay.year == date.year;
    
    if (isSelected) {
      return Color(0xFF10B981).withOpacity(0.1);
    } else if (isToday) {
      return Color(0xFF10B981).withOpacity(0.05);
    } else {
      return Colors.white;
    }
  }

  // 날짜 셀 내용
  Widget _buildDateContent(DateTime date) {
    bool isToday = DateTime.now().day == date.day && 
                   DateTime.now().month == date.month && 
                   DateTime.now().year == date.year;
    bool isSelected = _selectedDay.day == date.day && 
                      _selectedDay.month == date.month && 
                      _selectedDay.year == date.year;
    bool isSunday = date.weekday == 7;
    bool isSaturday = date.weekday == 6;
    bool isHoliday = _isHoliday(date);
    String? holidayName = _getHolidayName(date);
    
    String operatingHours = _getOperatingHours(date);
    
    // 날짜 텍스트 색상 결정
    Color dateTextColor;
    if (isSelected) {
      dateTextColor = Color(0xFF10B981);
    } else if (isToday) {
      dateTextColor = Color(0xFF10B981);
    } else if (isHoliday || isSunday) {
      dateTextColor = Color(0xFFEF4444);
    } else if (isSaturday) {
      dateTextColor = Color(0xFF2563EB);
    } else {
      dateTextColor = Color(0xFF374151);
    }
    
    return GestureDetector(
      onTap: () {
        // 프로가 선택되어 있을 때만 클릭 가능
        if (_selectedMode.isNotEmpty && _selectedProData != null) {
          _showDateTimeEditDialog(date);
        } else {
          _showErrorSnackBar('프로를 먼저 선택해주세요');
        }
      },
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜와 공휴일 이름을 같은 행에 배치
            Row(
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: dateTextColor,
                  ),
                ),
                if (holidayName != null && holidayName.isNotEmpty) ...[
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      holidayName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 4),
            // 운영시간
            Expanded(
              child: Center(
                child: Text(
                  operatingHours,
                  style: TextStyle(
                    fontSize: 14,
                    color: operatingHours == '휴무' 
                      ? Color(0xFFEF4444)
                      : operatingHours == '미설정'
                        ? Color(0xFF9CA3AF)
                        : Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 클릭 가능 표시 (프로가 선택되어 있을 때만)
            if (_selectedMode.isNotEmpty && _selectedProData != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.edit,
                  size: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 날짜별 수동 시간 편집 다이얼로그
  Future<void> _showDateTimeEditDialog(DateTime date) async {
    if (_selectedMode.isEmpty || _selectedProData == null) {
      _showErrorSnackBar('프로를 먼저 선택해주세요');
      return;
    }

    final dateString = DateFormat('yyyy-MM-dd').format(date);
    
    // 현재 설정된 시간 가져오기
    String currentStartTime = '07:00';
    String currentEndTime = '23:00';
    bool currentIsClosed = false;
    
    // 월별 스케줄에서 현재 값 확인
    if (_monthlySchedule.containsKey(dateString)) {
      final schedule = _monthlySchedule[dateString]!;
      currentIsClosed = schedule['isClosed'];
      if (!currentIsClosed) {
        currentStartTime = _formatTime(schedule['startTime']);
        currentEndTime = _formatTime(schedule['endTime']);
      }
    }
    
    // 컨트롤러 초기화
    final startTimeController = TextEditingController(text: currentIsClosed ? '' : currentStartTime);
    final endTimeController = TextEditingController(text: currentIsClosed ? '' : currentEndTime);
    bool isClosed = currentIsClosed;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  Icon(Icons.edit_calendar, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    '${DateFormat('M월 d일').format(date)} 시간 수정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 휴무 체크박스
                    Row(
                      children: [
                        Checkbox(
                          value: isClosed,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              isClosed = value ?? false;
                              if (isClosed) {
                                startTimeController.clear();
                                endTimeController.clear();
                              } else {
                                startTimeController.text = '07:00';
                                endTimeController.text = '23:00';
                              }
                            });
                          },
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
                        Text(
                          '휴무',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // 시작 시간
                    Row(
                      children: [
                        Container(
                          width: 80,
                          child: Text(
                            '시작 시간:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: startTimeController,
                            enabled: !isClosed,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '07:00',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                              filled: true,
                              fillColor: isClosed ? Color(0xFFF3F4F6) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                              LengthLimitingTextInputFormatter(5),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // 종료 시간
                    Row(
                      children: [
                        Container(
                          width: 80,
                          child: Text(
                            '종료 시간:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: endTimeController,
                            enabled: !isClosed,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '23:00',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                              filled: true,
                              fillColor: isClosed ? Color(0xFFF3F4F6) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                              LengthLimitingTextInputFormatter(5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFF6B7280),
                    backgroundColor: Color(0xFFF9FAFB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 시간 유효성 검사
                    if (!isClosed) {
                      if (!_isValidTime(startTimeController.text) || !_isValidTime(endTimeController.text)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '올바른 시간 형식을 입력해주세요 (예: 07:00)',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                        return;
                      }
                    }
                    
                    Navigator.of(context).pop({
                      'startTime': isClosed ? '00:00' : startTimeController.text,
                      'endTime': isClosed ? '00:00' : endTimeController.text,
                      'isClosed': isClosed,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (result != null) {
      await _updateDateSchedule(date, result);
    }
  }

  // 날짜별 스케줄 업데이트 (수동 조정)
  Future<void> _updateDateSchedule(DateTime date, Map<String, dynamic> scheduleData) async {
    if (_selectedMode.isEmpty || _selectedProData == null) return;

    try {
      final branchId = await _getBranchId();
      if (branchId == null) {
        _showErrorSnackBar('지점 정보를 가져올 수 없습니다');
        return;
      }

      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final now = DateTime.now();
      final currentTime = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      // 프로 ID를 올바르게 가져오기
      final proId = _selectedProData!['pro_id']?.toString() ?? _selectedProData!['staff_id']?.toString() ?? '';
      
      // 업데이트할 데이터 준비
      final updateData = {
        'branch_id': branchId,
        'pro_id': proId,
        'pro_name': _selectedMode,
        'scheduled_date': dateString,
        'work_start': scheduleData['isClosed'] ? '00:00:00' : '${scheduleData['startTime']}:00',
        'work_end': scheduleData['isClosed'] ? '00:00:00' : '${scheduleData['endTime']}:00',
        'is_day_off': scheduleData['isClosed'] ? '휴무' : '출근',
        'updated_at': currentTime,
        'is_manually_set': '수동조정',
      };

      print('날짜별 스케줄 업데이트 데이터: $updateData');

      // 기존 데이터 확인 후 업데이트 또는 추가
      final checkData = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'pro_id', 'operator': '=', 'value': proId},
          {'field': 'scheduled_date', 'operator': '=', 'value': dateString},
        ],
      );

      if (checkData.isNotEmpty) {
          // 기존 데이터가 있으면 업데이트
          final result = await SupabaseAdapter.updateData(
            table: 'v2_schedule_adjusted_pro',
            data: updateData,
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'pro_id', 'operator': '=', 'value': proId},
              {'field': 'scheduled_date', 'operator': '=', 'value': dateString},
            ],
          );

          print('날짜별 스케줄 업데이트 결과: ${result['success']}');

          if (result['success'] == true) {
            // 로컬 데이터 업데이트
            setState(() {
              _monthlySchedule[dateString] = {
                'startTime': scheduleData['startTime'],
                'endTime': scheduleData['endTime'],
                'isClosed': scheduleData['isClosed'],
                'isManuallySet': true,
              };
            });

            _showSuccessSnackBar('${DateFormat('M월 d일').format(date)} 스케줄이 수정되었습니다');
          } else {
            _showErrorSnackBar('스케줄 수정에 실패했습니다: ${result['message'] ?? '알 수 없는 오류'}');
          }
        } else {
          // 기존 데이터가 없으면 새로 추가
          final result = await SupabaseAdapter.addData(
            table: 'v2_schedule_adjusted_pro',
            data: updateData,
          );

          print('날짜별 스케줄 추가 결과: ${result['success']}');

          if (result['success'] == true) {
            // 로컬 데이터 업데이트
            setState(() {
              _monthlySchedule[dateString] = {
                'startTime': scheduleData['startTime'],
                'endTime': scheduleData['endTime'],
                'isClosed': scheduleData['isClosed'],
                'isManuallySet': true,
              };
            });

            _showSuccessSnackBar('${DateFormat('M월 d일').format(date)} 스케줄이 추가되었습니다');
          } else {
            _showErrorSnackBar('스케줄 추가에 실패했습니다: ${result['message'] ?? '알 수 없는 오류'}');
          }
        }
    } catch (e) {
      print('날짜별 스케줄 업데이트 오류: $e');
      _showErrorSnackBar('스케줄 수정 중 오류가 발생했습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF10B981),
        ),
      );
    }

    return Column(
      children: [
        // 탭바 헤더
        if (_proList.isNotEmpty)
          Container(
            child: Row(
              children: [
                // 프로 선택 탭들
                Expanded(
                  child: TabDesignUpper.buildCompleteTabBar(
                    controller: _tabController,
                    tabs: _proList.map((pro) {
                      final proName = pro['pro_name'] ?? '';
                      return TabDesignUpper.buildTabItem(
                        Icons.person,
                        proName,
                        size: 'medium',
                      );
                    }).toList(),
                    themeNumber: 1,
                    size: 'medium',
                    isScrollable: true,
                    hasTopRadius: false,
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(height: 16),
        
        // 메인 컨텐츠
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 프로별 운영시간 설정
              Container(
                width: 320,
                child: _buildProWeeklySettings(),
              ),
              SizedBox(width: 16),
              // 오른쪽: 달력
              Expanded(
                child: _buildCalendar(),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 