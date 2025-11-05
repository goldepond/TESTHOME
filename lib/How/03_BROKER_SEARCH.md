# 03. 공인중개사 찾기 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/03_BROKER_SEARCH.md`

---

## 📋 개요

공인중개사 찾기는 VWorld API와 서울시 공개 API를 연동하여 주변 공인중개사를 검색하고, 상세 정보를 제공합니다.

---

## 🔍 BrokerService 구조

**파일:** `lib/api_request/broker_service.dart`

**핵심 메서드:**

```14:153:lib/api_request/broker_service.dart
/// 주변 공인중개사 검색
/// 
/// [latitude] 위도
/// [longitude] 경도
/// [radiusMeters] 검색 반경 (미터), 기본값 1000m (1km)
static Future<List<Broker>> searchNearbyBrokers({
  required double latitude,
  required double longitude,
  int radiusMeters = 1000,
  bool shouldAutoRetry = true,
  bool isRecursive = false,
}) async {
  try {
    List<Broker> brokers = [];
    
    // BBOX 생성 (EPSG:4326 기준)
    final bbox = _generateEpsg4326Bbox(latitude, longitude, radiusMeters);
    
    final uri = Uri.parse(VWorldApiConstants.brokerQueryBaseUrl).replace(queryParameters: {
      'key': VWorldApiConstants.apiKey,
      'typename': VWorldApiConstants.brokerQueryTypeName,
      'bbox': bbox,
      'resultType': 'results',
      'srsName': VWorldApiConstants.srsName,
      'output': 'application/json',
      'maxFeatures': VWorldApiConstants.brokerMaxFeatures.toString(),
      'domain' : VWorldApiConstants.domainCORSParam,
    });
    
    
    final response = await http.get(uri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () {
        throw Exception('API 타임아웃');
      },
    );
    
    
    if (response.statusCode == 200) {
      final jsonText = utf8.decode(response.bodyBytes);
      // XML 파싱
      brokers = _parseJSON(jsonText, latitude, longitude);
    } else {
      print('   ❌ HTTP 오류: ${response.statusCode}');
      return [];
    }

    // 10KM 이하일 때, 결과값이 0이면 10KM 까지 넒혀가며 3회 재시도. 파라미터가 더러워서 정리가 필요할수도
    if (!isRecursive && shouldAutoRetry && brokers.isEmpty && radiusMeters < 10000) {
      const int step = 3;
      final int remaining = 10000 - radiusMeters;
      final int increment = remaining ~/ step;

      for (int attempt = 0; attempt < step; attempt++) {
        final int searchRadius = attempt < step
            ? radiusMeters + (attempt * increment)
            : 10000;
        brokers = await searchNearbyBrokers(latitude: latitude, longitude: longitude, radiusMeters: searchRadius, isRecursive: true);
        if (brokers.isNotEmpty) break;
      }
    }
    
    // 서울시 API 데이터 병합 (재귀 호출이 아닐 때만, 그리고 서울 지역일 때만)
    if (!isRecursive && brokers.isNotEmpty) {
      // 서울 지역 여부 확인 (주소에 "서울" 포함)
      final isSeoulArea = brokers.any((b) => 
        b.roadAddress.contains('서울') || 
        b.jibunAddress.contains('서울')
      );
      
      if (isSeoulArea) {
        
        // 주소 정보 리스트 생성
        final brokerAddresses = brokers.asMap().entries.map((entry) {
          return BrokerAddressInfo(
            key: entry.key.toString(), // 인덱스를 키로 사용
            name: entry.value.name,
            roadAddress: entry.value.roadAddress,
            jibunAddress: entry.value.jibunAddress,
          );
        }).toList();
        
        if (brokerAddresses.isNotEmpty) {
          final seoulData = await SeoulBrokerService.getBrokersDetailByAddress(brokerAddresses);
          
          if (seoulData.isNotEmpty) {
            // 병합된 Broker 리스트 생성
            brokers = brokers.asMap().entries.map((entry) {
              final idx = entry.key;
              final broker = entry.value;
              final seoulInfo = seoulData[idx.toString()];
              
              if (seoulInfo != null) {
                final merged = Broker(
                  name: broker.name,
                  roadAddress: broker.roadAddress,
                  jibunAddress: broker.jibunAddress,
                  registrationNumber: broker.registrationNumber,
                  etcAddress: broker.etcAddress,
                  employeeCount: broker.employeeCount,
                  registrationDate: broker.registrationDate,
                  latitude: broker.latitude,
                  longitude: broker.longitude,
                  distance: broker.distance,
                  // 서울시 API 데이터 추가 (전체 21개 필드)
                  systemRegNo: seoulInfo.systemRegNo.isNotEmpty ? seoulInfo.systemRegNo : null,
                  ownerName: seoulInfo.ownerName.isNotEmpty ? seoulInfo.ownerName : null,
                  businessName: seoulInfo.businessName.isNotEmpty ? seoulInfo.businessName : null,
                  phoneNumber: seoulInfo.phoneNumber.isNotEmpty ? seoulInfo.phoneNumber : null,
                  businessStatus: seoulInfo.businessStatus.isNotEmpty ? seoulInfo.businessStatus : null,
                  seoulAddress: seoulInfo.address.isNotEmpty ? seoulInfo.address : null,
                  district: seoulInfo.district.isNotEmpty ? seoulInfo.district : null,
                  legalDong: seoulInfo.legalDong.isNotEmpty ? seoulInfo.legalDong : null,
                  sggCode: seoulInfo.sggCode.isNotEmpty ? seoulInfo.sggCode : null,
                  stdgCode: seoulInfo.stdgCode.isNotEmpty ? seoulInfo.stdgCode : null,
                  lotnoSe: seoulInfo.lotnoSe.isNotEmpty ? seoulInfo.lotnoSe : null,
                  mno: seoulInfo.mno.isNotEmpty ? seoulInfo.mno : null,
                  sno: seoulInfo.sno.isNotEmpty ? seoulInfo.sno : null,
                  roadCode: seoulInfo.roadCode.isNotEmpty ? seoulInfo.roadCode : null,
                  bldg: seoulInfo.bldg.isNotEmpty ? seoulInfo.bldg : null,
                  bmno: seoulInfo.bmno.isNotEmpty ? seoulInfo.bmno : null,
                  bsno: seoulInfo.bsno.isNotEmpty ? seoulInfo.bsno : null,
                  penaltyStartDate: seoulInfo.penaltyStartDate.isNotEmpty ? seoulInfo.penaltyStartDate : null,
                  penaltyEndDate: seoulInfo.penaltyEndDate.isNotEmpty ? seoulInfo.penaltyEndDate : null,
                  inqCount: seoulInfo.inqCount.isNotEmpty ? seoulInfo.inqCount : null,
              );
              
              return merged;
              }
              return broker;
            }).toList();
            
          } else {
          }
        }
      } else {
      }
    }
    
    return brokers;
  } catch (e) {
    print('❌ [BrokerService] 공인중개사 검색 오류: $e');
    return [];
  }
}
```

**핵심 알고리즘:**

1. **BBOX 생성**: 위도/경도를 기반으로 검색 범위 생성
2. **자동 재시도**: 결과가 없으면 반경을 점진적으로 확대 (최대 10km)
3. **서울시 API 병합**: 서울 지역인 경우 서울시 API로 추가 정보 조회 (21개 필드)
4. **거리 계산**: Haversine 공식으로 거리 계산 및 정렬

---

## 📊 BrokerListPage 구조

**파일:** `lib/screens/broker_list_page.dart`

**주요 기능:**

1. **검색 및 필터링**
   - 검색어 필터 (이름, 주소)
   - 전화번호 필터
   - 영업상태 필터

2. **페이지네이션**
   - 10개씩 표시
   - 페이지 네비게이션

3. **다중 선택 모드** (MVP 핵심)
   - 여러 중개사 선택
   - 일괄 견적 요청

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[04_QUOTE_REQUEST.md](04_QUOTE_REQUEST.md)** - 견적 요청 시스템 상세 설명

