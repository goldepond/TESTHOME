# 🔐 관리자 페이지 접근 방법

## 📌 중요: 이 파일은 Git에 커밋하지 마세요!

이 파일에는 관리자 페이지 접근 URL이 포함되어 있습니다.
보안을 위해 절대 외부에 공개하지 마세요.

---

## 🚀 관리자 페이지 접근 URL

### 로컬 개발 환경
```
http://localhost:58810/#/admin-panel-myhome-2024
```

### 배포 환경
```
https://[your-domain]/#/admin-panel-myhome-2024
```

---

## 📝 사용 방법

1. 위 URL을 브라우저에 입력하여 직접 접근
2. 로그인 없이 바로 관리자 대시보드 사용 가능
3. "홈으로" 버튼을 클릭하면 메인 페이지로 이동

---

## 🔒 보안 권장사항

### 1. URL 보안 강화
- URL을 더 복잡하게 변경하려면 `lib/main.dart`의 `onGenerateRoute`에서 수정
- 예: `/admin-panel-myhome-2024` → `/super-secret-admin-xyz-2024`

### 2. IP 제한 (Firebase Hosting)
```json
// firebase.json
{
  "hosting": {
    "rewrites": [...],
    "headers": [
      {
        "source": "**",
        "headers": [
          {
            "key": "Access-Control-Allow-Origin",
            "value": "your-company-ip-range"
          }
        ]
      }
    ]
  }
}
```

### 3. 인증 추가 (나중에)
- 필요시 `AdminDashboard`에 간단한 비밀번호 입력 화면 추가
- 또는 Firebase Auth를 사용한 관리자 전용 로그인 구현

---

## ⚠️ 주의사항

- ❌ 이 URL을 외부에 공유하지 마세요
- ❌ GitHub 등 public repository에 커밋하지 마세요
- ✅ 회사 내부 문서에만 기록하세요
- ✅ 필요시 URL을 주기적으로 변경하세요

---

## 🔄 URL 변경 방법

`lib/main.dart` 파일에서 URL을 변경할 수 있습니다:

```dart
// lib/main.dart
onGenerateRoute: (settings) {
  // 이 부분의 URL을 변경하세요
  if (settings.name == '/admin-panel-myhome-2024') {  // ← 여기!
    return MaterialPageRoute(
      builder: (context) => const AdminDashboard(
        userId: 'admin',
        userName: '관리자',
      ),
    );
  }
  // ...
}
```

---

## 📞 문제 발생 시

관리자 페이지 접근에 문제가 있다면:
1. URL이 정확한지 확인
2. `flutter run -d chrome` 명령으로 로컬 테스트
3. 브라우저 캐시 삭제 후 재시도
4. 개발자 도구(F12)에서 콘솔 오류 확인

