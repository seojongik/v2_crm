import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/chat_models.dart';
import 'api_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 지점 ID 가져오기
  static String? _getCurrentBranchId() {
    return ApiService.getCurrentBranchId();
  }

  // 현재 지점 ID 가져오기 (공개 메서드)
  static String? getCurrentBranchId() {
    return ApiService.getCurrentBranchId();
  }

  // 현재 관리자 정보 가져오기
  static Map<String, dynamic>? _getCurrentAdmin() {
    return ApiService.getCurrentUser();
  }

  // 채팅방 생성 또는 가져오기
  static Future<ChatRoom> getOrCreateChatRoom(String memberId, String memberName, String memberPhone, String memberType) async {
    print('🏢 ChatService.getOrCreateChatRoom 시작');

    // 현재 관리자 정보 확인 (Firebase Auth 대신 DB 정보 사용)
    final admin = _getCurrentAdmin();
    print('👤 현재 관리자: ${admin?['staff_name']} (ID: ${admin?['staff_id']})');

    final branchId = _getCurrentBranchId();
    print('📍 브랜치 ID: $branchId');

    if (branchId == null) {
      print('❌ 브랜치 ID가 null입니다');
      throw Exception('지점 정보를 찾을 수 없습니다.');
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    print('🆔 생성된 채팅방 ID: $chatRoomId');

    try {
      final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
      print('📁 Firestore 참조 생성 완료');

      print('🔍 기존 채팅방 조회 중...');
      final doc = await chatRoomRef.get();
      print('📄 문서 조회 완료: exists=${doc.exists}');
      
      if (doc.exists) {
        print('✅ 기존 채팅방 발견');
        print('📊 원본 데이터: ${doc.data()}');
        
        try {
          final chatRoom = ChatRoom.fromFirestore(doc);
          print('🏠 채팅방 정보: ${chatRoom.memberName}');
          return chatRoom;
        } catch (e) {
          print('❌ ChatRoom.fromFirestore 파싱 에러: $e');
          rethrow;
        }
      } else {
        print('🆕 새 채팅방 생성 중...');
        
        // 새 채팅방 생성
        final newChatRoom = ChatRoom(
          id: chatRoomId,
          branchId: branchId,
          memberId: memberId,
          memberName: memberName,
          memberPhone: memberPhone,
          memberType: memberType,
          createdAt: DateTime.now(),
          lastMessage: '',
          lastMessageTime: DateTime.now(),
        );

        print('💾 Firestore에 채팅방 저장 중...');
        await chatRoomRef.set(newChatRoom.toFirestore());
        print('✅ 새 채팅방 저장 완료');
        
        return newChatRoom;
      }
    } catch (e, stackTrace) {
      print('❌ ChatService.getOrCreateChatRoom 에러!');
      print('에러: $e');
      print('타입: ${e.runtimeType}');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 현재 지점의 채팅방 목록 가져오기
  static Stream<List<ChatRoom>> getChatRoomsStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chatRooms')
        .where('branchId', isEqualTo: branchId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      // 클라이언트에서 정렬 (인덱스 불필요)
      final chatRooms = snapshot.docs
          .map((doc) => ChatRoom.fromFirestore(doc))
          .toList();
      
      chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      
      return chatRooms;
    });
  }

  // 특정 채팅방의 메시지 목록 가져오기
  static Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    print('📡 메시지 스트림 시작: $chatRoomId');

    return _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .snapshots()
        .map((snapshot) {
      print('📬 메시지 수신: ${snapshot.docs.length}개');
      
      // 클라이언트에서 정렬 (인덱스 불필요)
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
      
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return messages;
    });
  }

  // 메시지 전송
  static Future<void> sendMessage(String chatRoomId, String memberId, String message) async {
    final branchId = _getCurrentBranchId();
    final admin = _getCurrentAdmin();
    
    if (branchId == null || admin == null) {
      throw Exception('관리자 정보를 찾을 수 없습니다.');
    }

    final adminName = admin['staff_name'] ?? '관리자';
    final adminId = admin['staff_id']?.toString() ?? 'admin';

    // 메시지 ID 생성
    final messageId = ChatMessage.generateMessageId(branchId, memberId);
    
    // 메시지 생성
    final chatMessage = ChatMessage(
      id: messageId,
      chatRoomId: chatRoomId,
      branchId: branchId,
      senderId: adminId,
      senderType: 'admin',
      senderName: adminName,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    );

    // Firestore에 저장
    final batch = _firestore.batch();

    // 메시지 추가 (최상위 messages 컬렉션)
    final messageRef = _firestore.collection('messages').doc(messageId);
    batch.set(messageRef, chatMessage.toFirestore());

    // 채팅방 마지막 메시지 업데이트
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'lastMessage': message,
      'lastMessageTime': Timestamp.fromDate(DateTime.now()),
      'memberUnreadCount': FieldValue.increment(1), // 회원 읽지 않은 메시지 증가
    });

    await batch.commit();
    
    print('📨 메시지 전송 완료: $message');
    print('🔔 memberUnreadCount 증가 → 회원에게 알림 발생 예상');
  }

  // 관리자가 메시지를 읽었을 때 (회원이 보낸 메시지)
  static Future<void> markMessagesAsRead(String chatRoomId, String memberId) async {
    final branchId = _getCurrentBranchId();
    if (branchId == null) return;

    // 읽지 않은 회원 메시지들을 모두 읽음 처리
    final unreadMessages = await _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .where('senderType', isEqualTo: 'member')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    // 메시지들을 읽음 처리
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // 채팅방의 관리자 읽지 않은 메시지 수 초기화
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {'adminUnreadCount': 0});

    await batch.commit();
  }

  // 회원이 관리자 메시지를 읽었을 때 (관리자가 보낸 메시지) - 회원 앱에서 호출
  static Future<void> markAdminMessagesAsReadByMember(String chatRoomId) async {
    final branchId = _getCurrentBranchId();
    if (branchId == null) return;

    // 읽지 않은 관리자 메시지들을 모두 읽음 처리
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

  // 채팅방 삭제 (비활성화)
  static Future<void> deleteChatRoom(String chatRoomId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'isActive': false,
    });
  }

  // 메시지 개수 가져오기
  static Future<int> getMessageCount(String chatRoomId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .get();
    
    return snapshot.docs.length;
  }

  // 현재 지점의 읽지 않은 메시지 총 개수 (관리자 기준)
  static Stream<int> getUnreadMessageCountStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('chatRooms')
        .where('branchId', isEqualTo: branchId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .debounceTime(Duration(milliseconds: 300)) // 300ms 동안 업데이트 제한
        .map((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // 관리자 기준: 회원이 보낸 읽지 않은 메시지 수
        totalUnread += (data['adminUnreadCount'] as int? ?? 0);
      }
      print('🔍 [ChatService] 총 읽지 않은 메시지 수: $totalUnread');
      return totalUnread;
    }).distinct(); // 같은 값이 반복되지 않도록
  }
  
  // 새로운 메시지 활동 스트림 (관리자/회원 구분 없이 모든 메시지 활동 감지)
  static Stream<int> getMessageActivityStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      print('🔍 [ChatService] branchId가 null - 메시지 활동 스트림 중단');
      return Stream.value(0);
    }

    print('🔍 [ChatService] 메시지 활동 스트림 시작 - branchId: $branchId');

    try {
      return _firestore
          .collection('messages')
          .where('branchId', isEqualTo: branchId)
          .snapshots()
          .map((snapshot) {
        print('🔍 [ChatService] 메시지 컬렉션 변화 감지: ${snapshot.docs.length}개 메시지');
        
        if (snapshot.docs.isEmpty) {
          print('🔍 [ChatService] 메시지가 없음');
          return 0;
        }
        
        // 가장 최근 메시지 찾기 (클라이언트에서 정렬)
        final messages = snapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = data['timestamp'] as Timestamp?;
          return {
            'timestamp': timestamp?.millisecondsSinceEpoch ?? 0,
            'senderType': data['senderType'] ?? 'unknown',
            'message': data['message'] ?? '',
          };
        }).toList();
        
        messages.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        
        final latestMessage = messages.first;
        final timestamp = latestMessage['timestamp'] as int;
        final senderType = latestMessage['senderType'] as String;
        final messageText = latestMessage['message'] as String;
        
        print('🔍 [ChatService] 최신 메시지: ${senderType}가 "$messageText" 전송 (시간: $timestamp)');
        
        return timestamp;
      });
    } catch (e) {
      print('❌ [ChatService] 메시지 활동 스트림 에러: $e');
      return Stream.value(0);
    }
  }

  // 최신 메시지 상세 정보 스트림 (알림용)
  static Stream<Map<String, dynamic>?> getLatestMessageInfoStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      print('🔍 [ChatService] branchId가 null - 최신 메시지 정보 스트림 중단');
      return Stream.value(null);
    }

    print('🔍 [ChatService] 최신 메시지 정보 스트림 시작 - branchId: $branchId');

    try {
      return _firestore
          .collection('messages')
          .where('branchId', isEqualTo: branchId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return null;
        }
        
        // 가장 최근 메시지 찾기
        final messages = snapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = data['timestamp'] as Timestamp?;
          return {
            'timestamp': timestamp?.millisecondsSinceEpoch ?? 0,
            'senderType': data['senderType'] ?? 'unknown',
            'senderName': data['senderName'] ?? '알 수 없는 사용자',
            'message': data['message'] ?? '',
            'chatRoomId': data['chatRoomId'] ?? '',
          };
        }).toList();
        
        messages.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        
        final latestMessage = messages.first;
        print('📧 [ChatService] 최신 메시지 정보: ${latestMessage['senderName']} - ${latestMessage['message']}');
        
        return latestMessage;
      });
    } catch (e) {
      print('❌ [ChatService] 최신 메시지 정보 스트림 에러: $e');
      return Stream.value(null);
    }
  }

  // 특정 회원의 읽지 않은 메시지 개수
  static Stream<int> getUnreadMessageCountForMember(String memberId) {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value(0);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);
    
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data();
      return data?['adminUnreadCount'] as int? ?? 0;
    });
  }

  // 현재 지점의 모든 회원별 읽지 않은 메시지 개수 맵
  static Stream<Map<String, int>> getUnreadMessageCountsMapStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value({});
    }

    return _firestore
        .collection('chatRooms')
        .where('branchId', isEqualTo: branchId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .debounceTime(Duration(milliseconds: 300)) // 300ms 동안 업데이트 제한
        .map((snapshot) {
      Map<String, int> unreadCounts = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final memberId = data['memberId'] as String?;
        final unreadCount = data['adminUnreadCount'] as int? ?? 0;
        if (memberId != null) {
          unreadCounts[memberId] = unreadCount;
        }
      }
      return unreadCounts;
    });
  }
}