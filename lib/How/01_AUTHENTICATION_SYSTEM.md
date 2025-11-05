# 01. 인증 시스템 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/01_AUTHENTICATION_SYSTEM.md`

---

## 📋 개요

MyHome 서비스는 Firebase Authentication을 기반으로 한 사용자 인증 시스템을 사용합니다. 일반 사용자와 공인중개사를 분리하여 관리하며, 세션 관리는 자동으로 처리됩니다.

---

## 🔐 인증 구조

### Firebase Authentication 통합

```dart
// lib/main.dart에서 Firebase 초기화
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Firebase initialization error (handled): $e');
  }
  
  runApp(const MyApp());
}
```

### 인증 흐름

```
사용자 입력 (이메일/비밀번호)
    ↓
Firebase Authentication
    ↓
Firestore에서 사용자 정보 조회
    ↓
AuthGate에서 세션 관리
    ↓
MainPage로 이동
```

---

## 👤 일반 사용자 인증

### 1. 로그인

**파일:** `lib/screens/login_page.dart`

**코드 흐름:**

```45:121:lib/screens/login_page.dart
// 일반 사용자 로그인
Future<void> _loginUser() async {
  if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final userData = await _firebaseService.authenticateUser(
      _idController.text,
      _passwordController.text,
    );

    if (userData != null && mounted) {
      final userId = userData['uid'] ?? userData['id'] ?? _idController.text;
      final userName = userData['name'] ?? userId;
      
      Navigator.of(context).pop({
        'userId': userId,
        'userName': userName,
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인에 실패했습니다. 아이디와 비밀번호를 확인해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    String errorMessage = '로그인에 실패했습니다.';
    
    switch (e.code) {
      case 'user-not-found':
        errorMessage = '등록되지 않은 이메일입니다.\n회원가입을 먼저 진행해주세요.';
        break;
      case 'wrong-password':
        errorMessage = '비밀번호가 올바르지 않습니다.';
        break;
      case 'invalid-email':
        errorMessage = '이메일 형식이 올바르지 않습니다.';
        break;
      default:
        errorMessage = '로그인 중 오류가 발생했습니다.';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

**FirebaseService.authenticateUser() 구현:**

```22:69:lib/api_request/firebase_service.dart
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
      print('❌ [Firebase] UID가 없습니다');
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
      print('❌ [Firebase] Firestore에 사용자 정보 없음');
      return null;
    }
  } on FirebaseAuthException catch (e) {
    print('❌ [Firebase] 사용자 인증 실패: ${e.code} - ${e.message}');
    return null;
  } catch (e) {
    print('❌ [Firebase] 사용자 인증 실패: $e');
    return null;
  }
}
```

**핵심 로직:**

1. **ID → 이메일 변환**: 사용자가 ID만 입력해도 `@myhome.com`을 자동으로 추가
2. **Firebase Authentication 로그인**: `signInWithEmailAndPassword()` 호출
3. **Firestore에서 사용자 정보 조회**: UID를 기반으로 추가 정보 가져오기
4. **에러 처리**: FirebaseAuthException을 캐치하여 구체적인 에러 메시지 표시

---

### 2. 회원가입

**파일:** `lib/screens/signup_page.dart`

**코드 흐름:**

```58:188:lib/screens/signup_page.dart
Future<void> _signup() async {
  // 필수 입력 검증 (이메일, 비밀번호만)
  if (_emailController.text.isEmpty ||
      _passwordController.text.isEmpty ||
      _passwordConfirmController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('이메일과 비밀번호를 입력해주세요.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // 이메일 형식 검증
  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('올바른 이메일 형식을 입력해주세요.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // 휴대폰 번호 형식 검증 (입력된 경우만)
  if (_phoneController.text.isNotEmpty) {
    final phone = _phoneController.text.replaceAll('-', '').replaceAll(' ', '');
    if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 휴대폰 번호를 입력해주세요. (예: 010-1234-5678)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
  }

  // 비밀번호 길이 검증 (6자 이상)
  if (_passwordController.text.length < 6) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('비밀번호는 6자 이상 입력해주세요.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // 비밀번호 일치 확인
  if (_passwordController.text != _passwordConfirmController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('비밀번호가 일치하지 않습니다.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // 약관 동의 확인
  if (!_agreeToTerms || !_agreeToPrivacy) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('필수 약관에 동의해주세요.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // 이메일에서 ID 추출 (@ 앞부분)
    final id = _emailController.text.split('@')[0];
    
    // 휴대폰 번호 (입력된 경우만)
    final phone = _phoneController.text.isNotEmpty 
        ? _phoneController.text.replaceAll('-', '').replaceAll(' ', '')
        : null;
    
    // 기본 이름 (이메일 앞부분 사용)
    final name = id;
    
    final success = await _firebaseService.registerUser(
      id,
      _passwordController.text,
      name,
      email: _emailController.text,
      phone: phone,
      role: 'user', // 모든 사용자는 일반 사용자로 등록
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료되었습니다. 로그인해주세요.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 존재하는 이메일입니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원가입 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

**FirebaseService.registerUser() 구현:**

```123:174:lib/api_request/firebase_service.dart
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
      print('❌ [Firebase] UID 생성 실패');
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
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    
    return true;
  } on FirebaseAuthException catch (e) {
    print('❌ [Firebase] 등록 오류: ${e.code} - ${e.message}');
    if (e.code == 'email-already-in-use') {
    } else if (e.code == 'weak-password') {
    }
    return false;
  } catch (e) {
    print('❌ [Firebase] 사용자 등록 실패: $e');
    return false;
  }
}
```

**검증 로직:**

1. **이메일 형식 검증**: 정규식으로 이메일 형식 확인
2. **휴대폰 번호 검증**: 입력된 경우에만 형식 확인 (선택사항)
3. **비밀번호 길이**: 최소 6자 이상
4. **비밀번호 일치**: 비밀번호와 확인 비밀번호 일치 확인
5. **약관 동의**: 필수 약관 동의 확인

**비밀번호 강도 계산:**

```33:56:lib/screens/signup_page.dart
// 비밀번호 강도 계산
int _getPasswordStrength(String password) {
  if (password.isEmpty) return 0;
  int strength = 0;
  if (password.length >= 8) strength++;
  if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
  if (RegExp(r'[0-9]').hasMatch(password)) strength++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
  return strength;
}

Color _getPasswordStrengthColor(int strength) {
  if (strength <= 1) return Colors.red;
  if (strength == 2) return Colors.orange;
  if (strength == 3) return Colors.blue;
  return Colors.green;
}

String _getPasswordStrengthText(int strength) {
  if (strength <= 1) return '약함';
  if (strength == 2) return '보통';
  if (strength == 3) return '강함';
  return '매우 강함';
}
```

---

### 3. 세션 관리 (AuthGate)

**파일:** `lib/main.dart`

**코드:**

```138:205:lib/main.dart
/// Firebase Auth 상태를 구독하여 새로고침 시에도 로그인 유지
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Map<String, dynamic>? _cachedUserData;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        if (snapshot.connectionState == ConnectionState.waiting && user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (user == null) {
          _cachedUserData = null;
          return const MainPage(userId: '', userName: '');
        }
        
        // 캐시된 데이터가 있고 같은 사용자면 즉시 반환
        if (_cachedUserData != null && _cachedUserData!['uid'] == user.uid) {
          return MainPage(
            key: ValueKey('main_${_cachedUserData!['uid']}'),
            userId: _cachedUserData!['uid'],
            userName: _cachedUserData!['name'],
          );
        }
        
        // Firestore에서 사용자 표시 이름 로드
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.uid),
          future: FirebaseService().getUser(user.uid),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            final data = userSnap.data;
            final userName = data != null
                ? (data['name'] as String? ?? data['id'] as String? ?? user.email?.split('@').first ?? '사용자')
                : (user.email?.split('@').first ?? '사용자');
            
            // 캐시 업데이트
            _cachedUserData = {'uid': user.uid, 'name': userName};
            
            return MainPage(
              key: ValueKey('main_${user.uid}'),
              userId: user.uid,
              userName: userName,
            );
          },
        );
      },
    );
  }
}
```

**핵심 기능:**

1. **StreamBuilder 사용**: `authStateChanges()` 스트림을 구독하여 실시간 인증 상태 확인
2. **캐싱**: 사용자 데이터를 캐시하여 불필요한 Firestore 조회 방지
3. **자동 로그인**: 새로고침해도 로그인 상태 유지

---

### 4. 비밀번호 재설정

**파일:** `lib/screens/forgot_password_page.dart`

**FirebaseService.sendPasswordResetEmail() 구현:**

```176:188:lib/api_request/firebase_service.dart
/// 비밀번호 재설정 이메일 발송 (Firebase Authentication 내장 기능)
Future<bool> sendPasswordResetEmail(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
    return true;
  } on FirebaseAuthException catch (e) {
    print('❌ [Firebase] 이메일 발송 실패: ${e.code} - ${e.message}');
    return false;
  } catch (e) {
    print('❌ [Firebase] 이메일 발송 실패: $e');
    return false;
  }
}
```

**동작 방식:**

1. 사용자가 이메일 입력
2. Firebase Authentication의 `sendPasswordResetEmail()` 호출
3. Firebase가 자동으로 비밀번호 재설정 이메일 발송
4. 사용자가 이메일 링크 클릭하여 새 비밀번호 설정

---

### 5. 회원탈퇴

**FirebaseService.deleteUserAccount() 구현:**

```198:241:lib/api_request/firebase_service.dart
/// 회원탈퇴
/// [userId] 사용자 UID
/// 반환: String? - 성공 시 null, 실패 시 에러 메시지
Future<String?> deleteUserAccount(String userId) async {
  try {
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return '로그인된 사용자가 없습니다.';
    }
    
    // 현재 사용자가 본인인지 확인
    if (currentUser.uid != userId) {
      return '본인의 계정만 삭제할 수 있습니다.';
    }
    
    // 1. Firestore에서 사용자 데이터 삭제
    try {
      await _firestore.collection(_usersCollectionName).doc(userId).delete();
    } catch (e) {
      print('⚠️ [Firebase] Firestore 데이터 삭제 실패 (계속 진행): $e');
      // Firestore 삭제 실패해도 계속 진행
    }
    
    // 2. Firebase Authentication에서 사용자 삭제
    await currentUser.delete();
    
    // 3. 로그아웃 처리
    await _auth.signOut();
    
    return null; // 성공
  } on FirebaseAuthException catch (e) {
    print('❌ [Firebase] 회원탈퇴 실패: ${e.code} - ${e.message}');
    
    if (e.code == 'requires-recent-login') {
      return '보안을 위해 다시 로그인한 후 탈퇴해주세요.';
    } else {
      return '회원탈퇴 중 오류가 발생했습니다.\n${e.message ?? '알 수 없는 오류'}';
    }
  } catch (e) {
    print('❌ [Firebase] 회원탈퇴 실패: $e');
    return '회원탈퇴 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
  }
}
```

**주요 보안 기능:**

1. **본인 확인**: 현재 로그인한 사용자만 본인 계정 삭제 가능
2. **최근 로그인 확인**: Firebase의 `requires-recent-login` 에러 처리
3. **순차 삭제**: Firestore → Firebase Auth → 로그아웃 순서로 삭제

---

## 🏢 공인중개사 인증

### 1. 공인중개사 로그인

**파일:** `lib/screens/login_page.dart`

**코드:**

```123:177:lib/screens/login_page.dart
// 공인중개사 로그인
Future<void> _loginBroker() async {
  if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final result = await _firebaseService.authenticateBroker(
      _idController.text.trim(),
      _passwordController.text,
    );

    if (result != null && mounted) {
      final brokerId = result['brokerId'] ?? result['uid'];
      final brokerName = result['ownerName'] ?? result['businessName'] ?? '공인중개사';

      // MainPage로 result 반환하여 BrokerDashboardPage로 이동하도록 처리
      Navigator.of(context).pop({
        'userId': brokerId,
        'userName': brokerName,
        'userType': 'broker',
        'brokerData': result,
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인에 실패했습니다. 아이디/비밀번호를 확인해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

**FirebaseService.authenticateBroker() 구현:**

공인중개사는 `brokers` 컬렉션에서 관리되며, 등록번호와 비밀번호로 로그인합니다.

---

### 2. 공인중개사 회원가입

**파일:** `lib/screens/broker/broker_signup_page.dart`

**특징:**

1. **등록번호 검증**: 서울시 API로 등록번호 유효성 확인 (`SeoulBrokerService.validateBroker()`)
2. **대표자명 검증**: 등록번호와 대표자명 일치 확인 (부분 일치 허용, 공백/특수문자 무시)
3. **중복 확인**: 이미 가입된 등록번호인지 확인

**검증 서비스:**
- `lib/api_request/seoul_broker_service.dart` - 검증 로직 통합
- 등록번호 정규화 자동 처리
- 대표자명 비교 (공백, 특수문자 무시)

---

## 🔒 보안 고려사항

### 1. 비밀번호 암호화

- Firebase Authentication이 자동으로 비밀번호를 해시화하여 저장
- 평문 비밀번호는 절대 저장되지 않음

### 2. 세션 관리

- Firebase Authentication이 자동으로 세션 관리
- 토큰 기반 인증 (JWT)
- 세션 만료 자동 처리

### 3. API 키 보안

**현재 상태:**
- API 키가 하드코딩되어 있음 (`lib/constants/app_constants.dart`)
- 향후 환경 변수 또는 Firebase Remote Config로 이동 예정

---

## 📊 사용자 데이터 구조

### Firestore `users` 컬렉션

```dart
{
  uid: String,              // Firebase Auth UID (문서 ID)
  id: String,               // 사용자 ID (이메일 앞부분)
  name: String,             // 이름
  email: String,            // 이메일
  phone: String?,           // 휴대폰 번호 (선택사항)
  role: String,             // 'user' | 'admin'
  createdAt: Timestamp,     // 가입일
  updatedAt: Timestamp,     // 수정일
}
```

---

## 🎯 에러 처리

### 주요 에러 코드

1. **user-not-found**: 등록되지 않은 이메일
2. **wrong-password**: 비밀번호 불일치
3. **invalid-email**: 이메일 형식 오류
4. **email-already-in-use**: 이미 존재하는 이메일 (회원가입 시)
5. **weak-password**: 비밀번호가 너무 약함 (회원가입 시)
6. **requires-recent-login**: 최근 로그인이 필요한 작업 (회원탈퇴 시)

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[02_ADDRESS_SEARCH.md](02_ADDRESS_SEARCH.md)** - 주소 검색 및 부동산 정보 조회 상세 설명

