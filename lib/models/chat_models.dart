import 'dart:convert';

// Supabase와 Firestore 모두 지원하는 모델 클래스
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

  // Supabase용: Map에서 생성
  factory ChatRoom.fromMap(Map<String, dynamic> data, {String? id}) {
    // Timestamp 변환 헬퍼 함수 (Supabase는 ISO8601 문자열 또는 DateTime 반환)
    DateTime _parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }
    
    // bool 타입 안전하게 변환
    bool _parseBool(dynamic value, {bool defaultValue = false}) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value != 0;
      return defaultValue;
    }
    
    return ChatRoom(
      id: id ?? data['id'] ?? '',
      branchId: data['branch_id'] ?? data['branchId'] ?? '',
      memberId: data['member_id'] ?? data['memberId'] ?? '',
      memberName: data['member_name'] ?? data['memberName'] ?? '',
      memberPhone: data['member_phone'] ?? data['memberPhone'] ?? '',
      memberType: data['member_type'] ?? data['memberType'] ?? '',
      createdAt: _parseTimestamp(data['created_at'] ?? data['createdAt']),
      lastMessage: data['last_message'] ?? data['lastMessage'] ?? '',
      lastMessageTime: _parseTimestamp(data['last_message_time'] ?? data['lastMessageTime']),
      adminUnreadCount: data['admin_unread_count'] ?? data['adminUnreadCount'] ?? 0,
      memberUnreadCount: data['member_unread_count'] ?? data['memberUnreadCount'] ?? 0,
      isActive: _parseBool(data['is_active'] ?? data['isActive'], defaultValue: true),
    );
  }

  // Firestore용 (하위 호환성 유지)
  factory ChatRoom.fromFirestore(dynamic doc) {
    // Firestore DocumentSnapshot 또는 Supabase Map 모두 처리
    Map<String, dynamic> data;
    String docId;
    
    if (doc is Map<String, dynamic>) {
      // Supabase Map
      data = doc;
      docId = doc['id'] ?? '';
    } else {
      // Firestore DocumentSnapshot
      data = doc.data() as Map<String, dynamic>;
      docId = doc.id;
    }
    
    return ChatRoom.fromMap(data, id: docId);
  }

  // Supabase용: Map으로 변환 (snake_case)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'member_id': memberId,
      'member_name': memberName,
      'member_phone': memberPhone,
      'member_type': memberType,
      'created_at': createdAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.toIso8601String(),
      'admin_unread_count': adminUnreadCount,
      'member_unread_count': memberUnreadCount,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Firestore용 (하위 호환성 유지)
  Map<String, dynamic> toFirestore() {
    // Firestore는 Timestamp 객체 필요하므로 별도 처리
    // Supabase에서는 toMap() 사용
    return {
      'branchId': branchId,
      'memberId': memberId,
      'memberName': memberName,
      'memberPhone': memberPhone,
      'memberType': memberType,
      'createdAt': createdAt,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
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

// Supabase와 Firestore 모두 지원하는 모델 클래스
class ChatMessage {
  final String id;
  final String chatRoomId;
  final String branchId;
  final String senderId;
  final String senderType; // 'member', 'admin', 'pro', 'manager'
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isRead; // 하위 호환성을 위해 유지
  final Map<String, bool> readBy; // 각 sender_type별 읽음 상태

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
    Map<String, bool>? readBy,
  }) : readBy = readBy ?? {
          'member': false,
          'pro': false,
          'manager': false,
          'admin': false,
        };

  // Supabase용: Map에서 생성
  factory ChatMessage.fromMap(Map<String, dynamic> data, {String? id}) {
    // Timestamp 변환 헬퍼 함수 (Supabase는 ISO8601 문자열 또는 DateTime 반환)
    DateTime _parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }
    
    // bool 타입 안전하게 변환
    bool _parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value != 0;
      return false;
    }
    
    // read_by JSONB 파싱
    Map<String, bool> _parseReadBy(dynamic value) {
      if (value == null) {
        return {
          'member': false,
          'pro': false,
          'manager': false,
          'admin': false,
        };
      }
      
      if (value is Map<String, dynamic>) {
        return {
          'member': _parseBool(value['member'] ?? value['Member']),
          'pro': _parseBool(value['pro'] ?? value['Pro']),
          'manager': _parseBool(value['manager'] ?? value['Manager']),
          'admin': _parseBool(value['admin'] ?? value['Admin']),
        };
      }
      
      if (value is String) {
        try {
          final parsed = Map<String, dynamic>.from(
            Map<String, dynamic>.from(
              // JSON 문자열 파싱 시도
              value.startsWith('{') ? jsonDecode(value) : {}
            )
          );
          return {
            'member': _parseBool(parsed['member'] ?? parsed['Member']),
            'pro': _parseBool(parsed['pro'] ?? parsed['Pro']),
            'manager': _parseBool(parsed['manager'] ?? parsed['Manager']),
            'admin': _parseBool(parsed['admin'] ?? parsed['Admin']),
          };
        } catch (e) {
          return {
            'member': false,
            'pro': false,
            'manager': false,
            'admin': false,
          };
        }
      }
      
      return {
        'member': false,
        'pro': false,
        'manager': false,
        'admin': false,
      };
    }
    
    final readByData = data['read_by'] ?? data['readBy'] ?? data['read_by'];
    final parsedReadBy = _parseReadBy(readByData);
    final isReadValue = _parseBool(data['is_read'] ?? data['isRead']);
    
    return ChatMessage(
      id: id ?? data['id'] ?? '',
      chatRoomId: data['chat_room_id'] ?? data['chatRoomId'] ?? '',
      branchId: data['branch_id'] ?? data['branchId'] ?? '',
      senderId: data['sender_id'] ?? data['senderId'] ?? '',
      senderType: data['sender_type'] ?? data['senderType'] ?? 'member',
      senderName: data['sender_name'] ?? data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      isRead: isReadValue,
      readBy: parsedReadBy,
    );
  }

  // Firestore용 (하위 호환성 유지)
  factory ChatMessage.fromFirestore(dynamic doc) {
    // Firestore DocumentSnapshot 또는 Supabase Map 모두 처리
    Map<String, dynamic> data;
    String docId;
    
    if (doc is Map<String, dynamic>) {
      // Supabase Map
      data = doc;
      docId = doc['id'] ?? '';
    } else {
      // Firestore DocumentSnapshot
      data = doc.data() as Map<String, dynamic>;
      docId = doc.id;
    }
    
    return ChatMessage.fromMap(data, id: docId);
  }

  // Supabase용: Map으로 변환 (snake_case)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_room_id': chatRoomId,
      'branch_id': branchId,
      'sender_id': senderId,
      'sender_type': senderType,
      'sender_name': senderName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead, // 하위 호환성 유지
      'read_by': readBy, // JSONB 필드
    };
  }

  // Firestore용 (하위 호환성 유지)
  Map<String, dynamic> toFirestore() {
    // Firestore는 Timestamp 객체 필요하므로 별도 처리
    // Supabase에서는 toMap() 사용
    return {
      'chatRoomId': chatRoomId,
      'branchId': branchId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'readBy': readBy,
    };
  }
  
  // 특정 sender_type이 읽었는지 확인
  bool isReadBy(String senderType) {
    return readBy[senderType] ?? false;
  }
  
  // 읽음 상태를 문자열로 반환 (UI 표시용)
  String getReadStatusText() {
    final readStatuses = <String>[];
    if (readBy['member'] == true) readStatuses.add('회원');
    if (readBy['pro'] == true) readStatuses.add('프로');
    if (readBy['manager'] == true) readStatuses.add('매니저');
    if (readBy['admin'] == true) readStatuses.add('관리자');
    
    if (readStatuses.isEmpty) return '';
    return readStatuses.join(', ') + ' 읽음';
  }

  // 메시지 ID 생성: branchId_memberId_timestamp
  static String generateMessageId(String branchId, String memberId) {
    return '${branchId}_${memberId}_${DateTime.now().millisecondsSinceEpoch}';
  }
}