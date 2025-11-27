import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'crm6_locker_widget.dart' show Crm6LockerWidget;
import 'package:flutter/material.dart';

class Crm6LockerModel extends FlutterFlowModel<Crm6LockerWidget> {
  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;
  
  // State field(s) for search field
  FocusNode? searchFieldFocusNode;
  TextEditingController? searchController;
  
  // State for locker data
  List<Map<String, dynamic>> lockerData = [];
  List<Map<String, dynamic>> filteredLockerData = [];
  bool isLoading = false;
  
  // State for main table filtering
  List<Map<String, dynamic>> mainFilteredData = [];
  
  // State for selected lockers (for bulk operations)
  Set<int> selectedLockerIds = {};
  bool isSelectMode = false;
  
  // State for assignment popup
  bool showAssignmentPopup = false;
  int? selectedLockerId;
  Map<String, dynamic>? selectedLockerInfo;
  bool isUnpaidPaymentMode = false; // 미납 결제 모드인지 구분
  
  // Assignment form controllers
  TextEditingController? memberSearchController;
  TextEditingController? discountMinController;
  TextEditingController? discountRatioController;
  TextEditingController? startDateController;
  TextEditingController? endDateController;
  TextEditingController? remarkController;
  String? selectedPaymentMethod;
  Map<String, dynamic>? selectedMember;
  String? selectedPayMethod; // 결제방법 (크레딧 결제, 카드결제)
  TextEditingController? totalPriceController; // 총 가격
  String? calculatedMonths; // 계산된 개월수 표시
  Map<String, dynamic>? memberCreditInfo; // 회원 크레딧 정보
  String? selectedDiscountIncludeOption; // 할인 기간권 포함/제외 선택
  List<Map<String, dynamic>> memberSearchResults = []; // 회원 검색 결과
  bool showMemberSearchResults = false; // 회원 검색 결과 표시 여부
  
  // State for return popup
  bool showReturnPopup = false;
  String? selectedRefundMethod;
  TextEditingController? refundAmountController;
  TextEditingController? returnDateController;
  Map<String, dynamic>? returnPaymentInfo; // 반납 시 결제 정보
  List<String> availableRefundMethods = []; // 사용 가능한 환불 옵션
  
  // State for settings popup
  bool showSettingsPopup = false;
  TextEditingController? totalCountController;
  
  // State for total count change popup (separate from settings popup)
  bool showTotalCountPopup = false;
  
  // State for locker settings popup (new main popup)
  bool showLockerSettingsPopup = false;
  
  // State for locker filtering
  String? lockerFilter; // 'even', 'odd', 'range', 'single', null
  String? rangeStart;
  String? rangeEnd;
  List<Map<String, dynamic>> filteredSettingsLockers = [];
  TextEditingController? rangeStartController;
  TextEditingController? rangeEndController;
  TextEditingController? singleNumberController; // 개별 번호 검색용
  
  // State for property filtering
  Set<String> selectedZones = {};
  Set<String> selectedTypes = {};
  Set<String> selectedPrices = {};
  
  // State for usage status filtering
  String? selectedUsageStatus; // 'used', 'empty', null
  
  // State for member search in settings
  TextEditingController? memberSearchInSettingsController;
  
  // State for bulk property assignment
  bool showBulkAssignPopup = false;
  TextEditingController? bulkZoneController;
  TextEditingController? bulkTypeController;
  TextEditingController? bulkPriceController;
  String? selectedBulkType; // 선택된 락커 종류
  
  // State for individual editing
  bool showIndividualEditPopup = false;
  int? editingLockerId;
  TextEditingController? editZoneController;
  TextEditingController? editTypeController;
  TextEditingController? editPriceController;
  String? selectedEditType; // 개별 편집용 선택된 락커 종류
  
  // Cached unique properties for filter performance
  Set<String> uniqueZones = {};
  Set<String> uniqueTypes = {};
  Set<String> uniquePrices = {};

  @override
  void initState(BuildContext context) {
    sideBarNavModel = createModel(context, () => SideBarNavModel());
    
    // Initialize controllers
    searchController = TextEditingController();
    memberSearchController = TextEditingController();
    discountMinController = TextEditingController();
    discountRatioController = TextEditingController();
    startDateController = TextEditingController();
    endDateController = TextEditingController();
    remarkController = TextEditingController();
    totalCountController = TextEditingController();
    bulkZoneController = TextEditingController();
    bulkTypeController = TextEditingController();
    bulkPriceController = TextEditingController();
    refundAmountController = TextEditingController();
    returnDateController = TextEditingController();
    totalPriceController = TextEditingController();
    rangeStartController = TextEditingController();
    rangeEndController = TextEditingController();
    singleNumberController = TextEditingController();
    memberSearchInSettingsController = TextEditingController();
    editZoneController = TextEditingController();
    editTypeController = TextEditingController();
    editPriceController = TextEditingController();
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
    searchFieldFocusNode?.dispose();
    searchController?.dispose();
    memberSearchController?.dispose();
    discountMinController?.dispose();
    discountRatioController?.dispose();
    startDateController?.dispose();
    endDateController?.dispose();
    remarkController?.dispose();
    totalCountController?.dispose();
    bulkZoneController?.dispose();
    bulkTypeController?.dispose();
    bulkPriceController?.dispose();
    refundAmountController?.dispose();
    returnDateController?.dispose();
    totalPriceController?.dispose();
    rangeStartController?.dispose();
    rangeEndController?.dispose();
    singleNumberController?.dispose();
    memberSearchInSettingsController?.dispose();
    editZoneController?.dispose();
    editTypeController?.dispose();
    editPriceController?.dispose();
  }
  
  // Helper method to clear assignment form
  void clearAssignmentForm() {
    memberSearchController?.clear();
    discountMinController?.clear();
    discountRatioController?.clear();
    startDateController?.clear();
    endDateController?.clear();
    remarkController?.clear();
    totalPriceController?.clear();
    selectedPaymentMethod = null;
    selectedMember = null;
    selectedPayMethod = null;
    calculatedMonths = null;
    selectedDiscountIncludeOption = null;
    memberSearchResults.clear();
    showMemberSearchResults = false;
  }
  
  // Helper method to clear bulk assignment form
  void clearBulkAssignForm() {
    bulkZoneController?.clear();
    bulkTypeController?.clear();
    bulkPriceController?.clear();
    selectedBulkType = null;
    // selectedLockerIds는 지우지 않음 - 선택된 락커 유지
  }
  
  // Helper method to clear return form
  void clearReturnForm() {
    selectedRefundMethod = null;
    refundAmountController?.clear();
    returnDateController?.clear();
    returnPaymentInfo = null;
    availableRefundMethods = [];
    
    // 기본값으로 오늘 날짜 설정
    returnDateController?.text = DateTime.now().toString().split(' ')[0];
  }
  
  // Update unique properties for filter performance
  void updateUniqueProperties() {
    final zones = <String>{};
    final types = <String>{};
    final prices = <String>{};
    
    for (final locker in lockerData) {
      final zone = locker['locker_zone']?.toString() ?? '미지정';
      final type = locker['locker_type']?.toString() ?? '일반';
      final price = locker['locker_price'] ?? 0;
      
      zones.add(zone);
      types.add(type);
      prices.add(price == 0 ? '0원' : '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원');
    }
    
    uniqueZones = zones;
    uniqueTypes = types;
    uniquePrices = prices;
  }
}