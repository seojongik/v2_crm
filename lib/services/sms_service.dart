import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_adapter.dart';

/// CRM용 SMS 서비스 (카페24 프록시 경유)
class SmsService {
  // 카페24 프록시 URL
  static const String _cafe24BaseUrl = 'https://golfcrm.mycafe24.com/sms';
  static const String _proxySecret = 'golfcrm_aligo_2024!';
  
  static String get _sendSmsUrl => '$_cafe24BaseUrl/send_sms.php';
  
  /// 전화번호 포맷 정리 (010-1234-5678 형태로 통일)
  static String formatPhoneNumber(String phoneNumber) {
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digits.startsWith('82') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('10') && digits.length == 10) {
      digits = '0$digits';
    }
    
    if (digits.length == 11 && digits.startsWith('010')) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    
    return phoneNumber;
  }
  
  /// 앱 URL 조회 (Supabase app_urls 테이블에서 - 전역 테이블이라 branch_id 필터 없음)
  static Future<Map<String, String>> getAppUrls(String appName) async {
    try {
      // app_urls는 전역 테이블이라 SupabaseAdapter 직접 사용 (branch_id 필터 제외)
      final client = SupabaseAdapter.client;
      final response = await client
          .from('app_urls')
          .select('platform, url')
          .eq('app_name', appName)
          .eq('is_active', true);
      
      Map<String, String> urls = {};
      for (var row in (response as List)) {
        final platform = row['platform']?.toString() ?? '';
        final url = row['url']?.toString() ?? '';
        if (platform.isNotEmpty && url.isNotEmpty) {
          urls[platform] = url;
        }
      }
      
      print('📱 앱 URL 조회 성공: $urls');
      return urls;
    } catch (e) {
      print('❌ 앱 URL 조회 실패: $e');
      return {};
    }
  }
  
  /// 앱 설치 안내 SMS 발송
  static Future<Map<String, dynamic>> sendAppInstallSms({
    required String phoneNumber,
    required String memberName,
    String appName = 'crm_lite_pro',
  }) async {
    try {
      print('📱 앱 설치 안내 SMS 발송 시작');
      print('   - 수신자: $memberName ($phoneNumber)');
      print('   - 앱: $appName');
      
      // 전화번호 포맷 정리
      final formattedPhone = formatPhoneNumber(phoneNumber);
      
      // 앱 URL 조회
      final appUrls = await getAppUrls(appName);
      
      if (appUrls.isEmpty) {
        return {
          'success': false,
          'error': '앱 URL 정보를 찾을 수 없습니다.',
        };
      }
      
      // 메시지 생성
      String message = _buildInstallMessage(
        memberName: memberName,
        androidUrl: appUrls['android'],
        iosUrl: appUrls['ios'],
      );
      
      print('📝 발송 메시지:\n$message');
      
      // 카페24 프록시로 SMS 발송 요청
      final response = await http.post(
        Uri.parse(_sendSmsUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Secret': _proxySecret,
        },
        body: jsonEncode({
          'phone': formattedPhone,
          'message': message,
          'msg_type': 'LMS', // 긴 문자 (장문)
        }),
      );
      
      final result = jsonDecode(response.body);
      print('📥 SMS 발송 응답: $result');
      
      if (result['success'] == true) {
        // SMS 발송 성공 시 전화번호 인증 정보 초기화 (재인증 요구)
        await resetPhoneAuth(formattedPhone);
        
        return {
          'success': true,
          'message': '앱 설치 안내 문자가 발송되었습니다.',
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'SMS 발송에 실패했습니다.',
        };
      }
      
    } catch (e) {
      print('❌ SMS 발송 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// 앱 설치 안내 메시지 생성
  static String _buildInstallMessage({
    required String memberName,
    String? androidUrl,
    String? iosUrl,
  }) {
    StringBuffer sb = StringBuffer();
    
    sb.writeln('[AutoGolf CRM] 앱 설치 안내');
    sb.writeln('');
    sb.writeln('$memberName 회원님, 환영합니다!');
    sb.writeln('');
    sb.writeln('레슨 예약 및 일정 관리를 위해');
    sb.writeln('앱을 설치해 주세요.');
    sb.writeln('');
    sb.writeln('※ 초기 비밀번호: 휴대폰 번호 뒤 4자리');
    sb.writeln('');
    
    if (iosUrl != null && iosUrl.isNotEmpty) {
      sb.writeln('▶ iOS(아이폰)');
      sb.writeln(iosUrl);
      sb.writeln('');
    }
    
    if (androidUrl != null && androidUrl.isNotEmpty) {
      sb.writeln('▶ Android(안드로이드)');
      sb.writeln(androidUrl);
      sb.writeln('');
    }
    
    sb.writeln('문의: enables.tech@gmail.com');
    
    return sb.toString().trim();
  }
  
  /// 전화번호 인증 정보 초기화 (v3_members 테이블)
  /// 앱 설치 안내 발송 후 재인증을 요구하기 위해 사용
  static Future<void> resetPhoneAuth(String phoneNumber) async {
    try {
      final formattedPhone = formatPhoneNumber(phoneNumber);
      
      final client = SupabaseAdapter.client;
      await client
          .from('v3_members')
          .update({
            'member_phone_auth': null,
            'member_phone_auth_timestamp': null,
          })
          .eq('member_phone', formattedPhone);
      
      print('🔓 전화번호 인증 정보 초기화 완료: $formattedPhone');
    } catch (e) {
      print('❌ 전화번호 인증 정보 초기화 실패: $e');
      // 실패해도 SMS 발송은 성공으로 처리 (인증 초기화는 부가 기능)
    }
  }

  /// 일반 SMS 발송
  static Future<Map<String, dynamic>> sendSms({
    required String phoneNumber,
    required String message,
    String msgType = 'SMS', // SMS, LMS, MMS
  }) async {
    try {
      final formattedPhone = formatPhoneNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse(_sendSmsUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Secret': _proxySecret,
        },
        body: jsonEncode({
          'phone': formattedPhone,
          'message': message,
          'msg_type': msgType,
        }),
      );
      
      final result = jsonDecode(response.body);
      
      if (result['success'] == true) {
        return {
          'success': true,
          'message': '문자가 발송되었습니다.',
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'SMS 발송에 실패했습니다.',
        };
      }
      
    } catch (e) {
      print('❌ SMS 발송 오류: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

