import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';

class ContractStep1BasicInfo extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onNext;
  final Function(Map<String, dynamic>) onDataUpdate;

  const ContractStep1BasicInfo({
    Key? key,
    this.initialData,
    required this.onNext,
    required this.onDataUpdate,
  }) : super(key: key);

  @override
  State<ContractStep1BasicInfo> createState() => _ContractStep1BasicInfoState();
}

class _ContractStep1BasicInfoState extends State<ContractStep1BasicInfo> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
      _autoFillFromParsedData(widget.initialData!);
    }
  }

  void _autoFillFromParsedData(Map<String, dynamic> data) {
    // 임대인 정보 자동입력
    final ownerRaw = data['ownership']?['ownerRaw']?.toString() ?? '';
    final ownerLines = ownerRaw.split('\n').where((String e) => e.trim().isNotEmpty).toList();
    if (ownerLines.length >= 2) {
      final owner1 = ownerLines[0].split(' ');
      _formData['landlord_name'] = owner1.length > 1 ? owner1[1] : '임대인';
      _formData['landlord_id'] = owner1.length > 2 ? owner1[2] : '';
      _formData['landlord_address'] = ownerLines[1];
    } else {
      _formData['landlord_name'] = '임대인';
      _formData['landlord_id'] = '';
      _formData['landlord_address'] = '';
    }
    
    // 부동산 정보 자동입력
    _formData['property_address'] = data['header']?['realtyDesc'] ?? '';
    _formData['land_purpose'] = data['areas']?['land']?['purpose'] ?? '';
    _formData['land_area'] = data['areas']?['land']?['area'] ?? '0';
    
    // building_structure 정제
    String rawStructure = data['areas']?['building']?['structure'] ?? '';
    rawStructure = rawStructure
        .replaceAll(RegExp(r'\|.*'), '') // |로 시작하는 법조문 제거
        .replaceAll(RegExp(r'\[.*\]'), '') // [도로명주소] 등 제거
        .replaceAll(RegExp(r'\n+'), ' ') // 줄바꿈을 공백으로
        .replaceAll(RegExp(r'[^\uAC00-\uD7A3a-zA-Z0-9\s\.\-]'), ''); // 한글, 영문, 숫자, 공백, . -만 남김
    _formData['building_structure'] = rawStructure.trim();
    
    // 건물 면적(층별) 예시: 15층, 16층만
    final floors = data['areas']?['building']?['floors'] ?? [];
    String rentalPart = '', rentalArea = '';
    for (final f in floors) {
      if (f['floor'] == '15층' || f['floor'] == '16층') {
        rentalPart += '${f['floor']} ';
        String area = f['area']?.toString() ?? '';
        area = area.replaceAll(RegExp(r'[^\d\.]'), ''); // 숫자와 소수점만 남김
        rentalArea += '$area ';
      }
    }
    _formData['rental_part'] = rentalPart.trim();
    _formData['rental_area'] = rentalArea.trim().isEmpty ? '0' : rentalArea.trim();
    
    // 나머지 필드도 기본값 처리
    _formData['tenant_name'] = _formData['tenant_name'] ?? '임차인';
    _formData['tenant_address'] = _formData['tenant_address'] ?? '';
    _formData['landlord_phone'] = _formData['landlord_phone'] ?? '';
    _formData['tenant_phone'] = _formData['tenant_phone'] ?? '';
    _formData['building_area'] = _formData['building_area'] ?? '0';
    _formData['management_fee'] = _formData['management_fee'] ?? '0';
    _formData['management_details'] = _formData['management_details'] ?? '';
    _formData['special_terms'] = _formData['special_terms'] ?? '';
    _formData['repair_content'] = _formData['repair_content'] ?? '';
    _formData['repair_completion_date'] = _formData['repair_completion_date'] ?? '';
    _formData['contract_type'] = _formData['contract_type'] ?? 'new';
    _formData['rental_type'] = _formData['rental_type'] ?? 'jeonse';
    _formData['deposit'] = _formData['deposit'] ?? '0';
    _formData['contract_date'] = _formData['contract_date'] ?? DateTime.now().toIso8601String().split('T')[0];
    
    setState(() {}); // UI 업데이트
  }

  void _saveAndNext() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onDataUpdate(_formData);
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 기본 정보 섹션
            _buildSectionCard(
              title: '기본 정보',
              icon: Icons.person_outline,
              children: [
                _formGrid([
                  _textField('임대인 성명', 'landlord_name', required: true),
                  _textField('임대인 주소', 'landlord_address'),
                  _textField('임대인 연락처', 'landlord_phone', keyboardType: TextInputType.phone),
                  _textField('임대인 주민등록번호', 'landlord_id'),
                ]),
              ],
            ),
            const SizedBox(height: 20),

            // 부동산 정보 섹션
            _buildSectionCard(
              title: '부동산 정보',
              icon: Icons.home_outlined,
              children: [
                _formGrid([
                  _textField('소재지 (도로명주소)', 'property_address', required: true, fullWidth: true),
                  _textField('토지 지목', 'land_purpose'),
                  _textField('토지 면적 (㎡)', 'land_area', keyboardType: TextInputType.number),
                  _textField('건물 구조‧용도', 'building_structure'),
                  _textField('건물 면적 (㎡)', 'building_area', keyboardType: TextInputType.number),
                  _textField('임차할부분', 'rental_part', helpText: '상세주소가 있는 경우 동‧층‧호 정확히 기재'),
                  _textField('임차할부분 면적 (㎡)', 'rental_area', keyboardType: TextInputType.number),
                ]),
              ],
            ),
            const SizedBox(height: 32),

            // 다음 단계 버튼
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.kBrown,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kBrown.withValues(alpha:0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saveAndNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  '다음 단계',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
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
                  color: AppColors.kBrown.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.kBrown,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
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

  Widget _formGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Wrap(
          spacing: 16,
          runSpacing: 8,
          children: children.map((w) => SizedBox(
            width: isWide ? (w is _FullWidthField ? constraints.maxWidth : (constraints.maxWidth - 16) / 2) : constraints.maxWidth,
            child: w,
          )).toList(),
        );
      },
    );
  }

  Widget _textField(String label, String key, {bool required = false, TextInputType? keyboardType, int maxLines = 1, bool fullWidth = false, String? helpText}) {
    return _FullWidthField(
      fullWidth: fullWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          initialValue: _formData[key]?.toString(),
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label + (required ? ' *' : ''),
            helperText: helpText,
            helperStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            labelStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.kBrown, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[300]!),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF2C3E50),
          ),
          validator: (v) {
            if (required && (v == null || v.isEmpty)) {
              return '$label을(를) 입력해주세요';
            }
            return null;
          },
          onSaved: (v) => _formData[key] = v ?? (key.contains('area') || key.contains('fee') || key.contains('deposit') ? '0' : ''),
        ),
      ),
    );
  }
}

class _FullWidthField extends StatelessWidget {
  final Widget child;
  final bool fullWidth;
  const _FullWidthField({required this.child, this.fullWidth = false});
  @override
  Widget build(BuildContext context) => child;
}
