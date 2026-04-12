# 구조 결함 목록

> UX 문서와 달리 사용자 흐름이 아니라 코드·데이터·아키텍처 수준의 기술적 결함을 다룬다.
>
> 2026-04-11 코드베이스 기준

<br>

---

## 설계 결함

### [STR-001] 구매자 역할이 시스템에 없다

인증 시스템은 `broker` vs `user` 두 가지만 구분한다.
`BuyerInquiry` 모델(`buyer_inquiry.dart`)과 `MyInquiriesPage`(`screens/buyer/my_inquiries_page.dart`)가
구현되어 있지만, "구매자"라는 명시적 역할은 존재하지 않는다.

**현재 분기 로직:**
`main_page.dart:249-270`의 `_updateInitialTabByPropertyExistence()`가
등록 매물 유무에 따라 기본 탭을 결정한다. 매물이 없으면 탐색 탭(탭 3)이 기본이다.
그러나 이것은 역할 분기가 아니라 데이터 유무에 따른 분기다.

**구체적 문제:**
- 매물을 팔고 싶은 사용자와 사고 싶은 사용자가 같은 `MainPage`를 쓴다.
  탭 0(매물 등록)은 구매자에게 완전히 무의미하다.
- 구매자 전용 FCM 알림 타입이 부족하다 (STR-002 참조).
- 구매자 전용 대시보드가 없어서 문의 추적을 위해 `MainPage` 안에서
  `MyInquiriesPage`로 별도 네비게이션해야 한다.

**영향 범위:** 구매자 UX 전반, 알림 시스템, 탭 구조.

→ 최소한 "매물 없는 사용자"의 탭 구조를 구매자 맞춤으로 재편.
  이상적으로는 가입 시 "매물을 등록하려는 건가요, 매물을 찾으려는 건가요?"
  질문으로 역할 분기.

<br>

---

## 알림 시스템

### [STR-002] 운영에 필요하지만 존재하지 않는 FCM 알림 타입

`notification_model.dart:4-52`에 31개의 알림 타입이 정의되어 있다.
그러나 다음 4개는 현재 운영에서도 바로 필요하지만 존재하지 않는다:

| 누락된 타입 | 수신자 | 필요한 이유 |
|------------|--------|-----------|
| `buyer_inquiry_received` | 중개사 | 구매자 리드가 들어왔을 때 중개사에게 알려야 한다. 현재는 대시보드를 직접 열어봐야 알 수 있다 |
| `broker_inquiry_assigned` | 구매자 | 중개사가 배정되었을 때 구매자에게 알려야 한다. 현재는 `MyInquiriesPage`를 직접 새로고침해야 알 수 있다 |
| `new_property_in_region` | 지역 중개사 | 영업 지역에 새 매물이 올라왔을 때 알림이 가야 한다. 현재는 탐색 탭을 직접 확인해야 한다 |
| `visit_request_received` | 매도자 | 중개사가 방문 요청을 보냈을 때 매도자에게 알려야 한다. 현재는 대시보드를 직접 확인해야 한다 |

Airship(구 Urban Airship)의 2023년 벤치마크에 따르면
푸시 알림을 활성화한 사용자는 비활성 사용자 대비 리텐션이 88% 높다.
적시에 알림을 보내지 않으면 "앱을 열어야 확인할 수 있는" 수동적 경험이 되고,
이는 재방문 동기를 크게 떨어뜨린다.

<br>

### [STR-003] 알림을 탭해도 아무 일이 안 일어나는 경우가 있다

`notification_page.dart:281-320`의 `_navigateByNotificationType()`에서
`relatedId`가 null이거나 빈 문자열이면 `return`으로 빠져나온다 (line 283).
사용자는 알림을 탭했지만 화면 이동 없이 아무 일도 안 일어난다.

또한 매물이 삭제되거나 비공개된 경우에도 대비 로직이 없다.
`_mlsService.getProperty(relatedId)`가 null을 반환하면
네비게이션 시 예외가 발생할 수 있다.

→ `relatedId` 없을 때: "상세 정보를 찾을 수 없습니다" 토스트.
→ 매물 삭제 시: "삭제된 매물입니다" 메시지.

<br>

### [STR-004] 알림 벌크 전송에 에러 핸들링이 없다

`notification_firebase_service.dart:102-128`의 `sendBulkNotifications()`에
try-catch가 없다. Firestore 배치 커밋이 실패하면 예외가 호출자에게 전파되고,
어떤 알림이 성공했고 어떤 것이 실패했는지 구분할 수 없다.

