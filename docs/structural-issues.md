---
agent_status: reviewed
created: 2026-03-08
description: 프로젝트 구조 결함 분석 — 코드/데이터/아키텍처 수준의 문제점과 개선 방향
---

# 프로젝트 구조 결함 분석

> UX 분석(ux-analysis-*.md)과 달리 이 문서는 코드/데이터/아키텍처 수준의 문제를 다룹니다.

---

## 1. 사용자 역할(Role) 시스템 결함

### 🔴 [STR-001] 구매자(Buyer) 역할이 시스템에 없음

**현재 상태:**
- 사용자 역할: `seller(일반사용자)` / `broker(중개사)` / `admin(관리자)`
- 구매자는 별도 역할 없이 "로그인한 일반 사용자" = 매도자와 동일 처리

**문제:**
- 구매자가 로그인하면 매도자 화면(매물 등록)이 기본 탭으로 뜸
- BuyerInquiry 모델은 있는데 구매자용 대시보드 화면 없음
- 구매자 전용 FCM 타입 없음 (배정된 중개사 알림 등)

**개선 방향:**
```dart
// 현재
enum UserRole { seller, broker, admin }

// 개선
enum UserRole { seller, buyer, broker, admin }
// 또는 사용자가 여러 역할을 가질 수 있도록:
List<UserRole> roles; // 한 사람이 매도자이면서 구매자일 수도 있음
```

---

## 2. 알림(FCM) 시스템 불완전

### 🟡 [STR-002] 알림 클릭 후 해당 화면으로 이동 미구현

**현재 상태:**
- NotificationPage에 알림 타입별 아이콘/색상 있음
- 알림 클릭 → "읽음" 처리만 됨
- 알림 타입(broker_selected, visit_schedule_approved 등)에 맞는 네비게이션 미구현

**문제:**
- "중개사가 선정되었습니다" 알림 클릭 → 어느 매물인지 보여줘야 하는데 안 됨
- FCM 알림이 있는데 실제 행동을 유도하지 못함 → 알림의 절반 가치만 사용

**개선 방향:**
```dart
// NotificationPage의 알림 클릭 핸들러에 라우팅 추가
void _onNotificationTap(NotificationModel notif) {
  markAsRead(notif.id);
  switch (notif.type) {
    case 'broker_selected':
      Navigator.push(context, PropertyDetailPage(notif.propertyId));
    case 'visit_schedule_approved':
      Navigator.push(context, VisitSchedulePage(notif.propertyId));
    // ...
  }
}
```

### 🟡 [STR-003] 미구현 FCM 타입 (필요하지만 없는 것)

**현재 구현된 타입:**
- quote_answered, broker_selected, property_registered
- property_deposit_taken, property_sold, property_expired
- visit_schedule_approved, visit_schedule_rejected

**없는 타입:**
- `buyer_inquiry_received` — 중개사에게 구매자 리드 알림
- `broker_inquiry_assigned` — 구매자에게 중개사 배정 알림
- `broker_verified` — 중개사에게 인증 완료 알림
- `new_property_in_region` — 지역 중개사에게 새 매물 알림
- `visit_request_received` — 매도자에게 방문 요청 알림

---

## 3. 거래 흐름 UI 미완성

### 🔴 [STR-004] NegotiationLog UI 없음

**현재 상태:**
- `NegotiationLog` 모델: negotiationId, propertyId, brokerId, buyerFeedback, priceOffer 등 정의됨
- Firestore에 저장 로직 있음
- 하지만 매도자/중개사가 협상 현황을 보는 화면 없음

**문제:**
- 가격 협상이 어디서 어떻게 이루어지는지 플랫폼 내에서 보이지 않음
- 중개사가 "구매자가 9억을 제안했다"는 정보를 매도자에게 어떻게 전달하는가?
- 현재는 전화로 처리 추정 → 플랫폼 외부로 핵심 정보 유출

### 🟡 [STR-005] 방문 요청(VisitRequest) UI 불완전

**현재 상태:**
- `VisitRequest` 모델 있음 (visitId, propertyId, brokerId, requestedDate 등)
- AdminMatchingPage에서 수동 매칭은 있음
- 매도자가 방문 요청을 승인/거절하는 화면의 완성도 불명확

**문제:**
- 중개사 승인 후 방문 일정 잡는 흐름이 끊김
- "승인됐으니 전화하세요" 수준으로 마무리

---

## 4. 데이터 모델 설계 이슈

