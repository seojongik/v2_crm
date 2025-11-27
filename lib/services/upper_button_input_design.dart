import 'package:flutter/material.dart';

/// 상단 버튼 및 입력 필드 디자인 컴포넌트
///
/// 다양한 색상 테마와 사이즈를 제공하는 버튼 디자인
/// - 색상: green, cyan, blue, purple, red, orange, gray
/// - 사이즈: medium, large
class ButtonDesignUpper {
  // ========== 색상 테마 ==========

  /// 색상 테마 1: 초록색 (신규등록, 생성 액션)
  static const _ButtonColorTheme themeGreen = _ButtonColorTheme(
    gradientStartColor: Color(0xFF10B981),
    gradientEndColor: Color(0xFF059669),
    shadowColor: Color(0x4010B981),
    textColor: Colors.white,
  );

  /// 색상 테마 2: 청록색 (검색, 조회 액션)
  static const _ButtonColorTheme themeCyan = _ButtonColorTheme(
    gradientStartColor: Color(0xFF06B6D4),
    gradientEndColor: Color(0xFF0891B2),
    shadowColor: Color(0x4006B6D4),
    textColor: Colors.white,
  );

  /// 색상 테마 3: 파란색 (일반 액션, 확인)
  static const _ButtonColorTheme themeBlue = _ButtonColorTheme(
    gradientStartColor: Color(0xFF3B82F6),
    gradientEndColor: Color(0xFF2563EB),
    shadowColor: Color(0x403B82F6),
    textColor: Colors.white,
  );

  /// 색상 테마 4: 보라색 (특별 액션, 프리미엄)
  static const _ButtonColorTheme themePurple = _ButtonColorTheme(
    gradientStartColor: Color(0xFF8B5CF6),
    gradientEndColor: Color(0xFF7C3AED),
    shadowColor: Color(0x408B5CF6),
    textColor: Colors.white,
  );

  /// 색상 테마 5: 빨간색 (삭제, 위험한 액션)
  static const _ButtonColorTheme themeRed = _ButtonColorTheme(
    gradientStartColor: Color(0xFFEF4444),
    gradientEndColor: Color(0xFFDC2626),
    shadowColor: Color(0x40EF4444),
    textColor: Colors.white,
  );

  /// 색상 테마 6: 주황색 (경고, 주의 액션)
  static const _ButtonColorTheme themeOrange = _ButtonColorTheme(
    gradientStartColor: Color(0xFFF97316),
    gradientEndColor: Color(0xFFEA580C),
    shadowColor: Color(0x40F97316),
    textColor: Colors.white,
  );

  /// 색상 테마 7: 회색 (취소, 비활성화)
  static const _ButtonColorTheme themeGray = _ButtonColorTheme(
    gradientStartColor: Color(0xFF64748B),
    gradientEndColor: Color(0xFF475569),
    shadowColor: Color(0x4064748B),
    textColor: Colors.white,
  );

  // ========== 사이즈 설정 ==========

  /// 사이즈 설정: 중간 크기
  static const _ButtonSizeConfig sizeMedium = _ButtonSizeConfig(
    height: 40.0,
    iconSize: 18.0,
    fontSize: 13.0,
    borderRadius: 10.0,
    horizontalPadding: 16.0,
    gap: 6.0,
    shadowBlur: 6.0,
    shadowOffset: Offset(0.0, 3.0),
  );

  /// 사이즈 설정: 큰 크기 (기본)
  static const _ButtonSizeConfig sizeLarge = _ButtonSizeConfig(
    height: 48.0,
    iconSize: 20.0,
    fontSize: 14.0,
    borderRadius: 12.0,
    horizontalPadding: 20.0,
    gap: 8.0,
    shadowBlur: 8.0,
    shadowOffset: Offset(0.0, 4.0),
  );

  // ========== 테마 및 사이즈 매핑 ==========

  static _ButtonColorTheme _getColorTheme(String color) {
    switch (color.toLowerCase()) {
      case 'green':
        return themeGreen;
      case 'cyan':
        return themeCyan;
      case 'blue':
        return themeBlue;
      case 'purple':
        return themePurple;
      case 'red':
        return themeRed;
      case 'orange':
        return themeOrange;
      case 'gray':
        return themeGray;
      default:
        return themeCyan; // 기본값: 청록색
    }
  }

  static _ButtonSizeConfig _getSizeConfig(String size) {
    switch (size.toLowerCase()) {
      case 'medium':
        return sizeMedium;
      case 'large':
        return sizeLarge;
      default:
        return sizeLarge; // 기본값: 큰 크기
    }
  }

  // ========== 위젯 빌더 메서드 ==========

