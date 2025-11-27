import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/access_selection_helper.dart';

class AccessSelectionPage extends StatefulWidget {
  const AccessSelectionPage({Key? key}) : super(key: key);

  @override
  State<AccessSelectionPage> createState() => _AccessSelectionPageState();
}

class _AccessSelectionPageState extends State<AccessSelectionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _dontShowAgain = false;

  // 랜딩 페이지 URL (실제 배포 시 변경)
  static const String LANDING_PAGE_URL = 'https://seojongik.github.io/crm_landing_page';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveDontShowAgainPreference() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dontShowAccessSelection', true);
    }
  }

  Future<void> _openLandingPage() async {
    final uri = Uri.parse(LANDING_PAGE_URL);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('랜딩 페이지를 열 수 없습니다.')),
        );
      }
    }
  }

  void _goToCRM() async {
    await _saveDontShowAgainPreference();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _viewLandingAndContinue() async {
    await _openLandingPage();
    // 랜딩 페이지를 보여준 후에도 계속 진행
    await Future.delayed(const Duration(seconds: 1));
    _goToCRM();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2c5f2d),
              Color(0xFF4a8f4d),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 로고/아이콘
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.golf_course,
                          size: 60,
                          color: Color(0xFF2c5f2d),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 타이틀
                      Text(
                        'AutoGolf CRM',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 서브타이틀
                      Text(
                        '골프장 통합 관리 시스템',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 60),

                      // 선택 카드
                      Container(
                        constraints: BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 30,
                              offset: Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              '어떻게 시작하시겠습니까?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2c5f2d),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // CRM 바로 접속 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _goToCRM,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF2c5f2d),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'CRM 바로 접속',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 랜딩 페이지 보기 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _viewLandingAndContinue,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFF2c5f2d),
                                  side: BorderSide(
                                    color: Color(0xFF2c5f2d),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      '소개 페이지 보기',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 다시 보지 않기 체크박스
                            Row(
                              children: [
                                Checkbox(
                                  value: _dontShowAgain,
                                  onChanged: (value) {
                                    setState(() {
                                      _dontShowAgain = value ?? false;
                                    });
                                  },
                                  activeColor: Color(0xFF2c5f2d),
                                ),
                                Expanded(
                                  child: Text(
                                    '다음부터 이 화면 표시하지 않기',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 푸터 정보
                      Text(
                        '© 2025 AutoGolf CRM',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 정적 메서드: 사용자가 '다시 보지 않기' 설정했는지 확인
  // (하위 호환성을 위해 유지, 내부적으로 헬퍼 사용)
  static Future<bool> shouldShowAccessSelection() async {
    return AccessSelectionHelper.shouldShowAccessSelection();
  }

  // 정적 메서드: 설정 초기화 (필요한 경우)
  // (하위 호환성을 위해 유지, 내부적으로 헬퍼 사용)
  static Future<void> resetDontShowAgain() async {
    return AccessSelectionHelper.resetDontShowAgain();
  }
}

