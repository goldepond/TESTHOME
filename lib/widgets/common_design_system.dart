import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 공통 디자인 시스템
/// 모든 페이지에서 일관된 디자인을 위해 사용
class CommonDesignSystem {
  // 배경색
  static const Color backgroundColor = AirbnbColors.surface;
  static const Color surfaceColor = AirbnbColors.background;
  
  // 카드 스타일
  static BoxDecoration cardDecoration({
    Color? color,
    double? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? AirbnbColors.background,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
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
      color: color ?? AirbnbColors.background,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
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
        style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary),
      ),
      backgroundColor: AirbnbColors.background,
      foregroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 아이콘
      elevation: 2,
      toolbarHeight: 70,
      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      actions: actions,
      bottom: bottom,
    );
  }
  
  // AppBar 스타일 (TabBar 있는 페이지용) - 에어비엔비 스타일: 흰색 배경
  static AppBar tabAppBar({
    required String title,
    required TabBar tabBar,
    List<Widget>? actions,
  }) {
    return AppBar(
      title: Text(
        title,
        style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary), // 에어비엔비 스타일: 검은색 텍스트
      ),
      backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
      foregroundColor: AirbnbColors.textPrimary,
      elevation: 0,
      toolbarHeight: 70,
      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.1),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.screenPadding,
      ),
      child: Text(
        title,
        style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary),
      ),
    );
  }
  
  // 표준 간격 (하위 호환성을 위해 유지, AppSpacing 사용 권장)
  @Deprecated('Use AppSpacing instead')
  static const double standardPadding = AppSpacing.md;
  @Deprecated('Use AppSpacing instead')
  static const double standardMargin = AppSpacing.md;
  @Deprecated('Use AppSpacing instead')
  static const double cardSpacing = AppSpacing.cardSpacing;
  @Deprecated('Use AppSpacing instead')
  static const double sectionSpacing = AppSpacing.sectionSpacing;
  
  // 표준 버튼 스타일 (에어비엔비 스타일: 검은색 배경)
  static ButtonStyle primaryButtonStyle({
    double? height,
    double? borderRadius,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
      foregroundColor: AirbnbColors.textWhite,
      elevation: 2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      minimumSize: Size(0, height ?? 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      textStyle: AppTypography.button,
    );
  }
  
  // 에어비엔비 스타일: 흰색 배경 + 검은색 테두리
  static ButtonStyle secondaryButtonStyle({
    double? height,
    double? borderRadius,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 텍스트
      side: const BorderSide(color: AirbnbColors.textPrimary, width: 1.5), // 에어비엔비 스타일: 검은색 테두리
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      minimumSize: Size(0, height ?? 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      textStyle: AppTypography.button,
    );
  }
  
  // 비활성화된 버튼 스타일 (에어비엔비 스타일: 흰색 배경 + 회색 테두리)
  static ButtonStyle disabledButtonStyle({
    double? height,
    double? borderRadius,
    bool requiresLogin = false,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: AirbnbColors.background, // 흰색 배경
      foregroundColor: requiresLogin 
          ? AirbnbColors.primary.withValues(alpha: 0.6)  // 로그인 필요: 연한 보라색
          : AirbnbColors.textSecondary,  // 일반 비활성화: 회색
      disabledBackgroundColor: AirbnbColors.background,
      disabledForegroundColor: requiresLogin 
          ? AirbnbColors.primary.withValues(alpha: 0.6)
          : AirbnbColors.textSecondary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      minimumSize: Size(0, height ?? 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        side: BorderSide(
          color: requiresLogin 
              ? AirbnbColors.primary.withValues(alpha: 0.3)  // 로그인 필요: 연한 보라색 테두리
              : AirbnbColors.border,  // 일반 비활성화: 회색 테두리
          width: requiresLogin ? 1.5 : 1,
        ),
      ),
      textStyle: AppTypography.button,
    );
  }
  
  // 비활성화된 Outlined 버튼 스타일
  static ButtonStyle disabledOutlinedButtonStyle({
    double? height,
    double? borderRadius,
    bool requiresLogin = false,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: requiresLogin 
          ? AirbnbColors.primary.withValues(alpha: 0.6)
          : AirbnbColors.textSecondary,
      disabledForegroundColor: requiresLogin 
          ? AirbnbColors.primary.withValues(alpha: 0.6)
          : AirbnbColors.textSecondary,
      side: BorderSide(
        color: requiresLogin 
            ? AirbnbColors.primary.withValues(alpha: 0.3)
            : AirbnbColors.border,
        width: requiresLogin ? 1.5 : 1,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      minimumSize: Size(0, height ?? 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      textStyle: AppTypography.button,
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
      fillColor: AirbnbColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AirbnbColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AirbnbColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPadding,
        vertical: AppSpacing.inputPadding,
      ),
    );
  }
}

/// 접근성 개선을 위한 헬퍼 위젯
class AccessibleWidget {
  /// 접근 가능한 아이콘 버튼 생성
  /// Semantics와 Tooltip을 자동으로 추가
  static Widget iconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    String? semanticLabel,
    Color? color,
    double? iconSize,
  }) {
    final button = IconButton(
      icon: Icon(icon, size: iconSize),
      onPressed: onPressed,
      color: color,
      tooltip: tooltip,
    );
    
    return Semantics(
      label: semanticLabel ?? tooltip,
      button: true,
      enabled: onPressed != null,
      child: Tooltip(
        message: tooltip,
        child: button,
      ),
    );
  }
  
  /// 접근 가능한 텍스트 버튼 생성
  static Widget textButton({
    required String label,
    required VoidCallback? onPressed,
    String? semanticLabel,
    TextStyle? textStyle,
  }) {
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      enabled: onPressed != null,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: textStyle ?? AppTypography.button,
        ),
      ),
    );
  }
  
  /// 접근 가능한 Elevated 버튼 생성
  static Widget elevatedButton({
    required String label,
    required VoidCallback? onPressed,
    String? semanticLabel,
    ButtonStyle? style,
  }) {
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      enabled: onPressed != null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style ?? CommonDesignSystem.primaryButtonStyle(),
        child: Text(
          label,
          style: AppTypography.button,
        ),
      ),
    );
  }

  /// 확인/취소 다이얼로그를 표시합니다.
  ///
  /// [isDangerous]가 true이면 확인 버튼을 경고색으로 표시합니다.
  /// 사용자가 확인을 누르면 `true`, 취소를 누르면 `false`를 반환합니다.
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '확인',
    String cancelLabel = '취소',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDangerous
                ? ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.warning,
                    foregroundColor: AirbnbColors.background,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

