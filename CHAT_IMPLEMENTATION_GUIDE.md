# Firebase 기반 1:1 채팅 시스템 구현 가이드

## 📋 개요
이 가이드는 관리자 앱에서 구현된 Firebase 기반 1:1 채팅 시스템을 회원 앱에도 동일하게 구현하기 위한 상세 지침서입니다.

## 🏗️ 시스템 구조

### Firestore 데이터베이스 구조
```
chatRooms/
├── {branchId}_{memberId}/     // 예: "test_901"
│   ├── branchId: "test"
│   ├── memberId: "901"
│   ├── memberName: "서종익"
│   ├── memberPhone: "010-6250-7373"
│   ├── memberType: "웰빙클럽"
│   ├── createdAt: timestamp
│   ├── lastMessage: "안녕하세요"
│   ├── lastMessageTime: timestamp
│   ├── adminUnreadCount: 0    // 관리자 읽지 않은 메시지 수
│   └── memberUnreadCount: 1   // 회원 읽지 않은 메시지 수

messages/
├── {branchId}_{memberId}_{timestamp}/
│   ├── chatRoomId: "test_901"
│   ├── branchId: "test"
│   ├── senderId: "901" 또는 "admin_id"
│   ├── senderType: "member" 또는 "admin"
│   ├── senderName: "서종익" 또는 "관리자명"
│   ├── message: "메시지 내용"
│   ├── timestamp: timestamp
│   └── isRead: false
```

## 🚀 구현 단계

### 1단계: Firebase 설정

#### 1.1 Firebase 프로젝트 설정
```bash
# Firebase SDK 패키지 추가
flutter pub add firebase_core firebase_auth cloud_firestore
```

#### 1.2 Firebase 앱 등록
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. **mgpfunctions** 프로젝트 선택
3. 프로젝트 설정 > 일반 > "앱 추가"
4. 플랫폼 선택 (Android/iOS/Web)
5. 앱 닉네임: "MyGolfPlanner Member App"
6. 설정 파일 다운로드 및 적용

#### 1.3 main.dart에서 Firebase 초기화
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Firebase CLI로 생성된 파일

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('🔥 Firebase 초기화 완료');
  
  runApp(MyApp());
}
```

### 2단계: 데이터 모델 생성

#### 2.1 chat_models.dart 파일 생성
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String branchId;
  final String memberId;
  final String memberName;
  final String memberPhone;
  final String memberType;
  final DateTime createdAt;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int adminUnreadCount;
  final int memberUnreadCount;
  final bool isActive;

  ChatRoom({
    required this.id,
    required this.branchId,
    required this.memberId,
    required this.memberName,
    required this.memberPhone,
    required this.memberType,
    required this.createdAt,
    required this.lastMessage,
    required this.lastMessageTime,
    this.adminUnreadCount = 0,
    this.memberUnreadCount = 0,
    this.isActive = true,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      memberPhone: data['memberPhone'] ?? '',
      memberType: data['memberType'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      adminUnreadCount: data['adminUnreadCount'] ?? 0,
      memberUnreadCount: data['memberUnreadCount'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'branchId': branchId,
      'memberId': memberId,
      'memberName': memberName,
      'memberPhone': memberPhone,
      'memberType': memberType,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'adminUnreadCount': adminUnreadCount,
      'memberUnreadCount': memberUnreadCount,
      'isActive': isActive,
    };
  }

  static String generateChatRoomId(String branchId, String memberId) {
    return '${branchId}_${memberId}';
  }
}

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String branchId;
  final String senderId;
  final String senderType;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.branchId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      branchId: data['branchId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'member',
      senderName: data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatRoomId': chatRoomId,
      'branchId': branchId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  static String generateMessageId(String branchId, String memberId) {
    return '${branchId}_${memberId}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
```

### 3단계: 채팅 서비스 구현

#### 3.1 member_chat_service.dart 파일 생성
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';

class MemberChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인한 회원 정보 가져오기 (회원 앱의 구조에 맞게 수정)
  static String? _getCurrentBranchId() {
    // 회원 앱의 브랜치 ID 가져오는 로직 구현
    // 예: SharedPreferences, 전역 상태 등에서 가져오기
    return "test"; // 임시값
  }

  static String? _getCurrentMemberId() {
    // 회원 앱의 회원 ID 가져오는 로직 구현
    return "901"; // 임시값
  }

  static Map<String, dynamic>? _getCurrentMember() {
    // 회원 앱의 회원 정보 가져오는 로직 구현
    return {
      'member_id': '901',
      'member_name': '서종익',
      'member_phone': '010-6250-7373',
      'member_type': '웰빙클럽'
    }; // 임시값
  }

  // 채팅방 생성 또는 가져오기
  static Future<ChatRoom> getOrCreateChatRoom() async {
    final branchId = _getCurrentBranchId();
    final member = _getCurrentMember();
    
    if (branchId == null || member == null) {
      throw Exception('로그인 정보를 찾을 수 없습니다.');
    }

    final memberId = member['member_id'].toString();
    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);

    final doc = await chatRoomRef.get();
    
    if (doc.exists) {
      return ChatRoom.fromFirestore(doc);
    } else {
      // 새 채팅방 생성
      final newChatRoom = ChatRoom(
        id: chatRoomId,
        branchId: branchId,
        memberId: memberId,
        memberName: member['member_name'] ?? '',
        memberPhone: member['member_phone'] ?? '',
        memberType: member['member_type'] ?? '',
        createdAt: DateTime.now(),
        lastMessage: '',
        lastMessageTime: DateTime.now(),
      );

      await chatRoomRef.set(newChatRoom.toFirestore());
      return newChatRoom;
    }
  }

  // 메시지 목록 가져오기
  static Stream<List<ChatMessage>> getMessagesStream() {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) {
      return Stream.value([]);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    return _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
      
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // 메시지 전송 (회원이 보내는 경우)
  static Future<void> sendMessage(String message) async {
    final branchId = _getCurrentBranchId();
    final member = _getCurrentMember();
    
    if (branchId == null || member == null) {
      throw Exception('로그인 정보를 찾을 수 없습니다.');
    }

    final memberId = member['member_id'].toString();
    final memberName = member['member_name'] ?? '회원';
    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    // 메시지 ID 생성
    final messageId = ChatMessage.generateMessageId(branchId, memberId);
    
    // 메시지 생성
    final chatMessage = ChatMessage(
      id: messageId,
      chatRoomId: chatRoomId,
      branchId: branchId,
      senderId: memberId,
      senderType: 'member',
      senderName: memberName,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    );

    // Firestore에 저장
    final batch = _firestore.batch();

    // 메시지 추가
    final messageRef = _firestore.collection('messages').doc(messageId);
    batch.set(messageRef, chatMessage.toFirestore());

    // 채팅방 마지막 메시지 업데이트
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'lastMessage': message,
      'lastMessageTime': Timestamp.fromDate(DateTime.now()),
      'adminUnreadCount': FieldValue.increment(1), // 관리자 읽지 않은 메시지 증가
    });

    await batch.commit();
  }

  // 회원이 메시지를 읽었을 때
  static Future<void> markMessagesAsRead() async {
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
  }

  // 읽지 않은 메시지 수 가져오기
  static Stream<int> getUnreadMessageCountStream() {
    final branchId = _getCurrentBranchId();
    final memberId = _getCurrentMemberId();
    
    if (branchId == null || memberId == null) {
      return Stream.value(0);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);

    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data() as Map<String, dynamic>;
      return data['memberUnreadCount'] as int? ?? 0;
    });
  }
}
```

### 4단계: UI 구현

#### 4.1 채팅 화면 기본 구조
```dart
import 'package:flutter/material.dart';
import '../services/member_chat_service.dart';
import '../models/chat_models.dart';

class MemberChatPage extends StatefulWidget {
  @override
  _MemberChatPageState createState() => _MemberChatPageState();
}

class _MemberChatPageState extends State<MemberChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  ChatRoom? _chatRoom;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

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

      // 메시지 읽음 처리
      await MemberChatService.markMessagesAsRead();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅 초기화 실패: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    try {
      await MemberChatService.sendMessage(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('관리자와 채팅'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: _buildMessageList(),
          ),
          // 메시지 입력
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '관리자와의 채팅을 시작하세요',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
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
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
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
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey[100],
                filled: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (value) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
```

## 🔧 핵심 구현 포인트

### 1. 회원 앱 전용 수정사항
- `MemberChatService`에서 회원 정보 가져오는 로직 구현
- `senderType`을 'member'로 설정
- `memberUnreadCount` 대신 `adminUnreadCount` 증가
- UI에서 내 메시지/관리자 메시지 구분

### 2. 데이터 흐름
```
회원 메시지 전송:
1. 회원이 메시지 입력
2. Firestore messages 컬렉션에 저장 (senderType: 'member')
3. chatRooms의 adminUnreadCount 증가
4. 실시간으로 관리자 앱에 알림

관리자 메시지 수신:
1. 관리자가 메시지 전송
2. 회원 앱에서 실시간 수신
3. 회원이 채팅방 열면 memberUnreadCount 초기화
```

### 3. 보안 설정 (Firestore Rules)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /chatRooms/{chatRoomId} {
      allow read, write: if request.auth != null;
    }
    
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 🚨 주의사항

1. **Firebase 프로젝트 동일성**: 관리자 앱과 **동일한 Firebase 프로젝트** 사용
2. **데이터 구조 일치**: ChatRoom, ChatMessage 모델 구조 동일하게 유지
3. **브랜치 ID 관리**: 회원의 소속 지점 정보 정확히 설정
4. **에러 처리**: 네트워크 오류, 권한 오류 등 적절한 예외 처리
5. **실시간 동기화**: Stream 구독 해제 및 메모리 누수 방지

## 🎯 테스트 체크리스트

- [ ] Firebase 초기화 성공
- [ ] 채팅방 생성/조회 정상 동작
- [ ] 메시지 전송 성공 (회원 → 관리자)
- [ ] 메시지 수신 확인 (관리자 → 회원)
- [ ] 실시간 동기화 동작
- [ ] 읽음/읽지않음 상태 관리
- [ ] 지점별 데이터 분리 확인
- [ ] UI/UX 정상 동작

## 📞 지원

구현 중 문제가 발생하면 이 가이드의 코드와 설정을 참조하여 Claude AI와 함께 해결하세요.

---
*이 가이드는 관리자 앱에서 성공적으로 구현된 채팅 시스템을 기반으로 작성되었습니다.*