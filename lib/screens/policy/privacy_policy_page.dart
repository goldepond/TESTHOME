import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('개인정보 처리방침', style: TextStyle(color: Colors.black)),
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
              '본 문서는 서비스 운영을 위한 개인정보 처리의 목적, 항목, 보유기간, 제3자 제공, 위탁, 이용자 권리 등을 안내합니다.\n\n'
              '샘플 텍스트입니다. 실제 운영에 맞춰 내용을 채워주세요.',
              style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.kTextPrimary),
            ),
          ),
        ),
      ),
    );
  }
}


