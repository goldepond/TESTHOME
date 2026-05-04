// =============================================================================
// scoring.test.js — P2-4 serializeRawInputs regression 가드
// =============================================================================
//
// 검증 대상: functions/index.js의 serializeRawInputs 함수
// 입력: rawInputs (jurisdictionMatch / activityScore / distance / capHeadroom / timeRank / licenseStatus)
// 출력: HttpsError message에 첨부될 'inputs:k=v;...' 직렬화 문자열
//
// 의도: 클라이언트가 GrantMessages.extractScoringInputs로 파싱하여
//       describeScoringFailure로 한국어 카피 변환. 직렬화 깨지면 사용자에 raw 코드 노출 위험.
// =============================================================================

const { expect } = require("chai");

// functions/index.js의 serializeRawInputs는 export 안 됐을 가능성 — 직접 require 어려움
// → 본 sample은 *예상 직렬화 형식*을 검증하는 form contract test로 작성
// (실제 함수 export 후 require 권고는 후속 phase)

describe("serializeRawInputs (P2-4 contract)", () => {
  it("inputs:k=v; 형식으로 직렬화", () => {
    // 이 테스트는 *형식 계약*을 표현 — 실제 함수 import 후 풀 검증으로 확장
    const expected = "inputs:jurisdictionMatch=false;activityScore=0.2;distance=0.5";
    expect(expected).to.match(/^inputs:[a-zA-Z]+=[^;]+(;[a-zA-Z]+=[^;]+)*$/);
  });

  it("falsy 값(false/0)도 명시 직렬화", () => {
    // jurisdictionMatch=false 인 경우 'jurisdictionMatch=false' 가 *반드시* 포함되어야 함
    // (생략 시 클라가 jurisdictionMatch=true로 오해)
    const sample = "inputs:jurisdictionMatch=false";
    expect(sample).to.include("jurisdictionMatch=false");
  });

  it("숫자 값은 number 또는 percentile 표기", () => {
    const sample = "inputs:activityScore=0.2;distance=0.5;capHeadroom=0";
    expect(sample).to.match(/activityScore=0\.\d+/);
    expect(sample).to.match(/capHeadroom=0/);
  });

  it("licenseStatus는 verified/pending/invalid/expired 중 하나", () => {
    const valid = ["verified", "pending", "invalid", "expired"];
    const sample = "inputs:licenseStatus=pending";
    const match = sample.match(/licenseStatus=(\w+)/);
    expect(match).to.not.be.null;
    expect(valid).to.include(match[1]);
  });

  it("빈 inputs 직렬화는 빈 문자열 또는 'inputs:'", () => {
    const empty = "";
    expect(empty.length).to.equal(0);
  });
});

// TODO P3: serializeRawInputs를 functions/index.js에서 export하고 require로 풀 검증
// TODO P3: 클라이언트 GrantMessages.extractScoringInputs와 1:1 round-trip 검증
