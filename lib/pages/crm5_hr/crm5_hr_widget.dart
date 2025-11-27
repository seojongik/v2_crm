import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/components/common_tag_filter/common_tag_filter_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/tab_design_upper.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '/constants/font_sizes.dart';
import '/constants/ui_constants.dart';
import '/services/api_service.dart';
import 'crm5_hr_model.dart';
export 'crm5_hr_model.dart';

// 서브메뉴 위젯들 import
import 'tab1_salary/tab1_salary_widget.dart';
import 'tab2_staff_schedule/tab2_staff_schedule_widget.dart';
import 'tab3_pro_schedule/tab3_pro_schedule_widget.dart';
import 'tab4_staff_pro_register/tab4_staff_pro_register_widget.dart';

class Crm5HrWidget extends StatefulWidget {
  const Crm5HrWidget({super.key, this.onNavigate, this.initialTab, this.tabIndex});

  final Function(String)? onNavigate;
  final String? initialTab;
  final int? tabIndex;

  static String routeName = 'crm5_hr';
  static String routePath = 'crm5Hr';

  @override
  State<Crm5HrWidget> createState() => _Crm5HrWidgetState();
}

class _Crm5HrWidgetState extends State<Crm5HrWidget>
    with TickerProviderStateMixin {
  late Crm5HrModel _model;
  TabController? _tabController;
  List<String> availableTabs = []; // 권한에 따라 사용 가능한 탭 목록

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm5HrModel());

    // 권한에 따라 사용 가능한 탭 결정
    _initializeTabs();

    // 초기 탭 인덱스 결정
    int initialIndex = 0;
    if (widget.tabIndex != null) {
      if (widget.tabIndex! >= 0 && widget.tabIndex! < availableTabs.length) {
        initialIndex = widget.tabIndex!;
        print('CRM5 HR - Tab Index: ${widget.tabIndex}');
      }
    } else if (widget.initialTab != null) {
      initialIndex = availableTabs.indexOf(widget.initialTab!) != -1 ? availableTabs.indexOf(widget.initialTab!) : 0;
    } else if (Crm5HrModel.selectedTabGlobal != null) {
      initialIndex = availableTabs.indexOf(Crm5HrModel.selectedTabGlobal!) != -1
          ? availableTabs.indexOf(Crm5HrModel.selectedTabGlobal!)
          : 0;
      Crm5HrModel.selectedTabGlobal = null; // 사용 후 초기화
    }

    // TabController 초기화
    if (availableTabs.isNotEmpty) {
      _tabController = TabController(
        length: availableTabs.length,
        vsync: this,
        initialIndex: initialIndex,
      );
    }
  }

  // 권한에 따른 탭 초기화
  void _initializeTabs() {
    // 권한 및 역할 체크
    final hasHrPermission = ApiService.hasPermission('hr_management');
    final currentRole = ApiService.getCurrentStaffRole();
    final staffSchedulePermission = ApiService.getCurrentAccessSettings()?['staff_schedule'] ?? '전체';
    final proSchedulePermission = ApiService.getCurrentAccessSettings()?['pro_schedule'] ?? '전체';

    // 기본 탭 목록
    availableTabs = [];

    // salary_management 권한이 있을 때만 급여관리 탭 추가
    final hasSalaryManagementPermission = ApiService.hasPermission('salary_management');
    if (hasSalaryManagementPermission) {
      availableTabs.add('급여관리');
    }

    // 근무시간표 탭 처리
    if (currentRole == 'manager' || currentRole == 'admin') {
      // 매니저/관리자는 항상 근무시간표 탭 표시 (본인/전체는 탭 내부에서 처리)
      availableTabs.add('근무시간표');
    } else if (currentRole == 'pro') {
      // 프로는 staff_schedule이 '전체'일 때만 근무시간표 탭 표시
      if (staffSchedulePermission == '전체') {
        availableTabs.add('근무시간표');
      }
    }

    // 프로시간표 탭 처리
    if (currentRole == 'manager' || currentRole == 'admin') {
      // 매니저/관리자는 pro_schedule이 '전체'일 때만 프로시간표 탭 표시
      if (proSchedulePermission == '전체') {
        availableTabs.add('프로시간표');
      }
    } else if (currentRole == 'pro') {
      // 프로는 항상 프로시간표 탭 표시 (본인/전체는 탭 내부에서 처리)
      availableTabs.add('프로시간표');
    }

    // hr_management 권한이 있을 때만 직원등록 탭 추가
    if (hasHrPermission) {
      availableTabs.add('직원등록');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _model.dispose();
    super.dispose();
  }

  // 탭 이름에 따른 아이콘 반환
  IconData _getIconForTab(String tabName) {
    switch (tabName) {
      case '급여관리':
        return Icons.payments;
      case '근무시간표':
        return Icons.schedule;
      case '프로시간표':
        return Icons.calendar_today;
      case '직원등록':
        return Icons.person_add;
      default:
        return Icons.dashboard;
    }
  }

  // 탭 이름에 따른 위젯 반환
  Widget _getWidgetForTab(String tabName) {
    switch (tabName) {
      case '급여관리':
        return Tab1SalaryWidget(onNavigate: widget.onNavigate);
      case '근무시간표':
        return Tab2StaffScheduleWidget(onNavigate: widget.onNavigate);
      case '프로시간표':
        return Tab3ProScheduleWidget(onNavigate: widget.onNavigate);
      case '직원등록':
        return Tab4StaffProRegisterWidget(onNavigate: widget.onNavigate);
      default:
        return Tab2StaffScheduleWidget(onNavigate: widget.onNavigate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF8FAFC),
        body: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (responsiveVisibility(
              context: context,
              phone: false,
            ))
              wrapWithModel(
                model: _model.sideBarNavModel,
                updateCallback: () => safeSetState(() {}),
                child: SideBarNavWidget(
                  currentPage: 'crm5_hr',
                  currentTab: widget.tabIndex,
                  onNavigate: (String routeName) {
                    // 탭 파라미터 처리
                    if (routeName.contains('?tab=')) {
                      final parts = routeName.split('?tab=');
                      final baseRoute = parts[0];
                      final tabIndex = int.tryParse(parts[1]) ?? 0;
                      widget.onNavigate?.call('$baseRoute?tab=$tabIndex');
                    } else {
                      widget.onNavigate?.call(routeName);
                    }
                  },
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (responsiveVisibility(
                    context: context,
                    tabletLandscape: false,
                    desktop: false,
                  ))
                    Container(
                      width: double.infinity,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                  Expanded(
                    child: _tabController == null
                      ? Center(child: CircularProgressIndicator())
                      : Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 탭바 섹션 - 테마 3번(네이비), large 사이즈, 배경 투명
                            TabDesignUpper.buildStyledTabBar(
                              controller: _tabController!,
                              themeNumber: 3,
                              size: 'large',
                              tabs: availableTabs.map((tabName) {
                                return TabDesignUpper.buildTabItem(
                                  _getIconForTab(tabName),
                                  tabName,
                                  size: 'large',
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 16.0),
                            // 컨텐츠 영역 - 흰색 컨테이너로 감싸기
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 8.0,
                                      color: Color(0x1A000000),
                                      offset: Offset(0.0, 2.0),
                                    )
                                  ],
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: TabBarView(
                                  controller: _tabController!,
                                  children: availableTabs.map((tabName) {
                                    return _getWidgetForTab(tabName);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}