### 🟡 [STR-006] PropertyStatus 불일치 가능성

**현재 상태:**
```dart
// 모델에 정의된 상태
enum PropertyStatus { active, paused, sold, expired }

// 그러나 코드에서 문자열로도 사용됨
// 'draft', 'pending', 'inquiry', 'underOffer', 'depositTaken' 등 레거시 상태값이 혼재 추정
```

**문제:**
- Firestore에 저장된 이전 데이터의 상태값과 현재 enum 불일치 위험
- `status` 필드를 enum으로 파싱할 때 예외 발생 가능

**개선 방향:**
- 모든 상태값을 한 곳에서 관리 (`lib/constants/status_constants.dart`)
- 레거시 상태값 마이그레이션 Cloud Function 작성

### 🟡 [STR-007] BuyerInquiry 연결 약함

**현재 상태:**
- `BuyerInquiry`: propertyId, buyerUserId, assignedBrokerId
- 하지만 BrokerResponse(중개사 참여 기록)와 BuyerInquiry(구매자 문의)가 독립적

**문제:**
- 구매자가 문의한 매물에 이미 승인된 중개사가 있어도 자동 연결 로직이 Cloud Function에 있는지 불명확
- BuyerInquiry.assignedBrokerId 업데이트 트리거가 명확하지 않음

---

## 5. 코드 구조 이슈

### 🟡 [STR-008] 외부 매물 연동 UI 미구현

**현재 상태:**
- MLSProperty 모델에 `externalSource` 필드 있음 (당근마켓, 피터팬, 맘카페)
- `importFromExternal()` 서비스 로직 추정됨
- 하지만 관리자 대시보드에 외부 매물 임포트 UI 없음

**문제:**
- 초기 매물 시딩 전략(buyer-strategy-analysis.md 8.4절)에서 외부 임포트가 핵심인데 UI 없음

### 🟢 [STR-009] 반응형 레이아웃 일관성

**현재 상태:**
- `ResponsiveConstants` 클래스 있음
- 일부 화면은 모바일/데스크톱 분기, 일부는 단일 레이아웃

**문제:**
- 웹 빌드 시 일부 화면이 모바일 레이아웃 그대로 표시 가능
- PublicListingsPage는 그리드 적용, 다른 화면은 미적용

### 🟢 [STR-010] 에러 핸들링 일관성 부재

**현재 상태:**
- `error_handler.dart` 있음
- 하지만 각 화면마다 try-catch 처리 방식이 다름
- 일부는 SnackBar, 일부는 다이얼로그, 일부는 print만

---

## 6. 보안 이슈

### 🔴 [STR-011] Firebase Admin SDK 키 파일이 git 트래킹됨

**현재 상태:**
- `functions/houseproject-18f44-firebase-adminsdk-fbsvc-3cd1e6b129.json` 파일이
  git status에서 미추적(untracked)으로 표시됨 — 즉 `.gitignore`에 없을 수 있음

**문제:**
- 이 파일이 실수로 커밋되면 Firebase Admin 권한 탈취 가능
- 즉시 확인 필요

**개선:**
```
# .gitignore에 반드시 포함
functions/*-firebase-adminsdk-*.json
functions/*.json  # 또는 더 구체적으로
```

---

## 7. 우선순위 종합

| 우선순위 | ID | 카테고리 | 작업 | 난이도 |
|---------|-----|---------|------|-------|
| 🔴 즉시 | STR-011 | 보안 | Admin SDK 키 .gitignore 추가 | 최하 |
| 🔴 높음 | STR-001 | 역할 | 구매자 역할 분기 (랜딩 탭 조건) | 하 |
| 🔴 높음 | STR-004 | 거래 | 협상 현황 UI 기초 구현 | 상 |
| 🟡 중간 | STR-002 | 알림 | 알림 클릭 → 해당 화면 이동 | 중 |
| 🟡 중간 | STR-003 | 알림 | 누락된 FCM 타입 추가 | 중 |
| 🟡 중간 | STR-007 | 데이터 | BuyerInquiry 자동 브로커 배정 로직 | 중 |
| 🟡 중간 | STR-008 | 기능 | 외부 매물 임포트 UI | 중 |
| 🟢 낮음 | STR-006 | 데이터 | PropertyStatus 일관성 정리 | 하 |
| 🟢 낮음 | STR-009 | UI | 반응형 레이아웃 일관화 | 중 |
| 🟢 낮음 | STR-010 | 코드 | 에러 핸들링 일관화 | 중 |
