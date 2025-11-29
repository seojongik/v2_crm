import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 설정 파일 관리 서비스
/// 각 프로젝트의 독립성을 유지하면서 설정 파일을 읽습니다.
class ConfigService {
  static Map<String, dynamic>? _config;
  static bool _initialized = false;
  
  /// 설정 파일 경로 (프로젝트 루트 기준)
  static String get _configPath => 'config.json';
  
  /// 설정 초기화
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final configFile = File(_configPath);
      
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        _config = json.decode(content) as Map<String, dynamic>;
        print('✅ [ConfigService] 설정 파일 로드 성공: $_configPath');
      } else {
        print('⚠️ [ConfigService] 설정 파일 없음: $_configPath - 기본값 사용');
        _config = null;
      }
    } catch (e) {
      print('⚠️ [ConfigService] 설정 파일 읽기 오류: $e - 기본값 사용');
      _config = null;
    }
    
    _initialized = true;
  }
  
  /// SMTP 설정 가져오기
  static Map<String, dynamic> getSmtpConfig() {
    if (_config != null && _config!['smtp'] != null) {
      return Map<String, dynamic>.from(_config!['smtp'] as Map);
    }
    // 기본값 (하위 호환성)
    return {
      'host': 'smtp.gmail.com',
      'port': 587,
      'username': 'auto.enables@gmail.com',
      'password': 'a131150*',
    };
  }
  
  /// Supabase 설정 가져오기
  static Map<String, dynamic> getSupabaseConfig() {
    if (_config != null && _config!['supabase'] != null) {
      return Map<String, dynamic>.from(_config!['supabase'] as Map);
    }
    // 기본값 (하위 호환성)
    return {
      'url': 'https://yejialakeivdhwntmagf.supabase.co',
      'anonKey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllamlhbGFrZWl2ZGh3bnRtYWdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5MTE0MjcsImV4cCI6MjA3OTQ4NzQyN30.a1WA6V7pD2tss1pkh1OSJcuknt6FTyeabvm9UzNjcfs',
    };
  }
}

