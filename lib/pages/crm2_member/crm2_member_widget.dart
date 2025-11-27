import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/components/common_tag_filter/common_tag_filter_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/tab_design_upper.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../../constants/font_sizes.dart';
import '../../constants/ui_constants.dart';
import 'crm2_member_model.dart';
export 'crm2_member_model.dart';

// 서브메뉴 위젯들 import
import 'tab1_membership/tab1_membership_widget.dart';
import 'tab2_statistics/tab2_statistics_widget.dart';
import 'tab3_expiry/tab3_expiry_widget.dart';

class Crm2MemberWidget extends StatefulWidget {
  const Crm2MemberWidget({super.key, this.onNavigate, this.initialTab, this.tabIndex});

  final Function(String)? onNavigate;
  final String? initialTab;
  final int? tabIndex;

  static String routeName = 'crm2_member';
  static String routePath = 'crmMember';

  @override
  State<Crm2MemberWidget> createState() => _Crm2MemberWidgetState();
}

class _Crm2MemberWidgetState extends State<Crm2MemberWidget>
    with TickerProviderStateMixin {
  late Crm2MemberModel _model;
  TabController? _tabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm2MemberModel());

    // 초기 탭 인덱스 결정
    int initialIndex = 0;
    if (widget.tabIndex != null) {
      if (widget.tabIndex! >= 0 && widget.tabIndex! < 3) {
        initialIndex = widget.tabIndex!;
        print('CRM2 Member - Tab Index: ${widget.tabIndex}');
      }
    } else if (widget.initialTab != null) {
      const tabs = ['회원권관리', '고객통계', '유효기간관리'];
      initialIndex = tabs.indexOf(widget.initialTab!) != -1 ? tabs.indexOf(widget.initialTab!) : 0;
    } else if (Crm2MemberModel.selectedTabGlobal != null) {
      const tabs = ['회원권관리', '고객통계', '유효기간관리'];
      initialIndex = tabs.indexOf(Crm2MemberModel.selectedTabGlobal!) != -1
          ? tabs.indexOf(Crm2MemberModel.selectedTabGlobal!)
          : 0;
      Crm2MemberModel.selectedTabGlobal = null; // 사용 후 초기화
    }

    // TabController 초기화
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _model.dispose();
    super.dispose();
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
                  currentPage: 'crm2_member',
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
                              tabs: [
                                TabDesignUpper.buildTabItem(Icons.card_membership, '회원권관리', size: 'large'),
                                TabDesignUpper.buildTabItem(Icons.bar_chart, '고객통계', size: 'large'),
                                TabDesignUpper.buildTabItem(Icons.event_available, '유효기간관리', size: 'large'),
                              ],
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
                                  children: [
                                    Tab1MembershipWidget(onNavigate: widget.onNavigate),
                                    Tab2StatisticsWidget(onNavigate: widget.onNavigate),
                                    Tab3ExpiryWidget(onNavigate: widget.onNavigate),
                                  ],
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