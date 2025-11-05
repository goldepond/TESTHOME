import 'package:flutter/material.dart';
import 'package:property/models/property.dart';
import 'package:property/models/visit_request.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/visit/visit_management_dashboard.dart';

class VisitRequestForm extends StatefulWidget {
  final Property property;
  final String currentUserId;
  final String currentUserName;

  const VisitRequestForm({
    super.key,
    required this.property,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<VisitRequestForm> createState() => _VisitRequestFormState();
}

class _VisitRequestFormState extends State<VisitRequestForm> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  bool _isSubmitting = false;
  String _currentMessage = ''; // 메시지 텍스트 상태 추가

  @override
  void dispose() {
    _messageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitVisitRequest() async {
    // 디버그: 메시지 검증 확인
    final messageText = _currentMessage.trim();
    
    // 메시지 검증 강화
    if (messageText.isEmpty || messageText.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('방문 신청 메시지를 3글자 이상 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 방문 시간 조합
      final visitDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final visitRequest = VisitRequest(
        propertyId: widget.property.firestoreId ?? '',
        propertyAddress: widget.property.address,
        buyerId: widget.currentUserId,
        buyerName: widget.currentUserName,
        sellerId: widget.property.userMainContractor ?? widget.property.registeredBy ?? '',
        sellerName: widget.property.userMainContractor ?? widget.property.registeredByName ?? '',
        visitTimestamp: visitDateTime,
        lastMessage: messageText, // _currentMessage.trim() 사용
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // 디버그: VisitRequest 생성 확인

      final result = await _firebaseService.createVisitRequest(visitRequest);
      
      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('방문 신청이 성공적으로 전송되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          // 방문 관리 대시보드로 이동
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VisitManagementDashboard(
                currentUserId: widget.currentUserId,
                currentUserName: widget.currentUserName,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('방문 신청 전송에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방문 신청'),
        backgroundColor: AppColors.kBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 매물 정보 카드
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.home, color: AppColors.kBrown, size: 24),
                        SizedBox(width: 8),
                        Text(
                          '매물 정보',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.property.address,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.property.transactionType} • ${widget.property.price.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},'
                      )}원',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '등록자: ${widget.property.mainContractor}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 방문 날짜 선택
            const Text(
              '방문 날짜',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.kBrown),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 방문 시간 선택
            const Text(
              '방문 시간',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.kBrown),
                    const SizedBox(width: 12),
                    Text(
                      _formatTime(_selectedTime),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 방문 신청 메시지
            const Text(
              '방문 신청 메시지 *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentMessage.length < 3 
                ? '3글자 이상 입력해주세요 (현재: ${_currentMessage.length}글자)'
                : '메시지 입력 완료 (${_currentMessage.length}글자)',
              style: TextStyle(
                fontSize: 12,
                color: _currentMessage.length < 3 ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              autofocus: false,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                setState(() {
                  _currentMessage = value;
                });
              },
              decoration: InputDecoration(
                hintText: '방문 신청 메시지를 입력해주세요...',
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _currentMessage.isNotEmpty && _currentMessage.length < 3 
                      ? Colors.red 
                      : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _currentMessage.isNotEmpty && _currentMessage.length < 3 
                      ? Colors.red 
                      : AppColors.kBrown,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
                counterText: '', // 문자 수 카운터 제거
              ),
            ),
            const SizedBox(height: 16),

            // 추가 메모
            const Text(
              '추가 메모 (선택사항)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '추가로 전달하고 싶은 내용이 있다면 입력해주세요...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 32),

            // 제출 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVisitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '방문 신청하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 