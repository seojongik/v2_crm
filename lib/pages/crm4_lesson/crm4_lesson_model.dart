import '/components/card09_order_card_widget.dart';
import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'crm4_lesson_widget.dart' show Crm4LessonWidget;
import 'package:flutter/material.dart';

class Crm4LessonModel extends FlutterFlowModel<Crm4LessonWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;
  // Model for Card09OrderCard component.
  late Card09OrderCardModel card09OrderCardModel1;
  // Model for Card09OrderCard component.
  late Card09OrderCardModel card09OrderCardModel2;
  // Model for Card09OrderCard component.
  late Card09OrderCardModel card09OrderCardModel3;

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {
    sideBarNavModel = createModel(context, () => SideBarNavModel());
    card09OrderCardModel1 = createModel(context, () => Card09OrderCardModel());
    card09OrderCardModel2 = createModel(context, () => Card09OrderCardModel());
    card09OrderCardModel3 = createModel(context, () => Card09OrderCardModel());
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
    card09OrderCardModel1.dispose();
    card09OrderCardModel2.dispose();
    card09OrderCardModel3.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
