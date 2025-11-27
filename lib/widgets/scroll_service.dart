import 'package:flutter/material.dart';

/// 범용 가로 스크롤 서비스
/// 테이블이나 넓은 컨텐츠를 가로 스크롤할 때 사용
class ScrollService extends StatelessWidget {
  final Widget child;
  final double contentWidth;
  final bool enableScrollbar;
  final double scrollbarHeight;
  final Color trackColor;
  final Color thumbColor;
  final EdgeInsets scrollbarMargin;
  final double sensitivity;

  const ScrollService({
    Key? key,
    required this.child,
    required this.contentWidth,
    this.enableScrollbar = true,
    this.scrollbarHeight = 8.0,
    this.trackColor = const Color(0xFFE5E7EB),
    this.thumbColor = const Color(0xFF6B7280),
    this.scrollbarMargin = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    this.sensitivity = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needsScroll = constraints.maxWidth < contentWidth;

        if (!needsScroll) {
          // 스크롤이 필요 없으면 일반 Container로 표시
          return Container(
            width: double.infinity,
            child: child,
          );
        }

        // 스크롤 컨트롤러 생성
        final scrollController = ScrollController();

        final viewportWidth = constraints.maxWidth; // 외부 뷰포트 너비 저장

        return Column(
          children: [
            // 스크롤 가능한 컨텐츠 컨테이너
            Expanded(
              child: Container(
                width: double.infinity,
                child: RawScrollbar(
                  controller: scrollController,
                  thumbVisibility: false,
                  trackVisibility: false,
                  thickness: 0,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: contentWidth,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),

            // 커스텀 드래그 스크롤바 (조건부 표시)
            if (enableScrollbar)
              StatefulBuilder(
                builder: (context, setState) {
                  // 스크롤 리스너 추가
                  if (scrollController.hasClients) {
                    scrollController.removeListener(() {});
                    scrollController.addListener(() {
                      setState(() {});
                    });
                  }

                  return Container(
                    height: scrollbarHeight + scrollbarMargin.vertical,
                    margin: scrollbarMargin,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final double maxScroll = contentWidth - viewportWidth;
                        if (maxScroll <= 0) return;

                        final double currentRatio = scrollController.hasClients
                            ? scrollController.offset / maxScroll
                            : 0.0;
                        final double deltaX = details.delta.dx;
                        final double newRatio = (currentRatio + (deltaX / viewportWidth * sensitivity)).clamp(0.0, 1.0);
                        final double newOffset = newRatio * maxScroll;

                        if (scrollController.hasClients) {
                          scrollController.jumpTo(newOffset);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: scrollbarHeight,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(scrollbarHeight / 2),
                        ),
                        child: LayoutBuilder(
                          builder: (context, trackConstraints) {
                            final double maxScroll = contentWidth - viewportWidth;
                            if (maxScroll <= 0) return Container();

                            final double thumbWidth = (viewportWidth / contentWidth * trackConstraints.maxWidth).clamp(20.0, trackConstraints.maxWidth * 0.8);
                            final double maxTravel = trackConstraints.maxWidth - thumbWidth;
                            final double currentRatio = scrollController.hasClients
                                ? scrollController.offset / maxScroll
                                : 0.0;
                            final double thumbPosition = currentRatio * maxTravel;

                            return Stack(
                              children: [
                                Positioned(
                                  left: thumbPosition,
                                  child: Container(
                                    width: thumbWidth,
                                    height: scrollbarHeight,
                                    decoration: BoxDecoration(
                                      color: thumbColor,
                                      borderRadius: BorderRadius.circular(scrollbarHeight / 2),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// ScrollService의 간편한 팩토리 메서드들
extension ScrollServiceFactory on ScrollService {
  /// 테이블용 스크롤 서비스 (기본 설정)
  static Widget forTable({
    required Widget table,
    required double tableWidth,
    bool enableScrollbar = true,
  }) {
    return ScrollService(
      child: table,
      contentWidth: tableWidth,
      enableScrollbar: enableScrollbar,
      scrollbarHeight: 8.0,
      trackColor: Color(0xFFE5E7EB),
      thumbColor: Color(0xFF6B7280),
      scrollbarMargin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      sensitivity: 2.0,
    );
  }

  /// 커스텀 스크롤 서비스
  static Widget custom({
    required Widget child,
    required double contentWidth,
    bool enableScrollbar = true,
    double scrollbarHeight = 8.0,
    Color trackColor = const Color(0xFFE5E7EB),
    Color thumbColor = const Color(0xFF6B7280),
    EdgeInsets scrollbarMargin = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    double sensitivity = 2.0,
  }) {
    return ScrollService(
      child: child,
      contentWidth: contentWidth,
      enableScrollbar: enableScrollbar,
      scrollbarHeight: scrollbarHeight,
      trackColor: trackColor,
      thumbColor: thumbColor,
      scrollbarMargin: scrollbarMargin,
      sensitivity: sensitivity,
    );
  }
}

/// 스크롤 서비스 유틸리티
class ScrollServiceUtils {
  /// 컬럼 너비 리스트로부터 테이블 총 너비 계산
  static double calculateTableWidth(List<double> columnWidths, {double padding = 40.0}) {
    return columnWidths.reduce((a, b) => a + b) + padding;
  }

  /// 화면 크기에 따른 스크롤 필요 여부 판단
  static bool needsScroll(double screenWidth, double contentWidth) {
    return screenWidth < contentWidth;
  }

  /// 디버깅 로그 출력
  static void debugLog(String component, double screenWidth, double tableWidth, bool needsScroll) {
    print('🖥️ [$component] 화면 너비: ${screenWidth.toStringAsFixed(1)}px, 테이블 너비: ${tableWidth.toStringAsFixed(1)}px');
    print('📏 [$component] 스크롤 ${needsScroll ? "✅ 활성화됨" : "❌ 비활성화됨"} (needsScroll: $needsScroll)');
    if (needsScroll) {
      print('🔄 [$component] ScrollService가 활성화됩니다!');
    }
  }
}