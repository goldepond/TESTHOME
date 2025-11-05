# 02. 주소 검색 및 부동산 정보 조회 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/02_ADDRESS_SEARCH.md`

---

## 📋 개요

MyHome 서비스의 핵심 기능 중 하나는 주소 검색과 부동산 정보 조회입니다. 사용자가 주소만 입력하면 여러 API를 연동하여 등기부등본, 아파트 정보, 토지 정보를 자동으로 조회합니다.

---

## 🔍 주소 검색 (Juso API)

### 1. AddressService 구조

**파일:** `lib/api_request/address_service.dart`

**주요 메서드:**

```29:145:lib/api_request/address_service.dart
// 도로명 주소 검색
Future<AddressSearchResult> searchRoadAddress(String keyword, {int page = 1}) async {
  if (keyword.trim().length < 4) {
    return AddressSearchResult(
      fullData: [],
      addresses: [],
      totalCount: 0,
      errorMessage: '도로명, 건물명, 지번 등 구체적으로 입력해 주세요.',
    );
  }

  try {
    final url = Uri.parse(
      '${ApiConstants.baseJusoUrl}'
      '?currentPage=$page'
      '&countPerPage=${ApiConstants.pageSize}'
      '&keyword=${Uri.encodeComponent(keyword)}'
      '&confmKey=${ApiConstants.jusoApiKey}'
      '&resultType=json',
    );
    
    
    final response = await http.get(url).timeout(
      Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () {
        throw TimeoutException('주소 검색 시간이 초과되었습니다.');
      },
    );
    
    
    // 503 또는 5xx 에러 처리
    if (response.statusCode == 503 || (response.statusCode >= 500 && response.statusCode < 600)) {
      print('주소 검색 API 서버 오류: ${response.statusCode}');
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: '주소 검색 서비스가 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해주세요. (오류 코드: ${response.statusCode})',
      );
    }
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final errorCode = data['results']['common']['errorCode'];
      final errorMsg = data['results']['common']['errorMessage'];
      
      if (errorCode != '0') {
        print('주소 검색 API 에러 반환: $errorMsg');
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: 'API 오류: $errorMsg',
        );
      }
      
      try {
        final juso = data['results']['juso'];
        final total = int.tryParse(data['results']['common']['totalCount'] ?? '0') ?? 0;
        
        if (juso != null && juso.length > 0) {
          final List<dynamic> rawList = juso as List;
          final addressList = rawList
              .map((e) => e['roadAddr']?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
          final List<Map<String,String>> convertedFullData = rawList
              .map((item) => (item as Map<String,dynamic>).cast<String,String>())
              .where((e) => e.isNotEmpty)
              .toList();
          
          return AddressSearchResult(
            fullData: convertedFullData,
            addresses: addressList,
            totalCount: total,
          );
        } else {
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '검색 결과 없음',
          );
        }
      } catch (e) {
        print('주소 데이터 파싱 오류: $e');
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: '검색 결과 처리 중 오류가 발생했습니다.',
        );
      }
    } else {
      print('API 응답 오류: ${response.statusCode}');
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: 'API 서버 오류 (${response.statusCode})',
      );
    }
  } on TimeoutException {
    return AddressSearchResult(
      fullData: [],
      addresses: [],
      totalCount: 0,
      errorMessage: '주소 검색 시간이 초과되었습니다.',
    );
  } catch (e) {
    return AddressSearchResult(
      fullData: [],
      addresses: [],
      totalCount: 0,
      errorMessage: '주소 검색 중 오류가 발생했습니다: $e',
    );
  }
}
```

**핵심 기능:**

1. **최소 길이 검증**: 4자 이상만 검색 허용
2. **타임아웃 처리**: 10초 타임아웃 설정
3. **에러 처리**: 503, 5xx 에러 별도 처리
4. **페이지네이션**: `currentPage` 파라미터 지원
5. **데이터 파싱**: JSON 응답을 `AddressSearchResult`로 변환

---

### 2. HomePage에서의 주소 검색 통합

