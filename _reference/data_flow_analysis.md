# MyHome 데이터 흐름 분석서

> 각 데이터의 생성 → 저장 → 상태 변경 → 소비 → 최종 상태를 추적하여
> "데이터가 사라지거나 막히는 지점"을 식별한 문서.

---

## 1. mlsProperties (매물)

### 흐름도
```
매도인 등록 (createProperty)
  ↓ Firestore: mlsProperties/{id}
  ↓ status: draft
  ↓
검증 요청 (submitForVerification)
  ↓ status: pending
  ↓
관리자 승인 (approveProperty)          관리자 거절 (rejectProperty)
  ↓ status: active                       ↓ status: rejected
  ↓ → 매도인 알림 ✅                      ↓ → 매도인 알림 ✅
  ↓                                      ↓ [끝]
중개사에게 배포됨
  ↓
방문 요청 승인 → status: inquiry
  ↓
협의 시작 → status: underOffer
  ↓
가계약 → status: depositTaken → 모든 중개사 알림 ✅
  ↓
거래완료 → status: sold → 모든 중개사 알림 ✅

또는: status: cancelled (매도인 취소)
삭제: soft delete (isDeleted=true) → 중개사 알림 ✅
```

### 조회
| 역할 | 조회 방법 | UI |
|------|---------|-----|
| 매도인 | `getPropertiesByUser(userId)` | mls_seller_dashboard_page.dart |
| 중개사 | `getBroadcastedProperties()` | mls_broker_dashboard_page.dart |
| 공개 | `getAllActiveProperties()` | public_listings_page.dart |
| 관리자 | 전체 목록 | admin_property_management.dart |

### 데이터 소실 여부: ✅ 없음

---

## 2. visitRequests (방문 요청)

### 흐름도
```
중개사가 방문 요청 (createVisitRequest)
  ↓ Firestore: mlsProperties/{id}/visitRequests/{id}
  ↓ status: pending
  ↓ → 매도인 알림 ✅
  ↓
  ├── 매도인 승인 (approveVisitRequest)
  │     ↓ status: approved
  │     ↓ 연락처 교환 (sellerPhone 저장, contactExchangedAt 기록)
  │     ↓ → 중개사 알림 ✅ (연락처 포함)
  │     ↓ → 매도인 확인 알림 ✅
  │     ↓ → 같은 시간대 다른 요청 → reschedule + 알림 ✅
  │     ↓
  │     방문 완료 (markVisitCompleted)
  │       ↓ visitCompletedAt 기록
  │
  ├── 매도인 거절 (rejectVisitRequest)
  │     ↓ status: rejected
  │     ↓ → 중개사 알림 ✅
  │
  └── 중개사 취소 (cancelVisitRequest)
        ↓ status: cancelled
        ↓ → 매도인 알림 ✅
```

### 조회
| 역할 | 조회 방법 | UI |
|------|---------|-----|
| 매도인 | `getPendingVisitRequests(propertyId)` | mls_property_detail_page.dart |
| 중개사 | `getVisitRequestsByBroker(brokerId)` | mls_broker_dashboard_page.dart |

### ⚠️ 잠재적 문제
- `expired` 상태 자동 전환 없음 — 지난 시간의 pending 요청이 정리 안 됨
- 노쇼 처리 메서드 미구현 (모델에만 정의)

---

## 3. buyerInquiries (구매자 문의)

### 흐름도
```
구매자가 문의 (createBuyerInquiry)
  ↓ Firestore: buyerInquiries/{id}
  ↓ status: pending
  ↓ → 매도인 알림 ✅
  ↓ → 배정된 중개사 알림 ✅ (있을 경우)
  ↓
  ├── 중개사 배정 (assignBrokerToInquiry) ✅
  │     ↓ status: brokerAssigned
  │     ↓ → 구매자 알림 ✅ ("중개사 배정 완료")
  │     ↓
  │     ├── 중개사가 연락 완료 (updateBuyerInquiryStatus) ✅
  │     │     ↓ status: contacted + contactedAt 기록
  │     │     ↓ → 구매자 알림 ✅
  │     │     ↓
  │     │     ├── 방문 진행 (updateBuyerInquiryStatus) ✅
  │     │     │     ↓ status: visiting
  │     │     │     ↓ → 구매자 알림 ✅
  │     │     │     ↓
  │     │     │     └── 완료 (updateBuyerInquiryStatus) ✅
  │     │     │           ↓ status: completed
  │     │     │           ↓ → 구매자 알림 ✅
  │     │     │
  │     │     └── (정상 종료)
  │     │
  │     └── (정상 종료)
  │
  └── 구매자 취소 (cancelBuyerInquiry)
        ↓ status: cancelled
        ↓ → 매도인 알림 ✅
        ↓ → 배정 중개사 알림 ✅
```

### 조회
| 역할 | 조회 방법 | UI |
|------|---------|-----|
| 구매자 | `getMyBuyerInquiries()` | ⚠️ 스트림 있음, 전용 UI 미구현 (향후 추가 권장) |
| 중개사 | `getMyBuyerLeads(brokerId)` | broker 대시보드 "구매자 리드" 탭 ✅ |
| 매물별 | `getBuyerInquiriesForProperty()` | ⚠️ 스트림 있음, 전용 UI 미구현 |

