# 04. 견적 요청 시스템 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/04_QUOTE_REQUEST.md`

---

## 📋 개요

견적 요청 시스템은 MVP의 핵심 기능입니다. 사용자가 여러 공인중개사를 선택하여 동시에 견적을 요청할 수 있습니다.

---

## 📝 QuoteRequest 모델

**파일:** `lib/models/quote_request.dart`

**주요 필드:**

```5:82:lib/models/quote_request.dart
/// 견적문의 모델 (매도자 입찰카드)
class QuoteRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String brokerName;
  final String? brokerRegistrationNumber;
  final String? brokerRoadAddress;
  final String? brokerJibunAddress;
  final String? brokerEmail; // Admin이 나중에 추가하는 필드
  final String message;
  final String status; // pending, contacted, completed, cancelled
  final DateTime requestDate;
  final DateTime? emailAttachedAt;
  final DateTime? emailAttachedBy;
  final DateTime? updatedAt;
  
  // ========== 1️⃣ 기본정보 (자동 입력) ==========
  final String? propertyType;        // 매물 유형 (아파트/오피스텔/원룸)
  final String? propertyAddress;     // 위치
  final String? propertyArea;        // 전용면적 (㎡)
  
  // ========== 2️⃣ 중개 제안 (중개업자 입력) ==========
  final String? recommendedPrice;    // 권장 매도가
  final String? minimumPrice;        // 최저수락가
  final String? expectedDuration;    // 예상 거래기간
  final String? promotionMethod;     // 홍보 방법
  final String? commissionRate;      // 수수료 제안율
  final String? recentCases;         // 최근 유사 거래 사례
  
  // ========== 3️⃣ 특이사항 (판매자 입력) ==========
  final bool? hasTenant;             // 세입자 여부
  final String? desiredPrice;        // 희망가
  final String? targetPeriod;        // 목표기간
  final String? specialNotes;        // 특이사항
  
  // ========== 4️⃣ 중개업자 답변 ==========
  final String? brokerAnswer;        // 공인중개사 답변
  final DateTime? answerDate;        // 답변 일시
  final String? inquiryLinkId;       // 고유 링크 ID (이메일용)

  QuoteRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.brokerName,
    this.brokerRegistrationNumber,
    this.brokerRoadAddress,
    this.brokerJibunAddress,
    this.brokerEmail,
    required this.message,
    required this.status,
    required this.requestDate,
    this.emailAttachedAt,
    this.emailAttachedBy,
    this.updatedAt,
    // 1️⃣ 기본정보
    this.propertyType,
    this.propertyAddress,
    this.propertyArea,
    // 2️⃣ 중개 제안
    this.recommendedPrice,
    this.minimumPrice,
    this.expectedDuration,
    this.promotionMethod,
    this.commissionRate,
    this.recentCases,
    // 3️⃣ 특이사항
    this.hasTenant,
    this.desiredPrice,
    this.targetPeriod,
    this.specialNotes,
    // 4️⃣ 중개업자 답변
    this.brokerAnswer,
    this.answerDate,
    this.inquiryLinkId,
  });
```

---

## 🔄 견적 요청 플로우

### 1. 개별 견적 요청

```1997:2011:lib/screens/broker_list_page.dart
void _requestQuote(Broker broker) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => _QuoteRequestFormPage(
        broker: broker,
        userName: widget.userName,
        userId: widget.userId ?? '',
        propertyAddress: widget.address, // 조회한 주소 전달
        propertyArea: widget.propertyArea, // 토지 면적 전달
      ),
      fullscreenDialog: true,
    ),
  );
}
```

### 2. 다중 견적 요청 (MVP 핵심)

```2014:2044:lib/screens/broker_list_page.dart
/// 여러 공인중개사에게 일괄 견적 요청 (MVP 핵심 기능)
Future<void> _requestQuoteToMultiple() async {
  if (_selectedBrokerIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('견적을 요청할 공인중개사를 선택해주세요.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // 선택한 중개사 목록 가져오기
  final selectedBrokers = filteredBrokers.where((broker) {
    return _selectedBrokerIds.contains(broker.systemRegNo);
  }).toList();
  
  // 일괄 견적 요청 다이얼로그 표시
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _MultipleQuoteRequestDialog(
      brokerCount: selectedBrokers.length,
      address: widget.address,
      propertyArea: widget.propertyArea,
    ),
  );
  
  if (result == null) return; // 취소됨
  
  // 선택한 모든 중개사에게 동일한 정보로 견적 요청
  int successCount = 0;
```

---

## 💾 Firebase 저장

**FirebaseService.saveQuoteRequest() 구현:**

견적 요청은 Firestore의 `quoteRequests` 컬렉션에 저장됩니다. 각 요청마다 고유한 `inquiryLinkId`가 생성되어 중개사가 접근할 수 있는 링크를 제공합니다.

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[05_QUOTE_MANAGEMENT.md](05_QUOTE_MANAGEMENT.md)** - 견적 관리 및 답변 시스템 상세 설명

