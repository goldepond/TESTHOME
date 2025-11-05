import 'dart:convert';
import 'package:flutter/services.dart';
// import 'package:property/constants/app_constants.dart'; // 미사용이므로 삭제
import 'package:property/utils/owner_parser.dart';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';

class RegisterService {
  static final RegisterService instance = RegisterService._init();
  
  RegisterService._init();

  // Access Token 발급 (CODEF 공식 방식)
  Future<String?> getCodefAccessToken() async {
    try {
      final url = Uri.parse('https://oauth.codef.io/oauth/token');
      const String clientId = CodefApiKeys.clientId;
      const String clientSecret = CodefApiKeys.clientSecret;
      final String basicAuth = 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}';

      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': basicAuth,
      };
      const body = 'grant_type=client_credentials&scope=read';

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('❌ CODEF 토큰 발급 오류: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ CODEF 토큰 발급 중 오류: $e');
      return null;
    }
  }

  // RSA 암호화 함수
  String rsaEncrypt(String plainText, String publicKeyPem) {
    final parser = RSAKeyParser();
    final RSAPublicKey publicKey = parser.parse(publicKeyPem) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: publicKey, encoding: RSAEncoding.PKCS1));
    final encrypted = encrypter.encrypt(plainText);
    return base64.encode(encrypted.bytes);
  }

  // 등기부등본 조회 (API/테스트 모드 전환 가능)
  Future<Map<String, dynamic>?> getRealEstateRegister({
    required String accessToken,
    required String phoneNo,
    required String password,
    required String sido,
    required String sigungu,
    required String roadName,
    required String buildingNumber,
    required String ePrepayNo,
    required String dong,
    required String ho,
    required String ePrepayPass,
    bool useTestcase = true, // 기본값: 테스트 모드 (false로 변경하면 실제 API 사용)
  }) async {
    
    if (useTestcase) {
      // ===================== 테스트 모드 =====================
      try {
        // 테스트 모드에서는 testcase.json 파일에서 데이터를 읽어옴
        final String response = await rootBundle.loadString('assets/testcase.json');
        final Map<String, dynamic> testData = json.decode(response);
        // resRegisterEntriesList 타입 안전 변환
        if (testData['data']?['resRegisterEntriesList'] is List) {
          testData['data']['resRegisterEntriesList'] =
              (testData['data']['resRegisterEntriesList'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        }
        return testData;
      } catch (e) {
        print('testcase.json 파일 읽기 중 오류: $e');
        // 파일 읽기 실패 시 기본 테스트 데이터 반환
        return {
          'result': {'code': 'CF-00000', 'extraMessage': '정상 처리되었습니다.'},
          'data': {
            'resRegisterEntriesList': [
              {
                'resRegistrationHisList': [
                  {
                    'resType': '갑구',
                    'resContentsList': [
                      {
                        'resType2': '2',
                        'resDetailList': [
                          {'resContents': '소유자: 홍길동'},
                          {'resContents': '등기원인: 2020년 7월 15일 매매'},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        };
      }
    } else {
      // ===================== 실제 API 연동 모드 =====================
      try {
        final url = Uri.parse('https://development.codef.io/v1/kr/public/ck/real-estate-register/status'); // CODEF 등기부등본 데모 API 엔드포인트
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        };
        // CODEF 공식 가이드에 맞는 파라미터로 요청
        const pemKey = '-----BEGIN PUBLIC KEY-----\n${CodefApiKeys.publicKey}\n-----END PUBLIC KEY-----';
        final encryptedPassword = rsaEncrypt(password, pemKey);
        
        // 비밀번호 길이 검증 (4~8자리)
        if (ePrepayPass.length < 4 || ePrepayPass.length > 8) {
          throw Exception('선불전자지급수단 비밀번호는 4~8자리로 입력해주세요.');
        }
        
        // ePrepayPass는 암호화하지 않고 원본 그대로 사용
        const Map<String, String> constantFields = {
          'organization': '0002',
          'inquiryType': '3',
          'realtyType': '1',
          'issueType': '1', // 열람
          'registerSummaryYN': '1',
          'jointMortgageJeonseYN': '0',
          'tradingYN': '0',
          'recordStatus': '0',
          'selectAddress': '0',
          'isIdentityViewYn': '0',
        };
        
        const List<Map<String, String>> identityList = [
          {'reqIdentity': ''}
        ];
        
        final dynamicFields = {
          'phoneNo': phoneNo.replaceAll('-', ''),
          'password': encryptedPassword,
          'addr_sido': sido,
          'addr_sigungu': sigungu,
          'addr_roadName': roadName,
          'addr_buildingNumber': buildingNumber,
          'dong': dong.isNotEmpty ? dong : null,
          'ho': ho.isNotEmpty ? ho : null,
          'ePrepayNo': ePrepayNo,
          'ePrepayPass': ePrepayPass, // 암호화하지 않은 비밀번호 사용
        };
        
        final bodyMap = {
          ...constantFields,
          ...dynamicFields,
          'identityList': identityList,
        };
        final body = json.encode(bodyMap);
        final response = await http.post(url, headers: headers, body: body);
        if (response.statusCode == 200) {
          final decodedBody = Uri.decodeFull(response.body);
          final Map<String, dynamic> data = json.decode(decodedBody);
          return data;
        } else {
          print('❌ CODEF API 오류: ${response.statusCode} ${response.body}');
          return {
            'result': {'code': 'CF-ERROR', 'extraMessage': 'CODEF API 오류: ${response.statusCode}'},
            'data': {},
          };
        }
      } catch (e) {
        print('❌ CODEF API 호출 중 오류: $e');
        return {
          'result': {'code': 'CF-ERROR', 'extraMessage': 'CODEF API 호출 중 오류: $e'},
          'data': {},
        };
      }
    }
  }

  /// 등기부등본 entry에서 소유자 이름 리스트를 추출한다.
  List<String> extractOwnerNamesFromEntry(Map<String, dynamic> entry) {
    return extractOwnerNames(entry);
  }

  // 등기부등본 요약 정보 생성
  Map<String, dynamic> generateRegisterSummary(Map<String, dynamic> registerData) {
    try {
      final entry = registerData['data']?['resRegisterEntriesList']?[0];
      if (entry == null) {
        return {'error': '등기부등본 데이터를 찾을 수 없습니다.'};
      }

      return {
        'docTitle': entry['resDocTitle'] ?? '등기사항증명서',
        'realty': entry['resRealty'] ?? '',
        'publishDate': entry['resPublishDate'] ?? '',
        'competentOffice': entry['commCompetentRegistryOffice'] ?? '',
        'ownerNames': extractOwnerNames(registerData),
        'registrationHistory': entry['resRegistrationHisList'] ?? [],
      };
    } catch (e) {
      print('등기부등본 요약 생성 중 오류: $e');
      return {'error': '등기부등본 요약 생성에 실패했습니다.'};
    }
  }
} 