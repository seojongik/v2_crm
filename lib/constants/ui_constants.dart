import 'package:flutter/material.dart';

/// UI 레이아웃 관련 상수 정의
class UIConstants {
  // 컨테이너 높이
  static const double defaultContainerHeight = 700.0;
  static const double compactContainerHeight = 600.0;
  static const double expandedContainerHeight = 800.0;
  
  // 탭 컨테이너 높이 (각 페이지별 탭 영역)
  static const double tabContainerHeight = 700.0;
  static const double tabContainerHeightCompact = 600.0;
  
  // 패딩
  static const double pagePadding = 24.0;
  static const double cardPadding = 24.0;
  static const double sectionPadding = 16.0;
  
  // 모서리 반경
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double inputBorderRadius = 8.0;
  
  // 그림자
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      blurRadius: 8.0,
      color: Color(0x1A000000),
      offset: Offset(0.0, 2.0),
    )
  ];
  
  // 사이드바 너비
  static const double sidebarWidth = 280.0;
  static const double sidebarCollapsedWidth = 80.0;
  
  // 헤더 높이
  static const double headerHeight = 80.0;
  static const double mobileHeaderHeight = 44.0;
  
  // 버튼 높이
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 40.0;
  static const double buttonHeightLarge = 56.0;
  
  // 입력 필드 높이
  static const double inputFieldHeight = 48.0;
  
  // 간격
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;
  
  // 애니메이션 지속 시간
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);
  
  // 브레이크포인트
  static const double mobileBreakpoint = 480.0;
  static const double tabletBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;
  static const double largeDesktopBreakpoint = 1440.0;
}