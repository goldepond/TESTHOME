# 2026-04-11 활동 내역: 찜/관심 기능

## 목표
- buyer-strategy-analysis.md 기반 찜 기능 구현

## 구현 내용
- 공개 매물 목록(PublicListingsPage)에 Airbnb 스타일 하트 아이콘 오버레이 추가
  - 로그인 사용자에게만 표시 (FirebaseAuth.instance.currentUser 체크)
  - 북마크 상태: 빨간 채움 하트 / 미북마크: 흰색 테두리 하트 + 그림자
  - 낙관적 업데이트(Set 즉시 변경 후 서버 호출, 실패 시 롤백)
  - initState에서 addPostFrameCallback으로 북마크 ID 목록 로드
- 찜 목록 전용 페이지(MyFavoritesPage) 신규 생성
  - 북마크 ID 조회 → 매물 문서 fetch (30개 단위 청크 분할)
  - 반응형 그리드 레이아웃 (Center + ConstrainedBox + ResponsiveHelper.getMaxWidth)
  - 카드 내 하트 토글로 찜 해제 가능
  - 카드 탭 시 PublicPropertyDetailPage로 이동
  - 빈 상태: favorite_border 아이콘 + "찜한 매물이 없습니다" 메시지
- MainPage 헤더에 찜 목록 바로가기 버튼 추가
  - 알림 버튼 왼쪽에 favorite_border 아이콘 배치
  - 로그인 사용자에게만 표시
  - 탭 시 Navigator.push로 MyFavoritesPage 이동

## 변경된 파일
- `lib/screens/public/public_listings_page.dart` — 북마크 상태 관리 및 하트 오버레이 추가
- `lib/screens/buyer/my_favorites_page.dart` — 신규 생성 (찜 목록 페이지)
- `lib/screens/main_page.dart` — 헤더에 찜 목록 버튼 추가

## 남은 작업
- 매물 상세 페이지(PublicPropertyDetailPage)에도 하트 토글 추가 검토
- 찜 목록 변경 시 PublicListingsPage와 MyFavoritesPage 간 실시간 동기화 (현재는 각 페이지 진입 시 로드)
- 찜 개수 배지를 MainPage 헤더 버튼에 표시하는 기능 검토

## 비고
- 기존 FirebaseService의 toggleBookmark/getBookmarks 메서드를 그대로 활용
- Firestore whereIn 제한(30개)을 고려한 청크 분할 처리 적용
- dart analyze 통과 확인 (신규/수정 파일 에러/경고 없음)
