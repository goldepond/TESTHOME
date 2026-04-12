import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../api_request/firebase_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/responsive_constants.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../../models/mls_property.dart';
import '../../utils/address_utils.dart';
import '../../utils/formatters.dart';
import '../../utils/logger.dart';
import '../public/public_property_detail_page.dart';

/// 찜 목록 페이지
///
/// 사용자가 북마크한 매물 목록을 보여주는 페이지.
/// 하트 토글로 북마크 제거, 카드 탭으로 매물 상세 이동.
class MyFavoritesPage extends StatefulWidget {
  const MyFavoritesPage({super.key});

  @override
  State<MyFavoritesPage> createState() => _MyFavoritesPageState();
}

class _MyFavoritesPageState extends State<MyFavoritesPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  Set<String> _bookmarkedPropertyIds = {};
  List<MLSProperty> _bookmarkedProperties = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadBookmarkedProperties();
    });
  }

  /// 북마크된 매물 ID 목록을 가져온 뒤 각 매물 문서를 조회
  Future<void> _loadBookmarkedProperties() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final bookmarkIds =
          await _firebaseService.getBookmarks(currentUser.uid);
      if (!mounted) return;

      setState(() {
        _bookmarkedPropertyIds = bookmarkIds.toSet();
      });

      if (bookmarkIds.isEmpty) {
        if (mounted) {
          setState(() {
            _bookmarkedProperties = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 북마크된 매물 문서들을 조회
      final properties = <MLSProperty>[];
      // Firestore whereIn은 최대 30개 제한이므로 청크 분할
      final chunks = _chunkList(bookmarkIds, 30);
      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection('mlsProperties')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          try {
            final property =
                MLSProperty.fromMap(doc.data());
            properties.add(property);
          } catch (error) {
            Logger.warning(
              '매물 파싱 실패',
              metadata: {'docId': doc.id, 'error': error.toString()},
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _bookmarkedProperties = properties;
        _isLoading = false;
      });
    } catch (error) {
      Logger.error('찜 목록 로드 실패', error: error, context: 'MyFavoritesPage');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 리스트를 주어진 크기의 청크로 분할
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// 북마크 토글 (낙관적 업데이트)
  Future<void> _toggleBookmark(String propertyId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 낙관적 업데이트: UI 먼저 반영
    final wasBookmarked = _bookmarkedPropertyIds.contains(propertyId);
    setState(() {
      if (wasBookmarked) {
        _bookmarkedPropertyIds.remove(propertyId);
        _bookmarkedProperties.removeWhere((p) => p.id == propertyId);
      } else {
        _bookmarkedPropertyIds.add(propertyId);
      }
    });

    // 서버 반영
    final result =
        await _firebaseService.toggleBookmark(currentUser.uid, propertyId);

    // 서버 결과와 낙관적 업데이트가 다르면 롤백
    if (mounted && result == wasBookmarked) {
      setState(() {
        if (wasBookmarked) {
          _bookmarkedPropertyIds.add(propertyId);
          // 제거한 매물을 다시 로드해야 하므로 전체 새로고침
          _loadBookmarkedProperties();
        } else {
          _bookmarkedPropertyIds.remove(propertyId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveHelper.getMaxWidth(context);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: Text(
          '찜 목록',
          style: AppTypography.h4.copyWith(color: AirbnbColors.textPrimary),
        ),
        backgroundColor: AirbnbColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AirbnbColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _buildBody(isMobile),
        ),
      ),
    );
  }

  Widget _buildBody(bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookmarkedProperties.isEmpty) {
      return _buildEmptyState();
    }

    final crossAxisCount =
        isMobile ? 1 : (MediaQuery.of(context).size.width ~/ 350).clamp(2, 4);

    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: isMobile ? 280 : null,
        childAspectRatio: isMobile ? 1 : 1.1,
      ),
      itemCount: _bookmarkedProperties.length,
      itemBuilder: (context, index) =>
          _buildPropertyCard(_bookmarkedProperties[index], isMobile),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.favorite_border,
            size: 64,
            color: AirbnbColors.borderLight,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '찜한 매물이 없습니다',
            style: AppTypography.body.copyWith(
              color: AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '관심 있는 매물의 하트를 눌러 저장하세요',
            style: AppTypography.bodySmall.copyWith(
              color: AirbnbColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(MLSProperty property, bool isMobile) {
    final displayAddress = AddressUtils.maskDetailAddress(property.address);
    final isBookmarked = _bookmarkedPropertyIds.contains(property.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PublicPropertyDetailPage(propertyId: property.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AirbnbColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 + 하트 오버레이
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: property.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: property.thumbnailUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildPlaceholder(),
                            errorWidget: (context, url, error) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  // 하트 아이콘 오버레이 (우측 상단)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: GestureDetector(
                      onTap: () => _toggleBookmark(property.id),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          isBookmarked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: isBookmarked
                              ? AirbnbColors.red
                              : AirbnbColors.background,
                          shadows: isBookmarked
                              ? null
                              : const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black54,
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 정보
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 거래유형 + 가격
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AirbnbColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text(
                            property.transactionType,
                            style: AppTypography.caption.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            PriceFormatter.format(property.desiredPrice),
                            style: AppTypography.body.copyWith(color: AirbnbColors.textPrimary, letterSpacing: -0.3, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 주소
                    Text(
                      displayAddress,
                      style: AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // 면적/층수
                    Text(
                      _buildPropertyMeta(property),
                      style: AppTypography.withColor(AppTypography.caption, AirbnbColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AirbnbColors.surface,
      child: const Center(
        child:
            Icon(Icons.home_outlined, size: 40, color: AirbnbColors.textLight),
      ),
    );
  }

  String _buildPropertyMeta(MLSProperty property) {
    final parts = <String>[];
    if (property.area != null) {
      parts.add('${property.area!.toStringAsFixed(1)}m\u00B2');
    }
    if (property.floor != null) {
      parts.add('${property.floor}\uCE35');
    }
    if (property.rooms != null) {
      parts.add('${property.rooms}\uB8F8');
    }
    if (property.buildingName.isNotEmpty) {
      parts.add(property.buildingName);
    }
    return parts.join(' \u00B7 ');
  }
}
