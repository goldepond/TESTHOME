import 'package:cloud_firestore/cloud_firestore.dart';

/// 우선권 이의 제기 (priority_appeals 컬렉션)
///
/// 중개사 또는 매도자가 우선권 부여 결과에 이의를 제기할 때 생성된다.
/// 클라이언트는 `status='open'`으로만 생성 가능, 변경은 관리자만.
///
/// P1-12 — 이의 제기와 listingMode 통합:
///   * `appealCategory` 필드(선택, 기본 'grant_decision') 추가.
///   * 'listing_mode_dispute' 분류는 *grantId 부재 허용* — propertyId 만으로
///     제기 가능 (exclusive 모드 진입/지정 자체에 대한 분쟁).
///   * 분쟁 카테고리는 매도자 + 중개사 양측 모두 제기 가능.
class PriorityAppeal {
  final String appealId;
  final String filerUid; // 이의 제기자 Firebase Auth uid
  final String grantId; // 대상 우선권 grantId (listing_mode_dispute 시 빈 문자열 허용)

  // P1-12 — 분쟁 분류. 기존 데이터 호환을 위해 기본값 'grant_decision'.
  // 'listing_mode_dispute' 일 때만 grantId 부재 허용 + propertyId 필수.
  final AppealCategory appealCategory;

  // P1-12 — listing_mode_dispute 카테고리에서 사용. grant_decision 시 nullable.
  // grantId 가 없을 때 분쟁 대상 매물을 식별하기 위한 보조 키.
  final String? propertyId;

  // 사유 (max 1000자)
  final String reason;

  // 처리 상태
  final AppealStatus status;
  final String? resolution; // 처리 결과 메시지

  // 재현된 산정 결과 (관리자가 산정 알고리즘 재실행한 결과 스냅샷)
  final Map<String, dynamic>? replayedDecision;

  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// 사유 길이 제한 — 1000자
  static const int maxReasonLength = 1000;

  PriorityAppeal({
    required this.appealId,
    required this.filerUid,
    required this.grantId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.appealCategory = AppealCategory.grantDecision,
    this.propertyId,
    this.resolution,
    this.replayedDecision,
    this.resolvedAt,
  }) : assert(
          reason.length <= maxReasonLength,
          'reason은 최대 $maxReasonLength자까지 허용된다',
        );

  Map<String, dynamic> toMap() {
    return {
      'appealId': appealId,
      'filerUid': filerUid,
      'grantId': grantId,
      'appealCategory': appealCategory.wireName,
      'propertyId': propertyId,
      'reason': reason,
      'status': status.name,
      'resolution': resolution,
      'replayedDecision': replayedDecision,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  factory PriorityAppeal.fromMap(Map<String, dynamic> map) {
    final rawReason = (map['reason'] ?? '') as String;
    // 저장된 데이터가 1000자 초과이면 잘라서 안전하게 로드한다 (마이그레이션 안전).
    final reason = rawReason.length > maxReasonLength
        ? rawReason.substring(0, maxReasonLength)
        : rawReason;

    return PriorityAppeal(
      appealId: map['appealId'] ?? '',
      filerUid: map['filerUid'] ?? '',
      grantId: map['grantId'] ?? '',
      appealCategory: AppealCategory.fromWireName(map['appealCategory']),
      propertyId: map['propertyId'] as String?,
      reason: reason,
      status: AppealStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppealStatus.open,
      ),
      resolution: map['resolution'],
      replayedDecision: map['replayedDecision'] == null
          ? null
          : Map<String, dynamic>.from(map['replayedDecision']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      resolvedAt: _parseDate(map['resolvedAt']),
    );
  }

  factory PriorityAppeal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PriorityAppeal.fromMap({...data, 'appealId': doc.id});
  }

  PriorityAppeal copyWith({
    String? appealId,
    String? filerUid,
    String? grantId,
    AppealCategory? appealCategory,
    String? propertyId,
    String? reason,
    AppealStatus? status,
    String? resolution,
    Map<String, dynamic>? replayedDecision,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return PriorityAppeal(
      appealId: appealId ?? this.appealId,
      filerUid: filerUid ?? this.filerUid,
      grantId: grantId ?? this.grantId,
      appealCategory: appealCategory ?? this.appealCategory,
      propertyId: propertyId ?? this.propertyId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      resolution: resolution ?? this.resolution,
      replayedDecision: replayedDecision ?? this.replayedDecision,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  /// 미처리 상태 여부
  bool get isOpen =>
      status == AppealStatus.open || status == AppealStatus.reviewing;

  /// 종결 여부
  bool get isClosed =>
      status == AppealStatus.resolved || status == AppealStatus.rejected;
}

/// 이의 제기 처리 상태
enum AppealStatus {
  open, // 접수됨 (관리자 검토 대기)
  reviewing, // 검토 중
  resolved, // 인용 — 우선권 조정/취소
  rejected, // 기각
}

/// P1-12 — 이의 제기 분류
///
/// * `grantDecision` (기본): 우선권 부여/거절/해지 등 grant 결정에 대한 이의.
///   기존 흐름과 동일하게 `grantId` 필수.
/// * `listingModeDispute`: exclusive 모드 진입/지정 자체에 대한 분쟁
///   (예: 매도자의 단독 지정에 거절된 중개사가 항의 / 매도자가 admin 강제
///   변경에 항의). 이 분류에서는 `grantId` 부재 허용 + `propertyId` 필수.
/// * `other`: 위 두 분류에 해당하지 않는 기타 분쟁.
///
/// `wireName` 은 Firestore 저장용 snake_case 코드. 변경 시 functions/index.js
/// `APPEAL_CATEGORY_*` 상수와 1:1 동기화 필요.
enum AppealCategory {
  grantDecision('grant_decision'),
  listingModeDispute('listing_mode_dispute'),
  other('other');

  final String wireName;
  const AppealCategory(this.wireName);

  /// Firestore 저장 코드를 enum 으로 복원. 알 수 없는 값은 `grantDecision` 로 안전 폴백
  /// (기존 데이터 호환). `null` 도 동일하게 폴백.
  static AppealCategory fromWireName(dynamic value) {
    if (value is! String) return AppealCategory.grantDecision;
    for (final c in AppealCategory.values) {
      if (c.wireName == value) return c;
    }
    return AppealCategory.grantDecision;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
