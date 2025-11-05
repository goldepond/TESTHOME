import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';

class ContractStep4TransactionMethod extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Map<String, String>? fullAddrAPIData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(Map<String, dynamic>) onDataUpdate;
  final Function(String) onTransactionMethodSet;
  final String? currentUserId; // 현재 사용자 ID

  const ContractStep4TransactionMethod({
    Key? key,
    this.initialData,
    required this.fullAddrAPIData,
    required this.onNext,
    required this.onPrevious,
    required this.onDataUpdate,
    required this.onTransactionMethodSet,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<ContractStep4TransactionMethod> createState() => _ContractStep4TransactionMethodState();
}

class _ContractStep4TransactionMethodState extends State<ContractStep4TransactionMethod> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  String? _selectedTransactionMethod;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
    _formData['deal_type'] ??= 'direct';
    _selectedTransactionMethod = _formData['deal_type'] as String?;
  }

  void _saveAndNext() {
    // 거래 방식 선택 검증
    if (_selectedTransactionMethod == null || _selectedTransactionMethod!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('거래 방식을 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // 중개업자 거래 선택 시 broker_id는 나중에 설정 (매물 등록 완료 시점에서)
      if (_selectedTransactionMethod == 'broker') {
      }
      
      widget.onDataUpdate(_formData);
      widget.onTransactionMethodSet(_selectedTransactionMethod!);
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
            // 거래 방식 섹션
            _sectionTitle('거래 방식'),
            _transactionMethodSelection(),
            const SizedBox(height: 24),

            // 중개업자 정보 (중개업자 선택 시에만 표시)
            if (_selectedTransactionMethod == 'broker') ...[
              _sectionTitle('중개업자 정보'),
              _formGrid([
                _textField('중개업소명', 'broker_office_name', required: true),
                _textField('대표 중개업자명', 'broker_name', required: true),
                _textField('중개업자 연락처', 'broker_phone', keyboardType: TextInputType.phone, required: true),
                //_textField('중개업자 주소', 'broker_address'),
                _textField('중개업자 등록번호', 'broker_license_number', required: true),
                _textField('중개업소 주소', 'broker_office_address', required: true),
              ]),
              const SizedBox(height: 24),
            ],

            // 안내 메시지
            _buildInfoMessage(),
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
                    onPressed: _selectedTransactionMethod != null ? _saveAndNext : null,
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

  Widget _transactionMethodSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('거래 방식 *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _transactionMethodCard(
                  '직거래',
                  'direct',
                  '임대인과 임차인이 직접 계약을 진행합니다.\n상세한 시설 정보를 입력해야 합니다.',
                  Icons.handshake,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _transactionMethodCard(
                  '중개업자',
                  'broker',
                  '중개업자를 통해 계약을 진행합니다.\n담당 중개업자에게 정보를 전송합니다.',
                  Icons.business,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionMethodCard(String title, String value, String description, IconData icon) {
    final isSelected = _selectedTransactionMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransactionMethod = value;
          _formData['deal_type'] = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.withValues(alpha:0.1) : Colors.white,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? Colors.blue : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoMessage() {
    if (_selectedTransactionMethod == 'direct') {
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
                  '직거래 선택 시',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '다음 단계에서 상세한 시설 정보를 입력해야 합니다:\n'
              '• 수도, 전기, 가스, 소방\n'
              '• 난방방식, 승강기, 배수\n'
              '• 벽면/바닥/도배, 환경조건\n'
              '• 특약사항',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    } else if (_selectedTransactionMethod == 'broker') {
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
                  '중개업자 선택 시',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '담당 중개업자에게 계약 정보를 전송하고,\n'
              '매물 상태가 "보류"로 등록됩니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
          onSaved: (v) => _formData[key] = v ?? '',
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
