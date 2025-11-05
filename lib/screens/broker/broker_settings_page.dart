import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';

/// 공인중개사 본인 정보 관리 페이지
class BrokerSettingsPage extends StatefulWidget {
  final String brokerId;
  final String brokerName;

  const BrokerSettingsPage({
    super.key,
    required this.brokerId,
    required this.brokerName,
  });

  @override
  State<BrokerSettingsPage> createState() => _BrokerSettingsPageState();
}

class _BrokerSettingsPageState extends State<BrokerSettingsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // 중개업자 정보 필드들
  final TextEditingController _brokerNameController = TextEditingController();
  final TextEditingController _brokerPhoneController = TextEditingController();
  final TextEditingController _brokerAddressController = TextEditingController();
  final TextEditingController _brokerLicenseNumberController = TextEditingController();
  final TextEditingController _brokerOfficeNameController = TextEditingController();
  final TextEditingController _brokerOfficeAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrokerInfo();
  }

  @override
  void dispose() {
    _brokerNameController.dispose();
    _brokerPhoneController.dispose();
    _brokerAddressController.dispose();
    _brokerLicenseNumberController.dispose();
    _brokerOfficeNameController.dispose();
    _brokerOfficeAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokerInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      // brokers 컬렉션에서 정보 가져오기
      final brokerData = await _firebaseService.getBroker(widget.brokerId);
      
      if (brokerData != null) {
        
        _brokerNameController.text = brokerData['ownerName'] ?? brokerData['businessName'] ?? '';
        _brokerPhoneController.text = brokerData['phone'] ?? brokerData['phoneNumber'] ?? '';
        _brokerAddressController.text = brokerData['address'] ?? brokerData['roadAddress'] ?? '';
        _brokerLicenseNumberController.text = brokerData['brokerRegistrationNumber'] ?? brokerData['registrationNumber'] ?? '';
        _brokerOfficeNameController.text = brokerData['businessName'] ?? brokerData['name'] ?? '';
        _brokerOfficeAddressController.text = brokerData['roadAddress'] ?? brokerData['address'] ?? '';
      } else {
        
        // users 컬렉션의 brokerInfo에서도 확인
        final userData = await _firebaseService.getUser(widget.brokerId);
        if (userData != null && userData['brokerInfo'] != null) {
          final brokerInfo = userData['brokerInfo'];
          
          _brokerNameController.text = brokerInfo['broker_name'] ?? '';
          _brokerPhoneController.text = brokerInfo['broker_phone'] ?? '';
          _brokerAddressController.text = brokerInfo['broker_address'] ?? '';
          _brokerLicenseNumberController.text = brokerInfo['broker_license_number'] ?? '';
          _brokerOfficeNameController.text = brokerInfo['broker_office_name'] ?? '';
          _brokerOfficeAddressController.text = brokerInfo['broker_office_address'] ?? '';
        }
      }
    } catch (e) {
      print('❌ [BrokerSettings] 공인중개사 정보 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정보를 불러오는데 실패했습니다: $e'),
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

  Future<void> _saveBrokerInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final brokerInfo = {
        'broker_name': _brokerNameController.text.trim(),
        'broker_phone': _brokerPhoneController.text.trim(),
        'broker_address': _brokerAddressController.text.trim(),
        'broker_license_number': _brokerLicenseNumberController.text.trim(),
        'broker_office_name': _brokerOfficeNameController.text.trim(),
        'broker_office_address': _brokerOfficeAddressController.text.trim(),
      };

      // brokers 컬렉션 업데이트
      final success = await _firebaseService.updateBrokerInfo(widget.brokerId, brokerInfo);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보가 성공적으로 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        // 저장 후 정보 다시 로드
        _loadBrokerInfo();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정보 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.kBackground,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.kPrimary, AppColors.kSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.kPrimary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 정보 관리',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.brokerName}님의 정보를 관리하세요',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 기본 정보 섹션
              _buildSectionCard(
                title: '기본 정보',
                icon: Icons.person_rounded,
                color: Colors.blue,
                children: [
                  _buildTextField(
                    controller: _brokerNameController,
                    label: '중개업자 성명',
                    hint: '홍길동',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerPhoneController,
                    label: '연락처',
                    hint: '010-1234-5678',
                    keyboardType: TextInputType.phone,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerAddressController,
                    label: '주소',
                    hint: '서울시 강남구',
                    required: true,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 사업자 정보 섹션
              _buildSectionCard(
                title: '사업자 정보',
                icon: Icons.business_rounded,
                color: Colors.green,
                children: [
                  _buildTextField(
                    controller: _brokerLicenseNumberController,
                    label: '중개업자 등록번호',
                    hint: '12345',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerOfficeNameController,
                    label: '사무소명',
                    hint: '강남부동산',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerOfficeAddressController,
                    label: '사무소 주소',
                    hint: '서울시 강남구 테헤란로 456',
                    required: true,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBrokerInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '정보 저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
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
                  color: color.withValues(alpha: 0.1),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: hint,
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
          borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label을(를) 입력해주세요';
              }
              return null;
            }
          : null,
    );
  }
}

