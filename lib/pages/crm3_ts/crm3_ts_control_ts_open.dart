import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/font_sizes.dart';
import '/services/api_service.dart';

/// 센터타석오픈 관련 기능을 담당하는 서비스 클래스
class TsTsOpenService {
  /// 센터타석오픈 DB 저장
  static Future<void> saveCenterTsOpen({
    required DateTime selectedDate,
    required int tsId,
    required String startTime,
    required String endTime,
    required String memo,
  }) async {
    // 선택된 날짜 정보
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayOfWeek = _getDayOfWeek(selectedDate);
    
    // reservation_id 생성: yymmdd_타석번호_hhmm
    final yymmdd = DateFormat('yyMMdd').format(selectedDate);
    final hhmm = startTime.replaceAll(':', '');
    final reservationId = '${yymmdd}_${tsId}_$hhmm';
    
    // 시간대별 분류 계산
    final timeClassification = await _calculateTimeClassification(selectedDate, startTime, endTime);
    
    // 현재 시간을 timestamp로 사용
    final timeStamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    
    // v2_priced_TS에 저장할 데이터
    final data = {
      'reservation_id': reservationId,
      'ts_id': tsId,
      'ts_date': dateStr,
      'ts_start': '$startTime:00',
      'ts_end': '$endTime:00',
      'ts_payment_method': '', // 빈칸
      'ts_status': '결제완료',
      'member_id': null, // 빈칸
      'member_type': '', // 빈칸
      'member_name': '', // 빈칸
      'member_phone': '', // 빈칸
      'total_amt': 0, // 빈칸
      'term_discount': 0, // 빈칸
      'coupon_discount': 0, // 빈칸
      'total_discount': 0, // 빈칸
      'net_amt': 0, // 빈칸
      'discount_min': timeClassification['discount_min'],
      'normal_min': timeClassification['normal_min'],
      'extracharge_min': timeClassification['extracharge_min'],
      'ts_min': timeClassification['ts_min'],
      'bill_min': null, // 빈칸
      'time_stamp': timeStamp,
      'day_of_week': dayOfWeek,
      'bill_id': null, // 빈칸
      'bill_min_id': null, // 빈칸
      'bill_game_id': null, // 빈칸
      'program_id': null, // 빈칸
      'program_name': '', // 빈칸
      'memo': memo, // 메모 내용 저장
    };
    
    // API를 통해 데이터 저장
    await ApiService.addTsData(data);
    
    print('센터타석오픈 저장 완료:');
    print('reservation_id: $reservationId');
    print('시간대별 분류: $timeClassification');
    if (memo.isNotEmpty) {
      print('메모: $memo');
    }
  }

  /// 요일 한글명 반환
  static String _getDayOfWeek(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[date.weekday - 1];
  }

  /// 시간대별 분류 계산 (요금정책 테이블 연동)
  static Future<Map<String, int>> _calculateTimeClassification(DateTime date, String startTime, String endTime) async {
    try {
      // 요금 정책 조회
      final pricingPolicies = await ApiService.getTsPricingPolicy(date: date);
      if (pricingPolicies.isEmpty) {
        print('요금 정책이 없습니다. 분류하지 않음');
        final totalMinutes = _timeToMinutes(endTime) - _timeToMinutes(startTime);
        return {
          'discount_min': 0,
          'normal_min': 0,
          'extracharge_min': 0,
          'ts_min': totalMinutes,
        };
      }
      
      // 시간대별 요금 분석 (분 단위)
      final timeAnalysis = ApiService.analyzePricingByTimeRange(
        startTime: startTime,
        endTime: endTime,
        pricingPolicies: pricingPolicies,
      );
      
      // 총 시간(분) 계산
      final totalMinutes = _timeToMinutes(endTime) - _timeToMinutes(startTime);
      
      return {
        'discount_min': timeAnalysis['discount_price'] ?? 0,
        'normal_min': timeAnalysis['base_price'] ?? 0,
        'extracharge_min': timeAnalysis['extracharge_price'] ?? 0,
        'ts_min': totalMinutes,
      };
    } catch (e) {
      print('시간대별 분류 계산 오류: $e');
      final totalMinutes = _timeToMinutes(endTime) - _timeToMinutes(startTime);
      return {
        'discount_min': 0,
        'normal_min': 0,
        'extracharge_min': 0,
        'ts_min': totalMinutes,
      };
    }
  }

  /// 시간(HH:MM)을 분으로 변환
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}

/// 센터타석오픈 다이얼로그
class TsTsOpenDialog extends StatefulWidget {
  final int bayNumber;
  final String initialStartTime;
  final String initialEndTime;
  final DateTime selectedDate;

