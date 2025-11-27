import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import '/constants/font_sizes.dart';
import 'tab2_staff_schedule_model.dart';
import 'tab9_manager_hours.dart';
export 'tab2_staff_schedule_model.dart';

class Tab2StaffScheduleWidget extends StatefulWidget {
  const Tab2StaffScheduleWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab2StaffScheduleWidget> createState() => _Tab2StaffScheduleWidgetState();
}

class _Tab2StaffScheduleWidgetState extends State<Tab2StaffScheduleWidget> {
  late Tab2StaffScheduleModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab2StaffScheduleModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tab9ManagerHoursWidget();
  }
}