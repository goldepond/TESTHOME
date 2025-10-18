import 'package:flutter/material.dart';
import '../../models/special_clause.dart';
import '../../constants/app_constants.dart';

class SmartClauseRecommendationScreen extends StatefulWidget {
  final Map<String, dynamic> propertyData;
  final Function(List<SpecialClause>) onClausesSelected;

  const SmartClauseRecommendationScreen({
    Key? key,
    required this.propertyData,
    required this.onClausesSelected,
  }) : super(key: key);

  @override
  State<SmartClauseRecommendationScreen> createState() => _SmartClauseRecommendationScreenState();
}

class _SmartClauseRecommendationScreenState extends State<SmartClauseRecommendationScreen> {
  List<SpecialClause> allClauses = [];
  List<SpecialClause> recommendedClauses = [];
  Map<String, bool> selectedClauses = {};
  Map<String, String> clauseTexts = {};

  @override
  void initState() {
    super.initState();
    _initializeClauses();
  }

  void _initializeClauses() {
    // 모든 특약 가져오기
    allClauses = SpecialClauseData.getDefaultClauses();
    
    // 추천 특약 계산
    recommendedClauses = SpecialClauseData.getRecommendedClauses(
      maintenanceFee: widget.propertyData['maintenanceFee'] ?? 0.0,
      hasIndividualMetering: widget.propertyData['hasIndividualMetering'] ?? false,
      buildingType: widget.propertyData['buildingType'] ?? '일반',
      hasJuniorMortgage: widget.propertyData['hasJuniorMortgage'] ?? false,
      buildingAge: widget.propertyData['buildingAge'] ?? 0,
      deposit: widget.propertyData['deposit'] ?? 0.0,
      leaseTerm: widget.propertyData['leaseTerm'] ?? 12,
      hasDefectHistory: widget.propertyData['hasDefectHistory'] ?? false,
      isNewBuilding: widget.propertyData['isNewBuilding'] ?? false,
    );

    // 기본 선택 상태 설정
    for (final clause in allClauses) {
      selectedClauses[clause.id] = clause.isDefaultOn;
      clauseTexts[clause.id] = clause.defaultText;
    }
  }

  void _toggleClause(String clauseId) {
    setState(() {
      selectedClauses[clauseId] = !(selectedClauses[clauseId] ?? false);
    });
  }

  void _showReasonDialog(SpecialClause clause) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${clause.title} - 추천 이유'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '추천 이유:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(clause.reason),
              const SizedBox(height: 16),
              Text(
                '객관적 근거:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(clause.objectiveBasis),
              if (clause.recommendationConditions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '추천 조건:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...clause.recommendationConditions.map((condition) => 
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('• $condition'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showAlternativesDialog(SpecialClause clause) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${clause.title} - 대체안'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '임대인이 거절할 경우 제안할 수 있는 대체안:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...clause.alternatives.map((alternative) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(alternative)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 협상 팁:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    clause.objectiveBasis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showTextEditDialog(SpecialClause clause) {
    final TextEditingController controller = TextEditingController(
      text: clauseTexts[clause.id] ?? clause.defaultText,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${clause.title} - 문구 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '기본 문구에서 날짜·기한 등 변수만 안전하게 편집하세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '특약 문구를 입력하세요',
              ),
            ),
            if (clause.variables.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '수정 가능한 변수:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...clause.variables.entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${entry.key}: ${entry.value}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                clauseTexts[clause.id] = controller.text;
              });
              Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseCard(SpecialClause clause) {
    final isSelected = selectedClauses[clause.id] ?? false;
    final isRecommended = recommendedClauses.contains(clause);
    final isDefaultOn = clause.isDefaultOn;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            clause.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isDefaultOn) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '기본',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '추천됨',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clause.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 토글 스위치
                Column(
                  children: [
                    Switch(
                      value: isSelected,
                      onChanged: (value) => _toggleClause(clause.id),
                      activeThumbColor: AppColors.kBrown,
                    ),
                    Text(
                      isSelected ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // 액션 버튼들
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReasonDialog(clause),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('왜 추천됐나요?'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAlternativesDialog(clause),
                    icon: const Icon(Icons.help_outline, size: 16),
                    label: const Text('대체안'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTextEditDialog(clause),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('문구 수정'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedClauses.values.where((selected) => selected).length;
    final totalCount = allClauses.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('스마트 특약 추천'),
        backgroundColor: AppColors.kBrown,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 상단 안내
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha:0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lightbulb, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '추천 특약',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '계약서에 꼭 넣어야 할 보호 특약을 자동 추천해드립니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  '선택된 특약: $selectedCount/$totalCount개',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // 체크리스트 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: allClauses.length,
              itemBuilder: (context, index) {
                return _buildClauseCard(allClauses[index]);
              },
            ),
          ),
          
          // 하단 버튼들
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha:0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // 모든 특약 선택 해제
                          setState(() {
                            for (final clause in allClauses) {
                              selectedClauses[clause.id] = false;
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('모두 해제'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 선택된 특약들을 계약서에 추가
                          final selectedClauseList = allClauses
                              .where((clause) => selectedClauses[clause.id] ?? false)
                              .map((clause) => clause.copyWith(
                                    defaultText: clauseTexts[clause.id] ?? clause.defaultText,
                                  ))
                              .toList();
                          
                          widget.onClausesSelected(selectedClauseList);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('계약서에 추가'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '기본 ON 상태의 특약은 임차인 보호에 가장 중요한 조항입니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

