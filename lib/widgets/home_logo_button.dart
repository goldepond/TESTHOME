import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'package:property/constants/typography.dart';

/// 홈으로 이동하는 MyHome 로고 버튼
class HomeLogoButton extends StatefulWidget {
  final Color? color;
  final double? fontSize;
  final double? logoHeight;
  
  const HomeLogoButton({
    this.color,
    this.fontSize = 24,
    this.logoHeight,
    super.key,
  });

  @override
  State<HomeLogoButton> createState() => _HomeLogoButtonState();
}

class _HomeLogoButtonState extends State<HomeLogoButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 클릭 시 스케일 애니메이션
          _controller.forward().then((_) {
            _controller.reverse();
          });
          
          // 홈으로 이동 (기존 스택 유지, 루트로 복귀)
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.transparent, // 리플 효과 제거
        highlightColor: Colors.transparent, // 하이라이트 효과 제거
        hoverColor: Colors.transparent, // 호버 효과 제거
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildLogo(widget.logoHeight ?? widget.fontSize! * 2.5),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double height) {
    // 로고 이미지 파일 존재 여부 확인 후 표시
    // assets/Big_Logo.png 우선 사용 (사용자가 제공한 로고)
    return Image.asset(
      'assets/Big_Logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // logo.jpg가 없으면 myhome_logo.png 시도
        return Image.asset(
          'assets/myhome_logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // myhome_logo.png가 없으면 logo.png 시도
            return Image.asset(
              'assets/logo.png',
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // 로고 파일이 없으면 기본 아이콘 사용
                return Icon(
                  Icons.home,
                  color: widget.color ?? AirbnbColors.background,
                  size: height,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 로고만 표시하는 위젯 (텍스트 없이)
class LogoImage extends StatelessWidget {
  final double? height;
  final double? width;
  final Color? color;
  
  const LogoImage({
    this.height,
    this.width,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/Big_Logo.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // logo.jpg가 없으면 myhome_logo.png 시도
        return Image.asset(
          'assets/myhome_logo.png',
          height: height,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // myhome_logo.png가 없으면 logo.png 시도
            return Image.asset(
              'assets/logo.png',
              height: height,
              width: width,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // 로고 파일이 없으면 기본 아이콘 사용
                return Icon(
                  Icons.home,
                  color: color ?? AirbnbColors.primary,
                  size: height ?? 24,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 로고와 텍스트를 함께 표시하는 위젯 (로고 이미지에 텍스트가 포함되어 있으면 텍스트 없이 표시)
class LogoWithText extends StatefulWidget {
  final double? fontSize;
  final double? logoHeight;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool showText; // 텍스트 표시 여부 (기본값: false, 로고 이미지에 텍스트 포함)
  
  const LogoWithText({
    this.fontSize = 24,
    this.logoHeight,
    this.textColor,
    this.onTap,
    this.showText = false, // 로고 이미지에 텍스트가 포함되어 있으므로 기본값 false
    super.key,
  });

  @override
  State<LogoWithText> createState() => _LogoWithTextState();
}

class _LogoWithTextState extends State<LogoWithText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoWidget = LogoImage(
      height: widget.logoHeight ?? widget.fontSize! * 2.5,
      color: widget.textColor,
    );

    final contentWidget = widget.showText
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              logoWidget,
              const SizedBox(width: 8),
              Text(
                'MyHome',
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor ?? AirbnbColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          )
        : logoWidget;

    if (widget.onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 클릭 시 스케일 애니메이션
            _controller.forward().then((_) {
              _controller.reverse();
            });
            widget.onTap!();
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.transparent, // 리플 효과 제거
          highlightColor: Colors.transparent, // 하이라이트 효과 제거
          hoverColor: Colors.transparent, // 호버 효과 제거
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: contentWidget,
            ),
          ),
        ),
      );
    }

    return contentWidget;
  }
}

/// AppBar용 타이틀 (홈 이동 가능)
class AppBarTitle extends StatelessWidget {
  final String title;
  final bool showHomeLogo;
  
  const AppBarTitle({
    required this.title,
    this.showHomeLogo = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (showHomeLogo) {
      return Row(
        children: [
          const HomeLogoButton(fontSize: 20),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 20,
            color: AirbnbColors.background.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style:  AppTypography.withColor(AppTypography.bodyLarge, AirbnbColors.background),
          ),
        ],
      );
    }
    
    return Text(
      title,
      style:  AppTypography.withColor(AppTypography.bodyLarge, AirbnbColors.background),
    );
  }
}

