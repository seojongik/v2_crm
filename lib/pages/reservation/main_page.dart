import 'package:flutter/material.dart';
import 'lib/services/api_service.dart';

import '../../constants/font_sizes.dart';
class MainPage extends StatefulWidget {
  final bool isAdminMode;
  final Map<String, dynamic>? selectedMember;
  final String? branchId;
  
  const MainPage({
    Key? key, 
    this.isAdminMode = false,
    this.selectedMember,
    this.branchId,
  }) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentMember;
  String? _currentBranchId;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '홈',
    ),
    NavigationItem(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      label: '조회',
    ),
    NavigationItem(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: '예약',
    ),
    NavigationItem(
      icon: Icons.card_membership_outlined,
      selectedIcon: Icons.card_membership,
      label: '회원권',
    ),
    NavigationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '계정관리',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializePageData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleRouteArguments();
  }

  void _initializePageData() {
    _currentMember = widget.selectedMember;
    _currentBranchId = widget.branchId;
  }

  void _handleRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    print('메인 페이지 라우트 인수: $args');
    
    if (args != null) {
      print('회원 정보 업데이트: ${args['selectedMember']}');
      print('브랜치 ID: ${args['branchId']}');
      print('관리자 모드: ${args['isAdminMode']}');
      
      setState(() {
        _currentMember = args['selectedMember'];
        _currentBranchId = args['branchId'];
      });
    } else {
      print('라우트 인수가 없습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _buildCurrentPage(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildSearchPage();
      case 2:
        return _buildReservationPage();
      case 3:
        return _buildMembershipPage();
      case 4:
        return _buildAccountPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(isSmallScreen),
            SizedBox(height: 32.0),
            
            // 빠른 액션 버튼들
            _buildQuickActions(isSmallScreen),
            SizedBox(height: 32.0),
            
            // 통계 카드들
            _buildStatsCards(isSmallScreen),
            SizedBox(height: 32.0),
            
            // 최근 활동
            _buildRecentActivity(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    final memberName = _currentMember?['member_name']?.toString() ?? '사용자';
    final memberId = _currentMember?['member_id']?.toString() ?? '';
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.isAdminMode ? '$memberName님의 페이지 👤' : '안녕하세요! 👋',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20.0 : 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.isAdminMode) ...[
                    SizedBox(width: 8.0),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        '관리자',
                        style: AppTextStyles.cardBody.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 4.0),
              Text(
                widget.isAdminMode 
                  ? '회원 ID: $memberId | 관리자 모드로 접속중'
                  : '오늘도 건강한 하루 되세요',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12.0 : 14.0,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // 알림 버튼 및 관리자 메뉴
        Row(
          children: [
            if (widget.isAdminMode) ...[
              // 회원 변경 버튼
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10.0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.swap_horiz, color: Colors.white),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/admin-login');
                  },
                  tooltip: '다른 회원 선택',
                ),
              ),
              SizedBox(width: 8.0),
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.notifications_outlined),
                onPressed: () {
                  // 알림 페이지로 이동
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '빠른 실행',
          style: TextStyle(
            fontSize: isSmallScreen ? 18.0 : 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 16.0),
        
        // 예약하기 버튼 (가장 크게)
        _buildMainReservationButton(isSmallScreen),
        SizedBox(height: 16.0),
        
        // 기타 빠른 액션들
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.search,
                title: '예약 조회',
                subtitle: '내 예약 확인',
                color: Colors.green,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.card_membership,
                title: '회원권 관리',
                subtitle: '잔여 횟수 확인',
                color: Colors.purple,
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainReservationButton(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 120.0 : 140.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20.0,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.0),
          onTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 60.0 : 70.0,
                  height: isSmallScreen ? 60.0 : 70.0,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: isSmallScreen ? 30.0 : 35.0,
                  ),
                ),
                SizedBox(width: 20.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '예약하기',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 24.0 : 28.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        '원하는 시간에 예약하세요',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 100.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20.0,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  title,
                  style: AppTextStyles.formLabel.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이번 달 통계',
          style: TextStyle(
            fontSize: isSmallScreen ? 18.0 : 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 16.0),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '총 예약',
                value: '12',
                icon: Icons.calendar_today,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: _buildStatCard(
                title: '잔여 횟수',
                value: '8',
                icon: Icons.fitness_center,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: _buildStatCard(
                title: '이용 시간',
                value: '24h',
                icon: Icons.access_time,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24.0,
          ),
          SizedBox(height: 8.0),
          Text(
            value,
            style: AppTextStyles.titleH3.copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.0),
          Text(
            title,
            overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 활동',
          style: TextStyle(
            fontSize: isSmallScreen ? 18.0 : 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 16.0),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildActivityItem(
                icon: Icons.calendar_today,
                title: '헬스 개인레슨 예약',
                subtitle: '2025년 1월 25일 오후 2시',
                time: '2시간 전',
                color: Colors.blue,
              ),
              Divider(height: 1),
              _buildActivityItem(
                icon: Icons.fitness_center,
                title: '필라테스 수업 완료',
                subtitle: '2025년 1월 22일 오전 10시',
                time: '3일 전',
                color: Colors.green,
              ),
              Divider(height: 1),
              _buildActivityItem(
                icon: Icons.card_membership,
                title: '회원권 결제 완료',
                subtitle: '10회권 구매',
                time: '1주일 전',
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20.0,
            ),
          ),
          SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.formLabel.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2.0),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
                ),
              ],
            ),
          ),
          Text(
            time,
            overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '예약 조회',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
            SizedBox(height: 20.0),
            Text('예약 조회 기능이 여기에 표시됩니다.'),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationPage() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '예약하기',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
            SizedBox(height: 20.0),
            Text('예약 기능이 여기에 표시됩니다.'),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipPage() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '회원권 관리',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
            SizedBox(height: 20.0),
            Text('회원권 관리 기능이 여기에 표시됩니다.'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    final memberName = _currentMember?['member_name']?.toString() ?? '사용자';
    final memberPhone = _currentMember?['member_phone']?.toString() ?? '';
    final memberId = _currentMember?['member_id']?.toString() ?? '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '계정 관리',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
            SizedBox(height: 20.0),
            
            if (widget.isAdminMode && _currentMember != null) ...[
              // 선택된 회원 정보 표시
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 접속중인 회원',
                      style: AppTextStyles.bodyText.copyWith(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12.0),
                    _buildInfoRow('회원 ID', memberId),
                    _buildInfoRow('이름', memberName),
                    _buildInfoRow('전화번호', memberPhone),
                    _buildInfoRow('지점 ID', _currentBranchId ?? ''),
                  ],
                ),
              ),
              SizedBox(height: 20.0),
              
              // 관리자 액션 버튼들
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/admin-login');
                },
                icon: Icon(Icons.swap_horiz),
                label: Text('다른 회원 선택'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48.0),
                ),
              ),
              SizedBox(height: 12.0),
            ] else ...[
              Text('계정 관리 기능이 여기에 표시됩니다.'),
              SizedBox(height: 20.0),
            ],
            
            ElevatedButton(
              onPressed: () {
                if (widget.isAdminMode) {
                  // 관리자 모드에서는 CRM으로 돌아가기
                  Navigator.of(context).pop();
                } else {
                  // 일반 모드에서는 로그인 페이지로
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: Text(widget.isAdminMode ? 'CRM으로 돌아가기' : '로그아웃'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.0,
            child: Text(
              '$label:',
              style: AppTextStyles.formLabel.copyWith(color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '정보 없음',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10.0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;
              final isReservation = index == 2; // 예약 탭

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isReservation ? 16.0 : 12.0,
                    vertical: isReservation ? 12.0 : 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isReservation ? Colors.blue : Colors.blue.withOpacity(0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(isReservation ? 16.0 : 12.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected
                            ? (isReservation ? Colors.white : Colors.blue)
                            : Colors.grey[600],
                        size: isReservation ? 28.0 : 24.0,
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: isReservation ? 12.0 : 11.0,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? (isReservation ? Colors.white : Colors.blue)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
} 