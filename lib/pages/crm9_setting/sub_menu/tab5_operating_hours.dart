import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../services/holiday_service.dart';
import '../../../services/api_service.dart';
import '../../../services/upper_button_input_design.dart';
import '../../../constants/font_sizes.dart';
import '/services/supabase_adapter.dart';

class Tab5OperatingHoursWidget extends StatefulWidget {
  const Tab5OperatingHoursWidget({super.key});

  @override
  State<Tab5OperatingHoursWidget> createState() => _Tab5OperatingHoursWidgetState();
}

class _Tab5OperatingHoursWidgetState extends State<Tab5OperatingHoursWidget> {
  // 캘린더 관련
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  
  // 공휴일 데이터
  List<String> _holidays = [];
  bool _isLoadingHolidays = false;
  
  // 요일별 운영시간 설정 (일요일=0, 월요일=1, ... 토요일=6, 공휴일=7로 변경)
  Map<int, Map<String, dynamic>> _weeklyHours = {
    0: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false},  // 일요일 (기본값)
    1: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false}, // 월요일
    2: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false}, // 화요일
    3: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false}, // 수요일
    4: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false}, // 목요일
    5: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false}, // 금요일
    6: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false}, // 토요일
    7: {'startTime': '09:00', 'endTime': '22:00', 'isClosed': false},  // 공휴일 (기본값)
  };

  // 일별 스케줄 데이터 (날짜별 운영시간)
  Map<String, Map<String, dynamic>> _dailySchedule = {};

  final List<String> _weekdayNames = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '공휴일'];

  // 저장 중 상태
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _initializeData();
  }

  // 데이터 초기화
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadWeeklySchedule();
      await _loadDailySchedule();
      await _loadHolidays(_focusedDay.year);
    } catch (e) {
      print('❌ 타석 데이터 로드 실패: $e');
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 주간 스케줄 불러오기
  Future<void> _loadWeeklySchedule() async {
    try {
      final response = await SupabaseAdapter.getData(
        table: 'v2_weekly_schedule_ts',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        ],
      );

      if (response.isNotEmpty) {
        print('📊 ========== DB에서 가져온 데이터 ==========');
        for (var item in response) {
          print('DB: ${item['day_of_week']} - 시작: ${item['business_start']}, 종료: ${item['business_end']}, 휴무: ${item['is_holiday']}');
        }
        print('==========================================\n');

        // 불러온 데이터로 _weeklyHours 업데이트
        for (var item in response) {
          final dayOfWeek = item['day_of_week'];
          int dayIndex = _weekdayNames.indexOf(dayOfWeek);

          if (dayIndex != -1) {
            _weeklyHours[dayIndex] = {
              'startTime': _formatTime(item['business_start'] ?? '09:00'),
              'endTime': _formatTime(item['business_end'] ?? '22:00'),
              'isClosed': item['is_holiday'] == 'close',
            };
          }
        }

        print('📱 ========== _weeklyHours Map 내용 ==========');
        for (int i = 0; i < _weekdayNames.length; i++) {
          print('Map[$i] ${_weekdayNames[i]}: 시작=${_weeklyHours[i]!['startTime']}, 종료=${_weeklyHours[i]!['endTime']}, 휴무=${_weeklyHours[i]!['isClosed']}');
        }
        print('=============================================\n');

        print('✅ 주간 스케줄 로드 완료: ${response.length}개');
      } else {
        print('ℹ️ 주간 스케줄 데이터 없음 - 기본값 사용');
      }
    } catch (e) {
      print('❌ 주간 스케줄 로드 오류: $e');
      throw e;
    }
  }

  // 일별 스케줄 불러오기
  Future<void> _loadDailySchedule() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year + 1, 12, 31);
      
      final response = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_ts',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
          {'field': 'ts_date', 'operator': '>=', 'value': DateFormat('yyyy-MM-dd').format(startDate)},
          {'field': 'ts_date', 'operator': '<=', 'value': DateFormat('yyyy-MM-dd').format(endDate)},
        ],
      );

      if (response.isNotEmpty) {
        // 불러온 데이터로 _dailySchedule 업데이트
        _dailySchedule.clear();
        for (var item in response) {
          final dateString = item['ts_date'];
          _dailySchedule[dateString] = {
            'startTime': _formatTime(item['business_start'] ?? '09:00'),
            'endTime': _formatTime(item['business_end'] ?? '22:00'),
            'isClosed': item['is_holiday'] == 'close',
            'isManuallySet': item['is_manually_set'] == '수동',
          };
        }

        print('✅ 일별 스케줄 로드 완료: ${response.length}개');
      } else {
        print('ℹ️ 일별 스케줄 데이터 없음');
      }
    } catch (e) {
      print('❌ 일별 스케줄 로드 오류: $e');
      throw e;
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

  // 특정 날짜가 공휴일인지 확인
  bool _isHoliday(DateTime date) {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _holidays.contains(dateStr);
  }

  // 특정 날짜의 공휴일 이름 가져오기
  String? _getHolidayName(DateTime date) {
    return HolidayService.getHolidayName(date);
  }

  // 요일 번호를 한글 요일명으로 변환
  String _getWeekdayName(int weekday) {
    // Flutter weekday를 배열 인덱스로 변환: 일요일=7 -> 0, 월요일=1 -> 1, ..., 토요일=6 -> 6
    int index = weekday == 7 ? 0 : weekday;
    return _weekdayNames[index];
  }

  // 날짜의 요일 번호 가져오기 (일요일=0, 월요일=1, ... 토요일=6)
  int _getWeekdayNumber(DateTime date) {
    // Flutter weekday를 내부 인덱스로 변환: 일요일=7 -> 0, 월요일=1 -> 1, ..., 토요일=6 -> 6
    return date.weekday == 7 ? 0 : date.weekday;
  }

  // 특정 날짜의 운영시간 가져오기
  String _getOperatingHours(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    
    // 1. 일별 스케줄에서 먼저 확인 (DB에 저장된 실제 데이터만 사용)
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
    
    // 2. 일별 스케줄에 없으면 "미설정"으로 표시
    return '미설정';
  }

  // 시간 형식 검증
  bool _isValidTime(String time) {
    // 24:00도 허용 (자정 표시)
    if (time == '24:00') return true;

    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  // 시간 포맷팅 (화면 표시용)
  String _formatTime(String time) {
    if (time.isEmpty) return time;

    // HH:mm:ss 형식을 HH:mm으로 변환
    if (time.length >= 5 && time.contains(':')) {
      final formattedTime = time.substring(0, 5);
      // 00:00을 24:00으로 표시 (종료시간일 가능성이 높음)
      if (formattedTime == '00:00') {
        return '24:00';
      }
      return formattedTime;
    }

    // HHMM 형식을 HH:mm으로 변환
    if (time.length == 4 && !time.contains(':')) {
      return '${time.substring(0, 2)}:${time.substring(2, 4)}';
    }

    return time;
  }

  // DB 저장용 시간 포맷팅 (24:00을 00:00으로 변환)
  String _formatTimeForDB(String time) {
    if (time.isEmpty) return time;

    // 24:00을 00:00으로 변환
    if (time == '24:00') {
      return '00:00';
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

  // 운영시간 저장
  Future<void> _saveOperatingHours() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🏢 현재 브랜치 ID: ${ApiService.getCurrentBranchId()}');
      
      // 수동 설정된 날짜들 확인
      final manuallySetDates = await _getManuallySetDates();
      
      if (manuallySetDates.isNotEmpty) {
        // 경고창 표시
        final shouldProceed = await _showManualResetWarning(manuallySetDates);
        if (!shouldProceed) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      // 선택된 기간의 시작일과 종료일 계산 - 선택된 날짜부터 1년 후까지
      final startDate = _selectedDay;
      final endDate = DateTime(_selectedDay.year + 1, _selectedDay.month, _selectedDay.day);
      
      print('📅 저장 기간: ${DateFormat('yyyy-MM-dd').format(startDate)} ~ ${DateFormat('yyyy-MM-dd').format(endDate)}');
      
      // 요일별 스케줄과 일별 스케줄 저장
      await _updateWeeklySchedule();
      await _updateDailySchedule(startDate, endDate);
      
      _showSuccessSnackBar('운영시간이 저장되었습니다');
      
      // 데이터 새로고침
      await _loadDailySchedule();
      
    } catch (e) {
      print('❌ 운영시간 저장 실패: $e');
      _showErrorSnackBar('저장 실패: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 수동 설정된 날짜들 조회
  Future<List<Map<String, dynamic>>> _getManuallySetDates() async {
    try {
      print('수동 설정 날짜 조회 시작');
      
      // 선택된 날짜부터 1년 후까지 범위 계산
      final startDate = _selectedDay;
      final endDate = DateTime(_selectedDay.year + 1, _selectedDay.month, _selectedDay.day);
      
      print('조회 날짜 범위: ${startDate.toString().substring(0, 10)} ~ ${endDate.toString().substring(0, 10)}');
      print('브랜치 ID: ${ApiService.getCurrentBranchId()}');
      
      // API 조건 설정
      final conditions = [
        {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        {'field': 'ts_date', 'operator': '>=', 'value': startDate.toString().substring(0, 10)},
        {'field': 'ts_date', 'operator': '<=', 'value': endDate.toString().substring(0, 10)},
        {'field': 'is_manually_set', 'operator': '=', 'value': '수동조정'},
      ];
      
      print('쿼리 조건: $conditions');
      
      // API 호출 - 올바른 메서드명 사용
      final response = await ApiService.getScheduleAdjustedTsData(
        where: conditions,
        orderBy: [
          {'field': 'ts_date', 'direction': 'ASC'}
        ],
      );
      
      print('API 응답 상태: 성공');
      print('응답 데이터: $response');
      print('수동 설정 날짜 개수: ${response.length}개');
      
      if (response.isNotEmpty) {
        print('수동 설정 날짜 목록:');
        for (var date in response) {
          print('- ${date['ts_date']}: ${date['business_start']} ~ ${date['business_end']}');
        }
      }
      
      return response;
    } catch (e) {
      print('수동 설정 날짜 조회 실패: $e');
      return [];
    }
  }

  // 예약 충돌 체크 함수 추가
  Future<Map<String, List<Map<String, dynamic>>>> _checkReservationConflicts(List<Map<String, dynamic>> affectedDates) async {
    try {
      print('예약 충돌 체크 시작');
      
      Map<String, List<Map<String, dynamic>>> conflictsByDate = {};
      
      for (var dateData in affectedDates) {
        final tsDate = dateData['ts_date'];
        final date = DateTime.parse(tsDate);
        final dayOfWeek = _getWeekdayNumber(date);
        
        // 현재 수동 설정된 시간
        final currentBusinessStart = dateData['business_start'] ?? '';
        final currentBusinessEnd = dateData['business_end'] ?? '';
        final currentIsHoliday = dateData['is_holiday'] == 'close';
        
        // 변경될 요일별 운영시간
        final weeklyHours = _weeklyHours[dayOfWeek];
        
        bool willBeClosed = false;
        String newStartTime = '';
        String newEndTime = '';
        
        if (weeklyHours != null) {
          willBeClosed = weeklyHours['isClosed'] == true;
          newStartTime = weeklyHours['startTime'] ?? '';
          newEndTime = weeklyHours['endTime'] ?? '';
        }
        
        // 예약 데이터 조회
        final reservations = await ApiService.getPricedTsData(
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
            {'field': 'ts_date', 'operator': '=', 'value': tsDate},
            {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
          ],
          orderBy: [
            {'field': 'ts_start', 'direction': 'ASC'}
          ],
        );
        
        print('$tsDate 예약 조회 결과: ${reservations.length}개');
        
        List<Map<String, dynamic>> conflictReservations = [];
        
        for (var reservation in reservations) {
          final tsStart = reservation['ts_start'] ?? '';
          final tsEnd = reservation['ts_end'] ?? '';
          
          if (tsStart.isEmpty || tsEnd.isEmpty) continue;
          
          bool isConflict = false;
          
          // 충돌 조건 체크
          if (willBeClosed) {
            // 새로 휴무가 되는 경우 - 모든 예약이 충돌
            isConflict = true;
          } else if (currentIsHoliday && !willBeClosed) {
            // 현재 휴무에서 영업으로 변경되는 경우 - 충돌 없음
            isConflict = false;
          } else if (newStartTime.isNotEmpty && newEndTime.isNotEmpty) {
            // 운영시간이 변경되는 경우
            final reservationStart = _parseTime(tsStart);
            final reservationEnd = _parseTime(tsEnd);
            final newStart = _parseTime(newStartTime);
            final newEnd = _parseTime(newEndTime);
            
            // 예약 시간이 새로운 운영시간 범위를 벗어나는지 체크
            if (reservationStart < newStart || reservationEnd > newEnd) {
              isConflict = true;
            }
          }
          
          if (isConflict) {
            conflictReservations.add({
              'member_name': reservation['member_name'] ?? '',
              'ts_id': reservation['ts_id'] ?? '',
              'ts_start': reservation['ts_start'] ?? '',
              'ts_end': reservation['ts_end'] ?? '',
              'ts_min': reservation['ts_min'] ?? 0,
            });
          }
        }
        
        if (conflictReservations.isNotEmpty) {
          conflictsByDate[tsDate] = conflictReservations;
          print('$tsDate 충돌 예약: ${conflictReservations.length}개');
        }
      }
      
      print('총 충돌 날짜: ${conflictsByDate.keys.length}개');
      return conflictsByDate;
      
    } catch (e) {
      print('예약 충돌 체크 실패: $e');
      return {};
    }
  }

  // 시간 문자열을 분 단위로 변환하는 헬퍼 함수
  int _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return hour * 60 + minute;
      }
    } catch (e) {
      print('시간 파싱 오류: $timeStr - $e');
    }
    return 0;
  }

  // 수동 설정 리셋 경고창 - bool 반환값 추가
  Future<bool> _showManualResetWarning(List<Map<String, dynamic>> manuallySetDates) async {
    // 예약 충돌 체크
    final reservationConflicts = await _checkReservationConflicts(manuallySetDates);
    final hasConflicts = reservationConflicts.isNotEmpty;
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasConflicts 
                        ? Color(0xFFEF4444).withOpacity(0.1)
                        : Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasConflicts ? Icons.error : Icons.warning,
                    color: hasConflicts ? Color(0xFFEF4444) : Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasConflicts ? '운영시간 변경 불가' : '수동 설정 리셋 확인',
                        style: AppTextStyles.modalTitle.copyWith(
                          color: hasConflicts ? Color(0xFFEF4444) : Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            width: 800,
            constraints: BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 영향받는 날짜 목록
                  Text(
                    '수동 조정된 날짜가 아래와 같이 일괄 조정됩니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Table(
                      columnWidths: {
                        0: FlexColumnWidth(2.5),  // 날짜
                        1: FlexColumnWidth(1.5),  // 요일
                        2: FlexColumnWidth(3),    // 변경 전
                        3: FlexColumnWidth(0.8),  // 화살표
                        4: FlexColumnWidth(3),    // 변경 후
                      },
                      children: [
                        // 헤더 행
                        TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '날짜',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '요일',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '변경 전',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '변경 후',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        // 데이터 행들
                        ...manuallySetDates.map((dateData) {
                          final date = DateTime.parse(dateData['ts_date']);
                          final dayOfWeek = _getWeekdayNumber(date);
                          final dayName = _getWeekdayName(dayOfWeek);
                          
                          // 현재 수동 설정된 시간
                          final currentBusinessStart = dateData['business_start'] ?? '';
                          final currentBusinessEnd = dateData['business_end'] ?? '';
                          final currentIsHoliday = dateData['is_holiday'] == 'close';
                          
                          String currentTimeInfo;
                          if (currentIsHoliday) {
                            currentTimeInfo = '휴무';
                          } else if (currentBusinessStart.isNotEmpty && currentBusinessEnd.isNotEmpty) {
                            currentTimeInfo = '${_formatTime(currentBusinessStart)} ~ ${_formatTime(currentBusinessEnd)}';
                          } else {
                            currentTimeInfo = '시간 미설정';
                          }
                          
                          // 변경될 요일별 운영시간
                          final weeklyHours = _weeklyHours[dayOfWeek];
                          String newTimeInfo;
                          if (weeklyHours != null) {
                            if (weeklyHours['isClosed'] == true) {
                              newTimeInfo = '휴무';
                            } else {
                              final startTime = weeklyHours['startTime'] ?? '';
                              final endTime = weeklyHours['endTime'] ?? '';
                              if (startTime.isNotEmpty && endTime.isNotEmpty) {
                                newTimeInfo = '${_formatTime(startTime)} ~ ${_formatTime(endTime)}';
                              } else {
                                newTimeInfo = '시간 미설정';
                              }
                            }
                          } else {
                            newTimeInfo = '시간 미설정';
                          }
                          
                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: dateData != manuallySetDates.last 
                                    ? BorderSide(color: Color(0xFFE5E7EB), width: 0.5)
                                    : BorderSide.none,
                              ),
                            ),
                            children: [
                              // 날짜
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  dateData['ts_date'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 요일
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  dayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: dayOfWeek == 6 
                                        ? Color(0xFF2563EB)  // 토요일
                                        : dayOfWeek == 0
                                            ? Color(0xFFEF4444)  // 일요일
                                            : Color(0xFF374151), // 평일
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // 변경 전
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFEF4444).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Color(0xFFEF4444).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    currentTimeInfo,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              // 화살표
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Color(0xFF6B7280),
                                  size: 18,
                                ),
                              ),
                              // 변경 후
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Color(0xFF10B981).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    newTimeInfo,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // 예약 충돌 정보 섹션
                  Text(
                    '예약이 있는 경우 조정이 불가합니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  if (!hasConflicts) ...[
                    // 충돌이 없는 경우
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                          SizedBox(width: 8),
                          Text(
                            '해당 변경으로 인해 영향받는 예약건이 없습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 충돌이 있는 경우 - 날짜별로 예약 정보 표시
                    ...reservationConflicts.entries.map((entry) {
                      final tsDate = entry.key;
                      final conflicts = entry.value;
                      final date = DateTime.parse(tsDate);
                      final dayOfWeek = _getWeekdayNumber(date);
                      final dayName = _getWeekdayName(dayOfWeek);
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFEF4444).withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 날짜 헤더
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Color(0xFFEF4444), size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    '$tsDate ($dayName) - ${conflicts.length}건 충돌',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 예약 목록 테이블
                            Table(
                              columnWidths: {
                                0: FlexColumnWidth(2),    // 회원명
                                1: FlexColumnWidth(1.5),  // 타석번호
                                2: FlexColumnWidth(1.5),  // 시작시간
                                3: FlexColumnWidth(1.5),  // 종료시간
                                4: FlexColumnWidth(1),    // 이용시간
                              },
                              children: [
                                // 테이블 헤더
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        '회원명',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        '타석번호',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        '시작시간',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        '종료시간',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        '이용시간',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                // 예약 데이터 행들
                                ...conflicts.map((conflict) {
                                  return TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: conflict != conflicts.last 
                                            ? BorderSide(color: Color(0xFFE5E7EB), width: 0.5)
                                            : BorderSide.none,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          conflict['member_name'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          conflict['ts_id'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          _formatTime(conflict['ts_start'] ?? ''),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          _formatTime(conflict['ts_end'] ?? ''),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          '${conflict['ts_min'] ?? 0}분',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                          SizedBox(width: 8),
                          Text(
                            '예약 취소 후 운영시간 변경이 가능합니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            if (!hasConflicts) // 충돌이 없을 때만 진행하기 버튼 표시
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // true 반환
                },
                child: Text(
                  '진행하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6366F1),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
          ],
        );
      },
    ) ?? false; // null인 경우 false 반환
  }

  // v2_weekly_schedule_ts 테이블 업데이트
  Future<void> _updateWeeklySchedule() async {
    for (int dayIndex = 0; dayIndex <= 7; dayIndex++) {
      final dayName = _weekdayNames[dayIndex];
      final hours = _weeklyHours[dayIndex];

      if (hours == null) continue;

      final data = {
        'branch_id': ApiService.getCurrentBranchId(),
        'day_of_week': dayName,
        'is_holiday': hours['isClosed'] ? 'close' : 'open',
        'business_start': hours['isClosed'] ? null : _formatTimeForDB(hours['startTime']),
        'business_end': hours['isClosed'] ? null : _formatTimeForDB(hours['endTime']),
        'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      print('📝 주간 스케줄 저장: $dayName - $data');

      try {
        final whereConditions = [
          {'field': 'branch_id', 'operator': '=', 'value': data['branch_id']},
          {'field': 'day_of_week', 'operator': '=', 'value': dayName},
        ];

        // 기존 데이터 확인
        final getResponse = await SupabaseAdapter.getData(
          table: 'v2_weekly_schedule_ts',
          where: whereConditions,
        );

        print('🔍 기존 데이터 조회 결과: ${getResponse.length}건');

        // 데이터가 있으면 업데이트, 없으면 추가
        Map<String, dynamic> result;
        if (getResponse.isNotEmpty) {
          result = await SupabaseAdapter.updateData(
            table: 'v2_weekly_schedule_ts',
            data: data,
            where: whereConditions,
          );
          print('🔍 업데이트 결과: ${result['success']}');
        } else {
          result = await SupabaseAdapter.addData(
            table: 'v2_weekly_schedule_ts',
            data: data,
          );
          print('🔍 추가 결과: ${result['success']}');
        }

        if (result['success'] != true) {
          throw Exception('API 오류: ${result['message'] ?? '알 수 없는 오류'}');
        }
      } catch (e) {
        print('❌ v2_weekly_schedule_ts 테이블 업데이트 오류: $e');
        throw Exception('v2_weekly_schedule_ts 테이블 업데이트 실패: $e');
      }
    }
  }

  // v2_schedule_adjusted_ts 테이블 업데이트 (일별)
  Future<void> _updateDailySchedule(DateTime startDate, DateTime endDate) async {
    DateTime date = startDate;

    while (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) {
      final dayOfWeek = _getWeekdayNumber(date); // 통일된 함수 사용
      final hours = _weeklyHours[dayOfWeek];

      if (hours != null) {
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final dayName = _weekdayNames[dayOfWeek];

        final data = {
          'branch_id': ApiService.getCurrentBranchId(),
          'ts_date': dateString,
          'day_of_week': dayName,
          'business_start': hours['isClosed'] ? null : _formatTimeForDB(hours['startTime']),
          'business_end': hours['isClosed'] ? null : _formatTimeForDB(hours['endTime']),
          'is_holiday': hours['isClosed'] ? 'close' : 'open',
          'is_manually_set': '자동',
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        };

        print('📅 일별 스케줄 저장: $dateString ($dayName) - $data');

        try {
          final whereConditions = [
            {'field': 'branch_id', 'operator': '=', 'value': data['branch_id']},
            {'field': 'ts_date', 'operator': '=', 'value': dateString},
          ];

          print('🔍 조회 조건: $whereConditions');

          // 기존 데이터 확인
          final getResponse = await SupabaseAdapter.getData(
            table: 'v2_schedule_adjusted_ts',
            where: whereConditions,
          );

          print('🔍 기존 데이터 조회 결과: ${getResponse.length}건');

          // 데이터가 있으면 업데이트, 없으면 추가
          Map<String, dynamic> result;
          if (getResponse.isNotEmpty) {
            result = await SupabaseAdapter.updateData(
              table: 'v2_schedule_adjusted_ts',
              data: data,
              where: whereConditions,
            );
            print('🔍 업데이트 결과: ${result['success']}');
          } else {
            result = await SupabaseAdapter.addData(
              table: 'v2_schedule_adjusted_ts',
              data: data,
            );
            print('🔍 추가 결과: ${result['success']}');
          }

          if (result['success'] != true) {
            throw Exception('API 오류: ${result['message'] ?? '알 수 없는 오류'}');
          }
        } catch (e) {
          print('❌ v2_schedule_adjusted_ts 테이블 업데이트 오류: $e');
          throw Exception('v2_schedule_adjusted_ts 테이블 업데이트 실패: $e');
        }
      }

      date = date.add(Duration(days: 1));
    }
  }

  // 요일별 운영시간 설정 위젯
  Widget _buildWeeklyHoursSettings() {
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
            padding: EdgeInsets.all(14), // 18에서 14로 줄임
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Color(0xFF6366F1), size: 20), // 24에서 20으로 줄임
                SizedBox(width: 10),
                Text(
                  '요일별 운영시간',
                  style: TextStyle(
                    fontSize: 16, // 18에서 16으로 줄임 (달력 제목과 같은 크기)
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          // 테이블 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), // 18, 12에서 14, 8로 줄임
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60, // 70에서 60으로 줄임
                  child: Text(
                    '요일',
                    style: TextStyle(
                      fontSize: 14, // 16에서 14로 줄임
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                SizedBox(width: 8), // 12에서 8로 줄임
                Container(
                  width: 70, // 80에서 70으로 줄임
                  child: Text(
                    '시작',
                    style: TextStyle(
                      fontSize: 14, // 16에서 14로 줄임
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 8), // 12에서 8로 줄임
                Container(
                  width: 70, // 80에서 70으로 줄임
                  child: Text(
                    '종료',
                    style: TextStyle(
                      fontSize: 14, // 16에서 14로 줄임
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 10), // 15에서 10으로 줄임
                Text(
                  '휴무',
                  style: TextStyle(
                    fontSize: 14, // 16에서 14로 줄임
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          // 요일별 설정 리스트
          _isLoading
            ? Container(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                  ),
                ),
              )
            : Column(
            children: List.generate(_weekdayNames.length, (index) {
              String weekdayName = _weekdayNames[index];
              // 배열 인덱스를 weekdayNumber로 직접 사용 (0=일요일, 1=월요일, ..., 6=토요일, 7=공휴일)
              int weekdayNumber = index;

              Map<String, dynamic> dayInfo = _weeklyHours[weekdayNumber]!;

              // UI 렌더링 시 디버깅
              print('🖥️ UI 렌더링 - index:$index, 요일:$weekdayName, 데이터: 시작=${dayInfo['startTime']}, 종료=${dayInfo['endTime']}, 휴무=${dayInfo['isClosed']}');

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), // 18, 12에서 14, 8로 줄임
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
                      width: 60, // 70에서 60으로 줄임
                      child: Text(
                        weekdayName,
                        style: TextStyle(
                          fontSize: 14, // 16에서 14로 줄임
                          fontWeight: FontWeight.w600,
                          color: index == 6 ? Color(0xFF2563EB) : // 토요일은 파란색
                                 (index == 0 || index == 7) ? Color(0xFFEF4444) : // 일요일과 공휴일은 빨간색
                                 Color(0xFF374151), // 평일은 기본색
                        ),
                      ),
                    ),
                    SizedBox(width: 8), // 12에서 8로 줄임
                    // 시작시간
                    Container(
                      width: 70, // 80에서 70으로 줄임
                      height: 34, // 38에서 34로 줄임
                      child: TextFormField(
                        key: ValueKey('start_${weekdayNumber}_${dayInfo['startTime']}_${dayInfo['isClosed']}'),
                        initialValue: dayInfo['isClosed'] ? '' : dayInfo['startTime'],
                        enabled: !dayInfo['isClosed'],
                        style: TextStyle(
                          fontSize: 14, // 13에서 14로 1 증가
                          color: dayInfo['isClosed'] ? Color(0xFF9CA3AF) : Color(0xFF374151),
                          fontWeight: FontWeight.bold, // w500에서 bold로 변경
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '09:00',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), // 14에서 12로 줄임
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
                            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6), // 8에서 6으로 줄임
                        ),
                        onChanged: (value) {
                          if (_isValidTime(value)) {
                            setState(() {
                              _weeklyHours[weekdayNumber]!['startTime'] = _formatTime(value);
                            });
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                      ),
                    ),
                    SizedBox(width: 8), // 12에서 8로 줄임
                    // 종료시간
                    Container(
                      width: 70, // 80에서 70으로 줄임
                      height: 34, // 38에서 34로 줄임
                      child: TextFormField(
                        key: ValueKey('end_${weekdayNumber}_${dayInfo['endTime']}_${dayInfo['isClosed']}'),
                        initialValue: dayInfo['isClosed'] ? '' : dayInfo['endTime'],
                        enabled: !dayInfo['isClosed'],
                        style: TextStyle(
                          fontSize: 14, // 13에서 14로 1 증가
                          color: dayInfo['isClosed'] ? Color(0xFF9CA3AF) : Color(0xFF374151),
                          fontWeight: FontWeight.bold, // w500에서 bold로 변경
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '22:00',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), // 14에서 12로 줄임
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
                            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6), // 8에서 6으로 줄임
                        ),
                        onChanged: (value) {
                          if (_isValidTime(value)) {
                            setState(() {
                              _weeklyHours[weekdayNumber]!['endTime'] = _formatTime(value);
                            });
                          }
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                      ),
                    ),
                    SizedBox(width: 10), // 15에서 10으로 줄임
                    // 휴무 체크박스
                    Transform.scale(
                      scale: 0.9, // 1.0에서 0.9로 약간 줄임
                      child: Checkbox(
                        value: dayInfo['isClosed'],
                        onChanged: (bool? value) {
                          setState(() {
                            _weeklyHours[weekdayNumber]!['isClosed'] = value ?? false;
                          });
                        },
                        activeColor: Color(0xFFEF4444),
                        side: BorderSide(
                          color: Color(0xFF374151),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          // 저장 버튼 추가
          Container(
            padding: EdgeInsets.all(14), // 18에서 14로 줄임
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
                    print('🔘 저장 버튼 클릭됨');
                    _saveOperatingHours();
                  },
                  icon: _isSaving 
                    ? SizedBox(
                        width: 16, // 18에서 16으로 줄임
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.save, color: Colors.white, size: 16), // 18에서 16으로 줄임
                  label: Text(
                    _isSaving ? '저장 중...' : '운영시간 저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14, // 16에서 14로 줄임
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6366F1),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 20, 14에서 16, 12로 줄임
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
                Icon(Icons.calendar_today, color: Color(0xFF6366F1), size: 20),
                SizedBox(width: 8),
                Text(
                  '운영시간 달력',
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
                      onPressed: () {
                        final previousYear = _selectedDay.year;
                        setState(() {
                          _selectedDay = DateTime(_selectedDay.year, _selectedDay.month - 1);
                        });
                        // 연도가 바뀌면 공휴일 데이터 새로 로드
                        if (_selectedDay.year != previousYear) {
                          _loadHolidays(_selectedDay.year);
                        }
                      },
                      icon: Icon(Icons.chevron_left, color: Color(0xFF6366F1)),
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
                      onPressed: () {
                        final previousYear = _selectedDay.year;
                        setState(() {
                          _selectedDay = DateTime(_selectedDay.year, _selectedDay.month + 1);
                        });
                        // 연도가 바뀌면 공휴일 데이터 새로 로드
                        if (_selectedDay.year != previousYear) {
                          _loadHolidays(_selectedDay.year);
                        }
                      },
                      icon: Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
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
                                  ? Color(0xFF2563EB)  // 토요일은 파란색
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
                          child: GestureDetector(
                            onTap: date != null ? () => _showDateScheduleDialog(date) : null,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: dayIndex < 6 ? BorderSide(color: Color(0xFFE5E7EB), width: 1) : BorderSide.none,
                                ),
                                color: date != null ? _getCellColor(date) : Colors.transparent,
                              ),
                              child: date != null ? _buildDateContent(date) : Container(),
                            ),
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
      return Color(0xFF6366F1).withOpacity(0.1);
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
    bool isSunday = date.weekday == 7; // 일요일=7
    bool isSaturday = date.weekday == 6; // 토요일=6
    bool isHoliday = _isHoliday(date);
    String? holidayName = _getHolidayName(date);
    
    String operatingHours = _getOperatingHours(date);
    
    // 수동 조정 여부 확인
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    bool isManuallySet = _dailySchedule.containsKey(dateString) && 
                        (_dailySchedule[dateString]!['isManuallySet'] ?? false);
    
    // 날짜 텍스트 색상 결정
    Color dateTextColor;
    if (isSelected) {
      dateTextColor = Color(0xFF6366F1);
    } else if (isToday) {
      dateTextColor = Color(0xFF10B981);
    } else if (isHoliday || isSunday) {
      dateTextColor = Color(0xFFEF4444); // 공휴일과 일요일은 빨간색
    } else if (isSaturday) {
      dateTextColor = Color(0xFF2563EB); // 토요일은 파란색
    } else {
      dateTextColor = Color(0xFF374151); // 평일은 검은색
    }
    
    return Container(
      padding: EdgeInsets.all(6),
      child: Stack(
        children: [
          Column(
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
                        ? Color(0xFFEF4444)  // 휴무: 빨간색
                        : operatingHours == '미설정'
                          ? Color(0xFF9CA3AF)  // 미설정: 회색
                          : Color(0xFF6B7280), // 정상 운영: 기본 회색 (타석과 동일)
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          // 수동 조정 표식
          if (isManuallySet)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDateScheduleDialog(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final dayName = _getWeekdayName(date.weekday);
    
    // 현재 해당 날짜의 운영시간 정보 가져오기
    String currentStartTime = '09:00';
    String currentEndTime = '22:00';
    bool isClosed = false;
    
    // 일별 스케줄에서 먼저 확인
    if (_dailySchedule.containsKey(dateString)) {
      final daySchedule = _dailySchedule[dateString]!;
      isClosed = daySchedule['isClosed'] ?? false;
      if (!isClosed) {
        currentStartTime = daySchedule['startTime'] ?? '09:00';
        currentEndTime = daySchedule['endTime'] ?? '22:00';
      }
    } else {
      // 주간 스케줄에서 가져오기
      int weekday = _getWeekdayNumber(date);
      Map<String, dynamic> dayInfo = _weeklyHours[weekday]!;
      isClosed = dayInfo['isClosed'] ?? false;
      if (!isClosed) {
        currentStartTime = dayInfo['startTime'] ?? '09:00';
        currentEndTime = dayInfo['endTime'] ?? '22:00';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => DateScheduleDialog(
        date: date,
        dateString: dateString,
        dayName: dayName,
        initialStartTime: currentStartTime,
        initialEndTime: currentEndTime,
        initialIsClosed: isClosed,
        onSave: (startTime, endTime, isClosed) async {
          await _saveDateSchedule(date, startTime, endTime, isClosed);
        },
      ),
    );
  }

  // 특정 날짜의 스케줄 저장
  Future<void> _saveDateSchedule(DateTime date, String startTime, String endTime, bool isClosed) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final dayName = _getWeekdayName(date.weekday);

      print('📅 날짜별 스케줄 저장 시작: $dateString ($dayName)');

      // 예약 충돌 확인 먼저 수행
      final hasConflicts = await _checkSingleDateReservationConflicts(date, startTime, endTime, isClosed);
      if (hasConflicts) {
        _showErrorSnackBar('예약이 있는 경우 조정이 불가합니다');
        return;
      }

      final data = {
        'branch_id': ApiService.getCurrentBranchId(),
        'ts_date': dateString,
        'day_of_week': dayName,
        'business_start': isClosed ? null : _formatTimeForDB(startTime),
        'business_end': isClosed ? null : _formatTimeForDB(endTime),
        'is_holiday': isClosed ? 'close' : 'open',
        'is_manually_set': '수동조정',
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('💾 날짜별 스케줄 저장 요청: $data');

      final whereConditions = [
        {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        {'field': 'ts_date', 'operator': '=', 'value': dateString},
      ];

      // 기존 데이터가 있는지 확인
      final checkResponse = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_ts',
        where: whereConditions,
      );

      print('📋 기존 데이터 확인: ${checkResponse.length}개');

      Map<String, dynamic> result;
      if (checkResponse.isNotEmpty) {
        // 기존 데이터가 있으면 업데이트
        result = await SupabaseAdapter.updateData(
          table: 'v2_schedule_adjusted_ts',
          data: data,
          where: whereConditions,
        );
        print('🔍 업데이트 결과: ${result['success']}');

        if (result['success'] == true) {
          print('✅ 날짜별 스케줄 업데이트 성공');
        } else {
          throw Exception('날짜별 스케줄 업데이트 실패: ${result['message'] ?? '알 수 없는 오류'}');
        }
      } else {
        // 기존 데이터가 없으면 새로 추가
        result = await SupabaseAdapter.addData(
          table: 'v2_schedule_adjusted_ts',
          data: data,
        );
        print('🔍 추가 결과: ${result['success']}');

        if (result['success'] == true) {
          print('✅ 날짜별 스케줄 추가 성공');
        } else {
          throw Exception('날짜별 스케줄 추가 실패: ${result['message'] ?? '알 수 없는 오류'}');
        }
      }

      // 로컬 데이터 업데이트
      setState(() {
        _dailySchedule[dateString] = {
          'startTime': isClosed ? null : startTime,
          'endTime': isClosed ? null : endTime,
          'isClosed': isClosed,
          'isManuallySet': true,
        };
      });

      _showSuccessSnackBar('${dateString} 운영시간이 저장되었습니다');

    } catch (e) {
      print('❌ 날짜별 스케줄 저장 오류: $e');
      _showErrorSnackBar('날짜별 스케줄 저장 실패: ${e.toString()}');
    }
  }

  // 개별 날짜 예약 충돌 확인 함수 추가
  Future<bool> _checkSingleDateReservationConflicts(DateTime date, String newStartTime, String newEndTime, bool willBeClosed) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      print('개별 날짜 예약 충돌 확인: $dateString');
      
      // 예약 데이터 조회
      final reservations = await ApiService.getPricedTsData(
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
          {'field': 'ts_date', 'operator': '=', 'value': dateString},
          {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
        ],
      );
      
      print('$dateString 예약 조회 결과: ${reservations.length}개');
      
      if (reservations.isEmpty) {
        return false; // 예약이 없으면 충돌 없음
      }
      
      // 휴무로 변경되는 경우 모든 예약이 충돌
      if (willBeClosed) {
        print('휴무로 변경되어 모든 예약과 충돌');
        return true;
      }
      
      // 운영시간 변경 시 충돌 확인
      for (var reservation in reservations) {
        final tsStart = reservation['ts_start'] ?? '';
        final tsEnd = reservation['ts_end'] ?? '';
        
        if (tsStart.isEmpty || tsEnd.isEmpty) continue;
        
        final reservationStart = _parseTime(tsStart);
        final reservationEnd = _parseTime(tsEnd);
        final newStart = _parseTime(newStartTime);
        final newEnd = _parseTime(newEndTime);
        
        // 예약 시간이 새로운 운영시간 범위를 벗어나는지 체크
        if (reservationStart < newStart || reservationEnd > newEnd) {
          print('예약 시간 충돌: $tsStart-$tsEnd vs $newStartTime-$newEndTime');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('개별 날짜 예약 충돌 확인 실패: $e');
      return false; // 오류 시 충돌 없음으로 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Row(
            children: [
              ButtonDesignUpper.buildHelpTooltip(
                message: '설정된 운영시간에 따라 고객이 앱에서 타석예약을 할 수 있습니다',
                iconSize: 20.0,
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
              // 왼쪽: 요일별 운영시간 설정
              Container(
                width: 320,
                child: _buildWeeklyHoursSettings(),
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

// 날짜별 운영시간 수정 다이얼로그
class DateScheduleDialog extends StatefulWidget {
  final DateTime date;
  final String dateString;
  final String dayName;
  final String initialStartTime;
  final String initialEndTime;
  final bool initialIsClosed;
  final Function(String, String, bool) onSave;

  const DateScheduleDialog({
    super.key,
    required this.date,
    required this.dateString,
    required this.dayName,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.initialIsClosed,
    required this.onSave,
  });

  @override
  State<DateScheduleDialog> createState() => _DateScheduleDialogState();
}

class _DateScheduleDialogState extends State<DateScheduleDialog> {
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late bool _isClosed;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimeController = TextEditingController(text: widget.initialStartTime);
    _endTimeController = TextEditingController(text: widget.initialEndTime);
    _isClosed = widget.initialIsClosed;
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onSave(
        _startTimeController.text,
        _endTimeController.text,
        _isClosed,
      );
      Navigator.of(context).pop();
    } catch (e) {
      // 에러는 부모에서 처리됨
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 400,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_calendar,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '운영시간 수정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${widget.dateString} (${widget.dayName})',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // 휴무 체크박스
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _isClosed,
                    onChanged: (value) {
                      setState(() {
                        _isClosed = value ?? false;
                      });
                    },
                    activeColor: Color(0xFFEF4444),
                  ),
                  Text(
                    '휴무',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // 운영시간 설정
            if (!_isClosed) ...[
              Text(
                '운영시간',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '시작시간',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _startTimeController,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                          decoration: InputDecoration(
                            hintText: '09:00',
                            filled: true,
                            fillColor: Colors.white,
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
                              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '종료시간',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _endTimeController,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                          decoration: InputDecoration(
                            hintText: '22:00',
                            filled: true,
                            fillColor: Colors.white,
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
                              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            
            SizedBox(height: 24),
            
            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6366F1),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 