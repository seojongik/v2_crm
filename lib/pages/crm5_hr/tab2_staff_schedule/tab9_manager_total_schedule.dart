import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';

class ManagerTotalScheduleDialog extends StatefulWidget {
  final DateTime selectedMonth;
  final Map<String, Map<String, dynamic>> businessHours;
  final Map<String, List<Map<String, dynamic>>> allStaffSchedules;
  final List<Map<String, dynamic>> managerList;

  const ManagerTotalScheduleDialog({
    Key? key,
    required this.selectedMonth,
    required this.businessHours,
    required this.allStaffSchedules,
    required this.managerList,
  }) : super(key: key);

  @override
  State<ManagerTotalScheduleDialog> createState() => _ManagerTotalScheduleDialogState();
}

class _ManagerTotalScheduleDialogState extends State<ManagerTotalScheduleDialog> {
  Map<String, bool> _selectedManagers = {};
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = false;
  bool _showUnmanned = true; // 무인운영 표시 여부
  
  List<Color> _managerColors = [
    Color(0xFF3B82F6), // 파랑
    Color(0xFF10B981), // 초록
    Color(0xFF8B5CF6), // 보라
    Color(0xFFF59E0B), // 주황
    Color(0xFF06B6D4), // 하늘
    Color(0xFFEC4899), // 분홍
    Color(0xFF84CC16), // 라임
    Color(0xFF6366F1), // 인디고
    Color(0xFF14B8A6), // 청록
    Color(0xFF8B5CF6), // 보라
  ];
  
  // 현재 표시중인 데이터
  Map<String, Map<String, dynamic>> _currentBusinessHours = {};
  Map<String, List<Map<String, dynamic>>> _currentAllStaffSchedules = {};

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.selectedMonth;
    
    // 모든 매니저를 기본으로 선택
    for (var manager in widget.managerList) {
      final managerName = manager['manager_name'] ?? '';
      _selectedManagers[managerName] = true;
    }
    