  const TsTsOpenDialog({
    Key? key,
    required this.bayNumber,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<TsTsOpenDialog> createState() => _TsTsOpenDialogState();
}

class _TsTsOpenDialogState extends State<TsTsOpenDialog> {
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _memoController;
  int _totalMinutes = 0;

  @override
  void initState() {
    super.initState();
    _startTimeController = TextEditingController(text: widget.initialStartTime);
    _endTimeController = TextEditingController(text: widget.initialEndTime);
    _memoController = TextEditingController();
    _calculateTotalMinutes();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '센터타석오픈',
                  style: AppTextStyles.modalTitle.copyWith(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // 타석 정보
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.golf_course,
                    size: 20,
                    color: Color(0xFF3B82F6),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${widget.bayNumber}번 타석',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            
            // 시작 시간
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시작 시간',
                  style: AppTextStyles.formLabel.copyWith(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startTimeController,
                        style: AppTextStyles.formInput.copyWith(
                          color: Colors.black,
                          fontFamily: 'Pretendard',
                        ),
                        decoration: InputDecoration(
                          hintText: 'HH:MM',
                          prefixIcon: Icon(Icons.access_time, color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF3B82F6)),
                          ),
                        ),
                        onChanged: (value) => _formatTimeInput(value, true),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      height: 56, // TextField의 기본 높이와 맞춤
                      child: Column(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _adjustTime(true, true),
                              child: Container(
                                width: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: Icon(Icons.keyboard_arrow_up, size: 18, color: Color(0xFF64748B)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _adjustTime(true, false),
                              child: Container(
                                width: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                                child: Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // 종료 시간
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '종료 시간',
                  style: AppTextStyles.formLabel.copyWith(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _endTimeController,
                        style: AppTextStyles.formInput.copyWith(
                          color: Colors.black,
                          fontFamily: 'Pretendard',
                        ),
                        decoration: InputDecoration(
                          hintText: 'HH:MM',
                          prefixIcon: Icon(Icons.access_time, color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF3B82F6)),
                          ),
                        ),
                        onChanged: (value) => _formatTimeInput(value, false),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      height: 56,
                      child: Column(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _adjustTime(false, true),
                              child: Container(
                                width: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: Icon(Icons.keyboard_arrow_up, size: 18, color: Color(0xFF64748B)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _adjustTime(false, false),
                              child: Container(
                                width: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                                child: Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // 예약시간(분) 표시
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '예약시간(분): $_totalMinutes분',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            
            // 메모
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '메모',
                  style: AppTextStyles.formLabel.copyWith(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _memoController,
                  maxLines: 3,
                  style: AppTextStyles.formInput.copyWith(
                    color: Colors.black,
                    fontFamily: 'Pretendard',
                  ),
                  decoration: InputDecoration(
                    hintText: '센터타석오픈에 대한 메모를 입력하세요',
                    hintStyle: AppTextStyles.formInput.copyWith(
                      color: Color(0xFF94A3B8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // 버튼
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF64748B),
                      side: BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '취소',
                      style: AppTextStyles.modalButton.copyWith(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '저장',
                      style: AppTextStyles.modalButton.copyWith(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  // 시간 입력 포맷팅
  void _formatTimeInput(String value, bool isStartTime) {
    // 숫자만 추출
    String numbers = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 최대 4자리까지만 허용
    if (numbers.length > 4) {
      numbers = numbers.substring(0, 4);
    }
    
    // HH:MM 형식으로 포맷팅
    String formatted = '';
    if (numbers.length >= 3) {
      formatted = '${numbers.substring(0, 2)}:${numbers.substring(2)}';
    } else {
      formatted = numbers;
    }
    
    // 종료시간 유효성 검사
    if (!isStartTime && formatted.length == 5) {
      final startTime = _startTimeController.text;
      if (startTime.length == 5 && startTime.contains(':')) {
        if (!_isEndTimeValid(startTime, formatted)) {
          // 시작시간 + 5분으로 자동 설정
          formatted = _getMinimumEndTime(startTime);
        }
      }
    }
    
    // 컨트롤러 업데이트
    final controller = isStartTime ? _startTimeController : _endTimeController;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    
    // 시작시간이 변경되면 종료시간도 검증
    if (isStartTime && formatted.length == 5) {
      final endTime = _endTimeController.text;
      if (endTime.length == 5 && !_isEndTimeValid(formatted, endTime)) {
        _endTimeController.text = _getMinimumEndTime(formatted);
      }
    }
    
    // 총 시간 재계산
    _calculateTotalMinutes();
  }
  
  // 총 예약시간(분) 계산
  void _calculateTotalMinutes() {
    final startTime = _startTimeController.text;
    final endTime = _endTimeController.text;
    
    if (startTime.length == 5 && endTime.length == 5 && 
        startTime.contains(':') && endTime.contains(':')) {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMinute = int.tryParse(startParts[1]) ?? 0;
      final endHour = int.tryParse(endParts[0]) ?? 0;
      final endMinute = int.tryParse(endParts[1]) ?? 0;
      
      final startTotalMinutes = startHour * 60 + startMinute;
      final endTotalMinutes = endHour * 60 + endMinute;
      
      setState(() {
        _totalMinutes = endTotalMinutes - startTotalMinutes;
        if (_totalMinutes < 0) {
          _totalMinutes += 24 * 60; // 자정을 넘어가는 경우
        }
      });
    }
  }

  // 종료시간 유효성 검사 (시작시간보다 최소 5분 이후인지)
  bool _isEndTimeValid(String startTime, String endTime) {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    
    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMinute = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMinute = int.tryParse(endParts[1]) ?? 0;
    
    final startTotalMinutes = startHour * 60 + startMinute;
    final endTotalMinutes = endHour * 60 + endMinute;
    
    // 자정을 넘어가는 경우 처리
    final diff = endTotalMinutes >= startTotalMinutes 
        ? endTotalMinutes - startTotalMinutes 
        : (24 * 60 - startTotalMinutes) + endTotalMinutes;
    
    return diff >= 5;
  }
  
  // 최소 종료시간 계산 (시작시간 + 5분)
  String _getMinimumEndTime(String startTime) {
    final parts = startTime.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1]) ?? 0;
    
    minute += 5;
    if (minute >= 60) {
      minute -= 60;
      hour += 1;
      if (hour >= 24) hour = 0;
    }
    
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // 시간 조정 (위/아래 버튼)
  void _adjustTime(bool isStartTime, bool isIncrement) {
    final controller = isStartTime ? _startTimeController : _endTimeController;
    final currentText = controller.text;
    
    if (currentText.length != 5 || !currentText.contains(':')) return;
    
    final parts = currentText.split(':');
    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1]) ?? 0;
    
    String newTime;
    if (isIncrement) {
      // 위 화살표: 5분 감소 (과거로)
      minute -= 5;
      if (minute < 0) {
        minute += 60;
        hour -= 1;
        if (hour < 0) hour = 23;
      }
    } else {
      // 아래 화살표: 5분 증가 (미래로)
      minute += 5;
      if (minute >= 60) {
        minute -= 60;
        hour += 1;
        if (hour >= 24) hour = 0;
      }
    }
    
    newTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    
    // 종료시간 조정시 유효성 검사
    if (!isStartTime) {
      final startTime = _startTimeController.text;
      if (startTime.length == 5 && !_isEndTimeValid(startTime, newTime)) {
        // 최소 종료시간으로 설정
        newTime = _getMinimumEndTime(startTime);
      }
    }
    
    controller.text = newTime;
    
    // 시작시간 조정시 종료시간도 검증
    if (isStartTime) {
      final endTime = _endTimeController.text;
      if (endTime.length == 5 && !_isEndTimeValid(newTime, endTime)) {
        _endTimeController.text = _getMinimumEndTime(newTime);
      }
    }
    
    // 총 시간 재계산
    _calculateTotalMinutes();
  }

  // 저장 처리
  Future<void> _handleSave() async {
    final startTime = _startTimeController.text;
    final endTime = _endTimeController.text;
    final memo = _memoController.text;
    
    try {
      // 센터타석오픈 DB 저장
      await TsTsOpenService.saveCenterTsOpen(
        selectedDate: widget.selectedDate,
        tsId: widget.bayNumber,
        startTime: startTime,
        endTime: endTime,
        memo: memo,
      );
      
      // 저장 성공시 true 반환 (날짜 유지를 위함)
      Navigator.of(context).pop(true);
      
      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('센터타석오픈이 저장되었습니다'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      // 에러 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
}

/// 센터타석오픈 다이얼로그를 표시하는 헬퍼 메서드
class TsTsOpenHelper {
  /// 빈 타석 정보 표시 - 센터타석오픈
  static Future<bool?> showEmptySlotInfo({
    required BuildContext context,
    required int bayNumber,
    required String time,
    required DateTime selectedDate,
  }) async {
    // 종료시간 계산 (시작시간 + 1시간)
    final timeParts = time.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMinute = int.parse(timeParts[1]);
    
    int endHour = startHour + 1;
    int endMinute = startMinute;
    
    if (endHour >= 24) {
      endHour = endHour - 24;
    }
    
    final endTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TsTsOpenDialog(
          bayNumber: bayNumber,
          initialStartTime: time,
          initialEndTime: endTime,
          selectedDate: selectedDate,
        );
      },
    );
  }
}