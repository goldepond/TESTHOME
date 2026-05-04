// =============================================================================
// 04_m2_disclosure.test.js — Task 05 M2 시간기록 공개
// =============================================================================
//
// TODO (P3 후속): 풀 구현
//
// 시나리오:
//   1. broker A 참여 등록 → broker_participations 'declared' 단계 생성
//   2. assignParticipationDisplayName 트리거 → displayName='중개사 A' 자동 할당
//   3. broker B 참여 등록 → displayName='중개사 B' 할당 (등록 순서)
//   4. broker A 임장 약속 (visitRequest) → broker_participations 'visit_scheduled' 단계 전이
//   5. broker A 의향서 (offer) → 'offer_made' 전이
//   6. getBrokerParticipationsForSeller callable → 모든 broker displayName + 시간 반환
//   7. getMyParticipations callable (broker A) → 본인 시간기록만 + 다른 broker 실명 차단

const { expect } = require('chai');
describe('Task 05 — M2 시간기록 공개 (placeholder)', () => {
  it.skip('TODO: 풀 구현 — Task 05 흐름 7단계', () => {});
});
