# 메시지 '읽음' 표시 기능 구현 가이드

## 📋 개요
채팅에서 상대방이 내 메시지를 읽었는지 확인할 수 있는 '읽음' 표시 기능 구현 가이드입니다.

## 🏗️ 관리자 앱 구현 완료사항

### ✅ 이미 구현된 기능
1. **읽음 표시 UI** - 관리자가 보낸 메시지에 읽음/안읽음 아이콘 표시
2. **읽음 처리 서비스** - 회원이 메시지를 읽었을 때 실시간 반영
3. **실시간 동기화** - Stream을 통한 읽음 상태 업데이트

### 📱 관리자 앱 UI
```dart
// 관리자 메시지에만 읽음 표시
if (isAdmin) ...[
  SizedBox(width: 4),
  Icon(
    message.isRead ? Icons.done_all : Icons.done,  // 읽음: ✓✓, 안읽음: ✓
    size: 12,
    color: message.isRead ? Colors.blue : Colors.grey.shade400,
  ),
  if (message.isRead)
    Text(' 읽음', style: TextStyle(color: Colors.blue, fontSize: 9)),
],
```

## 🔧 회원 앱 구현 가이드

### 1. MemberChatService 수정

#### 1.1 읽음 처리 메서드 추가
```dart
// member_chat_service.dart에 추가

// 관리자 메시지를 읽었을 때 호출
static Future<void> markAdminMessagesAsRead() async {
  final branchId = _getCurrentBranchId();
  final memberId = _getCurrentMemberId();
  
  if (branchId == null || memberId == null) return;

  final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);

  // 해당 채팅방의 읽지 않은 관리자 메시지들을 모두 읽음 처리
  final unreadMessages = await _firestore
      .collection('messages')
      .where('chatRoomId', isEqualTo: chatRoomId)
      .where('senderType', isEqualTo: 'admin')
      .where('isRead', isEqualTo: false)
      .get();

  final batch = _firestore.batch();

  // 메시지들을 읽음 처리
  for (final doc in unreadMessages.docs) {
    batch.update(doc.reference, {'isRead': true});
  }

  // 채팅방의 회원 읽지 않은 메시지 수 초기화
  final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
  batch.update(chatRoomRef, {'memberUnreadCount': 0});

  await batch.commit();
  print('✅ 관리자 메시지 읽음 처리 완료');
}
```

#### 1.2 기존 markMessagesAsRead 메서드 수정
```dart
// 기존 메서드를 markAdminMessagesAsRead로 교체
static Future<void> markMessagesAsRead() async {
  await markAdminMessagesAsRead();
}
```

### 2. 채팅 화면 수정

#### 2.1 채팅방 진입 시 읽음 처리
```dart
// member_chat_page.dart의 _initializeChat 메서드 수정

Future<void> _initializeChat() async {
  try {
    // 채팅방 생성/가져오기
    final chatRoom = await MemberChatService.getOrCreateChatRoom();
    setState(() {
      _chatRoom = chatRoom;
    });

    // 메시지 스트림 구독
    MemberChatService.getMessagesStream().listen((messages) {
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    });

    // ✨ 관리자 메시지 읽음 처리 (회원이 채팅방에 들어왔을 때)
    await MemberChatService.markAdminMessagesAsRead();
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('채팅 초기화 실패: $e')),
    );
  }
}
```

#### 2.2 앱이 포그라운드로 돌아올 때 읽음 처리
```dart
// member_chat_page.dart에 AppLifecycleListener 추가

class _MemberChatPageState extends State<MemberChatPage> 
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때 읽음 처리
      MemberChatService.markAdminMessagesAsRead();
    }
  }
}
```

### 3. 메시지 UI에 읽음 표시 추가

#### 3.1 회원이 보낸 메시지에 읽음 표시
```dart
// _buildMessageList 메서드의 메시지 아이템 수정

Widget _buildMessageItem(ChatMessage message) {
  final isMyMessage = message.senderType == 'member';
  
  return Container(
    margin: EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: isMyMessage 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
      children: [
        if (!isMyMessage) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.support_agent, size: 16, color: Colors.blue),
          ),
          SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isMyMessage 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMyMessage ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.message,
                  style: TextStyle(
                    color: isMyMessage ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(height: 4),
              // ✨ 시간과 읽음 표시
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                  // 내가 보낸 메시지에만 읽음 표시
                  if (isMyMessage) ...[
                    SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 12,
                      color: message.isRead ? Colors.blue : Colors.grey[400],
                    ),
                    if (message.isRead)
                      Text(
                        ' 읽음',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
            backgroundColor: Colors.green[100],
            child: Icon(Icons.person, size: 16, color: Colors.green),
          ),
        ],
      ],
    ),
  );
}
```

