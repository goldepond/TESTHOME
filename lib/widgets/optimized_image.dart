import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:property/constants/app_constants.dart';

/// 최적화된 네트워크 이미지 위젯
/// - 캐싱 지원
/// - 웹 최적화 (cacheWidth/cacheHeight)
/// - 로딩 상태 표시
/// - 에러 처리
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedNetworkImage({
    required this.imageUrl, super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // 웹 최적화: 캐시 크기 제한으로 메모리 사용량 감소
      cacheWidth: kIsWeb && width != null ? (width! * 2).toInt() : null,
      cacheHeight: kIsWeb && height != null ? (height! * 2).toInt() : null,
      // 이미지 캐싱은 자동으로 URL을 키로 사용
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: placeholderColor ?? AirbnbColors.borderLight,
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  color: AirbnbColors.textSecondary,
                  size: 48,
                ),
              ),
            );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          width: width,
          height: height,
          color: placeholderColor ?? AirbnbColors.surface,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

/// 최적화된 이미지 갤러리 (PageView)
class OptimizedImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final double height;
  final BorderRadius? borderRadius;

  const OptimizedImageGallery({
    required this.imageUrls, super.key,
    this.height = 300,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          color: AirbnbColors.borderLight,
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 48, color: AirbnbColors.textSecondary),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        color: AirbnbColors.surface,
      ),
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return OptimizedNetworkImage(
            imageUrl: imageUrls[index],
            height: height,
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          );
        },
      ),
    );
  }
}

