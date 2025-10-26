import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../widgets/radio_group.dart';

class ContractStep2ContractConditions extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(Map<String, dynamic>) onDataUpdate;

  const ContractStep2ContractConditions({
    Key? key,
    this.initialData,
    required this.onNext,
    required this.onPrevious,
    required this.onDataUpdate,
  }) : super(key: key);

  @override
  State<ContractStep2ContractConditions> createState() => _ContractStep2ContractConditionsState();
}

class _ContractStep2ContractConditionsState extends State<ContractStep2ContractConditions> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
    // 기본값 설정
    _formData['contract_type'] = _formData['contract_type'] ?? 'new';
    _formData['rental_type'] = _formData['rental_type'] ?? 'jeonse';
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
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 계약 조건 섹션
            _sectionTitle('계약 조건'),
            _formGrid([
              _radioGroup('계약의 종류', 'contract_type', [
                {'label': '신규 계약', 'value': 'new'},
                {'label': '합의에 의한 재계약', 'value': 'renewal'},
                {'label': '계약갱신요구권 행사에 의한 갱신계약', 'value': 'extension'},
              ], required: true),
              _radioGroup('임대차 유형', 'rental_type', [
                {'label': '전세', 'value': 'jeonse'},
                {'label': '보증금 있는 월세', 'value': 'monthly'},
              ], required: true),
            ]),
            const SizedBox(height: 32),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onPrevious,
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
                    onPressed: _saveAndNext,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.kBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('다음 단계'),
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

  Widget _radioGroup(String label, String key, List<Map<String, String>> options, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FormField<String>(
        initialValue: _formData[key],
        validator: (v) {
          if (required && (v == null || v.isEmpty)) {
            return '$label을(를) 선택해주세요';
          }
          return null;
        },
        onSaved: (v) => _formData[key] = v ?? options.first['value'],
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label + (required ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: state.value,
                onChanged: (v) {
                  state.didChange(v);
                  setState(() {
                    _formData[key] = v;
                  });
                },
                child: Wrap(
                  spacing: 16,
                  children: options.map((opt) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: opt['value']!,
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
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          );
        },
      ),
    );
  }
}
