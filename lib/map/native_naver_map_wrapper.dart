import 'dart:math' as math;

import 'package:property/constants/app_constants.dart';

import 'package:flutter_naver_map/flutter_naver_map.dart';


class NativeNMapWrapper {
  NativeNMapWrapper._(); // Private constructor

  static final NativeNMapWrapper instance = NativeNMapWrapper._();

  static bool _initialized = false;

  // TODO: check if we can utilize FlutterNaverMap.isInitialized
  Future<void> initMapLib() async {
    if (!_initialized) {
      _initialized = true;
      await FlutterNaverMap().init(
        clientId: ApiConstants.naverMapClientId,
        onAuthFailed: (ex) {
          switch (ex) {
            case NQuotaExceededException(:final message):
              print("사용량 초과 (message: $message)");
              _initialized = false;
              break;
            case NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException():
              print("인증 실패: $ex");
              _initialized = false;
              break;
          }
        },
      );
    }
  }

  double calculateDistanceHaversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // km
    final dlat = (lat2 - lat1) * (math.pi / 180);
    final dlon = (lon2 - lon1) * (math.pi / 180);
    final a = math.pow(math.sin(dlat / 2), 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) * math.pow(math.sin(dlon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

}