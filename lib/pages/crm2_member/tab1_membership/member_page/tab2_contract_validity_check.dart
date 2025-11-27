/// 계약 만료 및 유효성 검증을 위한 비즈니스 로직 클래스
///
/// 이 클래스는 다양한 타입의 계약(크레딧, 레슨권, 시간권, 게임권, 기간권)에 대한
/// 만료 여부와 유효성을 판정하는 비즈니스 로직을 담당합니다.
class ContractValidityChecker {

  /// 계약이 만료되었는지 확인
  ///
  /// [contract] 계약 정보 Map
  /// [debug] 디버그 정보 출력 여부
  ///
  /// 반환값:
  /// - true: 만료된 계약 (모든 잔액이 0이고 유효기간도 만료)
  /// - false: 유효한 계약 (잔액이 있거나 유효기간이 남음)
  static bool isExpiredContract(Map<String, dynamic> contract, {bool debug = false}) {
    final contractName = contract['contract_name'] ?? '';
    final contractType = contract['contract_type'] ?? '';

    // 락커 계약은 만료 로직에서 제외 (단일 날짜로 끝나므로)
    if (contractType.contains('락커') || contractType.contains('locker')) {
      if (debug) print('🔐 $contractName: 락커계약 → 만료로직 제외');
      return false;
    }

    // 잔액이 하나라도 있으면 만료되지 않음
    final hasBalance = hasTransferableBalance(contract, debug: debug);

    if (hasBalance) {
      if (debug) print('💰 $contractName: 잔액있음 → 유효');
      return false;
    }

    // 모든 잔액이 0이고 기간권도 만료되었으면 만료된 계약
    if (debug) print('⏰ $contractName: 모든잔액 0 → 만료');
    return true;
  }

  /// 양도 가능한 잔액이 있는지 확인
  ///
  /// [contract] 계약 정보 Map
  /// [debug] 디버그 정보 출력 여부
  ///
  /// 반환값:
  /// - true: 양도 가능한 잔액이 하나라도 있음
  /// - false: 모든 잔액이 0
  static bool hasTransferableBalance(Map<String, dynamic> contract, {bool debug = false}) {
    final contractName = contract['contract_name'] ?? '';
    List<String> balanceDetails = [];
    // 크레딧 잔액 확인
    final creditBalance = safeParseInt(contract['credit_balance']) ?? 0;
    if (creditBalance > 0) {
      balanceDetails.add('크레딧${creditBalance}원');
      if (debug) print('  💰 $contractName: $balanceDetails → 유효');
      return true;
    }

    // 레슨권 잔액 확인
    final lessonBalance = safeParseInt(contract['lesson_balance']) ?? 0;
    if (lessonBalance > 0) {
      balanceDetails.add('레슨${lessonBalance}분');
      if (debug) print('  💰 $contractName: $balanceDetails → 유효');
      return true;
    }

    // 시간권 잔액 확인
    final timeBalance = safeParseInt(contract['time_balance']) ?? 0;
    if (timeBalance > 0) {
      balanceDetails.add('시간${timeBalance}분');
      if (debug) print('  💰 $contractName: $balanceDetails → 유효');
      return true;
    }

    // 게임권 잔액 확인
    final gameBalance = safeParseInt(contract['game_balance']) ?? 0;
    if (gameBalance > 0) {
      balanceDetails.add('게임${gameBalance}회');
      if (debug) print('  💰 $contractName: $balanceDetails → 유효');
      return true;
    }

    // 기간권 확인 (남은 일수)
    final termDaysLeft = safeParseInt(contract['term_remaining_days']) ?? 0;
    if (termDaysLeft > 0) {
      balanceDetails.add('기간${termDaysLeft}일');
      if (debug) print('  💰 $contractName: $balanceDetails → 유효');
      return true;
    }

    if (debug) {
      List<String> zeroBalances = [];
      if (creditBalance == 0) zeroBalances.add('크레딧0');
      if (lessonBalance == 0) zeroBalances.add('레슨0');
      if (timeBalance == 0) zeroBalances.add('시간0');
      if (gameBalance == 0) zeroBalances.add('게임0');
      if (termDaysLeft == 0) zeroBalances.add('기간0일');
      print('  ❌ $contractName: ${zeroBalances.join(', ')} → 만료');
    }
    return false;
  }

