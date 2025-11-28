import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';
import 'tab2_contract_new.dart';
import 'tab3_credit.dart' show ManualCreditDialog, ProductPurchaseDialog;
import 'tab2_contract_setting_viewer.dart';
import 'tab2_contract_receipt.dart';
import 'tab2_contract_program_viewer.dart';
import 'tab2_contract_expiry_change.dart';
import 'tab2_contract_popup_design.dart';
import 'tab2_contract_time_manual.dart';
import 'tab2_contract_game_manual.dart';
import 'tab2_contract_lesson_manual.dart';
import 'tab2_contract_lesson_pro_change.dart';
import 'tab2_transfer.dart';
import 'tab2_contract_validity_check.dart';

class Tab2ContractWidget extends StatefulWidget {
  final int memberId;
  final Map<String, dynamic>? memberData;

  const Tab2ContractWidget({
    Key? key,
    required this.memberId,
    this.memberData,
  }) : super(key: key);

  @override
  State<Tab2ContractWidget> createState() => _Tab2ContractWidgetState();
}

class _Tab2ContractWidgetState extends State<Tab2ContractWidget> {
  List<Map<String, dynamic>> contractData = [];
  List<Map<String, dynamic>> filteredContractData = [];
  bool isLoading = true;
  String? errorMessage;
  
  // 필터 상태
  bool includeLocker = false; // 락커 포함 여부 (디폴트: 제외)
  bool includeExpired = false; // 만료 포함 여부 (디폴트: 제외)
  String? activeFilter; // 현재 활성화된 필터
  
  // 통계 데이터
  int totalContracts = 0;
  int totalPayment = 0;
  int totalCredits = 0;
  int lessonPurchases = 0;
  int totalLessonMinutes = 0;
  int totalGameCount = 0;
  int totalTimeMinutes = 0;
  int totalTermMonths = 0;
  
  // 유효 잔액 합계 및 유효 계약수
  int validCreditBalance = 0;
  int validCreditCount = 0;
  int validLessonBalance = 0;
  int validLessonCount = 0;
  int validGameBalance = 0;
  int validGameCount = 0;
  int validTimeBalance = 0;
  int validTimeCount = 0;
  int validTermDays = 0;
  int validTermCount = 0;

  @override
  void initState() {
    super.initState();
    _loadContractData();
  }

  Future<void> _loadContractData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final data = await ApiService.getContractHistoryData(
        where: [
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        orderBy: [
          {
            'field': 'contract_date',
            'direction': 'DESC',
          }
        ],
      );

      // 통계 계산 - 실제 필드명 사용
      int payment = 0;
      int credits = 0;
      int lessons = 0;
      int lessonMinutes = 0;
      int gameCount = 0;
      int timeMinutes = 0;
      int termMonths = 0;
      
      for (var contract in data) {
        payment += _safeParseInt(contract['price']);
        credits += _safeParseInt(contract['contract_credit']);
        
        final contractLessonMin = _safeParseInt(contract['contract_LS_min']);
        if (contractLessonMin > 0) {
          lessons++;
          lessonMinutes += contractLessonMin;
        }
        
        gameCount += _safeParseInt(contract['contract_games']);
        timeMinutes += _safeParseInt(contract['contract_TS_min']);
        termMonths += _safeParseInt(contract['contract_term_month']);
      }

      setState(() {
        contractData = data;
        totalContracts = data.length;
        totalPayment = payment;
        totalCredits = credits;
        lessonPurchases = lessons;
        totalLessonMinutes = lessonMinutes;
        totalGameCount = gameCount;
        totalTimeMinutes = timeMinutes;
        totalTermMonths = termMonths;
        isLoading = false;
      });
      
      // 계약 상세 정보 로드 (program_reservation_availability 포함)
      await _loadContractDetails();
      
      // 잔액 정보 로드 (유효 잔액 계산 포함)
      await _loadBalanceData();
      
      // 잔액 데이터 로드 완료 후 필터 적용
      _applyFilters();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 계약 상세 정보 로드 (v2_contracts 테이블에서 program_reservation_availability 등 조회)
  Future<void> _loadContractDetails() async {
    try {
      for (var contract in contractData) {
        final contractId = contract['contract_id'];
        if (contractId != null) {
          // v2_contracts 테이블에서 상세 정보 조회
          final contractDetails = await ApiService.getDataList(
            table: 'v2_contracts',
            where: [
              {
                'field': 'contract_id',
                'operator': '=',
                'value': contractId,
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': ApiService.getCurrentBranchId(),
              }
            ],
            limit: 1,
          );
          
          if (contractDetails.isNotEmpty) {
            // program_reservation_availability 정보 추가
            final programAvailability = contractDetails[0]['program_reservation_availability']?.toString();
            contract['program_reservation_availability'] = programAvailability;
            
            // 프로그램명 조회하여 저장
            if (programAvailability != null && programAvailability.isNotEmpty) {
              final programs = programAvailability.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
              Map<String, String> programNames = {};
              
              for (String programId in programs) {
                final programName = await _getProgramName(programId);
                programNames[programId] = programName;
              }
              
              contract['program_names'] = programNames;
            }
          }
        }
      }
    } catch (e) {
      print('Contract details loading error: $e');
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCurrency(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  // 안전한 숫자 변환 함수 추가
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    if (value is num) return value.toInt();
    return 0;
  }

  // 잔액 정보 로드
  Future<void> _loadBalanceData() async {
    print('\n=== 잔액 조회 시작 ===');
    try {
      for (var contract in contractData) {
        final contractHistoryId = contract['contract_history_id'];
        final contractName = contract['contract_name'];

        print('\n[$contractName] contract_history_id=$contractHistoryId');

        if (contractHistoryId != null) {
          // 크레딧 잔액 및 유효기간 조회 (v2_bills)
          final contractCredit = _safeParseInt(contract['contract_credit']);
          if (contractCredit > 0) {
            final creditData = await _getCreditBalance(contractHistoryId);
            contract['credit_balance'] = creditData['balance'];
            contract['contract_credit_expiry_date'] = creditData['expiry_date'];
            print('  크레딧: contract_credit=$contractCredit, credit_balance=${creditData['balance']}, contract_credit_expiry_date=${creditData['expiry_date']} (v2_bills)');
          }

          // 시간권 잔액 및 유효기간 조회 (v2_bill_times)
          final contractTime = _safeParseInt(contract['contract_TS_min']);
          if (contractTime > 0) {
            final timeData = await _getTimeBalance(contractHistoryId);
            contract['time_balance'] = timeData['balance'];
            contract['contract_TS_min_expiry_date'] = timeData['expiry_date'];
            print('  시간권: contract_TS_min=$contractTime, time_balance=${timeData['balance']}, contract_TS_min_expiry_date=${timeData['expiry_date']} (v2_bill_times)');
          }

          // 게임권 잔액 및 유효기간 조회 (v2_bill_games)
          final contractGames = _safeParseInt(contract['contract_games']);
          if (contractGames > 0) {
            final gameData = await _getGameBalance(contractHistoryId);
            contract['game_balance'] = gameData['balance'];
            contract['contract_games_expiry_date'] = gameData['expiry_date'];
            print('  게임권: contract_games=$contractGames, game_balance=${gameData['balance']}, contract_games_expiry_date=${gameData['expiry_date']} (v2_bill_games)');
          }

          // 레슨권 잔액 및 유효기간 조회 (v3_LS_countings)
          final contractLessonMin = _safeParseInt(contract['contract_LS_min']);
          if (contractLessonMin > 0) {
            final lessonData = await _getLessonBalance(contractHistoryId);
            contract['lesson_balance'] = lessonData['balance'];
            contract['contract_LS_min_expiry_date'] = lessonData['expiry_date'];
            print('  레슨권: contract_LS_min=$contractLessonMin, lesson_balance=${lessonData['balance']}, contract_LS_min_expiry_date=${lessonData['expiry_date']} (v3_LS_countings)');
          }

          // 기간권 남은 일수 및 만료일 조회 (v2_bill_term)
          final contractTerm = _safeParseInt(contract['contract_term_month']);
          if (contractTerm > 0) {
            final termData = await _getTermData(contractHistoryId);
            if (termData != null) {
              contract['term_remaining_days'] = termData['remaining_days'];
              contract['contract_term_month_expiry_date'] = termData['expiry_date'];
              print('  기간권: contract_term_month=$contractTerm, term_remaining_days=${termData['remaining_days']}, contract_term_month_expiry_date=${termData['expiry_date']} (v2_bill_term)');
            } else {
              contract['term_remaining_days'] = 0;
            }
          }
        }
      }
      
      // 유효 잔액 합계 계산
      _calculateValidBalances();

      setState(() {
        // UI 업데이트
      });
      print('\n=== 잔액 조회 완료 ===');
    } catch (e) {
      print('Balance data loading error: $e');
    }
  }
  
  // 크레딧 잔액 및 유효기간 조회 (v2_bills에서 가장 큰 bill_id)
  Future<Map<String, dynamic>> _getCreditBalance(int contractHistoryId) async {
    try {
      final data = await ApiService.getBillsData(
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          },
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'bill_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final balance = _safeParseInt(data[0]['bill_balance_after']);
        final expiryDate = data[0]['contract_credit_expiry_date'];
        print('    📊 v2_bills 조회결과: ${data.length}건, bill_id=${data[0]['bill_id']}, bill_balance_after=$balance, contract_credit_expiry_date=$expiryDate');
        return {
          'balance': balance,
          'expiry_date': expiryDate,
        };
      }
      print('    ⚠️ v2_bills 조회결과: 0건 (이력없음) - contract_history_id=$contractHistoryId가 v2_bills에 없음');
      return {'balance': 0, 'expiry_date': null};
    } catch (e) {
      print('    ❌ 크레딧 잔액 조회 오류: $e');
      return {'balance': 0, 'expiry_date': null};
    }
  }
  
  // 시간권 잔액 및 유효기간 조회 (v2_bill_times에서 가장 큰 bill_min_id)
  Future<Map<String, dynamic>> _getTimeBalance(int contractHistoryId) async {
    try {
      final data = await ApiService.getBillTimesData(
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          },
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'bill_min_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final balance = _safeParseInt(data[0]['bill_balance_min_after']);
        final expiryDate = data[0]['contract_TS_min_expiry_date'];
        print('    📊 v2_bill_times 조회결과: ${data.length}건, bill_min_id=${data[0]['bill_min_id']}, bill_balance_min_after=$balance, contract_TS_min_expiry_date=$expiryDate');
        return {
          'balance': balance,
          'expiry_date': expiryDate,
        };
      }
      print('    ⚠️ v2_bill_times 조회결과: 0건 (이력없음)');
      return {'balance': 0, 'expiry_date': null};
    } catch (e) {
      print('    ❌ 시간권 잔액 조회 오류: $e');
      return {'balance': 0, 'expiry_date': null};
    }
  }

  // 게임권 잔액 및 유효기간 조회 (v2_bill_games에서 가장 큰 bill_game_id)
  Future<Map<String, dynamic>> _getGameBalance(int contractHistoryId) async {
    try {
      final data = await ApiService.getDataList(
        table: 'v2_bill_games',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          },
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'bill_game_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final balance = _safeParseInt(data[0]['bill_balance_game_after']);
        final expiryDate = data[0]['contract_games_expiry_date'];
        print('    📊 v2_bill_games 조회결과: ${data.length}건, bill_game_id=${data[0]['bill_game_id']}, bill_balance_game_after=$balance, contract_games_expiry_date=$expiryDate');
        return {
          'balance': balance,
          'expiry_date': expiryDate,
        };
      }
      print('    ⚠️ v2_bill_games 조회결과: 0건 (이력없음)');
      return {'balance': 0, 'expiry_date': null};
    } catch (e) {
      print('    ❌ 게임권 잔액 조회 오류: $e');
      return {'balance': 0, 'expiry_date': null};
    }
  }
  
