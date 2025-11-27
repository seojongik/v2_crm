import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../widgets/common_widgets.dart';
import '../pages/login_by_admin.dart';
import 'api_service.dart';

import '../constants/font_sizes.dart';
class FloatingReservationButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final double? iconSize;
  final double? elevation;
  final bool isAdminMode; // 관리자 모드 여부

  const FloatingReservationButton({
    Key? key,
    this.backgroundColor,
    this.iconColor,
    this.size,
    this.iconSize,
    this.elevation,
    this.isAdminMode = true, // CRM에서 접근할 때는 기본적으로 관리자 모드
  }) : super(key: key);

  void _openReservationSystem(BuildContext context) {
    // 관리자 모드로 골프플래너 앱 열기
    FloatingReservationHelper.navigateToReservationSystemAsAdmin(context);
  }

  @override
  Widget build(BuildContext context) {
    final defaultSize = size ?? 70.0;
    final defaultIconSize = iconSize ?? 36.0;
    final defaultElevation = elevation ?? 12.0;
    
    return SizedBox(
      width: defaultSize,
      height: defaultSize,
      child: FloatingActionButton(
        onPressed: () => _openReservationSystem(context),
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
        child: Icon(
          Icons.phone_android,
          color: iconColor ?? Colors.white,
          size: defaultIconSize,
        ),
        elevation: defaultElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultSize / 2),
        ),
        tooltip: isAdminMode ? '골프 플래너 앱 (관리자)' : '골프 플래너 앱',
        heroTag: "reservation_floating_button",
      ),
    );
  }
}

/// 플로팅 버튼 헬퍼 함수들
class FloatingReservationHelper {
  /// URL 생성 헬퍼
  static String _getMyxplannerAppUrl(String path) {
    final currentUrl = html.window.location.href;
    final uri = Uri.parse(currentUrl);
    final baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$baseUrl/myxplanner_app/#$path';
  }

  /// 고객용: 예약 시스템으로 이동 (로그인 페이지부터)
  static void navigateToReservationSystemAsCustomer(BuildContext context) {
    final url = _getMyxplannerAppUrl('/login');
    html.window.open(url, '_blank', 'width=1400,height=900,scrollbars=yes,resizable=yes');
  }

  /// 관리자용: 예약 시스템으로 이동 (관리자 로그인 페이지)
  static void navigateToReservationSystemAsAdmin(BuildContext context) {
    final url = _getMyxplannerAppUrl('/admin-login');
    print('🚀 골프플래너 앱 열기 (관리자): $url');
    html.window.open(url, '_blank', 'width=1400,height=900,scrollbars=yes,resizable=yes');
  }

  /// 예약 시스템으로 교체하는 함수 (현재 화면을 대체)
  static void replaceWithReservationSystem(BuildContext context, {bool isAdminMode = true}) {
    final path = isAdminMode ? '/admin-login' : '/login';
    final url = _getMyxplannerAppUrl(path);
    html.window.location.href = url;
  }

  /// 예약 시스템을 새로운 스택으로 열기
  static void openReservationSystemAsNewStack(BuildContext context, {bool isAdminMode = true}) {
    final path = isAdminMode ? '/admin-login' : '/login';
    final url = _getMyxplannerAppUrl(path);
    html.window.open(url, '_blank', 'width=1400,height=900,scrollbars=yes,resizable=yes');
  }

  /// 특정 회원으로 바로 접근하는 함수 (관리자용)
  static void navigateToMemberPageDirectly(
    BuildContext context, {
    required Map<String, dynamic> memberData,
    required String branchId,
  }) {
    final memberId = memberData['member_id']?.toString() ?? '';
    if (memberId.isEmpty) {
      print('❌ 회원 ID가 없습니다.');
      return;
    }

    final url = _getMyxplannerAppUrl('/crm-member?branchId=$branchId&memberId=$memberId&isAdminMode=true');
    print('🚀 골프플래너 앱 열기 (회원 직접): $url');
    print('   회원: ${memberData['member_name']} (ID: $memberId)');
    print('   지점: $branchId');

    html.window.open(url, '_blank', 'width=1400,height=900,scrollbars=yes,resizable=yes');
  }
}

/// 커스텀 플로팅 버튼 스타일들
class FloatingReservationStyles {
  /// 관리자용 기본 스타일
  static Widget adminStyle(BuildContext context) {
    return const FloatingReservationButton(isAdminMode: true);
  }

  /// 고객용 기본 스타일
  static Widget customerStyle(BuildContext context) {
    return const FloatingReservationButton(isAdminMode: false);
  }

  /// 큰 사이즈 스타일 (관리자용)
  static Widget largeAdminStyle(BuildContext context) {
    return const FloatingReservationButton(
      size: 80.0,
      iconSize: 40.0,
      elevation: 16.0,
      isAdminMode: true,
    );
  }

  /// 작은 사이즈 스타일 (관리자용)
  static Widget smallAdminStyle(BuildContext context) {
    return const FloatingReservationButton(
      size: 56.0,
      iconSize: 28.0,
      elevation: 8.0,
      isAdminMode: true,
    );
  }

  /// 커스텀 색상 스타일
  static Widget customColorStyle(BuildContext context, {
    required Color backgroundColor,
    required Color iconColor,
    bool isAdminMode = true,
  }) {
    return FloatingReservationButton(
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      isAdminMode: isAdminMode,
    );
  }

  /// 그라데이션 스타일 (Container로 래핑)
  static Widget gradientStyle(BuildContext context, {bool isAdminMode = true}) {
    return Container(
      width: 70.0,
      height: 70.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(35.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(35.0),
          onTap: () => isAdminMode
            ? FloatingReservationHelper.navigateToReservationSystemAsAdmin(context)
            : FloatingReservationHelper.navigateToReservationSystemAsCustomer(context),
          child: const Center(
            child: Icon(
              Icons.phone_android,
              color: Colors.white,
              size: 36.0,
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingReservationService {
  /// 골프 플래너 앱에 관리자 모드로 접근하는 메서드
  /// CRM에서 현재 로그인된 관리자의 브랜치 ID를 전달받아 사용
  static void accessAsAdmin(BuildContext context) {
    FloatingReservationHelper.navigateToReservationSystemAsAdmin(context);
  }
} 