  /// 유효기간이 만료되었는지 확인
  ///
  /// [contract] 계약 정보 Map
  ///
  /// 반환값:
  /// - true: 유효기간이 만료됨
  /// - false: 유효기간이 남아있음
  static bool isDateExpired(Map<String, dynamic> contract) {
    final latestExpiryDate = getLatestExpiryDate(contract);
    if (latestExpiryDate != null) {
      try {
        final expiryDate = DateTime.parse(latestExpiryDate);
        final today = DateTime.now();
        return expiryDate.isBefore(today);
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// 계약이 유효한지 확인 (만료되지 않았고 잔액이 있는지)
  ///
  /// [contract] 계약 정보 Map
  ///
  /// 반환값:
  /// - true: 유효한 계약 (날짜도 유효하고 잔액도 있음)
  /// - false: 만료되었거나 잔액이 없음
  static bool isContractActive(Map<String, dynamic> contract) {
    return !isDateExpired(contract) && !isBalanceEmpty(contract);
  }

  /// 잔액이 모두 비어있는지 확인
  ///
  /// [contract] 계약 정보 Map
  ///
  /// 반환값:
  /// - true: 모든 잔액이 0
  /// - false: 하나라도 잔액이 있음
  static bool isBalanceEmpty(Map<String, dynamic> contract) {
    // 어떤 혜택이라도 있는지 확인
    bool hasAnyBenefit = false;
    bool hasBalance = false;

    // 크레딧 확인
    final creditBalance = safeParseInt(contract['credit_balance']) ?? 0;
    if (creditBalance > 0) {
      hasAnyBenefit = true;
      hasBalance = true;
    }

    // 레슨권 확인
    final lessonBalance = safeParseInt(contract['lesson_balance']) ?? 0;
    if (lessonBalance > 0) {
      hasAnyBenefit = true;
      hasBalance = true;
    }

    // 시간권 확인
    final timeBalance = safeParseInt(contract['time_balance']) ?? 0;
    if (timeBalance > 0) {
      hasAnyBenefit = true;
      hasBalance = true;
    }

    // 게임권 확인
    final gameBalance = safeParseInt(contract['game_balance']) ?? 0;
    if (gameBalance > 0) {
      hasAnyBenefit = true;
      hasBalance = true;
    }

    // 기간권 확인
    final termMonth = safeParseInt(contract['contract_term_month']) ?? 0;
    if (termMonth > 0) {
      hasAnyBenefit = true;
      final remainingDays = safeParseInt(contract['term_remaining_days']) ?? 0;
      if (remainingDays > 0) hasBalance = true;
    }

    return hasAnyBenefit && !hasBalance;
  }

  /// 가장 늦은 만료일을 찾는 함수
  ///
  /// [contract] 계약 정보 Map
  ///
  /// 반환값: 가장 늦은 만료일 문자열 (yyyy-MM-dd 형식) 또는 null
  static String? getLatestExpiryDate(Map<String, dynamic> contract) {
    List<String?> expiryDates = [
      contract['contract_credit_expiry_date']?.toString(),
      contract['contract_LS_min_expiry_date']?.toString(),
      contract['contract_games_expiry_date']?.toString(),
      contract['contract_TS_min_expiry_date']?.toString(),
      contract['contract_term_month_expiry_date']?.toString(),
    ];

    DateTime? latestDate;

    for (String? dateStr in expiryDates) {
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          DateTime date = DateTime.parse(dateStr);
          if (latestDate == null || date.isAfter(latestDate)) {
            latestDate = date;
          }
        } catch (e) {
          // 날짜 파싱 실패 시 무시
        }
      }
    }

    return latestDate?.toIso8601String().split('T')[0];
  }

  /// 계약 목록을 만료 여부에 따라 필터링
  ///
  /// [contracts] 계약 목록
  /// [includeExpired] true면 만료된 계약도 포함, false면 유효한 계약만 포함
  ///
  /// 반환값: 필터링된 계약 목록
  static List<Map<String, dynamic>> filterContractsByExpiry(
    List<Map<String, dynamic>> contracts,
    bool includeExpired,
  ) {
    return contracts.where((contract) {
      if (!includeExpired && isExpiredContract(contract)) {
        return false; // 만료된 계약 제외
      }
      return true;
    }).toList();
  }

  /// 계약 상태 정보를 반환
  ///
  /// [contract] 계약 정보 Map
  ///
  /// 반환값: 계약 상태 정보 Map
  /// - isExpired: 만료 여부
  /// - isDateExpired: 유효기간 만료 여부
  /// - isBalanceEmpty: 잔액 소진 여부
  /// - isActive: 유효 여부
  /// - hasBalance: 잔액 존재 여부
  static Map<String, bool> getContractStatus(Map<String, dynamic> contract) {
    return {
      'isExpired': isExpiredContract(contract),
      'isDateExpired': isDateExpired(contract),
      'isBalanceEmpty': isBalanceEmpty(contract),
      'isActive': isContractActive(contract),
      'hasBalance': hasTransferableBalance(contract),
    };
  }

  /// 안전한 정수 파싱 헬퍼 함수
  static int? safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        try {
          return double.parse(value).toInt();
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }
}