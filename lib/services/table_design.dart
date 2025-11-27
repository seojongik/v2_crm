import 'package:flutter/material.dart';

/// 테이블 디자인 컴포넌트
///
/// 재사용 가능한 테이블 UI 요소들을 제공
/// - 컨테이너: 테이블 전체를 감싸는 스타일
/// - 헤더: 고정 헤더 스타일
/// - 행: 데이터 행 스타일 (호버 효과 포함)
class TableDesign {
  // ========== 색상 상수 ==========

  /// 컨테이너 배경색
  static const Color containerBackground = Colors.white;

  /// 컨테이너 테두리 색상
  static const Color containerBorder = Color(0xFFE2E8F0);

  /// 헤더 배경색
  static const Color headerBackground = Color(0xFFF8FAFC);

  /// 헤더 텍스트 색상
  static const Color headerTextColor = Color(0xFF475569);

  /// 헤더 하단 테두리 색상
  static const Color headerBottomBorder = Color(0xFFE2E8F0);

  /// 행 배경색 (일반)
  static const Color rowBackground = Colors.white;

  /// 행 배경색 (대체 - 주니어 등)
  static const Color rowBackgroundAlt = Color(0xFFF8FAFC);

  /// 행 배경색 (호버)
  static const Color rowBackgroundHover = Color(0xFFF1F5F9);

  /// 행 하단 테두리 색상
  static const Color rowBottomBorder = Color(0xFFF1F5F9);

  /// 기본 텍스트 색상
  static const Color textColorPrimary = Color(0xFF1E293B);

  /// 보조 텍스트 색상
  static const Color textColorSecondary = Color(0xFF64748B);

  // ========== 크기 상수 ==========

  /// 컨테이너 둥근 모서리
  static const double containerBorderRadius = 12.0;

  /// 컨테이너 테두리 두께
  static const double containerBorderWidth = 1.0;

  /// 컨테이너 패딩
  static const double containerPadding = 24.0;

  /// 헤더 패딩
  static const double headerPadding = 16.0;

  /// 헤더 하단 테두리 두께
  static const double headerBottomBorderWidth = 1.0;

  /// 행 패딩 (세로)
  static const double rowPaddingVertical = 16.0;

  /// 행 패딩 (가로)
  static const double rowPaddingHorizontal = 16.0;

  /// 행 최소 높이
  static const double rowMinHeight = 60.0;

  /// 행 하단 테두리 두께
  static const double rowBottomBorderWidth = 1.0;

  /// 헤더 폰트 크기
  static const double headerFontSize = 14.0;

  /// 행 폰트 크기
  static const double rowFontSize = 14.0;

  // ========== 위젯 빌더 메서드 ==========

