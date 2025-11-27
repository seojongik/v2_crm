import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../services/table_design.dart';
import '../../../services/upper_button_input_design.dart';

class Tab7TsPriceWidget extends StatefulWidget {
  const Tab7TsPriceWidget({super.key});

  @override
  State<Tab7TsPriceWidget> createState() => _Tab7TsPriceWidgetState();
}

class _Tab7TsPriceWidgetState extends State<Tab7TsPriceWidget> {
  bool _isEditMode = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _dayGroups = []; // 요일묶음 데이터
  final List<String> _categories = ['일반', '할인', '할증', '미운영'];
  final List<String> _weekdays1 = ['월요일', '수요일', '금요일', '토요일', '공휴일']; // 첫 번째 열: 월수금토공휴일
  final List<String> _weekdays2 = ['화요일', '목요일', '', '일요일', '']; // 두 번째 열: 화목(빈칸)일(빈칸)
  
  @override
  void initState() {
    super.initState();
    _loadPricingPolicyData(); // API에서 데이터 로드
  }

  // API에서 과금정책 데이터 로드
  Future<void> _loadPricingPolicyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('API 호출 시작: v2_ts_pricing_policy 데이터 로드');
      
      final data = await ApiService.getPricingPolicyData(
        orderBy: [
          {'field': 'policy_category', 'direction': 'ASC'},
          {'field': 'policy_start_time', 'direction': 'ASC'}
        ]
      );

