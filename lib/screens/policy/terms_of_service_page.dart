import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('이용약관', style: TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '본 문서는 서비스 이용과 관련된 권리, 의무 및 책임사항을 규정합니다.\n\n'
              '샘플 텍스트입니다. 실제 운영에 맞춰 내용을 채워주세요.',
              style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.kTextPrimary),
            ),
          ),
        ),
      ),
    );
  }
}


