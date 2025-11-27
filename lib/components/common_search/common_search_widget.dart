import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'common_search_model.dart';
export 'common_search_model.dart';

class CommonSearchWidget extends StatefulWidget {
  const CommonSearchWidget({
    super.key,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
    this.focusNode,
  });

  final String hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<CommonSearchWidget> createState() => _CommonSearchWidgetState();
}

class _CommonSearchWidgetState extends State<CommonSearchWidget> {
  late CommonSearchModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CommonSearchModel());
    
    if (widget.controller == null) {
      _model.textController ??= TextEditingController();
    }
    if (widget.focusNode == null) {
      _model.textFieldFocusNode ??= FocusNode();
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: TextFormField(
        controller: widget.controller ?? _model.textController,
        focusNode: widget.focusNode ?? _model.textFieldFocusNode,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        autofocus: false,
        obscureText: false,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF94A3B8),
            fontSize: 15.0,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFF3B82F6),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFFEF4444),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFFEF4444),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 16.0),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: Color(0xFF64748B),
                  size: 20.0,
                )
              : null,
          suffixIcon: widget.suffixIcon,
        ),
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF1E293B),
          fontSize: 15.0,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
        ),
        cursorColor: Color(0xFF3B82F6),
      ),
    );
  }
} 