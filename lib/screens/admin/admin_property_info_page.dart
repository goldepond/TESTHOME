import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';

class AdminPropertyInfoPage extends StatelessWidget {
  final Property property;

  const AdminPropertyInfoPage({
    super.key,
    required this.property,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '매물 전체 정보',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.kBrown,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기본 정보 섹션
            _buildInfoSection(
              title: '기본 정보',
              icon: Icons.info_outline,
              color: Colors.blue,
              children: [
                _buildInfoRow('주소', property.address),
                if (property.buildingName != null && property.buildingName!.isNotEmpty)
                  _buildInfoRow('건물명', property.buildingName!),
                if (property.buildingType != null && property.buildingType!.isNotEmpty)
                  _buildInfoRow('건물 유형', property.buildingType!),
                if (property.totalFloors != null)
                  _buildInfoRow('전체 층수', '${property.totalFloors}층'),
                if (property.floor != null)
                  _buildInfoRow('해당 층', '${property.floor}층'),
                if (property.area != null)
                  _buildInfoRow('면적', '${property.area}㎡'),
                if (property.structure != null && property.structure!.isNotEmpty)
                  _buildInfoRow('구조', property.structure!),
                if (property.buildingYear != null && property.buildingYear!.isNotEmpty)
                  _buildInfoRow('건축년도', property.buildingYear!),
                _buildInfoRow('거래 유형', property.transactionType),
                _buildInfoRow('가격', '${property.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원'),
                _buildInfoRow('계약 상태', property.contractStatus),
              ],
            ),

            const SizedBox(height: 16),

            // 등기부등본 정보 섹션
            if (property.registerData.isNotEmpty)
              _buildInfoSection(
                title: '등기부등본 정보',
                icon: Icons.description_outlined,
                color: Colors.green,
                children: [
                  if (property.docTitle != null && property.docTitle!.isNotEmpty)
                    _buildInfoRow('문서 제목', property.docTitle!),
                  if (property.officeName != null && property.officeName!.isNotEmpty)
                    _buildInfoRow('발급기관', property.officeName!),
                  if (property.publishDate != null && property.publishDate!.isNotEmpty)
                    _buildInfoRow('발급일', property.publishDate!),
                  if (property.publishNo != null && property.publishNo!.isNotEmpty)
                    _buildInfoRow('발급번호', property.publishNo!),
                  if (property.uniqueNo != null && property.uniqueNo!.isNotEmpty)
                    _buildInfoRow('고유번호', property.uniqueNo!),
                  if (property.issueNo != null && property.issueNo!.isNotEmpty)
                    _buildInfoRow('발행번호', property.issueNo!),
                ],
              ),

            const SizedBox(height: 16),

            // 소유권 정보 섹션
            if (property.ownerName != null && property.ownerName!.isNotEmpty)
              _buildInfoSection(
                title: '소유권 정보',
                icon: Icons.person_outline,
                color: Colors.purple,
                children: [
                  _buildInfoRow('소유자명', property.ownerName!),
                  if (property.ownershipRatio != null && property.ownershipRatio!.isNotEmpty)
                    _buildInfoRow('소유지분', property.ownershipRatio!),
                  if (property.receiptDate != null && property.receiptDate!.isNotEmpty)
                    _buildInfoRow('접수일', property.receiptDate!),
                  if (property.cause != null && property.cause!.isNotEmpty)
                    _buildInfoRow('원인', property.cause!),
                  if (property.purpose != null && property.purpose!.isNotEmpty)
                    _buildInfoRow('목적', property.purpose!),
                ],
              ),

            const SizedBox(height: 16),

            // 토지 정보 섹션
            if (property.landArea != null || (property.landPurpose != null && property.landPurpose!.isNotEmpty))
              _buildInfoSection(
                title: '토지 정보',
                icon: Icons.landscape_outlined,
                color: Colors.brown,
                children: [
                  if (property.landArea != null)
                    _buildInfoRow('토지 면적', '${property.landArea}㎡'),
                  if (property.landPurpose != null && property.landPurpose!.isNotEmpty)
                    _buildInfoRow('토지 지목', property.landPurpose!),
                  if (property.landNumber != null && property.landNumber!.isNotEmpty)
                    _buildInfoRow('토지번호', property.landNumber!),
                  if (property.landRatio != null && property.landRatio!.isNotEmpty)
                    _buildInfoRow('토지지분', property.landRatio!),
                  if (property.landUse != null && property.landUse!.isNotEmpty)
                    _buildInfoRow('토지용도', property.landUse!),
                  if (property.landCategory != null && property.landCategory!.isNotEmpty)
                    _buildInfoRow('토지분류', property.landCategory!),
                ],
              ),

            const SizedBox(height: 16),

            // 중개업자 정보 섹션
            if (property.brokerInfo != null)
              _buildInfoSection(
                title: '중개업자 정보',
                icon: Icons.business_outlined,
                color: Colors.orange,
                children: [
                  if (property.brokerInfo!['broker_name'] != null && property.brokerInfo!['broker_name'].toString().isNotEmpty)
                    _buildInfoRow('대표 중개업자명', property.brokerInfo!['broker_name']),
                  if (property.brokerInfo!['broker_phone'] != null && property.brokerInfo!['broker_phone'].toString().isNotEmpty)
                    _buildInfoRow('연락처', property.brokerInfo!['broker_phone']),
                  if (property.brokerInfo!['broker_address'] != null && property.brokerInfo!['broker_address'].toString().isNotEmpty)
                    _buildInfoRow('주소', property.brokerInfo!['broker_address']),
                  if (property.brokerInfo!['broker_license_number'] != null && property.brokerInfo!['broker_license_number'].toString().isNotEmpty)
                    _buildInfoRow('등록번호', property.brokerInfo!['broker_license_number']),
                  if (property.brokerInfo!['broker_office_name'] != null && property.brokerInfo!['broker_office_name'].toString().isNotEmpty)
                    _buildInfoRow('사무소명', property.brokerInfo!['broker_office_name']),
                  if (property.brokerInfo!['broker_office_address'] != null && property.brokerInfo!['broker_office_address'].toString().isNotEmpty)
                    _buildInfoRow('사무소 주소', property.brokerInfo!['broker_office_address']),
                ],
              ),

            const SizedBox(height: 16),

            // 상세 정보 섹션
            if (property.detailFormData != null && property.detailFormData!.isNotEmpty)
              _buildInfoSection(
                title: '상세 정보',
                icon: Icons.edit_note_outlined,
                color: Colors.teal,
                children: _buildDetailFormData(property.detailFormData!),
              ),

            const SizedBox(height: 16),

            // 특약사항 섹션
            if (property.selectedClauses != null && property.selectedClauses!.isNotEmpty)
              _buildInfoSection(
                title: '특약사항',
                icon: Icons.article_outlined,
                color: Colors.indigo,
                children: _buildSelectedClauses(property.selectedClauses!),
              ),

            const SizedBox(height: 16),

            // 시스템 정보 섹션
            _buildInfoSection(
              title: '시스템 정보',
              icon: Icons.settings_outlined,
              color: Colors.grey,
              children: [
                _buildInfoRow('등록자', property.registeredByName ?? '알 수 없음'),
                _buildInfoRow('등록일', _formatDate(property.createdAt)),
                if (property.updatedAt != null)
                  _buildInfoRow('수정일', _formatDate(property.updatedAt!)),
                if (property.firestoreId != null)
                  _buildInfoRow('문서 ID', property.firestoreId!),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailFormData(Map<String, dynamic> detailData) {
    List<Widget> widgets = [];
    
    detailData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        String displayName = _getFormFieldDisplayName(key);
        String displayValue = _formatFormFieldValue(value);
        
        widgets.add(_buildInfoRow(displayName, displayValue));
      }
    });
    
    return widgets;
  }

  List<Widget> _buildSelectedClauses(Map<String, bool> clauses) {
    List<Widget> widgets = [];
    
    clauses.forEach((key, value) {
      if (value == true) {
        String displayName = _getClauseDisplayName(key);
        widgets.add(_buildInfoRow(displayName, '선택됨'));
      }
    });
    
    return widgets;
  }

  String _getFormFieldDisplayName(String key) {
    switch (key) {
      case 'property_address': return '매물 주소';
      case 'rental_type': return '임대차 유형';
      case 'deposit': return '보증금';
      case 'monthly_rent': return '월세';
      case 'management_fee': return '관리비';
      case 'landlord_name': return '임대인 성명';
      case 'tenant_name': return '임차인 성명';
      case 'tenant_phone': return '임차인 연락처';
      case 'tenant_address': return '임차인 주소';
      case 'tenant_id': return '임차인 주민등록번호';
      case 'deal_type': return '거래 방식';
      case 'contract_type': return '계약 유형';
      case 'special_terms': return '특약사항';
      case 'has_expected_tenant': return '예정된 임차인';
      default: return key;
    }
  }

  String _formatFormFieldValue(dynamic value) {
    if (value is bool) {
      return value ? '예' : '아니오';
    }
    return value.toString();
  }

  String _getClauseDisplayName(String key) {
    switch (key) {
      case 'dispute_mediation': return '분쟁조정 특약';
      case 'termination_right': return '해지권 특약';
      case 'overdue_exception': return '연체 관련 특약';
      default: return key;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

