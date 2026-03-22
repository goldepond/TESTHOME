# 국토부 실거래가 API

## 1. 개요

국토교통부에서 제공하는 **부동산 실거래가 공공 데이터 API**를 활용하여 매매/전세/월세 거래 정보를 조회합니다.

| 항목 | 내용 |
|------|------|
| 제공처 | 국토교통부 (공공데이터포털) |
| 데이터 유형 | 아파트, 연립다세대, 단독/다가구 매매/전세/월세 실거래 |
| 갱신 주기 | 매월 (전월 거래 기준) |
| 인증 방식 | ServiceKey (공공데이터포털 발급) |

---

## 2. 지원 주택 유형

| 주택 유형 | 매매 API | 전월세 API | 설명 |
|----------|----------|-----------|------|
| **아파트** | `RTMSDataSvcAptTradeDev` | `RTMSDataSvcAptRent` | 공동주택 (5층 이상) |
| **연립다세대** | `RTMSDataSvcRHTrade` | `RTMSDataSvcRHRent` | 연립주택/다세대주택 (4층 이하) |
| **단독/다가구** | `RTMSDataSvcSHTrade` | `RTMSDataSvcSHRent` | 단독주택/다가구주택 |

---

## 3. API 엔드포인트

### 아파트
```
GET https://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev  (매매 - 상세)
GET https://apis.data.go.kr/1613000/RTMSDataSvcAptRent/getRTMSDataSvcAptRent          (전월세)
```

### 연립다세대
```
GET https://apis.data.go.kr/1613000/RTMSDataSvcRHTrade/getRTMSDataSvcRHTrade  (매매)
GET https://apis.data.go.kr/1613000/RTMSDataSvcRHRent/getRTMSDataSvcRHRent    (전월세)
```

### 단독/다가구
```
GET https://apis.data.go.kr/1613000/RTMSDataSvcSHTrade/getRTMSDataSvcSHTrade  (매매)
GET https://apis.data.go.kr/1613000/RTMSDataSvcSHRent/getRTMSDataSvcSHRent    (전월세)
```

---

## 4. 요청 파라미터

| 파라미터 | 필수 | 설명 | 예시 |
|---------|------|------|------|
| `ServiceKey` | O | 공공데이터포털 인증키 | `AbCdEfGh...` |
| `LAWD_CD` | O | 법정동코드 앞 5자리 | `11680` (강남구) |
| `DEAL_YMD` | O | 거래년월 (YYYYMM) | `202501` |
| `_type` | X | 응답 형식 (기본: XML) | `json` |
| `numOfRows` | X | 한 페이지 결과 수 | `100` |
| `pageNo` | X | 페이지 번호 | `1` |

---

## 5. 현재 구현 (RealTransactionService)

### 파일 위치
```
lib/api_request/real_transaction_service.dart
```

### 주요 클래스

#### HousingType (주택 유형)
```dart
enum HousingType {
  apartment,   // 아파트
  rowHouse,    // 연립다세대
  singleHouse, // 단독/다가구
}
```

#### RealTransaction (데이터 모델)
```dart
class RealTransaction {
  // 공통 필드
  final String buildingName;    // 건물명 (아파트명/연립다세대명/빈값)
  final double area;            // 면적 (㎡) - 전용 또는 연면적
  final int dealAmount;         // 거래금액/보증금 (만원)
  final int dealYear;           // 거래년
  final int dealMonth;          // 거래월
  final int dealDay;            // 거래일
  final int floor;              // 층 (단독/다가구는 0)
  final String? buildYear;      // 건축년도
  final String transactionType; // 매매/전세/월세
  final HousingType housingType; // 주택 유형
  final String? umdNm;          // 법정동명
  final String? jibun;          // 지번

  // 매매 전용
  final String? dealingGbn;     // 거래유형 (중개/직거래)
  final String? slerGbn;        // 매도자 구분 (개인/법인)
  final String? buyerGbn;       // 매수자 구분 (개인/법인)

  // 전월세 전용
  final int? deposit;           // 보증금 (만원)
  final int? monthlyRent;       // 월세 (만원)
  final String? contractType;   // 계약구분 (신규/갱신)
  final String? contractTerm;   // 계약기간
  final bool useRenewalRight;   // 갱신요구권 사용 여부
  final int? preDeposit;        // 종전 보증금
  final int? preMonthlyRent;    // 종전 월세

  // 단독/다가구 전용
  final String? houseType;      // 주택유형 (단독/다가구)
  final double? landArea;       // 대지면적 (㎡)
}
```

