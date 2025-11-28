import 'package:flutter/material.dart';
import '/services/api_service.dart';

class MemoPost {
  final int boardId;
  final String title;
  final String content;
  final String boardType;
  final String staffName;
  final String? memberName;
  final String? memberPhone;
  final String formattedDate;
  final bool isNew;
  final List<Map<String, dynamic>> comments;

  MemoPost({
    required this.boardId,
    required this.title,
    required this.content,
    required this.boardType,
    required this.staffName,
    this.memberName,
    this.memberPhone,
    required this.formattedDate,
    required this.isNew,
    required this.comments,
  });
}

class Tab1MemoTabModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<MemoPost> _memos = [];
  int _memberId = 0;
  int? _memberNoBranch;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MemoPost> get memos => _memos;
  int? get memberNoBranch => _memberNoBranch;

  final List<String> boardTypes = [
    '상담기록',
    '회원요청',
    '이벤트기획',
    '기기문제',
    '주차권',
    '락커대기',
    '일반'
  ];

  void initState(BuildContext context, int memberId) {
    _memberId = memberId;
    loadMemos();
  }

  void dispose() {
    // 정리 작업
  }

  // 메모 데이터 로드
  Future<void> loadMemos() async {
    print('메모 로드 시작 - 회원 ID: $_memberId');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 회원 정보 조회 (member_no_branch를 가져오기 위해)
      try {
        final memberInfoData = await ApiService.getMemberData(
          fields: ['member_no_branch'],
          where: [
            {'field': 'member_id', 'operator': '=', 'value': _memberId},
            {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
          ],
          limit: 1,
        );
        if (memberInfoData.isNotEmpty) {
          _memberNoBranch = memberInfoData[0]['member_no_branch'];
          print('회원번호 조회 완료: $_memberNoBranch');
        }
      } catch (e) {
        print('회원번호 조회 오류: $e');
      }

      // Board 테이블에서 해당 회원의 메모 조회
      print('Board 데이터 조회 시작');
      final boardData = await ApiService.getBoardData(
        where: [
          {'field': 'member_id', 'operator': '=', 'value': _memberId},
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
        ],
        orderBy: [
          {'field': 'created_at', 'direction': 'DESC'}
        ],
      );

      print('Board 데이터 조회 완료: ${boardData.length}건');

      List<MemoPost> memos = [];

      for (var board in boardData) {
        print('Board 처리 중: ${board['board_id']} - ${board['title']}');

        // 작성자 이름 (manager_name이 있으면 사용)
        String staffName = board['manager_name'] ?? '관리자';

        // Member 정보 가져오기
        String? memberName;
        String? memberPhone;
        try {
          final memberData = await ApiService.getMemberData(
            where: [
              {'field': 'member_id', 'operator': '=', 'value': board['member_id']},
              {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
            ],
            limit: 1,
          );
          if (memberData.isNotEmpty) {
            memberName = memberData[0]['member_name'];
            memberPhone = memberData[0]['member_phone'];
          }
        } catch (e) {
          print('Member 정보 로드 오류: $e');
        }

        // 댓글 정보 가져오기
        List<Map<String, dynamic>> comments = [];
        try {
          final commentData = await ApiService.getCommentData(
            where: [
              {'field': 'board_id', 'operator': '=', 'value': board['board_id']},
              {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
            ],
            orderBy: [
              {'field': 'created_at', 'direction': 'ASC'}
            ],
          );

          for (var comment in commentData) {
            // 작성자 이름 (manager_name 또는 pro_name 사용)
            String commentStaffName = comment['manager_name'] ?? comment['pro_name'] ?? '관리자';

            comments.add({
              ...comment,
              'staff_name': commentStaffName,
            });
          }
        } catch (e) {
          print('댓글 로드 오류: $e');
        }

        memos.add(MemoPost(
          boardId: board['board_id'],
          title: board['title'] ?? '',
          content: board['content'] ?? '',
          boardType: board['board_type'] ?? '일반',
          staffName: staffName,
          memberName: memberName,
          memberPhone: memberPhone,
          formattedDate: _formatDate(board['created_at']),
          isNew: _isNewPost(board['created_at']),
          comments: comments,
        ));
      }

      _memos = memos;
      print('메모 처리 완료: ${_memos.length}건');
      _isLoading = false;
      _errorMessage = null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      print('메모 로드 오류: $e');
    }

    notifyListeners();
  }

  // 새로고침
  Future<void> refresh() async {
    await loadMemos();
  }

  // 메모 작성
  Future<bool> createMemo({
    required String title,
    required String content,
    required String boardType,
  }) async {
    try {
      // 로그인한 직원 정보 가져오기
      final currentUser = ApiService.getCurrentUser();
      final managerId = currentUser?['manager_contract_id'] ?? currentUser?['pro_contract_id'];
      final managerName = currentUser?['manager_name'] ?? currentUser?['pro_name'] ?? '관리자';

      final data = {
        'title': title,
        'content': content,
        'board_type': boardType,
        'manager_id': managerId,
        'manager_name': managerName,
        'member_id': _memberId,
        'branch_id': ApiService.getCurrentBranchId(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ApiService.addBoardData(data);
      await refresh(); // 목록 새로고침
      return true;
    } catch (e) {
      print('메모 작성 오류: $e');
      return false;
    }
  }

  // 메모 수정
  Future<bool> updateMemo({
    required int boardId,
    required String title,
    required String content,
    required String boardType,
  }) async {
    try {
      final data = {
        'title': title,
        'content': content,
        'board_type': boardType,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ApiService.updateBoardData(
        data,
        [
          {'field': 'board_id', 'operator': '=', 'value': boardId},
          {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
        ],
      );
      
      await refresh(); // 목록 새로고침
      return true;
    } catch (e) {
      print('메모 수정 오류: $e');
      return false;
    }
  }

  // 메모 삭제
  Future<bool> deleteMemo(int boardId) async {
    try {
      // 먼저 관련 댓글들 삭제
      await ApiService.deleteCommentData([
        {'field': 'board_id', 'operator': '=', 'value': boardId},
        {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
      ]);

      // 메모 삭제
      await ApiService.deleteBoardData([
        {'field': 'board_id', 'operator': '=', 'value': boardId},
        {'field': 'branch_id', 'operator': '=', 'value': ApiService.getCurrentBranchId()}
      ]);
      
      await refresh(); // 목록 새로고침
      return true;
    } catch (e) {
      print('메모 삭제 오류: $e');
      return false;
    }
  }

  // 댓글 업데이트
  void updateMemoComments(int boardId, List<Map<String, dynamic>> comments) {
    final memoIndex = _memos.indexWhere((memo) => memo.boardId == boardId);
    if (memoIndex != -1) {
      _memos[memoIndex] = MemoPost(
        boardId: _memos[memoIndex].boardId,
        title: _memos[memoIndex].title,
        content: _memos[memoIndex].content,
        boardType: _memos[memoIndex].boardType,
        staffName: _memos[memoIndex].staffName,
        memberName: _memos[memoIndex].memberName,
        memberPhone: _memos[memoIndex].memberPhone,
        formattedDate: _memos[memoIndex].formattedDate,
        isNew: _memos[memoIndex].isNew,
        comments: comments,
      );
      notifyListeners();
    }
  }

  // 날짜 포맷팅
  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // 새 게시글 판단 (24시간 이내)
  bool _isNewPost(String? dateString) {
    if (dateString == null) return false;
    
    try {
      DateTime postDate = DateTime.parse(dateString);
      DateTime now = DateTime.now();
      Duration difference = now.difference(postDate);
      return difference.inHours < 24;
    } catch (e) {
      return false;
    }
  }
} 