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
import 'crm9_setting_model.dart';
export 'crm9_setting_model.dart';

// 서브메뉴 위젯들 import
import 'sub_menu/tab1_ts_setting.dart';
import 'sub_menu/tab3_product_setting.dart';
import 'sub_menu/tab4_contract_setting.dart';
import 'sub_menu/tab5_operating_hours.dart';
import 'sub_menu/category_management.dart';
import 'sub_menu/tab7_ts_price.dart';
import 'sub_menu/tab10_discount_coupon_setting.dart';
import 'sub_menu/tab11_cancellation_policy.dart';

class Crm9SettingWidget extends StatefulWidget {
  const Crm9SettingWidget({super.key, this.onNavigate, this.initialTab, this.tabIndex});

  final Function(String)? onNavigate;
  final String? initialTab;
  final int? tabIndex;

  static String routeName = 'crm9_setting';
  static String routePath = 'crm9Setting';

  @override
  State<Crm9SettingWidget> createState() => _Crm9SettingWidgetState();
}

class _Crm9SettingWidgetState extends State<Crm9SettingWidget>
    with TickerProviderStateMixin {
  late Crm9SettingModel _model;
  TabController? _tabController;
  final List<String> _tabs = ['타석설정', '상품설정', '회원권설정', '운영시간', '유형설정', '시간별과금', '할인쿠폰설정', '취소규정'];

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm9SettingModel());

    // 초기 탭 인덱스 결정
    int initialIndex = 0;
    if (widget.tabIndex != null) {
      if (widget.tabIndex! >= 0 && widget.tabIndex! < _tabs.length) {
        initialIndex = widget.tabIndex!;
        print('CRM9 Setting - Tab Index: ${widget.tabIndex}');
      }
    } else if (widget.initialTab != null) {
      initialIndex = _tabs.indexOf(widget.initialTab!) != -1 ? _tabs.indexOf(widget.initialTab!) : 0;
    } else if (Crm9SettingModel.selectedTabGlobal != null) {
      initialIndex = _tabs.indexOf(Crm9SettingModel.selectedTabGlobal!) != -1
          ? _tabs.indexOf(Crm9SettingModel.selectedTabGlobal!)
          : 0;
      Crm9SettingModel.selectedTabGlobal = null; // 사용 후 초기화
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
      case '타석설정':
        return Icons.sports_golf;
      case '상품설정':
        return Icons.inventory_2;
      case '회원권설정':
        return Icons.card_membership;
      case '운영시간':
        return Icons.access_time;
      case '유형설정':
        return Icons.category;
      case '시간별과금':
        return Icons.attach_money;
      case '할인쿠폰설정':
        return Icons.discount;
      case '취소규정':
        return Icons.cancel;
      default:
        return Icons.settings;
    }
  }

  // 탭 이름에 따른 위젯 반환
  Widget _getWidgetForTab(String tabName) {
    switch (tabName) {
      case '타석설정':
        return Tab1TsSettingWidget();
      case '상품설정':
        return Tab3ProductSettingWidget();
      case '회원권설정':
        return Tab4ContractSettingWidget();
      case '운영시간':
        return Tab5OperatingHoursWidget();
      case '유형설정':
        return CategoryManagementWidget();
      case '시간별과금':
        return Tab7TsPriceWidget();
      case '할인쿠폰설정':
        return Tab10DiscountCouponSettingWidget();
      case '취소규정':
        return Tab11CancellationPolicyWidget();
      default:
        return Tab1TsSettingWidget();
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
                  currentPage: 'crm9_setting',
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
