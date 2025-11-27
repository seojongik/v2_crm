import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:famd_clientapp/providers/notice_provider.dart';
import 'package:famd_clientapp/models/notice.dart';
import 'package:famd_clientapp/screens/login_screen.dart';
import 'package:famd_clientapp/screens/subpages/subpage_screen.dart';
import 'package:famd_clientapp/screens/notice_screen.dart';
import 'package:famd_clientapp/screens/first_page/today_reservations_widget.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 약간의 지연 후 공지사항 로드 (build 완료 이후에)
    Future.microtask(_loadNotices);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    try {
      final noticeProvider = Provider.of<NoticeProvider>(context, listen: false);
      await noticeProvider.loadNotices();
    } catch (e) {
      print('공지사항 로드 중 오류: $e');
    }
  }

  void _navigateToSubpage(int pageIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubpageScreen(pageIndex: pageIndex),
      ),
    );
  }

  void _navigateToNoticeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NoticeScreen(),
      ),
    );
  }

  void _logout() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.clearUser();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.user?.name ?? '사용자';

    return Scaffold(
      appBar: AppBar(
        title: Text('${userProvider.user?.name ?? '사용자'}님의 프렌즈 아카데미'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotices,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 환영 메시지 추가
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5D6), // 연한 노란색
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Theme.of(context).colorScheme.secondary, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$userName님! 환영합니다.',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '오늘도 좋은 하루 되세요.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 오늘의 예약 섹션
                const TodayReservationsWidget(),
                const SizedBox(height: 20),
                // 공지사항 섹션
                _buildNoticeSection(),
                const SizedBox(height: 20),
                // 메뉴 섹션
                _buildMenuSection(),
                // 하단 여백 추가
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeSection() {
    return Consumer<NoticeProvider>(
      builder: (context, noticeProvider, child) {
        if (noticeProvider.isLoading) {
          return const SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 공지사항 표시할 컨테이너
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '공지사항',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // 전체공지 확인 버튼
                TextButton.icon(
                  onPressed: _navigateToNoticeScreen,
                  icon: const Icon(Icons.list_alt, size: 14),
                  label: const Text('전체공지 확인', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 공지사항 목록
            noticeProvider.notices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('공지사항이 없습니다'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: noticeProvider.notices.length > 4 ? 4 : noticeProvider.notices.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notice = noticeProvider.notices[index];
                      return _buildNoticeItem(notice);
                    },
                  ),
            if (noticeProvider.notices.length > 4)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _navigateToNoticeScreen,
                  child: const Text('더보기', style: TextStyle(fontSize: 13)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNoticeItem(Notice notice) {
    return InkWell(
      onTap: () {
        // 공지사항 상세 보기 dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notice.title),
            content: SingleChildScrollView(
              child: Text(notice.content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notice.isImportant)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '중요',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontWeight: notice.isImportant ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${notice.date.year}/${notice.date.month}/${notice.date.day}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    // 메뉴 아이템 정보 - 색상 팔레트 개선
    final menuItems = [
      {'icon': Icons.credit_card, 'title': '크레딧조회', 'color': Theme.of(context).primaryColor},
      {'icon': Icons.golf_course, 'title': '싱글로 가는 지름길\n레슨피드백', 'color': Theme.of(context).primaryColor},
      {'icon': Icons.calendar_today, 'title': '통합예약', 'color': Theme.of(context).primaryColor},
      {'icon': Icons.card_membership, 'title': '회원권', 'color': Theme.of(context).primaryColor},
      {'icon': Icons.settings, 'title': '메뉴 5', 'color': Theme.of(context).primaryColor},
      {'icon': Icons.help, 'title': '메뉴 6', 'color': Theme.of(context).primaryColor},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '메뉴',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
          ),
          itemCount: 4, // 4개 메뉴만 표시
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return _buildMenuButton(
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              color: item['color'] as Color,
              onTap: () => _navigateToSubpage(index + 1),
              index: index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    // 그라데이션 색상 목록 - 부드럽고 통일감 있는 색상으로 변경
    final List<List<Color>> gradients = [
      [const Color(0xFF4A6FED), const Color(0xFF6A8CFF)], // 푸른색 계열
      [const Color(0xFF4EAEDE), const Color(0xFF6BC4EF)], // 하늘색 계열
      [const Color(0xFF5E72EB), const Color(0xFF8E54E9)], // 보라색 계열
      [const Color(0xFF4776E6), const Color(0xFF8E54E9)], // 파란-보라 그라데이션
      [const Color(0xFF396AFC), const Color(0xFF2948FF)], // 파란색 계열
      [const Color(0xFF56CCF2), const Color(0xFF2F80ED)], // 하늘-파란 그라데이션
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: gradients[index % gradients.length],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 