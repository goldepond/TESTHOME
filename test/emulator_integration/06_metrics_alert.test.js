// =============================================================================
// 06_metrics_alert.test.js — Task 06 점유율 모니터링
// =============================================================================
//
// TODO (P3 후속): 풀 구현
//
// 시나리오:
//   1. 시군구 강남구에 active 매물 100건 시드
//   2. market_estimates/{districtCode}에 추정 거래량 200건 시드 (점유율 50% — red 임계)
//   3. computeDailyMetricsScheduled 수동 호출
//   4. platform_metrics/{yyyymmdd} 문서 생성 검증
//   5. alertLevel='red' 검증
//   6. yellow 임계(30~40%) 시드도 별도 시나리오
//
// 검증:
//   - estimatedRegionMarketShare 계산 정확
//   - alertLevel 임계값 (green<0.3 / yellow 0.3~0.4 / red >=0.4)
//   - 시군구별 점유율 분리

const { expect } = require('chai');
describe('Task 06 — 점유율 모니터링 (placeholder)', () => {
  it.skip('TODO: 풀 구현 — Task 06 점유율 흐름', () => {});
});
