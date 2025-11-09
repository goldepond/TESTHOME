import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';
import 'seoul_broker_service.dart';

/// VWorld 부동산중개업WFS조회 API 서비스
class BrokerService {
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
  }) async {
    try {
      // 1단계: VWorld API에서 기본 중개사 정보 조회
      List<Broker> brokers = await _searchFromVWorld(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );

      // 2단계: 결과가 없으면 반경을 넓혀가며 재시도
      if (shouldAutoRetry && brokers.isEmpty && radiusMeters < 10000) {
        brokers = await _retryWithExpandedRadius(
          latitude: latitude,
          longitude: longitude,
          initialRadius: radiusMeters,
        );
      }

      // 3단계: 서울 지역인 경우 서울시 API 데이터로 보강
      if (brokers.isNotEmpty) {
        brokers = await _enhanceWithSeoulData(brokers);
      }

      return brokers;
    } catch (e) {
      return [];
    }
  }

  /// VWorld API에서 중개사 정보 조회
  static Future<List<Broker>> _searchFromVWorld({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
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

    final proxyUri = Uri.parse(ApiConstants.proxyRequstAddr).replace(queryParameters: {
      'q': uri.toString()
    });
    
    final response = await http.get(proxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () {
        throw Exception('API 타임아웃');
      },
    );
    
    if (response.statusCode == 200) {
      final jsonText = utf8.decode(response.bodyBytes);
      return _parseJSON(jsonText, latitude, longitude);
    } else {
      return [];
    }
  }

  /// 반경을 넓혀가며 재시도 (최대 10km까지)
  static Future<List<Broker>> _retryWithExpandedRadius({
    required double latitude,
    required double longitude,
    required int initialRadius,
  }) async {
    const int maxRadius = 10000;
    const int retrySteps = 3;
    final int increment = (maxRadius - initialRadius) ~/ retrySteps;

    for (int attempt = 0; attempt < retrySteps; attempt++) {
      final int searchRadius = attempt < retrySteps - 1
          ? initialRadius + (attempt + 1) * increment
          : maxRadius;
      
      final brokers = await _searchFromVWorld(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: searchRadius,
      );
      
      if (brokers.isNotEmpty) {
        return brokers;
      }
    }
    
    return [];
  }

  /// 서울시 API 데이터로 중개사 정보 보강
  static Future<List<Broker>> _enhanceWithSeoulData(List<Broker> brokers) async {
    // 서울 지역 여부 확인
    final isSeoulArea = brokers.any((b) => 
      b.roadAddress.contains('서울') || 
      b.jibunAddress.contains('서울')
    );
    
    if (!isSeoulArea) {
      return brokers;
    }

    // 주소 정보 리스트 생성
    final brokerAddresses = brokers.asMap().entries.map((entry) {
      return BrokerAddressInfo(
        key: entry.key.toString(),
        name: entry.value.name,
        roadAddress: entry.value.roadAddress,
        jibunAddress: entry.value.jibunAddress,
      );
    }).toList();

    if (brokerAddresses.isEmpty) {
      return brokers;
    }

    // 서울시 API에서 상세 정보 조회
    final seoulData = await SeoulBrokerService.getBrokersDetailByAddress(brokerAddresses);
    
    if (seoulData.isEmpty) {
      return brokers;
    }

    // 병합된 Broker 리스트 생성
    return brokers.asMap().entries.map((entry) {
      final idx = entry.key;
      final broker = entry.value;
      final seoulInfo = seoulData[idx.toString()];
      
      if (seoulInfo == null) {
        return broker;
      }

      return Broker(
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
    }).toList();
  }
  
  /// BBOX 생성 (검색 범위)
  static String _generateEpsg4326Bbox(double lat, double lon, int radiusMeters) {
    final latDelta = radiusMeters / 111000.0;
    final lonDelta = radiusMeters / (111000.0 * cos(lat * pi / 180));
    
    final ymin = lat - latDelta;
    final xmin = lon - lonDelta;
    final ymax = lat + latDelta;
    final xmax = lon + lonDelta;
    
    return '$ymin,$xmin,$ymax,$xmax,EPSG:4326';
  }

  static List<Broker> _parseJSON(String jsonText, double baseLat, double baseLon) {
    final brokers = <Broker>[];

    try {
      final data = json.decode(jsonText);
      final List<dynamic> features = data['features'] ?? [];


      for (final dynamic featureRaw in features) {
        final feature = featureRaw as Map<String, dynamic>;
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};

        // 각 필드 추출
        final name = properties['bsnm_cmpnm']?.toString() ?? '';
        final roadAddr = properties['rdnmadr']?.toString() ?? '';
        final jibunAddr = properties['mnnmadr']?.toString() ?? '';
        final registNo = properties['brkpg_regist_no']?.toString() ?? '';
        final etcAddr = properties['etc_adres']?.toString() ?? '';
        final employeeCount = properties['emplym_co']?.toString() ?? '';
        final registDate = properties['frst_regist_dt']?.toString().replaceAll('Z', '') ?? '';

        // 좌표 추출 (geometry.coordinates에서 [lon, lat])
        double? brokerLat;
        double? brokerLon;
        double? distance;

        final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
        final coordinates = geometry['coordinates'] as List?;
        if (coordinates != null && coordinates.length >= 2) {
          try {
            brokerLon = double.parse(coordinates[0].toString());
            brokerLat = double.parse(coordinates[1].toString());
            distance = _calculateHaversineDistance(baseLat, baseLon, brokerLat, brokerLon);
          } catch (_) {
            // 좌표 파싱 실패 시 거리 계산 스킵
          }
        }

        brokers.add(Broker(
          name: name,
          roadAddress: roadAddr,
          jibunAddress: jibunAddr,
          registrationNumber: registNo,
          etcAddress: etcAddr,
          employeeCount: employeeCount,
          registrationDate: registDate,
          latitude: brokerLat,
          longitude: brokerLon,
          distance: distance,
        ));
      }

      // 거리순 정렬
      brokers.sort((a, b) {
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

    } catch (_) {
      // 서울시 API 병합 실패 시 기존 브로커 리스트 반환
    }

    return brokers;
  }
  
  /// Haversine 공식으로 거리 계산 (미터)
  static double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    // EPSG:5186 (TM 좌표)인 경우 유클리드 거리
    if (lon1 > 1000 && lon2 > 1000) {
      final dx = lon2 - lon1;
      final dy = lat2 - lat1;
      return sqrt(dx * dx + dy * dy);
    }
    
    // WGS84 좌표인 경우 Haversine 공식
    const R = 6371000.0; // 지구 반지름 (미터)
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}

/// 공인중개사 정보 모델
class Broker {
  final String name;                // 상호명
  final String roadAddress;         // 도로명주소
  final String jibunAddress;        // 지번주소
  final String registrationNumber;  // 등록번호
  final String etcAddress;          // 기타주소 (동/호수)
  final String employeeCount;       // 고용인원
  final String registrationDate;    // 등록일
  final double? latitude;           // 위도
  final double? longitude;          // 경도
  final double? distance;           // 거리 (미터)
  
  // 서울시 API 추가 정보 (전체 21개 필드)
  final String? systemRegNo;        // 시스템등록번호 (SYS_REG_NO)
  final String? ownerName;          // 중개업자명/대표자 (MDT_BSNS_NM)
  final String? businessName;       // 사업자상호 (BZMN_CONM)
  final String? phoneNumber;        // 전화번호 (TELNO)
  final String? businessStatus;     // 상태구분 (STTS_SE)
  final String? seoulAddress;       // 서울시 API 주소 (ADDR)
  final String? district;           // 자치구명 (CGG_CD)
  final String? legalDong;          // 법정동명 (LGL_DONG_NM)
  final String? sggCode;            // 시군구코드 (SGG_CD)
  final String? stdgCode;           // 법정동코드 (STDG_CD)
  final String? lotnoSe;            // 지번구분 (LOTNO_SE)
  final String? mno;                // 본번 (MNO)
  final String? sno;                // 부번 (SNO)
  final String? roadCode;           // 도로명코드 (ROAD_CD)
  final String? bldg;               // 건물 (BLDG)
  final String? bmno;               // 건물 본번 (BMNO)
  final String? bsno;               // 건물 부번 (BSNO)
  final String? penaltyStartDate;   // 행정처분 시작일 (PBADMS_DSPS_STRT_DD)
  final String? penaltyEndDate;     // 행정처분 종료일 (PBADMS_DSPS_END_DD)
  final String? inqCount;           // 조회 개수 (INQ_CNT)
  
  Broker({
    required this.name,
    required this.roadAddress,
    required this.jibunAddress,
    required this.registrationNumber,
    required this.etcAddress,
    required this.employeeCount,
    required this.registrationDate,
    this.latitude,
    this.longitude,
    this.distance,
    this.systemRegNo,
    this.ownerName,
    this.businessName,
    this.phoneNumber,
    this.businessStatus,
    this.seoulAddress,
    this.district,
    this.legalDong,
    this.sggCode,
    this.stdgCode,
    this.lotnoSe,
    this.mno,
    this.sno,
    this.roadCode,
    this.bldg,
    this.bmno,
    this.bsno,
    this.penaltyStartDate,
    this.penaltyEndDate,
    this.inqCount,
  });
  
  /// 거리를 읽기 쉬운 형태로 변환
  String get distanceText {
    if (distance == null) return '-';
    if (distance! >= 1000) {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
    }
    return '${distance!.toStringAsFixed(0)}m';
  }
  
  /// 전체 주소 (도로명 + 기타)
  String get fullAddress {
    if (etcAddress.isEmpty || etcAddress == '-') {
      return roadAddress;
    }
    return '$roadAddress $etcAddress';
  }
}

