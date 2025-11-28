import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';

class ContractRegistrationModal extends StatefulWidget {
  final int memberId;
  final Map<String, dynamic>? memberData;

  const ContractRegistrationModal({
    Key? key,
    required this.memberId,
    this.memberData,
  }) : super(key: key);

  @override
  State<ContractRegistrationModal> createState() => _ContractRegistrationModalState();
}

class _ContractRegistrationModalState extends State<ContractRegistrationModal> 
    with TickerProviderStateMixin {
  // 회원권 유형 선택
  String? selectedMembershipType;
  List<String> membershipTypes = []; // 동적으로 로드할 리스트로 변경

  // 계약 선택
  String? selectedContract;
  List<Map<String, dynamic>> contracts = [];
  bool isLoadingContracts = false;
  bool isLoadingMembershipTypes = false; // 회원권 유형 로딩 상태 추가

  // 자유적립 금액 입력
  TextEditingController freeDepositController = TextEditingController();
  int? freeDepositAmount;

  // 결제 방식
  String? selectedPaymentType;
  final List<Map<String, dynamic>> paymentTypes = [
    {'value': '카드결제', 'icon': Icons.credit_card, 'color': Color(0xFF3B82F6)},
    {'value': '현금결제', 'icon': Icons.payments, 'color': Color(0xFF10B981)},
    {'value': '크레딧결제', 'icon': Icons.account_balance_wallet, 'color': Color(0xFF8B5CF6)},
    {'value': '톡스토어', 'icon': Icons.store, 'color': Color(0xFFF59E0B)},
  ];

  // 등록일자
  DateTime selectedDate = DateTime.now();

  // 프로 매칭 관련
  List<Map<String, dynamic>> availablePros = [];
  String? selectedProId;
  bool isLoadingProData = false;

  // 기간권 시작일자 관련
  DateTime? termStartDate;
  DateTime? termEndDate;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    
    _loadMembershipTypes(); // 회원권 유형 로드 추가
    _loadContracts();
    
    // 자유적립 금액 입력 리스너
    freeDepositController.addListener(() {
      final text = freeDepositController.text.replaceAll(',', '');
      final amount = int.tryParse(text);
      setState(() {
        freeDepositAmount = amount;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    freeDepositController.dispose();
    super.dispose();
  }

  // 회원권 유형 동적 로드 - v2_contracts 테이블에서 contract_type 조회
  Future<void> _loadMembershipTypes() async {
    try {
      setState(() {
        isLoadingMembershipTypes = true;
      });

      print('회원권 유형 로드 시작 - v2_contracts 테이블에서 contract_type 조회');

      // v2_contracts 테이블에서 회원권 카테고리의 유효한 계약 조회
      final data = await ApiService.getContractsData(
        where: [
          {'field': 'contract_category', 'operator': '=', 'value': '회원권'},
          {'field': 'contract_status', 'operator': '=', 'value': '유효'},
        ],
      );

      print('조회된 계약 수: ${data.length}개');

      // contract_type 추출 및 중복 제거
      final Set<String> typeSet = {};
      for (var contract in data) {
        final contractType = contract['contract_type']?.toString().trim();
        if (contractType != null && contractType.isNotEmpty) {
          typeSet.add(contractType);
        }
      }

      // 정렬
      final types = typeSet.toList()..sort();
      print('추출된 회원권 유형 (중복 제거 후): $types');

      setState(() {
        membershipTypes = types;
      });
    } catch (e) {
      print('회원권 유형 로드 오류: $e');
      print('오류 타입: ${e.runtimeType}');
      print('오류 스택트레이스: ${StackTrace.current}');

      // 오류 발생 시 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원권 유형을 불러오는데 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoadingMembershipTypes = false;
      });
    }
  }

  // API에서 계약 데이터 로드 - ApiService 사용으로 변경
  Future<void> _loadContracts() async {
    setState(() {
      isLoadingContracts = true;
    });

    try {
      final data = await ApiService.getContractsData(
        where: [
          {
            'field': 'contract_category',
            'operator': '=',
            'value': '회원권'
          },
          {
            'field': 'contract_status',
            'operator': '=',
            'value': '유효'
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId()
          },
        ],
        orderBy: [
          {
            'field': 'contract_type',
            'direction': 'ASC'
          },
          {
            'field': 'contract_id',
            'direction': 'ASC'
          }
        ]
      );

      setState(() {
        contracts = data;
      });
    } catch (e) {
      print('계약 데이터 로드 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계약 데이터를 불러오는데 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoadingContracts = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredContracts {
    if (selectedMembershipType == null) return [];
    return contracts
        .where((contract) => 
            contract['contract_type'] == selectedMembershipType &&
            contract['contract_name'] != '자유적립') // 자유적립 이름의 계약 제외
        .toList();
  }

  Map<String, dynamic>? get selectedContractData {
    if (selectedContract == null) return null;
    
    // 자유적립인 경우
    if (selectedContract == 'free_deposit') {
      return {
        'contract_name': '자유적립',
        'contract_credit': freeDepositAmount ?? 0,
        'contract_LS_min': 0, // contract_LS → contract_LS_min으로 변경
        'price': freeDepositAmount ?? 0,
      };
    }
    
    // 기존 계약인 경우
    return contracts.firstWhere((contract) => contract['contract_id'] == selectedContract);
  }

  // 안전한 정수 변환 헬퍼 함수
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    try {
      if (value == null) {
        return defaultValue;
      }
      
      if (value is int) {
        return value;
      }
      
      if (value is double) {
        return value.toInt();
      }
      
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        } else {
          return defaultValue;
        }
      }
      
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  // 크레딧 결제 가능 여부 확인
  bool _canPayWithCredit(Map<String, dynamic> contract) {
    final sellByCreditPrice = _safeParseInt(contract['sell_by_credit_price']);
    return sellByCreditPrice > 0;
  }

  // 크레딧 결제 경고 표시
  void _showCreditPaymentWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('크레딧 결제가 불가능한 상품입니다.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 가격 포맷팅
  String _formatPrice(dynamic price) {
    if (price == null) {
      return '0원';
    }
    try {
      final priceInt = _safeParseInt(price);
      final formatter = NumberFormat('#,###');
      final result = '${formatter.format(priceInt)}원';
      return result;
    } catch (e) {
      return '0원';
    }
  }

  // 유효기간 만료일 계산 함수
  String? _calcExpiryDate(DateTime base, dynamic month) {
    final m = _safeParseInt(month);
    if (m < 0) return null; // 음수면 null
    if (m == 0) {
      // 0개월이면 계약일과 동일한 날짜 (즉시 종료)
      return DateFormat('yyyy-MM-dd').format(base);
    }
    // m개월 후의 전날로 계산 (예: 6월 10일 + 1개월 = 7월 9일)
    final expiry = DateTime(base.year, base.month + m, base.day).subtract(Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(expiry);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 헤더
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '회원권 등록',
                            style: AppTextStyles.modalTitle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '회원 ID: ${widget.memberId}',
                              style: AppTextStyles.cardMeta.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    // 메인 컨텐츠
                    Expanded(
                      child: Row(
                        children: [
                          // 왼쪽 영역 - 회원권 유형 및 계약 선택
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 회원권 유형
                                  Text(
                                    '회원권 유형 *',
                                    style: AppTextStyles.cardSubtitle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  isLoadingMembershipTypes
                                    ? Container(
                                        height: 40,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF3B82F6),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: membershipTypes.map((type) {
                                          final isSelected = selectedMembershipType == type;
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                selectedMembershipType = type;
                                                selectedContract = null;
                                              });
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isSelected ? Color(0xFF3B82F6) : Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              child: Text(
                                                type,
                                                style: AppTextStyles.cardSubtitle.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected ? Colors.white : Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  
                                  SizedBox(height: 24),
                                  
                                  // 계약 선택
                                  Text(
                                    '계약 선택 *',
                                    style: AppTextStyles.cardSubtitle.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  
                                  // 계약 리스트
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(child: _buildContractList()),
                                        
                                        // 자유적립 선택 시 금액 입력창
                                        if (selectedContract == 'free_deposit') ...[
                                          SizedBox(height: 16),
                                          Container(
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFF0F9FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Color(0xFF0369A1).withOpacity(0.3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '적립 금액 입력',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0369A1),
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                TextField(
                                                  controller: freeDepositController,
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(
                                                    color: Color(0xFF1F2937),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: '금액을 입력하세요',
                                                    hintStyle: TextStyle(
                                                      color: Color(0xFF9CA3AF),
                                                      fontSize: 13,
                                                    ),
                                                    suffixText: '원',
                                                    suffixStyle: TextStyle(
                                                      color: Color(0xFF374151),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: Color(0xFF0369A1), width: 2),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                  ),
                                                  onChanged: (value) {
                                                    // 숫자만 입력되도록 포맷팅
                                                    String formatted = value.replaceAll(RegExp(r'[^0-9]'), '');
                                                    if (formatted.isNotEmpty) {
                                                      final number = int.parse(formatted);
                                                      final formatter = NumberFormat('#,###');
                                                      freeDepositController.value = TextEditingValue(
                                                        text: formatter.format(number),
                                                        selection: TextSelection.collapsed(offset: formatter.format(number).length),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // 구분선
                          Container(
                            width: 1,
                            color: Color(0xFFE2E8F0),
                          ),
                          
                          // 오른쪽 영역 - 선택된 계약 정보 및 결제 방식
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildContractInfo(),
                                  SizedBox(height: 24),
                                  _buildPaymentMethods(),
                                  SizedBox(height: 24),
                                  _buildDatePicker(),
                                  SizedBox(height: 16),
                                  _buildSelectedProInfo(),
                                  if (_shouldShowTermDatePicker()) ...[
                                    SizedBox(height: 16),
                                    _buildTermDatePicker(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 하단 버튼
                    _buildBottomButtons(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContractList() {
    if (selectedMembershipType == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            '회원권 유형을 먼저 선택해주세요',
            style: AppTextStyles.bodyTextSmall.copyWith(
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    if (isLoadingContracts) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B82F6),
          ),
        ),
      );
    }

    if (filteredContracts.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '해당 유형의 계약이 없습니다',
            style: AppTextStyles.bodyTextSmall.copyWith(
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(8),
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(), // 스크롤 비활성화
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2열
          crossAxisSpacing: 8,
          mainAxisSpacing: 6,
          childAspectRatio: 3.1, // 2.8에서 3.1로 변경하여 타일 높이를 10% 줄임
        ),
        itemCount: (filteredContracts.length > 15 ? 15 : filteredContracts.length) + (_shouldShowFreeDeposit() ? 1 : 0), // 동적으로 자유적립 표시 여부 결정
        itemBuilder: (context, index) {
          // 자유적립 타일 (크레딧 관련 유형일 때만 첫 번째 위치)
          if (index == 0 && _shouldShowFreeDeposit()) {
            final isSelected = selectedContract == 'free_deposit';
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedContract = 'free_deposit';
                  freeDepositController.clear();
                  freeDepositAmount = null;
                  // 자유적립은 레슨권이 없으므로 프로 선택 초기화
                  selectedProId = null;
                  // 자유적립은 기간권이 없으므로 기간권 날짜 초기화
                  termStartDate = null;
                  termEndDate = null;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFFF0F9FF) : Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Color(0xFF0369A1) : Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Color(0xFF0369A1).withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // 왼쪽 - 계약 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '자유적립',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Color(0xFF0369A1) : Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3),
                            Text(
                              '크레딧 ${freeDepositAmount != null ? NumberFormat('#,###').format(freeDepositAmount!) : '0'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Color(0xFF0369A1) : Color(0xFF374151),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 오른쪽 - 가격과 선택 표시
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Color(0xFF0369A1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? Color(0xFF0369A1).withOpacity(0.1) 
                                : Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              freeDepositAmount != null ? '${NumberFormat('#,###').format(freeDepositAmount!)}원' : '0원',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Color(0xFF0369A1) : Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          // 기존 계약 타일들 (인덱스 조정)
          final contractIndex = _shouldShowFreeDeposit() ? index - 1 : index;
          if (contractIndex >= filteredContracts.length || contractIndex < 0) return Container();
          
          final contract = filteredContracts[contractIndex];
          final isSelected = selectedContract == contract['contract_id'];
          
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedContract = contract['contract_id'];
                // 레슨권이 없는 상품을 선택하면 프로 선택 초기화
                final contractLS = contract['contract_LS_min'] ?? 0;
                if (contractLS <= 0) {
                  selectedProId = null;
                }
                // 레슨권이 있는 계약을 선택하면 프로 선택 다이얼로그 표시
                else {
                  _showProSelectionDialog(contract);
                }
                
                // 기간권이 포함된 상품을 선택하면 시작일자 설정
                final contractTermMonth = contract['contract_term_month'] ?? 0;
                if (contractTermMonth > 0) {
                  termStartDate = DateTime.now();
                  // 종료일 계산: 시작일 + 개월수 - 1일
                  termEndDate = DateTime(
                    termStartDate!.year,
                    termStartDate!.month + _safeParseInt(contractTermMonth),
                    termStartDate!.day,
                  ).subtract(Duration(days: 1));
                } else {
                  termStartDate = null;
                  termEndDate = null;
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFF0F9FF) : Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Color(0xFF0369A1) : Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Color(0xFF0369A1).withOpacity(0.2),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // 왼쪽 - 계약 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            contract['contract_name'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Color(0xFF0369A1) : Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Row(
                            children: [
                              if ((contract['contract_credit'] ?? 0) > 0) ...[
                                Text(
                                  '크레딧 ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Color(0xFF0369A1) : Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${NumberFormat('#,###').format(contract['contract_credit'])}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Color(0xFF0369A1) : Color(0xFF374151),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                              if ((contract['contract_LS_min'] ?? 0) > 0) ...[
                                Text(
                                  '레슨시간 ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Color(0xFF0369A1) : Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${NumberFormat('#,###').format(contract['contract_LS_min'])}분',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Color(0xFF0369A1) : Color(0xFF374151),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 오른쪽 - 가격과 선택 표시
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isSelected)
                          Container(
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Color(0xFF0369A1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                              ? Color(0xFF0369A1).withOpacity(0.1) 
                              : Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatPrice(contract['price']),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Color(0xFF0369A1) : Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContractInfo() {
    final contract = selectedContractData;
    final f = NumberFormat('#,###');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '계약 정보',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: contract == null
              ? Container(
                  height: 120,
                  child: Center(
                    child: Text(
                      '계약을 선택해주세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: 상품명 + 칩
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contract['contract_name'] ?? '',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                if ((contract['contract_credit'] ?? 0) > 0)
                                  _buildServiceChip(
                                    icon: Icons.monetization_on,
                                    iconColor: Colors.amber,
                                    label: '크레딧 ${f.format(contract['contract_credit'])}원',
                                    effectMonth: contract['contract_credit_effect_month'],
                                  ),
                                if ((contract['contract_LS_min'] ?? 0) > 0)
                                  _buildServiceChip(
                                    icon: Icons.school,
                                    iconColor: Colors.blueAccent,
                                    label: '레슨권 ${f.format(contract['contract_LS_min'])}분',
                                    effectMonth: contract['contract_LS_min_effect_month'],
                                  ),
                                if ((contract['contract_TS_min'] ?? 0) > 0)
                                  _buildServiceChip(
                                    icon: Icons.sports_golf,
                                    iconColor: Colors.green,
                                    label: '타석시간 ${f.format(contract['contract_TS_min'])}분',
                                    effectMonth: contract['contract_TS_min_effect_month'],
                                  ),
                                if ((contract['contract_games'] ?? 0) > 0)
                                  _buildServiceChip(
                                    icon: Icons.sports_esports,
                                    iconColor: Colors.purple,
                                    label: '스크린게임 ${f.format(contract['contract_games'])}회',
                                    effectMonth: contract['contract_games_effect_month'],
                                  ),
                                if ((contract['contract_term_month'] ?? 0) > 0)
                                  _buildServiceChip(
                                    icon: Icons.calendar_month,
                                    iconColor: Colors.teal,
                                    label: '기간권 ${f.format(contract['contract_term_month'])}',
                                    effectMonth: contract['contract_term_month_effect_month'],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 오른쪽: 가격
                      if ((contract['price'] ?? 0) > 0)
                        Container(
                          margin: EdgeInsets.only(left: 12),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFFFFEDD5)),
                          ),
                          child: Text(
                            '가격 ${f.format(contract['price'])}원',
                            style: TextStyle(
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '결제 방식 *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 12),
        
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 4.2, // 2.8에서 4.2로 변경하여 높이를 2/3로 줄임
          ),
          itemCount: paymentTypes.length,
          itemBuilder: (context, index) {
            final payment = paymentTypes[index];
            final isSelected = selectedPaymentType == payment['value'];
            final isCreditPayment = payment['value'] == '크레딧결제';
            final canPayWithCredit = selectedContractData != null ? _canPayWithCredit(selectedContractData!) : true;
            final isDisabled = isCreditPayment && !canPayWithCredit;
            
            return GestureDetector(
              onTap: () {
                if (isDisabled) {
                  _showCreditPaymentWarning();
                  return;
                }
                setState(() {
                  selectedPaymentType = payment['value'];
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), // 패딩 줄임
                decoration: BoxDecoration(
                  color: isDisabled 
                    ? Color(0xFFF3F4F6)
                    : isSelected 
                      ? Color(0xFF3B82F6).withOpacity(0.1) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDisabled
                      ? Color(0xFFD1D5DB)
                      : isSelected 
                        ? Color(0xFF3B82F6) 
                        : Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      payment['icon'],
                      size: 16, // 아이콘 크기 줄임
                      color: isDisabled
                        ? Color(0xFF9CA3AF)
                        : isSelected 
                          ? Color(0xFF3B82F6) 
                          : Color(0xFF6B7280),
                    ),
                    SizedBox(width: 6), // 간격 줄임
                    Expanded(
                      child: Text(
                        payment['value'],
                        style: TextStyle(
                          fontSize: 13, // 폰트 크기 키우고 볼드 처리
                          fontWeight: FontWeight.w700,
                          color: isDisabled
                            ? Color(0xFF9CA3AF)
                            : isSelected 
                              ? Color(0xFF3B82F6) 
                              : Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    if (isDisabled)
                      Icon(
                        Icons.block,
                        size: 14, // 아이콘 크기 줄임
                        color: Color(0xFF9CA3AF),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: [
        Container(
          width: 80, // 고정 너비로 라벨 영역 통일
          child: Text(
            '등록일자 *',
            style: AppTextStyles.bodyTextSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              height: 48, // 고정 높이 설정
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  SizedBox(width: 12),
                  Text(
                    DateFormat('yyyy. MM. dd.').format(selectedDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedProInfo() {
    if (selectedProId == null) return Container();

    // availablePros에서 선택된 프로 정보 찾기
    final selectedPro = availablePros.firstWhere(
      (pro) => _safeToString(pro['pro_id']) == selectedProId,
      orElse: () => {},
    );

    if (selectedPro.isNotEmpty) {
      return Row(
        children: [
          Container(
            width: 80, // 고정 너비로 라벨 영역 통일
            child: Text(
              '담당프로',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 48, // 고정 높이 설정 (등록일자와 동일)
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF0369A1).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedPro['pro_name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Container();
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _canSave() ? () async {
                print('=== 계약 저장 시작 ===');
                try {
                  final contractData = selectedContractData;
                  if (contractData == null) {
                    print('ERROR: 계약 정보를 찾을 수 없습니다');
                    throw Exception('계약 정보를 찾을 수 없습니다');
                  }
                  String memberName = '';
                  if (widget.memberData != null) {
                    memberName = _safeToString(widget.memberData!['member_name']);
                  }
                  final branchId = ApiService.getCurrentBranchId();
                  final contractDate = DateFormat('yyyy-MM-dd').format(selectedDate);

                  // 디버깅: selectedMembershipType 값 확인
                  print('selectedMembershipType 값: $selectedMembershipType');
                  print('contractData: $contractData');

                  // 디버깅: expiry_date 계산 확인
                  print('=== Expiry Date 계산 디버깅 ===');
                  print('contract_credit_effect_month: ${contractData['contract_credit_effect_month']}');
                  print('contract_LS_min_effect_month: ${contractData['contract_LS_min_effect_month']}');
                  print('contract_games_effect_month: ${contractData['contract_games_effect_month']}');
                  print('contract_TS_min_effect_month: ${contractData['contract_TS_min_effect_month']}');
                  print('contract_term_month_effect_month: ${contractData['contract_term_month_effect_month']}');
                  print('effect_month (기본): ${contractData['effect_month']}');

                  // bill_id, pro_id, pro_name는 기존 로직에서 할당
                  int? billId;
                  int? proId;
                  String? proName;
                  // billId, proId, proName는 아래 결제/프로 처리 후 할당됨

                  // 기간권 종료일 계산 (termStartDate 기반)
                  String? calculatedTermExpiryDate = null;
                  if ((contractData['contract_term_month'] ?? 0) > 0) {
                    final termStart = termStartDate ?? selectedDate;
                    final termEnd = termEndDate ?? DateTime(
                      termStart.year,
                      termStart.month + _safeParseInt(contractData['contract_term_month']),
                      termStart.day,
                    ).subtract(Duration(days: 1));
                    calculatedTermExpiryDate = DateFormat('yyyy-MM-dd').format(termEnd);
                  }

                  // 저장할 데이터 구성 (새로운 구조)
                  final saveData = {
                    'branch_id': branchId,
                    // contract_history_id는 AI/DB에서 자동 생성
                    'member_id': widget.memberId,
                    'member_name': memberName,
                    'contract_id': contractData['contract_id'] ?? (selectedContract == 'free_deposit' ? 'c01' : selectedContract),
                    'contract_name': contractData['contract_name'],
                    'contract_type': selectedMembershipType,      // 회원권 유형 추가
                    'contract_date': contractDate,
                    'contract_register': DateTime.now().toIso8601String(),
                    'payment_type': selectedPaymentType,
                    'contract_history_status': '활성',
                    'price': contractData['price'] ?? 0,
                    'contract_credit': contractData['contract_credit'] ?? 0,
                    'contract_LS_min': contractData['contract_LS_min'] ?? 0,
                    'contract_games': contractData['contract_games'] ?? 0,
                    'contract_TS_min': contractData['contract_TS_min'] ?? 0,
                    'contract_term_month': contractData['contract_term_month'] ?? 0,
                    'contract_credit_expiry_date': (contractData['contract_credit'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_credit_effect_month'] ?? contractData['effect_month']) : null,
                    'contract_LS_min_expiry_date': (contractData['contract_LS_min'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_LS_min_effect_month'] ?? contractData['effect_month']) : null,
                    'contract_games_expiry_date': (contractData['contract_games'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_games_effect_month'] ?? contractData['effect_month']) : null,
                    'contract_TS_min_expiry_date': (contractData['contract_TS_min'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_TS_min_effect_month'] ?? contractData['effect_month']) : null,
                    'contract_term_month_expiry_date': calculatedTermExpiryDate,  // 기간권 시작일 기반으로 계산된 종료일 사용
                    'bill_id': null, // 결제 후 할당
                    'pro_id': null,  // 프로 처리 후 할당
                    'pro_name': null,
                  };
                  
                  // 디버깅: saveData 확인
                  print('saveData에 포함된 contract_type: ${saveData['contract_type']}');
                  print('=== 계산된 Expiry Dates ===');
                  print('contract_credit_expiry_date: ${saveData['contract_credit_expiry_date']}');
                  print('contract_LS_min_expiry_date: ${saveData['contract_LS_min_expiry_date']}');
                  print('contract_games_expiry_date: ${saveData['contract_games_expiry_date']}');
                  print('contract_TS_min_expiry_date: ${saveData['contract_TS_min_expiry_date']}');
                  print('contract_term_month_expiry_date: ${saveData['contract_term_month_expiry_date']}');
                  print('saveData 전체: $saveData');

                  // v3_contract_history 테이블에 저장
                  print('v3_contract_history 테이블에 저장 시작...');
                  final response = await ApiService.addContractHistoryData(saveData);
                  print('v3_contract_history 저장 응답: $response');
                  
                  if (response['success'] == true) {
                    print('계약 히스토리 저장 성공');
                    // 계약 등록 성공 후 bill_id 생성 및 업데이트
                    final contractHistoryId = response['insertId']; // 방금 생성된 contract_history_id
                    print('생성된 contract_history_id: $contractHistoryId');
                    
                    // v2_bills 테이블 업데이트
                    // 크레딧 결제인 경우 잔액 확인
                    if (selectedPaymentType == '크레딧결제') {
                      print('크레딧 결제 처리 시작...');
                      // 결제 금액 확인 (크레딧 결제 가격 또는 일반 가격)
                      final sellByCreditPrice = contractData['sell_by_credit_price'];
                      final regularPrice = contractData['price'];
                      int paymentAmount;

                      if (sellByCreditPrice != null) {
                        paymentAmount = _safeParseInt(sellByCreditPrice);
                      } else if (regularPrice != null) {
                        paymentAmount = _safeParseInt(regularPrice);
                      } else {
                        paymentAmount = 0;
                      }
                      print('결제 금액: $paymentAmount');
                      
                      // 크레딧 결제인 경우 먼저 차감 처리
                      final deductionAmount = _safeParseInt(contractData['price']);
                      print('크레딧 차감 처리 시작 - 차감액: $deductionAmount');
                      
                      final deductionBillData = {
                        'member_id': widget.memberId,
                        'branch_id': ApiService.getCurrentBranchId(),
                        'bill_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'bill_type': '회원권구매',
                        'bill_text': contractData['contract_name'],
                        'bill_totalamt': -deductionAmount,
                        'bill_deduction': 0,
                        'bill_netamt': -deductionAmount,
                        'bill_timestamp': DateTime.now().toIso8601String(),
                        'bill_balance_before': 0,
                        'bill_balance_after': -deductionAmount,
                        'bill_status': '결제완료',
                        'contract_history_id': contractHistoryId,
                        'contract_credit_expiry_date': (contractData['contract_credit'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_credit_effect_month'] ?? contractData['effect_month']) : null,
                      };
                      print('크레딧 차감 데이터: $deductionBillData');
                      
                      final deductionResponse = await ApiService.addBillsData(deductionBillData);
                      print('크레딧 차감 응답: $deductionResponse');
                    }
                    
                    // 크레딧 적립 처리 (actual_credit이 0보다 큰 경우만)
                    int? billIdForContract; // 계약에 연결할 bill_id
                    final creditAmount = _safeParseInt(contractData['contract_credit']);
                    print('크레딧 적립 처리 시작 - 적립액: $creditAmount');
                    
                    if (creditAmount > 0) {
                      final creditBillData = {
                        'member_id': widget.memberId,
                        'branch_id': ApiService.getCurrentBranchId(),
                        'bill_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'bill_type': '회원권적립',
                        'bill_text': contractData['contract_name'],
                        'bill_totalamt': contractData['contract_credit'],
                        'bill_deduction': 0,
                        'bill_netamt': contractData['contract_credit'],
                        'bill_timestamp': DateTime.now().toIso8601String(),
                        'bill_balance_before': 0,
                        'bill_balance_after': contractData['contract_credit'],
                        'bill_status': '결제완료',
                        'contract_history_id': contractHistoryId,
                        'contract_credit_expiry_date': (contractData['contract_credit'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_credit_effect_month'] ?? contractData['effect_month']) : null,
                      };
                      print('크레딧 적립 데이터: $creditBillData');
                      
                      final creditBillResponse = await ApiService.addBillsData(creditBillData);
                      print('크레딧 적립 응답: $creditBillResponse');
                      
                      // 생성된 bill_id 저장
                      if (creditBillResponse['success'] == true) {
                        billIdForContract = _safeParseInt(creditBillResponse['insertId']);
                        print('생성된 bill_id: $billIdForContract');
                      }
                    }
                    
                    // 4. 계약 테이블의 bill_id 필드 업데이트 (적립 bill이 있으면 그것을, 없으면 null)
                    if (billIdForContract != null) {
                      print('계약 히스토리 bill_id 업데이트 시작...');
                      final updateResponse = await ApiService.updateContractHistoryData(
                        {'bill_id': billIdForContract},
                        [
                          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId}
                        ],
                      );
                      print('bill_id 업데이트 응답: $updateResponse');
                    }
                    
                    // 5. v3_LS_countings 테이블 업데이트 (contract_LS_min > 0인 경우에만)
                    final contractLS = contractData['contract_LS_min'] ?? 0;
                    print('레슨권 처리 시작 - 레슨 시간: $contractLS분');

                    if (contractLS > 0) {
                      // 계약 종료일 계산 (effect_month가 있으면 사용, 없으면 12개월)
                      final effectMonth = _safeParseInt(contractData['contract_LS_min_effect_month'] ?? contractData['effect_month'], defaultValue: 12);

                      final contractEndDate = DateTime(
                        selectedDate.year,
                        selectedDate.month + effectMonth,
                        selectedDate.day,
                      );
                      print('계약 종료일: ${DateFormat('yyyy-MM-dd').format(contractEndDate)}');

                      // 회원 유형 가져오기
                      String memberType = '';
                      if (widget.memberData != null) {
                        memberType = _safeToString(widget.memberData!['member_type']);
                      }

                      // === 프로 정보 추출 ===
                      int? proIdToSave;
                      String? proNameToSave;
                      print('프로 정보 추출 시작 - selectedProId: $selectedProId');
                      if (selectedProId != null) {
                        // availablePros에서 선택된 프로 정보 찾기
                        final selectedPro = availablePros.firstWhere(
                          (pro) => _safeToString(pro['pro_id']) == selectedProId,
                          orElse: () => {},
                        );
                        print('찾은 프로 정보: $selectedPro');
                        if (selectedPro.isNotEmpty && selectedPro['pro_name'] != null) {
                          proIdToSave = _safeParseInt(selectedProId);
                          proNameToSave = selectedPro['pro_name'];
                          print('프로 정보 설정 완료 - proIdToSave: $proIdToSave, proNameToSave: $proNameToSave');
                        } else {
                          print('프로 정보를 찾을 수 없음 또는 pro_name이 null');
                        }
                      } else {
                        print('selectedProId가 null - 프로를 선택하지 않음');
                      }
                      // === // ===

                      // v3_LS_countings 테이블에 바로 추가 (v2_LS_contracts 제외)
                      final branchId = ApiService.getCurrentBranchId();
                      final lsNetMin = contractLS;

                      final lsCountingData = {
                        'LS_transaction_type': '레슨권 구매',
                        'LS_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'member_id': widget.memberId,
                        'member_name': memberName,
                        'member_type': memberType,
                        'LS_status': '결제완료',
                        'LS_type': '일반',
                        'LS_contract_id': null, // v2_LS_contracts를 사용하지 않으므로 null
                        'contract_history_id': contractHistoryId,
                        'LS_id': null,
                        'LS_balance_min_before': 0,
                        'LS_net_min': lsNetMin,
                        'LS_balance_min_after': lsNetMin,
                        'LS_counting_source': 'v3_contract_history',
                        'LS_expiry_date': DateFormat('yyyy-MM-dd').format(contractEndDate),
                        'pro_id': proIdToSave,
                        'pro_name': proNameToSave,
                        'branch_id': branchId,
                      };
                      print('LS 카운팅 데이터: $lsCountingData');

                      final lsCountingResponse = await ApiService.addLSCountingData(lsCountingData);
                      print('LS 카운팅 응답: $lsCountingResponse');
                    }
                    
                    // 6. v2_bill_times 테이블 업데이트 (contract_TS_min > 0인 경우에만)
                    final contractTS = contractData['contract_TS_min'] ?? 0;
                    print('타석시간 처리 시작 - 타석 시간: $contractTS분');
                    
                    if (contractTS > 0) {
                      // 타석시간 만료일 계산
                      final contractTSExpiryDate = (contractData['contract_TS_min'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_TS_min_effect_month'] ?? contractData['effect_month']) : null;
                      
                      final billTimesData = {
                        'member_id': widget.memberId,
                        'bill_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'bill_type': '회원권등록',
                        'bill_text': contractData['contract_name'],
                        'bill_min': contractTS,
                        'bill_timestamp': DateTime.now().toIso8601String(),
                        'bill_balance_min_before': 0,
                        'bill_balance_min_after': contractTS,
                        'reservation_id': null,
                        'bill_status': '결제완료',
                        'contract_history_id': contractHistoryId,
                        'routine_id': null,
                        'branch_id': ApiService.getCurrentBranchId(),
                        'contract_TS_min_expiry_date': contractTSExpiryDate,
                      };
                      print('타석시간 적립 데이터: $billTimesData');
                      
                      final billTimesResponse = await ApiService.addBillTimesData(billTimesData);
                      print('타석시간 적립 응답: $billTimesResponse');
                    }
                    
                    // 7. v2_bill_games 테이블 업데이트 (contract_games > 0인 경우에만)
                    final contractGames = contractData['contract_games'] ?? 0;
                    print('스크린게임 처리 시작 - 게임 횟수: $contractGames회');
                    
                    if (contractGames > 0) {
                      // 스크린게임 만료일 계산
                      final contractGamesExpiryDate = (contractData['contract_games'] ?? 0) > 0 ? _calcExpiryDate(selectedDate, contractData['contract_games_effect_month'] ?? contractData['effect_month']) : null;
                      
                      final billGamesData = {
                        'member_id': widget.memberId,
                        'bill_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'bill_type': '회원권등록',
                        'bill_text': contractData['contract_name'],
                        'bill_games': contractGames,
                        'bill_timestamp': DateTime.now().toIso8601String(),
                        'bill_balance_game_before': 0,
                        'bill_balance_game_after': contractGames,
                        'reservation_id': null,
                        'bill_status': '결제완료',
                        'contract_history_id': contractHistoryId,
                        'routine_id': null,
                        'branch_id': ApiService.getCurrentBranchId(),
                        'group_play_id': null,
                        'group_members_numbers': null,
                        'member_name': memberName,
                        'non_member_name': null,
                        'non_member_phone': null,
                      };
                      print('스크린게임 적립 데이터: $billGamesData');
                      
                      final billGamesResponse = await ApiService.addBillGamesData(billGamesData);
                      print('스크린게임 적립 응답: $billGamesResponse');
                    }
                    
                    // 8. v2_bill_term 테이블 업데이트 (contract_term_month > 0인 경우에만)
                    final contractTermMonth = contractData['contract_term_month'] ?? 0;
                    print('기간권 처리 시작 - 기간: $contractTermMonth개월');
                    
                    if (contractTermMonth > 0) {
                      // 기간권 시작일과 종료일 사용
                      final termStart = termStartDate ?? selectedDate;
                      final termEnd = termEndDate ?? DateTime(
                        termStart.year,
                        termStart.month + _safeParseInt(contractTermMonth),
                        termStart.day,
                      ).subtract(Duration(days: 1));
                      
                      final billTermData = {
                        'member_id': widget.memberId,
                        'bill_date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'bill_type': '회원권등록',
                        'bill_text': contractData['contract_name'],
                        'bill_term_min': null,  // null로 설정
                        'bill_timestamp': DateTime.now().toIso8601String(),
                        'reservation_id': null,  // null로 설정
                        'bill_status': '결제완료',
                        'contract_history_id': contractHistoryId,
                        'contract_term_month_expiry_date': DateFormat('yyyy-MM-dd').format(termEnd),
                        'term_startdate': DateFormat('yyyy-MM-dd').format(termStart),
                        'term_enddate': DateFormat('yyyy-MM-dd').format(termEnd),
                        'branch_id': ApiService.getCurrentBranchId(),
                      };
                      print('기간권 등록 데이터: $billTermData');
                      
                      final billTermResponse = await ApiService.addBillTermData(billTermData);
                      print('기간권 등록 응답: $billTermResponse');
                    }
                    
                    print('=== 계약 저장 완료 ===');
                    // 성공 메시지 표시 후 다이얼로그 닫기
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('회원권이 등록되었습니다'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  } else {
                    print('ERROR: 계약 히스토리 저장 실패 - ${response['error']}');
                    throw Exception(response['error'] ?? '등록에 실패했습니다');
                  }
                } catch (e) {
                  print('ERROR: 계약 저장 중 오류 발생 - $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('등록 중 오류가 발생했습니다: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                '저장',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2E8F0),
                foregroundColor: Color(0xFF64748B),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  bool _canSave() {
    if (selectedMembershipType == null || 
        selectedContract == null || 
        selectedPaymentType == null) {
      return false;
    }
    
    // 자유적립 선택 시 금액이 입력되었는지 확인
    if (selectedContract == 'free_deposit' && (freeDepositAmount == null || freeDepositAmount! <= 0)) {
      return false;
    }
    
    // 크레딧 결제 선택 시 추가 검증
    if (selectedPaymentType == '크레딧결제' && selectedContractData != null) {
      return _canPayWithCredit(selectedContractData!);
    }
    
    return true;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }


  // 사용 가능한 프로 목록 조회
  Future<void> _loadAvailablePros() async {
    try {
      // 1. 프로 목록 조회
      final data = await ApiService.getStaffProData(
        fields: [
          'pro_id',
          'pro_name',
          'staff_status',
          'pro_contract_round',
          'min_service_min',        // 최소레슨시간
          'svc_time_unit',          // 레슨시간 단위
          'min_reservation_term',   // 최소예약조건
          // 필요시 추가 필드
        ],
        where: [
          {'field': 'staff_status', 'operator': '=', 'value': '재직'}
          // branch_id는 ApiService에서 자동 필터링
        ],
        orderBy: [
          {'field': 'pro_id', 'direction': 'ASC'},
          {'field': 'pro_contract_round', 'direction': 'DESC'},
        ],
      );

      // pro_id별로 pro_contract_round가 가장 큰(최신) 레코드만 남기기
      final Map<dynamic, Map<String, dynamic>> uniquePros = {};
      for (final pro in data) {
        final proId = pro['pro_id'];
        if (!uniquePros.containsKey(proId)) {
          uniquePros[proId] = pro;
        }
      }

      // 2. 구매횟수 데이터 조회
      Map<String, int> purchaseCounts = {};
      try {
        final purchaseData = await ApiService.getMemberProPurchaseCount(
          memberId: widget.memberId,
        );
        
        if (purchaseData['success'] == true && purchaseData['data'] != null) {
          for (final item in purchaseData['data']) {
            purchaseCounts[item['pro_id'].toString()] = item['purchase_count'];
          }
        }
      } catch (e) {
        print('구매횟수 조회 오류: $e');
      }

      // 3. 프로 데이터에 구매횟수 추가 및 정렬
      final prosWithCounts = uniquePros.values.map((pro) {
        final proId = pro['pro_id'].toString();
        return {
          ...pro,
          'purchase_count': purchaseCounts[proId] ?? 0,
        };
      }).toList();

      // 구매횟수 내림차순, 그 다음 프로 이름 오름차순 정렬
      prosWithCounts.sort((a, b) {
        final countA = a['purchase_count'] as int;
        final countB = b['purchase_count'] as int;
        if (countA != countB) {
          return countB.compareTo(countA); // 구매횟수 내림차순
        }
        return (a['pro_name'] ?? '').toString().compareTo((b['pro_name'] ?? '').toString()); // 이름 오름차순
      });

      setState(() {
        availablePros = prosWithCounts;
      });
    } catch (e) {
      print('프로 목록 로드 오류: $e');
    }
  }

  // 프로 선택 다이얼로그 표시
  Future<void> _showProSelectionDialog(Map<String, dynamic> contract) async {
    await _loadAvailablePros();
    
    // 모든 재직중인 프로를 표시
    List<Map<String, dynamic>> filteredPros = availablePros;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            '담당프로 선택',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * (2/3), // 기존 double.maxFinite에서 2/3로 변경
            height: 400,
            child: Column(
              children: [
                Text(
                  '담당프로를 선택하세요:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredPros.length,
                    itemBuilder: (context, index) {
                      final pro = filteredPros[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedProId = _safeToString(pro['pro_id']);
                            });
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 프로 이름 (하이라이트)
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF3B82F6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'PRO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        pro['pro_name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                    // 구매횟수 배지
                                    if (pro['purchase_count'] != null && pro['purchase_count'] > 0)
                                      Container(
                                        margin: EdgeInsets.only(right: 8),
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${pro['purchase_count']}회',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    if (_safeToString(pro['staff_nickname']).isNotEmpty)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          pro['staff_nickname'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // 프로 정보
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildProInfoItem(
                                        '최소레슨시간',
                                        '${pro['min_service_min'] ?? 0}분',
                                        Icons.schedule,
                                        Color(0xFF10B981),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Color(0xFFE5E7EB),
                                      margin: EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    Expanded(
                                      child: _buildProInfoItem(
                                        '레슨시간단위',
                                        '${pro['svc_time_unit'] ?? 0}분',
                                        Icons.timer,
                                        Color(0xFF8B5CF6),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Color(0xFFE5E7EB),
                                      margin: EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    Expanded(
                                      child: _buildProInfoItem(
                                        '최소예약조건',
                                        _formatReservationTerm(pro['min_reservation_term'] ?? 0),
                                        Icons.event_available,
                                        Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  // 프로 정보 아이템 위젯
  Widget _buildProInfoItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16, // 기존 14 → 16
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // 기존 10 → 12
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }


  String _formatReservationTerm(int minutes) {
    if (minutes < 60) {
      return '$minutes분 전';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours시간 전';
      } else {
        return '$hours시간 ${remainingMinutes}분 전';
      }
    }
  }


  // 안전한 문자열 변환 헬퍼 함수
  String _safeToString(dynamic value, {String defaultValue = ''}) {
    try {
      if (value == null) {
        return defaultValue;
      }
      return value.toString();
    } catch (e) {
      print('_safeToString 오류: $e, value: $value');
      return defaultValue;
    }
  }

  bool _shouldShowFreeDeposit() {
    if (selectedMembershipType == null) return false;
    // 크레딧 관련 키워드가 포함된 회원권 유형에서 자유적립 표시
    final lowerType = selectedMembershipType!.toLowerCase();
    return lowerType.contains('크레딧') || lowerType.contains('선불');
  }

  // 기간권 날짜 선택기 표시 여부 확인
  bool _shouldShowTermDatePicker() {
    if (selectedContractData == null) return false;
    final contractTermMonth = selectedContractData!['contract_term_month'] ?? 0;
    return contractTermMonth > 0;
  }

  // 기간권 날짜 선택 위젯
  Widget _buildTermDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 80,
              child: Text(
                '기간권 시작일',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTermStartDate(context),
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 12),
                      Text(
                        termStartDate != null 
                          ? DateFormat('yyyy. MM. dd.').format(termStartDate!)
                          : '시작일 선택',
                        style: TextStyle(
                          fontSize: 14,
                          color: termStartDate != null ? Color(0xFF374151) : Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (termStartDate != null && termEndDate != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 20,
                  color: Color(0xFF10B981),
                ),
                SizedBox(width: 12),
                Text(
                  '기간: ${DateFormat('yyyy.MM.dd').format(termStartDate!)} ~ ${DateFormat('yyyy.MM.dd').format(termEndDate!)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 기간권 시작일 선택
  Future<void> _selectTermStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: termStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != termStartDate) {
      setState(() {
        termStartDate = picked;
        // 종료일 재계산
        if (selectedContractData != null) {
          final contractTermMonth = selectedContractData!['contract_term_month'] ?? 0;
          if (contractTermMonth > 0) {
            termEndDate = DateTime(
              termStartDate!.year,
              termStartDate!.month + _safeParseInt(contractTermMonth),
              termStartDate!.day,
            ).subtract(Duration(days: 1));
          }
        }
      });
    }
  }

  String buildContractSummary(Map<String, dynamic> contract) {
    List<String> parts = [];
    final f = NumberFormat('#,###');
    if ((contract['contract_credit'] ?? 0) > 0) {
      String s = '크레딧 ${f.format(contract['contract_credit'])}원';
      if ((contract['contract_credit_effect_month'] ?? 0) > 0) {
        s += ' (유효기간: ${contract['contract_credit_effect_month']}개월)';
      }
      parts.add(s);
    }
    if ((contract['contract_LS_min'] ?? 0) > 0) {
      String s = '레슨권 ${f.format(contract['contract_LS_min'])}분';
      if ((contract['contract_LS_min_effect_month'] ?? 0) > 0) {
        s += ' (유효기간: ${contract['contract_LS_min_effect_month']}개월)';
      }
      parts.add(s);
    }
    if ((contract['contract_TS_min'] ?? 0) > 0) {
      String s = '타석시간 ${f.format(contract['contract_TS_min'])}분';
      if ((contract['contract_TS_min_effect_month'] ?? 0) > 0) {
        s += ' (유효기간: ${contract['contract_TS_min_effect_month']}개월)';
      }
      parts.add(s);
    }
    if ((contract['contract_games'] ?? 0) > 0) {
      String s = '스크린게임 ${f.format(contract['contract_games'])}회';
      if ((contract['contract_games_effect_month'] ?? 0) > 0) {
        s += ' (유효기간: ${contract['contract_games_effect_month']}개월)';
      }
      parts.add(s);
    }
    if ((contract['contract_term_month'] ?? 0) > 0) {
      String s = '기간권 ${f.format(contract['contract_term_month'])}개월';
      if ((contract['contract_term_month_effect_month'] ?? 0) > 0) {
        s += ' (유효기간: ${contract['contract_term_month_effect_month']}개월)';
      }
      parts.add(s);
    }
    if ((contract['price'] ?? 0) > 0) {
      parts.add('가격 ${f.format(contract['price'])}원');
    }
    return parts.join(', ');
  }

  Widget _buildServiceChip({required IconData icon, required Color iconColor, required String label, int? effectMonth}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (effectMonth != null && effectMonth > 0)
            Text(
              ' (${effectMonth}개월)',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
} 