# 가로채기·노력 보호 메커니즘 — 산업 횡단 종합 카탈로그

> 작성일: 2026-04-26
> 목적: "다중 에이전트 경쟁 + 노력 사전 투입 + 성공 시에만 보수" 구조에서 발생하는 *가로채기* 및 *노력 보호* 문제를 다른 산업이 어떻게 해결했는지 **유명 사례를 모두 망라**한다.
> 선행 문서:
> - [multi_agent_competition_solutions_cross_industry.md](multi_agent_competition_solutions_cross_industry.md) (v10) — 시스템 강제 가능 메커니즘 2개로 정제
> - [platform_commission_intervention_legal_check.md](platform_commission_intervention_legal_check.md) — 한국법 충돌 검증
>
> 이 문서는 v10에 *없던* 사례·메커니즘을 발굴하는 광범위 망라가 목적이다. 따라서 한국법 적용성 판단은 후순위, *메커니즘 다양성*이 우선이다.

---

## 0. Executive Summary — 핵심 발견 5개

40개 이상의 산업·제도·관행을 조사한 결과, MyHome v10 분석에 *없던* 다음 5가지 메커니즘 유형을 발견했다.

### 발견 1. **"휴전 협정(Cease-Fire Pact)" 모델** — 경쟁자끼리 *공동 서명*하는 가로채기 룰

대표 사례: **FINRA Broker Protocol (2004)**. 경쟁 증권사 3곳이 "이직 시 가져갈 수 있는 고객 정보를 5개 항목으로 한정"하는 협정에 자발 서명 → 1,500개사로 확장. *플랫폼이 룰을 강제하지 않고 참여자가 룰에 합의*하는 구조.

→ MyHome 시사점: 플랫폼이 일방적으로 룰을 발표하는 대신, *지역 중개사 협의체와 공동 서명한 행동강령*을 만들어 위반 시 검증 마크 박탈. 한국 §33①9호("단체 결성 금지")와 충돌하지 않으려면 "단체 결성"이 아닌 "거래 관행 표준화"로 포지셔닝 필수.

### 발견 2. **"기여도 33% 룰(Threshold Contribution)"** — 정량 기여도 미달 시 크레딧 박탈

대표 사례: **WGA Writing Credit Determination**. 제3 작가는 33% 이상 기여 입증 시에만 크레딧. 1·2 작가는 기준 없음. → *공동 작업의 부분 기여자에게 명확한 입력 컷오프*.

→ MyHome 시사점: 공동중개 시 두 번째 진입 중개사는 *임장·계약 기여 시간이 일정 비율 이상*인 경우에만 보호권 인정. v10의 Deal Registration이 시간 우선만 다루는 것과 달리, *기여 정량화* 차원을 추가.

### 발견 3. **"Garden Leave + 5개 정보 한정"** — 이직 시점 자체를 늦추고, 가져갈 수 있는 자원도 제한

대표 사례: **Goldman/UBS Private Banking — Garden Leave 60-90일 + FINRA Protocol 5개 정보 한정**. 이직 직전 60-90일은 무급 휴직(다른 곳 영업도 안 됨), 이직 후 가져갈 수 있는 고객 정보는 5개 항목(이름·주소·전화·이메일·계좌명)으로 한정.

→ MyHome 시사점: 우선권 종료 후 다른 중개사가 진입 시 *Cooling-off period* (예: 7일) 도입. 그 사이 매도자가 충분히 비교·결정할 시간 확보. v10에는 우선권 종료 = 즉시 다른 중개사 진입 가능 구조였음.

### 발견 4. **"Royalty Stack(영구 로열티) → 시장 거부 → ERC-721C 강제 표준"** 패턴

대표 사례: **NFT 창작자 로열티 — OpenSea/Magic Eden/Blur 전쟁**. 로열티가 약속되었으나 강제력 부재 → Blur가 로열티 제거로 시장 점유율 1위 → Magic Eden이 *프로토콜 레벨 강제 (ERC-721C, Open Creator Protocol)* 로 반격. **약속 < 코드 < 프로토콜** 순으로 강제력이 진화한 사례.

→ MyHome 시사점: "노력 보호"를 단순히 *약관·정책*에 명시하는 단계 → *플랫폼 코드 수준에서 강제* 단계 → 만약 거래가 외부로 빠지면 *추적·탐지 + 중개사 자격 박탈* 단계로 점층적 설계. v10의 Deal Registration은 1·2단계만 있고 3단계(이탈 탐지)가 약함.

### 발견 5. **"공식 정량 기준이 있는 패배자 보상 (P3 Stipend, 건축 공모 Honorarium, Topcoder)"** — 모든 산업에서 동일한 비율(0.15-0.48%)

대표 사례: **미국·캐나다 P3 (Public-Private Partnership) Procurement**. 입찰 탈락자에게 총 사업비의 0.15-0.48% (평균 0.25%) 를 *Stipend로 정량 지급*. 평균 50만~100만 달러. **단, IP 사용권을 발주처에 양도하는 조건**.

→ MyHome 시사점: "수수료 분배"는 한국법 충돌하지만, *플랫폼이 자체 비용으로 임장 수당·노력 인정 크레딧 제공*은 합법. v10에서 제외했던 "All-pay+Stipend" 모델을 *플랫폼 자기 부담*으로 재설계 가능. 평균 비율(0.25%) 은 부동산 거래가 5억 원 기준 125만 원 — 플랫폼 흡수 가능 수준.

---

## 1. 카테고리별 사례 카탈로그

### A. 전문 서비스

#### A.1 경매하우스 — Sotheby's / Christie's Specialist 보호

