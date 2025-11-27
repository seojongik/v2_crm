import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/font_sizes.dart';
import '../../services/api_service.dart';
import '/models/ts_reservation.dart';

/// 타석 OTP 관련 기능을 담당하는 서비스 클래스
class TsOtpService {
  /// OTP 표시 조건 확인
  static bool shouldShowOTP(TsReservation reservation) {
    // 타석 예약만 대상 (프로그램 예약은 현재 구조상 모두 타석 관련)
    final status = reservation.tsStatus;
    final endTime = DateTime.tryParse('${reservation.tsDate} ${reservation.tsEnd}');
    
    // 취소되지 않은 예약이고, 예약 종료 시간이 현재 시간 이후인 경우
    return status != '예약취소' && 
           endTime != null && 
           endTime.isAfter(DateTime.now());
  }

  /// OTP 생성 (고객 앱과 정확히 동일한 로직)
  static String generateOTP(TsReservation reservation) {
    final now = DateTime.now();
    
    // 5분 블록 계산 (고객 앱과 동일)
    final totalMinutes = now.hour * 60 + now.minute;
    final roundedMinutes = (totalMinutes / 5).floor() * 5;
    final roundedHour = roundedMinutes ~/ 60;
    final roundedMinute = roundedMinutes % 60;
    
    final fiveMinuteBlock = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
                           '${roundedHour.toString().padLeft(2, '0')}${roundedMinute.toString().padLeft(2, '0')}';
    
    // 고객 앱과 정확히 동일한 OTP 생성 공식
    // branchId-reservationId-fiveMinuteBlock
    // reservation.branchId가 없으면 현재 로그인된 브랜치 ID 사용
    final branchId = reservation.branchId ?? ApiService.getCurrentBranchId() ?? 'test';
    final combinedString = '$branchId-${reservation.reservationId}-$fiveMinuteBlock';

    // SHA-256 해시 생성
    final bytes = utf8.encode(combinedString);
    final digest = sha256.convert(bytes);
    final hashString = digest.toString();

    // 해시값에서 숫자만 추출해서 6자리로 만들기
    final numericHash = hashString.replaceAll(RegExp(r'[^0-9]'), '');

    String otp;
    if (numericHash.length >= 6) {
      otp = numericHash.substring(0, 6);
    } else {
      // 숫자가 부족한 경우 해시값의 각 문자를 ASCII 코드의 마지막 자리로 변환
      final buffer = StringBuffer(numericHash);
      for (int i = 0; i < hashString.length && buffer.length < 6; i++) {
        final char = hashString[i];
        if (!RegExp(r'[0-9]').hasMatch(char)) {
          buffer.write(char.codeUnitAt(0) % 10);
        }
      }
      otp = buffer.toString().substring(0, 6);
    }

    // OTP 생성 디버깅 로그
    print('=== [CRM] OTP 생성 ===');
    print('branchId: $branchId');
    print('reservationId: ${reservation.reservationId}');
    print('fiveMinuteBlock: $fiveMinuteBlock');
    print('combinedString: $combinedString');
    print('생성된 OTP: $otp');
    print('====================');

    return otp;
  }
}

/// OTP 표시 위젯
class TsOtpWidget extends StatefulWidget {
  final TsReservation reservation;

  const TsOtpWidget({
    Key? key,
    required this.reservation,
  }) : super(key: key);

  @override
  State<TsOtpWidget> createState() => _TsOtpWidgetState();
}

class _TsOtpWidgetState extends State<TsOtpWidget> {
  Timer? _otpTimer;
  String _currentOTP = '';

  @override
  void initState() {
    super.initState();
    _initializeOTP();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  /// OTP 초기화 및 자동 갱신 설정
  void _initializeOTP() {
    if (TsOtpService.shouldShowOTP(widget.reservation)) {
      _generateOTP();
      // 30초마다 OTP 갱신
      _otpTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (mounted) {
          _generateOTP();
        }
      });
    }
  }

  /// OTP 생성
  void _generateOTP() {
    if (!TsOtpService.shouldShowOTP(widget.reservation)) return;
    
    final otp = TsOtpService.generateOTP(widget.reservation);
    
    setState(() {
      _currentOTP = otp;
    });
  }

  /// 수동 OTP 새로고침
  void _refreshOTP() {
    _generateOTP();
  }

  @override
  Widget build(BuildContext context) {
    if (!TsOtpService.shouldShowOTP(widget.reservation)) {
      return SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue[200]!,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.key,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '타석 오픈 OTP',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      color: Colors.blue[900],
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: _refreshOTP,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    tooltip: 'OTP 새로고침',
                  ),
                ],
              ),
              SizedBox(height: 12),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue[300]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _currentOTP,
                    style: AppTextStyles.h1.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      color: Colors.blue[700],
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  '5분마다 자동 변경 • 고객 앱과 동일',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'Pretendard',
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}