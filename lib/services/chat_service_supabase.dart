import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../models/chat_models.dart';
import 'api_service.dart';
import 'supabase_adapter.dart';

/// Supabase 기반 채팅 서비스
/// Firebase Firestore 대신 Supabase PostgreSQL + Realtime 사용
class ChatServiceSupabase {
  static SupabaseClient get _supabase => SupabaseAdapter.client;

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
  static Future<ChatRoom> getOrCreateChatRoom(
      String memberId, String memberName, String memberPhone, String memberType) async {
    print('🏢 ChatServiceSupabase.getOrCreateChatRoom 시작');

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
      // 기존 채팅방 조회
      final response = await _supabase
          .from('chat_rooms')
          .select()
          .eq('id', chatRoomId)
          .maybeSingle();

      if (response != null) {
        print('✅ 기존 채팅방 발견');
        return ChatRoom.fromMap(response);
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

        print('💾 Supabase에 채팅방 저장 중...');
        await _supabase.from('chat_rooms').insert(newChatRoom.toMap());
        print('✅ 새 채팅방 저장 완료');

        return newChatRoom;
      }
    } catch (e, stackTrace) {
      print('❌ ChatServiceSupabase.getOrCreateChatRoom 에러!');
      print('에러: $e');
      print('타입: ${e.runtimeType}');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 현재 지점의 채팅방 목록 가져오기 (실시간 구독)
  static Stream<List<ChatRoom>> getChatRoomsStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value([]);
    }

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_rooms')
          .select()
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .order('last_message_time', ascending: false)
          .then((data) => (data as List)
              .map((item) => ChatRoom.fromMap(item as Map<String, dynamic>))
              .toList()),
    );

    // 초기 데이터 + 실시간 업데이트 스트림
    return initialStream.asyncExpand((initialRooms) {
      // 실시간 변경사항을 처리하는 스트림
      final changeStream = StreamController<List<ChatRoom>>();

      // 초기 데이터 전송
      changeStream.add(initialRooms);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_rooms_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) async {
              // 변경사항 발생 시 전체 목록 다시 조회
              try {
                final updatedData = await _supabase
                    .from('chat_rooms')
                    .select()
                    .eq('branch_id', branchId)
                    .eq('is_active', true)
                    .order('last_message_time', ascending: false);
                
                final updatedRooms = (updatedData as List)
                    .map((item) => ChatRoom.fromMap(item as Map<String, dynamic>))
                    .toList();
                
                changeStream.add(updatedRooms);
              } catch (e) {
                print('❌ 채팅방 목록 업데이트 실패: $e');
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream;
    });
  }

  // 특정 채팅방의 메시지 목록 가져오기 (실시간 구독)
  static Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    print('📡 메시지 스트림 시작: $chatRoomId');

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('timestamp', ascending: true)
          .then((data) => (data as List)
              .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
              .toList()),
    );

    // 초기 데이터 + 실시간 업데이트 스트림
    return initialStream.asyncExpand((initialMessages) {
      final changeStream = StreamController<List<ChatMessage>>();

      // 초기 데이터 전송
      changeStream.add(initialMessages);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_messages_$chatRoomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_room_id',
              value: chatRoomId,
            ),
            callback: (payload) async {
              // 변경사항 발생 시 전체 목록 다시 조회
              try {
                final updatedData = await _supabase
                    .from('chat_messages')
                    .select()
                    .eq('chat_room_id', chatRoomId)
                    .order('timestamp', ascending: true);
                
                final updatedMessages = (updatedData as List)
                    .map((item) => ChatMessage.fromMap(item as Map<String, dynamic>))
                    .toList();
                
                changeStream.add(updatedMessages);
              } catch (e) {
                print('❌ 메시지 목록 업데이트 실패: $e');
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream;
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
      readBy: {
        'member': false,
        'pro': false,
        'manager': false,
        'admin': false,
      },
    );

    try {
      // 현재 채팅방 정보 가져오기
      final chatRoomData = await _supabase
          .from('chat_rooms')
          .select('member_unread_count')
          .eq('id', chatRoomId)
          .single();

      final currentUnreadCount = (chatRoomData['member_unread_count'] as int? ?? 0);

      // 트랜잭션: 메시지 삽입 + 채팅방 업데이트
      await _supabase.from('chat_messages').insert(chatMessage.toMap());

      // 채팅방 마지막 메시지 업데이트
      await _supabase.from('chat_rooms').update({
        'last_message': message,
        'last_message_time': DateTime.now().toIso8601String(),
        'member_unread_count': currentUnreadCount + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chatRoomId);

      print('📨 메시지 전송 완료: $message');
      print('🔔 memberUnreadCount 증가 → 회원에게 알림 발생 예상');
    } catch (e) {
      print('❌ 메시지 전송 실패: $e');
      rethrow;
    }
  }

  // 관리자/프로/매니저가 메시지를 읽었을 때 (회원이 보낸 메시지)
  static Future<void> markMessagesAsRead(String chatRoomId, String memberId) async {
    final branchId = _getCurrentBranchId();
    if (branchId == null) return;

    // 현재 로그인한 사용자의 sender_type 가져오기
    final currentUserRole = ApiService.getCurrentStaffRole() ?? 'admin';
    
    // 읽음 처리할 sender_type 결정
    String readByKey;
    switch (currentUserRole) {
      case 'pro':
        readByKey = 'pro';
        break;
      case 'manager':
        readByKey = 'manager';
        break;
      case 'admin':
      default:
        readByKey = 'admin';
        break;
    }

    try {
      // 읽지 않은 회원 메시지들을 현재 사용자의 sender_type으로 읽음 처리
      // 먼저 읽지 않은 메시지들을 조회
      final unreadMessages = await _supabase
          .from('chat_messages')
          .select('id, read_by')
          .eq('chat_room_id', chatRoomId)
          .eq('sender_type', 'member');

      if (unreadMessages.isNotEmpty) {
        for (final msg in unreadMessages) {
          // 현재 read_by 상태 확인
          final currentReadBy = msg['read_by'] as Map<String, dynamic>? ?? {
            'member': false,
            'pro': false,
            'manager': false,
            'admin': false,
          };
          
          // 이미 읽었으면 스킵
          if (currentReadBy[readByKey] == true) continue;
          
          // read_by 업데이트
          final updatedReadBy = Map<String, dynamic>.from(currentReadBy);
          updatedReadBy[readByKey] = true;
          
          // is_read도 업데이트 (하위 호환성) - 모든 타입이 읽었는지 확인
          final allRead = (updatedReadBy['member'] == true) &&
                          (updatedReadBy['pro'] == true) &&
                          (updatedReadBy['manager'] == true) &&
                          (updatedReadBy['admin'] == true);

          await _supabase
              .from('chat_messages')
              .update({
                'read_by': updatedReadBy,
                'is_read': allRead,
              })
              .eq('id', msg['id']);
        }
      }

      // 주의: admin_unread_count는 공유 필드이므로 업데이트하지 않음
      // 각 역할별 읽음 상태는 read_by 필드로 관리되며, 카운트는 read_by 기반으로 계산됨
      // admin_unread_count를 0으로 만들면 다른 역할의 카운트에도 영향을 주므로 업데이트하지 않음
      
      print('✅ [읽음처리] 채팅방 $chatRoomId의 메시지를 읽음 처리 완료 (역할: $readByKey, read_by 업데이트됨)');
    } catch (e) {
      print('❌ 메시지 읽음 처리 실패: $e');
      rethrow;
    }
  }

  // 회원이 관리자/프로/매니저 메시지를 읽었을 때 - 회원 앱에서 호출
  static Future<void> markAdminMessagesAsReadByMember(String chatRoomId) async {
    final branchId = _getCurrentBranchId();
    if (branchId == null) return;

    try {
      // 읽지 않은 관리자/프로/매니저 메시지들을 회원이 읽음 처리
      final unreadMessages = await _supabase
          .from('chat_messages')
          .select('id, read_by')
          .eq('chat_room_id', chatRoomId)
          .inFilter('sender_type', ['admin', 'pro', 'manager']);

      if (unreadMessages.isNotEmpty) {
        for (final msg in unreadMessages) {
          // 현재 read_by 상태 확인
          final currentReadBy = msg['read_by'] as Map<String, dynamic>? ?? {
            'member': false,
            'pro': false,
            'manager': false,
            'admin': false,
          };
          
          // 이미 회원이 읽었으면 스킵
          if (currentReadBy['member'] == true) continue;
          
          // read_by 업데이트
          final updatedReadBy = Map<String, dynamic>.from(currentReadBy);
          updatedReadBy['member'] = true;
          
          // is_read도 업데이트 (하위 호환성) - 모든 타입이 읽었는지 확인
          final allRead = (updatedReadBy['member'] == true) &&
                          (updatedReadBy['pro'] == true) &&
                          (updatedReadBy['manager'] == true) &&
                          (updatedReadBy['admin'] == true);

          await _supabase
              .from('chat_messages')
              .update({
                'read_by': updatedReadBy,
                'is_read': allRead,
              })
              .eq('id', msg['id']);
        }
      }

      // 채팅방의 회원 읽지 않은 메시지 수 초기화
      await _supabase.from('chat_rooms').update({
        'member_unread_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chatRoomId);
    } catch (e) {
      print('❌ 메시지 읽음 처리 실패: $e');
      rethrow;
    }
  }

  // 채팅방 삭제 (비활성화)
  static Future<void> deleteChatRoom(String chatRoomId) async {
    await _supabase
        .from('chat_rooms')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', chatRoomId);
  }

  // 메시지 개수 가져오기
  static Future<int> getMessageCount(String chatRoomId) async {
    final response = await _supabase
        .from('chat_messages')
        .select('id')
        .eq('chat_room_id', chatRoomId);

    return (response as List).length;
  }

  // 현재 지점의 읽지 않은 메시지 총 개수 (현재 사용자 역할 기준)
  // 각 역할별로 독립적인 읽지 않은 메시지 카운트를 위해 read_by 필드 기반 계산
  static Stream<int> getUnreadMessageCountStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value(0);
    }

    // 현재 사용자 역할 가져오기
    final currentUserRole = ApiService.getCurrentStaffRole() ?? 'admin';
    final readByKey = currentUserRole == 'pro' ? 'pro' : (currentUserRole == 'manager' ? 'manager' : 'admin');

    // 초기 데이터 로드 - read_by 필드를 기반으로 각 역할별 읽지 않은 메시지 계산
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_rooms')
          .select('id')
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .then((chatRooms) async {
            int totalUnread = 0;
            
            // 각 채팅방별로 읽지 않은 메시지 수 계산
            for (final chatRoom in chatRooms as List) {
              final chatRoomId = chatRoom['id'] as String;
              
              // 해당 채팅방의 읽지 않은 회원 메시지 수 계산 (현재 역할 기준)
              final unreadMessages = await _supabase
                  .from('chat_messages')
                  .select('read_by')
                  .eq('chat_room_id', chatRoomId)
                  .eq('sender_type', 'member');
              
              for (final msg in unreadMessages as List) {
                final readBy = msg['read_by'] as Map<String, dynamic>? ?? {
                  'member': false,
                  'pro': false,
                  'manager': false,
                  'admin': false,
                };
                
                // 현재 역할이 읽지 않은 메시지면 카운트 증가
                if (readBy[readByKey] != true) {
                  totalUnread++;
                }
              }
            }
            
            print('📊 [읽지않은메시지] 총 ${totalUnread}개 (역할: $readByKey)');
            return totalUnread;
          }),
    );

    return initialStream.asyncExpand((initialCount) {
      final changeStream = StreamController<int>();

      changeStream.add(initialCount);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_rooms_unread_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) async {
              try {
                // read_by 필드를 기반으로 각 역할별 읽지 않은 메시지 수 재계산
                final chatRooms = await _supabase
                    .from('chat_rooms')
                    .select('id')
                    .eq('branch_id', branchId)
                    .eq('is_active', true);

                int totalUnread = 0;
                for (final chatRoom in chatRooms as List) {
                  final chatRoomId = chatRoom['id'] as String;
                  
                  final unreadMessages = await _supabase
                      .from('chat_messages')
                      .select('read_by')
                      .eq('chat_room_id', chatRoomId)
                      .eq('sender_type', 'member');
                  
                  for (final msg in unreadMessages as List) {
                    final readBy = msg['read_by'] as Map<String, dynamic>? ?? {
                      'member': false,
                      'pro': false,
                      'manager': false,
                      'admin': false,
                    };
                    
                    if (readBy[readByKey] != true) {
                      totalUnread++;
                    }
                  }
                }

                changeStream.add(totalUnread);
              } catch (e) {
                print('❌ 읽지 않은 메시지 수 업데이트 실패: $e');
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream.distinct().debounceTime(const Duration(milliseconds: 300));
    });
  }

  // 새로운 메시지 활동 스트림 (관리자/회원 구분 없이 모든 메시지 활동 감지)
  static Stream<int> getMessageActivityStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      print('🔍 [ChatServiceSupabase] branchId가 null - 메시지 활동 스트림 중단');
      return Stream.value(0);
    }

    print('🔍 [ChatServiceSupabase] 메시지 활동 스트림 시작 - branchId: $branchId');

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_messages')
          .select('timestamp')
          .eq('branch_id', branchId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle()
          .then((data) {
            if (data == null) return 0;
            final timestamp = data['timestamp'];
            if (timestamp is DateTime) {
              return timestamp.millisecondsSinceEpoch;
            } else if (timestamp is String) {
              return DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? 0;
            }
            return 0;
          }),
    );

    return initialStream.asyncExpand((initialTimestamp) {
      final changeStream = StreamController<int>();

      changeStream.add(initialTimestamp);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_messages_activity_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                final timestamp = newRecord['timestamp'];
                int timestampMs = 0;
                if (timestamp is DateTime) {
                  timestampMs = timestamp.millisecondsSinceEpoch;
                } else if (timestamp is String) {
                  timestampMs = DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? 0;
                }
                changeStream.add(timestampMs);
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream;
    });
  }

  // 최신 메시지 상세 정보 스트림 (알림용)
  static Stream<Map<String, dynamic>?> getLatestMessageInfoStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      print('🔍 [ChatServiceSupabase] branchId가 null - 최신 메시지 정보 스트림 중단');
      return Stream.value(null);
    }

    print('🔍 [ChatServiceSupabase] 최신 메시지 정보 스트림 시작 - branchId: $branchId');

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_messages')
          .select()
          .eq('branch_id', branchId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle()
          .then((data) {
            if (data == null) return null;
            final msg = ChatMessage.fromMap(data as Map<String, dynamic>);
            return {
              'timestamp': msg.timestamp.millisecondsSinceEpoch,
              'senderType': msg.senderType,
              'senderName': msg.senderName,
              'message': msg.message,
              'chatRoomId': msg.chatRoomId,
            };
          }),
    );

    return initialStream.asyncExpand((initialMessage) {
      final changeStream = StreamController<Map<String, dynamic>?>();

      if (initialMessage != null) {
        changeStream.add(initialMessage);
      }

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_messages_latest_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                final msg = ChatMessage.fromMap(newRecord);
                changeStream.add({
                  'timestamp': msg.timestamp.millisecondsSinceEpoch,
                  'senderType': msg.senderType,
                  'senderName': msg.senderName,
                  'message': msg.message,
                  'chatRoomId': msg.chatRoomId,
                });
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream;
    });
  }

  // 특정 회원의 읽지 않은 메시지 개수
  static Stream<int> getUnreadMessageCountForMember(String memberId) {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value(0);
    }

    final chatRoomId = ChatRoom.generateChatRoomId(branchId, memberId);

    // 초기 데이터 로드
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_rooms')
          .select('admin_unread_count')
          .eq('id', chatRoomId)
          .maybeSingle()
          .then((data) => data?['admin_unread_count'] as int? ?? 0),
    );

    return initialStream.asyncExpand((initialCount) {
      final changeStream = StreamController<int>();

      changeStream.add(initialCount);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_room_unread_$chatRoomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'chat_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: chatRoomId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                changeStream.add(newRecord['admin_unread_count'] as int? ?? 0);
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream;
    });
  }

  // 현재 지점의 모든 회원별 읽지 않은 메시지 개수 맵 (현재 사용자 역할 기준)
  static Stream<Map<String, int>> getUnreadMessageCountsMapStream() {
    final branchId = _getCurrentBranchId();
    if (branchId == null) {
      return Stream.value({});
    }

    // 현재 사용자 역할 가져오기
    final currentUserRole = ApiService.getCurrentStaffRole() ?? 'admin';
    final readByKey = currentUserRole == 'pro' ? 'pro' : (currentUserRole == 'manager' ? 'manager' : 'admin');

    // 초기 데이터 로드 - read_by 필드를 기반으로 각 역할별 읽지 않은 메시지 계산
    final initialStream = Stream.fromFuture(
      _supabase
          .from('chat_rooms')
          .select('id, member_id')
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .then((chatRooms) async {
            Map<String, int> unreadCounts = {};
            
            // 각 채팅방별로 읽지 않은 메시지 수 계산
            for (final chatRoom in chatRooms as List) {
              final chatRoomId = chatRoom['id'] as String;
              final memberId = chatRoom['member_id'] as String?;
              
              if (memberId == null) continue;
              
              // 해당 채팅방의 읽지 않은 회원 메시지 수 계산 (현재 역할 기준)
              final unreadMessages = await _supabase
                  .from('chat_messages')
                  .select('read_by')
                  .eq('chat_room_id', chatRoomId)
                  .eq('sender_type', 'member');
              
              int count = 0;
              for (final msg in unreadMessages as List) {
                final readBy = msg['read_by'] as Map<String, dynamic>? ?? {
                  'member': false,
                  'pro': false,
                  'manager': false,
                  'admin': false,
                };
                
                // 현재 역할이 읽지 않은 메시지면 카운트 증가
                if (readBy[readByKey] != true) {
                  count++;
                }
              }
              
              if (count > 0) {
                unreadCounts[memberId] = count;
              }
            }
            
            return unreadCounts;
          }),
    );

    return initialStream.asyncExpand((initialMap) {
      final changeStream = StreamController<Map<String, int>>();

      changeStream.add(initialMap);

      // Realtime 구독 (asyncExpand 내부에서 생성하여 스트림과 함께 관리)
      final channel = _supabase
          .channel('chat_rooms_unread_map_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) async {
              try {
                // read_by 필드를 기반으로 각 역할별 읽지 않은 메시지 수 재계산
                final chatRooms = await _supabase
                    .from('chat_rooms')
                    .select('id, member_id')
                    .eq('branch_id', branchId)
                    .eq('is_active', true);

                Map<String, int> unreadCounts = {};
                for (final chatRoom in chatRooms as List) {
                  final chatRoomId = chatRoom['id'] as String;
                  final memberId = chatRoom['member_id'] as String?;
                  
                  if (memberId == null) continue;
                  
                  final unreadMessages = await _supabase
                      .from('chat_messages')
                      .select('read_by')
                      .eq('chat_room_id', chatRoomId)
                      .eq('sender_type', 'member');
                  
                  int count = 0;
                  for (final msg in unreadMessages as List) {
                    final readBy = msg['read_by'] as Map<String, dynamic>? ?? {
                      'member': false,
                      'pro': false,
                      'manager': false,
                      'admin': false,
                    };
                    
                    if (readBy[readByKey] != true) {
                      count++;
                    }
                  }
                  
                  if (count > 0) {
                    unreadCounts[memberId] = count;
                  }
                }

                changeStream.add(unreadCounts);
              } catch (e) {
                print('❌ 읽지 않은 메시지 맵 업데이트 실패: $e');
              }
            },
          )
          .subscribe();

      // 스트림이 취소될 때 채널 구독 해제
      changeStream.onCancel = () {
        channel.unsubscribe();
      };

      return changeStream.stream
          .debounceTime(const Duration(milliseconds: 300))
          .distinct();
    });
  }
}

