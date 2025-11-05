import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';

/// 공통 디자인 시스템
/// 모든 페이지에서 일관된 디자인을 위해 사용
class CommonDesignSystem {
  // 배경색
  static const Color backgroundColor = AppColors.kBackground;
  static const Color surfaceColor = AppColors.kSurface;
  
  // 카드 스타일
  static BoxDecoration cardDecoration({
    Color? color,
    double? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  // 작은 카드 스타일
  static BoxDecoration smallCardDecoration({
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  // AppBar 스타일 (일반 페이지용)
  static AppBar standardAppBar({
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.kTextPrimary,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.kPrimary,
      elevation: 2,
      toolbarHeight: 70,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      actions: actions,
      bottom: bottom,
    );
  }
  
  // AppBar 스타일 (TabBar 있는 페이지용)
  static AppBar tabAppBar({
    required String title,
    required TabBar tabBar,
    List<Widget>? actions,
  }) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppColors.kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: tabBar,
      ),
    );
  }
  
  // 섹션 제목 스타일
  static Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.kTextPrimary,
        ),
      ),
    );
  }
  
  // 표준 간격
  static const double standardPadding = 16.0;
  static const double standardMargin = 16.0;
  static const double cardSpacing = 16.0;
  static const double sectionSpacing = 24.0;
  
  // 표준 버튼 스타일
  static ButtonStyle primaryButtonStyle({
    double? height,
    double? borderRadius,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.kPrimary,
      foregroundColor: Colors.white,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: Size(0, height ?? 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
    );
  }
  
  static ButtonStyle secondaryButtonStyle({
    double? height,
    double? borderRadius,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.kPrimary,
      side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: Size(0, height ?? 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
    );
  }
  
  // 입력 필드 스타일
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

