import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 급여 정산 시스템의 공통 UI 컴포넌트 및 스타일을 관리하는 서비스
class SalaryFormService {
  // 공통 색상 정의
  static const Color primaryColor = Color(0xFF8B5CF6);
  static const Color successColor = Color(0xFF10B981);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color darkColor = Color(0xFF1F2937);
  static const Color grayColor = Color(0xFF6B7280);
  static const Color lightGrayColor = Color(0xFFF9FAFB);
  static const Color borderColor = Color(0xFFE5E7EB);

  // 공통 패딩 및 마진
  static const double defaultPadding = 20.0;
  static const double smallPadding = 12.0;
  static const double largePadding = 24.0;

  // 공통 border radius
  static const double defaultRadius = 12.0;
  static const double smallRadius = 8.0;
  static const double largeRadius = 16.0;

  /// 급여 정산 다이얼로그 헤더 빌드
  static Widget buildDialogHeader({
    required String title,
    required String subtitle,
    required VoidCallback onClose,
    bool isLoading = false,
    Widget? customActions,
  }) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(largeRadius)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          if (customActions != null) customActions,
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 월 네비게이션 위젯 빌드
  static Widget buildMonthNavigation({
    required DateTime selectedMonth,
    required Function(DateTime) onMonthChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: defaultPadding, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
              onMonthChanged(prevMonth);
            },
            icon: Icon(Icons.chevron_left, color: primaryColor),
          ),
          Text(
            DateFormat('yyyy년 MM월').format(selectedMonth),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkColor,
            ),
          ),
          IconButton(
            onPressed: () {
              final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
              onMonthChanged(nextMonth);
            },
            icon: Icon(Icons.chevron_right, color: primaryColor),
          ),
        ],
      ),
    );
  }

  /// 탭바 빌드
  static Widget buildTabBar({
    required TabController tabController,
    required List<TabItem> tabs,
    required Function(int) onTabChanged,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: defaultPadding),
      decoration: BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: TabBar(
        controller: tabController,
        onTap: onTabChanged,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: grayColor,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: tabs.map((tab) => Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 18),
              SizedBox(width: 6),
              Text(tab.label),
            ],
          ),
        )).toList(),
      ),
    );
  }

  /// 정보 카드 빌드 (레슨비 정산 스타일)
  static Widget buildInfoCard({
    required String title,
    required List<InfoItem> items,
    Color backgroundColor = primaryColor,
    Color textColor = Colors.white,
    IconData? icon,
  }) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || title.isNotEmpty)
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textColor, size: 24),
                  SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          if (icon != null || title.isNotEmpty) SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: item.isTotal ? 18 : 16,
                    fontWeight: item.isTotal ? FontWeight.bold : FontWeight.normal,
                    color: textColor.withOpacity(item.isTotal ? 1.0 : 0.9),
                  ),
                ),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: item.isTotal ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// 공제 항목 입력 필드 빌드
  static Widget buildDeductionField({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    Color focusColor = primaryColor,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: darkColor,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: '원',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: focusColor, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// 실지급액 카드 빌드
  static Widget buildNetPayCard({
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E40AF), infoColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(defaultRadius),
        boxShadow: [
          BoxShadow(
            color: infoColor.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 제출 버튼 빌드
  static Widget buildSubmitButton({
    required String text,
    required VoidCallback onPressed,
    IconData icon = Icons.send,
    bool isEnabled = true,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(smallRadius),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 테이블 헤더 셀 빌드
  static Widget buildTableHeaderCell({
    required String text,
    double? width,
    TextAlign textAlign = TextAlign.center,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: darkColor,
        ),
        textAlign: textAlign,
      ),
    );
  }

  /// 테이블 데이터 셀 빌드
  static Widget buildTableDataCell({
    required String text,
    double? width,
    TextAlign textAlign = TextAlign.center,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color ?? darkColor,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
        textAlign: textAlign,
      ),
    );
  }

  /// 상태 배지 빌드
  static Widget buildStatusBadge({
    required String status,
    required Color backgroundColor,
    Color textColor = Colors.white,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  /// 로딩 인디케이터 빌드
  static Widget buildLoadingIndicator({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: grayColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 빈 상태 표시 위젯
  static Widget buildEmptyState({
    required String message,
    IconData icon = Icons.info_outline,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: grayColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 금액 포맷팅
  static String formatCurrency(int amount) {
    return '${NumberFormat('#,###').format(amount)}원';
  }

  /// 날짜 포맷팅
  static String formatDate(DateTime date, {String format = 'yyyy.MM.dd'}) {
    return DateFormat(format, 'ko_KR').format(date);
  }
}

/// 탭 아이템 모델
class TabItem {
  final String label;
  final IconData icon;

  TabItem({required this.label, required this.icon});
}

/// 정보 아이템 모델
class InfoItem {
  final String label;
  final String value;
  final bool isTotal;

  InfoItem({
    required this.label,
    required this.value,
    this.isTotal = false,
  });
}