**파일:** `lib/screens/home_page.dart`

**디바운싱 처리:**

```474:550:lib/screens/home_page.dart
// 도로명 주소 검색 함수 (AddressService 사용)
Future<void> searchRoadAddress(String keyword, {int page = 1, bool skipDebounce = false}) async {
  // 디바운싱 (페이지네이션은 제외)
  if (!skipDebounce && page == 1) {
    // 중복 요청 방지
    if (_lastSearchKeyword == keyword.trim() && isSearchingRoadAddr) {
      return;
    }
    
    // 이전 타이머 취소
    _addressSearchDebounceTimer?.cancel();
    
    // 디바운싱 적용
    _lastSearchKeyword = keyword.trim();
    _addressSearchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performAddressSearch(keyword, page: page);
    });
    return;
  }
  
  // 페이지네이션이나 즉시 검색이 필요한 경우 바로 실행
  await _performAddressSearch(keyword, page: page);
}

// 실제 주소 검색 수행
Future<void> _performAddressSearch(String keyword, {int page = 1}) async {
  setState(() {
    isSearchingRoadAddr = true;
  });
  
  try {
    final result = await AddressService.instance.searchRoadAddress(keyword, page: page);
    
    if (mounted) {
      setState(() {
        if (page == 1) {
          fullAddrAPIDataList = result.fullData;
          roadAddressList = result.addresses;
        } else {
          // 페이지네이션: 기존 목록에 추가
          fullAddrAPIDataList.addAll(result.fullData);
          roadAddressList.addAll(result.addresses);
        }
        totalCount = result.totalCount;
        currentPage = page;
      });
      
      // 첫 번째 결과 자동 선택
      if (result.addresses.isNotEmpty && page == 1) {
        final firstAddr = result.addresses.first;
        final firstData = result.fullData.first;
        setState(() {
          selectedRoadAddress = firstAddr;
          selectedFullAddrAPIData = firstData;
          selectedFullAddress = firstAddr;
        });
        
        // 자동으로 VWorld 데이터 로드
        _loadVWorldData(firstAddr);
        
        // 단지 정보도 자동으로 로드
        _loadAptInfoFromAddress(firstAddr, fullAddrAPIData: firstData);
      }
    }
  } finally {
    setState(() {
      isSearchingRoadAddr = false;
    });
  }
}
```

**디바운싱 로직:**
- **목적**: 사용자가 입력하는 동안 불필요한 API 호출 방지
- **지연 시간**: 500ms
- **예외**: 페이지네이션은 디바운싱 적용 안 함

---

## 📍 좌표 변환 (VWorld API)

### 1. VWorldService 구조

**파일:** `lib/api_request/vworld_service.dart`

**주요 메서드:**

```17:78:lib/api_request/vworld_service.dart
/// 주소를 좌표로 변환 (Geocoder API)
/// 
/// [address] 도로명주소 또는 지번주소
/// 
/// 반환: {
///   'x': '경도',
///   'y': '위도',
///   'level': '정확도 레벨'
/// }
static Future<Map<String, dynamic>?> getCoordinatesFromAddress(String address) async {
  try {

    final uri = Uri.parse(VWorldApiConstants.geocoderBaseUrl).replace(queryParameters: {
      'service': 'address',
      'request': 'getCoord',
      'version': '2.0',
      'crs': VWorldApiConstants.srsName,
      'address': address,
      'refine': 'true',
      'simple': 'false',
      'format': 'json',
      'type': 'ROAD',
      'key': VWorldApiConstants.geocoderApiKey,
    });


    final response = await http.get(uri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () {
        throw Exception('Geocoder API 타임아웃');
      },
    );
    

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      
      final data = json.decode(responseBody);
      
      if (data['response'] != null && 
          data['response']['status'] == 'OK' &&
          data['response']['result'] != null) {
        
        final result = data['response']['result'];
        
        // point가 있는 경우
        if (result['point'] != null) {
          final point = result['point'];
          
          return {
            'x': point['x'], // 경도 (longitude)
            'y': point['y'], // 위도 (latitude)
            'level': result['level'] ?? '0',
            'address': address,
          };
        }
        
        return null;
      } else {
        print('❌ [VWorldService] 응답 구조 오류: $data');
        return null;
      }
    } else {
      print('❌ [VWorldService] HTTP 오류: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('❌ [VWorldService] Geocoder API 오류: $e');
    return null;
  }
}
```

