# adjacent_dongs — 법정동 인접 정적 데이터셋

> **상위 문서**: [docs/task/2026-04-30-task-04-tiered-release-handoff.md](../../docs/task/2026-04-30-task-04-tiered-release-handoff.md) §5.1 #1
> **상위 문서 (운영)**: [scripts/p0-migration/README.md](../../scripts/p0-migration/README.md)
> **목표**: tier3_adjacent 인접 동 알림이 *실제 지리적 인접*에 기반하도록 v1의 "같은 시군구 다른 동" 단순화를 대체.

## 1. 데이터 모델

Firestore 컬렉션: `adjacent_dongs/{lawdCd}`

```
adjacent_dongs/{lawdCd}
  - lawdCd: string         (예: "1168010100" — 법정동 10자리 코드)
  - dongName: string       (예: "역삼동")
  - district: string       (예: "강남구")
  - sido: string           (예: "서울특별시")
  - neighbors: string[]    (예: ["1168010200","1168010300", ...])
                           각 항목은 lawdCd 형식. 인접 동의 법정동 코드 배열.
  - source: string         (예: "MOIS_2024Q4" — 데이터 출처 + 갱신 시점)
  - updatedAt: Timestamp
```

## 2. 데이터 소스

| 출처 | URL | 비고 |
|---|---|---|
| 행정안전부 법정동 코드 (전체 목록) | https://www.code.go.kr/stdcode/regCodeL.do | 법정동 코드 + 동명. 인접 정보는 *없음* — 보조용 |
| 통계청 SGIS Plus 행정구역경계 | https://sgis.kostat.go.kr/view/board/expData | shapefile 인접성 계산 가능. 본 데이터셋 빌드의 *주력* |
| 공공데이터포털 SGIS_API | https://www.data.go.kr/data/15001216/openapi.do | 자동 API 호출용 (인증 필요) |

## 3. 빌드 절차 (1회 작업)

```
1. 통계청 SGIS Plus 에서 법정동 shapefile (.shp) 다운로드
2. GIS 도구(QGIS · GeoPandas)에서 인접 폴리곤 추출
3. Python 스크립트로 lawdCd → 인접 lawdCd[] 매핑 JSON 생성
4. 본 디렉토리에 sample-adjacent-dongs.json 형식으로 저장
5. seed-adjacent-dongs.js 로 Firestore 적재
```

## 4. 본 디렉토리 파일

| 파일 | 역할 |
|---|---|
| `README.md` | 본 문서 |
| `sample-adjacent-dongs.json` | 강남구·서초구·송파구 샘플 데이터 (3개 시군구, 23건) — *실제 인접 검증 후 정식 데이터로 교체 필수* |
| `schema.json` | JSON Schema (개별 항목 검증용) |

## 5. 시드 후 functions/index.js 수정 필요

현재 `fetchEligibleBrokersForTier(tier3_adjacent)` 는 "같은 시군구 다른 동"으로 구현됨.
시드 완료 후 다음 P1 phase 에서 다음 변경 권장:

```javascript
// AS-IS (functions/index.js §2.4)
} else if (tier === "tier3_adjacent") {
  candidates = await filterByDifferentRegion(candidates, region);
}
// TO-BE
} else if (tier === "tier3_adjacent") {
  const adjDoc = await db.collection("adjacent_dongs").doc(lawdCd).get();
  const neighborCodes = adjDoc.exists ? adjDoc.data().neighbors || [] : [];
  candidates = await filterByLawdCdSet(candidates, neighborCodes);
  // adjacent_dongs 미존재 시 fallback: filterByDifferentRegion (현 로직 유지)
}
```

본 P0-6 산출물은 **데이터 적재**까지 — functions 로직 변경은 P1 인계.
