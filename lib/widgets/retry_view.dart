import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';

class RetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const RetryView({
    required this.message, required this.onRetry, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AirbnbColors.warning),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

