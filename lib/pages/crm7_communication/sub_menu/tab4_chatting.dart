import 'dart:async';
import 'package:flutter/material.dart';
import '../../../constants/font_sizes.dart';
import '../../../services/api_service.dart';
import '../../../services/chat_service_supabase.dart';
import '../../../services/chat_notification_service.dart';
import '../../../models/chat_models.dart';
import '../../crm2_member/tab1_membership/member_page/member_main.dart';

class Member {
  final int memberId;
  final String memberName;
  final String memberPhone;
  final String memberType;
  final String memberNickname;
  final String memberGender;
  final String chatBookmark;

  Member({
    required this.memberId,
    required this.memberName,
    required this.memberPhone,
    required this.memberType,
    this.memberNickname = '',
    this.memberGender = '',
    this.chatBookmark = '',
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      memberId: int.tryParse(map['member_id'].toString()) ?? 0,
      memberName: map['member_name']?.toString() ?? '',
      memberPhone: map['member_phone']?.toString() ?? '',
      memberType: map['member_type']?.toString() ?? '',
      memberNickname: map['member_nickname']?.toString() ?? '',
      memberGender: map['member_gender']?.toString() ?? '',
      chatBookmark: map['chat_bookmark']?.toString() ?? '',
    );
  }
  
  bool get isFavorite => chatBookmark == 'marked';
}

class Tab4ChattingWidget extends StatefulWidget {
  @override
  _Tab4ChattingWidgetState createState() => _Tab4ChattingWidgetState();
}

class _Tab4ChattingWidgetState extends State<Tab4ChattingWidget> {
  bool isLoading = false;
  List<Member> allMembers = [];
  List<Member> filteredMembers = [];
  List<Member> openChatTabs = [];
  int currentChatIndex = 0;

  // 채팅 관련 상태
  Map<String, List<ChatMessage>> chatMessages = {};
  Map<String, TextEditingController> messageControllers = {};
  Map<String, ChatRoom?> chatRooms = {};
  Map<String, int> unreadCounts = {};
  Map<String, StreamSubscription> messageSubscriptions = {};
  bool _showEmojiPicker = false;

