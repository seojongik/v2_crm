import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'transfer_confirmation_page.dart';
import 'transfer_contract_page.dart';

class TransferMembershipWidget extends StatefulWidget {
  final Map<String, dynamic> contract;
  final VoidCallback onTransferComplete;

  const TransferMembershipWidget({
    Key? key,
    required this.contract,
    required this.onTransferComplete,
  }) : super(key: key);

  @override
  _TransferMembershipWidgetState createState() => _TransferMembershipWidgetState();
}

class _TransferMembershipWidgetState extends State<TransferMembershipWidget> {
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> filteredMembers = [];
  Map<String, dynamic>? selectedMember;
  bool isLoading = false;
  int currentBalance = 0;
  int lessonBalance = 0;
  int timeBalance = 0;
  int gameBalance = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('=== TransferMembershipWidget 초기화 ===');
    print('양도할 회원권 정보: ${widget.contract}');
    _loadMembers();
    _loadCurrentBalance();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        filteredMembers = members;
      } else {
        filteredMembers = members.where((member) {
          final name = (member['member_name'] ?? '').toString().toLowerCase();
          final phone = (member['member_phone'] ?? '').toString().toLowerCase();
          final memberNo = (member['member_no_branch'] ?? '').toString();

          return name.contains(query) ||
                 phone.contains(query) ||
                 memberNo.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadCurrentBalance() async {
    try {
      print('=== 현재 잔액 로드 시작 ===');

      // 크레딧 잔액
      final creditBal = await _getCurrentCreditBalance();
      print('현재 크레딧 잔액: $creditBal원');

      // 레슨권 잔액
      final lessonBal = await _getCurrentLessonBalance();
      print('현재 레슨권 잔액: $lessonBal분');

      // 시간권 잔액
      final timeBal = await _getCurrentTimeBalance();
      print('현재 시간권 잔액: $timeBal분');

      // 게임권 잔액
      final gameBal = await _getCurrentGameBalance();
      print('현재 게임권 잔액: $gameBal회');

      setState(() {
        currentBalance = creditBal;
        lessonBalance = lessonBal;
        timeBalance = timeBal;
        gameBalance = gameBal;
      });
    } catch (e) {
      print('잔액 로드 실패: $e');
    }
  }

  Future<void> _loadMembers() async {
    try {
      print('=== 회원 목록 로드 시작 ===');
      setState(() {
        isLoading = true;
      });

      try {
        // 먼저 모든 회원을 조회해보자
        final data = await ApiService.getDataList(
          table: 'v3_members',
          fields: ['member_id', 'member_no_branch', 'member_name', 'member_phone'],
          where: [
            {
              'field': 'branch_id',
              'operator': '=',
              'value': ApiService.getCurrentBranchId(),
            }
          ],
          orderBy: [
            {
              'field': 'member_name',
              'direction': 'ASC',
            }
          ],
        );

        // 클라이언트에서 본인 제외 필터링
        final filteredData = data.where((member) => 
          member['member_id'] != widget.contract['member_id']
        ).toList();

        print('전체 회원 목록 조회 결과: ${data.length}개');
        print('필터링 후 회원 목록: ${filteredData.length}개');
        print('회원 데이터 샘플: ${filteredData.take(3).toList()}');

        setState(() {
          members = filteredData;
          filteredMembers = filteredData;
          isLoading = false;
        });
      } catch (apiError) {
        print('API 조회 실패: $apiError');
        setState(() {
          members = [];
          isLoading = false;
        });
        throw apiError;
      }
    } catch (e) {
      print('회원 목록 로드 완전 실패: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원 목록을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showConfirmation() {
    if (selectedMember == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransferConfirmationPage(
        contract: widget.contract,
        transferee: selectedMember!,
        creditBalance: currentBalance,
        lessonBalance: lessonBalance,
        timeBalance: timeBalance,
        gameBalance: gameBalance,
        onConfirm: () {
          Navigator.of(context).pop(); // 확인 페이지 닫기
          _transferCredit(); // 양도 실행
        },
        onCancel: () {
          Navigator.of(context).pop(); // 확인 페이지만 닫기
        },
      ),
    );
  }

  Future<void> _transferCredit() async {
    if (selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('양수받을 회원을 선택해주세요')),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      // 양도할 항목들 확인
      final hasCredit = (_safeParseInt(widget.contract['contract_credit']) ?? 0) > 0;
      final hasLesson = (_safeParseInt(widget.contract['contract_LS_min']) ?? 0) > 0;
      final hasTime = (_safeParseInt(widget.contract['contract_TS_min']) ?? 0) > 0;
      final hasGames = (_safeParseInt(widget.contract['contract_games']) ?? 0) > 0;
      final hasTerm = widget.contract['contract_term_month_expiry_date'] != null &&
                      widget.contract['contract_term_month_expiry_date'].toString().isNotEmpty;

      print('\n=====================================');
      print('🔄 회원권 양도 프로세스 시작');
      print('=====================================');
      print('👤 양도자: ${widget.contract['member_name']} (ID: ${widget.contract['member_id']})');
      print('👤 양수자: ${selectedMember!['member_name']} (ID: ${selectedMember!['member_id']})');
      print('📋 계약 이력 ID: ${widget.contract['contract_history_id']}');
      print('');

      // 1. 양수자를 위한 contract_history 생성 (한 번만 실행)
      print('📝 [1단계] 양수자 계약 이력 생성');
      final newContractHistoryId = await _createTransferInContractHistory();
      print('✅ 성공: 새 계약 이력 ID = $newContractHistoryId\n');

      int transferredCount = 0;
      List<String> transferredItems = [];

      // 2. 크레딧 양도 처리
      if (hasCredit) {
        print('💰 [2단계] 크레딧 양도 처리');
        try {
          final currentCreditBalance = await _getCurrentCreditBalance();
          if (currentCreditBalance > 0) {
            print('   잔액: ${NumberFormat('#,###').format(currentCreditBalance)}원');
            await _createTransferOutRecord(currentCreditBalance);
            print('   ✅ 양도자 차감 완료');
            await _createTransferInRecord(currentCreditBalance, newContractHistoryId);
            print('   ✅ 양수자 충전 완료');
            transferredCount++;
            transferredItems.add('크레딧 ${NumberFormat('#,###').format(currentCreditBalance)}원');
            print('   ✅ 크레딧 양도 성공\n');
          } else {
            print('   ⚠️ 크레딧 잔액 없음 - 스킵\n');
          }
        } catch (e) {
          print('   ❌ 크레딧 양도 실패: $e\n');
          rethrow;
        }
      }

      // 3. 레슨권 양도 처리
      if (hasLesson) {
        print('📚 [3단계] 레슨권 양도 처리');
        try {
          final currentLessonBalance = await _getCurrentLessonBalance();
          if (currentLessonBalance > 0) {
            print('   잔액: ${currentLessonBalance}분');
            await _createLessonTransferOutRecord(currentLessonBalance);
            print('   ✅ 양도자 차감 완료');
            await _createLessonTransferInRecord(currentLessonBalance, newContractHistoryId);
            print('   ✅ 양수자 충전 완료');
            transferredCount++;
            transferredItems.add('레슨권 ${currentLessonBalance}분');
            print('   ✅ 레슨권 양도 성공\n');
          } else {
            print('   ⚠️ 레슨권 잔액 없음 - 스킵\n');
          }
        } catch (e) {
          print('   ❌ 레슨권 양도 실패: $e\n');
          rethrow;
        }
      }

      // 4. 시간권 양도 처리
      if (hasTime) {
        print('⏰ [4단계] 시간권 양도 처리');
        try {
          final currentTimeBalance = await _getCurrentTimeBalance();
          if (currentTimeBalance > 0) {
            print('   잔액: ${currentTimeBalance}분');
            await _createTimeTransferOutRecord(currentTimeBalance);
            print('   ✅ 양도자 차감 완료');
            await _createTimeTransferInRecord(currentTimeBalance, newContractHistoryId);
            print('   ✅ 양수자 충전 완료');
            transferredCount++;
            transferredItems.add('시간권 ${currentTimeBalance}분');
            print('   ✅ 시간권 양도 성공\n');
          } else {
            print('   ⚠️ 시간권 잔액 없음 - 스킵\n');
          }
        } catch (e) {
          print('   ❌ 시간권 양도 실패: $e\n');
          rethrow;
        }
      }

      // 5. 게임권 양도 처리
      if (hasGames) {
        print('🎮 [5단계] 게임권 양도 처리');
        try {
          final currentGameBalance = await _getCurrentGameBalance();
          if (currentGameBalance > 0) {
            print('   잔액: ${currentGameBalance}회');
            await _createGameTransferOutRecord(currentGameBalance);
            print('   ✅ 양도자 차감 완료');
            await _createGameTransferInRecord(currentGameBalance, newContractHistoryId);
            print('   ✅ 양수자 충전 완료');
            transferredCount++;
            transferredItems.add('게임권 ${currentGameBalance}회');
            print('   ✅ 게임권 양도 성공\n');
          } else {
            print('   ⚠️ 게임권 잔액 없음 - 스킵\n');
          }
        } catch (e) {
          print('   ❌ 게임권 양도 실패: $e\n');
          rethrow;
        }
      }

      // 6. 기간권 양도 처리
      if (hasTerm) {
        print('📅 [6단계] 기간권 양도 처리');
        try {
          final expiryDate = widget.contract['contract_term_month_expiry_date'];
          print('   만료일: $expiryDate');
          await _createTermTransferOutRecord();
          print('   ✅ 양도자 만료 처리 완료');
          await _createTermTransferInRecord(newContractHistoryId);
          print('   ✅ 양수자 기간권 설정 완료');
          transferredCount++;
          transferredItems.add('기간권 (~$expiryDate)');
          print('   ✅ 기간권 양도 성공\n');
        } catch (e) {
          print('   ❌ 기간권 양도 실패: $e\n');
          rethrow;
        }
      }

      print('=====================================');
      print('✅ 양도 완료 요약');
      print('=====================================');
      print('📊 총 ${transferredCount}개 항목 양도 완료:');
      for (var item in transferredItems) {
        print('   ✓ $item');
      }
      print('=====================================\n');

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        String message = '${selectedMember!['member_name']}님께 ';
        if (hasCredit) message += '크레딧, ';
        if (hasLesson) message += '레슨권, ';
        if (hasTime) message += '시간권, ';
        if (hasGames) message += '게임권, ';
        if (hasTerm) message += '기간권, ';
        message = message.substring(0, message.length - 2) + '이 양도되었습니다';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pop();
        
        // 양도계약서 페이지로 이동
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TransferContractPage(
              contract: widget.contract,
              transferee: selectedMember!,
              creditBalance: currentBalance,
              lessonBalance: lessonBalance,
              timeBalance: timeBalance,
              gameBalance: gameBalance,
              termExpiryDate: widget.contract['contract_term_month_expiry_date']?.toString(),
            ),
          ),
        );
        
        widget.onTransferComplete();
      }
    } catch (e) {
      print('=====================================');
      print('❌ 양도 프로세스 실패');
      print('=====================================');
      print('오류: $e');
      print('=====================================\n');

      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('양도 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<int> _getCurrentCreditBalance() async {
    print('=== 현재 크레딧 잔액 조회 시작 ===');
    print('contract_history_id: ${widget.contract['contract_history_id']}');
    print('branch_id: ${ApiService.getCurrentBranchId()}');
    
    final data = await ApiService.getBillsData(
      where: [
        {
          'field': 'contract_history_id',
          'operator': '=',
          'value': widget.contract['contract_history_id'],
        },
        {
          'field': 'branch_id',
          'operator': '=',
          'value': ApiService.getCurrentBranchId(),
        },
      ],
      orderBy: [
        {
          'field': 'bill_id',
          'direction': 'DESC',
        }
      ],
    );

    print('bills 조회 결과 ${data.length}개 레코드');
    if (data.isNotEmpty) {
      print('가장 최근 bill 레코드: ${data[0]}');
      final balance = int.tryParse(data[0]['bill_balance_after']?.toString() ?? '0') ?? 0;
      print('파싱된 잔액: $balance원');
      return balance;
    }
    
    print('bills 데이터 없음 - 잔액 0 반환');
    return 0;
  }

  Future<void> _createTransferOutRecord(int currentBalance) async {
    final transferOutData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': widget.contract['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_type': '회원권양도',
      'bill_text': '${selectedMember!['member_no_branch'] ?? selectedMember!['member_id']}, ${selectedMember!['member_name']}께 양도',
      'bill_totalamt': -currentBalance,
      'bill_deduction': 0,
      'bill_netamt': -currentBalance,
      'bill_timestamp': DateTime.now().toIso8601String(),
      'bill_balance_before': currentBalance,
      'bill_balance_after': 0,
      'reservation_id': '',
      'bill_status': '결제완료',
      'contract_history_id': widget.contract['contract_history_id'],
      'locker_bill_id': null,
      'routine_id': null,
      'contract_credit_expiry_date': widget.contract['contract_credit_expiry_date'],
    };

    await ApiService.addBillsData(transferOutData);
  }

  // 레슨권 잔액 조회
  Future<Map<String, dynamic>> _getCurrentLessonInfo() async {
    print('=== 현재 레슨권 정보 조회 시작 ===');
    print('contract_history_id: ${widget.contract['contract_history_id']}');
    
    final data = await ApiService.getDataList(
      table: 'v3_LS_countings',
      where: [
        {
          'field': 'contract_history_id',
          'operator': '=',
          'value': widget.contract['contract_history_id'],
        },
        {
          'field': 'branch_id',
          'operator': '=',
          'value': ApiService.getCurrentBranchId(),
        },
      ],
      orderBy: [
        {
          'field': 'LS_counting_id',
          'direction': 'DESC',
        }
      ],
    );

    print('LS_countings 조회 결과 ${data.length}개 레코드');
    if (data.isNotEmpty) {
      print('가장 최근 레슨권 레코드: ${data[0]}');
      print('LS_expiry_date 원본값: ${data[0]['LS_expiry_date']}');
      return data[0]; // 전체 레코드 반환
    }
    
    print('레슨권 데이터 없음');
    return {};
  }
  
  Future<int> _getCurrentLessonBalance() async {
    final lessonInfo = await _getCurrentLessonInfo();
    if (lessonInfo.isNotEmpty) {
      final balance = _safeParseInt(lessonInfo['LS_balance_min_after']);
      print('파싱된 레슨권 잔액: ${balance}분');
      return balance;
    }
    return 0;
  }

  // 시간권 잔액 조회
  Future<int> _getCurrentTimeBalance() async {
    print('=== 현재 시간권 잔액 조회 시작 ===');
    print('contract_history_id: ${widget.contract['contract_history_id']}');
    
    final data = await ApiService.getDataList(
      table: 'v2_bill_times',
      where: [
        {
          'field': 'contract_history_id',
          'operator': '=',
          'value': widget.contract['contract_history_id'],
        },
        {
          'field': 'branch_id',
          'operator': '=',
          'value': ApiService.getCurrentBranchId(),
        },
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.contract['member_id'],
        },
      ],
      orderBy: [
        {
          'field': 'bill_min_id',
          'direction': 'DESC',
        }
      ],
    );

    print('bill_times 조회 결과 ${data.length}개 레코드');
    if (data.isNotEmpty) {
      final balance = _safeParseInt(data[0]['bill_balance_min_after']);
      print('파싱된 시간권 잔액: ${balance}분');
      return balance;
    }
    return 0;
  }

  // 게임권 잔액 조회
  Future<int> _getCurrentGameBalance() async {
    print('=== 현재 게임권 잔액 조회 시작 ===');
    print('contract_history_id: ${widget.contract['contract_history_id']}');
    
    final data = await ApiService.getDataList(
      table: 'v2_bill_games',
      where: [
        {
          'field': 'contract_history_id',
          'operator': '=',
          'value': widget.contract['contract_history_id'],
        },
        {
          'field': 'branch_id',
          'operator': '=',
          'value': ApiService.getCurrentBranchId(),
        },
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.contract['member_id'],
        },
      ],
      orderBy: [
        {
          'field': 'bill_game_id',
          'direction': 'DESC',
        }
      ],
    );

    print('bill_games 조회 결과 ${data.length}개 레코드');
    if (data.isNotEmpty) {
      final balance = _safeParseInt(data[0]['bill_balance_game_after']);
      print('파싱된 게임권 잔액: ${balance}회');
      return balance;
    }
    return 0;
  }

  // 레슨권 양도자 차감 레코드 생성
  Future<void> _createLessonTransferOutRecord(int currentBalance) async {
    print('=== 레슨권 양도자 차감 레코드 생성 시작 ===');
    print('현재 잔액: ${currentBalance}분');
    
    // 최근 레슨권 정보 가져오기
    final lessonInfo = await _getCurrentLessonInfo();
    
    final transferOutData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'LS_transaction_type': '레슨권양도',
      'LS_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'member_id': widget.contract['member_id'],
      'member_name': widget.contract['member_name'],
      'member_type': lessonInfo['member_type'] ?? '',
      'LS_status': '차감완료',
      'LS_type': '양도',
      'LS_contract_id': null,
      'contract_history_id': widget.contract['contract_history_id'],
      'LS_id': null, // LS_id는 예약 관련 필드이므로 null
      'LS_balance_min_before': currentBalance,
      'LS_net_min': currentBalance, // 양수로 표시 (차감이지만 절대값)
      'LS_balance_min_after': 0,
      'LS_counting_source': '양도처리',
      'updated_at': DateTime.now().toIso8601String(),
      'program_id': null,
      'pro_id': lessonInfo['pro_id'],
      'pro_name': lessonInfo['pro_name'],
      'LS_expiry_date': lessonInfo['LS_expiry_date'] ?? widget.contract['contract_LS_min_expiry_date'],
    };

    await ApiService.addLSCountingData(transferOutData);
    print('레슨권 양도자 차감 레코드 생성 완료');
  }

  // 시간권 양도자 차감 레코드 생성
  Future<void> _createTimeTransferOutRecord(int currentBalance) async {
    print('=== 시간권 양도자 차감 레코드 생성 시작 ===');
    print('현재 잔액: ${currentBalance}분');
    
    final transferOutData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': widget.contract['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_text': '시간권양도',
      'bill_type': '시간권양도',
      'reservation_id': '',
      'bill_total_min': 0,
      'bill_discount_min': 0,
      'bill_min': currentBalance, // 차감할 분
      'bill_balance_min_before': currentBalance,
      'bill_balance_min_after': 0,
      'bill_timestamp': DateTime.now().toIso8601String(),
      'bill_status': '결제완료',
      'contract_history_id': widget.contract['contract_history_id'],
      'routine_id': null,
      'contract_TS_min_expiry_date': widget.contract['contract_TS_min_expiry_date'],
    };

    await ApiService.addBillTimesData(transferOutData);
    print('시간권 양도자 차감 레코드 생성 완료');
  }

  // 기간권 양도자 만료 처리 레코드 생성
  Future<void> _createTermTransferOutRecord() async {
    print('=== 기간권 양도자 만료 처리 레코드 생성 시작 ===');
    
    final transferOutData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': widget.contract['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_type': '기간권양도',
      'bill_text': '기간권양도',
      'bill_term_min': null,
      'bill_timestamp': DateTime.now().toIso8601String(),
      'reservation_id': '',
      'bill_status': '결제완료',
      'contract_history_id': widget.contract['contract_history_id'],
      'contract_term_month_expiry_date': DateFormat('yyyy-MM-dd').format(DateTime.now()), // 오늘 날짜로 만료
      'term_startdate': widget.contract['contract_term_month_expiry_date'], // 기존 만료일을 그대로 기록
      'term_enddate': widget.contract['contract_term_month_expiry_date'], // 기존 만료일을 그대로 기록
    };

    await ApiService.addBillTermData(transferOutData);
    print('기간권 양도자 만료 처리 레코드 생성 완료');
  }

  // 게임권 양도자 차감 레코드 생성
  Future<void> _createGameTransferOutRecord(int currentBalance) async {
    print('=== 게임권 양도자 차감 레코드 생성 시작 ===');
    print('현재 잔액: ${currentBalance}회');
    
    final transferOutData = {
      'member_id': widget.contract['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_type': '게임권양도',
      'bill_text': '게임권양도',
      'bill_games': currentBalance, // 차감할 회수
      'bill_timestamp': DateTime.now().toIso8601String(),
      'bill_balance_game_before': currentBalance,
      'bill_balance_game_after': 0,
      'reservation_id': '',
      'bill_status': '결제완료',
      'contract_history_id': widget.contract['contract_history_id'],
      'routine_id': null,
      'branch_id': ApiService.getCurrentBranchId(),
      'group_play_id': null,
      'group_members_numbers': null,
      'member_name': widget.contract['member_name'],
      'non_member_name': null,
      'non_member_phone': null,
      'contract_games_expiry_date': widget.contract['contract_games_expiry_date'],
    };

    await ApiService.addBillGamesData(transferOutData);
    print('게임권 양도자 차감 레코드 생성 완료');
  }

  // 레슨권 양수자 충전 레코드 생성
  Future<void> _createLessonTransferInRecord(int transferAmount, int contractHistoryId) async {
    print('=== 레슨권 양수자 충전 레코드 생성 시작 ===');
    print('양수 금액: ${transferAmount}분, contractHistoryId: $contractHistoryId');
    
    // 원래 레슨권 정보 가져오기 (양도자와 동일한 정보 사용)
    final lessonInfo = await _getCurrentLessonInfo();
    
    final transferInData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'LS_transaction_type': '레슨권양수',
      'LS_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'member_id': selectedMember!['member_id'],
      'member_name': selectedMember!['member_name'],
      'member_type': lessonInfo['member_type'] ?? '',
      'LS_status': '결제완료',
      'LS_type': '양수',
      'LS_contract_id': null,
      'contract_history_id': contractHistoryId,
      'LS_id': null, // LS_id는 예약 관련 필드이므로 null
      'LS_balance_min_before': 0,
      'LS_net_min': transferAmount, // 양수로 증가
      'LS_balance_min_after': transferAmount,
      'LS_counting_source': '양수처리',
      'updated_at': DateTime.now().toIso8601String(),
      'program_id': null,
      'pro_id': lessonInfo['pro_id'],
      'pro_name': lessonInfo['pro_name'],
      'LS_expiry_date': lessonInfo['LS_expiry_date'] ?? widget.contract['contract_LS_min_expiry_date'],
    };

    await ApiService.addLSCountingData(transferInData);
    print('레슨권 양수자 충전 레코드 생성 완료');
  }

  // 시간권 양수자 충전 레코드 생성
  Future<void> _createTimeTransferInRecord(int transferAmount, int contractHistoryId) async {
    print('=== 시간권 양수자 충전 레코드 생성 시작 ===');
    print('양수 금액: ${transferAmount}분, contractHistoryId: $contractHistoryId');
    
    final transferInData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': selectedMember!['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_text': '시간권양수',
      'bill_type': '시간권양수',
      'reservation_id': '',
      'bill_total_min': 0,
      'bill_discount_min': 0,
      'bill_min': transferAmount, // 충전할 분
      'bill_balance_min_before': 0,
      'bill_balance_min_after': transferAmount,
      'bill_timestamp': DateTime.now().toIso8601String(),
      'bill_status': '결제완료',
      'contract_history_id': contractHistoryId,
      'routine_id': null,
      'contract_TS_min_expiry_date': widget.contract['contract_TS_min_expiry_date'],
    };

    await ApiService.addBillTimesData(transferInData);
    print('시간권 양수자 충전 레코드 생성 완료');
  }

  // 기간권 양수자 연장 레코드 생성
  Future<void> _createTermTransferInRecord(int contractHistoryId) async {
    print('=== 기간권 양수자 연장 레코드 생성 시작 ===');
    print('contractHistoryId: $contractHistoryId');
    
    final today = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(today);
    
    final transferInData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': selectedMember!['member_id'],
      'bill_date': todayString,
      'bill_type': '기간권양수',
      'bill_text': '기간권양수',
      'bill_term_min': null,
      'bill_timestamp': DateTime.now().toIso8601String(),
      'reservation_id': '',
      'bill_status': '결제완료',
      'contract_history_id': contractHistoryId,
      'contract_term_month_expiry_date': widget.contract['contract_term_month_expiry_date'], // 원래 만료일
      'term_startdate': todayString, // 양도일부터 시작
      'term_enddate': widget.contract['contract_term_month_expiry_date'], // 원래 만료일까지
    };

    await ApiService.addBillTermData(transferInData);
    print('기간권 양수자 연장 레코드 생성 완료');
  }

  // 게임권 양수자 충전 레코드 생성
  Future<void> _createGameTransferInRecord(int transferAmount, int contractHistoryId) async {
    print('=== 게임권 양수자 충전 레코드 생성 시작 ===');
    print('양수 금액: ${transferAmount}회, contractHistoryId: $contractHistoryId');
    
    final transferInData = {
      'member_id': selectedMember!['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_type': '게임권양수',
      'bill_text': '게임권양수',
      'bill_games': transferAmount, // 충전할 회수
      'bill_timestamp': DateTime.now().toIso8601String(),
      'bill_balance_game_before': 0,
      'bill_balance_game_after': transferAmount,
      'reservation_id': '',
      'bill_status': '결제완료',
      'contract_history_id': contractHistoryId,
      'routine_id': null,
      'branch_id': ApiService.getCurrentBranchId(),
      'group_play_id': null,
      'group_members_numbers': null,
      'member_name': selectedMember!['member_name'],
      'non_member_name': null,
      'non_member_phone': null,
      'contract_games_expiry_date': widget.contract['contract_games_expiry_date'],
    };

    await ApiService.addBillGamesData(transferInData);
    print('게임권 양수자 충전 레코드 생성 완료');
  }

  Future<int> _createTransferInContractHistory() async {
    final contractHistoryData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': selectedMember!['member_id'],
      'member_name': selectedMember!['member_name'],
      'contract_type': widget.contract['contract_type'],
      'contract_id': widget.contract['contract_id'],
      'contract_name': '${widget.contract['contract_name'] ?? '회원권'} (양수도)',
      'contract_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'contract_register': DateTime.now().toIso8601String(),
      'payment_type': '양수도결제',
      'contract_history_status': '활성',
      'price': 0, // 양도는 가격이 없음
      'contract_credit': await _getCurrentCreditBalance(),
      'contract_LS_min': await _getCurrentLessonBalance(),
      'contract_games': await _getCurrentGameBalance(),
      'contract_TS_min': await _getCurrentTimeBalance(),
      'contract_term_month': widget.contract['contract_term_month'] ?? 0,
      'contract_credit_expiry_date': widget.contract['contract_credit_expiry_date'],
      'contract_LS_min_expiry_date': widget.contract['contract_LS_min_expiry_date'],
      'contract_games_expiry_date': widget.contract['contract_games_expiry_date'],
      'contract_TS_min_expiry_date': widget.contract['contract_TS_min_expiry_date'],
      'contract_term_month_expiry_date': widget.contract['contract_term_month_expiry_date'],
      'bill_id': null,
      'pro_id': null,
      'pro_name': null,
    };

    final result = await ApiService.addContractHistoryData(contractHistoryData);
    print('계약 이력 생성 결과: $result');

    // addContractHistoryData가 생성된 ID를 반환한다고 가정
    final contractHistoryId = int.tryParse(result['insertId']?.toString() ?? '0') ?? 
                             result['contract_history_id'] ?? 
                             result['id'] ?? 0;
    print('파싱된 contract_history_id: $contractHistoryId');
    
    return contractHistoryId;
  }

  Future<void> _createTransferInRecord(int transferAmount, int contractHistoryId) async {
    print('=== 양수자 크레딧 충전 레코드 생성 시작 ===');
    print('transferAmount: $transferAmount, contractHistoryId: $contractHistoryId');

    final transferInData = {
      'branch_id': ApiService.getCurrentBranchId(),
      'member_id': selectedMember!['member_id'],
      'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'bill_type': '회원권양수',
      'bill_text': '${widget.contract['member_no_branch'] ?? widget.contract['member_id']}, ${widget.contract['member_name']}님으로부터 양수',
      'bill_totalamt': transferAmount,
      'bill_deduction': 0,
      'bill_netamt': transferAmount,
      'bill_timestamp': DateTime.now().toIso8601String(),
      'bill_balance_before': 0,
      'bill_balance_after': transferAmount,
      'reservation_id': '',
      'bill_status': '결제완료',
      'contract_history_id': contractHistoryId,
      'locker_bill_id': null,
      'routine_id': null,
      'contract_credit_expiry_date': widget.contract['contract_credit_expiry_date'],
    };

    final result = await ApiService.addBillsData(transferInData);
    print('양수자 bills 레코드 생성 결과: $result');

    // 생성된 bill_id로 contract_history 업데이트
    if (result['insertId'] != null) {
      await _updateContractHistoryBillId(contractHistoryId, result['insertId']);
    }
  }

  Future<void> _updateContractHistoryBillId(int contractHistoryId, dynamic billId) async {
    try {
      print('=== contract_history bill_id 업데이트 시작 ===');
      print('contractHistoryId: $contractHistoryId, billId: $billId');
      
      await ApiService.updateData(
        table: 'v3_contract_history',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          }
        ],
        data: {
          'bill_id': billId,
        },
      );
      print('contract_history bill_id 업데이트 완료');
    } catch (e) {
      print('contract_history bill_id 업데이트 실패: $e');
    }
  }

  Widget _buildBalanceChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '크레딧 양도',
                  style: AppTextStyles.h2.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 양도할 회원권 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '양도할 회원권',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: const Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.contract['contract_name'] ?? '-',
                    style: AppTextStyles.cardBody.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 양도 항목 목록
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 크레딧
                      if (currentBalance > 0)
                        _buildBalanceChip(
                          icon: Icons.account_balance_wallet,
                          label: '크레딧',
                          value: '${NumberFormat('#,###').format(currentBalance)}원',
                          color: const Color(0xFF059669),
                        ),

                      // 레슨권
                      if (lessonBalance > 0)
                        _buildBalanceChip(
                          icon: Icons.school,
                          label: '레슨권',
                          value: '${lessonBalance}분',
                          color: const Color(0xFF3B82F6),
                        ),

                      // 시간권
                      if (timeBalance > 0)
                        _buildBalanceChip(
                          icon: Icons.access_time,
                          label: '시간권',
                          value: '${timeBalance}분',
                          color: const Color(0xFF8B5CF6),
                        ),

                      // 게임권
                      if (gameBalance > 0)
                        _buildBalanceChip(
                          icon: Icons.sports_golf,
                          label: '게임권',
                          value: '${gameBalance}회',
                          color: const Color(0xFFEC4899),
                        ),

                      // 기간권
                      if (widget.contract['contract_term_month_expiry_date'] != null &&
                          widget.contract['contract_term_month_expiry_date'].toString().isNotEmpty)
                        _buildBalanceChip(
                          icon: Icons.calendar_today,
                          label: '기간권',
                          value: '~${widget.contract['contract_term_month_expiry_date']}',
                          color: const Color(0xFFF59E0B),
                        ),
                    ],
                  ),

                  // 양도 항목이 없는 경우
                  if (currentBalance == 0 &&
                      lessonBalance == 0 &&
                      timeBalance == 0 &&
                      gameBalance == 0 &&
                      (widget.contract['contract_term_month_expiry_date'] == null ||
                       widget.contract['contract_term_month_expiry_date'].toString().isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '양도할 수 있는 항목이 없습니다',
                        style: AppTextStyles.cardBody.copyWith(
                          color: const Color(0xFF9CA3AF),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 회원 선택
            Text(
              '양수받을 회원 선택',
              style: AppTextStyles.cardTitle.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // 검색 필드
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이름, 전화번호, 회원번호로 검색',
                hintStyle: AppTextStyles.cardBody.copyWith(
                  color: const Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF6B7280),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Color(0xFF6B7280),
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 검색 결과 개수 표시
            if (!isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${filteredMembers.length}명',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),

            // 회원 목록
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (filteredMembers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: const Color(0xFFD1D5DB),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '검색 결과가 없습니다',
                        style: AppTextStyles.cardBody.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      final isSelected = selectedMember?['member_id'] == member['member_id'];

                      return Container(
                        decoration: BoxDecoration(
                          border: index > 0
                              ? const Border(
                                  top: BorderSide(color: Color(0xFFF1F5F9)),
                                )
                              : null,
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              selectedMember = member;
                            });
                          },
                          leading: Radio<int>(
                            value: member['member_id'],
                            groupValue: selectedMember?['member_id'],
                            onChanged: (value) {
                              setState(() {
                                selectedMember = member;
                              });
                            },
                            activeColor: const Color(0xFF3B82F6),
                          ),
                          title: Text(
                            member['member_name'] ?? '-',
                            style: AppTextStyles.cardBody.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            '회원번호: ${member['member_no_branch'] ?? '-'} | ${member['member_phone'] ?? '-'}',
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    child: Text(
                      '취소',
                      style: AppTextStyles.cardBody.copyWith(
                        color: const Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedMember != null && !isLoading ? _showConfirmation : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '다음',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Colors.white,
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
}