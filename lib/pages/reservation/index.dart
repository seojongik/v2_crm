// ========== FACRM 피트니스 관리 시스템 ==========
// 버전: 2.0.0
// 설명: 피트니스 센터 예약 관리 시스템

// FACRM 피트니스 관리 시스템 Exports
// 예약 시스템 모듈의 모든 페이지와 위젯을 여기서 export합니다.

// 메인 페이지들
export 'login_page.dart';
export 'main_page.dart';
export 'login_by_admin.dart';

// 추후 추가될 페이지들
// export 'reservation_form_page.dart';
// export 'reservation_list_page.dart';
// export 'membership_page.dart';
// export 'account_page.dart';

// 모델 및 서비스 (추후 추가)
// export 'models/user_model.dart';
// export 'models/reservation_model.dart';
// export 'services/auth_service.dart';
// export 'services/reservation_service.dart';

/// FACRM 예약 시스템 사용 예시:
/// 
/// ```dart
/// import 'package:your_app/pages/reservation/index.dart';
/// 
/// // 로그인 페이지로 이동
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => LoginPage(),
///   ),
/// );
/// 
/// // 메인 페이지로 이동
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => MainPage(),
///   ),
/// );
/// ```
/// 
/// 플로팅 버튼은 별도 서비스로 분리되어 있습니다:
/// ```dart
/// import 'package:your_app/services/floating_reservation_service.dart';
/// 
/// // 플로팅 버튼 사용
/// floatingActionButton: FloatingReservationButton(),
/// 
/// // 또는 다양한 스타일 사용
/// floatingActionButton: FloatingReservationStyles.gradientStyle(context),
/// ```

// 모듈 정보
const String appVersion = '1.0.0';
const String appName = 'FACRM';
const String appDescription = '피트니스 관리 시스템';

// 앱 정보를 반환하는 함수
Map<String, String> getAppInfo() {
  return {
    'name': appName,
    'version': appVersion,
    'description': appDescription,
    'author': 'FACRM Team',
    'created': '2025-01-22',
    'updated': '2025-01-22',
  };
}

// ========== 서비스 exports ==========
export 'lib/services/api_service.dart'; 