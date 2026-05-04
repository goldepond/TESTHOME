// =============================================================================
// 07_exclusive_listing.test.js — Task 07 매도자 자율 단독 지정
// =============================================================================
//
// TODO (P3 후속): 풀 구현
//
// 시나리오:
//   1. 매도자가 매물 등록 시 listingMode='exclusive' + exclusiveBrokerIds=[A, B] 선택
//   2. broker C (비지정)가 issuePriorityGrant → 'not_in_exclusive_list' 거부
//   3. broker A (지정)가 issuePriorityGrant → 정상 발급
//   4. 매도자가 changeListingMode 호출 (exclusive → open)
//   5. 24h 쿨다운 적용 — 다시 changeListingMode 시도 → 'COOLDOWN' 거부
//   6. 24h 후 변경 정상 처리
//   7. 활성 grant 보유 매물의 open → exclusive 변경 시도 → 거부 (기득권 보호)
//
// 검증:
//   - listingMode/exclusiveBrokerIds 직접 update 차단 (callable만)
//   - "추천" 어휘 0건 (Task 07 §6.2)
//   - audit log 'grant_rejected_not_in_exclusive_list' / 'listing_mode_changed' 1:1

const { expect } = require('chai');
describe('Task 07 — 매도자 자율 단독 지정 (placeholder)', () => {
  it.skip('TODO: 풀 구현 — Task 07 흐름 7단계', () => {});
});
