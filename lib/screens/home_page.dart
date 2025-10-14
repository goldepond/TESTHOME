import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../services/address_service.dart';
import '../services/register_service.dart';
import '../services/firebase_service.dart'; // FirebaseService import
import '../utils/address_parser.dart';
import '../utils/owner_parser.dart';
import '../models/property.dart';

import '../utils/current_state_parser.dart';
import 'contract/contract_step_controller.dart'; // 단계별 계약서 작성 화면 임포트

class HomePage extends StatefulWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  late Stream<List<Property>> _propertyStream;
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
  String? saveMessage;

  // 부동산 목록
  List<Map<String, dynamic>> estates = [];

  // 페이지네이션 관련 변수
  int currentPage = 1;
  int totalCount = 0;

  // 주소 파싱 관련 변수
  Map<String, String> parsedAddress1st = {};
  Map<String, String> parsedDetail = {};

  @override
  void initState() {
    super.initState();
    _propertyStream = _firebaseService.getProperties(widget.userName);
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
      setState(() {
        saveMessage = '저장할 등기부등본 정보가 없습니다.';
      });
      return;
    }

    setState(() {
      isSaving = true;
      saveMessage = null;
    });

    try {
      // 등기부등본 원본 JSON
      final rawJson = json.encode(registerResult);
      print('[DEBUG] registerResult: '
          '타입: ${registerResult.runtimeType}\n값: ${registerResult}');
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
      print('[DEBUG] originalData: 타입: ${originalData.runtimeType}, 값: ${originalData}');
      final entriesList = safeMapList(originalData['resRegisterEntriesList']);
      print('[DEBUG] entriesList: 타입: ${entriesList.runtimeType}, 길이: ${entriesList.length}, 값: ${entriesList}');
      final firstEntry = entriesList.isNotEmpty ? entriesList[0] : <String, dynamic>{};
      print('[DEBUG] firstEntry: 타입: ${firstEntry.runtimeType}, 값: ${firstEntry}');
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
      final landCategory = '대';
      
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
        
        setState(() {
          saveMessage = '✅ 부동산 데이터가 성공적으로 저장되었습니다!\n문서 ID: $propertyId\n저장된 필드 수: ${newProperty.toMap().length}개\n등기부등본 데이터 포함: ${rawJson.length}자';
        });
        
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
        setState(() {
          saveMessage = '❌ 부동산 데이터 저장에 실패했습니다.';
        });
      }
    } catch (e, stack) {
      print('❌ 저장 중 오류 발생: $e');
      print('❌ 스택트레이스: $stack');
      setState(() {
        saveMessage = '❌ 저장 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        isSaving = false;
      });
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
      saveMessage = null; // 새로운 조회 시 저장 메시지 초기화
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
      appBar: AppBar(
        backgroundColor: AppColors.kBrown,
        foregroundColor: Colors.white,
        title: const Text(
          '내집팔기',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                '먼저, 내 집 시세를 알아볼까요?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kBrown,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.kLightBrown,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
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
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '서울시 강남구 역삼동 123-45',
                          hintStyle: TextStyle(
                            fontSize: 28,
                            color: Color.fromARGB(64, 141, 103, 72),
                            letterSpacing: 4,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 28,
                          color: AppColors.kDarkBrown,
                          letterSpacing: 4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        icon: const Icon(Icons.search, color: AppColors.kBrown),
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
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              if (roadAddressList.isNotEmpty)
                RoadAddressList(
                  addresses: roadAddressList,
                  selectedAddress: roadAddress,
                  onSelect: (addr) {
                    setState(() {
                      roadAddress = addr;
                      detailAddress = '';
                      fullAddress = addr;
                      _detailController.clear();
                      parsedAddress1st = AddressParser.parseAddress1st(addr);
                      parsedDetail = {};
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
                        style: const TextStyle(color: AppColors.kBrown),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Text(
                    '최종 주소: $fullAddress',
                    style: TextStyle(color: AppColors.kBrown, fontWeight: FontWeight.bold, fontSize: 16),
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
                          backgroundColor: AppColors.kBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                            : const Text('등기부등본 조회하기', textAlign: TextAlign.center),
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
                        color: Colors.orange.withOpacity(0.1),
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
                        color: Colors.black.withOpacity(0.08),
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
                            colors: [AppColors.kBrown, AppColors.kBrown.withOpacity(0.8)],
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
                                color: Colors.white.withOpacity(0.2),
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
                              content: widget.userName ?? '',
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
                      
                      // 액션 버튼
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: isSaving ? null : saveRegisterDataToDatabase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.kBrown,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
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
                                  : const Icon(Icons.assessment, size: 24),
                              label: const Text('판매 등록 심사'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              // 저장 결과 메시지
              if (saveMessage != null)
                ResultMessage(message: saveMessage!),
              
              const SizedBox(height: 30),
              StreamBuilder<List<Property>>(
                stream: _propertyStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('오류: ${snapshot.error}'));
                  }
                  final properties = snapshot.data ?? [];
                  if (properties.isEmpty) {
                    return const Center(child: Text('등록된 매물이 없습니다.'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: properties.length,
                    itemBuilder: (context, index) {
                      final property = properties[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(property.address),
                          subtitle: Text('${property.transactionType} - ${property.price}'),
                          trailing: Text(property.contractStatus),
                        ),
                      );
                    },
                  );
                },
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
              color: iconColor.withOpacity(0.1),
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
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '등기사항전부증명서',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('주소', header.realtyDesc),
                  _buildDetailRow('발급일', header.publishDate),
                  _buildDetailRow('발급기관', header.officeName),
                  if (header.publishNo.isNotEmpty)
                    _buildDetailRow('발급번호', header.publishNo),
                ],
              ),
            ),
          ),
          // 소유자 정보
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '소유자 정보',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ownership.ownerRaw.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[100]!, width: 1),
                      ),
                      child: Text(
                        ownership.ownerRaw,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildDetailRow('목적', ownership.purpose),
                  _buildDetailRow('원인', ownership.cause),
                  _buildDetailRow('접수일', ownership.receipt),
                ],
              ),
            ),
          ),
          // 토지/건물 정보
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[200]!, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.home,
                        color: Colors.purple[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '토지/건물 정보',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('토지 지목', land.landPurpose),
                  _buildDetailRow('토지 면적', land.landSize),
                  _buildDetailRow('건물 구조', building.structure),
                  _buildDetailRow('건물 전체면적', building.areaTotal),
                  if (building.floors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[100]!, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '층별 면적',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.purple[600],
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 권리(저당 등)
          if (liens.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gavel,
                          color: Colors.red[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '권리사항',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...liens.map((l) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[100]!, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('목적', l.purpose),
                          _buildDetailRow('내용', l.mainText),
                          _buildDetailRow('접수일', l.receipt),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
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
    final itemPadding = isMobile ? 14.0 : 10.0;
    final fontSize = isMobile ? 17.0 : 15.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '도로명 주소 검색 결과',
            style: TextStyle(
              color: AppColors.kBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
                      ? AppColors.kBrown.withValues(alpha: 38)
                      : Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  addr,
                  style: TextStyle(
                    color: AppColors.kBrown,
                    fontWeight: selectedAddress.trim() == addr.trim()
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: fontSize,
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상세 주소 입력',
          style: TextStyle(
            color: AppColors.kBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: '상세 주소를 입력하세요 (예: 제211동 제15,16층 제1506호)',
            hintStyle: TextStyle(
              color: Color.fromARGB(128, 107, 79, 51),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            '등기부등본 조회 실패',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 결과 메시지(저장 등) 표시 위젯
class ResultMessage extends StatelessWidget {
  final String message;
  const ResultMessage({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: message.startsWith('✅') ? AppColors.kLightBrown : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: message.startsWith('✅') ? AppColors.kBrown : Colors.red[900],
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}