### 4. 실시간 읽음 상태 업데이트

#### 4.1 메시지 스트림 리스너 개선
```dart
// _initializeChat 메서드에서 스트림 구독 개선

// 메시지 스트림 구독
MemberChatService.getMessagesStream().listen((messages) {
  setState(() {
    _messages = messages;
  });
  
  // 새로운 관리자 메시지가 있으면 자동으로 읽음 처리
  final unreadAdminMessages = messages.where((msg) => 
    msg.senderType == 'admin' && !msg.isRead
  ).toList();
  
  if (unreadAdminMessages.isNotEmpty) {
    // 잠시 후 읽음 처리 (사용자가 메시지를 볼 시간을 줌)
    Future.delayed(Duration(milliseconds: 500), () {
      MemberChatService.markAdminMessagesAsRead();
    });
  }
  
  _scrollToBottom();
});
```

## 🔄 데이터 흐름

### 읽음 처리 프로세스
```
1. 관리자가 메시지 전송
   ↓
2. 회원 앱에서 메시지 수신 (isRead: false)
   ↓
3. 회원이 채팅방 열거나 메시지 확인
   ↓
4. markAdminMessagesAsRead() 호출
   ↓
5. Firestore에서 해당 메시지의 isRead: true로 변경
   ↓
6. 관리자 앱에서 실시간으로 "읽음" 표시 업데이트
```

### 반대 방향 (회원 → 관리자)
```
1. 회원이 메시지 전송
   ↓
2. 관리자 앱에서 메시지 수신 (isRead: false)
   ↓
3. 관리자가 채팅방 열거나 메시지 확인
   ↓
4. markMessagesAsRead() 호출 (이미 구현됨)
   ↓
5. Firestore에서 해당 메시지의 isRead: true로 변경
   ↓
6. 회원 앱에서 실시간으로 "읽음" 표시 업데이트
```

## 🎯 테스트 체크리스트

### 회원 앱에서 확인할 사항
- [ ] 채팅방 진입 시 관리자 메시지 자동 읽음 처리
- [ ] 회원이 보낸 메시지에 읽음/안읽음 표시
- [ ] 관리자가 메시지를 읽으면 실시간으로 "읽음" 표시
- [ ] 앱 백그라운드 → 포그라운드 시 읽음 처리
- [ ] 새로운 관리자 메시지 수신 시 자동 읽음 처리

### 관리자 앱에서 확인할 사항
- [ ] 관리자가 보낸 메시지에 읽음/안읽음 표시
- [ ] 회원이 메시지를 읽으면 실시간으로 "읽음" 표시

## 🚨 주의사항

1. **동일한 Firebase 프로젝트 사용**: 관리자 앱과 회원 앱이 같은 Firestore 데이터베이스 사용
2. **브랜치 ID 일치**: 회원의 소속 지점 정보가 정확해야 함
3. **실시간 동기화**: Stream 리스너가 제대로 작동하는지 확인
4. **메모리 관리**: 앱 종료 시 리스너 해제 필수
5. **에러 처리**: 네트워크 오류 시 적절한 예외 처리

## 💡 추가 개선사항

### 1. 타이핑 표시기
```dart
// 상대방이 타이핑 중일 때 표시
static Future<void> setTypingStatus(bool isTyping) async {
  // Firestore에 타이핑 상태 저장
}
```

### 2. 온라인 상태 표시
```dart
// 상대방이 온라인인지 표시
static Future<void> updateOnlineStatus(bool isOnline) async {
  // Firestore에 온라인 상태 저장
}
```

### 3. 메시지 전송 시간 표시 개선
```dart
// 더 정확한 시간 표시 (몇 초 전, 몇 분 전 등)
String _formatDetailedTime(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  
  if (difference.inSeconds < 30) return '방금 전';
  if (difference.inMinutes < 1) return '${difference.inSeconds}초 전';
  if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
  if (difference.inHours < 24) return '${difference.inHours}시간 전';
  return DateFormat('MM/dd HH:mm').format(timestamp);
}
```

---
*이 가이드를 따라 구현하면 완전한 읽음 표시 기능이 완성됩니다.*