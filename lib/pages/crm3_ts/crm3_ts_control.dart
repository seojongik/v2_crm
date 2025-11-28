import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import '/models/ts_reservation.dart';
import '/pages/crm2_member/tab1_membership/member_page/member_main.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '../../constants/font_sizes.dart';
import 'crm3_ts_control_otp.dart';
import 'crm3_ts_control_time_adjust.dart';
import 'crm3_ts_control_ts_move.dart';
import 'crm3_ts_control_reservation_cancel.dart';

// Helper methods for missing API functionality (Supabase 마이그레이션 완료)
class _ApiHelper {
  static Future<List<Map<String, dynamic>>> getBillTimesData({
    List<Map<String, dynamic>>? where,
    String? orderBy,
    String? order,
    int? limit,
  }) async {
    try {
      List<Map<String, dynamic>>? orderByList;
      if (orderBy != null) {
        orderByList = [{'field': orderBy, 'direction': order ?? 'ASC'}];
      }

      return await SupabaseAdapter.getData(
        table: 'v2_bill_times',
        where: where,
        orderBy: orderByList,
        limit: limit,
      );
    } catch (e) {
      throw Exception('bill_times 데이터 조회 오류: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getBillGamesData({
    List<Map<String, dynamic>>? where,
    String? orderBy,
    String? order,
    int? limit,
  }) async {
    try {
      List<Map<String, dynamic>>? orderByList;
      if (orderBy != null) {
        orderByList = [{'field': orderBy, 'direction': order ?? 'ASC'}];
      }

      return await SupabaseAdapter.getData(
        table: 'v2_bill_games',
        where: where,
        orderBy: orderByList,
        limit: limit,
      );
    } catch (e) {
      throw Exception('bill_games 데이터 조회 오류: $e');
    }
  }
}

class TsReservationDetailDialog extends StatefulWidget {
  final TsReservation reservation;
  final VoidCallback? onDataChanged;

  const TsReservationDetailDialog({
    super.key,
    required this.reservation,
    this.onDataChanged,
  });

  @override
  State<TsReservationDetailDialog> createState() => _TsReservationDetailDialogState();
  
  // 정적 메서드로 팝업 표시
  static Future<void> show(BuildContext context, TsReservation reservation, {VoidCallback? onDataChanged}) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return TsReservationDetailDialog(
          reservation: reservation, 
          onDataChanged: onDataChanged,
        );
      },
    );
  }
}

class _TsReservationDetailDialogState extends State<TsReservationDetailDialog> {
  List<Map<String, dynamic>> usedCoupons = [];
  List<Map<String, dynamic>> issuedCoupons = [];
  bool isLoadingCoupons = true;
  
