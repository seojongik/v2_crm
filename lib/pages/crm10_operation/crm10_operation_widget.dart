import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/components/common_tag_filter/common_tag_filter_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/tab_design_upper.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../../constants/ui_constants.dart';
import 'crm10_operation_model.dart';
export 'crm10_operation_model.dart';

// 서브메뉴 위젯들 import
import 'sub_menu/tab5_sales.dart';
import 'sub_menu/tab8_system_credit.dart';
import 'sub_menu/tab9_online_settlement.dart';

class Crm10OperationWidget extends StatefulWidget {
  const Crm10OperationWidget({super.key, this.onNavigate, this.initialTab, this.tabIndex});

  final Function(String)? onNavigate;
  final String? initialTab;
  final int? tabIndex;

  static String routeName = 'crm10_operation';
  static String routePath = 'crm10Operation';

  @override
  State<Crm10OperationWidget> createState() => _Crm10OperationWidgetState();
}

class _Crm10OperationWidgetState extends State<Crm10OperationWidget>
    with TickerProviderStateMixin {
  late Crm10OperationModel _model;
  TabController? _tabController;
  final List<String> _tabs = ['매출관리', '시스템크레딧', '온라인정산'];

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm10OperationModel());

    // 초기 탭 인덱스 결정
    int initialIndex = 0;
    if (widget.tabIndex != null) {
      if (widget.tabIndex! >= 0 && widget.tabIndex! < _tabs.length) {
        initialIndex = widget.tabIndex!;
        print('CRM10 Operation - Tab Index: ${widget.tabIndex}');
      }
    } else if (widget.initialTab != null) {
      initialIndex = _tabs.indexOf(widget.initialTab!) != -1 ? _tabs.indexOf(widget.initialTab!) : 0;
    }

    // TabController 초기화
    _tabController = TabController(
      length: _tabs.length,
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

  // 탭 이름에 따른 아이콘 반환
  IconData _getIconForTab(String tabName) {
    switch (tabName) {
      case '매출관리':
        return Icons.payments;
      case '시스템크레딧':
        return Icons.credit_card;
      case '온라인정산':
        return Icons.account_balance;
      default:
        return Icons.business;
    }
  }

  // 탭 이름에 따른 위젯 반환
  Widget _getWidgetForTab(String tabName) {
    switch (tabName) {
      case '매출관리':
        return Tab5SalesWidget();
      case '시스템크레딧':
        return Tab8SystemCreditWidget();
      case '온라인정산':
        return Tab9OnlineSettlementWidget();
      default:
        return Tab5SalesWidget();
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
                  currentPage: 'crm10_operation',
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
                              tabs: _tabs.map((tabName) {
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
                                  children: _tabs.map((tabName) {
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