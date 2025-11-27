import 'api_service.dart';

/// 시간대별 예약내역 계산 결과 모델
class PricingResult {
  final Map<String, int> timeAnalysis;      // 시간대별 분석 (분 단위)
  final Map<String, int> priceAnalysis;     // 시간대별 요금 분석
  final int totalPrice;                     // 총 요금
  final int totalMinutes;                   // 총 시간(분)
  final String endTime;                     // 종료 시간
  final Map<String, dynamic>? tsInfo;       // 타석 정보
  
  PricingResult({
    required this.timeAnalysis,
    required this.priceAnalysis,
    required this.totalPrice,
    required this.totalMinutes,
    required this.endTime,
    this.tsInfo,
  });
  
  /// 시간대별 예약내역 리스트 반환 (UI 표시용)
  List<Map<String, dynamic>> getTimeBreakdown() {
    List<Map<String, dynamic>> breakdown = [];
    
    timeAnalysis.forEach((policyKey, minutes) {
      if (minutes > 0) {
        final price = priceAnalysis[policyKey] ?? 0;
        breakdown.add({
          'timeSlot': _getPolicyDisplayName(policyKey),
          'minutes': minutes,
          'price': price,
          'policyKey': policyKey,
        });
      }
    });
    
    return breakdown;
  }
  
  /// 요금 정책 이름 변환
  String _getPolicyDisplayName(String policyKey) {
    switch (policyKey) {
      case 'base_price':
        return '일반';
      case 'discount_price':
        return '할인';
      case 'extracharge_price':
        return '할증';
      case 'out_of_business':
        return '미운영';
      default:
        return policyKey;
    }
  }
}

/// 타석 예약 시간대별 요금 계산 서비스
class TsPricingService {
  
  /// 시간대별 예약내역 계산 (메인 함수)
  /// 
  /// [selectedDate] 선택된 날짜
  /// [selectedTime] 선택된 시작 시간 (예: "09:00")
  /// [selectedDuration] 선택된 연습 시간 (분 단위)
  /// [selectedTs] 선택된 타석 ID
  /// [memberId] 회원 ID (선택사항 - 할인권 조회용)
  /// 
  /// 반환값: PricingResult 객체
  static Future<PricingResult?> calculatePricing({
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
    String? memberId,
  }) async {
    try {
      print('=== TsPricingService.calculatePricing 시작 ===');
      print('선택된 날짜: $selectedDate');
      print('선택된 시간: $selectedTime');
      print('선택된 연습시간: ${selectedDuration}분');
      print('선택된 타석: $selectedTs');
      print('회원 ID: $memberId');
      
      // 1. 종료 시간 계산
      final endTime = _calculateEndTime(selectedTime, selectedDuration);
      print('계산된 종료시간: $endTime');
      
      // 2. 타석 정보 조회 (단가 정보)
      final tsInfo = await ApiService.getTsInfoById(tsId: selectedTs);
      if (tsInfo == null) {
        print('타석 정보 조회 실패: $selectedTs');
        return null;
      }
      print('타석 정보: $tsInfo');
      
      // 3. 요금 정책 조회
      final pricingPolicies = await ApiService.getTsPricingPolicy(date: selectedDate);
      if (pricingPolicies.isEmpty) {
        print('요금 정책 조회 실패');
        return null;
      }
      print('조회된 요금 정책 수: ${pricingPolicies.length}');
      
      // 4. 시간대별 요금 분석 (분 단위)
      final timeAnalysis = ApiService.analyzePricingByTimeRange(
        startTime: selectedTime,
        endTime: endTime,
        pricingPolicies: pricingPolicies,
      );
      print('시간대별 분석 결과: $timeAnalysis');
      
      // 5. 실제 요금 계산
      final priceAnalysis = _calculateFinalPricing(tsInfo, timeAnalysis);
      print('요금 분석 결과: $priceAnalysis');
      
      // 6. 총 요금 계산
      final totalPrice = priceAnalysis.values.fold(0, (sum, price) => sum + price);
      print('총 요금: $totalPrice원');
      
      return PricingResult(
        timeAnalysis: timeAnalysis,
        priceAnalysis: priceAnalysis,
        totalPrice: totalPrice,
        totalMinutes: selectedDuration,
        endTime: endTime,
        tsInfo: tsInfo,
      );
      
    } catch (e) {
      print('시간대별 예약내역 계산 오류: $e');
      return null;
    }
  }
  
