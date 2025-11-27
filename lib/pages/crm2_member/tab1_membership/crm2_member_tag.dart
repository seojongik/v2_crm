import '/services/api_service.dart';

/// 회원관리 페이지의 태그 필터링 기능을 담당하는 클래스
class Crm2MemberTag {
  // 재직중인 프로 목록
  List<Map<String, dynamic>> _staffProData = [];
  
  // 기간권 회원 존재 여부 (타입별 분류 없이 단순히 존재 여부만)
  bool _hasTermMembers = false;
  
  // 타석 회원 존재 여부 (유효한 레슨권이 없는 회원)
  bool _hasBattingMembers = false;
  
  // 최근 등록 회원 존재 여부
  bool _hasRecentMembers = false;

  // 만료 회원 존재 여부 (유효한 회원권이 없는 회원)
  bool _hasExpiredMembers = false;

  // 레슨 회원 존재 여부 (유효한 레슨권을 가진 회원)
  bool _hasLessonMembers = false;
  
  // 현재 선택된 태그 (단일 선택)
  String _selectedTag = '';
  
  // 상태 변경 콜백
  Function()? _onStateChanged;
  
  /// 생성자
  Crm2MemberTag({Function()? onStateChanged}) {
    _onStateChanged = onStateChanged;
  }
  
  /// 현재 선택된 태그 반환
  String get selectedTag => _selectedTag;
  
  /// 프로 목록 데이터 반환
  List<Map<String, dynamic>> get staffProData => _staffProData;
  
  /// 기간권 회원 존재 여부 반환
  bool get hasTermMembers => _hasTermMembers;
  
  /// 타석 회원 존재 여부 반환
  bool get hasBattingMembers => _hasBattingMembers;
  
  /// 최근 등록 회원 존재 여부 반환
  bool get hasRecentMembers => _hasRecentMembers;

  /// 만료 회원 존재 여부 반환
  bool get hasExpiredMembers => _hasExpiredMembers;

  /// 레슨 회원 존재 여부 반환
  bool get hasLessonMembers => _hasLessonMembers;
  
  /// 프로 목록 로드
  Future<void> loadStaffProData() async {
    try {
      _staffProData = await ApiService.getActiveStaffPros();
      _notifyStateChanged();
    } catch (e) {
      print('프로 목록 로드 오류: $e');
      _staffProData = [];
    }
  }
  
  /// 기간권 회원 존재 여부 확인
  Future<void> loadTermMemberData() async {
    try {
      List<Map<String, dynamic>> termMembers = await ApiService.getActiveTermMembers();
      _hasTermMembers = termMembers.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      print('기간권 회원 로드 오류: $e');
      _hasTermMembers = false;
    }
  }
  
  /// 타석 회원 존재 여부 확인 (유효한 레슨권이 없는 회원)
  Future<void> loadBattingMemberData() async {
    try {
      List<int> battingMemberIds = await ApiService.getBattingMemberIds();
      _hasBattingMembers = battingMemberIds.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      print('타석 회원 로드 오류: $e');
      _hasBattingMembers = false;
    }
  }
  
  /// 최근 등록 회원 존재 여부 확인
  Future<void> loadRecentMemberData() async {
    try {
      List<int> recentMemberIds = await ApiService.getRecentMemberIds();
      _hasRecentMembers = recentMemberIds.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      print('최근 등록 회원 로드 오류: $e');
      _hasRecentMembers = false;
    }
  }

  /// 만료 회원 존재 여부 확인
  Future<void> loadExpiredMemberData() async {
    try {
      List<int> expiredMemberIds = await ApiService.getExpiredMemberIds();
      _hasExpiredMembers = expiredMemberIds.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      print('만료 회원 로드 오류: $e');
      _hasExpiredMembers = false;
    }
  }

  /// 레슨 회원 존재 여부 확인 (유효한 레슨권을 가진 회원)
  Future<void> loadLessonMemberData() async {
    try {
      List<int> lessonMemberIds = await ApiService.getValidLessonMemberIds();
      _hasLessonMembers = lessonMemberIds.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      print('레슨 회원 로드 오류: $e');
      _hasLessonMembers = false;
    }
  }
  
  /// 사용 가능한 태그 목록 생성 (최근등록 + 전체 + 기간권 + 프로 이름들 + 관계)
  List<String> getAvailableTags() {
    List<String> tags = [];
    
    // 최근 등록 회원이 있는 경우에만 최근등록 태그 추가 (맨 앞에)
    if (_hasRecentMembers) {
      tags.add('최근등록');
    }
    
    // 전체 태그 추가
    tags.add('전체');
    
    // 기간권 회원이 있는 경우에만 기간권 태그 추가
    if (_hasTermMembers) {
      tags.add('기간권');
    }

    // 레슨 회원이 있는 경우에만 레슨회원 태그 추가
    if (_hasLessonMembers) {
      tags.add('레슨회원');
    }

    // 프로 이름 추가
    tags.addAll(_staffProData.map((pro) => pro['pro_name'] as String));
    
    // 타석 회원이 있는 경우에만 타석 태그 추가
    if (_hasBattingMembers) {
      tags.add('타석');
    }

    // 만료 회원이 있는 경우에만 만료회원 태그 추가 (맨 뒤에)
    if (_hasExpiredMembers) {
      tags.add('만료회원');
    }

    return tags;
  }
  