  /// 아이콘과 텍스트가 있는 버튼 생성
  ///
  /// [text]: 버튼에 표시할 텍스트
  /// [icon]: 버튼에 표시할 아이콘
  /// [onPressed]: 버튼 클릭 시 실행할 함수
  /// [color]: 색상 테마 ('green', 'cyan', 'blue', 'purple', 'red', 'orange', 'gray', 기본값: 'cyan')
  /// [size]: 사이즈 ('medium', 'large', 기본값: 'large')
  static Widget buildIconButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    String color = 'cyan',
    String size = 'large',
  }) {
    final theme = _getColorTheme(color);
    final sizeConfig = _getSizeConfig(size);

    return Container(
      height: sizeConfig.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.gradientStartColor, theme.gradientEndColor],
          stops: [0.0, 1.0],
          begin: AlignmentDirectional(0.0, -1.0),
          end: AlignmentDirectional(0, 1.0),
        ),
        borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            blurRadius: sizeConfig.shadowBlur,
            color: theme.shadowColor,
            offset: sizeConfig.shadowOffset,
          )
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: sizeConfig.iconSize,
          color: theme.textColor,
        ),
        label: Text(
          text,
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: theme.textColor,
            fontSize: sizeConfig.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
          ),
          padding: EdgeInsetsDirectional.fromSTEB(
            sizeConfig.horizontalPadding,
            0.0,
            sizeConfig.horizontalPadding,
            0.0,
          ),
        ),
      ),
    );
  }

  /// 텍스트만 있는 버튼 생성
  ///
  /// [text]: 버튼에 표시할 텍스트
  /// [onPressed]: 버튼 클릭 시 실행할 함수
  /// [color]: 색상 테마 ('green', 'cyan', 'blue', 'purple', 'red', 'orange', 'gray', 기본값: 'cyan')
  /// [size]: 사이즈 ('medium', 'large', 기본값: 'large')
  static Widget buildTextButton({
    required String text,
    required VoidCallback onPressed,
    String color = 'cyan',
    String size = 'large',
  }) {
    final theme = _getColorTheme(color);
    final sizeConfig = _getSizeConfig(size);

    return Container(
      height: sizeConfig.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.gradientStartColor, theme.gradientEndColor],
          stops: [0.0, 1.0],
          begin: AlignmentDirectional(0.0, -1.0),
          end: AlignmentDirectional(0, 1.0),
        ),
        borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            blurRadius: sizeConfig.shadowBlur,
            color: theme.shadowColor,
            offset: sizeConfig.shadowOffset,
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: theme.textColor,
            fontSize: sizeConfig.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
          ),
          padding: EdgeInsetsDirectional.fromSTEB(
            sizeConfig.horizontalPadding,
            0.0,
            sizeConfig.horizontalPadding,
            0.0,
          ),
        ),
      ),
    );
  }

  /// 아이콘만 있는 버튼 생성
  ///
  /// [icon]: 버튼에 표시할 아이콘
  /// [onPressed]: 버튼 클릭 시 실행할 함수
  /// [color]: 색상 테마 ('green', 'cyan', 'blue', 'purple', 'red', 'orange', 'gray', 기본값: 'cyan')
  /// [size]: 사이즈 ('medium', 'large', 기본값: 'large')
  static Widget buildIconOnlyButton({
    required IconData icon,
    required VoidCallback onPressed,
    String color = 'cyan',
    String size = 'large',
  }) {
    final theme = _getColorTheme(color);
    final sizeConfig = _getSizeConfig(size);

    return Container(
      width: sizeConfig.height,
      height: sizeConfig.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.gradientStartColor, theme.gradientEndColor],
          stops: [0.0, 1.0],
          begin: AlignmentDirectional(0.0, -1.0),
          end: AlignmentDirectional(0, 1.0),
        ),
        borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            blurRadius: sizeConfig.shadowBlur,
            color: theme.shadowColor,
            offset: sizeConfig.shadowOffset,
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Icon(
          icon,
          size: sizeConfig.iconSize,
          color: theme.textColor,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ========== 입력 필드 빌더 메서드 ==========

  /// 검색용 텍스트 입력 필드 생성
  ///
  /// [controller]: TextEditingController
  /// [focusNode]: FocusNode (선택사항)
  /// [hintText]: 힌트 텍스트 (기본값: '검색어를 입력하세요')
  /// [onSubmitted]: Enter 키 입력 시 실행할 함수
  /// [width]: 입력 필드 너비 (기본값: 300.0)
  static Widget buildSearchField({
    required TextEditingController controller,
    FocusNode? focusNode,
    String hintText = '검색어를 입력하세요',
    Function(String)? onSubmitted,
    double width = 300.0,
  }) {
    return Container(
      width: width,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        autofocus: false,
        obscureText: false,
        onFieldSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF94A3B8),
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFFE2E8F0),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFF3B82F6),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
        ),
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF1E293B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  /// 검색 바 (검색 필드 + 검색 버튼) 조합 생성
  ///
  /// [controller]: TextEditingController
  /// [focusNode]: FocusNode (선택사항)
  /// [hintText]: 힌트 텍스트 (기본값: '검색어를 입력하세요')
  /// [onSearch]: 검색 실행 함수
  /// [searchFieldWidth]: 검색 필드 너비 (기본값: 300.0)
  /// [buttonSize]: 버튼 사이즈 ('medium', 'large', 기본값: 'large')
  /// [buttonColor]: 버튼 색상 (기본값: 'cyan')
  static Widget buildSearchBar({
    required TextEditingController controller,
    required VoidCallback onSearch,
    FocusNode? focusNode,
    String hintText = '검색어를 입력하세요',
    double searchFieldWidth = 300.0,
    String buttonSize = 'large',
    String buttonColor = 'cyan',
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildSearchField(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
          onSubmitted: (_) => onSearch(),
          width: searchFieldWidth,
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
          child: buildIconButton(
            text: '검색',
            icon: Icons.search,
            onPressed: onSearch,
            color: buttonColor,
            size: buttonSize,
          ),
        ),
      ],
    );
  }

  // ========== 헬퍼 위젯 빌더 메서드 ==========

  /// 툴팁이 있는 안내 아이콘 생성
  ///
  /// [message]: 툴팁에 표시할 메시지
  /// [iconSize]: 아이콘 크기 (기본값: 20.0)
  /// [iconColor]: 아이콘 색상 (기본값: Color(0xFF64748B) - 회색)
  /// [backgroundColor]: 툴팁 배경색 (기본값: Color(0xFF1E293B) - 다크 그레이)
  static Widget buildHelpTooltip({
    required String message,
    double iconSize = 20.0,
    Color iconColor = const Color(0xFF64748B),
    Color backgroundColor = const Color(0xFF1E293B),
  }) {
    return _HelpTooltipWidget(
      message: message,
      iconSize: iconSize,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
    );
  }
}