**HomePage에서의 사용:**

```439:472:lib/screens/home_page.dart
// VWorld API 데이터 로드 (백그라운드)
Future<void> _loadVWorldData(String address) async {
  setState(() {
    isVWorldLoading = true;
    vworldError = null;
    vworldCoordinates = null;
  });
  
  try {
    final result = await VWorldService.getLandInfoFromAddress(address);
    
    if (result != null && mounted) {
      setState(() {
        vworldCoordinates = result['coordinates'];
        isVWorldLoading = false;
      });
      
    } else {
      if (mounted) {
        setState(() {
          isVWorldLoading = false;
          vworldError = 'VWorld API 호출 실패 (CORS 에러 또는 네트워크 오류)';
        });
      }
    }
  } catch (e) {
    print('❌ VWorld API 오류: $e');
    if (mounted) {
      setState(() {
        isVWorldLoading = false;
        vworldError = 'VWorld API 오류: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
      });
    }
  }
}
```

---

## 🏢 아파트 정보 조회 (Data.go.kr API)

### 1. AptInfoService 구조

**파일:** `lib/api_request/apt_info_service.dart`

**주요 메서드:**

```8:124:lib/api_request/apt_info_service.dart
/// 아파트 기본정보 조회
static Future<Map<String, dynamic>?> getAptBasisInfo(String kaptCode) async {
  try {
    
    // ServiceKey URL 인코딩 문제 방지를 위해 queryParameters 사용
    // API 문서에 따르면 Encoding된 인증키를 사용해야 함
    // Uri.replace()가 자동으로 URL 인코딩해줌
    const baseUrl = ApiConstants.aptInfoAPIBaseUrl;
    final queryParams = {
      'ServiceKey': ApiConstants.data_go_kr_serviceKey, // Decoding된 키 (Uri가 자동 인코딩)
      'kaptCode': kaptCode,
    };
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    

    queryParams.forEach((key, value) {
      if (key == 'ServiceKey') {
      } else {
      }
    });

    final response = await http.get(uri);
    
    
    // UTF-8 디코딩으로 응답 본문 가져오기
    String responseBody;
    try {
      responseBody = utf8.decode(response.bodyBytes);
    } catch (e) {
      print('⚠️ [AptInfoService] UTF-8 디코딩 실패, 기본 디코딩 시도: $e');
      responseBody = response.body;
    }
    
    
    if (response.statusCode == 200) {
      try {
        final data = json.decode(responseBody);
        
        // 응답 구조 확인
        if (data['response'] != null) {
          final responseData = data['response'];
          
          // 에러 체크
          if (responseData['header'] != null) {
            final header = responseData['header'];
            final resultCode = header['resultCode']?.toString() ?? '';
            final resultMsg = header['resultMsg']?.toString() ?? '';
            
            // 에러 코드가 있는 경우
            if (resultCode != '00' && resultCode != '0') {
              print('❌ [AptInfoService] API 에러 응답 - resultCode: $resultCode, resultMsg: $resultMsg');
              return null;
            }
          }
          
          if (responseData['body'] != null) {
            final body = responseData['body'];
            
            // 응답 구조 확인: body['item'] 또는 body['items']['item']
            dynamic item;
            if (body['item'] != null) {
              // 직접 item이 있는 경우 (getAphusDtlInfoV4)
              item = body['item'];
              return _parseAptInfo(item);
            } else if (body['items'] != null && body['items']['item'] != null) {
              // items 안에 item이 있는 경우 (다른 API)
              item = body['items']['item'];
              return _parseAptInfo(item);
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          print('❌ [AptInfoService] response가 없습니다 - data: $data');
          return null;
        }
      } catch (e) {
        print('❌ [AptInfoService] JSON 파싱 오류: $e');
        print('❌ [AptInfoService] 파싱 실패한 응답 본문: $responseBody');
        return null;
      }
    } else {
      print('❌ [AptInfoService] API 요청 실패 - 상태코드: ${response.statusCode}');
      print('❌ [AptInfoService] 응답 헤더: ${response.headers}');
      print('❌ [AptInfoService] 응답 본문: $responseBody');
      
      // 500 에러인 경우 추가 정보
      if (response.statusCode == 500) {
        print('❌ [AptInfoService] 500 Internal Server Error 발생');
        print('❌ [AptInfoService] 이는 서버 측 오류입니다. 가능한 원인:');
        print('   1. API 서버 일시적 오류');
        print('   4. 요청 파라미터 형식 오류');
      }
      
      // 응답 본문이 JSON 형식인지 확인
      try {
        final errorData = json.decode(responseBody);
        print('❌ [AptInfoService] 에러 응답 JSON: $errorData');
        
        if (errorData['response'] != null && errorData['response']['header'] != null) {
          final errorHeader = errorData['response']['header'];
          final errorCode = errorHeader['resultCode']?.toString() ?? '';
          final errorMsg = errorHeader['resultMsg']?.toString() ?? '';
          print('❌ [AptInfoService] API 에러 코드: $errorCode, 메시지: $errorMsg');
        }
      } catch (e) {
        print('⚠️ [AptInfoService] 에러 응답이 JSON 형식이 아닙니다');
      }
      
      return null;
    }
  } catch (e) {
    print('❌ [AptInfoService] 아파트 기본정보 조회 오류: $e');
    return null;
  }
}
```

