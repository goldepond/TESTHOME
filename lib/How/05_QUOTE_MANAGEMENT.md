# 05. 견적 관리 및 답변 시스템 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/05_QUOTE_MANAGEMENT.md`

---

## 📋 개요

견적 관리 시스템은 사용자가 요청한 견적을 확인하고, 중개사가 답변하는 전체 플로우를 관리합니다.

---

## 📊 견적 이력 확인

**파일:** `lib/screens/quote_history_page.dart`

**실시간 데이터 수신:**

```46:78:lib/screens/quote_history_page.dart
/// 견적문의 목록 로드
Future<void> _loadQuotes() async {
  if (!mounted) return;
  
  setState(() {
    isLoading = true;
    error = null;
  });
  
  try {
    
    // userId가 있으면 userId 사용, 없으면 userName 사용
    final queryId = widget.userId ?? widget.userName;
    
    // Stream으로 실시간 데이터 수신
    _firebaseService.getQuoteRequestsByUser(queryId).listen((loadedQuotes) {
      if (mounted) {
        setState(() {
          quotes = loadedQuotes;
          isLoading = false;
        });
        _applyFilter();
      }
    });
  } catch (e) {
    print('❌ [견적문의내역] 로드 오류: $e');
    if (!mounted) return;
    
    setState(() {
      error = '견적문의 내역을 불러오는 중 오류가 발생했습니다.';
      isLoading = false;
    });
  }
}
```

**필터링 및 그룹화:**

```80:104:lib/screens/quote_history_page.dart
/// 필터 적용
void _applyFilter() {
  setState(() {
    if (selectedStatus == 'all') {
      filteredQuotes = quotes;
    } else {
      filteredQuotes = quotes.where((q) => q.status == selectedStatus).toList();
    }
    
    // 주소별로 그룹화
    _groupedQuotes = {};
    for (final quote in filteredQuotes) {
      final address = quote.propertyAddress ?? '주소없음';
      if (!_groupedQuotes.containsKey(address)) {
        _groupedQuotes[address] = [];
      }
      _groupedQuotes[address]!.add(quote);
    }
    
    // 각 그룹 내에서 날짜순 정렬 (최신순)
    _groupedQuotes.forEach((key, value) {
      value.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    });
  });
}
```

---

## 🔄 중개사 답변 시스템

**파일:** `lib/screens/inquiry/broker_inquiry_response_page.dart`

**답변 로드:**

```40:70:lib/screens/inquiry/broker_inquiry_response_page.dart
Future<void> _loadInquiry() async {
  setState(() => _isLoading = true);

  try {
    final data = await _firebaseService.getQuoteRequestByLinkId(widget.linkId);
    
    if (data == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() {
      _inquiryData = data;
      _isLoading = false;
      // 이미 답변이 있으면 표시하고 수정 가능하도록
      if (data['brokerAnswer'] != null && data['brokerAnswer'].toString().isNotEmpty) {
        _hasExistingAnswer = true;
        _answerController.text = data['brokerAnswer'];
      }
    });
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문의 정보를 불러오는데 실패했습니다: $e')),
      );
    }
  }
}
```

**답변 제출:**

```72:132:lib/screens/inquiry/broker_inquiry_response_page.dart
Future<void> _submitAnswer() async {
  if (_answerController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('답변을 입력해주세요.')),
    );
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    final success = await _firebaseService.updateQuoteRequestAnswer(
      _inquiryData!['id'],
      _answerController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      
      if (success) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_hasExistingAnswer ? '✅ 답변 수정 완료' : '✅ 답변 전송 완료'),
            content: Text(
              _hasExistingAnswer 
                ? '답변이 성공적으로 수정되었습니다.\n'
                  '문의자에게 수정된 답변이 즉시 전달됩니다.'
                : '답변이 성공적으로 전송되었습니다.\n'
                  '문의자에게 답변이 즉시 전달됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        
        // 기존 답변 상태로 변경 및 데이터 다시 로드
        setState(() => _hasExistingAnswer = true);
        await _loadInquiry();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('답변 전송에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }
}
```

---

## 📊 견적 비교 기능

**파일:** `lib/screens/quote_comparison_page.dart`

견적 비교 페이지는 여러 중개사의 답변을 한눈에 비교할 수 있도록 제공합니다.

**주요 기능:**
- 최저가/평균가/최고가 자동 계산
- 가격 추출 및 파싱
- 중개사별 상세 정보 표시

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[06_ADMIN_SYSTEM.md](06_ADMIN_SYSTEM.md)** - 관리자 시스템 상세 설명

