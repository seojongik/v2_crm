import 'package:flutter/material.dart';

class AppTextStyles {
  // 제목 계층
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.5,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
  
  // 본문 텍스트
  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );
  
  static const TextStyle bodyTextSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  
  // 카드/컴포넌트
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  
  static const TextStyle cardBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  
  static const TextStyle cardMeta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  
  // UI 요소
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static const TextStyle navigation = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static const TextStyle tabMenu = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static const TextStyle formLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static const TextStyle formInput = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );
  
  // 모달/팝업
  static const TextStyle modalTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
  
  static const TextStyle modalBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );
  
  static const TextStyle modalButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  // Legacy aliases for backward compatibility
  static const TextStyle headline1 = h1;
  static const TextStyle headline2 = h2;
  static const TextStyle headline3 = h3;
  static const TextStyle headline4 = h4;
  static const TextStyle bodyText2 = bodyTextSmall;
  
  // Additional styles
  static const TextStyle titleH1 = h1;
  static const TextStyle titleH2 = h2;
  static const TextStyle titleH3 = h3;
  static const TextStyle titleH4 = h4;
  
  static const TextStyle tagMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static const TextStyle overline = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.4,
  );
}

// 폰트 크기 상수
class FontSizes {
  // 제목
  static const double h1 = 32;
  static const double h2 = 24;
  static const double h3 = 20;
  static const double h4 = 18;
  
  // 본문
  static const double bodyLarge = 16;
  static const double bodyMedium = 14;
  static const double bodySmall = 13;
  
  // 카드
  static const double cardTitle = 15;
  static const double cardSubtitle = 13;
  static const double cardBody = 14;
  static const double cardMeta = 13;
  
  // UI 요소
  static const double button = 14;
  static const double navigation = 14;
  static const double formLabel = 13;
  static const double formInput = 14;
  
  // 모달
  static const double modalTitle = 18;
  static const double modalBody = 14;
  
  // 최소 크기
  static const double minimum = 13;
}