import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/models/ts_reservation.dart';
import '/services/api_service.dart';
import '/services/calendar_format_service.dart';
import '/services/holiday_service.dart';
import '/services/upper_button_input_design.dart';
import '/pages/crm9_setting/crm9_setting_widget.dart';
import '/pages/crm9_setting/crm9_setting_model.dart';
import 'crm3_ts_control_ts_open.dart';
import 'crm3_ts_control.dart';
import 'ts_current_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'crm3_ts_model.dart';
export 'crm3_ts_model.dart';
import '../../constants/font_sizes.dart';

class Crm3TsWidget extends StatefulWidget {
  const Crm3TsWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  static String routeName = 'crm3_ts';
  static String routePath = 'crm3Ts';

  @override
  State<Crm3TsWidget> createState() => _Crm3TsWidgetState();
}

class _Crm3TsWidgetState extends State<Crm3TsWidget> {
  late Crm3TsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 시간표 설정
  static const double timeColWidth = 70; // 시간 열 너비
  static const double bayColWidth = 120; // 타석 열 너비 (원래대로)
  static const double rowHeight = 60; // 행 높이
  static const double headerHeight = 40; // 헤더 높이
  
  // 공휴일 데이터 저장
  Map<String, Map<String, dynamic>> _scheduleData = {};
  bool _isLoadingSchedule = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm3TsModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
    
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _model.loadTsReservations();
      _loadScheduleData();
    });
  }

  // 스케줄 데이터 로드 (공휴일 포함)
  Future<void> _loadScheduleData() async {
    setState(() {
      _isLoadingSchedule = true;
    });

    try {
      final year = _model.selectedDate.year;
      final holidays = await HolidayService.getHolidays(year);
      
      Map<String, Map<String, dynamic>> scheduleData = {};
      
      for (String holidayDate in holidays) {
        scheduleData[holidayDate] = {
          'is_holiday': 'close',
          'holiday_name': HolidayService.getHolidayName(DateTime.parse(holidayDate)) ?? '공휴일',
        };
      }
      
      setState(() {
        _scheduleData = scheduleData;
        _isLoadingSchedule = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSchedule = false;
      });
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // 시간표 높이 계산
  double _calculateTimetableHeight() {
    return 800.0; // 항상 고정 높이 반환
  }


  // 예약 박스 높이 계산 (정확한 분 단위)
  double _getReservationHeight(String startTime, String endTime) {
    try {
      // 시간을 분 단위로 변환
      final startMinutes = _timeStringToMinutes(startTime);
      final endMinutes = _timeStringToMinutes(endTime);
      
      // 자정을 넘어가는 경우 처리
      int durationMinutes;
      if (endMinutes >= startMinutes) {
        durationMinutes = endMinutes - startMinutes;
      } else {
        // 자정을 넘어가는 경우 (예: 23:30 ~ 01:30)
        durationMinutes = (24 * 60) - startMinutes + endMinutes;
      }
      
      // 분 단위를 픽셀로 변환 (1시간 = 60분 = rowHeight 픽셀)
      final height = (durationMinutes / 60.0) * rowHeight;
      
      // 최소 높이 보장 (15분 = 15픽셀 최소)
      final finalHeight = height.clamp(15.0, 300.0);
      
      // print('예약 높이 계산: $startTime-$endTime, ${durationMinutes}분, ${finalHeight}px');
      
      return finalHeight;
    } catch (e) {
      // print('예약 높이 계산 오류: $startTime-$endTime - $e');
      return 60.0; // 기본 1시간 높이
    }
  }

  // 시간 문자열을 분 단위로 변환
  int _timeStringToMinutes(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF8FAFC),
        body: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (responsiveVisibility(
              context: context,
              phone: false,
            ))
              wrapWithModel(
                model: _model.sideBarNavModel,
                updateCallback: () => safeSetState(() {}),
                child: SideBarNavWidget(
                  currentPage: 'crm3_ts',
                  onNavigate: (String routeName) {
                    widget.onNavigate?.call(routeName);
                  },
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (responsiveVisibility(
                    context: context,
                    tabletLandscape: false,
                    desktop: false,
                  ))
                    Container(
                      width: double.infinity,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8.0,
                              color: Color(0x1A000000),
                              offset: Offset(0.0, 2.0),
                            )
                          ],
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 헤더 섹션
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16.0),
                                  topRight: Radius.circular(16.0),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 왼쪽: 날짜 선택 및 오늘 버튼
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 날짜 필드
                                        InkWell(
                                          onTap: () async {
                                            await _showCalendarDialog();
                                          },
                                          child: Container(
                                            height: 48.0,
                                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8.0),
                                              border: Border.all(
                                                color: Color(0xFFE2E8F0),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  color: Color(0xFF64748B),
                                                  size: 18.0,
                                                ),
                                                SizedBox(width: 8.0),
                                                Text(
                                                  DateFormat('yyyy-MM-dd').format(_model.selectedDate),
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFF1E293B),
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12.0),
                                        // 오늘 버튼
                                        ButtonDesignUpper.buildTextButton(
                                          text: '오늘',
                                          onPressed: () {
                                            _model.goToToday();
                                          },
                                          color: 'blue',
                                          size: 'large',
                                        ),
                                      ],
                                    ),
                                    // 오른쪽: 설정 버튼들
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ButtonDesignUpper.buildIconButton(
                                          text: '현재타석',
                                          icon: Icons.grid_view,
                                          onPressed: () => _showCurrentStatusDialog(),
                                          color: _isToday() ? 'red' : 'cyan',
                                          size: 'large',
                                        ),
                                        SizedBox(width: 12.0),
                                        ButtonDesignUpper.buildIconButton(
                                          text: '타석설정',
                                          icon: Icons.settings,
                                          onPressed: () => _navigateToTsSetting(),
                                          color: 'gray',
                                          size: 'large',
                                        ),
                                        SizedBox(width: 12.0),
                                        ButtonDesignUpper.buildIconButton(
                                          text: '운영시간',
                                          icon: Icons.schedule,
                                          onPressed: () => _navigateToOperatingHours(),
                                          color: 'gray',
                                          size: 'large',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 시간표 섹션
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(24.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _model,
                                    builder: (context, child) {
                                      return _model.isLoading
                                          ? Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF3B82F6),
                                              ),
                                            )
                                          : _model.errorMessage != null
                                              ? _buildErrorMessage()
                                              : _model.isHoliday 
                                                  ? _buildHolidayMessage()
                                                  : _hasRequiredData()
                                                    ? _buildTimetable()
                                                    : _buildErrorMessage();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                        ),
                      ),
                  ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시간표 위젯 빌드
  Widget _buildTimetable() {
    final totalBays = _model.bayNumbers.isNotEmpty ? _model.bayNumbers.length : 9;
    final now = DateTime.now();
    final isToday = _isToday();

    // 영업시간 파싱해서 총 시간 계산
    final startHour = _parseBusinessHour(_model.businessStart ?? '09:00:00');
    final endHour = _parseBusinessHour(_model.businessEnd ?? '22:00:00');
    int totalHours;
    if (endHour > startHour) {
      totalHours = endHour - startHour;
    } else {
      totalHours = (24 - startHour) + endHour;
    }
    totalHours = totalHours.clamp(1, 20);

    final timetableHeight = 40.0 + (totalHours * 60.0); // 헤더 + 시간행들

    print('📏 시간표 높이: 컨테이너 600px, 실제 콘텐츠 ${timetableHeight}px → 스크롤 ${timetableHeight > 600 ? '가능' : '불필요'}');

    return Container(
      width: double.infinity,
      height: 600, // 고정 높이 설정으로 스크롤 영역 확보
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: 70 + (totalBays * 120), // 시간열(70) + 타석열들(120씩)
            child: Stack(
              children: [
                // 기본 시간표 그리드
                _buildTimetableGrid(),
                
                // 예약 박스들 (정확한 시간 포지셔닝)
                ..._buildReservationBoxes(),
                
                // 현재 시간선 (오늘인 경우만)
                if (isToday && 
                    _model.businessStart != null && 
                    _model.businessEnd != null &&
                    _isWithinBusinessHours(now))
                  _buildCurrentTimeLine(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 시간표 그리드 빌드 (Stack 구조용)
  Widget _buildTimetableGrid() {
    final totalBays = _model.bayNumbers.isNotEmpty ? _model.bayNumbers.length : 9;
    
    // 영업시간 파싱 (기본값: 9시-22시)
    final startHour = _parseBusinessHour(_model.businessStart ?? '09:00:00');
    final endHour = _parseBusinessHour(_model.businessEnd ?? '22:00:00');
    
    // 총 시간 수 계산 (최대 14시간으로 제한)
    int totalHours;
    if (endHour > startHour) {
      totalHours = endHour - startHour;
    } else {
      totalHours = (24 - startHour) + endHour;
    }
    totalHours = totalHours.clamp(1, 20); // 최소 1시간, 최대 20시간 (24시간 영업 대응)

    // 시간표 범위 로그 출력
    print('📊 시간표 생성 - 세로축(시간): ${startHour}시~${endHour}시 (총 ${totalHours}시간)');
    print('📊 시간표 생성 - 가로축(타석): ${_model.bayNumbers} (총 ${totalBays}개 타석)');
    
    return Container(
      width: 70 + (totalBays * 120), // 고정 너비
      height: 40 + (totalHours * 60), // 헤더(40) + 시간행들(60씩)
      child: Column(
        children: [
          // 헤더
          _buildTimetableHeader(totalBays),
          
          // 시간 행들
          ...List.generate(totalHours, (i) {
            final hour = (startHour + i) % 24;
            if (i == 0) print('⏰ 시간표 행 생성 시작: ${hour}시부터');
            if (i == totalHours - 1) print('⏰ 시간표 행 생성 종료: ${hour}시까지');
            return _buildTimetableRow(hour, totalBays);
          }),
        ],
      ),
    );
  }
  
  // 영업시간 문자열을 시간으로 파싱
  int _parseBusinessHour(String timeStr) {
    final parts = timeStr.split(':');
    return int.tryParse(parts[0]) ?? 9;
  }

  // 시간 위치를 정확하게 계산 (분 단위까지 고려)
  double _getTimePosition(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      // 영업시간 시작 시간 기준으로 계산
      final startHour = _parseBusinessHour(_model.businessStart ?? '09:00:00');
      
      // 시작 시간으로부터의 차이 계산 (시간 단위)
      double hourDiff = (hour - startHour).toDouble();
      if (hourDiff < 0) hourDiff += 24; // 자정 넘어가는 경우
      
      // 분 단위를 시간 단위로 변환하여 추가
      final minuteInHours = minute / 60.0;
      
      // 최종 위치 계산: 헤더(40) + (시간차이 + 분비율) * 행높이(60)
      final position = headerHeight + ((hourDiff + minuteInHours) * rowHeight);
      
      // print('시간 위치 계산: $timeStr -> ${hour}시 ${minute}분 -> 위치: ${position}px');
      return position;
    } catch (e) {
      print('시간 파싱 오류: $timeStr - $e');
      return headerHeight;
    }
  }

  Widget _buildTimetableHeader(int totalBays) {
    return Container(
      height: headerHeight,
      child: Row(
        children: [
          // 시간 컬럼 헤더
          Container(
            width: timeColWidth,
            height: headerHeight,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(
                right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
          ),
          // 베이 헤더들
          ...List.generate(totalBays, (index) {
            final bayNumber = _model.bayNumbers.isNotEmpty && index < _model.bayNumbers.length 
                ? _model.bayNumbers[index] 
                : index + 1;
            return Container(
              width: bayColWidth,
              height: headerHeight,
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6), // 옅은 회색
                border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_golf,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$bayNumber번',
                      style: AppTextStyles.formLabel.copyWith(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimetableRow(int hour, int totalBays) {
    return Container(
      height: rowHeight,
      child: Row(
        children: [
          // 시간 표시
          Container(
            width: timeColWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              color: Color(0xFFF9FAFB), // 더 고급스러운 연한 그레이
              border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
            ),
            child: Center(
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: AppTextStyles.formLabel.copyWith(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // 베이 셀들
          ...List.generate(totalBays, (index) {
            final bayNumber = _model.bayNumbers.isNotEmpty && index < _model.bayNumbers.length 
                ? _model.bayNumbers[index] 
                : index + 1;
            return GestureDetector(
              onTapDown: (details) {
                // 셀 내에서의 클릭 위치를 기반으로 시간 계산
                final localY = details.localPosition.dy;
                final minutes = (localY / rowHeight * 60).round();
                final roundedMinutes = (minutes ~/ 5) * 5; // 5분 단위로 반올림
                _handleEmptySlotClick(bayNumber, hour, roundedMinutes);
              },
              child: Container(
                width: bayColWidth,
                height: rowHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 예약 박스들 빌드
  List<Widget> _buildReservationBoxes() {
    final filteredReservations = _model.getFilteredReservations();
    
    return filteredReservations.map((reservation) {
      return _buildReservationBox(reservation);
    }).toList();
  }

  Map<String, double> _getReservationPosition(TsReservation reservation) {
    final bayNum = reservation.tsId!;
    final startPos = _getTimePosition(reservation.tsStart!);
    
    // 실제 타석 번호에서 인덱스 찾기
    final bayIndex = _model.bayNumbers.indexOf(bayNum);
    final leftPos = timeColWidth + (bayIndex >= 0 ? bayIndex : bayNum - 1) * bayColWidth + 2;
    
    return {
      'left': leftPos,
      'top': startPos,
    };
  }

  Widget _buildReservationBox(TsReservation reservation) {
    final position = _getReservationPosition(reservation);
    final calculatedHeight = _getReservationHeight(reservation.tsStart!, reservation.tsEnd!);
    final height = calculatedHeight < 45 ? 45 : calculatedHeight; // 최소 높이 45px 보장
    
    return Positioned(
      left: position['left']!,
      top: position['top']!,
      child: InkWell(
        onTap: () => TsReservationDetailDialog.show(
          context, 
          reservation,
          onDataChanged: () => _model.loadTsReservations(),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
        width: bayColWidth - 6,
        height: height - 6,
        margin: EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: reservation.getStatusColor(),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: reservation.getStatusTextColor().withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 회원명과 크레딧을 한 줄에
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          reservation.displayMemberName,
                          style: AppTextStyles.cardTitle.copyWith(
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w700,
                            fontSize: (AppTextStyles.cardTitle.fontSize ?? 16) - 2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (reservation.formattedNetAmt.isNotEmpty) ...[
                        SizedBox(width: 4),
                        Text(
                          reservation.formattedNetAmt,
                          style: AppTextStyles.tagMedium.copyWith(
                            color: Color(0xFF64748B),
                            fontSize: (AppTextStyles.tagMedium.fontSize ?? 12) - 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 2),
                // 시간
                Flexible(
                  child: Text(
                    reservation.formattedTimeRange,
                    style: AppTextStyles.caption.copyWith(
                      color: reservation.getStatusTextColor().withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 상태 (공간이 있을 때만)
                if (reservation.displayStatus.isNotEmpty && height > 60) ...[
                  SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      reservation.displayStatus,
                      style: AppTextStyles.overline.copyWith(
                        color: reservation.getStatusTextColor(),
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // 설정 버튼 빌드
  Widget _buildSettingButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isHighlight ? Color(0xFFEF4444) : Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isHighlight ? Color(0xFFEF4444) : Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: isHighlight ? [
            BoxShadow(
              color: Color(0xFFEF4444).withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.0,
              color: isHighlight ? Colors.white : Color(0xFF64748B),
            ),
            SizedBox(width: 6.0),
            Text(
              label,
              style: AppTextStyles.formLabel.copyWith(
                fontWeight: FontWeight.w600,
                color: isHighlight ? Colors.white : Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 빈 타석 클릭 처리
  void _handleEmptySlotClick(int bayNumber, int hour, int minutes) {
    // 해당 시간대에 예약이 있는지 확인
    final clickedTime = '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    bool hasReservation = false;
    
    for (final reservation in _model.getFilteredReservations()) {
      if (reservation.tsId == bayNumber) {
        final startTime = _parseTimeToMinutes(reservation.tsStart ?? '');
        final endTime = _parseTimeToMinutes(reservation.tsEnd ?? '');
        final clickedMinutes = hour * 60 + minutes;
        
        if (clickedMinutes >= startTime && clickedMinutes < endTime) {
          hasReservation = true;
          break;
        }
      }
    }
    
    if (!hasReservation) {
      _showEmptySlotInfo(bayNumber, clickedTime);
    }
  }
  
  // 시간 문자열을 분 단위로 변환
  int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
  
  // 빈 타석 정보 표시 - 센터타석오픈
  void _showEmptySlotInfo(int bayNumber, String time) async {
    final result = await TsTsOpenHelper.showEmptySlotInfo(
      context: context,
      bayNumber: bayNumber,
      time: time,
      selectedDate: _model.selectedDate,
    );
    
    // 저장 성공시에만 데이터 새로고침 (날짜는 유지)
    if (result == true) {
      _model.loadTsReservations();
    }
  }

  // 타석설정 페이지로 이동
  void _navigateToTsSetting() {
    // 전역 상태에 탭 정보 저장
    Crm9SettingModel.selectedTabGlobal = '타석설정';
    widget.onNavigate?.call('crm9_setting');
  }

  // 운영시간 설정 페이지로 이동
  void _navigateToOperatingHours() {
    // 전역 상태에 탭 정보 저장
    Crm9SettingModel.selectedTabGlobal = '운영시간';
    widget.onNavigate?.call('crm9_setting');
  }


  // 달력 팝업 표시
  Future<void> _showCalendarDialog() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 배경 어둡게
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white, // 다이얼로그 배경 흰색
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: 420,
            padding: EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '날짜 선택',
                      style: AppTextStyles.modalTitle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildCalendar(),
                SizedBox(height: 16),
                CalendarFormatService.buildSelectedDateDisplay(_model.selectedDate),
              ],
            ),
          ),
        );
      },
    );
  }



  // 휴일 메시지 빌드
  Widget _buildHolidayMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Color(0xFFE5E7EB),
          ),
          SizedBox(height: 16),
          Text(
            '휴일',
            style: AppTextStyles.titleH3.copyWith(
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '오늘은 영업하지 않습니다',
            style: AppTextStyles.bodyText.copyWith(
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // 오늘 날짜인지 확인
  bool _isToday() {
    final today = DateTime.now();
    return _model.selectedDate.year == today.year &&
           _model.selectedDate.month == today.month &&
           _model.selectedDate.day == today.day;
  }

  // 현재 시간이 영업시간 내에 있는지 확인
  bool _isWithinBusinessHours(DateTime now) {
    if (_model.businessStart == null || _model.businessEnd == null) {
      return false;
    }
    
    final startHour = _parseBusinessHour(_model.businessStart!);
    final endHour = _parseBusinessHour(_model.businessEnd!);
    final currentHour = now.hour;
    
    if (startHour < endHour) {
      return currentHour >= startHour && currentHour < endHour;
    } else {
      // 자정을 넘어가는 경우
      return currentHour >= startHour || currentHour < endHour;
    }
  }

  // 필수 데이터가 있는지 확인
  bool _hasRequiredData() {
    // 로딩 중이면 일단 true 반환 (로딩 표시를 위해)
    if (_model.isLoading) {
      return true;
    }
    
    // 오류 메시지가 있으면 false (오류 화면 표시)
    if (_model.errorMessage != null && _model.errorMessage!.isNotEmpty) {
      return false;
    }
    
    // 실제 데이터 체크 (좀 더 관대하게)
    return _model.availableTsBays.isNotEmpty || 
           (_model.businessStart != null && _model.businessEnd != null);
  }

  // 오류 메시지 빌드
  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Color(0xFFEF4444),
          ),
          SizedBox(height: 16),
          Text(
            '설정 오류',
            style: AppTextStyles.titleH3.copyWith(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _model.errorMessage ?? '타석 정보나 영업시간 설정이 필요합니다.',
              style: AppTextStyles.bodyText.copyWith(
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 현재 시간 표시선 빌드
  Widget _buildCurrentTimeLine() {
    final now = DateTime.now();
    final currentTimePosition = _getTimePosition('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');

    // 동적 너비 계산: 시간열(70) + 타석수 × 타석너비(120)
    final totalBays = _model.bayNumbers.isNotEmpty ? _model.bayNumbers.length : 9;
    final dynamicWidth = 70.0 + (totalBays * 120.0);

    return Positioned(
      left: 0,
      top: currentTimePosition - 10, // 클릭 영역을 위해 위로 확장
      child: GestureDetector(
        onTap: () => _showCurrentStatusDialog(),
        child: Container(
          width: dynamicWidth, // 동적 너비로 변경
          height: 20, // 클릭 영역 확대
          color: Colors.transparent,
          child: Stack(
            children: [
              // 클릭 가능한 배경 (호버 효과용)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 실제 현재 시간선
              Positioned(
                top: 9,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Color(0xFFEF4444),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // 시간 표시 레이블 (클릭 버튼 형태로 개선)
              Positioned(
                left: 4,
                top: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                        style: AppTextStyles.overline.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '현황',
                        style: AppTextStyles.overline.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 우측 끝에 클릭 안내 아이콘
              Positioned(
                right: 4,
                top: 2,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.grid_view,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 현재 타석 현황 다이얼로그
  void _showCurrentStatusDialog() {
    // 항상 현재 날짜와 시간을 기준으로 함
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: TsCurrentStatusWidget(
              selectedDate: today, // 항상 오늘 날짜 사용
              reservations: _getTodayReservations(), // 오늘 예약만 가져오기
              bayNumbers: _model.bayNumbers,
              businessStart: _model.businessStart, // 영업시간 정보 전달
              businessEnd: _model.businessEnd,     // 영업시간 정보 전달
              onReservationTap: (reservation) {
                Navigator.of(context).pop(); // 현황 다이얼로그 닫기
                TsReservationDetailDialog.show(
                  context,
                  reservation,
                  onDataChanged: () => _model.loadTsReservations(),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 오늘 예약만 가져오는 메서드
  List<TsReservation> _getTodayReservations() {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    
    // 모든 예약 중에서 오늘 날짜인 것만 필터링
    return _model.reservations.where((reservation) {
      return reservation.tsDate == todayStr;
    }).toList();
  }

  // 달력 위젯 빌드
  Widget _buildCalendar() {
    final config = CalendarFormatService.getCommonCalendarConfig();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: TableCalendar<String>(
        locale: 'ko_KR',
        firstDay: config['firstDay'],
        lastDay: config['lastDay'],
        focusedDay: _model.selectedDate,
        selectedDayPredicate: (day) {
          return isSameDay(_model.selectedDate, day);
        },
        holidayPredicate: (day) {
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          return _scheduleData[dateStr]?['is_holiday'] == 'close';
        },
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_model.selectedDate, selectedDay)) {
            _model.changeDate(selectedDay);
            Navigator.of(context).pop(); // 날짜 선택 시 팝업 닫기
          }
        },
        onPageChanged: (focusedDay) {
          if (focusedDay.year != _model.selectedDate.year) {
            _loadScheduleData();
          }
        },
        calendarFormat: config['calendarFormat'],
        startingDayOfWeek: config['startingDayOfWeek'],
        availableCalendarFormats: config['availableCalendarFormats'],
        rowHeight: config['rowHeight'],
        daysOfWeekHeight: config['daysOfWeekHeight'],
        calendarStyle: CalendarFormatService.getCalendarStyle(
          selectedColor: Color(0xFF3B82F6),
        ),
        headerStyle: CalendarFormatService.getHeaderStyle(
          chevronColor: Color(0xFF3B82F6),
        ),
        daysOfWeekStyle: CalendarFormatService.getDaysOfWeekStyle(),
        calendarBuilders: CalendarFormatService.getCalendarBuilders(_scheduleData),
      ),
    );
  }
}