**아파트 정보 파싱:**

```127:200:lib/api_request/apt_info_service.dart
/// 아파트 정보 파싱
static Map<String, dynamic> _parseAptInfo(dynamic item) {
  final Map<String, dynamic> aptInfo = {};
  
  try {
    // 기본 정보
    aptInfo['kaptCode'] = item['kaptCode'] ?? ''; // 단지코드
    aptInfo['kaptName'] = item['kaptName'] ?? ''; // 단지명
    
    // 관리 정보
    aptInfo['codeMgr'] = item['codeMgr'] ?? ''; // 관리방식
    aptInfo['kaptMgrCnt'] = item['kaptMgrCnt'] ?? ''; // 관리사무소 수
    aptInfo['kaptCcompany'] = item['kaptCcompany'] ?? ''; // 관리업체
    
    // 보안 정보
    aptInfo['codeSec'] = item['codeSec'] ?? ''; // 보안관리방식
    aptInfo['kaptdScnt'] = item['kaptdScnt'] ?? ''; // 보안인력 수
    aptInfo['kaptdSecCom'] = item['kaptdSecCom'] ?? ''; // 보안업체
    
    // 청소 정보
    aptInfo['codeClean'] = item['codeClean'] ?? ''; // 청소관리방식
    aptInfo['kaptdClcnt'] = item['kaptdClcnt'] ?? ''; // 청소인력 수
    aptInfo['codeGarbage'] = item['codeGarbage'] ?? ''; // 쓰레기 수거방식
    
    // 소독 정보
    aptInfo['codeDisinf'] = item['codeDisinf'] ?? ''; // 소독관리방식
    aptInfo['kaptdDcnt'] = item['kaptdDcnt'] ?? ''; // 소독인력 수
    aptInfo['disposalType'] = item['disposalType'] ?? ''; // 소독방식
    
    // 건물 정보
    aptInfo['codeStr'] = item['codeStr'] ?? ''; // 건물구조
    aptInfo['kaptdEcapa'] = item['kaptdEcapa'] ?? ''; // 전기용량
    aptInfo['codeEcon'] = item['codeEcon'] ?? ''; // 전기계약방식
    aptInfo['codeEmgr'] = item['codeEmgr'] ?? ''; // 전기관리방식
    
    // 소방 정보
    aptInfo['codeFalarm'] = item['codeFalarm'] ?? ''; // 화재경보기 타입
    
    // 급수 정보
    aptInfo['codeWsupply'] = item['codeWsupply'] ?? ''; // 급수방식
    
    // 엘리베이터 정보
    aptInfo['codeElev'] = item['codeElev'] ?? ''; // 엘리베이터 관리방식
    aptInfo['kaptdEcnt'] = item['kaptdEcnt'] ?? ''; // 엘리베이터 수
    
    // 주차 정보
    aptInfo['kaptdPcnt'] = item['kaptdPcnt'] ?? ''; // 지상주차장 수
    aptInfo['kaptdPcntu'] = item['kaptdPcntu'] ?? ''; // 지하주차장 수
    
    // 통신 정보
    aptInfo['codeNet'] = item['codeNet'] ?? ''; // 인터넷 설치여부
    aptInfo['kaptdCccnt'] = item['kaptdCccnt'] ?? ''; // CCTV 수
    
    // 편의시설
    aptInfo['welfareFacility'] = item['welfareFacility'] ?? ''; // 복리시설
    
    // 교통 정보
    aptInfo['kaptdWtimebus'] = item['kaptdWtimebus'] ?? ''; // 버스 도보시간
    aptInfo['subwayLine'] = item['subwayLine'] ?? ''; // 지하철 노선
    aptInfo['subwayStation'] = item['subwayStation'] ?? ''; // 지하철역
    aptInfo['kaptdWtimesub'] = item['kaptdWtimesub'] ?? ''; // 지하철 도보시간
    
    // 주변시설
    aptInfo['convenientFacility'] = item['convenientFacility'] ?? ''; // 편의시설
    aptInfo['educationFacility'] = item['educationFacility'] ?? ''; // 교육시설
    
    // 전기차 충전기
    aptInfo['groundElChargerCnt'] = item['groundElChargerCnt'] ?? ''; // 지상 전기차 충전기 수
    aptInfo['undergroundElChargerCnt'] = item['undergroundElChargerCnt'] ?? ''; // 지하 전기차 충전기 수
    
    // 사용여부
    aptInfo['useYn'] = item['useYn'] ?? ''; // 사용여부
    
    
  } catch (e) {
```

