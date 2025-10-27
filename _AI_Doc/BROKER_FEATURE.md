# 🏘️ 공인중개사 찾기 기능 추가!

## 📋 **기능 개요**

`D:\houseMvpProject`의 **공인중개사 찾기** 기능을 Flutter 프로젝트에 완벽하게 통합!

---

## 🎯 **주요 기능**

### **1. VWorld 부동산중개업WFS조회 API**
```
API: https://api.vworld.kr/ned/wfs/getEstateBrkpgWFS
- 검색 반경: 1km (1000m)
- 최대 결과: 30개
- 거리순 자동 정렬
```

### **2. 필터링**
```
📍 가까운 3곳: 상위 3개만 표시
📋 전체 보기: 최대 30개 표시
```

### **3. 공인중개사 정보**
```
🏢 상호명
📍 도로명주소 + 기타주소
📍 지번주소
📋 등록번호
👥 고용인원
📅 데이터기준일
📏 거리 (자동 계산)
```

### **4. 액션**
```
🗺️ 길찾기: 카카오맵 연동
💬 견적문의: 메시지 입력
```

---

## 🔄 **사용자 플로우**

### **Before**
```
[판매 등록 심사] 버튼
   ↓
계약서 작성 화면 (ContractStepController)
```

### **After**
```
[공인중개사 찾기] 버튼
   ↓
공인중개사 목록 페이지 (BrokerListPage)
   ↓
[길찾기] / [견적문의]
```

---

## 📊 **API 요청 예시**

### **프록시 서버를 통한 요청**
```
http://localhost:3001/api/broker?
  key=FA0D6750-3DC2-3389-B8F1-0385C5976B96
  &typename=dt_d170
  &bbox=37.3805,127.1322,37.3824,127.1341,EPSG:4326
  &resultType=results
  &srsName=EPSG:4326
  &output=GML2
  &maxFeatures=30
```

### **BBOX 계산 (1km 반경)**
```dart
final latDelta = 1000 / 111000.0;           // 위도 변화량
final lonDelta = 1000 / (111000.0 * cos(lat * pi / 180)); // 경도 변화량

bbox = '$ymin,$xmin,$ymax,$xmax,EPSG:4326'
```

---

## 🏗️ **생성된 파일**

### **1. lib/services/broker_service.dart**
```dart
/// VWorld 부동산중개업WFS조회 API 서비스
class BrokerService {
  // API 호출
  static Future<List<Broker>> searchNearbyBrokers({
    required double latitude,
    required double longitude,
    int radiusMeters = 1000,
  });
  
  // BBOX 생성
  static String _generateBBOX(...);
  
  // XML 파싱
  static List<Broker> _parseXML(...);
  
  // 거리 계산 (Haversine 공식)
  static double _calculateHaversineDistance(...);
}

/// 공인중개사 정보 모델
class Broker {
  final String name;
  final String roadAddress;
  final String jibunAddress;
  final String registrationNumber;
  final double? distance;
  
  String get distanceText;  // "1.2km" 또는 "350m"
  String get fullAddress;   // 도로명 + 기타주소
}
```

### **2. lib/screens/broker_list_page.dart**
```dart
/// 공인중개사 찾기 페이지
class BrokerListPage extends StatefulWidget {
  final String address;
  final double latitude;
  final double longitude;
}

Features:
- 주소 요약 카드
- 필터 버튼 (가까운 3곳 / 전체 보기)
- 공인중개사 카드 목록
- 길찾기 / 견적문의 버튼
```

### **3. proxy-server.js (업데이트)**
```javascript
// 새로운 엔드포인트 추가
app.use('/api/broker', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    pathRewrite: {
        '^/api/broker': '/ned/wfs/getEstateBrkpgWFS'
    }
}));
```

### **4. lib/screens/home_page.dart (수정)**
```dart
// Import 추가
import 'broker_list_page.dart';

// 메서드 추가
void _goToBrokerSearch() {
  Navigator.push(...);
}

// 버튼 변경
onPressed: _goToBrokerSearch
label: Text('공인중개사 찾기')
```

---

## 🎨 **UI 디자인**