| 차원 | 내용 |
|---|---|
| **사례명** | Sotheby's·Christie's specialist consignor 유치 보호 |
| **문제 구조** | Specialist (각 분야 전문가)가 수년간 컬렉터와 신뢰 관계 구축 → 한 작품 위탁 발견 → 동료가 가로채거나 경쟁 하우스로 이직 시 가져감 |
| **해법 메커니즘** | ① **Specialist에게 보너스 + 지분 부여** — 수익 일부 직접 귀속 ② **Guarantee/Irrevocable Bid** — 위탁자에게 최저가 보장 (하우스 자기 부담) ③ **사내 분쟁은 management 직접 중재** — 분야별 head specialist가 결정 ④ Christie's·Sotheby's 간 Rock-paper-scissors 일화 (Maspro 2005) — 양 하우스가 동률일 때 가위바위보로 결정한 유명 사례 |
| **시스템화 정도** | 사람 판단 (관계 깊이 평가) + 일부 정량(거래액 추적) |
| **효과·한계** | Sotheby's는 specialist 핵심을 잃으며 Christie's에 뒤처지는 흐름 (2024-2025 BSIC 보고). 효과적 보호 부재 시 인재 유출 가속 |
| **한국 적용성** | 변형. *Specialist*를 *지역 전문 중개사*로 치환하면 "특정 단지·지역 전문 중개사" 인증 + 매도자가 직접 지정 시 우선권 (M1.1 옵션과 정합) |
| **출처** | [BSIC](https://bsic.it/what-went-wrong-at-sothebys-inside-the-auction-houses-fall-behind-christies/), [Artsy Rock-paper-scissors](https://www.artsy.net/article/artsy-editorial-christies-sothebys-played-rock-paper-scissors-20-million-consignment), [TheArtNewspaper](https://www.theartnewspaper.com/2018/11/22/why-the-christies-and-sothebys-duopoly-is-impregnable) |

**MyHome 새 시사점**: 가위바위보 일화는 농담 같지만 *완전 공동 기여가 측정 불가*할 때 무작위 결정이 분쟁을 종결시키는 가장 빠른 방법이라는 점에서 의미. v10 Deal Registration의 시간 동률(같은 초 등록) 처리에 무작위 룰 적용 가능.

#### A.2 요트 브로커 — IYBA Central Listing Agreement

| 차원 | 내용 |
|---|---|
| **사례명** | International Yacht Brokers Association (IYBA) Central Listing & Co-broker |
| **문제 구조** | 요트는 부동산처럼 고가·저빈도. 매도자가 다중 브로커에 공개 시 분쟁 빈발 |
| **해법 메커니즘** | ① **Central Listing은 서면 + 최소 30일** — 구두 합의 무효 ② **Co-broker 협력 시 listing broker 동의 없이 제3자 끌어들이기 금지** ③ **수수료 분배는 매수 제안서 *제출 전*에 합의** — 사후 분쟁 방지 ④ **Cooperating broker의 client와 owner 간 직거래 시 listing broker 보호** (직거래 우회 차단) |
| **시스템화 정도** | 사람 판단 + 협회 윤리위 중재 |
| **효과·한계** | 협회 비회원에게 강제력 없음. 미국 위주 (한국 미적용) |
| **한국 적용성** | 직접. *제출 전 분배 합의* 룰이 핵심 — MyHome도 임장 시작 *전*에 공동중개 분배 비율 합의 강제 (수수료 직접 개입은 §32 위반이므로 *권장 양식 제공*까지) |
| **출처** | [IYBA Bylaws](https://iyba.org/bylaws), [IYBA Resources](https://iyba.org/resources) |

**MyHome 새 시사점**: "사전 합의 강제" — 매도자가 다중 중개사에 공개할 경우, 임장 *시작 전*에 분배 비율 합의서를 시스템에서 강제 입력받는 양식. 사후 분쟁이 압도적으로 줄어듦.

#### A.3 프라이빗 뱅킹 — UBS·Goldman·Morgan Stanley Garden Leave

| 차원 | 내용 |
|---|---|
| **사례명** | Wealth Manager 이직 시 Garden Leave + Non-solicit |
| **문제 구조** | Wealth Manager가 고객 50-200명 관계 구축 후 경쟁사로 이직하며 고객 데려감. 회사는 인재 양성 비용 회수 불가 |
| **해법 메커니즘** | ① **Garden Leave 60-90일** — 무급 휴직, 이 기간 영업 금지 ② **Non-solicit 1-2년** — 기존 고객 능동 접촉 금지 (하지만 고객이 자발적으로 따라오는 것은 허용) ③ **Forgivable Loan** — 입사 시 거액 보너스, 일정 기간 근무 시 면제 (조기 이직 시 반환) ④ **FINRA Broker Protocol** — 가져갈 수 있는 정보 5개로 한정 |
| **시스템화 정도** | 계약 + 법적 강제 |
| **효과·한계** | 효과적 — Goldman·UBS·MS 모두 인재 보유 강화. 한계: 본인이 자발적으로 따라오는 고객은 막을 수 없음 (관계 자산은 결국 사람에게 귀속) |
| **한국 적용성** | 변형. 한국 부동산은 중개사 이직 자체가 흔하지 않으나, *우선권 종료 후 매도자가 다른 중개사로 갈 때* 고객 보호 vs 기존 중개사 노력 보호 균형 설계에 시사 |
| **출처** | [AdvisorHub UBS-Goldman](https://www.advisorhub.com/ubs-lands-goldman-sachs-private-wealth-team-in-dallas/), [Kitces](https://www.kitces.com/blog/broker-protocol-recruiting-requirements-for-moving-brokers-to-breakaway-or-go-independent-ria/) |

**MyHome 새 시사점**: **Garden Leave 개념을 우선권 만료 후 *Cooling-off period*로 변형**. 우선권 만료 직후 즉시 다른 중개사 진입이 아니라, 7일 정도 매도자가 결정할 시간을 강제. 그 사이 *기존 중개사의 마지막 의견 진술*을 시스템에서 받음.

#### A.4 증권 FINRA Broker Protocol

| 차원 | 내용 |
|---|---|
| **사례명** | Protocol for Broker Recruiting (2004) |
| **문제 구조** | 증권 브로커가 이직할 때마다 회사 간 소송 폭증 → 산업 전체 비용 |
| **해법 메커니즘** | ① **3개사 자발 서명 (Smith Barney·Merrill·UBS)** — 점차 1,500개사로 확장 ② **5개 항목 정보만 가져가기 허용**: 이름·주소·전화·이메일·계좌명 ③ 그 외 정보 (자산 규모·거래 이력·투자 성향) 반출 금지 ④ Protocol 준수 시 비솔리시트 위반 면제 ⑤ 위반 시 FINRA 징계 |
| **시스템화 정도** | 정적 룰 (5개 항목 정확히 명시) + FINRA 강제 |
| **효과·한계** | 매우 효과적 — 소송 급감. 한계: 일부 대형사 (Morgan Stanley 2017, UBS 2017) 탈퇴하며 약화 추세 |
| **한국 적용성** | 매우 직접적. *어떤 정보까지 가져가도 되는가*를 5개로 한정한 발상은 부동산에 그대로 적용 가능 |
| **출처** | [Kitces](https://www.kitces.com/blog/broker-protocol-recruiting-requirements-for-moving-brokers-to-breakaway-or-go-independent-ria/), [SHU Firm](https://shufirm.com/brokerprotocol) |

**MyHome 새 시사점 (★★★★★)**: 우선권이 만료되어 다른 중개사로 옮겨갈 때, 기존 중개사가 *어떤 데이터를 다음 중개사에게 인수인계해야 하는가* 또는 *어떤 데이터를 가져가지 못하는가*를 5개 항목으로 정량 한정. 예: ① 매도자 연락처 ② 매물 주소 ③ 임장 횟수 ④ 마지막 가격 협상 라인 ⑤ 매수 의향자 수. 이 5개만 시스템에서 후속 중개사에게 노출, 나머지(예: 매수자 신원·내부 메모) 보호.

#### A.5 M&A Advisory — Tail Fee + No-Shop

| 차원 | 내용 |
|---|---|
| **사례명** | Investment Banking Engagement Letter Tail Fee |
| **문제 구조** | M&A 자문사가 인수자 발굴·실사·협상 노력 → 고객이 계약 종료 직후 자문사 없이 거래 종결 → 자문 수수료 회피 |
| **해법 메커니즘** | ① **Tail Period 12-24개월** — 종료 후 1-2년 내 *자문사가 소개한 인수자*와 거래 시 수수료 지급 의무 ② **Solicited Party 명단 첨부** — 누가 자문사 소개인지 명시 ③ **No-Shop 조항** — 협상 중 다른 인수자 접촉 금지 ④ **Active Negotiation Test** — 단순 명단이 아닌 "실질적 협상" 진행한 자만 인정 |
| **시스템화 정도** | 계약 명문화, 분쟁 시 법원 판단 |
| **효과·한계** | 효과적 — 명단 + 실질 협상 두 단계로 거짓 청구 차단 |
| **한국 적용성** | 매우 직접적. v10의 Sunset/Tail이 후행 분리되었지만, *Solicited Party 명단 첨부 + Active Negotiation Test* 발상은 신규 |
| **출처** | [NYSBA](https://nysba.org/beware-of-the-tail-fee-avoiding-the-common-pitfalls-of-investment-banking-agreements/), [Weil PDF](https://www.weil.com/~/media/files/pdfs/engagement_letters.pdf), [Lexology](https://www.lexology.com/library/detail.aspx?g=84675f88-e4c0-492e-8535-954518c0c7f5) |

**MyHome 새 시사점**: Tail Fee의 *Active Negotiation Test*가 핵심 — 단순히 매수자 명단 등록만 인정하지 않고, *임장 진행+가격 협상 진행*까지 진행한 매수자만 보호 대상. v10 Deal Registration이 "임장 신청"만 등록 기준으로 했는데, *"실질적 진행 단계"* 정량 기준 추가 가능.

#### A.6 광고 에이전시 — 미디어 커미션 분배

| 차원 | 내용 |
|---|---|
| **사례명** | 15% Agency Commission + Multi-touch Attribution |
| **문제 구조** | 광고주가 여러 에이전시 사용 시 어느 에이전시 노력으로 매출이 발생했는지 측정 불가 |
| **해법 메커니즘** | ① **Gross-up 방식 15% 커미션** — 매체 비용에 17.65% 가산해 에이전시에 환원 ② **계약 시 카테고리 독점 (competitor exclusivity)** ③ **Multi-touch Attribution 모델** — first/last/linear/time-decay/U-shape ④ **Performance-based fee** — 결과 기반 |
| **시스템화 정도** | 측정 도구화 (GA4·Adobe Analytics 등) |
| **효과·한계** | 측정은 발달했으나 *어느 모델이 맞는가*는 여전히 논쟁 |
| **한국 적용성** | 변형. Multi-touch Attribution은 v10에서 후행 분리되었으나, *카테고리 독점 (competitor exclusivity)* 은 신규 시사점 |
| **출처** | [MediaPost PDF](https://s3.amazonaws.com/media.mediapost.com/uploads/MediaAgencyCompensation.pdf), [Mock Agency](https://mocktheagency.com/content/how-much-commission-does-creative-agency-get/) |

**MyHome 새 시사점**: 광고 에이전시가 *경쟁사 동시 작업 금지* (예: Coke 담당하면 Pepsi 못 받음) 룰을 도입한 것처럼, 한 중개사가 *동일 단지·동일 기간*에 매도자 양측을 동시 대리 못 하게 하는 옵션. 한국 법에서 양타는 합법이지만, *매도자가 단독 대리 옵션 선택 시* 그 중개사는 인근 동 매수자 측 대리 불가.

#### A.7 PR 에이전시 — Retainer Transition Plan

| 차원 | 내용 |
|---|---|
| **사례명** | PR Agency Retainer with Exit Clause |
| **문제 구조** | PR 효과는 1-3개월 후 나타남. 클라이언트가 그 직전 종료 시 노력 무료화 |
| **해법 메커니즘** | ① **3-6개월 최소 약정** ② **30-60일 사전 통지 의무** ③ **Transition Plan** — 후임 에이전시·인하우스로 이전 시 30일 인수인계 ④ **Morals/Ethics Clause** — 양측 위반 시 즉시 해지 |
| **시스템화 정도** | 계약 명문화 |
| **효과·한계** | 효과적이나 강제력은 약함 |
| **한국 적용성** | 직접. *최소 약정 기간 + 사전 통지* 룰을 매도자-중개사 우선권에 적용. v10에서 7일 활동 의무는 있지만, *매도자가 우선권 취소 시 사전 통지* 룰은 미명시 |
| **출처** | [Caster Communications](https://castercomm.com/who-we-are/blog/what%E2%80%99s-really-in-a-pr-retainer-contract-a-guide-to-terms-scope-and-expectations), [Contractable](https://contractable.ai/blog/public-relations-service-agreement-retainers-and-crisis-management-service-provider-guide) |

#### A.8 번역 산업 — Non-Circumvention NCND

| 차원 | 내용 |
|---|---|
| **사례명** | Translation Agency Non-Circumvention/Non-Disclosure |
| **문제 구조** | 에이전시가 클라이언트와 번역가를 매칭 → 양측이 직거래로 빠짐 |
| **해법 메커니즘** | ① **NCND 계약** — 양측 직거래 금지 일정 기간 (보통 2년) ② **ProZ Blue Board** — 평판 시스템으로 위반자 공개 |
| **시스템화 정도** | 계약 + 평판 |
| **효과·한계** | NCND는 위반 입증 어려움. 평판이 더 효과적 |
| **한국 적용성** | 부적합 (한국에서 매도자-중개사 NCND는 사적 자치 영역이나 분쟁 시 입증 곤란) |
| **출처** | [ProZ KudoZ](https://www.proz.com/kudoz/english-to-spanish/law-contracts/2502128-non-circumvention.html) |

---

### B. 매칭 플랫폼

#### B.1 Tinder/Match Group — Retention Paradox

| 차원 | 내용 |
|---|---|
| **사례명** | 데이팅 앱의 "성공이 곧 이탈" 역설 |
| **문제 구조** | 매칭 성사 → 두 사용자 모두 이탈. *플랫폼은 매칭 실패에서 수익* |
| **해법 메커니즘** | ① **유료 사이클 — 한 매칭이 깨지면 다시 돌아오게** ② **Hinge "Designed to be deleted" 메시지 — 역설을 마케팅으로 전환** ③ **데이터 락-인** — 프로필·취향 데이터 누적이 재가입 유도 ④ **금지된 사용자 재가입 차단 시도 (실패)** |
| **시스템화 정도** | 알고리즘 + UX |
| **효과·한계** | 본질적 해결 불가. 다른 데이팅 앱(틴더 → 힌지 → 범블)으로 사용자 순환 |
| **한국 적용성** | **매우 중요한 시사점**: 부동산은 *거래 1회로 이탈*하므로 동일 역설 발생. 해법은 매도자가 "다음 매물 등록 시 자동 우선 노출", 중개사가 "거래 횟수 누적 평판 자산"을 갖게 하는 것 |
| **출처** | [Amplitude](https://amplitude.com/blog/tinder-dating-app-retention-paradox), [The Markup](https://themarkup.org/investigations/2025/02/13/dating-app-tinder-hinge-cover-up) |

**MyHome 새 시사점 (★★★★)**: 부동산도 거래 성사 = 양측 이탈 구조. v10에 누락된 "성공이 곧 이탈" 역설을 명시적으로 다뤄야 함. 해법: *매도자에게는 다음 거래(다른 매물·세입자 매칭) 우선권 누적*, *중개사에게는 거래 누적 평판 = 다음 매물 우선권* 형태로 락-인.

#### B.2 LinkedIn Recruiter — InMail Source Attribution

| 차원 | 내용 |
|---|---|
| **사례명** | Hire Source Attribution Rate |
| **문제 구조** | 채용 담당자가 LinkedIn에서 후보자 발굴 → 다른 채널(이메일·소개)로 최종 채용 → LinkedIn 노력 측정 불가 |
| **해법 메커니즘** | ① **Hire Source Attribution Rate** — 면접·채용 단계별로 발굴 채널 추적 ② **InMail 응답률 (10-25%)** 정량화 ③ **Cost-per-hire** 계산 ④ **Recruiter Corporate $12,960/seat — 사용 자체에 비용 부과** |
| **시스템화 정도** | 분석 대시보드 |
| **효과·한계** | 자기 신고 기반이라 부정확 |
| **한국 적용성** | 직접. *임장 신청 → 매수 의향 → 가격 협상 → 계약*까지 단계별 *원천 채널* 추적 시스템 |
| **출처** | [Juicebox](https://juicebox.ai/blog/linkedin-recruiter-pricing) |

#### B.3 Uber/Lyft — Multi-app Driver & Trip Chaining

| 차원 | 내용 |
|---|---|
| **사례명** | Driver Acceptance Rate + Trip Chaining |
| **문제 구조** | 드라이버가 Uber·Lyft 동시 켜고 cherry-pick. Uber는 드라이버 이탈 방지 필요 |
| **해법 메커니즘** | ① **Acceptance Rate Tier (Blue → Gold → Platinum → Diamond)** — 수락률 높을수록 *프리미엄 콜 우선 배차* ② **Trip Chaining** — 한 콜 끝나기 전 다음 콜 매칭 → 다른 앱 켤 시간 차단 ③ **Surge Pricing** — 비용으로 보상 |
| **시스템화 정도** | 알고리즘 자동 |
| **효과·한계** | 드라이버 불만 (강제로 안 좋은 콜도 수락해야 됨). FTC·CPLEA 조사 대상 |
| **한국 적용성** | 직접. *수락률 기반 우선권* — 임장 요청을 빠르게 수락하는 중개사에게 다음 매물 우선권. 다만 한국 카카오모빌리티 알고리즘 조작 사건처럼 *우선권 알고리즘 투명성*이 필수 |
| **출처** | [Levi Spires](https://www.levispires.com/uber-driver-blog/i-declined-404-uber-trips-to-expose-the-algorithm), [Quora](https://www.quora.com/How-does-Ubers-dispatch-algorithm-work) |

**MyHome 새 시사점**: Trip Chaining 발상 → *임장 종료 직후 인근 다음 매물 우선 추천*으로 중개사를 플랫폼 안에 락-인. 다른 채널(직거래)로 빠질 시간을 최소화.

#### B.4 Doordash/Uber Eats — Restaurant Exclusive

| 차원 | 내용 |
|---|---|
| **사례명** | Doordash 식당 독점 계약 (반독점 소송) |
| **문제 구조** | 식당이 Doordash·Uber Eats 동시 사용 시 양 플랫폼 간 식당 가로채기 |
| **해법 메커니즘** | ① **Exclusive 계약** — 한 플랫폼만 사용 시 수수료 인하 ② **Preferred Placement** — 독점 시 검색 상위 노출 ③ **First-party Delivery 묶음** — 자체 주문도 Doordash Drive로 처리 강제 |
| **시스템화 정도** | 계약 + 알고리즘 노출 조정 |
| **효과·한계** | Uber가 2025년 2월 Doordash를 반독점 위반으로 제소. *멀티호밍 차단의 합법성*이 쟁점. 100대 미국 식당 중 90개 이상이 Doordash 독점 |
| **한국 적용성** | **위험 신호**. MyHome도 매도자에게 *MyHome 단독 등록 시 우대*를 제공할 수 있으나, 시장 지배력 확보 후에는 공정거래법 위반 소지 |
| **출처** | [RestaurantDive](https://www.restaurantdive.com/news/uber-eats-lawsuit-against-doordash-impact-first-party-delivery/740759/), [RestaurantBusinessOnline](https://www.restaurantbusinessonline.com/technology/uber-sues-doordash-alleging-it-bullies-restaurants-exclusive-contracts) |

#### B.5 Airbnb — Off-Platform Policy

| 차원 | 내용 |
|---|---|
| **사례명** | Airbnb Anti-Circumvention |
| **문제 구조** | 호스트·게스트가 첫 거래 후 직거래 ("Direct Booking Bypass") |
| **해법 메커니즘** | ① **메시지 시스템 외부 연락처 자동 마스킹** — 결제 완료 전까지 전화·이메일·SNS 차단 ② **결제 완료 후 일정 기간만 외부 통신 허용** ③ **위반 시 계정 정지** ④ **호스트가 재예약 위해 기존 예약 취소 시 패널티** ⑤ **외부 마케팅 위해 게스트 정보 사용 금지** |
| **시스템화 정도** | 자동 감지 (NLP·정규식) + 사람 검토 |
| **효과·한계** | 효과적이나 100% 차단 불가능. *재거래*는 막을 수 없음 |
| **한국 적용성** | 매우 직접적. **승인 전까지 연락처 비공개** 룰 v10에 이미 있음. 추가: *연락처 교환 후 일정 기간 플랫폼 외부 거래 금지* + *위반 적발 시 다음 거래 우선권 박탈* |
| **출처** | [Airbnb Help](https://www.airbnb.com/help/article/3566), [Airbnb Off-Platform](https://www.airbnb.com/help/article/2799) |

**MyHome 새 시사점 (★★★★★)**: v10에 *연락처 교환 후* 추적이 약함. Airbnb처럼 *플랫폼 메시지 시스템 자체*를 거래 종결까지 의무화 → 외부 통신 시도 자동 탐지 → 우선권 자동 박탈. 위반 입증의 책임을 *플랫폼 데이터 로그*로 이전.

#### B.6 Booking.com/Expedia — Rate Parity (실패 사례)

| 차원 | 내용 |
|---|---|
| **사례명** | OTA Rate Parity Clause (반독점 위반) |
| **문제 구조** | OTA가 호텔에 "어떤 채널에서도 우리보다 싸게 팔지 마라" 강제 |
| **해법 메커니즘** | ① **Wide Parity** — 모든 채널 가격 동일 (EU 금지) ② **Narrow Parity** — 호텔 자체 사이트만 동일 (제한적 허용) ③ **Booking.basic** — 호텔이 OTA를 통해 도매가 판매 |
| **시스템화 정도** | 계약 강제 |
| **효과·한계** | **EU·한국 등 다수 국가에서 위법 판결** — Spain Booking.com €400M 과징금 (2024). EU 최고법원 2024.9.19 판결로 EU 전역 금지 |
| **한국 적용성** | **금지 사례로 학습**. MyHome이 매도자에게 "다른 플랫폼에서 더 싸게 등록 금지" 같은 룰 도입 시 공정거래법 위반 즉시 |
| **출처** | [Mirai](https://www.mirai.com/blog/parity-is-over-defining-a-new-pricing-strategy-with-booking-com-and-expedia/), [LegalDive](https://www.legaldive.com/news/online-price-parity-clauses-at-risk-eu-bookingcom-decision-lodging-other-industries/727688/) |

#### B.7 한국 결혼정보회사 — 듀오·가연

| 차원 | 내용 |
|---|---|
| **사례명** | 듀오·가연 매니저 가입자 매칭 보호 |
| **문제 구조** | 매니저가 가입자 두 명 매칭 → 외부 직거래 (회사 회피) → 회사 매출 손실. 회원이 환불 요구 시 위약금 분쟁 |
| **해법 메커니즘** | ① **위약금 약관 (가입비 - 사용 비례)** ② **매니저 인센티브 = 매칭 성사 건수** ③ **추가 매칭권 시스템** — 한 가입자에게 N회 매칭 보장 ④ **공정위 약관 시정명령** — 불공정 환불 약관 차단 |
| **시스템화 정도** | 약관 + 매니저 KPI |
| **효과·한계** | 한국 결정사 환불 분쟁 빈발 (피해자 모임·법무법인 환불 대행 활성화) |
| **한국 적용성** | 변형. *매니저 인센티브 = 매칭 성사 건수* 모델은 부동산 중개사에 적용 가능 — 우선권 부여 시 *최종 거래 성사*까지 책임 부여 |
| **출처** | [네이트뉴스 듀오-가연 분쟁](https://news.nate.com/view/20231002n03137?mid=n0100), [나무위키 듀오정보](https://namu.wiki/w/%EB%93%80%EC%98%A4%EC%A0%95%EB%B3%B4) |

---

### C. 콘텐츠·창작

#### C.1 음악 산업 — Mechanical Royalty Split

| 차원 | 내용 |
|---|---|
| **사례명** | Songwriter–Publisher–Label 50/50 Split |
| **문제 구조** | 한 곡에 작곡가·작사가·퍼블리셔·레이블·아티스트 5+ 당사자 |
| **해법 메커니즘** | ① **Songwriter share 50% + Publisher share 50%** — 법정 표준 ② **Mechanical Royalty 강제 — Copyright Royalty Board 결정 ($0.0911/곡)** ③ **Harry Fox Agency 중앙 징수** ④ **Performance Royalty (BMI·ASCAP·SESAC)** ⑤ **Sync License** 별도 |
| **시스템화 정도** | 강력 자동화 (메타데이터 → 자동 분배) |
| **효과·한계** | 효과적이나 메타데이터 누락 시 분쟁 (Black Box) |
| **한국 적용성** | 변형. *50/50 강제*는 한국법(매도자·매수자 각자 지급)과 다르나, *메타데이터 기반 자동 분배*는 부동산 공동중개에 시사 |
| **출처** | [Royalty Exchange](https://royaltyexchange.com/blog/mechanical-royalties), [BMI](https://www.bmi.com/news/entry/Understanding_Mechanical_Royalties), [SoundCharts](https://soundcharts.com/en/blog/mechanical-royalties) |

#### C.2 영화·TV — WGA Writing Credit & Separated Rights

| 차원 | 내용 |
|---|---|
| **사례명** | WGA Screen Credits Manual (1941~) |
| **문제 구조** | 한 시나리오에 5-10명 작가 거치며 누가 "Written by" 받을지 분쟁 |
| **해법 메커니즘** | ① **3인 Arbitration Committee** — 익명 ② **3rd 작가 33% 기여 룰** — 1·2 작가는 기준 무, 3+ 는 33% 입증 ③ **Statement 24시간 제출 — 유일한 증거** ④ **Separated Rights** — 시나리오 핵심 캐릭터·아이디어 권리는 작가 보유 (스튜디오 양도 못함) ⑤ **TV Series는 별도 산정** |
| **시스템화 정도** | 사람 판단 (Arbitrator 3인) + 강한 절차 |
| **효과·한계** | 75년 운영. 영화 제작자도 WGA 결정 *불복 불가*. 한계: 익명 위원 결정의 일관성 |
| **한국 적용성** | **신규 시사점 (★★★★)**: *33% 기여 룰* 도입 가능 — 두 번째 진입 중개사가 임장·계약 기여 33% 미만 시 보호권 박탈 |
| **출처** | [WGA Screen Credits Manual](https://www.wga.org/contracts/credits/manuals/screen-credits-manual), [Wikipedia](https://en.wikipedia.org/wiki/WGA_screenwriting_credit_system), [BHBA](https://bhba.org/modernlawyer-posts/the-basics-of-wga-credit-allocation-and-arbitration/) |

**MyHome 새 시사점 (★★★★★)**: WGA의 *33% Threshold + Statement-only Arbitration* 모델은 가장 정교한 다중 기여자 분쟁 해결 시스템. MyHome 적용:
- 두 번째 중개사 진입 시 *임장 횟수·시간·매수자 도입 수*가 첫 번째 중개사의 *33% 이상*이어야 보호권 분할
- 분쟁 시 양 중개사가 24-48시간 내 *시스템 로그 + 1페이지 statement* 제출
- 익명 패널 (이웃 동 중개사 3인) 결정 — 사람 판단의 분쟁 종결 효과

#### C.3 출판 — 다중 에이전트 동시 제출

| 차원 | 내용 |
|---|---|
| **사례명** | Simultaneous Submission Convention |
| **문제 구조** | 작가가 여러 에이전트에게 동시 투고 → 한 에이전트가 시간·노력 투자 후 다른 에이전트가 가져감 |
| **해법 메커니즘** | ① **Simultaneous OK 관행** — 단 다른 에이전트의 진행 상황 *즉시 통지* 의무 ② **Exclusive Period 요청 가능** — 풀스크립트 검토 시 2-4주 ③ **동일 에이전시 내 동시 투고 금지** — 한 명만 ④ **5개 ideal agent + 25 possibility "shotgun 금지"** |
| **시스템화 정도** | 관행 (강제력 약함) |
| **효과·한계** | 작가 자율, 강제 불가 |
| **한국 적용성** | 변형. *통지 의무*가 핵심 — 매도자가 다른 중개사에게 매물 등록 시 기존 중개사에게 *시스템 자동 통지* |
| **출처** | [WritersDigest](https://www.writersdigest.com/getting-published/can-writers-query-multiple-agents-at-once), [Kidlit](https://kidlit.com/simultaneous-submissions/) |

#### C.4 한국 출판 — 표준계약서 인세

| 차원 | 내용 |
|---|---|
| **사례명** | 문체부 출판 표준계약서 (2021) |
| **문제 구조** | 작가-출판사 인세 분쟁, 다중 에이전트 (저작권에이전시) 개입 시 분배 |
| **해법 메커니즘** | ① **선지불·후지불·절충형 3가지 인세 방식** ② **표준계약서 양식 — 발행부수·판매부수 기준 명시** ③ **저작재산권 양도계약서 별도** ④ **출판권 설정계약서 분리** |
| **시스템화 정도** | 양식 제공 (강제력 없음) |
| **효과·한계** | "표준계약서" 표현 자체에 법적 구속력 없음. 출판사 자체 양식 우세 |
| **한국 적용성** | 직접. **MyHome도 *권장 공동중개 합의서 양식* 제공** — 강제는 못 하지만 디폴트 채택률 높임 |
| **출처** | [문체부 표준계약서](https://www.mcst.go.kr/kor/s_data/generalData/dataView.jsp?pSeq=32&pMenuCD=0405050000), [한국출판문화산업진흥원](https://www.kpipa.or.kr/p/g3_4) |

#### C.5 미술 갤러리 — Consignment Agreement

| 차원 | 내용 |
|---|---|
| **사례명** | Artist–Gallery Consignment + Exclusivity |
| **문제 구조** | 갤러리가 작가 발굴·전시 → 작가가 다른 갤러리로 옮기며 매출 가져감 |
| **해법 메커니즘** | ① **Exclusivity Clause** — 지역·장르·기간별 독점 ② **60일 사전 통지 종료** ③ **2-3년 정기 재계약** ④ **Fiduciary Agent 명시** ⑤ **Sales Tail** — 종료 후 갤러리 소개로 발생한 거래 6-12개월 수수료 |
| **시스템화 정도** | 계약 |
| **효과·한계** | 작가 권리 보호 강화 추세 |
| **한국 적용성** | 직접. *지역 독점 옵션 + 60일 사전 통지*는 매도자 단독 중개 모드에 적용 |
| **출처** | [Artwork Archive](https://www.artworkarchive.com/blog/art-business-essentials-consignment-agreements-for-artists), [Mallory Shotwell](https://www.malloryshotwell.com/post/breaking-down-gallery-contracts-what-every-artist-should-know) |

---

### D. 게임·디지털 경제

#### D.1 e스포츠 — LCK 이적료 + Pre-contract Policy

| 차원 | 내용 |
|---|---|
| **사례명** | LCK Transfer Fee + Pre-contract |
| **문제 구조** | 팀이 신인 발굴·육성 → 다른 팀이 자유계약 직전 빼감 |
| **해법 메커니즘** | ① **이적료 (Buyout)** — 새 팀이 원소속팀에 지급 ② **외국 이적 시 추가 가산** ③ **Pre-contract Policy** — 계약 마지막 해 1명 designation, 그 시점부터 협상 가능 ④ **Garden Leave 형태 보호 기간** ⑤ **Roster Lock** — 시즌 중 이적 금지 |
| **시스템화 정도** | 리그 룰 + 협회 강제 |
| **효과·한계** | 효과적. 단 buyout 거품 시기 (2020-2022) 후 안정화 |
| **한국 적용성** | 변형. *이적료 = 노력 보상*은 한국 부동산 §32 충돌. 단 *우선권 양도 시 후속 중개사가 플랫폼에 *수수료 추가* 형태로 응용 가능 |
| **출처** | [Esports Insider](https://esportsinsider.com/2022/07/lck-new-policies), [Sheep Esports](https://www.sheepesports.com/en/all/articles/league-of-legends-the-global-contract-database/en) |

#### D.2 게임 길드 — DKP·EPGP·GDKP·Loot Council

| 차원 | 내용 |
|---|---|
| **사례명** | WoW Raid Loot 분배 시스템 |
| **문제 구조** | 20-40명이 동일 보스 기여 → 1개 아이템을 누가 가질 것인가 |
| **해법 메커니즘** | ① **DKP (Dragon Kill Points)** — 참여 시 적립, 아이템 획득 시 차감 ② **EPGP (Effort/Gear Points)** — 노력 vs 받은 장비 비율 ③ **GDKP (Gold DKP)** — 골드 입찰, 경매 후 골드 분배 ④ **Loot Council** — 길드장 임의 결정 (분쟁 빈발) ⑤ **Need/Greed Roll** — 무작위 |
| **시스템화 정도** | 알고리즘 vs 사람 판단 혼재 |
| **효과·한계** | DKP는 정량 공정성, EPGP는 *받은 만큼 다음 우선권 박탈* (역공정성), GDKP는 시장 메커니즘, Loot Council은 분쟁 다발 |
| **한국 적용성** | **신규 시사점**: *EPGP 발상* — 우선권을 받은 만큼 다음 우선권 점수 차감. 기여(Effort)와 *받은 보상(Gear)*의 비율을 점수화 |
| **출처** | [WoWWiki DKP](https://wowwiki-archive.fandom.com/wiki/Dragon_kill_points), [Guild Relations Wiki](https://guildrelationswow.fandom.com/wiki/Guild_Loot_Distribution_Systems) |

**MyHome 새 시사점 (★★★)**: EPGP 모델 — 우선권을 N번 받았으면 다음 우선권 점수에서 N만큼 차감. 한 중개사 우선권 독점 자동 방지.

#### D.3 DeFi — Vampire Attack & Liquidity Mining

| 차원 | 내용 |
|---|---|
| **사례명** | SushiSwap이 Uniswap 유동성 가로채기 (2020.8) |
| **문제 구조** | 한 프로토콜이 LP 유동성 누적 → 후발주자가 더 좋은 인센티브로 유동성 빨아감 |
| **해법 메커니즘** | ① **SushiSwap이 한 일**: Uniswap LP 토큰 staking 시 SUSHI 보상 → 11일 만에 $1.8B TVL ② **Uniswap의 반격**: UNI 토큰 retroactive airdrop — 과거 사용자에게 보상 ③ **결과**: 한 달 후 Uniswap이 더 강해짐 (생태계 확장 효과) |
| **시스템화 정도** | 스마트 컨트랙트 자동 |
| **효과·한계** | Vampire Attack은 가능하지만, *Retroactive 보상*으로 기존 사용자 락-인 가능 |
| **한국 적용성** | **신규 시사점**: *기존 사용자 Retroactive 보상* — MyHome 정식 출시 시점에 *베타 단계 사용자에게 누적 우선권 점수* 부여 |
| **출처** | [Finematics](https://finematics.com/vampire-attack-sushiswap-explained/), [Gemini Cryptopedia](https://www.gemini.com/cryptopedia/sushiswap-uniswap-vampire-attack), [The Defiant](https://thedefiant.io/news/defi/sushiswaps-vampire-scheme-hours-away-and-with-1-3b-at-stake) |

#### D.4 NFT — Creator Royalty 강제 진화

| 차원 | 내용 |
|---|---|
| **사례명** | OpenSea → Blur → Magic Eden 로열티 전쟁 |
| **문제 구조** | 1세대 NFT 마켓: 창작자 5-10% 영구 로열티 약속 → 2세대(Blur)가 로열티 0%로 차별화 → 1위 등극 → 3세대(Magic Eden)가 *프로토콜 레벨 강제* |
| **해법 메커니즘** | ① **OpenSea** — 약속만 있고 강제 못 함 (창작자 의존) ② **Blur** — 로열티 0%로 트레이더 유치 ③ **Magic Eden Open Creator Protocol (OCP)** — 스마트 컨트랙트 차원 강제, 비준수 마켓 차단 ④ **ERC-721C** — 토큰 표준 자체에 로열티 강제 ⑤ **Yuga Labs+Magic Eden Alliance** — 업계 표준 작성 |
| **시스템화 정도** | 코드 레벨 강제 (3세대) |
| **효과·한계** | 1·2세대 약속은 무력화. 3세대 코드 강제만 작동 |
| **한국 적용성** | **신규 시사점 (★★★★★)**: *약속 → 약관 → 코드 강제* 진화 패턴. v10 Deal Registration도 *약관 레벨*에 머무르면 무력화. 코드 레벨 강제 (예: 매도자 정보 마스킹·결제 묶음·연락처 차단) 필수 |
| **출처** | [Decrypt Yuga](https://decrypt.co/201917/yuga-labs-magic-eden-join-collective-rethinking-nft-creator-royalties), [CoinTelegraph Magic Eden](https://cointelegraph.com/news/magic-eden-follows-opensea-with-nft-royalty-enforcement-tool) |

---

### E. 학술·연구

#### E.1 arXiv Priority Disclosure

| 차원 | 내용 |
|---|---|
| **사례명** | arXiv 타임스탬프 우선권 (1991~) |
| **문제 구조** | 같은 발견을 다른 연구자가 먼저 출판 → "scoop" |
| **해법 메커니즘** | ① **arXiv 업로드 = 타임스탬프 우선권** — 학술지 발행 전 입증 ② **물리학자 일과 = 매일 arXiv 체크** — 가시성 확보 ③ **eLife·EMBO** 등 일부 저널 *preprint scoop protection* — preprint 후 6개월 내 동일 결과 게재 시에도 priority 인정 |
| **시스템화 정도** | 자동 (업로드 시각) |
| **효과·한계** | 물리학·CS·수학에서 표준화. 생물학은 여전히 보수적 |
| **한국 적용성** | 직접. *임장 신청 시각 = 우선권*은 v10에 있음. 추가 시사점: *6개월 priority extension* — 우선권 만료 후에도 N개월간 노력 기록 보호 |
| **출처** | [Review Commons](https://asapbio.org/review-commons-implements-new-policies-on-preprints-and-extended-scoop-protection/), [eLife](https://elifesciences.org/articles/16931), [arXiv FAQ](https://arxiv.org/pdf/1706.04188) |

#### E.2 WIPO Madrid Protocol — Trademark Priority

| 차원 | 내용 |
|---|---|
| **사례명** | International Trademark Priority (1989) |
| **문제 구조** | 한 나라에서 상표 등록 → 다른 나라에서 누가 먼저 베껴 등록할지 경쟁 |
| **해법 메커니즘** | ① **6개월 Priority Window** — 본국 등록일 기준 6개월 내 국제 출원 시 *본국 출원일이 국제 출원일*로 인정 ② **2개월 Submission Window** — 국제국 접수 2개월 내 도착 필수 ③ **One Application, Multi-country** — 단일 출원으로 회원국 동시 보호 |
| **시스템화 정도** | 자동 (날짜 비교) |
| **효과·한계** | 효과적. 한계: 본국 등록 *거절 시 5년간* 국제 등록도 무효 (Central Attack) |
| **한국 적용성** | **신규 시사점**: *Priority Window* 발상 — 매물 등록 후 X일 내 우선권 청구 가능, 그 후엔 일반 풀로 환원 |
| **출처** | [WIPO Madrid](https://www.wipo.int/en/web/madrid-system), [USPTO Madrid](https://www.uspto.gov/ip-policy/international-protection/madrid-protocol) |

#### E.3 Nobel Prize — 3인 한정 + 사후 수상 금지

| 차원 | 내용 |
|---|---|
| **사례명** | Nobel Prize 공동수상 룰 |
| **문제 구조** | 한 발견에 4-10명 기여 시 누구를 인정할 것인가 |
| **해법 메커니즘** | ① **3인 한정** — Watson·Crick·Wilkins (1962) 받고 Franklin (사후) 제외 ② **1974년 사후 수상 폐지** — 그 전까지는 수상자 결정 후 사망은 인정 ③ **재단 결정 = 절대** — 항소·재심 없음 ④ **공동수상 시 1/2·1/4·1/4 분할** (분야마다 다름) |
| **시스템화 정도** | 사람 판단 (위원회) |
| **효과·한계** | 높은 권위. 한계: Franklin 사례처럼 *공정성 영구 논란* 남음 |
| **한국 적용성** | 변형. *3인 한정* 발상은 한 매물 보호권 N명 한정 룰에 적용. 다만 *항소 불가*는 한국 행정법상 적용 불가 |
| **출처** | [NobelPrize.org 1962](https://www.nobelprize.org/prizes/medicine/1962/summary/), [Scientific American Franklin](https://www.scientificamerican.com/article/rosalind-franklin-deserves-a-posthumous-nobel-prize-for-co-discovering-dna-structure/) |

---

### F. 의료·바이오

#### F.1 UNOS — Organ Allocation

| 차원 | 내용 |
|---|---|
| **사례명** | UNOS Organ Procurement & Transplantation Network |
| **문제 구조** | 한 기증 장기에 수백 명 대기자. 누구에게 우선 배정? |
| **해법 메커니즘** | ① **의료·물리 기준만** — 명성·소득·보험 일체 배제 ② **동적 매칭 리스트** — 장기 사용 시점에 새로 생성 ③ **우선순위 다차원**: 의료 긴급도 + 이식 성공 가능성 + 형평성 + 지리 거리 ④ **소아 우선** — 아동에게 아동 장기 ⑤ **CPRA·MELD·LAS** 등 정량 점수 |
| **시스템화 정도** | 알고리즘 자동 (사람 개입 거의 없음) |
| **효과·한계** | 매우 효과적. 한계: 정량 모델 한계 (질병별로 다른 규칙 필요) |
| **한국 적용성** | **신규 시사점 (★★★★)**: *매칭 시점에 *동적*으로 우선권 리스트 생성*. v10은 등록 순으로 정적 — UNOS는 *매물 등록 시점이 아닌 매수 의향 발생 시점*에 다시 계산. 한 매물에 매수 의향이 들어올 때마다 가장 적합한 중개사가 다시 결정됨 |
| **출처** | [UNOS](https://unos.org/transplant/how-we-match-organs/), [Loyola Medicine](https://www.loyolamedicine.org/blog-articles/how-organ-matching-and-prioritization-work-todays-transplant-system) |

**MyHome 새 시사점 (★★★★★)**: UNOS의 *Dynamic List Generation*은 v10에 없는 발상. 매수자가 임장 요청을 *그 시점*에 가장 적합한 중개사 — 임장 가능 시간·해당 매물 임장 횟수·응답 속도·지역 전문성 — 에게 동적 매칭. 매물 등록 시점의 정적 리스트보다 훨씬 효율적.

#### F.2 임상시험 환자 모집 — Site Poaching

| 차원 | 내용 |
|---|---|
| **사례명** | CRO Patient Recruitment Cross-trial Competition |
| **문제 구조** | 같은 질환 환자가 여러 시험에 동시 모집 가능 → 사이트 간 환자 가로채기 |
| **해법 메커니즘** | ① **Competing Trials Analysis** — 사이트의 동시 진행 시험 가시화 ② **DTP (Direct-to-Patient)** — 사이트 우회 직접 모집 ③ **Bonus per enrollment** — 사이트별 인센티브 ④ **Exclusivity at site** — 사이트당 1개 시험만 |
| **시스템화 정도** | 분석 도구 + 계약 |
| **효과·한계** | 환자 풀 한정 시 한계 |
| **한국 적용성** | 변형. *동시 진행 가시화*는 v10에 일부. *Exclusivity at site*는 한국 부동산에 매도자 단독 중개에 적용 |
| **출처** | [WorldPharmaToday](https://www.worldpharmatoday.com/clinical-trails/clinical-trial-patient-recruitment-and-site-selection/), [SCRS Framework](https://myscrs.org/resources/patient-recruitment-landscape/) |

#### F.3 제약 영업 — PDMA Sample Accountability

| 차원 | 내용 |
|---|---|
| **사례명** | Prescription Drug Marketing Act 1987 |
| **문제 구조** | 영업사원이 샘플 무단 유통, 의사 데이터 무단 사용 |
| **해법 메커니즘** | ① **샘플 서면 요청 의무** — 의사가 서명한 요청서 ② **연 1회 샘플 재고 실측** ③ **No Standing Order** — 매번 별도 요청 ④ **PDRP (Prescriber Data Restriction Program)** — 의사가 자기 처방 데이터 차단 가능 |
| **시스템화 정도** | 강력 규제 (FDA) |
| **효과·한계** | 효과적. 영업사원 책임 강화 |
| **한국 적용성** | 변형. *책임의 정량 기록* — 중개사가 임장·통화 등 모든 활동을 시스템 로그에 기록, 분쟁 시 증거 |
| **출처** | [FDA PDMA](https://www.fda.gov/regulatory-information/selected-amendments-fdc-act/prescription-drug-marketing-act-1987), [StatPearls](https://www.ncbi.nlm.nih.gov/books/NBK574533/) |

---

### G. 한국 특화

#### G.1 한국 부동산 — 공동중개 보수 분배 판례

| 차원 | 내용 |
|---|---|
| **사례명** | 대법원 2024.1.4. 2023다252162 외 |
| **문제 구조** | 매도자·매수자 측 중개사가 각각 자기 의뢰인에게서 단독 수금 — 분쟁 시 분배 룰 부재 |
| **해법 메커니즘** | ① **§32 공인중개사법** — 의뢰인-중개사 2자관계 ② **시·도 조례 보수 한도** ③ **§33①9 단체 결성 금지** ④ **대법원 2007 (2005다32159)** — 한도 초과 무효, 환급 ⑤ **인과관계 요건** — 중개행위와 계약 체결 인과관계 입증 시 보수권 |
| **시스템화 정도** | 법령 + 판례 |
| **효과·한계** | 분배 룰 자체는 부재. 양타·공동중개 모두 사적 자치 |
| **한국 적용성** | **MyHome v10 핵심 제약 — 플랫폼 직접 분배 불가, 권장 양식·시각 기록만 가능** |
| **출처** | [국가법령정보 §32](https://www.law.go.kr/), [easylaw 부동산 매매](https://www.easylaw.go.kr/CSP/CnpClsMain.laf?csmSeq=649&ccfNo=2&cciNo=2&cnpClsNo=2) |

#### G.2 한국 공동소송 변호사 보수 분배

| 차원 | 내용 |
|---|---|
| **사례명** | 대법원 91다29804 등 |
| **문제 구조** | 공동소송 위임에서 각 변호사 기여도가 다를 때 보수 분배 |
| **해법 메커니즘** | ① **약정 우선** — 위임계약 명시 ② **신의성실·형평 원칙** — 약정이 *부당하게 과다*하면 상당 범위 내로 감액 ③ **소송비용 산입 별표** — 패소자 부담 산정 시 객관 표준 ④ **민사소송법 §109** |
| **시스템화 정도** | 법령 + 판례 (사후 판단) |
| **효과·한계** | 형평 원칙은 사후·일반론. 사전 분쟁 차단 약함 |
| **한국 적용성** | 직접. *부당 과다 시 감액 가능*은 MyHome 권장 양식의 default rate에 적용 — 시장 평균 대비 일정 % 이상 차이 시 자동 경고 |
| **출처** | [CaseNote 91다29804](https://casenote.kr/%EB%8C%80%EB%B2%95%EC%9B%90/91%EB%8B%A429804), [민사소송법 §109](https://casenote.kr/%EB%B2%95%EB%A0%B9/%EB%AF%BC%EC%82%AC%EC%86%8C%EC%86%A1%EB%B2%95/%EC%A0%9C109%EC%A1%B0) |

#### G.3 한국 건설 하도급 노임 직불제

| 차원 | 내용 |
|---|---|
| **사례명** | 건설산업기본법 §29, 하도급법, 근로기준법 §44의2 |
| **문제 구조** | 원청 → 하청 → 하하청 단계마다 노임 가로채기 |
| **해법 메커니즘** | ① **하도급 제한** — 주요 부분 대부분 하도급 금지 ② **노임 직불제** — 발주자가 하수급인에게 직접 지급 가능 ③ **15일 내 조정 통지 의무** — 원청이 발주자로부터 조정받으면 즉시 통지 ④ **§44의2** — 직상 수급인과 하수급인 임금 연대책임 |
| **시스템화 정도** | 법령 강제 |
| **효과·한계** | 노임 직불 신청률 낮음. 시스템화 미흡 |
| **한국 적용성** | **신규 시사점 (★★★★)**: *직불제* 발상 — 매수자가 중개수수료를 *플랫폼 에스크로*로 결제, 플랫폼이 자격 확인 후 중개사에 송금. 단 §32와 충돌 가능 (의뢰인이 자기 측 중개사에 직접 지급 의무) — *지급 대행* 형태로 우회 가능 |
| **출처** | [건설산업기본법 §29](https://www.law.go.kr/lsInfoP.do?lsId=001808), [하도급법](https://www.law.go.kr/lsInfoP.do?lsId=001590), [국토부 하도급 제도](https://www.molit.go.kr/USR/policyData/m_34681/dtl?id=171) |

#### G.4 한국 카카오 콜택시 — 알고리즘 조작 사건

| 차원 | 내용 |
|---|---|
| **사례명** | 공정거래위원회 의결 2023-093 (카카오모빌리티 257억 과징금) |
| **문제 구조** | 카카오T 배차 알고리즘이 자회사 가맹택시(카카오T블루) 우대 → 비가맹 차별 |
| **해법 메커니즘** | ① **공정위 시정명령** + **257억 과징금** ② **법원 2025.5 판결**: 알고리즘 자체는 *불공정 행위 아님* — 수락률 기반 우선 배차 합법 ③ **알고리즘 공개 의무화 추세** |
| **시스템화 정도** | 사후 규제 |
| **효과·한계** | 한국에서 *플랫폼 알고리즘 조작은 명시적 규제 대상*. 우선권 알고리즘 투명성 필수 |
| **한국 적용성** | **위험 신호 (★★★★★)**: MyHome도 *우선권 부여 알고리즘이 특정 중개사를 우대*한다고 인식되면 동일 위반. 알고리즘 공개·감사 가능성 필수 |
| **출처** | [경향신문 카카오 257억](https://www.khan.co.kr/article/202302141206001), [공정위 의결 2023-093](https://casenote.kr/%EA%B3%B5%EC%A0%95%EA%B1%B0%EB%9E%98%EC%9C%84%EC%9B%90%ED%9A%8C/%EC%9D%98%EA%B2%B02023-093) |

#### G.5 한국 출판 — 표준계약서

(C.4 참조)

#### G.6 한국 결혼정보회사 — 듀오·가연

(B.7 참조)

---

### H. 정부·공공

#### H.1 P3 Procurement Stipend (미국)

| 차원 | 내용 |
|---|---|
| **사례명** | Public-Private Partnership Bid Stipend |
| **문제 구조** | 대형 P3 입찰에 수억 원 제안서 작성 비용 → 패배자 회수 불가 → 입찰 참여자 감소 |
| **해법 메커니즘** | ① **Shortlist 후보자에게 Stipend** — 패배자에게 50만~100만 달러 ② **Stipend 비율 0.15-0.48% (평균 0.25%)** of total contract ③ **IP 사용권 양도 조건** — 패배자 제안 기술 발주처 사용 가능 ④ **승자는 받지 않음** (계약 취소 시 예외) |
| **시스템화 정도** | 명시 정량 룰 |
| **효과·한계** | 매우 효과적 — 입찰 참여자 증가. 한계: IP 양도 부담으로 양질 제안 회피 |
| **한국 적용성** | **신규 시사점 (★★★★★)**: 한국 부동산 §32는 의뢰인↔중개사 2자관계만 허용. 단 **플랫폼 자기 부담**은 합법. *임장 활동 시 평균 0.25% 비례 보상 (5억 매물 기준 125만 원)*을 플랫폼이 마케팅 비용으로 흡수. 매수자가 결국 다른 중개사로 가도 *임장 한 모든 중개사*에게 분배 |
| **출처** | [Bilzin Sumberg P3](https://www.bilzin.com/we-think-big/insights/publications/2020/01/p3-blog-3), [DOT FHWA](https://www.fhwa.dot.gov/ipd/p3/toolkit/publications/other_guides/p3_procurement_guide_0319/ch_4.aspx) |

#### H.2 IATA Airport Slot Allocation

| 차원 | 내용 |
|---|---|
| **사례명** | Worldwide Airport Slot Guidelines (WASG) |
| **문제 구조** | 혼잡 공항 슬롯 분배 — 기존 항공사 vs 신규 항공사 |
| **해법 메커니즘** | ① **Grandfather Rights** — 80:20 룰 (전년 슬롯의 80% 사용 시 다음 해 자동 갱신) ② **Use-it-or-Lose-it** — 80% 미만 사용 시 회수 ③ **신규 진입자 50% 할당** — 새 슬롯 절반은 신규 ④ **Slot Coordinator 중립 기관** |
| **시스템화 정도** | 룰 기반 자동 + 협의 |
| **효과·한계** | 안정성·신규 진입 균형. 한계: Grandfather가 카르텔화 |
| **한국 적용성** | **신규 시사점 (★★★★)**: *Use-it-or-Lose-it 80% 룰* — 우선권을 받았으면 N% 이상 활동(임장·통화)해야 다음 우선권 자동 갱신. v10의 7일 활동 의무를 정량화 |
| **출처** | [IATA WASG](https://www.iata.org/en/programs/ops-infra/slots/slot-guidelines/), [WASG Edition 3 PDF](https://www.iata.org/contentassets/4ede2aabfcc14a55919e468054d714fe/wasg-edition-3-english-version.pdf) |

#### H.3 한국 공공 디자인 공모전 — 서울시·LH

| 차원 | 내용 |
|---|---|
| **사례명** | 서울 공공디자인 공모, 한국디자인전람회 |
| **문제 구조** | 디자이너가 공모 작품 제작 비용 사전 투입 |
| **해법 메커니즘** | ① **본선 진출자 honorarium** — 단 미국 P3보다 적음 ② **상위 입상작 상금** ③ **저작권 발주처 양도** — 보상 조건 |
| **시스템화 정도** | 룰 기반 |
| **효과·한계** | 한국은 honorarium 비율 낮아 입찰 비용 회수 어려움 |
| **한국 적용성** | 직접. **MyHome도 임장 보상을 honorarium 형태로 — 매물 1건당 정량 + 거래 성사 시 중개사 정산** |
| **출처** | [서울 설계공모](https://project.seoul.go.kr/), [공공디자인 종합정보](https://publicdesign.kr/) |

---

### I. 익숙하지 않은 영역

#### I.1 양봉 — 꿀벌 분봉 권리

| 차원 | 내용 |
|---|---|
| **사례명** | Honey Bee Swarm Ownership |
| **문제 구조** | 분봉(swarm)이 발생하면 누구의 것인가 — Roman law ferae naturae 원칙 |
| **해법 메커니즘** | ① **시야 + 추적 가능 시 원소유자** — 시야에서 사라지면 권리 상실 ② **포획자 우선** — 다른 사람이 발견·포획 시 그 사람 소유 ③ **45일 내 여왕벌 교체 의무** (Virginia) ④ **Apiary 등록 시스템** |
| **시스템화 정도** | 관습법 + 주별 규제 |
| **효과·한계** | 명확 |
| **한국 적용성** | **흥미로운 시사점**: *시야·추적 가능성*이 권리 기준 — 매도자가 *지속적 응답·연락 가능*한 동안만 우선권 유지. 연락 두절 시 다른 중개사에게 자동 이전 |
| **출처** | [Beesource Forums](https://www.beesource.com/threads/ownership-of-a-swarm.345025/), [Virginia 2VAC5-319-30](https://law.lis.virginia.gov/admincode/title2/agency5/chapter319/section30/) |

#### I.2 어업 — Individual Transferable Quota (ITQ)

| 차원 | 내용 |
|---|---|
| **사례명** | New Zealand 1986 ITQ 시스템 |
| **문제 구조** | 공유지 비극 — 여러 어부가 같은 어장에서 무한 경쟁 |
| **해법 메커니즘** | ① **TAC (Total Allowable Catch) 설정** ② **Initial Allocation = 과거 어획 이력 비례** ③ **양도 가능** — 자유 시장 거래 ④ **연간 quota** — 사용 안 하면 상실 |
| **시스템화 정도** | 룰 기반 + 시장 |
| **효과·한계** | NZ·아이슬란드·캐나다 등 80% 권리 기반 시스템. 한계: 초기 분배 형평성 문제 |
| **한국 적용성** | **신규 시사점**: *과거 활동 이력 = 초기 우선권 할당 비례* — 매물·임장 이력 많은 중개사에게 *Quota* 부여. 거래 성공 시 추가 적립 |
| **출처** | [Wikipedia IFQ](https://en.wikipedia.org/wiki/Individual_fishing_quota), [EDF Fishery](https://fisherysolutionscenter.edf.org/build-knowledge/sustainable-fisheries/individually-allocated-fishing-rights), [FAO](https://www.fao.org/4/y2684e/y2684e20.htm) |

#### I.3 광산 — General Mining Act 1872 + Prior Appropriation

| 차원 | 내용 |
|---|---|
| **사례명** | 1872 Mining Law |
| **문제 구조** | 광부가 발견·청구권 등록 → 다른 사람이 같은 자리 청구 |
| **해법 메커니즘** | ① **Discovery + Location** — 발견 후 영역 정의·표시 ② **Annual Maintenance** — 매년 작업 입증 또는 수수료 ③ **First-to-locate 우선** ④ **Patent** — 광권 확정 시 토지 자체 소유권 (1994년 후 폐지 추세) |
| **시스템화 정도** | 등록 시스템 |
| **효과·한계** | 1872년 룰 그대로 — 발견자 우선이 핵심 |
| **한국 적용성** | **신규 시사점**: *Annual Maintenance* — 우선권 보유자가 매년 활동 입증 의무. 한 번 받고 묵히면 박탈 |
| **출처** | [Wikipedia 1872 Mining](https://en.wikipedia.org/wiki/General_Mining_Act_of_1872), [BLM](https://www.blm.gov/programs/energy-and-minerals/mining-and-minerals/about) |

#### I.4 인디언 카지노 — Tribal Gaming Compact

| 차원 | 내용 |
|---|---|
| **사례명** | Indian Gaming Regulatory Act 1988 |
| **문제 구조** | 한 주 내 여러 부족 카지노 중복 → 지역 독점 협상 |
| **해법 메커니즘** | ① **3-class Gaming**: I (전통) 부족 단독, II (빙고) 부족+NIGC, III (카지노) 부족-주 compact 필수 ② **Exclusive Class III rights** — 캘리포니아 5% 매출 주에 지급 시 독점 ③ **Compact 조건**: 면허·세무·표준 ④ **Secretary of Interior 승인** |
| **시스템화 정도** | 법령 + 협상 |
| **효과·한계** | 부족·주 협상 비대칭 |
| **한국 적용성** | **신규 시사점**: *지리 독점에 대한 명시 대가* — 매도자 단독 중개 옵션 시 *플랫폼에 일정 비율 대가* 약정 가능 |
| **출처** | [NIGC IGRA](https://www.nigc.gov/office-of-general-counsel/laws-and-regulations/indian-gaming-regulatory-act/), [CRS IGRA](https://www.everycrsreport.com/reports/R42471.html) |

---

## 2. 메커니즘 추출 매트릭스

40+ 사례에서 도출되는 메커니즘 패턴을 분류하면 다음 *11가지 원형*이 나타난다.

| # | 패턴 | 핵심 발상 | 대표 사례 (다수) | MyHome 적용 가능 |
|---|---|---|---|---|
| 1 | **Time Stamp Priority** | 등록 시각 = 절대 우선권 | arXiv·WIPO·1872 Mining·Salesforce·IYBA·NAR | ★★★★★ (v10 M1) |
| 2 | **Threshold Contribution (33% rule)** | 정량 기여도 미달 시 크레딧 박탈 | WGA Writing Credit | ★★★★ (v10 미반영) |
| 3 | **Pre-agreement Forced Form** | 활동 시작 *전* 분배 합의서 양식 강제 | IYBA·결혼정보·M&A engagement | ★★★★ (v10 미반영) |
| 4 | **Garden Leave + Cooling-off** | 우선권 종료 후 N일 무활동 | Goldman·UBS·NAR Procuring Cause | ★★★ (v10 미반영) |
| 5 | **5-item Information Limit** | 양도 가능 데이터 정량 한정 | FINRA Broker Protocol | ★★★★★ (v10 미반영) |
| 6 | **Use-it-or-Lose-it (80:20)** | N% 활동 미달 시 자동 회수 | IATA Slot·1872 Mining 연간 유지 | ★★★★ (v10 7일 활동 의무 → 정량화) |
| 7 | **Tail / Sunset 6-24개월** | 종료 후 일정 기간 노력 보호 | M&A Tail·Insurance Sunset·Gallery Sales Tail | ★★★ (v10 후행 분리) |
| 8 | **Active Negotiation Test** | 형식 등록이 아닌 실질 진행 입증 | M&A Tail Active Test·NAR Procuring Cause | ★★★★ (v10 미반영) |
| 9 | **Dynamic Matching List** | 매칭 시점에 매번 새 우선순위 계산 | UNOS Organ·Uber Dispatch | ★★★★★ (v10 정적 → 동적) |
| 10 | **Code-level Enforcement** | 약속·약관이 아닌 코드 강제 | NFT ERC-721C·Airbnb Off-Platform·Carros | ★★★★★ (v10 약관 수준 → 코드) |
| 11 | **Stipend / Honorarium** | 패배자에게도 정량 보상 | P3 0.25%·Topcoder·서울 공모전 | ★★★ (플랫폼 자기 부담) |

추가로 *3가지 메타 패턴*:

| # | 메타 패턴 | 의미 |
|---|---|---|
| α | **Cease-Fire Pact** | 경쟁자끼리 자발 서명 (FINRA·IYBA·NAR) → 단일 플랫폼 일방 룰보다 강력 |
| β | **Royalty Stack 진화** | 약속 → 약관 → 코드 → 프로토콜 (NFT 사례 압축) |
| γ | **Retroactive Reward** | 과거 사용자 보상으로 락-인 (Uniswap UNI airdrop) |

---

## 3. MyHome에 새로 시사하는 점

v10 분석은 *2개 메커니즘 (Deal Registration M1 + 매도자 자율 선택 M1.1)* 으로 정제되어 있다. 이 catalog 발굴은 v10에 *다음 8가지 보강*을 제시한다.

### 3.1 v10 보강 #1: 33% Threshold Contribution Rule (WGA 모델)

**현 v10**: 두 번째 진입 중개사가 들어오면 *시간 우선*만 비교.
**보강**: 두 번째 중개사도 *임장·연락 활동량이 첫 번째의 33% 이상*이면 분쟁 시 보호권 분할 청구 가능. 미만이면 시간 우선만 인정.

**구현**: 시스템 로그 (임장 횟수·메시지 수·통화 시간) 정량 비교 → 33% 룰 자동 평가 → 분쟁 시 표시.

### 3.2 v10 보강 #2: Code-level Off-Platform Enforcement (Airbnb·NFT 모델)

**현 v10**: 연락처 교환 후 우선권 추적 약함.
**보강**: 거래 종결 전까지 *플랫폼 메시지 시스템 의무*. 외부 통신 시도 자동 탐지 (NLP 패턴 인식). 위반 시 우선권 자동 박탈.

**구현**: 메시지 본문에 전화번호·외부 SNS·이메일 패턴 마스킹. 마스킹 우회 시 경고 → 반복 시 우선권 박탈.

### 3.3 v10 보강 #3: Dynamic Matching List (UNOS 모델)

**현 v10**: 매물 등록 시점 = 정적 우선순위.
**보강**: 매수 의향 발생 시점에 *그 시점 가장 적합한 중개사*에게 동적 매칭. 평가 차원: ① 임장 가능 시간 ② 해당 매물 임장 횟수 ③ 응답 속도 ④ 지역 전문성.

**효과**: 매물 등록 후 1개월 무활동 중개사가 우선권 점유 → 정적 모델은 매수자 손해. 동적 모델은 *매수자 발생 시점에 활동적인 중개사*가 자동 우선.

### 3.4 v10 보강 #4: Use-it-or-Lose-it 정량화 (IATA Slot 모델)

**현 v10**: 7일 임장 진행 의무 (이진 — 진행/미진행).
**보강**: *주간 활동 80% 미만 시 자동 회수*. 활동 = (임장 + 메시지 + 시세 업데이트). 임장 1번이 아니라 매주 일정 활동 강제.

### 3.5 v10 보강 #5: Pre-agreement Forced Form (IYBA·M&A 모델)

**현 v10**: 매도자가 다중 중개사 노출 시 분배 룰 부재.
**보강**: 두 번째 중개사가 진입할 때 *권장 분배 합의서 양식* 자동 제시 — 매도자·기존 중개사·신규 중개사 3자 합의. 합의 미체결 시 시스템에 *분쟁 가능성 경고* 표시.

**한국법 충돌 회피**: 강제 아닌 *권장*으로 §32 우회. 한국 출판 표준계약서 모델과 동일.

### 3.6 v10 보강 #6: Stipend (P3 0.25% 모델)

**현 v10**: 패배자 보상 부재 (All-pay 인정).
**보강**: 플랫폼이 *임장 활동 검증된 중개사*에게 정량 honorarium 지급. 매물 5억 원 기준 0.05% (25만 원) 선. 거래 성사 시 추가 정산 또는 차감.

**재원**: 플랫폼이 매도자로부터 받는 등록 수수료 또는 광고 수익으로 흡수. 매도자·매수자 부담 0 = §32 충돌 없음.

### 3.7 v10 보강 #7: 5-item Information Limit (FINRA 모델)

**현 v10**: 우선권 만료 후 정보 인수인계 룰 부재.
**보강**: 우선권 만료 시 *후속 중개사에게 5개 항목만 전달*: ① 매물 주소 ② 임장 횟수 ③ 마지막 가격 협상 라인 ④ 매수 의향자 수 ⑤ 매도자 특이사항. 그 외(예: 매수자 신원·내부 메모) 보호.

### 3.8 v10 보강 #8: Algorithm Transparency Audit (카카오모빌리티 교훈)

**현 v10**: 우선권 알고리즘 불투명.
**보강**: 알고리즘 *기준 공개* — 어떤 중개사가 어떤 조건에서 우선권 받는지 공개. 변경 이력 감사 로그.

**필수**: 카카오모빌리티 257억 과징금 사례. 시장 지배력 확보 후 알고리즘 조작 의혹은 즉시 공정거래법 §3의2 위반 가능성.

---

## 4. 가장 새로운 발견 5선 — 우선 검토 권고

| 순위 | 메커니즘 | 출처 | v10 대비 | 도입 우선순위 |
|---|---|---|---|---|
| 1 | **5-item Information Limit (FINRA Protocol)** | 증권업계 | 미반영 | ★★★★★ — 우선권 만료 시 후속 중개사에게 무엇을 넘길지 정량 룰 |
| 2 | **Dynamic Matching List (UNOS)** | 의료 | 미반영 | ★★★★★ — 정적 등록 → 동적 매칭으로 패러다임 전환 |
| 3 | **Code-level Enforcement Evolution (NFT ERC-721C)** | 디지털 | 미반영 | ★★★★★ — 약관·약속이 아닌 코드 강제 |
| 4 | **33% Threshold Contribution (WGA)** | 영화 | 미반영 | ★★★★ — 두 번째 중개사 보호권 정량 컷오프 |
| 5 | **P3 Stipend 0.15-0.48% (정부조달)** | 공공 | 후행 분리 → 재고 | ★★★★ — 플랫폼 자기 부담 honorarium |

---

## 5. 출처 목록

### 1차 자료 (협회·정부·기업 공식 문서)

**증권·금융**
- [FINRA Broker Protocol Overview - Kitces](https://www.kitces.com/blog/broker-protocol-recruiting-requirements-for-moving-brokers-to-breakaway-or-go-independent-ria/)
- [Protocol for Broker Recruiting - SHU Firm](https://shufirm.com/brokerprotocol)
- [The Protocol is Breaking Down - Levenfeld Pearlstein](https://www.lplegal.com/content/finra-broker-protocol-for-recruiting-is-breaking-down/)
- [Customer Information Protection - FINRA.org](https://www.finra.org/rules-guidance/key-topics/customer-information-protection)

**M&A·투자은행**
- [Beware of the Tail Fee - NYSBA](https://nysba.org/beware-of-the-tail-fee-avoiding-the-common-pitfalls-of-investment-banking-agreements/)
- [Negotiating Investment Banking Engagement Letters - Weil PDF](https://www.weil.com/~/media/files/pdfs/engagement_letters.pdf)
- [Engagement Letters Lexology](https://www.lexology.com/library/detail.aspx?g=84675f88-e4c0-492e-8535-954518c0c7f5)

**부동산 (NAR Procuring Cause)**
- [Article 17 Case Interpretations - NAR](https://www.nar.realtor/code-of-ethics-and-arbitration-manual/case-interpretations-related-to-article-17)
- [Procuring Cause Arbitration Guidelines - NAR](https://www.nar.realtor/code-of-ethics-and-arbitration-manual/appendix-ii-to-part-ten-arbitration-guidelines)
- [NAR Settlement and Procuring Cause - Inman 2025](https://www.inman.com/2025/06/10/nar-the-settlement-didnt-kill-procuring-cause/)
- [NAR Procuring Cause Introduction PDF](https://www.nabor.com/page-data/files/pages/pro-standards/mediation-and-arbitration-dispute-desolution/NARs-procuring-cause-ntro-and-factors.pdf)

**보험**
- [Broker of Record Letters - NY DFS Opinion 01-04-13](https://www.dfs.ny.gov/insurance/ogco2001/rg104112.htm)
- [Broker of Record Letters - The Coyle Group](https://thecoylegroup.com/broker-of-record-letters/)
- [Hylant BOR Template](https://hylant.com/insights/blog/broker-of-record-letter)

**요트**
- [IYBA Bylaws](https://iyba.org/bylaws)
- [IYBA Resources](https://iyba.org/resources)

**프라이빗 뱅킹**
- [UBS Lands Goldman Wealth Team - AdvisorHub](https://www.advisorhub.com/ubs-lands-goldman-sachs-private-wealth-team-in-dallas/)

**경매하우스**
- [What Went Wrong at Sotheby's - BSIC](https://bsic.it/what-went-wrong-at-sothebys-inside-the-auction-houses-fall-behind-christies/)
- [Christie's Sotheby's Rock-Paper-Scissors - Artsy](https://www.artsy.net/article/artsy-editorial-christies-sothebys-played-rock-paper-scissors-20-million-consignment)
- [Christie's Sotheby's Duopoly - The Art Newspaper](https://www.theartnewspaper.com/2018/11/22/why-the-christies-and-sothebys-duopoly-is-impregnable)

**플랫폼**
- [Airbnb Circumvention Policy](https://www.airbnb.com/help/article/3566)
- [Airbnb Off-Platform and Fee Transparency](https://www.airbnb.com/help/article/2799)
- [Booking.com Parity Mirai](https://www.mirai.com/blog/parity-is-over-defining-a-new-pricing-strategy-with-booking-com-and-expedia/)
- [EU Booking.com Decision - LegalDive](https://www.legaldive.com/news/online-price-parity-clauses-at-risk-eu-bookingcom-decision-lodging-other-industries/727688/)
- [Tinder Retention Paradox - Amplitude](https://amplitude.com/blog/tinder-dating-app-retention-paradox)
- [Uber sues DoorDash - RestaurantDive](https://www.restaurantdive.com/news/uber-eats-lawsuit-against-doordash-impact-first-party-delivery/740759/)
- [Uber Algorithm Insights - Levi Spires](https://www.levispires.com/uber-driver-blog/i-declined-404-uber-trips-to-expose-the-algorithm)

**콘텐츠·창작**
- [WGA Screen Credits Manual](https://www.wga.org/contracts/credits/manuals/screen-credits-manual)
- [WGA Screenwriting Credit System Wikipedia](https://en.wikipedia.org/wiki/WGA_screenwriting_credit_system)
- [WGAE Separated Rights](https://www.wgaeast.org/know-your-rights/separated-rights/)
- [BHBA WGA Credit Allocation](https://bhba.org/modernlawyer-posts/the-basics-of-wga-credit-allocation-and-arbitration/)
- [Mechanical Royalties - Royalty Exchange](https://royaltyexchange.com/blog/mechanical-royalties)
- [BMI Mechanical Royalties Guide](https://www.bmi.com/news/entry/Understanding_Mechanical_Royalties)
- [Soundcharts Mechanical Royalties](https://soundcharts.com/en/blog/mechanical-royalties)
- [Writers Digest Multiple Submissions](https://www.writersdigest.com/getting-published/can-writers-query-multiple-agents-at-once)
- [Kidlit Simultaneous Submissions](https://kidlit.com/simultaneous-submissions/)
- [Artwork Archive Consignment](https://www.artworkarchive.com/blog/art-business-essentials-consignment-agreements-for-artists)
- [Mallory Shotwell Gallery Contracts](https://www.malloryshotwell.com/post/breaking-down-gallery-contracts-what-every-artist-should-know)

**디지털**
- [SushiSwap Vampire Attack - Finematics](https://finematics.com/vampire-attack-sushiswap-explained/)
- [SushiSwap Gemini Cryptopedia](https://www.gemini.com/cryptopedia/sushiswap-uniswap-vampire-attack)
- [SushiSwap The Defiant](https://thedefiant.io/news/defi/sushiswaps-vampire-scheme-hours-away-and-with-1-3b-at-stake)
- [NFT Royalty Magic Eden - CoinTelegraph](https://cointelegraph.com/news/magic-eden-follows-opensea-with-nft-royalty-enforcement-tool)
- [NFT Yuga Magic Eden Alliance - Decrypt](https://decrypt.co/201917/yuga-labs-magic-eden-join-collective-rethinking-nft-creator-royalties)
- [LCK Pre-contract - Esports Insider](https://esportsinsider.com/2022/07/lck-new-policies)
- [LoL Contract Database - Sheep Esports](https://www.sheepesports.com/en/all/articles/league-of-legends-the-global-contract-database/en)
- [WoW DKP - WoWWiki](https://wowwiki-archive.fandom.com/wiki/Dragon_kill_points)

**학술**
- [arXiv Preprint Priority - Review Commons](https://asapbio.org/review-commons-implements-new-policies-on-preprints-and-extended-scoop-protection/)
- [eLife Priority of Discovery](https://elifesciences.org/articles/16931)
- [arXiv Preprint Déjà Vu - Ginsparg](https://arxiv.org/pdf/1706.04188)
- [WIPO Madrid System](https://www.wipo.int/en/web/madrid-system)
- [USPTO Madrid Protocol](https://www.uspto.gov/ip-policy/international-protection/madrid-protocol)
- [Nobel 1962 Medicine](https://www.nobelprize.org/prizes/medicine/1962/summary/)
- [Franklin Posthumous Nobel - Scientific American](https://www.scientificamerican.com/article/rosalind-franklin-deserves-a-posthumous-nobel-prize-for-co-discovering-dna-structure/)

**의료**
- [UNOS How We Match Organs](https://unos.org/transplant/how-we-match-organs/)
- [UNOS Allocation Loyola](https://www.loyolamedicine.org/blog-articles/how-organ-matching-and-prioritization-work-todays-transplant-system)
- [FDA Prescription Drug Marketing Act](https://www.fda.gov/regulatory-information/selected-amendments-fdc-act/prescription-drug-marketing-act-1987)
- [PDMA StatPearls](https://www.ncbi.nlm.nih.gov/books/NBK574533/)
- [SCRS Patient Recruitment Framework](https://myscrs.org/resources/patient-recruitment-landscape/)

**정부·공공**
- [P3 Stipends - Bilzin Sumberg](https://www.bilzin.com/we-think-big/insights/publications/2020/01/p3-blog-3)
- [DOT FHWA P3 Procurement](https://www.fhwa.dot.gov/ipd/p3/toolkit/publications/other_guides/p3_procurement_guide_0319/ch_4.aspx)
- [DOT P3 Successful Practices PDF](https://www.transportation.gov/sites/dot.gov/files/docs/P3_Successful_Practices_Final_BAH.PDF)
- [IATA Worldwide Airport Slot Guidelines](https://www.iata.org/en/programs/ops-infra/slots/slot-guidelines/)
- [WASG Edition 3 PDF](https://www.iata.org/contentassets/4ede2aabfcc14a55919e468054d714fe/wasg-edition-3-english-version.pdf)
- [NIGC Indian Gaming Regulatory Act](https://www.nigc.gov/office-of-general-counsel/laws-and-regulations/indian-gaming-regulatory-act/)
- [IGRA CRS Report](https://www.everycrsreport.com/reports/R42471.html)

**자연자원**
- [Fishing ITQ Wikipedia](https://en.wikipedia.org/wiki/Individual_fishing_quota)
- [EDF Fishery Solutions](https://fisherysolutionscenter.edf.org/build-knowledge/sustainable-fisheries/individually-allocated-fishing-rights)
- [FAO ITQ Case Studies](https://www.fao.org/4/y2684e/y2684e20.htm)
- [General Mining Act 1872 Wikipedia](https://en.wikipedia.org/wiki/General_Mining_Act_of_1872)
- [BLM Mining and Minerals](https://www.blm.gov/programs/energy-and-minerals/mining-and-minerals/about)
- [Beesource Swarm Ownership](https://www.beesource.com/threads/ownership-of-a-swarm.345025/)
- [Virginia Beekeeping Best Practices](https://law.lis.virginia.gov/admincode/title2/agency5/chapter319/section30/)

**한국**
- [공정위 의결 2023-093 (카카오모빌리티)](https://casenote.kr/%EA%B3%B5%EC%A0%95%EA%B1%B0%EB%9E%98%EC%9C%84%EC%9B%90%ED%9A%8C/%EC%9D%98%EA%B2%B02023-093)
- [경향신문 카카오모빌리티 257억 과징금](https://www.khan.co.kr/article/202302141206001)
- [국가법령정보 건설산업기본법](https://www.law.go.kr/lsInfoP.do?lsId=001808)
- [국가법령정보 하도급법](https://www.law.go.kr/lsInfoP.do?lsId=001590)
- [국토부 건설하도급제도](https://www.molit.go.kr/USR/policyData/m_34681/dtl?id=171)
- [대법원 91다29804 (변호사 보수)](https://casenote.kr/%EB%8C%80%EB%B2%95%EC%9B%90/91%EB%8B%A429804)
- [민사소송법 §109](https://casenote.kr/%EB%B2%95%EB%A0%B9/%EB%AF%BC%EC%82%AC%EC%86%8C%EC%86%A1%EB%B2%95/%EC%A0%9C109%EC%A1%B0)
- [easylaw 부동산 매매 중개보수](https://www.easylaw.go.kr/CSP/CnpClsMain.laf?csmSeq=649&ccfNo=2&cciNo=2&cnpClsNo=2)
- [문체부 출판 표준계약서](https://www.mcst.go.kr/kor/s_data/generalData/dataView.jsp?pSeq=32&pMenuCD=0405050000)
- [한국출판문화산업진흥원](https://www.kpipa.or.kr/p/g3_4)
- [듀오정보 나무위키](https://namu.wiki/w/%EB%93%80%EC%98%A4%EC%A0%95%EB%B3%B4)
- [네이트뉴스 듀오-가연 분쟁](https://news.nate.com/view/20231002n03137?mid=n0100)
- [서울 설계공모](https://project.seoul.go.kr/)
- [공공디자인 종합정보시스템](https://www.publicdesign.kr/)

### 학술 논문
- [Priority of Discovery in the Life Sciences - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC4911212/)
- [ITQs and Tragedy of Commons - Canadian Sci](https://cdnsciencepub.com/doi/10.1139/F10-104)
- [Realist Evaluation of ITQ Finland Herring - Oxford ICES](https://academic.oup.com/icesjms/article/78/10/3603/6383435)

---

## 부록: v10 대비 보강 요약

```
v10 메커니즘 (현행)               이 catalog 추가 보강 (8개)
─────────────────────────         ──────────────────────────
M1. Deal Registration         →  +33% Threshold (WGA)
                                 +Active Negotiation Test (M&A)
                                 +Use-it-or-Lose-it 80% (IATA)
                                 +Dynamic List (UNOS)
                                 +Algorithm Transparency (카카오 교훈)

M1.1 매도자 자율 선택         →  +Pre-agreement Form (IYBA)
                                 +5-item Info Limit (FINRA)
                                 +Code-level Enforcement (NFT/Airbnb)
                                 +P3 Stipend 0.25% (정부조달)
                                 +Cooling-off Garden Leave (Goldman)
```

이 보강을 모두 도입할 필요는 없다. 우선순위 5선(섹션 4)을 단계적으로 도입할 것을 권고한다.