#### RealTransactionService (API 호출)
```dart
class RealTransactionService {
  // 아파트
  static Future<List<RealTransaction>> getAptTrades({...});
  static Future<List<RealTransaction>> getAptRents({...});

  // 연립다세대
  static Future<List<RealTransaction>> getRhTrades({...});
  static Future<List<RealTransaction>> getRhRents({...});

  // 단독/다가구
  static Future<List<RealTransaction>> getShTrades({...});
  static Future<List<RealTransaction>> getShRents({...});

  // 편의 메서드
  static Future<List<RealTransaction>> getRecentTransactions({
    required String lawdCd,
    String? aptName,
    String transactionType = '매매',
    HousingType housingType = HousingType.apartment,
    int months = 3,
  });

  // 모든 주택유형 통합 조회
  static Future<List<RealTransaction>> getAllHousingTypesTransactions({...});
}
```

---

## 6. 데이터 필터링

### 해제 거래 필터링
매매 API에서 `cdealType == "O"`인 거래는 자동으로 필터링됩니다.

```dart
// 서비스 내부에서 자동 처리
.where((item) => !RealTransaction._isCancelled(item))
```

### 전세/월세 구분
```dart
if (monthlyRent == 0) {
  type = '전세';
} else {
  type = '월세';
}
```

### 고급 필터 옵션

#### 검색 범위 (SearchScope)
| 범위 | 설명 |
|------|------|
| `sameRoad` | 같은 도로 (가장 좁음) |
| `sameDong` | 같은 법정동 (기본값) |
| `sameDistrict` | 같은 시군구 (가장 넓음) |

#### 면적 카테고리 (AreaCategory)
| 카테고리 | 범위 | 설명 |
|---------|------|------|
| `compact` | ~40㎡ | 초소형 (원룸, 1인가구) |
| `small` | 40~59㎡ | 소형 (신혼, 2인가구) |
| `medium` | 60~84㎡ | 중형 (3~4인 표준가구) |
| `large` | 85㎡~ | 대형 (대가족) |

#### 층수 카테고리 (FloorCategory)
| 카테고리 | 범위 |
|---------|------|
| `low` | 1~5층 |
| `mid` | 6~15층 |
| `high` | 16층~ |

#### 건축년도 카테고리 (BuildYearCategory)
| 카테고리 | 기준 |
|---------|------|
| `brandNew` | 5년 이내 |
| `newer` | 5~10년 |
| `middle` | 10~20년 |
| `old` | 20년 이상 |

#### 가격대 필터 (PriceRange)
| 카테고리 | 범위 |
|---------|------|
| `under1` | 1억 미만 |
| `range1to3` | 1~3억 |
| `range3to5` | 3~5억 |
| `range5to10` | 5~10억 |
| `range10to20` | 10~20억 |
| `over20` | 20억 이상 |

#### 거래유형 (DealingType) - 매매만
| 값 | 설명 |
|----|------|
| `broker` | 중개거래 |
| `direct` | 직거래 |

#### 계약구분 (ContractTypeFilter) - 전월세만
| 값 | 설명 |
|----|------|
| `newContract` | 신규 계약 |
| `renewal` | 갱신 계약 |

#### 거래당사자 (PartyType) - 매매만
| 값 | 설명 |
|----|------|
| `individual` | 개인 |
| `corporation` | 법인 |

---

## 7. 사용 예시

### 아파트 매매 조회
```dart
final trades = await RealTransactionService.getAptTrades(
  lawdCd: '11680',    // 강남구
  dealYmd: '202501',  // 2025년 1월
);
```

### 연립다세대 전월세 조회
```dart
final rents = await RealTransactionService.getRhRents(
  lawdCd: '11680',
  dealYmd: '202501',
);
```

### 특정 아파트 최근 3개월 조회
```dart
final transactions = await RealTransactionService.getRecentTransactions(
  lawdCd: '11680',
  aptName: '래미안대치팰리스',
  transactionType: '매매',
  housingType: HousingType.apartment,
  months: 3,
);
```

### 모든 주택유형 통합 조회
```dart
final allTransactions = await RealTransactionService.getAllHousingTypesTransactions(
  lawdCd: '11680',
  transactionType: '매매',
  months: 6,
);
```

