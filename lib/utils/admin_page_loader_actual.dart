/// 관리자 페이지 실제 구현 (관리자 페이지 파일이 있을 때만 사용)
/// 
/// 이 파일은 lib/screens/admin/ 폴더가 존재할 때만 컴파일됩니다.
/// 관리자 페이지를 외부로 분리할 때 이 파일을 삭제하면
/// 자동으로 관리자 기능이 비활성화됩니다.
library;

import 'package:flutter/material.dart';
import 'package:property/screens/admin/admin_dashboard.dart';

/// 관리자 페이지 실제 구현 로더
/// 
/// 관리자 페이지 파일이 존재할 때만 사용되는 실제 구현입니다.
class AdminPageLoaderActual {
  /// 관리자 페이지 Route 생성
  static Route<dynamic>? createAdminRoute(String? routeName) {
    // 관리자 페이지 라우팅 URL
    const adminRoutePath = '/admin-panel-myhome-2024';
    
    // 관리자 페이지 URL이 아니면 null 반환
    if (routeName != adminRoutePath) {
      return null;
    }
    
    // 관리자 페이지 Route 생성
    return MaterialPageRoute(
      builder: (context) => const AdminDashboard(
        userId: 'admin',
        userName: '관리자',
      ),
    );
  }
}

