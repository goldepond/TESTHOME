import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../constants/app_constants.dart';
import '../../api_request/firebase_service.dart';
import 'package:property/utils/snackbar_utils.dart';
import '../../models/broker_review.dart';

class ReviewDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String brokerRegistrationNumber;
  final String quoteRequestId;

  const ReviewDialog({
    required this.userId,
    required this.userName,
    required this.brokerRegistrationNumber,
    required this.quoteRequestId,
    super.key,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final TextEditingController _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final review = BrokerReview(
        id: '', // Firebase가 생성
        userId: widget.userId,
        userName: widget.userName,
        brokerRegistrationNumber: widget.brokerRegistrationNumber,
        quoteRequestId: widget.quoteRequestId,
        rating: _rating.toInt(), // double을 int로 변환
        recommend: _rating >= 4.0, // 4점 이상이면 추천
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirebaseService().saveBrokerReview(review);

      if (!mounted) return;
      Navigator.pop(context, true); // 성공 반환
      
      AppSnackBar.success(context, '소중한 리뷰가 등록되었습니다!');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '리뷰 등록에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('상담은 어떠셨나요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('공인중개사와의 상담 경험을 공유해주세요.'),
          const SizedBox(height: 20),
          RatingBar.builder(
            initialRating: 5,
            minRating: 1,
            allowHalfRating: true,
            itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: AirbnbColors.orange,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                _rating = rating;
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: '친절함, 전문성 등 자유롭게 적어주세요 (선택)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.primary,
            foregroundColor: AirbnbColors.background,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AirbnbColors.background),
                )
              : const Text('등록'),
        ),
      ],
    );
  }
}

