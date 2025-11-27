import 'package:flutter/material.dart';
import '/constants/font_sizes.dart';

/// 상단 탭 디자인 컴포넌트
///
/// 다양한 색상 테마와 사이즈를 제공하는 탭바 디자인
/// - 색상: 1~5번 테마 (무채색 계열)
/// - 사이즈: small, medium, large
class TabDesignUpper {
  // ========== 색상 테마 ==========

  /// 색상 테마 1: 시안색 (기본)
  static const _ColorTheme theme1 = _ColorTheme(
    activeColor: Color(0xFF06B6D4),
    inactiveColor: Color(0xFF64748B),
    indicatorColor: Color(0xFF06B6D4),
    gradientStartColor: Color(0xFFF8FAFC),
    gradientEndColor: Color(0xFFF1F5F9),
  );

  /// 색상 테마 2: 다크 그레이
  static const _ColorTheme theme2 = _ColorTheme(
    activeColor: Color(0xFF1E293B),
    inactiveColor: Color(0xFF94A3B8),
    indicatorColor: Color(0xFF334155),
    gradientStartColor: Color(0xFFF8FAFC),
    gradientEndColor: Color(0xFFF1F5F9),
  );

  /// 색상 테마 3: 네이비 블루
  static const _ColorTheme theme3 = _ColorTheme(
    activeColor: Color(0xFF1E40AF),
    inactiveColor: Color(0xFF64748B),
    indicatorColor: Color(0xFF3B82F6),
    gradientStartColor: Color(0xFFF8FAFC),
    gradientEndColor: Color(0xFFEFF6FF),
  );

  /// 색상 테마 4: 슬레이트 그레이
  static const _ColorTheme theme4 = _ColorTheme(
    activeColor: Color(0xFF475569),
    inactiveColor: Color(0xFF94A3B8),
    indicatorColor: Color(0xFF64748B),
    gradientStartColor: Color(0xFFFAFAFA),
    gradientEndColor: Color(0xFFF1F5F9),
  );

  /// 색상 테마 5: 라이트 그레이
  static const _ColorTheme theme5 = _ColorTheme(
    activeColor: Color(0xFF0F172A),
    inactiveColor: Color(0xFFCBD5E1),
    indicatorColor: Color(0xFF475569),
    gradientStartColor: Color(0xFFFFFFFF),
    gradientEndColor: Color(0xFFF8FAFC),
  );

  // ========== 사이즈 설정 ==========

  /// 사이즈 설정: 작은 크기
  static const _SizeConfig sizeSmall = _SizeConfig(
    iconSize: 14.0,
    fontSize: 12.0,
    indicatorWeight: 2.0,
    horizontalPadding: 12.0,
    gap: 4.0,
  );

  /// 사이즈 설정: 중간 크기 (기본)
  static const _SizeConfig sizeMedium = _SizeConfig(
    iconSize: 16.0,
    fontSize: 14.0,
    indicatorWeight: 3.0,
    horizontalPadding: 16.0,
    gap: 6.0,
  );

  /// 사이즈 설정: 큰 크기
  static const _SizeConfig sizeLarge = _SizeConfig(
    iconSize: 18.0,
    fontSize: 16.0,
    indicatorWeight: 3.5,
    horizontalPadding: 20.0,
    gap: 8.0,
  );

  // ========== 테마 및 사이즈 매핑 ==========

  static _ColorTheme _getColorTheme(int themeNumber) {
    switch (themeNumber) {
      case 1: return theme1;
      case 2: return theme2;
      case 3: return theme3;
      case 4: return theme4;
      case 5: return theme5;
      default: return theme1;
    }
  }

  static _SizeConfig _getSizeConfig(String size) {
    switch (size.toLowerCase()) {
      case 'small': return sizeSmall;
      case 'medium': return sizeMedium;
      case 'large': return sizeLarge;
      default: return sizeMedium;
    }
  }

  // ========== 위젯 빌더 메서드 ==========

