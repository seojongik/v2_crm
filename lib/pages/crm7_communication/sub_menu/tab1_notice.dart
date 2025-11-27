import 'package:flutter/material.dart';
import '../../../constants/font_sizes.dart';
import '../../../services/api_service.dart';
import '../../../services/upper_button_input_design.dart';
import 'package:intl/intl.dart';

class Tab1NoticeWidget extends StatefulWidget {
  @override
  _Tab1NoticeWidgetState createState() => _Tab1NoticeWidgetState();
}

class _Tab1NoticeWidgetState extends State<Tab1NoticeWidget> {
  bool isLoading = false;
  List<Map<String, dynamic>> boardList = [];
  String searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBoardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadBoardData() async {
    print('🔍 [UI DEBUG] _loadBoardData 시작 - 공지사항');
    print('🔍 [UI DEBUG] 검색 키워드: "$searchKeyword"');
    print('🔍 [UI DEBUG] 현재 branch_id: ${ApiService.getCurrentBranchId()}');
    print('🔍 [UI DEBUG] 현재 branch 정보: ${ApiService.getCurrentBranch()}');
    
    setState(() {
      isLoading = true;
    });

    try {
      final whereConditions = [
        {'field': 'board_type', 'operator': '=', 'value': '공지사항'},
        if (searchKeyword.isNotEmpty) 
          {'field': 'title', 'operator': 'LIKE', 'value': '%$searchKeyword%'},
      ];
      
      print('🔍 [UI DEBUG] WHERE 조건: $whereConditions');
      
      final data = await ApiService.getBoardByMemberData(
        where: whereConditions,
        orderBy: [
          {'field': 'created_at', 'direction': 'DESC'},
        ],
      );
      
      print('✅ [UI DEBUG] 데이터 로드 성공: ${data.length}개');
      setState(() {
        boardList = data;
      });
    } catch (e) {
      print('❌ [UI DEBUG] 데이터 로드 실패: $e');
      _showErrorSnackBar('게시글 로드 실패: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchKeyword = value;
    });
    _loadBoardData();
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.announcement, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '공지사항 작성',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // 내용
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '제목',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '공지사항 제목을 입력하세요',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '내용',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 200,
                          child: TextField(
                            controller: _contentController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: '공지사항 내용을 입력하세요',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 버튼
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _titleController.clear();
                            _contentController.clear();
                            Navigator.of(context).pop();
                          },
                          child: Text('취소'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _createPost(),
                          child: Text('작성', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
      },
    );
  }

  Future<void> _createPost() async {
    print('🔍 [UI DEBUG] _createPost 시작');
    print('📝 [UI DEBUG] 제목: "${_titleController.text.trim()}"');
    print('📝 [UI DEBUG] 내용: "${_contentController.text.trim()}"');
    
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      print('⚠️ [UI DEBUG] 제목이나 내용이 비어있음');
      _showErrorSnackBar('제목과 내용을 모두 입력해주세요');
      return;
    }

    try {
      final branchData = ApiService.getCurrentBranch();
      final branchName = branchData?['branch_name'] ?? '관리자';
      
      print('🏢 [UI DEBUG] 현재 branch 정보: $branchData');
      print('👤 [UI DEBUG] 작성자명: $branchName');
      
      final postData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'board_type': '공지사항',
        'member_name': branchName,
      };
      
      print('📋 [UI DEBUG] 작성할 게시글 데이터: $postData');
      
      await ApiService.addBoardByMemberData(postData);

      print('🎉 [UI DEBUG] 게시글 작성 완료!');
      
