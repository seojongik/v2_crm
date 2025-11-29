import '/components/side_bar_nav/side_bar_nav_model.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/api_service.dart';
import '/pages/crm2_member/tab1_membership/crm2_member_tag.dart';
import 'tab1_membership_widget.dart' show Tab1MembershipWidget;
import 'package:flutter/material.dart';

// 회원 표시용 데이터 클래스
class MemberDisplayData {
  final Map<String, dynamic> memberData;
  final bool isJunior;
  final List<MemberDisplayData> children; // 주니어 회원들
  
  MemberDisplayData({
    required this.memberData,
    this.isJunior = false,
    this.children = const [],
  });
}

class Tab1MembershipModel extends FlutterFlowModel<Tab1MembershipWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  // API 데이터 관리
  List<Map<String, dynamic>> memberData = [];
  List<MemberDisplayData> hierarchicalMemberData = []; // 계층적 회원 데이터
  Map<int, Map<String, dynamic>> memberCredits = {}; // 회원별 크레딧 정보 (total_balance, contract_count, nearest_expiry_date)
  Map<int, Map<String, dynamic>> memberLessonTickets = {}; // 회원별 레슨권 정보 (total_balance, contract_count, nearest_expiry_date, lesson_types, pro_names)
  Map<int, Map<String, dynamic>> memberTimeTickets = {}; // 회원별 시간권 정보 (total_balance, contract_count, nearest_expiry_date)
  Map<int, Map<String, dynamic>> memberTermTickets = {}; // 회원별 기간권 정보 (contract_count, nearest_expiry_date, term_types)
  bool isLoading = false;
  String? errorMessage;
  
  // 태그 관리 클래스
  late Crm2MemberTag tagManager;
  
  // 상태 업데이트 콜백
  VoidCallback? onStateChanged;

  @override
  void initState(BuildContext context) {
    sideBarNavModel = createModel(context, () => SideBarNavModel());
    
    // 태그 관리자 초기화
    tagManager = Crm2MemberTag(onStateChanged: () => notifyStateChanged());
    
    // 데이터 로드 및 초기 태그 설정
    _initializeData();
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }

  // 상태 업데이트 콜백 설정
  void setStateCallback(VoidCallback callback) {
    onStateChanged = callback;
  }

  // 상태 변경 알림
  void notifyStateChanged() {
    onStateChanged?.call();
  }

  // 데이터 초기화 및 초기 태그 설정
  Future<void> _initializeData() async {
    await Future.wait([
      tagManager.loadStaffProData(), // 프로 목록 로드
      tagManager.loadTermMemberData(), // 기간권 데이터 로드
      tagManager.loadBattingMemberData(), // 타석 회원 데이터 로드
      tagManager.loadRecentMemberData(), // 최근등록 데이터 로드
      tagManager.loadExpiredMemberData(), // 만료회원 데이터 로드
      tagManager.loadLessonMemberData(), // 레슨회원 데이터 로드
    ]);
    
    // 모든 데이터 로드 완료 후 초기 태그 설정
    tagManager.setInitialTag();
    
    // 회원 데이터 로드
    await loadMemberData();
  }

  // 회원 데이터 로드
  Future<void> loadMemberData() async {
    isLoading = true;
    errorMessage = null;
    notifyStateChanged();
    
    try {
      // 선택된 프로 ID 목록 가져오기 (전체가 아닌 경우만)
      List<int>? selectedProIds = tagManager.getFilteredProIds();
      
      // 기간권 필터링 여부 확인
      bool isTermFilterSelected = tagManager.getFilteredTermFilter();
      
      // 타석 필터링 여부 확인
      bool isBattingFilterSelected = tagManager.getFilteredBattingFilter();
      
      // 최근등록 필터링 여부 확인
      bool isRecentFilterSelected = tagManager.getFilteredRecentFilter();

      // 만료회원 필터링 여부 확인
      bool isExpiredFilterSelected = tagManager.getFilteredExpiredFilter();

      // 레슨회원 필터링 여부 확인
      bool isLessonFilterSelected = tagManager.getFilteredLessonFilter();

      // 회원 데이터 조회
      memberData = await ApiService.getMembers(
        searchQuery: textController?.text,
        selectedTags: null, // 더 이상 사용하지 않음
        selectedProIds: selectedProIds,
        isTermFilter: isTermFilterSelected, // 기간권 필터링 여부 전달
        isBattingFilter: isBattingFilterSelected, // 타석 필터링 여부 전달
        isRecentFilter: isRecentFilterSelected, // 최근등록 필터링 여부 전달
        isExpiredFilter: isExpiredFilterSelected, // 만료회원 필터링 여부 전달
        isLessonFilter: isLessonFilterSelected, // 레슨회원 필터링 여부 전달
      );
      
      // 회원 ID 목록 추출
      List<int> memberIds = memberData
          .map((member) => member['member_id'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toList();
      
      // 크레딧, 레슨권, 시간권, 기간권 정보 조회
      if (memberIds.isNotEmpty) {
        memberCredits = await ApiService.getMemberCredits(memberIds);
        memberLessonTickets = await ApiService.getMemberLessonTickets(memberIds);
        memberTimeTickets = await ApiService.getMemberTimeTickets(memberIds);
        memberTermTickets = await ApiService.getMemberTermTickets(memberIds);
      } else {
        memberCredits = {};
        memberLessonTickets = {};
        memberTimeTickets = {};
        memberTermTickets = {};
      }
      
      // 주니어 관계 데이터 조회 및 계층적 구조 생성
      await _buildHierarchicalData();
      
    } catch (e) {
      errorMessage = e.toString();
      memberData = [];
      memberCredits = {};
      memberLessonTickets = {};
      memberTimeTickets = {};
      memberTermTickets = {};
      hierarchicalMemberData = [];
    } finally {
      isLoading = false;
      notifyStateChanged();
    }
  }

  // 계층적 데이터 구조 생성
  Future<void> _buildHierarchicalData() async {
    try {
      // 최근등록, 타석, 만료회원, 레슨회원 필터가 선택된 경우 계층 구조 없이 평면 구조로 표시
      bool isRecentFilterSelected = tagManager.getFilteredRecentFilter();
      bool isBattingFilterSelected = tagManager.getFilteredBattingFilter();
      bool isExpiredFilterSelected = tagManager.getFilteredExpiredFilter();
      bool isLessonFilterSelected = tagManager.getFilteredLessonFilter();

      if (isRecentFilterSelected || isBattingFilterSelected || isExpiredFilterSelected || isLessonFilterSelected) {
        // 최근등록, 타석, 만료회원, 레슨회원 필터 시에는 모든 회원을 평면 구조로 표시
        hierarchicalMemberData = memberData.map((member) => MemberDisplayData(
          memberData: member,
          isJunior: false, // 특정 필터에서는 모두 독립 회원으로 표시
        )).toList();
        return;
      }
      
      // 주니어 관계 데이터 조회
      List<Map<String, dynamic>> juniorRelations = await ApiService.getJuniorRelations();
      
      // 부모 회원 ID를 키로 하고, 주니어 회원 ID 리스트를 값으로 하는 맵 생성
      Map<int, List<int>> parentToJuniorsMap = {};
      Set<int> juniorMemberIds = {}; // 주니어 회원 ID들을 추적
      
      for (var relation in juniorRelations) {
        // v2_group 테이블 구조: member_id가 주니어 ID, related_member_id가 부모 ID
        int? juniorMemberId = relation['member_id']; // 주니어 회원 ID
        int? parentMemberId = relation['related_member_id']; // 부모 회원 ID
        
        if (parentMemberId != null && juniorMemberId != null) {
          // 부모-주니어 관계 매핑
          if (!parentToJuniorsMap.containsKey(parentMemberId)) {
            parentToJuniorsMap[parentMemberId] = [];
          }
          parentToJuniorsMap[parentMemberId]!.add(juniorMemberId);
          
          // 주니어 회원 ID 추적
          juniorMemberIds.add(juniorMemberId);
        }
      }
      
      // 계층적 구조 생성
      hierarchicalMemberData = [];
      
      for (var member in memberData) {
        int? memberId = member['member_id'];
        if (memberId == null) continue;
        
        String memberType = member['member_type'] ?? '';
        
        // 구분이 '주니어'이면서 주니어 관계 테이블에 등록된 회원은 독립 표시하지 않음
        if (memberType == '주니어' && juniorMemberIds.contains(memberId)) {
          continue;
        }
        
        // 부모 회원 처리 (주니어가 아니거나, 주니어이지만 관계 테이블에 없는 경우)
        List<MemberDisplayData> children = [];
        
        // 이 회원의 주니어들 찾기
        if (parentToJuniorsMap.containsKey(memberId)) {
          for (int juniorId in parentToJuniorsMap[memberId]!) {
            var juniorMember = memberData.firstWhere(
              (m) => m['member_id'] == juniorId,
              orElse: () => {},
            );
            
            if (juniorMember.isNotEmpty) {
              children.add(MemberDisplayData(
                memberData: juniorMember,
                isJunior: true,
              ));
            }
          }
        }
        
        hierarchicalMemberData.add(MemberDisplayData(
          memberData: member,
          isJunior: false,
          children: children,
        ));
      }
      
    } catch (e) {
      print('주니어 관계 데이터 처리 오류: $e');
      // 오류 시 기본 평면 구조로 폴백 (단, 주니어 회원은 제외)
      hierarchicalMemberData = memberData
          .where((member) => member['member_type'] != '주니어')
          .map((member) => MemberDisplayData(
            memberData: member,
            isJunior: false,
          )).toList();
    }
  }

  // 검색 실행
  Future<void> performSearch() async {
    // 검색 시 필터를 '전체'로 초기화
    tagManager.updateTagFilter(['전체']);
    await loadMemberData();
  }

  // 태그 필터 변경 (태그 관리자에 위임)
  void updateTagFilter(List<String> tags) {
    tagManager.updateTagFilter(tags);
    loadMemberData(); // 데이터 다시 로드
  }

  // 태그 관련 메서드들 (태그 관리자에 위임)
  List<String> getAvailableTags() => tagManager.getAvailableTags();
  List<String> getSelectedTags() => tagManager.getSelectedTags();
  int? getSelectedProId() => tagManager.getSelectedProId();
  List<int>? getFilteredProIds() => tagManager.getFilteredProIds();
}
