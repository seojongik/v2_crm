import 'package:flutter/material.dart';
import 'package:famd_clientapp/screens/subpages/pages/credit_transactions_screen.dart';
import 'package:famd_clientapp/screens/subpages/pages/lesson_history_page.dart';
import 'package:famd_clientapp/screens/subpages/pages/integrated_reservation_screen.dart';

class SubpageScreen extends StatelessWidget {
  final int pageIndex;

  const SubpageScreen({Key? key, required this.pageIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 페이지 인덱스에 따라 다른 화면을 보여줌
    switch (pageIndex) {
      case 1:
        return const CreditTransactionsScreen();
      case 2:
        return const LessonHistoryPage();
      case 3:
        return const IntegratedReservationScreen();
      case 4:
        return _buildPlaceholderPage(context, '회원권');
      default:
        return _buildPlaceholderPage(context, '준비 중인 페이지');
    }
  }

  Widget _buildPlaceholderPage(BuildContext context, String title) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '준비 중입니다',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이 기능은 곧 제공될 예정입니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 