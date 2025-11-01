import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/screens/chat/chat_screen.dart';
import 'package:property/screens/visit/visit_request_form.dart';
import 'electronic_checklist_screen.dart';
import 'package:property/widgets/maintenance_fee_card.dart';
import 'package:property/models/maintenance_fee.dart';

class HouseDetailPage extends StatefulWidget {
  final Property property;
  final String imagePath;
  final String currentUserId;
  final String currentUserName;
  
  const HouseDetailPage({
    required this.property, 
    required this.imagePath, 
    required this.currentUserId,
    required this.currentUserName,
    super.key
  });

  @override
  State<HouseDetailPage> createState() => _HouseDetailPageState();
}

class _HouseDetailPageState extends State<HouseDetailPage> {
  // 위치 기반 확인 관련 변수들
  bool _showLocationInfo = false;
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  String _currentAddress = '';
  String _propertyAddress = '';
  double? _distance;

  int? _getTotalAmount() {
    try {
      final regData = widget.property.registerData;
      if (regData.isNotEmpty && regData != '{}') {
        final map = json.decode(regData);
        if (map['total_amount'] != null) {
          return int.tryParse(map['total_amount'].toString().replaceAll(',', ''));
        }
      }
    } catch (_) {}
    return null;
  }

  String _formatCurrency(int value) {
    if (value >= 100000000) {
      final eok = value ~/ 100000000;
      final man = (value % 100000000) ~/ 10000;
      if (man == 0) {
        return '${_addComma(eok)}억원';
      } else {
        return '${_addComma(eok)}억${_addComma(man)}만원';
      }
    } else if (value >= 10000) {
      final man = value ~/ 10000;
      final rest = value % 10000;
      return rest == 0 ? '${_addComma(man)}만원' : '${_addComma(man)}만${_addComma(rest)}원';
    }
    return '${_addComma(value)}원';
  }

  // 위치 기반 확인 기능
  Future<void> _toggleLocationInfo() async {
    if (_showLocationInfo) {
      setState(() {
        _showLocationInfo = false;
      });
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _showLocationInfo = true;
    });

