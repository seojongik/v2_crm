import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'common_button_model.dart';
export 'common_button_model.dart';

enum ButtonVariant { primary, secondary, outline, ghost, danger }
enum ButtonSize { small, medium, large }

class CommonButtonWidget extends StatefulWidget {
  const CommonButtonWidget({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final bool fullWidth;

  @override
  State<CommonButtonWidget> createState() => _CommonButtonWidgetState();
}

class _CommonButtonWidgetState extends State<CommonButtonWidget> {
  late CommonButtonModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CommonButtonModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  double get _height {
    switch (widget.size) {
      case ButtonSize.small:
        return 36.0;
      case ButtonSize.medium:
        return 44.0;
      case ButtonSize.large:
        return 52.0;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 13.0;
      case ButtonSize.medium:
        return 15.0;
      case ButtonSize.large:
        return 16.0;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 16.0;
      case ButtonSize.medium:
        return 18.0;
      case ButtonSize.large:
        return 20.0;
    }
  }

  EdgeInsetsDirectional get _padding {
    switch (widget.size) {
      case ButtonSize.small:
        return EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0);
      case ButtonSize.medium:
        return EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0);
      case ButtonSize.large:
        return EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0);
    }
  }

  Color get _backgroundColor {
    if (widget.isDisabled) return Color(0xFFF1F5F9);
    
    switch (widget.variant) {
      case ButtonVariant.primary:
        return Color(0xFF3B82F6);
      case ButtonVariant.secondary:
        return Color(0xFF64748B);
      case ButtonVariant.outline:
        return Colors.transparent;
      case ButtonVariant.ghost:
        return Colors.transparent;
      case ButtonVariant.danger:
        return Color(0xFFEF4444);
    }
  }

  Color get _textColor {
    if (widget.isDisabled) return Color(0xFF94A3B8);
    
    switch (widget.variant) {
      case ButtonVariant.primary:
      case ButtonVariant.secondary:
      case ButtonVariant.danger:
        return Colors.white;
      case ButtonVariant.outline:
        return Color(0xFF3B82F6);
      case ButtonVariant.ghost:
        return Color(0xFF64748B);
    }
  }

  Color get _borderColor {
    if (widget.isDisabled) return Color(0xFFE2E8F0);
    
    switch (widget.variant) {
      case ButtonVariant.outline:
        return Color(0xFF3B82F6);
      default:
        return Colors.transparent;
    }
  }

  Color get _hoverColor {
    if (widget.isDisabled) return Color(0xFFF1F5F9);
    
    switch (widget.variant) {
      case ButtonVariant.primary:
        return Color(0xFF2563EB);
      case ButtonVariant.secondary:
        return Color(0xFF475569);
      case ButtonVariant.outline:
        return Color(0xFFF8FAFC);
      case ButtonVariant.ghost:
        return Color(0xFFF8FAFC);
      case ButtonVariant.danger:
        return Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FFButtonWidget(
      onPressed: (widget.isDisabled || widget.isLoading) ? null : widget.onPressed,
      text: widget.isLoading ? '' : widget.text,
      icon: widget.isLoading
          ? SizedBox(
              width: _iconSize,
              height: _iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(_textColor),
              ),
            )
          : widget.icon != null
              ? Icon(
                  widget.icon,
                  size: _iconSize,
                  color: _textColor,
                )
              : null,
      showLoadingIndicator: false,
      options: FFButtonOptions(
        width: widget.fullWidth ? double.infinity : null,
        height: _height,
        padding: _padding,
        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
        color: _backgroundColor,
        textStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: _textColor,
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        elevation: 0.0,
        borderSide: BorderSide(
          color: _borderColor,
          width: widget.variant == ButtonVariant.outline ? 1.0 : 0.0,
        ),
        borderRadius: BorderRadius.circular(12.0),
        hoverColor: _hoverColor,
      ),
    );
  }
} 