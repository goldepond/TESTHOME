import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/broker_stats.dart';
import '../models/seller_history.dart';
import '../utils/logger.dart';

/// 중개사 통계 및 판매자 히스토리 서비스
///
/// 행동 데이터 기반의 중개사 성과 측정 및 판매자 거래 이력 관리
class BrokerStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== 컬렉션 참조 ==========
  CollectionReference<Map<String, dynamic>> get _brokerStatsCollection =>
      _firestore.collection('brokerStats');

  CollectionReference<Map<String, dynamic>> get _sellerHistoryCollection =>
      _firestore.collection('sellerHistory');

  // ========== 중개사 통계 조회 ==========

  /// 중개사 통계 조회
  Future<BrokerStats?> getBrokerStats(String brokerId) async {
    try {
      final doc = await _brokerStatsCollection.doc(brokerId).get();
      if (!doc.exists) return null;
      return BrokerStats.fromMap(doc.data()!);
    } catch (e) {
      Logger.error('중개사 통계 조회 실패', error: e);
      return null;
    }
  }

  /// 중개사 통계 스트림
  Stream<BrokerStats?> getBrokerStatsStream(String brokerId) {
    return _brokerStatsCollection.doc(brokerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BrokerStats.fromMap(doc.data()!);
    });
  }

  /// 모든 중개사 통계 조회 (관리자용)
  Future<List<BrokerStats>> getAllBrokerStats({int? limit}) async {
    try {
      Query<Map<String, dynamic>> query = _brokerStatsCollection
          .orderBy('completedDeals', descending: true);
      if (limit != null) {
        query = query.limit(limit);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => BrokerStats.fromMap(doc.data())).toList();
    } catch (e) {
      Logger.error('전체 중개사 통계 조회 실패', error: e);
      return [];
    }
  }

  /// 모든 중개사 통계 스트림 (관리자용)
  Stream<List<BrokerStats>> getAllBrokerStatsStream({int? limit}) {
    Query<Map<String, dynamic>> query = _brokerStatsCollection
        .orderBy('completedDeals', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BrokerStats.fromMap(doc.data())).toList();
    });
  }

  /// 지역별 상위 중개사 조회
  Future<List<BrokerStats>> getTopBrokersByRegion(String region,
      {int limit = 10}) async {
    try {
      final snapshot = await _brokerStatsCollection
          .where('dealsByRegion.$region', isGreaterThan: 0)
          .orderBy('dealsByRegion.$region', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => BrokerStats.fromMap(doc.data())).toList();
    } catch (e) {
      // 인덱스가 없을 경우 전체 조회 후 필터링
      Logger.warning('지역별 인덱스 없음, 전체 조회 후 필터링');
      final allStats = await getAllBrokerStats();
      final filtered = allStats
          .where((s) => (s.dealsByRegion[region] ?? 0) > 0)
          .toList()
        ..sort((a, b) =>
            (b.dealsByRegion[region] ?? 0).compareTo(a.dealsByRegion[region] ?? 0));
      return filtered.take(limit).toList();
    }
  }

  /// 중개사 지표 요약 조회 (판매자에게 표시용)
  Future<BrokerMetricsSummary?> getBrokerMetricsSummary(String brokerId) async {
    final stats = await getBrokerStats(brokerId);
    if (stats == null) return null;
    return BrokerMetricsSummary.fromStats(stats);
  }

  /// 여러 중개사 지표 요약 조회
  Future<List<BrokerMetricsSummary>> getBrokerMetricsSummaries(
      List<String> brokerIds) async {
    final results = <BrokerMetricsSummary>[];
    for (final brokerId in brokerIds) {
      final summary = await getBrokerMetricsSummary(brokerId);
      if (summary != null) {
        results.add(summary);
      }
    }
    return results;
  }

  // ========== 통계 업데이트 ==========

  /// 방문 요청 생성 시 호출
  Future<void> onVisitRequestCreated({
    required String brokerId,
    required String brokerName,
    String? brokerCompany,
  }) async {
    try {
      await _brokerStatsCollection.doc(brokerId).set({
        'brokerId': brokerId,
        'brokerName': brokerName,
        'brokerCompany': brokerCompany,
        'totalRequests': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // createdAt이 없으면 추가
      final doc = await _brokerStatsCollection.doc(brokerId).get();
      if (doc.data()?['createdAt'] == null) {
        await _brokerStatsCollection.doc(brokerId).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Logger.info('방문 요청 생성 통계 업데이트: $brokerId');
    } catch (e) {
      Logger.error('방문 요청 생성 통계 업데이트 실패', error: e);
    }
  }

  /// 방문 요청 응답 시 호출 (판매자가 승인/거절)
  Future<void> onVisitRequestResponded({
    required String brokerId,
    required bool approved,
    required int responseTimeSeconds,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'totalResponseTimeSeconds': FieldValue.increment(responseTimeSeconds),
        'responseCount': FieldValue.increment(1),
      };

      if (approved) {
        updates['approvedRequests'] = FieldValue.increment(1);
      } else {
        updates['rejectedRequests'] = FieldValue.increment(1);
      }

      await _brokerStatsCollection.doc(brokerId).set(updates, SetOptions(merge: true));
      Logger.info('방문 요청 응답 통계 업데이트: $brokerId, approved: $approved');
    } catch (e) {
      Logger.error('방문 요청 응답 통계 업데이트 실패', error: e);
    }
  }

  /// 방문 요청 취소 시 호출 (중개사가 취소)
  Future<void> onVisitRequestCancelled({
    required String brokerId,
  }) async {
    try {
      await _brokerStatsCollection.doc(brokerId).set({
        'brokerId': brokerId,
        'cancelledRequests': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.info('방문 요청 취소 통계 업데이트: $brokerId');
    } catch (e) {
      Logger.error('방문 요청 취소 통계 업데이트 실패', error: e);
    }
  }

  /// 방문 완료 시 호출
  Future<void> onVisitCompleted({
    required String brokerId,
  }) async {
    try {
      await _brokerStatsCollection.doc(brokerId).set({
        'brokerId': brokerId,
        'completedVisits': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.info('방문 완료 통계 업데이트: $brokerId');
    } catch (e) {
      Logger.error('방문 완료 통계 업데이트 실패', error: e);
    }
  }

  /// 노쇼 기록 시 호출
  Future<void> onNoShow({
    required String brokerId,
  }) async {
    try {
      await _brokerStatsCollection.doc(brokerId).set({
        'brokerId': brokerId,
        'noShowCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.info('노쇼 통계 업데이트: $brokerId');
    } catch (e) {
      Logger.error('노쇼 통계 업데이트 실패', error: e);
    }
  }

  /// 거래 완료 시 호출
  Future<void> onDealCompleted({
    required String brokerId,
    required double dealAmount,
    required double proposedPrice, // 최초 제안가
    required double finalPrice, // 최종 거래가
    String? region,
  }) async {
    try {
      final updates = <String, dynamic>{
        'completedDeals': FieldValue.increment(1),
        'totalDealAmount': FieldValue.increment(dealAmount),
        'totalProposedAmount': FieldValue.increment(proposedPrice),
        'totalFinalAmount': FieldValue.increment(finalPrice),
        'priceComparisonCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (region != null && region.isNotEmpty) {
        updates['dealsByRegion.$region'] = FieldValue.increment(1);
      }

      await _brokerStatsCollection.doc(brokerId).set(updates, SetOptions(merge: true));
      Logger.info('거래 완료 통계 업데이트: $brokerId${region != null ? ", region: $region" : ""}');
    } catch (e) {
      Logger.error('거래 완료 통계 업데이트 실패', error: e);
    }
  }

  // ========== 판매자 히스토리 ==========

  /// 판매자 히스토리 조회
  Future<SellerHistory?> getSellerHistory(String sellerId) async {
    try {
      final doc = await _sellerHistoryCollection.doc(sellerId).get();
      if (!doc.exists) return null;
      return SellerHistory.fromMap(doc.data()!);
    } catch (e) {
      Logger.error('판매자 히스토리 조회 실패', error: e);
      return null;
    }
  }

  /// 판매자 히스토리 스트림
  Stream<SellerHistory?> getSellerHistoryStream(String sellerId) {
    return _sellerHistoryCollection.doc(sellerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SellerHistory.fromMap(doc.data()!);
    });
  }

  /// 판매자 히스토리 업데이트 (매물 등록 시)
  Future<void> onPropertyRegistered({
    required String sellerId,
    required String sellerName,
  }) async {
    try {
      await _sellerHistoryCollection.doc(sellerId).set({
        'sellerId': sellerId,
        'sellerName': sellerName,
        'totalProperties': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // createdAt이 없으면 추가
      final doc = await _sellerHistoryCollection.doc(sellerId).get();
      if (doc.data()?['createdAt'] == null) {
        await _sellerHistoryCollection.doc(sellerId).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Logger.info('매물 등록 히스토리 업데이트: $sellerId');
    } catch (e) {
      Logger.error('매물 등록 히스토리 업데이트 실패', error: e);
    }
  }

  /// 거래 완료 시 판매자 히스토리 업데이트
  Future<void> onSellerDealCompleted({
    required String sellerId,
    required String propertyId,
    required String brokerId,
    required String brokerName,
    required double finalPrice,
    required double proposedPrice,
    String? region,
    String? brokerCompany,
    String? address,
    String? transactionType,
  }) async {
    try {
      final doc = await _sellerHistoryCollection.doc(sellerId).get();
      final now = DateTime.now();

      // 거래 기록 생성
      final dealRecord = DealRecord(
        propertyId: propertyId,
        address: address ?? '',
        region: region ?? '',
        initialPrice: proposedPrice,
        finalPrice: finalPrice,
        priceAdjustments: proposedPrice != finalPrice
            ? [
                PriceAdjustment(
                  previousPrice: proposedPrice,
                  newPrice: finalPrice,
                  adjustedAt: now,
                  reason: '최종 거래가',
                ),
              ]
            : [],
        finalBrokerId: brokerId,
        finalBrokerName: brokerName,
        transactionType: transactionType ?? '매매',
        registeredAt: now, // 실제로는 매물 등록일이 필요
        soldAt: now,
        durationDays: 0, // 실제로는 등록일부터 계산 필요
      );

      if (!doc.exists) {
        // 신규 판매자 히스토리 생성
        await _sellerHistoryCollection.doc(sellerId).set({
          'sellerId': sellerId,
          'dealRecords': [dealRecord.toMap()],
          'brokerPerformances': {
            brokerId: BrokerPerformance(
              brokerId: brokerId,
              brokerName: brokerName,
              brokerCompany: brokerCompany,
              totalDeals: 1,
              totalAmount: finalPrice,
              regions: region != null ? [region] : [],
              lastDealAt: now,
            ).toMap(),
          },
          'totalProperties': 1,
          'completedDeals': 1,
          'totalDealAmount': finalPrice,
          'avgDealDurationDays': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final currentHistory = SellerHistory.fromMap(doc.data()!);

        // 거래 기록 추가
        final updatedRecords = [...currentHistory.dealRecords, dealRecord];

        // 중개사 성과 업데이트
        final updatedPerformances =
            Map<String, BrokerPerformance>.from(currentHistory.brokerPerformances);

        if (updatedPerformances.containsKey(brokerId)) {
          final existing = updatedPerformances[brokerId]!;
          updatedPerformances[brokerId] = existing.copyWith(
            totalDeals: existing.totalDeals + 1,
            totalAmount: existing.totalAmount + finalPrice,
            lastDealAt: now,
            regions: region != null
                ? {...existing.regions, region}.toList()
                : existing.regions,
          );
        } else {
          updatedPerformances[brokerId] = BrokerPerformance(
            brokerId: brokerId,
            brokerName: brokerName,
            brokerCompany: brokerCompany,
            totalDeals: 1,
            totalAmount: finalPrice,
            regions: region != null ? [region] : [],
            lastDealAt: now,
          );
        }

        // 평균 거래 기간 계산
        final totalDuration =
            updatedRecords.fold<int>(0, (acc, r) => acc + r.durationDays);
        final avgDuration = updatedRecords.isNotEmpty
            ? totalDuration ~/ updatedRecords.length
            : 0;

        await _sellerHistoryCollection.doc(sellerId).update({
          'dealRecords': updatedRecords.map((r) => r.toMap()).toList(),
          'brokerPerformances':
              updatedPerformances.map((k, v) => MapEntry(k, v.toMap())),
          'completedDeals': FieldValue.increment(1),
          'totalDealAmount': FieldValue.increment(finalPrice),
          'avgDealDurationDays': avgDuration,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      Logger.info('판매자 거래 완료 히스토리 업데이트: $sellerId');
    } catch (e) {
      Logger.error('판매자 거래 완료 히스토리 업데이트 실패', error: e);
    }
  }

  /// 판매자에게 추천할 중개사 목록 (이전 성과 기반)
  Future<List<BrokerPerformance>> getRecommendedBrokersForSeller(
    String sellerId, {
    String? region,
    int limit = 3,
  }) async {
    try {
      final history = await getSellerHistory(sellerId);
      if (history == null) return [];

      if (region != null) {
        return history.getTopBrokersInRegion(region, limit: limit);
      }
      return history.getTopBrokers(limit: limit);
    } catch (e) {
      Logger.error('추천 중개사 조회 실패', error: e);
      return [];
    }
  }

  // ========== 관리자용 집계 ==========

  /// 전체 통계 요약 (관리자 대시보드용)
  Future<Map<String, dynamic>> getOverallStatsSummary() async {
    try {
      final stats = await getAllBrokerStats();

      final totalRequests = stats.fold<int>(0, (acc, s) => acc + s.totalRequests);
      final totalApproved =
          stats.fold<int>(0, (acc, s) => acc + s.approvedRequests);
      final totalDeals = stats.fold<int>(0, (acc, s) => acc + s.completedDeals);
      final totalNoShows = stats.fold<int>(0, (acc, s) => acc + s.noShowCount);
      final totalDealAmount =
          stats.fold<double>(0, (acc, s) => acc + s.totalDealAmount);

      return {
        'totalBrokers': stats.length,
        'totalRequests': totalRequests,
        'totalApproved': totalApproved,
        'totalDeals': totalDeals,
        'totalNoShows': totalNoShows,
        'totalDealAmount': totalDealAmount,
        'avgVisitSuccessRate': totalRequests > 0
            ? totalApproved / totalRequests
            : 0.0,
        'avgNoShowRate': totalApproved > 0 ? totalNoShows / totalApproved : 0.0,
      };
    } catch (e) {
      Logger.error('전체 통계 요약 조회 실패', error: e);
      return {};
    }
  }

  /// 기간별 통계 (관리자용) - 향후 구현
  // Future<Map<String, dynamic>> getStatsByPeriod(...) { }
}