### 상태 전환 UI (중개사 대시보드)
| 현재 상태 | 버튼 | 다음 상태 |
|---------|------|---------|
| brokerAssigned | "연락 완료" | contacted |
| contacted | "방문 진행" | visiting |
| visiting | "완료" | completed |

### 데이터 소실 여부: ✅ 해결됨
- ~~중개사 배정 메서드 없음~~ → `assignBrokerToInquiry()` 구현 완료
- ~~상태 전환 메서드 없음~~ → `updateBuyerInquiryStatus()` 구현 완료
- ~~중개사 상태 변경 불가~~ → 대시보드에 상태 변경 버튼 추가 완료

### ⚠️ 남은 과제
- 구매자가 자기 문의를 조회할 전용 UI (현재 공개 매물 상세에서 취소/수정만 가능)

---

## 4. brokerOffers (중개 제안)

### 흐름도
```
중개사가 제안 (_showOfferDialog)
  ↓ Firestore: brokerOffers/{id} (UI에서 직접 저장)
  ↓ status: pending
  ↓ → 매도인 알림 ✅
  ↓
  ├── 매도인이 선정 (_selectBrokerOffer in mls_property_detail_page) ✅
  │     ↓ 선정된 제안: status: selected + selectedAt
  │     ↓ 나머지 제안: status: rejected (batch update)
  │     ↓ → 선정 중개사 알림 ✅
  │     ↓ → 미선정 중개사 알림 ✅
  │
  ├── 관리자가 선정 (_selectBrokerOffer in admin_property_management) ✅
  │     ↓ (동일 로직)
  │
  └── 매물 종료 시 자동 정리 (_closePendingBrokerOffers) ✅
        ↓ sold/cancelled 상태 변경 시 자동 호출
        ↓ 모든 pending offer → rejected (batch update)
```

### 조회
| 역할 | 조회 방법 | UI |
|------|---------|-----|
| 매도인 | StreamBuilder 직접 쿼리 | mls_property_detail_page.dart ✅ + "이 중개사 선정" 버튼 ✅ |
| 관리자 | `_showOffersDialog()` | admin_property_management.dart ✅ |
| 중개사 | 자기 제안 조회 | broker 대시보드 ✅ |

### 데이터 소실 여부: ✅ 해결됨
- ~~매도인이 선정 불가~~ → 매물 상세에 선정 버튼 추가 완료
- ~~매물 종료 시 pending offer 정리 안 됨~~ → `_closePendingBrokerOffers()` 자동 호출

### ⚠️ 남은 과제
- 중개사가 제안을 수정/취소할 방법 없음
- 서비스 레이어 없음 (UI에서 직접 Firestore 접근)

---

## 5. notifications (알림)

### 흐름도
```
앱 내 이벤트 발생
  ↓
FirebaseService.sendNotification() 호출
  ↓ Firestore: notifications/{id}
  ↓ 필드: userId, title, message, type, relatedId, isRead, createdAt
  ↓
  ├── Cloud Function 자동 트리거 (sendPushNotification)
  │     ↓ users 컬렉션에서 FCM 토큰 조회
  │     ↓ 없으면 brokers 컬렉션도 확인 ✅ (수정됨)
  │     ↓ FCM 푸시 전송
  │     ↓ 만료 토큰 자동 삭제
  │
  └── notification_page.dart에서 조회
        ↓ StreamBuilder 실시간
        ↓ 읽음 처리: markNotificationAsRead()
        ↓ 전체 읽음: markAllNotificationsAsRead()
```

### 등록된 알림 타입 (notification_page.dart)
| 타입 | 아이콘 | 상태 |
|------|-------|------|
| property_approved | ✅ 등록됨 | 매물 승인 |
| property_rejected | ✅ 등록됨 | 매물 거절 |
| property_deleted | ✅ 등록됨 | 매물 삭제 |
| buyer_inquiry | ✅ 등록됨 | 구매자 문의 |
| buyer_inquiry_cancelled | ✅ 등록됨 | 문의 취소 |
| broker_offer | ✅ 등록됨 | 중개 제안 |
| broker_verified | ✅ 등록됨 | 중개사 인증 |
| visit_request | ✅ 등록됨 | 방문 요청 |
| visit_approved | ✅ 등록됨 | 방문 승인 |
| visit_confirmed | ✅ 등록됨 | 방문 확정 |
| visit_rejected | ✅ 등록됨 | 방문 거절 |
| visit_cancelled | ✅ 등록됨 | 방문 취소 |

### ⚠️ 잠재적 문제
- 알림 삭제 기능 없음 (Firestore에 영구 축적)
- 알림 클릭 시 네비게이션이 일부 타입에서만 동작

---

## 6. brokers (중개사)

