import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'backend/firebase/firebase_config.dart';
import 'services/chat_notification_service.dart';
import 'services/session_manager.dart';
import 'services/supabase_adapter.dart';
import 'widgets/activity_detector.dart';
import 'pages/access_selection_page.dart';
import 'utils/access_selection_helper.dart';
import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await initFirebase();
  print('🔥 Firebase 초기화 완료');
  
  // Supabase 초기화 (cafe24에서 마이그레이션)
  await SupabaseAdapter.initialize();
  print('🗄️ Supabase 초기화 완료');
  
  await FlutterFlowTheme.initialize();
  
  // 채팅 알림 서비스 초기화
  await ChatNotificationService().initialize();
  print('🔔 채팅 알림 서비스 초기화 완료');
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  bool _showAccessSelection = false;  // CRM만 테스트하므로 false로 설정
  bool _isLoading = false;  // 로딩도 불필요

  String getRoute() => '/login';
  List<String> getRouteStack() => ['/login'];

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  void initState() {
    super.initState();
    // AccessSelectionPage는 사용하지 않으므로 체크 로직 제거
    // _checkAccessSelectionPreference();
  }

  Future<void> _checkAccessSelectionPreference() async {
    // 사용하지 않지만 하위 호환성을 위해 유지
    final shouldShow = await AccessSelectionHelper.shouldShowAccessSelection();
    setState(() {
      _showAccessSelection = shouldShow;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
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
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (context) => ChatNotificationService(),
      child: ActivityDetector(
        child: MaterialApp(
          navigatorKey: SessionManager.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'AutoGolfCRM',
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', '')],
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: false,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: false,
          ),
          themeMode: _themeMode,
          home: _showAccessSelection ? AccessSelectionPage() : LoginWidget(),
          routes: {
            '/login': (context) => LoginWidget(),
          },
        ),
      ),
    );
  }
}

class NavBarPage extends StatefulWidget {
  NavBarPage({
    Key? key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  }) : super(key: key);

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'crm1_board';
  late Widget? _currentPage;
  int? _currentTabIndex;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  void _navigateToPage(String pageName) {
    setState(() {
      // 탭 파라미터 처리
      if (pageName.contains('?tab=')) {
        final parts = pageName.split('?tab=');
        _currentPageName = parts[0];
        final tabIndex = int.tryParse(parts[1]);
        
        // 탭 인덱스가 있는 경우 해당 페이지에 전달
        if (tabIndex != null) {
          _currentTabIndex = tabIndex;
          print('탭 네비게이션: $pageName -> Page: $_currentPageName, Tab Index: $_currentTabIndex');
        }
      } else {
        _currentPageName = pageName;
        _currentTabIndex = null;
      }
      _currentPage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ChatNotificationService에 BuildContext 설정 (스낵바 표시용)
    ChatNotificationService().setContext(context);
    
    final tabs = {
      'crm1_board': Crm1BoardWidget(key: ValueKey('crm1_board'), onNavigate: _navigateToPage),
      'crm2_member': Crm2MemberWidget(
        key: ValueKey('crm2_member_${_currentTabIndex ?? 0}'),
        onNavigate: _navigateToPage, 
        tabIndex: _currentPageName == 'crm2_member' ? _currentTabIndex : null
      ),
      'crm3_ts': Crm3TsWidget(key: ValueKey('crm3_ts'), onNavigate: _navigateToPage),
      'crm4_lesson': Crm4LessonWidget(key: ValueKey('crm4_lesson'), onNavigate: _navigateToPage),
      'crm5_hr': Crm5HrWidget(
        key: ValueKey('crm5_hr_${_currentTabIndex ?? 0}'),
        onNavigate: _navigateToPage, 
        tabIndex: _currentPageName == 'crm5_hr' ? _currentTabIndex : null
      ),
      'crm6_locker': Crm6LockerWidget(key: ValueKey('crm6_locker'), onNavigate: _navigateToPage),
      'crm7_communication': Crm7CommunicationWidget(
        key: ValueKey('crm7_communication_${_currentTabIndex ?? 0}'),
        onNavigate: _navigateToPage, 
        tabIndex: _currentPageName == 'crm7_communication' ? _currentTabIndex : null
      ),
      'crm9_setting': Crm9SettingWidget(
        key: ValueKey('crm9_setting_${_currentTabIndex ?? 0}'),
        onNavigate: _navigateToPage, 
        tabIndex: _currentPageName == 'crm9_setting' ? _currentTabIndex : null
      ),
      'crm10_operation': Crm10OperationWidget(
        key: ValueKey('crm10_operation_${_currentTabIndex ?? 0}'),
        onNavigate: _navigateToPage, 
        tabIndex: _currentPageName == 'crm10_operation' ? _currentTabIndex : null
      ),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    return Scaffold(
      resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
      body: _currentPage ?? tabs[_currentPageName],
      bottomNavigationBar: Visibility(
        visible: responsiveVisibility(
          context: context,
          tabletLandscape: false,
          desktop: false,
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => safeSetState(() {
            _currentPage = null;
            _currentPageName = tabs.keys.toList()[i];
          }),
          backgroundColor: Colors.white,
          selectedItemColor: FlutterFlowTheme.of(context).primary,
          unselectedItemColor: FlutterFlowTheme.of(context).secondaryText,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.school_outlined,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.person_search,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.dashboard_rounded,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.sports_kabaddi,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.location_history_outlined,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.all_inbox_sharp,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.message_rounded,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.domain,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.store_outlined,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.emoji_events_rounded,
                size: 24.0,
              ),
              label: '•',
              tooltip: '',
            )
          ],
        ),
      ),
    );
  }
}
