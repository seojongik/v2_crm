import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../pages/login/login_widget.dart';

class SessionManager {
  static SessionManager? _instance;
  static SessionManager get instance => _instance ??= SessionManager._internal();

  SessionManager._internal();

  Timer? _sessionTimer;
  DateTime? _lastActivity;
  final int _sessionTimeoutMinutes = 20;
  bool _warningShown = false;

  // 타이머 스트림 컨트롤러
  StreamController<String>? _timerStreamController;
  Stream<String> get timerStream {
    _timerStreamController ??= StreamController<String>.broadcast();
    return _timerStreamController!.stream;
  }

  // 현재 컨텍스트를 저장하기 위한 GlobalKey
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 세션 시작
  void startSession() {
    _lastActivity = DateTime.now();
    _startTimer();
    print('🔐 세션 시작 - 20분 후 자동 로그아웃');
  }

  // 활동 갱신 (모든 user action에서 호출)
  void updateActivity() {
    _lastActivity = DateTime.now();
    _warningShown = false; // 활동 갱신 시 경고 리셋
    print('🔄 활동 갱신 - ${_lastActivity!.toIso8601String()}');
  }

  // 세션 종료
  void endSession() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _lastActivity = null;
    _timerStreamController?.close();
    _timerStreamController = null;
    print('🔐 세션 종료');
  }

  // 타이머 시작
  void _startTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _checkSession();
      // 타이머 스트림 업데이트
      _timerStreamController ??= StreamController<String>.broadcast();
      _timerStreamController!.add(remainingTimeFormatted);
    });
  }

  // 세션 유효성 검사
  void _checkSession() {
    if (_lastActivity == null) return;

    final now = DateTime.now();
    final timeDifference = now.difference(_lastActivity!);

    // 1분 전 경고
    if (timeDifference.inMinutes >= (_sessionTimeoutMinutes - 1) &&
        timeDifference.inMinutes < _sessionTimeoutMinutes &&
        !_warningShown) {
      _warningShown = true;
      print('⚠️ 세션 만료 1분 전 경고');
      _showWarningDialog();
    }
    // 세션 만료
    else if (timeDifference.inMinutes >= _sessionTimeoutMinutes) {
      print('⏰ 세션 만료 - 자동 로그아웃 실행');
      _performAutoLogout();
    }
  }

  // 자동 로그아웃 실행
  void _performAutoLogout() {
    _sessionTimer?.cancel();

    // 전역 상태 초기화
    ApiService.logout();

    // 로그인 페이지로 이동
    final context = navigatorKey.currentContext;
    if (context != null) {
      _showLogoutDialog(context);
    }
  }

  // 경고 다이얼로그 표시 (1분 전)
  void _showWarningDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('세션 만료 경고'),
            ],
          ),
          content: Text('1분 후 자동 로그아웃됩니다.\n세션을 연장하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 세션 연장 (활동 갱신)
                updateActivity();
                print('✅ 세션 연장됨');
              },
              child: Text('연장'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 즉시 로그아웃
                _performAutoLogout();
              },
              child: Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

  // 로그아웃 다이얼로그 표시
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.timer_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('세션 만료'),
            ],
          ),
          content: Text('20분간 활동이 없어 자동 로그아웃되었습니다.\n다시 로그인해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginWidget()),
                  (route) => false,
                );
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }


  // 세션 상태 확인
  bool get isSessionActive => _lastActivity != null;

  // 남은 시간 계산 (초 단위)
  int get remainingSeconds {
    if (_lastActivity == null) return 0;
    final elapsed = DateTime.now().difference(_lastActivity!).inSeconds;
    final totalSeconds = _sessionTimeoutMinutes * 60;
    return (totalSeconds - elapsed).clamp(0, totalSeconds);
  }

  // 남은 시간을 MM:SS 형태로 포맷
  String get remainingTimeFormatted {
    final seconds = remainingSeconds;
    final minutes = seconds ~/ 60;
    final remainingSecondsInMinute = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecondsInMinute.toString().padLeft(2, '0')}';
  }
}