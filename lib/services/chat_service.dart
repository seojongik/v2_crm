// Supabase로 전환: ChatService를 ChatServiceSupabase의 wrapper로 사용
import 'chat_service_supabase.dart';
import '../models/chat_models.dart';
export '../models/chat_models.dart' show ChatRoom, ChatMessage;

/// ChatService는 ChatServiceSupabase의 wrapper입니다.
/// 기존 코드와의 호환성을 위해 유지됩니다.
class ChatService {
  // 모든 정적 메서드를 ChatServiceSupabase로 위임
  static String? getCurrentBranchId() => ChatServiceSupabase.getCurrentBranchId();
  
  static Future<ChatRoom> getOrCreateChatRoom(
    String memberId,
    String memberName,
    String memberPhone,
    String memberType,
  ) => ChatServiceSupabase.getOrCreateChatRoom(memberId, memberName, memberPhone, memberType);
  
  static Stream<List<ChatRoom>> getChatRoomsStream() => ChatServiceSupabase.getChatRoomsStream();
  
  static Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) =>
      ChatServiceSupabase.getMessagesStream(chatRoomId);
  
  static Future<void> sendMessage(String chatRoomId, String memberId, String message) =>
      ChatServiceSupabase.sendMessage(chatRoomId, memberId, message);
  
  static Future<void> markMessagesAsRead(String chatRoomId, String memberId) =>
      ChatServiceSupabase.markMessagesAsRead(chatRoomId, memberId);
  
  static Future<void> deleteChatRoom(String chatRoomId) =>
      ChatServiceSupabase.deleteChatRoom(chatRoomId);
  
  static Future<int> getMessageCount(String chatRoomId) =>
      ChatServiceSupabase.getMessageCount(chatRoomId);
  
  static Stream<int> getUnreadMessageCountStream() =>
      ChatServiceSupabase.getUnreadMessageCountStream();
  
  static Stream<int> getMessageActivityStream() =>
      ChatServiceSupabase.getMessageActivityStream();
  
  static Stream<Map<String, dynamic>?> getLatestMessageInfoStream() =>
      ChatServiceSupabase.getLatestMessageInfoStream();
  
  static Stream<int> getUnreadMessageCountForMember(String memberId) =>
      ChatServiceSupabase.getUnreadMessageCountForMember(memberId);
  
  static Stream<Map<String, int>> getUnreadMessageCountsMapStream() =>
      ChatServiceSupabase.getUnreadMessageCountsMapStream();
}
