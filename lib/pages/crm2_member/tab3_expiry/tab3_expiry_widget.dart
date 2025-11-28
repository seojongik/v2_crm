import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/api_service.dart';
import '/services/table_design.dart';
import '/services/tab_design_upper.dart';
import '/services/upper_button_input_design.dart';
import '/constants/font_sizes.dart';
import 'tab3_expiry_model.dart';
export 'tab3_expiry_model.dart';

class Tab3ExpiryWidget extends StatefulWidget {
  const Tab3ExpiryWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab3ExpiryWidget> createState() => _Tab3ExpiryWidgetState();
}

class _Tab3ExpiryWidgetState extends State<Tab3ExpiryWidget> with SingleTickerProviderStateMixin {
  late Tab3ExpiryModel _model;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab3ExpiryModel());
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 첫 번째 탭(크레딧) 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('### initState: 첫 번째 탭(크레딧) 로드 시작');
      _loadTabData(0);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _model.dispose();
    super.dispose();
  }

  // 탭 변경 이벤트
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      print('### 탭 변경: ${_tabController.index}');
      setState(() {
        _model.selectedTabIndex = _tabController.index;
      });

      // 아직 로드되지 않은 탭이면 로드
      if (_model.tabDataLoaded[_tabController.index] != true) {
        print('### 탭 ${_tabController.index} 데이터 로드 시작');
        _loadTabData(_tabController.index);
      } else {
        print('### 탭 ${_tabController.index} 이미 로드됨, 필터만 적용');
        setState(() {
          _model.applyFilters();
        });
      }
    }
  }

  // 탭별 데이터 로드
  Future<void> _loadTabData(int tabIndex) async {
    // 이미 로드된 경우 스킵
    if (_model.tabDataLoaded[tabIndex] == true) {
      return;
    }

    setState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      final branchId = ApiService.getCurrentBranchId();
      print('=== 탭 $tabIndex 데이터 조회 시작 ===');
      print('branch_id: $branchId');

      // 모든 탭이 해당 상품만 조회 (탭 인덱스 + 1 = 이전 개별 탭 인덱스)
      List<ExpiryItem> items = await _loadSingleProduct(branchId, tabIndex + 1);

      setState(() {
        _model.tabDataCache[tabIndex] = items;
        _model.tabDataLoaded[tabIndex] = true;
        _model.applyFilters();
        _model.isLoading = false;
      });

      print('탭 $tabIndex 로드 완료: ${items.length}개 ExpiryItem 생성');
      print('필터 적용 후: ${_model.filteredItems.length}개 표시');
    } catch (e, stackTrace) {
      print('탭 $tabIndex 로드 오류: $e');
      print('스택트레이스: $stackTrace');
      setState(() {
        _model.errorMessage = '데이터 로드 중 오류가 발생했습니다: $e';
        _model.isLoading = false;
      });
    }
  }


  // 단일 상품 데이터 로드
  Future<List<ExpiryItem>> _loadSingleProduct(dynamic branchId, int tabIndex) async {
    const tabNames = ['', '크레딧', '시간권', '게임권', '레슨권', '기간권'];
    print('>>> _loadSingleProduct 시작 (탭: ${tabNames[tabIndex]})');

    List billData = [];
    String tableName = '';
    String productType = '';

    // 탭별로 필요한 bill 테이블만 조회
    switch (tabIndex) {
      case 1: // 크레딧
        tableName = 'v2_bills';
        productType = 'credit';
        billData = await ApiService.getBillsData(
          where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
        );
        break;
      case 2: // 시간권
        tableName = 'v2_bill_times';
        productType = 'time';
        billData = await ApiService.getBillTimesData(
          where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
        );
        break;
      case 3: // 게임권
        tableName = 'v2_bill_games';
        productType = 'game';
        billData = await ApiService.getDataList(
          table: 'v2_bill_games',
          where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
        );
        break;
      case 4: // 레슨권
        tableName = 'v3_LS_countings';
        productType = 'lesson';
        billData = await ApiService.getDataList(
          table: 'v3_LS_countings',
          where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
        );
        break;
      case 5: // 기간권
        tableName = 'v2_bill_term';
        productType = 'term';
        billData = await ApiService.getDataList(
          table: 'v2_bill_term',
          where: [{'field': 'branch_id', 'operator': '=', 'value': branchId}],
        );
        break;
    }

    print('  - $tableName: ${billData.length}개 조회');

    // bill 테이블 기준으로 ExpiryItem 생성
    return _buildExpiryItemsFromBills(billData, productType, branchId);
  }

  // bill 테이블 기준으로 ExpiryItem 생성
  Future<List<ExpiryItem>> _buildExpiryItemsFromBills(
    List billData,
    String productType,
    dynamic branchId,
  ) async {
    print('>>> _buildExpiryItemsFromBills 시작 (상품: $productType, ${billData.length}개)');

    if (billData.isEmpty) {
      return [];
    }

    // contract_history_id별로 최신 레코드만 선택
    Map<int, Map<String, dynamic>> latestBills;
    switch (productType) {
      case 'credit':
        latestBills = _groupLatestByContractHistoryId(billData, 'bill_id');
        break;
      case 'time':
        latestBills = _groupLatestByContractHistoryId(billData, 'bill_min_id');
        break;
      case 'game':
        latestBills = _groupLatestByContractHistoryId(billData, 'bill_game_id');
        break;
      case 'lesson':
        latestBills = _groupLatestByContractHistoryId(billData, 'LS_counting_id');
        break;
      case 'term':
        latestBills = _groupLatestByContractHistoryId(billData, 'bill_term_id');
        break;
      default:
        return [];
    }

    print('  - contract_history_id별 최신 레코드: ${latestBills.length}개');

    // contract_history_id 목록 추출
    final contractHistoryIds = latestBills.keys.toList();

    // v3_contract_history에서 contract_name, contract_date, member_id만 조회
    final contracts = await ApiService.getContractHistoryData(
      where: [
        {
          'field': 'contract_history_id',
          'operator': 'IN',
          'value': contractHistoryIds,
        }
      ],
    );
    print('  - v3_contract_history 조회: ${contracts.length}개');

    // member_id 목록 추출
    final memberIds = contracts.map((c) => c['member_id']).whereType<int>().toSet().toList();

    // v3_members에서 member_name 조회
    final members = await ApiService.getDataList(
      table: 'v3_members',
      where: [
        {
          'field': 'member_id',
          'operator': 'IN',
          'value': memberIds,
        }
      ],
    );
    print('  - v3_members 조회: ${members.length}개');

    // 맵 생성
    final memberMap = {for (var m in members) m['member_id']: m['member_name']};
    final contractMap = {for (var c in contracts) c['contract_history_id']: c};

    // 레슨권 프로 목록 추출 (v2_staff_pro 테이블에서 조회)
    if (productType == 'lesson') {
      final pros = await ApiService.getDataList(
        table: 'v2_staff_pro',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );

      // pro_id 기준으로 중복 제거 (null 제외)
      final seenIds = <dynamic>{};
      _model.availablePros = pros.where((p) {
        final proId = p['pro_id'];
        final proName = p['pro_name'];

        // null이면 제외
        if (proId == null || proName == null) {
          return false;
        }

        // 중복 체크
        if (seenIds.contains(proId)) {
          return false;
        }
        seenIds.add(proId);
        return true;
      }).map((p) => {
        'pro_id': p['pro_id'],
        'pro_name': p['pro_name'],
      }).toList();

      print('  - 레슨권 프로 목록 (v2_staff_pro): ${_model.availablePros.length}명');

      // selectedProId가 목록에 없으면 초기화
      if (_model.selectedProId != null) {
        final exists = _model.availablePros.any(
          (p) => p['pro_id'].toString() == _model.selectedProId
        );
        if (!exists) {
          _model.selectedProId = null;
          print('  - selectedProId 초기화 (목록에 없음)');
        }
      }
    } else {
      // 레슨권이 아닌 탭에서는 프로 필터 초기화
      _model.selectedProId = null;
      _model.availablePros = [];
    }

    // ExpiryItem 생성
    List<ExpiryItem> items = [];

    for (var entry in latestBills.entries) {
      final contractHistoryId = entry.key;
      final bill = entry.value;
      final contract = contractMap[contractHistoryId];

      if (contract == null) continue;

      final memberId = contract['member_id'];
      final memberName = memberMap[memberId] ?? '이름없음';
      final contractName = contract['contract_name'] ?? '';
      final contractDateStr = contract['contract_date'];

      if (contractDateStr == null) continue;

      final purchaseDate = DateTime.parse(contractDateStr);

      // 상품별 잔액, 만료일 추출
      dynamic balance;
      DateTime? expiryDate;

      switch (productType) {
        case 'credit':
          balance = _safeParseInt(bill['bill_balance_after']);
          expiryDate = _parseDate(bill['contract_credit_expiry_date']);
          break;
        case 'time':
          balance = _safeParseInt(bill['bill_balance_min_after']);
          expiryDate = _parseDate(bill['contract_TS_min_expiry_date']);
          break;
        case 'game':
          balance = _safeParseInt(bill['bill_balance_game_after']);
          expiryDate = _parseDate(bill['contract_games_expiry_date']);
          break;
        case 'lesson':
          balance = _safeParseInt(bill['LS_balance_min_after']);
          expiryDate = _parseDate(bill['LS_expiry_date']);
          break;
        case 'term':
          expiryDate = _parseDate(bill['contract_term_month_expiry_date']);
          if (expiryDate != null) {
            balance = '${expiryDate.difference(DateTime.now()).inDays}일';
          }
          break;
      }

      // 잔액이 있거나 기간권인 경우 ExpiryItem 생성
      if (productType == 'term' || (balance is int && balance > 0)) {
        items.add(ExpiryItem(
          memberId: memberId,
          memberName: memberName,
          contractHistoryId: contractHistoryId,
          productType: productType,
          contractName: contractName,
          purchaseDate: purchaseDate,
          expiryDate: expiryDate,
          currentBalance: balance,
          proName: productType == 'lesson' ? bill['pro_name'] : null,
          proId: productType == 'lesson' ? bill['pro_id'] : null,
        ));
      }
    }

    print('>>> ExpiryItem 생성 완료: ${items.length}개');
    return items;
  }

  Map<int, Map<String, dynamic>> _groupLatestByContractHistoryId(
    List data,
    String primaryKey,
  ) {
    final Map<int, Map<String, dynamic>> result = {};
    data.sort((a, b) {
      final aKey = _safeParseInt(a[primaryKey]);
      final bKey = _safeParseInt(b[primaryKey]);
      return bKey.compareTo(aKey);
    });

    for (var record in data) {
      final contractHistoryId = record['contract_history_id'];
      if (contractHistoryId != null && !result.containsKey(contractHistoryId)) {
        result[contractHistoryId] = record;
      }
    }

    return result;
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (e) {
      return null;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 필터 영역
        _buildFilterSection(),
        SizedBox(height: 16),

        // 탭 바
        _buildTabBar(),
        SizedBox(height: 16),

        // 통계 요약
        _buildSummarySection(),
        SizedBox(height: 16),

        // 테이블
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  // 탭 바
  Widget _buildTabBar() {
    return TabDesignUpper.buildCompleteTabBar(
      controller: _tabController,
      tabs: [
        Tab(text: '크레딧'),
        Tab(text: '시간권'),
        Tab(text: '게임권'),
        Tab(text: '레슨권'),
        Tab(text: '기간권'),
      ],
      themeNumber: 1,
      size: 'medium',
      isScrollable: true,
      hasTopRadius: false,
    );
  }

  // 필터 섹션
  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 시작일
          _buildDatePicker(
            label: '시작일',
            date: _model.startDate,
            onDateSelected: (date) {
              setState(() {
                _model.startDate = date;
                _model.applyFilters();
              });
            },
          ),
          SizedBox(width: 16),

          // 종료일
          _buildDatePicker(
            label: '종료일',
            date: _model.endDate,
            onDateSelected: (date) {
              setState(() {
                _model.endDate = date;
                _model.applyFilters();
              });
            },
          ),
          SizedBox(width: 16),

          // 레슨권 탭일 때만 프로 필터 표시 (탭 인덱스 3)
          if (_model.selectedTabIndex == 3 && _model.availablePros.isNotEmpty) ...[
            _buildProFilter(),
            SizedBox(width: 16),
          ],

          Spacer(),

          // 새로고침 버튼
          ButtonDesignUpper.buildIconButton(
            text: '새로고침',
            icon: Icons.refresh,
            onPressed: () {
              print('### 새로고침 버튼 클릭 - 탭 ${_model.selectedTabIndex} 데이터 초기화');
              _model.tabDataLoaded[_model.selectedTabIndex] = false;
              _model.tabDataCache.remove(_model.selectedTabIndex);
              _loadTabData(_model.selectedTabIndex);
            },
            color: 'cyan',
            size: 'medium',
          ),
        ],
      ),
    );
  }

  // 날짜 선택기
  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required Function(DateTime) onDateSelected,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF1E293B),
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: const Locale('ko', 'KR'),
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE2E8F0), width: 1.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  date != null ? DateFormat('yyyy-MM-dd').format(date) : '날짜 선택',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF1E293B),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 프로 필터 (레슨권 전용)
  Widget _buildProFilter() {
    return Row(
      children: [
        Text(
          '프로',
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF1E293B),
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 12),
        Container(
          width: 180,
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFFE2E8F0), width: 1.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: DropdownButton<String>(
            value: _model.selectedProId,
            hint: Text(
              '전체',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF94A3B8),
                fontSize: 14.0,
                fontWeight: FontWeight.w400,
              ),
            ),
            isExpanded: true,
            underline: SizedBox(),
            dropdownColor: Colors.white,
            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 20),
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF1E293B),
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
            ),
            isDense: true,
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  '전체',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF1E293B),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              ..._model.availablePros.where((pro) =>
                pro['pro_id'] != null && pro['pro_name'] != null
              ).map((pro) {
                return DropdownMenuItem<String>(
                  value: pro['pro_id'].toString(),
                  child: Text(
                    pro['pro_name'].toString(),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF1E293B),
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                _model.selectedProId = value;
                _model.applyFilters();
              });
            },
          ),
        ),
      ],
    );
  }

  // 통계 요약 섹션
  Widget _buildSummarySection() {
    final total = _model.filteredItems.length;
    final expired = _model.filteredItems.where((item) => item.expiryStatus == '만료').length;
    final imminent = _model.filteredItems.where((item) => item.expiryStatus == '임박').length;
    final warning = _model.filteredItems.where((item) => item.expiryStatus == '주의').length;
    final totalBalance = _model.calculateTotalBalance();
    final unit = _model.getBalanceUnit();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryCard('전체', total.toString()),
          _buildSummaryCard('만료', expired.toString()),
          _buildSummaryCard('임박 (7일)', imminent.toString()),
          _buildSummaryCard('주의 (30일)', warning.toString()),
          if (unit.isNotEmpty)
            _buildSummaryCard('잔액 합계', '${NumberFormat('#,###').format(totalBalance)}$unit'),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.cardBody.copyWith(color: Colors.black)),
        SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.h1.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  // 콘텐츠
  Widget _buildContent() {
    if (_model.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_model.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _model.errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildDataTable();
  }

  // 데이터 테이블
  Widget _buildDataTable() {
    if (_model.filteredItems.isEmpty) {
      return Center(
        child: Text(
          '조회된 데이터가 없습니다.',
          style: AppTextStyles.cardBody.copyWith(color: Colors.black),
        ),
      );
    }

    return TableDesign.buildTableContainer(
      child: Column(
        children: [
          // 헤더
          TableDesign.buildTableHeader(
            children: [
              TableDesign.buildHeaderColumn(text: '상태', flex: 1),
              TableDesign.buildHeaderColumn(text: '회원명', flex: 2),
              TableDesign.buildHeaderColumn(text: '계약명', flex: 2),
              TableDesign.buildHeaderColumn(text: '구매일', flex: 2),
              TableDesign.buildHeaderColumn(text: '만료일', flex: 2),
              TableDesign.buildHeaderColumn(text: '잔여일', flex: 1),
              TableDesign.buildHeaderColumn(text: '현재잔액', flex: 2),
              // 레슨권 탭(인덱스 3)일 때만 프로 컬럼 표시
              if (_model.selectedTabIndex == 3)
                TableDesign.buildHeaderColumn(text: '프로', flex: 2),
            ],
          ),
          // 본문
          Expanded(
            child: TableDesign.buildTableBody(
              itemCount: _model.filteredItems.length,
              itemBuilder: (context, index) {
                final item = _model.filteredItems[index];

                return TableDesign.buildTableRow(
                  children: [
                    // 상태
                    Expanded(
                      flex: 1,
                      child: Center(child: _buildStatusBadge(item.expiryStatus)),
                    ),
                    // 회원명
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.memberName,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 계약명
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.contractName,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 구매일
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(item.purchaseDate),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 만료일
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.expiryDate != null
                            ? DateFormat('yyyy-MM-dd').format(item.expiryDate!)
                            : '-',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 잔여일
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.daysUntilExpiry != null ? '${item.daysUntilExpiry}일' : '-',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 현재잔액
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatBalance(item.productType, item.currentBalance),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 레슨권 탭(인덱스 3)일 때만 프로 컬럼 표시
                    if (_model.selectedTabIndex == 3)
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.proName ?? '-',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
              isLoading: false,
              hasError: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case '만료':
        bgColor = Color(0xFFFEE2E2);
        textColor = Color(0xFFDC2626);
        break;
      case '임박':
        bgColor = Color(0xFFFED7AA);
        textColor = Color(0xFFEA580C);
        break;
      case '주의':
        bgColor = Color(0xFFFEF3C7);
        textColor = Color(0xFFCA8A04);
        break;
      default:
        bgColor = Color(0xFFDCFCE7);
        textColor = Color(0xFF16A34A);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: AppTextStyles.cardBody.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatBalance(String productType, dynamic balance) {
    if (balance == null) return '-';

    switch (productType) {
      case 'credit':
        return NumberFormat('#,###원').format(balance);
      case 'time':
      case 'lesson':
        return NumberFormat('#,###분').format(balance);
      case 'game':
        return NumberFormat('#,###게임').format(balance);
      case 'term':
        return balance.toString();
      default:
        return balance.toString();
    }
  }
}