  // 탭 관련 상태
  int selectedMemberTab = 0; // 0: 응답대상, 1: 즐겨찾기, 2: 전체회원
  List<Member> pendingResponseMembers = [];

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
    searchController.addListener(_filterMembers);
    _subscribeToUnreadCounts();
  }

  StreamSubscription? _unreadCountSubscription;
  Map<String, int> _previousUnreadCounts = {};

  void _subscribeToUnreadCounts() {
    _unreadCountSubscription = ChatServiceSupabase.getUnreadMessageCountsMapStream().listen((counts) {
      if (!mounted) return;

      // 값이 실제로 변경되었는지 확인
      bool hasChanged = false;
      if (counts.length != _previousUnreadCounts.length) {
        hasChanged = true;
      } else {
        for (var key in counts.keys) {
          if (_previousUnreadCounts[key] != counts[key]) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged) {
        _previousUnreadCounts = Map.from(counts);
        setState(() {
          unreadCounts = counts;
          _updatePendingResponseMembers();
        });
      }
    });
  }

  void _updatePendingResponseMembers() {
    // 응답대상 회원 업데이트 (읽지 않은 메시지가 있는 회원들 추가만, 제거는 탭 변경 시에만)
    for (var member in allMembers) {
      final memberId = member.memberId.toString();
      final hasUnread = unreadCounts[memberId] != null && unreadCounts[memberId]! > 0;

      if (hasUnread && !pendingResponseMembers.any((m) => m.memberId == member.memberId)) {
        pendingResponseMembers.add(member);
      }
    }
  }

  void _refreshPendingResponseMembers() {
    // 탭 변경 시 응답대상 회원 목록 재구성
    pendingResponseMembers = allMembers.where((member) {
      final memberId = member.memberId.toString();
      return unreadCounts[memberId] != null && unreadCounts[memberId]! > 0;
    }).toList();
  }

  @override
  void dispose() {
    // 모든 스트림 구독 취소
    _unreadCountSubscription?.cancel();
    for (var subscription in messageSubscriptions.values) {
      subscription.cancel();
    }
    messageSubscriptions.clear();

    searchController.dispose();
    for (var controller in messageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('🔍 [DEBUG] 현재 브랜치 ID: ${ApiService.getCurrentBranchId()}');
      final memberData = await ApiService.getMembers();
      print('📊 [DEBUG] 로드된 회원 수: ${memberData.length}');
      print('⭐ [DEBUG] 첫 번째 회원 데이터: ${memberData.isNotEmpty ? memberData.first : 'empty'}');
      setState(() {
        allMembers = memberData.map((data) => Member.fromMap(data)).toList();
        _refreshPendingResponseMembers();
        _filterMembers();
      });
    } catch (e) {
      print('회원 목록 로드 실패: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterMembers() {
    if (!mounted) return;

    String query = searchController.text.toLowerCase();
    List<Member> sourceMembers;

    switch (selectedMemberTab) {
      case 0: // 응답대상
        sourceMembers = pendingResponseMembers;
        break;
      case 1: // 즐겨찾기
        sourceMembers = allMembers.where((member) => member.isFavorite).toList();
        break;
      case 2: // 전체회원
      default:
        sourceMembers = allMembers;
        break;
    }

    List<Member> newFilteredMembers;
    if (selectedMemberTab == 2 && query.isNotEmpty) {
      // 전체회원 탭에서만 검색 적용
      newFilteredMembers = sourceMembers.where((member) {
        return member.memberName.toLowerCase().contains(query) ||
               member.memberPhone.contains(query) ||
               member.memberNickname.toLowerCase().contains(query);
      }).toList();
    } else {
      newFilteredMembers = List.from(sourceMembers);
    }

    // 즐겨찾기 회원을 상단으로 정렬
    newFilteredMembers.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.memberName.compareTo(b.memberName);
    });

    // 실제로 변경되었을 때만 setState 호출
    if (_membersListChanged(filteredMembers, newFilteredMembers)) {
      setState(() {
        filteredMembers = newFilteredMembers;
      });
    }
  }

  // 회원 목록이 실제로 변경되었는지 확인
  bool _membersListChanged(List<Member> oldList, List<Member> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].memberId != newList[i].memberId) return true;
    }
    return false;
  }

  Future<void> _toggleFavorite(Member member) async {
    try {
      // API 호출하여 DB 업데이트
      final newBookmarkStatus = member.isFavorite ? '' : 'marked';
      await ApiService.updateMemberBookmark(member.memberId, newBookmarkStatus);
      
      // 로컬 상태 업데이트
      setState(() {
        final index = allMembers.indexWhere((m) => m.memberId == member.memberId);
        if (index != -1) {
          allMembers[index] = Member(
            memberId: member.memberId,
            memberName: member.memberName,
            memberPhone: member.memberPhone,
            memberType: member.memberType,
            memberNickname: member.memberNickname,
            memberGender: member.memberGender,
            chatBookmark: newBookmarkStatus,
          );
        }
        _filterMembers();
      });
    } catch (e) {
      print('즐겨찾기 업데이트 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기 업데이트에 실패했습니다.')),
      );
    }
  }

  // 채팅방 열기
  Future<void> _openChatRoom(Member member) async {
    print('🚀 채팅방 열기 시도: ${member.memberName} (ID: ${member.memberId})');

    try {
      // 현재 브랜치 ID 확인
      final branchId = ApiService.getCurrentBranchId();
      print('📍 현재 브랜치 ID: $branchId');

      if (branchId == null) {
        throw Exception('브랜치 ID가 없습니다. 로그인 상태를 확인해주세요.');
      }

      // 관리자 정보 확인
      final admin = ApiService.getCurrentUser();
      print('👤 현재 관리자 정보: $admin');
      print('👤 관리자 staff_id: ${admin?['staff_id']}');
      print('👤 관리자 staff_access_id: ${admin?['staff_access_id']}');
      print('👤 관리자 role: ${admin?['role']}');

      print('💬 ChatService.getOrCreateChatRoom 호출 중...');
      
      // 채팅방 생성 또는 가져오기
      final chatRoom = await ChatServiceSupabase.getOrCreateChatRoom(
        member.memberId.toString(),
        member.memberName,
        member.memberPhone,
        member.memberType,
      );

      print('✅ 채팅방 생성/조회 성공: ${chatRoom.id}');
      final chatRoomId = chatRoom.id;
      
      setState(() {
        if (!openChatTabs.any((m) => m.memberId == member.memberId)) {
          openChatTabs.add(member);
          currentChatIndex = openChatTabs.length - 1;
          
          // 메시지 컨트롤러 생성
          messageControllers[chatRoomId] = TextEditingController();
          chatRooms[chatRoomId] = chatRoom;
          chatMessages[chatRoomId] = [];
          print('📝 새 채팅 탭 생성: $chatRoomId');
        } else {
          currentChatIndex = openChatTabs.indexWhere((m) => m.memberId == member.memberId);
          print('🔄 기존 채팅 탭으로 이동: $chatRoomId');
        }
      });

      // 메시지 스트림 구독
      print('📡 메시지 스트림 구독 시작...');
      _subscribeToMessages(chatRoomId);
      
      // 메시지를 읽음 처리
      print('👁️ 메시지 읽음 처리 중...');
      await ChatServiceSupabase.markMessagesAsRead(chatRoomId, member.memberId.toString());
      
      print('🎉 채팅방 열기 완료!');
      
    } catch (e, stackTrace) {
      print('❌ 채팅방 열기 실패!');
      print('에러: $e');
      print('타입: ${e.runtimeType}');
      print('스택 트레이스: $stackTrace');
      
      String errorMessage = '채팅방 열기 실패';
      if (e.toString().contains('permission')) {
        errorMessage = '권한이 없습니다. Firestore 규칙을 확인해주세요.';
      } else if (e.toString().contains('network')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else {
        errorMessage = '채팅방 열기 실패: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // 메시지 스트림 구독
  void _subscribeToMessages(String chatRoomId) {
    // 기존 구독이 있다면 취소
    messageSubscriptions[chatRoomId]?.cancel();
    
    messageSubscriptions[chatRoomId] = ChatServiceSupabase.getMessagesStream(chatRoomId).listen((messages) {
      if (mounted) {
        setState(() {
          chatMessages[chatRoomId] = messages;
        });
      }
    });
  }

  // 메시지 전송
  Future<void> _sendMessage(String chatRoomId, String memberId) async {
    final controller = messageControllers[chatRoomId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final message = controller.text.trim();
    controller.clear();
    
    // 메시지 전송 후 이모티콘 창 닫기
    if (_showEmojiPicker ?? false) {
      setState(() {
        _showEmojiPicker = false;
      });
    }

    try {
      await ChatServiceSupabase.sendMessage(chatRoomId, memberId, message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  // 채팅 탭 닫기
  void _closeChatTab(int index) {
    final member = openChatTabs[index];
    final chatRoomId = ChatRoom.generateChatRoomId(
      ApiService.getCurrentBranchId() ?? '',
      member.memberId.toString()
    );

    setState(() {
      openChatTabs.removeAt(index);
      messageControllers[chatRoomId]?.dispose();
      messageControllers.remove(chatRoomId);
      chatMessages.remove(chatRoomId);
      chatRooms.remove(chatRoomId);

      if (currentChatIndex >= openChatTabs.length && openChatTabs.isNotEmpty) {
        currentChatIndex = openChatTabs.length - 1;
      }
    });
  }

  // 회원 목록 탭 빌더
  Widget _buildMemberTab(int index, IconData icon, String label) {
    final isSelected = selectedMemberTab == index;
    final activeColor = Color(0xFF06B6D4); // Cyan
    final inactiveColor = Color(0xFF64748B); // Gray

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedMemberTab = index;
            _refreshPendingResponseMembers();
            _filterMembers();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16.0,
                color: isSelected ? activeColor : inactiveColor,
              ),
              SizedBox(width: 6.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFFFCD00),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFFCD00).withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
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
                  Icons.chat,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1:1 채팅',
                    style: TextStyle(
                      color: Color(0xFF3C1E1E),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '회원과의 개별 채팅을 통해 소통하세요',
                    style: TextStyle(
                      color: Color(0xFF3C1E1E).withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Spacer(),
              // 알림 테스트 버튼
              GestureDetector(
                onTap: () {
                  ChatNotificationService().simulateNewMessage();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔔 알림음 테스트 실행!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '테스트',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                '총 ${filteredMembers.length}명',
                style: TextStyle(
                  color: Color(0xFF3C1E1E),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 메인 컨텐츠
        Expanded(
          child: Row(
            children: [
              // 왼쪽: 회원 목록
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                child: Column(
                  children: [
                    
                    // 탭 메뉴
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildMemberTab(0, Icons.pending_actions, '응답대상'),
                          _buildMemberTab(1, Icons.star, '즐겨찾기'),
                          _buildMemberTab(2, Icons.people, '전체회원'),
                        ],
                      ),
                    ),
                    
                    // 회원 목록
                    Expanded(
                      child: isLoading
                          ? Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                // 검색바 (전체회원 탭에서만 표시)
                                if (selectedMemberTab == 2) 
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.search, color: Colors.grey.shade600),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: searchController,
                                            style: TextStyle(color: Colors.black87),
                                            decoration: InputDecoration(
                                              hintText: '회원명, 전화번호, 닉네임 검색...',
                                              border: InputBorder.none,
                                              hintStyle: TextStyle(color: Colors.grey.shade500),
                                            ),
                                          ),
                                        ),
                                        if (searchController.text.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              searchController.clear();
                                            },
                                            child: Icon(Icons.clear, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filteredMembers.length,
                                    itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                final isFavorite = member.isFavorite;
                                final isSelected = openChatTabs.isNotEmpty && 
                                    currentChatIndex < openChatTabs.length && 
                                    openChatTabs[currentChatIndex].memberId == member.memberId;
                                
                                return Container(
                                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFFFFCD00).withOpacity(0.2) : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: Color(0xFF3C1E1E), width: 2) : null,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.grey.shade200,
                                      child: Text(
                                        '${member.memberId}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        if (isFavorite)
                                          Icon(Icons.star, color: Colors.amber, size: 16),
                                        SizedBox(width: isFavorite ? 4 : 0),
                                        Text(
                                          member.memberName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          member.memberPhone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: member.memberNickname.isNotEmpty
                                      ? Text(
                                          member.memberNickname,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                          ),
                                        )
                                      : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 읽지 않은 메시지 뱃지
                                        if (unreadCounts[member.memberId.toString()] != null && unreadCounts[member.memberId.toString()]! > 0) ...[
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${unreadCounts[member.memberId.toString()]! > 99 ? '99+' : unreadCounts[member.memberId.toString()]}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                        ],
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFFFCD00).withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            member.memberType,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF3C1E1E),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => _toggleFavorite(member),
                                          child: Icon(
                                            isFavorite ? Icons.star : Icons.star_border,
                                            color: isFavorite ? Colors.amber : Colors.grey.shade400,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _openChatRoom(member),
                                  ),
                                );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                ),
              ),
              
              SizedBox(width: 16),
              
              // 오른쪽: 채팅창
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: openChatTabs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFCD00).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Color(0xFF3C1E1E),
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                '회원을 선택해주세요',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '왼쪽 목록에서 채팅하고 싶은 회원을 선택하세요',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildChatArea(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatArea() {
    if (currentChatIndex >= openChatTabs.length) return Container();
    
    final member = openChatTabs[currentChatIndex];
    
    return Column(
      children: [
        // 채팅 탭 헤더
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              // 왼쪽 화살표
              if (openChatTabs.length > 1)
                IconButton(
                  onPressed: currentChatIndex > 0 ? () {
                    setState(() {
                      currentChatIndex--;
                    });
                  } : null,
                  icon: Icon(Icons.chevron_left, color: currentChatIndex > 0 ? Colors.black87 : Colors.grey.shade400),
                ),
              
              // 채팅 탭들
              Expanded(
                child: Container(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: openChatTabs.length,
                    itemBuilder: (context, index) {
                      final tabMember = openChatTabs[index];
                      final isActive = index == currentChatIndex;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            currentChatIndex = index;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? Color(0xFFFFCD00) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? Color(0xFF3C1E1E) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey.shade200,
                                child: Text(
                                  '${tabMember.memberId}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                tabMember.memberName,
                                style: TextStyle(
                                  color: isActive ? Color(0xFF3C1E1E) : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _closeChatTab(index),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isActive ? Color(0xFF3C1E1E) : Colors.grey.shade600,
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
              
              // 오른쪽 화살표
              if (openChatTabs.length > 1)
                IconButton(
                  onPressed: currentChatIndex < openChatTabs.length - 1 ? () {
                    setState(() {
                      currentChatIndex++;
                    });
                  } : null,
                  icon: Icon(Icons.chevron_right, color: currentChatIndex < openChatTabs.length - 1 ? Colors.black87 : Colors.grey.shade400),
                ),
            ],
          ),
        ),
        
        // 채팅 헤더 (현재 선택된 회원 정보)
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  '${member.memberId}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${member.memberPhone} • ${member.memberType}',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // 회원 상세조회 버튼
              ElevatedButton.icon(
                onPressed: () => _showMemberDetailDialog(context, member),
                icon: Icon(
                  Icons.visibility_rounded,
                  size: 16,
                  color: Colors.black87,
                ),
                label: Text(
                  '상세조회',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        
        // 채팅 메시지 영역
        Expanded(
          child: Container(
            color: Color(0xFFB8C5D6), // MyXPlanner 스타일 통일
            child: _buildMessageList(member),
          ),
        ),
        
        // 메시지 입력 영역
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFB8C5D6), // MyXPlanner 스타일 통일
          ),
          child: SafeArea(
            top: false,
            child: _buildMessageInput(member),
          ),
        ),
      ],
    );
  }

  // 메시지 목록 위젯
  Widget _buildMessageList(Member member) {
    final chatRoomId = ChatRoom.generateChatRoomId(
      ApiService.getCurrentBranchId() ?? '', 
      member.memberId.toString()
    );
    
    final messages = chatMessages[chatRoomId] ?? [];
    
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              '${member.memberName}님과의 채팅',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '아직 메시지가 없습니다.\n아래에서 첫 메시지를 보내보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        
        // 현재 로그인한 사용자의 sender_type 가져오기
        final currentUserRole = ApiService.getCurrentStaffRole() ?? 'admin';
        
        // 본인 메시지 판단: 현재 로그인한 사용자의 sender_type과 일치하는 메시지만 본인 메시지
        final isMyMessage = message.senderType == currentUserRole;
        
        // 상대방 메시지일 때 발신자 라벨 생성
        String? senderLabel;
        if (!isMyMessage) {
          // 상대방 메시지일 때만 라벨 표시
          switch (message.senderType) {
            case 'admin':
              senderLabel = '관리자';
              break;
            case 'manager':
              senderLabel = '매니저';
              break;
            case 'pro':
              // 프로는 이름 + " 프로" 형식
              final proName = message.senderName.isNotEmpty 
                  ? message.senderName 
                  : '프로';
              senderLabel = '$proName 프로';
              break;
            case 'member':
              // 회원 메시지일 때
              senderLabel = message.senderName.isNotEmpty ? message.senderName : null;
              break;
          }
        }
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMyMessage) ...[
                // sender_type별 아이콘 및 색상
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getAvatarColor(message.senderType),
                  child: Icon(
                    _getAvatarIcon(message.senderType),
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 상대방 메시지일 때 발신자 라벨 표시
                    if (!isMyMessage && senderLabel != null) ...[
                      Padding(
                        padding: EdgeInsets.only(
                          left: 0,
                          right: 0,
                          bottom: 2,
                        ),
                        child: Text(
                          senderLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMyMessage ? Color(0xFFFFCD00) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isMyMessage ? null : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        message.message,
                        style: TextStyle(
                          color: isMyMessage ? Color(0xFF000000) : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                        if (isMyMessage) ...[
                          SizedBox(width: 4),
                          // 각 sender_type별 읽음 상태 표시
                          _buildReadStatusIcons(message),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isMyMessage) ...[
                SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFFFCD00).withOpacity(0.3),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: Color(0xFF3C1E1E),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // 메시지 입력 위젯
  Widget _buildMessageInput(Member member) {
    final chatRoomId = ChatRoom.generateChatRoomId(
      ApiService.getCurrentBranchId() ?? '', 
      member.memberId.toString()
    );
    
    final controller = messageControllers[chatRoomId];
    if (controller == null) return Container();

    return Column(
      children: [
        if (_showEmojiPicker ?? false)
          Container(
            height: 180,
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: GridView.builder(
              padding: EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _commonEmojis.length,
              itemBuilder: (context, index) {
                if (index >= _commonEmojis.length) {
                  return SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: () {
                    if (controller != null) {
                      _insertEmoji(controller, _commonEmojis[index]);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _commonEmojis[index],
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: 48,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      isDense: true,
                    ),
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _sendMessage(chatRoomId, member.memberId.toString());
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _showEmojiPicker = !(_showEmojiPicker ?? false);
                  });
                },
                icon: Icon(
                  (_showEmojiPicker ?? false) ? Icons.keyboard : Icons.sentiment_satisfied,
                  color: Colors.black54,
                  size: 22,
                ),
                padding: EdgeInsets.all(10),
                constraints: BoxConstraints(),
              ),
            ),
            SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _sendMessage(chatRoomId, member.memberId.toString()),
                icon: Icon(Icons.send, color: Colors.black54, size: 22),
                padding: EdgeInsets.all(10),
                constraints: BoxConstraints(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // sender_type별 아바타 아이콘 가져오기
  IconData _getAvatarIcon(String senderType) {
    switch (senderType) {
      case 'admin':
        return Icons.golf_course; // 골프 홀 아이콘
      case 'manager':
        return Icons.supervisor_account;
      case 'pro':
        return Icons.school; // 레슨 아이콘
      case 'member':
      default:
        return Icons.account_circle;
    }
  }

  // sender_type별 아바타 배경색 가져오기
  Color _getAvatarColor(String senderType) {
    switch (senderType) {
      case 'admin':
        return Color(0xFF3B82F6); // 파란색
      case 'manager':
        return Color(0xFF8B5CF6); // 보라색
      case 'pro':
        return Color(0xFF10B981); // 초록색
      case 'member':
      default:
        return Colors.grey.shade600; // 회색
    }
  }

  // 각 sender_type별 읽음 상태 아이콘 표시
  Widget _buildReadStatusIcons(ChatMessage message) {
    final currentUserRole = ApiService.getCurrentStaffRole() ?? 'admin';
    
    // 현재 사용자가 보낸 메시지가 아니면 표시하지 않음
    if (message.senderType != currentUserRole) {
      return SizedBox.shrink();
    }

    // 읽음 상태 리스트 생성
    final readStatuses = <Map<String, dynamic>>[];
    
    // 회원이 읽었는지 확인
    if (message.readBy['member'] == true) {
      readStatuses.add({'type': 'member', 'label': '회원'});
    }
    
    // 프로가 읽었는지 확인
    if (message.readBy['pro'] == true) {
      readStatuses.add({'type': 'pro', 'label': '프로'});
    }
    
    // 매니저가 읽었는지 확인
    if (message.readBy['manager'] == true) {
      readStatuses.add({'type': 'manager', 'label': '매니저'});
    }
    
    // 관리자가 읽었는지 확인
    if (message.readBy['admin'] == true) {
      readStatuses.add({'type': 'admin', 'label': '관리자'});
    }

    if (readStatuses.isEmpty) {
      // 아무도 읽지 않음
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done,
            size: 12,
            color: Colors.grey.shade400,
          ),
        ],
      );
    }

    // 일부 또는 모두 읽음
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.done_all,
          size: 12,
          color: Colors.blue,
        ),
        SizedBox(width: 2),
        Text(
          readStatuses.map((s) => s['label']).join(', ') + ' 읽음',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 자주 사용하는 이모티콘 목록
  static const List<String> _commonEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
    '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
    '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩', '🥳',
    '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
    '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤',
    '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱',
    '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫',
    '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦',
    '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵',
    '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕',
    '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩',
    '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺',
    '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
    '👈', '👉', '👆', '🖕', '👇', '☝️', '👋', '🤚',
    '🖐️', '✋', '🖖', '👏', '🙌', '🤲', '🤝', '🙏',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
    '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️',
  ];

  void _insertEmoji(TextEditingController controller, String emoji) {
    final text = controller.text;
    final selection = controller.selection;
    
    // selection 범위 검증
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    
    final newText = text.replaceRange(start, end, emoji);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (start + emoji.length).clamp(0, newText.length),
      ),
    );
  }

  // 시간 포맷팅
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }


  // 회원 상세조회 다이얼로그 표시
  void _showMemberDetailDialog(BuildContext context, Member member) {
    // 회원 정보로 memberData 구성
    final memberData = {
      'member_id': member.memberId,
      'member_name': member.memberName,
      'member_type': member.memberType,
      'member_phone': member.memberPhone,
      'member_nickname': member.memberNickname,
      'member_gender': member.memberGender,
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
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: MemberMainWidget(
                memberId: member.memberId,
                memberData: memberData,
              ),
            ),
          ),
        );
      },
    );
  }
}