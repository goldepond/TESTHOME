import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/address_utils.dart';
import 'dart:convert';

class ContractStep5Registration extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onPrevious;
  final String? userName;
  final String? propertyId;
  final String transactionMethod; // 'direct' or 'broker'

  const ContractStep5Registration({
    Key? key,
    this.initialData,
    required this.onPrevious,
    this.userName,
    this.propertyId,
    required this.transactionMethod,
  }) : super(key: key);

  @override
  State<ContractStep5Registration> createState() => _ContractStep5RegistrationState();
}

class _ContractStep5RegistrationState extends State<ContractStep5Registration> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
    // 기본값 설정
    _formData['has_expected_tenant'] = _formData['has_expected_tenant'] ?? false;
    _formData['tenant_name'] = _formData['tenant_name'] ?? '임차인';
    _formData['tenant_address'] = _formData['tenant_address'] ?? '';
    _formData['tenant_phone'] = _formData['tenant_phone'] ?? '';
    _formData['tenant_id'] = _formData['tenant_id'] ?? '';
    _formData['contract_date'] = _formData['contract_date'] ?? DateTime.now().toIso8601String().split('T')[0];
  }

  Future<void> _registerProperty() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        if (widget.transactionMethod == 'direct') {
          // 직거래의 경우 바로 매물 등록
          await _registerAsComplete();
        } else {
          // 중개업자 거래의 경우 보류 상태로 등록
          await _registerAsPending();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('등록 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _registerAsComplete() async {
    final address = _formData['property_address'] ?? '';
    final addressCity = AddressUtils.extractCityFromAddress(address);
    
    final property = Property(
      id: null, // Firestore ID is handled by the service
      address: address,
      addressCity: addressCity,
      transactionType: _formData['rental_type'] ?? 'jeonse',
      price: int.tryParse(_formData['deposit'] ?? '0') ?? 0,
      description: _formData['special_terms'] ?? '',
      contractStatus: _formData['has_expected_tenant'] == true ? '예약' : '작성 완료', // 예정된 임차인이 있으면 예약, 없으면 작성 완료
      mainContractor: _formData['landlord_name'] ?? '',
      contractor: _formData['tenant_name'] ?? '',
      registeredBy: widget.userName ?? '',
      registeredByName: widget.userName ?? '',
      // 모든 폼 데이터를 detailFormData에 저장
      detailFormData: _formData,
      detailFormJson: json.encode(_formData),
      // 선택된 특약사항들을 별도로 저장
      selectedClauses: {
        'dispute_mediation': _formData['clause_dispute_mediation'] ?? false,
        'termination_right': _formData['clause_termination_right'] ?? false,
        'overdue_exception': _formData['clause_overdue_exception'] ?? false,
      },
    );

    if (widget.propertyId != null) {
      await _firebaseService.updateProperty(widget.propertyId!, property);
    } else {
      await _firebaseService.addProperty(property);
    }

    if (mounted) {
      _showDirectTransactionCompleteDialog();
    }
  }

  Future<void> _registerAsPending() async {
    final address = _formData['property_address'] ?? '';
    final addressCity = AddressUtils.extractCityFromAddress(address);
    
    final property = Property(
      id: null, // Firestore ID is handled by the service
      address: address,
      addressCity: addressCity,
      transactionType: _formData['rental_type'] ?? 'jeonse',
      price: int.tryParse(_formData['deposit'] ?? '0') ?? 0,
      description: _formData['special_terms'] ?? '',
      contractStatus: '보류', // 중개업자 거래 시 보류 상태
      mainContractor: _formData['landlord_name'] ?? '',
      contractor: _formData['tenant_name'] ?? '',
      registeredBy: widget.userName ?? '',
      registeredByName: widget.userName ?? '',
      // 모든 폼 데이터를 detailFormData에 저장
      detailFormData: _formData,
      detailFormJson: json.encode(_formData),
      // 선택된 특약사항들을 별도로 저장
      selectedClauses: {
        'dispute_mediation': _formData['clause_dispute_mediation'] ?? false,
        'termination_right': _formData['clause_termination_right'] ?? false,
        'overdue_exception': _formData['clause_overdue_exception'] ?? false,
      },
      brokerInfo: _formData['deal_type'] == 'broker' ? {
        'broker_name': _formData['broker_name'] ?? '',
        'broker_phone': _formData['broker_phone'] ?? '',
        'broker_address': _formData['broker_address'] ?? '',
        'broker_license_number': _formData['broker_license_number'] ?? '',
        'broker_office_name': _formData['broker_office_name'] ?? '',
        'broker_office_address': _formData['broker_office_address'] ?? '',
      } : null,
      brokerId: null, // brokerInfo로만 관리하므로 brokerId는 사용하지 않음
    );

    // 디버깅: broker 정보 확인
    print('🔍 [Property Registration] deal_type: ${_formData['deal_type']}');
    print('🔍 [Property Registration] broker_license_number: ${_formData['broker_license_number']}');
    print('🔍 [Property Registration] property.brokerInfo: ${property.brokerInfo}');

    if (widget.propertyId != null) {
      await _firebaseService.updateProperty(widget.propertyId!, property);
    } else {
      await _firebaseService.addProperty(property);
    }

    if (mounted) {
      // 중개업자에게 전송 완료 메시지
      _showBrokerNotificationDialog();
    }
  }

  void _showDirectTransactionCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('매물 등록 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('직거래 계약서 작성이 완료되었습니다.'),
            const SizedBox(height: 16),
            Text('임대인: ${_formData['landlord_name'] ?? ''}'),
            Text('임차인: ${_formData['tenant_name'] ?? ''}'),
            Text('부동산: ${_formData['property_address'] ?? ''}'),
            const SizedBox(height: 16),
            const Text(
              '매물이 성공적으로 등록되었습니다.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 계약서 작성 화면 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showBrokerNotificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('중개업자 전송 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('담당 중개업자에게 계약 정보가 전송되었습니다.'),
            const SizedBox(height: 16),
            Text('중개업자: ${_formData['broker_name'] ?? ''}'),
            Text('연락처: ${_formData['broker_phone'] ?? ''}'),
            const SizedBox(height: 16),
            const Text(
              '매물 상태가 "보류"로 등록되었습니다.\n중개업자의 검토 후 계약이 진행됩니다.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 계약서 작성 화면 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 등록 정보 요약
            _sectionTitle('등록 정보 요약'),
            _buildSummaryCard(),
            const SizedBox(height: 24),

            // 거래 방식별 안내
            _buildTransactionMethodInfo(),
            const SizedBox(height: 24),

            // 임차인 정보 (직거래의 경우)
            if (widget.transactionMethod == 'direct') ...[
              _sectionTitle('임차인 정보'),
              _formGrid([
                _radioGroup('예정된 임차인이 있습니까?', 'has_expected_tenant', [
                  {'label': '예', 'value': true},
                  {'label': '아니오', 'value': false},
                ], required: true),
              ]),
              const SizedBox(height: 16),
              
              // 예정된 임차인이 있는 경우에만 표시
              if (_formData['has_expected_tenant'] == true) ...[
                _formGrid([
                  _textField('임차인 성명', 'tenant_name', required: true),
                  _textField('임차인 주소', 'tenant_address', required: true),
                  _textField('임차인 연락처', 'tenant_phone', keyboardType: TextInputType.phone, required: true),
                  _textField('임차인 주민등록번호', 'tenant_id'),
                ]),
              ],
              const SizedBox(height: 24),
            ],

            // 작성일자
            _sectionTitle('작성일자'),
            _dateField('계약서 작성일', 'contract_date'),
            const SizedBox(height: 32),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : widget.onPrevious,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('이전 단계'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerProperty,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.kBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.transactionMethod == 'direct' ? '매물 등록' : '중개업자 전송'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('임대인', _formData['landlord_name'] ?? ''),
            _summaryRow('부동산 주소', _formData['property_address'] ?? ''),
            _summaryRow('계약 종류', _getContractTypeText(_formData['contract_type'])),
            _summaryRow('임대차 유형', _getRentalTypeText(_formData['rental_type'])),
            _summaryRow('보증금/전세금', '${_formData['deposit'] ?? '0'}원'),
            if (_formData['rental_type'] == 'monthly')
              _summaryRow('월 임대료', '${_formData['monthly_rent'] ?? '0'}원'),
            _summaryRow('거래 방식', _getTransactionMethodText(_formData['deal_type'])),
            if (_formData['deal_type'] == 'broker')
              _summaryRow('중개업자', _formData['broker_name'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionMethodInfo() {
    if (widget.transactionMethod == 'direct') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '직거래 등록',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '다음 단계에서 상세한 시설 정보를 입력하고\n최종 계약서를 완성합니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  '중개업자 전송',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '담당 중개업자에게 계약 정보를 전송하고\n매물 상태가 "보류"로 등록됩니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }
  }

  String _getContractTypeText(String? type) {
    switch (type) {
      case 'new': return '신규 계약';
      case 'renewal': return '합의에 의한 재계약';
      case 'extension': return '계약갱신요구권 행사에 의한 갱신계약';
      default: return '신규 계약';
    }
  }

  String _getRentalTypeText(String? type) {
    switch (type) {
      case 'jeonse': return '전세';
      case 'monthly': return '보증금 있는 월세';
      default: return '전세';
    }
  }

  String _getTransactionMethodText(String? type) {
    switch (type) {
      case 'direct': return '직거래';
      case 'broker': return '중개업자';
      default: return '직거래';
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
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
            width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
            child: w,
          )).toList(),
        );
      },
    );
  }

  Widget _textField(String label, String key, {bool required = false, TextInputType? keyboardType, int maxLines = 1, String? helpText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: _formData[key]?.toString(),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label + (required ? ' *' : ''),
          helperText: helpText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        style: const TextStyle(fontSize: 16),
        validator: (v) {
          if (required && (v == null || v.isEmpty)) {
            return '$label을(를) 입력해주세요';
          }
          return null;
        },
        onSaved: (v) => _formData[key] = v ?? '',
      ),
    );
  }

  Widget _dateField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: _formData[key] ?? DateTime.now().toIso8601String().split('T')[0],
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        style: const TextStyle(fontSize: 16),
        onSaved: (v) => _formData[key] = v ?? DateTime.now().toIso8601String().split('T')[0],
      ),
    );
  }

  Widget _radioGroup(String label, String key, List<Map<String, dynamic>> options, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FormField<dynamic>(
        initialValue: _formData[key],
        validator: (v) {
          if (required && v == null) {
            return '$label을(를) 선택해주세요';
          }
          return null;
        },
        onSaved: (v) => _formData[key] = v,
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label + (required ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: options.map((opt) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<dynamic>(
                      value: opt['value'],
                      groupValue: state.value,
                      onChanged: (v) {
                        state.didChange(v);
                        setState(() {
                          _formData[key] = v;
                        });
                      },
                    ),
                    Text(opt['label']!),
                  ],
                )).toList(),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
