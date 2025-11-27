import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class JuniorLessonService {
  // 주니어 레슨 예약 API 호출
  static Future<Map<String, dynamic>> addJuniorLesson({
    required int juniorMemberId,
    String? branchId,
    required String juniorName,
    required String lessonDate,
    required String proName,
    required String sessionStartTime,
    required String sessionEndTime,
    required int sessionMinutes,
    String? notes,
  }) async {
    try {
      print('🔍 [디버깅] 주니어 레슨 추가 시작');
      print('🔍 [디버깅] 파라미터: juniorMemberId=$juniorMemberId, branchId=$branchId, juniorName=$juniorName, lessonDate=$lessonDate, proName=$proName');

      // 데이터 구성
      final lessonData = {
        'member_id': juniorMemberId,
        'member_name': juniorName,
        'scheduled_date': lessonDate,
        'pro_name': proName,
        'session_start_time': sessionStartTime,
        'session_end_time': sessionEndTime,
        'session_minutes': sessionMinutes,
        'notes': notes,
        'order_type': 'junior_lesson',
        'order_status': 'confirmed',
        'created_at': DateTime.now().toIso8601String(),
      };

      // branchId가 제공된 경우 추가
      if (branchId != null && branchId.isNotEmpty) {
        lessonData['branch_id'] = branchId;
      }

      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'add',
          'table': 'v2_LS_orders',
          'data': lessonData
        }),
      ).timeout(const Duration(seconds: 30));

      print('🔍 [디버깅] 주니어 레슨 추가 요청 상태: ${response.statusCode}');
      print('🔍 [디버깅] 주니어 레슨 추가 응답 미리보기: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('🔍 [디버깅] 주니어 레슨 추가 응답 파싱 완료: $responseData');
        
        if (responseData['success'] == true) {
          return {
            'success': true,
            'message': '주니어 레슨이 성공적으로 추가되었습니다.',
            'data': responseData['data']
          };
        } else {
          return {
            'success': false,
            'message': responseData['error'] ?? '주니어 레슨 추가에 실패했습니다.'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP 오류: ${response.statusCode}'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': '요청 시간이 초과되었습니다. 네트워크 연결을 확인해주세요.'
      };
    } catch (e) {
      print('❌ 주니어 레슨 추가 중 예외 발생: $e');
      return {
        'success': false,
        'message': '주니어 레슨 추가 중 오류가 발생했습니다: $e'
      };
    }
  }
} 