  // 기간권 정보 조회 (v2_bill_term에서 남은 일수와 만료일 반환)
  Future<Map<String, dynamic>?> _getTermData(int contractHistoryId) async {
    try {
      final data = await ApiService.getDataList(
        table: 'v2_bill_term',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          },
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [{'field': 'bill_term_id', 'direction': 'DESC'}],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final expiryDateStr = data[0]['contract_term_month_expiry_date']?.toString();
        print('    📊 v2_bill_term 조회결과: ${data.length}건, bill_term_id=${data[0]['bill_term_id']}, contract_term_month_expiry_date=$expiryDateStr');
        if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            final today = DateTime.now();
            final difference = expiryDate.difference(today).inDays;
            return {
              'remaining_days': difference > 0 ? difference : 0,
              'expiry_date': expiryDateStr,
            };
          } catch (e) {
            print('    ❌ 날짜 파싱 오류: $e');
          }
        }
      } else {
        print('    ⚠️ v2_bill_term 조회결과: 0건 (이력없음)');
      }
      return null;
    } catch (e) {
      print('    ❌ 기간권 정보 조회 오류: $e');
      return null;
    }
  }

  // 레슨권 잔액 및 유효기간 조회 (v3_LS_countings에서 가장 큰 LS_counting_id)
  Future<Map<String, dynamic>> _getLessonBalance(int contractHistoryId) async {
    try {
      final data = await ApiService.getDataList(
        table: 'v3_LS_countings',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          },
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.memberId,
          }
        ],
        orderBy: [
          {
            'field': 'LS_counting_id',
            'direction': 'DESC',
          }
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final balance = _safeParseInt(data[0]['LS_balance_min_after']);
        final expiryDate = data[0]['LS_expiry_date'];
        print('    📊 v3_LS_countings 조회결과: ${data.length}건, LS_counting_id=${data[0]['LS_counting_id']}, LS_balance_min_after=$balance, LS_expiry_date=$expiryDate');
        return {
          'balance': balance,
          'expiry_date': expiryDate,
        };
      }
      print('    ⚠️ v3_LS_countings 조회결과: 0건 (이력없음)');
      return {'balance': 0, 'expiry_date': null};
    } catch (e) {
      print('    ❌ 레슨권 잔액 조회 오류: $e');
      return {'balance': 0, 'expiry_date': null};
    }
  }
  

  // 잔액이 모두 소진되었는지 확인


  // 혜택별 아이콘 반환
  IconData _getBenefitIcon(String benefitType) {
    switch (benefitType) {
      case 'credit':
        return Icons.monetization_on;
      case 'lesson':
        return Icons.school;
      case 'game':
        return Icons.sports_esports;
      case 'time':
        return Icons.sports_golf;
      case 'term':
        return Icons.calendar_month;
      default:
        return Icons.history;
    }
  }

  // 상태 태그들을 빌드하는 함수
  List<Widget> _buildStatusTags(Map<String, dynamic> contract) {
    List<Widget> tags = [];
    
    bool dateExpired = ContractValidityChecker.isDateExpired(contract);
    bool balanceEmpty = ContractValidityChecker.isBalanceEmpty(contract);
    
    if (dateExpired) {
      tags.add(Container(
        margin: EdgeInsets.only(left: 6),
        child: Text(
          '유효기간 만료',
          style: AppTextStyles.cardBody.copyWith(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ));
    }
    
    if (balanceEmpty) {
      tags.add(Container(
        margin: EdgeInsets.only(left: 6),
        child: Text(
          '잔액 소진완료',
          style: AppTextStyles.cardBody.copyWith(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ));
    }
    
    return tags;
  }

  // 프로그램 ID로 프로그램명을 조회하는 함수
  Future<String> _getProgramName(String programId) async {
    try {
      final data = await ApiService.getDataList(
        table: 'v2_base_option_setting',
        where: [
          {
            'field': 'option_value',
            'operator': '=',
            'value': programId,
          },
          {
            'field': 'field_name',
            'operator': '=',
            'value': 'program_id',
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        limit: 1,
      );
      
      if (data.isNotEmpty) {
        return data[0]['table_name']?.toString() ?? programId;
      }
      return programId;
    } catch (e) {
      print('Program name loading error: $e');
      return programId;
    }
  }

  // 예약 가능 프로그램 태그들을 빌드하는 함수
  List<Widget> _buildProgramReservationTags(Map<String, dynamic> contract) {
    List<Widget> tags = [];
    
    // program_names 맵에서 프로그램명 정보 가져오기
    final programNames = contract['program_names'] as Map<String, String>?;
    
    if (programNames != null && programNames.isNotEmpty) {
      for (MapEntry<String, String> entry in programNames.entries) {
        final programId = entry.key;
        final programName = entry.value;
        
        tags.add(Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return ProgramViewerDialog(
                    programId: programId,
                    programName: programName,
                  );
                },
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              margin: EdgeInsets.only(left: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9), // 회색 배경
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFE2E8F0), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: Color(0xFF475569), // 검은색 계열
                  ),
                  SizedBox(width: 3),
                  Text(
                    programName,
                    style: AppTextStyles.cardBody.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569), // 검은색 계열
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }
    
    return tags;
  }

  // 필터링 함수 추가
  void _applyFilter(String? filterType) {
    setState(() {
      activeFilter = activeFilter == filterType ? null : filterType;
      
      if (activeFilter == null) {
        filteredContractData = contractData;
      } else {
        filteredContractData = contractData.where((contract) {
          switch (activeFilter) {
            case 'credit':
              return _safeParseInt(contract['contract_credit']) > 0;
            case 'lesson':
              return _safeParseInt(contract['contract_LS_min']) > 0;
            case 'game':
              return _safeParseInt(contract['contract_games']) > 0;
            case 'time':
              return _safeParseInt(contract['contract_TS_min']) > 0;
            case 'term':
              return _safeParseInt(contract['contract_term_month']) > 0;
            default:
              return true;
          }
        }).toList();
      }
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String? filterType) {
    final isActive = activeFilter == filterType;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: filterType != null ? () => _applyFilter(filterType) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color.withOpacity(0.3) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive 
                  ? color.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.03),
                blurRadius: isActive ? 8 : 4,
                offset: Offset(0, isActive ? 2 : 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    icon, 
                    color: isActive ? color : color.withOpacity(0.8), 
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.cardBody.copyWith(
                        color: isActive ? color : Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (filterType != null)
                    Icon(
                      Icons.filter_alt_outlined,
                      color: isActive ? color : Color(0xFFCBD5E1),
                      size: 14,
                    ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                value,
                style: AppTextStyles.cardBody.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : Color(0xFF1E293B),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 회원권 등록 버튼
  Widget _buildRegistrationButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return ContractRegistrationModal(
                memberId: widget.memberId,
                memberData: widget.memberData,
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color(0xFF3B82F6).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.add_card,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '회원권 등록',
                      style: AppTextStyles.cardBody.copyWith(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '새 계약 추가',
                style: AppTextStyles.cardBody.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractTable() {
    if (contractData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 16),
            Text(
              '계약 이력이 없습니다',
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredContractData.isEmpty && activeFilter != null) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 16),
            Text(
              '필터 조건에 맞는 계약이 없습니다',
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => _applyFilter(null),
              child: Text('필터 초기화'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filteredContractData.length,
      itemBuilder: (context, index) {
        final contract = filteredContractData[index];
        return _buildContractCard(contract, index);
      },
    );
  }

  // 필터 버튼 카드 생성
  List<Widget> _buildFilterCards() {
    List<Widget> cards = [];
    
    // 크레딧
    if (totalCredits > 0) {
      cards.add(Expanded(
        child: _buildStatCard(
          '크레딧',
          '${_formatCurrency(validCreditBalance)}원 (${validCreditCount})',
          Icons.monetization_on,
          Color(0xFFFFA500),
          'credit',
        ),
      ));
    }
    
    // 레슨 시간
    if (totalLessonMinutes > 0) {
      cards.add(Expanded(
        child: _buildStatCard(
          '레슨',
          '${_formatCurrency(validLessonBalance)}분 (${validLessonCount})',
          Icons.school,
          Color(0xFF2563EB),
          'lesson',
        ),
      ));
    }
    
    // 스크린게임
    if (totalGameCount > 0) {
      cards.add(Expanded(
        child: _buildStatCard(
          '스크린게임',
          '${validGameBalance}회 (${validGameCount})',
          Icons.sports_esports,
          Color(0xFF8B5CF6),
          'game',
        ),
      ));
    }
    
    // 타석시간
    if (totalTimeMinutes > 0) {
      cards.add(Expanded(
        child: _buildStatCard(
          '타석시간',
          '${_formatCurrency(validTimeBalance)}분 (${validTimeCount})',
          Icons.sports_golf,
          Color(0xFF10B981),
          'time',
        ),
      ));
    }
    
    // 기간권
    if (totalTermMonths > 0) {
      cards.add(Expanded(
        child: _buildStatCard(
          '기간권',
          '${validTermDays}일 (${validTermCount})',
          Icons.calendar_month,
          Color(0xFF0D9488),
          'term',
        ),
      ));
    }
    
    return cards;
  }

  Widget _buildContractCard(Map<String, dynamic> contract, int index) {
    final isActive = ContractValidityChecker.isContractActive(contract);
    
    return Container(
      margin: EdgeInsets.only(bottom: 8, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.04 : 0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Stack(
            children: [
              // 메인 컨텐츠 영역 - 태그 공간 확보를 위한 패딩
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16), // 기본 패딩으로 복원
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 첫 번째 줄: 상품명, 금액, 결제방식, 기간
                    Padding(
                      padding: EdgeInsets.only(left: 100), // 태그 너비만큼 왼쪽 여백 증가
                      child: Row(
                        children: [
                          // 상품명
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    contract['contract_name']?.toString() ?? '-',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? Color(0xFF0F172A) : Color(0xFF64748B),
                                      height: 1.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 4),
                                // 정보 버튼 추가
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return ContractViewerDialog(
                                            contractHistoryId: contract['contract_history_id'],
                                          );
                                        },
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: isActive ? Color(0xFF64748B) : Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                // 예약 가능 프로그램 태그들
                                ..._buildProgramReservationTags(contract),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                        // 금액
                        Text(
                          '${_formatCurrency(_safeParseInt(contract['price']))}원',
                          style: AppTextStyles.cardBody.copyWith(
                            color: isActive ? Color(0xFF059669) : Color(0xFF94A3B8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        // 결제 방식 - 클릭 가능하도록 수정
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return ContractReceiptDialog(
                                    contractData: contract,
                                  );
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Color(0xFFF1F5F9) : Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Color(0xFFE2E8F0), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 12,
                                    color: isActive ? Color(0xFF475569) : Color(0xFF94A3B8),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    contract['payment_type']?.toString() ?? '-',
                                    style: AppTextStyles.cardBody.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: isActive ? Color(0xFF475569) : Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // 기간 (음영 제거)
                        Text(
                          _buildDateInfoText(contract),
                          style: AppTextStyles.cardBody.copyWith(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // 두 번째 줄: 혜택과 잔액 정보
                    _buildBenefitsWithBalance(contract, isActive),
                  ],
                ),
              ),
              // 좌측 상단: 계약 타입 태그와 상태 태그들
              Positioned(
                top: 0,
                left: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 계약 타입 태그
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive 
                          ? _getContractTypeColor(contract['contract_type']?.toString())
                          : Color(0xFF94A3B8),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isActive 
                              ? _getContractTypeColor(contract['contract_type']?.toString())
                              : Color(0xFF94A3B8)).withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        contract['contract_type']?.toString() ?? '-',
                        style: AppTextStyles.cardBody.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    // 상태 태그들
                    Row(
                      children: _buildStatusTags(contract),
                    ),
                  ],
                ),
              ),
              // 우측 하단: 양도/삭제 버튼
              Positioned(
                bottom: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 양도 버튼 (잔액이 있을 때만 표시)
                    if (ContractValidityChecker.hasTransferableBalance(contract))
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          onPressed: () {
                            _showTransferDialog(contract);
                          },
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.swap_horiz,
                            size: 16,
                            color: Color(0xFF0EA5E9),
                          ),
                          tooltip: '회원권 양도',
                        ),
                      ),
                    // 삭제 버튼
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: () {
                          _showDeleteConfirmDialog(contract, index);
                        },
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        tooltip: '계약 삭제',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 기간 정보 텍스트만 반환
  String _buildDateInfoText(Map<String, dynamic> contract) {
    final contractDate = _formatDate(contract['contract_date']?.toString());
    final contractName = contract['contract_name'] ?? '';
    final contractHistoryId = contract['contract_history_id'];

    // 디버그: 5개 만료일 필드 출력 (모든 계약)
    print('\n[$contractName] (ID:$contractHistoryId) 만료일 필드:');
    print('  1. contract_credit_expiry_date = ${contract['contract_credit_expiry_date']}');
    print('  2. contract_LS_min_expiry_date = ${contract['contract_LS_min_expiry_date']}');
    print('  3. contract_games_expiry_date = ${contract['contract_games_expiry_date']}');
    print('  4. contract_TS_min_expiry_date = ${contract['contract_TS_min_expiry_date']}');
    print('  5. contract_term_month_expiry_date = ${contract['contract_term_month_expiry_date']}');

    // 기간권이 있으면 기간권 만료일만 사용 (v2_bill_term에서 조회한 정확한 값)
    final termRemainingDays = contract['term_remaining_days'];
    String result;
    if (termRemainingDays != null && termRemainingDays > 0) {
      final termExpiryDate = contract['contract_term_month_expiry_date'];
      if (termExpiryDate != null) {
        result = '$contractDate ~ $termExpiryDate';
        print('  ✅ 결론: 기간권 사용 → $result');
        print('  🖥️ 화면 표시: $result');
        return result;
      }
    }

    // 기간권이 없으면 모든 만료일 중 가장 늦은 날짜 사용
    final expiryDate = ContractValidityChecker.getLatestExpiryDate(contract);

    if (expiryDate != null) {
      result = '$contractDate ~ $expiryDate';
      print('  ✅ 결론: 최신 만료일 사용 → $result');
      print('  🖥️ 화면 표시: $result');
      return result;
    } else {
      result = contractDate;
      print('  ✅ 결론: 만료일 없음 → $result');
      print('  🖥️ 화면 표시: $result');
      return result;
    }
  }

  // 날짜 정보 위젯
  Widget _buildDateInfo(Map<String, dynamic> contract) {
    final contractDate = _formatDate(contract['contract_date']?.toString());
    final expiryDate = ContractValidityChecker.getLatestExpiryDate(contract);
    
    if (expiryDate != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range, size: 10, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              '$contractDate ~ $expiryDate',
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 10, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              contractDate,
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }


  // 혜택과 잔액 정보를 함께 표시
  Widget _buildBenefitsWithBalance(Map<String, dynamic> contract, bool isActive) {
    List<Widget> benefits = [];
    
    // 크레딧
    final credit = _safeParseInt(contract['contract_credit']);
    if (credit > 0) {
      final balance = _safeParseInt(contract['credit_balance']);
      benefits.add(_buildBenefitWithBalanceChip(
        '크레딧',
        '${_formatCurrency(balance)} / ${_formatCurrency(credit)}원',
        Icons.monetization_on,
        Color(0xFFFFA500),
        balance > 0,
        contract: contract,
        benefitType: 'credit',
      ));
    }
    
    // 레슨 시간
    final lessonMin = _safeParseInt(contract['contract_LS_min']);
    if (lessonMin > 0) {
      final balance = _safeParseInt(contract['lesson_balance']);
      benefits.add(_buildBenefitWithBalanceChip(
        '레슨',
        '${_formatCurrency(balance)} / ${_formatCurrency(lessonMin)}분',
        Icons.school,
        Color(0xFF2563EB),
        balance > 0,
        contract: contract,
        benefitType: 'lesson',
      ));
    }
    
    // 스크린게임 횟수
    final games = _safeParseInt(contract['contract_games']);
    if (games > 0) {
      final balance = _safeParseInt(contract['game_balance']);
      benefits.add(_buildBenefitWithBalanceChip(
        '스크린게임',
        '${balance} / ${games}회',
        Icons.sports_esports,
        Color(0xFF8B5CF6),
        balance > 0,
        contract: contract,
        benefitType: 'game',
      ));
    }
    
    // 타석시간
    final timeMin = _safeParseInt(contract['contract_TS_min']);
    if (timeMin > 0) {
      final balance = _safeParseInt(contract['time_balance']);
      benefits.add(_buildBenefitWithBalanceChip(
        '타석시간',
        '${balance} / ${_formatCurrency(timeMin)}분',
        Icons.sports_golf,
        Color(0xFF10B981),
        balance > 0,
        contract: contract,
        benefitType: 'time',
      ));
    }
    
    // 기간권
    final termMonth = _safeParseInt(contract['contract_term_month']);
    if (termMonth > 0) {
      final remainingDays = _safeParseInt(contract['term_remaining_days']);
      // 총 기간(일)을 계산하기 위해 개월수를 일로 변환 (평균 30일로 가정)
      final totalDays = termMonth * 30;
      benefits.add(_buildBenefitWithBalanceChip(
        '기간권',
        '${remainingDays} / ${totalDays}일',
        Icons.calendar_month,
        Color(0xFF0D9488),
        remainingDays > 0,
        contract: contract,
        benefitType: 'term',
      ));
    }
    
    if (benefits.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8),
        margin: EdgeInsets.only(left: 80), // 태그 너비만큼 왼쪽 여백
        child: Text(
          '포함된 혜택이 없습니다',
          style: AppTextStyles.cardBody.copyWith(
            color: Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Padding(
      padding: EdgeInsets.only(left: 100), // 태그 너비만큼 왼쪽 여백 증가
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: benefits,
      ),
    );
  }

  Widget _buildBenefitWithBalanceChip(String title, String value, IconData icon, Color color, bool hasBalance, {Map<String, dynamic>? contract, String? benefitType}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: contract != null && benefitType != null ? () => _showBalanceHistoryModal(contract, benefitType, title) : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: hasBalance ? color.withOpacity(0.08) : Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hasBalance ? color.withOpacity(0.2) : Color(0xFFE2E8F0), 
              width: 0.5
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                size: 12, 
                color: hasBalance ? color : Color(0xFF94A3B8),
              ),
              SizedBox(width: 3),
              Text(
                '$title: $value',
                style: AppTextStyles.cardBody.copyWith(
                  color: hasBalance ? color : Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (contract != null && benefitType != null) ...[
                SizedBox(width: 3),
                Icon(
                  Icons.info_outline,
                  size: 10,
                  color: hasBalance ? color.withOpacity(0.7) : Color(0xFFCBD5E1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBenefits(Map<String, dynamic> contract) {
    List<Widget> benefits = [];
    
    // 크레딧
    final credit = _safeParseInt(contract['contract_credit']);
    if (credit > 0) {
      benefits.add(_buildCompactBenefitChip(
        '크레딧',
        '${_formatCurrency(credit)}원',
        Icons.monetization_on,
        Color(0xFFFFA500),
      ));
    }
    
    // 레슨 시간
    final lessonMin = _safeParseInt(contract['contract_LS_min']);
    if (lessonMin > 0) {
      benefits.add(_buildCompactBenefitChip(
        '레슨',
        '${_formatCurrency(lessonMin)}분',
        Icons.school,
        Color(0xFF2563EB),
      ));
    }
    
    // 스크린게임 횟수
    final games = _safeParseInt(contract['contract_games']);
    if (games > 0) {
      benefits.add(_buildCompactBenefitChip(
        '스크린게임',
        '${games}회',
        Icons.sports_esports,
        Color(0xFF8B5CF6),
      ));
    }
    
    // 타석시간
    final timeMin = _safeParseInt(contract['contract_TS_min']);
    if (timeMin > 0) {
      benefits.add(_buildCompactBenefitChip(
        '타석시간',
        '${_formatCurrency(timeMin)}분',
        Icons.sports_golf,
        Color(0xFF10B981),
      ));
    }
    
    // 기간권
    final termMonth = _safeParseInt(contract['contract_term_month']);
    if (termMonth > 0) {
      benefits.add(_buildCompactBenefitChip(
        '기간권',
        '${termMonth}개월',
        Icons.calendar_month,
        Color(0xFF0D9488),
      ));
    }
    
    if (benefits.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '포함된 혜택이 없습니다',
          style: AppTextStyles.cardBody.copyWith(
            color: Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: benefits,
    );
  }

  Widget _buildCompactBenefitChip(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 3),
          Text(
            '$title: $value',
            style: AppTextStyles.cardBody.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsGrid(Map<String, dynamic> contract) {
    // 이 함수는 더 이상 사용하지 않음 - _buildCompactBenefits로 대체
    return Container();
  }

  Widget _buildBenefitItem(String title, String value, IconData icon, Color color, String? expiryDate) {
    // 이 함수는 더 이상 사용하지 않음 - _buildCompactBenefitChip으로 대체
    return Container();
  }

  Color _getContractTypeColor(String? type) {
    switch (type) {
      case '패키지':
        return Color(0xFF3B82F6);
      case '선불크레딧':
        return Color(0xFF7C3AED);
      case '레슨권':
        return Color(0xFFDC2626);
      case '시간권':
        return Color(0xFFEF4444);
      case '기간권':
        return Color(0xFF059669);
      default:
        return Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF8FAFC),
      child: Column(
        children: [
          // 상단 필터 버튼들
          Container(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                // 필터 카드들과 회원권 등록 버튼
                Row(
                  children: [
                    // 필터 카드들 사이에 spacing 추가
                    ..._buildFilterCards().asMap().entries.expand((entry) {
                      final index = entry.key;
                      final widget = entry.value;
                      if (index == 0) {
                        return [widget];
                      } else {
                        return [SizedBox(width: 8), widget];
                      }
                    }),
                    if (_buildFilterCards().isNotEmpty) SizedBox(width: 8),
                    // 회원권 등록 버튼 - member_registration 권한 체크
                    if (ApiService.hasPermission('member_registration'))
                      Expanded(
                        child: _buildRegistrationButton(),
                      ),
                  ],
                ),
                
                // 락커/만료 필터 컨트롤러
                SizedBox(height: 12),
                Row(
                  children: [
                    // 락커 필터 토글
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: includeLocker,
                            onChanged: (value) {
                              setState(() {
                                includeLocker = value ?? false;
                              });
                              _applyFilters();
                            },
                            activeColor: Color(0xFF3B82F6),
                            side: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '락커 포함',
                          style: AppTextStyles.caption.copyWith(
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(width: 20),
                    
                    // 만료 필터 토글
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: includeExpired,
                            onChanged: (value) {
                              setState(() {
                                includeExpired = value ?? false;
                              });
                              _applyFilters();
                            },
                            activeColor: Color(0xFF3B82F6),
                            side: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '만료 포함',
                          style: AppTextStyles.caption.copyWith(
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: 8),
          
          // 계약 이력 테이블
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 12),
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '계약 데이터를 불러오는 중...',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFFDC2626),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '데이터 로딩 중 오류가 발생했습니다',
                                style: AppTextStyles.caption.copyWith(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: AppTextStyles.caption.copyWith(
                                  color: Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadContractData,
                                child: Text('다시 시도'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: _buildContractTable(),
                        ),
            ),
          ),
          
          // 총 계약수와 총 결제금액 텍스트
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 계약수: ${totalContracts}건',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '총 결제금액: ${_formatCurrency(totalPayment)}원',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(Map<String, dynamic> contract, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '계약 삭제',
            style: AppTextStyles.cardBody.copyWith(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '다음 계약을 삭제하시겠습니까?',
                style: AppTextStyles.caption.copyWith(
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '계약명: ${contract['contract_name'] ?? '-'}',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '계약일: ${_formatDate(contract['contract_date']?.toString())}',
                      style: AppTextStyles.caption.copyWith(
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '결제금액: ${_formatCurrency(_safeParseInt(contract['price']))}원',
                      style: AppTextStyles.caption.copyWith(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ 이 작업은 되돌릴 수 없습니다.',
                style: AppTextStyles.caption.copyWith(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: AppTextStyles.cardBody.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteContract(contract, index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                '삭제',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 계약 삭제 함수
  Future<void> _deleteContract(Map<String, dynamic> contract, int index) async {
    try {
      // TODO: 실제 API 호출로 계약 삭제
      // await ApiService.deleteContract(contract['id']);
      
      // 임시로 로컬에서만 삭제
      setState(() {
        // 원본 데이터에서 삭제
        contractData.removeWhere((c) => c['id'] == contract['id']);
        // 필터된 데이터도 업데이트
        filteredContractData = contractData.where((c) {
          if (activeFilter == null) return true;
          switch (activeFilter) {
            case 'credit':
              return _safeParseInt(c['contract_credit']) > 0;
            case 'lesson':
              return _safeParseInt(c['contract_LS_min']) > 0;
            case 'game':
              return _safeParseInt(c['contract_games']) > 0;
            case 'time':
              return _safeParseInt(c['contract_TS_min']) > 0;
            case 'term':
              return _safeParseInt(c['contract_term_month']) > 0;
            default:
              return true;
          }
        }).toList();
        // 통계 재계산
        _recalculateStats();
        _calculateValidBalances();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계약이 삭제되었습니다'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  // 유효 잔액 합계 계산
  void _calculateValidBalances() {
    // 초기화
    validCreditBalance = 0;
    validCreditCount = 0;
    validLessonBalance = 0;
    validLessonCount = 0;
    validGameBalance = 0;
    validGameCount = 0;
    validTimeBalance = 0;
    validTimeCount = 0;
    validTermDays = 0;
    validTermCount = 0;
    
    for (var contract in contractData) {
      if (ContractValidityChecker.isContractActive(contract)) {
        // 크레딧
        final creditBalance = _safeParseInt(contract['credit_balance']);
        if (creditBalance > 0) {
          validCreditBalance += creditBalance;
          validCreditCount++;
        }
        
        // 레슨
        final lessonBalance = _safeParseInt(contract['lesson_balance']);
        if (lessonBalance > 0) {
          validLessonBalance += lessonBalance;
          validLessonCount++;
        }
        
        // 게임
        final gameBalance = _safeParseInt(contract['game_balance']);
        if (gameBalance > 0) {
          validGameBalance += gameBalance;
          validGameCount++;
        }
        
        // 타석시간
        final timeBalance = _safeParseInt(contract['time_balance']);
        if (timeBalance > 0) {
          validTimeBalance += timeBalance;
          validTimeCount++;
        }
        
        // 기간권
        final termDays = _safeParseInt(contract['term_remaining_days']);
        if (termDays > 0) {
          validTermDays += termDays;
          validTermCount++;
        }
      }
    }
  }

  // 통계 재계산 함수
  void _recalculateStats() {
    int payment = 0;
    int credits = 0;
    int lessons = 0;
    int lessonMinutes = 0;
    int gameCount = 0;
    int timeMinutes = 0;
    int termMonths = 0;
    
    for (var contract in contractData) {
      payment += _safeParseInt(contract['price']);
      credits += _safeParseInt(contract['contract_credit']);
      
      final contractLessonMin = _safeParseInt(contract['contract_LS_min']);
      if (contractLessonMin > 0) {
        lessons++;
        lessonMinutes += contractLessonMin;
      }
      
      gameCount += _safeParseInt(contract['contract_games']);
      timeMinutes += _safeParseInt(contract['contract_TS_min']);
      termMonths += _safeParseInt(contract['contract_term_month']);
    }

    totalContracts = contractData.length;
    totalPayment = payment;
    totalCredits = credits;
    lessonPurchases = lessons;
    totalLessonMinutes = lessonMinutes;
    totalGameCount = gameCount;
    totalTimeMinutes = timeMinutes;
    totalTermMonths = termMonths;
  }

  // 잔액 내역 모달 표시
  void _showBalanceHistoryModal(Map<String, dynamic> contract, String benefitType, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(-1.0, 0.0),
                      end: AlignmentDirectional(1.0, 0.0),
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Icon(
                                _getBenefitIcon(benefitType),
                                color: Colors.white,
                                size: 24.0,
                              ),
                            ),
                            SizedBox(width: 16.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$title 사용 내역',
                                  style: AppTextStyles.titleH3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  contract['contract_name']?.toString() ?? '-',
                                  style: AppTextStyles.cardBody.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20.0),
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 내용
                Expanded(
                  child: _buildBalanceHistoryContent(contract, benefitType),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 잔액 내역 내용 구성
  Widget _buildBalanceHistoryContent(Map<String, dynamic> contract, String benefitType) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getBalanceHistory(contract['contract_history_id'], benefitType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF3B82F6)),
                SizedBox(height: 16),
                Text(
                  '내역을 불러오는 중...',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
                SizedBox(height: 16),
                Text(
                  '내역을 불러오는 중 오류가 발생했습니다',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        final historyData = snapshot.data ?? [];
        
        if (historyData.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(height: 16),
                Text(
                  '사용 내역이 없습니다',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 크레딧인 경우에만 버튼 표시
            if (benefitType == 'credit') ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 수동차감/적립 다이얼로그 호출 (팝업 닫지 않음)
                          _showManualCreditDialog(contract);
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text(
                          '수동차감/적립',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // 상품구매 다이얼로그 호출 (팝업 닫지 않음)
                          final result = await _showProductPurchaseDialog(contract);
                          if (result == true) {
                            // 상품구매 성공 후 사용 내역 새로고침
                            Navigator.of(context).pop(); // 현재 팝업 닫기
                            _showBalanceHistoryModal(contract, 'credit', '크레딧'); // 새로고침된 팝업 다시 열기
                          }
                        },
                        icon: Icon(Icons.shopping_cart, size: 16),
                        label: Text(
                          '상품구매',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 유효기간 조정 다이얼로그 호출 (팝업 닫지 않음)
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ExpiryChangeDialog(
                                contractHistoryId: contract['contract_history_id'],
                                benefitType: 'credit',
                                onSaved: () {
                                  // 유효기간 변경 후 데이터 새로고침
                                  _loadContractData();
                                },
                              );
                            },
                          );
                        },
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '유효기간 조정',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 타석시간 버튼들
            if (benefitType == 'time') ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 수동차감/적립 다이얼로그 호출 (팝업 닫지 않음)
                          _showTimeManualDialog(contract);
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text(
                          '수동차감/적립',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 유효기간 조정 다이얼로그 호출 (팝업 닫지 않음)
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ExpiryChangeDialog(
                                contractHistoryId: contract['contract_history_id'],
                                benefitType: 'time',
                                onSaved: () {
                                  // 유효기간 변경 후 데이터 새로고침
                                  _loadContractData();
                                },
                              );
                            },
                          );
                        },
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '유효기간 조정',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 스크린게임 버튼들
            if (benefitType == 'game') ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 수동차감/적립 다이얼로그 호출 (팝업 닫지 않음)
                          _showGameManualDialog(contract);
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text(
                          '수동차감/적립',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 유효기간 조정 다이얼로그 호출 (팝업 닫지 않음)
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ExpiryChangeDialog(
                                contractHistoryId: contract['contract_history_id'],
                                benefitType: 'game',
                                onSaved: () {
                                  // 유효기간 변경 후 데이터 새로고침
                                  _loadContractData();
                                },
                              );
                            },
                          );
                        },
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '유효기간 조정',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 레슨권 버튼들
            if (benefitType == 'lesson') ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 수동차감/적립 다이얼로그 호출 (팝업 닫지 않음)
                          _showLessonManualDialog(contract);
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text(
                          '수동차감/적립',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 프로변경 다이얼로그 호출 (팝업 닫지 않음)
                          _showLessonProChangeDialog(contract);
                        },
                        icon: Icon(Icons.person_outline, size: 16),
                        label: Text(
                          '프로변경',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 유효기간 조정 다이얼로그 호출 (팝업 닫지 않음)
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ExpiryChangeDialog(
                                contractHistoryId: contract['contract_history_id'],
                                benefitType: 'lesson',
                                onSaved: () {
                                  // 유효기간 변경 후 데이터 새로고침
                                  _loadContractData();
                                },
                              );
                            },
                          );
                        },
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '유효기간 조정',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 기간권 버튼들
            if (benefitType == 'term') ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // 홀드등록 다이얼로그 호출 (팝업 닫지 않음)
                          final result = await _showTermHoldDialog(contract);
                          if (result == true) {
                            // 홀드등록 성공 후 사용 내역 새로고침
                            Navigator.of(context).pop(); // 현재 팝업 닫기
                            _showBalanceHistoryModal(contract, 'term', '기간권'); // 새로고침된 팝업 다시 열기
                          }
                        },
                        icon: Icon(Icons.pause_circle, size: 16),
                        label: Text(
                          '홀드등록',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 통일된 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // 유효기간 조정 다이얼로그 호출 (팝업 닫지 않음)
                          await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ExpiryChangeDialog(
                                contractHistoryId: contract['contract_history_id'],
                                benefitType: 'term',
                                onSaved: () {
                                  // 유효기간 변경 후 데이터 새로고침
                                  _loadContractData();
                                },
                              );
                            },
                          );
                          // 유효기간 조정 완료 후 사용 내역 새로고침
                          Navigator.of(context).pop(); // 현재 팝업 닫기
                          _showBalanceHistoryModal(contract, 'term', '기간권'); // 새로고침된 팝업 다시 열기
                        },
                        icon: Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '유효기간 조정',
                          style: AppTextStyles.button.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B7280), // 회색
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 요약 정보
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: _buildSummaryInfo(contract, benefitType, historyData),
            ),
            // 내역 테이블
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: _buildHistoryTable(benefitType, historyData),
              ),
            ),
          ],
        );
      },
    );
  }

  // 요약 정보
  Widget _buildSummaryInfo(Map<String, dynamic> contract, String benefitType, List<Map<String, dynamic>> historyData) {
    String summaryText = '';
    
    switch (benefitType) {
      case 'credit':
        final total = _safeParseInt(contract['contract_credit']);
        final balance = _safeParseInt(contract['credit_balance']);
        final used = total - balance;
        summaryText = '총 ${_formatCurrency(total)}원 중 ${_formatCurrency(used)}원 사용, ${_formatCurrency(balance)}원 잔액';
        break;
      case 'time':
        final total = _safeParseInt(contract['contract_TS_min']);
        final balance = _safeParseInt(contract['time_balance']);
        final used = total - balance;
        summaryText = '총 ${total}분 중 ${used}분 사용, ${balance}분 잔액';
        break;
      case 'game':
        final total = _safeParseInt(contract['contract_games']);
        final balance = _safeParseInt(contract['game_balance']);
        final used = total - balance;
        summaryText = '총 ${total}회 중 ${used}회 사용, ${balance}회 잔액';
        break;
      case 'term':
        final totalMonths = _safeParseInt(contract['contract_term_month']);
        final remainingDays = _safeParseInt(contract['term_remaining_days']);
        summaryText = '${totalMonths}개월 기간권, ${remainingDays}일 남음';
        break;
      case 'lesson':
        final total = _safeParseInt(contract['contract_LS_min']);
        summaryText = '레슨 ${total}분 (잔액 추적 없음)';
        break;
    }

    return Row(
      children: [
        Icon(
          Icons.info_outline,
          color: Color(0xFF3B82F6),
          size: 20,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            summaryText,
            style: AppTextStyles.cardBody.copyWith(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // 내역 테이블
  Widget _buildHistoryTable(String benefitType, List<Map<String, dynamic>> historyData) {
    return ListView.builder(
      itemCount: historyData.length,
      itemBuilder: (context, index) {
        final item = historyData[index];
        return _buildHistoryItem(benefitType, item, index);
      },
    );
  }

  // 내역 아이템
  Widget _buildHistoryItem(String benefitType, Map<String, dynamic> item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // 날짜
          Container(
            width: 80,
            child: Text(
              _formatDate(benefitType == 'lesson' 
                ? item['LS_date']?.toString() 
                : item['bill_date']?.toString()),
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefitType == 'lesson' 
                    ? item['LS_transaction_type']?.toString() ?? '-'
                    : item['bill_text']?.toString() ?? '-',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  benefitType == 'lesson' 
                    ? '${item['LS_status']?.toString() ?? '-'} ${item['LS_id']?.toString() ?? ''}'.trim()
                    : item['bill_type']?.toString() ?? '-',
                  style: AppTextStyles.cardBody.copyWith(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // 사용량/잔액
          _buildAmountColumn(benefitType, item),
        ],
      ),
    );
  }

  // 사용량/잔액 컬럼
  Widget _buildAmountColumn(String benefitType, Map<String, dynamic> item) {
    String amount = '';
    String balance = '';
    Color amountColor = Color(0xFF64748B);
    
    switch (benefitType) {
      case 'credit':
        final balanceBefore = _safeParseInt(item['bill_balance_before']);
        final balanceAfter = _safeParseInt(item['bill_balance_after']);
        final changeAmount = balanceAfter - balanceBefore; // after - before로 차감액 계산
        amount = changeAmount >= 0 ? '+${_formatCurrency(changeAmount)}원' : '${_formatCurrency(changeAmount)}원';
        balance = '잔액: ${_formatCurrency(balanceAfter)}원';
        amountColor = changeAmount >= 0 ? Color(0xFF059669) : Color(0xFFDC2626);
        break;
      case 'time':
        final balanceBefore = _safeParseInt(item['bill_balance_min_before']);
        final balanceAfter = _safeParseInt(item['bill_balance_min_after']);
        final changeAmount = balanceAfter - balanceBefore; // after - before로 차감액 계산
        amount = changeAmount >= 0 ? '+${changeAmount}분' : '${changeAmount}분';
        balance = '잔액: ${balanceAfter}분';
        amountColor = changeAmount >= 0 ? Color(0xFF059669) : Color(0xFFDC2626);
        break;
      case 'game':
        final balanceBefore = _safeParseInt(item['bill_balance_game_before']);
        final balanceAfter = _safeParseInt(item['bill_balance_game_after']);
        final changeAmount = balanceAfter - balanceBefore; // after - before로 차감액 계산
        amount = changeAmount >= 0 ? '+${changeAmount}회' : '${changeAmount}회';
        balance = '잔액: ${balanceAfter}회';
        amountColor = changeAmount >= 0 ? Color(0xFF059669) : Color(0xFFDC2626);
        break;
      case 'lesson':
        final balanceBefore = _safeParseInt(item['LS_balance_min_before']);
        final balanceAfter = _safeParseInt(item['LS_balance_min_after']);
        final changeAmount = balanceAfter - balanceBefore; // after - before로 차감액 계산
        amount = changeAmount >= 0 ? '+${changeAmount}분' : '${changeAmount}분';
        balance = '잔액: ${balanceAfter}분';
        amountColor = changeAmount >= 0 ? Color(0xFF059669) : Color(0xFFDC2626);
        break;
      case 'term':
        // 기간권은 단순히 등록 정보만
        amount = '등록';
        balance = '';
        amountColor = Color(0xFF059669);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          amount,
          style: AppTextStyles.cardBody.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (balance.isNotEmpty)
          Text(
            balance,
            style: AppTextStyles.cardBody.copyWith(
              color: Color(0xFF64748B),
            ),
          ),
      ],
    );
  }

  // 혜택별 내역 데이터 조회
  Future<List<Map<String, dynamic>>> _getBalanceHistory(int contractHistoryId, String benefitType) async {
    try {
      switch (benefitType) {
        case 'credit':
          final data = await ApiService.getBillsData(
            where: [
              {
                'field': 'contract_history_id',
                'operator': '=',
                'value': contractHistoryId,
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': ApiService.getCurrentBranchId(),
              },
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId,
              }
            ],
            orderBy: [
              {
                'field': 'bill_id',
                'direction': 'DESC',
              }
            ],
          );
          // 클라이언트에서 예약취소 제외
          return data.where((item) => item['bill_type'] != '예약취소').toList();
        case 'time':
          final data = await ApiService.getBillTimesData(
            where: [
              {
                'field': 'contract_history_id',
                'operator': '=',
                'value': contractHistoryId,
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': ApiService.getCurrentBranchId(),
              },
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId,
              }
            ],
            orderBy: [
              {
                'field': 'bill_min_id',
                'direction': 'DESC',
              }
            ],
          );
          // 클라이언트에서 예약취소 제외
          return data.where((item) => item['bill_type'] != '예약취소').toList();
        case 'game':
          final data = await ApiService.getDataList(
            table: 'v2_bill_games',
            where: [
              {
                'field': 'contract_history_id',
                'operator': '=',
                'value': contractHistoryId,
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': ApiService.getCurrentBranchId(),
              },
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId,
              }
            ],
            orderBy: [
              {
                'field': 'bill_game_id',
                'direction': 'DESC',
              }
            ],
          );
          // 클라이언트에서 예약취소 제외
          return data.where((item) => item['bill_type'] != '예약취소').toList();
        case 'term':
          return await ApiService.getDataList(
            table: 'v2_bill_term',
            where: [
              {
                'field': 'contract_history_id',
                'operator': '=',
                'value': contractHistoryId,
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': ApiService.getCurrentBranchId(),
              },
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId,
              }
            ],
            orderBy: [
              {
                'field': 'bill_term_id',
                'direction': 'DESC',
              }
            ],
          );
        case 'lesson':
          final data = await ApiService.getDataList(
            table: 'v3_LS_countings',
            where: [
              {
                'field': 'contract_history_id',
                'operator': '=',
                'value': contractHistoryId,
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': ApiService.getCurrentBranchId(),
              },
              {
                'field': 'member_id',
                'operator': '=',
                'value': widget.memberId,
              }
            ],
            orderBy: [
              {
                'field': 'LS_counting_id',
                'direction': 'DESC',
              }
            ],
          );
          // 클라이언트에서 예약취소 제외
          return data.where((item) => item['LS_status'] != '예약취소').toList();
        default:
          return [];
      }
    } catch (e) {
      print('Balance history loading error: $e');
      return [];
    }
  }

  // 수동차감/적립 다이얼로그 표시
  void _showManualCreditDialog(Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ManualCreditDialog(
          memberId: widget.memberId,
          contractHistoryId: contract['contract_history_id'],
          onSuccess: () {
            // 성공 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
  }

  // 타석시간 수동차감/적립 다이얼로그 표시
  void _showTimeManualDialog(Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TimeManualDialog(
          contract: contract,
          onSaved: () {
            // 성공 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
  }

  // 스크린게임 수동차감/적립 다이얼로그 표시
  void _showGameManualDialog(Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GameManualDialog(
          contract: contract,
          onSaved: () {
            // 성공 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
  }

  // 레슨권 수동차감/적립 다이얼로그 표시
  void _showLessonManualDialog(Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LessonManualDialog(
          contract: contract,
          onSaved: () {
            // 성공 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
  }

  // 레슨권 프로변경 다이얼로그 표시
  void _showLessonProChangeDialog(Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LessonProChangeDialog(
          contract: contract,
          onSaved: () {
            // 성공 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
  }

  // 필터 적용
  void _applyFilters() {
    print('=== 필터 적용 시작 ===');
    print('락커 포함: $includeLocker, 만료 포함: $includeExpired');

    Map<String, List<String>> excludedReasons = {
      '락커': [],
      '만료': [],
    };
    List<String> included = [];

    setState(() {
      filteredContractData = contractData.where((contract) {
        final contractName = contract['contract_name'] ?? '';
        final contractType = contract['contract_type'] ?? '';

        // 락커 필터
        if (!includeLocker) {
          if (contractType.contains('락커') || contractType.contains('locker')) {
            excludedReasons['락커']!.add(contractName);
            return false;
          }
        }

        // 만료 필터 (디버그 모드로 상세 정보 출력)
        if (!includeExpired && ContractValidityChecker.isExpiredContract(contract, debug: true)) {
          excludedReasons['만료']!.add(contractName);
          return false;
        }

        included.add(contractName);
        return true;
      }).toList();

      // 컴팩트 디버그 출력
      print('📊 필터링 결과 요약:');
      print('  ✅ 포함: ${included.length}건 ${included.isNotEmpty ? '- ${included.join(", ")}' : ''}');
      print('  🚫 락커 제외: ${excludedReasons['락커']!.length}건 ${excludedReasons['락커']!.isNotEmpty ? '- ${excludedReasons['락커']!.join(", ")}' : ''}');
      print('  ⏰ 만료 제외: ${excludedReasons['만료']!.length}건 ${excludedReasons['만료']!.isNotEmpty ? '- ${excludedReasons['만료']!.join(", ")}' : ''}');
      print('  📈 전체: ${contractData.length}건 → ${filteredContractData.length}건');
    });
  }



  // 회원권 양도 다이얼로그 표시
  void _showTransferDialog(Map<String, dynamic> contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TransferMembershipWidget(
          contract: contract,
          onTransferComplete: () {
            // 양도 완료 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
  }

  // 홀드 이력 조회
  Future<List<Map<String, dynamic>>> _getHoldHistory(int contractHistoryId) async {
    try {
      final data = await ApiService.getDataList(
        table: 'v2_bill_term_hold',
        where: [
          {
            'field': 'contract_history_id',
            'operator': '=',
            'value': contractHistoryId,
          }
        ],
        orderBy: [
          {
            'field': 'term_hold_timestamp',
            'direction': 'DESC',
          }
        ],
      );
      return data;
    } catch (e) {
      print('홀드 이력 조회 오류: $e');
      return [];
    }
  }

  // 기간권 홀드등록 다이얼로그 표시
  Future<bool> _showTermHoldDialog(Map<String, dynamic> contract) async {
    print('=== tab2_contract 홀드등록 다이얼로그 시작 ===');
    DateTime? holdStartDate;
    DateTime? holdEndDate;
    String holdReason = '';
    int holdDays = 0;
    List<Map<String, dynamic>> holdHistory = [];
    
    // 기간권 종료일 파싱 (term_remaining_days를 이용해 현재 만료일 계산)
    final remainingDays = _safeParseInt(contract['term_remaining_days']);
    final contractEndDate = DateTime.now().add(Duration(days: remainingDays));
    
    // 홀드 이력 조회
    holdHistory = await _getHoldHistory(contract['contract_history_id']);

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BaseContractDialog(
              benefitType: 'term',
              title: '기간권 홀드 등록',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 홀드 이력
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BenefitTypeTheme.getTheme('term').background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BenefitTypeTheme.getTheme('term').border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: BenefitTypeTheme.getTheme('term').primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '홀드 이력',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: BenefitTypeTheme.getTheme('term').primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          height: 120,
                          child: holdHistory.isEmpty
                            ? Center(
                                child: Text(
                                  '홀드 이력이 없습니다',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: holdHistory.length,
                                itemBuilder: (context, index) {
                                  final hold = holdHistory[index];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: BenefitTypeTheme.getTheme('term').primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${hold['term_add_dates'] ?? 0}일',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '${hold['term_hold_start']} ~ ${hold['term_hold_end']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (hold['term_hold_reason'] != null && hold['term_hold_reason'].toString().isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            hold['term_hold_reason'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // 홀드 시작일
                  ContractInputField(
                    label: '홀드 시작일',
                    hint: '날짜를 선택하세요',
                    controller: TextEditingController(
                      text: holdStartDate != null 
                        ? DateFormat('yyyy.MM.dd').format(holdStartDate!)
                        : '',
                    ),
                    isRequired: true,
                    enabled: false,
                    suffix: IconButton(
                      onPressed: () async {
                        print('=== tab2_contract 홀드 시작일 IconButton 클릭됨 ===');
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: holdStartDate ?? (DateTime.now().isBefore(contractEndDate) 
                            ? DateTime.now() 
                            : contractEndDate.subtract(Duration(days: 1))),
                          firstDate: DateTime.now(),
                          lastDate: contractEndDate,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            holdStartDate = picked;
                            // 홀드 종료일이 시작일보다 이전이면 초기화
                            if (holdEndDate != null && holdEndDate!.isBefore(picked)) {
                              holdEndDate = null;
                              holdDays = 0;
                            } else if (holdEndDate != null) {
                              holdDays = holdEndDate!.difference(holdStartDate!).inDays + 1;
                            }
                          });
                        }
                      },
                      icon: Icon(Icons.calendar_today, color: BenefitTypeTheme.getTheme('term').primary),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // 홀드 종료일
                  ContractInputField(
                    label: '홀드 종료일',
                    hint: holdStartDate != null ? '날짜를 선택하세요' : '시작일을 먼저 선택하세요',
                    controller: TextEditingController(
                      text: holdEndDate != null 
                        ? DateFormat('yyyy.MM.dd').format(holdEndDate!)
                        : '',
                    ),
                    isRequired: true,
                    enabled: false,
                    suffix: IconButton(
                      onPressed: holdStartDate != null ? () async {
                        print('=== tab2_contract 홀드 종료일 IconButton 클릭됨 ===');
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: holdEndDate ?? holdStartDate!,
                          firstDate: holdStartDate!,
                          lastDate: contractEndDate,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            holdEndDate = picked;
                            holdDays = picked.difference(holdStartDate!).inDays + 1;
                          });
                        }
                      } : null,
                      icon: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: holdStartDate != null ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.calendar_today, 
                          size: 24,
                          color: holdStartDate != null ? Colors.green : Colors.grey,
                        ),
                      ),
                      tooltip: holdStartDate != null ? '종료일 선택' : '시작일을 먼저 선택하세요',
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // 홀드 일수 표시
                  if (holdDays > 0) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BenefitTypeTheme.getTheme('term').background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BenefitTypeTheme.getTheme('term').border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: BenefitTypeTheme.getTheme('term').primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '홀드 기간: $holdDays일',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: BenefitTypeTheme.getTheme('term').primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // 홀드 사유
                  ContractInputField(
                    label: '홀드 사유',
                    hint: '홀드 사유를 입력하세요',
                    maxLines: 3,
                    onChanged: (value) {
                      holdReason = value;
                    },
                  ),
                ],
              ),
              actions: [
                ContractActionButton(
                  text: '취소',
                  benefitType: 'term',
                  isSecondary: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                SizedBox(width: 12),
                ContractActionButton(
                  text: '홀드 등록',
                  benefitType: 'term',
                  onPressed: (holdStartDate != null && holdEndDate != null && holdDays > 0)
                    ? () => Navigator.of(context).pop(true)
                    : null,
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && holdStartDate != null && holdEndDate != null) {
      final success = await _processTermHoldRegistration(
        contract, 
        holdStartDate!, 
        holdEndDate!, 
        holdReason, 
        holdDays
      );
      return success;
    }
    return false;
  }

  // 기간권 홀드 등록 처리
  Future<bool> _processTermHoldRegistration(
    Map<String, dynamic> contract, 
    DateTime holdStart, 
    DateTime holdEnd, 
    String reason, 
    int addDays
  ) async {
    try {
      final contractHistoryId = contract['contract_history_id'];

      // 1. v2_bill_term_hold 테이블에 홀드 정보 추가
      final currentUser = ApiService.getCurrentUser();
      final staffId = currentUser?['manager_contract_id'] ?? currentUser?['pro_contract_id'] ?? 1;

      final holdData = {
        'contract_history_id': contractHistoryId,
        'term_hold_start': DateFormat('yyyy-MM-dd').format(holdStart),
        'term_hold_end': DateFormat('yyyy-MM-dd').format(holdEnd),
        'term_hold_reason': reason,
        'term_add_dates': addDays,
        'staff_id': staffId,
        'term_hold_timestamp': DateTime.now().toIso8601String(),
      };

      final holdResponse = await ApiService.addBillTermHoldData(holdData);
      
      if (holdResponse['success'] == true) {
        // 2. v2_bill_term에 홀드등록 레코드 추가
        final latestTerm = await ApiService.getLatestBillTermByContractHistoryId(contractHistoryId);
        if (latestTerm != null) {
          final originalEndDate = DateTime.parse(latestTerm['contract_term_month_expiry_date']);
          final newEndDate = originalEndDate.add(Duration(days: addDays));
          
          final newTermData = {
            'member_id': contract['member_id'] ?? widget.memberId,
            'bill_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'bill_type': '홀드등록',
            'bill_text': '${contract['bill_text'] ?? ''} (홀드 ${addDays}일)',
            'bill_term_min': null,
            'bill_timestamp': DateTime.now().toIso8601String(),
            'reservation_id': null,
            'bill_status': '결제완료',
            'contract_history_id': contractHistoryId,
            'contract_term_month_expiry_date': DateFormat('yyyy-MM-dd').format(newEndDate),
            'term_startdate': latestTerm['term_startdate'], // 원래 계약 시작일 유지
            'term_enddate': DateFormat('yyyy-MM-dd').format(newEndDate), // 연장된 종료일
          };

          final termResponse = await ApiService.addBillTermData(newTermData);
          
          if (termResponse['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('홀드가 성공적으로 등록되었습니다. (+${addDays}일 연장)'),
                  backgroundColor: Color(0xFF059669),
                ),
              );
            }
            
            // 데이터 새로고침
            _loadContractData();
            return true;
          } else {
            throw Exception('v2_bill_term 등록 실패: ${termResponse['message']}');
          }
        } else {
          throw Exception('최신 기간권 정보를 찾을 수 없습니다.');
        }
      } else {
        throw Exception('홀드 정보 등록 실패: ${holdResponse['message']}');
      }
    } catch (e) {
      print('홀드 등록 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('홀드 등록 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // 상품구매 다이얼로그 표시
  Future<bool> _showProductPurchaseDialog(Map<String, dynamic> contract) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ProductPurchaseDialog(
          memberId: widget.memberId,
          contractHistoryId: contract['contract_history_id'],
          onSuccess: () {
            // 성공 시 계약 데이터 다시 로드
            _loadContractData();
          },
        );
      },
    );
    
    return result ?? false;
  }
}