  /// 현재 선택된 태그 목록 반환 (단일 선택이므로 하나만)
  List<String> getSelectedTags() {
    return [_selectedTag];
  }
  
  /// 태그 필터 변경 (단일 선택)
  void updateTagFilter(List<String> tags) {
    if (tags.isNotEmpty) {
      _selectedTag = tags.first; // 첫 번째 태그만 선택
    } else {
      _selectedTag = _hasRecentMembers ? '최근등록' : '전체'; // 기본값
    }
    _notifyStateChanged();
  }
  
  /// 선택된 프로의 ID 가져오기 (단일 선택)
  int? getSelectedProId() {
    if (_selectedTag == '전체' || _selectedTag == '기간권' || _selectedTag == '레슨회원' || _selectedTag == '타석' || _selectedTag == '최근등록' || _selectedTag == '만료회원') {
      return null; // 특수 태그는 프로가 아님
    }

    // 프로 이름으로 프로 ID 찾기
    var pro = _staffProData.firstWhere(
      (p) => p['pro_name'] == _selectedTag,
      orElse: () => {},
    );

    return pro.isNotEmpty ? pro['pro_id'] as int : null;
  }
  
  /// 기간권 필터링 여부 확인
  bool isTermFilterSelected() {
    return _selectedTag == '기간권';
  }

  /// 타석 필터링 여부 확인
  bool isBattingFilterSelected() {
    return _selectedTag == '타석';
  }

  /// 최근등록 필터링 여부 확인
  bool isRecentFilterSelected() {
    return _selectedTag == '최근등록';
  }

  /// 만료회원 필터링 여부 확인
  bool isExpiredFilterSelected() {
    return _selectedTag == '만료회원';
  }

  /// 레슨회원 필터링 여부 확인
  bool isLessonFilterSelected() {
    return _selectedTag == '레슨회원';
  }
  
  /// 필터링된 프로 ID 목록 반환 (전체 선택 시 null, 특정 프로 선택 시 해당 프로만)
  List<int>? getFilteredProIds() {
    if (_selectedTag == '전체' || _selectedTag == '기간권' || _selectedTag == '레슨회원' || _selectedTag == '타석' || _selectedTag == '최근등록' || _selectedTag == '만료회원') {
      return null; // 전체 선택 시
    }

    int? proId = getSelectedProId();
    return proId != null ? [proId] : null;
  }
  
  /// 기간권 필터링 여부 반환 (API 호출용)
  bool getFilteredTermFilter() {
    return _selectedTag == '기간권';
  }

  /// 타석 필터링 여부 반환 (API 호출용)
  bool getFilteredBattingFilter() {
    return _selectedTag == '타석';
  }

  /// 최근등록 필터링 여부 반환 (API 호출용)
  bool getFilteredRecentFilter() {
    return _selectedTag == '최근등록';
  }

  /// 만료회원 필터링 여부 반환 (API 호출용)
  bool getFilteredExpiredFilter() {
    return _selectedTag == '만료회원';
  }

  /// 레슨회원 필터링 여부 반환 (API 호출용)
  bool getFilteredLessonFilter() {
    return _selectedTag == '레슨회원';
  }
  
  /// 태그가 '전체'인지 확인
  bool isAllSelected() {
    return _selectedTag == '전체' || _selectedTag.isEmpty;
  }
  
  /// 특정 프로가 선택되었는지 확인
  bool isProSelected(String proName) {
    return _selectedTag == proName;
  }
  
  /// 기간권이 선택되었는지 확인
  bool isTermSelected() {
    return _selectedTag == '기간권';
  }
  
  /// 타석이 선택되었는지 확인
  bool isBattingSelected() {
    return _selectedTag == '타석';
  }

  /// 최근등록이 선택되었는지 확인
  bool isRecentSelected() {
    return _selectedTag == '최근등록';
  }

  /// 만료회원이 선택되었는지 확인
  bool isExpiredSelected() {
    return _selectedTag == '만료회원';
  }

  /// 레슨회원이 선택되었는지 확인
  bool isLessonSelected() {
    return _selectedTag == '레슨회원';
  }

  /// 태그 초기화 (최근등록 또는 전체로 리셋)
  void resetTag() {
    _selectedTag = _hasRecentMembers ? '최근등록' : '전체';
    _notifyStateChanged();
  }
  
  /// 초기 태그 설정 (최근등록 회원 존재 여부에 따라)
  void setInitialTag() {
    if (_selectedTag.isEmpty) { // 아직 설정되지 않은 경우만
      _selectedTag = _hasRecentMembers ? '최근등록' : '전체';
      _notifyStateChanged();
    }
  }
  
  /// 상태 변경 알림
  void _notifyStateChanged() {
    _onStateChanged?.call();
  }
  
  /// 상태 변경 콜백 설정
  void setStateCallback(Function() callback) {
    _onStateChanged = callback;
  }
} 