    // 현재 월의 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthData(_currentMonth);
    });
  }

  // 월 변경시 데이터 로드
  Future<void> _loadMonthData(DateTime month) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final branchId = ApiService.getCurrentBranchId();
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      
      final firstDateStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDateStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
      
      
      // 영업시간 로드 (Supabase)
      final businessData = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_ts',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_date', 'operator': '>=', 'value': firstDateStr},
          {'field': 'ts_date', 'operator': '<=', 'value': lastDateStr},
        ],
        orderBy: [
          {'field': 'ts_date', 'direction': 'ASC'}
        ],
      );

      Map<String, Map<String, dynamic>> businessHours = {};
      for (var business in businessData) {
        final dateStr = business['ts_date'];
        final isHoliday = business['is_holiday'] == 'close';
        final businessStart = business['business_start'] ?? '';
        final businessEnd = business['business_end'] ?? '';

        businessHours[dateStr] = {
          'isHoliday': isHoliday,
          'businessStart': businessStart,
          'businessEnd': businessEnd,
        };
      }

      // 직원 스케줄 로드 (Supabase)
      final scheduleData = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_manager',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'scheduled_date', 'operator': '>=', 'value': firstDateStr},
          {'field': 'scheduled_date', 'operator': '<=', 'value': lastDateStr},
        ],
        orderBy: [
          {'field': 'scheduled_date', 'direction': 'ASC'},
          {'field': 'manager_name', 'direction': 'ASC'}
        ],
      );

      Map<String, List<Map<String, dynamic>>> allStaffSchedules = {};
      for (var schedule in scheduleData) {
        final dateStr = schedule['scheduled_date'];
        final managerName = schedule['manager_name'];
        final isDayOff = schedule['is_day_off'] == '휴무';
        final workStart = schedule['work_start'] ?? '';
        final workEnd = schedule['work_end'] ?? '';

        if (!allStaffSchedules.containsKey(dateStr)) {
          allStaffSchedules[dateStr] = [];
        }

        allStaffSchedules[dateStr]!.add({
          'managerName': managerName,
          'isDayOff': isDayOff,
          'workStart': workStart,
          'workEnd': workEnd,
        });
      }

      setState(() {
        _currentBusinessHours = businessHours;
        _currentAllStaffSchedules = allStaffSchedules;
        _currentMonth = month;
        _isLoading = false;
      });

      print('✅ ${month.year}년 ${month.month}월 데이터 로드 완료');
    } catch (e) {
      print('❌ ${month.year}년 ${month.month}월 데이터 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 매니저별 색상 가져오기
  Color _getManagerColor(String managerName) {
    final index = widget.managerList.indexWhere((m) => m['manager_name'] == managerName);
    return index >= 0 && index < _managerColors.length 
        ? _managerColors[index] 
        : Colors.grey;
  }

  // 특정 날짜의 전체 스케줄 생성
  List<Widget> _buildDaySchedule(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    
    final businessHour = _currentBusinessHours[dateString];
    final staffSchedules = _currentAllStaffSchedules[dateString] ?? [];

    // 해당 날짜의 데이터가 없으면 빈 위젯 반환 (다른 달 날짜)
    if (businessHour == null) {
      return [];
    }

    List<Widget> scheduleWidgets = [];

    final businessStart = businessHour['businessStart'] ?? '';
    final businessEnd = businessHour['businessEnd'] ?? '';
    final isHoliday = businessHour['isHoliday'] == true;

    // 영업시간이 없거나 휴무인 경우
    if (businessHour == null || isHoliday) {
      scheduleWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          margin: EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '휴무',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
      return scheduleWidgets;
    }

    // 영업시간이 설정되지 않은 경우 (휴무가 아닌데 시간이 없음)
    if (businessStart.isEmpty || businessEnd.isEmpty) {
      scheduleWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          margin: EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '시간 미설정',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
      return scheduleWidgets;
    }

    // 실제 근무하는 직원들 (체크박스 선택과 무관하게 모든 근무 직원)
    final allWorkingStaff = staffSchedules.where((staff) {
      final isDayOff = staff['isDayOff'];
      return !isDayOff;
    }).toList();

    // 시간대별 스케줄 생성 (무인운영 계산용 - 모든 근무 직원 기준)
    final timeSlots = _createTimeSlots(businessStart, businessEnd, allWorkingStaff);
    
    for (var slot in timeSlots) {
      final isUnmanned = slot['isUnmanned'] ?? false;
      final staffName = slot['staffName'] ?? '';
      final timeRange = slot['timeRange'] ?? '';
      
      // 무인운영과 직원 근무시간 필터링
      if ((isUnmanned && _showUnmanned) || (!isUnmanned && _selectedManagers[staffName] == true)) {
        scheduleWidgets.add(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            margin: EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: isUnmanned
                ? Colors.transparent
                : _getManagerColor(staffName).withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              isUnmanned ? '$timeRange 무인운영' : '$timeRange $staffName',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isUnmanned ? Colors.grey[600] : Colors.white,
              ),
            ),
          ),
        );
      }
    }

    return scheduleWidgets;
  }

  // 시간대별 슬롯 생성 함수
  List<Map<String, dynamic>> _createTimeSlots(String businessStart, String businessEnd, List<dynamic> workingStaff) {
    List<Map<String, dynamic>> slots = [];
    
    // 영업시간을 분 단위로 변환
    int businessStartMinutes = _timeToMinutes(businessStart);
    int businessEndMinutes = _timeToMinutes(businessEnd);
    
    // 직원별 근무시간을 분 단위로 변환
    List<Map<String, dynamic>> staffSchedules = [];
    for (var staff in workingStaff) {
      final workStart = staff['workStart'] ?? '';
      final workEnd = staff['workEnd'] ?? '';
      if (workStart.isNotEmpty && workEnd.isNotEmpty) {
        staffSchedules.add({
          'name': staff['managerName'],
          'startMinutes': _timeToMinutes(workStart),
          'endMinutes': _timeToMinutes(workEnd),
        });
      }
    }
    
    // 시간순으로 정렬
    staffSchedules.sort((a, b) => a['startMinutes'].compareTo(b['startMinutes']));
    
    int currentMinutes = businessStartMinutes;
    
    for (var schedule in staffSchedules) {
      int staffStart = schedule['startMinutes'];
      int staffEnd = schedule['endMinutes'];
      String staffName = schedule['name'];
      
      // 무인운영 시간이 있으면 추가
      if (currentMinutes < staffStart) {
        slots.add({
          'timeRange': '${_minutesToTime(currentMinutes)}-${_minutesToTime(staffStart)}',
          'isUnmanned': true,
        });
      }
      
      // 직원 근무 시간 추가
      slots.add({
        'timeRange': '${_minutesToTime(staffStart)}-${_minutesToTime(staffEnd)}',
        'staffName': staffName,
        'isUnmanned': false,
      });
      
      currentMinutes = staffEnd > currentMinutes ? staffEnd : currentMinutes;
    }
    
    // 직원이 없는 경우 전체 시간 무인운영, 있는 경우 마지막 무인운영 시간 확인
    if (staffSchedules.isEmpty) {
      slots.add({
        'timeRange': '${_minutesToTime(businessStartMinutes)}-${_minutesToTime(businessEndMinutes)}',
        'isUnmanned': true,
      });
    } else if (currentMinutes < businessEndMinutes) {
      slots.add({
        'timeRange': '${_minutesToTime(currentMinutes)}-${_minutesToTime(businessEndMinutes)}',
        'isUnmanned': true,
      });
    }
    
    return slots;
  }
  
  // 시간을 분으로 변환
  int _timeToMinutes(String time) {
    if (time.isEmpty) return 0;
    final parts = time.split(':');
    if (parts.length >= 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
  }
  
  // 분을 시간으로 변환
  String _minutesToTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // 시간 포맷팅
  String _formatTime(String time) {
    if (time.isEmpty) return '00:00';
    if (time.contains(':')) {
      final parts = time.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
    }
    return time;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        width: screenSize.width * 0.63,
        height: screenSize.height * 0.75,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.calendar_view_month, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 12),
                Text(
                  '전체일정 조회',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(width: 24),
                // 월 네비게이션
                Row(
                  children: [
                    IconButton(
                      onPressed: _isLoading ? null : () async {
                        final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        await _loadMonthData(previousMonth);
                      },
                      icon: Icon(Icons.chevron_left, color: _isLoading ? Colors.grey : Color(0xFF10B981)),
                      iconSize: 24,
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentMonth.year}년 ${_currentMonth.month}월',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : () async {
                        final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        await _loadMonthData(nextMonth);
                      },
                      icon: Icon(Icons.chevron_right, color: _isLoading ? Colors.grey : Color(0xFF10B981)),
                      iconSize: 24,
                    ),
                  ],
                ),
                Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                SizedBox(width: 12),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 직원 선택 체크박스
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '직원 선택',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // 무인운영 체크박스
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showUnmanned = !_showUnmanned;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _showUnmanned ? Colors.orange[300] : Colors.white,
                                border: Border.all(color: Colors.orange[300]!, width: 2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: _showUnmanned
                                  ? Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '무인운영',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 직원 체크박스들
                      ...widget.managerList.map((manager) {
                        final managerName = manager['manager_name'] ?? '';
                        final color = _getManagerColor(managerName);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedManagers[managerName] = !(_selectedManagers[managerName] ?? false);
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _selectedManagers[managerName] == true ? color : Colors.white,
                                  border: Border.all(color: color, width: 2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: _selectedManagers[managerName] == true
                                    ? Icon(Icons.check, size: 12, color: Colors.white)
                                    : null,
                              ),
                              SizedBox(width: 8),
                              Text(
                                managerName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // 달력
            Expanded(
              child: _buildFullCalendar(),
            ),
          ],
        ),
      ),
    );
  }

  // 전체 달력 위젯 생성
  Widget _buildFullCalendar() {
    DateTime firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    DateTime lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    int firstWeekday = firstDayOfMonth.weekday % 7;

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
      currentWeek.add(DateTime(_currentMonth.year, _currentMonth.month, day));
    }
    
    // 마지막 주 완성
    while (currentWeek.length < 7) {
      currentWeek.add(null);
    }
    weeks.add(currentWeek);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFE5E7EB), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 요일 헤더
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
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
                          fontSize: 14,
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
              children: weeks.map((week) {
                // 이 주의 최대 스케줄 개수 계산
                int maxSchedulesInWeek = 0;
                for (var date in week) {
                  if (date != null) {
                    int scheduleCount = _buildDaySchedule(date).length;
                    if (scheduleCount > maxSchedulesInWeek) {
                      maxSchedulesInWeek = scheduleCount;
                    }
                  }
                }
                
                // 최소 높이 보장하고, 스케줄이 많으면 높이 증가
                double weekHeight = 80.0 + (maxSchedulesInWeek > 3 ? (maxSchedulesInWeek - 3) * 20.0 : 0.0);
                
                return Container(
                  height: weekHeight,
                  child: Row(
                    children: week.asMap().entries.map((entry) {
                      int dayIndex = entry.key;
                      DateTime? date = entry.value;
                      
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: dayIndex < 6 ? BorderSide(color: Color(0xFFE5E7EB), width: 1) : BorderSide.none,
                              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                            ),
                          ),
                          child: date != null ? _buildCalendarCell(date) : Container(),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 달력 셀 내용
  Widget _buildCalendarCell(DateTime date) {
    bool isSunday = date.weekday == 7;
    bool isSaturday = date.weekday == 6;
    
    Color dateTextColor = isSunday 
        ? Color(0xFFEF4444) 
        : isSaturday 
          ? Color(0xFF2563EB)
          : Color(0xFF374151);

    final scheduleWidgets = _buildDaySchedule(date);

    return Container(
      padding: EdgeInsets.all(2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 날짜 영역 (고정 너비)
          Container(
            width: 16,
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: dateTextColor,
              ),
            ),
          ),
          // 구분선
          Container(
            width: 1,
            height: double.infinity,
            color: Colors.white,
            margin: EdgeInsets.symmetric(horizontal: 2),
          ),
          // 오른쪽: 스케줄 영역
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: scheduleWidgets,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 전체일정 조회 기능을 위한 헬퍼 클래스
class TotalScheduleHelper {
  // 영업시간 데이터 로드 (v2_schedule_adjusted_ts) - Supabase
  static Future<Map<String, Map<String, dynamic>>> loadBusinessHours(DateTime selectedMonth) async {
    Map<String, Map<String, dynamic>> businessHours = {};

    try {
      final branchId = ApiService.getCurrentBranchId();

      final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      final firstDateStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDateStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final businessData = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_ts',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'ts_date', 'operator': '>=', 'value': firstDateStr},
          {'field': 'ts_date', 'operator': '<=', 'value': lastDateStr},
        ],
        orderBy: [
          {'field': 'ts_date', 'direction': 'ASC'}
        ],
      );

      for (var business in businessData) {
        final dateStr = business['ts_date'];
        final isHoliday = business['is_holiday'] == 'close';
        final businessStart = business['business_start'] ?? '';
        final businessEnd = business['business_end'] ?? '';

        businessHours[dateStr] = {
          'isHoliday': isHoliday,
          'businessStart': businessStart,
          'businessEnd': businessEnd,
        };
      }

      print('✅ 영업시간 로드 완료');
    } catch (e) {
      print('❌ 영업시간 로드 실패: $e');
    }

    return businessHours;
  }

  // 모든 직원 스케줄 데이터 로드 - Supabase
  static Future<Map<String, List<Map<String, dynamic>>>> loadAllStaffSchedules(DateTime selectedMonth) async {
    Map<String, List<Map<String, dynamic>>> allStaffSchedules = {};

    try {
      final branchId = ApiService.getCurrentBranchId();

      final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      final firstDateStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDateStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final scheduleData = await SupabaseAdapter.getData(
        table: 'v2_schedule_adjusted_manager',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'scheduled_date', 'operator': '>=', 'value': firstDateStr},
          {'field': 'scheduled_date', 'operator': '<=', 'value': lastDateStr},
        ],
        orderBy: [
          {'field': 'scheduled_date', 'direction': 'ASC'},
          {'field': 'manager_name', 'direction': 'ASC'}
        ],
      );

      for (var schedule in scheduleData) {
        final dateStr = schedule['scheduled_date'];
        final managerName = schedule['manager_name'];
        final isDayOff = schedule['is_day_off'] == '휴무';
        final workStart = schedule['work_start'] ?? '';
        final workEnd = schedule['work_end'] ?? '';

        if (!allStaffSchedules.containsKey(dateStr)) {
          allStaffSchedules[dateStr] = [];
        }

        allStaffSchedules[dateStr]!.add({
          'managerName': managerName,
          'isDayOff': isDayOff,
          'workStart': workStart,
          'workEnd': workEnd,
        });
      }

      print('✅ 모든 직원 스케줄 로드 완료 - ${allStaffSchedules.length}개 날짜');
    } catch (e) {
      print('❌ 모든 직원 스케줄 로드 실패: $e');
    }

    return allStaffSchedules;
  }

  // 전체일정 다이얼로그 표시
  static Future<void> showAllScheduleDialog(BuildContext context, {
    required DateTime selectedMonth,
    required List<Map<String, dynamic>> managerList,
  }) async {
    // 데이터 로드
    final businessHours = await loadBusinessHours(selectedMonth);
    final allStaffSchedules = await loadAllStaffSchedules(selectedMonth);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ManagerTotalScheduleDialog(
          selectedMonth: selectedMonth,
          businessHours: businessHours,
          allStaffSchedules: allStaffSchedules,
          managerList: managerList,
        );
      },
    );
  }
}