      print('데이터 로드 성공: ${data.length}개 레코드');
      _convertApiDataToDayGroups(data);
      
    } catch (e) {
      print('API 호출 오류: $e');
      print('오류 타입: ${e.runtimeType}');
      _showErrorSnackBar('데이터 로드 실패: $e');
      setState(() {
        _dayGroups = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // API 데이터를 UI 요일묶음 형태로 변환
  void _convertApiDataToDayGroups(List<dynamic> apiData) {
    print('🔍 [로드] ========== DB 데이터를 UI 요일묶음으로 변환 시작 ==========');
    print('🔍 [로드] DB에서 가져온 총 레코드 수: ${apiData.length}개');
    
    if (apiData.isEmpty) {
      print('🔍 [로드] DB 데이터가 비어있음');
      return;
    }

    Map<int, Map<String, dynamic>> categoryGroups = {};

    // 카테고리별로 그룹화
    for (var record in apiData) {
      int category = record['policy_category'];
      String dayOfWeek = record['day_of_week'];
      String rawStartTime = record['policy_start_time']?.toString() ?? '';
      String rawEndTime = record['policy_end_time']?.toString() ?? '';
      
      print('🔍 [로드] 레코드: policy_category=$category, day_of_week=$dayOfWeek, 시간=$rawStartTime ~ $rawEndTime');
      
      String startTime = rawStartTime.length >= 5 ? rawStartTime.substring(0, 5) : rawStartTime; // HH:MM 형태로
      String endTime = rawEndTime.length >= 5 ? rawEndTime.substring(0, 5) : rawEndTime;
      
      // DB에서 가져온 값을 그대로 사용 (변환하지 않음)
      print('🔍 [로드] UI에 표시할 시간: $startTime ~ $endTime (변환 없음)');
      
      String policyApply = record['policy_apply'];

      // 정책 적용 타입을 UI 카테고리로 변환
      String uiCategory;
      switch (policyApply) {
        case 'base_price':
          uiCategory = '일반';
          break;
        case 'discount_price':
          uiCategory = '할인';
          break;
        case 'extracharge_price':
          uiCategory = '할증';
          break;
        case 'out_of_business':
          uiCategory = '미운영';
          break;
        default:
          uiCategory = '일반';
      }

      if (!categoryGroups.containsKey(category)) {
        categoryGroups[category] = {
          'id': category.toString(),
          'selectedDays': <String>[],
          'timeSlots': <Map<String, dynamic>>[],
        };
      }

      // 요일 추가 (중복 방지)
      String fullDayName = _convertDayToFullName(dayOfWeek);
      if (!categoryGroups[category]!['selectedDays'].contains(fullDayName)) {
        categoryGroups[category]!['selectedDays'].add(fullDayName);
      }

      // 시간구획 추가 (중복 방지)
      List<Map<String, dynamic>> timeSlots = categoryGroups[category]!['timeSlots'];
      bool timeSlotExists = timeSlots.any((slot) => 
        slot['start_time'] == startTime && 
        slot['end_time'] == endTime && 
        slot['category'] == uiCategory
      );

      if (!timeSlotExists) {
        timeSlots.add({
          'start_time': startTime,
          'end_time': endTime,
          'category': uiCategory,
        });
      }
    }

    // 시간순으로 정렬 (00:00을 가장 앞으로)
    for (var group in categoryGroups.values) {
      List<Map<String, dynamic>> timeSlots = group['timeSlots'];
      timeSlots.sort((a, b) {
        int startA = _timeToMinutes(a['start_time']);
        int startB = _timeToMinutes(b['start_time']);
        // 00:00은 가장 앞으로 (0분)
        if (startA == 0 && startB != 0) return -1;
        if (startA != 0 && startB == 0) return 1;
        return startA.compareTo(startB);
      });
      
      // 정렬 후 로그 출력
      print('🔍 [로드] 정렬된 시간구획:');
      for (var slot in timeSlots) {
        print('🔍   - ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']})');
      }
    }

    print('🔍 [로드] 생성된 요일묶음 수: ${categoryGroups.length}개');
    for (var entry in categoryGroups.entries) {
      int category = entry.key;
      var group = entry.value;
      List<String> selectedDays = group['selectedDays'];
      List<Map<String, dynamic>> timeSlots = group['timeSlots'];
      print('🔍 [로드] 요일묶음 $category: 요일=${selectedDays.join(', ')}, 시간구획=${timeSlots.length}개');
    }
    print('🔍 [로드] ============================================');

    setState(() {
      _dayGroups = categoryGroups.values.toList();
      
      // setState 후 값 확인
      print('🔍 [로드] setState 후 _dayGroups 값:');
      for (int i = 0; i < _dayGroups.length; i++) {
        var group = _dayGroups[i];
        List<Map<String, dynamic>> timeSlots = group['timeSlots'];
        print('🔍 [로드] 요일묶음 ${i + 1} 시간구획:');
        for (var slot in timeSlots) {
          print('🔍   - ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']})');
        }
      }
    });
  }

  // 짧은 요일명을 전체 요일명으로 변환
  String _convertDayToFullName(String shortDay) {
    switch (shortDay) {
      case '월': return '월요일';
      case '화': return '화요일';
      case '수': return '수요일';
      case '목': return '목요일';
      case '금': return '금요일';
      case '토': return '토요일';
      case '일': return '일요일';
      case '공휴일': return '공휴일';
      default: return shortDay;
    }
  }

  // 전체 요일명을 짧은 요일명으로 변환
  String _convertDayToShortName(String fullDay) {
    switch (fullDay) {
      case '월요일': return '월';
      case '화요일': return '화';
      case '수요일': return '수';
      case '목요일': return '목';
      case '금요일': return '금';
      case '토요일': return '토';
      case '일요일': return '일';
      case '공휴일': return '공휴일';
      default: return fullDay;
    }
  }

  // UI 카테고리를 DB 정책 적용 타입으로 변환
  String _convertCategoryToPolicyApply(String category) {
    switch (category) {
      case '일반': return 'base_price';
      case '할인': return 'discount_price';
      case '할증': return 'extracharge_price';
      case '미운영': return 'out_of_business';
      default: return 'base_price';
    }
  }

  // 과금정책 데이터 저장
  Future<void> _savePricingPolicyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('저장 시작: 기존 데이터 삭제');
      
      // 1. 기존 데이터 삭제 (ApiService에서 자동으로 branch_id 필터링)
      await ApiService.deletePricingPolicyData([]);

      // 2. 새로운 데이터 삽입
      List<Map<String, dynamic>> recordsToInsert = [];

      for (int categoryIndex = 0; categoryIndex < _dayGroups.length; categoryIndex++) {
        Map<String, dynamic> dayGroup = _dayGroups[categoryIndex];
        List<String> selectedDays = List<String>.from(dayGroup['selectedDays']);
        List<Map<String, dynamic>> timeSlots = List<Map<String, dynamic>>.from(dayGroup['timeSlots']);

        for (String fullDayName in selectedDays) {
          String shortDayName = _convertDayToShortName(fullDayName);
          
          for (Map<String, dynamic> timeSlot in timeSlots) {
            String originalStartTime = timeSlot['start_time']?.toString() ?? '';
            String originalEndTime = timeSlot['end_time']?.toString() ?? '';
            
            print('🔍 [저장] 원본 시간구획: $originalStartTime ~ $originalEndTime (타입: ${originalStartTime.runtimeType}, ${originalEndTime.runtimeType})');
            
            // 저장 시: 00:00을 24:00으로 변환 (DB에 저장할 때)
            String normalizedStartTime = originalStartTime == '00:00' && originalEndTime != '00:00' 
                ? originalStartTime 
                : (originalStartTime == '24:00' ? '00:00' : originalStartTime);
            String normalizedEndTime = originalEndTime == '00:00' && originalStartTime != '00:00'
                ? '24:00'  // 종료시간이 00:00이고 시작시간이 0이 아니면 24:00으로 저장
                : (originalEndTime == '24:00' ? '00:00' : originalEndTime);
            
            print('🔍 [저장] 변환 로직: endTime==00:00 && startTime!=00:00 ? ${originalEndTime == '00:00' && originalStartTime != '00:00'}');
            print('🔍 [저장] 변환된 시간구획: $normalizedStartTime ~ $normalizedEndTime');
            
            recordsToInsert.add({
              'policy_category': categoryIndex + 1,
              'day_of_week': shortDayName,
              'policy_start_time': '${normalizedStartTime}:00',
              'policy_end_time': '${normalizedEndTime}:00',
              'policy_apply': _convertCategoryToPolicyApply(timeSlot['category']),
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      print('삽입할 레코드 수: ${recordsToInsert.length}');
      print('삽입할 데이터 샘플: ${recordsToInsert.isNotEmpty ? recordsToInsert.first : 'None'}');

      // 각 레코드를 개별적으로 삽입
      for (int i = 0; i < recordsToInsert.length; i++) {
        Map<String, dynamic> record = recordsToInsert[i];
        print('레코드 ${i + 1}/${recordsToInsert.length} 삽입 중: $record');
        
        await ApiService.addPricingPolicyData(record);
      }

      print('모든 데이터 저장 완료');
      _showSuccessSnackBar('과금 설정이 저장되었습니다');
      
      // 저장 성공 후 최신 데이터를 다시 로드
      await _loadPricingPolicyData();
      
    } catch (e) {
      print('저장 오류: $e');
      print('오류 타입: ${e.runtimeType}');
      _showErrorSnackBar('저장 중 오류가 발생했습니다: $e');
      
      // 저장 실패 시에도 최신 데이터를 다시 로드 (DB 상태와 UI 동기화)
      await _loadPricingPolicyData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 요일묶음 추가 (빈 상태로 생성)
  void _addDayGroup() {
    setState(() {
      Map<String, dynamic> newDayGroup = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'selectedDays': <String>[], // 빈 상태로 시작
        'timeSlots': <Map<String, dynamic>>[
          <String, dynamic>{
            'start_time': '06:00',
            'end_time': '10:00',
            'category': '할인',
          },
          <String, dynamic>{
            'start_time': '10:00',
            'end_time': '17:00',
            'category': '일반',
          },
          <String, dynamic>{
            'start_time': '17:00',
            'end_time': '22:00',
            'category': '할증',
          },
          <String, dynamic>{
            'start_time': '22:00',
            'end_time': '24:00',
            'category': '일반',
          },
          <String, dynamic>{
            'start_time': '24:00',
            'end_time': '06:00',
            'category': '미운영',
          },
        ],
      };
      _dayGroups.add(newDayGroup);
    });
  }

  // 시간구획 추가 (특정 위치에)
  void _addTimeSlot(int dayGroupIndex) {
    setState(() {
      Map<String, dynamic> newTimeSlot = <String, dynamic>{
        'start_time': '00:00',
        'end_time': '00:00',
        'category': '일반',
      };
      (_dayGroups[dayGroupIndex]['timeSlots'] as List<Map<String, dynamic>>).add(newTimeSlot);
    });
  }

  // 특정 위치에 시간구획 행 추가 (빈 시간구획만 추가)
  void _insertTimeSlot(int dayGroupIndex, int afterIndex) {
    print('🔍 [행추가] ========== 시간구획 행 추가 시작 ==========');
    print('🔍 [행추가] 요일묶음 인덱스: $dayGroupIndex');
    print('🔍 [행추가] 삽입할 위치 (afterIndex): $afterIndex');
    
    setState(() {
      // 원본 _dayGroups를 직접 수정
      List<Map<String, dynamic>> timeSlots = (_dayGroups[dayGroupIndex]['timeSlots'] as List<Map<String, dynamic>>);
      
      print('🔍 [행추가] 삽입 전 시간구획 수: ${timeSlots.length}');
      print('🔍 [행추가] 삽입 전 전체 시간구획 상태:');
      for (int i = 0; i < timeSlots.length; i++) {
        var slot = timeSlots[i];
        print('🔍 [행추가]   [$i] ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']}) - 해시코드: ${slot.hashCode}');
      }
      
      // 완전히 새로운 빈 시간구획 추가 (참조 복사 방지)
      Map<String, dynamic> newTimeSlot = Map<String, dynamic>.from({
        'start_time': '00:00',
        'end_time': '00:00',
        'category': '일반',
      });
      
      print('🔍 [행추가] 새로 생성할 시간구획: ${newTimeSlot['start_time']} ~ ${newTimeSlot['end_time']} (${newTimeSlot['category']}) - 해시코드: ${newTimeSlot.hashCode}');
      print('🔍 [행추가] 삽입할 위치 계산: afterIndex + 1 = ${afterIndex + 1}, timeSlots.length = ${timeSlots.length}');
      
      // 해당 줄 아래에 삽입
      if (afterIndex + 1 <= timeSlots.length) {
        print('🔍 [행추가] 조건 확인: ${afterIndex + 1} <= ${timeSlots.length} = true → insert() 사용');
        timeSlots.insert(afterIndex + 1, newTimeSlot);
        print('🔍 [행추가] insert(${afterIndex + 1}, newTimeSlot) 실행 완료');
      } else {
        // 인덱스가 범위를 벗어나면 맨 끝에 추가
        print('🔍 [행추가] 조건 확인: ${afterIndex + 1} <= ${timeSlots.length} = false → add() 사용');
        timeSlots.add(newTimeSlot);
        print('🔍 [행추가] add(newTimeSlot) 실행 완료');
      }
      
      print('🔍 [행추가] 삽입 후 시간구획 수: ${timeSlots.length}');
      print('🔍 [행추가] 삽입 후 전체 시간구획 상태:');
      for (int i = 0; i < timeSlots.length; i++) {
        var slot = timeSlots[i];
        print('🔍 [행추가]   [$i] ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']}) - 해시코드: ${slot.hashCode}');
        if (i == afterIndex + 1 && afterIndex + 1 <= timeSlots.length - 1) {
          print('🔍 [행추가]   ⭐ 위 행이 새로 추가된 행입니다!');
        }
      }
      print('🔍 [행추가] ============================================');
    });
  }

  // 시간을 분으로 변환 (24:00은 1440분으로 처리)
  int _timeToMinutes(String time) {
    if (time == '24:00') {
      return 24 * 60; // 1440분
    }
    List<String> parts = time.split(':');
    int hours = int.parse(parts[0]);
    int minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }

  // 분을 시간으로 변환 (1440분은 24:00으로 표시)
  String _minutesToTime(int minutes) {
    // 24:00 (1440분)인 경우
    if (minutes == 24 * 60) {
      return '24:00';
    }
    // 24시간(1440분)을 넘어가는 경우 처리
    minutes = minutes % (24 * 60);
    int hours = minutes ~/ 60;
    int mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // 두 시간 구간이 겹치는지 확인 (정규화된 구간 사용)
  bool _isTimeRangeOverlap(Map<String, int> range1, Map<String, int> range2) {
    int start1 = range1['start']!;
    int end1 = range1['end']!;
    int start2 = range2['start']!;
    int end2 = range2['end']!;
    
    // 겹침 검사: 두 구간이 겹치면 true
    return (start1 < end2 && end1 > start2) || (start2 < end1 && end2 > start1);
  }

  // 시간구획을 정규화된 구간 리스트로 변환 (자정을 넘어가는 경우 두 구간으로 분리)
  List<Map<String, int>> _normalizeTimeSlot(Map<String, dynamic> slot) {
    List<Map<String, int>> normalizedRanges = [];
    const int fullDayMinutes = 24 * 60; // 1440분
    
    String startTime = slot['start_time']?.toString() ?? '';
    String endTime = slot['end_time']?.toString() ?? '';
    int startMin = _timeToMinutes(startTime);
    int endMin = _timeToMinutes(endTime);
    
    print('🔍 [정규화] 입력: $startTime ~ $endTime (${startMin}분 ~ ${endMin}분)');
    
    // 종료시간이 00:00인 경우 24:00으로 해석
    if (endMin == 0 && startMin != 0) {
      print('🔍 [정규화] 종료시간이 00:00이고 시작시간이 0이 아니므로 24:00(1440분)으로 변환');
      endMin = fullDayMinutes;
    }
    
    // 자정을 넘어가는 경우 두 구간으로 분리 (예: 23:00 ~ 06:00)
    if (endMin < startMin) {
      print('🔍 [정규화] 자정을 넘어가는 구간: ${startMin}분 ~ ${endMin}분');
      // 구간 1: startMin ~ 24:00
      normalizedRanges.add({'start': startMin, 'end': fullDayMinutes});
      print('🔍 [정규화] 구간 1 추가: ${startMin}분(${_minutesToTime(startMin)}) ~ ${fullDayMinutes}분(24:00)');
      // 구간 2: 00:00 ~ endMin
      if (endMin > 0) {
        normalizedRanges.add({'start': 0, 'end': endMin});
        print('🔍 [정규화] 구간 2 추가: 0분(00:00) ~ ${endMin}분(${_minutesToTime(endMin)})');
      }
    } else {
      // 일반적인 경우
      normalizedRanges.add({'start': startMin, 'end': endMin});
      print('🔍 [정규화] 일반 구간 추가: ${startMin}분(${_minutesToTime(startMin)}) ~ ${endMin}분(${_minutesToTime(endMin)})');
    }
    
    print('🔍 [정규화] 결과: ${normalizedRanges.length}개 구간');
    return normalizedRanges;
  }

  // 요일묶음 내 시간 겹침 검사 (정규화된 구간으로 정확하게 검사)
  String? _validateTimeOverlap(List<Map<String, dynamic>> timeSlots) {
    // 모든 시간구획을 정규화된 구간 리스트로 변환
    List<Map<String, dynamic>> normalizedSlots = [];
    
    for (int i = 0; i < timeSlots.length; i++) {
      var slot = timeSlots[i];
      var normalizedRanges = _normalizeTimeSlot(slot);
      
      for (var range in normalizedRanges) {
        normalizedSlots.add({
          'originalIndex': i,
          'originalSlot': slot,
          'range': range,
        });
      }
    }
    
    // 모든 정규화된 구간 쌍에 대해 겹침 검사
    for (int i = 0; i < normalizedSlots.length; i++) {
      for (int j = i + 1; j < normalizedSlots.length; j++) {
        var slot1 = normalizedSlots[i];
        var slot2 = normalizedSlots[j];
        
        // 같은 원본 시간구획이면 건너뛰기 (자정을 넘어가는 경우 같은 구간이 두 개로 나뉘어질 수 있음)
        if (slot1['originalIndex'] == slot2['originalIndex']) {
          continue;
        }
        
        Map<String, int> range1 = slot1['range'] as Map<String, int>;
        Map<String, int> range2 = slot2['range'] as Map<String, int>;
        
        // 겹침 검사
        if (_isTimeRangeOverlap(range1, range2)) {
          Map<String, dynamic> originalSlot1 = slot1['originalSlot'] as Map<String, dynamic>;
          Map<String, dynamic> originalSlot2 = slot2['originalSlot'] as Map<String, dynamic>;
          
          return '시간구획이 겹칩니다: ${originalSlot1['start_time']} ~ ${originalSlot1['end_time']} 와 ${originalSlot2['start_time']} ~ ${originalSlot2['end_time']}';
        }
      }
    }
    
    return null;
  }

  // 24시간 커버리지 검사 (각 요일묶음별)
  String? _validate24HourCoverage(List<Map<String, dynamic>> timeSlots, int dayGroupIndex) {
    print('🔍 ========== 24시간 커버리지 검사 시작 (요일묶음 ${dayGroupIndex + 1}) ==========');
    
    if (timeSlots.isEmpty) {
      print('🔍 [검증] 시간구획이 비어있음 - 다른 검증에서 처리');
      return null; // 빈 경우는 다른 검증에서 처리
    }
    
    print('🔍 [검증] 입력된 시간구획 수: ${timeSlots.length}개');
    for (int i = 0; i < timeSlots.length; i++) {
      var slot = timeSlots[i];
      print('🔍 [검증] 시간구획 ${i + 1}: ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']})');
    }
    
    // 모든 시간구획을 정규화된 구간 리스트로 변환 (자정을 넘어가는 경우 두 구간으로 분리)
    List<Map<String, int>> normalizedRanges = [];
    const int fullDayMinutes = 24 * 60; // 1440분
    
    for (var slot in timeSlots) {
      // _normalizeTimeSlot 함수 재사용
      var normalizedSlotRanges = _normalizeTimeSlot(slot);
      normalizedRanges.addAll(normalizedSlotRanges);
    }
    
    print('🔍 [검증] 정규화된 구간 수: ${normalizedRanges.length}개');
    
    // 시작시간 순으로 다시 정렬
    normalizedRanges.sort((a, b) => a['start']!.compareTo(b['start']!));
    
    print('🔍 [검증] 정렬된 정규화 구간:');
    for (var range in normalizedRanges) {
      print('🔍   - ${_minutesToTime(range['start']!)} (${range['start']}분) ~ ${_minutesToTime(range['end']!)} (${range['end']}분)');
    }
    
    // 00:00부터 시작해서 24:00까지 모든 시간이 커버되는지 확인
    List<String> missingRanges = [];
    int currentTime = 0; // 00:00 (0분)
    
    print('🔍 [검증] 커버리지 확인 시작 (현재시간: ${currentTime}분 = 00:00)');
    
    for (var range in normalizedRanges) {
      int startMin = range['start']!;
      int endMin = range['end']!;
      
      print('🔍 [검증] 구간 확인: ${_minutesToTime(startMin)} (${startMin}분) ~ ${_minutesToTime(endMin)} (${endMin}분), 현재시간: ${currentTime}분 (${_minutesToTime(currentTime)})');
      
      // 현재 시간과 시작 시간 사이에 빈 구간이 있는지 확인
      if (startMin > currentTime) {
        String missingStart = _minutesToTime(currentTime);
        String missingEnd = _minutesToTime(startMin);
        print('🔍 [검증] ❌ 빈 구간 발견: $missingStart (${currentTime}분) ~ $missingEnd (${startMin}분)');
        missingRanges.add('$missingStart ~ $missingEnd');
      } else {
        print('🔍 [검증] ✅ 구간 연속됨');
      }
      
      // 현재 시간을 종료 시간으로 업데이트 (더 큰 값으로)
      int oldCurrentTime = currentTime;
      currentTime = endMin > currentTime ? endMin : currentTime;
      if (oldCurrentTime != currentTime) {
        print('🔍 [검증] 현재시간 업데이트: ${oldCurrentTime}분 (${_minutesToTime(oldCurrentTime)}) → ${currentTime}분 (${_minutesToTime(currentTime)})');
      }
    }
    
    // 마지막 시간구획 이후 24:00까지 빈 구간이 있는지 확인
    print('🔍 [검증] 최종 확인: 현재시간=${currentTime}분 (${_minutesToTime(currentTime)}), 목표=${fullDayMinutes}분 (24:00)');
    if (currentTime < fullDayMinutes) {
      String missingStart = _minutesToTime(currentTime);
      print('🔍 [검증] ❌ 마지막 구간 이후 빈 구간 발견: $missingStart (${currentTime}분) ~ 24:00 (${fullDayMinutes}분)');
      missingRanges.add('$missingStart ~ 24:00');
    } else {
      print('🔍 [검증] ✅ 24시간 전체 커버됨');
    }
    
    if (missingRanges.isNotEmpty) {
      String errorMsg = '요일묶음 ${dayGroupIndex + 1}: 정책이 설정되지 않은 시간대가 있습니다.\n${missingRanges.join(', ')}';
      print('🔍 [검증] ❌ 검증 실패: $errorMsg');
      print('🔍 ============================================');
      return errorMsg;
    }
    
    print('🔍 [검증] ✅ 검증 성공 - 모든 시간대가 커버됨');
    print('🔍 ============================================');
    return null;
  }

  // 요일 중복/누락 검사
  String? _validateDayGroups() {
    List<String> allDays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일', '공휴일'];
    List<String> usedDays = [];
    
    // 각 요일묶음에서 사용된 요일 수집 및 중복 검사
    for (int i = 0; i < _dayGroups.length; i++) {
      List<String> selectedDays = List<String>.from(_dayGroups[i]['selectedDays']);
      
      // 요일이 선택되지 않은 요일묶음은 건너뛰기 (DB에 남아있는 불필요한 데이터)
      if (selectedDays.isEmpty) {
        continue;
      }
      
      for (String day in selectedDays) {
        if (usedDays.contains(day)) {
          return '요일 "$day"이(가) 중복되었습니다.';
        }
        usedDays.add(day);
      }
    }
    
    // 누락된 요일 검사
    List<String> missingDays = allDays.where((day) => !usedDays.contains(day)).toList();
    if (missingDays.isNotEmpty) {
      return '누락된 요일이 있습니다: ${missingDays.join(', ')}';
    }
    
    return null;
  }

  // 전체 검증 실행
  String? _validateAllData() {
    // 요일묶음이 비어있는지 검사
    if (_dayGroups.isEmpty) {
      return '최소 하나의 요일묶음이 필요합니다.';
    }
    
    // 각 요일묶음 내 시간 겹침 검사
    for (int i = 0; i < _dayGroups.length; i++) {
      Map<String, dynamic> dayGroup = _dayGroups[i];
      List<String> selectedDays = List<String>.from(dayGroup['selectedDays']);
      List<Map<String, dynamic>> timeSlots = List<Map<String, dynamic>>.from(dayGroup['timeSlots']);
      
      // 요일이 선택되지 않은 요일묶음은 검증에서 제외 (DB에 남아있는 불필요한 데이터)
      if (selectedDays.isEmpty) {
        print('🔍 [검증] 요일묶음 ${i + 1}: 요일이 선택되지 않아 검증 건너뜀');
        continue;
      }
      
      if (timeSlots.isEmpty) {
        return '요일묶음 ${i + 1}에 시간구획이 없습니다.';
      }
      
      String? timeError = _validateTimeOverlap(timeSlots);
      if (timeError != null) {
        return '요일묶음 ${i + 1}: $timeError';
      }
      
      // 시간 형식 검사
      for (int j = 0; j < timeSlots.length; j++) {
        String startTime = timeSlots[j]['start_time'];
        String endTime = timeSlots[j]['end_time'];
        
        if (!_isValidTime(startTime)) {
          return '요일묶음 ${i + 1}, 시간구획 ${j + 1}: 잘못된 시작시간 형식 ($startTime)';
        }
        
        if (!_isValidTime(endTime)) {
          return '요일묶음 ${i + 1}, 시간구획 ${j + 1}: 잘못된 종료시간 형식 ($endTime)';
        }
        
        if (timeSlots[j]['category'].isEmpty) {
          return '요일묶음 ${i + 1}, 시간구획 ${j + 1}: 과금정책이 선택되지 않았습니다.';
        }
      }
      
      // 24시간 커버리지 검사
      String? coverageError = _validate24HourCoverage(timeSlots, i + 1);
      if (coverageError != null) {
        return coverageError;
      }
    }
    
    // 요일 중복/누락 검사
    String? dayError = _validateDayGroups();
    if (dayError != null) {
      return dayError;
    }
    
    return null;
  }

  // 요일묶음 삭제
  void _removeDayGroup(int index) {
    setState(() {
      _dayGroups.removeAt(index);
    });
  }

  // 시간구획 삭제
  void _removeTimeSlot(int dayGroupIndex, int timeSlotIndex) {
    setState(() {
      (_dayGroups[dayGroupIndex]['timeSlots'] as List<Map<String, dynamic>>).removeAt(timeSlotIndex);
    });
  }

  // 요일 선택/해제
  void _toggleDay(int dayGroupIndex, String day) {
    setState(() {
      List<String> selectedDays = List<String>.from(_dayGroups[dayGroupIndex]['selectedDays']);
      
      if (selectedDays.contains(day)) {
        // 이미 선택된 요일이면 해제
        selectedDays.remove(day);
      } else {
        // 다른 요일묶음에서 이미 선택된 요일인지 확인
        bool isAlreadySelected = false;
        for (int i = 0; i < _dayGroups.length; i++) {
          if (i != dayGroupIndex) {
            List<String> otherSelectedDays = List<String>.from(_dayGroups[i]['selectedDays']);
            if (otherSelectedDays.contains(day)) {
              isAlreadySelected = true;
              break;
            }
          }
        }
        
        if (!isAlreadySelected) {
          selectedDays.add(day);
        }
      }
      _dayGroups[dayGroupIndex]['selectedDays'] = selectedDays;
    });
  }

  // 시간 포맷팅 (0700 -> 07:00)
  String _formatTime(String time) {
    if (time.contains(':')) return time;
    if (time.length == 4) {
      return '${time.substring(0, 2)}:${time.substring(2, 4)}';
    }
    return time;
  }

  // 시간 입력 검증 (24:00도 허용)
  bool _isValidTime(String time) {
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-4]):[0-5][0-9]$|^([0-1]?[0-9]|2[0-4])[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  // 24:00을 00:00으로 변환하는 함수
  String _normalizeTime(String time) {
    if (time == '24:00') {
      return '00:00';
    }
    return time;
  }

  // 선택된 요일들을 문자열로 변환 (짧은 형태로)
  String _getDayGroupName(List<String> selectedDays) {
    if (selectedDays.isEmpty) return '요일 미선택';
    // 전체 요일명을 짧은 형태로 변환
    List<String> shortDays = selectedDays.map((day) {
      switch (day) {
        case '월요일': return '월';
        case '화요일': return '화';
        case '수요일': return '수';
        case '목요일': return '목';
        case '금요일': return '금';
        case '토요일': return '토';
        case '일요일': return '일';
        case '공휴일': return '공휴일';
        default: return day;
      }
    }).toList();
    return shortDays.join(', ');
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

  Widget _buildEditableCell({
    required String value,
    required Function(String) onChanged,
    required TextInputType keyboardType,
    String? suffix,
    Color? textColor,
    Key? key,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: TextFormField(
          key: key,
          initialValue: value,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: textColor ?? TableDesign.textColorPrimary,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDropdownCell({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value.isNotEmpty ? value : null,
            hint: Text(
              '선택',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            isExpanded: true,
            dropdownColor: Colors.white,
            menuMaxHeight: 200,
            icon: Icon(Icons.arrow_drop_down, size: 20),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Center(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: TableDesign.textColorPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // 요일 선택 타일들 (2열 배치용 - 빈칸 포함)
  Widget _buildDaySelectionTiles(int dayGroupIndex) {
    List<String> selectedDays = List<String>.from(_dayGroups[dayGroupIndex]['selectedDays']);
    
    // 다른 요일묶음에서 이미 선택된 요일들 수집
    Set<String> alreadySelectedDays = {};
    for (int i = 0; i < _dayGroups.length; i++) {
      if (i != dayGroupIndex) {
        List<String> otherSelectedDays = List<String>.from(_dayGroups[i]['selectedDays']);
        alreadySelectedDays.addAll(otherSelectedDays);
      }
    }
    
    return Row(
      children: [
        // 첫 번째 열: 월요일수요일금요일토요일공휴일
        Expanded(
          child: Column(
            children: _weekdays1.map((day) {
              if (day.isEmpty) {
                // 빈칸 처리
                return Container(
                  width: double.infinity,
                  height: 40, // 다른 타일과 같은 높이
                  margin: EdgeInsets.only(bottom: 4),
                );
              }
              
              final isSelected = selectedDays.contains(day);
              final isDisabled = alreadySelectedDays.contains(day);
              
              return GestureDetector(
                onTap: isDisabled ? null : () => _toggleDay(dayGroupIndex, day),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDisabled 
                        ? Color(0xFFE5E7EB) 
                        : isSelected 
                            ? Color(0xFF6366F1) 
                            : Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDisabled 
                          ? Color(0xFFD1D5DB)
                          : isSelected 
                              ? Color(0xFF6366F1) 
                              : Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDisabled
                          ? Color(0xFF9CA3AF)
                          : isSelected
                              ? Colors.white
                              : TableDesign.textColorPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(width: 8),
        // 두 번째 열: 화요일목요일(빈칸)일요일(빈칸)
        Expanded(
          child: Column(
            children: _weekdays2.map((day) {
              if (day.isEmpty) {
                // 빈칸 처리
                return Container(
                  width: double.infinity,
                  height: 40, // 다른 타일과 같은 높이
                  margin: EdgeInsets.only(bottom: 4),
                );
              }
              
              final isSelected = selectedDays.contains(day);
              final isDisabled = alreadySelectedDays.contains(day);
              
              return GestureDetector(
                onTap: isDisabled ? null : () => _toggleDay(dayGroupIndex, day),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDisabled 
                        ? Color(0xFFE5E7EB) 
                        : isSelected 
                            ? Color(0xFF6366F1) 
                            : Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDisabled 
                          ? Color(0xFFD1D5DB)
                          : isSelected 
                              ? Color(0xFF6366F1) 
                              : Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDisabled
                          ? Color(0xFF9CA3AF)
                          : isSelected
                              ? Colors.white
                              : TableDesign.textColorPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 요일묶음 카드 (수정모드용) - 컴팩트 버전
  Widget _buildDayGroupCard(int dayGroupIndex) {
    Map<String, dynamic> dayGroup = _dayGroups[dayGroupIndex];
    
    print('🔍 [렌더링] ========== 요일묶음 $dayGroupIndex 렌더링 시작 ==========');
    print('🔍 [렌더링] 원본 _dayGroups[$dayGroupIndex] 시간구획 수: ${(dayGroup['timeSlots'] as List).length}');
    print('🔍 [렌더링] 원본 _dayGroups[$dayGroupIndex] 시간구획 내용:');
    for (int i = 0; i < (dayGroup['timeSlots'] as List).length; i++) {
      var slot = (dayGroup['timeSlots'] as List)[i];
      print('🔍 [렌더링]   원본[$i] ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']}) - 해시코드: ${slot.hashCode}');
    }
    
    // 깊은 복사로 변경 (Map 객체도 복사)
    List<Map<String, dynamic>> timeSlots = (dayGroup['timeSlots'] as List).map((slot) => Map<String, dynamic>.from(slot)).toList();
    List<String> selectedDays = List<String>.from(dayGroup['selectedDays']);
    
    print('🔍 [렌더링] 깊은 복사 후 timeSlots 수: ${timeSlots.length}');
    print('🔍 [렌더링] 깊은 복사 후 timeSlots 내용:');
    for (int i = 0; i < timeSlots.length; i++) {
      var slot = timeSlots[i];
      print('🔍 [렌더링]   복사본[$i] ${slot['start_time']} ~ ${slot['end_time']} (${slot['category']}) - 해시코드: ${slot.hashCode}');
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌우 배치: 왼쪽 요일 선택, 오른쪽 시간구획 설정
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 요일묶음 헤더 + 요일 선택
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // 요일묶음 헤더 (시간추가 버튼 제거)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: TableDesign.headerBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '요일묶음 ${dayGroupIndex + 1}: ${_getDayGroupName(selectedDays)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Color(0xFFEF4444), size: 18),
                              onPressed: () => _removeDayGroup(dayGroupIndex),
                              tooltip: '요일묶음 삭제',
                              padding: EdgeInsets.all(4),
                              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      // 요일 선택
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFBAE6FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '요일 선택',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildDaySelectionTiles(dayGroupIndex),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                
                // 오른쪽: 시간구획 설정
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 테이블 제목만 (시간구획 추가 버튼 제거)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: TableDesign.headerBackground,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            '시간구획 설정',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: TableDesign.headerTextColor,
                            ),
                          ),
                        ),
                        // 테이블 헤더
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text('시작', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TableDesign.headerTextColor))),
                              Expanded(flex: 2, child: Text('종료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TableDesign.headerTextColor))),
                              Expanded(flex: 2, child: Text('과금정책', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TableDesign.headerTextColor))),
                              Expanded(flex: 2, child: Text('작업', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TableDesign.headerTextColor), textAlign: TextAlign.center)),
                            ],
                          ),
                        ),
                        // 시간구획 행들
                        ...timeSlots.asMap().entries.map((timeSlotEntry) {
                          int timeSlotIndex = timeSlotEntry.key;
                          Map<String, dynamic> timeSlot = timeSlotEntry.value;
                          
                          // 클로저 문제 방지를 위해 값 미리 저장
                          String startTime = timeSlot['start_time']?.toString() ?? '00:00';
                          String endTime = timeSlot['end_time']?.toString() ?? '00:00';
                          String category = timeSlot['category']?.toString() ?? '일반';
                          
                          // 렌더링 시점 값 확인 (모든 행 출력)
                          print('🔍 [렌더링] 요일묶음 $dayGroupIndex, 시간구획 $timeSlotIndex: $startTime ~ $endTime ($category) - 해시코드: ${timeSlot.hashCode}');
                          
                          return Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: timeSlotIndex % 2 == 0 ? Colors.white : Color(0xFFFAFAFA),
                              border: Border(
                                bottom: timeSlotIndex < timeSlots.length - 1 
                                  ? BorderSide(color: Color(0xFFE5E7EB), width: 1)
                                  : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                // 시작시간
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: _buildEditableCell(
                                      key: ValueKey('start_${dayGroupIndex}_${timeSlotIndex}_$startTime'), // value 포함하여 값 변경 시 재생성
                                      value: startTime,
                                      onChanged: (value) {
                                        print('🔍 [입력] 시작시간 입력: "$value" (원본: $startTime)');
                                        String formattedTime = _formatTime(value);
                                        print('🔍 [입력] 포맷팅 후: "$formattedTime"');
                                        if (_isValidTime(formattedTime)) {
                                          print('🔍 [입력] 유효한 시간 - 저장: "$formattedTime"');
                                          setState(() {
                                            // 원본 _dayGroups를 직접 수정
                                            _dayGroups[dayGroupIndex]['timeSlots'][timeSlotIndex]['start_time'] = formattedTime;
                                          });
                                        } else {
                                          print('🔍 [입력] ❌ 유효하지 않은 시간 형식: "$formattedTime"');
                                        }
                                      },
                                      keyboardType: TextInputType.text,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                // 종료시간
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: _buildEditableCell(
                                      key: ValueKey('end_${dayGroupIndex}_${timeSlotIndex}_$endTime'), // value 포함하여 값 변경 시 재생성
                                      value: endTime,
                                      onChanged: (value) {
                                        print('🔍 [입력] 종료시간 입력: "$value" (원본: $endTime)');
                                        String formattedTime = _formatTime(value);
                                        print('🔍 [입력] 포맷팅 후: "$formattedTime"');
                                        if (_isValidTime(formattedTime)) {
                                          print('🔍 [입력] 유효한 시간 - 저장: "$formattedTime"');
                                          setState(() {
                                            // 원본 _dayGroups를 직접 수정
                                            _dayGroups[dayGroupIndex]['timeSlots'][timeSlotIndex]['end_time'] = formattedTime;
                                          });
                                        } else {
                                          print('🔍 [입력] ❌ 유효하지 않은 시간 형식: "$formattedTime"');
                                        }
                                      },
                                      keyboardType: TextInputType.text,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                // 과금정책
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: _buildDropdownCell(
                                      value: category,
                                      items: _categories,
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            // 원본 _dayGroups를 직접 수정
                                            _dayGroups[dayGroupIndex]['timeSlots'][timeSlotIndex]['category'] = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                // 작업 버튼들
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 시간구획 행 추가 버튼
                                      IconButton(
                                        icon: Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 14),
                                        onPressed: () => _insertTimeSlot(dayGroupIndex, timeSlotIndex),
                                        tooltip: '시간구획 행 추가',
                                        padding: EdgeInsets.all(2),
                                        constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                      // 삭제 버튼
                                      IconButton(
                                        icon: Icon(Icons.remove_circle, color: Color(0xFFEF4444), size: 14),
                                        onPressed: () => _removeTimeSlot(dayGroupIndex, timeSlotIndex),
                                        tooltip: '시간구획 삭제',
                                        padding: EdgeInsets.all(2),
                                        constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 왼쪽: 수정 버튼 (일반 모드) 또는 요일묶음 추가 버튼 (편집 모드)
              if (_isEditMode)
                ButtonDesignUpper.buildIconButton(
                  text: '요일묶음 추가',
                  icon: Icons.event_available,
                  onPressed: _addDayGroup,
                  color: 'blue',
                  size: 'large',
                )
              else
                ButtonDesignUpper.buildIconButton(
                  text: '수정',
                  icon: Icons.edit_calendar,
                  onPressed: () {
                    setState(() {
                      _isEditMode = !_isEditMode;
                    });
                  },
                  color: 'blue',
                  size: 'large',
                ),
              // 오른쪽: 편집 모드일 때만 취소, 저장 버튼 표시
              if (_isEditMode)
                Row(
                  children: [
                    ButtonDesignUpper.buildIconButton(
                      text: '취소',
                      icon: Icons.close,
                      onPressed: () {
                        setState(() {
                          _isEditMode = false;
                        });
                      },
                      color: 'gray',
                      size: 'large',
                    ),
                    SizedBox(width: 12.0),
                    ButtonDesignUpper.buildIconButton(
                      text: '저장',
                      icon: Icons.save,
                      onPressed: () async {
                        // 검증 실행
                        String? validationError = _validateAllData();
                        if (validationError != null) {
                          _showErrorSnackBar(validationError);
                          return;
                        }

                        // API로 데이터 저장
                        await _savePricingPolicyData();

                        setState(() {
                          _isEditMode = false;
                        });
                      },
                      color: 'green',
                      size: 'large',
                    ),
                  ],
                ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 컨텐츠
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '데이터를 처리하고 있습니다...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : _dayGroups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.schedule,
                              size: 64,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            '설정된 과금 정보가 없습니다',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '요일묶음을 추가해보세요',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isEditMode
                      ? SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: _dayGroups.asMap().entries.map((entry) {
                              return _buildDayGroupCard(entry.key);
                            }).toList(),
                          ),
                        )
                      : TableDesign.buildTableContainer(
                          child: Column(
                            children: [
                              TableDesign.buildTableHeader(
                                children: [
                                  TableDesign.buildHeaderColumn(text: '요일구분', flex: 3),
                                  TableDesign.buildHeaderColumn(text: '시작시간', flex: 2),
                                  TableDesign.buildHeaderColumn(text: '종료시간', flex: 2),
                                  TableDesign.buildHeaderColumn(text: '과금정책', flex: 3),
                                ],
                              ),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    // 모든 요일묶음의 시간구획을 하나의 리스트로 flatten
                                    List<Map<String, dynamic>> flattenedRows = [];
                                    for (int dayGroupIndex = 0; dayGroupIndex < _dayGroups.length; dayGroupIndex++) {
                                      Map<String, dynamic> dayGroup = _dayGroups[dayGroupIndex];
                                      List<Map<String, dynamic>> timeSlots = List<Map<String, dynamic>>.from(dayGroup['timeSlots']);
                                      List<String> selectedDays = List<String>.from(dayGroup['selectedDays']);

                                      for (int timeSlotIndex = 0; timeSlotIndex < timeSlots.length; timeSlotIndex++) {
                                        flattenedRows.add({
                                          'dayGroupIndex': dayGroupIndex,
                                          'timeSlotIndex': timeSlotIndex,
                                          'selectedDays': selectedDays,
                                          'timeSlot': timeSlots[timeSlotIndex],
                                        });
                                      }
                                    }

                                    return TableDesign.buildTableBody(
                                      itemCount: flattenedRows.length,
                                      itemBuilder: (context, index) {
                                        final row = flattenedRows[index];
                                        final timeSlotIndex = row['timeSlotIndex'] as int;
                                        final selectedDays = row['selectedDays'] as List<String>;
                                        final timeSlot = row['timeSlot'] as Map<String, dynamic>;

                                        return TableDesign.buildTableRow(
                                          children: [
                                            // 요일구분 (첫 번째 시간구획에만 표시)
                                            TableDesign.buildColumn(
                                              flex: 3,
                                              child: timeSlotIndex == 0
                                                  ? Text(
                                                      _getDayGroupName(selectedDays),
                                                      style: TextStyle(
                                                        fontFamily: 'Pretendard',
                                                        color: TableDesign.textColorPrimary,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    )
                                                  : SizedBox(),
                                            ),
                                            // 시작시간
                                            TableDesign.buildRowColumn(
                                              text: timeSlot['start_time'],
                                              flex: 2,
                                              fontSize: 15,
                                            ),
                                            // 종료시간
                                            TableDesign.buildRowColumn(
                                              text: timeSlot['end_time'],
                                              flex: 2,
                                              fontSize: 15,
                                            ),
                                            // 과금정책 배지
                                            TableDesign.buildColumn(
                                              flex: 3,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: timeSlot['category'] == '할인' ? Color(0xFF10B981).withOpacity(0.1) :
                                                         timeSlot['category'] == '할증' ? Color(0xFFF59E0B).withOpacity(0.1) :
                                                         timeSlot['category'] == '미운영' ? Color(0xFF6B7280).withOpacity(0.1) :
                                                         Color(0xFF6366F1).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  timeSlot['category'],
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: timeSlot['category'] == '할인' ? Color(0xFF10B981) :
                                                           timeSlot['category'] == '할증' ? Color(0xFFF59E0B) :
                                                           timeSlot['category'] == '미운영' ? Color(0xFF6B7280) :
                                                           Color(0xFF6366F1),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ],
    );
  }
} 