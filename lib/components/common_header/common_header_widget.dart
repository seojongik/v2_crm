import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'common_header_model.dart';
export 'common_header_model.dart';

class CommonHeaderWidget extends StatefulWidget {
  const CommonHeaderWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonIcon,
    this.onButtonPressed,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final IconData buttonIcon;
  final VoidCallback? onButtonPressed;

  @override
  State<CommonHeaderWidget> createState() => _CommonHeaderWidgetState();
}

class _CommonHeaderWidgetState extends State<CommonHeaderWidget> {
  late CommonHeaderModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CommonHeaderModel());
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(32.0, 32.0, 32.0, 32.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF0F172A),
                      fontSize: 32.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                    child: Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: Color(0xFF64748B),
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (responsiveVisibility(
              context: context,
              phone: false,
            ))
              FFButtonWidget(
                onPressed: widget.onButtonPressed,
                text: widget.buttonText,
                icon: Icon(
                  widget.buttonIcon,
                  size: 18.0,
                  color: Colors.white,
                ),
                options: FFButtonOptions(
                  height: 48.0,
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
                  color: Color(0xFF3B82F6),
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Colors.white,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  elevation: 0.0,
                  borderRadius: BorderRadius.circular(12.0),
                  hoverColor: Color(0xFF2563EB),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 