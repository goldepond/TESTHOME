import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property/firebase_options.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/main_page.dart';
import 'package:property/screens/broker/mls_broker_dashboard_page.dart';
import 'package:property/screens/auth/auth_landing_page.dart';
import 'package:property/screens/auth/profile_completion_page.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/fcm_service.dart';
import 'package:property/screens/inquiry/broker_inquiry_response_page.dart';
import 'package:property/screens/market_price/market_price_page.dart';
import 'package:property/screens/public/public_listings_page.dart';
import 'package:property/screens/public/public_property_detail_page.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:property/utils/app_analytics_observer.dart';
import 'package:property/utils/admin_page_loader_actual.dart';
import 'package:property/utils/logger.dart';
// 웹에서만 사용하는 import
// 웹 전용 import (조건부)
import 'main_stub.dart' if (dart.library.html) 'main_web.dart' as web;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 이미지 캐시 최적화 (메모리 사용량 제한)
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB

  // 전역 에러 핸들러 설정 (Crashlytics + Logger)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Crashlytics에 Flutter 프레임워크 에러 전송 (웹 제외)
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
    Logger.error(
      'Flutter Error 발생',
      error: details.exception,
      stackTrace: details.stack,
      context: 'flutter_error_handler',
    );
  };

  // 비동기 에러 핸들러 설정 (Crashlytics + Logger)
  PlatformDispatcher.instance.onError = (error, stack) {
    // Crashlytics에 비동기 에러 전송 (웹 제외)
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    Logger.error(
      'Platform Error 발생',
      error: error,
      stackTrace: stack,
      context: 'platform_error_handler',
    );
    return true;
  };

  // .env 파일 로드 (assets에서) - 카카오 SDK 초기화 전에 먼저 로드
  try {
    await dotenv.load();
    Logger.info('.env 파일 로드 성공 - JUSO_API_KEY 존재: ${dotenv.env['JUSO_API_KEY']?.isNotEmpty ?? false}');
  } catch (e) {
    // .env 파일이 없어도 앱은 실행 가능 (웹에서는 다른 방식으로 로드될 수 있음)
    Logger.warning(
      '.env 파일을 로드할 수 없습니다',
      metadata: {'error': e.toString()},
    );
  }

  // 카카오 SDK 초기화 (.env 로드 후)
  kakao.KakaoSdk.init(
    nativeAppKey: ApiConstants.kakaoNativeAppKey,
    javaScriptAppKey: ApiConstants.kakaoJavaScriptAppKey,
  );

  // Firebase 초기화 (앱 실행 전에 완료)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.info('Firebase 초기화 성공');
    } else {
      Logger.info('Firebase 이미 초기화됨 (${Firebase.apps.length}개 앱)');
    }

    // Crashlytics 초기화 (웹 제외 - 웹은 미지원)
    if (!kIsWeb) {
      // Crashlytics 수집 활성화
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      Logger.info('Crashlytics 초기화 완료');
    }

    // Remote Config 초기화
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.setDefaults({
      'maintenance_mode': false,
      'maintenance_message': '서버 점검 중입니다. 잠시 후 다시 시도해주세요.',
      'min_app_version': '1.0.0',
      'force_update': false,
      'new_feature_banner': '',
    });
    // 백그라운드에서 fetch (앱 시작 차단하지 않음)
    remoteConfig.fetchAndActivate().then((_) {
      Logger.info('Remote Config 활성화 완료');
    }).catchError((e) {
      Logger.warning('Remote Config fetch 실패', metadata: {'error': e.toString()});
    });

    // FCM 백그라운드 핸들러 등록 (Firebase 초기화 후)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // FCM 서비스 초기화
    await FCMService().initialize();
  } catch (e) {
    // duplicate-app 에러는 무시 (이미 초기화된 경우)
    if (e.toString().contains('duplicate-app')) {
      Logger.info('Firebase 이미 초기화됨 (duplicate-app)');
    } else {
      Logger.error('Firebase 초기화 실패', error: e);
    }
  }

  // 앱 실행
  runApp(const MyApp());

  // 웹에서 Flutter 첫 프레임 렌더링 완료 후 로딩 화면 제거 신호 전송
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 첫 프레임 렌더링 완료 후 JavaScript에 신호 전송
      web.dispatchFlutterAppReady();
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Firebase는 main()에서 이미 초기화됨 - 여기서는 상태만 확인
  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Firebase 초기화 실패 시 에러 화면 표시
    if (!_isFirebaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _NetworkErrorScreen(
          message: '서버에 연결할 수 없습니다.\n네트워크 연결을 확인해주세요.',
          onRetry: () => setState(() {}),
        ),
      );
    }

    return MaterialApp(
      title: 'MyHome - 부동산 매물 등록', 
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AirbnbColors.primary,
        scaffoldBackgroundColor: AirbnbColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AirbnbColors.primary,
          primary: AirbnbColors.primary,
          secondary: AirbnbColors.success,
          surface: AirbnbColors.surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AirbnbColors.background,
          foregroundColor: AirbnbColors.textPrimary,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.textPrimary,
            foregroundColor: AirbnbColors.textWhite,
            elevation: 2,
            shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AirbnbColors.textPrimary,
            side: const BorderSide(color: AirbnbColors.textPrimary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AirbnbColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
          foregroundColor: AirbnbColors.textWhite,
          elevation: 3.0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AirbnbColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AirbnbColors.border),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AirbnbColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AirbnbColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AirbnbColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        useMaterial3: false,
        fontFamily: 'NotoSansKR',
      ),
      // 화면 전환 로깅을 위한 Observer 등록
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        AppAnalyticsObserver(),
      ],
      // URL 기반 라우팅
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // 관리자 페이지 라우팅 (조건부 로드)
        // 관리자 페이지를 외부로 분리할 때는 AdminPageLoaderActual 파일을 삭제하면
        // 자동으로 관리자 기능이 비활성화됩니다.
        try {
          final adminRoute = AdminPageLoaderActual.createAdminRoute(settings.name);
          if (adminRoute != null) {
            return adminRoute;
          }
        } catch (e) {
          // 관리자 페이지 파일이 없는 경우 (외부로 분리된 경우)
          Logger.warning(
            '관리자 페이지 라우팅 실패',
            metadata: {'route': settings.name, 'error': e.toString()},
          );
        }
        
        // 공인중개사용 답변 페이지 (/inquiry/:id)
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'inquiry') {
          final linkId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => BrokerInquiryResponsePage(linkId: linkId),
          );
        }
        
        // 시세 조회 페이지 (공개 - 로그인 불필요)
        if (uri.path == '/market-price') {
          return MaterialPageRoute(
            builder: (context) => const MarketPricePage(),
          );
        }

        // 공개 매물 목록 (로그인 불필요)
        if (uri.path == '/listings') {
          return MaterialPageRoute(
            builder: (context) => const PublicListingsPage(),
          );
        }

        // 공개 매물 상세 (로그인 불필요)
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'property') {
          final id = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => PublicPropertyDetailPage(propertyId: id),
          );
        }

        // 기본 홈 페이지: Auth 게이트 사용
        return MaterialPageRoute(
          builder: (context) => const _AuthGate(),
        );
      },
    );
  }
}

