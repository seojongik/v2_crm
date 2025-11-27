import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import '/constants/font_sizes.dart';
import 'tab4_staff_pro_register_model.dart';
import 'tab2_staff_management_tab.dart';
export 'tab4_staff_pro_register_model.dart';

class Tab4StaffProRegisterWidget extends StatefulWidget {
  const Tab4StaffProRegisterWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab4StaffProRegisterWidget> createState() => _Tab4StaffProRegisterWidgetState();
}

class _Tab4StaffProRegisterWidgetState extends State<Tab4StaffProRegisterWidget> {
  late Tab4StaffProRegisterModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab4StaffProRegisterModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tab2StaffManagementTab();
  }
}