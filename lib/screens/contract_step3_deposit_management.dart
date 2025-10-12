import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class ContractStep3DepositManagement extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(Map<String, dynamic>) onDataUpdate;

  const ContractStep3DepositManagement({
    Key? key,
    this.initialData,
    required this.onNext,
    required this.onPrevious,
    required this.onDataUpdate,
  }) : super(key: key);

  @override
  State<ContractStep3DepositManagement> createState() => _ContractStep3DepositManagementState();
}

class _ContractStep3DepositManagementState extends State<ContractStep3DepositManagement> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
    // 기본값 설정
    _formData['deposit'] = _formData['deposit'] ?? '0';
    _formData['monthly_rent'] = _formData['monthly_rent'] ?? '0';
    _formData['management_fee'] = _formData['management_fee'] ?? '0';
    _formData['management_details'] = _formData['management_details'] ?? '';
    _formData['repair_needed'] = _formData['repair_needed'] ?? 'none';
    _formData['repair_content'] = _formData['repair_content'] ?? '';
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
            // 희망계약금 섹션
            _sectionTitle('희망계약금'),
            _formGrid([
              _textField('보증금/전세금 (원)', 'deposit', keyboardType: TextInputType.number, required: true),
              if (_formData['rental_type'] == 'monthly')
                _textField('월 임대료 (원)', 'monthly_rent', keyboardType: TextInputType.number, required: true),
            ]),
            const SizedBox(height: 24),

            // 관리비 섹션
            _sectionTitle('관리비'),
            _formGrid([
              _textField('관리비 (정액인 경우)', 'management_fee', keyboardType: TextInputType.number),
              _textField('관리비 항목 및 산정방식', 'management_details', maxLines: 2, fullWidth: true),
            ]),
            const SizedBox(height: 24),

            // 입주 전 수리 섹션
            _sectionTitle('입주 전 수리'),
            _formGrid([
              _radioGroup('수리 필요 시설', 'repair_needed', [
                {'label': '없음', 'value': 'none'},
                {'label': '있음', 'value': 'has'},
              ]),
              _textField('수리할 내용', 'repair_content', maxLines: 2, fullWidth: true),
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
              borderSide: BorderSide(color: AppColors.kBrown.withAlpha((0.2 * 255).toInt())),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.kBrown.withAlpha((0.1 * 255).toInt())),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.kBrown, width: 2),
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
          onSaved: (v) => _formData[key] = v ?? (key.contains('area') || key.contains('fee') || key.contains('deposit') ? '0' : ''),
        ),
      ),
    );
  }

  Widget _radioGroup(String label, String key, List<Map<String, String>> options, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FormField<String>(
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
              Wrap(
                spacing: 16,
                children: options.map((opt) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: opt['value']!,
                      groupValue: state.value ?? _formData[key],
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

class _FullWidthField extends StatelessWidget {
  final Widget child;
  final bool fullWidth;
  const _FullWidthField({required this.child, this.fullWidth = false});
  @override
  Widget build(BuildContext context) => child;
}
