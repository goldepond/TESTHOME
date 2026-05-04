import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/utils/logger.dart';

/// 우선권 감사 로그 단일 엔트리.
///
/// `priority_audit_logs` collectionGroup 의 1건. *append-only*.
/// 클라이언트는 본인 관련(`brokerId == uid` OR `actorUid == uid` OR `sellerUid == uid`)만 read.
class PriorityAuditLogEntry {
  final String eventId;
  final String eventType;
  final String? actorUid;
  final String? propertyId;
  final String? brokerId;
  final String? sellerUid;
  final String? grantId;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> outputs;
  final String rulebookVersion;
  final DateTime createdAt;

  const PriorityAuditLogEntry({
    required this.eventId,
    required this.eventType,
    required this.inputs,
    required this.outputs,
    required this.rulebookVersion,
    required this.createdAt,
    this.actorUid,
    this.propertyId,
    this.brokerId,
    this.sellerUid,
    this.grantId,
  });

  factory PriorityAuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PriorityAuditLogEntry.fromMap(<String, dynamic>{
      ...data,
      'eventId': data['eventId'] ?? doc.id,
    });
  }

  factory PriorityAuditLogEntry.fromMap(Map<String, dynamic> map) {
    return PriorityAuditLogEntry(
      eventId: (map['eventId'] ?? '') as String,
      eventType: (map['eventType'] ?? '') as String,
      actorUid: map['actorUid'] as String?,
      propertyId: map['propertyId'] as String?,
      brokerId: map['brokerId'] as String?,
      sellerUid: map['sellerUid'] as String?,
      grantId: map['grantId'] as String?,
      inputs: map['inputs'] is Map
          ? Map<String, dynamic>.from(map['inputs'] as Map)
          : const <String, dynamic>{},
      outputs: map['outputs'] is Map
          ? Map<String, dynamic>.from(map['outputs'] as Map)
          : const <String, dynamic>{},
      rulebookVersion: (map['rulebookVersion'] ?? '') as String,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'eventId': eventId,
      'eventType': eventType,
      'actorUid': actorUid,
      'propertyId': propertyId,
      'brokerId': brokerId,
      'sellerUid': sellerUid,
      'grantId': grantId,
      'inputs': inputs,
      'outputs': outputs,
      'rulebookVersion': rulebookVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// 우선권 감사 로그 클라이언트 서비스 (Task 06).
///
/// 본인 관련 이벤트만 읽을 수 있다 — Rules 가 brokerId/actorUid/sellerUid 일치 시 read 허용.
/// Firestore 단일 query 의 OR 미지원 → **3-쿼리 fan-out + 머지** 패턴.
///
/// `inputs`/`outputs` 는 *내부 디버깅용*. UI 에 노출하지 말 것.
class PriorityAuditLogService {
  static final PriorityAuditLogService _instance =
      PriorityAuditLogService._internal();
  factory PriorityAuditLogService() => _instance;
  PriorityAuditLogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'priority_audit_logs';

  /// 본인 관련 audit 로그 (brokerId OR actorUid OR sellerUid 본인 일치).
  ///
  /// 3 쿼리 fan-out → eventId 기준 중복 제거 → createdAt DESC 머지 → [limit] 컷.
  Future<List<PriorityAuditLogEntry>> getMyAuditLogs({int limit = 50}) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const <PriorityAuditLogEntry>[];
    }

    try {
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> futures =
          <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collectionGroup(_collection)
            .where('brokerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get(),
        _firestore
            .collectionGroup(_collection)
            .where('actorUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get(),
        _firestore
            .collectionGroup(_collection)
            .where('sellerUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get(),
      ];

      final List<QuerySnapshot<Map<String, dynamic>>> results =
          await Future.wait(futures);
      return _mergeAndDedup(results, limit: limit);
    } catch (e, stack) {
      Logger.error(
        'getMyAuditLogs failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityAuditLogService',
        metadata: <String, dynamic>{'uid': uid},
      );
      return const <PriorityAuditLogEntry>[];
    }
  }

  /// 매물별 audit 로그 — 매도자가 본인 매물 단계 이력 조회용.
  ///
  /// Rules 가 sellerUid 매칭 시 read 허용. propertyId + sellerUid(=본인 uid) 로 좁힌다.
  Future<List<PriorityAuditLogEntry>> getPropertyAuditLogs(
    String propertyId, {
    int limit = 100,
  }) async {
    if (propertyId.isEmpty) {
      return const <PriorityAuditLogEntry>[];
    }
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const <PriorityAuditLogEntry>[];
    }

    try {
      // Rules 권한을 만족시키기 위해 sellerUid 도 본인 uid 로 필터.
      // (관리자가 아닌 일반 사용자 path)
      final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
          .collectionGroup(_collection)
          .where('propertyId', isEqualTo: propertyId)
          .where('sellerUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                PriorityAuditLogEntry.fromFirestore(d),
          )
          .toList(growable: false);
    } catch (e, stack) {
      Logger.error(
        'getPropertyAuditLogs failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityAuditLogService',
        metadata: <String, dynamic>{
          'propertyId': propertyId,
          'uid': uid,
        },
      );
      return const <PriorityAuditLogEntry>[];
    }
  }

  /// 3 쿼리 결과 머지 → eventId 중복 제거 → createdAt DESC 정렬 → limit 컷.
  List<PriorityAuditLogEntry> _mergeAndDedup(
    List<QuerySnapshot<Map<String, dynamic>>> results, {
    required int limit,
  }) {
    final Map<String, PriorityAuditLogEntry> byId =
        <String, PriorityAuditLogEntry>{};
    for (final QuerySnapshot<Map<String, dynamic>> snap in results) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        final PriorityAuditLogEntry entry =
            PriorityAuditLogEntry.fromFirestore(doc);
        if (entry.eventId.isEmpty) continue;
        byId[entry.eventId] = entry;
      }
    }
    final List<PriorityAuditLogEntry> merged = byId.values.toList()
      ..sort(
        (PriorityAuditLogEntry a, PriorityAuditLogEntry b) =>
            b.createdAt.compareTo(a.createdAt),
      );
    if (merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }
}