// ========== 내부 클래스 ==========

/// 툴팁 위젯 (호버 및 클릭 지원)
class _HelpTooltipWidget extends StatefulWidget {
  final String message;
  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;

  const _HelpTooltipWidget({
    required this.message,
    required this.iconSize,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  _HelpTooltipWidgetState createState() => _HelpTooltipWidgetState();
}

class _HelpTooltipWidgetState extends State<_HelpTooltipWidget> {
  bool _isHovered = false;
  bool _isClicked = false;

  void _showTooltip() {
    setState(() {
      _isHovered = true;
    });
  }

  void _hideTooltip() {
    // 클릭된 상태가 아닐 때만 숨김
    if (!_isClicked) {
      setState(() {
        _isHovered = false;
      });
    }
  }

  void _toggleClick() {
    setState(() {
      _isClicked = !_isClicked;
      if (_isClicked) {
        _isHovered = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showTooltip(),
      onExit: (_) => _hideTooltip(),
      cursor: SystemMouseCursors.help,
      child: GestureDetector(
        onTap: _toggleClick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 아이콘 (더 큰 호버 영역)
            Container(
              width: widget.iconSize + 16,
              height: widget.iconSize + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.iconColor.withOpacity(0.1),
              ),
              child: Center(
                child: Icon(
                  Icons.help_outline,
                  size: widget.iconSize,
                  color: widget.iconColor,
                ),
              ),
            ),
            // 툴팁 (오른쪽에 표시)
            if (_isHovered || _isClicked)
              Positioned(
                left: widget.iconSize + 20,
                top: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 200),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      alignment: Alignment.topLeft,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 250),
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8.0,
                          offset: Offset(0.0, 2.0),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: Colors.white,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 버튼 색상 테마 설정
class _ButtonColorTheme {
  final Color gradientStartColor;
  final Color gradientEndColor;
  final Color shadowColor;
  final Color textColor;

  const _ButtonColorTheme({
    required this.gradientStartColor,
    required this.gradientEndColor,
    required this.shadowColor,
    required this.textColor,
  });
}

/// 버튼 사이즈 설정
class _ButtonSizeConfig {
  final double height;
  final double iconSize;
  final double fontSize;
  final double borderRadius;
  final double horizontalPadding;
  final double gap;
  final double shadowBlur;
  final Offset shadowOffset;

  const _ButtonSizeConfig({
    required this.height,
    required this.iconSize,
    required this.fontSize,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.gap,
    required this.shadowBlur,
    required this.shadowOffset,
  });
}