  /// 스타일이 적용된 TabBar를 감싸는 Container를 반환
  ///
  /// [child]: TabBar 위젯
  /// [themeNumber]: 색상 테마 번호 (1~5, 기본값: 1)
  /// [hasTopRadius]: 상단 모서리 둥글게 처리 여부 (기본값: true)
  static Widget buildTabBarContainer({
    required Widget child,
    int themeNumber = 1,
    bool hasTopRadius = true,
  }) {
    final theme = _getColorTheme(themeNumber);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.gradientStartColor, theme.gradientEndColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: hasTopRadius
            ? BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              )
            : null,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  /// 스타일이 적용된 TabBar 위젯을 생성
  ///
  /// [controller]: TabController
  /// [tabs]: Tab 위젯 리스트
  /// [themeNumber]: 색상 테마 번호 (1~5, 기본값: 1)
  /// [size]: 사이즈 ('small', 'medium', 'large', 기본값: 'medium')
  /// [isScrollable]: 스크롤 가능 여부 (기본값: true)
  static TabBar buildStyledTabBar({
    required TabController controller,
    required List<Widget> tabs,
    int themeNumber = 1,
    String size = 'medium',
    bool isScrollable = true,
  }) {
    final theme = _getColorTheme(themeNumber);
    final sizeConfig = _getSizeConfig(size);

    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      labelColor: theme.activeColor,
      unselectedLabelColor: theme.inactiveColor,
      indicatorColor: theme.indicatorColor,
      indicatorWeight: sizeConfig.indicatorWeight,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: sizeConfig.fontSize,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: sizeConfig.fontSize,
        fontWeight: FontWeight.w500,
      ),
      padding: EdgeInsets.zero,
      labelPadding: EdgeInsets.only(left: sizeConfig.horizontalPadding, right: sizeConfig.horizontalPadding),
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      tabs: tabs,
    );
  }

  /// 아이콘과 텍스트를 포함한 탭 아이템 생성
  ///
  /// [icon]: 탭에 표시할 아이콘
  /// [text]: 탭에 표시할 텍스트
  /// [size]: 사이즈 ('small', 'medium', 'large', 기본값: 'medium')
  static Tab buildTabItem(IconData icon, String text, {String size = 'medium'}) {
    final sizeConfig = _getSizeConfig(size);

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizeConfig.iconSize),
          SizedBox(width: sizeConfig.gap),
          Text(text),
        ],
      ),
    );
  }

  /// 완성된 탭바 (Container + TabBar) 반환
  ///
  /// [controller]: TabController
  /// [tabs]: Tab 위젯 리스트
  /// [themeNumber]: 색상 테마 번호 (1~5, 기본값: 1)
  /// [size]: 사이즈 ('small', 'medium', 'large', 기본값: 'medium')
  /// [isScrollable]: 스크롤 가능 여부 (기본값: true)
  /// [hasTopRadius]: 상단 모서리 둥글게 처리 여부 (기본값: true)
  static Widget buildCompleteTabBar({
    required TabController controller,
    required List<Widget> tabs,
    int themeNumber = 1,
    String size = 'medium',
    bool isScrollable = true,
    bool hasTopRadius = true,
  }) {
    return buildTabBarContainer(
      themeNumber: themeNumber,
      hasTopRadius: hasTopRadius,
      child: buildStyledTabBar(
        controller: controller,
        tabs: tabs,
        themeNumber: themeNumber,
        size: size,
        isScrollable: isScrollable,
      ),
    );
  }
}

// ========== 내부 클래스 ==========

/// 색상 테마 설정
class _ColorTheme {
  final Color activeColor;
  final Color inactiveColor;
  final Color indicatorColor;
  final Color gradientStartColor;
  final Color gradientEndColor;

  const _ColorTheme({
    required this.activeColor,
    required this.inactiveColor,
    required this.indicatorColor,
    required this.gradientStartColor,
    required this.gradientEndColor,
  });
}

/// 사이즈 설정
class _SizeConfig {
  final double iconSize;
  final double fontSize;
  final double indicatorWeight;
  final double horizontalPadding;
  final double gap;

  const _SizeConfig({
    required this.iconSize,
    required this.fontSize,
    required this.indicatorWeight,
    required this.horizontalPadding,
    required this.gap,
  });
}
