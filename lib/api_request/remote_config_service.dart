import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../utils/logger.dart';

/// Firebase Remote Config 서비스.
/// 앱 재배포 없이 설정 변경 가능:
/// - 점검 모드 on/off
/// - 최소 버전 강제 업데이트
/// - 기능 플래그 제어
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// 점검 모드 여부
  bool get isMaintenanceMode => _remoteConfig.getBool('maintenance_mode');

  /// 점검 메시지
  String get maintenanceMessage =>
      _remoteConfig.getString('maintenance_message');

  /// 최소 앱 버전 (이 버전 미만이면 업데이트 권장/강제)
  String get minAppVersion => _remoteConfig.getString('min_app_version');

  /// 강제 업데이트 여부
  bool get forceUpdate => _remoteConfig.getBool('force_update');

  /// 새 기능 배너 텍스트 (빈 문자열이면 표시 안 함)
  String get newFeatureBanner => _remoteConfig.getString('new_feature_banner');

  /// 최신 설정을 서버에서 가져와 활성화
  Future<bool> fetchAndActivate() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      Logger.info('Remote Config 갱신: $updated');
      return updated;
    } catch (e) {
      Logger.warning('Remote Config fetch 실패',
          metadata: {'error': e.toString()});
      return false;
    }
  }

  /// 특정 키의 문자열 값 가져오기
  String getString(String key) => _remoteConfig.getString(key);

  /// 특정 키의 bool 값 가져오기
  bool getBool(String key) => _remoteConfig.getBool(key);

  /// 특정 키의 int 값 가져오기
  int getInt(String key) => _remoteConfig.getInt(key);

  /// 특정 키의 double 값 가져오기
  double getDouble(String key) => _remoteConfig.getDouble(key);
}
