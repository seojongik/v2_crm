import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import '/constants/font_sizes.dart';
import 'tab3_pro_schedule_model.dart';
import 'tab11_lesson_hours.dart';
export 'tab3_pro_schedule_model.dart';

class Tab3ProScheduleWidget extends StatefulWidget {
  const Tab3ProScheduleWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab3ProScheduleWidget> createState() => _Tab3ProScheduleWidgetState();
}

class _Tab3ProScheduleWidgetState extends State<Tab3ProScheduleWidget> {
  late Tab3ProScheduleModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab3ProScheduleModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tab11LessonHoursWidget();
  }
}