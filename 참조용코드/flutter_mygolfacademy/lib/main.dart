import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/screens/login_screen.dart';
import 'package:famd_clientapp/screens/menu_screen.dart';
import 'package:famd_clientapp/screens/password_change_screen.dart';
import 'package:famd_clientapp/providers/notice_provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 한국어 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoticeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: '프렌즈 아카데미 목동',
        theme: ThemeData(
          // 로고 색상에 맞는 테마 색상 설정
          primaryColor: const Color(0xFFFFCC00), // 노란색 (메인)
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFCC00), // 노란색 (메인)
            primary: const Color(0xFFFFCC00), // 노란색 (메인)
            secondary: const Color(0xFFF39C30), // 주황색 (캐릭터)
            background: Colors.white,
            surface: Colors.white,
            error: Colors.red,
            // 다크 테마 색상
            onPrimary: const Color(0xFF3C1F11), // 갈색 (하단 부분)
            onSecondary: Colors.white,
            onBackground: const Color(0xFF3C1F11), // 갈색 (하단 부분)
            onSurface: const Color(0xFF3C1F11), // 갈색 (하단 부분)
            onError: Colors.white,
            brightness: Brightness.light,
          ),
          // 버튼 테마
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00), // 노란색 (메인)
              foregroundColor: const Color(0xFF3C1F11), // 갈색 (하단 부분)
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // 앱바 테마
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF3C1F11), // 갈색 (하단 부분)
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'NotoSansKR',
          // 입력 필드 테마
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFFCC00)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF39C30), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
        home: const ResponsiveLayout(
          mobileBody: SplashScreen(),
          webBody: SplashScreen(),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// 자동로그인 체크를 위한 스플래시 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 빌드 완료 후에 자동로그인 체크 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  Future<void> _checkAutoLogin() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // 저장된 사용자 정보 로드 시도
    await userProvider.init();
    
    if (!mounted) return;
    
    // 사용자 정보가 있으면 메뉴 화면으로, 없으면 로그인 화면으로
    if (userProvider.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MenuScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3C1F11), // 갈색 배경
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/logo_backup.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              '프렌즈아카데미 목동프리미엄점',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Color(0xFFFFCC00), // 노란색 로딩 인디케이터
            ),
          ],
        ),
      ),
    );
  }
}

// 반응형 레이아웃을 위한 클래스
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget webBody;

  const ResponsiveLayout({
    Key? key,
    required this.mobileBody,
    required this.webBody,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // 모바일 화면
          return mobileBody;
        } else {
          // 태블릿 또는 웹 화면
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: webBody,
            ),
          );
        }
      },
    );
  }
} 