### **공인중개사 카드 (등기부등본 스타일과 통일)**
```
┌──────────────────────────────────────┐
│ 🏢 성남부동산중개        📍 250m     │ ← 보라/인디고 그라데이션
├──────────────────────────────────────┤
│ 📍 도로명주소: 경기도 성남시...      │
│ 📍 지번주소: 서현동 266-1            │
│ 📋 등록번호: 11680-2019-00345        │
│ 👥 고용인원: 2명                     │
│ 📅 데이터기준일: 2024-01-15          │
├──────────────────────────────────────┤
│ [🗺️ 길찾기]  [💬 견적문의]          │
└──────────────────────────────────────┘
```

---

## 🚀 **거리 계산 로직**

### **Haversine 공식 (WGS84 좌표)**
```dart
// 지구를 구로 가정하고 두 점 간 최단 거리 계산
const R = 6371000.0; // 지구 반지름 (미터)

final dLat = (lat2 - lat1) * pi / 180;
final dLon = (lon2 - lon1) * pi / 180;

final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLon / 2) * sin(dLon / 2);

final c = 2 * atan2(sqrt(a), sqrt(1 - a));
final distance = R * c; // 미터 단위
```

### **유클리드 거리 (TM 좌표, EPSG:5186)**
```dart
// TM 좌표계는 이미 미터 단위이므로 피타고라스 정리
if (lon1 > 1000 && lon2 > 1000) {
  final dx = lon2 - lon1;
  final dy = lat2 - lat1;
  return sqrt(dx * dx + dy * dy);
}
```

---

## 📱 **사용 시나리오**

### **예시: 성남시 아파트 매물**
```
1. 주소 검색: "경기도 성남시 분당구 중앙공원로 54"
2. 상세 주소: "211동 1506호"
3. [조회하기] 클릭
4. 등기부등본 + VWorld 정보 표시
5. [공인중개사 찾기] 클릭 ← NEW!
   ↓
6. 공인중개사 목록 페이지
   ━━━━━━━━━━━━━━━━━━━━━━━━━━
   📍 검색 기준 주소
   경기도 성남시 분당구 중앙공원로 54...
   좌표: 37.381490, 127.133153
   ━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   [📍 가까운 3곳] [📋 전체 보기]
   
   ┌────────────────────────────────┐
   │ 🏢 성남부동산중개     📍 250m   │
   │ 📍 황새울로 246, 1층 101호     │
   │ 📋 11680-2019-00345            │
   │ 👥 2명                         │
   │ [🗺️ 길찾기] [💬 견적문의]      │
   └────────────────────────────────┘
   
   ┌────────────────────────────────┐
   │ 🏢 분당공인중개사사무소 📍 450m │
   │ ...                            │
   └────────────────────────────────┘
   
   ┌────────────────────────────────┐
   │ 🏢 서현부동산        📍 680m   │
   │ ...                            │
   └────────────────────────────────┘
```

---

## ✅ **D:\houseMvpProject 기능 흡수 완료!**

| 기능 | D:\houseMvpProject | 현재 Flutter 프로젝트 | 상태 |
|------|-------------------|---------------------|------|
| **VWorld Geocoder** | ✅ | ✅ | 완료 |
| **VWorld 토지특성** | ✅ | ✅ | 완료 |
| **VWorld 부동산중개업** | ✅ | ✅ | **NEW!** |
| **프록시 서버** | ✅ | ✅ | 완료 |
| **거리 계산** | ✅ | ✅ | 완료 |
| **필터링** | ✅ | ✅ | 완료 |
| **길찾기** | ✅ | ✅ | 완료 |
| **견적문의** | ✅ | ✅ | 완료 |

---

## 🔧 **다음 단계**

### **1. 프록시 서버 재시작**
```bash
# 기존 프록시 서버 중지 (Ctrl+C)
# 새로운 프록시 서버 시작
node proxy-server.js
```

### **2. Flutter 앱 확인**
```
주소 조회 → [공인중개사 찾기] 버튼 클릭
→ 주변 공인중개사 목록 표시
```

---

## 🎉 **완료!**

**D:\houseMvpProject의 공인중개사 찾기 기능이 Flutter 프로젝트에 완벽하게 통합되었습니다!**

- ✅ API 연동
- ✅ 거리 계산
- ✅ UI/UX 통일
- ✅ 프록시 서버
- ✅ 필터링
- ✅ 액션 버튼