**구체적 위험:** 지역 중개사 10명에게 새 매물 알림을 보낼 때 배치가 실패하면,
일부만 알림을 받고 나머지는 못 받는 상황이 감지도 복구도 안 된다.

→ try-catch + 실패 건수 로깅 + 재시도 로직.

<br>

### [STR-005] 알림 페이지에서 다이얼로그와 네비게이션이 경합한다

`notification_page.dart:164-169`에서 `showDialog()` 후 즉시
`Navigator.of(context).pop()` + 새 라우트 푸시가 이어진다.
느린 네트워크에서 다이얼로그가 닫히기 전에 라우트가 푸시되면
다이얼로그가 중복되거나 네비게이션 스택이 오염될 수 있다.

→ 다이얼로그 완료를 `await`한 뒤 네비게이션.

<br>

---

## 데이터 모델

### [STR-006] 구매자 문의 자동 배정의 실패 케이스가 처리되지 않는다

`mls_property_service.dart:2334-2354`의 `createBuyerInquiry()` 내부에서
자동 배정 로직이 다음과 같이 동작한다:

```dart
if (approvedBrokers.length == 1) {
  // 승인된 중개사가 정확히 1명이면 자동 배정
  await assignBrokerToInquiry(...);
  return inquiry.copyWith(status: BuyerInquiryStatus.brokerAssigned, ...);
}
// 그 외: pending 상태로 반환, 배정 없음
return inquiry;
```

**세 가지 문제:**
1. 승인된 중개사가 **0명**이면 문의가 `pending` 상태로 방치된다.
   관리자에게 알림도 가지 않으므로 이 문의는 아무도 모른다.
2. 승인된 중개사가 **2명 이상**이면 배정하지 않는다.
   어떤 기준으로 1명을 선택해야 하는지 정의되어 있지 않다.
3. `assignBrokerToInquiry()` 호출이 실패해도 에러 처리가 없다.

→ 0명: 관리자에게 수동 배정 요청 알림.
→ 2명 이상: 응답 속도, 성사율 등 기준으로 자동 선택하거나 관리자에게 위임.
→ 배정 실패: try-catch + 재시도.

<br>

### [STR-007] 전화번호 저장 포맷이 일관되지 않는다

코드베이스 전반에서 전화번호가 다양한 포맷으로 저장·비교된다:

| 위치 | 저장/비교 방식 | 문제 |
|------|-------------|------|
| `mls_quick_registration_page.dart:277` | `.text.trim()` 그대로 저장 | 포맷 무관 |
| `mls_quick_registration_page.dart:1328` | `RegExp(r'[0-9\-]')` 필터만 | `123-4567` 허용 |
| `public_property_detail_page.dart:1268` | `.trim()` 그대로 Firestore 쿼리 | 정규화 없이 비교 |
| `public_property_detail_page.dart:1280` | 숫자만 추출 후 비교 | 위와 불일치 |
| `visit_request_quick_sheet.dart:420` | 빈 값만 확인 | 포맷 무관 |

같은 전화번호가 `"010-1234-5678"`, `"01012345678"`, `"010 1234 5678"` 세 가지로
저장될 수 있다. 중복 제안 확인(`public_property_detail_page.dart:1264-1283`)에서
첫 번째 쿼리는 원본 포맷을 쓰고 두 번째 쿼리는 정규화 포맷을 써서,
포맷이 다르면 중복을 잡지 못한다.

→ 전화번호 저장 전 공통 정규화 함수: `phone.replaceAll(RegExp(r'[^0-9]'), '')`.
  모든 저장·비교 지점에서 이 함수를 적용.

<br>

---

## 보안

### [STR-008] 주소 프라이버시 마스킹이 한국어 패턴에만 대응한다

`address_utils.dart:27`의 주소 파싱 정규식:
```dart
final reg = RegExp(r'^(.*?)(\d+)(?=\s|\(|$)');
```

이 정규식은 도로명 + 건물번호를 추출한다. 그러나:
- **동/호 분리가 이 레벨에서 이루어지지 않는다.** 동/호가 포함된 상세 주소가
  별도 필드(`detailAddress`)가 아닌 `roadAddress`에 합쳐져 있으면 노출된다.
- 영문 표기("Building A, Unit 5")나 복합 번지("52-1, 52-2")에 대응하지 않는다.

