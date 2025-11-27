import '/flutter_flow/flutter_flow_util.dart';
import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/services/api_service.dart';
import 'crm1_board_widget.dart' show Crm1BoardWidget;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 게시글 데이터 모델 (v2_board 구조에 맞게 수정)
class BoardPost {
  final int boardId;
  final String title;
  final String content;
  final int? memberId;
  final String? memberName; // v3_members 테이블에서 가져올 회원명
  final DateTime createdAt;
  final DateTime updatedAt;
  final String boardType;
  final String branchId;
  final int? managerId;
  final String? managerName; // v2_board 테이블에 포함된 작성자명
  final int? proId;
  final String? proName; // v2_board 테이블에 포함된 작성자명
  final int commentCount; // v2_board_comment 테이블에서 가져올 댓글 수
  final List<Map<String, dynamic>> comments; // 댓글 목록

  BoardPost({
    required this.boardId,
    required this.title,
    required this.content,
    this.memberId,
    this.memberName,
    required this.createdAt,
    required this.updatedAt,
    required this.boardType,
    required this.branchId,
    this.managerId,
    this.managerName,
    this.proId,
    this.proName,
    this.commentCount = 0,
    this.comments = const [],
  });

  // DB 데이터에서 BoardPost 객체 생성
  factory BoardPost.fromJson(Map<String, dynamic> json) {
    return BoardPost(
      boardId: json['board_id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      memberId: json['member_id'],
      memberName: json['member_name'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      boardType: json['board_type'] ?? '일반',
      branchId: json['branch_id'] ?? '',
      managerId: json['manager_id'],
      managerName: json['manager_name'],
      proId: json['pro_id'],
      proName: json['pro_name'],
      commentCount: int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
      comments: json['comments'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'board_id': boardId,
      'title': title,
      'content': content,
      'member_id': memberId,
      'member_name': memberName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'board_type': boardType,
      'branch_id': branchId,
      'manager_id': managerId,
      'manager_name': managerName,
      'pro_id': proId,
      'pro_name': proName,
      'comment_count': commentCount,
      'comments': comments,
    };
  }

  // NEW 표시 여부 (3일 이내)
  bool get isNew {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 3; // 3일 이내를 NEW로 간주
  }

  // 최근글 여부 (7일 이내)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays <= 7; // 7일 이내를 최근글로 간주
  }

  // 날짜 포맷팅
  String get formattedDate {
    return DateFormat('yyyy.MM.dd   HH:mm').format(createdAt);
  }

  // 작성자 이름 가져오기 (manager_name 또는 pro_name 중 하나)
  String get authorName {
    if (managerName != null && managerName!.isNotEmpty) {
      return managerName!;
    } else if (proName != null && proName!.isNotEmpty) {
      return proName!;
    } else {
      return '관리자';
    }
  }
}

class Crm1BoardModel extends FlutterFlowModel<Crm1BoardWidget> with ChangeNotifier {
  ///  State fields for stateful widgets in this page.

  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // 게시글 관련 상태
  List<BoardPost> _allPosts = [];
  List<BoardPost> _filteredPosts = [];
  String _searchQuery = '';
  String _selectedTag = '최근글'; // 기본값을 최근글로 설정
  bool _isLoading = false;
  String? _errorMessage;
  
  // 태그별 캐시 추가 - 성능 최적화
  Map<String, List<BoardPost>> _tagCache = {};
  bool _cacheInitialized = false;
  
  // 페이지네이션 추가
  static const int _pageSize = 10000; // 한 번에 표시할 게시글 수 - 모든 게시글 표시
  Map<String, int> _currentPageByTag = {}; // 태그별 현재 페이지
  Map<String, List<BoardPost>> _displayedPostsByTag = {}; // 태그별 현재 표시 중인 게시글
  
  // 사용 가능한 태그 목록 (board_type 기반)
  final List<String> availableTags = [
    '최근글',
    '상담기록', 
    '회원요청', 
    '이벤트기획', 
    '기기문제', 
    '주차권', 
    '락커대기',
    '일반'
  ];

  // 게시글 타입 목록 (게시글 작성시 사용)
  final List<String> boardTypes = [
    '상담기록',
    '회원요청', 
    '이벤트기획', 
    '기기문제', 
    '주차권', 
    '락커대기'
  ];

  // Getters
  List<BoardPost> get filteredPosts => _filteredPosts;
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // 페이지네이션 관련 getters
  bool get hasMorePosts {
    final taggedPosts = _tagCache[_selectedTag] ?? [];
    final currentPage = _currentPageByTag[_selectedTag] ?? 1;
    return taggedPosts.length > currentPage * _pageSize;
  }
  
  int get totalPostsForCurrentTag {
    return _tagCache[_selectedTag]?.length ?? 0;
  }
  
  int get displayedPostsCount {
    return _filteredPosts.length;
  }

  @override
  void initState(BuildContext context) {
    print('🔍 [DEBUG] ========== Crm1BoardModel 초기화 시작 ==========');
    sideBarNavModel = createModel(context, () => SideBarNavModel());
    print('🔍 [DEBUG] SideBarNavModel 생성 완료');
    print('🔍 [DEBUG] 게시글 로드 시작...');
    loadPosts();
    print('🔍 [DEBUG] ========== Crm1BoardModel 초기화 완료 ==========');
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
    tabBarController?.dispose();
    super.dispose();
  }

  // 태그별 캐시 생성 - 한번만 실행 (상세 디버깅 추가)
  void _buildTagCache() {
    if (_cacheInitialized) return;
    
    print('🔍 [DEBUG] ========== 태그별 캐시 생성 시작 ==========');
    print('🔍 [DEBUG] 전체 게시글 수: ${_allPosts.length}');
    
    _tagCache.clear();
    _currentPageByTag.clear();
    _displayedPostsByTag.clear();
    
    // 각 태그별로 미리 필터링
    for (String tag in availableTags) {
      List<BoardPost> taggedPosts;
      
      if (tag == '최근글') {
        taggedPosts = _allPosts.where((post) => post.isRecent).toList();
        print('🔍 [DEBUG] 최근글 태그: ${taggedPosts.length}개 (7일 이내)');
      } else {
        taggedPosts = _allPosts.where((post) => post.boardType == tag).toList();
        print('🔍 [DEBUG] $tag 태그: ${taggedPosts.length}개');
      }
      
      _tagCache[tag] = taggedPosts;
      
      // 각 태그의 첫 페이지 초기화
      _currentPageByTag[tag] = 1;
      _displayedPostsByTag[tag] = [];
    }
    
    _cacheInitialized = true;
    print('🔍 [DEBUG] 태그별 캐시 생성 완료:');
    for (var entry in _tagCache.entries) {
      print('   • ${entry.key}: ${entry.value.length}개');
    }
    print('🔍 [DEBUG] ========== 태그별 캐시 생성 종료 ==========');
  }

  // 검색어 적용 (캐시된 태그 결과에서 검색) - 페이지네이션 적용 (상세 디버깅 추가)
  void _applySearchToTaggedPosts() {
    print('🔍 [DEBUG] ========== 검색 적용 시작 ==========');
    print('🔍 [DEBUG] 선택된 태그: $_selectedTag');
    print('🔍 [DEBUG] 검색어: "$_searchQuery"');
    
    List<BoardPost> taggedPosts = _tagCache[_selectedTag] ?? [];
    print('🔍 [DEBUG] 태그별 게시글 수: ${taggedPosts.length}개');
    
    List<BoardPost> searchedPosts;
    
    if (_searchQuery.isEmpty) {
      searchedPosts = taggedPosts;
      print('🔍 [DEBUG] 검색어 없음 - 전체 게시글 사용');
    } else {
      final searchLower = _searchQuery.toLowerCase();
      searchedPosts = taggedPosts.where((post) {
        return post.title.toLowerCase().contains(searchLower) ||
            post.content.toLowerCase().contains(searchLower) ||
            post.authorName.toLowerCase().contains(searchLower) ||
            (post.memberName?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
      print('🔍 [DEBUG] 검색 결과: ${searchedPosts.length}개');
    }
    
    // 페이지네이션 적용
    final currentPage = _currentPageByTag[_selectedTag] ?? 1;
    final endIndex = currentPage * _pageSize;
    
    print('🔍 [DEBUG] 페이지네이션 정보:');
    print('   • 현재 페이지: $currentPage');
    print('   • 페이지 크기: $_pageSize');
    print('   • 끝 인덱스: $endIndex');
    
    if (searchedPosts.length <= _pageSize) {
      // 데이터가 적으면 모두 표시
      _filteredPosts = searchedPosts;
      print('🔍 [DEBUG] 데이터가 적어 전체 표시: ${_filteredPosts.length}개');
    } else {
      // 페이지네이션 적용
      _filteredPosts = searchedPosts.take(endIndex).toList();
      print('🔍 [DEBUG] 페이지네이션 적용: ${_filteredPosts.length}개 표시 (전체: ${searchedPosts.length}개)');
    }
    
    _displayedPostsByTag[_selectedTag] = _filteredPosts;
    
    print('🔍 [DEBUG] 최종 필터된 게시글: ${_filteredPosts.length}개');
    print('🔍 [DEBUG] ========== 검색 적용 종료 ==========');
  }

  // 실제 데이터 로드 (v2_board 구조에 맞게 수정) - 상세 디버깅 추가
  Future<void> loadPosts() async {
    print('🔍 [DEBUG] ========== 게시글 로드 시작 ==========');
    _isLoading = true;
    _errorMessage = null;
    _cacheInitialized = false; // 캐시 초기화
    notifyListeners();
    
    try {
      // 현재 로그인 정보 확인
      final currentUser = ApiService.getCurrentUser();
      final currentBranchId = ApiService.getCurrentBranchId();
      
      print('🔍 [DEBUG] 현재 로그인 정보:');
      print('   • 사용자: $currentUser');
      print('   • 지점ID: $currentBranchId');
      
      if (currentBranchId == null) {
        print('❌ [DEBUG] branch_id가 null입니다!');
        throw Exception('지점 정보가 없습니다.');
      }
      
      // 1. v2_board 데이터 먼저 모두 가져오기 (branch_id만으로)
      print('🔍 [DEBUG] 게시글 데이터 요청 시작...');
      print('   • 테이블: v2_board_by_member');
      print('   • branch_id: $currentBranchId');
      
      final boardData = await ApiService.getBoardByMemberData(
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': currentBranchId}
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'DESC'}
        ],
      );
      
      print('🔍 [DEBUG] 게시글 데이터 응답:');
      print('   • 데이터 개수: ${boardData.length}');
      if (boardData.isNotEmpty) {
        print('   • 첫 번째 게시글: ${boardData[0]}');
      }
      
      if (boardData.isEmpty) {
        print('⚠️ [DEBUG] 게시글 데이터가 비어있습니다.');
        _allPosts = [];
        _tagCache.clear();
        _filteredPosts = [];
        return;
      }
      
      // 2. 필요한 ID들 추출 (member_id만 필요)
      final memberIds = <int>{};
      final boardIds = <int>{};
      
      for (var board in boardData) {
        if (board['member_id'] != null && board['member_id'] != 0) {
          memberIds.add(board['member_id']);
        }
        if (board['board_id'] != null) {
          boardIds.add(board['board_id']);
        }
      }
      
      print('🔍 [DEBUG] 추출된 ID들:');
      print('   • member_ids: $memberIds');
      print('   • board_ids: $boardIds');
      
      // 3. Member 데이터 한번에 가져오기 (member_id가 있는 경우만)
      Map<int, Map<String, dynamic>> memberMap = {};
      if (memberIds.isNotEmpty) {
        print('🔍 [DEBUG] 회원 데이터 요청 시작...');
        try {
          final memberData = await ApiService.getMemberData(
            where: [
              {'field': 'member_id', 'operator': 'IN', 'value': memberIds.toList()}
            ],
          );
          print('🔍 [DEBUG] 회원 데이터 응답: ${memberData.length}개');
          
          for (var member in memberData) {
            if (member['member_id'] != null) {
              memberMap[member['member_id']] = member;
            }
          }
        } catch (e) {
          print('❌ [DEBUG] Member 데이터 로드 오류: $e');
        }
      }
      
      // 4. v2_board_comment 데이터 한번에 가져오기 (branch_id만으로)
      Map<int, List<Map<String, dynamic>>> commentMap = {};
      Map<int, int> commentCountMap = {};
      if (boardIds.isNotEmpty) {
        print('🔍 [DEBUG] 댓글 데이터 요청 시작...');
        print('   • 테이블: v2_board_by_member_replies');
        print('   • branch_id: $currentBranchId');
        
        try {
          final commentData = await ApiService.getBoardRepliesData(
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': currentBranchId}
            ],
            orderBy: [
              {'field': 'board_id', 'direction': 'ASC'},
              {'field': 'created_at', 'direction': 'ASC'}
            ],
          );
          
          print('🔍 [DEBUG] 댓글 데이터 응답: ${commentData.length}개');
          if (commentData.isNotEmpty) {
            print('   • 첫 번째 댓글: ${commentData[0]}');
          }
          
          // Comment를 board_id별로 그룹화
          for (var comment in commentData) {
            final boardId = comment['board_id'];
            if (boardId != null) {
              if (!commentMap.containsKey(boardId)) {
                commentMap[boardId] = [];
                commentCountMap[boardId] = 0;
              }
              commentMap[boardId]!.add(comment);
              commentCountMap[boardId] = commentCountMap[boardId]! + 1;
            }
          }
          
          print('🔍 [DEBUG] 댓글 그룹화 완료:');
          print('   • 댓글이 있는 게시글 수: ${commentMap.length}');
          for (var entry in commentMap.entries) {
            print('   • 게시글 ${entry.key}: ${entry.value.length}개 댓글');
          }
        } catch (e) {
          print('❌ [DEBUG] Comment 데이터 로드 오류: $e');
        }
      }
      
      // 5. BoardPost 객체들 생성 (모든 데이터 조합)
      print('🔍 [DEBUG] BoardPost 객체 생성 시작...');
      List<BoardPost> posts = [];
      for (var boardJson in boardData) {
        final memberId = boardJson['member_id'];
        final boardId = boardJson['board_id'];
        
        // Member 정보 조합
        String? memberName;
        if (memberId != null && memberId != 0 && memberMap.containsKey(memberId)) {
          memberName = memberMap[memberId]!['member_name'];
        }
        
        // Comment 정보 조합
        final comments = commentMap[boardId] ?? [];
        final commentCount = commentCountMap[boardId] ?? 0;
        
        final post = BoardPost(
          boardId: boardJson['board_id'] ?? 0,
          title: boardJson['title'] ?? '',
          content: boardJson['content'] ?? '',
          memberId: memberId == 0 ? null : memberId, // 0이면 null로 처리
          memberName: memberName,
          createdAt: DateTime.tryParse(boardJson['created_at'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(boardJson['updated_at'] ?? '') ?? DateTime.now(),
          boardType: boardJson['board_type'] ?? '일반',
          branchId: boardJson['branch_id'] ?? '',
          managerId: boardJson['manager_id'],
          managerName: boardJson['manager_name'],
          proId: boardJson['pro_id'],
          proName: boardJson['pro_name'],
          commentCount: commentCount,
          comments: comments,
        );
        
        posts.add(post);
      }
      
      _allPosts = posts;
      print('🔍 [DEBUG] 전체 게시글 수: ${_allPosts.length}');
      
      // 태그별 캐시 생성
      print('🔍 [DEBUG] 태그별 캐시 생성 시작...');
      _buildTagCache();
      
      // 현재 선택된 태그에 맞는 결과 적용
      print('🔍 [DEBUG] 현재 태그 적용: $_selectedTag');
      _applySearchToTaggedPosts();
      
      print('✅ [DEBUG] 게시글 로드 완료!');
      print('   • 전체 게시글: ${_allPosts.length}개');
      print('   • 필터된 게시글: ${_filteredPosts.length}개');
      print('   • 현재 태그: $_selectedTag');
      
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ [DEBUG] 게시글 로드 오류: $e');
      print('❌ [DEBUG] 스택 트레이스: ${StackTrace.current}');
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🔍 [DEBUG] ========== 게시글 로드 종료 ==========');
    }
  }

  // 확장된 검색 기능
  void onSearchChanged(String query) {
    _searchQuery = query;
    _applySearchToTaggedPosts(); // 캐시된 태그 결과에서 검색
    notifyListeners();
  }

  void onSearchSubmitted(String query) {
    _searchQuery = query;
    _applySearchToTaggedPosts(); // 캐시된 태그 결과에서 검색
    notifyListeners();
    print('검색 실행: $query');
  }

  // 태그 선택 (한번에 하나만 선택 가능) - 즉시 반응 (상세 디버깅 추가)
  void onTagSelected(List<String> selectedTags) {
    print('🔍 [DEBUG] ========== 태그 선택 시작 ==========');
    print('🔍 [DEBUG] 선택된 태그들: $selectedTags');
    print('🔍 [DEBUG] 이전 선택된 태그: $_selectedTag');
    
    // 한번에 하나의 태그만 선택 가능
    if (selectedTags.isNotEmpty) {
      _selectedTag = selectedTags.last;
    } else {
      _selectedTag = '최근글'; // 기본값
    }
    
    print('🔍 [DEBUG] 새로운 선택된 태그: $_selectedTag');
    
    // 해당 태그의 페이지를 1로 리셋
    _currentPageByTag[_selectedTag] = 1;
    print('🔍 [DEBUG] 페이지 리셋: $_selectedTag -> 1페이지');
    
    // 캐시에서 즉시 결과 가져오기
    _applySearchToTaggedPosts();
    notifyListeners();
    
    print('🔍 [DEBUG] 태그 선택 완료: $_selectedTag (캐시에서 ${_filteredPosts.length}개 게시글 로드, 전체: ${totalPostsForCurrentTag}개)');
    print('🔍 [DEBUG] ========== 태그 선택 종료 ==========');
  }

  // 게시글 작성 버튼 클릭
  void onCreatePostPressed() {
    print('게시글 작성 버튼 클릭됨');
    // TODO: 게시글 작성 다이얼로그 또는 페이지 열기
  }

  // 게시글 클릭
  void onPostTapped(BoardPost post) {
    print('게시글 클릭: ${post.title}');
    // TODO: 게시글 상세 페이지로 네비게이션
  }

  // 게시글 생성 (v2_board 구조에 맞게 수정)
  Future<bool> createPost({
    required String title,
    required String content,
    required String boardType,
    int? memberId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // 현재 로그인 사용자 정보 가져오기
      final currentUser = ApiService.getCurrentUser();
      final currentBranchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || currentBranchId == null) {
        throw Exception('로그인 정보가 없습니다.');
      }
      
      print('🔍 [DEBUG] 게시글 작성 시작');
      print('   • 현재 사용자: $currentUser');
      print('   • 현재 지점: $currentBranchId');
      print('   • 제목: $title');
      print('   • 내용: $content');
      print('   • 타입: $boardType');
      print('   • 회원ID: $memberId');
      
      final data = {
        'title': title,
        'content': content,
        'board_type': boardType,
        'member_id': memberId ?? 0, // 개발용으로 0 설정
        'member_name': memberId != null ? '회원' : '개발자', // 개발용으로 '개발자' 설정
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'branch_id': currentBranchId,
        'manager_id': currentUser['manager_id'],
        'manager_name': currentUser['manager_name'],
        'pro_id': currentUser['pro_id'],
        'pro_name': currentUser['pro_name'],
      };
      
      print('🔍 [DEBUG] 전송할 데이터: $data');
      
      final result = await ApiService.addBoardByMemberData(data);
      
      print('🔍 [DEBUG] 게시글 생성 결과: $result');
      
      // 새로 생성된 게시글 ID 가져오기 (API 응답에서)
      int? newBoardId;
      if (result is Map<String, dynamic> && result['board_id'] != null) {
        newBoardId = result['board_id'];
      } else {
        // ID를 직접 받을 수 없는 경우 최신 게시글을 다시 조회
        final latestBoard = await ApiService.getBoardByMemberData(
          orderBy: [{'field': 'created_at', 'direction': 'DESC'}],
          limit: 1,
        );
        if (latestBoard.isNotEmpty) {
          newBoardId = latestBoard[0]['board_id'];
        }
      }
      
      if (newBoardId != null) {
        // Member 정보 가져오기 (필요한 경우)
        String? memberName;
        if (memberId != null && memberId != 0) {
          try {
            final memberData = await ApiService.getMemberData(
              where: [{'field': 'member_id', 'operator': '=', 'value': memberId}],
              limit: 1,
            );
            if (memberData.isNotEmpty) {
              memberName = memberData[0]['member_name'];
            }
          } catch (e) {
            print('Member 정보 로드 오류: $e');
          }
        }
        
        // 새 게시글 객체 생성
        final newPost = BoardPost(
          boardId: newBoardId,
          title: title,
          content: content,
          memberId: memberId == 0 ? null : memberId,
          memberName: memberName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          boardType: boardType,
          branchId: currentBranchId,
          managerId: currentUser['manager_id'],
          managerName: currentUser['manager_name'],
          proId: currentUser['pro_id'],
          proName: currentUser['pro_name'],
          commentCount: 0,
          comments: [],
        );
        
        print('🔍 [DEBUG] 새 게시글 객체 생성 완료: ${newPost.title}');
        
        // 기존 목록 맨 앞에 추가
        _allPosts.insert(0, newPost);
        
        // 캐시 재생성
        _cacheInitialized = false;
        _buildTagCache();
        
        // 현재 선택된 태그에 맞는 결과 적용
        _applySearchToTaggedPosts();
        
        print('✅ [DEBUG] 게시글 생성 성공');
      } else {
        // ID를 가져올 수 없는 경우에만 전체 새로고침
        print('⚠️ [DEBUG] 게시글 ID를 가져올 수 없어 전체 새로고침 실행');
        await loadPosts();
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ [DEBUG] 게시글 생성 오류: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 게시글 삭제 (v2_board 구조에 맞게 수정)
  Future<bool> deletePost(int boardId) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('🔍 [DEBUG] 게시글 삭제 시작: ID $boardId');

      // API를 통해 게시글 삭제
      await ApiService.deleteBoardByMemberData([
        {'field': 'board_id', 'operator': '=', 'value': boardId}
      ]);

      print('🔍 [DEBUG] 게시글 삭제 API 호출 완료');

      // 로컬 데이터에서도 제거
      _allPosts.removeWhere((post) => post.boardId == boardId);
      
      // 캐시 재생성
      _cacheInitialized = false;
      _buildTagCache();
      
      // 현재 선택된 태그에 맞는 결과 적용
      _applySearchToTaggedPosts();
      
      _isLoading = false;
      notifyListeners();
      
      print('✅ [DEBUG] 게시글 삭제 성공: ID $boardId');
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = '게시글 삭제 중 오류가 발생했습니다: $e';
      notifyListeners();
      print('❌ [DEBUG] 게시글 삭제 오류: $e');
      return false;
    }
  }

  // 새로고침
  Future<void> refresh() async {
    await loadPosts();
  }

  // 특정 게시글의 댓글 정보 업데이트 (v2_board 구조에 맞게 수정)
  void updatePostComments(int boardId, List<Map<String, dynamic>> updatedComments) {
    for (int i = 0; i < _allPosts.length; i++) {
      if (_allPosts[i].boardId == boardId) {
        _allPosts[i] = BoardPost(
          boardId: _allPosts[i].boardId,
          title: _allPosts[i].title,
          content: _allPosts[i].content,
          memberId: _allPosts[i].memberId,
          memberName: _allPosts[i].memberName,
          createdAt: _allPosts[i].createdAt,
          updatedAt: _allPosts[i].updatedAt,
          boardType: _allPosts[i].boardType,
          branchId: _allPosts[i].branchId,
          managerId: _allPosts[i].managerId,
          managerName: _allPosts[i].managerName,
          proId: _allPosts[i].proId,
          proName: _allPosts[i].proName,
          commentCount: updatedComments.length,
          comments: updatedComments,
        );
        break;
      }
    }
    
    // 캐시 재생성
    _cacheInitialized = false;
    _buildTagCache();
    
    // 현재 선택된 태그에 맞는 결과 적용
    _applySearchToTaggedPosts();
    notifyListeners();
  }

  // 더 많은 게시글 로드 (페이지네이션)
  void loadMorePosts() {
    if (!hasMorePosts) return;
    
    final currentPage = _currentPageByTag[_selectedTag] ?? 1;
    _currentPageByTag[_selectedTag] = currentPage + 1;
    
    _applySearchToTaggedPosts();
    notifyListeners();
    
    print('더 많은 게시글 로드: 페이지 ${_currentPageByTag[_selectedTag]}, 표시 중: ${_filteredPosts.length}개');
  }
}
