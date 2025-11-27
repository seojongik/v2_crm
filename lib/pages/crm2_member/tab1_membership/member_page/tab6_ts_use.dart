import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';

class Tab6TsUseWidget extends StatefulWidget {
  const Tab6TsUseWidget({
    super.key,
    required this.memberId,
    this.memberData, // 회원 정보를 받을 수 있도록 추가
  });

  final int memberId;
  final Map<String, dynamic>? memberData; // 캐시된 회원 정보

  @override
  State<Tab6TsUseWidget> createState() => _Tab6TsUseWidgetState();
}

class _Tab6TsUseWidgetState extends State<Tab6TsUseWidget> {
  List<Map<String, dynamic>> tsUseHistory = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? memberInfo; // 회원 정보 저장

  @override
  void initState() {
    super.initState();
    _loadMemberInfo();
    _loadTsUseHistory();
  }

  // 회원 정보 로드
  Future<void> _loadMemberInfo() async {
    try {
      if (widget.memberData != null) {
        memberInfo = widget.memberData;
      } else {
        memberInfo = await ApiService.getMemberById(widget.memberId);
      }
    } catch (e) {
      print('회원 정보 로드 오류: $e');
    }
  }

  Future<void> _loadTsUseHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // v2_priced_TS 데이터 조회
      final data = await _getTsUseData();
      
