import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import 'contract_step1_basic_info.dart';
import 'contract_step2_contract_conditions.dart';
import 'contract_step3_deposit_management.dart';
import 'contract_step4_transaction_method.dart';
import 'contract_step4_direct_details.dart';
import 'contract_step5_registration.dart';

class ContractStepController extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? userName;
  final String? propertyId;
  final String? currentUserId;

  const ContractStepController({
    Key? key,
    this.initialData,
    this.userName,
    this.propertyId,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<ContractStepController> createState() => _ContractStepControllerState();
}

class _ContractStepControllerState extends State<ContractStepController> {
  int _currentStep = 1;
  final Map<String, dynamic> _formData = {};
  String? _transactionMethod; // 'direct' or 'broker'

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
    });
  }

  void _setTransactionMethod(String method) {
    setState(() {
      _transactionMethod = method;
    });
  }

  void _updateFormData(Map<String, dynamic> data) {
    setState(() {
      _formData.addAll(data);
    });
  }

  Widget _getCurrentStep() {
    switch (_currentStep) {
      case 1:
        return ContractStep1BasicInfo(
          initialData: _formData,
          onNext: _nextStep,
          onDataUpdate: _updateFormData,
        );
      case 2:
        return ContractStep2ContractConditions(
          initialData: _formData,
          onNext: _nextStep,
          onPrevious: _previousStep,
          onDataUpdate: _updateFormData,
        );
      case 3:
        return ContractStep3DepositManagement(
          initialData: _formData,
          onNext: _nextStep,
          onPrevious: _previousStep,
          onDataUpdate: _updateFormData,
        );
      case 4:
        return ContractStep4TransactionMethod(
          initialData: _formData,
          onNext: _nextStep,
          onPrevious: _previousStep,
          onDataUpdate: _updateFormData,
          onTransactionMethodSet: _setTransactionMethod,
          currentUserId: widget.currentUserId,
        );
      case 5:
        if (_transactionMethod == 'direct') {
          // 직거래의 경우 상세내용 작성 (4-1~4-10단계)
          return ContractStep4DirectDetails(
            initialData: _formData,
            onNext: _nextStep,
            onPrevious: _previousStep,
            onDataUpdate: _updateFormData,
          );
        } else {
          // 중개업자 거래의 경우 바로 매물등록
          return ContractStep5Registration(
            initialData: _formData,
            onPrevious: _previousStep,
            userName: widget.userName,
            propertyId: widget.propertyId,
            transactionMethod: _transactionMethod!,
          );
        }
      case 6:
        // 직거래의 경우 상세내용 작성 후 매물등록
        return ContractStep5Registration(
          initialData: _formData,
          onPrevious: _previousStep,
          userName: widget.userName,
          propertyId: widget.propertyId,
          transactionMethod: _transactionMethod!,
        );
      default:
        return ContractStep1BasicInfo(
          initialData: _formData,
          onNext: _nextStep,
          onDataUpdate: _updateFormData,
        );
    }
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return '1단계: 기본정보 및 부동산 정보';
      case 2:
        return '2단계: 계약 조건';
      case 3:
        return '3단계: 희망계약금 및 관리비';
      case 4:
        return '4단계: 거래 방식';
      case 5:
        if (_transactionMethod == 'direct') {
          return '4-1단계: 상세내용 작성';
        } else {
          return '5단계: 매물 등록';
        }
      case 6:
        return '5단계: 매물 등록';
      default:
        return '주택임대차계약서 작성';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _getStepTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.kBrown,
        elevation: 0,
        leading: _currentStep > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _previousStep,
              )
            : null,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$_currentStep/${_getTotalSteps()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 진행률 표시
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: AppColors.kBrown,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '진행 상황',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_getProgressValue() * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kBrown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _getProgressValue(),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.kBrown),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_currentStep단계 / 총 ${_getTotalSteps()}단계',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // 현재 단계 내용
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: _getCurrentStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getProgressValue() {
    int totalSteps = _getTotalSteps();
    return _currentStep / totalSteps;
  }

  int _getTotalSteps() {
    if (_transactionMethod == 'broker') {
      return 5; // 1,2,3,4,5단계
    } else {
      return 6; // 1,2,3,4,5(상세내용),6(등록)단계
    }
  }
}