### 흐름도
```
중개사 회원가입 (registerBroker)
  ↓ Firebase Auth + Firestore: brokers/{uid}
  ↓ verified: false
  ↓
  ├── 관리자 인증 승인 (_approveBroker)
  │     ↓ verified: true
  │     ↓ → 중개사 알림 ✅
  │     ↓ 매물 탐색/방문 요청/중개 제안 기능 활성화
  │
  ├── 관리자 인증 해제 (_revokeBroker)
  │     ↓ verified: false
  │     ↓ → 중개사 알림 ✅
  │
  └── 탈퇴 (deleteBroker)
        ↓ Hard delete (문서 삭제)
        ↓ ❌ 관련 데이터 정리 안 됨
```

### ⚠️ 잠재적 문제
- 인증 상태가 `verified: boolean`만 — "심사중" 상태 없음
- 탈퇴 시 brokerOffers, visitRequests, buyerInquiries 고아 데이터 발생
- 인증 거절 사유 저장 안 됨

---

## 7. users (일반 사용자)

### 흐름도
```
회원가입 (이메일 / 카카오 / Google)
  ↓ Firebase Auth + Firestore: users/{uid}
  ↓
  ├── 이메일: profileCompleted = true (가입 시 이름/전화 입력)
  │
  └── 소셜: profileCompleted = false
        ↓ ProfileCompletionPage 진입
        ↓ 이름/전화번호 입력
        ↓ profileCompleted = true
        ↓ MainPage 진입
```

### ⚠️ 잠재적 문제
- 탈퇴 메서드 미구현 (`deleteUserAccount`에서 users 문서만 삭제)
- 관련 데이터 (매물, 문의, 북마크) 정리 안 됨

---

## 데이터 소실 요약

| 데이터 | 소실 유형 | 심각도 | 상태 |
|--------|---------|--------|------|
| buyerInquiries | pending에서 영구 정체 | ~~Critical~~ | ✅ 해결 |
| buyerInquiries | 구매자가 자기 문의를 볼 UI 없음 | **Medium** | ⚠️ 부분 해결 (취소/수정만 가능, 전용 목록 UI 미구현) |
| brokerOffers | 매도인이 직접 선정 불가 | ~~Medium~~ | ✅ 해결 |
| brokerOffers | 매물 종료 시 pending offer 정리 안 됨 | ~~Low~~ | ✅ 해결 |
| visitRequests | expired 자동 전환 없음 | **Low** | 미해결 |
| notifications | 삭제 기능 없음 (영구 축적) | **Low** | 미해결 |
| brokers 탈퇴 | 고아 데이터 발생 | **Medium** | 미해결 |
| users 탈퇴 | 고아 데이터 발생 | **Medium** | 미해결 |

---

## 이번 세션에서 해결한 항목 (총 20건)

### 알림 누락 수정 (10건)
| 문제 | 해결 |
|------|------|
| 매물 승인 시 매도인 알림 없음 | ✅ approveProperty에 알림 추가 |
| 매물 삭제 시 중개사 알림 없음 | ✅ deleteProperty에 알림 추가 |
| 구매자 문의 시 매도인 알림 없음 | ✅ _notifyBrokersOnNewInquiry 수정 |
| 중개 제안 시 매도인 알림 없음 | ✅ _showOfferDialog에 알림 추가 |
| 문의 취소 시 알림 없음 | ✅ cancelBuyerInquiry에 알림 추가 |
| FCM 중개사 푸시 누락 | ✅ brokers 컬렉션도 확인 (functions/index.js) |
| 방문 승인 시 매도인 알림 없음 | ✅ approveVisitRequest에 알림 추가 |
| 알림 페이지 타입 누락 | ✅ 15개 타입 아이콘/색상 추가 |
| 구매자 문의 상태 변경 시 알림 없음 | ✅ updateBuyerInquiryStatus에 알림 추가 |
| 중개사 배정 시 구매자 알림 없음 | ✅ assignBrokerToInquiry에 알림 추가 |

### 데이터 흐름 막힘 해결 (6건)
| 문제 | 해결 |
|------|------|
| buyerInquiries 배정 메서드 없음 | ✅ assignBrokerToInquiry() 구현 |
| buyerInquiries 상태 전환 메서드 없음 | ✅ updateBuyerInquiryStatus() 구현 |
| 중개사가 리드 상태 변경 불가 | ✅ 대시보드에 "연락 완료/방문 진행/완료" 버튼 추가 |
| 매도인이 중개 제안 선정 불가 | ✅ 매물 상세에 "이 중개사 선정" 버튼 + 확인 다이얼로그 |
| 매물 종료 시 pending offer 정리 안 됨 | ✅ _closePendingBrokerOffers() 자동 호출 |
| 매도인이 중개 제안을 볼 수 없음 | ✅ 매물 상세에 제안 목록 섹션 UI 추가 |

### UX 버그 수정 (4건)
| 문제 | 해결 |
|------|------|
| 문의 보내기 시 TextEditingController disposed 에러 | ✅ 수동 dispose 제거 |
| 문의 접수 완료 텍스트 오버플로우 | ✅ Flexible + ellipsis 적용 |
| 소셜 로그인 비밀번호 변경 에러 | ✅ 진입 차단 + 안내 UI |
| 문의 취소/수정 불가 | ✅ 메모 수정 + 문의 취소 UI 추가 |
