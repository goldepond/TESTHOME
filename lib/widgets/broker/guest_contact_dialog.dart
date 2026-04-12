import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/validation_utils.dart';

/// 게스트 모드 연락처 입력 다이얼로그
class GuestContactDialog extends StatefulWidget {
  const GuestContactDialog({super.key});

  @override
  State<GuestContactDialog> createState() => _GuestContactDialogState();
}

class _GuestContactDialogState extends State<GuestContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.contact_mail, color: AirbnbColors.primary, size: 24),
          SizedBox(width: 12),
          Text('연락처 정보', style: AppTypography.h4),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일 *',
                  hintText: '예: user@example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!ValidationUtils.isValidEmail(value)) {
                    return '올바른 이메일 형식을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  hintText: '예: 01012345678',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '전화번호를 입력해주세요';
                  }
                  final cleanPhone = value.replaceAll('-', '').replaceAll(' ', '').trim();
                  if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(cleanPhone)) {
                    return '올바른 전화번호 형식을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AirbnbColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AirbnbColors.info.withValues(alpha: 0.3)),
                ),
                child:   Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AirbnbColors.info),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '공인중개사의 상담 응답을 받을 연락처를 적어주세요.\n상담 이후 응답은 내집관리에서 확인 가능합니다.',
                        style: AppTypography.caption.copyWith(color: AirbnbColors.info, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final cleanPhone = _phoneController.text
                  .replaceAll('-', '')
                  .replaceAll(' ', '')
                  .trim();
              Navigator.pop(context, {
                'email': _emailController.text.trim(),
                'phone': cleanPhone,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.textPrimary,
            foregroundColor: AirbnbColors.background,
          ),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
