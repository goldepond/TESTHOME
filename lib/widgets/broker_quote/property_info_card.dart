import 'package:flutter/material.dart';
import 'package:property/models/quote_request.dart';

class PropertyInfoCard extends StatelessWidget {
  final QuoteRequest quote;

  const PropertyInfoCard({
    super.key,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.home,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '매물 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
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
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, size: 18, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        '특이사항',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quote.specialNotes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
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
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isImportant ? Colors.orange[700] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: isImportant ? Colors.orange[900] : const Color(0xFF2C3E50),
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.w600,
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

