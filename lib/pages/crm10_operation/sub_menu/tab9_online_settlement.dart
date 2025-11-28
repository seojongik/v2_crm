import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../services/portone_settlement_service.dart';

class Tab9OnlineSettlementWidget extends StatefulWidget {
  const Tab9OnlineSettlementWidget({super.key});

  @override
  State<Tab9OnlineSettlementWidget> createState() => _Tab9OnlineSettlementWidgetState();
}

class _Tab9OnlineSettlementWidgetState extends State<Tab9OnlineSettlementWidget> {
  bool _isLoading = false;
  bool _isLoadingSummary = false;
  
  // 날짜 선택
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // 로그인된 지점 ID
  String? _currentBranchId;
  
  // 정산 내역 데이터
  List<Map<String, dynamic>> _settlementItems = [];
  Map<String, dynamic>? _summary;
  
  // 페이지네이션
  int _currentPage = 0;
  int _pageSize = 20;
  int _totalPages = 1;
  
  // 플랫폼 기능 활성화 상태
  bool _isPlatformNotEnabled = false;
  
  final NumberFormat _numberFormat = NumberFormat('#,###');
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    // 로그인된 지점 ID 가져오기
    _currentBranchId = ApiService.getCurrentBranchId();
    if (_currentBranchId == null) {
      print('경고: 로그인된 지점 정보가 없습니다.');
    }
    // 포트원 API Secret 초기화 후 정산 내역 로드
    _initializeAndLoad();
  }
  
  /// 포트원 API Secret 초기화 후 정산 내역 로드
  Future<void> _initializeAndLoad() async {
    // 먼저 포트원 API Secret 초기화
    await _initializePortoneApiSecret();
    // API Secret 설정 완료 후 정산 내역 로드
    _loadSettlementData();
  }
  
  /// 포트원 API Secret 초기화 (DB에서 가져오기)
  Future<void> _initializePortoneApiSecret() async {
    try {
      print('=== 포트원 API Secret 초기화 시작 ===');
      print('지점 ID: $_currentBranchId');
      
      // v2_branch 테이블에서 포트원 API Secret 조회
      final branches = await ApiService.getDataList(
        table: 'v2_branch',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': _currentBranchId ?? ''},
        ],
      );
      
      print('DB 조회 결과: ${branches.length}개 지점 정보');
      
      if (branches.isNotEmpty) {
        final branch = branches.first;
        final apiSecret = branch['portone_api_secret'] as String?;
        
        print('DB에서 가져온 portone_api_secret: ${apiSecret != null ? "${apiSecret.substring(0, 10)}..." : "null"}');
        
        if (apiSecret != null && apiSecret.isNotEmpty) {
          PortoneSettlementService.setApiSecret(apiSecret);
          print('✅ 포트원 API Secret을 DB에서 로드했습니다.');
          print('설정된 API Secret 확인: ${PortoneSettlementService.getApiSecret() != null ? "설정됨" : "설정 안됨"}');
        } else {
          print('⚠️ DB에 포트원 API Secret이 없습니다. (null 또는 빈 문자열)');
        }
      } else {
        print('⚠️ 지점 정보를 찾을 수 없습니다.');
      }
    } catch (e, stackTrace) {
      print('❌ 포트원 API Secret 초기화 오류: $e');
      print('스택 트레이스: $stackTrace');
    }
    print('=== 포트원 API Secret 초기화 완료 ===');
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 정산 내역 로드
  Future<void> _loadSettlementData() async {
    print('=== 온라인 정산 페이지: 정산 내역 로드 시작 ===');
    print('지점 ID: $_currentBranchId');
    print('조회 기간: ${_startDate.toString().split(' ')[0]} ~ ${_endDate.toString().split(' ')[0]}');
    print('페이지: $_currentPage, 페이지 크기: $_pageSize');
    
    if (_currentBranchId == null) {
      print('❌ 지점 ID가 없습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인된 지점 정보가 없습니다.')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // API Secret 확인
      final apiSecret = PortoneSettlementService.getApiSecret();
      print('포트원 API Secret 설정 여부: ${apiSecret != null ? "설정됨" : "설정 안됨"}');
      if (apiSecret == null) {
        print('⚠️ 포트원 API Secret이 설정되지 않아 DB에서 조회합니다.');
      }
      
      final result = await PortoneSettlementService.getBranchSettlements(
        branchId: _currentBranchId!,
        from: _startDate,
        to: _endDate,
        page: _currentPage,
        pageSize: _pageSize,
      );
      
      print('정산 내역 조회 결과: success=${result['success']}');
      if (result.containsKey('warning')) {
        print('⚠️ 경고: ${result['warning']}');
      }
      
      // 플랫폼 미활성화 오류 확인
      if (result.containsKey('errorType') && result['errorType'] == 'PLATFORM_NOT_ENABLED') {
        print('⚠️ 파트너 정산 자동화 기능이 활성화되지 않았습니다.');
        setState(() {
          _isPlatformNotEnabled = true;
          _settlementItems = [];
          _summary = null;
        });
        return; // DB 폴백 하지 않음
      }
      
      if (result['success'] == true) {
        final items = List<Map<String, dynamic>>.from(
          result['data']['items'] ?? [],
        );
        print('조회된 정산 내역 건수: ${items.length}');
        print('요약 정보: ${result['data']['summary']}');
        
        setState(() {
          _isPlatformNotEnabled = false;
          _settlementItems = items;
          _summary = result['data']['summary'];
          _totalPages = result['data']['pagination']['totalPages'] ?? 1;
        });
      } else {
        print('❌ 정산 내역 조회 실패: ${result['error']}');
        setState(() {
          _isPlatformNotEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정산 내역 조회 실패: ${result['error']}')),
        );
      }
    } catch (e, stackTrace) {
      print('❌ 정산 내역 로드 오류: $e');
      print('스택 트레이스: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('정산 내역을 불러오는 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('=== 정산 내역 로드 완료 ===');
    }
  }
  
  /// 날짜 선택
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: Locale('ko', 'KR'),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 0;
      });
      _loadSettlementData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_currentBranchId == null) {
      return Center(
        child: Text(
          '로그인된 지점 정보가 없습니다.',
          style: TextStyle(color: Colors.black),
        ),
      );
    }
    
    // 플랫폼 미활성화 상태일 때 안내 메시지 표시
    if (_isPlatformNotEnabled) {
      return Container(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(),
            SizedBox(height: 24),
            
            // 안내 메시지 카드
            _buildPlatformNotEnabledCard(),
          ],
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 및 필터
          _buildHeader(),
          SizedBox(height: 16),
          
          // 요약 카드
          if (_summary != null) _buildBranchSummaryCard(),
          
          SizedBox(height: 16),
          
          // 정산 내역 테이블
          Expanded(
            child: _buildSettlementTable(),
          ),
        ],
      ),
    );
  }
  
  /// 플랫폼 미활성화 안내 카드
  Widget _buildPlatformNotEnabledCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFF59E0B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Color(0xFFF59E0B),
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '파트너 정산 자동화 기능 활성화 필요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '포트원 영업팀과 협의 중',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안내사항',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 12),
                _buildInfoItem(
                  '• 포트원 파트너 정산 자동화 서비스를 사용하려면 기능 활성화가 필요합니다.',
                ),
                SizedBox(height: 8),
                _buildInfoItem(
                  '• 현재 포트원 영업팀과 협의 중입니다.',
                ),
                SizedBox(height: 8),
                _buildInfoItem(
                  '• 기능 활성화가 완료되면 정산 내역을 조회할 수 있습니다.',
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '문의처',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '포트원 고객지원: tech.support@portone.io',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 안내 항목 위젯
  Widget _buildInfoItem(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Color(0xFF92400E),
        height: 1.5,
      ),
    );
  }
  
  /// 헤더 및 필터
  Widget _buildHeader() {
    // 현재 지점 정보 가져오기
    final currentBranch = ApiService.getCurrentBranch();
    final branchName = currentBranch?['branch_name'] ?? _currentBranchId ?? '현재 지점';
    
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '온라인 정산 관리',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '지점: $branchName',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
        Spacer(),
        // 날짜 선택 버튼
        ElevatedButton.icon(
          onPressed: _selectDateRange,
          icon: Icon(Icons.calendar_today, size: 18),
          label: Text(
            '${DateFormat('yyyy-MM-dd').format(_startDate)} ~ ${DateFormat('yyyy-MM-dd').format(_endDate)}',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
  
  
  /// 정산 내역 테이블
  Widget _buildSettlementTable() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_settlementItems.isEmpty) {
      return Center(
        child: Text(
          '조회 기간 내 정산 내역이 없습니다.',
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // 테이블 헤더
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildHeaderCell('상태', 80),
                _buildHeaderCell('결제일시', 120),
                _buildHeaderCell('정산일', 100),
                _buildHeaderCell('주문명', 150),
                _buildHeaderCell('결제수단', 100),
                _buildHeaderCell('결제금액', 110, alignment: TextAlign.right),
                _buildHeaderCell('공급가액', 110, alignment: TextAlign.right),
                _buildHeaderCell('부가세', 100, alignment: TextAlign.right),
                _buildHeaderCell('플랫폼수수료', 110, alignment: TextAlign.right),
                _buildHeaderCell('수수료부가세', 110, alignment: TextAlign.right),
                _buildHeaderCell('지점정산금액', 120, alignment: TextAlign.right),
                _buildHeaderCell('취소여부', 80, alignment: TextAlign.center),
                _buildHeaderCell('관리', 80, alignment: TextAlign.center),
              ],
            ),
          ),
          // 구분선
          Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          // 테이블 본문
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _settlementItems.length,
              itemBuilder: (context, index) => _buildTableRow(index),
            ),
          ),
        ],
      ),
    );
  }

  /// 페이지네이션 위젯 (필요시 추가 가능)
  Widget _buildPagination() {
    if (_totalPages <= 1) return SizedBox();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _loadSettlementData();
                  }
                : null,
          ),
          Text(
            '${_currentPage + 1} / $_totalPages',
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _loadSettlementData();
                  }
                : null,
          ),
        ],
      ),
    );
  }
  
  /// 지점별 요약 카드
  Widget _buildBranchSummaryCard() {
    if (_summary == null) return SizedBox();
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryItem(
                '총 결제 금액',
                _summary!['totalPaymentAmount'] ?? 0,
              ),
              SizedBox(width: 24),
              _buildSummaryItem(
                '공급가액',
                _summary!['totalPaymentSupply'] ?? 0,
              ),
              SizedBox(width: 24),
              _buildSummaryItem(
                '부가세',
                _summary!['totalPaymentVat'] ?? 0,
              ),
              SizedBox(width: 24),
              _buildSummaryItem(
                '결제 건수',
                _summary!['totalCount'] ?? 0,
                isCount: true,
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem(
                '플랫폼 수수료',
                _summary!['totalPlatformFee'] ?? 0,
              ),
              SizedBox(width: 24),
              _buildSummaryItem(
                '수수료 부가세',
                _summary!['totalPlatformFeeVat'] ?? 0,
              ),
              SizedBox(width: 24),
              _buildSummaryItem(
                '지점 정산 금액',
                _summary!['totalBranchAmount'] ?? 0,
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, dynamic value, {bool isCount = false, bool isHighlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isCount
                ? '${_numberFormat.format(value)}건'
                : '${_numberFormat.format(value)}원',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Color(0xFF3B82F6) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
  
  TextStyle get _headerTextStyle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );


  /// 테이블 헤더 셀
  Widget _buildHeaderCell(String text, double width, {TextAlign alignment = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: _headerTextStyle,
        textAlign: alignment,
      ),
    );
  }

  /// 테이블 행 빌드
  Widget _buildTableRow(int index) {
    final item = _settlementItems[index];
    final paymentDate = item['paymentDate'] as String? ?? '';
    final settlementDate = item['settlementDate'] as String?;
    final orderName = item['orderName'] as String? ?? '';
    final paymentMethod = item['paymentMethod'] as String? ?? '';
    final paymentAmount = item['paymentAmount'] as int? ?? 0;
    final paymentSupply = item['paymentSupply'] as int? ?? 0;
    final paymentVat = item['paymentVat'] as int? ?? 0;
    final platformFee = item['platformFee'] as int? ?? 0;
    final platformFeeVat = item['platformFeeVat'] as int? ?? 0;
    final branchAmount = item['branchAmount'] as int? ?? 0;
    final settlementStatus = item['settlementStatus'] as String? ?? 'UNKNOWN';
    final isCancelled = item['isCancelled'] as bool? ?? false;
    final paymentId = item['paymentId'] as String? ?? '';

    DateTime? dateTime;
    if (paymentDate.isNotEmpty) {
      try {
        dateTime = DateTime.parse(paymentDate);
      } catch (e) {
        // 파싱 실패 시 무시
      }
    }

    DateTime? settlementDateTime;
    if (settlementDate != null && settlementDate.isNotEmpty) {
      try {
        settlementDateTime = DateTime.parse(settlementDate);
      } catch (e) {
        // 파싱 실패 시 무시
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: isCancelled ? Color(0xFFFFF5F5) : Colors.white,
      ),
      child: Row(
        children: [
              // 상태
              SizedBox(
                width: 80,
                child: _buildStatusBadge(settlementStatus, isCancelled),
              ),
              // 결제일시
              SizedBox(
                width: 120,
                child: Text(
                  dateTime != null
                      ? DateFormat('yyyy-MM-dd\nHH:mm').format(dateTime)
                      : paymentDate,
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
              // 정산일
              SizedBox(
                width: 100,
                child: Text(
                  settlementDateTime != null
                      ? DateFormat('yyyy-MM-dd').format(settlementDateTime)
                      : settlementDate ?? '-',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
              // 주문명
              SizedBox(
                width: 150,
                child: Text(
                  orderName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
              // 결제수단
              SizedBox(
                width: 100,
                child: Text(
                  _getPaymentMethodName(paymentMethod),
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
              // 결제금액
              SizedBox(
                width: 110,
                child: Text(
                  '${_numberFormat.format(paymentAmount)}원',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.right,
                ),
              ),
              // 공급가액
              SizedBox(
                width: 110,
                child: Text(
                  '${_numberFormat.format(paymentSupply)}원',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.right,
                ),
              ),
              // 부가세
              SizedBox(
                width: 100,
                child: Text(
                  '${_numberFormat.format(paymentVat)}원',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.right,
                ),
              ),
              // 플랫폼수수료
              SizedBox(
                width: 110,
                child: Text(
                  '${_numberFormat.format(platformFee)}원',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.right,
                ),
              ),
              // 수수료부가세
              SizedBox(
                width: 110,
                child: Text(
                  '${_numberFormat.format(platformFeeVat)}원',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.right,
                ),
              ),
              // 지점정산금액
              SizedBox(
                width: 120,
                child: Text(
                  '${_numberFormat.format(branchAmount)}원',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // 취소여부
              SizedBox(
                width: 80,
                child: Center(
                  child: isCancelled
                      ? Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFE5E5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          '정상',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              // 관리
              SizedBox(
                width: 80,
                child: Center(
                  child: !isCancelled && paymentId.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                          onPressed: () => _showCancelDialog(paymentId, paymentAmount),
                          tooltip: '결제 취소',
                        )
                      : SizedBox(),
                ),
              ),
            ],
      ),
    );
  }
  
  String _getPaymentMethodName(String? method) {
    switch (method) {
      case 'CARD':
        return '카드';
      case 'EASY_PAY':
        return '간편결제';
      case 'VIRTUAL_ACCOUNT':
        return '가상계좌';
      case 'TRANSFER':
        return '계좌이체';
      case 'MOBILE':
        return '휴대폰';
      default:
        return method ?? '-';
    }
  }
  
  /// 정산 상태 배지
  Widget _buildStatusBadge(String status, bool isCancelled) {
    if (isCancelled) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFFFFE5E5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '취소',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    
    Color bgColor;
    Color textColor;
    String statusText;
    
    switch (status) {
      case 'PAYOUT_PREPARED':
        bgColor = Color(0xFFE0F2FE);
        textColor = Color(0xFF0369A1);
        statusText = '지급예정';
        break;
      case 'PAYOUT_SCHEDULED':
        bgColor = Color(0xFFFEF3C7);
        textColor = Color(0xFF92400E);
        statusText = '지급예약';
        break;
      case 'PAID_OUT':
        bgColor = Color(0xFFD1FAE5);
        textColor = Color(0xFF065F46);
        statusText = '지급완료';
        break;
      case 'PAYOUT_FAILED':
        bgColor = Color(0xFFFFE5E5);
        textColor = Color(0xFFDC2626);
        statusText = '지급실패';
        break;
      case 'PAYOUT_WITHHELD':
        bgColor = Color(0xFFFFF5E5);
        textColor = Color(0xFFB45309);
        statusText = '지급보류';
        break;
      case 'IN_PAYOUT':
        bgColor = Color(0xFFE0F2FE);
        textColor = Color(0xFF0369A1);
        statusText = '지급중';
        break;
      default:
        bgColor = Color(0xFFF3F4F6);
        textColor = Color(0xFF6B7280);
        statusText = '미확인';
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  /// 결제 취소 다이얼로그
  Future<void> _showCancelDialog(String paymentId, int paymentAmount) async {
    final reasonController = TextEditingController();
    bool isPartialCancel = false;
    final cancelAmountController = TextEditingController(text: paymentAmount.toString());
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('결제 취소'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('결제 ID: $paymentId'),
                SizedBox(height: 8),
                Text('결제 금액: ${_numberFormat.format(paymentAmount)}원'),
                SizedBox(height: 16),
                CheckboxListTile(
                  title: Text('부분 취소'),
                  value: isPartialCancel,
                  onChanged: (value) {
                    setDialogState(() {
                      isPartialCancel = value ?? false;
                    });
                  },
                ),
                if (isPartialCancel) ...[
                  SizedBox(height: 8),
                  TextField(
                    controller: cancelAmountController,
                    decoration: InputDecoration(
                      labelText: '취소 금액',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: '취소 사유',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('취소 사유를 입력해주세요.')),
                  );
                  return;
                }
                
                final cancelAmount = isPartialCancel
                    ? int.tryParse(cancelAmountController.text)
                    : null;
                
                if (isPartialCancel && (cancelAmount == null || cancelAmount <= 0 || cancelAmount > paymentAmount)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('올바른 취소 금액을 입력해주세요.')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                await _cancelPayment(paymentId, reasonController.text, cancelAmount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 결제 취소 실행
  Future<void> _cancelPayment(String paymentId, String reason, int? cancelAmount) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final result = await PortoneSettlementService.cancelPayment(
        paymentId: paymentId,
        cancelReason: reason,
        cancelAmount: cancelAmount,
      );
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결제 취소가 완료되었습니다.')),
        );
        // 정산 내역 다시 로드
        _loadSettlementData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결제 취소 실패: ${result['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('결제 취소 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