  /// 테이블 전체를 감싸는 컨테이너 생성
  ///
  /// [child]: 테이블 내용 (헤더 + 데이터)
  /// [padding]: 패딩 (기본값: 24.0)
  static Widget buildTableContainer({
    required Widget child,
    double? padding,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: containerBackground,
        borderRadius: BorderRadius.circular(containerBorderRadius),
        border: Border.all(
          color: containerBorder,
          width: containerBorderWidth,
        ),
      ),
      child: child,
    );
  }

  /// 테이블 헤더 컨테이너 생성
  ///
  /// [children]: 헤더 컬럼 위젯들
  /// [padding]: 패딩 (기본값: 16.0)
  static Widget buildTableHeader({
    required List<Widget> children,
    double? padding,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: headerBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(containerBorderRadius),
          topRight: Radius.circular(containerBorderRadius),
        ),
        border: Border(
          bottom: BorderSide(
            color: headerBottomBorder,
            width: headerBottomBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding ?? headerPadding),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: children,
        ),
      ),
    );
  }

  /// 헤더 컬럼 텍스트 스타일 생성
  ///
  /// [text]: 컬럼 텍스트
  /// [flex]: Expanded의 flex 값 (null이면 일반 Container)
  /// [width]: 고정 너비 (flex가 null일 때만 사용)
  /// [textAlign]: 텍스트 정렬 (기본값: 가운데)
  static Widget buildHeaderColumn({
    required String text,
    int? flex,
    double? width,
    TextAlign textAlign = TextAlign.center,
  }) {
    final textWidget = Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'Pretendard',
        color: headerTextColor,
        fontSize: headerFontSize,
        fontWeight: FontWeight.w600,
      ),
    );

    if (flex != null) {
      return Expanded(
        flex: flex,
        child: textWidget,
      );
    } else if (width != null) {
      return Container(
        width: width,
        child: textWidget,
      );
    } else {
      return textWidget;
    }
  }

  /// 테이블 행 위젯 생성 (호버 효과 포함)
  ///
  /// [children]: 행의 컬럼 위젯들
  /// [onTap]: 클릭 이벤트 핸들러
  /// [isAlternate]: 대체 배경색 사용 여부 (주니어 등)
  /// [leftPadding]: 왼쪽 패딩 (들여쓰기 등)
  /// [rightPadding]: 오른쪽 패딩
  /// [verticalPadding]: 세로 패딩
  static Widget buildTableRow({
    required List<Widget> children,
    VoidCallback? onTap,
    bool isAlternate = false,
    double? leftPadding,
    double? rightPadding,
    double? verticalPadding,
  }) {
    return _TableRowWidget(
      onTap: onTap,
      isAlternate: isAlternate,
      leftPadding: leftPadding ?? rowPaddingHorizontal,
      rightPadding: rightPadding ?? rowPaddingHorizontal,
      verticalPadding: verticalPadding ?? rowPaddingVertical,
      children: children,
    );
  }

  /// 행 컬럼 텍스트 스타일 생성
  ///
  /// [text]: 컬럼 텍스트
  /// [flex]: Expanded의 flex 값 (null이면 일반 Container)
  /// [width]: 고정 너비 (flex가 null일 때만 사용)
  /// [textAlign]: 텍스트 정렬 (기본값: 가운데)
  /// [color]: 텍스트 색상 (기본값: primary)
  /// [fontWeight]: 폰트 굵기 (기본값: w500)
  /// [fontSize]: 폰트 크기 (기본값: 14.0)
  static Widget buildRowColumn({
    required String text,
    int? flex,
    double? width,
    TextAlign textAlign = TextAlign.center,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double? fontSize,
  }) {
    final textWidget = Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'Pretendard',
        color: color ?? textColorPrimary,
        fontSize: fontSize ?? rowFontSize,
        fontWeight: fontWeight,
      ),
    );

    if (flex != null) {
      return Expanded(
        flex: flex,
        child: textWidget,
      );
    } else if (width != null) {
      return Container(
        width: width,
        child: textWidget,
      );
    } else {
      return textWidget;
    }
  }

  /// 위젯을 감싸는 컬럼 생성 (커스텀 위젯용)
  ///
  /// [child]: 컬럼에 들어갈 위젯
  /// [flex]: Expanded의 flex 값 (null이면 일반 Container)
  /// [width]: 고정 너비 (flex가 null일 때만 사용)
  /// [padding]: 패딩
  static Widget buildColumn({
    required Widget child,
    int? flex,
    double? width,
    EdgeInsetsGeometry? padding,
  }) {
    final paddedChild = padding != null
        ? Padding(padding: padding, child: child)
        : child;

    if (flex != null) {
      return Expanded(
        flex: flex,
        child: paddedChild,
      );
    } else if (width != null) {
      return Container(
        width: width,
        child: paddedChild,
      );
    } else {
      return paddedChild;
    }
  }

  /// 스크롤 가능한 테이블 본문 생성 (ListView.builder 사용)
  ///
  /// [itemCount]: 항목 개수
  /// [itemBuilder]: 항목 빌더
  /// [emptyWidget]: 데이터가 없을 때 표시할 위젯
  /// [loadingWidget]: 로딩 중 표시할 위젯
  /// [errorWidget]: 에러 발생 시 표시할 위젯
  /// [isLoading]: 로딩 상태
  /// [hasError]: 에러 상태
  static Widget buildTableBody({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    Widget? emptyWidget,
    Widget? loadingWidget,
    Widget? errorWidget,
    bool isLoading = false,
    bool hasError = false,
  }) {
    if (isLoading) {
      return loadingWidget ??
          Center(
            child: CircularProgressIndicator(
              color: Color(0xFF06B6D4),
            ),
          );
    }

    if (hasError) {
      return errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48.0,
                  color: Color(0xFFEF4444),
                ),
                SizedBox(height: 16.0),
                Text(
                  '데이터를 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFFEF4444),
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          );
    }

    if (itemCount == 0) {
      return emptyWidget ??
          Center(
            child: Text(
              '조회된 데이터가 없습니다.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: textColorSecondary,
                fontSize: 16.0,
              ),
            ),
          );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }

  /// 완성된 테이블 구조 생성 (헤더 고정 + 스크롤 가능한 본문)
  ///
  /// [headerColumns]: 헤더 컬럼들
  /// [itemCount]: 항목 개수
  /// [itemBuilder]: 항목 빌더
  /// [emptyWidget]: 데이터가 없을 때 표시할 위젯
  /// [loadingWidget]: 로딩 중 표시할 위젯
  /// [errorWidget]: 에러 발생 시 표시할 위젯
  /// [isLoading]: 로딩 상태
  /// [hasError]: 에러 상태
  static Widget buildCompleteTable({
    required List<Widget> headerColumns,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    Widget? emptyWidget,
    Widget? loadingWidget,
    Widget? errorWidget,
    bool isLoading = false,
    bool hasError = false,
  }) {
    return buildTableContainer(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // 헤더 (고정)
          buildTableHeader(children: headerColumns),
          // 본문 (스크롤 가능)
          Expanded(
            child: buildTableBody(
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              emptyWidget: emptyWidget,
              loadingWidget: loadingWidget,
              errorWidget: errorWidget,
              isLoading: isLoading,
              hasError: hasError,
            ),
          ),
        ],
      ),
    );
  }

  // ========== DataTable 전용 스타일 메서드 ==========

  /// DataTable용 테마 데이터 생성
  ///
  /// Flutter의 기본 DataTable 위젯을 사용할 때 일관된 스타일 적용
  static DataTableThemeData getDataTableTheme() {
    return DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(headerBackground),
      headingTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: headerTextColor,
        fontSize: headerFontSize,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: textColorPrimary,
        fontSize: rowFontSize,
        fontWeight: FontWeight.w400,
      ),
      columnSpacing: 24.0,
      horizontalMargin: 16.0,
      dividerThickness: 0.0, // 세로 구분선 제거
      decoration: BoxDecoration(
        color: containerBackground,
        borderRadius: BorderRadius.circular(containerBorderRadius),
        border: Border.all(
          color: containerBorder,
          width: containerBorderWidth,
        ),
      ),
    );
  }

  /// DataColumn 헬퍼 메서드 (일관된 스타일의 헤더 컬럼 생성)
  ///
  /// [label]: 헤더 텍스트
  /// [numeric]: 숫자 컬럼 여부 (우측 정렬)
  /// [tooltip]: 툴팁 텍스트
  static DataColumn buildDataColumn({
    required String label,
    bool numeric = false,
    String? tooltip,
  }) {
    return DataColumn(
      label: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: headerTextColor,
            fontSize: headerFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      numeric: numeric,
      tooltip: tooltip,
    );
  }

  /// 스타일이 적용된 DataTable 래퍼
  ///
  /// [columns]: DataColumn 리스트
  /// [rows]: DataRow 리스트
  /// [columnSpacing]: 컬럼 간격
  /// [headingRowHeight]: 헤더 행 높이
  /// [dataRowHeight]: 데이터 행 높이
  static Widget buildStyledDataTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    double? columnSpacing,
    double? headingRowHeight,
    double? dataRowHeight,
  }) {
    return Theme(
      data: ThemeData(
        dataTableTheme: getDataTableTheme(),
      ),
      child: DataTable(
        columns: columns,
        rows: rows,
        columnSpacing: columnSpacing ?? 24.0,
        headingRowHeight: headingRowHeight ?? 56.0,
        dataRowMinHeight: dataRowHeight ?? 48.0,
        dataRowMaxHeight: dataRowHeight ?? 60.0,
        headingRowColor: WidgetStateProperty.all(headerBackground),
      ),
    );
  }

  /// DataTable을 헤더 고정 + 본문 스크롤 구조로 감싸기
  ///
  /// [columns]: DataColumn 리스트
  /// [rows]: DataRow 리스트
  /// [isLoading]: 로딩 상태
  /// [isEmpty]: 데이터 없음 상태
  /// [emptyMessage]: 빈 데이터 메시지
  /// [columnSpacing]: 컬럼 간격
  static Widget buildScrollableDataTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    bool isLoading = false,
    bool isEmpty = false,
    String emptyMessage = '데이터가 없습니다',
    double? columnSpacing,
  }) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Color(0xFF06B6D4),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16.0,
            color: textColorSecondary,
          ),
        ),
      );
    }

    // 스크롤바 너비를 고려한 패딩
    const scrollbarWidth = 15.0;

    return Column(
      children: [
        // 고정 헤더
        Container(
          decoration: BoxDecoration(
            color: headerBackground,
            border: Border(
              bottom: BorderSide(
                color: headerBottomBorder,
                width: headerBottomBorderWidth,
              ),
            ),
          ),
          // 스크롤바 너비만큼 오른쪽 패딩 추가
          padding: EdgeInsets.only(right: scrollbarWidth),
          child: Theme(
            data: ThemeData(
              dataTableTheme: getDataTableTheme(),
            ),
            child: DataTable(
              columns: columns,
              rows: [], // 헤더만 표시
              columnSpacing: columnSpacing ?? 24.0,
              headingRowHeight: 56.0,
              headingRowColor: WidgetStateProperty.all(headerBackground),
              dividerThickness: 0,
            ),
          ),
        ),
        // 스크롤 가능한 본문
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Theme(
                data: ThemeData(
                  dataTableTheme: getDataTableTheme(),
                ),
                child: DataTable(
                  columns: columns.map((col) => DataColumn(label: SizedBox.shrink())).toList(), // 빈 헤더
                  rows: rows,
                  columnSpacing: columnSpacing ?? 24.0,
                  dataRowMinHeight: 48.0,
                  dataRowMaxHeight: 60.0,
                  headingRowHeight: 0, // 헤더 높이 0으로 숨김
                  dividerThickness: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ========== 내부 위젯 ==========

/// 호버 효과가 있는 테이블 행 위젯
class _TableRowWidget extends StatefulWidget {
  final List<Widget> children;
  final VoidCallback? onTap;
  final bool isAlternate;
  final double leftPadding;
  final double rightPadding;
  final double verticalPadding;

  const _TableRowWidget({
    required this.children,
    this.onTap,
    this.isAlternate = false,
    required this.leftPadding,
    required this.rightPadding,
    required this.verticalPadding,
  });

  @override
  _TableRowWidgetState createState() => _TableRowWidgetState();
}

class _TableRowWidgetState extends State<_TableRowWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: TableDesign.rowMinHeight,
          ),
          decoration: BoxDecoration(
            color: isHovered
                ? TableDesign.rowBackgroundHover
                : (widget.isAlternate
                    ? TableDesign.rowBackgroundAlt
                    : TableDesign.rowBackground),
            border: Border(
              bottom: BorderSide(
                color: TableDesign.rowBottomBorder,
                width: TableDesign.rowBottomBorderWidth,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.leftPadding,
              widget.verticalPadding,
              widget.rightPadding,
              widget.verticalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: widget.children,
            ),
          ),
        ),
      ),
    );
  }
}
