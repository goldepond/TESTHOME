import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/google_sign_in_helper.dart';
import 'package:property/api_request/kakao_sign_in_helper.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/models/broker_review.dart';
import 'package:property/models/notification_model.dart';
import 'package:property/models/chat_model.dart';
import 'package:property/models/report.dart';
import 'package:property/utils/logger.dart';
import 'notification_firebase_service.dart';

class FirebaseService {
  // 싱글톤 패턴 - 인스턴스 재사용으로 성능 향상
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Lazy initialization - Firebase 초기화 이후에 접근
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  static const String _collectionName = 'properties';
  static const String _usersCollectionName = 'users';
  static const String _brokersCollectionName = 'brokers';
  static const String _quoteRequestsCollectionName = 'quoteRequests';
  static const String _brokerReviewsCollectionName = 'brokerReviews';
  static const String _notificationsCollectionName = 'notifications';
  static const String _chatRoomsCollectionName = 'chatRooms';
  static const String _chatMessagesCollectionName = 'chatMessages';
  static const String _reportsCollectionName = 'reports';

  final _notificationService = NotificationFirebaseService();

  // 캐시: 자주 조회되는 데이터 캐싱
  final Map<String, Map<String, dynamic>?> _userCache = {};
  final Map<String, Map<String, dynamic>?> _brokerCache = {};
  DateTime? _lastCacheClear;

  /// 캐시 초기화 (10분마다 자동)
  void _checkCacheExpiry() {
    final now = DateTime.now();
    if (_lastCacheClear == null ||
        now.difference(_lastCacheClear!).inMinutes > 10) {
      _userCache.clear();
      _brokerCache.clear();
      _lastCacheClear = now;
    }
  }

  /// 소셜 로그인용 암호 생성 (provider + socialId + salt 기반 base64 해시)
  /// 단순히 ID를 그대로 사용하지 않고 솔트를 추가하여 예측 불가능하게 만든다.
  String _generateSocialPassword(String provider, String socialId) {
    const salt = 'myhome_social_auth_2024_salt';
    final combined = '$provider:$socialId:$salt';
    final bytes = utf8.encode(combined);
    return '${provider}_${base64Encode(bytes).substring(0, 32)}';
  }

