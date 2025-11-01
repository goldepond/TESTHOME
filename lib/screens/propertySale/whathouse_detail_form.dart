import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:property/api_request/firebase_service.dart';
import 'dart:convert';
import 'package:property/screens/main_page.dart';

class WhathouseDetailFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String userName;
  final String? propertyId; // propertyId 추가
  const WhathouseDetailFormScreen({Key? key, this.initialData, required this.userName, this.propertyId}) : super(key: key);

  @override
  State<WhathouseDetailFormScreen> createState() => _WhathouseDetailFormScreenState();
}

class _WhathouseDetailFormScreenState extends State<WhathouseDetailFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  final FirebaseService _firebaseService = FirebaseService(); // FirebaseService 추가

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
  }

  void _saveTotalAmount() {
    // 각 항목을 int로 변환 후 합산
    int parse(String? v) => int.tryParse(v?.replaceAll(',', '') ?? '') ?? 0;
    final deposit = parse(_formData['desired_deposit']?.toString());
    final contract = parse(_formData['contract_payment']?.toString());
    final interim = parse(_formData['interim_payment']?.toString());
    final balance = parse(_formData['balance_payment']?.toString());
    final rent = parse(_formData['monthly_rent']?.toString());
    _formData['total_amount'] = deposit + contract + interim + balance + rent;
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      _saveTotalAmount();
      try {
        // Firebase에 상세정보 저장
        if (widget.propertyId != null) {
          print('🔥 [WhathouseDetailForm] 상세정보 Firebase 저장 시작');
          print('🔥 [WhathouseDetailForm] 저장할 데이터: $_formData');
          
          // 상세정보를 JSON으로 변환하여 저장
          final detailData = {
            'detailFormData': _formData,
            'detailFormJson': json.encode(_formData),
            'updatedAt': DateTime.now().toIso8601String(),
          };
          
          final success = await _firebaseService.updatePropertyFields(
            widget.propertyId!, 
            detailData
          );
          
          if (success) {
            print('✅ [WhathouseDetailForm] 상세정보 Firebase 저장 성공');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('상세 내용이 성공적으로 저장되었습니다.')),
              );
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => MainPage(userId: widget.userName, userName: widget.userName)),
                  (route) => false,
                );
              }
            }
          } else {
            print('❌ [WhathouseDetailForm] 상세정보 Firebase 저장 실패');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('상세 내용 저장에 실패했습니다.')),
              );
            }
          }
        } else {
          print('⚠️ [WhathouseDetailForm] propertyId가 없어 저장을 건너뜁니다');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('상세 내용이 성공적으로 저장되었습니다.')),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => MainPage(userId: widget.userName, userName: widget.userName)),
                (route) => false,
              );
            }
          }
        }
      } catch (e) {
        print('❌ [WhathouseDetailForm] 상세정보 저장 중 오류: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('상세 내용 저장 중 오류: $e')),
          );
        }
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _textField(String label, String key, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: _formData[key]?.toString() ?? '',
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        onSaved: (v) => _formData[key] = v ?? '',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _radioGroup(String label, String key, List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: options.map((opt) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: opt,
                  groupValue: _formData[key],
                  onChanged: (v) => setState(() => _formData[key] = v),
                ),
                Text(opt),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _numberField(String label, String key, {String? hint}) {
    return _textField(label, key, hint: hint, keyboardType: TextInputType.number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 내용 입력'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('수도'),
              _radioGroup('파손 여부', 'water_damage', ['없음', '있음']),
              _textField('파손 위치', 'water_damage_location', hint: '예: 욕실, 주방'),
              _radioGroup('용수량', 'water_amount', ['정상', '부족함']),
              _textField('용수량 부족 위치', 'water_amount_location', hint: '예: 세면대'),

              _sectionTitle('전기'),
              _radioGroup('공급상태', 'electricity_status', ['정상', '교체 필요']),
              _textField('교체할 부분', 'electricity_replace_part', hint: '예: 거실 조명'),

              _sectionTitle('가스(취사용)'),
              _radioGroup('공급방식', 'gas_type', ['도시가스', '그 밖의 방식']),
              _textField('그 밖의 방식', 'gas_type_etc', hint: '예: LPG'),

              _sectionTitle('소방'),
              _radioGroup('단독경보형 감지기', 'fire_alarm', ['없음', '있음']),
              _numberField('감지기 수량', 'fire_alarm_count', hint: '숫자만 입력'),

              _sectionTitle('난방방식 및 연료공급'),
              _radioGroup('공급방식', 'heating_supply', ['중앙공급', '개별공급', '지역난방']),
              _radioGroup('시설작동', 'heating_working', ['정상', '수선 필요']),
              _textField('수선 필요 사유', 'heating_working_reason'),
              _numberField('사용연한(년)', 'heating_years'),
              _radioGroup('종류', 'heating_fuel', ['도시가스', '기름', '프로판가스', '연탄', '그 밖의 종류']),
              _textField('그 밖의 종류', 'heating_fuel_etc'),

              _sectionTitle('승강기'),
              _radioGroup('승강기', 'elevator', ['있음', '없음']),
              _radioGroup('상태', 'elevator_status', ['양호', '불량']),

              _sectionTitle('배수'),
              _radioGroup('배수', 'drain', ['정상', '수선 필요']),
              _textField('수선 필요 위치', 'drain_repair_location'),

              _sectionTitle('벽면/바닥/도배'),
              _radioGroup('벽면 균열', 'wall_crack', ['없음', '있음']),
              _textField('균열 위치', 'wall_crack_location'),
              _radioGroup('벽면 누수', 'wall_leak', ['없음', '있음']),
              _textField('누수 위치', 'wall_leak_location'),
              _radioGroup('바닥면', 'floor_status', ['깨끗함', '보통임', '수리 필요']),
              _textField('수리 필요 위치', 'floor_repair_location'),
              _radioGroup('도배', 'wallpaper', ['깨끗함', '보통임', '도배 필요']),

              _sectionTitle('환경조건'),
              _radioGroup('일조량', 'sunlight', ['풍부함', '보통임', '불충분']),
              _textField('불충분 사유', 'sunlight_reason'),
              _radioGroup('소음', 'noise', ['아주 작음', '보통임', '심한 편임']),
              _radioGroup('진동', 'vibration', ['아주 작음', '보통임', '심한 편임']),

              _sectionTitle('현장안내'),
              _radioGroup('현장안내자', 'guide_type', ['개업공인중개사', '소속공인중개사', '중개보조원', '해당 없음']),
              _radioGroup('신분고지 여부', 'guide_notice', ['예', '아니오']),

              const SizedBox(height: 18),
              // 희망 계약금/지급 조건 입력 버튼
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => DepositConditionPage(initialData: _formData),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _formData.addAll(result);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('희망 계약금/지급 조건 입력'),
              ),
              // 버튼 분리용 구분선 및 안내
              const SizedBox(height: 32),
              Divider(thickness: 1.2, color: Color(0xFFe0e0e0)),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '모든 입력이 끝나면 아래 버튼을 눌러 계약서를 생성하세요.',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 18),
              // 계약서 생성 버튼
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('계약서 생성'),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 희망 계약금/지급 조건 입력 페이지
class DepositConditionPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const DepositConditionPage({Key? key, this.initialData}) : super(key: key);

  @override
  State<DepositConditionPage> createState() => _DepositConditionPageState();
}

class _DepositConditionPageState extends State<DepositConditionPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
  }

  void _saveTotalAmount() {
    int parse(String? v) => int.tryParse(v?.replaceAll(',', '') ?? '') ?? 0;
    final deposit = parse(_formData['desired_deposit']?.toString());
    final contract = parse(_formData['contract_payment']?.toString());
    final interim = parse(_formData['interim_payment']?.toString());
    final balance = parse(_formData['balance_payment']?.toString());
    final rent = parse(_formData['monthly_rent']?.toString());
    _formData['total_amount'] = deposit + contract + interim + balance + rent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('희망 계약금/지급 조건 입력'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _numberField('보증금 (원정)', 'desired_deposit', hint: '예: 220000000'),
              const SizedBox(height: 8),
              _numberField('계약금 (계약시 지불)', 'contract_payment', hint: '예: 20000000'),
              const SizedBox(height: 8),
              _numberField('중도금 (원정)', 'interim_payment', hint: '예: 50000000'),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _formData['interim_payment_date']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: '중도금 지급일 (YYYY-MM-DD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
                onSaved: (v) => _formData['interim_payment_date'] = v ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              _numberField('잔금 (원정)', 'balance_payment', hint: '예: 150000000'),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _formData['balance_payment_date']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: '잔금 지급일 (YYYY-MM-DD)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
                onSaved: (v) => _formData['balance_payment_date'] = v ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              _numberField('차임 (원정)', 'monthly_rent', hint: '예: 1000000'),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _formData['monthly_rent_date']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: '차임 지급일 (매월 n일)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
                onSaved: (v) => _formData['monthly_rent_date'] = v ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _formData['monthly_rent_type'] ?? '후불',
                items: const [
                  DropdownMenuItem(value: '후불', child: Text('후불')),
                  DropdownMenuItem(value: '선불', child: Text('선불')),
                ],
                onChanged: (v) => setState(() => _formData['monthly_rent_type'] = v),
                onSaved: (v) => _formData['monthly_rent_type'] = v ?? '후불',
                decoration: const InputDecoration(
                  labelText: '차임 지급 방식',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                ),
              ),
              const SizedBox(height: 18),
              // AI 추천 박스
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withAlpha((0.2 * 255).toInt()), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Colors.blue, size: 26),
                        SizedBox(width: 8),
                        Text('AI 추천 가격', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.savings, color: Colors.indigo, size: 28),
                        SizedBox(width: 8),
                        Text('보증금 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        Expanded(
                          child: Text('2,000만원', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                        SizedBox(width: 24),
                        Icon(Icons.payments, color: Colors.blue, size: 28),
                        SizedBox(width: 8),
                        Text('계약금 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                        Expanded(
                          child: Text('2억원', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 반응형으로 변경하여 오버플로우 방지
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // 데스크톱/태블릿: 한 줄에 모든 정보 표시
                          return Row(
                            children: const [
                              Icon(Icons.trending_up, color: Colors.green, size: 18),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '최근 거래가: 2억1,800만원',
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.bar_chart, color: Colors.orange, size: 18),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '시세: 2억2,500만원',
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.verified, color: Colors.blue, size: 18),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'AI 신뢰도: 92%',
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // 모바일: 여러 줄로 나누어 표시
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.trending_up, color: Colors.green, size: 18),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '최근 거래가: 2억1,800만원',
                                      style: TextStyle(fontSize: 14, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, color: Colors.orange, size: 18),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '시세: 2억2,500만원',
                                      style: TextStyle(fontSize: 14, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.verified, color: Colors.blue, size: 18),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'AI 신뢰도: 92%',
                                      style: TextStyle(fontSize: 14, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    // 가격 추이 그래프
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '최근 6개월 가격 추이',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${(value / 10000).round()}만',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const months = ['1월', '2월', '3월', '4월', '5월', '6월'];
                                        return Text(
                                          months[value.toInt()],
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      const FlSpot(0, 21000),
                                      const FlSpot(1, 21500),
                                      const FlSpot(2, 21800),
                                      const FlSpot(3, 22200),
                                      const FlSpot(4, 22500),
                                      const FlSpot(5, 22800),
                                    ],
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.blue.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 주변 시세 비교 테이블
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '주변 시세 비교',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '구분',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '평균가',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '변동',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '동일 단지',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '2억2,500만원',
                                      style: TextStyle(color: Colors.black87),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '+1.2%',
                                      style: TextStyle(color: Colors.green),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '인근 단지',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '2억1,800만원',
                                      style: TextStyle(color: Colors.black87),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '-0.5%',
                                      style: TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '지역 평균',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '2억2,000만원',
                                      style: TextStyle(color: Colors.black87),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '+0.8%',
                                      style: TextStyle(color: Colors.green),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          _formKey.currentState?.save();
                          _saveTotalAmount();
                          Navigator.of(context).pop(_formData);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('입력 완료'),
                    ),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(String label, String key, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: _formData[key]?.toString() ?? '',
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        keyboardType: TextInputType.number,
        onSaved: (v) => _formData[key] = v ?? '',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
} 