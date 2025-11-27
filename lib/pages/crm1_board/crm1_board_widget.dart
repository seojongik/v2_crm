import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/components/common_tag_filter/common_tag_filter_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/api_service.dart';
import '/services/tab_design_upper.dart';
import '../../constants/font_sizes.dart';
import 'package:flutter/material.dart';
import 'crm1_board_model.dart';
export 'crm1_board_model.dart';

class Crm1BoardWidget extends StatefulWidget {
  const Crm1BoardWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Crm1BoardWidget> createState() => _Crm1BoardWidgetState();
}

class _Crm1BoardWidgetState extends State<Crm1BoardWidget>
    with TickerProviderStateMixin {
  late Crm1BoardModel _model;
  TabController? _tabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm1BoardModel());
    _model.initState(context);

    // TabController 초기화
    final currentIndex = _model.availableTags.indexOf(_model.selectedTag);
    final safeIndex = currentIndex >= 0 ? currentIndex : 0;
    _tabController = TabController(
      length: _model.availableTags.length,
      vsync: this,
      initialIndex: safeIndex,
    );
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        final selectedTag = _model.availableTags[_tabController!.index];
        _model.onTagSelected([selectedTag]);
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _model.dispose();
    super.dispose();
  }

  // 태그에 맞는 아이콘 반환
  IconData _getIconForTag(String tag) {
    switch (tag) {
      case '최근글':
        return Icons.schedule;
      case '상담기록':
        return Icons.chat_bubble_outline;
      case '회원요청':
        return Icons.person_pin;
      case '이벤트기획':
        return Icons.celebration;
      case '기기문제':
        return Icons.build_circle;
      case '주차권':
        return Icons.local_parking;
      case '락커대기':
        return Icons.lock_clock;
      case '일반':
        return Icons.article;
      default:
        return Icons.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF8FAFC),
        body: Row(
            mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (responsiveVisibility(
                context: context,
                phone: false,
              ))
                wrapWithModel(
                  model: _model.sideBarNavModel,
                  updateCallback: () => safeSetState(() {}),
                  child: SideBarNavWidget(
                    currentPage: 'crm1_board',
                    onNavigate: (String routeName) {
                      widget.onNavigate?.call(routeName);
                    },
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (responsiveVisibility(
                      context: context,
                      tabletLandscape: false,
                      desktop: false,
                    ))
                      Container(
                        width: double.infinity,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8.0,
                                color: Color(0x1A000000),
                                offset: Offset(0.0, 2.0),
                              )
                            ],
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 헤더 섹션
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16.0),
                                    topRight: Radius.circular(16.0),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // 글쓰기 버튼 (왼쪽)
                                      Container(
                                        height: 48.0,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                            stops: [0.0, 1.0],
                                            begin: AlignmentDirectional(0.0, -1.0),
                                            end: AlignmentDirectional(0, 1.0),
                                          ),
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8.0),
                                            onTap: () async {
                                              // 게시글 작성 기능 활성화
                                              _showCreatePostDialog();
                                            },
                                            child: Container(
                                              width: 120.0,
                                              height: 48.0,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    color: Colors.white,
                                                    size: 20.0,
                                                  ),
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                                                    child: Text(
                                                      '글쓰기',
                                                      style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 검색 필드 (오른쪽)
                                      Container(
                                        width: 300.0,
                                        child: TextFormField(
                                          onChanged: (value) => _model.onSearchChanged(value),
                                          autofocus: false,
                                          obscureText: false,
                                          decoration: InputDecoration(
                                            hintText: '제목 또는 내용으로 검색',
                                            hintStyle: AppTextStyles.bodyTextSmall.copyWith(
                                              color: Color(0xFF94A3B8),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFFE2E8F0),
                                                width: 1.0,
                                              ),
                                              borderRadius: BorderRadius.circular(8.0),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFF3B82F6),
                                                width: 2.0,
                                              ),
                                              borderRadius: BorderRadius.circular(8.0),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
                                          ),
                                          style: AppTextStyles.bodyTextSmall.copyWith(
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // 태그 필터 섹션 - 중간 사이즈 탭 (테마 1번: 시안색)
                            if (_tabController != null)
                              Padding(
                                padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
                                child: TabDesignUpper.buildStyledTabBar(
                                  controller: _tabController!,
                                  themeNumber: 1,
                                  size: 'medium',
                                  tabs: _model.availableTags.map((tag) =>
                                    TabDesignUpper.buildTabItem(
                                      _getIconForTag(tag),
                                      tag,
                                      size: 'medium',
                                    )
                                  ).toList(),
                                ),
                              ),
                            
                            // 게시글 목록 섹션 - Expanded로 감싸서 남은 공간 차지
                            Expanded(
                              child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(16.0),
                                    bottomRight: Radius.circular(16.0),
                                  ),
                                ),
                                child: AnimatedBuilder(
                                animation: _model,
                                builder: (context, child) {
                                  if (_model.isLoading) {
                                    return Container(
                                      height: 400.0,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  if (_model.errorMessage != null) {
                                    return Container(
                                      height: 400.0,
                                      child: Center(
                                  child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                            Icon(
                                              Icons.error_outline,
                                              size: 64.0,
                                              color: Color(0xFFEF4444),
                                            ),
                                            SizedBox(height: 16.0),
                                            Text(
                                              '데이터를 불러오는 중 오류가 발생했습니다.',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: Color(0xFF1E293B),
                                                fontSize: FontSizes.bodyLarge,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 8.0),
                                            Text(
                                              _model.errorMessage!,
                                              style: AppTextStyles.bodyTextSmall.copyWith(
                                                color: Color(0xFF64748B),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 16.0),
                                      Container(
                                              height: 40.0,
                                        decoration: BoxDecoration(
                                                color: Color(0xFF3B82F6),
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(8.0),
                                                  onTap: () {
                                                    _model.refresh();
                                                  },
                                                  child: Container(
                                                    width: 100.0,
                                                    height: 40.0,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8.0),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '다시 시도',
                                                        style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  if (_model.filteredPosts.isEmpty) {
                                    return Container(
                                      height: 400.0,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.article_outlined,
                                              size: 64.0,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            SizedBox(height: 16.0),
                                            Text(
                                              '게시글이 없습니다.',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: Color(0xFF64748B),
                                                fontSize: FontSizes.bodyLarge,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return RefreshIndicator(
                                    onRefresh: () => _model.refresh(),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: _model.filteredPosts.length,
                                      itemBuilder: (context, index) {
                                        final post = _model.filteredPosts[index];
                                        
                                        return Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                                color: Color(0xFFF1F5F9),
                                              width: 1.0,
                                            ),
                                          ),
                                        ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                _showPostDetailDialog(post);
                                              },
                                        child: Padding(
                                                padding: EdgeInsets.all(24.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                    // 게시글 타입 아이콘과 타입을 하나의 박스에
                                                    Container(
                                                      width: 65.0,
                                                      height: 65.0,
                                                      padding: EdgeInsets.all(8.0),
                                                      decoration: BoxDecoration(
                                                        color: _getBoardTypeColor(post.boardType),
                                                        borderRadius: BorderRadius.circular(12.0),
                                                      ),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            _getBoardTypeIcon(post.boardType),
                                                            color: _getBoardTypeIconColor(post.boardType),
                                                            size: 24.0,
                                                          ),
                                                          SizedBox(height: 2.0),
                                                          Text(
                                                            post.boardType,
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: _getBoardTypeIconColor(post.boardType),
                                                              fontSize: FontSizes.minimum,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 16.0),
                                                    
                                                    // 게시글 내용
                                              Expanded(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.max,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            mainAxisSize: MainAxisSize.max,
                                                            children: [
                                                              Expanded(
                                                                child: SelectableText(
                                                                  post.title,
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                                    color: Color(0xFF1E293B),
                                                                    fontSize: FontSizes.bodyLarge,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                                              if (post.isNew)
                                                                Container(
                                                                  padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                                                                  decoration: BoxDecoration(
                                                                    color: Color(0xFFEF4444),
                                                                    borderRadius: BorderRadius.circular(12.0),
                                                                  ),
                                                                child: Text(
                                                                    'NEW',
                                                  style: AppTextStyles.overline.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          SizedBox(height: 8.0),
                                                          SelectableText(
                                                            post.content,
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF64748B),
                                                    fontSize: FontSizes.bodyMedium,
                                                              fontWeight: FontWeight.w400,
                                                            ),
                                                          ),
                                                          SizedBox(height: 12.0),
                                                          
                                                          // 작성자와 회원 정보 - 라벨만 박스에
                                                          Row(
                                                            mainAxisSize: MainAxisSize.max,
                                                            children: [
                                                              Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                                decoration: BoxDecoration(
                                                                  color: Color(0xFFF8FAFC),
                                                                  borderRadius: BorderRadius.circular(6.0),
                                                                  border: Border.all(
                                                                    color: Color(0xFFE2E8F0),
                                                                    width: 1.0,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  '작성자',
                                                                  style: TextStyle(
                                                                    fontFamily: 'Pretendard',
                                                                    color: Color(0xFF475569),
                                                                    fontSize: FontSizes.cardMeta,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(width: 8.0),
                                                              Text(
                                                                post.authorName,
                                                                style: TextStyle(
                                                                  fontFamily: 'Pretendard',
                                                                  color: Color(0xFF475569),
                                                                  fontSize: FontSizes.bodyMedium,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                              if (post.memberName != null) ...[
                                                                SizedBox(width: 16.0),
                                                                Container(
                                                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                                  decoration: BoxDecoration(
                                                                    color: Color(0xFFF8FAFC),
                                                                    borderRadius: BorderRadius.circular(6.0),
                                                                    border: Border.all(
                                                                      color: Color(0xFFE2E8F0),
                                                                      width: 1.0,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    '회원',
                                                                    style: TextStyle(
                                                                      fontFamily: 'Pretendard',
                                                                      color: Color(0xFF475569),
                                                                      fontSize: FontSizes.cardMeta,
                                                                      fontWeight: FontWeight.w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(width: 8.0),
                                                                Text(
                                                                  '${post.memberName ?? '개발자'}',
                                                                  style: TextStyle(
                                                                    fontFamily: 'Pretendard',
                                                                    color: Color(0xFF475569),
                                                                    fontSize: FontSizes.bodyMedium,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                              Spacer(),
                                                              Text(
                                                                post.formattedDate,
                                                                style: TextStyle(
                                                                  fontFamily: 'Pretendard',
                                                                  color: Color(0xFF94A3B8),
                                                                  fontSize: FontSizes.bodySmall,
                                                                  fontWeight: FontWeight.w400,
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
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            ), // Expanded 닫는 괄호
                          ],
                        ),
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

  Color _getBoardTypeColor(String boardType) {
    switch (boardType) {
      case '상담기록':
        return Color(0xFFDCF2FF);
      case '회원요청':
        return Color(0xFFF3E8FF);
      case '이벤트기획':
        return Color(0xFFDCFCE7);
      case '기기문제':
        return Color(0xFFFEF3C7);
      case '주차권':
        return Color(0xFFE0F2F1);
      case '락커대기':
        return Color(0xFFFCE4EC);
      case '일반':
        return Color(0xFFF1F5F9);
      default:
        return Color(0xFFF1F5F9);
    }
  }

  IconData _getBoardTypeIcon(String boardType) {
    switch (boardType) {
      case '상담기록':
        return Icons.support_agent;
      case '회원요청':
        return Icons.person_pin;
      case '이벤트기획':
        return Icons.event;
      case '기기문제':
        return Icons.build;
      case '주차권':
        return Icons.local_parking;
      case '락커대기':
        return Icons.lock;
      case '일반':
        return Icons.article;
      default:
        return Icons.article;
    }
  }

  Color _getBoardTypeIconColor(String boardType) {
    switch (boardType) {
      case '상담기록':
        return Color(0xFF3B82F6);
      case '회원요청':
        return Color(0xFF8B5CF6);
      case '이벤트기획':
        return Color(0xFF16A34A);
      case '기기문제':
        return Color(0xFFF59E0B);
      case '주차권':
        return Color(0xFF059669);
      case '락커대기':
        return Color(0xFFDC2626);
      case '일반':
        return Color(0xFF64748B);
      default:
        return Color(0xFF64748B);
    }
  }

  // 게시글 작성 다이얼로그
  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedBoardType = _model.boardTypes.first;
    final memberSearchController = TextEditingController();
    int? selectedMemberId;
    String? selectedMemberInfo;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 700.0,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: 700.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24.0,
                      color: Color(0x1A000000),
                      offset: Offset(0.0, 8.0),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더 섹션 (그라데이션 배경)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(-1.0, 0.0),
                          end: AlignmentDirectional(1.0, 0.0),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Icon(
                                    Icons.edit_note,
                                    color: Colors.white,
                                    size: 24.0,
                                  ),
                                ),
                                SizedBox(width: 16.0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '일반 글쓰기',
                                      style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '작성자: 운영자 (실장) • 작성일: ${DateTime.now().toString().substring(0, 16)}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white.withOpacity(0.8),
                                                    fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // 닫기 버튼
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20.0),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 스크롤 가능한 컨텐츠 섹션
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '제목',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: titleController,
                                      decoration: InputDecoration(
                                        hintText: '게시글 제목을 입력하세요',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                      ),
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                                    fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.0),
                              
                              // 게시글 타입 선택 (개선된 버전)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '게시글 타입',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedBoardType,
                                        isExpanded: true,
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF1E293B),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        dropdownColor: Colors.white,
                                        items: _model.boardTypes.map((String type) {
                                          return DropdownMenuItem<String>(
                                            value: type,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(vertical: 12.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 24.0,
                                                    height: 24.0,
                                                    decoration: BoxDecoration(
                                                      color: _getBoardTypeColor(type),
                                                      borderRadius: BorderRadius.circular(6.0),
                                                    ),
                                                    child: Icon(
                                                      _getBoardTypeIcon(type),
                                                      color: _getBoardTypeIconColor(type),
                                                      size: 16.0,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12.0),
                                                  Text(type),
                                            ],
                                          ),
                                        ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              selectedBoardType = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.0),
                              
                              // 회원 검색 (개선된 버전)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '회원 선택 (선택사항)',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: memberSearchController,
                                      decoration: InputDecoration(
                                        hintText: '회원 이름 또는 전화번호로 검색',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                        suffixIcon: isSearching 
                                            ? Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: SizedBox(
                                                  width: 20.0,
                                                  height: 20.0,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.0,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF3B82F6),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.search,
                                                color: Color(0xFF94A3B8),
                                              ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      onChanged: (value) async {
                                        if (value.length >= 2) {
                                          setState(() {
                                            isSearching = true;
                                          });
                                          
                                          try {
                                            final results = await _searchMembers(value);
                                            setState(() {
                                              searchResults = results;
                                              isSearching = false;
                                            });
                                          } catch (e) {
                                            setState(() {
                                              searchResults = [];
                                              isSearching = false;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            searchResults = [];
                                            selectedMemberId = null;
                                            selectedMemberInfo = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  
                                  // 선택된 회원 정보 표시
                                  if (selectedMemberInfo != null)
                                    Container(
                                      margin: EdgeInsets.only(top: 8.0),
                                      padding: EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFDCF2FF),
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: Color(0xFF3B82F6),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color: Color(0xFF3B82F6),
                                            size: 16.0,
                                          ),
                                          SizedBox(width: 8.0),
                                      Expanded(
                                            child: Text(
                                              '선택된 회원: $selectedMemberInfo',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: Color(0xFF1E293B),
                                                fontSize: FontSizes.bodyMedium,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12.0),
                                              onTap: () {
                                                setState(() {
                                                  selectedMemberId = null;
                                                  selectedMemberInfo = null;
                                                  memberSearchController.clear();
                                                });
                                              },
                                              child: Container(
                                                width: 24.0,
                                                height: 24.0,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF3B82F6),
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                                child: Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 12.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // 검색 결과 목록
                                  if (searchResults.isNotEmpty)
                                    Container(
                                      margin: EdgeInsets.only(top: 8.0),
                                      constraints: BoxConstraints(maxHeight: 200.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 8.0,
                                            color: Color(0x1A000000),
                                            offset: Offset(0.0, 2.0),
                                          )
                                        ],
                                      ),
                                        child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: searchResults.length,
                                          itemBuilder: (context, index) {
                                          final member = searchResults[index];
                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  selectedMemberId = member['member_id'];
                                                  selectedMemberInfo = '${member['member_name']} (${member['member_phone']})';
                                                  memberSearchController.text = selectedMemberInfo!;
                                                  searchResults = [];
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(12.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Color(0xFFF1F5F9),
                                                    width: 1.0,
                                                  ),
                                                ),
                                              ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32.0,
                                                      height: 32.0,
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFFF3E8FF),
                                                        borderRadius: BorderRadius.circular(16.0),
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        color: Color(0xFF8B5CF6),
                                                        size: 16.0,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12.0),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            member['member_name'] ?? '이름 없음',
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF1E293B),
                                                              fontSize: FontSizes.bodyMedium,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          Text(
                                                            member['member_phone'] ?? '전화번호 없음',
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF64748B),
                                                              fontSize: FontSizes.bodySmall,
                                                              fontWeight: FontWeight.w400,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      'ID: ${member['member_id']}',
                                                      style: TextStyle(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF94A3B8),
                                                        fontSize: FontSizes.bodySmall,
                                                        fontWeight: FontWeight.w400,
                                                      ),
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
                              SizedBox(height: 24.0),
                              
                              // 내용 입력 (동적 높이)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '내용',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                                            Container(
                                    width: double.infinity,
                                    constraints: BoxConstraints(
                                      minHeight: 120.0,
                                      maxHeight: 300.0,
                                    ),
                                                              decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                                                borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: contentController,
                                      decoration: InputDecoration(
                                        hintText: '게시글 내용을 입력하세요',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                      ),
                                                                style: TextStyle(
                                                                  fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: null,
                                      minLines: 5,
                                      textAlignVertical: TextAlignVertical.top,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // 하단 버튼 섹션
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16.0),
                          bottomRight: Radius.circular(16.0),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 취소 버튼
                            Container(
                              height: 44.0,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8.0),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    width: 80.0,
                                    height: 44.0,
                                    child: Center(
                                                      child: Text(
                                        '취소',
                                                        style: TextStyle(
                                                          fontFamily: 'Pretendard',
                                                          color: Color(0xFF64748B),
                                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.0),
                            
                            // 작성 버튼
                            Container(
                              height: 44.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                  stops: [0.0, 1.0],
                                  begin: AlignmentDirectional(0.0, -1.0),
                                  end: AlignmentDirectional(0, 1.0),
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 8.0,
                                    color: Color(0x1A06B6D4),
                                    offset: Offset(0.0, 2.0),
                                  )
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8.0),
                                  onTap: () async {
                                    if (titleController.text.trim().isEmpty || 
                                        contentController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('제목과 내용을 모두 입력해주세요.'),
                                          backgroundColor: Color(0xFFEF4444),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    final success = await _model.createPost(
                                      title: titleController.text.trim(),
                                      content: contentController.text.trim(),
                                      boardType: selectedBoardType,
                                      memberId: selectedMemberId,
                                    );
                                    
                                    Navigator.of(context).pop();
                                    
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20.0,
                                              ),
                                              SizedBox(width: 8.0),
                                              Text('게시글이 성공적으로 작성되었습니다.'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFF16A34A),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.error,
                                                color: Colors.white,
                                                size: 20.0,
                                              ),
                                              SizedBox(width: 8.0),
                                              Text('게시글 작성 중 오류가 발생했습니다.'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFFEF4444),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 100.0,
                                    height: 44.0,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 16.0,
                                        ),
                                        SizedBox(width: 8.0),
                                        Text(
                                          '작성',
                                                        style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 회원 검색 함수
  Future<List<Map<String, dynamic>>> _searchMembers(String query) async {
    try {
      // 이름으로 검색
      final nameResults = await ApiService.getMemberData(
        where: [
          {
            'field': 'member_name',
            'operator': 'LIKE',
            'value': '%$query%'
          }
        ],
        limit: 5,
      );
      
      // 전화번호로 검색
      final phoneResults = await ApiService.getMemberData(
        where: [
          {
            'field': 'member_phone',
            'operator': 'LIKE',
            'value': '%$query%'
          }
        ],
        limit: 5,
      );
      
      // 결과 합치기 (중복 제거)
      final allResults = <Map<String, dynamic>>[];
      final seenIds = <int>{};
      
      for (var result in [...nameResults, ...phoneResults]) {
        final id = result['member_id'];
        if (id != null && !seenIds.contains(id)) {
          seenIds.add(id);
          allResults.add(result);
        }
      }
      
      return allResults.take(10).toList();
    } catch (e) {
      print('회원 검색 오류: $e');
      return [];
    }
  }

  void _showPostDetailDialog(BoardPost post) {
    final commentController = TextEditingController();
    List<Map<String, dynamic>> comments = List.from(post.comments); // 이미 로드된 댓글 사용
    bool isLoadingComments = false; // 이미 로드되어 있으므로 false
    bool isAddingComment = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 800.0,
                constraints: BoxConstraints(
                  maxWidth: 800.0,
                  maxHeight: MediaQuery.of(context).size.height * 0.9, // 최대 높이 제한 추가
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24.0,
                      color: Color(0x1A000000),
                      offset: Offset(0.0, 8.0),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더 섹션
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_getBoardTypeColor(post.boardType), _getBoardTypeIconColor(post.boardType)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(-1.0, 0.0),
                          end: AlignmentDirectional(1.0, 0.0),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Icon(
                                    _getBoardTypeIcon(post.boardType),
                                    color: Colors.white,
                                    size: 24.0,
                                  ),
                                ),
                                SizedBox(width: 16.0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.boardType,
                                      style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '작성자: ${post.authorName} • 작성일: ${post.formattedDate}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white.withOpacity(0.8),
                                                          fontSize: FontSizes.bodyMedium,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // 수정 버튼
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20.0),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _showEditPostDialog(post);
                                    },
                                    child: Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.0),
                                
                                // 삭제 버튼
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20.0),
                                    onTap: () {
                                      _showDeleteConfirmDialog(post);
                                    },
                                    child: Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.0),
                                
                                // 닫기 버튼
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20.0),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 게시글 내용 섹션 - 스크롤 가능하도록 수정
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 게시글 제목과 내용
                            Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                                      Expanded(
                                        child: SelectableText(
                                          post.title,
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF1E293B),
                                            fontSize: FontSizes.h2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (post.isNew)
                                        Container(
                                          padding: EdgeInsetsDirectional.fromSTEB(12.0, 6.0, 12.0, 6.0),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            borderRadius: BorderRadius.circular(16.0),
                                          ),
                                                          child: Text(
                                          'NEW',
                                                          style: AppTextStyles.cardBody.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.0),
                                  
                                  // 회원 정보 (있는 경우)
                                  if (post.memberName != null)
                                    Container(
                                      padding: EdgeInsets.all(16.0),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF3E8FF),
                                        borderRadius: BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: Color(0xFF8B5CF6),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color: Color(0xFF8B5CF6),
                                            size: 20.0,
                                          ),
                                          SizedBox(width: 12.0),
                                      Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '관련 회원: ${post.memberName ?? '개발자'}',
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFF1E293B),
                                                    fontSize: FontSizes.bodyMedium,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                    if (post.memberName != null) SizedBox(height: 16.0),
                                    
                                    // 게시글 내용 - 전체 표시
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(20.0),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: SelectableText(
                                        post.content,
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF1E293B),
                                          fontSize: FontSizes.bodyLarge,
                                                          fontWeight: FontWeight.w400,
                                          height: 1.6,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                            ),
                            
                            // 댓글 섹션
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.comment,
                                          color: Color(0xFF3B82F6),
                                          size: 20.0,
                                        ),
                                        SizedBox(width: 8.0),
                                        Text(
                                          '댓글 (${comments.length})',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF1E293B),
                                            fontSize: FontSizes.h4,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20.0),
                                    
                                    // 댓글 목록 (기존 댓글 먼저 표시)
                                    if (isLoadingComments)
                                      Container(
                                        height: 100.0,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (comments.isEmpty)
                                      Container(
                                        padding: EdgeInsets.all(40.0),
                                        child: Center(
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.comment_outlined,
                                                size: 48.0,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              SizedBox(height: 12.0),
                                              Text(
                                                '아직 댓글이 없습니다.',
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF64748B),
                                                  fontSize: FontSizes.bodyMedium,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else
                                      // 댓글 목록 - 스크롤 없이 전체 표시
                                      Column(
                                        children: comments.map((comment) {
                                          return Container(
                                            margin: EdgeInsets.only(bottom: 12.0),
                                            padding: EdgeInsets.all(16.0),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12.0),
                                              border: Border.all(
                                                color: Color(0xFFE2E8F0),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 32.0,
                                                      height: 32.0,
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFFDCF2FF),
                                                        borderRadius: BorderRadius.circular(16.0),
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        color: Color(0xFF3B82F6),
                                                        size: 16.0,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12.0),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            comment['author_name'] ?? '관리자',
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF1E293B),
                                                              fontSize: FontSizes.bodyMedium,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          Text(
                                                            _formatCommentDate(comment['created_at']),
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF94A3B8),
                                                              fontSize: FontSizes.bodySmall,
                                                              fontWeight: FontWeight.w400,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12.0),
                                                SelectableText(
                                                  comment['content'] ?? '',
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFF1E293B),
                                                    fontSize: FontSizes.bodyMedium,
                                                    fontWeight: FontWeight.w400,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    
                                    // 댓글 작성 폼 (목록 아래로 이동)
                                    SizedBox(height: 20.0),
                                    Container(
                                      padding: EdgeInsets.all(20.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '댓글 작성',
                                            style: TextStyle(
                                              fontFamily: 'Pretendard',
                                              color: Color(0xFF1E293B),
                                              fontSize: FontSizes.bodyLarge,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 12.0),
                                          TextFormField(
                                            controller: commentController,
                                            decoration: InputDecoration(
                                              hintText: '댓글을 입력하세요...',
                                              hintStyle: AppTextStyles.bodyTextSmall.copyWith(
                                                color: Color(0xFF94A3B8),
                                              ),
                                              border: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                  width: 1.0,
                                                ),
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Color(0xFF3B82F6),
                                                  width: 2.0,
                                                ),
                                                borderRadius: BorderRadius.circular(8.0),
                                              ),
                                              contentPadding: EdgeInsets.all(16.0),
                                            ),
                                            style: AppTextStyles.bodyTextSmall.copyWith(
                                              color: Color(0xFF1E293B),
                                            ),
                                            maxLines: 3,
                                          ),
                                          SizedBox(height: 12.0),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                height: 36.0,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                                    stops: [0.0, 1.0],
                                                    begin: AlignmentDirectional(0.0, -1.0),
                                                    end: AlignmentDirectional(0, 1.0),
                                                  ),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(6.0),
                                                    onTap: isAddingComment ? null : () async {
                                                      if (commentController.text.trim().isEmpty) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('댓글 내용을 입력해주세요.'),
                                                            backgroundColor: Color(0xFFEF4444),
                                                          ),
                                                        );
                                                        return;
                                                      }
                                                      
                                                      setState(() {
                                                        isAddingComment = true;
                                                      });
                                                      
                                                      final success = await _addComment(
                                                        post.boardId,
                                                        commentController.text.trim(),
                                                      );
                                                      
                                                      if (success) {
                                                        commentController.clear();
                                                        // 댓글 목록 새로고침 - 해당 게시글만 업데이트
                                                        final updatedComments = await _loadComments(post.boardId);
                                                        setState(() {
                                                          comments = updatedComments;
                                                          isAddingComment = false;
                                                        });
                                                        
                                                        // 메인 모델의 해당 게시글 댓글 정보도 업데이트
                                                        _updatePostComments(post.boardId, updatedComments);
                                                        
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('댓글이 등록되었습니다.'),
                                                            backgroundColor: Color(0xFF16A34A),
                                                          ),
                                                        );
                                                      } else {
                                                        setState(() {
                                                          isAddingComment = false;
                                                        });
                                                        
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('댓글 등록 중 오류가 발생했습니다.'),
                                                            backgroundColor: Color(0xFFEF4444),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      width: 80.0,
                                                      height: 36.0,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          if (isAddingComment)
                                                            SizedBox(
                                                              width: 16.0,
                                                              height: 16.0,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2.0,
                                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                              ),
                                                            )
                                                          else
                                                            Icon(
                                                              Icons.send,
                                                              color: Colors.white,
                                                              size: 14.0,
                                                            ),
                                                          if (!isAddingComment) SizedBox(width: 6.0),
                                                          if (!isAddingComment)
                                                            Text(
                                                              '등록',
                                                              style: AppTextStyles.cardBody.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 댓글 로드 함수 (v2_board_comment 구조에 맞게 수정)
  Future<List<Map<String, dynamic>>> _loadComments(int boardId) async {
    try {
      print('🔍 [DEBUG] 댓글 로드 시작: boardId $boardId');
      
      final commentData = await ApiService.getBoardRepliesData(
        where: [
          {'field': 'board_id', 'operator': '=', 'value': boardId}
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'ASC'}
        ],
      );
      
      print('🔍 [DEBUG] 댓글 데이터 로드 완료: ${commentData.length}개');
      
      // v2_board_comment에는 이미 작성자 정보가 포함되어 있음
      List<Map<String, dynamic>> commentsWithAuthor = [];
      
      for (var comment in commentData) {
        // 작성자 이름 결정 (manager_name 또는 pro_name)
        String authorName = '관리자';
        if (comment['manager_name'] != null && comment['manager_name'].toString().isNotEmpty) {
          authorName = comment['manager_name'];
        } else if (comment['pro_name'] != null && comment['pro_name'].toString().isNotEmpty) {
          authorName = comment['pro_name'];
        }
        
        commentsWithAuthor.add({
          ...comment,
          'author_name': authorName, // 통일된 필드명 사용
        });
        
        print('🔍 [DEBUG] 댓글 처리: $authorName - ${comment['content']}');
      }
      
      print('✅ [DEBUG] 댓글 로드 완료: ${commentsWithAuthor.length}개');
      return commentsWithAuthor;
    } catch (e) {
      print('❌ [DEBUG] 댓글 로드 오류: $e');
      return [];
    }
  }

  // 댓글 추가 함수 (v2_board_comment 구조에 맞게 수정)
  Future<bool> _addComment(int boardId, String content) async {
    try {
      // 현재 로그인 사용자 정보 가져오기
      final currentUser = ApiService.getCurrentUser();
      final currentBranchId = ApiService.getCurrentBranchId();
      
      if (currentUser == null || currentBranchId == null) {
        throw Exception('로그인 정보가 없습니다.');
      }
      
      print('🔍 [DEBUG] 댓글 작성 시작');
      print('   • boardId: $boardId');
      print('   • content: $content');
      print('   • 현재 사용자: $currentUser');
      print('   • 현재 지점: $currentBranchId');
      
      final data = {
        'board_id': boardId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
        'branch_id': currentBranchId,
        'manager_id': currentUser['manager_id'],
        'manager_name': currentUser['manager_name'],
        'pro_id': currentUser['pro_id'],
        'pro_name': currentUser['pro_name'],
      };
      
      print('🔍 [DEBUG] 댓글 전송할 데이터: $data');
      
      await ApiService.addBoardReplyData(data);
      
      print('✅ [DEBUG] 댓글 추가 성공');
      return true;
    } catch (e) {
      print('❌ [DEBUG] 댓글 추가 오류: $e');
      return false;
    }
  }

  // 댓글 날짜 포맷팅
  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      DateTime date = DateTime.parse(dateString);
      DateTime now = DateTime.now();
      Duration difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분 전';
      } else {
        return '방금 전';
      }
    } catch (e) {
      return dateString;
    }
  }

  String _formatCommentDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      DateTime date = DateTime.parse(dateString);
      DateTime now = DateTime.now();
      Duration difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분 전';
      } else {
        return '방금 전';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _updatePostComments(int boardId, List<Map<String, dynamic>> comments) {
    _model.updatePostComments(boardId, comments);
    setState(() {}); // UI 업데이트
  }

  // 게시글 수정 다이얼로그
  void _showEditPostDialog(BoardPost post) {
    final titleController = TextEditingController(text: post.title);
    final contentController = TextEditingController(text: post.content);
    String selectedBoardType = post.boardType;
    final memberSearchController = TextEditingController();
    int? selectedMemberId = post.memberId;
    String? selectedMemberInfo = post.memberName != null 
        ? '${post.memberName ?? '개발자'}'
        : null;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    if (selectedMemberInfo != null) {
      memberSearchController.text = selectedMemberInfo;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 700.0,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  maxWidth: 700.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24.0,
                      color: Color(0x1A000000),
                      offset: Offset(0.0, 8.0),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더 섹션 (수정용 그라데이션)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(-1.0, 0.0),
                          end: AlignmentDirectional(1.0, 0.0),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Icon(
                                    Icons.edit_note,
                                    color: Colors.white,
                                    size: 24.0,
                                  ),
                                ),
                                SizedBox(width: 16.0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '게시글 수정',
                                      style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '작성자: ${post.authorName} • 작성일: ${post.formattedDate}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20.0),
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 스크롤 가능한 컨텐츠 섹션 (기존 작성 다이얼로그와 동일한 구조)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '제목',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: titleController,
                                      decoration: InputDecoration(
                                        hintText: '게시글 제목을 입력하세요',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.0),
                              
                              // 게시글 타입 선택
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '게시글 타입',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedBoardType,
                                        isExpanded: true,
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF1E293B),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        dropdownColor: Colors.white,
                                        items: _model.boardTypes.map((String type) {
                                          return DropdownMenuItem<String>(
                                            value: type,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(vertical: 12.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 24.0,
                                                    height: 24.0,
                                                    decoration: BoxDecoration(
                                                      color: _getBoardTypeColor(type),
                                                      borderRadius: BorderRadius.circular(6.0),
                                                    ),
                                                    child: Icon(
                                                      _getBoardTypeIcon(type),
                                                      color: _getBoardTypeIconColor(type),
                                                      size: 16.0,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12.0),
                                                  Text(type),
                                            ],
                                          ),
                                        ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              selectedBoardType = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.0),
                              
                              // 회원 검색 (기존과 동일)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '회원 선택 (선택사항)',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: memberSearchController,
                                      decoration: InputDecoration(
                                        hintText: '회원 이름 또는 전화번호로 검색',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                        suffixIcon: isSearching 
                                            ? Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: SizedBox(
                                                  width: 20.0,
                                                  height: 20.0,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.0,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF3B82F6),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.search,
                                                color: Color(0xFF94A3B8),
                                              ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      onChanged: (value) async {
                                        if (value.length >= 2) {
                                          setState(() {
                                            isSearching = true;
                                          });
                                          
                                          try {
                                            final results = await _searchMembers(value);
                                            setState(() {
                                              searchResults = results;
                                              isSearching = false;
                                            });
                                          } catch (e) {
                                            setState(() {
                                              searchResults = [];
                                              isSearching = false;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            searchResults = [];
                                            selectedMemberId = null;
                                            selectedMemberInfo = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  
                                  // 선택된 회원 정보 표시
                                  if (selectedMemberInfo != null)
                                    Container(
                                      margin: EdgeInsets.only(top: 8.0),
                                      padding: EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFDCF2FF),
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: Color(0xFF3B82F6),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color: Color(0xFF3B82F6),
                                            size: 16.0,
                                          ),
                                          SizedBox(width: 8.0),
                                      Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '선택된 회원: $selectedMemberInfo',
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFF1E293B),
                                                    fontSize: FontSizes.bodyMedium,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // 검색 결과 목록 (기존과 동일)
                                  if (searchResults.isNotEmpty)
                                    Container(
                                      margin: EdgeInsets.only(top: 8.0),
                                      constraints: BoxConstraints(maxHeight: 200.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8.0),
                                        border: Border.all(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 8.0,
                                            color: Color(0x1A000000),
                                            offset: Offset(0.0, 2.0),
                                          )
                                        ],
                                      ),
                                        child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: searchResults.length,
                                          itemBuilder: (context, index) {
                                          final member = searchResults[index];
                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  selectedMemberId = member['member_id'];
                                                  selectedMemberInfo = '${member['member_name']} (${member['member_phone']})';
                                                  memberSearchController.text = selectedMemberInfo!;
                                                  searchResults = [];
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(12.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Color(0xFFF1F5F9),
                                                    width: 1.0,
                                                  ),
                                                ),
                                              ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32.0,
                                                      height: 32.0,
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFFF3E8FF),
                                                        borderRadius: BorderRadius.circular(16.0),
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        color: Color(0xFF8B5CF6),
                                                        size: 16.0,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12.0),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            member['member_name'] ?? '이름 없음',
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF1E293B),
                                                              fontSize: FontSizes.bodyMedium,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          Text(
                                                            member['member_phone'] ?? '전화번호 없음',
                                                            style: TextStyle(
                                                              fontFamily: 'Pretendard',
                                                              color: Color(0xFF64748B),
                                                              fontSize: FontSizes.bodySmall,
                                                              fontWeight: FontWeight.w400,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      'ID: ${member['member_id']}',
                                                      style: TextStyle(
                                                        fontFamily: 'Pretendard',
                                                        color: Color(0xFF94A3B8),
                                                        fontSize: FontSizes.bodySmall,
                                                        fontWeight: FontWeight.w400,
                                                      ),
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
                              SizedBox(height: 24.0),
                              
                              // 내용 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '내용',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: FontSizes.bodyLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Container(
                                    width: double.infinity,
                                    constraints: BoxConstraints(
                                      minHeight: 120.0,
                                      maxHeight: 300.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: contentController,
                                      decoration: InputDecoration(
                                        hintText: '게시글 내용을 입력하세요',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: FontSizes.bodyMedium,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: null,
                                      minLines: 5,
                                      textAlignVertical: TextAlignVertical.top,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // 하단 버튼 섹션
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16.0),
                          bottomRight: Radius.circular(16.0),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 취소 버튼
                            Container(
                              height: 44.0,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8.0),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    width: 80.0,
                                    height: 44.0,
                                    child: Center(
                                      child: Text(
                                        '취소',
                                                        style: TextStyle(
                                                          fontFamily: 'Pretendard',
                                                          color: Color(0xFF64748B),
                                                          fontSize: FontSizes.bodyMedium,
                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.0),
                            
                            // 수정 버튼
                            Container(
                              height: 44.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  stops: [0.0, 1.0],
                                  begin: AlignmentDirectional(0.0, -1.0),
                                  end: AlignmentDirectional(0, 1.0),
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 8.0,
                                    color: Color(0x1AF59E0B),
                                    offset: Offset(0.0, 2.0),
                                  )
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8.0),
                                  onTap: () async {
                                    if (titleController.text.trim().isEmpty || 
                                        contentController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('제목과 내용을 모두 입력해주세요.'),
                                          backgroundColor: Color(0xFFEF4444),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    final success = await _updatePost(
                                      boardId: post.boardId,
                                      title: titleController.text.trim(),
                                      content: contentController.text.trim(),
                                      boardType: selectedBoardType,
                                      memberId: selectedMemberId,
                                    );
                                    
                                    Navigator.of(context).pop();
                                    
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20.0,
                                              ),
                                              SizedBox(width: 8.0),
                                              Text('게시글이 성공적으로 수정되었습니다.'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFF16A34A),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                Icons.error,
                                                color: Colors.white,
                                                size: 20.0,
                                              ),
                                              SizedBox(width: 8.0),
                                              Text('게시글 수정 중 오류가 발생했습니다.'),
                                            ],
                                          ),
                                          backgroundColor: Color(0xFFEF4444),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 100.0,
                                    height: 44.0,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.save,
                                          color: Colors.white,
                                          size: 16.0,
                                        ),
                                        SizedBox(width: 8.0),
                                        Text(
                                          '수정',
                                                        style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 게시글 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(BoardPost post) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24.0,
                  color: Color(0x1A000000),
                  offset: Offset(0.0, 8.0),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더 섹션 (삭제용 빨간색 그라데이션)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(-1.0, 0.0),
                      end: AlignmentDirectional(1.0, 0.0),
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Icon(
                            Icons.warning,
                            color: Colors.white,
                            size: 24.0,
                          ),
                        ),
                        SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '게시글 삭제',
                                style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '이 작업은 되돌릴 수 없습니다.',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: FontSizes.bodyMedium,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 내용 섹션
                Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '정말로 이 게시글을 삭제하시겠습니까?',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFF1E293B),
                          fontSize: FontSizes.bodyLarge,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16.0),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '제목: ${post.title}',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF1E293B),
                                fontSize: FontSizes.bodyMedium,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              '타입: ${post.boardType}',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF64748B),
                                fontSize: FontSizes.bodyMedium,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '작성자: ${post.authorName}',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF64748B),
                                fontSize: FontSizes.bodyMedium,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '작성일: ${post.formattedDate}',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF64748B),
                                fontSize: FontSizes.bodyMedium,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.0),
                      Text(
                        '• 게시글과 관련된 모든 댓글도 함께 삭제됩니다.\n• 삭제된 데이터는 복구할 수 없습니다.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: Color(0xFFEF4444),
                          fontSize: FontSizes.bodyMedium,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 하단 버튼 섹션
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.0),
                      bottomRight: Radius.circular(16.0),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 취소 버튼
                        Container(
                          height: 44.0,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8.0),
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: 80.0,
                                height: 44.0,
                                child: Center(
                                  child: Text(
                                    '취소',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF64748B),
                                      fontSize: FontSizes.bodyMedium,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.0),
                        
                        // 삭제 버튼
                        Container(
                          height: 44.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              stops: [0.0, 1.0],
                              begin: AlignmentDirectional(0.0, -1.0),
                              end: AlignmentDirectional(0, 1.0),
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8.0,
                                color: Color(0x1AEF4444),
                                offset: Offset(0.0, 2.0),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8.0),
                              onTap: () async {
                                Navigator.of(context).pop(); // 확인 다이얼로그 닫기
                                
                                final success = await _model.deletePost(post.boardId);
                                
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 20.0,
                                          ),
                                          SizedBox(width: 8.0),
                                          Text('게시글이 성공적으로 삭제되었습니다.'),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFF16A34A),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.error,
                                            color: Colors.white,
                                            size: 20.0,
                                          ),
                                          SizedBox(width: 8.0),
                                          Text('게시글 삭제 중 오류가 발생했습니다.'),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 100.0,
                                height: 44.0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete_forever,
                                      color: Colors.white,
                                      size: 16.0,
                                    ),
                                    SizedBox(width: 8.0),
                                    Text(
                                      '삭제',
                                      style: AppTextStyles.formLabel.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 게시글 수정 함수
  Future<bool> _updatePost({
    required int boardId,
    required String title,
    required String content,
    required String boardType,
    int? memberId,
  }) async {
    try {
      final data = {
        'title': title,
        'content': content,
        'board_type': boardType,
        'member_id': memberId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ApiService.updateBoardData(
        data,
        [
          {'field': 'board_id', 'operator': '=', 'value': boardId}
        ],
      );

      // 목록 새로고침
      await _model.refresh();
      return true;
    } catch (e) {
      print('게시글 수정 오류: $e');
      return false;
    }
  }
} 