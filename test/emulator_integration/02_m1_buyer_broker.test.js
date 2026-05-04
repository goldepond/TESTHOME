// =============================================================================
// 02_m1_buyer_broker.test.js — Task 03 M1.2 매수자-중개사 매물별 매칭
// =============================================================================
//
// TODO (P3 후속): 풀 구현
//
// 시나리오:
//   1. 매수자 임장 신청 (BuyerInquiry 생성)
//   2. 매수자가 BrokerPickerDialog에서 broker 선택
//   3. createBuyerMatchGrant → buyer_match grant 30일 + 24h 쿨다운 설정
//   4. 24h 내 다른 broker로 변경 시도 → 'BUYER_SWITCH_COOLDOWN' 거부
//   5. 24h 후 (timestamp 시뮬레이션) 변경 시도 → 정상 처리
//   6. 다른 매물에 대해서는 같은 매수자가 *다른 broker* 자유 선택 (영구 바인딩 X)
//
// 검증:
//   - priority_grants 'type=buyer_match' grant 생성
//   - broker_participations 시간기록 동기 생성 (Task 05)
//   - 24h 쿨다운 작동
//   - 매물별 매칭 (영구 바인딩 0)
//   - audit log 1:1 매칭

const { expect } = require('chai');
describe('Task 03 — M1.2 매수자-중개사 매물별 매칭 (placeholder)', () => {
  it.skip('TODO: 풀 구현 — Task 03 흐름 7단계', () => {});
});
