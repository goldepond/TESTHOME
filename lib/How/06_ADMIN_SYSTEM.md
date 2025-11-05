# 06. 관리자 시스템 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/06_ADMIN_SYSTEM.md`

---

## 📋 개요

관리자 시스템은 견적문의를 모니터링하고, 중개사에게 이메일을 전송하는 수동 프로세스를 지원합니다.

---

## 🔐 관리자 페이지 접근

**라우팅:** `lib/main.dart`

```106:118:lib/main.dart
onGenerateRoute: (settings) {
  // 관리자 페이지 라우팅 (조건부 로드)
  // 관리자 페이지를 외부로 분리할 때는 AdminPageLoaderActual 파일을 삭제하면
  // 자동으로 관리자 기능이 비활성화됩니다.
  try {
    final adminRoute = AdminPageLoaderActual.createAdminRoute(settings.name);
    if (adminRoute != null) {
      return adminRoute;
    }
  } catch (e) {
    // 관리자 페이지 파일이 없는 경우 (외부로 분리된 경우)
    print('⚠️ [Main] 관리자 페이지를 찾을 수 없습니다. 외부로 분리되었을 수 있습니다.');
  }
```

**URL:** `/admin-panel-myhome-2024`

---

## 📊 견적문의 관리

**파일:** `lib/screens/admin/admin_quote_requests_page.dart`

**실시간 모니터링:**

```31:100:lib/screens/admin/admin_quote_requests_page.dart
body: StreamBuilder<List<QuoteRequest>>(
  stream: _firebaseService.getAllQuoteRequests(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.kBrown),
            ),
            SizedBox(height: 16),
            Text(
              '견적문의를 불러오는 중...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('오류: ${snapshot.error}'),
          ],
        ),
      );
    }

    final quoteRequests = snapshot.data ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 통계 카드
          _buildStatsCards(quoteRequests),
          
          const SizedBox(height: 24),
          
          // 견적문의 목록
          const Text(
            '💬 견적문의 관리',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.kDarkBrown,
            ),
          ),
          const SizedBox(height: 16),
          
          if (quoteRequests.isEmpty)
            _buildEmptyState()
          else
            ...quoteRequests.map((request) => _buildQuoteRequestCard(request)),
        ],
      ),
    );
  },
),
```

**주요 기능:**

1. **통계 대시보드**
   - 총 견적문의 수
   - 대기중/완료 개수
   - 오늘 문의 수

2. **링크 복사**
   - 각 견적문의의 고유 링크 복사
   - 중개사에게 이메일/문자로 전송

3. **이메일 첨부**
   - 중개사 이메일 주소 입력
   - 이메일 첨부 시간 기록

---

## 🔒 캡슐화 구조

관리자 페이지는 외부로 분리 가능하도록 캡슐화되어 있습니다.

**파일 구조:**
- `lib/screens/admin/` - 관리자 페이지 UI
- `lib/utils/admin_page_loader_actual.dart` - 관리자 페이지 로더

**외부 분리 방법:**
1. `lib/utils/admin_page_loader_actual.dart` 삭제
2. `lib/screens/admin/` 폴더 삭제
3. `lib/main.dart`에서 해당 import 제거

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[07_DATA_MODELS.md](07_DATA_MODELS.md)** - 데이터 모델 상세 설명

