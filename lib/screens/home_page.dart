import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/address_service.dart';
import 'package:property/api_request/firebase_service.dart'; // FirebaseService import
import 'package:property/api_request/vworld_service.dart'; // VWorld API 서비스 추가
import 'package:property/utils/address_utils.dart';
import 'package:property/utils/owner_parser.dart';
import 'package:property/models/property.dart';

import 'package:property/utils/current_state_parser.dart';
import 'broker_list_page.dart'; // 공인중개사 찾기 페이지
import 'package:property/widgets/loading_overlay.dart'; // 공통 로딩 오버레이
// 로그인 페이지
import 'package:property/api_request/apt_info_service.dart'; // 단지코드 조회

class HomePage extends StatefulWidget {
  final String userId;
  final String userName;
  const HomePage({super.key, required this.userId, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  String queryAddress = '';
  bool isSearchingRoadAddr = false;

  List<Map<String,String>> fullAddrAPIDataList = [];
  List<String> roadAddressList = [];

  Map<String,String> selectedFullAddrAPIData = {};
  String selectedRoadAddress = '';
  String selectedDetailAddress = '';
  String selectedFullAddress = '';

  bool isRegisterLoading = false;
  
  // 주소 검색 디바운싱 관련
  Timer? _addressSearchDebounceTimer;
  String? _lastSearchKeyword;
  Map<String, dynamic>? registerResult;
  String? registerError;
  String? ownerMismatchError;
  bool isSaving = false;
  bool hasAttemptedSearch = false; // 조회 시도 여부

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
  String? vworldError;                     // VWorld API 에러 메시지
  bool isVWorldLoading = false;            // VWorld API 로딩 상태
  
  // 단지코드 관련 정보
  Map<String, dynamic>? aptInfo;           // 아파트 단지 정보
  String? kaptCode;                        // 단지코드
  bool isLoadingAptInfo = false;            // 단지코드 조회 중

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
          address: selectedFullAddress,
          latitude: lat,
          longitude: lon,
          userName: widget.userName, // 로그인 사용자 정보 전달
          userId: widget.userId,
          propertyArea: null, // 토지 면적은 더 이상 사용하지 않음
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
      setState(() {
        ownerMismatchError = '⚠️ 소유자 정보 확인 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 등기부등본 정보 DB 저장 함수
  Future<void> saveRegisterDataToDatabase() async {
    if (registerResult == null || selectedFullAddress.isEmpty) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // 등기부등본 원본 JSON
      final rawJson = json.encode(registerResult);
      // 핵심 정보 추출
      final currentState = parseCurrentState(rawJson);
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
      final entriesList = safeMapList(originalData['resRegisterEntriesList']);
      final firstEntry = entriesList.isNotEmpty ? entriesList[0] : <String, dynamic>{};
      // 예시: 중첩 리스트도 safeMapList로 변환
      for (final entry in entriesList) {
        final hisList = safeMapList(entry['resRegistrationHisList']);
        for (final his in hisList) {
          final contentsList = safeMapList(his['resContentsList']);
          for (final contents in contentsList) {
            // resDetailList 처리 (필요시 추가)
            safeMapList(contents['resDetailList']);
          }
        }
      }
      
      // 소유자 정보 추출
      final ownerNames = extractOwnerNames(firstEntry);
      
      // 층별 면적 정보 변환
      final floorAreas = building.floors.map((f) => {
        "floor": f.floorLabel,
        "area": f.area,
      }).toList();
      
      // 권리사항 리스트 변환
      final liensList = liens.map((l) => "${l.purpose}: ${l.mainText}").toList();
      
      // 주소에서 건물명 추출
      final buildingName = selectedFullAddress.contains('우성아파트') ? '우성아파트' :
                          selectedFullAddress.contains('아파트') ? '아파트' : '';
      
      // 층수 추출
      final floorMatch = RegExp(r'제(\d+)층').firstMatch(selectedFullAddress);
      final floor = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;
      
      // 등기부등본 원본 데이터 구조화
      final result = registerResult?['result'] as Map<String, dynamic>?;
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
      
      // 소유권 정보 구조화
      final registerOwnership = {
        'currentOwners': ownerNames.map((name) => {
          'name': name,
          'ratio': '2분의 1', // 예시 데이터
          'address': selectedFullAddress,
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
      
      final userInfo = {
        'userId': widget.userName,
        'userName': widget.userName,
        'registrationDate': DateTime.now().toIso8601String(),
        'userType': 'registered',
      };
      
      final newProperty = Property(
        fullAddrAPIData: selectedFullAddrAPIData,
        address: selectedFullAddress,
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
      
      final docRef = await _firebaseService.addProperty(newProperty);

      if (docRef != null) {
        if (!mounted) return;
        // 부동산 데이터 저장 완료
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('부동산 정보가 저장되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // 저장 실패 시 무시
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  // (제거됨) 내 부동산에 추가 기능

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
      if (mounted) {
        setState(() {
          isVWorldLoading = false;
          vworldError = 'VWorld API 오류: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
        });
      }
    }
  }

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
      selectedRoadAddress = '';
      roadAddressList = [];
      if (page == 1) currentPage = 1;
    });

    try {
      final AddressSearchResult result = await AddressService().searchRoadAddress(keyword, page: page);
      
      setState(() {
        fullAddrAPIDataList = result.fullData;
        roadAddressList = result.addresses;
        totalCount = result.totalCount;
        currentPage = page;
        
        if (result.errorMessage != null) {
          selectedRoadAddress = result.errorMessage!;
        } else if (roadAddressList.isNotEmpty) {
          // 첫 번째 결과를 자동으로 선택
          final firstAddr = roadAddressList[0];
          final firstData = fullAddrAPIDataList[0];
          
          // onSelect 로직 실행
          selectedFullAddrAPIData = firstData;
          selectedRoadAddress = firstAddr;
          selectedDetailAddress = '';
          selectedFullAddress = firstAddr;
          _detailController.clear();
          parsedAddress1st = AddressUtils.parseAddress1st(firstAddr);
          parsedDetail = {};
          
          // 상태 초기화
          hasAttemptedSearch = false;
          registerResult = null;
          registerError = null;
          ownerMismatchError = null;
          vworldCoordinates = null;
          vworldError = null;
          isVWorldLoading = false;
          
          // 주소 자동 선택 시 단지코드 조회 (주소 검색 API 데이터 포함)
          _loadAptInfoFromAddress(firstAddr, fullAddrAPIData: firstData);
        }
      });
    } finally {
      setState(() {
        isSearchingRoadAddr = false;
      });
    }
  }
  
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
            final extractedKaptCodeFromResult = aptInfoResult['kaptCode']?.toString();
            
            setState(() {
              aptInfo = aptInfoResult;
              kaptCode = extractedKaptCodeFromResult;
            });
            
          } else {
            // API 호출 실패 시
            setState(() {
              aptInfo = null;
              kaptCode = null;
            });
          }
        }
      } else {
        // 단지코드 추출 실패 (공동주택이 아니거나 매칭되지 않음)
        if (mounted) {
          setState(() {
            aptInfo = null;
            kaptCode = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aptInfo = null;
          kaptCode = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAptInfo = false;
        });
      }
    }
  }

  // 등기부등본 조회 함수 (RegisterService 사용)
  Future<void> searchRegister() async {
    // ========================================
    // 🔴 등기부등본 기능 비활성화 플래그
    // ========================================
    const bool isRegisterFeatureEnabled = false; // true로 변경하면 기능 활성화
    
    if (selectedFullAddress.isEmpty) {
      setState(() {
        registerError = '주소를 먼저 입력해주세요.';
      });
      return;
    }

    // 상세주소 체크 (선택적) - 기능 활성화 시 사용
    // final dong = parsedDetail['dong'] ?? '';
    // final ho = parsedDetail['ho'] ?? '';
    
    setState(() {
      isRegisterLoading = true;
      registerError = null;
      registerResult = null;
      ownerMismatchError = null;
      hasAttemptedSearch = true; // 조회 시도 표시
    });

    try {
      // VWorld API는 항상 호출 (로그인 여부 무관)
      _loadVWorldData(selectedFullAddress);
      
      // 단지 정보도 조회하기 버튼 클릭 시 자동으로 로드
      if (selectedFullAddress.isNotEmpty) {
        _loadAptInfoFromAddress(
          selectedFullAddress,
          fullAddrAPIData: selectedFullAddrAPIData.isNotEmpty ? selectedFullAddrAPIData : null,
        );
      }
      
      // ========================================
      // 🔴 등기부등본 기능 비활성화 처리
      // ========================================
      if (!isRegisterFeatureEnabled) {
        setState(() {
          isRegisterLoading = false;
          registerError = null;
          registerResult = null;
        });
        return;
      }
      
      // 기능 활성화 시에만 실행되는 코드 (현재는 데드 코드)
      // 로그인하지 않은 경우: 등기부등본 API 호출하지 않음
      // if (widget.userName.isEmpty) {
      //   setState(() {
      //     isRegisterLoading = false;
      //     registerError = null;
      //   });
      //   return;
      // }
      
      // 등기부등본 조회 코드 (기능 활성화 시 사용)
      // const bool useTestcase = true; // 테스트 모드 활성화 (false로 변경하면 실제 API 사용)
      // String? accessToken;
      // final dongValue = dong.replaceAll('동', '').replaceAll(' ', '');
      // final hoValue = ho.replaceAll('호', '').replaceAll(' ', '');
      // final result = await RegisterService.instance.getRealEstateRegister(
      //   accessToken: accessToken ?? '',
      //   phoneNo: TestConstants.tempPhoneNo,
      //   password: TestConstants.tempPassword,
      //   sido: parsedAddress1st['sido'] ?? '',
      //   sigungu: parsedAddress1st['sigungu'] ?? '',
      //   roadName: parsedAddress1st['roadName'] ?? '',
      //   buildingNumber: parsedAddress1st['buildingNumber'] ?? '',
      //   ePrepayNo: TestConstants.ePrepayNo,
      //   dong: dongValue,
      //   ho: hoValue,
      //   ePrepayPass: 'tack1171',
      //   useTestcase: useTestcase,
      // );
      // 
      // if (result != null) {
      //   setState(() {
      //     registerResult = result;
      //   });
      //   
      //   // 소유자 이름 비교 실행
      //   checkOwnerName(result);
      // } else {
      //   setState(() {
      //     registerError = '등기부등본 조회에 실패했습니다. 주소를 다시 확인해주세요.';
      //   });
      // }
    } catch (_) {
      // 등기부등본 조회 중 오류 발생 (기능 비활성화 상태에서는 도달 불가)
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
    _addressSearchDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = widget.userName.isNotEmpty;
    
    return LoadingOverlay(
      isLoading: isRegisterLoading || isSaving || isVWorldLoading,
      message: isRegisterLoading
          ? '등기부등본 조회 중...'
          : isSaving
              ? '저장 중...'
              : '위치 정보 조회 중...',
      child: Scaffold(
        backgroundColor: AppColors.kBackground,
        body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 상단 타이틀 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
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
                      '쉽고 빠른 부동산 상담',
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
                      '주소만 입력하면 근처 공인중개사를 찾아드립니다',
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
              const SizedBox(height: 16),
              
              // 검색 입력창
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.3), width: 1.5), // 테두리 추가
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.kPrimary.withValues(alpha: 0.2), // 그림자 강화
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (val) => setState(() => queryAddress = val),
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
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () {
                          if (queryAddress.trim().isNotEmpty) {
                            searchRoadAddress(queryAddress.trim(), page: 1);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                ),
              ),
              if (isSearchingRoadAddr)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.kPrimary),
                  ),
                ),
              if (roadAddressList.isNotEmpty)
                RoadAddressList(
                  fullAddrAPIDatas: fullAddrAPIDataList,
                  addresses: roadAddressList,
                  selectedAddress: selectedRoadAddress, // why?
                  onSelect: (fullData, addr) async {
                    setState(() {
                      selectedFullAddrAPIData = fullData;
                      selectedRoadAddress = addr;
                      selectedDetailAddress = '';
                      selectedFullAddress = addr;
                      _detailController.clear();
                      parsedAddress1st = AddressUtils.parseAddress1st(addr);
                      parsedDetail = {};
                      // 상태 초기화
                      hasAttemptedSearch = false;
                      registerResult = null;
                      registerError = null;
                      ownerMismatchError = null;
                      vworldCoordinates = null;
                      vworldError = null;
                      isVWorldLoading = false;
                      
                    });
                    
                    // 주소 선택 시 단지코드 자동 조회 (주소 검색 API 데이터 포함)
                    _loadAptInfoFromAddress(addr, fullAddrAPIData: fullData);
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
                              queryAddress.isNotEmpty ? queryAddress : _controller.text,
                              page: currentPage - 1,
                              skipDebounce: true,
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
                              queryAddress.isNotEmpty ? queryAddress : _controller.text,
                              page: currentPage + 1,
                              skipDebounce: true,
                            );
                          },
                          child: const Text('다음'),
                        ),
                      ),
                  ],
                ),
              if (selectedRoadAddress.isNotEmpty && !selectedRoadAddress.startsWith('API 오류') && !selectedRoadAddress.startsWith('검색 결과 없음')) ...[
                // 선택된 주소 표시
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.kPrimary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle, color: AppColors.kPrimary, size: 20),
                          SizedBox(width: 12),
                          Text(
                            '선택된 주소',
                            style: TextStyle(
                              color: AppColors.kPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFullAddress,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                
                // 상세주소 입력 (선택사항)
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: DetailAddressInput(
                      controller: _detailController,
                      onChanged: (val) {
                        setState(() {
                          selectedDetailAddress = val;
                          parsedDetail = AddressUtils.parseDetailAddress(val);
                          // 상세주소가 있으면 추가, 없으면 도로명주소만
                          if (val.trim().isNotEmpty) {
                            selectedFullAddress = '$selectedRoadAddress ${val.trim()}';
                          } else {
                            selectedFullAddress = selectedRoadAddress;
                          }
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 조회하기 버튼 (조회 전에만 표시)
                if (!hasAttemptedSearch)
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: SizedBox(
                          width: double.infinity,
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
                  ),
                
                // 공동주택 단지 정보 (조회하기 버튼 클릭 이후 조회하기 버튼 밑에 표시)
                if (hasAttemptedSearch)
                  Builder(
                    builder: (context) {
                      // 최대 너비 설정 (모바일: 전체 너비, 큰 화면: 900px)
                      const double maxContentWidth = 900;
                      
                      // 로딩 중일 때
                      if (isLoadingAptInfo) {
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: maxContentWidth),
                            margin: const EdgeInsets.only(top: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[300]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 16),
                                  Text(
                                    '공동주택 단지 정보 조회 중...',
                                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // 단지 정보 표시 조건: aptInfo와 kaptCode가 모두 있을 때
                      if (aptInfo != null && kaptCode != null) {
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: maxContentWidth),
                            margin: const EdgeInsets.only(top: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildAptInfoCard(),
                          ),
                        );
                      }
                      
                      // 단지 정보가 없는 경우 (공동주택이 아닐 수 있음) - 조회는 시도했지만 결과가 없는 경우에도 표시하지 않음
                      return const SizedBox.shrink();
                    },
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
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                ),
                
              
              
              // 공인중개사 찾기 버튼 (조회 후에 표시, 로그인 여부 무관)
              // 결과 카드가 있을 때는 하단(결과 카드 내부)에 표시하므로 여기서는 숨김
              if (hasAttemptedSearch && vworldCoordinates != null && !(isLoggedIn && registerResult != null))
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                        onPressed: _goToBrokerSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kSecondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: AppColors.kSecondary.withValues(alpha: 0.5),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.business, size: 24),
                        label: const Text('공인중개사 찾기'),
                      ),
                      ),
                    ),
                  ),
                ),
              
              // 등기부등본 결과 표시 및 저장 버튼 (로그인 사용자만)
              if (isLoggedIn && registerResult != null)
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.2), width: 1.5), // 테두리 추가
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.kPrimary.withValues(alpha:0.15), // 색상 그림자
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppColors.kSecondary, // 남색 단색
                          borderRadius: BorderRadius.only(
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
                              content: selectedFullAddress,
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

                      // 결과 카드 맨 하단 - 공인중개사 찾기 버튼
                      if (vworldCoordinates != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _goToBrokerSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.kSecondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: AppColors.kSecondary.withValues(alpha: 0.5),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.business, size: 24),
                              label: const Text('공인중개사 찾기'),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // 단지 정보는 조회하기 버튼 아래에만 표시하므로 등기부등본 카드 내부에서는 제거
                      
                      const SizedBox(height: 0),
                      
                    ],
                  ),
                    ),
                  ),
                ),
                
              // 단지 정보는 조회하기 버튼 아래에만 표시하므로 독립 카드 제거
              // (조회하기 버튼 아래에서 이미 표시됨)
            ],
          ),
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
                    fontSize: 18,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 - 더 컴팩트하게
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          // 구분선
          Divider(height: 1, color: Colors.grey[200]),
          // 내용
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: content,
          ),
        ],
      ),
    );
  }

  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 단지 정보 카드 위젯
  Widget _buildAptInfoCard() {
    if (aptInfo == null) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기본 정보
        _buildRegisterCard(
          icon: Icons.info_outline,
          title: '기본 정보',
          iconColor: AppColors.kPrimary,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (aptInfo!['kaptCode'] != null && aptInfo!['kaptCode'].toString().isNotEmpty)
                _buildDetailRow('단지코드', aptInfo!['kaptCode'].toString()),
              if (aptInfo!['kaptName'] != null && aptInfo!['kaptName'].toString().isNotEmpty)
                _buildDetailRow('단지명', aptInfo!['kaptName'].toString()),
              if (aptInfo!['codeStr'] != null && aptInfo!['codeStr'].toString().isNotEmpty)
                _buildDetailRow('건물구조', aptInfo!['codeStr'].toString()),
            ],
          ),
        ),
        
        // 나머지 단지 정보 카드들 (기본정보와 일반관리 사이에 배치)
        _buildAptInfoCardBetweenBasicAndManagement(),
        
        // 일반 관리
        if ((aptInfo!['codeMgr'] != null && aptInfo!['codeMgr'].toString().isNotEmpty) ||
            (aptInfo!['kaptMgrCnt'] != null && aptInfo!['kaptMgrCnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptCcompany'] != null && aptInfo!['kaptCcompany'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.manage_accounts,
            title: '일반 관리',
            iconColor: Colors.blue,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeMgr'] != null && aptInfo!['codeMgr'].toString().isNotEmpty)
                  _buildDetailRow('관리방식', aptInfo!['codeMgr'].toString()),
                if (aptInfo!['kaptMgrCnt'] != null && aptInfo!['kaptMgrCnt'].toString().isNotEmpty)
                  _buildDetailRow('관리사무소 수', '${aptInfo!['kaptMgrCnt']}개'),
                if (aptInfo!['kaptCcompany'] != null && aptInfo!['kaptCcompany'].toString().isNotEmpty)
                  _buildDetailRow('관리업체', aptInfo!['kaptCcompany'].toString()),
              ],
            ),
          ),
      ],
    );
  }

  /// 기본정보와 일반관리 사이에 표시할 단지 정보 카드 (기본정보와 일반관리 제외)
  Widget _buildAptInfoCardBetweenBasicAndManagement() {
    if (aptInfo == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 경비 관리
        if ((aptInfo!['codeSec'] != null && aptInfo!['codeSec'].toString().isNotEmpty) ||
            (aptInfo!['kaptdScnt'] != null && aptInfo!['kaptdScnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptdSecCom'] != null && aptInfo!['kaptdSecCom'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.security,
            title: '경비 관리',
            iconColor: Colors.red,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeSec'] != null && aptInfo!['codeSec'].toString().isNotEmpty)
                  _buildDetailRow('경비관리방식', aptInfo!['codeSec'].toString()),
                if (aptInfo!['kaptdScnt'] != null && aptInfo!['kaptdScnt'].toString().isNotEmpty)
                  _buildDetailRow('경비인력 수', '${aptInfo!['kaptdScnt']}명'),
                if (aptInfo!['kaptdSecCom'] != null && aptInfo!['kaptdSecCom'].toString().isNotEmpty)
                  _buildDetailRow('경비업체', aptInfo!['kaptdSecCom'].toString()),
              ],
            ),
          ),
        
        // 청소 관리
        if ((aptInfo!['codeClean'] != null && aptInfo!['codeClean'].toString().isNotEmpty) ||
            (aptInfo!['kaptdClcnt'] != null && aptInfo!['kaptdClcnt'].toString().isNotEmpty) ||
            (aptInfo!['codeGarbage'] != null && aptInfo!['codeGarbage'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.cleaning_services,
            title: '청소 관리',
            iconColor: Colors.green,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeClean'] != null && aptInfo!['codeClean'].toString().isNotEmpty)
                  _buildDetailRow('청소관리방식', aptInfo!['codeClean'].toString()),
                if (aptInfo!['kaptdClcnt'] != null && aptInfo!['kaptdClcnt'].toString().isNotEmpty)
                  _buildDetailRow('청소인력 수', '${aptInfo!['kaptdClcnt']}명'),
                if (aptInfo!['codeGarbage'] != null && aptInfo!['codeGarbage'].toString().isNotEmpty)
                  _buildDetailRow('음식물처리방법', aptInfo!['codeGarbage'].toString()),
              ],
            ),
          ),
        
        // 소독 관리
        if ((aptInfo!['codeDisinf'] != null && aptInfo!['codeDisinf'].toString().isNotEmpty) ||
            (aptInfo!['kaptdDcnt'] != null && aptInfo!['kaptdDcnt'].toString().isNotEmpty) ||
            (aptInfo!['disposalType'] != null && aptInfo!['disposalType'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.medical_services,
            title: '소독 관리',
            iconColor: Colors.purple,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeDisinf'] != null && aptInfo!['codeDisinf'].toString().isNotEmpty)
                  _buildDetailRow('소독관리방식', aptInfo!['codeDisinf'].toString()),
                if (aptInfo!['kaptdDcnt'] != null && aptInfo!['kaptdDcnt'].toString().isNotEmpty)
                  _buildDetailRow('소독인력 수', '${aptInfo!['kaptdDcnt']}명'),
                if (aptInfo!['disposalType'] != null && aptInfo!['disposalType'].toString().isNotEmpty)
                  _buildDetailRow('소독방법', aptInfo!['disposalType'].toString()),
              ],
            ),
          ),
        
        // 건물/시설 정보
        if ((aptInfo!['codeEcon'] != null && aptInfo!['codeEcon'].toString().isNotEmpty) ||
            (aptInfo!['codeEmgr'] != null && aptInfo!['codeEmgr'].toString().isNotEmpty) ||
            (aptInfo!['kaptdEcapa'] != null && aptInfo!['kaptdEcapa'].toString().isNotEmpty) ||
            (aptInfo!['codeFalarm'] != null && aptInfo!['codeFalarm'].toString().isNotEmpty) ||
            (aptInfo!['codeWsupply'] != null && aptInfo!['codeWsupply'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.home,
            title: '건물/시설',
            iconColor: Colors.orange,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['kaptdEcapa'] != null && aptInfo!['kaptdEcapa'].toString().isNotEmpty)
                  _buildDetailRow('수전용량', aptInfo!['kaptdEcapa'].toString()),
                if (aptInfo!['codeEcon'] != null && aptInfo!['codeEcon'].toString().isNotEmpty)
                  _buildDetailRow('세대전기계약방식', aptInfo!['codeEcon'].toString()),
                if (aptInfo!['codeEmgr'] != null && aptInfo!['codeEmgr'].toString().isNotEmpty)
                  _buildDetailRow('전기안전관리자법정선임여부', aptInfo!['codeEmgr'].toString()),
                if (aptInfo!['codeFalarm'] != null && aptInfo!['codeFalarm'].toString().isNotEmpty)
                  _buildDetailRow('화재수신반방식', aptInfo!['codeFalarm'].toString()),
                if (aptInfo!['codeWsupply'] != null && aptInfo!['codeWsupply'].toString().isNotEmpty)
                  _buildDetailRow('급수방식', aptInfo!['codeWsupply'].toString()),
              ],
            ),
          ),
        
        // 승강기/주차 정보
        if ((aptInfo!['codeElev'] != null && aptInfo!['codeElev'].toString().isNotEmpty) ||
            (aptInfo!['kaptdEcnt'] != null && aptInfo!['kaptdEcnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptdPcnt'] != null && aptInfo!['kaptdPcnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptdPcntu'] != null && aptInfo!['kaptdPcntu'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.elevator,
            title: '승강기/주차',
            iconColor: Colors.teal,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeElev'] != null && aptInfo!['codeElev'].toString().isNotEmpty)
                  _buildDetailRow('승강기관리형태', aptInfo!['codeElev'].toString()),
                if (aptInfo!['kaptdEcnt'] != null && aptInfo!['kaptdEcnt'].toString().isNotEmpty)
                  _buildDetailRow('승강기대수', '${aptInfo!['kaptdEcnt']}대'),
                if (aptInfo!['kaptdPcnt'] != null && aptInfo!['kaptdPcnt'].toString().isNotEmpty)
                  _buildDetailRow('주차대수(지상)', '${aptInfo!['kaptdPcnt']}대'),
                if (aptInfo!['kaptdPcntu'] != null && aptInfo!['kaptdPcntu'].toString().isNotEmpty)
                  _buildDetailRow('주차대수(지하)', '${aptInfo!['kaptdPcntu']}대'),
              ],
            ),
          ),
        
        // 통신/보안시설
        if ((aptInfo!['codeNet'] != null && aptInfo!['codeNet'].toString().isNotEmpty) ||
            (aptInfo!['kaptdCccnt'] != null && aptInfo!['kaptdCccnt'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.camera_alt,
            title: '통신/보안시설',
            iconColor: Colors.indigo,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeNet'] != null && aptInfo!['codeNet'].toString().isNotEmpty)
                  _buildDetailRow('주차관제/홈네트워크', aptInfo!['codeNet'].toString()),
                if (aptInfo!['kaptdCccnt'] != null && aptInfo!['kaptdCccnt'].toString().isNotEmpty)
                  _buildDetailRow('CCTV대수', '${aptInfo!['kaptdCccnt']}대'),
              ],
            ),
          ),
        
        // 편의/복리시설
        if ((aptInfo!['welfareFacility'] != null && aptInfo!['welfareFacility'].toString().isNotEmpty) ||
            (aptInfo!['convenientFacility'] != null && aptInfo!['convenientFacility'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.local_convenience_store,
            title: '편의/복리시설',
            iconColor: Colors.pink,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['welfareFacility'] != null && aptInfo!['welfareFacility'].toString().isNotEmpty)
                  _buildDetailRow('부대/복리시설', aptInfo!['welfareFacility'].toString()),
                if (aptInfo!['convenientFacility'] != null && aptInfo!['convenientFacility'].toString().isNotEmpty)
                  _buildDetailRow('편의시설', aptInfo!['convenientFacility'].toString()),
              ],
            ),
          ),
        
        // 교통 정보
        if ((aptInfo!['kaptdWtimebus'] != null && aptInfo!['kaptdWtimebus'].toString().isNotEmpty) ||
            (aptInfo!['subwayLine'] != null && aptInfo!['subwayLine'].toString().isNotEmpty) ||
            (aptInfo!['subwayStation'] != null && aptInfo!['subwayStation'].toString().isNotEmpty) ||
            (aptInfo!['kaptdWtimesub'] != null && aptInfo!['kaptdWtimesub'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.train,
            title: '교통 정보',
            iconColor: Colors.blueGrey,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['kaptdWtimebus'] != null && aptInfo!['kaptdWtimebus'].toString().isNotEmpty)
                  _buildDetailRow('버스정류장 거리', aptInfo!['kaptdWtimebus'].toString()),
                if (aptInfo!['subwayLine'] != null && aptInfo!['subwayLine'].toString().isNotEmpty)
                  _buildDetailRow('지하철호선', aptInfo!['subwayLine'].toString()),
                if (aptInfo!['subwayStation'] != null && aptInfo!['subwayStation'].toString().isNotEmpty)
                  _buildDetailRow('지하철역명', aptInfo!['subwayStation'].toString()),
                if (aptInfo!['kaptdWtimesub'] != null && aptInfo!['kaptdWtimesub'].toString().isNotEmpty)
                  _buildDetailRow('지하철역 거리', aptInfo!['kaptdWtimesub'].toString()),
              ],
            ),
          ),
        
        // 교육시설
        if (aptInfo!['educationFacility'] != null && aptInfo!['educationFacility'].toString().isNotEmpty)
          _buildRegisterCard(
            icon: Icons.school,
            title: '교육시설',
            iconColor: Colors.amber,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('교육시설', aptInfo!['educationFacility'].toString()),
              ],
            ),
          ),
        
        // 전기차 충전기
        if ((aptInfo!['groundElChargerCnt'] != null && aptInfo!['groundElChargerCnt'].toString().isNotEmpty) ||
            (aptInfo!['undergroundElChargerCnt'] != null && aptInfo!['undergroundElChargerCnt'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.ev_station,
            title: '전기차 충전기',
            iconColor: Colors.lightGreen,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['groundElChargerCnt'] != null && aptInfo!['groundElChargerCnt'].toString().isNotEmpty)
                  _buildDetailRow('지상 전기차 충전기', '${aptInfo!['groundElChargerCnt']}대'),
                if (aptInfo!['undergroundElChargerCnt'] != null && aptInfo!['undergroundElChargerCnt'].toString().isNotEmpty)
                  _buildDetailRow('지하 전기차 충전기', '${aptInfo!['undergroundElChargerCnt']}대'),
              ],
            ),
          ),
      ],
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
  final List<Map<String, String>> fullAddrAPIDatas;
  final List<String> addresses;
  final String selectedAddress;
  final void Function(Map<String, String>, String) onSelect;

  const RoadAddressList(
      {required this.fullAddrAPIDatas, required this.addresses, required this.selectedAddress, required this.onSelect, super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery
        .of(context)
        .size
        .width < 600;
    final horizontalMargin = isMobile ? 16.0 : 40.0;
    final itemPadding = isMobile ? 14.0 : 12.0;
    final fontSize = isMobile ? 17.0 : 15.0;

    List<Widget> listItems = [];
    for (int i = 0; i < addresses.length; i++) {
      final addr = addresses[i];
      final fullData = fullAddrAPIDatas[i];
      final isSelected = selectedAddress.trim() == addr.trim();
      listItems.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(fullData, addr),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.symmetric(
                  vertical: itemPadding, horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.kPrimary : Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: isSelected ? AppColors.kPrimary : Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: isSelected
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
                  if (isSelected) const Icon(
                      Icons.check_circle, color: Colors.white, size: 20),
                  if (isSelected) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      addr,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors
                            .kTextPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight
                            .w500,
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(
                    Icons.location_on, color: AppColors.kPrimary, size: 20),
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
          ...listItems,
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
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: '상세주소 (선택사항)',
          hintText: '예: 211동 1506호',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
          ),
          helperText: '💡 아파트/오피스텔은 동/호수 입력, 단독주택/다가구는 생략 가능합니다',
          helperStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kError.withValues(alpha: 0.08), // 단색 배경
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.kError.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(
                Icons.error_outline,
                color: AppColors.kError,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
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
      ),
    );
  }
}

/// VWorld 데이터 표시 위젯
class VWorldDataWidget extends StatelessWidget {
  final Map<String, dynamic>? coordinates;
  final String? error;
  final bool isLoading;
  
  const VWorldDataWidget({
    this.coordinates,
    this.error,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 로딩 중이거나, 데이터가 있거나, 에러가 있으면 표시
    if (!isLoading && coordinates == null && error == null) {
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
                      isLoading ? '위치 정보 조회 중...' : (error != null ? '위치 정보 조회 실패' : '위치 정보'),
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

}

