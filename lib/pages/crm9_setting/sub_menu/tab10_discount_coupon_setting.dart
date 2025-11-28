import '../../../constants/font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../services/upper_button_input_design.dart';
import 'package:intl/intl.dart';
import '/services/supabase_adapter.dart';

class Tab10DiscountCouponSettingWidget extends StatefulWidget {
  const Tab10DiscountCouponSettingWidget({super.key});

  @override
  State<Tab10DiscountCouponSettingWidget> createState() => _Tab10DiscountCouponSettingWidgetState();
}

class _Tab10DiscountCouponSettingWidgetState extends State<Tab10DiscountCouponSettingWidget> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _availableTriggers = [];
  bool _showInactiveCoupons = false;
  
  @override
  void initState() {
    super.initState();
    _loadCoupons();
    _loadAutoTriggers();
  }
  
  // 다음 쿠폰 코드 자동 생성
  Future<String> _getNextCouponCode() async {
    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null || currentBranchId.isEmpty) {
        throw Exception('브랜치 정보가 없습니다');
      }
      
      final data = await SupabaseAdapter.getData(
        table: 'v2_discount_coupon_setting',
        fields: ['coupon_code'],
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId},
        ],
      );

      // 현재 브랜치의 쿠폰 코드 패턴 찾기
      final branchPrefix = '${currentBranchId}_';
      int maxNum = 0;

      for (var coupon in data) {
        final couponCode = coupon['coupon_code'].toString();

        if (couponCode.startsWith(branchPrefix)) {
          final numPart = couponCode.substring(branchPrefix.length);
          final num = int.tryParse(numPart) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }

      // 다음 번호 생성 (3자리 패딩)
      final nextNum = maxNum + 1;
      final nextCode = '${branchPrefix}${nextNum.toString().padLeft(3, '0')}';

      return nextCode;
      
      // 첫 번째 쿠폰인 경우
      return '${currentBranchId}_001';
    } catch (e) {
      print('❌ 쿠폰 코드 생성 오류: $e');
      final currentBranchId = ApiService.getCurrentBranchId() ?? 'unknown';
      return '${currentBranchId}_001';
    }
  }
  
  // 쿠폰 데이터 로드
  Future<void> _loadCoupons() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final branchId = ApiService.getCurrentBranchId();
      print('🔍 현재 branch_id: $branchId');
      
      if (branchId == null || branchId.isEmpty) {
        throw Exception('branch_id가 설정되지 않았습니다.');
      }
      
      List<Map<String, dynamic>> whereConditions = [
        {'field': 'branch_id', 'operator': '=', 'value': branchId},
      ];
      
      // 비활성 쿠폰 표시 옵션에 따라 필터 조건 추가
      if (!_showInactiveCoupons) {
        whereConditions.add({'field': 'setting_status', 'operator': '=', 'value': '유효'});
      }
      
      final data = await SupabaseAdapter.getData(
        table: 'v2_discount_coupon_setting',
        where: whereConditions,
        orderBy: [
          {'field': 'setting_status', 'direction': 'DESC'}, // 유효한 것부터
          {'field': 'coupon_code', 'direction': 'ASC'}
        ],
      );

      setState(() {
        _coupons = data.cast<Map<String, dynamic>>();
      });
      print('✅ 쿠폰 ${_coupons.length}개 로드 완료');
      if (_coupons.isNotEmpty) {
        print('🔧 첫 번째 쿠폰 데이터 키 확인: ${_coupons[0].keys.toList()}');
      }
    } catch (e) {
      print('❌ 쿠폰 로드 오류: $e');
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 자동발행 트리거 로드
  Future<void> _loadAutoTriggers() async {
    try {
      final data = await SupabaseAdapter.getData(
        table: 'v2_discount_coupon_auto_triggers',
        where: [
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ],
        orderBy: [
          {'field': 'trigger_id', 'direction': 'ASC'}
        ],
      );

      setState(() {
        _availableTriggers = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('❌ 자동발행 트리거 로드 오류: $e');
    }
  }
  
  // 쿠폰 추가/수정 다이얼로그 표시
  void _showCouponDialog({Map<String, dynamic>? coupon}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CouponDialog(
          coupon: coupon,
          onSave: (couponData) async {
            if (coupon != null) {
              print('🔧 수정 모드 - coupon 데이터: ${coupon.keys.toList()}');
              final couponCode = coupon['coupon_code'];
              if (couponCode != null) {
                await _updateCoupon(couponCode, couponData);
              } else {
                throw Exception('coupon_code가 없습니다');
              }
            } else {
              await _addCoupon(couponData);
            }
          },
          onDelete: coupon != null ? () async {
            await _deleteCoupon(coupon);
          } : null,
        );
      },
    );
  }
  
  // 쿠폰 추가
  Future<void> _addCoupon(Map<String, dynamic> couponData) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 쿠폰 코드 자동 생성
      final couponCode = await _getNextCouponCode();
      couponData['coupon_code'] = couponCode;
      couponData['branch_id'] = ApiService.getCurrentBranchId();
      couponData['updated_at'] = DateTime.now().toIso8601String();
      couponData['setting_status'] = '유효';
      
      print('🔧 API 저장 데이터: $couponData');

      await SupabaseAdapter.addData(
        table: 'v2_discount_coupon_setting',
        data: couponData,
      );

      _showSuccessSnackBar('쿠폰이 추가되었습니다.');
      _loadCoupons();
    } catch (e) {
      print('❌ 쿠폰 추가 오류: $e');
      _showErrorSnackBar('쿠폰 추가에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 쿠폰 수정
  Future<void> _updateCoupon(dynamic couponIdOrCode, Map<String, dynamic> updateData) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      updateData['updated_at'] = DateTime.now().toIso8601String();
      
      print('🔧 API 수정 데이터: $updateData');

      await SupabaseAdapter.updateData(
        table: 'v2_discount_coupon_setting',
        data: updateData,
        where: [
          {'field': 'coupon_code', 'operator': '=', 'value': couponIdOrCode},
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        ],
      );

      _showSuccessSnackBar('쿠폰이 수정되었습니다.');
      _loadCoupons();
    } catch (e) {
      print('❌ 쿠폰 수정 오류: $e');
      _showErrorSnackBar('쿠폰 수정에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 쿠폰 삭제
  Future<void> _deleteCoupon(Map<String, dynamic> coupon) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await SupabaseAdapter.updateData(
        table: 'v2_discount_coupon_setting',
        data: {
          'setting_status': '무효',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: [
          {'field': 'coupon_code', 'operator': '=', 'value': coupon['coupon_code']},
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()},
        ],
      );

      _showSuccessSnackBar('쿠폰이 비활성화되었습니다.');
      _loadCoupons();
    } catch (e) {
      print('❌ 쿠폰 비활성화 오류: $e');
      _showErrorSnackBar('쿠폰 비활성화에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        backgroundColor: Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  // 쿠폰 타입별 표시 텍스트 생성
  String _getCouponDisplayText(Map<String, dynamic> coupon) {
    switch (coupon['coupon_type']) {
      case '정률권':
        return '${coupon['discount_ratio']}% 할인';
      case '정액권':
        return '${NumberFormat('#,###').format(coupon['discount_amt'] ?? 0)}원 할인';
      case '시간권':
        return '${coupon['discount_min']}분 시간할인';
      default:
        return '할인 쿠폰';
    }
  }
  
  bool _isAutoIssueCoupon(Map<String, dynamic> coupon) {
    final triggerIds = coupon['trigger_id']?.toString() ?? '';
    if (triggerIds.isEmpty) {
      return false;
    }
    
    final triggerIdList = triggerIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return triggerIdList.isNotEmpty;
  }
  
  String _getAutoTriggerText(Map<String, dynamic> coupon) {
    final triggerIds = coupon['trigger_id']?.toString() ?? '';
    if (triggerIds.isEmpty) {
      return '수동발행';
    }
    
    final triggerIdList = triggerIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (triggerIdList.isEmpty) {
      return '수동발행';
    }
    
    if (_availableTriggers.isEmpty) {
      return '자동발행 : 설정됨';
    }
    
    final matchedTriggers = _availableTriggers.where((trigger) => 
      triggerIdList.contains(trigger['trigger_id']?.toString())
    ).toList();
    
    if (matchedTriggers.isEmpty) {
      return '자동발행 : 설정됨';
    }
    
    if (matchedTriggers.length == 1) {
      return '자동발행 : ${matchedTriggers[0]['trigger_discription'] ?? '조건 설정됨'}';
    } else {
      return '자동발행 : ${matchedTriggers[0]['trigger_discription']} 외 ${matchedTriggers.length - 1}건';
    }
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
              // 왼쪽: 새 쿠폰 등록 버튼
              ButtonDesignUpper.buildIconButton(
                text: '새 쿠폰 등록',
                icon: Icons.confirmation_number,
                onPressed: () => _showCouponDialog(),
                color: 'orange',
                size: 'large',
              ),
              // 오른쪽: 비활성 쿠폰 토글
              Row(
                children: [
                  Text(
                    '비활성 표시',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF64748B),
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Switch(
                    value: _showInactiveCoupons,
                    onChanged: (value) {
                      setState(() {
                        _showInactiveCoupons = value;
                      });
                      _loadCoupons();
                    },
                    activeColor: Color(0xFF6366F1),
                    activeTrackColor: Color(0xFF6366F1).withOpacity(0.3),
                    inactiveThumbColor: Color(0xFF94A3B8),
                    inactiveTrackColor: Color(0xFFE2E8F0),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 24),
        
        // 쿠폰 목록
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _coupons.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '등록된 쿠폰이 없습니다.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '새 쿠폰을 등록하여 관리하세요.',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _coupons.length,
                      itemBuilder: (context, index) {
                        final coupon = _coupons[index];
                        final isActive = coupon['setting_status'] == '유효';
                        final isAutoIssue = _isAutoIssueCoupon(coupon);
                        
                        return InkWell(
                          onTap: () => _showCouponDialog(coupon: coupon),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAutoIssue 
                                  ? (isActive ? Color(0xFF3B82F6).withOpacity(0.4) : Color(0xFF3B82F6).withOpacity(0.2))
                                  : (isActive ? Color(0xFF22C55E).withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                                width: isAutoIssue ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isAutoIssue 
                                    ? Color(0xFF3B82F6).withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                  blurRadius: isAutoIssue ? 12 : 8,
                                  offset: Offset(0, isAutoIssue ? 3 : 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // 배경 패턴
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.confirmation_number,
                                    size: 100,
                                    color: Colors.grey[100],
                                  ),
                                ),
                                // 자동발행 배지
                                if (isAutoIssue)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(8),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFF3B82F6).withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bolt,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'AUTO',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // 콘텐츠
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 8),
                                      // 쿠폰명
                                      Text(
                                        coupon['coupon_description'] ?? '쿠폰명 없음',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 6),
                                      // 할인 정보
                                      Text(
                                        _getCouponDisplayText(coupon),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      // 쿠폰 타입과 유효기간을 한 줄에
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF3B82F6).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${coupon['coupon_type'] ?? '정액권'}',
                                              style: TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFF59E0B).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '유효기간 ${coupon['coupon_expiry_days'] ?? 0}일',
                                              style: TextStyle(
                                                color: Color(0xFFF59E0B),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      // 발행 방식 정보
                                      Text(
                                        _getAutoTriggerText(coupon),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Spacer(),
                                      Row(
                                        children: [
                                          Spacer(),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isActive ? Color(0xFFF0FDF4) : Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isActive ? '활성' : '비활성',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isActive ? Color(0xFF059669) : Color(0xFFEF4444),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 수정 버튼 오버레이
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// 쿠폰 추가/수정 다이얼로그
class CouponDialog extends StatefulWidget {
  final Map<String, dynamic>? coupon;
  final Function(Map<String, dynamic>) onSave;
  final Function()? onDelete;

  const CouponDialog({
    super.key,
    this.coupon,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends State<CouponDialog> {
  final TextEditingController _discountRatioController = TextEditingController();
  final TextEditingController _discountAmtController = TextEditingController();
  final TextEditingController _discountMinController = TextEditingController();
  final TextEditingController _couponExpiryDaysController = TextEditingController();
  final TextEditingController _couponDescriptionController = TextEditingController();
  
  String _selectedCouponType = '정액권';
  bool _multipleCouponUse = true;
  int _settingStatus = 1;
  List<String> _selectedTriggerIds = [];
  List<Map<String, dynamic>> _availableTriggers = [];
  bool _isLoadingTriggers = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.coupon != null) {
      _selectedCouponType = widget.coupon!['coupon_type'] ?? '정액권';
      _discountRatioController.text = widget.coupon!['discount_ratio']?.toString() ?? '';
      _discountAmtController.text = widget.coupon!['discount_amt']?.toString() ?? '';
      _discountMinController.text = widget.coupon!['discount_min']?.toString() ?? '';
      _couponExpiryDaysController.text = widget.coupon!['coupon_expiry_days']?.toString() ?? '';
      _couponDescriptionController.text = widget.coupon!['coupon_description'] ?? '';
      _multipleCouponUse = widget.coupon!['multiple_coupon_use'] == '가능';
      _settingStatus = widget.coupon!['setting_status'] == '유효' ? 1 : 0;
      
      // trigger_id 파싱
      final triggerIds = widget.coupon!['trigger_id']?.toString() ?? '';
      print('🔧 수정모드 - 원본 trigger_id: $triggerIds');
      if (triggerIds.isNotEmpty) {
        _selectedTriggerIds = triggerIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        print('🔧 수정모드 - 파싱된 trigger_id 리스트: $_selectedTriggerIds');
      }
    }
    _loadAutoTriggers();
  }
  
  @override
  void dispose() {
    _discountRatioController.dispose();
    _discountAmtController.dispose();
    _discountMinController.dispose();
    _couponExpiryDaysController.dispose();
    _couponDescriptionController.dispose();
    super.dispose();
  }
  
  // 자동발행 트리거 로드
  Future<void> _loadAutoTriggers() async {
    setState(() {
      _isLoadingTriggers = true;
    });
    
    try {
      final data = await SupabaseAdapter.getData(
        table: 'v2_discount_coupon_auto_triggers',
        where: [
          {'field': 'setting_status', 'operator': '=', 'value': '유효'},
        ],
        orderBy: [
          {'field': 'trigger_id', 'direction': 'ASC'}
        ],
      );

      setState(() {
        _availableTriggers = data.cast<Map<String, dynamic>>();
      });
      print('🔧 CouponDialog - 트리거 로드 완료: ${_availableTriggers.length}개');
      print('🔧 CouponDialog - 현재 선택된 트리거: $_selectedTriggerIds');
    } catch (e) {
      print('❌ CouponDialog - 자동발행 트리거 로드 오류: $e');
    } finally {
      setState(() {
        _isLoadingTriggers = false;
      });
    }
  }
  
  // 테이블 헤더 위젯
  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF374151),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  // 테이블 셀 위젯
  Widget _buildTableCell(String text) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.coupon != null;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEdit ? '쿠폰 수정' : '쿠폰 추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isEdit) ...[
                    SizedBox(width: 20),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.coupon!['coupon_code'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 콘텐츠
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 기본 설정을 컴팩트하게 배치
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기본 설정',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // 쿠폰명 (맨 위로)
                          Text('쿠폰명', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                          SizedBox(height: 4),
                          TextField(
                            controller: _couponDescriptionController,
                            decoration: InputDecoration(
                              hintText: '쿠폰명을 입력하세요',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            style: TextStyle(color: Color(0xFF374151), fontSize: 14),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // 상태와 쿠폰 타입을 한 줄에
                          Row(
                            children: [
                              // 상태 설정 (수정 모드에서만)
                              if (isEdit) ...[
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('쿠폰 상태', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Radio<int>(
                                            value: 1, 
                                            groupValue: _settingStatus, 
                                            onChanged: (v) => setState(() => _settingStatus = v!),
                                            activeColor: Color(0xFF059669),
                                          ),
                                          Text('활성', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                          SizedBox(width: 8),
                                          Radio<int>(
                                            value: 0, 
                                            groupValue: _settingStatus, 
                                            onChanged: (v) => setState(() => _settingStatus = v!),
                                            activeColor: Color(0xFF6B7280),
                                          ),
                                          Text('비활성', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
                              ],
                              
                              // 쿠폰 타입
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('할인 타입', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Radio<String>(
                                          value: '정액권', 
                                          groupValue: _selectedCouponType, 
                                          onChanged: (v) => setState(() => _selectedCouponType = v!),
                                          activeColor: Color(0xFF3B82F6),
                                        ),
                                        Text('정액권', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                        SizedBox(width: 4),
                                        Radio<String>(
                                          value: '정률권', 
                                          groupValue: _selectedCouponType, 
                                          onChanged: (v) => setState(() => _selectedCouponType = v!),
                                          activeColor: Color(0xFF8B5CF6),
                                        ),
                                        Text('정률권', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                        SizedBox(width: 4),
                                        Radio<String>(
                                          value: '시간권', 
                                          groupValue: _selectedCouponType, 
                                          onChanged: (v) => setState(() => _selectedCouponType = v!),
                                          activeColor: Color(0xFFF59E0B),
                                        ),
                                        Text('시간권', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          // 할인값, 유효기간, 중복사용을 한 줄에
                          Row(
                            children: [
                              // 할인 금액/비율/시간
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCouponType == '정률권' ? '할인율 (%)' : 
                                      _selectedCouponType == '정액권' ? '할인 금액' : '할인 시간(분)',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                                    ),
                                    SizedBox(height: 4),
                                    TextField(
                                      controller: _selectedCouponType == '정률권' ? _discountRatioController :
                                                 _selectedCouponType == '정액권' ? _discountAmtController : _discountMinController,
                                      decoration: InputDecoration(
                                        hintText: _selectedCouponType == '정률권' ? '10' : 
                                                 _selectedCouponType == '정액권' ? '1000' : '10',
                                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixText: _selectedCouponType == '정률권' ? '%' :
                                                   _selectedCouponType == '정액권' ? '원' : '분',
                                        suffixStyle: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      style: TextStyle(color: Color(0xFF374151), fontSize: 14),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: _selectedCouponType == '정액권' ? [
                                        FilteringTextInputFormatter.digitsOnly,
                                        ThousandsSeparatorInputFormatter(),
                                      ] : [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              
                              // 유효기간
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('유효기간', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                    SizedBox(height: 4),
                                    TextField(
                                      controller: _couponExpiryDaysController,
                                      decoration: InputDecoration(
                                        hintText: '7',
                                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixText: '일',
                                        suffixStyle: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      style: TextStyle(color: Color(0xFF374151), fontSize: 14),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              
                              // 중복 사용 가능
                              Container(
                                width: 120,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('중복 사용', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                    SizedBox(height: 4),
                                    CheckboxListTile(
                                      title: Text('가능', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
                                      value: _multipleCouponUse,
                                      onChanged: (value) => setState(() => _multipleCouponUse = value!),
                                      activeColor: Color(0xFF3B82F6),
                                      checkColor: Colors.white,
                                      side: BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 자동발행 설정
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '자동발행 설정',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // 트리거 테이블
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: _isLoadingTriggers
                                ? Container(
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                : Column(
                                    children: [
                                      // 헤더
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            topRight: Radius.circular(6),
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: Text('선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text('발행 조건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text('트리거', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 데이터 행들
                                      if (_availableTriggers.isEmpty)
                                        Container(
                                          height: 100,
                                          child: Center(
                                            child: Text(
                                              '등록된 자동발행 트리거가 없습니다.',
                                              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          height: 200,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              children: _availableTriggers.map((trigger) {
                                                final triggerId = trigger['trigger_id']?.toString() ?? '';
                                                final isSelected = _selectedTriggerIds.contains(triggerId);
                                                
                                                return InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      if (isSelected) {
                                                        _selectedTriggerIds.remove(triggerId);
                                                      } else {
                                                        _selectedTriggerIds.add(triggerId);
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(color: Color(0xFFE5E7EB)),
                                                      ),
                                                    ),
                                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 1,
                                                          child: Checkbox(
                                                            value: isSelected,
                                                            activeColor: Color(0xFF3B82F6),
                                                            checkColor: Colors.white,
                                                            side: BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                                            onChanged: (value) {
                                                              setState(() {
                                                                if (value!) {
                                                                  _selectedTriggerIds.add(triggerId);
                                                                  print('🔧 트리거 추가: $triggerId, 현재 리스트: $_selectedTriggerIds');
                                                                } else {
                                                                  _selectedTriggerIds.remove(triggerId);
                                                                  print('🔧 트리거 제거: $triggerId, 현재 리스트: $_selectedTriggerIds');
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            trigger['trigger_discription'] ?? '',
                                                            style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Color(0xFFEBF5FF),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              trigger['trigger'] ?? '',
                                                              style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6)),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 액션 버튼
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isEdit && widget.onDelete != null)
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: Text('쿠폰 삭제', style: TextStyle(color: Color(0xFF374151))),
                            content: Text('이 쿠폰을 삭제하시겠습니까?', style: TextStyle(color: Color(0xFF6B7280))),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFF6B7280),
                                ),
                                child: Text('취소'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                  widget.onDelete!();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFFEF4444),
                                ),
                                child: Text('삭제', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFFEF4444),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: Icon(Icons.delete_outline, size: 18),
                      label: Text('삭제', style: TextStyle(fontWeight: FontWeight.w500)),
                    )
                  else
                    SizedBox(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF6B7280),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text('취소', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final triggerIdString = _selectedTriggerIds.join(',');
                          print('🔧 저장할 trigger_id: $triggerIdString');
                          print('🔧 선택된 트리거 리스트: $_selectedTriggerIds');
                          
                          final couponData = {
                            'coupon_type': _selectedCouponType,
                            'discount_ratio': _selectedCouponType == '정률권' 
                                ? int.tryParse(_discountRatioController.text.replaceAll(',', '')) ?? 0 
                                : 0,
                            'discount_amt': _selectedCouponType == '정액권' 
                                ? int.tryParse(_discountAmtController.text.replaceAll(',', '')) ?? 0 
                                : 0,
                            'discount_min': _selectedCouponType == '시간권' 
                                ? int.tryParse(_discountMinController.text) ?? 0 
                                : 0,
                            'coupon_expiry_days': int.tryParse(_couponExpiryDaysController.text) ?? 0,
                            'multiple_coupon_use': _multipleCouponUse ? '가능' : '불가능',
                            'coupon_description': _couponDescriptionController.text,
                            'setting_status': _settingStatus == 1 ? '유효' : '무효',
                            'trigger_id': triggerIdString.isEmpty ? null : triggerIdString,
                          };
                          
                          print('🔧 전체 쿠폰 데이터: $couponData');
                          
                          Navigator.of(context).pop();
                          widget.onSave(couponData);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isEdit ? '수정' : '추가',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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

// 1,000단위 콤마 자동 입력 포맷터
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(',', '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    int value = int.tryParse(newText) ?? 0;
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}