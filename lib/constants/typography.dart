import 'package:flutter/material.dart';

/// 타이포그래피 시스템
/// 일관된 텍스트 스타일을 위한 표준 정의
class AppTypography {
  // Display (대제목)
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
    fontFamily: 'NotoSansKR',
  );
  
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
    height: 1.3,
    fontFamily: 'NotoSansKR',
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.2,
    height: 1.3,
    fontFamily: 'NotoSansKR',
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.4,
    fontFamily: 'NotoSansKR',
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: 'NotoSansKR',
  );
  
  // Body
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamily: 'NotoSansKR',
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamily: 'NotoSansKR',
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamily: 'NotoSansKR',
  );
  
  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
    fontFamily: 'NotoSansKR',
  );
  
  static const TextStyle captionLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
    fontFamily: 'NotoSansKR',
  );

  // Button
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFamily: 'NotoSansKR',
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFamily: 'NotoSansKR',
  );
  
  /// 색상을 적용한 텍스트 스타일 생성
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }
}











