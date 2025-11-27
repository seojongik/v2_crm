import '/components/side_bar_nav/side_bar_nav_model.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'crm2_member_widget.dart' show Crm2MemberWidget;
import 'package:flutter/material.dart';

class Crm2MemberModel extends FlutterFlowModel<Crm2MemberWidget> {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();
  // Model for SideBarNav component.
  late SideBarNavModel sideBarNavModel;
  
  // 전역 탭 상태 관리
  static String? selectedTabGlobal;

  @override
  void initState(BuildContext context) {
    sideBarNavModel = createModel(context, () => SideBarNavModel());
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
  }
}