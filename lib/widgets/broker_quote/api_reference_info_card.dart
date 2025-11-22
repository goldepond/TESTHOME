import 'package:flutter/material.dart';

class ApiReferenceInfoCard extends StatelessWidget {
  final bool isLoading;
  final String? apiError;
  final Map<String, String>? fullAddrAPIData;
  final Map<String, dynamic>? vworldCoordinates;
  final Map<String, dynamic>? aptInfo;

  const ApiReferenceInfoCard({
    super.key,
    required this.isLoading,
    this.apiError,
    this.fullAddrAPIData,
    this.vworldCoordinates,
    this.aptInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              const Text(
                '매물 정보 참조',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '주소 검색 시 API로 불러온 정보입니다. 답변 작성 시 참고하세요.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (apiError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      apiError!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 주소 상세 정보 (Juso API)
            if (fullAddrAPIData != null && fullAddrAPIData!.isNotEmpty) ...[
              _buildInfoSection(
                '주소 상세 정보',
                Icons.location_on,
                [
                  if (fullAddrAPIData!['roadAddr'] != null && fullAddrAPIData!['roadAddr']!.isNotEmpty)
                    _buildInfoRow('도로명주소', fullAddrAPIData!['roadAddr']!),
                  if (fullAddrAPIData!['jibunAddr'] != null && fullAddrAPIData!['jibunAddr']!.isNotEmpty)
                    _buildInfoRow('지번주소', fullAddrAPIData!['jibunAddr']!),
                  if (fullAddrAPIData!['bdNm'] != null && fullAddrAPIData!['bdNm']!.isNotEmpty)
                    _buildInfoRow('건물명', fullAddrAPIData!['bdNm']!),
                  if (fullAddrAPIData!['siNm'] != null && fullAddrAPIData!['siNm']!.isNotEmpty)
                    _buildInfoRow('시도', fullAddrAPIData!['siNm']!),
                  if (fullAddrAPIData!['sggNm'] != null && fullAddrAPIData!['sggNm']!.isNotEmpty)
                    _buildInfoRow('시군구', fullAddrAPIData!['sggNm']!),
                  if (fullAddrAPIData!['emdNm'] != null && fullAddrAPIData!['emdNm']!.isNotEmpty)
                    _buildInfoRow('읍면동', fullAddrAPIData!['emdNm']!),
                  if (fullAddrAPIData!['rn'] != null && fullAddrAPIData!['rn']!.isNotEmpty)
                    _buildInfoRow('도로명', fullAddrAPIData!['rn']!),
                  if (fullAddrAPIData!['buldMgtNo'] != null && fullAddrAPIData!['buldMgtNo']!.isNotEmpty)
                    _buildInfoRow('건물관리번호', fullAddrAPIData!['buldMgtNo']!),
                  if (fullAddrAPIData!['roadAddrNo'] != null && fullAddrAPIData!['roadAddrNo']!.isNotEmpty)
                    _buildInfoRow('건물번호', fullAddrAPIData!['roadAddrNo']!),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // VWorld 좌표 정보
            if (vworldCoordinates != null && vworldCoordinates!.isNotEmpty) ...[
              _buildInfoSection(
                '좌표 정보',
                Icons.my_location,
                [
                  if (vworldCoordinates!['x'] != null)
                    _buildInfoRow('경도', vworldCoordinates!['x'].toString()),
                  if (vworldCoordinates!['y'] != null)
                    _buildInfoRow('위도', vworldCoordinates!['y'].toString()),
                  if (vworldCoordinates!['level'] != null)
                    _buildInfoRow('정확도 레벨', vworldCoordinates!['level'].toString()),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // 아파트 단지 정보
            if (aptInfo != null && aptInfo!.isNotEmpty) ...[
              _buildInfoSection(
                '아파트 단지 정보',
                Icons.apartment,
                [
                  if (aptInfo!['kaptCode'] != null && aptInfo!['kaptCode'].toString().isNotEmpty)
                    _buildInfoRow('단지코드', aptInfo!['kaptCode'].toString()),
                  if (aptInfo!['kaptName'] != null && aptInfo!['kaptName'].toString().isNotEmpty)
                    _buildInfoRow('단지명', aptInfo!['kaptName'].toString()),
                  if (aptInfo!['codeStr'] != null && aptInfo!['codeStr'].toString().isNotEmpty)
                    _buildInfoRow('건물구조', aptInfo!['codeStr'].toString()),
                  if (aptInfo!['kaptdPcnt'] != null && aptInfo!['kaptdPcnt'].toString().isNotEmpty)
                    _buildInfoRow('주차대수(지상)', '${aptInfo!['kaptdPcnt']}대'),
                  if (aptInfo!['kaptdPcntu'] != null && aptInfo!['kaptdPcntu'].toString().isNotEmpty)
                    _buildInfoRow('주차대수(지하)', '${aptInfo!['kaptdPcntu']}대'),
                  if (aptInfo!['kaptdEcnt'] != null && aptInfo!['kaptdEcnt'].toString().isNotEmpty)
                    _buildInfoRow('승강기대수', '${aptInfo!['kaptdEcnt']}대'),
                  if (aptInfo!['kaptMgrCnt'] != null && aptInfo!['kaptMgrCnt'].toString().isNotEmpty)
                    _buildInfoRow('관리사무소 수', '${aptInfo!['kaptMgrCnt']}개'),
                  if (aptInfo!['kaptCcompany'] != null && aptInfo!['kaptCcompany'].toString().isNotEmpty)
                    _buildInfoRow('관리업체', aptInfo!['kaptCcompany'].toString()),
                  if (aptInfo!['codeMgr'] != null && aptInfo!['codeMgr'].toString().isNotEmpty)
                    _buildInfoRow('관리방식', aptInfo!['codeMgr'].toString()),
                  if (aptInfo!['kaptdCccnt'] != null && aptInfo!['kaptdCccnt'].toString().isNotEmpty)
                    _buildInfoRow('CCTV대수', '${aptInfo!['kaptdCccnt']}대'),
                  if (aptInfo!['codeSec'] != null && aptInfo!['codeSec'].toString().isNotEmpty)
                    _buildInfoRow('경비관리방식', aptInfo!['codeSec'].toString()),
                  if (aptInfo!['kaptdScnt'] != null && aptInfo!['kaptdScnt'].toString().isNotEmpty)
                    _buildInfoRow('경비인력 수', '${aptInfo!['kaptdScnt']}명'),
                  if (aptInfo!['kaptdSecCom'] != null && aptInfo!['kaptdSecCom'].toString().isNotEmpty)
                    _buildInfoRow('경비업체', aptInfo!['kaptdSecCom'].toString()),
                  if (aptInfo!['codeClean'] != null && aptInfo!['codeClean'].toString().isNotEmpty)
                    _buildInfoRow('청소관리방식', aptInfo!['codeClean'].toString()),
                  if (aptInfo!['kaptdClcnt'] != null && aptInfo!['kaptdClcnt'].toString().isNotEmpty)
                    _buildInfoRow('청소인력 수', '${aptInfo!['kaptdClcnt']}명'),
                  if (aptInfo!['codeGarbage'] != null && aptInfo!['codeGarbage'].toString().isNotEmpty)
                    _buildInfoRow('음식물처리방법', aptInfo!['codeGarbage'].toString()),
                  if (aptInfo!['codeDisinf'] != null && aptInfo!['codeDisinf'].toString().isNotEmpty)
                    _buildInfoRow('소독관리방식', aptInfo!['codeDisinf'].toString()),
                  if (aptInfo!['kaptdDcnt'] != null && aptInfo!['kaptdDcnt'].toString().isNotEmpty)
                    _buildInfoRow('소독인력 수', '${aptInfo!['kaptdDcnt']}명'),
                  if (aptInfo!['codeEcon'] != null && aptInfo!['codeEcon'].toString().isNotEmpty)
                    _buildInfoRow('세대전기계약방식', aptInfo!['codeEcon'].toString()),
                  if (aptInfo!['kaptdEcapa'] != null && aptInfo!['kaptdEcapa'].toString().isNotEmpty)
                    _buildInfoRow('수전용량', aptInfo!['kaptdEcapa'].toString()),
                  if (aptInfo!['codeFalarm'] != null && aptInfo!['codeFalarm'].toString().isNotEmpty)
                    _buildInfoRow('화재수신반방식', aptInfo!['codeFalarm'].toString()),
                  if (aptInfo!['codeWsupply'] != null && aptInfo!['codeWsupply'].toString().isNotEmpty)
                    _buildInfoRow('급수방식', aptInfo!['codeWsupply'].toString()),
                  if (aptInfo!['codeElev'] != null && aptInfo!['codeElev'].toString().isNotEmpty)
                    _buildInfoRow('승강기관리형태', aptInfo!['codeElev'].toString()),
                  if (aptInfo!['codeNet'] != null && aptInfo!['codeNet'].toString().isNotEmpty)
                    _buildInfoRow('주차관제/홈네트워크', aptInfo!['codeNet'].toString()),
                  if (aptInfo!['welfareFacility'] != null && aptInfo!['welfareFacility'].toString().isNotEmpty)
                    _buildInfoRow('부대/복리시설', aptInfo!['welfareFacility'].toString()),
                  if (aptInfo!['convenientFacility'] != null && aptInfo!['convenientFacility'].toString().isNotEmpty)
                    _buildInfoRow('편의시설', aptInfo!['convenientFacility'].toString()),
                  if (aptInfo!['kaptdWtimebus'] != null && aptInfo!['kaptdWtimebus'].toString().isNotEmpty)
                    _buildInfoRow('버스정류장 거리', aptInfo!['kaptdWtimebus'].toString()),
                  if (aptInfo!['subwayLine'] != null && aptInfo!['subwayLine'].toString().isNotEmpty)
                    _buildInfoRow('지하철 노선', aptInfo!['subwayLine'].toString()),
                  if (aptInfo!['subwayStation'] != null && aptInfo!['subwayStation'].toString().isNotEmpty)
                    _buildInfoRow('지하철역', aptInfo!['subwayStation'].toString()),
                  if (aptInfo!['kaptdWtimesub'] != null && aptInfo!['kaptdWtimesub'].toString().isNotEmpty)
                    _buildInfoRow('지하철역 거리', aptInfo!['kaptdWtimesub'].toString()),
                ],
              ),
            ],
            
            // 정보가 하나도 없는 경우
            if ((fullAddrAPIData == null || fullAddrAPIData!.isEmpty) &&
                (vworldCoordinates == null || vworldCoordinates!.isEmpty) &&
                (aptInfo == null || aptInfo!.isEmpty))
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'API 정보를 불러올 수 없습니다.\n주소 정보를 확인해주세요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
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
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

