import 'package:flutter/material.dart';
import '../../../constants/font_sizes.dart';

class Tab3ProductSettingWidget extends StatefulWidget {
  const Tab3ProductSettingWidget({super.key});

  @override
  State<Tab3ProductSettingWidget> createState() => _Tab3ProductSettingWidgetState();
}

class _Tab3ProductSettingWidgetState extends State<Tab3ProductSettingWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상품 설정',
            style: AppTextStyles.h3.copyWith(
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 16.0),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상품 관리 설정',
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 12.0),
                Text(
                  '• 상품 카테고리 관리\n• 상품 가격 설정\n• 할인 정책 관리\n• 상품 재고 관리',
                  style: AppTextStyles.modalBody.copyWith(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 