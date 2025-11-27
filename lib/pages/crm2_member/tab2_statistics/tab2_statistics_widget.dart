import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import '/services/tab_design_upper.dart';
import 'tab2_statistics_model.dart';
import 'pages/ts_usage_ranking_page.dart';
import 'pages/lesson_usage_ranking_page.dart';
export 'tab2_statistics_model.dart';

class Tab2StatisticsWidget extends StatefulWidget {
  const Tab2StatisticsWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab2StatisticsWidget> createState() => _Tab2StatisticsWidgetState();
}

class _Tab2StatisticsWidgetState extends State<Tab2StatisticsWidget> with SingleTickerProviderStateMixin {
  late Tab2StatisticsModel _model;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab2StatisticsModel());
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 탭 바
        TabDesignUpper.buildCompleteTabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '레슨이용순위'),
            Tab(text: '타석이용순위'),
          ],
          themeNumber: 1,
          size: 'medium',
          isScrollable: true,
          hasTopRadius: false,
        ),
        SizedBox(height: 16),

        // 탭 컨텐츠
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 레슨이용순위 탭
              LessonUsageRankingPage(),

              // 타석이용순위 탭
              TsUsageRankingPage(),
            ],
          ),
        ),
      ],
    );
  }
}
