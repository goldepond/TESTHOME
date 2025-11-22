import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';

class SelectedQuoteCard extends StatelessWidget {
  final QuoteRequest quote;
  final bool isSubmitting;
  final bool isRegistered;
  final VoidCallback onRegisterPressed;

  const SelectedQuoteCard({
    super.key,
    required this.quote,
    required this.isSubmitting,
    required this.isRegistered,
    required this.onRegisterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.kSuccess.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.kSuccess.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.kSuccess, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '판매자가 이 견적을 선택했습니다!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kSuccess,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 16),
              _buildContactRow(
                icon: Icons.person,
                label: '요청자',
                value: quote.userName,
              ),
              const SizedBox(height: 12),
              _buildContactRow(
                icon: Icons.phone,
                label: '휴대폰',
                value: quote.userPhone ?? '미등록',
                isHighlight: true,
              ),
              const SizedBox(height: 12),
              _buildContactRow(
                icon: Icons.email,
                label: '이메일',
                value: quote.userEmail,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (isSubmitting || isRegistered) ? null : onRegisterPressed,
                  icon: isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isRegistered ? Icons.check : Icons.upload_file),
                  label: Text(
                    isSubmitting 
                        ? '등록 중...' 
                        : (isRegistered ? '매물 등록 완료' : '내집구매에 매물 등록하기')
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRegistered ? Colors.grey : AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    elevation: isRegistered ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  isRegistered 
                      ? '이미 매물로 등록되었습니다.' 
                      : '매물 등록 시 내집구매 목록에 즉시 노출됩니다.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String? value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value ?? '-',
            style: TextStyle(
              fontSize: isHighlight ? 18 : 15,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.kPrimary : const Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }
}