    try {
      print('📍 [위치기반확인] 위치 정보 가져오기 시작');
      
      // 1. 사용자의 firstZone 정보를 먼저 확인
      print('📍 [위치기반확인] 사용자 firstZone 정보 확인 중...');
      final userData = await FirebaseService().getUser(widget.currentUserId);
      
      if (userData != null && userData['firstZone'] != null && userData['firstZone'].toString().isNotEmpty) {
        _currentAddress = userData['firstZone'].toString();
        print('📍 [위치기반확인] firstZone에서 주소 가져옴: $_currentAddress');
        
        // firstZone 주소를 좌표로 변환
        try {
          final location = await locationFromAddress(_currentAddress);
          if (location.isNotEmpty) {
            final latLng = location.first;
            _currentPosition = Position(
              latitude: latLng.latitude,
              longitude: latLng.longitude,
              timestamp: DateTime.now(),
              accuracy: 10.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            );
            print('📍 [위치기반확인] firstZone 좌표 변환 성공: lat=${_currentPosition?.latitude}, lng=${_currentPosition?.longitude}');
          } else {
            print('📍 [위치기반확인] firstZone 주소를 좌표로 변환 실패');
            _currentPosition = null;
          }
        } catch (e) {
          print('❌ [위치기반확인] firstZone 좌표 변환 오류: $e');
          _currentPosition = null;
        }
      } else {
        print('📍 [위치기반확인] firstZone 정보 없음 - GPS 위치 사용');
        
        // 2. firstZone이 없으면 GPS 위치 사용
        await _getGpsLocation();
      }

      // 매물 주소 설정 및 거리 계산
      if (_currentAddress.isNotEmpty) {
        _propertyAddress = widget.property.address.isNotEmpty ? widget.property.address : '주소 정보 없음';
        print('📍 [위치기반확인] 매물 주소: $_propertyAddress');

        // 거리 계산
        await _calculateDistance();
      }

    } catch (e) {
      print('❌ [위치기반확인] 전체 오류: $e');
      _showLocationError('위치 정보를 가져오는 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  // GPS 위치 가져오기
  Future<void> _getGpsLocation() async {
    try {
      print('📍 [GPS위치] 위치 권한 확인 시작');
      
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 [GPS위치] 현재 권한 상태: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('📍 [GPS위치] 권한 요청 후 상태: $permission');
        if (permission == LocationPermission.denied) {
          _showLocationError('위치 권한이 거부되었습니다.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
        return;
      }

      print('📍 [GPS위치] 현재 위치 가져오기 시작');
      
      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 [GPS위치] 위치 서비스 활성화 상태: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('📍 [GPS위치] 위치 서비스 비활성화 - 테스트 모드로 전환');
        // Windows에서 위치 서비스가 비활성화된 경우 테스트용 위치 사용
        _currentPosition = Position(
          latitude: 37.5665, // 서울시청 좌표
          longitude: 126.9780,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        _currentAddress = '서울특별시 중구 세종대로 110';
        print('📍 [GPS위치] 테스트 위치 설정: $_currentAddress');
      } else {
        // 현재 위치 가져오기
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // 10초 타임아웃
        );

        print('📍 [GPS위치] 현재 위치 획득: lat=${_currentPosition?.latitude}, lng=${_currentPosition?.longitude}');

        // 현재 위치를 주소로 변환
        if (_currentPosition != null) {
          try {
            print('📍 [GPS위치] 주소 변환 시작');
            final placemarks = await placemarkFromCoordinates(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            );

            print('📍 [GPS위치] 주소 변환 결과: ${placemarks.length}개');

            if (placemarks.isNotEmpty) {
              final placemark = placemarks.first;
              print('📍 [GPS위치] 주소 정보: ${placemark.administrativeArea}, ${placemark.locality}, ${placemark.thoroughfare}, ${placemark.subThoroughfare}');
              
              // null 체크를 더 안전하게 처리
              final adminArea = placemark.administrativeArea ?? '';
              final locality = placemark.locality ?? '';
              final thoroughfare = placemark.thoroughfare ?? '';
              final subThoroughfare = placemark.subThoroughfare ?? '';
              
              _currentAddress = '$adminArea $locality $thoroughfare $subThoroughfare'.trim();
              print('📍 [GPS위치] 최종 현재 주소: $_currentAddress');
            } else {
              _currentAddress = '주소 정보를 가져올 수 없습니다';
              print('📍 [GPS위치] 주소 정보 없음');
            }
          } catch (e) {
            print('❌ [GPS위치] 주소 변환 오류: $e');
            _currentAddress = '주소 변환 실패';
          }
        } else {
          print('❌ [GPS위치] 현재 위치가 null입니다');
        }
      }
    } catch (e) {
      print('❌ [GPS위치] GPS 위치 가져오기 오류: $e');
      _currentAddress = 'GPS 위치 가져오기 실패';
    }
  }

  // 거리 계산
  Future<void> _calculateDistance() async {
    try {
      print('📍 [거리계산] 거리 계산 시작');
      print('📍 [거리계산] 매물 주소: $_propertyAddress');
      print('📍 [거리계산] 현재 위치: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      
      if (_propertyAddress.isEmpty || _propertyAddress == '주소 정보 없음') {
        print('📍 [거리계산] 매물 주소가 유효하지 않음');
        _distance = null;
        return;
      }

      if (_currentPosition == null) {
        print('📍 [거리계산] 현재 위치가 null');
        _distance = null;
        return;
      }

      print('📍 [거리계산] 매물 주소를 좌표로 변환 시작');
      
      // 매물 주소를 좌표로 변환
      final propertyLocation = await locationFromAddress(_propertyAddress);
      print('📍 [거리계산] 매물 좌표 변환 결과: ${propertyLocation.length}개');
      
      if (propertyLocation.isNotEmpty) {
        final propertyLatLng = propertyLocation.first;
        print('📍 [거리계산] 매물 좌표: ${propertyLatLng.latitude}, ${propertyLatLng.longitude}');
        
        // 안전한 거리 계산
        try {
          _distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            propertyLatLng.latitude,
            propertyLatLng.longitude,
          );
          
          print('📍 [거리계산] 계산된 거리: ${_distance}m');
        } catch (e) {
          print('❌ [거리계산] 거리 계산 중 오류: $e');
          _distance = null;
        }
      } else {
        print('📍 [거리계산] 매물 좌표 변환 실패');
        _distance = null;
      }
    } catch (e) {
      print('❌ [거리계산] 거리 계산 오류: $e');
      _distance = null;
    }
  }

  // 위치 오류 메시지 표시
  void _showLocationError(String message) {
    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
        _showLocationInfo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _addComma(int value) {
    return value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // 위치 정보 카드 위젯
  Widget _buildLocationInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '위치 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingLocation) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('위치 정보를 가져오는 중...'),
                ],
              ),
            ),
          ] else ...[
            // 현재 위치 정보
            _buildLocationRow(
              '현재 위치',
              _currentAddress.isNotEmpty ? _currentAddress : '위치 정보 없음',
              Icons.my_location,
              Colors.green,
            ),
            const SizedBox(height: 12),
            
            // 매물 위치 정보
            _buildLocationRow(
              '매물 위치',
              _propertyAddress.isNotEmpty ? _propertyAddress : '주소 정보 없음',
              Icons.home,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            
            // 거리 정보
            if (_distance != null) ...[
              _buildLocationRow(
                '거리',
                _formatDistance(_distance!),
                Icons.straighten,
                Colors.purple,
              ),
            ] else ...[
              _buildLocationRow(
                '거리',
                '계산 중...',
                Icons.straighten,
                Colors.grey,
              ),
            ],
            const SizedBox(height: 12),
            
            // 대중교통 정보
            _buildTransportationInfo(),
          ],
        ],
      ),
    );
  }

  // 위치 정보 행 위젯
  Widget _buildLocationRow(String label, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 거리 포맷팅
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  // 대중교통 정보 위젯
  Widget _buildTransportationInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.directions_bus,
                color: Colors.blue,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                '대중교통 정보',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 버스 노선 그림
          _buildBusRouteDiagram(),
          const SizedBox(height: 8),
          
          // 예상 소요시간 정보
          _buildTransportationTime(),
        ],
      ),
    );
  }

  // 버스 노선 다이어그램
  Widget _buildBusRouteDiagram() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // 현재 위치 (firstZone)
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '출발',
            style: TextStyle(fontSize: 10, color: Colors.green),
          ),
          
          // 버스 노선
          Expanded(
            child: SizedBox(
              height: 2,
              child: CustomPaint(
                painter: BusRoutePainter(),
              ),
            ),
          ),
          
          // 매물 위치
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '도착',
            style: TextStyle(fontSize: 10, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  // 대중교통 소요시간 정보
  Widget _buildTransportationTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 첫 번째 경로
        _buildTransportationRoute(
          icon: Icons.directions_bus,
          time: '1시간 10분',
          route: '1557번 버스',
          transfer: '환승 1회 (지하철 2호선)',
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        
        // 두 번째 경로
        _buildTransportationRoute(
          icon: Icons.train,
          time: '45분',
          route: '지하철 2호선 → 3호선',
          transfer: '환승 2회',
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        
        // 세 번째 경로
        _buildTransportationRoute(
          icon: Icons.directions_bus,
          time: '1시간 25분',
          route: '146번 버스 → 5007번 버스',
          transfer: '환승 1회',
          color: Colors.orange,
        ),
      ],
    );
  }

  // 대중교통 경로 위젯
  Widget _buildTransportationRoute({
    required IconData icon,
    required String time,
    required String route,
    required String transfer,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '예상 시간: $time',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.route,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  route,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.transfer_within_a_station,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                transfer,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _showJsonDialog(BuildContext context, String title, String? jsonString) {
    String prettyJson;
    try {
      final safeJson = (jsonString == null || jsonString.trim().isEmpty) ? '{}' : jsonString;
      final jsonObj = json.decode(safeJson);
      prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObj);
    } catch (e) {
      prettyJson = 'JSON 파싱 오류 또는 데이터 없음\n\n$e';
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(prettyJson, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 내 매물인지 확인 (사용자 정보 필드 사용)
    final isMyProperty = widget.property.userMainContractor == widget.currentUserName || 
                         widget.property.registeredBy == widget.currentUserName;
    final totalAmount = _getTotalAmount();
    
    // 디버그: 매물 소유권 확인
    print('🔍 [HouseDetailPage] 매물 소유권 확인:');
    print('   - property.userMainContractor: ${widget.property.userMainContractor}');
    print('   - property.registeredBy: ${widget.property.registeredBy}');
    print('   - currentUserName: ${widget.currentUserName}');
    print('   - isMyProperty: $isMyProperty');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '매물 상세',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.kBrown,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // 이미지
            Stack(
              children: [
                Image.asset(
                  widget.imagePath,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.home, size: 64, color: Colors.grey)),
                  ),
                ),
                if (isMyProperty)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.kBrown,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '내 매물',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 주소
                  Text(
                    widget.property.address,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 가격 정보
                  if (totalAmount != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.kBrown.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.kBrown.withValues(alpha:0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, color: AppColors.kBrown),
                          const SizedBox(width: 8),
                          Text(
                            '총 가격: ${_formatCurrency(totalAmount)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.kBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 등록자 정보
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMyProperty 
                          ? AppColors.kBrown.withValues(alpha:0.2)
                          : AppColors.kBrown.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: isMyProperty 
                          ? Border.all(color: AppColors.kBrown, width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMyProperty ? Icons.person : Icons.person_outline,
                          color: AppColors.kBrown,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '등록자: ${widget.property.mainContractor}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.kBrown,
                            fontWeight: isMyProperty ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 관리비 투명성 카드 (시뮬레이션 데이터)
                  _buildMaintenanceFeeCard(),
                  
                  const SizedBox(height: 16),
                  
                  // 거래 유형
                  _buildInfoRow('거래 유형', widget.property.transactionType),
                  
                  // 건물 구조
                  if (widget.property.structure != null && widget.property.structure!.isNotEmpty)
                    _buildInfoRow('건물 구조', widget.property.structure!),
                  
                  // 면적
                  if (widget.property.area != null)
                    _buildInfoRow('면적', '${widget.property.area}㎡'),
                  
                  // 등록일
                  _buildInfoRow('등록일', _formatDate(widget.property.createdAt)),
                  
                  const SizedBox(height: 16),
                  
                  // 위치 기반 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _toggleLocationInfo,
                      icon: Icon(_showLocationInfo ? Icons.location_off : Icons.location_on),
                      label: Text(_showLocationInfo ? '위치 정보 숨기기' : '위치 기반 확인'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showLocationInfo ? Colors.grey : Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 위치 정보 표시 섹션
                  if (_showLocationInfo) ...[
                    _buildLocationInfoCard(),
                    const SizedBox(height: 16),
                  ],
                  
                  // 계약 조건 및 예상 금액
                  _buildContractConditionsCard(),
                  
                  const SizedBox(height: 16),
                  
                  // 관리비 투명성
                  _buildMaintenanceFeeTransparencyCard(),
                  
                  const SizedBox(height: 16),

                  // 액션 버튼들
                  if (!isMyProperty) ...[
                    // 가계약/예약 버튼 (전자체크리스트 게이트)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => ElectronicChecklistScreen(
                                property: widget.property,
                                userName: widget.currentUserName,
                                currentUserId: widget.currentUserId,
                              ),
                            ),
                          );
                          if (result == true) {
                            // 체크리스트 완료 시 가계약 화면으로 이동
                            if(context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '모든 확인사항이 완료되었습니다. 가계약을 진행합니다.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            // TODO: 가계약 화면으로 이동
                          }
                        },
                        icon: const Icon(Icons.checklist),
                        label: const Text('가계약/예약'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 방문 신청 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => VisitRequestForm(
                                property: widget.property,
                                currentUserId: widget.currentUserId,
                                currentUserName: widget.currentUserName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('방문 신청'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // 등록자 문의하기 버튼 (내 매물이 아닐 때만 표시)
                  if (!isMyProperty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                property: widget.property,
                                currentUserId: widget.currentUserId,
                                currentUserName: widget.currentUserName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('등록자 문의하기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.kBrown,
                          side: const BorderSide(color: AppColors.kBrown),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // 내 매물일 때 표시할 정보
                  if (isMyProperty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.kBrown.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.kBrown.withValues(alpha:0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.person,
                            color: AppColors.kBrown,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '내가 등록한 매물입니다',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.kBrown,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '방문 신청과 문의는 다른 사용자만 할 수 있습니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.kBrown.withValues(alpha:0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // 상세 정보 섹션들
                  _buildDetailedPropertyInfo(isMyProperty),
                  
                  const SizedBox(height: 24),
                  
                  // 상세 정보 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showJsonDialog(context, '등기부등본 데이터', widget.property.registerData),
                          child: const Text('등기부등본'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showJsonDialog(context, '상세 정보', widget.property.detailFormJson),
                          child: const Text('상세 정보'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceFeeCard() {
    // 시뮬레이션 관리비 데이터 생성
    final maintenanceFee = MaintenanceFee(
      amount: 120000, // 12만원
      area: 25.0, // 25㎡
      includedItems: ['엘리베이터', '경비', '청소'],
      excludedItems: ['전기', '가스', '수도', '난방'],
      region: '강남구',
      lastUpdated: DateTime.now(),
      monthlyHistory: [
        MonthlyFee(date: DateTime(2024, 1), amount: 115000),
        MonthlyFee(date: DateTime(2024, 2), amount: 118000),
        MonthlyFee(date: DateTime(2024, 3), amount: 120000),
        MonthlyFee(date: DateTime(2024, 4), amount: 122000),
        MonthlyFee(date: DateTime(2024, 5), amount: 120000),
        MonthlyFee(date: DateTime(2024, 6), amount: 125000),
        MonthlyFee(date: DateTime(2024, 7), amount: 120000),
        MonthlyFee(date: DateTime(2024, 8), amount: 118000),
        MonthlyFee(date: DateTime(2024, 9), amount: 120000),
        MonthlyFee(date: DateTime(2024, 10), amount: 122000),
        MonthlyFee(date: DateTime(2024, 11), amount: 120000),
        MonthlyFee(date: DateTime(2024, 12), amount: 120000),
      ],
    );

    return MaintenanceFeeCard(
      maintenanceFee: maintenanceFee,
      isCompact: false,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.kDarkBrown,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContractConditionsCard() {
    // 시뮬레이션 데이터 - 실제로는 매물 정보에서 가져와야 함
    final contractConditions = {
      'deposit': 50000000, // 보증금 5천만원
      'monthlyRent': 500000, // 월세 50만원 (전세인 경우 0)
      'contractFee': 1000000, // 계약금 100만원
      'managementFee': 120000, // 관리비 12만원
      'keyMoney': 500000, // 열쇠 교체비 5만원
      'insuranceFee': 200000, // 보험료 20만원
      'taxFee': 150000, // 취득세 등 15만원
      'brokerFee': 0, // 중개수수료 (직거래인 경우 0)
    };

    final totalAmount = contractConditions.values.reduce((a, b) => a + b);
    final isJeonse = widget.property.transactionType == '전세';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBrown.withValues(alpha:0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.account_balance_wallet,
                color: AppColors.kBrown,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '계약 조건 및 예상 금액',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 계약 조건
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.kBrown.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '계약 조건',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                _buildConditionRow('보증금', _formatCurrency(contractConditions['deposit']!)),
                if (!isJeonse)
                  _buildConditionRow('월세', _formatCurrency(contractConditions['monthlyRent']!)),
                _buildConditionRow('계약기간', '2년'),
                _buildConditionRow('갱신여부', '갱신 가능'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 예상 금액
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '예상 지불 금액',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                _buildAmountRow('계약금', contractConditions['contractFee']!, isHighlight: true),
                _buildAmountRow('관리비 (1개월)', contractConditions['managementFee']!),
                _buildAmountRow('열쇠 교체비', contractConditions['keyMoney']!),
                _buildAmountRow('보험료', contractConditions['insuranceFee']!),
                _buildAmountRow('취득세 등', contractConditions['taxFee']!),
                
                const Divider(height: 20),
                
                // 총 금액
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '총 예상 금액',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      _formatCurrency(totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 안내 문구
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '실제 금액은 계약 시 협의에 따라 달라질 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceFeeTransparencyCard() {
    // 시뮬레이션 데이터 - 실제로는 매물 정보에서 가져와야 함
    final maintenanceFee = MaintenanceFee(
      amount: 120000, // 관리비 12만원
      area: 84.0, // 면적 84㎡
      region: '강남구', // 지역
      includedItems: [
        '전기료',
        '수도료', 
        '가스료',
        '청소비',
        '경비비',
        '승강기 유지비',
      ],
      excludedItems: [
        '난방비',
        '인터넷',
        'TV',
        '주차비',
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kBrown.withValues(alpha:0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
              Icon(
                Icons.account_balance_wallet,
                color: AppColors.kBrown,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '관리비 투명성',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              // 관리비 수준 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: maintenanceFee.level.color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: maintenanceFee.level.color),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      maintenanceFee.level.icon,
                      size: 12,
                      color: maintenanceFee.level.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '관리비 ${maintenanceFee.level.displayName}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: maintenanceFee.level.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 관리비 금액
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '월 관리비',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  '${maintenanceFee.amount.toStringAsFixed(0)}원',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 포함 항목
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '포함 항목',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: maintenanceFee.includedItems.map((item) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 제외 항목
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      color: Colors.orange[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '제외 항목',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: maintenanceFee.excludedItems.map((item) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 안내 문구
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '관리비는 매월 1일 기준으로 부과되며, 실제 사용량에 따라 변동될 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7F8C8D),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, int amount, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight ? AppColors.kBrown : const Color(0xFF7F8C8D),
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.kBrown : const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  // 상세 매물 정보 섹션
  Widget _buildDetailedPropertyInfo(bool isMyProperty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기본 정보 섹션
        _buildInfoSection(
          title: '기본 정보',
          icon: Icons.info_outline,
          color: Colors.blue,
          children: [
            if (widget.property.buildingName != null && widget.property.buildingName!.isNotEmpty)
              _buildDetailRow('건물명', widget.property.buildingName!),
            if (widget.property.buildingType != null && widget.property.buildingType!.isNotEmpty)
              _buildDetailRow('건물 유형', widget.property.buildingType!),
            if (widget.property.totalFloors != null)
              _buildDetailRow('전체 층수', '${widget.property.totalFloors}층'),
            if (widget.property.floor != null)
              _buildDetailRow('해당 층', '${widget.property.floor}층'),
            if (widget.property.area != null)
              _buildDetailRow('면적', '${widget.property.area}㎡'),
            if (widget.property.structure != null && widget.property.structure!.isNotEmpty)
              _buildDetailRow('구조', widget.property.structure!),
            if (widget.property.buildingYear != null && widget.property.buildingYear!.isNotEmpty)
              _buildDetailRow('건축년도', widget.property.buildingYear!),
          ],
        ),
        
        const SizedBox(height: 16),
        
        
        // 건물 상세 정보 섹션
        _buildInfoSection(
          title: '건물 상세 정보',
          icon: Icons.home_outlined,
          color: Colors.orange,
          children: [
            if (widget.property.buildingNumber != null && widget.property.buildingNumber!.isNotEmpty)
              _buildDetailRow('건물번호', widget.property.buildingNumber!),
            if (widget.property.exclusiveArea != null && widget.property.exclusiveArea!.isNotEmpty)
              _buildDetailRow('전용면적', widget.property.exclusiveArea!),
            if (widget.property.commonArea != null && widget.property.commonArea!.isNotEmpty)
              _buildDetailRow('공용면적', widget.property.commonArea!),
            if (widget.property.parkingArea != null && widget.property.parkingArea!.isNotEmpty)
              _buildDetailRow('주차면적', widget.property.parkingArea!),
            if (widget.property.buildingPermit != null && widget.property.buildingPermit!.isNotEmpty)
              _buildDetailRow('건축허가', widget.property.buildingPermit!),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 토지 정보 섹션
        _buildInfoSection(
          title: '토지 정보',
          icon: Icons.landscape_outlined,
          color: Colors.brown,
          children: [
            if (widget.property.landNumber != null && widget.property.landNumber!.isNotEmpty)
              _buildDetailRow('토지번호', widget.property.landNumber!),
            if (widget.property.landArea != null)
              _buildDetailRow('토지면적', '${widget.property.landArea}㎡'),
            if (widget.property.landPurpose != null && widget.property.landPurpose!.isNotEmpty)
              _buildDetailRow('토지 지목', widget.property.landPurpose!),
            if (widget.property.landRatio != null && widget.property.landRatio!.isNotEmpty)
              _buildDetailRow('토지지분', widget.property.landRatio!),
            if (widget.property.landUse != null && widget.property.landUse!.isNotEmpty)
              _buildDetailRow('토지용도', widget.property.landUse!),
            if (widget.property.landCategory != null && widget.property.landCategory!.isNotEmpty)
              _buildDetailRow('토지분류', widget.property.landCategory!),
          ],
        ),
        
        const SizedBox(height: 16),
        
        
        
        // 시세 정보 섹션
        _buildInfoSection(
          title: '시세 정보',
          icon: Icons.trending_up_outlined,
          color: Colors.teal,
          children: [
            if (widget.property.estimatedValue != null && widget.property.estimatedValue!.isNotEmpty)
              _buildDetailRow('감정가', widget.property.estimatedValue!),
            if (widget.property.marketValue != null && widget.property.marketValue!.isNotEmpty)
              _buildDetailRow('시세', widget.property.marketValue!),
            if (widget.property.recentTransaction != null && widget.property.recentTransaction!.isNotEmpty)
              _buildDetailRow('최근 거래가', widget.property.recentTransaction!),
            if (widget.property.aiConfidence != null && widget.property.aiConfidence!.isNotEmpty)
              _buildDetailRow('AI 신뢰도', widget.property.aiConfidence!),
          ],
        ),
        
        const SizedBox(height: 16),
        
        
        
        // 중개업자 정보 섹션 (중개업자 거래인 경우에만 표시)
        if (widget.property.brokerInfo != null && widget.property.brokerInfo!.isNotEmpty) ...[
          _buildInfoSection(
            title: '중개업자 정보',
            icon: Icons.business_outlined,
            color: Colors.amber,
            children: [
              if (widget.property.brokerInfo!['name'] != null)
                _buildDetailRow('대표 중개업자명', widget.property.brokerInfo!['name'].toString()),
              if (widget.property.brokerInfo!['phone'] != null)
                _buildDetailRow('연락처', widget.property.brokerInfo!['phone'].toString()),
              if (widget.property.brokerInfo!['license'] != null)
                _buildDetailRow('중개업 등록번호', widget.property.brokerInfo!['license'].toString()),
              if (widget.property.brokerInfo!['address'] != null)
                _buildDetailRow('주소', widget.property.brokerInfo!['address'].toString()),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // 특약사항 정보 섹션 (선택된 특약사항이 있는 경우에만 표시)
        if (widget.property.selectedClauses != null && widget.property.selectedClauses!.isNotEmpty) ...[
          _buildInfoSection(
            title: '선택된 특약사항',
            icon: Icons.checklist_outlined,
            color: Colors.green,
            children: [
              ...widget.property.selectedClauses!.entries.map((entry) {
                final clauseName = _getClauseDisplayName(entry.key);
                final isSelected = entry.value;
                return _buildDetailRow(
                  clauseName,
                  isSelected ? '선택됨' : '선택 안됨',
                  valueColor: isSelected ? Colors.green : Colors.grey,
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // 상세 폼 데이터 섹션 (상세 폼 데이터가 있는 경우에만 표시)
        if (widget.property.detailFormData != null && widget.property.detailFormData!.isNotEmpty) ...[
          _buildInfoSection(
            title: '상세 입력 정보',
            icon: Icons.edit_outlined,
            color: Colors.cyan,
            children: [
              ...widget.property.detailFormData!.entries.map((entry) {
                final key = entry.key;
                final value = entry.value;
                if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
                
                final displayKey = _getFormFieldDisplayName(key);
                final displayValue = _formatFormFieldValue(key, value);
                
                return _buildDetailRow(displayKey, displayValue);
              }).toList(),
            ],
          ),
        ],
      ],
    );
  }

  // 정보 섹션 위젯
  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
              Icon(
                icon,
                color: color,
                size: 20,
              ),
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // 상세 정보 행 위젯
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? const Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 특약사항 표시명 변환
  String _getClauseDisplayName(String key) {
    switch (key) {
      case 'dispute_mediation':
        return '분쟁조정 특약';
      case 'termination_right':
        return '해지권 특약';
      case 'overdue_exception':
        return '연체 예외 특약';
      default:
        return key;
    }
  }

  // 폼 필드 표시명 변환
  String _getFormFieldDisplayName(String key) {
    switch (key) {
      case 'landlord_name':
        return '임대인 성명';
      case 'landlord_phone':
        return '임대인 연락처';
      case 'landlord_address':
        return '임대인 주소';
      case 'tenant_name':
        return '임차인 성명';
      case 'tenant_phone':
        return '임차인 연락처';
      case 'tenant_address':
        return '임차인 주소';
      case 'tenant_id':
        return '임차인 주민등록번호';
      case 'property_address':
        return '부동산 주소';
      case 'deposit':
        return '보증금';
      case 'monthly_rent':
        return '월세';
      case 'management_fee':
        return '관리비';
      case 'contract_type':
        return '계약 종류';
      case 'rental_type':
        return '임대차 유형';
      case 'deal_type':
        return '거래 방식';
      case 'contract_date':
        return '계약서 작성일';
      case 'special_terms':
        return '특약사항';
      case 'has_expected_tenant':
        return '예정된 임차인';
      case 'broker_name':
        return '대표 중개업자명';
      case 'broker_phone':
        return '중개업자 연락처';
      case 'broker_license':
        return '중개업 등록번호';
      case 'broker_address':
        return '중개업자 주소';
      // 수도 관련 필드
      case 'water_damage':
        return '수도 파손여부';
      case 'water_flow_condition':
        return '용수량';
      // 전기 관련 필드
      case 'electricity_condition':
        return '전기 상태';
      // 가스 관련 필드
      case 'gas_type':
        return '가스 종류';
      case 'gas_condition':
        return '가스 상태';
      // 소방 관련 필드
      case 'fire_extinguisher':
        return '소화기 설치';
      case 'fire_extinguisher_location':
        return '소화기 위치';
      case 'fire_alarm':
        return '화재경보기';
      case 'emergency_exit':
        return '비상구';
      case 'emergency_exit_location':
        return '비상구 위치';
      case 'fire_facilities_notes':
        return '소방시설 특이사항';
      // 배수 관련 필드
      case 'drainage_condition':
        return '배수 상태';
      case 'drainage_notes':
        return '배수 특이사항';
      // 벽면/바닥/도배 관련 필드
      case 'wall_crack':
        return '벽면 균열';
      case 'wall_leak':
        return '벽면 누수';
      case 'floor_condition':
        return '바닥면';
      case 'wallpaper_condition':
        return '도배';
      case 'wall_floor_notes':
        return '벽면/바닥 특이사항';
      default:
        return key;
    }
  }

  // 폼 필드 값 포맷팅
  String _formatFormFieldValue(String key, dynamic value) {
    if (value == null) return '';
    
    switch (key) {
      case 'deposit':
      case 'monthly_rent':
      case 'management_fee':
        if (value is int) {
          return _formatCurrency(value);
        } else if (value is String) {
          final intValue = int.tryParse(value);
          if (intValue != null) {
            return _formatCurrency(intValue);
          }
        }
        return value.toString();
      case 'contract_type':
        return value == 'new' ? '신규계약' : '갱신계약';
      case 'rental_type':
        return value == 'jeonse' ? '전세' : '월세';
      case 'deal_type':
        return value == 'direct' ? '직거래' : '중개업자';
      case 'has_expected_tenant':
        return value == true ? '예' : '아니오';
      case 'contract_date':
        if (value is String) {
          try {
            final date = DateTime.parse(value);
            return _formatDate(date);
          } catch (e) {
            return value;
          }
        }
        return value.toString();
      // 수도 관련 필드 값 포맷팅
      case 'water_damage':
        return value == 'yes' ? '있음' : '없음';
      case 'water_flow_condition':
        return value == 'normal' ? '정상' : '비정상';
      // 전기 관련 필드 값 포맷팅
      case 'electricity_condition':
        switch (value) {
          case 'good':
            return '양호';
          case 'normal':
            return '보통';
          case 'poor':
            return '불량';
          default:
            return value.toString();
        }
      // 가스 관련 필드 값 포맷팅
      case 'gas_type':
        switch (value) {
          case 'city_gas':
            return '도시가스';
          case 'lpg':
            return 'LPG';
          case 'none':
            return '없음';
          default:
            return value.toString();
        }
      case 'gas_condition':
        switch (value) {
          case 'good':
            return '양호';
          case 'normal':
            return '보통';
          case 'poor':
            return '불량';
          default:
            return value.toString();
        }
      // 소방 관련 필드 값 포맷팅
      case 'fire_extinguisher':
        return value == 'yes' ? '있음' : '없음';
      case 'fire_alarm':
        return value == 'yes' ? '있음' : '없음';
      case 'emergency_exit':
        return value == 'yes' ? '있음' : '없음';
      // 배수 관련 필드 값 포맷팅
      case 'drainage_condition':
        return value == 'normal' ? '정상' : '수선 필요';
      // 벽면/바닥/도배 관련 필드 값 포맷팅
      case 'wall_crack':
        return value == 'yes' ? '있음' : '없음';
      case 'wall_leak':
        return value == 'yes' ? '있음' : '없음';
      case 'floor_condition':
        switch (value) {
          case 'clean':
            return '깨끗함';
          case 'normal':
            return '보통';
          case 'repair_needed':
            return '수리필요';
          default:
            return value.toString();
        }
      case 'wallpaper_condition':
        switch (value) {
          case 'clean':
            return '깨끗함';
          case 'normal':
            return '보통';
          case 'wallpaper_needed':
            return '도배필요';
          default:
            return value.toString();
        }
      default:
        return value.toString();
    }
  }

}

// 버스 노선을 그리는 CustomPainter
class BusRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // 시작점
    path.moveTo(0, size.height / 2);
    
    // 중간에 약간의 곡선 추가 (실제 버스 노선처럼)
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.1,
      size.width * 0.5, size.height / 2,
    );
    
    path.quadraticBezierTo(
      size.width * 0.7, size.height * 0.9,
      size.width, size.height / 2,
    );
    
    canvas.drawPath(path, paint);
    
    // 중간에 버스 아이콘 그리기
    final busPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final busRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height / 2),
      width: 8,
      height: 6,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(busRect, const Radius.circular(2)),
      busPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 