  /// 종료 시간 계산
  static String _calculateEndTime(String startTime, int durationMinutes) {
    try {
      final parts = startTime.split(':');
      final startHour = int.parse(parts[0]);
      final startMinute = int.parse(parts[1]);
      
      final totalMinutes = startHour * 60 + startMinute + durationMinutes;
      final endHour = (totalMinutes ~/ 60) % 24;
      final endMinute = totalMinutes % 60;
      
      return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('종료 시간 계산 오류: $e');
      return '00:00';
    }
  }
  
  /// 최종 요금 계산
  static Map<String, int> _calculateFinalPricing(
    Map<String, dynamic> tsInfo,
    Map<String, int> timeAnalysis,
  ) {
    try {
      print('=== 최종 요금 계산 시작 ===');
      
      // 타석 단가 정보 (60분 기준)
      final basePricePerHour = int.tryParse(tsInfo['base_price']?.toString() ?? '0') ?? 0;
      final discountPricePerHour = int.tryParse(tsInfo['discount_price']?.toString() ?? '0') ?? 0;
      final extrachargePricePerHour = int.tryParse(tsInfo['extracharge_price']?.toString() ?? '0') ?? 0;
      
      print('타석 단가 (60분 기준):');
      print('- 일반: $basePricePerHour원');
      print('- 할인: $discountPricePerHour원');
      print('- 할증: $extrachargePricePerHour원');
      
      Map<String, int> priceAnalysis = {};
      
      // 각 시간대별로 요금 계산
      timeAnalysis.forEach((policyKey, minutes) {
        if (minutes > 0) {
          int pricePerHour = 0;
          
          switch (policyKey) {
            case 'base_price':
              pricePerHour = basePricePerHour;
              break;
            case 'discount_price':
              pricePerHour = discountPricePerHour;
              break;
            case 'extracharge_price':
              pricePerHour = extrachargePricePerHour;
              break;
            default:
              pricePerHour = 0;
          }
          
          // 분 단위로 요금 계산: (시간당 단가 / 60분) * 이용 분
          final finalPrice = ((pricePerHour / 60) * minutes).round();
          
          priceAnalysis[policyKey] = finalPrice;
          
          print('$policyKey: ${minutes}분 × (${pricePerHour}원/60분) = ${finalPrice}원');
        }
      });
      
      return priceAnalysis;
      
    } catch (e) {
      print('최종 요금 계산 오류: $e');
      return {};
    }
  }
  
  /// 간단한 총 요금만 계산하는 함수 (빠른 계산용)
  static Future<int?> calculateTotalPrice({
    required DateTime selectedDate,
    required String selectedTime,
    required int selectedDuration,
    required String selectedTs,
  }) async {
    final result = await calculatePricing(
      selectedDate: selectedDate,
      selectedTime: selectedTime,
      selectedDuration: selectedDuration,
      selectedTs: selectedTs,
    );
    
    return result?.totalPrice;
  }
  
  /// 시간대별 예약내역을 문자열로 포맷 (로깅/디버깅용)
  static String formatPricingResult(PricingResult result) {
    final buffer = StringBuffer();
    buffer.writeln('=== 시간대별 예약내역 ===');
    buffer.writeln('예약 시간: ${result.totalMinutes}분');
    buffer.writeln('종료 시간: ${result.endTime}');
    buffer.writeln('');
    
    final breakdown = result.getTimeBreakdown();
    for (final item in breakdown) {
      buffer.writeln('${item['timeSlot']}: ${item['minutes']}분 - ${item['price']}원');
    }
    
    buffer.writeln('');
    buffer.writeln('총 요금: ${result.totalPrice}원');
    
    return buffer.toString();
  }
} 