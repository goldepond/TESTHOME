import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

// 도로명 주소 검색 결과 모델
class AddressSearchResult {
  final List<String> addresses;
  final int totalCount;
  final String? errorMessage;

  AddressSearchResult({
    required this.addresses,
    required this.totalCount,
    this.errorMessage,
  });
}

class AddressService {
  static final AddressService instance = AddressService._init();
  
  AddressService._init();

  // 도로명 주소 검색
  Future<AddressSearchResult> searchRoadAddress(String keyword, {int page = 1}) async {
    if (keyword.trim().length < 4) {
      return AddressSearchResult(
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
      
      print('주소 검색 API 요청: $url');
      
      final response = await http.get(url).timeout(
        Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          throw TimeoutException('주소 검색 시간이 초과되었습니다.');
        },
      );
      
      print('주소 검색 API 응답 상태: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final errorCode = data['results']['common']['errorCode'];
        final errorMsg = data['results']['common']['errorMessage'];
        
        if (errorCode != '0') {
          return AddressSearchResult(
            addresses: [],
            totalCount: 0,
            errorMessage: 'API 오류: $errorMsg',
          );
        }
        
        try {
          final juso = data['results']['juso'];
          final total = int.tryParse(data['results']['common']['totalCount'] ?? '0') ?? 0;
          
          if (juso != null && juso.length > 0) {
            final addressList = (juso as List)
                .map((e) => e['roadAddr']?.toString() ?? '')
                .where((e) => e.isNotEmpty)
                .toList();
            
            return AddressSearchResult(
              addresses: addressList,
              totalCount: total,
            );
          } else {
            return AddressSearchResult(
              addresses: [],
              totalCount: 0,
              errorMessage: '검색 결과 없음',
            );
          }
        } catch (e) {
          print('주소 데이터 파싱 오류: $e');
          return AddressSearchResult(
            addresses: [],
            totalCount: 0,
            errorMessage: '검색 결과 처리 중 오류가 발생했습니다.',
          );
        }
      } else {
        print('API 응답 오류: ${response.statusCode}');
        return AddressSearchResult(
          addresses: [],
          totalCount: 0,
          errorMessage: 'API 서버 오류 (${response.statusCode})',
        );
      }
    } on TimeoutException {
      return AddressSearchResult(
        addresses: [],
        totalCount: 0,
        errorMessage: '주소 검색 시간이 초과되었습니다.',
      );
    } catch (e) {
      print('주소 검색 중 예외 발생: $e');
      return AddressSearchResult(
        addresses: [],
        totalCount: 0,
        errorMessage: '주소 검색 중 오류가 발생했습니다: $e',
      );
    }
  }

  // 특정 주소의 상세 정보 조회
  Future<Map<String, dynamic>?> getAddressDetail(String roadAddress) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseJusoUrl}'
        '?currentPage=1'
        '&countPerPage=1'
        '&keyword=${Uri.encodeComponent(roadAddress.trim())}'
        '&confmKey=${ApiConstants.registerApiKey}'
        '&resultType=json',
      );

      final response = await http.get(url).timeout(
        Duration(seconds: ApiConstants.requestTimeoutSeconds),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final juso = data['results']['juso'];
        if (juso != null && juso.isNotEmpty) {
          return juso[0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('주소 상세 정보 조회 중 오류: $e');
      return null;
    }
  }
} 