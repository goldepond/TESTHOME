import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// 검색 분석 서비스 - 시세 조회 통계 수집
class SearchAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 시세 조회 이벤트 로깅
  ///
  /// [lawdCd] 법정동코드 앞 5자리
  /// [buildingName] 건물명 (아파트명 등)
  /// [transactionType] 거래유형 (매매/전세/월세)
  /// [address] 전체 주소
  static Future<void> logMarketPriceSearch({
    required String lawdCd,
    required String transactionType,
    String? buildingName,
    String? address,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      await _firestore.collection('analytics_market_price').add({
        'lawdCd': lawdCd,
        'buildingName': buildingName,
        'transactionType': transactionType,
        'address': address,
        'userId': user?.uid,
        'isLoggedIn': user != null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 지역별 카운트 증가 (집계용)
      await _incrementRegionCount(lawdCd, transactionType);
    } catch (e) {
      Logger.warning('시세 조회 로깅 실패: $e');
    }
  }

  /// 지역별 조회 카운트 증가
  static Future<void> _incrementRegionCount(String lawdCd, String transactionType) async {
    try {
      final docRef = _firestore.collection('analytics_region_counts').doc(lawdCd);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          final data = snapshot.data() ?? {};
          final totalCount = (data['totalCount'] ?? 0) + 1;
          final typeCount = (data['${transactionType}Count'] ?? 0) + 1;

          transaction.update(docRef, {
            'totalCount': totalCount,
            '${transactionType}Count': typeCount,
            'lastSearched': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(docRef, {
            'lawdCd': lawdCd,
            'totalCount': 1,
            '${transactionType}Count': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSearched': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      // 카운트 실패는 무시 (핵심 기능 아님)
    }
  }

  /// 인기 지역 조회 (상위 N개)
  static Future<List<RegionPopularity>> getPopularRegions({
    int limit = 10,
    String? transactionType,
  }) async {
    try {
      final query = _firestore
          .collection('analytics_region_counts')
          .orderBy('totalCount', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RegionPopularity(
          lawdCd: data['lawdCd'] ?? doc.id,
          totalCount: data['totalCount'] ?? 0,
          saleCount: data['매매Count'] ?? 0,
          jeonseCount: data['전세Count'] ?? 0,
          monthlyRentCount: data['월세Count'] ?? 0,
        );
      }).toList();
    } catch (e) {
      Logger.warning('인기 지역 조회 실패: $e');
      return [];
    }
  }

  /// 특정 지역의 최근 조회 수 (24시간 내)
  static Future<int> getRecentSearchCount(String lawdCd) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));

      final snapshot = await _firestore
          .collection('analytics_market_price')
          .where('lawdCd', isEqualTo: lawdCd)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 특정 건물의 최근 조회 수 (24시간 내)
  static Future<int> getBuildingSearchCount(String lawdCd, String buildingName) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));

      final snapshot = await _firestore
          .collection('analytics_market_price')
          .where('lawdCd', isEqualTo: lawdCd)
          .where('buildingName', isEqualTo: buildingName)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 중개사용: 지역별 관심도 조회
  /// 중개사가 어떤 지역의 매물에 관심이 많은지 파악
  static Future<Map<String, dynamic>> getAgentInterestStats(String lawdCd) async {
    try {
      // 최근 7일간의 조회 통계
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('analytics_market_price')
          .where('lawdCd', isEqualTo: lawdCd)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();

      final totalSearches = snapshot.docs.length;
      final loggedInSearches = snapshot.docs.where((doc) => doc.data()['isLoggedIn'] == true).length;

      final Map<String, int> byTransactionType = {};
      for (final doc in snapshot.docs) {
        final type = doc.data()['transactionType'] as String? ?? '기타';
        byTransactionType[type] = (byTransactionType[type] ?? 0) + 1;
      }

      return {
        'totalSearches': totalSearches,
        'loggedInSearches': loggedInSearches,
        'guestSearches': totalSearches - loggedInSearches,
        'byTransactionType': byTransactionType,
        'period': '최근 7일',
      };
    } catch (e) {
      Logger.warning('관심도 통계 조회 실패: $e');
      return {};
    }
  }
}

/// 지역 인기도 모델
class RegionPopularity {
  final String lawdCd;
  final int totalCount;
  final int saleCount;
  final int jeonseCount;
  final int monthlyRentCount;

  const RegionPopularity({
    required this.lawdCd,
    required this.totalCount,
    required this.saleCount,
    required this.jeonseCount,
    required this.monthlyRentCount,
  });
}
