import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'config_service.dart';

class EmailService {
  // SMTP 서버 설정 (설정 파일에서 읽기)
  static String get _smtpHost {
    final config = ConfigService.getSmtpConfig();
    return config['host'] as String? ?? 'smtp.gmail.com';
  }
  
  static int get _smtpPort {
    final config = ConfigService.getSmtpConfig();
    return config['port'] as int? ?? 587;
  }
  
  static String get _username {
    final config = ConfigService.getSmtpConfig();
    return config['username'] as String? ?? 'auto.enables@gmail.com';
  }
  
  static String get _password {
    final config = ConfigService.getSmtpConfig();
    return config['password'] as String? ?? 'a131150*';
  }
  
  // 실제 이메일 발송 서비스 설정 (API 방식)
  static const String _emailEndpoint = 'https://your-email-api.com/send';
  static const String _apiKey = 'your-email-api-key';

  // SMTP를 통한 실제 이메일 발송
  static Future<void> sendSalaryEmailViaSmtp({
    required String to,
    required String subject,
    required String content,
  }) async {
    try {
      // Gmail SMTP 서버 설정
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _username,
        password: _password,
        allowInsecure: false,
        ssl: false,
      );

      // 메시지 생성
      final message = Message()
        ..from = Address(_username, '급여관리시스템')
        ..recipients.add(to)
        ..subject = subject
        ..html = _convertToHtml(content)
        ..text = content;

      // 이메일 발송
      final sendReport = await send(message, smtpServer);
      print('이메일 발송 성공: ${sendReport.toString()}');
      
    } catch (e) {
      print('SMTP 이메일 발송 오류: $e');
      
      // SMTP 실패시 개발 모드로 폴백
      print('=== SMTP 실패, 개발 모드로 출력 ===');
      print('To: $to');
      print('Subject: $subject');
      print('Content:\n$content');
      print('================================');
      
      // 실제 운영에서는 예외를 다시 throw할 수 있음
      // throw e;
    }
  }

  static Future<void> sendSalaryEmail({
    required String to,
    required String subject,
    required String content,
  }) async {
    // 개발 환경에서는 실제 발송 대신 시뮬레이션
    try {
      print('📧 [이메일 발송 시뮬레이션]');
      print('받는이: $to');
      print('제목: $subject');
      print('발송자: $_username');
      print('상태: 발송 완료 (시뮬레이션)');
      print('='*50);
      print('내용:');
      print(content);
      print('='*50);
      
      // 실제 발송하려면 아래 주석을 해제하세요
      // await sendSalaryEmailViaSmtp(
      //   to: to,
      //   subject: subject,
      //   content: content,
      // );
      
      // 발송 완료를 시뮬레이션하기 위한 딜레이
      await Future.delayed(Duration(seconds: 1));
      
    } catch (e) {
      print('이메일 발송 오류: $e');
      rethrow;
    }
  }

  static String _convertToHtml(String content) {
    // 텍스트 콘텐츠를 HTML로 변환
    return '''
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 800px; margin: 0 auto; padding: 20px; }
            .header { background-color: #f4f4f4; padding: 20px; text-align: center; }
            .content { padding: 20px; }
            .employee-info { 
                background-color: #f9f9f9; 
                padding: 15px; 
                margin: 10px 0; 
                border-left: 4px solid #007bff; 
            }
            .link { 
                display: inline-block; 
                padding: 8px 16px; 
                background-color: #007bff; 
                color: white; 
                text-decoration: none; 
                border-radius: 4px; 
                margin: 5px 0;
            }
            .summary { 
                background-color: #e9ecef; 
                padding: 15px; 
                margin: 20px 0; 
                border-radius: 4px; 
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>급여 공제 요청</h2>
            </div>
            <div class="content">
                ${_formatContentToHtml(content)}
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  static String _formatContentToHtml(String content) {
    // 단순한 텍스트를 HTML로 포맷팅
    final lines = content.split('\n');
    final buffer = StringBuffer();
    bool inEmployeeSection = false;
    bool inSummarySection = false;
    
    for (String line in lines) {
      if (line.contains('님께,') || line.contains('세무사님께')) {
        buffer.writeln('<p><strong>$line</strong></p>');
      } else if (line.contains('--- 요약 ---')) {
        inSummarySection = true;
        buffer.writeln('<div class="summary">');
        buffer.writeln('<h3>요약</h3>');
      } else if (line.contains('(강사)') || line.contains('(매니저)')) {
        if (inEmployeeSection) {
          buffer.writeln('</div>');
        }
        inEmployeeSection = true;
        buffer.writeln('<div class="employee-info">');
        buffer.writeln('<h4>$line</h4>');
      } else if (line.contains('공제입력 링크:')) {
        final linkUrl = line.substring(line.indexOf('https://'));
        buffer.writeln('<a href="$linkUrl" class="link">공제금액 입력하기</a>');
      } else if (line.trim().isEmpty) {
        if (inEmployeeSection) {
          buffer.writeln('</div>');
          inEmployeeSection = false;
        }
        buffer.writeln('<br>');
      } else if (inSummarySection) {
        buffer.writeln('<p>$line</p>');
      } else {
        buffer.writeln('<p>$line</p>');
      }
    }
    
    if (inEmployeeSection) {
      buffer.writeln('</div>');
    }
    if (inSummarySection) {
      buffer.writeln('</div>');
    }
    
    return buffer.toString();
  }

  // 테스트용 이메일 발송 (개발 환경)
  static Future<void> sendTestEmail({
    required String to,
    required String subject,
    required String content,
  }) async {
    print('=== 테스트 이메일 발송 ===');
    print('To: $to');
    print('Subject: $subject');
    print('Content:\n$content');
    print('=======================');
    
    // 실제로는 이메일을 발송하지 않고 콘솔에만 출력
    await Future.delayed(Duration(seconds: 1)); // 네트워크 지연 시뮬레이션
  }
}