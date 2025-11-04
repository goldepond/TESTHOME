import 'package:property/api_request/seoul_broker_service.dart';

/// 공인중개사 등록번호 검증 결과
class BrokerValidationResult {
  final bool isValid;
  final String? errorMessage;
  final BrokerInfo? brokerInfo;

  BrokerValidationResult({
    required this.isValid,
    this.errorMessage,
    this.brokerInfo,
  });

  factory BrokerValidationResult.success(BrokerInfo info) {
    return BrokerValidationResult(
      isValid: true,
      brokerInfo: info,
    );
  }

  factory BrokerValidationResult.failure(String message) {
    return BrokerValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }
}

/// 검증된 공인중개사 정보
class BrokerInfo {
  final String registrationNumber;
  final String ownerName;
  final String businessName;
  final String phoneNumber;
  final String? systemRegNo;
  final String? address;

  BrokerInfo({
    required this.registrationNumber,
    required this.ownerName,
    required this.businessName,
    required this.phoneNumber,
    this.systemRegNo,
    this.address,
  });
}

/// 공인중개사 등록번호 검증 서비스
class BrokerValidationService {
  /// 공인중개사 등록번호 및 대표자명 검증
  /// 
  /// [registrationNumber] 중개업 등록번호 (예: "11230-2022-00144")
  /// [ownerName] 대표자명 (중개업자명)
  /// 
  /// 반환: BrokerValidationResult
  /// - isValid: true면 검증 성공
  /// - brokerInfo: 검증된 중개사 정보
  /// - errorMessage: 검증 실패 시 오류 메시지
  static Future<BrokerValidationResult> validateBroker({
    required String registrationNumber,
    required String ownerName,
  }) async {
    try {
      print('🔍 [BrokerValidationService] 공인중개사 검증 시작');
      print('   등록번호: $registrationNumber');
      print('   대표자명: $ownerName');

      // 입력값 검증
      if (registrationNumber.isEmpty || registrationNumber.trim().isEmpty) {
        return BrokerValidationResult.failure('등록번호를 입력해주세요.');
      }

      if (ownerName.isEmpty || ownerName.trim().isEmpty) {
        return BrokerValidationResult.failure('대표자명을 입력해주세요.');
      }

      // 등록번호 정규화 (공백, 하이픈 제거 후 재구성)
      final normalizedRegNo = _normalizeRegistrationNumber(registrationNumber);
      final normalizedOwnerName = ownerName.trim();

      print('   정규화된 등록번호: $normalizedRegNo');
      print('   정규화된 대표자명: $normalizedOwnerName');

      // 1단계: 서울시 API로 조회 (서울 소재 중개사)
      final seoulBroker = await SeoulBrokerService.getBrokerDetailByRegistrationNumber(
        registrationNumber,
      );

      if (seoulBroker != null) {
        print('   ✅ 서울시 API에서 찾음');

        // 대표자명 비교 (부분 일치 허용 - 공백, 특수문자 무시)
        final seoulOwnerName = seoulBroker.ownerName.trim();
        if (_compareNames(normalizedOwnerName, seoulOwnerName)) {
          print('   ✅ 대표자명 일치: "$normalizedOwnerName" == "$seoulOwnerName"');

          return BrokerValidationResult.success(
            BrokerInfo(
              registrationNumber: seoulBroker.registrationNumber,
              ownerName: seoulBroker.ownerName,
              businessName: seoulBroker.businessName,
              phoneNumber: seoulBroker.phoneNumber,
              systemRegNo: seoulBroker.systemRegNo,
              address: seoulBroker.address,
            ),
          );
        } else {
          print('   ❌ 대표자명 불일치');
          print('      입력: "$normalizedOwnerName"');
          print('      등록: "$seoulOwnerName"');
          return BrokerValidationResult.failure(
            '등록번호와 대표자명이 일치하지 않습니다.\n'
            '등록된 대표자명: $seoulOwnerName',
          );
        }
      }

      // 2단계: VWorld API로 조회 (전국 중개사)
      // 참고: VWorld API는 좌표 기반 검색만 지원하므로,
      // 등록번호로 직접 검색하기 어려움
      // 현재는 서울시 API만 사용
      // 향후 필요시 다른 공공데이터 API 활용 가능

      print('   ⚠️ 서울시 API에서 찾을 수 없음');
      return BrokerValidationResult.failure(
        '입력하신 등록번호로 등록된 공인중개사를 찾을 수 없습니다.\n'
        '등록번호와 대표자명을 다시 확인해주세요.\n\n'
        '※ 현재는 서울시 소재 공인중개사만 검증 가능합니다.',
      );
    } catch (e) {
      print('❌ [BrokerValidationService] 검증 중 오류: $e');
      return BrokerValidationResult.failure(
        '검증 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// 등록번호 정규화
  /// 예: "11230-2022-00144" → "11230-2022-00144"
  ///     "11230 2022 00144" → "11230-2022-00144"
  static String _normalizeRegistrationNumber(String regNo) {
    // 공백 제거
    var normalized = regNo.trim().replaceAll(RegExp(r'\s+'), '');
    
    // 하이픈이 없으면 형식에 맞게 추가
    // 형식: "XXXXX-YYYY-ZZZZZ"
    if (!normalized.contains('-')) {
      // 숫자만 추출
      final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 10) {
        // 5-4-5 형식으로 변환
        normalized = '${digits.substring(0, 5)}-${digits.substring(5, 9)}-${digits.substring(9)}';
      }
    }
    
    return normalized;
  }

  /// 이름 비교 (부분 일치 허용)
  /// 공백, 특수문자, 한글 자음/모음 변형 무시
  static bool _compareNames(String name1, String name2) {
    // 정규화: 공백, 특수문자 제거, 소문자 변환
    final n1 = name1
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w가-힣]'), '')
        .toLowerCase();
    final n2 = name2
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w가-힣]'), '')
        .toLowerCase();

    // 완전 일치
    if (n1 == n2) return true;

    // 부분 일치 (한쪽이 다른 쪽을 포함)
    if (n1.contains(n2) || n2.contains(n1)) return true;

    // 한글 자음/모음 변형 무시 (기본적인 레벨)
    // 예: "홍길동" == "홍 길 동"
    final n1Normalized = _normalizeKoreanName(n1);
    final n2Normalized = _normalizeKoreanName(n2);

    return n1Normalized == n2Normalized;
  }

  /// 한글 이름 정규화 (기본)
  /// 더 정교한 한글 유사도 비교는 향후 필요시 추가
  static String _normalizeKoreanName(String name) {
    // 공백 제거, 특수문자 제거만 수행
    return name.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^\w가-힣]'), '');
  }
}

