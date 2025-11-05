import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

// 도로명 주소 검색 결과 모델
class AddressSearchResult {
  final List<Map<String,String>> fullData; // _JsonMap
  final List<String> addresses;
  final int totalCount;
  final String? errorMessage;

  AddressSearchResult({
    required this.fullData,
    required this.addresses,
    required this.totalCount,
    this.errorMessage,
  });
}

class AddressService {
  // ignore: unused_field
  static const int _coolDown = 3; // Reserved for cooldown, do not remove
  static DateTime lastCalledTime = DateTime.utc(2000); // Reserved
  static final AddressService instance = AddressService._init();
  AddressService._init();

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

  // EPSG5179(UTM-K GRS80), VWORLD 는 EPSG 4326

  // http://125.60.46.141/addrlink/qna/qnaDetail.do?currentPage=3&keyword=%EC%A2%8C%ED%91%9C%EC%A0%9C%EA%B3%B5&searchType=subjectCn&noticeType=QNA&noticeTypeTmp=QNA&noticeMgtSn=128567&bulletinRefSn=128567&page=
} 