import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'tab1_memo_tab_model.dart';
export 'tab1_memo_tab_model.dart';

class Tab1MemoTabWidget extends StatefulWidget {
  const Tab1MemoTabWidget({
    super.key,
    required this.memberId,
  });

  final int memberId;

  @override
  State<Tab1MemoTabWidget> createState() => _Tab1MemoTabWidgetState();
}

class _Tab1MemoTabWidgetState extends State<Tab1MemoTabWidget> {
  late Tab1MemoTabModel _model;

  @override
  void initState() {
    super.initState();
    _model = Tab1MemoTabModel();
    _model.initState(context, widget.memberId);
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Color(0xFFF8FAFC),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 섹션 (메모 작성 버튼만)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
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
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () async {
                          _showCreateMemoDialog();
                        },
                        child: Container(
                          width: 110.0,
                          height: 36.0,
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
                                size: 16.0,
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  '메모 작성',
                                  style: AppTextStyles.tagMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
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
          
          // 메모 목록 섹션 (바로 표시)
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
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
                              style: AppTextStyles.cardTitle.copyWith(
                                color: Color(0xFF1E293B),
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
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
                  
                  if (_model.memos.isEmpty) {
                    return Container(
                      height: 400.0,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 64.0,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 16.0),
                            Text(
                              '이 회원과 관련된 메모가 없습니다.',
                              style: AppTextStyles.cardTitle.copyWith(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              '첫 번째 메모를 작성해보세요.',
                              style: AppTextStyles.bodyTextSmall.copyWith(
                                color: Color(0xFF94A3B8),
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
                      itemCount: _model.memos.length,
                      itemBuilder: (context, index) {
                        final memo = _model.memos[index];
                        
                        return _buildMemoItem(memo);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoItem(MemoPost memo) {
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
            _showMemoDetailDialog(memo);
          },
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 메모 타입 아이콘과 타입을 하나의 박스에
                Container(
                  width: 65.0,
                  height: 65.0,
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: _getBoardTypeColor(memo.boardType),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getBoardTypeIcon(memo.boardType),
                        color: _getBoardTypeIconColor(memo.boardType),
                        size: 24.0,
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        memo.boardType,
                        style: AppTextStyles.cardMeta.copyWith(
                          color: _getBoardTypeIconColor(memo.boardType),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.0),
                
                // 메모 내용
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: SelectableText(
                              memo.title,
                              style: AppTextStyles.cardTitle.copyWith(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (memo.isNew)
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
                        memo.content,
                        style: AppTextStyles.bodyTextSmall.copyWith(
                          color: Color(0xFF64748B),
                          height: 1.5,
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
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            memo.staffName,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Color(0xFF475569),
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (memo.memberName != null) ...[
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
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.0),
                            Text(
                              '${memo.memberName}${memo.memberPhone != null ? ' (${memo.memberPhone})' : ''}',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF475569),
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          Spacer(),
                          Text(
                            memo.formattedDate,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Color(0xFF94A3B8),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      
                      // 댓글 섹션
                      if (memo.comments.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16.0),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12.0),
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
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.comment,
                                        color: Color(0xFF3B82F6),
                                        size: 16.0,
                                      ),
                                      SizedBox(width: 6.0),
                                      Text(
                                        '댓글 ${memo.comments.length}개',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF1E293B),
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.0),
                                  ...memo.comments.take(3).map((comment) {
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 8.0),
                                      padding: EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6.0),
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
                                                width: 20.0,
                                                height: 20.0,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFDCF2FF),
                                                  borderRadius: BorderRadius.circular(10.0),
                                                ),
                                                child: Icon(
                                                  Icons.person,
                                                  color: Color(0xFF3B82F6),
                                                  size: 12.0,
                                                ),
                                              ),
                                              SizedBox(width: 6.0),
                                              Text(
                                                comment['staff_name'] ?? '관리자',
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF1E293B),
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(width: 6.0),
                                              Text(
                                                _formatCommentDate(comment['created_at']),
                                                style: TextStyle(
                                                  fontFamily: 'Pretendard',
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 10.0,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.0),
                                          SelectableText(
                                            comment['content'] ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Pretendard',
                                              color: Color(0xFF1E293B),
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w400,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  if (memo.comments.length > 3)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '+ ${memo.comments.length - 3}개 댓글 더보기',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF3B82F6),
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
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
        return Icons.note;
      default:
        return Icons.note;
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

  // 메모 작성 다이얼로그
  void _showCreateMemoDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedBoardType = _model.boardTypes.first;

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
                    // 헤더 섹션
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
                                      '회원 메모 작성',
                                      style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '회원번호: ${_model.memberNoBranch ?? '-'} • 작성일: ${DateTime.now().toString().substring(0, 16)}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14.0,
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
                                      fontSize: 16.0,
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
                                        hintText: '메모 제목을 입력하세요',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.0),
                              
                              // 메모 타입 선택
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '메모 타입',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: 16.0,
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
                                          fontSize: 14.0,
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
                              
                              // 내용 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '내용',
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF1E293B),
                                      fontSize: 16.0,
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
                                        hintText: '메모 내용을 입력하세요',
                                        hintStyle: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF94A3B8),
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16.0),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: 14.0,
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
                                          fontSize: 14.0,
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
                                    
                                    final success = await _model.createMemo(
                                      title: titleController.text.trim(),
                                      content: contentController.text.trim(),
                                      boardType: selectedBoardType,
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
                                              Text('메모가 성공적으로 작성되었습니다.'),
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
                                              Text('메모 작성 중 오류가 발생했습니다.'),
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

  // 메모 상세 다이얼로그
  void _showMemoDetailDialog(MemoPost memo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 800.0,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: 800.0,
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
                // 헤더
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _getBoardTypeColor(memo.boardType),
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
                            _getBoardTypeIcon(memo.boardType),
                            color: _getBoardTypeIconColor(memo.boardType),
                            size: 24.0,
                          ),
                        ),
                        SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                memo.title,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF1E293B),
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${memo.boardType} • ${memo.staffName} • ${memo.formattedDate}',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF64748B),
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20.0),
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF64748B),
                                size: 20.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 내용
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            memo.content,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Color(0xFF1E293B),
                              fontSize: 16.0,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                            ),
                          ),
                          if (memo.comments.isNotEmpty) ...[
                            SizedBox(height: 32.0),
                            Text(
                              '댓글 ${memo.comments.length}개',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: Color(0xFF1E293B),
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 16.0),
                            ...memo.comments.map((comment) {
                              return Container(
                                margin: EdgeInsets.only(bottom: 16.0),
                                padding: EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8FAFC),
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
                                        Text(
                                          comment['staff_name'] ?? '관리자',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF1E293B),
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 8.0),
                                        Text(
                                          _formatCommentDate(comment['created_at']),
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF94A3B8),
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.0),
                                    SelectableText(
                                      comment['content'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF1E293B),
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w400,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
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

  // 댓글 날짜 포맷팅
  String _formatCommentDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      DateTime date = DateTime.parse(dateString);
      DateTime now = DateTime.now();
      Duration difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return '방금 전';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}분 전';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}시간 전';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else {
        return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateString;
    }
  }
} 