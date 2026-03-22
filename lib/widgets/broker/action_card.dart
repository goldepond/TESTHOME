import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 에어비엔비 스타일 액션 카드 위젯 (호버/클릭 피드백 포함)
class ActionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final List<Color> gradient;
  final String badge;
  final double cardHeight;
  final VoidCallback? onTap;

  const ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.gradient,
    required this.badge,
    required this.cardHeight,
    super.key,
    this.onTap,
  });

  @override
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 에어비엔비 스타일: 비활성화 상태를 명확하게 구분
    final bool isDisabled = !widget.enabled;

    final Color cardColor = isDisabled
        ? AirbnbColors.background
        : widget.gradient[0];

    final Color borderColor = isDisabled
        ? AirbnbColors.border
        : (_isHovered
            ? widget.gradient[0].withValues(alpha: 0.8)
            : widget.gradient[0].withValues(alpha: 0.3));

    final Color textColor = isDisabled
        ? AirbnbColors.textSecondary
        : AirbnbColors.textWhite;

    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) {
            setState(() => _isPressed = true);
          }
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: widget.cardHeight,
          transform: () {
            final scale = _isPressed ? 0.98 : (_isHovered && widget.enabled ? 1.02 : 1.0);
            return Matrix4.identity()..scaleByDouble(scale, scale, scale, 1.0);
          }(),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isDisabled
                  ? 1.5
                  : (_isHovered && widget.enabled ? 2 : 1.5),
            ),
            boxShadow: widget.enabled
                ? (_isHovered
                    ? [AirbnbColors.cardShadowHover]
                    : [AirbnbColors.cardShadow])
                : [AirbnbColors.cardShadowSubtle],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 배경 아이콘
                  Positioned(
                    right: -8,
                    top: -8,
                    child: IgnorePointer(
                      child: Icon(
                        widget.icon,
                        size: ResponsiveHelper.isMobile(context) ? 70 : 90,
                        color: isDisabled
                            ? AirbnbColors.textLight.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  // 메인 콘텐츠
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 배지
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm + 2,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDisabled
                                      ? AirbnbColors.surface
                                      : Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isDisabled
                                      ? Border.all(color: AirbnbColors.border)
                                      : Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  widget.badge,
                                  style: AppTypography.withColor(
                                    AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                                    isDisabled ? AirbnbColors.textSecondary : AirbnbColors.textWhite,
                                  ),
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.isMobile(context) ? 8 : 12),
                              // 제목
                              Text(
                                widget.title,
                                style: AppTypography.withColor(
                                  AppTypography.h3.copyWith(
                                    fontSize: ResponsiveHelper.isMobile(context) ? 18 : 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                  textColor,
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.isMobile(context) ? 4 : 6),
                              // 설명
                              Flexible(
                                child: Text(
                                  widget.description,
                                  style: AppTypography.withColor(
                                    AppTypography.caption.copyWith(
                                      fontSize: ResponsiveHelper.isMobile(context) ? 11 : 13,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    isDisabled
                                        ? AirbnbColors.textSecondary
                                        : textColor.withValues(alpha: 0.95),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 하단 CTA
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: Matrix4.translationValues(
                                  _isHovered && widget.enabled ? 4.0 : 0.0,
                                  0.0,
                                  0.0,
                                ),
                                child: Icon(
                                  widget.enabled
                                      ? Icons.arrow_forward_rounded
                                      : Icons.info_outline_rounded,
                                  color: isDisabled ? AirbnbColors.textSecondary : textColor,
                                  size: ResponsiveHelper.isMobile(context) ? 15 : 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.enabled ? '바로 실행' : '사용 불가',
                                style: AppTypography.withColor(
                                  AppTypography.caption.copyWith(
                                    fontSize: ResponsiveHelper.isMobile(context) ? 12 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  isDisabled ? AirbnbColors.textSecondary : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
