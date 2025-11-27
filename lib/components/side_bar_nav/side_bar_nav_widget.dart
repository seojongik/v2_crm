import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'side_bar_nav_model.dart';
import 'side_bar_state.dart';
import '../../services/chat_service.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../pages/login/login_widget.dart';
import '../../pages/login/change_password_widget.dart';
import '../../widgets/planner_app_popup.dart';
export 'side_bar_nav_model.dart';

class SideBarNavWidget extends StatefulWidget {
  const SideBarNavWidget({
    super.key,
    this.onNavigate,
    this.currentPage,
    this.currentTab,
  });

  final Function(String)? onNavigate;
  final String? currentPage;
  final int? currentTab;

  @override
  State<SideBarNavWidget> createState() => _SideBarNavWidgetState();
}

class _SideBarNavWidgetState extends State<SideBarNavWidget> {
  late SideBarNavModel _model;
  final SideBarState _sideBarState = SideBarState();

  bool get _isCollapsed => _sideBarState.isCollapsed;
  set _isCollapsed(bool value) => _sideBarState.isCollapsed = value;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SideBarNavModel());
    _updateMenuExpansionState();
  }

  @override
  void didUpdateWidget(SideBarNavWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 현재 페이지가 변경되면 메뉴 확장 상태를 업데이트
    if (oldWidget.currentPage != widget.currentPage) {
      _updateMenuExpansionState();
    }
  }

  // 현재 페이지에 맞춰 메뉴 확장 상태 업데이트
  void _updateMenuExpansionState() {
    if (widget.currentPage != null) {
      // 현재 페이지가 탭이 있는 메뉴인지 확인하고 자동으로 확장
      final expandableMenus = [
        'crm2_member',
        'crm5_hr',
        'crm7_communication',
        'crm9_setting',
        'crm10_operation',
      ];

      if (expandableMenus.contains(widget.currentPage)) {
        // 현재 페이지의 메뉴만 확장
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _sideBarState.clearAll();
            _sideBarState.setExpanded(widget.currentPage!, true);
          });
        });
      } else {
        // 탭이 없는 페이지로 이동하면 모든 확장 닫기
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _sideBarState.clearAll();
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // 인사말 텍스트 생성
  String _buildGreetingText() {
    final currentUser = ApiService.getCurrentUser();
    final currentRole = ApiService.getCurrentStaffRole();

    if (currentUser == null) {
      return '좋은 하루 되세요!';
    }

    String? staffName;
    if (currentRole == 'pro') {
      staffName = currentUser['pro_name'];
    } else if (currentRole == 'manager') {
      staffName = currentUser['manager_name'];
    } else if (currentRole == 'admin') {
      staffName = currentUser['staff_name'] ?? '관리자';
    }

    if (staffName != null && staffName.isNotEmpty) {
      return '$staffName님, 좋은 하루 되세요!';
    } else {
      return '좋은 하루 되세요!';
    }
  }

  // 인사관리 서브메뉴 아이템 동적 생성 (권한 기반)
  List<Map<String, dynamic>> _getHrManagementSubItems() {
    List<Map<String, dynamic>> items = [];
    int tabIndex = 0;

    // 권한 및 역할 체크
    final hasHrPermission = ApiService.hasPermission('hr_management');
    final hasSalaryManagementPermission = ApiService.hasPermission('salary_management');
    final currentRole = ApiService.getCurrentStaffRole();
    final staffSchedulePermission = ApiService.getCurrentAccessSettings()?['staff_schedule'] ?? '전체';
    final proSchedulePermission = ApiService.getCurrentAccessSettings()?['pro_schedule'] ?? '전체';

    // salary_management 권한이 있을 때만 급여관리 추가
    if (hasSalaryManagementPermission) {
      items.add({'title': '급여관리', 'tab': tabIndex++});
    }

    // 근무시간표 처리
    if (currentRole == 'manager' || currentRole == 'admin') {
      // 매니저/관리자는 항상 표시
      items.add({'title': '근무시간표', 'tab': tabIndex++});
    } else if (currentRole == 'pro') {
      // 프로는 staff_schedule이 '전체'일 때만 표시
      if (staffSchedulePermission == '전체') {
        items.add({'title': '근무시간표', 'tab': tabIndex++});
      }
    }

    // 프로시간표 처리
    if (currentRole == 'manager' || currentRole == 'admin') {
      // 매니저/관리자는 pro_schedule이 '전체'일 때만 표시
      if (proSchedulePermission == '전체') {
        items.add({'title': '프로시간표', 'tab': tabIndex++});
      }
    } else if (currentRole == 'pro') {
      // 프로는 항상 표시
      items.add({'title': '프로시간표', 'tab': tabIndex++});
    }

    // hr_management 권한이 있을 때만 직원등록 추가
    if (hasHrPermission) {
      items.add({'title': '직원등록', 'tab': tabIndex});
    }

    return items;
  }

  // 로그아웃 처리
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('로그아웃'),
          content: Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                // 세션 종료
                SessionManager.instance.endSession();

                // 전역 상태 초기화
                ApiService.logout();

                // 로그인 페이지로 이동
                Navigator.of(context).pop(); // 다이얼로그 닫기
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginWidget()),
                  (route) => false,
                );
              },
              child: Text(
                '로그아웃',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 80.0 : 280.0,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 8.0,
            color: Color(0x1A000000),
            offset: Offset(2.0, 0.0),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 영역
          Container(
            width: double.infinity,
            height: 80.0,
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isCollapsed) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final branchName = ApiService.getCurrentBranch()?['branch_name'] ?? 'FACRM';
                              final textPainter = TextPainter(
                                text: TextSpan(
                                  text: branchName,
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                maxLines: 1,
                                textDirection: ui.TextDirection.ltr,
                              )..layout(maxWidth: double.infinity);

                              double fontSize = 20.0;
                              double letterSpacing = 0.0;

                              // 텍스트가 공간보다 크면 크기와 자간 조절
                              if (textPainter.width > constraints.maxWidth) {
                                // 먼저 폰트 크기를 줄임 (최소 14.0까지)
                                for (double size = 20.0; size >= 14.0; size -= 0.5) {
                                  textPainter.text = TextSpan(
                                    text: branchName,
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: size,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                  textPainter.layout(maxWidth: double.infinity);

                                  if (textPainter.width <= constraints.maxWidth) {
                                    fontSize = size;
                                    break;
                                  }
                                }

                                // 폰트 크기만으로 부족하면 자간도 줄임 (최대 -2.0까지)
                                if (textPainter.width > constraints.maxWidth) {
                                  for (double spacing = -0.2; spacing >= -2.0; spacing -= 0.2) {
                                    textPainter.text = TextSpan(
                                      text: branchName,
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: spacing,
                                      ),
                                    );
                                    textPainter.layout(maxWidth: double.infinity);

                                    if (textPainter.width <= constraints.maxWidth) {
                                      letterSpacing = spacing;
                                      break;
                                    }
                                  }
                                }
                              }

                              return Text(
                                branchName,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF1E293B),
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: letterSpacing,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              );
                            },
                          ),
                          SizedBox(height: 2.0),
                          Text(
                            _buildGreetingText(),
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Color(0xFF64748B),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isCollapsed = !_isCollapsed;
                      });
                    },
                    icon: Icon(
                      _isCollapsed ? Icons.menu : Icons.menu_open,
                      color: Color(0xFF64748B),
                      size: 24.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 메뉴 영역
          Expanded(
            child: Column(
              children: [
                // 스크롤 가능한 메뉴 영역
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            icon: Icons.dashboard_outlined,
                            title: '공유사항',
                            onTap: () {
                              SessionManager.instance.updateActivity();
                              widget.onNavigate?.call('crm1_board');
                            },
                            menuKey: 'crm1_board',
                          ),
                          // 회원관리 - member_page 권한 체크
                          if (ApiService.hasPermission('member_page')) ...[
                            _buildExpandableMenuItem(
                              icon: Icons.people_outline,
                              title: '회원관리',
                              menuKey: 'crm2_member',
                              onTap: () {
                                SessionManager.instance.updateActivity();
                                widget.onNavigate?.call('crm2_member');
                              },
                              subItems: [
                                {'title': '회원권관리', 'tab': 0},
                                {'title': '고객통계', 'tab': 1},
                                {'title': '유효기간관리', 'tab': 2},
                              ],
                            ),
                          ],
                          // 커뮤니케이션 - communication 권한 체크
                          if (ApiService.hasPermission('communication')) ...[
                            _buildExpandableMenuItemWithBadge(
                              icon: Icons.send_outlined,
                              title: '커뮤니케이션',
                              menuKey: 'crm7_communication',
                              onTap: () => widget.onNavigate?.call('crm7_communication'),
                              subItems: [
                                {'title': '1:1 채팅', 'tab': 0},
                                {'title': '1:1채팅 일괄발송', 'tab': 1},
                                {'title': '공지사항', 'tab': 2},
                                {'title': '고객게시판', 'tab': 3},
                              ],
                            ),
                          ],
                          // 타석관리 - ts_management 권한 체크
                          if (ApiService.hasPermission('ts_management')) ...[
                            _buildMenuItem(
                              icon: Icons.sports_golf_outlined,
                              title: '타석관리',
                              onTap: () => widget.onNavigate?.call('crm3_ts'),
                              menuKey: 'crm3_ts',
                            ),
                          ],
                          _buildMenuItem(
                            icon: Icons.school_outlined,
                            title: '레슨현황',
                            onTap: () => widget.onNavigate?.call('crm4_lesson'),
                            menuKey: 'crm4_lesson',
                          ),
                          _buildExpandableMenuItem(
                            icon: Icons.badge_outlined,
                            title: '인사관리',
                            menuKey: 'crm5_hr',
                            onTap: () => widget.onNavigate?.call('crm5_hr'),
                            subItems: _getHrManagementSubItems(),
                          ),
                          // 락커관리 - locker 권한 체크
                          if (ApiService.hasPermission('locker')) ...[
                            _buildMenuItem(
                              icon: Icons.lock_outline,
                              title: '락커관리',
                              onTap: () => widget.onNavigate?.call('crm6_locker'),
                              menuKey: 'crm6_locker',
                            ),
                          ],
                          // 매장설정 - branch_settings 권한 체크
                          if (ApiService.hasPermission('branch_settings')) ...[
                            _buildExpandableMenuItem(
                              icon: Icons.settings_outlined,
                              title: '매장설정',
                              menuKey: 'crm9_setting',
                              onTap: () => widget.onNavigate?.call('crm9_setting'),
                              subItems: [
                                {'title': '타석설정', 'tab': 0},
                                {'title': '상품설정', 'tab': 1},
                                {'title': '회원권설정', 'tab': 2},
                                {'title': '운영시간', 'tab': 3},
                                {'title': '유형설정', 'tab': 4},
                                {'title': '시간별과금', 'tab': 5},
                                {'title': '할인쿠폰설정', 'tab': 6},
                                {'title': '취소규정', 'tab': 7},
                              ],
                            ),
                          ],
                          // 매장운영 - branch_operation 권한 체크
                          if (ApiService.hasPermission('branch_operation')) ...[
                            _buildExpandableMenuItem(
                              icon: Icons.store_outlined,
                              title: '매장운영',
                              menuKey: 'crm10_operation',
                              onTap: () => widget.onNavigate?.call('crm10_operation'),
                              subItems: [
                                {'title': '매출관리', 'tab': 0},
                                {'title': '시스템크레딧', 'tab': 1},
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // 하단 고정 버튼들
                Column(
                  children: [
                    // 골프 플래너 앱 버튼 - client_app 권한 체크
                    if (ApiService.getCurrentAccessSettings()?['client_app'] == '허용') ...[
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: Tooltip(
                            message: _isCollapsed ? '골프 플래너 앱' : '',
                            waitDuration: Duration(milliseconds: 500),
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => PlannerAppPopup(),
                                );
                              },
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _isCollapsed ? 12.0 : 16.0,
                                  vertical: 12.0
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 8.0,
                                      color: Color(0xFF3B82F6).withOpacity(0.25),
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.phone_android,
                                      color: Colors.white,
                                      size: 24.0,
                                    ),
                                    if (!_isCollapsed) ...[
                                      SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                          '골프 플래너 앱',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Colors.white,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 내 계정 버튼
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: Tooltip(
                          message: _isCollapsed ? '내 계정' : '',
                          waitDuration: Duration(milliseconds: 500),
                          child: InkWell(
                            onTap: () {
                              final currentUser = ApiService.getCurrentUser();
                              final staffAccessId = currentUser?['staff_access_id'];

                              if (staffAccessId != null) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (context) => ChangePasswordWidget(
                                    staffAccessId: staffAccessId,
                                    isInitialPasswordChange: false,
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(12.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isCollapsed ? 12.0 : 16.0,
                                vertical: 12.0
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF64748B),
                                    size: 24.0,
                                  ),
                                  if (!_isCollapsed) ...[
                                    SizedBox(width: 12.0),
                                    Expanded(
                                      child: Text(
                                        '내 계정',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF1E293B),
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 로그아웃 버튼
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: Tooltip(
                          message: _isCollapsed ? '로그아웃' : '',
                          waitDuration: Duration(milliseconds: 500),
                          child: InkWell(
                            onTap: _handleLogout,
                            borderRadius: BorderRadius.circular(12.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout_outlined,
                                    color: Color(0xFFEF4444),
                                    size: 24.0,
                                  ),
                                  if (!_isCollapsed) ...[
                                    SizedBox(width: 16.0),
                                    Expanded(
                                      child: Text(
                                        '로그아웃',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFFEF4444),
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    // 세션 타이머 표시
                                    StreamBuilder<String>(
                                      stream: SessionManager.instance.timerStream,
                                      builder: (context, snapshot) {
                                        if (!SessionManager.instance.isSessionActive) {
                                          return SizedBox.shrink();
                                        }

                                        final timeText = snapshot.data ?? '20:00';
                                        final timeparts = timeText.split(':');
                                        final minutes = int.tryParse(timeparts[0]) ?? 20;

                                        // 5분 이하일 때 색상 변경
                                        final isLowTime = minutes <= 5;

                                        return Text(
                                          timeText,
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: isLowTime ? Color(0xFFEF4444) : Color(0xFF9CA3AF),
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: [ui.FontFeature.tabularFigures()],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? menuKey,
  }) {
    // 현재 페이지와 일치하는지 확인
    final isSelected = menuKey != null && widget.currentPage == menuKey;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: _isCollapsed ? title : '',
          waitDuration: Duration(milliseconds: 500),
          child: InkWell(
            onTap: () {
              SessionManager.instance.updateActivity();
              onTap();
            },
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: isSelected ? Color(0xFFF1F5F9) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Color(0xFF3B82F6) : Color(0xFF64748B),
                    size: 24.0,
                  ),
                  if (!_isCollapsed) ...[
                    SizedBox(width: 16.0),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          color: isSelected ? Color(0xFF3B82F6) : Color(0xFF1E293B),
                          fontSize: 16.0,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required IconData icon,
    required String title,
    required String menuKey,
    required VoidCallback onTap,
    required List<Map<String, dynamic>> subItems,
  }) {
    final isExpanded = _sideBarState.isExpanded(menuKey);
    // 현재 페이지와 일치하는지 확인
    final isSelected = widget.currentPage == menuKey;
    // 선택되었거나 확장된 경우 하이라이트
    final isHighlighted = isSelected || isExpanded;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: _isCollapsed ? title : '',
              waitDuration: Duration(milliseconds: 500),
              child: InkWell(
                onTap: () {
                  SessionManager.instance.updateActivity();
                  // 축소 모드일 때는 첫 번째 서브메뉴로 바로 이동
                  if (_isCollapsed && subItems.isNotEmpty) {
                    widget.onNavigate?.call('$menuKey?tab=${subItems[0]['tab']}');
                  } else {
                    // 확장 모드일 때는 기존대로 메인 페이지로 이동
                    onTap();
                  }
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: isHighlighted ? Color(0xFFF1F5F9) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: isHighlighted ? Color(0xFF3B82F6) : Color(0xFF64748B),
                        size: 24.0,
                      ),
                      if (!_isCollapsed) ...[
                        SizedBox(width: 16.0),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: isHighlighted ? Color(0xFF3B82F6) : Color(0xFF1E293B),
                              fontSize: 16.0,
                              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                // 한번에 하나의 메뉴만 펼쳐지도록
                                if (!isExpanded) {
                                  _sideBarState.clearAll();
                                  _sideBarState.setExpanded(menuKey, true);
                                } else {
                                  _sideBarState.setExpanded(menuKey, false);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(20.0),
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more,
                                  color: isHighlighted ? Color(0xFF3B82F6) : Color(0xFF64748B),
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: isExpanded && !_isCollapsed ? null : 0,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: 200),
            opacity: isExpanded && !_isCollapsed ? 1.0 : 0.0,
            child: Column(
              children: subItems.map((item) => _buildSubMenuItem(
                title: item['title'],
                onTap: () => widget.onNavigate?.call('$menuKey?tab=${item['tab']}'),
                menuKey: menuKey,
                tabIndex: item['tab'],
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableMenuItemWithBadge({
    required IconData icon,
    required String title,
    required String menuKey,
    required VoidCallback onTap,
    required List<Map<String, dynamic>> subItems,
  }) {
    final isExpanded = _sideBarState.isExpanded(menuKey);
    // 현재 페이지와 일치하는지 확인
    final isSelected = widget.currentPage == menuKey;
    // 선택되었거나 확장된 경우 하이라이트
    final isHighlighted = isSelected || isExpanded;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: _isCollapsed ? title : '',
              waitDuration: Duration(milliseconds: 500),
              child: InkWell(
                onTap: () {
                  SessionManager.instance.updateActivity();
                  // 축소 모드일 때는 첫 번째 서브메뉴로 바로 이동
                  if (_isCollapsed && subItems.isNotEmpty) {
                    widget.onNavigate?.call('$menuKey?tab=${subItems[0]['tab']}');
                  } else {
                    // 확장 모드일 때는 기존대로 메인 페이지로 이동
                    onTap();
                  }
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: isHighlighted ? Color(0xFFF1F5F9) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Icon(
                            icon,
                            color: isHighlighted ? Color(0xFF3B82F6) : Color(0xFF64748B),
                            size: 24.0,
                          ),
                          StreamBuilder<int>(
                            stream: ChatService.getUnreadMessageCountStream(),
                            builder: (context, snapshot) {
                              final unreadCount = snapshot.data ?? 0;
                              if (unreadCount <= 0) return SizedBox.shrink();

                              return Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    if (!_isCollapsed) ...[
                      SizedBox(width: 16.0),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: isHighlighted ? Color(0xFF3B82F6) : Color(0xFF1E293B),
                            fontSize: 16.0,
                            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: ChatService.getUnreadMessageCountStream(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          if (unreadCount <= 0) {
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    // 한번에 하나의 메뉴만 펼쳐지도록
                                    if (!isExpanded) {
                                      _sideBarState.clearAll();
                                      _sideBarState.setExpanded(menuKey, true);
                                    } else {
                                      _sideBarState.setExpanded(menuKey, false);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(20.0),
                                child: Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration: Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.expand_more,
                                      color: isHighlighted ? Color(0xFF3B82F6) : Color(0xFF64748B),
                                      size: 20.0,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          return Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.0),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      // 한번에 하나의 메뉴만 펼쳐지도록
                                      if (!isExpanded) {
                                        _sideBarState.clearAll();
                                        _sideBarState.setExpanded(menuKey, true);
                                      } else {
                                        _sideBarState.setExpanded(menuKey, false);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20.0),
                                  child: Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0,
                                      duration: Duration(milliseconds: 200),
                                      child: Icon(
                                        Icons.expand_more,
                                        color: isExpanded ? Color(0xFF3B82F6) : Color(0xFF64748B),
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: isExpanded && !_isCollapsed ? null : 0,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: 200),
            opacity: isExpanded && !_isCollapsed ? 1.0 : 0.0,
            child: Column(
              children: subItems.map((item) => _buildSubMenuItem(
                title: item['title'],
                onTap: () => widget.onNavigate?.call('$menuKey?tab=${item['tab']}'),
                menuKey: menuKey,
                tabIndex: item['tab'],
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubMenuItem({
    required String title,
    required VoidCallback onTap,
    String? menuKey,
    int? tabIndex,
  }) {
    // 현재 페이지와 탭이 모두 일치하는지 확인
    final isSelected = menuKey != null &&
                       tabIndex != null &&
                       widget.currentPage == menuKey &&
                       widget.currentTab == tabIndex;

    return Container(
      margin: EdgeInsets.only(left: 24.0, right: 8.0, top: 1.0, bottom: 1.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          hoverColor: Color(0xFFF1F5F9),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              color: isSelected ? Color(0xFFEFF6FF) : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  width: 4.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF3B82F6) : Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: isSelected ? Color(0xFF3B82F6) : Color(0xFF64748B),
                      fontSize: 14.0,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemWithBadge({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Icon(
                      icon,
                      color: Color(0xFF64748B),
                      size: 24.0,
                    ),
                    StreamBuilder<int>(
                      stream: ChatService.getUnreadMessageCountStream(),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        if (unreadCount <= 0) return SizedBox.shrink();
                        
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (!_isCollapsed) ...[
                  SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: Color(0xFF1E293B),
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: ChatService.getUnreadMessageCountStream(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount <= 0) return SizedBox.shrink();
                      
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