      setState(() {
        tsUseHistory = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // v2_priced_TS 데이터 조회를 위한 별도 함수
  Future<List<Map<String, dynamic>>> _getTsUseData() async {
    try {
      // ApiService를 사용하여 v2_priced_TS 데이터 조회
      final data = await ApiService.getPricedTsData(
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
            'field': 'ts_date',
            'direction': 'DESC'
          },
          {
            'field': 'ts_start',
            'direction': 'DESC'
          }
        ]
      );
      
      return data;
    } catch (e) {
      throw Exception('타석이용 내역 조회 실패: $e');
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

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '-';
    try {
      // HH:mm:ss 형식을 HH:mm으로 변환
      if (timeStr.length >= 5) {
        return timeStr.substring(0, 5);
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0원';
    try {
      final intAmount = int.parse(amount.toString());
      final formatter = NumberFormat('#,###');
      return '${formatter.format(intAmount)}원';
    } catch (e) {
      return '${amount}원';
    }
  }

  // 더미 다이얼로그 1 - 타석예약
  void _showTsReservationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('타석예약'),
          content: Text('타석예약 기능은 개발중입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 더미 다이얼로그 2 - 할인권 증정 (기존 이용내역 관리에서 변경)
  void _showDiscountCouponDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DiscountCouponDialog(
          memberId: widget.memberId,
          memberInfo: memberInfo,
        );
      },
    );
  }

  // 상세 조회 다이얼로그
  void _showDetailDialog(Map<String, dynamic> reservation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TsDetailDialog(
          reservationId: reservation['reservation_id'],
          reservationData: reservation,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Color(0xFFF8FAFC),
      child: Column(
        children: [
          // 상단 버튼 영역
          Container(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _showTsReservationDialog,
                      icon: Icon(Icons.add_circle, size: 18),
                      label: Text(
                        '타석예약',
                        style: AppTextStyles.button.copyWith(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Color(0xFF3B82F6).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _showDiscountCouponDialog, // 메서드명 변경
                      icon: Icon(Icons.card_giftcard, size: 18), // 아이콘 변경
                      label: Text(
                        '할인권 증정', // 버튼 텍스트 변경
                        style: AppTextStyles.button.copyWith(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: Color(0xFF10B981).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 테이블 영역
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '오류 발생',
                                style: AppTextStyles.h4.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: AppTextStyles.bodyTextSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF64748B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : tsUseHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_golf,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '타석이용 내역이 없습니다',
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // 테이블 헤더
                                Container(
                                  padding: EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8.0),
                                      topRight: Radius.circular(8.0),
                                    ),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '예약번호',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '타석',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '이용일자',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '시작시간',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '종료시간',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '총 금액',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '총 할인',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '순액',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '조회',
                                          style: AppTextStyles.formLabel.copyWith(
                                            fontFamily: 'Pretendard',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // 테이블 내용
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: tsUseHistory.length,
                                    itemBuilder: (context, index) {
                                      final item = tsUseHistory[index];
                                      final totalDiscount = (int.tryParse(item['term_discount']?.toString() ?? '0') ?? 0) +
                                                          (int.tryParse(item['member_discount']?.toString() ?? '0') ?? 0) +
                                                          (int.tryParse(item['junior_discount']?.toString() ?? '0') ?? 0) +
                                                          (int.tryParse(item['overtime_discount']?.toString() ?? '0') ?? 0) +
                                                          (int.tryParse(item['coupon_discount']?.toString() ?? '0') ?? 0) +
                                                          (int.tryParse(item['emergency_discount']?.toString() ?? '0') ?? 0);
                                      
                                      return Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                        decoration: BoxDecoration(
                                          color: index % 2 == 0 ? Colors.white : Color(0xFFFAFAFA),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE2E8F0),
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                item['reservation_id'] ?? '-',
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF374151),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                item['ts_id']?.toString() ?? '-',
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF374151),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatDate(item['ts_date']),
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF374151),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatTime(item['ts_start']),
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF374151),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatTime(item['ts_end']),
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF374151),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatAmount(item['total_amt']),
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF374151),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatAmount(totalDiscount),
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF10B981),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatAmount(item['net_amt']),
                                                style: AppTextStyles.cardBody.copyWith(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF1E293B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Center(
                                                child: IconButton(
                                                  onPressed: () => _showDetailDialog(item),
                                                  icon: Icon(
                                                    Icons.search,
                                                    size: 18,
                                                    color: Color(0xFF3B82F6),
                                                  ),
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: Color(0xFF3B82F6).withOpacity(0.1),
                                                    shape: CircleBorder(),
                                                    padding: EdgeInsets.all(8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// 타석이용 상세 조회 다이얼로그
class TsDetailDialog extends StatelessWidget {
  final String reservationId;
  final Map<String, dynamic> reservationData;

  const TsDetailDialog({
    Key? key,
    required this.reservationId,
    required this.reservationData,
  }) : super(key: key);

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0원';
    try {
      final intAmount = int.parse(amount.toString());
      final formatter = NumberFormat('#,###');
      return '${formatter.format(intAmount)}원';
    } catch (e) {
      return '${amount}원';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday - 1];
      return DateFormat('yyyy-MM-dd').format(date) + ' ($weekday)';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '-';
    try {
      if (timeStr.length >= 5) {
        return timeStr.substring(0, 5);
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  String _getUsageSummary() {
    final date = _formatDate(reservationData['ts_date']);
    final startTime = _formatTime(reservationData['ts_start']);
    final endTime = _formatTime(reservationData['ts_end']);
    final minutes = reservationData['ts_min'] ?? 0;
    return '$date  $startTime ~ $endTime (${minutes}분)';
  }

  @override
  Widget build(BuildContext context) {
    final totalDiscount = (int.tryParse(reservationData['term_discount']?.toString() ?? '0') ?? 0) +
                         (int.tryParse(reservationData['member_discount']?.toString() ?? '0') ?? 0) +
                         (int.tryParse(reservationData['junior_discount']?.toString() ?? '0') ?? 0) +
                         (int.tryParse(reservationData['overtime_discount']?.toString() ?? '0') ?? 0) +
                         (int.tryParse(reservationData['coupon_discount']?.toString() ?? '0') ?? 0) +
                         (int.tryParse(reservationData['emergency_discount']?.toString() ?? '0') ?? 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF1E40AF),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sports_golf,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '타석이용 상세정보',
                          style: AppTextStyles.h3.copyWith(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '예약번호: $reservationId',
                          style: AppTextStyles.cardSubtitle.copyWith(
                            fontFamily: 'Pretendard',
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 내용
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이용내역 요약
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 18, color: Color(0xFF3B82F6)),
                              SizedBox(width: 8),
                              Text(
                                '이용내역',
                                style: AppTextStyles.cardTitle.copyWith(
                                  fontFamily: 'Pretendard',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${reservationData['ts_id']}번 타석',
                            style: AppTextStyles.h4.copyWith(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _getUsageSummary(),
                            style: AppTextStyles.cardTitle.copyWith(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 요금 정보
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFFEFEFE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payments, size: 18, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text(
                                '요금 정보',
                                style: AppTextStyles.cardTitle.copyWith(
                                  fontFamily: 'Pretendard',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildPriceRow('총 금액', _formatAmount(reservationData['total_amt']), false),
                          _buildPriceRow('총 할인', _formatAmount(totalDiscount), true),
                          Divider(height: 20, color: Color(0xFFE2E8F0)),
                          _buildPriceRow('순액', _formatAmount(reservationData['net_amt']), false, isTotal: true),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 할인 상세 (할인이 있는 경우만 표시)
                    if (totalDiscount > 0) ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.discount, size: 18, color: Color(0xFF10B981)),
                                SizedBox(width: 8),
                                Text(
                                  '할인 상세',
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontFamily: 'Pretendard',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            ..._buildDiscountRows(),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                    
                    // 시간대별 분류 (시간이 있는 경우만 표시)
                    if ((reservationData['morning'] ?? 0) > 0 || 
                        (reservationData['normal'] ?? 0) > 0 || 
                        (reservationData['peak'] ?? 0) > 0 || 
                        (reservationData['night'] ?? 0) > 0) ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 18, color: Color(0xFFD97706)),
                                SizedBox(width: 8),
                                Text(
                                  '시간대별 분류',
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontFamily: 'Pretendard',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if ((reservationData['morning'] ?? 0) > 0)
                                  _buildTimeChip('조조', reservationData['morning']),
                                if ((reservationData['normal'] ?? 0) > 0)
                                  _buildTimeChip('일반', reservationData['normal']),
                                if ((reservationData['peak'] ?? 0) > 0)
                                  _buildTimeChip('피크', reservationData['peak']),
                                if ((reservationData['night'] ?? 0) > 0)
                                  _buildTimeChip('야간', reservationData['night']),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // 하단 버튼
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '확인',
                      style: AppTextStyles.modalButton.copyWith(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, bool isDiscount, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isTotal ? AppTextStyles.cardTitle : AppTextStyles.bodyTextSmall).copyWith(
              fontFamily: 'Pretendard',
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: (isTotal ? AppTextStyles.h4 : AppTextStyles.cardTitle).copyWith(
              fontFamily: 'Pretendard',
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isDiscount ? Color(0xFF10B981) : (isTotal ? Color(0xFF1E293B) : Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDiscountRows() {
    List<Widget> rows = [];
    
    final discounts = [
      {'label': '기간할인', 'value': reservationData['term_discount']},
      {'label': '회원할인', 'value': reservationData['member_discount']},
      {'label': '주니어할인', 'value': reservationData['junior_discount']},
      {'label': '집중연습할인', 'value': reservationData['overtime_discount']},
      {'label': '할인쿠폰사용', 'value': reservationData['coupon_discount']},
      {'label': '긴급할인', 'value': reservationData['emergency_discount']},
    ];
    
    for (var discount in discounts) {
      final amount = int.tryParse(discount['value']?.toString() ?? '0') ?? 0;
      if (amount > 0) {
        rows.add(_buildPriceRow(discount['label']!, _formatAmount(amount), true));
      }
    }
    
    // 긴급할인 사유
    if (reservationData['emergency_reason'] != null && 
        reservationData['emergency_reason'].toString().isNotEmpty &&
        (int.tryParse(reservationData['emergency_discount']?.toString() ?? '0') ?? 0) > 0) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '긴급할인 사유: ${reservationData['emergency_reason']}',
              style: AppTextStyles.cardBody.copyWith(
                fontFamily: 'Pretendard',
                color: Color(0xFF166534),
              ),
            ),
          ),
        ),
      );
    }
    
    return rows;
  }

  Widget _buildTimeChip(String label, dynamic minutes) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFD97706)),
      ),
      child: Text(
        '$label ${minutes}분',
        style: AppTextStyles.cardBody.copyWith(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
          color: Color(0xFFD97706),
        ),
      ),
    );
  }
}

// 할인권 증정 다이얼로그
class DiscountCouponDialog extends StatefulWidget {
  final int memberId;
  final Map<String, dynamic>? memberInfo;

  const DiscountCouponDialog({
    Key? key,
    required this.memberId,
    this.memberInfo,
  }) : super(key: key);

  @override
  State<DiscountCouponDialog> createState() => _DiscountCouponDialogState();
}

class _DiscountCouponDialogState extends State<DiscountCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String _selectedCouponType = '정액권(타석)'; // 기본값: 정액권(타석)
  String _selectedExpiryPeriod = '1주일'; // 기본값: 1주일
  final TextEditingController _discountValueController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  
  bool _isLoading = false;
  
  final List<String> _couponTypes = ['정액권(타석)', '정률권(타석)', '레슨권'];
  final List<Map<String, dynamic>> _expiryPeriods = [
    {'label': '1주일', 'days': 7},
    {'label': '2주일', 'days': 14},
    {'label': '1달', 'days': 30},
    {'label': '1년', 'days': 365},
  ];
  
  @override
  void initState() {
    super.initState();
    // 기본 만료일을 7일 후로 설정
    _updateExpiryDate();
  }

  @override
  void dispose() {
    _discountValueController.dispose();
    _descriptionController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  void _updateExpiryDate() {
    final selectedPeriod = _expiryPeriods.firstWhere(
      (period) => period['label'] == _selectedExpiryPeriod,
      orElse: () => _expiryPeriods.first,
    );
    final expiryDate = DateTime.now().add(Duration(days: selectedPeriod['days']));
    _expiryDateController.text = DateFormat('yyyy-MM-dd').format(expiryDate);
  }

  String _getUnitText() {
    switch (_selectedCouponType) {
      case '정액권(타석)':
        return '원';
      case '정률권(타석)':
        return '%';
      case '레슨권':
        return '분';
      default:
        return '';
    }
  }

  String _getHintText() {
    switch (_selectedCouponType) {
      case '정액권(타석)':
        return '할인 금액을 입력하세요 (예: 10000)';
      case '정률권(타석)':
        return '할인 비율을 입력하세요 (예: 10)';
      case '레슨권':
        return '레슨 시간을 입력하세요 (예: 60)';
      default:
        return '';
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final discountValue = int.tryParse(_discountValueController.text) ?? 0;
    
    // 확인 다이얼로그 표시
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 8),
              Text(
                '할인권 증정 확인',
                style: AppTextStyles.modalTitle.copyWith(
                  fontFamily: 'Pretendard',
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '다음 내용으로 할인권을 증정하시겠습니까?',
                style: AppTextStyles.modalBody.copyWith(
                  fontFamily: 'Pretendard',
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfirmRow('회원명', widget.memberInfo?['member_name'] ?? ''),
                    _buildConfirmRow('할인권 유형', _selectedCouponType),
                    _buildConfirmRow('할인내용', '$discountValue${_getUnitText()}'),
                    _buildConfirmRow('유효기간', '$_selectedExpiryPeriod (${_expiryDateController.text}까지)'),
                    if (_descriptionController.text.trim().isNotEmpty)
                      _buildConfirmRow('적요', _descriptionController.text.trim()),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFFF1F5F9),
                foregroundColor: Color(0xFF64748B),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '취소',
                style: AppTextStyles.modalButton.copyWith(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '확인',
                style: AppTextStyles.modalButton.copyWith(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _submitCoupon();
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.cardSubtitle.copyWith(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            ': ',
            style: AppTextStyles.cardSubtitle.copyWith(
              fontFamily: 'Pretendard',
              color: Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.cardSubtitle.copyWith(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCoupon() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final discountValue = int.tryParse(_discountValueController.text) ?? 0;
      
      // v2_discount_coupon 테이블에 저장할 데이터 준비
      final couponData = {
        'member_id': widget.memberId,
        'member_name': widget.memberInfo?['member_name'] ?? '',
        'coupon_type': _selectedCouponType,
        'discount_ratio': _selectedCouponType == '정률권(타석)' ? discountValue : 0,
        'discount_amt': _selectedCouponType == '정액권(타석)' ? discountValue : 0,
        'discount_LS_min': _selectedCouponType == '레슨권' ? discountValue : 0,
        'coupon_expiry_date': _expiryDateController.text,
        'coupon_issue_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'coupon_description': _descriptionController.text.trim(),
        'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      // API 호출
      final result = await ApiService.addDiscountCoupon(couponData);
      
      if (result['success'] == true) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('할인권이 성공적으로 증정되었습니다.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
        
        // 다이얼로그 닫기
        Navigator.of(context).pop();
      } else {
        throw Exception(result['error'] ?? '할인권 증정에 실패했습니다.');
      }
    } catch (e) {
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: ${e.toString()}'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF10B981),
                    Color(0xFF059669),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '할인권 증정',
                          style: AppTextStyles.h3.copyWith(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${widget.memberInfo?['member_name'] ?? '회원'}님께 할인권을 증정합니다',
                          style: AppTextStyles.cardSubtitle.copyWith(
                            fontFamily: 'Pretendard',
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 내용
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 할인권 유형 선택 (타일로 변경)
                      Text(
                        '할인권 유형',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: _couponTypes.map((type) {
                          final isSelected = _selectedCouponType == type;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: type != _couponTypes.last ? 8 : 0),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCouponType = type;
                                    _discountValueController.clear(); // 값 초기화
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFF10B981).withOpacity(0.1) : Colors.white,
                                    border: Border.all(
                                      color: isSelected ? Color(0xFF10B981) : Color(0xFFE2E8F0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        type == '정액권(타석)' ? Icons.attach_money :
                                        type == '정률권(타석)' ? Icons.percent :
                                        Icons.schedule,
                                        color: isSelected ? Color(0xFF10B981) : Color(0xFF64748B),
                                        size: 24,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        type,
                                        style: AppTextStyles.bodyTextSmall.copyWith(
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Color(0xFF10B981) : Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // 할인내용 입력
                      Text(
                        '할인내용',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _discountValueController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: _getHintText(),
                                hintStyle: AppTextStyles.bodyTextSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF9CA3AF),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Color(0xFF10B981)),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              style: AppTextStyles.formInput.copyWith(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF374151),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '할인내용을 입력해주세요';
                                }
                                final intValue = int.tryParse(value.trim());
                                if (intValue == null || intValue <= 0) {
                                  return '올바른 숫자를 입력해주세요';
                                }
                                if (_selectedCouponType == '정률권(타석)' && intValue > 100) {
                                  return '할인율은 100% 이하로 입력해주세요';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getUnitText(),
                              style: AppTextStyles.bodyTextSmall.copyWith(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // 유효기간 선택 (타일로 변경)
                      Text(
                        '유효기간',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: _expiryPeriods.map((period) {
                          final isSelected = _selectedExpiryPeriod == period['label'];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: period != _expiryPeriods.last ? 8 : 0),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedExpiryPeriod = period['label'];
                                    _updateExpiryDate();
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFF3B82F6).withOpacity(0.1) : Colors.white,
                                    border: Border.all(
                                      color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE2E8F0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: isSelected ? Color(0xFF3B82F6) : Color(0xFF64748B),
                                        size: 18,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        period['label'],
                                        style: AppTextStyles.cardBody.copyWith(
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Color(0xFF3B82F6) : Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '만료일: ${_expiryDateController.text}',
                                style: AppTextStyles.cardSubtitle.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // 적요 입력
                      Text(
                        '적요',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '할인권 증정 사유나 메모를 입력하세요',
                          hintStyle: AppTextStyles.bodyTextSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: Color(0xFF9CA3AF),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF10B981)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: AppTextStyles.formInput.copyWith(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 하단 버튼
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Color(0xFFE2E8F0),
                      foregroundColor: Color(0xFF64748B),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: AppTextStyles.modalButton.copyWith(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _showConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '증정 중...',
                                style: AppTextStyles.modalButton.copyWith(
                                  fontFamily: 'Pretendard',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '할인권 증정',
                            style: AppTextStyles.modalButton.copyWith(
                              fontFamily: 'Pretendard',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 