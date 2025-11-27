import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'crm7_communication_widget.dart' show Crm7CommunicationWidget;
import 'package:flutter/material.dart';

class Crm7CommunicationModel extends FlutterFlowModel<Crm7CommunicationWidget> {
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
