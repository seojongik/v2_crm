import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '/constants/font_sizes.dart';

// 권종별 색상 테마 정의
class BenefitTypeTheme {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color border;
  final IconData icon;
  final String name;

  const BenefitTypeTheme({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.border,
    required this.icon,
    required this.name,
  });

  static BenefitTypeTheme getTheme(String benefitType) {
    // 모든 권종을 레슨권 색상(파란색+하늘색)으로 통일
    const unifiedTheme = BenefitTypeTheme(
      primary: Color(0xFF2563EB),
      secondary: Color(0xFFDBEAFE),
      background: Color(0xFFEFF6FF),
      border: Color(0xFFBFDBFE),
      icon: Icons.help_outline, // 아이콘은 각 권종별로 다르게 설정
      name: '',
    );

    switch (benefitType) {
      case 'credit':
        return BenefitTypeTheme(
          primary: unifiedTheme.primary,
          secondary: unifiedTheme.secondary,
          background: unifiedTheme.background,
          border: unifiedTheme.border,
          icon: Icons.monetization_on,
          name: '크레딧',
        );
      case 'time':
        return BenefitTypeTheme(
          primary: unifiedTheme.primary,
          secondary: unifiedTheme.secondary,
          background: unifiedTheme.background,
          border: unifiedTheme.border,
          icon: Icons.sports_golf,
          name: '타석시간',
        );
      case 'game':
        return BenefitTypeTheme(
          primary: unifiedTheme.primary,
          secondary: unifiedTheme.secondary,
          background: unifiedTheme.background,
          border: unifiedTheme.border,
          icon: Icons.sports_esports,
          name: '스크린게임',
        );
      case 'lesson':
        return BenefitTypeTheme(
          primary: unifiedTheme.primary,
          secondary: unifiedTheme.secondary,
          background: unifiedTheme.background,
          border: unifiedTheme.border,
          icon: Icons.school,
          name: '레슨권',
        );
      case 'term':
        return BenefitTypeTheme(
          primary: unifiedTheme.primary,
          secondary: unifiedTheme.secondary,
          background: unifiedTheme.background,
          border: unifiedTheme.border,
          icon: Icons.calendar_month,
          name: '기간권',
        );
      default:
        return BenefitTypeTheme(
          primary: unifiedTheme.primary,
          secondary: unifiedTheme.secondary,
          background: unifiedTheme.background,
          border: unifiedTheme.border,
          icon: Icons.help_outline,
          name: '기타',
        );
    }
  }
}

// 통일된 다이얼로그 베이스 클래스
class BaseContractDialog extends StatefulWidget {
  final String benefitType;
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  const BaseContractDialog({
    Key? key,
    required this.benefitType,
    required this.title,
    required this.child,
    this.actions,
    this.onClose,
  }) : super(key: key);

  @override
  State<BaseContractDialog> createState() => _BaseContractDialogState();
}

class _BaseContractDialogState extends State<BaseContractDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BenefitTypeTheme.getTheme(widget.benefitType);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: theme.border, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              theme.icon,
                              color: theme.primary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 컨텐츠
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: widget.child,
                      ),
                    ),
                    
                    // 액션 버튼들
                    if (widget.actions != null) ...[
                      Padding(
                        padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Row(
                          children: widget.actions!,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// 통일된 입력 필드
class ContractInputField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool isRequired;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final bool enabled;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const ContractInputField({
    Key? key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.isRequired = false,
    this.keyboardType,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
          enabled: true,  // 항상 활성화
          readOnly: !enabled,  // enabled가 false면 읽기 전용
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            hintStyle: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// 통일된 선택 버튼
class ContractSelectionButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final String benefitType;

  const ContractSelectionButton({
    Key? key,
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.benefitType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 선택 버튼도 파란색 계열로 통일
    const selectedColor = Color(0xFF2563EB); // 파란색
    const unselectedColor = Colors.white;
    const borderColor = Color(0xFFE2E8F0);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          border: Border.all(
            color: isSelected ? selectedColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: AppTextStyles.button.copyWith(
              color: isSelected ? Colors.white : Color(0xFF2563EB),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// 통일된 액션 버튼
class ContractActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final String benefitType;
  final bool isSecondary;
  final bool isLoading;

  const ContractActionButton({
    Key? key,
    required this.text,
    this.onPressed,
    required this.benefitType,
    this.isSecondary = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 팝업 버튼들은 파란색 계열로 통일
    const primaryButtonColor = Color(0xFF2563EB); // 파란색
    const secondaryButtonColor = Colors.white;
    const secondaryTextColor = Color(0xFF6B7280); // 중간 회색
    
    return Expanded(
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? secondaryButtonColor : primaryButtonColor,
          foregroundColor: isSecondary ? secondaryTextColor : Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isSecondary 
              ? BorderSide(color: Color(0xFFE2E8F0)) 
              : BorderSide.none,
          ),
        ),
        child: isLoading 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSecondary ? primaryButtonColor : Colors.white,
                ),
              ),
            )
          : Text(
              text,
              style: AppTextStyles.button.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
      ),
    );
  }
}

// 통일된 정보 카드
class ContractInfoCard extends StatelessWidget {
  final String title;
  final String content;
  final String benefitType;
  final IconData? icon;

  const ContractInfoCard({
    Key? key,
    required this.title,
    required this.content,
    required this.benefitType,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = BenefitTypeTheme.getTheme(benefitType);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: theme.primary),
                SizedBox(width: 8),
              ],
              Text(
                title,
                style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.h4.copyWith(
              fontSize: 18,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

// 유틸리티 함수들
class ContractUtils {
  static String formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount)}원';
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy년 MM월 dd일').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}