      _titleController.clear();
      _contentController.clear();
      Navigator.of(context).pop();
      _showSuccessSnackBar('공지사항이 작성되었습니다');
      _loadBoardData();
    } catch (e) {
      print('❌ [UI DEBUG] 게시글 작성 실패: $e');
      _showErrorSnackBar('작성 실패: ${e.toString()}');
    }
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
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _PostDetailDialog(
          post: post,
          onReplyAdded: () => _loadBoardData(),
          onPostUpdated: () => _loadBoardData(),
          onPostDeleted: () => _loadBoardData(),
          replyController: _replyController,
        );
      },
    );
  }

  void _showEditPostDialog(Map<String, dynamic> post) {
    _titleController.text = post['title'] ?? '';
    _contentController.text = post['content'] ?? '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '공지사항 수정',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // 내용
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '제목',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '공지사항 제목을 입력하세요',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '내용',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 200,
                          child: TextField(
                            controller: _contentController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: '공지사항 내용을 입력하세요',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 버튼
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _titleController.clear();
                            _contentController.clear();
                            Navigator.of(context).pop();
                          },
                          child: Text('취소'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updatePost(post),
                          child: Text('수정', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
      },
    );
  }

  Future<void> _updatePost(Map<String, dynamic> post) async {
    print('🔍 [UI DEBUG] _updatePost 시작 - 공지사항');
    print('📝 [UI DEBUG] 수정할 게시글 ID: ${post['memberboard_id']}');
    print('📝 [UI DEBUG] 새 제목: "${_titleController.text.trim()}"');
    print('📝 [UI DEBUG] 새 내용: "${_contentController.text.trim()}"');
    
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      print('⚠️ [UI DEBUG] 제목이나 내용이 비어있음');
      _showErrorSnackBar('제목과 내용을 모두 입력해주세요');
      return;
    }

    try {
      final updateData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
      };
      
      print('📋 [UI DEBUG] 수정할 데이터: $updateData');
      
      await ApiService.updateBoardByMemberData(
        updateData,
        [{'field': 'memberboard_id', 'operator': '=', 'value': post['memberboard_id']}]
      );

      print('🎉 [UI DEBUG] 게시글 수정 완료!');
      
      _titleController.clear();
      _contentController.clear();
      Navigator.of(context).pop();
      _showSuccessSnackBar('공지사항이 수정되었습니다');
      _loadBoardData();
    } catch (e) {
      print('❌ [UI DEBUG] 게시글 수정 실패: $e');
      _showErrorSnackBar('수정 실패: ${e.toString()}');
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    print('🔍 [UI DEBUG] _deletePost 시작 - 공지사항');
    print('🗑️ [UI DEBUG] 삭제할 게시글 ID: ${post['memberboard_id']}');
    print('🗑️ [UI DEBUG] 삭제할 게시글 제목: "${post['title']}"');
    
    // 삭제 확인 다이얼로그
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('삭제 확인'),
            ],
          ),
          content: Text('이 공지사항을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('삭제', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) {
      print('❌ [UI DEBUG] 사용자가 삭제 취소');
      return;
    }

    try {
      await ApiService.deleteBoardByMemberData([
        {'field': 'memberboard_id', 'operator': '=', 'value': post['memberboard_id']}
      ]);

      print('🎉 [UI DEBUG] 게시글 삭제 완료!');
      _showSuccessSnackBar('공지사항이 삭제되었습니다');
      _loadBoardData();
    } catch (e) {
      print('❌ [UI DEBUG] 게시글 삭제 실패: $e');
      _showErrorSnackBar('삭제 실패: ${e.toString()}');
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
              // 왼쪽: 공지 작성 버튼 + 안내 아이콘
              Row(
                children: [
                  ButtonDesignUpper.buildIconButton(
                    text: '공지 작성',
                    icon: Icons.announcement,
                    onPressed: _showCreatePostDialog,
                    color: 'purple',
                    size: 'large',
                  ),
                  SizedBox(width: 8.0),
                  ButtonDesignUpper.buildHelpTooltip(
                    message: '고객 APP에 공지사항으로 등록됩니다',
                  ),
                ],
              ),

              // 오른쪽: 검색창
              ButtonDesignUpper.buildSearchField(
                controller: _searchController,
                hintText: '공지사항 검색',
                onSubmitted: _onSearchChanged,
                width: 300.0,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 컨텐츠
        Container(
          height: 570,
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                )
              : boardList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.announcement,
                              size: 64,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            '등록된 공지사항이 없습니다',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '새로운 공지사항을 작성해보세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF000000).withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.all(0),
                        itemCount: boardList.length,
                        itemBuilder: (context, index) {
                          final board = boardList[index];
                          return InkWell(
                            onTap: () => _showPostDetailDialog(board),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFE5E7EB),
                                    width: index < boardList.length - 1 ? 1 : 0,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.announcement,
                                    color: Color(0xFF6366F1),
                                    size: 16,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        board['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        board['content'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            board['member_name'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            _formatDate(board['created_at']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (board['post_status'] == '진행')
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '진행중',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }
}

class _PostDetailDialog extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onReplyAdded;
  final VoidCallback onPostUpdated;
  final VoidCallback onPostDeleted;
  final TextEditingController replyController;

  const _PostDetailDialog({
    Key? key,
    required this.post,
    required this.onReplyAdded,
    required this.onPostUpdated,
    required this.onPostDeleted,
    required this.replyController,
  }) : super(key: key);

  @override
  _PostDetailDialogState createState() => _PostDetailDialogState();
}

class _PostDetailDialogState extends State<_PostDetailDialog> {
  List<Map<String, dynamic>> replies = [];
  bool isLoadingReplies = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() {
      isLoadingReplies = true;
    });

    try {
      final data = await ApiService.getBoardRepliesData(
        where: [
          {'field': 'memberboard_id', 'operator': '=', 'value': widget.post['memberboard_id']},
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'ASC'},
        ],
      );
      setState(() {
        replies = data;
      });
    } catch (e) {
      _showErrorSnackBar('댓글 로드 실패: ${e.toString()}');
    } finally {
      setState(() {
        isLoadingReplies = false;
      });
    }
  }

  Future<void> _addReply() async {
    if (widget.replyController.text.trim().isEmpty) {
      _showErrorSnackBar('댓글 내용을 입력해주세요');
      return;
    }

    try {
      final branchData = ApiService.getCurrentBranch();
      final branchName = branchData?['branch_name'] ?? '관리자';
      
      await ApiService.addBoardReplyData({
        'memberboard_id': widget.post['memberboard_id'],
        'reply_by_member': widget.replyController.text.trim(),
        'member_name': branchName,
      });

      widget.replyController.clear();
      _showSuccessSnackBar('댓글이 작성되었습니다');
      _loadReplies();
      widget.onReplyAdded();
    } catch (e) {
      _showErrorSnackBar('댓글 작성 실패: ${e.toString()}');
    }
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
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _showEditPostDialog() {
    final titleController = TextEditingController(text: widget.post['title'] ?? '');
    final contentController = TextEditingController(text: widget.post['content'] ?? '');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '공지사항 수정',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // 내용
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '제목',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: titleController,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '공지사항 제목을 입력하세요',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '내용',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 200,
                          child: TextField(
                            controller: contentController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: '공지사항 내용을 입력하세요',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 버튼
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('취소'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updatePost(titleController, contentController),
                          child: Text('수정', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
      },
    );
  }

  Future<void> _updatePost(TextEditingController titleController, TextEditingController contentController) async {
    print('🔍 [UI DEBUG] _updatePost 시작 - 공지사항 (DetailDialog)');
    print('📝 [UI DEBUG] 수정할 게시글 ID: ${widget.post['memberboard_id']}');
    
    if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
      _showErrorSnackBar('제목과 내용을 모두 입력해주세요');
      return;
    }

    try {
      final updateData = {
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
      };
      
      await ApiService.updateBoardByMemberData(
        updateData,
        [{'field': 'memberboard_id', 'operator': '=', 'value': widget.post['memberboard_id']}]
      );

      print('🎉 [UI DEBUG] 게시글 수정 완료!');
      Navigator.of(context).pop();
      Navigator.of(context).pop(); // DetailDialog도 닫기
      _showSuccessSnackBar('공지사항이 수정되었습니다');
      widget.onPostUpdated();
    } catch (e) {
      print('❌ [UI DEBUG] 게시글 수정 실패: $e');
      _showErrorSnackBar('수정 실패: ${e.toString()}');
    }
  }

  Future<void> _deletePost() async {
    print('🔍 [UI DEBUG] _deletePost 시작 - 공지사항 (DetailDialog)');
    print('🗑️ [UI DEBUG] 삭제할 게시글 ID: ${widget.post['memberboard_id']}');
    
    // 삭제 확인 다이얼로그
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('삭제 확인'),
            ],
          ),
          content: Text('이 공지사항을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('삭제', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) {
      print('❌ [UI DEBUG] 사용자가 삭제 취소');
      return;
    }

    try {
      await ApiService.deleteBoardByMemberData([
        {'field': 'memberboard_id', 'operator': '=', 'value': widget.post['memberboard_id']}
      ]);

      print('🎉 [UI DEBUG] 게시글 삭제 완료!');
      Navigator.of(context).pop(); // DetailDialog 닫기
      _showSuccessSnackBar('공지사항이 삭제되었습니다');
      widget.onPostDeleted();
    } catch (e) {
      print('❌ [UI DEBUG] 게시글 삭제 실패: $e');
      _showErrorSnackBar('삭제 실패: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF6366F1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.announcement, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.post['title'] ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditPostDialog();
                    },
                    icon: Icon(Icons.edit, color: Colors.white),
                    tooltip: '수정',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deletePost();
                    },
                    icon: Icon(Icons.delete, color: Colors.white),
                    tooltip: '삭제',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // 본문 내용
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 게시글 정보
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Color(0xFF9CA3AF)),
                              SizedBox(width: 4),
                              Text(
                                widget.post['member_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.schedule, size: 16, color: Color(0xFF9CA3AF)),
                              SizedBox(width: 4),
                              Text(
                                _formatDate(widget.post['created_at']),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            widget.post['content'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF374151),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Divider(color: Color(0xFFE5E7EB)),
                    
                    // 댓글 목록
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '댓글 (${replies.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          if (isLoadingReplies)
                            Center(child: CircularProgressIndicator())
                          else if (replies.isEmpty)
                            Container(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  '댓글이 없습니다',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: replies.map((reply) {
                                return Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: Color(0xFF9CA3AF)),
                                          SizedBox(width: 4),
                                          Text(
                                            reply['member_name'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Icon(Icons.schedule, size: 14, color: Color(0xFF9CA3AF)),
                                          SizedBox(width: 4),
                                          Text(
                                            _formatDate(reply['created_at']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        reply['reply_by_member'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 댓글 입력
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: widget.replyController,
                    maxLines: 3,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Spacer(),
                      ElevatedButton(
                        onPressed: _addReply,
                        child: Text('댓글 작성', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6366F1),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
    );
  }
}