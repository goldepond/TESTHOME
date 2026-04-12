import 'package:flutter/material.dart';
import '../utils/analytics_service.dart';

/// 화면 전환을 자동으로 감지하여 AnalyticsService(Firebase Analytics)에 기록하는 Observer.
/// FirebaseAnalyticsObserver와 병행하여 커스텀 화면 이름 추적에 사용.
class AppAnalyticsObserver extends RouteObserver<PageRoute<dynamic>> {
  void _logScreenView(PageRoute<dynamic> route) {
    final String screenName = route.settings.name ?? route.runtimeType.toString();

    // 기본 라우트 이름은 제외
    if (screenName == 'MaterialPageRoute<dynamic>' || screenName == '/') {
      return;
    }

    AnalyticsService.instance.logScreenView(screenName);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _logScreenView(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute && route is PageRoute) {
      _logScreenView(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _logScreenView(newRoute);
    }
  }
}
