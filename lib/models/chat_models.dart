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
  final int adminUnreadCount; // 관리자 읽지 않은 메시지 수
  final int memberUnreadCount; // 회원 읽지 않은 메시지 수
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
    
    // Timestamp 변환 헬퍼 함수
    DateTime _parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }
    
    return ChatRoom(
      id: doc.id,
      branchId: data['branchId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      memberPhone: data['memberPhone'] ?? '',
      memberType: data['memberType'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: _parseTimestamp(data['lastMessageTime']),
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

  // 채팅방 ID 생성: branchId_memberId
  static String generateChatRoomId(String branchId, String memberId) {
    return '${branchId}_${memberId}';
  }
}

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String branchId;
  final String senderId;
  final String senderType; // 'member' or 'admin'
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
    
    // Timestamp 변환 헬퍼 함수
    DateTime _parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }
    
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      branchId: data['branchId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'member',
      senderName: data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
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

  // 메시지 ID 생성: branchId_memberId_timestamp
  static String generateMessageId(String branchId, String memberId) {
    return '${branchId}_${memberId}_${DateTime.now().millisecondsSinceEpoch}';
  }
}