  // 메모 관련 변수
  late TextEditingController _memoController;
  bool _isEditingMemo = false;
  bool _isSavingMemo = false;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: widget.reservation.memo ?? '');
    _loadCouponData();
  }
  
  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  // 쿠폰 데이터 로드
  Future<void> _loadCouponData() async {
    if (widget.reservation.reservationId == null) {
      setState(() => isLoadingCoupons = false);
      return;
    }

    try {
      final coupons = await ApiService.getDiscountCouponsData(
        where: [
          {
            'field': 'reservation_id_used',
            'operator': '=',
            'value': widget.reservation.reservationId!,
          },
        ],
      );
      
      final issuedCouponsData = await ApiService.getDiscountCouponsData(
        where: [
          {
            'field': 'reservation_id_issued',
            'operator': '=',
            'value': widget.reservation.reservationId!,
          },
        ],
      );

      setState(() {
        usedCoupons = coupons.where((coupon) => coupon['coupon_status'] != '취소').toList();
        issuedCoupons = issuedCouponsData.where((coupon) => coupon['coupon_status'] != '취소').toList();
        isLoadingCoupons = false;
      });
    } catch (e) {
      print('쿠폰 데이터 로드 오류: $e');
      setState(() => isLoadingCoupons = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: 700),
        padding: EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '예약 상세 정보',
                    style: AppTextStyles.titleH3.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // 예약 정보 (시간 조정, 타석 이동 버튼 추가)
              _buildDetailSectionWithButtons(
                title: '예약 정보',
                icon: Icons.event,
                buttons: [
                  {
                    'text': '시간 조정', 
                    'onPressed': TsTimeAdjustService.isTimeAdjustmentEnabled(widget.reservation) 
                      ? () => TsTimeAdjustDialog.show(context, widget.reservation, widget.onDataChanged)
                      : () => _showDisabledActionDialog('시간 조정'),
                    'enabled': TsTimeAdjustService.isTimeAdjustmentEnabled(widget.reservation),
                  },
                  {
                    'text': '타석 이동', 
                    'onPressed': TsTsMoveService.isTsMoveEnabled(widget.reservation) 
                      ? () => TsTsMoveDialog.show(context, widget.reservation, widget.onDataChanged)
                      : () => _showDisabledActionDialog('타석 이동'),
                    'enabled': TsTsMoveService.isTsMoveEnabled(widget.reservation),
                  },
                ],
                children: [
                  _buildDetailRow('예약 ID', widget.reservation.reservationId ?? '-'),
                  _buildDetailRow('날짜', widget.reservation.formattedDate),
                  _buildDetailRow('시간', '${widget.reservation.tsId}번 타석 ${widget.reservation.formattedTimeRange}(${_calculateActualDuration()}분)'),
                  _buildDetailRow('타석', '${widget.reservation.tsId}번'),
                  _buildDetailRow('상태', widget.reservation.tsStatus ?? '-'),
                  if (widget.reservation.timeStamp != null)
                    _buildDetailRow('등록 시간', widget.reservation.timeStamp!),
                ],
              ),
              SizedBox(height: 20),
              
              // 메모 섹션 (독립적으로 분리)
              _buildMemoSection(),
              SizedBox(height: 20),
              
              // 회원 정보 (간단한 정보만)
              _buildDetailSectionWithButtons(
                title: '회원 정보',
                icon: Icons.person,
                buttons: [
                  if (widget.reservation.memberId != null)
                    {'text': '상세 조회', 'onPressed': () {
                      Navigator.of(context).pop(); // 현재 팝업 닫기
                      _showMemberDetailDialog(context, widget.reservation.memberId!, widget.reservation);
                    }},
                ],
                children: [
                  _buildDetailRow('회원명', widget.reservation.memberName ?? '미등록'),
                  _buildDetailRow('회원 타입', widget.reservation.memberType ?? '-'),
                  _buildDetailRow('전화번호', widget.reservation.memberPhone ?? '-'),
                  _buildDetailRow('회원 ID', widget.reservation.memberId?.toString() ?? '-'),
                ],
              ),
              SizedBox(height: 20),
              
              // OTP 섹션 (분리된 위젯 사용)
              TsOtpWidget(reservation: widget.reservation),
              
              // 결제 정보
              _buildDetailSection(
                title: '결제 정보',
                icon: Icons.payment,
                children: [
                  _buildDetailRow(
                    '결제 방법', 
                    widget.reservation.billId != null 
                      ? '${widget.reservation.tsPaymentMethod ?? '-'} (청구서 번호: ${widget.reservation.billId})'
                      : widget.reservation.tsPaymentMethod ?? '-'
                  ),
                  _buildDetailRow(
                    '결제액',
                    _getPaymentAmount(widget.reservation),
                  ),
                  _buildDetailRow(
                    '시간 조정',
                    _getTimeDifference(),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // 쿠폰 현황
              _buildDetailSection(
                title: '쿠폰 현황',
                icon: Icons.confirmation_number,
                children: [
                  if (isLoadingCoupons)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    )
                  else ...[
                    // 사용된 쿠폰
                    if (usedCoupons.isNotEmpty) ...[
                      Text(
                        '본 예약에 사용된 쿠폰',
                        style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      ...usedCoupons.map((coupon) => _buildCouponItem(coupon)).toList(),
                      SizedBox(height: 16),
                    ],
                    
                    // 발급된 쿠폰
                    if (issuedCoupons.isNotEmpty) ...[
                      Text(
                        '본 예약시 발급된 쿠폰',
                        style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      ...issuedCoupons.map((coupon) => _buildCouponItem(coupon)).toList(),
                    ],
                    
                    // 쿠폰이 없는 경우
                    if (usedCoupons.isEmpty && issuedCoupons.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            '쿠폰 내역이 없습니다',
                            style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 회원 상세 정보 팝업 표시
  void _showMemberDetailDialog(BuildContext context, int memberId, TsReservation reservation) {
    // 이미 가지고 있는 회원 정보로 memberData 구성
    final memberData = {
      'member_id': memberId,
      'member_name': reservation.memberName,
      'member_type': reservation.memberType,
      'member_phone': reservation.memberPhone,
    };
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24.0,
                  color: Color(0x1A000000),
                  offset: Offset(0.0, 8.0),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: MemberMainWidget(
                memberId: memberId,
                memberData: memberData, // 캐시된 데이터 전달
              ),
            ),
          ),
        );
      },
    );
  }

  // 메모 섹션 빌드
  Widget _buildMemoSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.note_alt,
                    size: 20,
                    color: Color(0xFF3B82F6),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '메모',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // 편집/저장 버튼
              _isEditingMemo
                  ? Row(
                      children: [
                        TextButton(
                          onPressed: _isSavingMemo
                              ? null
                              : () {
                                  setState(() {
                                    _memoController.text = widget.reservation.memo ?? '';
                                    _isEditingMemo = false;
                                  });
                                },
                          child: Text(
                            '취소',
                            style: AppTextStyles.bodyTextSmall.copyWith(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSavingMemo ? null : _saveMemo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3B82F6),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isSavingMemo
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  '저장',
                                  style: AppTextStyles.bodyTextSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    )
                  : IconButton(
                      onPressed: () {
                        setState(() {
                          _isEditingMemo = true;
                        });
                      },
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
            ],
          ),
          SizedBox(height: 12),
          // 메모 입력/표시 영역
          _isEditingMemo
              ? TextField(
                  controller: _memoController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '메모를 입력하세요',
                    hintStyle: AppTextStyles.bodyTextSmall.copyWith(
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: AppTextStyles.bodyTextSmall.copyWith(
                    color: Colors.black,
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _memoController.text.isEmpty ? '메모가 없습니다' : _memoController.text,
                    style: AppTextStyles.bodyTextSmall.copyWith(
                      color: _memoController.text.isEmpty ? Color(0xFF94A3B8) : Color(0xFF1E293B),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
  
  // 메모 저장 함수
  Future<void> _saveMemo() async {
    setState(() {
      _isSavingMemo = true;
    });
    
    try {
      // v2_priced_TS 테이블의 memo 필드 업데이트 (예약취소 상태가 아닌 레코드만)
      final result = await ApiService.updateData(
        table: 'v2_priced_TS',
        data: {
          'memo': _memoController.text,
        },
        where: [
          {
            'field': 'reservation_id',
            'operator': '=',
            'value': widget.reservation.reservationId,
          },
          {
            'field': 'ts_status',
            'operator': '<>',
            'value': '예약취소',
          },
        ],
      );
      
      if (result['success'] == true) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메모가 저장되었습니다'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        
        // 편집 모드 종료
        setState(() {
          _isEditingMemo = false;
        });
        
        // 데이터 새로고침 콜백 호출
        widget.onDataChanged?.call();
      } else {
        throw Exception('메모 저장 실패');
      }
    } catch (e) {
      // 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메모 저장 중 오류가 발생했습니다'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        _isSavingMemo = false;
      });
    }
  }
  
  // 상세 정보 섹션 빌드
  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20.0,
                color: Color(0xFF3B82F6),
              ),
              SizedBox(width: 8.0),
              Text(
                title,
                style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12.0),
          ...children,
        ],
      ),
    );
  }

  // 여러 버튼이 있는 상세 정보 섹션 빌드
  Widget _buildDetailSectionWithButtons({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required List<Map<String, dynamic>> buttons,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20.0,
                    color: Color(0xFF3B82F6),
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    title,
                    style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // 버튼들
              Row(
                children: buttons.map((button) {
                  final enabled = button['enabled'] ?? true;
                  final text = button['text'] as String;
                  
                  // 버튼별 아이콘 설정
                  IconData buttonIcon;
                  Color buttonColor;
                  
                  switch (text) {
                    case '시간 조정':
                      buttonIcon = Icons.access_time_rounded;
                      buttonColor = enabled ? Color(0xFF10B981) : Color(0xFFF1F5F9);
                      break;
                    case '타석 이동':
                      buttonIcon = Icons.swap_horiz_rounded;
                      buttonColor = enabled ? Color(0xFFF59E0B) : Color(0xFFF1F5F9);
                      break;
                    case '상세 조회':
                      buttonIcon = Icons.visibility_rounded;
                      buttonColor = enabled ? Color(0xFF6366F1) : Color(0xFFF1F5F9);
                      break;
                    default:
                      buttonIcon = Icons.settings;
                      buttonColor = enabled ? Color(0xFF3B82F6) : Color(0xFFF1F5F9);
                  }
                  
                  return Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: button['onPressed'],
                      icon: Icon(
                        buttonIcon,
                        size: 18.0,
                        color: enabled ? Colors.white : Color(0xFFCBD5E1),
                      ),
                      label: Text(
                        text,
                        style: AppTextStyles.bodyTextSmall.copyWith(color: enabled ? Colors.white : Color(0xFFCBD5E1), fontWeight: enabled ? FontWeight.w600 : FontWeight.w400),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: enabled ? BorderSide.none : BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        minimumSize: Size(120, 42),
                        elevation: enabled ? 3.0 : 0.0,
                        shadowColor: Colors.black.withOpacity(0.1),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: 12.0),
          ...children,
        ],
      ),
    );
  }

  // 상세 정보 행 빌드
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.0,
            child: Text(
              label,
              style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  // 결제액 표시 헬퍼 메서드
  String _getPaymentAmount(TsReservation reservation) {
    // 결제 방법에 따라 적절한 값 반환
    switch (reservation.tsPaymentMethod) {
      case '선불크레딧':
        // 크레딧은 net_amt 사용 (원 단위)
        if (reservation.netAmt != null) {
          return NumberFormat('#,###원').format(reservation.netAmt!.abs());
        }
        return '0원';
        
      case '시간권':
      case '게임권':
      case '프로그램':
        // 시간권, 게임권, 프로그램은 bill_min 사용 (분 단위)
        if (reservation.billMin != null) {
          return '${reservation.billMin}분';
        }
        return '0분';
        
      default:
        // 기타 결제 방법은 net_amt를 원 단위로 표시
        if (reservation.netAmt != null) {
          return NumberFormat('#,###원').format(reservation.netAmt!.abs());
        }
        return '0원';
    }
  }

  // 시간 차이 표시 (과금시간 vs 실제시간)
  String _getTimeDifference() {
    final tsMin = widget.reservation.tsMin ?? 0; // 과금 시간
    final actualMinutes = _calculateActualDuration(); // 실제 사용 시간
    final difference = actualMinutes - tsMin;
    
    if (difference > 0) {
      return '추가시간 ${difference}분';
    } else if (difference < 0) {
      return '반납시간 ${difference.abs()}분';
    } else {
      return '정시 이용';
    }
  }





  // 시간 파싱 헬퍼
  DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
    return now;
  }

  // 예약 날짜를 고려한 시간 파싱
  DateTime _parseTimeWithDate(String timeStr, String dateStr) {
    final date = DateTime.parse(dateStr);
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return date;
  }

  // 남은 시간 계산
  int _calculateRemainingMinutes(DateTime now, DateTime endTime) {
    // 종료 시간이 현재 시간보다 이전이면 0 반환
    if (endTime.isBefore(now)) return 0;
    return endTime.difference(now).inMinutes;
  }



  // 비활성화된 액션에 대한 안내 다이얼로그
  void _showDisabledActionDialog(String actionName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF64748B),
                size: 48.0,
              ),
              SizedBox(height: 16.0),
              Text(
                '${actionName} 불가',
                style: AppTextStyles.bodyText.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8.0),
              Text(
                '예약 시간이 지난 후에는 ${actionName}을 할 수 없습니다.',
                style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '확인',
                style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // 실제 예약 시간 계산 (시작시간과 종료시간을 기반으로)
  int _calculateActualDuration() {
    if (widget.reservation.tsStart == null || widget.reservation.tsEnd == null) {
      return widget.reservation.tsMin ?? 0;
    }
    
    final startTime = _parseTime(widget.reservation.tsStart!);
    final endTime = _parseTime(widget.reservation.tsEnd!);
    
    return endTime.difference(startTime).inMinutes;
  }

  // v2_bills 잔액 재계산
  Future<void> _recalculateBillBalances(int contractHistoryId, int fromBillId) async {
    try {
      print('\n=== bills 잔액 재계산 시작 ===');
      
      // 변경된 bill_id부터 이후 bills를 조회
      final billsToRecalculate = await ApiService.getBillsData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '>=', 'value': fromBillId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'ASC'}],
      );
      
      print('재계산할 bills 수: ${billsToRecalculate.length}');
      
      // 시작점 계산을 위해 이전 bill의 balance_after 조회
      int runningBalance = 0;
      final previousBills = await ApiService.getBillsData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_id', 'operator': '<', 'value': fromBillId}
        ],
        orderBy: [{'field': 'bill_id', 'direction': 'DESC'}],
        limit: 1,
      );
      
      if (previousBills.isNotEmpty) {
        runningBalance = (previousBills[0]['bill_balance_after'] ?? 0) as int;
      }
      
      // 순차적으로 balance 재계산
      for (var bill in billsToRecalculate) {
        final billId = bill['bill_id'];
        final netAmt = (bill['bill_netamt'] ?? 0) as int;
        
        final newBalanceBefore = runningBalance;
        final newBalanceAfter = runningBalance + netAmt;
        
        await ApiService.updateBillsData(
          {
            'bill_balance_before': newBalanceBefore,
            'bill_balance_after': newBalanceAfter,
          },
          [
            {'field': 'bill_id', 'operator': '=', 'value': billId}
          ]
        );
        
        print('✅ bill_id $billId: before=$newBalanceBefore, after=$newBalanceAfter (netamt=$netAmt)');
        runningBalance = newBalanceAfter;
      }
      
      print('=== bills 잔액 재계산 완료 ===\n');
      
    } catch (e) {
      print('bills 잔액 재계산 오류: $e');
      throw e;
    }
  }

  // v2_bill_times 잔액 재계산
  Future<void> _recalculateBillTimesBalances(int contractHistoryId, int fromBillMinId) async {
    try {
      print('\n=== bill_times 잔액 재계산 시작 ===');
      
      // 변경된 bill_min_id부터 이후 bill_times를 조회
      final billTimesToRecalculate = await _ApiHelper.getBillTimesData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '>=', 'value': fromBillMinId}
        ],
        orderBy: 'bill_min_id',
        order: 'ASC',
      );
      
      print('재계산할 bill_times 수: ${billTimesToRecalculate.length}');
      
      // 시작점 계산을 위해 이전 bill_times의 balance_min_after 조회
      int runningBalance = 0;
      final previousBillTimes = await _ApiHelper.getBillTimesData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_min_id', 'operator': '<', 'value': fromBillMinId}
        ],
        orderBy: 'bill_min_id',
        order: 'DESC',
        limit: 1,
      );
      
      if (previousBillTimes.isNotEmpty) {
        runningBalance = (previousBillTimes[0]['bill_balance_min_after'] ?? 0) as int;
      }
      
      // 순차적으로 balance 재계산
      for (var billTime in billTimesToRecalculate) {
        final billMinId = billTime['bill_min_id'];
        final billMin = (billTime['bill_min'] ?? 0) as int;
        
        final newBalanceMinBefore = runningBalance;
        final newBalanceMinAfter = runningBalance - billMin;
        
        await ApiService.updateBillTimesData(
          {
            'bill_balance_min_before': newBalanceMinBefore,
            'bill_balance_min_after': newBalanceMinAfter,
          },
          [
            {'field': 'bill_min_id', 'operator': '=', 'value': billMinId}
          ]
        );
        
        print('✅ bill_min_id $billMinId: before=${newBalanceMinBefore}분, after=${newBalanceMinAfter}분 (사용=${billMin}분)');
        runningBalance = newBalanceMinAfter;
      }
      
      print('=== bill_times 잔액 재계산 완료 ===\n');
      
    } catch (e) {
      print('bill_times 잔액 재계산 오류: $e');
      throw e;
    }
  }

  // v2_bill_games 잔액 재계산
  Future<void> _recalculateBillGamesBalances(int contractHistoryId, int fromBillGameId) async {
    try {
      print('\n=== bill_games 잔액 재계산 시작 ===');
      
      // 변경된 bill_game_id부터 이후 bill_games를 조회
      final billGamesToRecalculate = await _ApiHelper.getBillGamesData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_game_id', 'operator': '>=', 'value': fromBillGameId}
        ],
        orderBy: 'bill_game_id',
        order: 'ASC',
      );
      
      print('재계산할 bill_games 수: ${billGamesToRecalculate.length}');
      
      // 시작점 계산을 위해 이전 bill_games의 balance_game_after 조회
      int runningBalanceGames = 0;
      final previousBillGames = await _ApiHelper.getBillGamesData(
        where: [
          {'field': 'contract_history_id', 'operator': '=', 'value': contractHistoryId},
          {'field': 'bill_game_id', 'operator': '<', 'value': fromBillGameId}
        ],
        orderBy: 'bill_game_id',
        order: 'DESC',
        limit: 1,
      );
      
      if (previousBillGames.isNotEmpty) {
        runningBalanceGames = previousBillGames[0]['bill_balance_game_after'] ?? 0;
        print('이전 잔액: ${runningBalanceGames}게임');
      }
      
      // 각 bill_games 순차적으로 재계산
      for (var billGame in billGamesToRecalculate) {
        final billGameValue = billGame['bill_game'] ?? 0;
        final newBalanceGameBefore = runningBalanceGames;
        final newBalanceGameAfter = runningBalanceGames - billGameValue; // 게임은 항상 차감
        
        // 잔액 업데이트
        await ApiService.updateBillGamesData(
          {
            'bill_balance_game_before': newBalanceGameBefore,
            'bill_balance_game_after': newBalanceGameAfter,
          },
          [
            {'field': 'bill_game_id', 'operator': '=', 'value': billGame['bill_game_id']}
          ]
        );
        
        print('bill_game_id ${billGame['bill_game_id']}: $newBalanceGameBefore → $newBalanceGameAfter (${billGameValue}게임 차감)');
        
        // 다음 계산을 위해 현재 잔액 업데이트
        runningBalanceGames = newBalanceGameAfter.toInt();
      }
      
      print('=== bill_games 잔액 재계산 완료 ===\n');
      
    } catch (e) {
      print('bill_games 잔액 재계산 오류: $e');
      throw e;
    }
  }


  // 쿠폰 아이템 빌드
  Widget _buildCouponItem(Map<String, dynamic> coupon) {
    final couponType = coupon['coupon_type'] ?? '';
    final description = coupon['coupon_description'] ?? '';
    final expiryDate = coupon['coupon_expiry_date'] ?? '';
    final issueDate = coupon['coupon_issue_date'] ?? '';
    
    // 쿠폰 타입에 따른 할인 정보
    String discountInfo = '';
    switch (couponType) {
      case '정률권':
        if (coupon['discount_ratio'] != null) {
          discountInfo = '${coupon['discount_ratio']}% 할인';
        }
        break;
      case '정액권':
        if (coupon['discount_amt'] != null) {
          discountInfo = '${NumberFormat('#,###').format(coupon['discount_amt'])}원 할인';
        }
        break;
      case '시간권':
        if (coupon['discount_min'] != null) {
          discountInfo = '${coupon['discount_min']}분 할인';
        }
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 쿠폰 설명과 할인 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 첫 줄: 쿠폰 설명
                Text(
                  description.isNotEmpty ? description : '쿠폰',
                  style: AppTextStyles.cardTitle.copyWith(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                // 둘째 줄: 쿠폰 타입과 할인 정보
                if (discountInfo.isNotEmpty)
                  Row(
                    children: [
                      // 쿠폰 타입
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          couponType,
                          style: AppTextStyles.cardMeta.copyWith(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 8),
                      // 할인 정보
                      Text(
                        discountInfo,
                        style: AppTextStyles.bodyTextSmall.copyWith(color: Color(0xFF059669), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // 오른쪽: 날짜 정보
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (issueDate.isNotEmpty)
                Text(
                  '발행: $issueDate',
                  style: AppTextStyles.cardMeta.copyWith(color: Color(0xFF64748B)),
                ),
              if (expiryDate.isNotEmpty)
                Text(
                  '만료: $expiryDate',
                  style: AppTextStyles.cardMeta.copyWith(color: Color(0xFF64748B)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}