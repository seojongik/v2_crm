import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'crm9_setting_widget.dart' show Crm9SettingWidget;
import 'package:flutter/material.dart';

class Crm9SettingModel extends FlutterFlowModel<Crm9SettingWidget> {
  // 전역 변수로 선택된 탭 저장
  static String? selectedTabGlobal;
  
  ///  State fields for stateful widgets in this page.

  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;

  @override
  void initState(BuildContext context) {
    sideBarNavModel = createModel(context, () => SideBarNavModel());
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
  }
}