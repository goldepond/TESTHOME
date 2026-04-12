import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/constants/typography.dart';

class PropertyInfoCard extends StatelessWidget {
  final QuoteRequest quote;

  const PropertyInfoCard({
    required this.quote, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AirbnbColors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.orange.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AirbnbColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.home,
                  color: AirbnbColors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
                Expanded(
                child: Text(
                  '매물 정보',
                  style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 매물 유형
          if (quote.propertyType != null && quote.propertyType!.isNotEmpty)
            _buildPropertyInfoRow(
              icon: Icons.category,
              label: '매물 유형',
              value: quote.propertyType!,
            ),
          // 매물 주소 (전체 주소)
          if (quote.propertyAddress != null && quote.propertyAddress!.isNotEmpty) ...[
            _buildPropertyInfoRow(
              icon: Icons.location_on,
              label: '매물 주소',
              value: quote.propertyAddress!,
              isImportant: true,
            ),
            // 주소에서 동/호 파싱해서 표시
            Builder(
              builder: (context) {
                // 주소에서 동/호 정보 추출 시도
                final address = quote.propertyAddress!;
                
                // 주소를 공백으로 분리하여 마지막 부분에서 동/호 찾기
                // 예: "서울특별시 동대문구 답십리로 130 (답십리동, 래미안위브) 제211동 제1506호"
                final dongHoMatch = RegExp(r'제?\s*(\d+동)\s*제?\s*(\d+호)?', caseSensitive: false).firstMatch(address);
                String? dong, ho;
                
                if (dongHoMatch != null) {
                  dong = dongHoMatch.group(1);
                  ho = dongHoMatch.group(2);
                } else {
                  // 다른 형식 시도: "211동 1506호"
                  final simpleMatch = RegExp(r'(\d+동)\s*(\d+호)?', caseSensitive: false).firstMatch(address);
                  if (simpleMatch != null) {
                    dong = simpleMatch.group(1);
                    ho = simpleMatch.group(2);
                  }
                }
                
                if (dong != null && dong.isNotEmpty) {
                  return Column(
                    children: [
                      _buildPropertyInfoRow(
                        icon: Icons.apartment,
                        label: '동',
                        value: dong,
                        isImportant: true,
                      ),
                      if (ho != null && ho.isNotEmpty)
                        _buildPropertyInfoRow(
                          icon: Icons.home,
                          label: '호수',
                          value: ho,
                          isImportant: true,
                        ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          // 전용면적
          if (quote.propertyArea != null && quote.propertyArea!.isNotEmpty)
            _buildPropertyInfoRow(
              icon: Icons.square_foot,
              label: '전용면적',
              value: '${quote.propertyArea}㎡',
            ),
          // 희망가
          if (quote.desiredPrice != null && quote.desiredPrice!.isNotEmpty)
            _buildPropertyInfoRow(
              icon: Icons.attach_money,
              label: '희망가',
              value: quote.desiredPrice!,
              isImportant: true,
            ),
          // 목표기간
          if (quote.targetPeriod != null && quote.targetPeriod!.isNotEmpty)
            _buildPropertyInfoRow(
              icon: Icons.calendar_today,
              label: '목표기간',
              value: quote.targetPeriod!,
            ),
          // 세입자 여부
          if (quote.hasTenant != null)
            _buildPropertyInfoRow(
              icon: Icons.people,
              label: '세입자 여부',
              value: quote.hasTenant! ? '있음' : '없음',
            ),
          // 특이사항
          if (quote.specialNotes != null && quote.specialNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AirbnbColors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AirbnbColors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, size: 18, color: AirbnbColors.orange),
                      const SizedBox(width: 8),
                        Text(
                        '특이사항',
                        style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quote.specialNotes!,
                    style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertyInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isImportant = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isImportant 
                  ? AirbnbColors.orange.withValues(alpha: 0.1)
                  : AirbnbColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isImportant ? AirbnbColors.orange : AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:  AppTypography.caption.copyWith(color: AirbnbColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.withColor(AppTypography.body, isImportant ? AirbnbColors.orange : AirbnbColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

