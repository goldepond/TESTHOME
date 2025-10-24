import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../services/address_service.dart';
import '../services/register_service.dart';
import '../services/firebase_service.dart'; // FirebaseService import
import '../services/vworld_service.dart'; // VWorld API 서비스 추가
import '../utils/address_parser.dart';
import '../utils/owner_parser.dart';
import '../models/property.dart';

import '../utils/current_state_parser.dart';
import 'contract/contract_step_controller.dart'; // 단계별 계약서 작성 화면 임포트
import 'broker_list_page.dart'; // 공인중개사 찾기 페이지

class HomePage extends StatefulWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  String address = '';
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  String roadAddress = '';
  bool isLoading = false;
  List<String> roadAddressList = [];
  String detailAddress = '';
  String fullAddress = '';
  bool isRegisterLoading = false;
  Map<String, dynamic>? registerResult;
  String? registerError;
  String? ownerMismatchError;
  bool isSaving = false;

  // 부동산 목록
  List<Map<String, dynamic>> estates = [];

  // 페이지네이션 관련 변수
  int currentPage = 1;
  int totalCount = 0;

  // 주소 파싱 관련 변수
  Map<String, String> parsedAddress1st = {};
  Map<String, String> parsedDetail = {};
  
  // VWorld API 데이터
  Map<String, dynamic>? vworldCoordinates; // 좌표 정보
  Map<String, dynamic>? vworldLandInfo;    // 토지 특성 정보
  String? vworldError;                     // VWorld API 에러 메시지
  bool isVWorldLoading = false;            // VWorld API 로딩 상태

  @override
  void initState() {
    super.initState();
  }

  /// 공인중개사 찾기 페이지로 이동
  void _goToBrokerSearch() {
    // VWorld 좌표가 있는지 확인
    if (vworldCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치 정보를 먼저 조회해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final lat = double.tryParse(vworldCoordinates!['y'].toString());
    final lon = double.tryParse(vworldCoordinates!['x'].toString());
    
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('좌표 정보가 올바르지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 공인중개사 찾기 페이지로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrokerListPage(
          address: fullAddress,
          latitude: lat,
          longitude: lon,
        ),
      ),
    );
  }

  /// 등기부등본 데이터에서 소유자 이름을 추출하여 로그인 사용자와 비교한다.
  /// 일치 여부에 따라 ownerMismatchError를 갱신한다.
  void checkOwnerName(Map<String, dynamic> registerData) {
    try {
      final entry = registerData['data']?['resRegisterEntriesList']?[0];
      if (entry == null) return;

      final ownerNames = extractOwnerNames(entry);

      // 로그인한 사용자 이름과 비교 (하드코딩된 테스트 이름 사용)
      final userName = widget.userName;
      if (ownerNames.isNotEmpty && !ownerNames.contains(userName)) {
        setState(() {
          ownerMismatchError = '⚠️ 주의: 등기부등본의 소유자와 로그인한 사용자가 다릅니다.\n소유자: ${ownerNames.join(", ")}\n로그인 사용자: $userName';
        });
      } else if (ownerNames.isNotEmpty && ownerNames.contains(userName)) {
        setState(() {
          ownerMismatchError = '✅ 등기부등본의 소유자와 로그인한 사용자가 일치합니다.\n소유자: ${ownerNames.join(", ")}';
        });
      } else {
        setState(() {
          ownerMismatchError = '⚠️ 등기부등본에서 소유자 정보를 찾을 수 없습니다.';
        });
      }
    } catch (e) {
      print('소유자 이름 확인 중 오류: $e');
      setState(() {
        ownerMismatchError = '⚠️ 소유자 정보 확인 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 등기부등본 정보 DB 저장 함수
  Future<void> saveRegisterDataToDatabase() async {
    if (registerResult == null || fullAddress.isEmpty) {
      print('⚠️ 저장할 등기부등본 정보가 없습니다.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // 등기부등본 원본 JSON
      final rawJson = json.encode(registerResult);
      print('[DEBUG] registerResult: '
          '타입: ${registerResult.runtimeType}\n값: $registerResult');
      // 핵심 정보 추출
      final currentState = parseCurrentState(rawJson);
      print('[DEBUG] currentState: $currentState');
      final summaryMap = {
        "header": {
          "publishNo": currentState.header.publishNo,
          "publishDate": currentState.header.publishDate,
          "docTitle": currentState.header.docTitle,
          "realtyDesc": currentState.header.realtyDesc,
          "officeName": currentState.header.officeName,
          "issueNo": currentState.header.issueNo,
          "uniqueNo": currentState.header.uniqueNo,
        },
        "ownership": {
          "purpose": currentState.ownership.purpose,
          "receipt": currentState.ownership.receipt,
          "cause": currentState.ownership.cause,
          "ownerRaw": currentState.ownership.ownerRaw,
        },
        "areas": {
          "land": {
            "purpose": currentState.land.landPurpose,
            "area": currentState.land.landSize,
          },
          "building": {
            "structure": currentState.building.structure,
            "floors": currentState.building.floors
                .map((f) => {"floor": f.floorLabel, "area": f.area}).toList(),
            "areaTotal": currentState.building.areaTotal,
          }
        },
        "liens": currentState.liens
            .map((l) => {
                  "purpose": l.purpose,
                  "receipt": l.receipt,
                  "mainText": l.mainText,
                })
            .toList(),
      };

      // 등기부등본 데이터에서 상세 정보 추출
      final header = currentState.header;
      final ownership = currentState.ownership;
      final land = currentState.land;
      final building = currentState.building;
      final liens = currentState.liens;
      
      // 원본 JSON 데이터에서 추가 정보 추출
      final originalData = registerResult!['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      print('[DEBUG] originalData: 타입: ${originalData.runtimeType}, 값: $originalData');
      final entriesList = safeMapList(originalData['resRegisterEntriesList']);
      print('[DEBUG] entriesList: 타입: ${entriesList.runtimeType}, 길이: ${entriesList.length}, 값: $entriesList');
      final firstEntry = entriesList.isNotEmpty ? entriesList[0] : <String, dynamic>{};
      print('[DEBUG] firstEntry: 타입: ${firstEntry.runtimeType}, 값: $firstEntry');
      // 예시: 중첩 리스트도 safeMapList로 변환
      for (final entry in entriesList) {
        final hisList = safeMapList(entry['resRegistrationHisList']);
        for (final his in hisList) {
          final contentsList = safeMapList(his['resContentsList']);
          for (final contents in contentsList) {
            final detailList = safeMapList(contents['resDetailList']);
            // detailList 사용
          }
        }
      }
      
      // 소유자 정보 추출
      final ownerNames = extractOwnerNames(firstEntry);
      print('[DEBUG] ownerNames: $ownerNames');
      
      // 층별 면적 정보 변환
      final floorAreas = building.floors.map((f) => {
        "floor": f.floorLabel,
        "area": f.area,
      }).toList();
      print('[DEBUG] floorAreas: $floorAreas');
      
      // 권리사항 리스트 변환
      final liensList = liens.map((l) => "${l.purpose}: ${l.mainText}").toList();
      print('[DEBUG] liensList: $liensList');
      
      // 주소에서 건물명 추출
      final buildingName = fullAddress.contains('우성아파트') ? '우성아파트' : 
                          fullAddress.contains('아파트') ? '아파트' : '';
      
      // 층수 추출
      final floorMatch = RegExp(r'제(\d+)층').firstMatch(fullAddress);
      final floor = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;
      
      // 등기부등본 원본 데이터 구조화
      final result = registerResult?['result'] as Map<String, dynamic>?;
      print('[DEBUG] result: $result');
      final registerHeader = {
        'docTitle': originalData['resDocTitle']?.toString(),
        'realty': originalData['resRealty']?.toString(),
        'publishNo': originalData['resPublishNo']?.toString(),
        'publishDate': originalData['resPublishDate']?.toString(),
        'competentRegistryOffice': originalData['commCompetentRegistryOffice']?.toString(),
        'transactionId': result?['transactionId']?.toString(),
        'resultCode': result?['code']?.toString(),
        'resultMessage': result?['message']?.toString(),
      };
      print('[DEBUG] registerHeader: $registerHeader');
      
      // 소유권 정보 구조화
      final registerOwnership = {
        'currentOwners': ownerNames.map((name) => {
          'name': name,
          'ratio': '2분의 1', // 예시 데이터
          'address': fullAddress,
        }).toList(),
        'ownershipHistory': [], // 실제 데이터에서는 등기부등본에서 추출
        'registerMainContractor': ownerNames.isNotEmpty ? ownerNames.first : null, // 등기부등본의 대표 소유자
        'registerContractor': '임차인', // 등기부등본의 계약자
      };
      
      // 권리사항 정보 구조화
      final registerLiens = {
        'currentLiens': liensList,
        'totalAmount': liens.fold<String>('', (sum, lien) {
          final amountMatch = RegExp(r'금([0-9,]+)원').firstMatch(lien.mainText);
          return amountMatch != null ? amountMatch.group(1)! : sum;
        }),
        'lienHistory': liens.map((l) => {
          'purpose': l.purpose,
          'receipt': l.receipt,
          'mainText': l.mainText,
        }).toList(),
      };
      
      // 건물 정보 구조화
      final registerBuilding = {
        'structure': building.structure,
        'totalFloors': 16, // 예시 데이터
        'floor': floor,
        'area': building.areaTotal,
        'floorAreas': floorAreas,
        'buildingNumber': '제211동',
        'exclusiveArea': '132.60㎡', // 15층+16층 합계
      };
      
      // 토지 정보 구조화
      final registerLand = {
        'purpose': land.landPurpose,
        'area': land.landSize,
        'landNumber': '1',
        'landRatio': '107932.4분의 77.844',
      };
      
      final landNumber = registerLand['landNumber'];
      final landRatio = registerLand['landRatio'];
      final landUse = registerLand['purpose'];
      const landCategory = '대';
      
      // 사용자 정보 구조화 (향후 확장 가능)
      final userInfo = {
        'userId': widget.userName,
        'userName': widget.userName,
        'registrationDate': DateTime.now().toIso8601String(),
        'userType': 'registered', // registered, partner, admin 등
        'contactInfo': {
          'phone': null, // 향후 추가
          'email': null, // 향후 추가
        },
        'profile': {
          'displayName': widget.userName,
          'avatar': null, // 향후 추가
        }
      };
      
      final newProperty = Property(
        address: fullAddress,
        transactionType: '매매', // 또는 입력값
        price: 0, // 실제 입력값
        description: '',
        registerData: rawJson,
        registerSummary: json.encode(summaryMap),
        mainContractor: '', // 등기부등본 데이터는 수정하지 않음
        contractor: '', // 등기부등본 데이터는 수정하지 않음
        registeredBy: widget.userName, // 등록자 ID
        registeredByName: widget.userName, // 등록자 이름
        registeredByInfo: userInfo, // 등록자 상세 정보
        
        // 사용자 정보 (등기부등본과 완전히 분리)
        userMainContractor: widget.userName, // 사용자가 설정한 대표 계약자
        userContractor: widget.userName, // 사용자가 설정한 계약자
        userContactInfo: '연락처 정보', // 사용자 연락처
        userNotes: '사용자 메모', // 사용자 메모
        // 추가 부동산 정보
        buildingName: buildingName,
        buildingType: buildingName.contains('아파트') ? '아파트' : '기타',
        floor: floor,
        area: building.areaTotal.isNotEmpty ? double.tryParse(building.areaTotal.replaceAll('㎡', '').trim()) : null,
        structure: building.structure,
        landPurpose: land.landPurpose,
        landArea: land.landSize.isNotEmpty ? double.tryParse(land.landSize.replaceAll('㎡', '').trim()) : null,
        ownerName: ownerNames.isNotEmpty ? ownerNames.join(', ') : null,
        ownerInfo: ownership.ownerRaw,
        liens: liensList.isNotEmpty ? liensList : null,
        publishDate: header.publishDate,
        officeName: header.officeName,
        publishNo: header.publishNo,
        uniqueNo: header.uniqueNo,
        issueNo: header.issueNo,
        realtyDesc: header.realtyDesc,
        receiptDate: ownership.receipt,
        cause: ownership.cause,
        purpose: ownership.purpose,
        floorAreas: floorAreas.isNotEmpty ? floorAreas : null,
        // 시세 정보 (예시 데이터)
        estimatedValue: '2억2,500만원',
        marketValue: '2억2,500만원',
        aiConfidence: '92%',
        recentTransaction: '2억1,800만원',
        priceHistory: json.encode({
          'months': ['1월', '2월', '3월', '4월', '5월', '6월'],
          'prices': [21000, 21500, 21800, 22200, 22500, 22800]
        }),
        nearbyPrices: json.encode({
          'average': '2억2,000만원',
          'change': '+2.3%',
          'comparison': [
            {'type': '동일 단지', 'price': '2억2,300만원', 'difference': '+300만원'},
            {'type': '주변 아파트', 'price': '2억1,800만원', 'difference': '-200만원'},
            {'type': '지역 평균', 'price': '2억2,000만원', 'difference': '0만원'},
          ]
        }),
        status: '판매중',
        notes: '등기부등본 조회 완료 - 소유자 확인 필요',
        // 등기부등본 상세 정보
        docTitle: registerHeader['docTitle']?.toString(),
        competentRegistryOffice: registerHeader['competentRegistryOffice']?.toString(),
        transactionId: registerHeader['transactionId']?.toString(),
        resultCode: registerHeader['resultCode']?.toString(),
        resultMessage: registerHeader['resultMessage']?.toString(),
        ownershipHistory: safeMapList(registerOwnership['ownershipHistory']),
        currentOwners: safeMapList(registerOwnership['currentOwners']),
        ownershipRatio: '2분의 1',
        lienHistory: safeMapList(registerLiens['lienHistory']),
        currentLiens: safeMapList(registerLiens['currentLiens']),
        totalLienAmount: registerLiens['totalAmount']?.toString(),
        buildingNumber: registerBuilding['buildingNumber']?.toString(),
        exclusiveArea: registerBuilding['exclusiveArea']?.toString(),
        commonArea: null,
        parkingArea: null,
        buildingYear: '1991',
        buildingPermit: null,
        landNumber: registerLand['landNumber'],
        landRatio: registerLand['landRatio'],
        landUse: registerLand['purpose'],
        landCategory: '대',
        registerHeader: registerHeader,
        registerOwnership: registerOwnership,
        registerLiens: registerLiens,
        registerBuilding: registerBuilding,
        registerLand: registerLand,
        registerSummaryData: summaryMap,
      );
      
      // 디버그: 등록자 정보 확인
      print('🔍 [DEBUG] 등록자 정보 확인:');
      print('   - widget.userName: ${widget.userName}');
      print('   - mainContractor (등기부): ${newProperty.mainContractor}');
      print('   - contractor (등기부): ${newProperty.contractor}');
      print('   - userMainContractor (사용자): ${newProperty.userMainContractor}');
      print('   - userContractor (사용자): ${newProperty.userContractor}');
      print('   - registeredBy: ${newProperty.registeredBy}');
      print('   - registeredByName: ${newProperty.registeredByName}');
      print('   - registeredByInfo: ${newProperty.registeredByInfo}');
      
      print('🔍 [DEBUG] 사용자 정보 구조:');
      print('   - userInfo: $userInfo');
      
      print('[DEBUG] Property 생성 완료: $newProperty');

      // Firebase에 저장할 데이터 확인
      final propertyMap = newProperty.toMap();
      print('🔍 [DEBUG] Firebase 저장 데이터 확인:');
      print('   - mainContractor (등기부): ${propertyMap['mainContractor']}');
      print('   - contractor (등기부): ${propertyMap['contractor']}');
      print('   - userMainContractor (사용자): ${propertyMap['userMainContractor']}');
      print('   - userContractor (사용자): ${propertyMap['userContractor']}');
      print('   - registeredBy: ${propertyMap['registeredBy']}');
      print('   - registeredByName: ${propertyMap['registeredByName']}');
      print('   - registeredByInfo: ${propertyMap['registeredByInfo']}');
      print('   - 전체 필드 수: ${propertyMap.length}개');

      final docRef = await _firebaseService.addProperty(newProperty);

      if (docRef != null) {
        final propertyId = docRef.id;
        print('✅ [HomePage] 부동산 데이터 저장 성공 - ID: $propertyId');
        
        print('✅ [Firebase] 부동산 데이터 저장 성공 - ID: $propertyId');
        
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ContractStepController(
              initialData: summaryMap,
              userName: widget.userName,
              propertyId: propertyId,
              currentUserId: widget.userName, // userName을 currentUserId로 사용
            ),
          ),
        );
      } else {
        print('❌ [Firebase] 부동산 데이터 저장 실패');
      }
    } catch (e, stack) {
      print('❌ 저장 중 오류 발생: $e');
      print('❌ 스택트레이스: $stack');
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  // VWorld API 데이터 로드 (백그라운드)
  Future<void> _loadVWorldData(String address) async {
    setState(() {
      isVWorldLoading = true;
      vworldError = null;
      vworldCoordinates = null;
      vworldLandInfo = null;
    });
    
    try {
      print('🗺️ [HomePage] VWorld API 호출 시작: $address');
      
      final result = await VWorldService.getLandInfoFromAddress(address);
      
      if (result != null && mounted) {
        setState(() {
          vworldCoordinates = result['coordinates'];
          vworldLandInfo = result['landInfo'];
          isVWorldLoading = false;
          
          // 좌표는 있지만 토지 정보가 없는 경우
          if (vworldCoordinates != null && vworldLandInfo == null) {
            vworldError = '좌표 변환 성공, 토지 정보 조회 실패';
          }
        });
        
        print('✅ [HomePage] VWorld 데이터 로드 완료');
        print('   좌표: ${vworldCoordinates?['x']}, ${vworldCoordinates?['y']}');
        print('   토지용도: ${vworldLandInfo?['landUse']}');
      } else {
        if (mounted) {
          setState(() {
            isVWorldLoading = false;
            vworldError = 'VWorld API 호출 실패 (CORS 에러 또는 네트워크 오류)';
          });
        }
        print('⚠️ [HomePage] VWorld 데이터 로드 실패');
      }
    } catch (e) {
      print('❌ [HomePage] VWorld API 오류: $e');
      if (mounted) {
        setState(() {
          isVWorldLoading = false;
          vworldError = 'VWorld API 오류: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
        });
      }
    }
  }

  // 도로명 주소 검색 함수 (AddressService 사용)
  Future<void> searchRoadAddress(String keyword, {int page = 1}) async {
    setState(() {
      isLoading = true;
      roadAddress = '';
      roadAddressList = [];
      if (page == 1) currentPage = 1;
    });

    try {
      final result = await AddressService.instance.searchRoadAddress(keyword, page: page);
      
      setState(() {
        roadAddressList = result.addresses;
        totalCount = result.totalCount;
        currentPage = page;
        
        if (result.errorMessage != null) {
          roadAddress = result.errorMessage!;
        } else if (roadAddressList.length == 1) {
          roadAddress = roadAddressList[0];
        }
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 등기부등본 조회 함수 (RegisterService 사용)
  Future<void> searchRegister() async {
    if (fullAddress.isEmpty) {
      setState(() {
        registerError = '주소를 먼저 입력해주세요.';
      });
      return;
    }

    // 상세주소 필수 체크
    final dong = parsedDetail['dong'] ?? '';
    final ho = parsedDetail['ho'] ?? '';
    if (dong.isEmpty || ho.isEmpty) {
      setState(() {
        registerError = '동/호수를 입력해주세요.';
      });
      return;
    }

    setState(() {
      isRegisterLoading = true;
      registerError = null;
      registerResult = null;
      ownerMismatchError = null;
    });

    try {
      // 모드 설정 (테스트 모드 / 실제 API 모드)
      const bool useTestcase = true; // 테스트 모드 활성화 (false로 변경하면 실제 API 사용)
      
      print('==============================');
      print('🔍 [DEBUG] searchRegister() 함수 시작');
      print('🔍 [DEBUG] useTestcase 값: $useTestcase');
      print('🔍 [DEBUG] useTestcase 타입: ${useTestcase.runtimeType}');
      print('🔍 [DEBUG] !useTestcase 값: ${!useTestcase}');
      if (useTestcase) {
        print('✅ [TEST MODE] 테스트 케이스로 동작합니다. 실제 CODEF API 호출하지 않음!');
      } else {
        print('🚨 [REAL MODE] 실제 CODEF API 토큰 발급 및 호출!');
      }
      print('==============================');

      String? accessToken;
      
      print('🔍 [DEBUG] if (!useTestcase) 조건문 진입 전');
      print('🔍 [DEBUG] !useTestcase = ${!useTestcase}');
      
      if (!useTestcase) {
        print('🚨 [DEBUG] 실제 API 모드 진입 - 이 로그가 나오면 안 됩니다!');
        // 실제 API 모드: Access Token 발급
        accessToken = await RegisterService.instance.getCodefAccessToken();
        if (accessToken == null) {
          throw Exception('Access Token 발급 실패');
        }
        print('✅ CODEF Access Token 발급 성공');
      } else {
        print('✅ [DEBUG] 테스트 모드 유지 - accessToken은 null로 설정');
      }

      // 주소 파싱
      final dongValue = dong.replaceAll('동', '').replaceAll(' ', '');
      final hoValue = ho.replaceAll('호', '').replaceAll(' ', '');

      // 등기부등본 조회
      final result = await RegisterService.instance.getRealEstateRegister(
        accessToken: accessToken ?? '', // 테스트 모드에서는 빈 문자열, 실제 모드에서는 발급된 토큰
        phoneNo: TestConstants.tempPhoneNo,
        password: TestConstants.tempPassword,
        sido: parsedAddress1st['sido'] ?? '',
        sigungu: parsedAddress1st['sigungu'] ?? '',
        roadName: parsedAddress1st['roadName'] ?? '',
        buildingNumber: parsedAddress1st['buildingNumber'] ?? '',
        ePrepayNo: TestConstants.ePrepayNo,
        dong: dongValue,
        ho: hoValue,
        ePrepayPass: 'tack1171',
        useTestcase: useTestcase,
      );

      if (result != null) {
        setState(() {
          registerResult = result;
        });
        
        // VWorld API 호출 (백그라운드, 등기부등본 조회 성공 후)
        _loadVWorldData(fullAddress);
        
        // 소유자 이름 비교 실행
        checkOwnerName(result);
      } else {
        setState(() {
          registerError = '등기부등본 조회에 실패했습니다. 주소를 다시 확인해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        registerError = e.toString();
      });
    } finally {
      setState(() {
        isRegisterLoading = false;
      });
    }
  }



  @override
  void dispose() {
    _controller.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 상단 타이틀 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.kPrimary,
                      AppColors.kSecondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.kPrimary.withValues(alpha: 0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.home_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
              const Text(
                      '내 집 시세를 알아볼까요?',
                style: TextStyle(
                        fontSize: 32,
                  fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '주소를 입력하고 등기부등본을 조회하세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              // 검색 입력창
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.kPrimary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (val) => setState(() => address = val),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            searchRoadAddress(val.trim(), page: 1);
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '경기도 성남시 분당구 중앙공원로 54',
                          hintStyle: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.kTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          if (address.trim().isNotEmpty) {
                            searchRoadAddress(address.trim(), page: 1);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.kPrimary),
                  ),
                ),
              if (roadAddressList.isNotEmpty)
                RoadAddressList(
                  addresses: roadAddressList,
                  selectedAddress: roadAddress,
                  onSelect: (addr) async {
                    setState(() {
                      roadAddress = addr;
                      detailAddress = '';
                      fullAddress = addr;
                      _detailController.clear();
                      parsedAddress1st = AddressParser.parseAddress1st(addr);
                      parsedDetail = {};
                      // VWorld 데이터 초기화 (조회 버튼 누를 때 호출)
                      vworldCoordinates = null;
                      vworldLandInfo = null;
                      vworldError = null;
                      isVWorldLoading = false;
                    });
                  },
                ),
              if (totalCount > ApiConstants.pageSize)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (currentPage > 1)
                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            searchRoadAddress(
                              address.isNotEmpty ? address : _controller.text,
                              page: currentPage - 1,
                            );
                          },
                          child: const Text('이전'),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '페이지 $currentPage / ${((totalCount - 1) ~/ ApiConstants.pageSize) + 1}',
                        style: const TextStyle(
                          color: AppColors.kPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (currentPage * ApiConstants.pageSize < totalCount)
                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            searchRoadAddress(
                              address.isNotEmpty ? address : _controller.text,
                              page: currentPage + 1,
                            );
                          },
                          child: const Text('다음'),
                        ),
                      ),
                  ],
                ),
              if (roadAddress.isNotEmpty && !roadAddress.startsWith('API 오류') && !roadAddress.startsWith('검색 결과 없음'))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: DetailAddressInput(
                    controller: _detailController,
                    onChanged: (val) {
                      setState(() {
                        detailAddress = val;
                        parsedDetail = AddressParser.parseDetailAddress(val);
                        fullAddress = roadAddress + (val.trim().isNotEmpty ? ' ${val.trim()}' : '');
                        print('상세 주소 파싱 결과: $parsedDetail');
                      });
                    },
                  ),
                ),
              
              if (fullAddress.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.kPrimary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.kPrimary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                  child: Text(
                    '최종 주소: $fullAddress',
                          style: const TextStyle(
                            color: AppColors.kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isRegisterLoading ? null : searchRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          shadowColor: AppColors.kPrimary.withValues(alpha: 0.5),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        child: isRegisterLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('조회하기', textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
              ],
              
              // 등기부등본 조회 오류 표시
              if (registerError != null)
                ErrorMessage(
                  message: registerError!,
                  onRetry: () {
                    setState(() {
                      registerError = null;
                    });
                    searchRegister();
                  },
                ),
              
              // 소유자 불일치 경고
              if (ownerMismatchError != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha:0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ownerMismatchError!,
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              // 등기부등본 결과 표시 및 저장 버튼
              if (registerResult != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.kPrimary, AppColors.kSecondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.description,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '등기부등본 조회 결과',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 기본 정보
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoCard(
                              icon: Icons.location_on,
                              title: '부동산 주소',
                              content: fullAddress,
                              iconColor: Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              icon: Icons.person,
                              title: '계약자',
                              content: widget.userName,
                              iconColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      
                      // 상세 정보
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildRegisterSummaryFromSummaryJson(),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // VWorld 위치 및 토지 정보 (등기부등본 내부)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: VWorldDataWidget(
                          coordinates: vworldCoordinates,
                          landInfo: vworldLandInfo,
                          error: vworldError,
                          isLoading: isVWorldLoading,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 액션 버튼
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: isSaving ? null : _goToBrokerSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.kSecondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                shadowColor: AppColors.kSecondary.withValues(alpha: 0.5),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.business, size: 24),
                              label: const Text('공인중개사 찾기'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 정보 카드 위젯
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 등기부등본 카드 위젯 (VWorld 스타일과 동일)
  Widget _buildRegisterCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // 상세 정보 행 위젯
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 아래에 핵심 JSON만 예쁘게 출력하는 위젯 추가
  Widget _buildRegisterSummaryFromSummaryJson() {
    try {
      final rawJson = json.encode(registerResult);
      final currentState = parseCurrentState(rawJson);
      // 헤더 정보
      final header = currentState.header;
      // 소유자 정보
      final ownership = currentState.ownership;
      // 토지/건물 정보
      final land = currentState.land;
      final building = currentState.building;
      // 권리(저당 등)
      final liens = currentState.liens;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더(문서 정보)
          _buildRegisterCard(
            icon: Icons.description,
            title: '등기사항전부증명서',
            iconColor: Colors.blue,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('주소', header.realtyDesc),
                _buildDetailRow('발급일', header.publishDate),
                _buildDetailRow('발급기관', header.officeName),
                if (header.publishNo.isNotEmpty)
                  _buildDetailRow('발급번호', header.publishNo),
              ],
            ),
          ),
          // 소유자 정보
          _buildRegisterCard(
            icon: Icons.people,
            title: '소유자 정보',
            iconColor: Colors.green,
            content: Text(
              ownership.ownerRaw.isNotEmpty ? ownership.ownerRaw : '-',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
                height: 1.5,
              ),
            ),
          ),
          // 토지/건물 정보
          _buildRegisterCard(
            icon: Icons.home,
            title: '토지/건물 정보',
            iconColor: AppColors.kPrimary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('토지 지목', land.landPurpose),
                _buildDetailRow('토지 면적', land.landSize),
                _buildDetailRow('건물 구조', building.structure),
                _buildDetailRow('건물 전체면적', building.areaTotal),
                if (building.floors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '층별 면적',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...building.floors.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          f.floorLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2C3E50),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          f.area,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2C3E50),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
          // 권리(저당 등)
          if (liens.isNotEmpty)
            _buildRegisterCard(
              icon: Icons.gavel,
              title: '권리사항',
              iconColor: Colors.orange,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: liens.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('목적', l.purpose),
                      _buildDetailRow('내용', l.mainText),
                      _buildDetailRow('접수일', l.receipt),
                      if (liens.indexOf(l) != liens.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.grey[300]),
                        ),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
      );
    } catch (e) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.kLightBrown,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('핵심 정보 표시 중 오류: $e', style: const TextStyle(color: Colors.red)),
      );
    }
  }
}

/// 도로명 주소 검색 결과 리스트 위젯
class RoadAddressList extends StatelessWidget {
  final List<String> addresses;
  final String selectedAddress;
  final void Function(String) onSelect;
  const RoadAddressList({required this.addresses, required this.selectedAddress, required this.onSelect, super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalMargin = isMobile ? 16.0 : 40.0;
    final itemPadding = isMobile ? 14.0 : 12.0;
    final fontSize = isMobile ? 17.0 : 15.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.kPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '검색 결과 ${addresses.length}건',
                  style: const TextStyle(
                    color: AppColors.kPrimary,
              fontWeight: FontWeight.bold,
                    fontSize: 16,
            ),
          ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...addresses.map((addr) => Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(addr.trim()),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: EdgeInsets.symmetric(vertical: itemPadding, horizontal: 18),
                decoration: BoxDecoration(
                  color: selectedAddress.trim() == addr.trim()
                      ? AppColors.kPrimary
                      : Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: selectedAddress.trim() == addr.trim()
                        ? AppColors.kPrimary
                        : Colors.grey[300]!,
                    width: 1,
                  ),
                  boxShadow: selectedAddress.trim() == addr.trim()
                      ? [
                          BoxShadow(
                            color: AppColors.kPrimary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    if (selectedAddress.trim() == addr.trim())
                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    if (selectedAddress.trim() == addr.trim())
                      const SizedBox(width: 12),
                    Expanded(
                child: Text(
                  addr,
                  style: TextStyle(
                          color: selectedAddress.trim() == addr.trim()
                              ? Colors.white
                              : AppColors.kTextPrimary,
                    fontWeight: selectedAddress.trim() == addr.trim()
                        ? FontWeight.bold
                              : FontWeight.w500,
                    fontSize: fontSize,
                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

/// 상세 주소 입력 위젯
class DetailAddressInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  const DetailAddressInput({required this.controller, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.edit_location, color: AppColors.kPrimary, size: 20),
                const SizedBox(width: 8),
        const Text(
          '상세 주소 입력',
          style: TextStyle(
                    color: AppColors.kPrimary,
            fontWeight: FontWeight.bold,
                    fontSize: 16,
          ),
        ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '상세 주소를 입력하세요 (예: 211동 1506호)',
            hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
            ),
              filled: true,
              fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.kPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: const Icon(Icons.home_work, color: AppColors.kPrimary),
          ),
        ),
      ],
      ),
    );
  }
}

/// 에러 메시지 표시 위젯
class ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorMessage({required this.message, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.kError.withValues(alpha: 0.1),
            AppColors.kError.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.kError.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.kError,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
            '등기부등본 조회 실패',
            style: TextStyle(
                    color: AppColors.kError,
              fontWeight: FontWeight.bold,
                    fontSize: 18,
            ),
          ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[800],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
              onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kError,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// VWorld 데이터 표시 위젯
class VWorldDataWidget extends StatelessWidget {
  final Map<String, dynamic>? coordinates;
  final Map<String, dynamic>? landInfo;
  final String? error;
  final bool isLoading;
  
  const VWorldDataWidget({
    this.coordinates,
    this.landInfo,
    this.error,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 로딩 중이거나, 데이터가 있거나, 에러가 있으면 표시
    if (!isLoading && coordinates == null && landInfo == null && error == null) {
      return const SizedBox.shrink();
    }

    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Row(
                  children: [
                    Icon(
                      isLoading ? Icons.hourglass_empty : (error != null ? Icons.warning_rounded : Icons.location_on),
                      color: isLoading ? Colors.grey : (error != null ? Colors.orange : AppColors.kPrimary),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLoading ? '위치 정보 조회 중...' : (error != null ? '위치 정보 조회 실패' : '위치 및 토지 정보'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isLoading ? Colors.grey : (error != null ? Colors.orange : AppColors.kPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 로딩 중
                if (isLoading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
                
                // 에러 메시지
                if (error != null && !isLoading) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 정보 카드들
                if (!isLoading && coordinates != null) ...[
                  // 좌표 정보
                  _buildInfoCard(
                    icon: Icons.pin_drop,
                    title: '좌표 정보',
                    content: '경도: ${coordinates!['x']}\n위도: ${coordinates!['y']}\n정확도: Level ${coordinates!['level'] ?? '-'}',
                    iconColor: Colors.blue,
                  ),
                  
                  // 토지 정보
                  if (landInfo != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.landscape,
                      title: '토지 정보',
                      content: _buildLandInfoContent(),
                      iconColor: Colors.green,
                    ),
                    
                    // 추가 상세 정보
                    if (_hasAdditionalInfo()) ...[
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.info_outline,
                        title: '상세 정보',
                        content: _buildAdditionalInfoContent(),
                        iconColor: Colors.orange,
                      ),
                    ],
                  ],
                  
                  // 토지 정보 없음 안내
                  if (landInfo != null && !_hasLandData()) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '해당 위치의 토지 정보가 없습니다.\n(아파트 등 집합건물일 수 있습니다)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[800],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            );
  }

  // 등기부등본 스타일의 정보 카드
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 토지 정보 내용 구성
  String _buildLandInfoContent() {
    final parts = <String>[];
    
    if (landInfo!['landUse']?.toString().isNotEmpty == true) {
      parts.add('지목: ${landInfo!['landUse']}');
    }
    if (landInfo!['landArea']?.toString().isNotEmpty == true) {
      parts.add('면적: ${landInfo!['landArea']}㎡');
    }
    if (landInfo!['pnu']?.toString().isNotEmpty == true) {
      parts.add('PNU: ${landInfo!['pnu']}');
    }
    if (landInfo!['address']?.toString().isNotEmpty == true) {
      parts.add('지번: ${landInfo!['address']}');
    }
    
    return parts.isEmpty ? '-' : parts.join('\n');
  }

  // 추가 상세 정보 내용 구성
  String _buildAdditionalInfoContent() {
    final parts = <String>[];
    
    if (landInfo!['prposArea1Nm']?.toString().isNotEmpty == true) {
      parts.add('용도지역1: ${landInfo!['prposArea1Nm']}');
    }
    if (landInfo!['prposArea2Nm']?.toString().isNotEmpty == true) {
      parts.add('용도지역2: ${landInfo!['prposArea2Nm']}');
    }
    if (landInfo!['ladUseSittnNm']?.toString().isNotEmpty == true) {
      parts.add('토지이용상황: ${landInfo!['ladUseSittnNm']}');
    }
    if (landInfo!['tpgrphHgCodeNm']?.toString().isNotEmpty == true) {
      parts.add('지형높이: ${landInfo!['tpgrphHgCodeNm']}');
    }
    if (landInfo!['tpgrphFrmCodeNm']?.toString().isNotEmpty == true) {
      parts.add('지형형상: ${landInfo!['tpgrphFrmCodeNm']}');
    }
    
    return parts.isEmpty ? '-' : parts.join('\n');
  }

  // 추가 정보가 있는지 확인
  bool _hasAdditionalInfo() {
    return (landInfo!['prposArea1Nm']?.toString().isNotEmpty == true) ||
           (landInfo!['prposArea2Nm']?.toString().isNotEmpty == true) ||
           (landInfo!['ladUseSittnNm']?.toString().isNotEmpty == true) ||
           (landInfo!['tpgrphHgCodeNm']?.toString().isNotEmpty == true) ||
           (landInfo!['tpgrphFrmCodeNm']?.toString().isNotEmpty == true);
  }

  // 기본 토지 데이터가 있는지 확인
  bool _hasLandData() {
    return (landInfo!['landUse']?.toString().isNotEmpty == true) ||
           (landInfo!['landArea']?.toString().isNotEmpty == true) ||
           (landInfo!['pnu']?.toString().isNotEmpty == true);
  }
}

