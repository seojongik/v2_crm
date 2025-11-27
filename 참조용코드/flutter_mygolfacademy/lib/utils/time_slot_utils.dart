import 'package:flutter/material.dart';

class TimeSlotUtils {
  // 시간 문자열을 분으로 변환 (예: "06:30" -> 390)
  static int convertTimeToMinutes(String timeString) {
    final parts = timeString.split(':');
    if (parts.length != 2) return 0;
    final int hours = int.tryParse(parts[0]) ?? 0;
    final int minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  // 시간대 설정 초기화 (평일/공휴일)
  static Map<String, List<List<int>>> getWeekdayTimeSlots({
    String morningStart = '06:00',
    String morningEnd = '10:00',
    String peakStart = '17:00',
    String peakEnd = '22:00',
    String nightStart = '23:00',
    String nightEnd = '24:00',
  }) {
    return {
      '조조': [[convertTimeToMinutes(morningStart), convertTimeToMinutes(morningEnd)]],
      '피크': [[convertTimeToMinutes(peakStart), convertTimeToMinutes(peakEnd)]],
      '심야': [[convertTimeToMinutes(nightStart), convertTimeToMinutes(nightEnd)]],
    };
  }

  static Map<String, List<List<int>>> getHolidayTimeSlots({
    String peakStart = '10:00',
    String peakEnd = '18:00',
  }) {
    return {
      '조조': [],
      '피크': [[convertTimeToMinutes(peakStart), convertTimeToMinutes(peakEnd)]],
      '심야': [],
    };
  }

  // 두 날짜가 같은 날인지 확인
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 시간/분 리스트 생성 (5분 단위)
  static List<int> generateHours(int startHour, int endHour) {
    return List.generate(endHour - startHour + 1, (index) => index + startHour);
  }
  static List<int> generateMinutes({int interval = 5}) {
    return List.generate(60 ~/ interval, (index) => index * interval);
  }

  // 유효한 분 리스트 (특정 시간에 대해)
  static List<int> getValidMinutesForHour({
    required int hour,
    required List<int> hours,
    required TimeOfDay businessStartTime,
    required TimeOfDay lastReservationTime,
    required DateTime selectedDate,
    required DateTime nowDate,
    required TimeOfDay nowTime,
    List<int>? minutes,
  }) {
    minutes ??= generateMinutes();
    int startTimeInMinutes = businessStartTime.hour * 60 + businessStartTime.minute;
    int lastReservationTimeInMinutes = lastReservationTime.hour * 60 + lastReservationTime.minute;
    bool isToday = isSameDay(selectedDate, nowDate);
    List<int> validMinutes = List.from(minutes);
    if (hour == hours.first) {
      int minMinute = 0;
      if (hour == businessStartTime.hour) {
        minMinute = businessStartTime.minute;
      }
      if (isToday && hour == nowTime.hour && nowTime.minute > businessStartTime.minute) {
        minMinute = nowTime.minute;
      }
      minMinute = ((minMinute + 4) ~/ 5) * 5;
      validMinutes.removeWhere((minute) => minute < minMinute);
    }
    if (hour == lastReservationTime.hour) {
      validMinutes.removeWhere((minute) => minute > lastReservationTime.minute);
    }
    if (hour > lastReservationTime.hour) {
      return [];
    }
    if (validMinutes.isEmpty) {
      if (hour == businessStartTime.hour) {
        int startMinute = (((businessStartTime.minute + 4) ~/ 5) * 5) % 60;
        validMinutes.add(startMinute);
      } else {
        validMinutes.add(0);
      }
    }
    return validMinutes;
  }

  // 기본 시간 설정 (현재 시간, 영업 시작/종료, 마지막 예약 가능 시간 등 고려)
  static TimeOfDay getDefaultTime({
    required DateTime selectedDate,
    required TimeOfDay businessStartTime,
    required TimeOfDay lastReservationTime,
    DateTime? nowDate,
    TimeOfDay? nowTime,
  }) {
    nowDate ??= DateTime.now();
    nowTime ??= TimeOfDay.now();
    final currentMinutes = nowTime.hour * 60 + nowTime.minute;
    final roundedMinutes = ((currentMinutes + 4) ~/ 5) * 5;
    final roundedHour = (roundedMinutes ~/ 60) % 24;
    final roundedMinute = roundedMinutes % 60;
    final lastReservationMinutes = lastReservationTime.hour * 60 + lastReservationTime.minute;
    final businessStartMinutes = businessStartTime.hour * 60 + businessStartTime.minute;
    if (isSameDay(selectedDate, nowDate)) {
      if (roundedMinutes >= businessStartMinutes && roundedMinutes <= lastReservationMinutes) {
        return TimeOfDay(hour: roundedHour, minute: roundedMinute);
      } else if (roundedMinutes < businessStartMinutes) {
        return businessStartTime;
      } else if (roundedMinutes > lastReservationMinutes) {
        return lastReservationTime;
      }
    } else {
      return businessStartTime;
    }
    return businessStartTime;
  }
} 