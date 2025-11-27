import 'package:flutter/material.dart';

class Tab8SystemCreditWidget extends StatefulWidget {
  const Tab8SystemCreditWidget({super.key});

  @override
  State<Tab8SystemCreditWidget> createState() => _Tab8SystemCreditWidgetState();
}

class _Tab8SystemCreditWidgetState extends State<Tab8SystemCreditWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시스템 크레딧',
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF1E293B),
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
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
                  '크레딧 시스템 설정',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF374151),
                    fontSize: 16.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12.0),
                Text(
                  '• 크레딧 환율 설정\n• 크레딧 적립 정책\n• 크레딧 사용 규칙\n• 크레딧 만료 정책',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF64748B),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
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