  // 사용자 인증 관련 메서드들
  /// 익명 로그인: 로그인 없이도 UID를 발급받아 데이터를 연결할 수 있게 한다.
  /// 성공 시 기본 사용자 문서를 생성(없을 경우)하고 uid/name/userType 정보를 반환한다.
  Future<Map<String, dynamic>?> signInAnonymously() async {
    try {
      // 이미 로그인되어 있으면 그대로 반환
      if (_auth.currentUser != null) {
        final user = _auth.currentUser!;
        // 사용자 문서 보장
        final userDoc = await _firestore.collection(_usersCollectionName).doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection(_usersCollectionName).doc(user.uid).set({
            'uid': user.uid,
            'id': user.uid,
            'name': '게스트 사용자',
            'userType': user.isAnonymous ? 'anonymous' : 'user',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return {
          'uid': user.uid,
          'id': user.uid,
          'name': user.displayName ?? '게스트 사용자',
          'userType': user.isAnonymous ? 'anonymous' : 'user',
        };
      }
      
      final credential = await _auth.signInAnonymously();
      final uid = credential.user?.uid;
      if (uid == null) return null;
      
      // 기본 사용자 문서 생성
      await _firestore.collection(_usersCollectionName).doc(uid).set({
        'uid': uid,
        'id': uid,
        'name': '게스트 사용자',
        'userType': 'anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return {
        'uid': uid,
        'id': uid,
        'name': '게스트 사용자',
        'userType': 'anonymous',
      };
    } on FirebaseAuthException catch (e) {
      Logger.error('익명 로그인 실패 (FirebaseAuthException)', error: e);
      return null;
    } catch (e) {
      Logger.error('익명 로그인 실패', error: e);
      return null;
    }
  }
  
  /// 익명 계정을 이메일/비밀번호 계정으로 업그레이드한다.
  /// 같은 UID를 유지하므로 기존 데이터(견적 이력 등)가 그대로 연결된다.
  Future<bool> linkAnonymousAccountToEmail(String email, String password, String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      if (!user.isAnonymous) return true; // 이미 정식 계정이면 성공 처리
      
      // 이메일 형식 보정 (@ 없으면 내부 도메인 추가)
      String authEmail = email;
      if (!authEmail.contains('@')) {
        authEmail = '$email@myhome.com';
      }
      
      final credential = EmailAuthProvider.credential(email: authEmail, password: password);
      await user.linkWithCredential(credential);
      await user.updateDisplayName(name);
      
      // 사용자 문서 업데이트
      await _firestore.collection(_usersCollectionName).doc(user.uid).set({
        'uid': user.uid,
        'id': user.uid,
        'name': name,
        'email': authEmail,
        'userType': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return true;
    } on FirebaseAuthException catch (e, stackTrace) {
      Logger.error(
        '익명 계정 업그레이드 실패 (FirebaseAuth)',
        error: e,
        stackTrace: stackTrace,
        context: 'linkAnonymousAccountToEmail',
      );
      return false;
    } catch (e, stackTrace) {
      Logger.error(
        '익명 계정 업그레이드 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'linkAnonymousAccountToEmail',
      );
      return false;
    }
  }
  
  /// 통합 로그인 (일반 사용자/공인중개사 자동 구분)
  /// [emailOrId] 이메일 또는 ID (ID는 @myhome.internal 도메인 추가)
  /// [password] 비밀번호
  /// [isSocialLogin] 소셜 로그인 전용 내부 이메일 생성 허용 여부 (기본값: false)
  /// 반환: Map에 'userType' 필드 포함 ('user' 또는 'broker')
  Future<Map<String, dynamic>?> authenticateUnified(String emailOrId, String password, {bool isSocialLogin = false}) async {
    try {
      // ID를 이메일 형식으로 변환 (@ 없으면 도메인 추가)
      String email = emailOrId;
      if (!emailOrId.contains('@')) {
        // 소셜 로그인 전용 내부 이메일 생성 - 일반 로그인에서는 차단
        if (!isSocialLogin) {
          throw FirebaseAuthException(
            code: 'invalid-email',
            message: '유효한 이메일 주소를 입력해주세요.',
          );
        }
        email = '$emailOrId@myhome.internal';
      }
      
      // Firebase Authentication으로 로그인
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        return null;
      }
      
      // 먼저 brokers 컬렉션 확인
      final brokerDoc = await _firestore.collection(_brokersCollectionName).doc(uid).get();
      if (brokerDoc.exists) {
        final data = brokerDoc.data() ?? <String, dynamic>{};
        return {
          ...data,
          'uid': uid,
          'brokerId': data['brokerId'] ?? emailOrId,
          'email': data['email'] ?? email,
          'userType': 'broker',
        };
      }
      
      // users 컬렉션 확인
      final userRef = _firestore.collection(_usersCollectionName).doc(uid);
      final userDoc = await userRef.get();
      Map<String, dynamic> data;

      if (userDoc.exists) {
        data = userDoc.data() ?? <String, dynamic>{};
      } else {
        // 기존 사용자 문서가 없더라도, 인증에 성공했으면 기본 사용자 문서를 생성해준다.
        final idValue =
            emailOrId.contains('@') ? emailOrId.split('@').first : emailOrId;
        data = <String, dynamic>{
          'uid': uid,
          'id': idValue,
          'name':
              userCredential.user?.displayName ?? idValue,
          'email': userCredential.user?.email ?? email,
          'userType': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await userRef.set(data, SetOptions(merge: true));
      }

      return {
        ...data,
        'uid': uid,
        'id': data['id'] ?? (userCredential.user?.email?.split('@').first ?? uid),
        'email': data['email'] ?? userCredential.user?.email ?? email,
        'name': data['name'] ?? userCredential.user?.displayName ?? (data['id'] ?? uid),
        'userType': 'user',
      };
    } on FirebaseAuthException {
      rethrow;
    } catch (e, stackTrace) {
      Logger.error(
        '통합 로그인 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'authenticateUnified',
      );
      return null;
    }
  }
  
  /// 사용자 로그인 (Firebase Authentication 사용)
  /// [emailOrId] 이메일 또는 ID (ID는 @myhome.com 도메인 추가)
  /// [password] 비밀번호
  Future<Map<String, dynamic>?> authenticateUser(String emailOrId, String password) async {
    try {
      
      // ID를 이메일 형식으로 변환 (@ 없으면 도메인 추가)
      String email = emailOrId;
      if (!emailOrId.contains('@')) {
        email = '$emailOrId@myhome.com';
      }
      
      
      // Firebase Authentication으로만 로그인 (Fallback 제거 - 보안상 위험)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        return null;
      }
      
      
      // Firestore에서 추가 사용자 정보 가져오기
      final doc = await _firestore.collection(_usersCollectionName).doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        // 항상 uid/id/email/name을 보장해서 반환
        return {
          ...data,
          'uid': uid,
          'id': data['id'] ?? (userCredential.user?.email?.split('@').first ?? uid),
          'email': data['email'] ?? userCredential.user?.email ?? email,
          'name': data['name'] ?? userCredential.user?.displayName ?? (data['id'] ?? uid),
        };
      } else {
        return null;
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      Logger.error(
        '사용자 로그인 실패 (FirebaseAuth)',
        error: e,
        stackTrace: stackTrace,
        context: 'authenticateUser',
      );
      return null;
    } catch (e, stackTrace) {
      Logger.error(
        '사용자 로그인 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'authenticateUser',
      );
      return null;
    }
  }

  // 사용자 조회
  Future<Map<String, dynamic>?> getUser(String id, {bool useCache = true}) async {
    if (id.isEmpty) return null;

    _checkCacheExpiry();

    // 캐시 확인
    if (useCache && _userCache.containsKey(id)) {
      return _userCache[id];
    }

    try {
      final doc = await _firestore.collection(_usersCollectionName).doc(id).get();
      final data = doc.exists ? doc.data() : null;
      // 캐시 저장
      _userCache[id] = data;
      return data;
    } catch (e) {
      Logger.error('사용자 조회 실패', error: e);
      return null;
    }
  }

  /// 관리자 권한 확인 (Firebase Custom Claims 기반)
  /// 서버에서 부여한 admin 커스텀 클레임이 있는지 확인합니다.
  Future<bool> isAdmin(String userId) async {
    try {
      if (userId.isEmpty) return false;

      final user = _auth.currentUser;
      if (user == null || user.uid != userId) return false;

      // Custom Claims에서 admin 확인 (서버에서만 설정 가능, 클라이언트 조작 불가)
      final idTokenResult = await user.getIdTokenResult(true);
      return idTokenResult.claims?['admin'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 사용자 등록 (Firebase Authentication 사용)
  /// [id] 사용자 ID (이메일 형식으로 자동 변환)
  /// [password] 비밀번호 (Firebase에서 자동 암호화)
  /// [name] 이름
  /// [email] 실제 이메일 (선택사항, 없으면 id@myhome.com 사용)
  /// [phone] 휴대폰 번호 (선택사항)
  Future<bool> registerUser(
    String id, 
    String password, 
    String name, {
    String? email,
    String? phone,
    String role = 'user',
  }) async {
    try {
      
      // 이메일 형식 생성 (실제 이메일이 없으면 id@myhome.com)
      final authEmail = email ?? '$id@myhome.com';
      
      // Firebase Authentication으로 계정 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,  // Firebase가 자동으로 암호화!
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        return false;
      }
      
      // displayName 설정
      await userCredential.user?.updateDisplayName(name);
      
      // Firestore에 추가 사용자 정보 저장 (비밀번호 제외!)
      await _firestore.collection(_usersCollectionName).doc(uid).set({
        'uid': uid,
        'id': id,
        'name': name,
        'email': email ?? authEmail,
        'phone': phone,
        'role': role,
        'profileCompleted': true, // 이메일 회원가입 시 프로필 이미 완성됨
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } on FirebaseAuthException catch (e) {
      Logger.error('회원가입 실패 (FirebaseAuthException): ${e.code}', error: e);
      return false;
    } catch (e) {
      Logger.error('회원가입 실패', error: e);
      return false;
    }
  }
  
  /// 이메일 중복 확인 (Firestore users 컬렉션 조회 방식)
  /// 임시 계정 생성/삭제 대신 Firestore에서 이메일 존재 여부를 확인한다.
  Future<bool> isEmailAlreadyRegistered(String email) async {
    try {
      // 1차: Firestore users 컬렉션에서 이메일 조회
      final querySnapshot = await _firestore
          .collection(_usersCollectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return true;
      }

      // 2차: brokers 컬렉션에서도 확인
      final brokerSnapshot = await _firestore
          .collection(_brokersCollectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return brokerSnapshot.docs.isNotEmpty;
    } catch (e) {
      Logger.error('이메일 중복 확인 실패', error: e);
      return false;
    }
  }

  /// 비밀번호 재설정 이메일 발송 (Firebase Authentication 내장 기능)
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e, stackTrace) {
      Logger.error(
        '비밀번호 재설정 이메일 발송 실패 (FirebaseAuth)',
        error: e,
        stackTrace: stackTrace,
        context: 'sendPasswordResetEmail',
      );
      return false;
    } catch (e, stackTrace) {
      Logger.error(
        '비밀번호 재설정 이메일 발송 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'sendPasswordResetEmail',
      );
      return false;
    }
  }

  /// 비밀번호 변경 (재인증 포함)
  /// 반환: null 이면 성공, 문자열이면 에러 메시지
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return '로그인이 필요합니다.';
      }
      final email = user.email;
      if (email == null || email.isEmpty) {
        return '이메일 정보를 확인할 수 없습니다.';
      }

      // 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);

      // 새 비밀번호로 변경
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        return '현재 비밀번호가 올바르지 않습니다.';
      }
      if (e.code == 'weak-password') {
        return '새 비밀번호가 너무 약합니다. 6자 이상으로 설정해주세요.';
      }
      if (e.code == 'requires-recent-login') {
        return '보안을 위해 다시 로그인한 후 시도해주세요.';
      }
      return '비밀번호 변경 중 오류가 발생했습니다.';
    } catch (e, stackTrace) {
      Logger.error(
        '비밀번호 변경 실패 (알 수 없는 오류)',
        error: e,
        stackTrace: stackTrace,
        context: 'changePassword',
      );
      return '비밀번호 변경 중 알 수 없는 오류가 발생했습니다.';
    }
  }

  // 이메일 찾기 기능은 정책상 제거되었습니다.
  
  /// 현재 로그인된 사용자 가져오기
  User? get currentUser => _auth.currentUser;
  
  /// 로그아웃
  /// 소셜 로그인 세션도 함께 클리어하여 다음 로그인 시 계정 선택 가능
  Future<void> signOut() async {
    // 소셜 로그인 세션 클리어
    try {
      await GoogleSignInService.signOut();
    } catch (e) {
      Logger.warning('Google 로그아웃 실패 (무시): $e');
    }
    try {
      await KakaoSignInService.signOut();
    } catch (e) {
      Logger.warning('Kakao 로그아웃 실패 (무시): $e');
    }

    // Firebase 로그아웃
    await _auth.signOut();
    Logger.info('로그아웃 완료 (소셜 세션 포함)');
  }

  /// 회원탈퇴
  /// [userId] 사용자 UID
  /// 반환: String? - 성공 시 null, 실패 시 에러 메시지
  Future<String?> deleteUserAccount(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return '로그인된 사용자가 없습니다.';
      }

      if (currentUser.uid != userId) {
        return '본인의 계정만 삭제할 수 있습니다.';
      }

      // 1. Firebase Auth 삭제 먼저 (실패 시 Firestore 건드리지 않음)
      try {
        await currentUser.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          final isGoogle = currentUser.providerData
              .any((p) => p.providerId == 'google.com');
          if (!isGoogle) {
            return '보안을 위해 다시 로그인한 후 탈퇴해주세요.';
          }
          // Google 계정: 재인증 후 재시도
          final reauthed = await GoogleSignInService.reauthenticate();
          if (!reauthed) {
            return '재인증에 실패했습니다. 다시 시도해주세요.';
          }
          try {
            await _auth.currentUser?.delete();
          } on FirebaseAuthException catch (retryError) {
            return '회원탈퇴 중 오류가 발생했습니다.\n${retryError.message ?? '알 수 없는 오류'}';
          }
        } else {
          return '회원탈퇴 중 오류가 발생했습니다.\n${e.message ?? '알 수 없는 오류'}';
        }
      }

      // 2. Auth 삭제 성공 후 Firestore 데이터 삭제
      try {
        await _firestore.collection(_usersCollectionName).doc(userId).delete();
      } catch (e) {
        // 개인정보는 Auth 삭제로 이미 접근 불가 — Firestore 실패는 무시
      }

      // 3. 로그아웃
      await _auth.signOut();

      return null; // 성공
    } catch (e) {
      return '회원탈퇴 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
    }
  }

  // 사용자 정보 업데이트 (일반)
  Future<bool> updateUser(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_usersCollectionName).doc(id).set(data, SetOptions(merge: true));
      // 캐시 무효화 - 다음 getUser 호출 시 최신 데이터 반환
      _userCache.remove(id);
      Logger.info('[Firebase] 사용자 정보 업데이트 성공: $id (캐시 무효화됨)');
      return true;
    } catch (e) {
      Logger.error('[Firebase] 사용자 정보 업데이트 실패: $e');
      return false;
    }
  }

  // 사용자 이름 업데이트
  Future<bool> updateUserName(String id, String newName) async {
    try {
      await _firestore.collection(_usersCollectionName).doc(id).set({
        'name': newName,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      _userCache.remove(id); // 캐시 무효화
      return true;
    } catch (e) {
      Logger.error('사용자 이름 업데이트 실패', error: e);
      return false;
    }
  }

  // 사용자 전화번호 업데이트
  Future<bool> updateUserPhone(String id, String newPhone) async {
    try {
      await _firestore.collection(_usersCollectionName).doc(id).set({
        'phone': newPhone,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      _userCache.remove(id); // 캐시 무효화
      return true;
    } catch (e) {
      Logger.error('사용자 전화번호 업데이트 실패', error: e);
      return false;
    }
  }

  // ========== 기본 스케줄 설정 ==========

  /// 기본 주간 시간 블록 저장
  /// weeklyTimeBlocks: {1: ['morning', 'afternoon'], 2: ['evening'], ...}
  /// 1=월요일, 7=일요일
  Future<bool> updateDefaultWeeklyTimeBlocks(
    String userId,
    Map<int, List<String>> weeklyTimeBlocks,
  ) async {
    try {
      // Firebase는 int key를 지원하지 않으므로 String으로 변환
      final convertedBlocks = weeklyTimeBlocks.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      await _firestore.collection(_usersCollectionName).doc(userId).set({
        'defaultWeeklyTimeBlocks': convertedBlocks,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      Logger.info('[Firebase] 기본 주간 시간 블록 저장 성공: $userId');
      return true;
    } catch (e) {
      Logger.error('[Firebase] 기본 주간 시간 블록 저장 실패: $e');
      return false;
    }
  }

  /// 기본 주간 시간 블록 조회
  Future<Map<int, List<String>>> getDefaultWeeklyTimeBlocks(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollectionName).doc(userId).get();
      if (!doc.exists) return {};

      final data = doc.data();
      if (data == null || data['defaultWeeklyTimeBlocks'] == null) return {};

      final blocks = data['defaultWeeklyTimeBlocks'] as Map<String, dynamic>;
      return blocks.map(
        (key, value) => MapEntry(
          int.parse(key),
          List<String>.from(value),
        ),
      );
    } catch (e) {
      Logger.error('[Firebase] 기본 주간 시간 블록 조회 실패: $e');
      return {};
    }
  }

  /// 방문 불가 날짜 저장 (Negative Selection)
  Future<bool> updateBlockedDates(
    String userId,
    List<DateTime> blockedDates,
  ) async {
    try {
      await _firestore.collection(_usersCollectionName).doc(userId).set({
        'blockedDates': blockedDates.map((d) => d.toIso8601String()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      Logger.info('[Firebase] 방문 불가 날짜 저장 성공: $userId');
      return true;
    } catch (e) {
      Logger.error('[Firebase] 방문 불가 날짜 저장 실패: $e');
      return false;
    }
  }

  /// 방문 불가 날짜 조회
  Future<List<DateTime>> getBlockedDates(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollectionName).doc(userId).get();
      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null || data['blockedDates'] == null) return [];

      final dates = data['blockedDates'] as List<dynamic>;
      return dates.map((d) => DateTime.parse(d as String)).toList();
    } catch (e) {
      Logger.error('[Firebase] 방문 불가 날짜 조회 실패: $e');
      return [];
    }
  }

  // 모든 사용자 조회
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      
      final querySnapshot = await _firestore.collection(_usersCollectionName).get();
      final users = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['firestoreId'] = doc.id;
        return data;
      }).toList();
      
      return users;
    } catch (e) {
      Logger.error('사용자 목록 조회 실패', error: e);
      return [];
    }
  }

  // Create
  Future<DocumentReference?> addProperty(Property property) async {
    try {

      final docRef = await _firestore.collection(_collectionName).add(property.toMap());

      return docRef;
    } catch (e) {
      Logger.error('매물 등록 실패', error: e);
      return null;
    }
  }

  /// 매물 등록과 견적 상태 업데이트를 트랜잭션으로 동시에 처리
  Future<bool> registerPropertyFromQuote({
    required Property property,
    required String quoteRequestId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 견적 요청 문서 참조
        final quoteRef = _firestore.collection(_quoteRequestsCollectionName).doc(quoteRequestId);
        
        // 2. 견적 요청 문서 읽기 (트랜잭션 내에서 읽어야 함)
        final quoteDoc = await transaction.get(quoteRef);
        if (!quoteDoc.exists) {
          throw Exception("Quote request does not exist!");
        }

        // 3. 이미 등록된 매물인지 확인 (중복 방지)
        final quoteData = quoteDoc.data();
        if (quoteData != null && quoteData['isPropertyRegistered'] == true) {
          throw Exception("Property already registered!");
        }

        // 4. 매물 문서 참조 생성
        final propertyRef = _firestore.collection(_collectionName).doc();
        
        // 5. 매물 등록 (새 문서 생성)
        transaction.set(propertyRef, property.toMap());

        // 6. 견적 요청 문서 업데이트 (매물 등록됨 표시)
        transaction.update(quoteRef, {
          'isPropertyRegistered': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 7. [알림] 소유자/임대인에게 매물 등록 알림 전송
        if (quoteData != null) {
          final userId = quoteData['userId'];
          if (userId != null && userId.isNotEmpty) {
            final notificationRef = _firestore.collection(_notificationsCollectionName).doc();
            transaction.set(notificationRef, {
              'userId': userId,
              'title': '매물 등록 완료',
              'message': '요청하신 견적 내용으로 매물 등록이 완료되었습니다.\n집 구하기 목록에서 확인해보세요!',
              'type': 'property_registered',
              'relatedId': propertyRef.id,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 매물 등록 임시 저장 (견적 요청 문서에 저장)
  Future<bool> savePropertyRegistrationDraft({
    required String quoteRequestId,
    required Map<String, dynamic> draftData,
  }) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(quoteRequestId).update({
        'propertyRegistrationDraft': draftData,
        'propertyRegistrationDraftSavedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.error('매물 등록 임시저장 실패', error: e);
      return false;
    }
  }

  /// 매물 등록 임시 저장 데이터 조회
  Future<Map<String, dynamic>?> getPropertyRegistrationDraft(String quoteRequestId) async {
    try {
      final doc = await _firestore.collection(_quoteRequestsCollectionName).doc(quoteRequestId).get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      return data?['propertyRegistrationDraft'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Read - 사용자별 부동산 목록
  Stream<List<Property>> getProperties(String userName) {
    return _firestore
        .collection(_collectionName)
        .where('mainContractor', isEqualTo: userName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
                data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
                data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
                return Property.fromMap(data);
              })
              .toList();
        });
  }

  // Read - 사용자별 부동산 목록 (Future 버전)
  Future<List<Property>> getPropertiesByUserId(String userId) async {
    // userId 체크 - 빈 문자열이면 빈 리스트 반환
    if (userId.isEmpty) {
      return [];
    }
    
    try {
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
            data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
            data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
            return Property.fromMap(data);
          })
          .toList();
    } catch (e) {
      Logger.error('사용자 매물 목록 조회 실패', error: e);
      return [];
    }
  }

  // Read - 모든 사용자의 부동산 목록 (내집사기 페이지용) - Stream 버전
  Stream<List<Property>> getAllProperties() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
                data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
                data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
                return Property.fromMap(data);
              })
              .toList();
        });
  }

  // Read - 모든 사용자의 부동산 목록 (내집사기 페이지용) - Future 버전
  Future<List<Property>> getAllPropertiesList() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
            data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
            data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
            return Property.fromMap(data);
          })
          .toList();
    } catch (e) {
      Logger.error('전체 매물 목록 조회 실패', error: e);
      return [];
    }
  }

  // Read - 특정 부동산 조회
  Future<Property?> getProperty(String propertyId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(propertyId).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
        data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
        data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
        return Property.fromMap(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Read - 주소로 부동산 검색
  Future<List<Property>> searchPropertiesByAddress(String address) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('address', isGreaterThanOrEqualTo: address)
          .where('address', isLessThan: '$address\uf8ff')
          .get();
      
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
            data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
            data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
            return Property.fromMap(data);
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Read - 거래 유형별 부동산 조회
  Stream<List<Property>> getPropertiesByType(String userName, String transactionType) {
    return _firestore
        .collection(_collectionName)
        .where('mainContractor', isEqualTo: userName)
        .where('transactionType', isEqualTo: transactionType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
              data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
              data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
              return Property.fromMap(data);
            })
            .toList());
  }

  // Read - 상태별 부동산 조회
  Stream<List<Property>> getPropertiesByStatus(String userName, String status) {
    return _firestore
        .collection(_collectionName)
        .where('mainContractor', isEqualTo: userName)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
              data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
              data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
              return Property.fromMap(data);
            })
            .toList());
  }

  // Update
  Future<bool> updateProperty(String id, Property property) async {
    try {
      
      await _firestore.collection(_collectionName).doc(id).update({
        ...property.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      Logger.error('매물 업데이트 실패', error: e);
      return false;
    }
  }

  // Update - 부분 업데이트
  Future<bool> updatePropertyFields(String id, Map<String, dynamic> fields) async {
    try {

      await _firestore.collection(_collectionName).doc(id).update({
        ...fields,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      Logger.error('매물 부분 업데이트 실패', error: e);
      return false;
    }
  }

  // Delete
  Future<bool> deleteProperty(String id) async {
    try {
      
      await _firestore.collection(_collectionName).doc(id).delete();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // 매물 삭제 (연계 데이터 포함)
  Future<bool> deletePropertyWithRelatedData(String propertyId) async {
    try {
      
      // 매물 자체 삭제
      await _firestore.collection(_collectionName).doc(propertyId).delete();
      
      return true;
    } catch (e) {
      return false;
    }
  }


  // 통계 정보 조회
  Future<Map<String, dynamic>> getPropertyStats(String userName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mainContractor', isEqualTo: userName)
          .get();
      
      final properties = querySnapshot.docs
          .map((doc) => Property.fromMap(doc.data()))
          .toList();
      
      final totalCount = properties.length;
      final byType = <String, int>{};
      final byStatus = <String, int>{};
      final totalValue = properties.fold<int>(0, (total, p) => total + p.price);
      
      for (final property in properties) {
        byType[property.transactionType] = (byType[property.transactionType] ?? 0) + 1;
        if (property.status != null) {
          byStatus[property.status!] = (byStatus[property.status!] ?? 0) + 1;
        }
      }
      
      return {
        'totalCount': totalCount,
        'totalValue': totalValue,
        'byType': byType,
        'byStatus': byStatus,
        'averageValue': totalCount > 0 ? totalValue ~/ totalCount : 0,
      };
    } catch (e) {
      return {
        'totalCount': 0,
        'totalValue': 0,
        'byType': {},
        'byStatus': {},
        'averageValue': 0,
      };
    }
  }

  // 배치 저장 (여러 부동산 데이터 한번에 저장)
  Future<List<String>> addPropertiesBatch(List<Property> properties) async {
    try {
      
      final batch = _firestore.batch();
      final docRefs = <DocumentReference>[];
      
      for (final property in properties) {
        final docRef = _firestore.collection(_collectionName).doc();
        batch.set(docRef, property.toMap());
        docRefs.add(docRef);
      }
      
      await batch.commit();
      
      final ids = docRefs.map((ref) => ref.id).toList();
      return ids;
    } catch (e) {
      return [];
    }
  }

  // ===== 관리자 기능 =====

  // 모든 매물 삭제 (관리자용)
  Future<bool> deleteAllProperties() async {
    try {
      
      // 모든 매물 조회
      final propertiesQuery = await _firestore.collection(_collectionName).get();
      
      // 모든 매물 삭제
      final propertyBatch = _firestore.batch();
      for (final doc in propertiesQuery.docs) {
        propertyBatch.delete(doc.reference);
      }
      await propertyBatch.commit();
      
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // 특정 사용자의 모든 매물 삭제
  Future<bool> deleteAllPropertiesByUser(String userName) async {
    try {
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mainContractor', isEqualTo: userName)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return true;
      }
      
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      return true;
    } catch (e) {
      return false;
    }
  }


  // 중개업자 정보 업데이트
  Future<bool> updateUserBrokerInfo(String userId, Map<String, dynamic> brokerInfo) async {
    try {
      
      await _firestore.collection(_usersCollectionName).doc(userId).set({
        'brokerInfo': brokerInfo,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      Logger.error('중개업자 정보 업데이트 실패', error: e);
      return false;
    }
  }

  /// 공인중개사 정보 업데이트 (brokers 컬렉션)
  /// [brokerIdOrUid] brokerId 또는 UID
  /// [brokerInfo] 업데이트할 정보
  Future<bool> updateBrokerInfo(String brokerIdOrUid, Map<String, dynamic> brokerInfo) async {
    try {
      
      // 먼저 UID로 조회
      final brokerDoc = await _firestore.collection(_brokersCollectionName).doc(brokerIdOrUid).get();
      
      String? docId;
      if (brokerDoc.exists) {
        docId = brokerIdOrUid; // UID로 찾음
      } else {
        // brokerId로 조회
        final querySnapshot = await _firestore
            .collection(_brokersCollectionName)
            .where('brokerId', isEqualTo: brokerIdOrUid)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          docId = querySnapshot.docs.first.id;
        }
      }
      
      if (docId == null) {
        return false;
      }
      
      // 업데이트할 데이터 준비 (기존 필드와 매핑)
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // brokerInfo의 필드를 brokers 컬렉션의 필드로 매핑
      if (brokerInfo.containsKey('broker_name')) {
        updateData['ownerName'] = brokerInfo['broker_name'];
      }
      if (brokerInfo.containsKey('broker_phone')) {
        updateData['phoneNumber'] = brokerInfo['broker_phone'];
      }
      // 개인 주소는 제거됨 (사무소 주소만 사용)
      // if (brokerInfo.containsKey('broker_address')) {
      //   updateData['address'] = brokerInfo['broker_address'];
      // }
      // 등록번호는 업데이트하지 않음 (고정값)
      // if (brokerInfo.containsKey('broker_license_number')) {
      //   updateData['brokerRegistrationNumber'] = brokerInfo['broker_license_number'];
      // }
      if (brokerInfo.containsKey('broker_office_name')) {
        updateData['businessName'] = brokerInfo['broker_office_name'];
      }
      if (brokerInfo.containsKey('broker_office_address')) {
        updateData['roadAddress'] = brokerInfo['broker_office_address'];
      }
      if (brokerInfo.containsKey('broker_introduction')) {
        updateData['introduction'] = brokerInfo['broker_introduction'];
      }
      // 승인 상태
      if (brokerInfo.containsKey('verified')) {
        updateData['verified'] = brokerInfo['verified'];
      }

      await _firestore.collection(_brokersCollectionName).doc(docId).update(updateData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 매물 수정
  Future<bool> updatePropertyByBroker({
    required String propertyId,
    required Property property,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(propertyId).update({
        ...property.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /* =========================================== */
  /* 견적문의 관리 메서드들 */
  /* =========================================== */

  /// 견적문의 저장
  Future<String?> saveQuoteRequest(QuoteRequest quoteRequest) async {
    try {
      final docRef = await _firestore.collection(_quoteRequestsCollectionName).add(quoteRequest.toMap());
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// 모든 견적문의 조회 (관리자용)
  Stream<List<QuoteRequest>> getAllQuoteRequests() {
    try {
      return _firestore
          .collection(_quoteRequestsCollectionName)
          .orderBy('requestDate', descending: true)
          .snapshots()
          .map((snapshot) {
            Logger.info('견적문의 조회: ${snapshot.docs.length}개 발견');
            return snapshot.docs
                .map((doc) => QuoteRequest.fromMap(doc.id, doc.data()))
                .toList();
          })
          .handleError((error) {
            Logger.error('견적문의 조회 오류', error: error);
            return <QuoteRequest>[];
          });
    } catch (e) {
      Logger.error('견적문의 스트림 생성 오류', error: e);
      return Stream.value([]);
    }
  }

  /// 특정 사용자의 견적문의 조회 (userId가 userName으로 저장된 과거 데이터도 포함)
  Stream<List<QuoteRequest>> getQuoteRequestsByUser(String userId) async* {
    // userId 체크 - 빈 문자열이면 빈 스트림 반환
    if (userId.isEmpty) {
      yield* Stream.value([]);
      return;
    }
    
    try {
      
      // 현재 사용자 정보 조회 (userName 얻기 위해)
      // userId가 실제 userId인지 userName인지 확인
      Map<String, dynamic>? userData;
      String userName = '';
      String actualUserId = userId; // 실제 사용할 userId
      
      try {
        userData = await getUser(userId);
        final nameFromMap = userData != null ? userData['name'] : null;
        final idFromMap = userData != null ? userData['id'] : null;
        final uidFromMap = userData != null ? userData['uid'] : null;
        userName = (nameFromMap is String && nameFromMap.isNotEmpty)
            ? nameFromMap
            : (idFromMap is String ? idFromMap : '');
        actualUserId = (uidFromMap is String && uidFromMap.isNotEmpty)
            ? uidFromMap
            : (idFromMap is String && idFromMap.isNotEmpty ? idFromMap : userId);
      } catch (e) {
        // getUser 실패 시 userId가 userName일 수 있음
        userName = userId; // userId가 실제로 userName일 수 있음
        actualUserId = userId; // userId를 그대로 사용
      }
      
      // userName이 비어있으면 userId를 userName으로 사용
      if (userName.isEmpty) {
        userName = userId;
      }
      
      
      // 두 가지 쿼리: 1) userId로 직접 조회, 2) userName으로 과거 데이터 조회
      yield* _firestore
          .collection(_quoteRequestsCollectionName)
          .orderBy('requestDate', descending: true)
          .snapshots()
          .map((snapshot) {
            final allDocs = snapshot.docs;
            
            // userId와 일치하거나 userName과 일치하는 문서만 필터링
            final filteredDocs = allDocs.where((doc) {
              final data = doc.data();
              final docUserId = data['userId'] as String? ?? '';
              final docUserName = data['userName'] as String? ?? '';
              
              // userId가 일치하거나 userName이 일치하는 경우
              final matchesUserId = docUserId.isNotEmpty && 
                  (docUserId == userId || docUserId == actualUserId);
              final matchesUserName = userName.isNotEmpty && docUserName == userName;
              
              return matchesUserId || matchesUserName;
            }).toList();
            
            return filteredDocs
                .map((doc) => QuoteRequest.fromMap(doc.id, doc.data()))
                .toList();
          });
    } catch (e) {
      yield* Stream.value([]);
    }
  }

  /// 견적문의 상태 업데이트
  Future<bool> updateQuoteRequestStatus(String requestId, String newStatus) async {
    try {
      Logger.info('견적문의 상태 업데이트: $requestId → $newStatus');
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.error('견적문의 상태 업데이트 실패', error: e);
      return false;
    }
  }

  /// 사용자가 특정 공인중개사를 최종 선택(배정)할 때 호출
  ///
  /// - [requestId]: 선택된 견적문의 ID
  /// - [userId]: 사용자 ID (users 컬렉션 document ID)
  ///
  /// 기능:
  /// - 견적문의 문서에 `isSelectedByUser`, `selectedAt` 필드 기록
  /// - 사용자 `users` 문서에서 휴대폰 번호를 조회해 `userPhone` 필드로 복사
  /// - [알림] 공인중개사에게 선택 알림 전송
  Future<bool> assignQuoteToBroker({
    required String requestId,
    required String userId,
  }) async {
    try {
      // 사용자 정보 조회 (연락처 가져오기)
      final userData = await getUser(userId);
      final String? phone = (userData != null ? userData['phone'] : null) as String?;

      final updateData = <String, dynamic>{
        'isSelectedByUser': true,
        'selectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (phone != null && phone.isNotEmpty) {
        updateData['userPhone'] = phone;
      }

      await _firestore
          .collection(_quoteRequestsCollectionName)
          .doc(requestId)
          .update(updateData);

      // [알림] 공인중개사에게 알림 전송
      try {
        // 견적 요청 정보 조회
        final quoteDoc = await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).get();
        if (quoteDoc.exists) {
          final quoteData = quoteDoc.data();
          final brokerRegistrationNumber = quoteData?['brokerRegistrationNumber'];
          
          if (brokerRegistrationNumber != null) {
            // 공인중개사 UID 찾기
            final brokerInfo = await getBrokerByRegistrationNumber(brokerRegistrationNumber);
            if (brokerInfo != null) {
              final brokerUid = brokerInfo['uid'];
              if (brokerUid != null) {
                await _notificationService.sendNotification(
                  userId: brokerUid,
                  title: '매칭 성공! 🎉',
                  message: '고객님이 제안해주신 상담을 선택해주셨어요! 🙏\n지금 바로 연락처를 확인해보세요.',
                  type: 'broker_selected',
                  relatedId: requestId,
                );
              }
            }
          }
        }
      } catch (e) {
        // 알림 전송 실패해도 전체 로직은 성공 처리
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 견적문의가 매물로 등록되었음을 표시
  Future<bool> markQuoteAsPropertyRegistered(String requestId) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'isPropertyRegistered': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 공인중개사 이메일 첨부 (관리자용)
  Future<bool> attachEmailToBroker(String requestId, String brokerEmail) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'brokerEmail': brokerEmail,
        'emailAttachedAt': FieldValue.serverTimestamp(),
        'emailAttachedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 견적문의 링크 ID 업데이트
  Future<bool> updateQuoteRequestLinkId(String requestId, String linkId) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'inquiryLinkId': linkId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 견적문의 답변 업데이트
  Future<bool> updateQuoteRequestAnswer(String requestId, String answer) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'brokerAnswer': answer,
        'answerDate': FieldValue.serverTimestamp(),
        'status': 'answered',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 공인중개사 상세 답변 업데이트 (회원용)
  Future<bool> updateQuoteRequestDetailedAnswer({
    required String requestId,
    String? recommendedPrice,
    String? minimumPrice,
    String? expectedDuration,
    String? promotionMethod,
    String? commissionRate,
    String? recentCases,
    String? brokerAnswer,
  }) async {
    try {
      
      final updateData = <String, dynamic>{
        'answerDate': FieldValue.serverTimestamp(),
        'status': 'answered', // completed -> answered (라이프사이클상 '비교중' 단계로 매핑되도록 수정)
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (recommendedPrice != null && recommendedPrice.isNotEmpty) {
        updateData['recommendedPrice'] = recommendedPrice;
      }
      if (minimumPrice != null && minimumPrice.isNotEmpty) {
        updateData['minimumPrice'] = minimumPrice;
      }
      if (expectedDuration != null && expectedDuration.isNotEmpty) {
        updateData['expectedDuration'] = expectedDuration;
      }
      if (promotionMethod != null && promotionMethod.isNotEmpty) {
        updateData['promotionMethod'] = promotionMethod;
      }
      if (commissionRate != null && commissionRate.isNotEmpty) {
        updateData['commissionRate'] = commissionRate;
      }
      if (recentCases != null && recentCases.isNotEmpty) {
        updateData['recentCases'] = recentCases;
      }
      if (brokerAnswer != null && brokerAnswer.isNotEmpty) {
        updateData['brokerAnswer'] = brokerAnswer;
      }

      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update(updateData);

      // [알림] 사용자에게 답변 도착 알림 전송
      try {
        // 견적 요청 정보 조회
        final quoteDoc = await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).get();
        if (quoteDoc.exists) {
          final quoteData = quoteDoc.data();
          final userId = quoteData?['userId'];
          
          if (userId != null) {
            await sendNotification(
              userId: userId,
              title: '견적 답변 도착 📨',
              message: '공인중개사님이 견적 요청에 상세 답변을 남겼습니다.\n지금 바로 확인해보세요!',
              type: 'quote_answered',
              relatedId: requestId,
            );
          }
        }
      } catch (e) {
        // 알림 전송 실패해도 전체 로직은 성공 처리
      }

      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 견적문의에 주소/좌표/단지 API 캐시를 저장 (재호출 방지)
  ///
  /// 이미 저장된 값이 있을 경우 덮어쓰지 않는 것이 기본 정책이며,
  /// 필요한 값만 부분 업데이트합니다.
  Future<bool> updateQuoteRequestApiCache({
    required String requestId,
    Map<String, String>? fullAddrAPIData,
    Map<String, dynamic>? vworldCoordinates,
    String? kaptCode,
    Map<String, dynamic>? aptInfo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fullAddrAPIData != null && fullAddrAPIData.isNotEmpty) {
        updateData['fullAddrAPIData'] = fullAddrAPIData;
      }
      if (vworldCoordinates != null && vworldCoordinates.isNotEmpty) {
        updateData['vworldCoordinates'] = vworldCoordinates;
      }
      if (kaptCode != null && kaptCode.isNotEmpty) {
        updateData['kaptCode'] = kaptCode;
      }
      if (aptInfo != null && aptInfo.isNotEmpty) {
        updateData['aptInfo'] = aptInfo;
      }

      // 업데이트할 데이터가 없으면 스킵
      if (updateData.length <= 1) {
        return true;
      }

      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).set(updateData, SetOptions(merge: true));
      return true;
    } catch (e) {
      Logger.error('견적문의 API 캐시 업데이트 실패', error: e);
      return false;
    }
  }

  /// 링크 ID로 견적문의 조회
  Future<Map<String, dynamic>?> getQuoteRequestByLinkId(String linkId) async {
    try {
      final snapshot = await _firestore
          .collection(_quoteRequestsCollectionName)
          .where('inquiryLinkId', isEqualTo: linkId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    } catch (e) {
      return null;
    }
  }

  /// 견적문의 삭제
  Future<bool> deleteQuoteRequest(String requestId) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /* =========================================== */
  /* 공인중개사 후기 / 추천 관련 메서드 */
  /* =========================================== */

  /// 공인중개사 후기 저장 (신규 또는 수정)
  Future<String?> saveBrokerReview(BrokerReview review) async {
    try {
      if (review.id.isEmpty) {
        final docRef = await _firestore.collection(_brokerReviewsCollectionName).add(review.toMap());
        return docRef.id;
      } else {
        await _firestore
            .collection(_brokerReviewsCollectionName)
            .doc(review.id)
            .set(review.toMap(), SetOptions(merge: true));
        return review.id;
      }
    } catch (e) {
      return null;
    }
  }

  /// 특정 공인중개사(등록번호 기준)에 대한 후기 스트림
  Stream<List<BrokerReview>> getBrokerReviews(String brokerRegistrationNumber) {
    try {
      return _firestore
          .collection(_brokerReviewsCollectionName)
          .where('brokerRegistrationNumber', isEqualTo: brokerRegistrationNumber)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BrokerReview.fromMap(doc.id, doc.data()))
                .toList();
          });
    } catch (e) {
      return Stream.value(<BrokerReview>[]);
    }
  }

  /// 사용자가 특정 견적에 대해 이미 남긴 후기가 있는지 조회
  Future<BrokerReview?> getUserReviewForQuote({
    required String userId,
    required String brokerRegistrationNumber,
    required String quoteRequestId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_brokerReviewsCollectionName)
          .where('userId', isEqualTo: userId)
          .where('brokerRegistrationNumber', isEqualTo: brokerRegistrationNumber)
          .where('quoteRequestId', isEqualTo: quoteRequestId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return BrokerReview.fromMap(doc.id, doc.data());
    } catch (e) {
      return null;
    }
  }

  /* =========================================== */
  /* 공인중개사 관련 메서드 */
  /* =========================================== */

  /// 공인중개사 등록
  /// [brokerId] 공인중개사 ID (이메일 또는 일반 ID)
  /// [password] 비밀번호
  /// [brokerInfo] 공인중개사 정보 (등록번호, 대표자명 등)
  /// 
  /// 반환: String? - 성공 시 null, 실패 시 에러 메시지
  Future<String?> registerBroker({
    required String brokerId,
    required String password,
    required Map<String, dynamic> brokerInfo,
  }) async {
    try {
      // 중개업 등록번호 중복 체크
      final registrationNumber = brokerInfo['brokerRegistrationNumber'] as String?;
      if (registrationNumber != null && registrationNumber.isNotEmpty) {
        final duplicateCheck = await _firestore
            .collection(_brokersCollectionName)
            .where('brokerRegistrationNumber', isEqualTo: registrationNumber)
            .limit(1)
            .get();

        if (duplicateCheck.docs.isNotEmpty) {
          return '이미 등록된 중개업 등록번호입니다.\n다른 등록번호를 입력하거나 기존 계정으로 로그인해주세요.';
        }
      }

      // 이메일 형식 생성
      String email = brokerId;
      if (!brokerId.contains('@')) {
        email = '$brokerId@myhome.com';
      }

      // Firebase Authentication으로 계정 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;

      if (uid == null) {
        return '계정 생성에 실패했습니다. 다시 시도해주세요.';
      }

      // displayName 설정
      await userCredential.user?.updateDisplayName(
        brokerInfo['ownerName'] ?? brokerId,
      );

      // Firestore에 공인중개사 정보 저장
      final docData = {
        'brokerId': brokerId,
        'uid': uid,
        'email': email,
        'userType': 'broker',
        ...brokerInfo,
        'verified': brokerInfo['verified'] ?? false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_brokersCollectionName).doc(uid).set(docData);
      Logger.info('공인중개사 등록 완료: $brokerId');

      return null; // 성공
    } on FirebaseAuthException catch (e) {
      Logger.warning('공인중개사 등록 실패', metadata: {'code': e.code});

      if (e.code == 'email-already-in-use') {
        return '이미 사용 중인 이메일입니다.\n로그인해주세요.';
      } else if (e.code == 'weak-password') {
        return '비밀번호가 너무 약합니다.\n6자 이상의 비밀번호를 사용해주세요.';
      } else if (e.code == 'invalid-email') {
        return '올바른 이메일 형식을 입력해주세요.';
      } else {
        return '회원가입에 실패했습니다.\n${e.message ?? '알 수 없는 오류가 발생했습니다.'}';
      }
    } catch (e) {
      Logger.warning('공인중개사 등록 예외', metadata: {'error': e.toString()});
      return '회원가입 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
    }
  }

  /// 공인중개사 로그인
  /// [emailOrId] 이메일 또는 ID
  /// [password] 비밀번호
  Future<Map<String, dynamic>?> authenticateBroker(String emailOrId, String password) async {
    try {
      
      // ID를 이메일 형식으로 변환
      String email = emailOrId;
      if (!emailOrId.contains('@')) {
        email = '$emailOrId@myhome.com';
      }
      
      
      // Firebase Authentication으로만 로그인
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        return null;
      }
      
      
      // Firestore에서 공인중개사 정보 가져오기
      final doc = await _firestore.collection(_brokersCollectionName).doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        return {
          ...data,
          'uid': uid,
          'brokerId': data['brokerId'] ?? emailOrId,
          'email': data['email'] ?? email,
          'userType': 'broker',
        };
      } else {
        return null;
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      Logger.error(
        '공인중개사 로그인 실패 (FirebaseAuth)',
        error: e,
        stackTrace: stackTrace,
        context: 'authenticateBroker',
      );
      return null;
    } catch (e, stackTrace) {
      Logger.error(
        '공인중개사 로그인 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'authenticateBroker',
      );
      return null;
    }
  }

  /// 전체 공인중개사 조회 (관리자용)
  Future<List<Map<String, dynamic>>> getAllBrokers() async {
    try {
      final snapshot = await _firestore.collection(_brokersCollectionName).get();
      
      final brokers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      return brokers;
    } catch (e) {
      return [];
    }
  }

  /// 공인중개사 정보 조회
  Future<Map<String, dynamic>?> getBroker(String brokerId, {bool useCache = true}) async {
    if (brokerId.isEmpty) return null;

    _checkCacheExpiry();

    // 캐시 확인
    if (useCache && _brokerCache.containsKey(brokerId)) {
      return _brokerCache[brokerId];
    }

    try {
      // UID로 조회
      final doc = await _firestore.collection(_brokersCollectionName).doc(brokerId).get();
      if (doc.exists) {
        final data = doc.data();
        _brokerCache[brokerId] = data;
        return data;
      }

      // brokerId로 조회
      final querySnapshot = await _firestore
          .collection(_brokersCollectionName)
          .where('brokerId', isEqualTo: brokerId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        _brokerCache[brokerId] = data;
        return data;
      }

      _brokerCache[brokerId] = null;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 공인중개사 삭제 (관리자용)
  /// [brokerIdOrUid] brokerId 또는 문서 ID
  Future<bool> deleteBroker(String brokerIdOrUid) async {
    try {
      // 먼저 문서 ID 찾기
      String? docId;
      
      // UID로 조회
      final brokerDoc = await _firestore.collection(_brokersCollectionName).doc(brokerIdOrUid).get();
      if (brokerDoc.exists) {
        docId = brokerIdOrUid;
      } else {
        // brokerId로 조회
        final querySnapshot = await _firestore
            .collection(_brokersCollectionName)
            .where('brokerId', isEqualTo: brokerIdOrUid)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          docId = querySnapshot.docs.first.id;
        }
      }
      
      if (docId == null) {
        return false;
      }
      
      // 중개사 문서 삭제
      await _firestore.collection(_brokersCollectionName).doc(docId).delete();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 공인중개사에게 온 견적문의 조회
  /// [brokerRegistrationNumber] 공인중개사 등록번호
  Stream<List<QuoteRequest>> getBrokerQuoteRequests(String brokerRegistrationNumber) {
    try {
      return _firestore
          .collection(_quoteRequestsCollectionName)
          .where('brokerRegistrationNumber', isEqualTo: brokerRegistrationNumber)
          // orderBy 제거: 인덱스 없이도 작동하도록 메모리에서 정렬
          .snapshots()
          .map((snapshot) {
            try {
              final quotes = snapshot.docs
                  .map((doc) {
                    try {
                      return QuoteRequest.fromMap(doc.id, doc.data());
                    } catch (e) {
                      return null;
                    }
                  })
                  .whereType<QuoteRequest>() // null 제거
                  .toList();
              
              // 메모리에서 날짜 기준 내림차순 정렬
              quotes.sort((a, b) => b.requestDate.compareTo(a.requestDate));
              
              return quotes;
            } catch (e) {
              return <QuoteRequest>[]; // 오류 발생 시 빈 리스트 반환
            }
          });
    } catch (e) {
      // 초기 오류는 빈 Stream으로 반환
      return Stream.value(<QuoteRequest>[]);
    }
  }

  /// 공인중개사가 등록번호로 조회 (중복 가입 방지)
  Future<Map<String, dynamic>?> getBrokerByRegistrationNumber(String registrationNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(_brokersCollectionName)
          .where('brokerRegistrationNumber', isEqualTo: registrationNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      Logger.warning('등록번호 조회 실패', metadata: {'error': e.toString()});
      return null;
    }
  }

  /// 여러 공인중개사를 한 번에 조회 (배치 최적화)
  /// Firestore의 'in' 쿼리를 사용하여 성능 향상
  Future<Map<String, Map<String, dynamic>>> getBrokersByRegistrationNumbers(
    List<String> registrationNumbers,
  ) async {
    try {
      if (registrationNumbers.isEmpty) return {};
      
      final Map<String, Map<String, dynamic>> result = {};
      const batchSize = 10; // Firestore 'in' 쿼리는 최대 10개까지만 지원
      
      // 10개씩 나누어 배치 조회
      for (int i = 0; i < registrationNumbers.length; i += batchSize) {
        final batch = registrationNumbers.skip(i).take(batchSize).toList();
        
        final querySnapshot = await _firestore
            .collection(_brokersCollectionName)
            .where('brokerRegistrationNumber', whereIn: batch)
            .get();
        
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          final regNo = data['brokerRegistrationNumber'] as String?;
          if (regNo != null) {
            result[regNo] = data;
          }
        }
      }
      
      return result;
    } catch (e) {
      return {};
    }
  }

  /* =========================================== */
  /* 알림 관리 메서드들 — NotificationFirebaseService에 위임 */
  /* =========================================== */

  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) => _notificationService.sendNotification(
        userId: userId, title: title, message: message,
        type: type, relatedId: relatedId,
      );

  Stream<List<NotificationModel>> getUserNotifications(String userId) =>
      _notificationService.getUserNotifications(userId);

  Future<bool> markNotificationAsRead(String notificationId) =>
      _notificationService.markNotificationAsRead(notificationId);

  Future<bool> markAllNotificationsAsRead(String userId) =>
      _notificationService.markAllNotificationsAsRead(userId);

  /* =========================================== */
  /* 채팅 관련 메서드 */
  /* =========================================== */

  /// 채팅방 생성 또는 조회
  Future<String?> createOrGetChatRoom({
    required String quoteRequestId,
    required String userId,
    required String brokerId,
    required String userPhone,
    required String brokerPhone,
  }) async {
    try {
      // 이미 존재하는 채팅방인지 확인
      final snapshot = await _firestore
          .collection(_chatRoomsCollectionName)
          .where('quoteRequestId', isEqualTo: quoteRequestId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }

      // 새 채팅방 생성
      final chatRoom = ChatRoom(
        id: '',
        quoteRequestId: quoteRequestId,
        userId: userId,
        brokerId: brokerId,
        userPhone: userPhone,
        brokerPhone: brokerPhone,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        lastMessage: '대화가 시작되었습니다.',
      );

      final docRef = await _firestore.collection(_chatRoomsCollectionName).add(chatRoom.toMap());
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// 메시지 전송
  Future<bool> sendMessage({
    required String roomId,
    required String senderId,
    required String message,
  }) async {
    try {
      // 1. 메시지 저장
      await _firestore.collection(_chatMessagesCollectionName).add({
        'roomId': roomId,
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 2. 채팅방 마지막 메시지 업데이트
      await _firestore.collection(_chatRoomsCollectionName).doc(roomId).update({
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 채팅 메시지 스트림
  Stream<List<ChatMessage>> getChatMessages(String roomId) {
    return _firestore
        .collection(_chatMessagesCollectionName)
        .where('roomId', isEqualTo: roomId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromMap(doc.id, doc.data())).toList();
    });
  }

  /// 내 채팅방 목록 조회
  Stream<List<ChatRoom>> getMyChatRooms(String userId) {
    return _firestore
        .collection(_chatRoomsCollectionName)
        .where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('brokerId', isEqualTo: userId),
        ))
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatRoom.fromMap(doc.id, doc.data())).toList();
    });
  }

  /// 채팅방 정보 조회
  Future<Map<String, dynamic>?> getChatRoom(String roomId) async {
    try {
      final doc = await _firestore.collection(_chatRoomsCollectionName).doc(roomId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      Logger.error('채팅방 정보 조회 실패', error: e);
      return null;
    }
  }

  // ============================================================
  // 소셜 로그인 (임시 비활성화 - 추후 구현)
  // ============================================================

  /// 카카오 로그인
  /// 카카오 OAuth로 로그인 후 Firebase Anonymous 계정과 연결하여 인증 상태 유지
  Future<Map<String, dynamic>?> signInWithKakao() async {
    Logger.info('[Firebase 카카오] ========== signInWithKakao 시작 ==========');

    try {
      // 플랫폼 지원 여부 확인
      Logger.info('[Firebase 카카오] 1. 플랫폼 지원 여부 확인...');
      if (!KakaoSignInService.isSupported) {
        Logger.warning('[Firebase 카카오] - 이 플랫폼에서 지원되지 않습니다.');
        return null;
      }
      Logger.info('[Firebase 카카오] - 플랫폼 지원됨 ✓');

      // 카카오 로그인 수행
      Logger.info('[Firebase 카카오] 2. KakaoSignInService.signIn() 호출...');
      final kakaoUser = await KakaoSignInService.signIn();

      if (kakaoUser == null) {
        Logger.info('[Firebase 카카오] - 카카오 로그인 취소됨 또는 실패');
        return null;
      }

      Logger.info('[Firebase 카카오] 3. 카카오 사용자 정보 수신 완료');
      final kakaoId = kakaoUser['id'] as String;
      final nickname = kakaoUser['nickname'] as String? ?? '카카오 사용자';
      final email = kakaoUser['email'] as String?;
      final profileImageUrl = kakaoUser['profileImageUrl'] as String?;

      Logger.info('[Firebase 카카오] - kakaoId: $kakaoId');
      Logger.info('[Firebase 카카오] - nickname: $nickname');
      Logger.info('[Firebase 카카오] - email: $email');
      Logger.info('[Firebase 카카오] - profileImageUrl: ${profileImageUrl != null ? "있음" : "없음"}');

      // Firebase Anonymous 로그인 (카카오는 Firebase OAuth Provider가 없음)
      // 카카오 ID를 기반으로 고유한 이메일 생성하여 Firebase에 연결
      final kakaoEmail = email ?? 'kakao_$kakaoId@myhome.com';
      Logger.info('[Firebase 카카오] 4. Firebase 이메일 생성: $kakaoEmail');

      User? firebaseUser;

      // 먼저 기존 계정이 있는지 확인
      Logger.info('[Firebase 카카오] 5. Firebase 기존 계정 로그인 시도...');
      final kakaoPassword = _generateSocialPassword('kakao', kakaoId);

      try {
        // 카카오 ID로 생성한 이메일로 로그인 시도
        final credential = await _auth.signInWithEmailAndPassword(
          email: kakaoEmail,
          password: kakaoPassword,
        );
        firebaseUser = credential.user;
        Logger.info('[Firebase 카카오] - 기존 계정 로그인 성공: ${firebaseUser?.uid}');
      } on FirebaseAuthException catch (e) {
        Logger.info('[Firebase 카카오] - Firebase Auth 예외: ${e.code}');
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // 기존 계정이 없으면 새로 생성
          Logger.info('[Firebase 카카오] 6. 신규 계정 생성 시도...');
          try {
            final credential = await _auth.createUserWithEmailAndPassword(
              email: kakaoEmail,
              password: kakaoPassword,
            );
            firebaseUser = credential.user;
            Logger.info('[Firebase 카카오] - 계정 생성 성공: ${firebaseUser?.uid}');

            Logger.info('[Firebase 카카오] - displayName 업데이트 중...');
            await firebaseUser?.updateDisplayName(nickname);
            if (profileImageUrl != null) {
              Logger.info('[Firebase 카카오] - photoURL 업데이트 중...');
              await firebaseUser?.updatePhotoURL(profileImageUrl);
            }
            Logger.info('[Firebase 카카오] - 프로필 업데이트 완료');
          } on FirebaseAuthException catch (createError) {
            Logger.error('[Firebase 카카오] - 계정 생성 실패: ${createError.code}');
            // email-already-in-use: 이미 계정이 있는데 로그인이 안 됐다면 비밀번호 문제
            // 이 경우 비밀번호를 재설정하거나 다른 처리 필요
            if (createError.code == 'email-already-in-use') {
              Logger.info('[Firebase 카카오] - 이메일이 이미 존재함, 다시 로그인 시도...');
              // 이미 계정이 있다면 혹시 이전에 다른 카카오 ID로 만들어진 것일 수 있음
              // 카카오 이메일이 실제 이메일이면 그걸로 다시 시도
              if (email != null && email != kakaoEmail) {
                try {
                  final retryCredential = await _auth.signInWithEmailAndPassword(
                    email: email,
                    password: kakaoPassword,
                  );
                  firebaseUser = retryCredential.user;
                  Logger.info('[Firebase 카카오] - 실제 이메일로 재로그인 성공');
                } catch (retryError) {
                  Logger.error('[Firebase 카카오] - 재로그인도 실패: $retryError');
                  return null;
                }
              } else {
                return null;
              }
            } else {
              Logger.error('[Firebase 카카오] - 에러 타입: ${createError.runtimeType}');
              return null;
            }
          } catch (createError) {
            Logger.error('[Firebase 카카오] - 계정 생성 실패 (일반): $createError');
            Logger.error('[Firebase 카카오] - 에러 타입: ${createError.runtimeType}');
            return null;
          }
        } else {
          Logger.error('[Firebase 카카오] - 로그인 실패 (예상치 못한 에러): ${e.code}');
          Logger.error('[Firebase 카카오] - 에러 메시지: ${e.message}');
          return null;
        }
      } catch (e) {
        // FirebaseAuthException이 아닌 다른 예외 처리
        Logger.error('[Firebase 카카오] - 예상치 못한 예외: $e');
        Logger.error('[Firebase 카카오] - 예외 타입: ${e.runtimeType}');
        return null;
      }

      if (firebaseUser == null) {
        Logger.error('[Firebase 카카오] - Firebase 사용자 없음 (null)');
        return null;
      }

      // Firestore에 사용자 문서 생성/업데이트
      Logger.info('[Firebase 카카오] 7. Firestore 사용자 문서 확인...');
      final userDoc = await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).get();
      Logger.info('[Firebase 카카오] - 문서 존재 여부: ${userDoc.exists}');
      bool isNewUser = false;

      if (!userDoc.exists) {
        // 신규 사용자 - 문서 생성
        isNewUser = true;
        Logger.info('[Firebase 카카오] 8. Firestore 신규 문서 생성 중...');
        try {
          await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).set({
            'name': nickname,
            'email': email ?? kakaoEmail,
            'photoUrl': profileImageUrl,
            'kakaoId': kakaoId,
            'userType': 'user',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'provider': 'kakao',
          });
          Logger.info('[Firebase 카카오] - Firestore 문서 생성 완료');
        } catch (firestoreError) {
          Logger.error('[Firebase 카카오] - Firestore 문서 생성 실패: $firestoreError');
        }
      } else {
        // 기존 사용자 - 마지막 로그인 시간 업데이트
        Logger.info('[Firebase 카카오] 8. 기존 사용자 - 로그인 시간 업데이트 중...');
        try {
          await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).update({
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
          Logger.info('[Firebase 카카오] - 로그인 시간 업데이트 완료');
        } catch (updateError) {
          Logger.error('[Firebase 카카오] - 로그인 시간 업데이트 실패: $updateError');
        }
      }

      // 최신 사용자 정보 가져오기
      Logger.info('[Firebase 카카오] 9. 최신 사용자 정보 조회...');
      final updatedDoc = await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).get();
      final userData = updatedDoc.data() ?? {};
      Logger.info('[Firebase 카카오] - 조회된 데이터: ${userData.keys.toList()}');

      final result = {
        'uid': firebaseUser.uid,
        'name': userData['name'] ?? nickname,
        'email': userData['email'] ?? email ?? kakaoEmail,
        'photoUrl': profileImageUrl,
        'kakaoId': kakaoId,
        'userType': userData['userType'] ?? 'user',
        'provider': 'kakao',
        'isNewUser': isNewUser,
      };

      Logger.info('[Firebase 카카오] 10. 최종 반환 데이터:');
      Logger.info('[Firebase 카카오] - uid: ${result['uid']}');
      Logger.info('[Firebase 카카오] - name: ${result['name']}');
      Logger.info('[Firebase 카카오] - userType: ${result['userType']}');
      Logger.info('[Firebase 카카오] ========== signInWithKakao 완료 ==========');

      return result;
    } catch (e, stackTrace) {
      Logger.error('[Firebase 카카오] 예외 발생: $e');
      Logger.error('[Firebase 카카오] 에러 타입: ${e.runtimeType}');
      Logger.error('[Firebase 카카오] 스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// 구글 로그인
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    Logger.info('[Firebase Google] ========== signInWithGoogle 시작 ==========');
    try {
      // 플랫폼 지원 여부 확인
      if (!GoogleSignInService.isSupported) {
        Logger.warning('[Firebase Google] 이 플랫폼에서 지원되지 않습니다.');
        return null;
      }
      Logger.info('[Firebase Google] 플랫폼 지원 확인됨');

      // Google Sign-In 수행
      Logger.info('[Firebase Google] GoogleSignInService.signIn() 호출...');
      final userCredential = await GoogleSignInService.signIn();
      Logger.info('[Firebase Google] GoogleSignInService.signIn() 완료: ${userCredential != null ? "성공" : "null"}');

      if (userCredential == null) {
        Logger.info('[Firebase Google] 구글 로그인 취소됨 또는 실패');
        return null;
      }

      final user = userCredential.user;
      Logger.info('[Firebase Google] Firebase User: ${user?.uid ?? "null"}');
      if (user == null) {
        Logger.error('[Firebase Google] Firebase 사용자 없음');
        return null;
      }

      // Firestore에 사용자 문서 생성/업데이트
      Logger.info('[Firebase Google] Firestore 사용자 문서 확인 중...');
      final userDoc = await _firestore.collection(_usersCollectionName).doc(user.uid).get();
      bool isNewUser = false;
      Logger.info('[Firebase Google] 문서 존재 여부: ${userDoc.exists}');

      if (!userDoc.exists) {
        // 신규 사용자 - 문서 생성
        isNewUser = true;
        Logger.info('[Firebase Google] 신규 사용자 - 문서 생성 중...');
        await _firestore.collection(_usersCollectionName).doc(user.uid).set({
          'name': user.displayName ?? '사용자',
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'userType': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'provider': 'google',
        });
        Logger.info('[Firebase Google] 신규 사용자 문서 생성 완료: ${user.uid}');
      } else {
        // 기존 사용자 - 마지막 로그인 시간 업데이트
        Logger.info('[Firebase Google] 기존 사용자 - 로그인 시간 업데이트 중...');
        await _firestore.collection(_usersCollectionName).doc(user.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        Logger.info('[Firebase Google] 기존 사용자 로그인 시간 업데이트 완료: ${user.uid}');
      }

      // 최신 사용자 정보 가져오기
      Logger.info('[Firebase Google] 최신 사용자 정보 조회 중...');
      final updatedDoc = await _firestore.collection(_usersCollectionName).doc(user.uid).get();
      final userData = updatedDoc.data() ?? {};
      Logger.info('[Firebase Google] 사용자 데이터 조회 완료');

      final result = {
        'uid': user.uid,
        'name': userData['name'] ?? user.displayName ?? '사용자',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'userType': userData['userType'] ?? 'user',
        'provider': 'google',
        'isNewUser': isNewUser,
      };
      Logger.info('[Firebase Google] ========== signInWithGoogle 완료 ==========');
      return result;
    } catch (e, stackTrace) {
      Logger.error('[Firebase Google] 예외 발생: $e');
      Logger.error('[Firebase Google] 스택트레이스: $stackTrace');
      return null;
    }
  }

  /// 다른 구글 계정으로 로그인 (계정 선택 UI 강제 표시)
  Future<Map<String, dynamic>?> signInWithNewGoogleAccount() async {
    try {
      if (!GoogleSignInService.isSupported) {
        Logger.warning('구글 로그인은 이 플랫폼에서 지원되지 않습니다.');
        return null;
      }

      final userCredential = await GoogleSignInService.signInWithNewAccount();

      if (userCredential == null) {
        Logger.info('구글 계정 선택 취소됨');
        return null;
      }

      final user = userCredential.user;
      if (user == null) {
        Logger.error('구글 로그인 실패: Firebase 사용자 없음');
        return null;
      }

      // Firestore에 사용자 문서 생성/업데이트 (signInWithGoogle과 동일한 로직)
      final userDoc = await _firestore.collection(_usersCollectionName).doc(user.uid).get();
      bool isNewUser = false;

      if (!userDoc.exists) {
        isNewUser = true;
        await _firestore.collection(_usersCollectionName).doc(user.uid).set({
          'name': user.displayName ?? '사용자',
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'userType': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'provider': 'google',
        });
      } else {
        await _firestore.collection(_usersCollectionName).doc(user.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      final updatedDoc = await _firestore.collection(_usersCollectionName).doc(user.uid).get();
      final userData = updatedDoc.data() ?? {};

      return {
        'uid': user.uid,
        'name': userData['name'] ?? user.displayName ?? '사용자',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'userType': userData['userType'] ?? 'user',
        'provider': 'google',
        'isNewUser': isNewUser,
      };
    } catch (e) {
      Logger.error('다른 구글 계정 로그인 오류: $e');
      return null;
    }
  }

  /// 다른 카카오 계정으로 로그인 (계정 선택 강제)
  Future<Map<String, dynamic>?> signInWithNewKakaoAccount() async {
    try {
      if (!KakaoSignInService.isSupported) {
        Logger.warning('카카오 로그인은 이 플랫폼에서 지원되지 않습니다.');
        return null;
      }

      final kakaoUser = await KakaoSignInService.signInWithNewAccount();

      if (kakaoUser == null) {
        Logger.info('카카오 계정 선택 취소됨');
        return null;
      }

      // signInWithKakao와 동일한 Firebase 연동 로직
      final kakaoId = kakaoUser['id'] as String;
      final nickname = kakaoUser['nickname'] as String? ?? '카카오 사용자';
      final email = kakaoUser['email'] as String?;
      final profileImageUrl = kakaoUser['profileImageUrl'] as String?;

      final kakaoEmail = email ?? 'kakao_$kakaoId@myhome.com';

      User? firebaseUser;

      final kakaoPassword = _generateSocialPassword('kakao', kakaoId);

      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: kakaoEmail,
          password: kakaoPassword,
        );
        firebaseUser = credential.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          final credential = await _auth.createUserWithEmailAndPassword(
            email: kakaoEmail,
            password: kakaoPassword,
          );
          firebaseUser = credential.user;
        } else {
          rethrow;
        }
      }

      if (firebaseUser == null) {
        return null;
      }

      final userDoc = await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).get();
      final bool isNewUser = !userDoc.exists;

      if (isNewUser) {
        await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).set({
          'name': nickname,
          'email': email ?? kakaoEmail,
          'photoUrl': profileImageUrl,
          'kakaoId': kakaoId,
          'userType': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'provider': 'kakao',
        });
      } else {
        await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      final updatedDoc = await _firestore.collection(_usersCollectionName).doc(firebaseUser.uid).get();
      final userData = updatedDoc.data() ?? {};

      return {
        'uid': firebaseUser.uid,
        'name': userData['name'] ?? nickname,
        'email': userData['email'] ?? email ?? kakaoEmail,
        'photoUrl': profileImageUrl,
        'kakaoId': kakaoId,
        'userType': userData['userType'] ?? 'user',
        'provider': 'kakao',
        'isNewUser': isNewUser,
      };
    } catch (e) {
      Logger.error('다른 카카오 계정 로그인 오류: $e');
      return null;
    }
  }

  // ============================================================
  // 알림 관련 메서드 — NotificationFirebaseService에 위임
  // ============================================================

  Stream<int> getUnreadNotificationCount(String userId) =>
      _notificationService.getUnreadNotificationCount(userId);

  Future<({int succeeded, int failed})> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? additionalData,
  }) => _notificationService.sendBulkNotifications(
        userIds: userIds, title: title, message: message,
        type: type, relatedId: relatedId, additionalData: additionalData,
      );

  // ============================================================
  // 중개사 통계 관련 메서드
  // ============================================================

  /// 거래 완료 시 중개사 통계 업데이트
  Future<void> updateBrokerStatsOnDeal({
    required String brokerId,
    required bool isDepositTaken,
  }) async {
    try {
      final docRef = _firestore.collection(_brokersCollectionName).doc(brokerId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;

        final data = doc.data() ?? {};
        final stats = Map<String, dynamic>.from(data['stats'] ?? {});

        // 통계 업데이트
        stats['totalDeals'] = (stats['totalDeals'] ?? 0) + 1;
        if (isDepositTaken) {
          stats['depositTakenCount'] = (stats['depositTakenCount'] ?? 0) + 1;
        } else {
          stats['soldCount'] = (stats['soldCount'] ?? 0) + 1;
        }
        stats['lastUpdatedAt'] = FieldValue.serverTimestamp();

        transaction.update(docRef, {'stats': stats});
      });
    } catch (e, stackTrace) {
      Logger.error(
        '중개사 통계 업데이트 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'updateBrokerStatsOnDeal',
      );
    }
  }

  /// 중개사 통계 조회
  Future<Map<String, dynamic>?> getBrokerStats(String brokerId) async {
    try {
      final doc = await _firestore.collection(_brokersCollectionName).doc(brokerId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return data?['stats'] as Map<String, dynamic>?;
    } catch (e) {
      Logger.error('중개사 통계 조회 실패', error: e, context: 'getBrokerStats');
      return null;
    }
  }

  /// 중개사 리뷰 작성
  Future<bool> createBrokerReview(BrokerReview review) async {
    try {
      // 리뷰 저장
      await _firestore.collection('broker_reviews').add(review.toMap());

      // 중개사 평균 평점 업데이트
      await _updateBrokerAverageRating(review.brokerRegistrationNumber);

      return true;
    } catch (e) {
      Logger.error('리뷰 작성 실패', error: e, context: 'createBrokerReview');
      return false;
    }
  }

  /// 중개사 평균 평점 업데이트
  Future<void> _updateBrokerAverageRating(String brokerRegistrationNumber) async {
    try {
      final reviews = await _firestore
          .collection('broker_reviews')
          .where('brokerRegistrationNumber', isEqualTo: brokerRegistrationNumber)
          .get();

      if (reviews.docs.isEmpty) return;

      double totalRating = 0;
      for (final doc in reviews.docs) {
        totalRating += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
      }

      final averageRating = totalRating / reviews.docs.length;

      // 등록번호로 중개사 문서 찾기
      final brokerQuery = await _firestore
          .collection(_brokersCollectionName)
          .where('registrationNumber', isEqualTo: brokerRegistrationNumber)
          .limit(1)
          .get();

      if (brokerQuery.docs.isNotEmpty) {
        await brokerQuery.docs.first.reference.update({
          'stats.averageRating': averageRating,
          'stats.totalReviews': reviews.docs.length,
        });
      }
    } catch (e) {
      Logger.error('평균 평점 업데이트 실패', error: e, context: '_updateBrokerAverageRating');
    }
  }

  // ========== 신고 관련 메서드 ==========

  /// 신고 제출
  Future<String?> submitReport(Report report) async {
    try {
      final docRef = await _firestore
          .collection(_reportsCollectionName)
          .add(report.toMap());

      Logger.info('신고 제출 완료', metadata: {
        'reportId': docRef.id,
        'brokerId': report.brokerId,
        'reason': report.reason.value,
      });

      return docRef.id;
    } catch (e) {
      Logger.error('신고 제출 실패', error: e, context: 'submitReport');
      return null;
    }
  }

  /// 중개사별 신고 조회 (관리자용)
  Stream<List<Report>> getReportsByBroker(String brokerId) {
    return _firestore
        .collection(_reportsCollectionName)
        .where('brokerId', isEqualTo: brokerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Report.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  /// 상태별 신고 조회 (관리자용)
  Stream<List<Report>> getReportsByStatus(String status) {
    return _firestore
        .collection(_reportsCollectionName)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Report.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  /// 신고자별 신고 조회 (내 신고 내역)
  Stream<List<Report>> getReportsByReporter(String reporterId) {
    return _firestore
        .collection(_reportsCollectionName)
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Report.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  /// 신고 상태 업데이트 (관리자용)
  Future<bool> updateReportStatus({
    required String reportId,
    required String newStatus,
    String? adminNotes,
  }) async {
    try {
      await _firestore.collection(_reportsCollectionName).doc(reportId).update({
        'status': newStatus,
        'adminNotes': adminNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.error('신고 상태 업데이트 실패', error: e, context: 'updateReportStatus');
      return false;
    }
  }

  /// 중개사의 총 신고 횟수 조회
  Future<int> getReportCountForBroker(String brokerId) async {
    try {
      final snapshot = await _firestore
          .collection(_reportsCollectionName)
          .where('brokerId', isEqualTo: brokerId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      Logger.error('신고 횟수 조회 실패', error: e, context: 'getReportCountForBroker');
      return 0;
    }
  }

  /// 매물 북마크 토글 (추가 또는 제거)
  /// users/{userId}.bookmarks 배열에 propertyId를 추가/제거
  Future<bool> toggleBookmark(String userId, String propertyId) async {
    if (userId.isEmpty) return false;
    try {
      final docRef = _firestore.collection(_usersCollectionName).doc(userId);
      final doc = await docRef.get();
      final bookmarks = List<String>.from(doc.data()?['bookmarks'] ?? []);
      final isBookmarked = bookmarks.contains(propertyId);
      if (isBookmarked) {
        await docRef.set({
          'bookmarks': FieldValue.arrayRemove([propertyId]),
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'bookmarks': FieldValue.arrayUnion([propertyId]),
        }, SetOptions(merge: true));
      }
      _userCache.remove(userId); // 캐시 무효화
      return !isBookmarked; // 새 북마크 상태 반환
    } catch (e) {
      Logger.error('북마크 토글 실패', error: e, context: 'toggleBookmark');
      return false;
    }
  }

  /// 사용자의 북마크 목록 조회
  Future<List<String>> getBookmarks(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final doc = await _firestore.collection(_usersCollectionName).doc(userId).get();
      return List<String>.from(doc.data()?['bookmarks'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// 특정 매물을 북마크한 사용자 수 조회
  Future<int> getPropertyBookmarkCount(String propertyId) async {
    try {
      final snap = await _firestore
          .collection(_usersCollectionName)
          .where('bookmarks', arrayContains: propertyId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      Logger.error('북마크 카운트 조회 실패', error: e);
      return 0;
    }
  }
}
