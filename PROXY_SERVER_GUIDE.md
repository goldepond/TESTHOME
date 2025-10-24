# 🌐 VWorld API 프록시 서버 가이드

## 📌 왜 프록시 서버가 필요한가?

### ❌ **문제: CORS 에러**
```
Access to fetch at 'https://api.vworld.kr/...' has been blocked by CORS policy
```

Flutter Web에서 VWorld API를 **직접 호출**하면 브라우저의 CORS 정책 때문에 차단됩니다.

### ✅ **해결: Node.js 프록시 서버**
```
Flutter Web → Node.js 프록시 (localhost:3001) → VWorld API
```

프록시 서버가 중간에서 요청을 대신 보내주므로 CORS 문제가 해결됩니다!

---

## 🚀 사용 방법

### **1단계: Node.js 패키지 설치**

```bash
npm install
```

**설치되는 패키지:**
- `express`: 웹 서버 프레임워크
- `http-proxy-middleware`: 프록시 미들웨어
- `cors`: CORS 헤더 추가

---

### **2단계: 프록시 서버 시작**

```bash
npm start
```

**또는**

```bash
node proxy-server.js
```

**성공 메시지:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Flutter VWorld API 프록시 서버 시작!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 서버 주소: http://localhost:3001
⏰ 시작 시간: 2025-01-24 14:30:00

📋 사용 가능한 API:
   ✅ /api/geocoder (좌표 변환 - VWorld)
   ✅ /api/land (토지특성 정보 - VWorld)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### **3단계: Flutter 앱 실행**

**새 터미널에서:**

```bash
flutter run -d chrome
```

---

## 📊 API 엔드포인트

### **1. Geocoder API (주소 → 좌표)**

**프록시 URL:**
```
http://localhost:3001/api/geocoder
```

**원본 URL (CORS 에러!):**
```
https://api.vworld.kr/req/address
```

**사용 예시:**
```dart
final uri = Uri.parse('http://localhost:3001/api/geocoder').replace(
  queryParameters: {
    'service': 'address',
    'request': 'getCoord',
    'address': '경기도 성남시 분당구 중앙공원로 54',
    'key': 'YOUR_API_KEY',
    ...
  }
);
```

---

### **2. Land Characteristics API (토지 정보)**

**프록시 URL:**
```
http://localhost:3001/api/land
```

**원본 URL (CORS 에러!):**
```
https://api.vworld.kr/ned/wfs/getLandCharacteristicsWFS
```

**사용 예시:**
```dart
final uri = Uri.parse('http://localhost:3001/api/land').replace(
  queryParameters: {
    'key': 'YOUR_API_KEY',
    'typename': 'dt_d194',
    'bbox': '$longitude,$latitude,$longitude,$latitude',
    ...
  }
);
```

---

## 🔧 트러블슈팅

### **1. `npm: command not found`**

**원인:** Node.js가 설치되지 않음

**해결:**
1. [Node.js 공식 사이트](https://nodejs.org/)에서 다운로드
2. 설치 후 터미널 재시작
3. `node -v` 명령어로 확인

---

### **2. `EADDRINUSE: address already in use`**

**원인:** 포트 3001이 이미 사용 중

**해결 방법 1: 기존 프로세스 종료**
```bash
# Windows
netstat -ano | findstr :3001
taskkill /PID <PID번호> /F

# Mac/Linux
lsof -i :3001
kill -9 <PID번호>
```

**해결 방법 2: 포트 번호 변경**
```javascript
// proxy-server.js
const PORT = 3002; // 다른 포트로 변경
```

```dart
// lib/services/vworld_service.dart
static const String _geocoderBaseUrl = 'http://localhost:3002/api/geocoder';
static const String _landBaseUrl = 'http://localhost:3002/api/land';
```

---

### **3. Flutter에서 여전히 CORS 에러**

**확인 사항:**
1. ✅ 프록시 서버가 실행 중인가? (`npm start`)
2. ✅ VWorldService가 `localhost:3001`을 사용하는가?
3. ✅ 브라우저 콘솔에서 요청 URL 확인

**네트워크 탭 확인:**
```
http://localhost:3001/api/geocoder?service=...  ← 이렇게 나와야 함!
```

만약 여전히 `https://api.vworld.kr/...`로 요청이 간다면, Flutter 앱을 재시작하세요.

---

## 📝 로그 확인

프록시 서버 터미널에서 모든 요청/응답이 로그로 출력됩니다:

```
🌐 GET /api/geocoder?service=address&...
🌍 [Geocoder API] 프록시 요청: /req/address?service=address&...
📥 응답 상태: 200
```

---

## 🎯 정리

### **개발 환경 실행 순서**

```bash
# 터미널 1: 프록시 서버
npm start

# 터미널 2: Flutter 앱
flutter run -d chrome
```

### **배포 시 주의사항**

⚠️ **로컬 프록시 서버는 개발 환경에서만 사용됩니다.**

배포 시에는:
1. **백엔드 서버**에 프록시 API를 추가하거나
2. **모바일 앱**으로 빌드하세요 (모바일은 CORS 제한 없음)

---

## 💡 참고

- **D:\houseMvpProject**도 동일한 방식으로 프록시 서버를 사용합니다
- 프록시 서버는 단순히 요청을 "중계"만 하므로 보안상 안전합니다
- API 키는 그대로 사용되며, 프록시는 CORS 헤더만 추가합니다



