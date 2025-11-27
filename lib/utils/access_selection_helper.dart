import 'package:shared_preferences/shared_preferences.dart';

/// 접속 선택 페이지 표시 여부를 관리하는 헬퍼 클래스
class AccessSelectionHelper {
  /// 사용자가 '다시 보지 않기' 설정했는지 확인
  static Future<bool> shouldShowAccessSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('dontShowAccessSelection') ?? false);
  }

  /// '다시 보지 않기' 설정 저장
  static Future<void> saveDontShowAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dontShowAccessSelection', true);
  }

  /// 설정 초기화 (필요한 경우)
  static Future<void> resetDontShowAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dontShowAccessSelection');
  }
}


