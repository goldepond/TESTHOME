import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

/// VWorld API 서비스
/// Geocoder API: 주소 → 좌표 변환
class VWorldService {
  /// 주소를 좌표로 변환 (Geocoder API)
  /// 
  /// [address] 도로명주소 또는 지번주소
  /// 
  /// 반환: {
  ///   'x': '경도',
  ///   'y': '위도',
  ///   'level': '정확도 레벨'
  /// }
  static Future<Map<String, dynamic>?> getCoordinatesFromAddress(
    String address, {
    Map<String, String>? fullAddrData,
  }) async {
    // 1) 건물관리번호(bdMgtSn)가 있는 경우 우선 시도
    final buildingId = fullAddrData?['bdMgtSn']?.trim();
    if (buildingId != null && buildingId.isNotEmpty) {
      final baseAddress = fullAddrData?['roadAddrPart1'] ??
          fullAddrData?['roadAddr'] ??
          address;
      final inferredType = (fullAddrData?['roadAddrPart1']?.trim().isNotEmpty ?? false) ||
              (fullAddrData?['roadAddr']?.trim().isNotEmpty ?? false)
          ? 'road'
          : 'parcel';
      final buildingResult = await _requestGeocoderByBuildingId(
        buildingId,
        baseAddress,
        inferredType,
      );
      if (buildingResult != null) {
        final enriched = Map<String, dynamic>.from(buildingResult);
        enriched['text'] = enriched['text'] ?? baseAddress;
        enriched['source'] = 'BLD';
        return enriched;
      }
    }

    // 2) 주소 후보를 한 번씩만 시도 (ROAD → PARCEL)
    final tried = <String>{};
    final candidates = _buildAddressCandidates(address, fullAddrData);

    for (final candidate in candidates.take(3)) {
      if (candidate.trim().isEmpty) continue;
      if (!tried.add(candidate)) continue;
      try {
        final roadResult = await _requestGeocoder(candidate, type: 'ROAD');
        if (roadResult != null && _isReliableGeocode(roadResult, candidate)) {
          return roadResult;
        }

        final parcelResult = await _requestGeocoder(candidate, type: 'PARCEL');
        if (parcelResult != null && _isReliableGeocode(parcelResult, candidate)) {
          return parcelResult;
        }
      } catch (_) {
        // 무시하고 다음 변형 주소 시도
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> _requestGeocoderByBuildingId(
    String buildingId,
    String baseAddress,
    String type,
  ) async {
    final uri = Uri.parse(VWorldApiConstants.geocoderBaseUrl).replace(queryParameters: {
      'service': 'address',
      'request': 'getCoord',
      'version': '2.0',
      'crs': VWorldApiConstants.srsName,
      'bldId': buildingId,
      'address': baseAddress,
      'type': type,
      'simple': 'true',
      'format': 'json',
      'key': VWorldApiConstants.geocoderApiKey,
    });

    final proxyUri = Uri.parse(VWorldApiConstants.vworldProxyUrl).replace(queryParameters: {
      'url': uri.toString(),
    });

    final response = await http.get(proxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () => throw Exception('Geocoder API 타임아웃'),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final responseBody = utf8.decode(response.bodyBytes);
    final data = json.decode(responseBody);
    final rawResult = data['response']?['result'];

    if (data['response']?['status'] != 'OK' || rawResult == null) {
      return null;
    }

    final result = rawResult is List
        ? (rawResult.isEmpty ? null : rawResult.first as Map<String, dynamic>?)
        : rawResult as Map<String, dynamic>?;

    if (result == null) {
      return null;
    }

    final point = result['point'];
    if (point == null) {
      return null;
    }

    return {
      'x': point['x'],
      'y': point['y'],
      'level': result['level']?.toString() ?? '9',
      'type': 'BLD',
      'structure': result['structure'],
      'text': result['text'],
      'address': result['text'] ?? '',
    };
  }

  /// 주소를 좌표로 변환 (Geocoder API)
  /// 
  /// [address] 도로명주소 또는 지번주소
  /// 
  /// 반환: {
  ///   'x': '경도',
  ///   'y': '위도',
  ///   'level': '정확도 레벨'
  /// }
  static Future<Map<String, dynamic>?> getLandInfoFromAddress(
    String address, {
    Map<String, String>? fullAddrData,
  }) async {
    try {
      
      final coordinates = await getCoordinatesFromAddress(
        address,
        fullAddrData: fullAddrData,
      );
      
      if (coordinates == null) {
        return null;
      }
      
      
      return {
        'coordinates': coordinates,
      };
    } catch (e) {
      return null;
    }
  }

  /// 테스트용 메서드
  static Future<void> testApis() async {
    
    // Geocoder API 테스트
    const testAddress = '경기도 성남시 분당구 중앙공원로 54';
    await getCoordinatesFromAddress(testAddress);
    
  }

  static Future<Map<String, dynamic>?> _requestGeocoder(String address, {required String type}) async {
    final uri = Uri.parse(VWorldApiConstants.geocoderBaseUrl).replace(queryParameters: {
      'service': 'address',
      'request': 'getCoord',
      'version': '2.0',
      'crs': VWorldApiConstants.srsName,
      'address': address,
      'refine': 'true',
      'simple': 'false',
      'format': 'json',
      'type': type,
      'key': VWorldApiConstants.geocoderApiKey,
    });

    final proxyUri = Uri.parse(VWorldApiConstants.vworldProxyUrl).replace(queryParameters: {
      'url': uri.toString(),
    });

    final response = await http.get(proxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () => throw Exception('Geocoder API 타임아웃'),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final responseBody = utf8.decode(response.bodyBytes);
    final data = json.decode(responseBody);
    final rawResult = data['response']?['result'];
    if (data['response']?['status'] != 'OK' || rawResult == null) {
      return null;
    }

    final result = rawResult is List
        ? (rawResult.isEmpty ? null : rawResult.first as Map<String, dynamic>?)
        : rawResult as Map<String, dynamic>?;
    if (result == null) {
      return null;
    }

    final point = result['point'];
    if (point == null) {
      return null;
    }

    return {
      'x': point['x'],
      'y': point['y'],
      'level': result['level']?.toString() ?? '9',
      'type': type,
      'structure': result['structure'],
      'text': result['text'],
      'address': address,
    };
  }

  static bool _isReliableGeocode(Map<String, dynamic> result, String inputAddress) {
    final levelValue = result['level']?.toString();
    final level = int.tryParse(levelValue ?? '');
    if (level != null) {
      final isReliableRange = level >= 2 && level <= 5;
      if (!isReliableRange) {
        return false;
      }
      return true;
    }

    final structure = result['structure'];
    if (structure is Map) {
      final level5 = structure['level5']?.toString().trim() ?? '';
      final detail = structure['detail']?.toString().trim() ?? '';
      if (level5.isNotEmpty || detail.isNotEmpty) {
        return true;
      }
    }

    final text = result['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return true;
    }

    return false;
  }

  static List<String> _buildAddressCandidates(
    String rawAddress,
    Map<String, String>? fullAddrData,
  ) {
    final candidates = LinkedHashSet<String>();

    String normalize(String value) =>
        value.replaceAll(RegExp(r'\s+'), ' ').trim();

    void addCandidate(String? value) {
      if (value == null) return;
      final normalized = normalize(value);
      if (normalized.isEmpty) return;
      candidates.add(normalized);

      final withoutParentheses =
          normalized.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      if (withoutParentheses.isNotEmpty) {
        candidates.add(normalize(withoutParentheses));
      }
    }

    addCandidate(rawAddress);
    addCandidate(_removeSiPrefix(rawAddress));

    if (fullAddrData != null && fullAddrData.isNotEmpty) {
      addCandidate(fullAddrData['roadAddr']);
      addCandidate(fullAddrData['roadAddrPart1']);
      addCandidate(fullAddrData['jibunAddr']);

      final si = fullAddrData['siNm']?.trim() ?? '';
      final sgg = fullAddrData['sggNm']?.trim() ?? '';
      final emd = fullAddrData['emdNm']?.trim() ?? '';
      final rn = fullAddrData['rn']?.trim() ?? '';

      final buldMain = fullAddrData['buldMnnm']?.trim() ?? '';
      final buldSub = fullAddrData['buldSlno']?.trim() ?? '';
      if (si.isNotEmpty && sgg.isNotEmpty && rn.isNotEmpty && buldMain.isNotEmpty) {
        final number =
            buldSub.isNotEmpty && buldSub != '0' ? '$buldMain-$buldSub' : buldMain;
        addCandidate('$si $sgg $rn $number');
        addCandidate('$sgg $rn $number');
        addCandidate('$rn $number');
      }

      final lnbrMain = fullAddrData['lnbrMnnm']?.trim() ?? '';
      final lnbrSub = fullAddrData['lnbrSlno']?.trim() ?? '';
      if (si.isNotEmpty && sgg.isNotEmpty && emd.isNotEmpty && lnbrMain.isNotEmpty) {
        final jibunNumber = lnbrSub.isNotEmpty && lnbrSub != '0'
            ? '$lnbrMain-$lnbrSub'
            : lnbrMain;
        addCandidate('$si $sgg $emd $jibunNumber');
        addCandidate('$sgg $emd $jibunNumber');
        addCandidate('$emd $jibunNumber');
      }
    }

    return candidates.toList();
  }

  static String? _removeSiPrefix(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final tokens = normalized.split(RegExp(r'\s+'));
    if (tokens.length <= 1) return null;
    final first = tokens.first;
    if (first.endsWith('시') || first.endsWith('도')) {
      return tokens.sublist(1).join(' ');
    }
    return null;
  }
}

