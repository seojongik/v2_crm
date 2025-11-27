import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import '/constants/font_sizes.dart';
import 'tab1_salary_model.dart';
import 'tab6_salary.dart';
export 'tab1_salary_model.dart';

class Tab1SalaryWidget extends StatefulWidget {
  const Tab1SalaryWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab1SalaryWidget> createState() => _Tab1SalaryWidgetState();
}

class _Tab1SalaryWidgetState extends State<Tab1SalaryWidget> {
  late Tab1SalaryModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab1SalaryModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tab6SalaryWidget();
  }
}