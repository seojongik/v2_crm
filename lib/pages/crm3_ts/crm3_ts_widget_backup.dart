import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/models/ts_reservation.dart';
import '/services/calendar_format_service.dart';
import '/services/holiday_service.dart';
import '../../constants/font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'crm3_ts_model.dart';
export 'crm3_ts_model.dart';

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

  // 시간을 시간표 위치로 변환
  double _getTimePosition(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      // 6시 기준으로 계산 (헤더 높이 50 포함)
      int hourDiff = hour - 6;
      if (hourDiff < 0) hourDiff += 24;
      
      // 정확한 위치 계산: 헤더(50) + 시간차이*행높이 + 분단위 위치
      final position = 50.0 + (hourDiff * rowHeight) + ((minute / 60.0) * rowHeight);
      
      print('시간 위치 계산: $timeStr -> ${hour}시 ${minute}분 -> 위치: ${position}px');
      return position;
    } catch (e) {
      print('시간 파싱 오류: $timeStr - $e');
      return 50.0;
    }
  }

  // 예약 박스 높이 계산
  double _getReservationHeight(String startTime, String endTime) {
    // 시작 시간과 종료 시간 파싱
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    
    final startHour = int.parse(startParts[0]);
    final startMin = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMin = int.parse(endParts[1]);
    
    // 시간 차이 계산 (분 단위)
    double durationHours;
    double durationMins;
    
    if (endHour < startHour) {
      // 자정을 넘어가는 경우
      durationHours = ((endHour + 24) - startHour).toDouble();
    } else {
      durationHours = (endHour - startHour).toDouble();
    }
    
    if (endMin < startMin) {
      durationMins = ((endMin + 60) - startMin).toDouble();
      durationHours -= 1.0;
    } else {
      durationMins = (endMin - startMin).toDouble();
    }
    
    final totalMinutes = (durationHours * 60) + durationMins;
    final height = (totalMinutes / 60) * rowHeight;
    
    // 최소 높이 30, 최대 높이 180으로 제한
    final finalHeight = height.clamp(30.0, 180.0);
    
    print('시간 계산: $startTime-$endTime, 총 ${totalMinutes}분, 높이: ${finalHeight}px');
    
    return finalHeight;
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
                  onNavigate: (String routeName) {
                    widget.onNavigate?.call(routeName);
                  },
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
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
                    Padding(
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '타석관리',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: Color(0xFF1E293B),
                                                fontSize: 28.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                              child: Text(
                                                '타석 현황을 관리하고 예약 상태를 확인할 수 있습니다.',
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF64748B),
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    // 달력 섹션
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '날짜 선택',
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF1E293B),
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  _model.goToToday();
                                                },
                                                child: Text(
                                                  '오늘',
                                                  style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Color(0xFF3B82F6),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8.0),
                                                  ),
                                                  padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16),
                                          _buildCalendar(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 시간표 섹션
                            Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Container(
                                width: double.infinity,
                                height: 1200, // 시간표 높이 고정
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
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      color: Color(0xFFEF4444),
                                                      size: 48.0,
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                                      child: Text(
                                                        '데이터를 불러오는 중 오류가 발생했습니다.',
                                                        style: TextStyle(
                                                          fontFamily: 'Pretendard',
                                                          color: Color(0xFF64748B),
                                                          fontSize: 16.0,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                                      child: Text(
                                                        _model.errorMessage!,
                                                        style: TextStyle(
                                                          fontFamily: 'Pretendard',
                                                          color: Color(0xFFEF4444),
                                                          fontSize: 14.0,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                                                      child: ElevatedButton.icon(
                                                        onPressed: () {
                                                          _model.loadTsReservations();
                                                        },
                                                        icon: Icon(
                                                          Icons.refresh,
                                                          color: Colors.white,
                                                          size: 20.0,
                                                        ),
                                                        label: Text(
                                                          '다시 시도',
                                                          style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Color(0xFF3B82F6),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8.0),
                                                          ),
                                                          padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : _buildTimetable();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시간표 위젯 빌드
  Widget _buildTimetable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: timeColWidth + (bayColWidth * _model.totalBays),
        height: 1200,
        child: Stack(
          children: [
            // 시간표 그리드
            _buildTimetableGrid(),
            // 예약 박스들
            ..._buildReservationBoxes(),
          ],
        ),
      ),
    );
  }

  // 시간표 그리드 빌드
  Widget _buildTimetableGrid() {
    return Column(
      children: [
        // 헤더
        _buildTimetableHeader(),
        // 시간 행들
        Expanded(
          child: Column(
            children: List.generate(19, (hourIndex) { // 6시부터 24시까지
              final hour = 6 + hourIndex;
              final displayHour = hour > 24 ? hour - 24 : hour;
              
              return _buildTimetableRow(displayHour);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableHeader() {
    return Container(
      height: 50,
      child: Row(
        children: [
          // 시간 컬럼 헤더
          Container(
            width: timeColWidth,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFF374151), // 고급스러운 진한 그레이
              border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
            ),
            child: Center(
              child: Text(
                '시간',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // 베이 헤더들
          ...List.generate(_model.totalBays, (index) {
            final bayNumber = _model.bayNumbers.isNotEmpty ? _model.bayNumbers[index] : index + 1;
            return Container(
              width: bayColWidth,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFF6B7280), // 고급스러운 중간 그레이
                border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
              ),
              child: Center(
                child: Text(
                  '$bayNumber번',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimetableRow(int hour) {
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151), // 더 진한 그레이 텍스트
                ),
              ),
            ),
          ),
          // 베이 셀들
          ...List.generate(_model.totalBays, (index) {
            return Container(
              width: bayColWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: reservation.getStatusTextColor(),
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (reservation.formattedNetAmt.isNotEmpty) ...[
                        SizedBox(width: 4),
                        Text(
                          reservation.formattedNetAmt,
                          style: TextStyle(
                            fontSize: 11,
                            color: reservation.getStatusTextColor(),
                            fontWeight: FontWeight.w600,
                            height: 1.0,
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
                    style: TextStyle(
                      fontSize: 11,
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
                      style: TextStyle(
                        fontSize: 9,
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
    );
  }
}
