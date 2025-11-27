import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'login_widget.dart' show LoginWidget;
import 'package:flutter/material.dart';

class LoginModel extends FlutterFlowModel<LoginWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for staff_access_id widget.
  FocusNode? staffAccessIdFocusNode;
  TextEditingController? staffAccessIdTextController;
  String? Function(BuildContext, String?)? staffAccessIdTextControllerValidator;

  // State field(s) for staff_password widget.
  FocusNode? staffPasswordFocusNode;
  TextEditingController? staffPasswordTextController;
  late bool staffPasswordVisibility;
  String? Function(BuildContext, String?)? staffPasswordTextControllerValidator;

  // 로그인 상태 관리
  bool isLoading = false;
  String? errorMessage;
  
  // 로그인된 사용자 정보
  Map<String, dynamic>? loggedInUser;
  
  // 지점 선택 관련
  List<Map<String, dynamic>> availableBranches = [];
  Map<String, dynamic>? selectedBranch;

  @override
  void initState(BuildContext context) {
    staffPasswordVisibility = false;
  }

  @override
  void dispose() {
    staffAccessIdFocusNode?.dispose();
    staffAccessIdTextController?.dispose();

    staffPasswordFocusNode?.dispose();
    staffPasswordTextController?.dispose();
  }
} 