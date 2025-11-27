import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../constants/font_sizes.dart';
class CalendarFormatService {
  // 공통 달력 스타일 설정
  static CalendarStyle getCalendarStyle({Color? selectedColor, Color? todayColor}) {
    return CalendarStyle(
      outsideDaysVisible: false,
      rowDecoration: BoxDecoration(),
      cellMargin: EdgeInsets.all(4),
      weekendTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
      ),
      holidayTextStyle: TextStyle(
        color: Color(0xFFEF4444), // 공휴일은 빨간색
        fontWeight: FontWeight.w600,
      ),
      selectedDecoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
        border: Border.all(
          color: selectedColor ?? Color(0xFF3B82F6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (selectedColor ?? Color(0xFF3B82F6)).withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      selectedTextStyle: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      todayDecoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: Color(0xFF3B82F6),
          width: 2,
        ),
      ),
      todayTextStyle: TextStyle(
        color: Color(0xFF3B82F6),
        fontWeight: FontWeight.bold,
      ),
      defaultDecoration: BoxDecoration(
        shape: BoxShape.circle,
      ),
      defaultTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      disabledDecoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      ),
      disabledTextStyle: TextStyle(
        color: Color(0xFFD0D0D0),
        fontWeight: FontWeight.w300,
      ),
      markersMaxCount: 0, // 마커 제거 (오늘 표시는 todayDecoration으로)
    );
  }

  // 공통 헤더 스타일 설정
  static HeaderStyle getHeaderStyle({Color? chevronColor}) {
    return HeaderStyle(
      formatButtonVisible: false,
      titleCentered: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
      leftChevronIcon: Icon(
        Icons.chevron_left,
        color: chevronColor ?? Color(0xFF3B82F6),
      ),
      rightChevronIcon: Icon(
        Icons.chevron_right,
        color: chevronColor ?? Color(0xFF3B82F6),
      ),
      headerPadding: EdgeInsets.symmetric(vertical: 8),
    );
  }

  // 공통 요일 스타일 설정
  static DaysOfWeekStyle getDaysOfWeekStyle() {
    return DaysOfWeekStyle(
      decoration: BoxDecoration(),
      weekdayStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      weekendStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  // 공통 달력 빌더 설정
  static CalendarBuilders<String> getCalendarBuilders(Map<String, Map<String, dynamic>> scheduleData) {
    return CalendarBuilders<String>(
      defaultBuilder: (context, day, focusedDay) {
        Color textColor = Color(0xFF1A1A1A);
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final isHoliday = scheduleData[dateStr]?['is_holiday'] == 'close';
        
        // 우선순위: 공휴일 > 일요일 > 토요일
        if (isHoliday || day.weekday == DateTime.sunday) {
          textColor = Color(0xFFEF4444); // 빨간색
        } else if (day.weekday == DateTime.saturday) {
          textColor = Color(0xFF3B82F6); // 파란색
        }
        
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
      holidayBuilder: (context, day, focusedDay) {
        // 공휴일은 빨간색으로 표시
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  // 공통 달력 설정
  static Map<String, dynamic> getCommonCalendarConfig() {
    return {
      'rowHeight': 45.0,
      'daysOfWeekHeight': 35.0,
      'calendarHeight': 340.0,
      'locale': 'ko_KR',
      'firstDay': DateTime(2020, 1, 1), // 과거 날짜 선택 가능하도록 변경
      'lastDay': DateTime.now().add(Duration(days: 365)),
      'calendarFormat': CalendarFormat.month,
      'startingDayOfWeek': StartingDayOfWeek.sunday,
      'availableCalendarFormats': const {
        CalendarFormat.month: '월',
      },
    };
  }

  // 선택된 날짜 표시 위젯
  static Widget buildSelectedDateDisplay(DateTime? selectedDate) {
    if (selectedDate == null) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택된 날짜',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(selectedDate),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 로딩 표시 위젯
  static Widget buildLoadingIndicator(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(message),
        ],
      ),
    );
  }
}