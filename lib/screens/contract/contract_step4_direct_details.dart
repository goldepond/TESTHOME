import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/api_request/building_info_service.dart';

class ContractStep4DirectDetails extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(Map<String, dynamic>) onDataUpdate;

  const ContractStep4DirectDetails({
    Key? key,
    this.initialData,
    required this.onNext,
    required this.onPrevious,
    required this.onDataUpdate,
  }) : super(key: key);

  @override
  State<ContractStep4DirectDetails> createState() => _ContractStep4DirectDetailsState();
}

class _ContractStep4DirectDetailsState extends State<ContractStep4DirectDetails> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  int _currentDetailStep = 1;
  final int _totalDetailSteps = 11;
  Map<String, dynamic>? _aptInfo; // 아파트 기본정보
  Map<String, dynamic>? _buildingInfo; // 건축물대장 정보

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
    _setDefaultValues();
    _loadAptInfo(); // 아파트 정보 백그라운드 로드
    _loadBuildingInfo(); // 건축물대장 정보 백그라운드 로드
    
    // 테스트용 API 호출
    AptInfoService.testApiCall();
    BuildingInfoService.testApiCall();
  }

  void _setDefaultValues() {
    // 수도 기본값
    _formData['water_damage'] = _formData['water_damage'] ?? 'no';
    _formData['water_flow_condition'] = _formData['water_flow_condition'] ?? 'normal';
    
    // 전기 기본값
    _formData['electricity_condition'] = _formData['electricity_condition'] ?? 'good';
    
    // 가스 기본값
    _formData['gas_type'] = _formData['gas_type'] ?? 'city_gas';
    _formData['gas_condition'] = _formData['gas_condition'] ?? 'good';
    
    // 소방 기본값
    _formData['fire_extinguisher'] = _formData['fire_extinguisher'] ?? 'yes';
    _formData['fire_extinguisher_location'] = _formData['fire_extinguisher_location'] ?? '';
    _formData['fire_alarm'] = _formData['fire_alarm'] ?? 'yes';
    _formData['emergency_exit'] = _formData['emergency_exit'] ?? 'yes';
    _formData['emergency_exit_location'] = _formData['emergency_exit_location'] ?? '';
    _formData['fire_facilities_notes'] = _formData['fire_facilities_notes'] ?? '';
    
    // 난방 기본값
    _formData['heating_type'] = _formData['heating_type'] ?? 'individual';
    _formData['fuel_type'] = _formData['fuel_type'] ?? 'gas';
    _formData['heating_condition'] = _formData['heating_condition'] ?? 'good';
    _formData['heating_notes'] = _formData['heating_notes'] ?? '';
    
    // 승강기 기본값
    _formData['elevator_exists'] = _formData['elevator_exists'] ?? 'no';
    _formData['elevator_count'] = _formData['elevator_count'] ?? '';
    _formData['elevator_condition'] = _formData['elevator_condition'] ?? 'good';
    _formData['elevator_notes'] = _formData['elevator_notes'] ?? '';
    
    // 배수 기본값
    _formData['drainage_condition'] = _formData['drainage_condition'] ?? 'normal';
    _formData['drainage_notes'] = _formData['drainage_notes'] ?? '';
    
    // 벽면/바닥 기본값
    _formData['wall_crack'] = _formData['wall_crack'] ?? 'no';
    _formData['wall_leak'] = _formData['wall_leak'] ?? 'no';
    _formData['floor_condition'] = _formData['floor_condition'] ?? 'clean';
    _formData['wallpaper_condition'] = _formData['wallpaper_condition'] ?? 'clean';
    _formData['wall_floor_notes'] = _formData['wall_floor_notes'] ?? '';
    
    // 환경조건 기본값
    _formData['sunlight_condition'] = _formData['sunlight_condition'] ?? 'good';
    _formData['ventilation_condition'] = _formData['ventilation_condition'] ?? 'good';
    _formData['noise_level'] = _formData['noise_level'] ?? 'normal';
    _formData['environment_notes'] = _formData['environment_notes'] ?? '';
    
    // 특약사항 기본값
    _formData['special_terms'] = _formData['special_terms'] ?? '';
  }

  void _nextDetailStep() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onDataUpdate(_formData);
      
      if (_currentDetailStep < _totalDetailSteps) {
        setState(() {
          _currentDetailStep++;
        });
      } else {
        widget.onNext();
      }
    }
  }

  void _previousDetailStep() {
    if (_currentDetailStep > 1) {
      setState(() {
        _currentDetailStep--;
      });
    } else {
      widget.onPrevious();
    }
  }


  Widget _getCurrentDetailStep() {
    switch (_currentDetailStep) {
      case 1: return _buildWaterStep();
      case 2: return _buildElectricityStep();
      case 3: return _buildGasStep();
      case 4: return _buildFireStep();
      case 5: return _buildHeatingStep();
      case 6: return _buildElevatorStep();
      case 7: return _buildDrainageStep();
      case 8: return _buildWallFloorStep();
      case 9: return _buildEnvironmentStep();
      case 10: return _buildSpecialTermsStep();
      case 11: return _buildSummaryStep();
      default: return _buildWaterStep();
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
            // 진행률 표시
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _currentDetailStep / _totalDetailSteps,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_currentDetailStep/$_totalDetailSteps 단계',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // 현재 단계 내용
            _getCurrentDetailStep(),
            
            const SizedBox(height: 32),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _previousDetailStep,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    child: Text(_currentDetailStep == 1 ? '이전 단계' : '이전'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextDetailStep,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.kBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    child: Text(_currentDetailStep == _totalDetailSteps ? '매물 등록' : '다음'),
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

  Widget _buildWaterStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('수도'),
        _formGrid([
          _radioGroup('파손여부', 'water_damage', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          _radioGroup('용수량', 'water_flow_condition', [
            {'label': '정상', 'value': 'normal'},
            {'label': '비정상', 'value': 'abnormal'},
          ]),
        ]),
      ],
    );
  }

  Widget _buildElectricityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('전기'),
        _formGrid([
          _radioGroup('전기 상태', 'electricity_condition', [
            {'label': '양호', 'value': 'good'},
            {'label': '보통', 'value': 'normal'},
            {'label': '불량', 'value': 'poor'},
          ]),
        ]),
      ],
    );
  }

  Widget _buildGasStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('가스'),
        _formGrid([
          _radioGroup('가스 종류', 'gas_type', [
            {'label': '도시가스', 'value': 'city_gas'},
            {'label': 'LPG', 'value': 'lpg'},
            {'label': '없음', 'value': 'none'},
          ]),
          _radioGroup('가스 상태', 'gas_condition', [
            {'label': '양호', 'value': 'good'},
            {'label': '보통', 'value': 'normal'},
            {'label': '불량', 'value': 'poor'},
          ]),
        ]),
      ],
    );
  }

  Widget _buildFireStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('소방'),
        _formGrid([
          _radioGroup('소화기 설치', 'fire_extinguisher', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          // 소화기 위치 입력 (있음 선택 시에만 표시)
          if (_formData['fire_extinguisher'] == 'yes') ...[
            _textField('소화기 위치', 'fire_extinguisher_location', helpText: '예: 1층 현관, 복도 중앙 등'),
          ],
          _radioGroup('화재경보기', 'fire_alarm', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          _radioGroup('비상구', 'emergency_exit', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          // 비상구 위치 입력 (있음 선택 시에만 표시)
          if (_formData['emergency_exit'] == 'yes') ...[
            _textField('비상구 위치', 'emergency_exit_location', helpText: '예: 계단 옆, 복도 끝 등'),
          ],
          _textField('소방시설 특이사항', 'fire_facilities_notes', maxLines: 2, fullWidth: true),
        ]),
      ],
    );
  }

  Widget _buildHeatingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('난방방식 및 연료 공급'),
        _formGrid([
          _radioGroup('난방 방식', 'heating_type', [
            {'label': '개별난방', 'value': 'individual'},
            {'label': '중앙난방', 'value': 'central'},
            {'label': '지역난방', 'value': 'district'},
          ]),
          _radioGroup('연료 종류', 'fuel_type', [
            {'label': '가스', 'value': 'gas'},
            {'label': '전기', 'value': 'electric'},
            {'label': '기름', 'value': 'oil'},
            {'label': '기타', 'value': 'other'},
          ]),
          _radioGroup('난방 상태', 'heating_condition', [
            {'label': '양호', 'value': 'good'},
            {'label': '보통', 'value': 'normal'},
            {'label': '불량', 'value': 'poor'},
          ]),
          _textField('난방 특이사항', 'heating_notes', maxLines: 2, fullWidth: true),
        ]),
      ],
    );
  }

  Widget _buildElevatorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('승강기'),
        _formGrid([
          _radioGroup('승강기 유무', 'elevator_exists', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          _textField('승강기 대수', 'elevator_count', keyboardType: TextInputType.number),
          _radioGroup('승강기 상태', 'elevator_condition', [
            {'label': '양호', 'value': 'good'},
            {'label': '보통', 'value': 'normal'},
            {'label': '불량', 'value': 'poor'},
          ]),
          _textField('승강기 특이사항', 'elevator_notes', maxLines: 2, fullWidth: true),
        ]),
      ],
    );
  }

  Widget _buildDrainageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('배수'),
        _formGrid([
          _radioGroup('배수 상태', 'drainage_condition', [
            {'label': '정상', 'value': 'normal'},
            {'label': '수선 필요', 'value': 'repair_needed'},
          ]),
          _textField('배수 특이사항', 'drainage_notes', maxLines: 2, fullWidth: true),
        ]),
      ],
    );
  }

  Widget _buildWallFloorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('벽면/바닥/도배'),
        _formGrid([
          _radioGroup('벽면 균열', 'wall_crack', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          _radioGroup('벽면 누수', 'wall_leak', [
            {'label': '있음', 'value': 'yes'},
            {'label': '없음', 'value': 'no'},
          ]),
          _radioGroup('바닥면', 'floor_condition', [
            {'label': '깨끗함', 'value': 'clean'},
            {'label': '보통', 'value': 'normal'},
            {'label': '수리필요', 'value': 'repair_needed'},
          ]),
          _radioGroup('도배', 'wallpaper_condition', [
            {'label': '깨끗함', 'value': 'clean'},
            {'label': '보통', 'value': 'normal'},
            {'label': '도배필요', 'value': 'wallpaper_needed'},
          ]),
          _textField('벽면/바닥 특이사항', 'wall_floor_notes', maxLines: 2, fullWidth: true),
        ]),
      ],
    );
  }

  Widget _buildEnvironmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('환경조건'),
        _formGrid([
          _radioGroup('일조 조건', 'sunlight_condition', [
            {'label': '양호', 'value': 'good'},
            {'label': '보통', 'value': 'normal'},
            {'label': '불량', 'value': 'poor'},
          ]),
          _radioGroup('통풍 조건', 'ventilation_condition', [
            {'label': '양호', 'value': 'good'},
            {'label': '보통', 'value': 'normal'},
            {'label': '불량', 'value': 'poor'},
          ]),
          _radioGroup('소음 수준', 'noise_level', [
            {'label': '조용함', 'value': 'quiet'},
            {'label': '보통', 'value': 'normal'},
            {'label': '시끄러움', 'value': 'noisy'},
          ]),
          _textField('환경 특이사항', 'environment_notes', maxLines: 2, fullWidth: true),
        ]),
      ],
    );
  }

  Widget _buildSpecialTermsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('특약사항'),
        
        // 정부 기본 특약 섹션
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '정부 기본 특약 (법적 보호)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildToggleClause('dispute_mediation', '분쟁조정위원회 조정', '분쟁 시 조정위원회 신청 의무', false),
              _buildToggleClause('termination_right', '해지권 특약', '감염병으로 인한 경제적 피해 시 계약 해지권', false),
              _buildToggleClause('overdue_exception', '연체 관련 특약', '코로나19 등 감염병 기간 중 연체 면제', false),
            ],
          ),
        ),
        
        _formGrid([
          _textField('추가 특약사항', 'special_terms', maxLines: 8, fullWidth: true, helpText: '위 특약사항 외에 추가로 필요한 특별한 조건이나 약정사항을 입력하세요'),
        ]),
      ],
    );
  }

  Widget _buildToggleClause(String key, String title, String description, bool isDefaultOn) {
    bool isSelected = _formData['clause_$key'] ?? isDefaultOn;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.green[300]! : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.grey[700] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                _formData['clause_$key'] = value;
              });
            },
            thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.green;
              }
              return Colors.grey;
            }),
          ),
        ],
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
          onSaved: (v) => _formData[key] = v ?? '',
        ),
      ),
    );
  }

  Widget _radioGroup(String label, String key, List<Map<String, String>> options, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FormField<String>(
        //initialValue: _formData[key],
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
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('총정리'),
        
        // 안내 메시지
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '입력하신 모든 정보를 확인해주세요. 확인 후 매물이 등록됩니다.',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 등본 정보 섹션
        _buildRegisterInfoSection(),
        
        const SizedBox(height: 16),
        
        // 아파트 기본정보 섹션
        _buildAptInfoSection(),
        
        const SizedBox(height: 16),
        
        // 건축물대장 정보 섹션
        _buildBuildingInfoSection(),
        
        const SizedBox(height: 16),
        
        // 기본 정보 섹션
        _buildSummarySection(
          '기본 정보',
          Icons.info_outline,
          Colors.blue,
          [
            _buildSummaryItem('임대인 성명', _formData['landlord_name'] ?? ''),
            _buildSummaryItem('임대인 연락처', _formData['landlord_phone'] ?? ''),
            _buildSummaryItem('임차인 성명', _formData['tenant_name'] ?? ''),
            _buildSummaryItem('임차인 연락처', _formData['tenant_phone'] ?? ''),
            _buildSummaryItem('부동산 주소', _formData['property_address'] ?? ''),
            _buildSummaryItem('보증금', _formData['deposit'] != null ? '${_formData['deposit']}만원' : ''),
            _buildSummaryItem('월세', _formData['monthly_rent'] != null ? '${_formData['monthly_rent']}만원' : ''),
            _buildSummaryItem('관리비', _formData['management_fee'] != null ? '${_formData['management_fee']}만원' : ''),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 시설 정보 섹션
        _buildSummarySection(
          '시설 정보',
          Icons.home_work_outlined,
          Colors.green,
          [
            _buildSummaryItem('수도 파손여부', _formData['water_damage'] == 'yes' ? '있음' : '없음'),
            _buildSummaryItem('용수량', _formData['water_flow_condition'] == 'normal' ? '정상' : '비정상'),
            _buildSummaryItem('전기 상태', _getElectricityConditionText()),
            _buildSummaryItem('가스 종류', _getGasTypeText()),
            _buildSummaryItem('가스 상태', _getGasConditionText()),
            _buildSummaryItem('소화기 설치', _formData['fire_extinguisher'] == 'yes' ? '있음' : '없음'),
            if (_formData['fire_extinguisher'] == 'yes')
              _buildSummaryItem('소화기 위치', _formData['fire_extinguisher_location'] ?? ''),
            _buildSummaryItem('화재경보기', _formData['fire_alarm'] == 'yes' ? '있음' : '없음'),
            _buildSummaryItem('비상구', _formData['emergency_exit'] == 'yes' ? '있음' : '없음'),
            if (_formData['emergency_exit'] == 'yes')
              _buildSummaryItem('비상구 위치', _formData['emergency_exit_location'] ?? ''),
            _buildSummaryItem('난방 방식', _getHeatingTypeText()),
            _buildSummaryItem('연료 종류', _getFuelTypeText()),
            _buildSummaryItem('난방 상태', _getHeatingConditionText()),
            _buildSummaryItem('승강기 유무', _formData['elevator_exists'] == 'yes' ? '있음' : '없음'),
            if (_formData['elevator_exists'] == 'yes')
              _buildSummaryItem('승강기 대수', _formData['elevator_count'] ?? ''),
            _buildSummaryItem('배수 상태', _formData['drainage_condition'] == 'normal' ? '정상' : '수선 필요'),
            _buildSummaryItem('벽면 균열', _formData['wall_crack'] == 'yes' ? '있음' : '없음'),
            _buildSummaryItem('벽면 누수', _formData['wall_leak'] == 'yes' ? '있음' : '없음'),
            _buildSummaryItem('바닥면', _getFloorConditionText()),
            _buildSummaryItem('도배', _getWallpaperConditionText()),
            _buildSummaryItem('일조 조건', _getSunlightConditionText()),
            _buildSummaryItem('통풍 조건', _getVentilationConditionText()),
            _buildSummaryItem('소음 수준', _getNoiseLevelText()),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 특약사항 섹션
        if (_hasSpecialTerms())
          _buildSummarySection(
            '특약사항',
            Icons.description_outlined,
            Colors.orange,
            [
              if (_formData['clause_dispute_mediation'] == true)
                _buildSummaryItem('분쟁조정위원회 조정', '적용'),
              if (_formData['clause_termination_right'] == true)
                _buildSummaryItem('해지권 특약', '적용'),
              if (_formData['clause_overdue_exception'] == true)
                _buildSummaryItem('연체 관련 특약', '적용'),
              if (_formData['special_terms']?.toString().isNotEmpty == true)
                _buildSummaryItem('추가 특약사항', _formData['special_terms'] ?? ''),
            ],
          ),
      ],
    );
  }

  Widget _buildSummarySection(String title, IconData icon, Color color, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getElectricityConditionText() {
    switch (_formData['electricity_condition']) {
      case 'good': return '양호';
      case 'normal': return '보통';
      case 'poor': return '불량';
      default: return '미입력';
    }
  }

  String _getGasTypeText() {
    switch (_formData['gas_type']) {
      case 'city_gas': return '도시가스';
      case 'lpg': return 'LPG';
      case 'none': return '없음';
      default: return '미입력';
    }
  }

  String _getGasConditionText() {
    switch (_formData['gas_condition']) {
      case 'good': return '양호';
      case 'normal': return '보통';
      case 'poor': return '불량';
      default: return '미입력';
    }
  }

  String _getHeatingTypeText() {
    switch (_formData['heating_type']) {
      case 'individual': return '개별난방';
      case 'central': return '중앙난방';
      case 'district': return '지역난방';
      default: return '미입력';
    }
  }

  String _getFuelTypeText() {
    switch (_formData['fuel_type']) {
      case 'gas': return '가스';
      case 'electric': return '전기';
      case 'oil': return '기름';
      case 'other': return '기타';
      default: return '미입력';
    }
  }

  String _getHeatingConditionText() {
    switch (_formData['heating_condition']) {
      case 'good': return '양호';
      case 'normal': return '보통';
      case 'poor': return '불량';
      default: return '미입력';
    }
  }

  String _getFloorConditionText() {
    switch (_formData['floor_condition']) {
      case 'clean': return '깨끗함';
      case 'normal': return '보통';
      case 'repair_needed': return '수리필요';
      default: return '미입력';
    }
  }

  String _getWallpaperConditionText() {
    switch (_formData['wallpaper_condition']) {
      case 'clean': return '깨끗함';
      case 'normal': return '보통';
      case 'wallpaper_needed': return '도배필요';
      default: return '미입력';
    }
  }

  String _getSunlightConditionText() {
    switch (_formData['sunlight_condition']) {
      case 'good': return '양호';
      case 'normal': return '보통';
      case 'poor': return '불량';
      default: return '미입력';
    }
  }

  String _getVentilationConditionText() {
    switch (_formData['ventilation_condition']) {
      case 'good': return '양호';
      case 'normal': return '보통';
      case 'poor': return '불량';
      default: return '미입력';
    }
  }

  String _getNoiseLevelText() {
    switch (_formData['noise_level']) {
      case 'quiet': return '조용함';
      case 'normal': return '보통';
      case 'noisy': return '시끄러움';
      default: return '미입력';
    }
  }

  bool _hasSpecialTerms() {
    return _formData['clause_dispute_mediation'] == true ||
           _formData['clause_termination_right'] == true ||
           _formData['clause_overdue_exception'] == true ||
           (_formData['special_terms']?.toString().isNotEmpty == true);
  }

  Widget _buildRegisterInfoSection() {
    // 등기부등본 정보가 있는지 확인
    final registerInfo = <String, String>{};
    
    // initialData에서 등본 관련 정보 추출
    if (widget.initialData != null) {
      final data = widget.initialData!;
      
      // 건물 정보
      if (data['building_name'] != null) registerInfo['건물명'] = data['building_name'].toString();
      if (data['building_type'] != null) registerInfo['건물 유형'] = data['building_type'].toString();
      if (data['floor'] != null) registerInfo['층수'] = '${data['floor']}층';
      if (data['area'] != null) registerInfo['면적'] = '${data['area']}㎡';
      if (data['structure'] != null) registerInfo['구조'] = data['structure'].toString();
      
      // 토지 정보
      if (data['land_purpose'] != null) registerInfo['토지 지목'] = data['land_purpose'].toString();
      if (data['land_area'] != null) registerInfo['토지 면적'] = '${data['land_area']}㎡';
      
      // 소유자 정보
      if (data['owner_name'] != null) registerInfo['소유자'] = data['owner_name'].toString();
      
      // 발급 정보
      if (data['publish_date'] != null) registerInfo['발급일'] = data['publish_date'].toString();
      if (data['office_name'] != null) registerInfo['발급기관'] = data['office_name'].toString();
      
      // 주소 정보
      if (data['property_address'] != null) registerInfo['주소'] = data['property_address'].toString();
    }
    
    // 등본 정보가 없으면 숨김
    if (registerInfo.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildSummarySection(
      '등기부등본 정보',
      Icons.description_outlined,
      Colors.purple,
      registerInfo.entries.map((entry) => 
        _buildSummaryItem(entry.key, entry.value)
      ).toList(),
    );
  }

  /// 아파트 기본정보 백그라운드 로드
  Future<void> _loadAptInfo() async {
    try {
      print('🏢 [ContractStep4DirectDetails] _loadAptInfo 시작');
      print('🏢 [ContractStep4DirectDetails] initialData: ${widget.initialData}');
      
      // 테스트용 하드코딩된 데이터 사용
      print('🏢 [ContractStep4DirectDetails] 테스트용 하드코딩된 데이터 사용');
      final testAptInfo = {
        'kaptCode': 'A46377309',
        'kaptName': '서현시범우성',
        'codeMgr': '위탁관리',
        'kaptMgrCnt': '16',
        'kaptCcompany': '(주)신화시스템즈',
        'codeSec': '위탁관리',
        'kaptdScnt': '52',
        'kaptdSecCom': '(유)미래환경',
        'codeClean': '위탁관리',
        'kaptdClcnt': '20',
        'codeGarbage': '차량수거방식',
        'codeDisinf': '위탁관리',
        'kaptdDcnt': '12',
        'disposalType': '도포식,분무식,독이식',
        'codeStr': '철근콘크리트구조',
        'kaptdEcapa': '4400',
        'codeEcon': '단일계약',
        'codeEmgr': '상주선임',
        'codeFalarm': 'P형',
        'codeWsupply': '부스타방식',
        'codeElev': '위탁관리',
        'kaptdEcnt': '51',
        'kaptdPcnt': '857',
        'kaptdPcntu': '1119',
        'codeNet': '무',
        'kaptdCccnt': '399',
        'welfareFacility': '관리사무소, 노인정, 주민공동시설, 어린이놀이터, 휴게시설, 자전거보관소',
        'kaptdWtimebus': '5분이내',
        'subwayLine': '분당선, 신분당선',
        'subwayStation': null,
        'kaptdWtimesub': '5~10분이내',
        'convenientFacility': '관공서(분당구청) 병원(제생병원) 백화점(삼성플라자) 공원(중앙공원)',
        'educationFacility': '초등학교(서현초등학교, 분당초등학교) 중학교(서현중교) 고등학교(서현고교)',
        'groundElChargerCnt': '0',
        'undergroundElChargerCnt': '22',
        'useYn': 'Y'
      };
      
      if (mounted) {
        setState(() {
          _aptInfo = testAptInfo;
        });
        print('✅ [ContractStep4DirectDetails] 테스트 아파트 정보 로드 완료: ${testAptInfo['kaptName']}');
        print('✅ [ContractStep4DirectDetails] _aptInfo 상태 업데이트됨: $_aptInfo');
      }
      
      // 실제 API 호출도 시도해보기
      final address = widget.initialData?['property_address']?.toString() ?? '';
      print('🏢 [ContractStep4DirectDetails] 추출된 주소: $address');
      
      if (address.isNotEmpty) {
        print('🏢 [ContractStep4DirectDetails] 실제 API 호출 시도 - 주소: $address');
        
        final kaptCode = AptInfoService.extractKaptCodeFromAddress(address);
        print('🏢 [ContractStep4DirectDetails] 추출된 단지코드: $kaptCode');
        
        final aptInfo = await AptInfoService.getAptBasisInfo(kaptCode);
        print('🏢 [ContractStep4DirectDetails] API 응답 결과: $aptInfo');
        
        if (aptInfo != null && mounted) {
          setState(() {
            _aptInfo = aptInfo;
          });
          print('✅ [ContractStep4DirectDetails] 실제 API 아파트 정보 로드 완료: ${aptInfo['kaptName']}');
          print('✅ [ContractStep4DirectDetails] _aptInfo 상태 업데이트됨: $_aptInfo');
        } else {
          print('⚠️ [ContractStep4DirectDetails] 실제 API에서 아파트 정보를 찾을 수 없습니다');
          print('⚠️ [ContractStep4DirectDetails] mounted 상태: $mounted');
        }
      } else {
        print('⚠️ [ContractStep4DirectDetails] 주소가 비어있습니다');
      }
    } catch (e) {
      print('❌ [ContractStep4DirectDetails] 아파트 정보 로드 오류: $e');
    }
  }

  /// 아파트 기본정보 섹션
  Widget _buildAptInfoSection() {
    print('🏢 [ContractStep4DirectDetails] _buildAptInfoSection 호출됨 - _aptInfo: $_aptInfo');
    
    if (_aptInfo == null) {
      print('🏢 [ContractStep4DirectDetails] _aptInfo가 null이므로 섹션 숨김');
      return const SizedBox.shrink();
    }

    final aptInfo = _aptInfo!;
    final infoItems = <String, String>{};
    print('🏢 [ContractStep4DirectDetails] 아파트 정보 섹션 빌드 시작 - aptInfo: $aptInfo');

    // 기본 정보
    if (aptInfo['kaptCode'] != null && aptInfo['kaptCode'].toString().isNotEmpty) {
      infoItems['단지코드'] = aptInfo['kaptCode'].toString();
    }
    if (aptInfo['kaptName'] != null && aptInfo['kaptName'].toString().isNotEmpty) {
      infoItems['단지명'] = aptInfo['kaptName'].toString();
    }
    
    // 관리 정보
    if (aptInfo['codeMgr'] != null && aptInfo['codeMgr'].toString().isNotEmpty) {
      infoItems['관리방식'] = aptInfo['codeMgr'].toString();
    }
    if (aptInfo['kaptMgrCnt'] != null && aptInfo['kaptMgrCnt'].toString().isNotEmpty) {
      infoItems['관리사무소 수'] = '${aptInfo['kaptMgrCnt']}개';
    }
    if (aptInfo['kaptCcompany'] != null && aptInfo['kaptCcompany'].toString().isNotEmpty) {
      infoItems['관리업체'] = aptInfo['kaptCcompany'].toString();
    }
    
    // 보안 정보
    if (aptInfo['codeSec'] != null && aptInfo['codeSec'].toString().isNotEmpty) {
      infoItems['보안관리방식'] = aptInfo['codeSec'].toString();
    }
    if (aptInfo['kaptdScnt'] != null && aptInfo['kaptdScnt'].toString().isNotEmpty) {
      infoItems['보안인력 수'] = '${aptInfo['kaptdScnt']}명';
    }
    if (aptInfo['kaptdSecCom'] != null && aptInfo['kaptdSecCom'].toString().isNotEmpty) {
      infoItems['보안업체'] = aptInfo['kaptdSecCom'].toString();
    }
    
    // 청소 정보
    if (aptInfo['codeClean'] != null && aptInfo['codeClean'].toString().isNotEmpty) {
      infoItems['청소관리방식'] = aptInfo['codeClean'].toString();
    }
    if (aptInfo['kaptdClcnt'] != null && aptInfo['kaptdClcnt'].toString().isNotEmpty) {
      infoItems['청소인력 수'] = '${aptInfo['kaptdClcnt']}명';
    }
    if (aptInfo['codeGarbage'] != null && aptInfo['codeGarbage'].toString().isNotEmpty) {
      infoItems['쓰레기 수거방식'] = aptInfo['codeGarbage'].toString();
    }
    
    // 건물 정보
    if (aptInfo['codeStr'] != null && aptInfo['codeStr'].toString().isNotEmpty) {
      infoItems['건물구조'] = aptInfo['codeStr'].toString();
    }
    if (aptInfo['kaptdEcapa'] != null && aptInfo['kaptdEcapa'].toString().isNotEmpty) {
      infoItems['전기용량'] = '${aptInfo['kaptdEcapa']}kVA';
    }
    if (aptInfo['codeEcon'] != null && aptInfo['codeEcon'].toString().isNotEmpty) {
      infoItems['전기계약방식'] = aptInfo['codeEcon'].toString();
    }
    if (aptInfo['codeEmgr'] != null && aptInfo['codeEmgr'].toString().isNotEmpty) {
      infoItems['전기관리방식'] = aptInfo['codeEmgr'].toString();
    }
    
    // 소방 정보
    if (aptInfo['codeFalarm'] != null && aptInfo['codeFalarm'].toString().isNotEmpty) {
      infoItems['화재경보기 타입'] = aptInfo['codeFalarm'].toString();
    }
    
    // 급수 정보
    if (aptInfo['codeWsupply'] != null && aptInfo['codeWsupply'].toString().isNotEmpty) {
      infoItems['급수방식'] = aptInfo['codeWsupply'].toString();
    }
    
    // 엘리베이터 정보
    if (aptInfo['codeElev'] != null && aptInfo['codeElev'].toString().isNotEmpty) {
      infoItems['엘리베이터 관리방식'] = aptInfo['codeElev'].toString();
    }
    if (aptInfo['kaptdEcnt'] != null && aptInfo['kaptdEcnt'].toString().isNotEmpty) {
      infoItems['엘리베이터 수'] = '${aptInfo['kaptdEcnt']}대';
    }
    
    // 주차 정보
    if (aptInfo['kaptdPcnt'] != null && aptInfo['kaptdPcnt'].toString().isNotEmpty) {
      infoItems['지상주차장 수'] = '${aptInfo['kaptdPcnt']}대';
    }
    if (aptInfo['kaptdPcntu'] != null && aptInfo['kaptdPcntu'].toString().isNotEmpty) {
      infoItems['지하주차장 수'] = '${aptInfo['kaptdPcntu']}대';
    }
    
    // 통신 정보
    if (aptInfo['codeNet'] != null && aptInfo['codeNet'].toString().isNotEmpty) {
      infoItems['인터넷 설치여부'] = aptInfo['codeNet'].toString();
    }
    if (aptInfo['kaptdCccnt'] != null && aptInfo['kaptdCccnt'].toString().isNotEmpty) {
      infoItems['CCTV 수'] = '${aptInfo['kaptdCccnt']}대';
    }
    
    // 편의시설
    if (aptInfo['welfareFacility'] != null && aptInfo['welfareFacility'].toString().isNotEmpty) {
      infoItems['복리시설'] = aptInfo['welfareFacility'].toString();
    }
    
    // 교통 정보
    if (aptInfo['kaptdWtimebus'] != null && aptInfo['kaptdWtimebus'].toString().isNotEmpty) {
      infoItems['버스 도보시간'] = aptInfo['kaptdWtimebus'].toString();
    }
    if (aptInfo['subwayLine'] != null && aptInfo['subwayLine'].toString().isNotEmpty) {
      infoItems['지하철 노선'] = aptInfo['subwayLine'].toString();
    }
    if (aptInfo['subwayStation'] != null && aptInfo['subwayStation'].toString().isNotEmpty) {
      infoItems['지하철역'] = aptInfo['subwayStation'].toString();
    }
    if (aptInfo['kaptdWtimesub'] != null && aptInfo['kaptdWtimesub'].toString().isNotEmpty) {
      infoItems['지하철 도보시간'] = aptInfo['kaptdWtimesub'].toString();
    }
    
    // 주변시설
    if (aptInfo['convenientFacility'] != null && aptInfo['convenientFacility'].toString().isNotEmpty) {
      infoItems['편의시설'] = aptInfo['convenientFacility'].toString();
    }
    if (aptInfo['educationFacility'] != null && aptInfo['educationFacility'].toString().isNotEmpty) {
      infoItems['교육시설'] = aptInfo['educationFacility'].toString();
    }
    
    // 전기차 충전기
    if (aptInfo['groundElChargerCnt'] != null && aptInfo['groundElChargerCnt'].toString() != '0') {
      infoItems['지상 전기차 충전기 수'] = '${aptInfo['groundElChargerCnt']}대';
    }
    if (aptInfo['undergroundElChargerCnt'] != null && aptInfo['undergroundElChargerCnt'].toString() != '0') {
      infoItems['지하 전기차 충전기 수'] = '${aptInfo['undergroundElChargerCnt']}대';
    }

    print('🏢 [ContractStep4DirectDetails] infoItems 생성 완료: $infoItems');
    
    if (infoItems.isEmpty) {
      print('🏢 [ContractStep4DirectDetails] infoItems가 비어있으므로 섹션 숨김');
      return const SizedBox.shrink();
    }

    print('🏢 [ContractStep4DirectDetails] 아파트 기본정보 섹션 반환');
    return _buildSummarySection(
      '아파트 기본정보',
      Icons.apartment_outlined,
      Colors.teal,
      infoItems.entries.map((entry) => 
        _buildSummaryItem(entry.key, entry.value)
      ).toList(),
    );
  }

  /// 건축물대장 정보 백그라운드 로드
  Future<void> _loadBuildingInfo() async {
    try {
      print('🏗️ [ContractStep4DirectDetails] _loadBuildingInfo 시작');
      
      // 테스트용 하드코딩된 데이터 사용
      print('🏗️ [ContractStep4DirectDetails] 테스트용 하드코딩된 데이터 사용');
      final testBuildingInfo = {
        'platPlc': '경기도 성남시 분당구 서현동 96',
        'newPlatPlc': '경기도 성남시 분당구 서현동 96',
        'bldNm': '서현시범우성',
        'splotNm': '',
        'platArea': '12345.67',
        'archArea': '8901.23',
        'totArea': '45678.90',
        'bcRat': '72.2',
        'vlRat': '370.5',
        'mainPurpsCdNm': '공동주택',
        'etcPurps': '상가',
        'hhldCnt': '1119',
        'fmlyCnt': '1119',
        'hoCnt': '1119',
        'mainBldCnt': '16',
        'atchBldCnt': '2',
        'atchBldArea': '1234.56',
        'totPkngCnt': '1976',
        'indrMechUtcnt': '857',
        'indrMechArea': '34567.89',
        'oudrMechUtcnt': '0',
        'oudrMechArea': '0',
        'indrAutoUtcnt': '0',
        'indrAutoArea': '0',
        'oudrAutoUtcnt': '1119',
        'oudrAutoArea': '12345.67',
        'pmsDay': '20010310',
        'stcnsDay': '20010315',
        'useAprDay': '20021220',
        'pmsnoKikCdNm': '성남시',
        'pmsnoGbCdNm': '건축허가',
        'engrGrade': '1+',
        'engrRat': '85.2',
        'engrEpi': '120.5',
        'gnBldGrade': '인증',
        'gnBldCert': '20190315',
        'regstrGbCdNm': '등기부등본',
        'regstrKindCdNm': '토지',
        'bylotCnt': '1'
      };
      
      if (mounted) {
        setState(() {
          _buildingInfo = testBuildingInfo;
        });
        print('✅ [ContractStep4DirectDetails] 테스트 건축물대장 정보 로드 완료: ${testBuildingInfo['bldNm']}');
        print('✅ [ContractStep4DirectDetails] _buildingInfo 상태 업데이트됨: $_buildingInfo');
      }
      
      // 실제 API 호출도 시도해보기
      final address = widget.initialData?['property_address']?.toString() ?? '';
      print('🏗️ [ContractStep4DirectDetails] 추출된 주소: $address');
      
      if (address.isNotEmpty) {
        print('🏗️ [ContractStep4DirectDetails] 실제 API 호출 시도 - 주소: $address');
        
        final params = BuildingInfoService.extractBuildingParamsFromAddress(address);
        print('🏗️ [ContractStep4DirectDetails] 추출된 파라미터: $params');
        
        final buildingInfo = await BuildingInfoService.getBuildingInfo(
          sigunguCd: params['sigunguCd']!,
          bjdongCd: params['bjdongCd']!,
          platGbCd: params['platGbCd']!,
          bun: params['bun']!,
          ji: params['ji']!,
        );
        print('🏗️ [ContractStep4DirectDetails] API 응답 결과: $buildingInfo');
        
        if (buildingInfo != null && mounted) {
          setState(() {
            _buildingInfo = buildingInfo;
          });
          print('✅ [ContractStep4DirectDetails] 실제 API 건축물대장 정보 로드 완료: ${buildingInfo['bldNm']}');
          print('✅ [ContractStep4DirectDetails] _buildingInfo 상태 업데이트됨: $_buildingInfo');
        } else {
          print('⚠️ [ContractStep4DirectDetails] 실제 API에서 건축물대장 정보를 찾을 수 없습니다');
          print('⚠️ [ContractStep4DirectDetails] mounted 상태: $mounted');
        }
      } else {
        print('⚠️ [ContractStep4DirectDetails] 주소가 비어있습니다');
      }
    } catch (e) {
      print('❌ [ContractStep4DirectDetails] 건축물대장 정보 로드 오류: $e');
    }
  }

  /// 건축물대장 정보 섹션
  Widget _buildBuildingInfoSection() {
    print('🏗️ [ContractStep4DirectDetails] _buildBuildingInfoSection 호출됨 - _buildingInfo: $_buildingInfo');
    
    if (_buildingInfo == null) {
      print('🏗️ [ContractStep4DirectDetails] _buildingInfo가 null이므로 섹션 숨김');
      return const SizedBox.shrink();
    }

    final buildingInfo = _buildingInfo!;
    final infoItems = <String, String>{};
    print('🏗️ [ContractStep4DirectDetails] 건축물대장 정보 섹션 빌드 시작 - buildingInfo: $buildingInfo');

    // 기본 정보
    if (buildingInfo['platPlc'] != null && buildingInfo['platPlc'].toString().isNotEmpty) {
      infoItems['대지위치'] = buildingInfo['platPlc'].toString();
    }
    if (buildingInfo['newPlatPlc'] != null && buildingInfo['newPlatPlc'].toString().isNotEmpty) {
      infoItems['새주소'] = buildingInfo['newPlatPlc'].toString();
    }
    if (buildingInfo['bldNm'] != null && buildingInfo['bldNm'].toString().isNotEmpty) {
      infoItems['건물명'] = buildingInfo['bldNm'].toString();
    }
    if (buildingInfo['splotNm'] != null && buildingInfo['splotNm'].toString().isNotEmpty) {
      infoItems['특수지구명'] = buildingInfo['splotNm'].toString();
    }
    
    // 면적 정보
    if (buildingInfo['platArea'] != null && buildingInfo['platArea'].toString().isNotEmpty) {
      infoItems['대지면적'] = '${buildingInfo['platArea']}㎡';
    }
    if (buildingInfo['archArea'] != null && buildingInfo['archArea'].toString().isNotEmpty) {
      infoItems['건축면적'] = '${buildingInfo['archArea']}㎡';
    }
    if (buildingInfo['totArea'] != null && buildingInfo['totArea'].toString().isNotEmpty) {
      infoItems['연면적'] = '${buildingInfo['totArea']}㎡';
    }
    if (buildingInfo['bcRat'] != null && buildingInfo['bcRat'].toString().isNotEmpty) {
      infoItems['건폐율'] = '${buildingInfo['bcRat']}%';
    }
    if (buildingInfo['vlRat'] != null && buildingInfo['vlRat'].toString().isNotEmpty) {
      infoItems['용적율'] = '${buildingInfo['vlRat']}%';
    }
    
    // 용도 정보
    if (buildingInfo['mainPurpsCdNm'] != null && buildingInfo['mainPurpsCdNm'].toString().isNotEmpty) {
      infoItems['주용도명'] = buildingInfo['mainPurpsCdNm'].toString();
    }
    if (buildingInfo['etcPurps'] != null && buildingInfo['etcPurps'].toString().isNotEmpty) {
      infoItems['기타용도'] = buildingInfo['etcPurps'].toString();
    }
    
    // 세대 정보
    if (buildingInfo['hhldCnt'] != null && buildingInfo['hhldCnt'].toString().isNotEmpty) {
      infoItems['세대수'] = '${buildingInfo['hhldCnt']}세대';
    }
    if (buildingInfo['fmlyCnt'] != null && buildingInfo['fmlyCnt'].toString().isNotEmpty) {
      infoItems['가구수'] = '${buildingInfo['fmlyCnt']}가구';
    }
    if (buildingInfo['hoCnt'] != null && buildingInfo['hoCnt'].toString().isNotEmpty) {
      infoItems['호수'] = '${buildingInfo['hoCnt']}호';
    }
    
    // 건물 정보
    if (buildingInfo['mainBldCnt'] != null && buildingInfo['mainBldCnt'].toString().isNotEmpty) {
      infoItems['주건축물수'] = '${buildingInfo['mainBldCnt']}동';
    }
    if (buildingInfo['atchBldCnt'] != null && buildingInfo['atchBldCnt'].toString().isNotEmpty) {
      infoItems['부속건축물수'] = '${buildingInfo['atchBldCnt']}동';
    }
    if (buildingInfo['atchBldArea'] != null && buildingInfo['atchBldArea'].toString().isNotEmpty) {
      infoItems['부속건축물면적'] = '${buildingInfo['atchBldArea']}㎡';
    }
    
    // 주차 정보
    if (buildingInfo['totPkngCnt'] != null && buildingInfo['totPkngCnt'].toString().isNotEmpty) {
      infoItems['총주차수'] = '${buildingInfo['totPkngCnt']}대';
    }
    if (buildingInfo['indrMechUtcnt'] != null && buildingInfo['indrMechUtcnt'].toString().isNotEmpty) {
      infoItems['지하기계식주차수'] = '${buildingInfo['indrMechUtcnt']}대';
    }
    if (buildingInfo['indrAutoUtcnt'] != null && buildingInfo['indrAutoUtcnt'].toString().isNotEmpty) {
      infoItems['지하자동식주차수'] = '${buildingInfo['indrAutoUtcnt']}대';
    }
    if (buildingInfo['oudrAutoUtcnt'] != null && buildingInfo['oudrAutoUtcnt'].toString().isNotEmpty) {
      infoItems['지상자동식주차수'] = '${buildingInfo['oudrAutoUtcnt']}대';
    }
    
    // 허가 정보
    if (buildingInfo['pmsDay'] != null && buildingInfo['pmsDay'].toString().isNotEmpty) {
      infoItems['허가일'] = buildingInfo['pmsDay'].toString();
    }
    if (buildingInfo['stcnsDay'] != null && buildingInfo['stcnsDay'].toString().isNotEmpty) {
      infoItems['착공일'] = buildingInfo['stcnsDay'].toString();
    }
    if (buildingInfo['useAprDay'] != null && buildingInfo['useAprDay'].toString().isNotEmpty) {
      infoItems['사용승인일'] = buildingInfo['useAprDay'].toString();
    }
    if (buildingInfo['pmsnoKikCdNm'] != null && buildingInfo['pmsnoKikCdNm'].toString().isNotEmpty) {
      infoItems['허가관리기관명'] = buildingInfo['pmsnoKikCdNm'].toString();
    }
    if (buildingInfo['pmsnoGbCdNm'] != null && buildingInfo['pmsnoGbCdNm'].toString().isNotEmpty) {
      infoItems['허가구분명'] = buildingInfo['pmsnoGbCdNm'].toString();
    }
    
    // 에너지 정보
    if (buildingInfo['engrGrade'] != null && buildingInfo['engrGrade'].toString().isNotEmpty) {
      infoItems['에너지등급'] = buildingInfo['engrGrade'].toString();
    }
    if (buildingInfo['engrRat'] != null && buildingInfo['engrRat'].toString().isNotEmpty) {
      infoItems['에너지비율'] = '${buildingInfo['engrRat']}%';
    }
    if (buildingInfo['engrEpi'] != null && buildingInfo['engrEpi'].toString().isNotEmpty) {
      infoItems['에너지성능지수'] = buildingInfo['engrEpi'].toString();
    }
    if (buildingInfo['gnBldGrade'] != null && buildingInfo['gnBldGrade'].toString().isNotEmpty) {
      infoItems['그린건축인증등급'] = buildingInfo['gnBldGrade'].toString();
    }
    if (buildingInfo['gnBldCert'] != null && buildingInfo['gnBldCert'].toString().isNotEmpty) {
      infoItems['그린건축인증일'] = buildingInfo['gnBldCert'].toString();
    }

    print('🏗️ [ContractStep4DirectDetails] infoItems 생성 완료: $infoItems');
    
    if (infoItems.isEmpty) {
      print('🏗️ [ContractStep4DirectDetails] infoItems가 비어있으므로 섹션 숨김');
      return const SizedBox.shrink();
    }

    print('🏗️ [ContractStep4DirectDetails] 건축물대장 정보 섹션 반환');
    return _buildSummarySection(
      '건축물대장 정보',
      Icons.business_outlined,
      Colors.indigo,
      infoItems.entries.map((entry) => 
        _buildSummaryItem(entry.key, entry.value)
      ).toList(),
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