공개 매물 목록(`public_listings_page.dart`)에서 `_sanitizeAddress()`가
추가 마스킹을 하지만, 위 정규식에 의존하므로 동일한 제약을 갖는다.

→ 동/호 이하 일괄 제거 로직 강화. `detailAddress` 필드 분리 확인.

<br>

---

## 코드 품질

### [STR-009] 방문 일정 조율이 앱 안에서 끊긴다

방문 요청의 승인/거절은 구현되어 있지만(`visit_request_quick_sheet.dart`,
`mls_property_detail_page.dart`), 구체적 방문 일정을 앱 안에서 조율하는 흐름은
"전화하세요"로 끝난다. 이후 거래 데이터가 플랫폼에 남지 않는다.

<br>

### [STR-010] 외부 매물 임포트 UI가 없다

`MLSProperty` 모델에 `externalSource`(당근, 피터팬, 맘카페), `externalSellerName`,
`externalSellerPhone`, `externalListingUrl` 필드가 정의되어 있다.
그러나 관리자가 이 필드를 채워 외부 매물을 등록하는 UI가 없다.
초기 매물 시딩 전략(buyer-strategy-analysis.md 참조)에서 외부 임포트는
핵심 수단인데, 현재는 코드에만 필드가 있고 사용할 수 없다.

<br>

### [STR-011] 에러 핸들링 패턴이 제각각이다

서비스 레이어(`firebase_service.dart`, `mls_property_service.dart`)는
`Logger.error()`로 에러를 기록한다. 그러나 UI 레이어는:

- `SnackBar`를 쓰는 곳
- `AlertDialog`를 쓰는 곳
- `Logger.warning()`만 하고 사용자에게 아무것도 보여주지 않는 곳
  (`mls_quick_registration_page.dart:286-288`, `mls_property_service.dart:2397-2399`)

이 비일관성 때문에 사용자는 "에러가 났는데 아무 일도 안 일어남"을 경험하거나,
같은 에러인데 어떤 화면에서는 SnackBar가, 다른 화면에서는 다이얼로그가 뜨는
일관성 없는 경험을 한다.

→ `AppErrorHandler.show(context, error)` 같은 중앙화된 에러 표시 유틸.

<br>

### [STR-012] 반응형 레이아웃이 불균일하다

`PublicListingsPage`는 `GridView.builder()`로 반응형 그리드를 구현하고,
`ResponsiveHelper.getGridColumns()`로 디바이스별 열 수를 조정한다.
그러나 매도자 대시보드와 중개사 대시보드는 모바일 단일 열 레이아웃 그대로다.
관리자 대시보드는 500~900px 구간에서 레이아웃이 깨진다 (A-008 참조).

→ 주요 대시보드 화면에 `ResponsiveHelper` 기반 그리드 적용.

<br>

---

## 우선순위 요약

| 긴급도 | ID | 할 일 | 난이도 | 근거 |
|:------:|:---:|-------|:------:|------|
| 높음 | 002 | 누락 FCM 타입 4건 | 중 | 알림 없으면 앱을 열어봐야 알 수 있음. 리텐션 직결 |
| 높음 | 006 | 문의 자동 배정 실패 처리 | 중 | 중개사 0명일 때 문의 방치. 운영 사각지대 |
| 높음 | 007 | 전화번호 정규화 | 하 | 중복 제안 버그 + 연락 불가. 정규식 한 줄 |
| 높음 | 003 | 알림 네비게이션 사일런트 실패 | 하 | 사용자 행동 차단. 조건문 추가 수준 |
| 중간 | 001 | 구매자 역할 분기 | 중 | 탭 구조 개편. 구매자 경험의 전제 조건 |
| 중간 | 004 | 벌크 알림 에러 핸들링 | 하 | try-catch 추가. 부분 실패 감지 |
| 중간 | 008 | 주소 프라이버시 강화 | 하 | 정규식 확장. 세대 정보 노출 방지 |
| 중간 | 010 | 외부 매물 임포트 UI | 중 | 초기 매물 시딩 전략의 전제 |
| 낮음 | 009 | 방문 일정 인앱 조율 | 중 | 거래 흐름 플랫폼 유지 |
| 낮음 | 011 | 에러 핸들링 통일 | 중 | 코드 일관성. 점진적 개선 가능 |
| 낮음 | 012 | 반응형 레이아웃 통일 | 중 | 웹 사용성. `ResponsiveHelper` 확산 |
| 낮음 | 005 | 다이얼로그 레이스 컨디션 | 하 | `await` 추가. 엣지 케이스 |
