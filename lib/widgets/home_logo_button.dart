import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/main_page.dart';

/// 홈으로 이동하는 MyHome 로고 버튼
class HomeLogoButton extends StatelessWidget {
  final Color? color;
  final double? fontSize;
  
  const HomeLogoButton({
    this.color,
    this.fontSize = 24,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // 홈으로 이동 (MainPage로 pushReplacement)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainPage(
              userId: '',
              userName: '',
            ),
          ),
          (route) => false,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home,
              color: color ?? Colors.white,
              size: fontSize,
            ),
            const SizedBox(width: 8),
            Text(
              'MyHome',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
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
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      );
    }
    
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        color: Colors.white,
      ),
    );
  }
}