### 단계적 로딩 (Progressive Loading)
```dart
await RealTransactionService.getRecentTransactionsProgressive(
  lawdCd: '11680',
  transactionType: '매매',
  housingType: HousingType.apartment,
  months: 12,
  areaCategory: AreaCategory.medium,
  searchScope: SearchScope.sameDong,
  umdNm: '역삼동',
  onData: (transactions, isPartial) {
    if (isPartial) {
      // 최근 3개월 데이터 먼저 표시
      showQuickResults(transactions);
    } else {
      // 전체 12개월 데이터 표시
      showFullResults(transactions);
    }
  },
);
```

### admCd에서 LAWD_CD 추출
```dart
// 예: 1168010100 → 11680
final lawdCd = RealTransactionService.extractLawdCd('1168010100');
```

---

## 8. 캐싱 전략

### 3단계 캐싱 시스템

| 단계 | 저장소 | TTL | 설명 |
|------|--------|-----|------|
| 1단계 | 메모리 캐시 | 1시간 | 앱 실행 중 가장 빠른 응답 |
| 2단계 | 로컬 저장소 | 1시간 | SharedPreferences 기반 영구 저장 |
| 3단계 | API 호출 | - | 캐시 미스 시 공공데이터포털 호출 |

### 캐시 설정

| 항목 | 값 | 설명 |
|------|-----|------|
| TTL | 1시간 | 실거래가는 하루 1회 갱신되므로 1시간 캐시 |
| 최대 개수 | 100개 | 초과 시 오래된 것부터 삭제 |
| 캐시 키 | `{type}_{lawdCd}_{dealYmd}` | 예: `apt_trade_11680_202501` |

### 로컬 캐시 관리
```dart
// 앱 시작 시 만료된 캐시 정리
await RealTransactionService.cleanupLocalCache();
```

---

## 9. 유틸리티 함수

### 가격 포맷팅
```dart
RealTransaction.formatKoreanPrice(94500);  // "9억 4500만원"
RealTransaction.formatKoreanPrice(50000);  // "5억원"
RealTransaction.formatKoreanPrice(8000);   // "8000만원"
```

### 면적 변환
```dart
final transaction = ...;
transaction.area;       // 84.99 (㎡)
transaction.areaPyeong; // 25.7 (평)
```

### 보증금 인상률 계산 (갱신 계약)
```dart
if (transaction.contractType == '갱신') {
  final rate = transaction.depositIncreaseRate;
  print('보증금 인상률: ${rate?.toStringAsFixed(1)}%');
}
```

---

## 10. 에러 처리

| 상황 | 처리 |
|------|------|
| ServiceKey 미설정 | 빈 리스트 반환 + 경고 로그 |
| API 응답 오류 (statusCode != 200) | 빈 리스트 반환 |
| 타임아웃 | TimeoutException 발생 후 빈 리스트 |
| 데이터 없음 (items == null) | 빈 리스트 캐싱 후 반환 |
| 해제된 거래 (cdealType == "O") | 자동 필터링 |

---

## 11. 주택유형별 필드 차이

| 필드 | 아파트 | 연립다세대 | 단독/다가구 |
|------|:------:|:---------:|:----------:|
| 건물명 | `aptNm` | `mhouseNm` | 없음 |
| 면적 | `excluUseAr` (전용) | `excluUseAr` (전용) | `totalFloorAr` (연면적) |
| 대지면적 | 없음 | `landAr` | `plottageAr` |
| 층 | O | O | X |
| 주택유형 | 없음 | 없음 | `houseType` |
| 동 정보 | `aptDong` (등기완료 시) | 없음 | 없음 |

---

## 12. 참고 링크

- [공공데이터포털 - 아파트 매매 실거래가](https://www.data.go.kr/data/15057511/openapi.do)
- [공공데이터포털 - 아파트 전월세 실거래가](https://www.data.go.kr/data/15058017/openapi.do)
- [공공데이터포털 - 연립다세대 매매 실거래가](https://www.data.go.kr/data/15058038/openapi.do)
- [공공데이터포털 - 연립다세대 전월세 실거래가](https://www.data.go.kr/data/15058352/openapi.do)
- [공공데이터포털 - 단독/다가구 매매 실거래가](https://www.data.go.kr/data/15058022/openapi.do)
- [공공데이터포털 - 단독/다가구 전월세 실거래가](https://www.data.go.kr/data/15058352/openapi.do)
- [법정동코드 조회](https://www.code.go.kr/stdcode/regCodeL.do)
