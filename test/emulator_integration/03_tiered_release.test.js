// =============================================================================
// 03_tiered_release.test.js — Task 04 지역 단계 노출
// =============================================================================
//
// TODO (P3 후속): 풀 구현
//
// 시나리오:
//   1. 매물 등록 → onMlsPropertyCreated 트리거 → tier1='1km' 시작 + 1km broker 알림
//   2. 24h timestamp 시뮬레이션 → advanceReleaseTierScheduled 수동 호출 → tier2='same_dong'
//   3. 활성 grant 시 단계 진척 정지 (issuePriorityGrant 호출 후 advanceReleaseTierScheduled → tier 무변경)
//   4. exclusive 매물(Task 07) → tier 무시 (모든 단계에서 비지정 broker 알림 0)
//   5. 96h 후 tier4='district' 도달 — 광역 broker 알림
//
// 검증:
//   - tier_releases 서브컬렉션 단계별 1건씩 기록
//   - 활성 grant 시 advanceReleaseTierScheduled가 단계 변경 X
//   - exclusive 매물은 tier 단계 무관

const { expect } = require('chai');
describe('Task 04 — 지역 단계 노출 (placeholder)', () => {
  it.skip('TODO: 풀 구현 — Task 04 흐름 5단계', () => {});
});