/// 네트워크 오류 화면
class _NetworkErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NetworkErrorScreen({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  '연결 오류',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Firebase Auth 상태를 구독하여 새로고침 시에도 로그인 유지
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Map<String, dynamic>? _cachedUserData;
  User? _lastKnownUser;
  int _cacheVersion = 0; // 캐시 무효화 시 증가하여 FutureBuilder 강제 재실행

  @override
  void initState() {
    super.initState();
    // 현재 사용자 상태 저장
    _lastKnownUser = FirebaseAuth.instance.currentUser;
  }

  /// 기본 이름인지 확인 (소셜 로그인 기본값)
  bool _isDefaultName(String? name) {
    if (name == null) return true;
    const defaultNames = [
      '카카오 사용자',
      '구글 사용자',
      '네이버 사용자',
      '사용자',
      'Google 사용자',
      'Kakao 사용자',
      'Naver 사용자',
    ];
    if (defaultNames.contains(name)) return true;

    // 소셜 로그인 ID 형식 체크 (예: kakao_4719204516, google_xxx, naver_xxx)
    final lowerName = name.toLowerCase();
    if (lowerName.startsWith('kakao_') ||
        lowerName.startsWith('google_') ||
        lowerName.startsWith('naver_')) {
      return true;
    }

    return false;
  }

  /// 프로필 완성이 필요한지 확인
  bool _needsProfileCompletion(Map<String, dynamic>? userData) {
    if (userData == null) return true;

    final name = userData['name'] as String?;
    final phone = userData['phone'] as String?;
    final profileCompleted = userData['profileCompleted'] as bool? ?? false;

    // 이미 프로필 완성 표시가 있으면 스킵
    if (profileCompleted) return false;

    // 이름이 기본값이거나 전화번호가 없으면 프로필 완성 필요
    return _isDefaultName(name) || phone == null || phone.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // Firebase는 main()에서 이미 초기화됨
    // userChanges()는 authStateChanges()보다 더 많은 이벤트를 emit하여
    // 로그인 상태 변화를 더 빠르게 감지함
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        // Firebase 준비 중에는 로딩 표시
        if (snapshot.connectionState == ConnectionState.waiting) {
          Logger.info('[AuthGate] Firebase 준비 중 - 로딩 표시');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Firebase 서버 오류 시 에러 화면 표시
        if (snapshot.hasError) {
          Logger.error('[AuthGate] Firebase Auth 스트림 오류', error: snapshot.error);
          return _NetworkErrorScreen(
            message: '서버에 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.',
            onRetry: () {
              setState(() {});
            },
          );
        }

        // 비로그인 상태 또는 익명 사용자: 랜딩 페이지로 이동
        if (user == null || user.isAnonymous) {
          // 캐시 즉시 초기화 - 재로그인 시 타이밍 문제 방지
          if (_cachedUserData != null || _lastKnownUser != null) {
            _cachedUserData = null;
            _lastKnownUser = null;
            _cacheVersion++; // 같은 계정으로 재로그인 시 FutureBuilder 강제 재실행
          }
          // const 제거 - 매번 새로운 State 생성 보장
          return AuthLandingPage(key: ValueKey('auth_landing_$_cacheVersion'));
        }

        Logger.info('[AuthGate] 로그인 상태 감지 - user: ${user.uid}');
        // 사용자 상태 업데이트
        _lastKnownUser = user;
        
        // 캐시된 데이터가 있고 같은 사용자면 즉시 반환
        if (_cachedUserData != null && _cachedUserData!['uid'] == user.uid) {
          // 브로커 계정인 경우 공인중개사 대시보드로 진입
          if (_cachedUserData!['userType'] == 'broker' &&
              _cachedUserData!['brokerData'] != null) {
            final brokerId =
                _cachedUserData!['brokerId'] ?? _cachedUserData!['uid'];
            final brokerName = _cachedUserData!['name'] ?? '공인중개사';
            return MLSBrokerDashboardPage(
              brokerId: brokerId,
              brokerName: brokerName,
              brokerData: _cachedUserData!['brokerData'],
            );
          }

          // 프로필 완성이 필요한지 확인 (일반 사용자만)
          if (_needsProfileCompletion(_cachedUserData!['userData'])) {
            return ProfileCompletionPage(
              userId: _cachedUserData!['uid'],
              currentName: _cachedUserData!['name'],
              onComplete: () {
                // 프로필 완성 후 캐시 초기화 + 버전 증가로 FutureBuilder 강제 재실행
                setState(() {
                  _cachedUserData = null;
                  _cacheVersion++;
                });
              },
            );
          }

          // 일반 사용자 기본 페이지
          return MainPage(
            key: ValueKey('main_${_cachedUserData!['uid']}'),
            userId: _cachedUserData!['uid'],
            userName: _cachedUserData!['name'],
          );
        }

        // Firestore / brokers 컬렉션에서 사용자 유형 및 표시 이름 로드
        // 로딩 중에도 기본 UI를 먼저 표시하여 사용자 경험 개선
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey('${user.uid}_$_cacheVersion'),
          future: () async {
            final service = FirebaseService();

            // 1) 공인중개사 컬렉션 먼저 확인
            final brokerData = await service.getBroker(user.uid);
            if (brokerData != null) {
              final brokerName = (brokerData['ownerName'] as String?) ??
                  (brokerData['businessName'] as String?) ??
                  '공인중개사';
              final brokerId =
                  (brokerData['brokerId'] as String?) ?? user.uid;

              // FCM 토큰 저장 (푸시 알림용)
              await FCMService().getAndSaveToken(user.uid);

              return <String, dynamic>{
                'uid': user.uid,
                'name': brokerName,
                'userType': 'broker',
                'brokerId': brokerId,
                'brokerData': brokerData,
              };
            }

            // 2) 일반 사용자 컬렉션 조회
            final data = await service.getUser(user.uid);
            final userName = data != null
                ? (data['name'] as String? ??
                    data['id'] as String? ??
                    user.email?.split('@').first ??
                    '사용자')
                : (user.email?.split('@').first ?? '사용자');

            // FCM 토큰 저장 (푸시 알림용)
            await FCMService().getAndSaveToken(user.uid);

            return <String, dynamic>{
              'uid': user.uid,
              'name': userName,
              'userType': 'user',
              'userData': data,
            };
          }(),
          builder: (context, userSnap) {
            // 에러 발생 시 네트워크 오류 화면 표시 (재시도 가능)
            if (userSnap.hasError) {
              Logger.error('사용자 정보 로드 실패', error: userSnap.error);
              return _NetworkErrorScreen(
                message: '사용자 정보를 불러올 수 없습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.',
                onRetry: () {
                  setState(() {
                    _cachedUserData = null;
                    _cacheVersion++;
                  });
                },
              );
            }
            
            // 로딩 중에는 로딩 인디케이터 표시 (중개사/일반 사용자 구분 전이므로)
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('로그인 정보를 확인하는 중...'),
                    ],
                  ),
                ),
              );
            }

            final profile = userSnap.data;

            // 프로필이 없으면 프로필 완성 페이지로
            if (profile == null) {
              return ProfileCompletionPage(
                userId: user.uid,
                currentName: user.email?.split('@').first,
                onComplete: () {
                  setState(() {
                    _cachedUserData = null;
                    _cacheVersion++;
                  });
                },
              );
            }

            // 캐시 업데이트 (브로커 / 일반 사용자 공통)
            _cachedUserData = profile;

            // 브로커 계정이면 공인중개사 대시보드로 이동
            if (profile['userType'] == 'broker' &&
                profile['brokerData'] != null) {
              final brokerId = profile['brokerId'] ?? profile['uid'];
              final brokerName = profile['name'] ?? '공인중개사';
              return MLSBrokerDashboardPage(
                brokerId: brokerId,
                brokerName: brokerName,
                brokerData: profile['brokerData'],
              );
            }

            // 프로필 완성이 필요한지 확인 (일반 사용자만)
            if (_needsProfileCompletion(profile['userData'])) {
              return ProfileCompletionPage(
                userId: profile['uid'] as String,
                currentName: profile['name'] as String?,
                onComplete: () {
                  setState(() {
                    _cachedUserData = null;
                    _cacheVersion++;
                  });
                },
              );
            }

            // 기본: 일반 사용자 메인 페이지
            return MainPage(
              key: ValueKey('main_${user.uid}'),
              userId: profile['uid'] as String,
              userName: profile['name'] as String,
            );
          },
        );
      },
    );
  }
}