**HomePage에서의 사용:**

```553:642:lib/screens/home_page.dart
/// 주소에서 단지코드 정보 자동 조회
Future<void> _loadAptInfoFromAddress(String address, {Map<String, String>? fullAddrAPIData}) async {
  if (address.isEmpty) {
    return;
  }
  
  setState(() {
    isLoadingAptInfo = true;
    aptInfo = null;
    kaptCode = null;
  });
  
  try {
    // 주소에서 단지코드를 비동기로 추출 시도 (도로명코드/법정동코드 우선, 단지명 검색 fallback)
    final extractedKaptCode = await AptInfoService.extractKaptCodeFromAddressAsync(address, fullAddrAPIData: fullAddrAPIData);
    
    if (extractedKaptCode != null && extractedKaptCode.isNotEmpty) {
      // 실제 API 호출
      final aptInfoResult = await AptInfoService.getAptBasisInfo(extractedKaptCode);
      
      if (mounted) {
        if (aptInfoResult != null) {
```

---

## 🔄 전체 플로우 정리

### 사용자 주소 입력 → 정보 조회 플로우

```
1. 사용자 입력 (주소)
   ↓
2. 디바운싱 (0.5초 대기)
   ↓
3. Juso API 호출 (AddressService)
   ↓
4. 결과 표시 및 첫 번째 자동 선택
   ↓
5. 동시에:
   - VWorld API 호출 (좌표 변환)
   - AptInfoService 호출 (아파트 정보)
   ↓
6. 좌표 정보 저장 (공인중개사 검색용)
   ↓
7. 아파트 정보 표시
   ↓
8. "공인중개사 찾기" 버튼 활성화
```

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[03_BROKER_SEARCH.md](03_BROKER_SEARCH.md)** - 공인중개사 찾기 상세 설명

