import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/components/common_tag_filter/common_tag_filter_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/tab_design_upper.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../constants/font_sizes.dart';
import '../../constants/ui_constants.dart';
import 'crm7_communication_model.dart';
export 'crm7_communication_model.dart';

// 서브메뉴 위젯들 import
import 'sub_menu/tab1_notice.dart';
import 'sub_menu/tab2_customer_board.dart';
import 'sub_menu/tab3_message_send.dart';
import 'sub_menu/tab4_chatting.dart';

class Crm7CommunicationWidget extends StatefulWidget {
  const Crm7CommunicationWidget({super.key, this.onNavigate, this.initialTab, this.tabIndex});

  final Function(String)? onNavigate;
  final String? initialTab;
  final int? tabIndex;

  static String routeName = 'crm7_communication';
  static String routePath = 'crm7Communication';

  @override
  State<Crm7CommunicationWidget> createState() =>
      _Crm7CommunicationWidgetState();
}

class _Crm7CommunicationWidgetState extends State<Crm7CommunicationWidget>
    with TickerProviderStateMixin {
  late Crm7CommunicationModel _model;
  TabController? _tabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm7CommunicationModel());

    // 초기 탭 인덱스 결정
    int initialIndex = 0;
    if (widget.tabIndex != null) {
      if (widget.tabIndex! >= 0 && widget.tabIndex! < 4) {
        initialIndex = widget.tabIndex!;
        print('CRM7 Communication - Tab Index: ${widget.tabIndex}');
      }
    } else if (widget.initialTab != null) {
      const tabs = ['1:1 채팅', '1:1채팅 일괄발송', '공지사항', '고객게시판'];
      initialIndex = tabs.indexOf(widget.initialTab!) != -1 ? tabs.indexOf(widget.initialTab!) : 0;
    }

    // TabController 초기화
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );

    animationsMap.addAll({
      'containerOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: Offset(30.0, 0.0),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
      'containerOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: Offset(30.0, 0.0),
            end: Offset(0.0, 0.0),
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
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
                  currentPage: 'crm7_communication',
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
                            // 탭바 섹션 - large 사이즈, 테마 3번(네이비 블루) (컨테이너 밖)
                            TabDesignUpper.buildStyledTabBar(
                              controller: _tabController!,
                              themeNumber: 3,
                              size: 'large',
                              tabs: [
                                TabDesignUpper.buildTabItem(Icons.chat_bubble_outline, '1:1 채팅', size: 'large'),
                                TabDesignUpper.buildTabItem(Icons.send, '1:1채팅 일괄발송', size: 'large'),
                                TabDesignUpper.buildTabItem(Icons.campaign, '공지사항', size: 'large'),
                                TabDesignUpper.buildTabItem(Icons.forum, '고객게시판', size: 'large'),
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
                                    Tab4ChattingWidget(),
                                    Tab3MessageSendWidget(),
                                    Tab1NoticeWidget(),
                                    Tab2CustomerBoardWidget(),
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
